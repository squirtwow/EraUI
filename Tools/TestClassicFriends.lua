-- The friends key on Forever with the game's newer social window switched on
-- (C_SocialUI.IsSystemEnabled()). Runs the real Classic/Social.lua on a mock
-- of both windows: Forever's Camelot FriendsFrame code (ToggleFriendsFrame and
-- the other ways in, FriendsFrame_OnShow hiding its tabs, the sub-tabs),
-- SocialUIControl and SocialUIFrame (deferred tab, last tab remembered, side
-- windows), the panel manager (its show and hide run as the game's; an
-- addon's in a fight is refused), and taint on the windows' own state (written
-- by the game's code run as EraUI's, it makes the game's later reads run as
-- EraUI's too). Checks: Friends & Guild on -> the classic Friends List opens
-- and the same key closes it; Raid, Quick Join and Recruit A Friend stay in the
-- newer window; a request in a fight keeps the game's window and switches after
-- it; off (from login or later, or the newer window switched off) -> the
-- game's own behaviour; no key written on the game's frames, none of the
-- game's code run as EraUI's but the ignore list's show, so its own Raid and
-- Quick Join still open in a fight; no game function replaced, no key binding.
-- Run with: fengari Tools/TestClassicFriends.lua
local checks = 0
unpack = table.unpack or unpack
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

-- Time, timers, combat and who is running: the game's own code (a key press,
-- a binding) runs "secure"; hooks, timers and events of an addon don't.
local now = 100
GetTime = function() return now end
local combat = false
InCombatLockdown = function() return combat end
local secure = false
local function AsAddon(fn, ...)
    local was = secure
    secure = false
    fn(...)
    secure = was
end
-- Taint, as the game tracks it, on the state the two windows keep (the page
-- the newer window shows and remembers, its deferred request, the friends
-- list's selected tab): a write while an addon's code runs taints that key,
-- and the game's own code that reads it later runs as the addon from there to
-- the end of that key press or event. Its own panel manager then refuses a
-- window in a fight, as on Forever. Every tainted write is listed.
local taintedKeys, taintedWrites = {}, {}
local function GameRead(key) if taintedKeys[key] then secure = false end end
local function GameWrite(key)
    if secure then taintedKeys[key] = nil return end
    taintedKeys[key] = true
    taintedWrites[#taintedWrites + 1] = key
end
-- The panel manager hands a show or hide to a forbidden frame of the game's,
-- so the window's own OnShow and OnHide run as the game's whoever asked.
local function Dispatch(fn)
    local was = secure
    secure = true
    fn()
    secure = was
end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function NextFrame()
    now = now + 1
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do AsAddon(fn) end
end

-- Writes on the game's frames from Classic/Social.lua are recorded.
local writes = {}
local function WatchWrites(name, k)
    local info = debug.getinfo(3, "S")
    local src = info and info.source or ""
    if src:find("Social.lua", 1, true) then writes[#writes + 1] = name .. "." .. tostring(k) end
end

-- A frame mock: named frames land in _G, unknown verbs do nothing.
local frames = {}
local F = {}
local VERBS = { "Set", "Enable", "Disable", "Register", "Unregister", "Hook", "Clear", "Create", "Get", "Is",
    "Start", "Stop", "Raise", "Lower", "Lock", "Unlock", "Add", "Remove", "Update", "Play", "Adjust", "Scroll" }
local function Verb(k)
    for _, v in ipairs(VERBS) do
        local rest = k:sub(#v + 1, #v + 1)
        if k:sub(1, #v) == v and (rest == "" or rest:match("%u")) then return true end
    end
end
local function Frame(kind, name, parent, blizzard)
    local store = { kind = kind, name = name, parent = parent, shown = not blizzard, scripts = {}, hooks = {},
        events = {}, enabled = true, h = 400, w = 300, blizzard = blizzard }
    local f = setmetatable({}, {
        __index = function(self, k)
            local v = store[k]
            if v ~= nil then return v end
            if F[k] then return F[k] end
            if type(k) ~= "string" then return nil end
            if k:match("^Get.*Texture$") then
                return function()
                    store[k .. "_"] = store[k .. "_"] or Frame("Texture", nil, self)
                    return store[k .. "_"]
                end
            end
            if Verb(k) then return function() end end
        end,
        __newindex = function(_, k, v)
            if store.blizzard then WatchWrites(store.name or "?", k) end
            store[k] = v
        end,
    })
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
function F:Fire(k, ...)
    -- An addon's own frame runs its scripts as the addon, even on a key press.
    if self.scripts[k] then
        if self.blizzard then self.scripts[k](self, ...) else AsAddon(self.scripts[k], self, ...) end
    end
    for _, hook in ipairs(self.hooks[k] or {}) do AsAddon(hook, self, ...) end
end
function F:SetScript(k, fn) self.scripts[k] = fn end
function F:HookScript(k, fn)
    self.hooks[k] = self.hooks[k] or {}
    table.insert(self.hooks[k], fn)
end
function F:GetScript(k) return self.scripts[k] end
function F:RegisterEvent(e) self.events[e] = true end
local combatTouches = 0
local function Touch(self)
    if self.blizzard and combat and not secure then combatTouches = combatTouches + 1 end
end
function F:Show()
    if self.shown then return end
    Touch(self)
    self.shown = true
    self:Fire("OnShow")
end
function F:Hide()
    if not self.shown then return end
    Touch(self)
    self.shown = false
    self:Fire("OnHide")
end
function F:SetShown(v) if v then self:Show() else self:Hide() end end
function F:IsShown() return self.shown end
function F:IsVisible() return self.shown and (self.parent == nil or self.parent:IsVisible()) end
function F:Click(button) self:Fire("OnClick", button or "LeftButton") end
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
function F:GetNumPoints() return 1 end
function F:CreateTexture(name) return Frame("Texture", name, self) end
function F:CreateFontString(name) return Frame("FontString", name, self) end
function F:GetParent() return self.parent end
function F:GetName() return self.name end
function F:GetFont() return "font", 12, "" end
function F:GetStringWidth() return 50 end
function F:GetMinMaxValues() return 0, 0 end
CreateFrame = function(kind, name, parent) return Frame(kind, name, parent) end
local function Blizzard(kind, name, parent) return Frame(kind, name, parent, true) end
local function Fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then AsAddon(f.scripts.OnEvent, f, event, ...) end
    end
end

-- Hooks: secure post-hooks, as the game's. Every wrapper is remembered, so a
-- game function changed any other way shows up.
local wrappers = {}
hooksecurefunc = function(a, b, c)
    local tbl, key, hook = _G, a, b
    if type(a) == "table" then tbl, key, hook = a, b, c end
    local original = tbl[key]
    assert(type(original) == "function", "hooksecurefunc on a missing function: " .. tostring(key))
    local wrapper = function(...)
        local out = table.pack(original(...))
        AsAddon(hook, ...)
        return table.unpack(out, 1, out.n)
    end
    wrappers[wrapper] = true
    tbl[key] = wrapper
end
local bindings = 0
SetOverrideBinding = function() bindings = bindings + 1 end
SetOverrideBindingClick = function() bindings = bindings + 1 end
ClearOverrideBindings = function() bindings = bindings + 1 end
SetBinding = function() bindings = bindings + 1 end

UIParent = Frame("Frame", "UIParent")
StaticPopupDialogs, SlashCmdList, UISpecialFrames = {}, {}, {}
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
format = string.format
SOUNDKIT = {}
PlaySound = function() end

-- The panel manager: left and center slots; the friends list is pushable 0
-- and the newer window 1, so it opens beside the list. Crowded: it takes the
-- list's place instead, as with other windows open. An addon's show or hide in
-- a fight is refused, as on Forever.
local slots = { left = nil, center = nil }
local pushable = {}
local blocked = {}
local crowded = false
function ShowUIPanel(frame)
    if not frame or frame:IsShown() then return end
    if combat and not secure then blocked[#blocked + 1] = "ShowUIPanel " .. frame:GetName() return end
    Dispatch(function()
        if not slots.left then
            slots.left = frame
        elseif crowded or (pushable[slots.left] == 0 and pushable[frame] == 0) then
            slots.left:Hide()
            slots.left = frame
        else
            if slots.center then slots.center:Hide() end
            slots.center = frame
        end
        frame:Show()
    end)
end
function HideUIPanel(frame)
    if not frame or not frame:IsShown() then return end
    if combat and not secure then blocked[#blocked + 1] = "HideUIPanel " .. frame:GetName() return end
    Dispatch(function()
        if slots.left == frame then
            slots.left, slots.center = slots.center, nil
        elseif slots.center == frame then
            slots.center = nil
        end
        frame:Hide()
    end)
end
function ToggleUIPanel(frame)
    if frame:IsShown() then HideUIPanel(frame) else ShowUIPanel(frame) end
end

-- Classic/Skin.lua's ns.ShowPanel and ns.HidePanel, as they are.
local ns = {}
local settings = { enabled = true }
local E = { Classic = ns }
function E:GetSetting(key) return settings[key] end
function E:IsPlayer() return false end
function ns.ShowPanel(frame)
    if not frame or frame:IsShown() then return true end
    if not InCombatLockdown() then
        if ShowUIPanel then ShowUIPanel(frame) else frame:Show() end
        return true
    end
    if frame.IsProtected and frame:IsProtected() then return false end
    frame:Show()
    return true
end
function ns.HidePanel(frame)
    if not frame or not frame:IsShown() then return true end
    if not InCombatLockdown() then
        if HideUIPanel then HideUIPanel(frame) else frame:Hide() end
        return true
    end
    if frame.IsProtected and frame:IsProtected() then return false end
    frame:Hide()
    return true
end

-- C_SocialUI and the newer window (Blizzard_SocialUIShared, Blizzard_SocialUI).
local systemOn = true
C_SocialUI = { IsSystemEnabled = function() return systemOn end }
SocialUITabType = { Friends = 1, FriendRequests = 2, QuickJoin = 3, RaidList = 4, RecruitAFriend = 5, RecentAllies = 6 }
SocialUISideWindowType = { BattleNetBroadcastFrame = 1, BattleNetUnavailableNoticeFrame = 2, IgnoreListFrame = 3, RaidInfoFrame = 4 }
local T = SocialUITabType
local social = Blizzard("Frame", "SocialUIFrame", UIParent)
local socialState = { selected = nil, last = nil, deferred = nil, deferredSide = nil, side = nil }
local available = { [T.Friends] = true, [T.FriendRequests] = true, [T.QuickJoin] = true, [T.RaidList] = true,
    [T.RecruitAFriend] = true }
pushable[social] = 1
function social:GetSelectedTab() GameRead("SocialUIFrame.selectedTab") return socialState.selected end
function social:GetActiveSideWindowType() GameRead("SocialUIFrame.activeSideWindowType") return socialState.side end
function social:GetDataForAvailableTab(tabType) return tabType and available[tabType] and {} or nil end
-- As the game's SelectTab: it reads the page it shows before it writes it.
function social:SelectTab(tabType)
    if tabType and not available[tabType] then return end
    GameRead("SocialUIFrame.selectedTab")
    socialState.selected = tabType
    GameWrite("SocialUIFrame.selectedTab")
    if tabType then
        socialState.last = tabType
        GameWrite("SocialUIFrame.lastSelectedTabType")
    end
end
local function SetSide(side)
    socialState.side = side
    GameWrite("SocialUIFrame.activeSideWindowType")
end
-- Reset on show: the deferred page, else the last one, and a deferred side window.
local socialShows = 0
social:SetScript("OnShow", function(self)
    socialShows = socialShows + 1
    GameRead("SocialUIFrame.deferredOpenTabType")
    local deferred = socialState.deferred
    socialState.deferred = nil
    GameWrite("SocialUIFrame.deferredOpenTabType")
    if deferred and available[deferred] then
        self:SelectTab(deferred)
    else
        GameRead("SocialUIFrame.lastSelectedTabType")
        self:SelectTab(socialState.last or T.Friends)
    end
    SetSide(socialState.deferredSide)
    socialState.deferredSide = nil
end)
social:SetScript("OnHide", function(self)
    self:SelectTab(nil)
    SetSide(nil)
end)
local function ToggleSocialUIReal()
    if C_SocialUI.IsSystemEnabled() and SocialUIFrame ~= nil then SocialUIControl.Toggle() end
end
function social:TriggerEvent(event, tabType, side)
    if self:IsShown() then
        self:SelectTab(tabType)
        if side then SetSide(side) end
        return
    end
    socialState.deferred, socialState.deferredSide = tabType, side
    GameWrite("SocialUIFrame.deferredOpenTabType")
    ToggleSocialUI()
end
local control = setmetatable({}, { __newindex = function(t, k, v) WatchWrites("SocialUIControl", k) rawset(t, k, v) end })
SocialUIControl = control
local controlFns = {}
function controlFns.IsEnabled() return C_SocialUI.IsSystemEnabled() and SocialUIFrame ~= nil end
function controlFns.Toggle() ToggleUIPanel(SocialUIFrame) end
local function ShouldClose(tabType, already)
    if not SocialUIFrame:IsShown() then return false end
    if already then return true end
    return SocialUIFrame:GetDataForAvailableTab(tabType) == nil
end
function controlFns.ToggleToTab(tabType)
    if ShouldClose(tabType, SocialUIFrame:GetSelectedTab() == tabType) then SocialUIControl.Toggle()
    else SocialUIFrame:TriggerEvent("OpenToTabRequested", tabType) end
end
function controlFns.OpenToTab(tabType) SocialUIFrame:TriggerEvent("OpenToTabRequested", tabType) end
function controlFns.ToggleToTabAndSideWindow(tabType, side)
    local already = SocialUIFrame:GetSelectedTab() == tabType and SocialUIFrame:GetActiveSideWindowType() == side
    if ShouldClose(tabType, already) then SocialUIControl.Toggle()
    else SocialUIFrame:TriggerEvent("OpenToTabAndSideWindowRequested", tabType, side) end
end
for k, fn in pairs(controlFns) do rawset(control, k, fn) end
ToggleSocialUI = ToggleSocialUIReal

-- The Camelot FriendsFrame (Blizzard_FriendsFrame/Camelot/FriendsFrame.lua).
FRIEND_TAB_FRIENDS, FRIEND_TAB_RAID, FRIEND_TAB_QUICK_JOIN = 1, 2, 3
local friends = Blizzard("Frame", "FriendsFrame", UIParent)
pushable[friends] = 0
local friendsStore = { selectedTab = 1, title = nil }
Blizzard("FontString", "FriendsFrameTitleText", friends)
local list = Blizzard("Frame", "FriendsListFrame", friends)
local raidFrame = Blizzard("Frame", "RaidFrame", friends)
local quickJoin = Blizzard("Frame", "QuickJoinFrame", friends)
local rafFrame = Blizzard("Frame", "RecruitAFriendFrame", friends)
local alliesFrame = Blizzard("Frame", "RecentAlliesFrame", friends)
for _, f in ipairs({ list, raidFrame, quickJoin, rafFrame, alliesFrame }) do f.shown = false end
-- (the mock's own key on the game's frame; written by the test, not by EraUI)
local ignoreList = Blizzard("Frame", nil, friends)
friends.IgnoreListWindow = ignoreList
-- Its OnShow and OnHide (FriendsIgnoreListMixin) tell the game's event
-- registry and refill the list: display only, listed apart.
ignoreList:SetScript("OnShow", function() GameWrite("display:IgnoreListWindow.OnShow") end)
ignoreList:SetScript("OnHide", function() GameWrite("display:IgnoreListWindow.OnHide") end)
local header = Blizzard("Frame", "FriendsTabHeader", friends)
header.friendsTabID, header.recentAlliesTabID, header.recruitAFriendTabID = 1, 2, 3
local headerTab = 1
local function SetHeaderTab(id)
    headerTab = id
    GameWrite("FriendsTabHeader.tab")
end
function header:GetTab() GameRead("FriendsTabHeader.tab") return headerTab end
function header:SelectTab(id) SetHeaderTab(id) FriendsFrame_Update() end
-- PanelTemplates_SetTab and PanelTemplates_GetSelectedTab on the friends list.
local function SetFriendsTab(id)
    friendsStore.selectedTab = id
    GameWrite("FriendsFrame.selectedTab")
end
local function FriendsTab()
    GameRead("FriendsFrame.selectedTab")
    return friendsStore.selectedTab
end
local tab1 = Blizzard("Button", "FriendsFrameTab1", friends)
local tab3 = Blizzard("Button", "FriendsFrameTab3", friends)
local tab4 = Blizzard("Button", "FriendsFrameTab4", friends)
tab1.shown, tab3.shown, tab4.shown = true, true, true
local tabIDs = { [tab1] = 1, [tab3] = 2, [tab4] = 3 }
local function ValidSubFrames()
    if C_SocialUI.IsSystemEnabled() then return { "FriendsListFrame" } end
    return { "FriendsListFrame", "QuickJoinFrame", "RecentAlliesFrame", "RecruitAFriendFrame", "RaidFrame" }
end
function FriendsFrame_ShowSubFrame(frameName)
    for _, value in ipairs(ValidSubFrames()) do
        if value == frameName then _G[value]:Show() else _G[value]:Hide() end
    end
end
function FriendsFrame_Update()
    local selected = FriendsTab()
    header:SetShown(selected == 1)
    if selected == 1 then
        GameRead("FriendsTabHeader.tab")
        if headerTab == 1 then
            friendsStore.title = "Friends List"
            FriendsFrame_ShowSubFrame("FriendsListFrame")
        elseif headerTab == 2 then
            friendsStore.title = "Recent Allies"
            FriendsFrame_ShowSubFrame("RecentAlliesFrame")
        else
            friendsStore.title = "Recruit A Friend"
            FriendsFrame_ShowSubFrame("RecruitAFriendFrame")
        end
    elseif selected == 2 then
        friendsStore.title = "Raid"
        FriendsFrame_ShowSubFrame("RaidFrame")
    else
        friendsStore.title = "Quick Join"
        FriendsFrame_ShowSubFrame("QuickJoinFrame")
    end
end
local function UpdateTabHiddenStates()
    local on = not C_SocialUI.IsSystemEnabled()
    tab1:SetShown(on)
    tab3:SetShown(on)
    tab4:SetShown(on)
end
-- It also registers event registry callbacks and closures of its own.
function FriendsFrame_OnShow()
    GameWrite("FriendsFrame.OnShow")
    UpdateTabHiddenStates()
    FriendsFrame_Update()
    header:SelectTab(header.friendsTabID)
end
local onShow = FriendsFrame_OnShow -- XML binds the function itself
friends:SetScript("OnShow", function(self) onShow(self) end)
friends:SetScript("OnHide", function()
    for _, value in ipairs(ValidSubFrames()) do _G[value]:Hide() end
    ignoreList:Hide()
end)
-- Tab looks (PanelTemplates_SelectTab and DeselectTab): cosmetic, kept here.
local tabLook = {}
function PanelTemplates_SelectTab(tab) tabLook[tab] = "selected" end
function PanelTemplates_DeselectTab(tab) tabLook[tab] = "deselected" end
for tab, id in pairs(tabIDs) do
    tab:SetScript("OnClick", function()
        SetFriendsTab(id)
        for other, otherID in pairs(tabIDs) do
            if otherID == id then PanelTemplates_SelectTab(other) else PanelTemplates_DeselectTab(other) end
        end
        FriendsFrame_OnShow(FriendsFrame)
    end)
end
local function SocialUIReplacing() return SocialUIControl and SocialUIControl.IsEnabled() end
local FRIEND_TAB_TO_SOCIAL = { [1] = T.Friends, [2] = T.RaidList, [3] = T.QuickJoin }
function ToggleFriendsFrame(requestedTab)
    if SocialUIReplacing() then
        local socialTab = requestedTab and FRIEND_TAB_TO_SOCIAL[requestedTab]
        if socialTab then SocialUIControl.ToggleToTab(socialTab)
        elseif not requestedTab then SocialUIControl.Toggle() end
        return
    end
    if not requestedTab then
        if FriendsFrame:IsShown() then HideUIPanel(FriendsFrame) else ShowUIPanel(FriendsFrame) end
    else
        if requestedTab == FriendsTab() and FriendsFrame:IsShown() then HideUIPanel(FriendsFrame) return end
        SetFriendsTab(requestedTab)
        if FriendsFrame:IsShown() then FriendsFrame_OnShow(FriendsFrame) else ShowUIPanel(FriendsFrame) end
    end
end
function ToggleRaidFrame() ToggleFriendsFrame(FRIEND_TAB_RAID) end
function OpenFriendsFrame(tab)
    if SocialUIReplacing() then
        SocialUIControl.OpenToTab(tab and FRIEND_TAB_TO_SOCIAL[tab] or T.Friends)
        return
    end
    if tab then SetFriendsTab(tab) end
    if FriendsFrame:IsShown() then FriendsFrame_OnShow(FriendsFrame) else ShowUIPanel(FriendsFrame) end
end
local function ToggleFriendsSubPanel(index)
    if FriendsFrame:IsShown() and FriendsTab() == 1 and header:GetTab() == index then
        HideUIPanel(FriendsFrame)
    else
        SetFriendsTab(1)
        header:SelectTab(index)
        ShowUIPanel(FriendsFrame)
    end
end
function ToggleFriendsPanel()
    if SocialUIReplacing() then SocialUIControl.ToggleToTab(T.Friends) return end
    ToggleFriendsSubPanel(1)
end
function ToggleRAFPanel()
    if SocialUIReplacing() then SocialUIControl.ToggleToTab(T.RecruitAFriend) return end
    ToggleFriendsSubPanel(3)
end
function ToggleQuickJoinPanel()
    if SocialUIReplacing() then SocialUIControl.ToggleToTab(T.QuickJoin) return end
    ToggleFriendsFrame(FRIEND_TAB_QUICK_JOIN)
end
function ToggleIgnorePanel()
    if SocialUIReplacing() then
        SocialUIControl.ToggleToTabAndSideWindow(T.Friends, SocialUISideWindowType.IgnoreListFrame)
        return
    end
    local already = FriendsFrame:IsShown()
    if already and not ignoreList:IsShown() then ignoreList:Show() return end
    if already then HideUIPanel(FriendsFrame) else ShowUIPanel(FriendsFrame) end
    ignoreList:SetShown(FriendsFrame:IsShown())
end
-- A press of a key or a slash command: the game's own code, secure, each in
-- a frame of its own (the timers of the frame before have run).
local function Press(fn, ...)
    NextFrame()
    local was = secure
    secure = true
    fn(...)
    secure = was
end
-- A sub-tab at the top of the friends list (FriendsTabMixin:OnClick).
local function SubTab(id) Press(function() SetHeaderTab(id) FriendsFrame_Update() end) end

-- What the game had before EraUI loads, to check nothing is replaced.
local WATCHED = { "ToggleFriendsFrame", "ToggleFriendsPanel", "ToggleIgnorePanel", "OpenFriendsFrame", "ToggleRaidFrame",
    "ToggleRAFPanel", "ToggleQuickJoinPanel", "ToggleSocialUI", "FriendsFrame_Update", "FriendsFrame_ShowSubFrame",
    "FriendsFrame_OnShow", "ShowUIPanel", "HideUIPanel", "ToggleUIPanel" }
local before = {}
for _, name in ipairs(WATCHED) do before[name] = _G[name] end
local beforeControl = {}
for k, fn in pairs(controlFns) do beforeControl[k] = fn end

-- Classic helpers from other files do nothing; a module is captured.
local modules = {}
setmetatable(ns, { __index = function(_, k)
    if type(k) == "string" and k:match("^%u") then return function() return Frame("Frame") end end
end })
ns.db = {}
ns.RegisterModule = function(name, m) modules[name] = m end
ns.PanelButton = function(parent, label) local b = Frame("Button", nil, parent); b.label = label; return b end
ns.RowMenu = function() return { Follow = function() end, Open = function() end, IsShown = function() return false end } end
C_FriendList = { GetNumWhoResults = function() return 0, 0 end, GetWhoInfo = function() end, SetWhoToUi = function() end }

-- Loaded before the newer window's addons: nothing to hook yet, then they arrive.
SocialUIFrame, SocialUIControl, ToggleSocialUI = nil, nil, nil
assert(loadfile("Classic/Social.lua"))("EraUI", E)
local who = modules.whoList
assert(who, "the who list module registers")

-- 0. Friends & Guild off from login (the module never applied): with the newer
-- window loaded too, nothing is hooked and the game's own window opens.
SocialUIFrame, SocialUIControl, ToggleSocialUI = social, control, ToggleSocialUIReal
Fire("ADDON_LOADED", "Blizzard_SocialUI")
local touched = {}
for _, name in ipairs(WATCHED) do if _G[name] ~= before[name] then touched[#touched + 1] = name end end
for k, fn in pairs(beforeControl) do if rawget(control, k) ~= fn then touched[#touched + 1] = "SocialUIControl." .. k end end
if social.hooks.OnShow then touched[#touched + 1] = "SocialUIFrame OnShow" end
if friends.hooks.OnHide then touched[#touched + 1] = "FriendsFrame OnHide" end
Equal(table.concat(touched, ", "), "", "option off from login: nothing of the game's is hooked")
Press(ToggleFriendsFrame)
NextFrame()
Equal(tostring(FriendsFrame:IsShown()) .. "|" .. tostring(SocialUIFrame:IsShown()), "false|true",
    "option off from login: the friends key opens the newer window")
Press(ToggleFriendsFrame)
Equal(SocialUIFrame:IsShown(), false, "and closes it")
socialShows, socialState.last = 0, nil
SocialUIFrame, SocialUIControl, ToggleSocialUI = nil, nil, nil

who.apply()
Press(ToggleFriendsFrame)
Equal(FriendsFrame:IsShown(), true, "without the newer window the game's own friends list opens")
Press(ToggleFriendsFrame)
Equal(FriendsFrame:IsShown(), false, "and closes")
SocialUIFrame, SocialUIControl, ToggleSocialUI = social, control, ToggleSocialUIReal
Fire("ADDON_LOADED", "Blizzard_SocialUI")

local function State()
    return (FriendsFrame:IsShown() and "classic" or "-") .. "|" .. (SocialUIFrame:IsShown() and "new" or "-")
end

-- 1. The friends key opens the classic Friends List and closes it again.
Press(ToggleFriendsFrame)
Equal(State(), "classic|-", "the friends key opens the classic window, not the newer one")
Equal(socialShows, 1, "the game opened its window, and it was closed again at once")
Equal(list:IsShown() and friendsStore.title, "Friends List", "on its Friends list")
Equal(slots.left, FriendsFrame, "in the window's usual place")
Equal(tab1:IsShown(), true, "its Friends tab shows, so Who and Guild lead back")
Equal(tab3:IsShown() or tab4:IsShown(), false, "Raid and Quick Join stay hidden, as the game has them")
NextFrame()
Equal(State(), "classic|-", "nothing changes a frame later")
Press(ToggleFriendsFrame)
Equal(State(), "-|-", "the friends key closes it again")
NextFrame()
Equal(State(), "-|-", "and it stays closed")

-- 2. /friends, the friends tab key and the chat friends button.
Press(ToggleFriendsPanel)
Equal(State(), "classic|-", "/friends opens the classic window")
Press(ToggleFriendsPanel)
Equal(State(), "-|-", "and closes it")
Press(ToggleFriendsFrame, FRIEND_TAB_FRIENDS)
Equal(State(), "classic|-", "the friends tab key opens it")
Press(ToggleFriendsFrame, FRIEND_TAB_FRIENDS)
Equal(State(), "-|-", "and closes it")

-- 3. Raid and Quick Join only exist in the newer window: left to it.
Press(ToggleRaidFrame)
NextFrame()
Equal(State(), "-|new", "Raid opens the newer window")
Equal(SocialUIFrame:GetSelectedTab(), T.RaidList, "on its Raid page")
Press(ToggleRaidFrame)
Equal(State(), "-|-", "and closes it")
Press(ToggleQuickJoinPanel)
NextFrame()
Equal(State() .. "|" .. SocialUIFrame:GetSelectedTab(), "-|new|" .. T.QuickJoin, "Quick Join opens the newer window on its page")
Press(ToggleQuickJoinPanel)
Equal(State(), "-|-", "and closes it")
-- The newer window now remembers Quick Join; the friends key still means friends.
Press(ToggleFriendsFrame)
Equal(State(), "classic|-", "the friends key opens the classic window whatever page the newer one remembers")
Press(ToggleFriendsFrame)
Equal(State(), "-|-", "and closes it")
Press(ToggleRAFPanel)
NextFrame()
Equal(SocialUIFrame:GetSelectedTab(), T.RecruitAFriend, "Recruit A Friend opens the newer window on its page")
Press(ToggleRAFPanel)
Equal(State(), "-|-", "and closes it")

-- 4. /ignore: the classic window with its ignore list.
Press(ToggleIgnorePanel)
Equal(State() .. "|" .. tostring(ignoreList:IsShown()), "classic|-|true", "/ignore opens the classic window and its ignore list")
Press(ToggleIgnorePanel)
Equal(State() .. "|" .. tostring(ignoreList:IsShown()), "-|-|false", "/ignore again closes both")
Press(ToggleFriendsFrame)
Press(ToggleIgnorePanel)
Equal(State() .. "|" .. tostring(ignoreList:IsShown()), "classic|-|true", "with the friends list open, /ignore adds its ignore list")
Press(ToggleFriendsFrame)
Equal(State(), "-|-", "the friends key closes the window")

-- 5. A friend request toast (OpenToTab) and OpenFriendsFrame open, never close.
Press(SocialUIControl.OpenToTab, T.FriendRequests)
Equal(State(), "classic|-", "a friend request toast opens the classic window (requests head its list)")
Press(SocialUIControl.OpenToTab, T.FriendRequests)
Equal(State(), "classic|-", "clicked again with the window open, it stays open")
Press(OpenFriendsFrame)
Equal(State(), "classic|-", "OpenFriendsFrame keeps it open")
Equal(list:IsShown(), true, "on its Friends list")
NextFrame()
Equal(State(), "classic|-", "still a frame later")
Press(ToggleFriendsFrame)
Equal(State(), "-|-", "the friends key closes it")

-- 6. The Who tab still works, and requests come back to the Friends page.
Press(ToggleFriendsFrame)
local whoTab, whoPanel = _G.EraUIClassicWhoTab, _G.EraUIClassicWhoPanel
assert(whoTab and whoPanel, "the Who tab and page exist")
Press(function() whoTab:Click() end)
Equal(whoPanel:IsShown(), true, "the Who tab shows the Who page")
Press(SocialUIControl.OpenToTab, T.FriendRequests)
Equal(State() .. "|" .. tostring(whoPanel:IsShown()) .. "|" .. tostring(list:IsShown()), "classic|-|false|true",
    "a friend request toast on the Who page turns back to the Friends list")
Press(function() whoTab:Click() end)
Press(ToggleIgnorePanel)
Equal(whoPanel:IsShown() and ignoreList:IsShown(), true, "/ignore on the Who page adds the ignore list and keeps the page")
Press(function() tab1:Click() end)
Equal(whoPanel:IsShown() == false and list:IsShown() and tab1:IsShown(), true, "the Friends tab leads back from Who and stays")
Press(ToggleFriendsFrame)
Equal(State(), "-|-", "the friends key closes it from any page")
Press(function() ns.OpenWhoList() end)
Equal(FriendsFrame:IsShown() and whoPanel:IsShown() and tab1:IsShown(), true, "/who opens the Who page with the Friends tab beside it")
Press(ToggleFriendsFrame)
Equal(State(), "-|-", "and the friends key closes it")

-- 7. The newer window takes the classic one's place as it opens (other
-- windows open): the key still closes it.
Press(ToggleFriendsFrame)
crowded = true
Press(ToggleFriendsFrame)
Equal(State(), "-|-", "replaced as the game's window opened, the key still counts as a close")
crowded = false
Press(ToggleFriendsFrame)
Equal(State(), "classic|-", "and opens it next time")
Press(ToggleFriendsFrame)
Press(ToggleIgnorePanel)
crowded = true
Press(ToggleIgnorePanel)
Equal(State() .. "|" .. tostring(ignoreList:IsShown()), "-|-|false", "replaced with its ignore list open, /ignore still closes both")
crowded = false
Press(ToggleFriendsFrame)
Equal(State() .. "|" .. tostring(ignoreList:IsShown()), "classic|-|false", "the friends key after that: the window alone")
Press(ToggleFriendsFrame)

-- 8. The friends list's Recruit A Friend tab (an empty page while the newer
-- window is on) is left as the game has it: EraUI opening the newer window
-- there would run the game's opener as EraUI's (see 15).
Press(ToggleFriendsFrame)
SubTab(header.recruitAFriendTabID)
Equal(rafFrame:IsShown(), false, "the game shows no classic Recruit A Friend page with the newer window on")
NextFrame()
Equal(State() .. "|" .. header:GetTab(), "classic|-|" .. header.recruitAFriendTabID, "the classic window stays on that tab, nothing opened")
SubTab(header.friendsTabID)
Equal(list:IsShown(), true, "its Friends tab leads back to the list")
Press(ToggleFriendsFrame)
Equal(State(), "-|-", "the friends key closes it")
Press(ToggleFriendsFrame)
Equal(State() .. "|" .. header:GetTab(), "classic|-|1", "and opens it on Friends next time")
Press(ToggleFriendsFrame)

-- 9. Another caller of the game's own opener (SocialUIControl): at once.
socialState.last = T.Friends -- the page it remembers
Press(ToggleSocialUI)
Equal(State(), "classic|-", "ToggleSocialUI from anywhere opens the classic window at once")
Press(ToggleSocialUI)
Equal(State(), "-|-", "and closes it")
Press(SocialUIControl.ToggleToTab, T.Friends)
Equal(State(), "classic|-", "a request for the newer window's Friends page: the classic window at once")
Press(SocialUIControl.ToggleToTab, T.Friends)
Equal(State(), "-|-", "and closes it")
Press(SocialUIControl.ToggleToTab, T.QuickJoin)
NextFrame()
Equal(State(), "-|new", "its Quick Join page stays")
Press(SocialUIControl.ToggleToTab, T.QuickJoin)
-- Anything else opening the newer window on its friends page: a frame later.
socialState.last = T.Friends
Press(ToggleUIPanel, SocialUIFrame)
Equal(State(), "-|new", "a direct open shows the newer window this frame")
NextFrame()
Equal(State(), "classic|-", "the classic one a frame later")
Press(ToggleFriendsFrame)
Press(ToggleRaidFrame)
Press(ToggleRaidFrame)
Press(ToggleUIPanel, SocialUIFrame)
NextFrame()
Equal(State() .. "|" .. SocialUIFrame:GetSelectedTab(), "-|new|" .. T.RaidList, "on another page it stays")
Press(ToggleUIPanel, SocialUIFrame)

-- 10. In a fight: the game's window, then the classic one after it.
socialState.last = T.Friends
combat = true
Press(ToggleFriendsFrame)
NextFrame()
Equal(State(), "-|new", "in a fight the friends key keeps the game's window")
Equal(#blocked .. "|" .. combatTouches, "0|0", "no window shown or hidden by EraUI in the fight")
combat = false
Fire("PLAYER_REGEN_ENABLED")
Equal(State(), "classic|-", "after the fight it becomes the classic window")
Press(ToggleFriendsFrame)
Equal(State(), "-|-", "and the key closes it")
combat = true
Press(ToggleFriendsFrame)
Press(function() SocialUIFrame:SelectTab(T.RaidList) end)
combat = false
Fire("PLAYER_REGEN_ENABLED")
Equal(State(), "-|new", "moved to another page in the fight: left alone")
Press(ToggleRaidFrame)
combat = true
Press(ToggleFriendsFrame)
Press(ToggleFriendsFrame)
combat = false
Fire("PLAYER_REGEN_ENABLED")
Equal(State(), "-|-", "closed again in the fight: nothing opens after it")
combat = true
Press(ToggleFriendsFrame)
combat = false
Press(ToggleFriendsFrame) -- the fight ended and the key closed it before the event
Fire("PLAYER_REGEN_ENABLED")
Equal(State(), "-|-", "closed before the fight's end was heard: nothing opens")
-- Open on the Who page, a friend request toast in a fight: the game's window
-- beside it, then the classic one turns to its Friends list.
Press(ToggleFriendsFrame)
Press(function() whoTab:Click() end)
combat = true
Press(SocialUIControl.OpenToTab, T.FriendRequests)
Equal(State(), "classic|new", "a toast in a fight opens the game's window beside the classic one")
combat = false
Fire("PLAYER_REGEN_ENABLED")
Equal(State() .. "|" .. tostring(whoPanel:IsShown()) .. "|" .. tostring(list:IsShown()), "classic|-|false|true",
    "after it: the classic window alone, on its Friends list")
Equal(tabLook[tab1], "selected", "its Friends tab looks chosen again")
Press(ToggleFriendsFrame)
Equal(State(), "-|-", "the friends key closes it")
-- The same on the Guild page (Classic/Guild.lua's page, stood in for here).
local guildPanel = CreateFrame("Frame", "EraUIClassicGuildPanel", FriendsFrame)
local guildHides = 0
ns.HideGuildRoster = function() guildHides = guildHides + 1 guildPanel:Hide() end
Press(ToggleFriendsFrame)
guildPanel:Show()
combat = true
Press(SocialUIControl.OpenToTab, T.FriendRequests)
combat = false
Fire("PLAYER_REGEN_ENABLED")
Equal(State() .. "|" .. tostring(guildPanel:IsShown()) .. "|" .. guildHides, "classic|-|false|1",
    "a toast in a fight on the Guild page: the Friends list after it, through the guild page's own hide")
Press(ToggleFriendsFrame)
guildPanel:Hide()
-- The Recruit A Friend tab in a fight: still left as the game has it after it.
Press(ToggleFriendsFrame)
combat = true
SubTab(header.recruitAFriendTabID)
NextFrame()
combat = false
Fire("PLAYER_REGEN_ENABLED")
Equal(State() .. "|" .. header:GetTab(), "classic|-|" .. header.recruitAFriendTabID, "the Recruit A Friend tab in a fight: nothing changes after it")
Press(ToggleFriendsFrame)
Equal(#blocked .. "|" .. combatTouches, "0|0", "still nothing blocked")

-- 11. EraUI turned off with no reload yet: the game's window.
settings.enabled = false
Press(ToggleFriendsFrame)
NextFrame()
Equal(State(), "-|new", "EraUI off: the newer window stays")
Press(ToggleFriendsFrame)
settings.enabled = true

-- 12. Friends & Guild off: the game's own behaviour, untouched.
socialState.last = T.Friends
who.restore()
Press(ToggleFriendsFrame)
NextFrame()
Equal(State(), "-|new", "Friends & Guild off: the friends key opens the newer window")
Equal(SocialUIFrame:GetSelectedTab(), T.Friends, "on its Friends page")
Press(ToggleFriendsFrame)
Equal(State(), "-|-", "and closes it")
Press(ShowUIPanel, FriendsFrame)
Equal(tab1:IsShown(), false, "the classic window's Friends tab stays as the game left it")
Press(HideUIPanel, FriendsFrame)
Press(ToggleIgnorePanel)
NextFrame()
Equal(State() .. "|" .. tostring(SocialUIFrame:GetActiveSideWindowType()), "-|new|" .. SocialUISideWindowType.IgnoreListFrame,
    "/ignore opens the newer window's ignore list")
Press(ToggleIgnorePanel)
who.apply()

-- 13. The newer window switched off by the game: its own classic window, no hooks acting.
systemOn = false
Press(ToggleFriendsFrame)
Equal(State() .. "|" .. tostring(tab1:IsShown()) .. "|" .. tostring(tab3:IsShown()), "classic|-|true|true",
    "newer window off: the game's own friends list, all its tabs")
Press(ToggleFriendsFrame)
Equal(State(), "-|-", "and the key closes it")
Press(ToggleRaidFrame)
Equal(State() .. "|" .. friendsStore.title, "classic|-|Raid", "Raid in the classic window as the game has it")
Press(ToggleRaidFrame)
Press(ToggleFriendsFrame, FRIEND_TAB_FRIENDS)
SubTab(header.recruitAFriendTabID)
NextFrame()
Equal(State() .. "|" .. tostring(rafFrame:IsShown()), "classic|-|true", "and its own Recruit A Friend page, nothing handed over")
Press(ToggleFriendsFrame)
systemOn = true

-- 14. Nothing written on the game's frames, nothing replaced, no key bound.
local own = {}
for _, w in ipairs(writes) do
    local k = w:match("%.(.+)$")
    -- The who list's marks from before this change: its pads on the bottom
    -- tabs and its "hidden" mark on the friends list's pages.
    if not (k == "fcuiPad" or k == "fcuiWhoHidden") then own[#own + 1] = w end
end
Equal(table.concat(own, ", "), "", "no key written on the game's frames or SocialUIControl")
for _, w in ipairs(writes) do
    assert(not w:find("^SocialUIFrame%.") and not w:find("^FriendsFrame%.") and not w:find("^FriendsTabHeader%.")
        and not w:find("^SocialUIControl%."), "nothing at all on the windows themselves: " .. w)
end
checks = checks + 1
local replaced = {}
for _, name in ipairs(WATCHED) do
    if _G[name] ~= before[name] and not wrappers[_G[name]] then replaced[#replaced + 1] = name end
end
for k, fn in pairs(beforeControl) do
    if rawget(control, k) ~= fn and not wrappers[rawget(control, k)] then replaced[#replaced + 1] = "SocialUIControl." .. k end
end
Equal(table.concat(replaced, ", "), "", "the game's functions only post-hooked, never replaced")
local hooked = 0
for _, name in ipairs(WATCHED) do if _G[name] ~= before[name] then hooked = hooked + 1 end end
Equal(hooked >= 5, true, "the friends ways in are post-hooked")
Equal(bindings, 0, "no key binding changed")
Equal(#blocked .. "|" .. combatTouches, "0|0", "no window shown or hidden by EraUI in a fight")

-- 15. Nothing of the game's own runs as EraUI's: no click on its tabs, no call
-- of its openers. The two windows' state (the page the newer window shows and
-- remembers, its deferred request, the friends list's tabs) was only ever
-- written by the game itself, so after all of the above, in a fight, its own
-- Raid and Quick Join opens still go through.
local hard, shown = {}, {}
for _, key in ipairs(taintedWrites) do
    if key:find("^display:") then shown[key] = true else hard[#hard + 1] = key end
end
Equal(table.concat(hard, ", "), "", "the game's window state is never written by its code run as EraUI's")
-- The one display-only exception: /ignore shows the classic ignore list.
for key in pairs(shown) do
    assert(key == "display:IgnoreListWindow.OnShow", "only the ignore list's own show runs as EraUI's: " .. key)
end
checks = checks + 1
combat = true
Press(ToggleRaidFrame)
Equal(State() .. "|" .. tostring(SocialUIFrame:GetSelectedTab()), "-|new|" .. T.RaidList, "in a fight the Raid key still opens the game's window")
Press(ToggleRaidFrame)
Press(ToggleQuickJoinPanel)
Equal(State(), "-|new", "and Quick Join")
Press(ToggleQuickJoinPanel)
Press(ToggleFriendsFrame)
Equal(State(), "-|new", "and the friends key its window")
Press(ToggleFriendsFrame)
combat = false
Fire("PLAYER_REGEN_ENABLED")
Equal(#blocked, 0, "the game refused none of its own opens")

print("Classic friends checks passed: " .. checks .. " assertions.")
