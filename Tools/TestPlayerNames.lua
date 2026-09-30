-- "Is this me?" on Forever. Names have a surname and no realm: UnitName("player")
-- gives ("Zriel", "Gustbellow") while the guild roster, /who, whispers and addon
-- messages call you "Zriel Gustbellow". Runs the shared helper, then the real
-- guild roster, /who list and turn-off code under a frame mock.
local checks = 0
unpack = table.unpack or unpack
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local secret = setmetatable({}, { __tostring = function() return "secret" end })
issecretvalue = function(v) return v == secret end
local function Me(first, surname) UnitName = function() return first, surname end end
local ambiguated = {}
Ambiguate = function(name, context)
    assert(not issecretvalue(name), "a hidden name must never reach Ambiguate")
    ambiguated[#ambiguated + 1] = context
    return (name:gsub("%-[^%s%-]+$", ""))
end
local myGuid = "Player-4-0001"
UnitGUID = function(unit) assert(unit == "player", "only your own GUID is asked for") return myGuid end

-- The shared helper.
local ns = {}
local E = { Classic = ns }
assert(loadfile("Core/Utils.lua"))("EraUI", E)

Me("Zriel", "Gustbellow")
Equal(E:PlayerFullName(), "Zriel Gustbellow", "your whole name joins first name and surname")
Equal(E:IsPlayer("Zriel Gustbellow"), true, "First Surname is you")
Equal(E:IsPlayer("Zriel"), false, "your first name alone is someone else")
Equal(E:IsPlayer("Zriel Otherperson"), false, "a different surname is someone else")
Equal(E:IsPlayer("Gustbellow"), false, "your surname alone is someone else")
Equal(E:IsPlayer("Coww Stagkiller"), false, "another player isn't you")
Equal(E:IsPlayer("Zriel Gustbellow-ClassicBetaPvE"), true, "a realm suffix is dropped first")
Equal(ambiguated[#ambiguated], "none", "only a same-realm suffix, as the update notice did")
Equal(E:IsPlayer("zriel gustbellow"), false, "names match exactly")
Equal(E:IsPlayer(nil), false, "no name isn't you")
Equal(E:IsPlayer(""), false, "an empty name isn't you")
Equal(E:IsPlayer(42), false, "a number isn't a name")
Equal(E:IsPlayer(secret), false, "a hidden name is never compared")

Equal(E:IsPlayer("Somebody", myGuid), true, "your GUID settles it")
Equal(E:IsPlayer("Zriel Gustbellow", "Player-4-0999"), true, "another GUID still falls back to the whole name")
Equal(E:IsPlayer("Coww Stagkiller", "Player-4-0999"), false, "another GUID and name isn't you")
Equal(E:IsPlayer("Coww Stagkiller", secret), false, "a hidden GUID is never compared")
myGuid = secret
Equal(E:IsPlayer("Coww Stagkiller", secret), false, "nor is a hidden own GUID")
Equal(E:IsPlayer("Zriel Gustbellow", "Player-4-0001"), true, "the name still works without your GUID")
myGuid = "Player-4-0001"

Me("Zriel", nil)
Equal(E:PlayerFullName(), "Zriel", "no surname: the first name is the whole name")
Equal(E:IsPlayer("Zriel"), true, "and matches")
Equal(E:IsPlayer("Zriel-ClassicBetaPvE"), true, "with or without a realm")
Me("Zriel", "")
Equal(E:IsPlayer("Zriel"), true, "an empty surname is no surname")
Equal(E:IsPlayer("Zriel "), false, "without a trailing space")
Me("Zriel Gustbellow", "Gustbellow")
Equal(E:PlayerFullName(), "Zriel Gustbellow", "a first value already holding the surname isn't doubled")
Me("Zriel", "Gustbellow")
Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = "_" } }
Equal(E:PlayerFullName(), "Zriel_Gustbellow", "the game's own surname separator is used")
Constants = nil
Me(secret, "Gustbellow")
Equal(E:PlayerFullName(), nil, "a hidden name gives nothing")
Equal(E:IsPlayer("Zriel Gustbellow"), false, "and matches nothing")
UnitNameUnmodified = function() return "Zriel", "Gustbellow" end
Equal(E:IsPlayer("Zriel Gustbellow"), true, "the unmodified name counts too, as the game's own check does")
UnitNameUnmodified = nil
Me("Zriel", secret)
Equal(E:PlayerFullName(), "Zriel", "a hidden surname is left off")
UnitName = function() error("no unit yet") end
Equal(E:PlayerFullName(), nil, "UnitName failing gives nothing")
Equal(E:IsPlayer("Zriel Gustbellow"), false, "and matches nothing")
Me("Zriel", "Gustbellow")

-- A frame mock: named frames land in _G, unknown verbs do nothing, fields are nil.
local frames = {}
local F = {}
local VERBS = { "Set", "Enable", "Disable", "Register", "Unregister", "Hook", "Clear", "Create", "Get", "Is",
    "Start", "Stop", "Raise", "Lower", "Lock", "Unlock", "Add", "Remove", "Update", "Play", "Adjust", "Scroll", "Click" }
local function Verb(k)
    for _, v in ipairs(VERBS) do
        local rest = k:sub(#v + 1, #v + 1)
        if k:sub(1, #v) == v and (rest == "" or rest:match("%u")) then return true end
    end
end
local function Frame(kind, name, parent)
    local f = setmetatable({ kind = kind, name = name, parent = parent, shown = true, scripts = {}, events = {},
        enabled = true, h = 400, w = 300 }, { __index = function(self, k)
        if F[k] then return F[k] end
        if type(k) ~= "string" then return nil end
        if k:match("^Get.*Texture$") then
            return function(me)
                if not rawget(me, k .. "_") then rawset(me, k .. "_", Frame("Texture", nil, me)) end
                return rawget(me, k .. "_")
            end
        end
        if Verb(k) then return function() end end
    end })
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
function F:SetScript(k, fn) self.scripts[k] = fn end
function F:HookScript(k, fn) self.scripts[k] = self.scripts[k] or fn end
function F:GetScript(k) return self.scripts[k] end
function F:RegisterEvent(e) self.events[e] = true end
function F:Show() self.shown = true end
function F:Hide() self.shown = false end
function F:SetShown(v) self.shown = not not v end
function F:IsShown() return self.shown end
function F:IsVisible() return self.shown end
function F:SetEnabled(v) self.enabled = not not v end
function F:Enable() self.enabled = true end
function F:Disable() self.enabled = false end
function F:IsEnabled() return self.enabled end
function F:SetText(t) self.text = t end
function F:GetText() return self.text end
function F:GetHeight() return self.h end
function F:GetWidth() return self.w end
function F:SetHeight(h) self.h = h end
function F:SetWidth(w) self.w = w end
function F:SetSize(w, h) self.w, self.h = w, h end
function F:GetValue() return 0 end
function F:GetFrameLevel() return 1 end
function F:CreateTexture(name) return Frame("Texture", name, self) end
function F:CreateFontString(name) return Frame("FontString", name, self) end
function F:GetParent() return self.parent end
function F:GetName() return self.name end
function F:GetFont() return "font", 12, "" end
function F:GetStringWidth() return 50 end
function F:GetMinMaxValues() return 0, 0 end
CreateFrame = function(kind, name, parent) return Frame(kind, name, parent) end
UIParent = Frame("Frame", "UIParent")
FriendsFrame = Frame("Frame", "FriendsFrame")
StaticPopupDialogs, SlashCmdList = {}, {}
C_Timer = { After = function() end }
hooksecurefunc = function() end
ClearOverrideBindings, SetOverrideBindingClick, GetBindingKey = function() end, function() end, function() end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
format = string.format
local combat = false
InCombatLockdown = function() return combat end
GetTime = function() return 100 end

-- Classic helpers from other files: row menus are recorded, the rest do nothing.
local menus = {}
local modules = {}
setmetatable(ns, { __index = function(_, k)
    if type(k) == "string" and k:match("^%u") then return function() return Frame("Frame") end end
end })
ns.ADDON = "EraUI"
ns.RegisterModule = function(name, m) modules[name] = m end
ns.ShowPanel = function() return true end
ns.PanelButton = function(parent, label) local b = Frame("Button", nil, parent); b.label = label; return b end
ns.RowMenu = function(items)
    local menu = { items = items }
    function menu:Follow() end
    function menu:Open(entry) self.opened = entry end
    menus[#menus + 1] = menu
    return menu
end

-- The real guild roster: you and a guildmate, both online.
IsInGuild = function() return true end
GetNumGuildMembers = function() return 2, 2 end
GetGuildRosterShowOffline = function() return true end
local ROSTER = {
    { "Zriel Gustbellow", "Officer", 1, 60, "Druid", "Moonglade", "", "", true, 0, "DRUID", 0, 0, false, false, 0, "Player-4-0001" },
    { "Coww Stagkiller", "Member", 2, 60, "Hunter", "Ironforge", "", "", true, 0, "HUNTER", 0, 0, false, false, 0, "Player-4-0002" },
}
GetGuildRosterInfo = function(i) return unpack(ROSTER[i]) end
local may = true
CanGuildPromote = function() return may end
CanGuildDemote = function() return may end
CanGuildRemove = function() return may end
IsGuildLeader = function() return may end
CanEditPublicNote = function() return false end
local loaded = {}
C_AddOns = { LoadAddOn = function(name) loaded[#loaded + 1] = name end }

local before = #frames
assert(loadfile("Classic/Guild.lua"))("EraUI", E)
local bridgeWatch
for i = before + 1, #frames do
    if frames[i].events.PLAYER_REGEN_DISABLED and frames[i].scripts.OnUpdate then bridgeWatch = frames[i] end
end
assert(bridgeWatch, "the notes bridge watcher is found")
modules.guildRoster.apply()
Equal(ns.OpenGuildRoster(), true, "the roster opens")
local rows = {}
for _, f in ipairs(frames) do
    if f.scripts.OnDoubleClick and f.entry and f.entry.index then rows[f.entry.name] = f end
end
local mine, theirs = rows["Zriel Gustbellow"], rows["Coww Stagkiller"]
assert(mine and theirs, "both roster lines are drawn")
Equal(ns.GuildIsMe(mine.entry), true, "your own roster line is you")
Equal(ns.GuildIsMe(theirs.entry), false, "a guildmate's isn't")
Equal(ns.GuildIsMe(nil), false, "no line isn't you")

-- Right-click menu: nothing to do to yourself.
mine.scripts.OnClick(mine, "RightButton")
local menu = menus[#menus]
assert(menu and menu.opened == mine.entry, "the menu opens on your line")
local function Offered(entry)
    local out = {}
    for _, item in ipairs(menu.items) do
        if item[3] == nil or item[3](entry) then out[#out + 1] = item[1] end
    end
    return table.concat(out, ",")
end
Equal(Offered(mine.entry), "", "no whisper, invite, add friend, promote, demote or remove on yourself")
Equal(Offered(theirs.entry), "Whisper,Invite,Add Friend,Promote,Demote,Remove", "all of them on a guildmate")

-- Player Status popout.
local out = _G.EraUIClassicGuildPanel.popout
mine.scripts.OnClick(mine, "LeftButton")
Equal(out:IsShown(), true, "a left click opens the popout")
Equal(out.title:GetText(), "Zriel Gustbellow", "on your line")
Equal(out.promote:IsEnabled(), false, "you can't promote yourself")
Equal(out.demote:IsEnabled(), false, "or demote yourself")
Equal(out.remove:IsEnabled(), false, "or remove yourself")
Equal(out.invite:IsEnabled(), false, "or invite yourself")
Equal(out.guildmaster:IsEnabled(), false, "or hand yourself Guild Master")
Equal(out.noteBox.mayEdit, true, "but you may write your own public note")
theirs.scripts.OnClick(theirs, "LeftButton")
Equal(out.title:GetText(), "Coww Stagkiller", "a guildmate's line")
Equal(out.promote:IsEnabled() and out.demote:IsEnabled() and out.remove:IsEnabled(), true, "rank and remove work on them")
Equal(out.invite:IsEnabled() and out.guildmaster:IsEnabled(), true, "and invite and Guild Master")
Equal(out.noteBox.mayEdit, false, "their public note needs the guild's permission")

-- The notes bridge wakes the game's guild window only when a note may be written.
loaded = {}
bridgeWatch.scripts.OnUpdate(bridgeWatch, 1)
Equal(#loaded, 0, "not for a guildmate's note without permission")
mine.scripts.OnClick(mine, "LeftButton")
loaded = {}
bridgeWatch.scripts.OnUpdate(bridgeWatch, 1)
Equal(loaded[1], "Blizzard_Communities", "but for your own")

-- Without a GUID from the game the whole name still finds you.
ROSTER[1][17] = nil
myGuid = nil
_G.EraUIClassicGuildPanel.popout:Show()
ns.RefreshGuildRoster()
Equal(mine.entry.name .. "|" .. tostring(mine.entry.guid), "Zriel Gustbellow|nil", "your line, now without a GUID")
mine.scripts.OnClick(mine, "LeftButton")
Equal(out.remove:IsEnabled(), false, "no GUID: your line is still you")
Equal(out.noteBox.mayEdit, true, "and your note still yours")
theirs.scripts.OnClick(theirs, "LeftButton")
Equal(out.remove:IsEnabled(), true, "and a guildmate still isn't")
myGuid = "Player-4-0001"

-- The real /who list.
local WHO = {
    { fullName = "Coww Stagkiller", fullGuildName = "", area = "Ironforge", level = 60, classStr = "Hunter", filename = "HUNTER", raceStr = "Dwarf" },
    { fullName = "Zriel Gustbellow", fullGuildName = "", area = "Moonglade", level = 60, classStr = "Druid", filename = "DRUID", raceStr = "Night Elf" },
}
C_FriendList = {
    GetNumWhoResults = function() return #WHO, #WHO end,
    GetWhoInfo = function(i) return WHO[i] end,
}
before = #frames
assert(loadfile("Classic/Social.lua"))("EraUI", E)
modules.whoList.apply()
Equal(ns.OpenWhoList(), true, "the /who list opens")
local whoRows = {}
for i = before + 1, #frames do
    local f = frames[i]
    if f.scripts.OnDoubleClick and f.entry then whoRows[f.entry.name] = f end
end
local meWho, themWho = whoRows["Zriel Gustbellow"], whoRows["Coww Stagkiller"]
assert(meWho and themWho, "both /who lines are drawn")
local menusBefore = #menus
meWho.scripts.OnClick(meWho, "RightButton")
Equal(#menus, menusBefore, "no menu on your own /who line")
themWho.scripts.OnClick(themWho, "RightButton")
Equal(menus[#menus].opened, themWho.entry, "someone else's /who line gets the menu")

-- Turning EraUI off names this character the way the game's AddOns list does.
local asked, disabled, reloaded
C_AddOns = {
    GetAddOnEnableState = function(addon, who) asked = addon .. "|" .. tostring(who); return 0 end,
    DisableAddOn = function(addon, who) disabled = addon .. "|" .. tostring(who) end,
}
C_UI = { Reload = function() reloaded = true end }
assert(loadfile("Classic/Options.lua"))("EraUI", E)
Equal(ns.BeingTurnedOff(), true, "turned off for this character")
Equal(asked, "EraUI|Player-4-0001", "asked by GUID, as the AddOns list does")
ns.TurnOffCleanly()
Equal(disabled, "EraUI|Player-4-0001", "and switched off by GUID")
Equal(reloaded, true, "then reloads")
myGuid = nil
ns.BeingTurnedOff()
Equal(asked, "EraUI|Zriel Gustbellow", "no GUID: the whole name, never the first name alone")
myGuid = secret
ns.TurnOffCleanly()
Equal(disabled, "EraUI|Zriel Gustbellow", "a hidden GUID is never passed on")
myGuid = "Player-4-0001"

print("Player name checks passed: " .. checks .. " assertions.")
