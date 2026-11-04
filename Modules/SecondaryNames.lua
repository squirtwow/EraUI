local _, EraUI = ...
local Module = {}
EraUI:RegisterModule("SecondaryNames", Module)

-- Client versions expose different subsets; never create unknown CVars.
local settings = {"UnitSurnameOwn", "UnitSurname", "UnitSurnameOther",
    "UnitSurnameFriendly", "UnitSurnameEnemy", "ShowSurnames"}
local changing = false
local function Read(name)
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    if not get then return end
    local ok, value = pcall(get, name)
    if ok and value ~= nil and not (issecretvalue and issecretvalue(value)) then return tostring(value) end
end
-- The game's surname switches are the player's until Hide Surnames is
-- ticked. While it is on, EraUI owns them (EraUIDB.secondaryNamesOwned) and
-- keeps them at "0"; switched off, each goes back to the game's default once
-- and is the player's again. Off and not owned, nothing is touched, so the
-- game's own "My surname" box keeps the player's choice through every
-- loading screen.
function Module:Apply()
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if changing or not set or not EraUIDB then return end
    local hidden = not self.handingBack and EraUI:GetSetting("hideSecondaryNames") and true or false
    if hidden then self:WatchTooltips() end
    if not hidden and not EraUIDB.secondaryNamesOwned then return end
    changing = true
    EraUIDB.secondaryNamesOwned = hidden or nil
    -- A saved "0" from a previous session must never become the value
    -- restored on disable.
    EraUIDB.secondaryNameBackup = nil
    for _, name in ipairs(settings) do
        local current = Read(name)
        if current ~= nil then
            local desired = "0"
            if not hidden then
                desired = "1"
                local getDefault = C_CVar and C_CVar.GetCVarDefault or GetCVarDefault
                if getDefault then
                    local ok, value = pcall(getDefault, name)
                    if ok and value ~= nil and not (issecretvalue and issecretvalue(value)) then
                        value = tostring(value)
                        if value ~= "0" and value ~= "" then desired = value end
                    end
                end
            end
            if current ~= desired then pcall(set, name, desired) end
        end
    end
    changing = false
end
-- /era reset, just before its reload (Core/Commands.lua). The reset leaves
-- Hide Surnames off with no record that EraUI owned the switches, so any it
-- owns go back to the game's defaults now, as switching it off does.
function Module:HandBack()
    if not (EraUIDB and EraUIDB.secondaryNamesOwned) then return end
    self.handingBack = true
    pcall(self.Apply, self)
    self.handingBack = nil
end
-- Change only the visible label of player links; retain the full link target.
local chatFrames = setmetatable({}, {__mode="k"})
function Module:ShortenChatText(text)
    if not EraUI:GetSetting("hideSecondaryNames") or (issecretvalue and issecretvalue(text)) or type(text)~="string" then return text end
    return (text:gsub("(|Hplayer:[^|]+|h)(.-)(|h)", function(link,label,ending)
        label=label:gsub("(%[[^%s%]]+)%s+[^|%]]+", "%1")
        return link..label..ending
    end))
end
function Module:HookChatFrames()
    for _,name in ipairs(CHAT_FRAMES or {}) do
        local frame=_G[name]
        if frame and frame.AddMessage and not chatFrames[frame] then
            chatFrames[frame]=true
            local original=frame.AddMessage
            frame.AddMessage=function(self,text,...)
                return original(self,Module:ShortenChatText(text),...)
            end
        end
    end
end
-- Players' names on unit tooltips without the surname (On Tooltips Too,
-- under Hide Surnames). The game has no surname switch for tooltips (its one
-- surname CVar, UnitSurnameOwn, is the name over your own head), so the
-- name line is trimmed after the game has written it, from the game's own
-- unit tooltip post-call: Forever runs an add-on's post-calls in a call of
-- their own, apart from the tooltip's code, the path Tooltip IDs uses. No
-- hook on GameTooltip and no key written on it: only the name line's text
-- changes, and only when every value read is plain (never a hidden one).
local function Secret(value) return issecretvalue ~= nil and issecretvalue(value) == true end
local function Separator()
    local consts = Constants and Constants.CharacterNameSeparatorConsts
    local sep = consts and consts.CHARACTERNAME_SURNAME_SEPARATOR
    if type(sep) == "string" and sep ~= "" and not Secret(sep) then return sep end
    return " "
end
-- The unit the tooltip shows (mouseover, target, a party member...), or nil.
local function UnitFor(guid)
    if type(UnitTokenFromGUID) ~= "function" then return nil end
    local ok, unit = pcall(UnitTokenFromGUID, guid)
    if ok and not Secret(unit) and type(unit) == "string" and unit ~= "" then return unit end
end
-- A player's whole name as the game writes it, and the first name alone; nil
-- without a surname. UnitName gives the surname as its second value; with
-- the game's regional names it may come joined to the first.
local function NameParts(unit)
    local ok, first, surname = pcall(UnitName, unit)
    if not ok or Secret(first) or Secret(surname) or type(first) ~= "string" or first == "" then return nil end
    local sep = Separator()
    if type(surname) == "string" and surname ~= "" then
        local tail = sep .. surname
        if #first > #tail and first:sub(-#tail) == tail then return first, first:sub(1, #first - #tail) end
        return first .. tail, first
    end
    local at = first:find(sep, 1, true)
    if not at or at == 1 or at + #sep > #first then return nil end
    return first, first:sub(1, at - 1)
end
-- The tooltip's name line: the line the game's data marks as the unit's
-- name (the first, as a rule), read through the template's own key.
local function NameLabel(tooltip, data)
    local index = 1
    local kinds = Enum and Enum.TooltipDataLineType
    if kinds and kinds.UnitName ~= nil and type(data.lines) == "table" then
        for _, line in ipairs(data.lines) do
            if type(line) == "table" and line.type == kinds.UnitName then
                local at = line.lineIndex
                if not Secret(at) and type(at) == "number" then index = at end
                break
            end
        end
    end
    local label = tooltip["TextLeft" .. index]
    if type(label) == "table" and type(label.GetText) == "function" and type(label.SetText) == "function" then return label end
end
function Module:TrimTooltipName(tooltip, data)
    if not (EraUI:GetSetting("hideSecondaryNames") and EraUI:GetSetting("hideSecondaryNamesTooltips")) then return end
    if type(tooltip) ~= "table" or type(data) ~= "table" then return end
    if tooltip.IsForbidden and tooltip:IsForbidden() then return end
    local guid = data.guid
    if Secret(guid) or type(guid) ~= "string" or guid:sub(1, 7) ~= "Player-" then return end
    local unit = UnitFor(guid)
    local whole, first = nil, nil
    if unit then whole, first = NameParts(unit) end
    if not whole then return end
    local label = NameLabel(tooltip, data)
    if not label then return end
    local text = label:GetText()
    if Secret(text) or type(text) ~= "string" then return end
    local at = text:find(whole, 1, true)
    if not at then return end
    label:SetText(text:sub(1, at - 1) .. first .. text:sub(at + #whole))
end
-- Asked for the first time Hide Surnames is on (the post-call can't be taken
-- back, and with the option off it is never there at all).
function Module:WatchTooltips()
    if self.watchingTooltips then return end
    local processor, kinds = TooltipDataProcessor, Enum and Enum.TooltipDataType
    if type(processor) ~= "table" or type(processor.AddTooltipPostCall) ~= "function" or not kinds or kinds.Unit == nil then return end
    self.watchingTooltips = true
    processor.AddTooltipPostCall(kinds.Unit, function(tooltip, data) Module:TrimTooltipName(tooltip, data) end)
end
function Module:Initialize()
    self:HookChatFrames()
    if FCF_OpenTemporaryWindow then hooksecurefunc("FCF_OpenTemporaryWindow", function() self:HookChatFrames() end) end
    if FCF_OpenNewWindow then hooksecurefunc("FCF_OpenNewWindow", function() self:HookChatFrames() end) end
    self.events = CreateFrame("Frame")
    self.events:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.events:SetScript("OnEvent", function()
        if not changing then self:Apply() end
    end)
    -- The client can rewrite these CVars while it redraws name text, which
    -- used to make the toggle look like it switched itself back off. While
    -- the toggle is on, quietly re-assert the values every couple of seconds;
    -- six reads that land on the right value change nothing at all.
    self.events:SetScript("OnUpdate", function(_, elapsed)
        if not EraUI:GetSetting("hideSecondaryNames") then return end
        self.since = (self.since or 0) + elapsed
        if self.since < 2 then return end
        self.since = 0
        if not changing then self:Apply() end
    end)
    self:Apply()
end
