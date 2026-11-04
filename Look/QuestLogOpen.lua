-- The classic quest log's ways in and out, its buttons, and its registry
-- entries ("questLog", from /era's Quest Log, a reload setting, with a
-- one-time login step; then "questLogDual", the window's own Double pane
-- choice, live):
--   * ns.ShowQuestLog(questID), ns.HideQuestLog(), ns.ToggleQuestLog():
--     opening never happens in a fight (it says false); closing always works;
--   * the quest micro button: the shared secure pad over it clicks
--     EraUIClassicQuestLogBind, so the micro button opens EraUI's window
--     (its own click is never replaced). EraUI changes no key binding: the
--     game's quest log key opens the game's own map quest panel; a key the
--     player sets on Classic Quest Log (the game's Key Bindings, AddOns
--     section: Bindings.xml) and a /click EraUIClassicQuestLogBind macro
--     open EraUI's;
--   * a quest title clicked in the objective tracker, and Questie's
--     "open quest log" action, open the window on that quest;
--   * the map opens without its quest side list while the window is on;
--   * Escape (the game's own list of windows), the game menu, quest NPC
--     windows and EraUI's shared window manager close it.
-- The window's saved place (from a drag) wins over the window manager's
-- slot, across reloads.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Q = Look.Quest
local parts = Q.parts

local REFRESH_EVENTS = Look.Words("QUEST_LOG_UPDATE QUEST_WATCH_LIST_CHANGED GROUP_ROSTER_UPDATE PLAYER_MONEY")
local NPC_EVENTS = Look.Words("QUEST_DETAIL QUEST_PROGRESS QUEST_COMPLETE QUEST_GREETING GOSSIP_SHOW")

local function Now()
    return type(GetTime) == "function" and (Look.Number(GetTime()) or 0) or 0
end

local function QuickBinding()
    local check = KeybindFrames_InQuickKeybindMode
    if type(check) ~= "function" then return false end
    return Q.Yes(check)
end

---------------------------------------------------------------------------
-- Opening and closing
---------------------------------------------------------------------------

function Q.Hide()
    if Q.window then Q.window:Hide() end
end

-- The quest's own header opened (in the game and in EraUI's folding); the
-- other folded sections stay folded. The quest becomes the selection.
local function OpenTo(questID)
    local headerKey
    local index = 1
    while index <= Q.EntryCount() do
        local info = Q.Info(index)
        if info and info.isHeader == true then
            if info.isCollapsed == true and type(ExpandQuestHeader) == "function" then
                pcall(ExpandQuestHeader, Look.Number(info.questLogIndex) or index)
            end
            headerKey = info.headerSortKey
            if headerKey == nil or Look.Secret(headerKey) then headerKey = Q.Words(info.title) end
            headerKey = headerKey or info.questLogIndex or index
        elseif info and info.questID == questID then
            if headerKey ~= nil then Q.folded[headerKey] = nil end
            break
        end
        index = index + 1
    end
    Q.selected = questID
    Q.SelectInGame(questID)
end

-- The list scrolled just enough to show the quest; the detail from its top.
local function Reveal(questID)
    local _, place = Q.EntryFor(questID)
    if not place then return end
    local offset, shown = Q.ListOffset(), Q.rowsShown or 6
    if place <= offset then
        parts.listBar:SetValue(place - 1)
    elseif place > offset + shown then
        parts.listBar:SetValue(place - shown)
    end
    parts.detailBar:SetValue(0)
end

function ns.ShowQuestLog(questID)
    if not Q.active or Look.InFight() then return false end
    local window = Q.Build()
    local wanted = Look.Number(questID)
    if wanted then OpenTo(wanted) end
    if window:IsShown() then Q.Refresh() else window:Show() end
    if wanted and window:IsShown() then Reveal(wanted) end
    return window:IsShown()
end

function ns.HideQuestLog()
    Q.Hide()
end

function ns.ToggleQuestLog()
    if Q.window and Q.window:IsShown() then
        Q.Hide()
        return
    end
    ns.ShowQuestLog()
end

function ns.QuestLogSetAllCollapsed(collapsed)
    Q.FoldAll(collapsed and true or false)
end

-- The layout switch (nothing before the window exists; it reads
-- questLogDual when it is built).
function ns.QuestLogSetDual(on)
    local window = Q.window
    if not window then return end
    on = on and true or false
    if Q.double == on then return end
    Q.Lay(on)
    if window:IsShown() then Q.Refresh() end
end

---------------------------------------------------------------------------
-- The window's controls
---------------------------------------------------------------------------

function Q.AllTabClicked()
    local opening = Q.AllFolded()
    Q.FoldAll(not opening)
    Q.Sound(opening and "IG_QUEST_LIST_OPEN" or "IG_QUEST_LIST_CLOSE")
    Q.Refresh()
end

function Q.TrackRadioClicked(radio)
    local chosen = Q.selected
    if not chosen then
        radio:SetChecked(false)
        return
    end
    local wanted = radio:GetChecked() and true or false
    Q.SetWatched(chosen, wanted)
    Q.Sound(wanted and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
    Q.Refresh()
end

function Q.DualRadioClicked(radio)
    local wanted = radio:GetChecked() and true or false
    Q.Sound(wanted and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
    local saved = ns.db
    if saved then saved.questLogDual = wanted end
    if type(ns.ApplyAll) == "function" then Look.Try(ns.ApplyAll) end
    if type(ns.RefreshOptionsWindow) == "function" then Look.Try(ns.RefreshOptionsWindow) end
end

function Q.TrackClicked()
    if not Q.selected then return end
    Q.FlipWatch(Q.selected)
    Q.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
    Q.Refresh()
end

-- The game's own pop-ups do the abandoning.
local function AbandonItems()
    local names = {}
    local reader = C_QuestLog and C_QuestLog.GetAbandonQuestItems
    if type(reader) ~= "function" then return names end
    local fine, items = pcall(reader)
    if not fine or type(items) ~= "table" then return names end
    local named = C_Item and C_Item.GetItemNameByID
    for _, itemID in ipairs(items) do
        local name
        if type(named) == "function" then
            local asked, answer = pcall(named, itemID)
            name = asked and Q.Words(answer) or nil
        end
        names[#names + 1] = name or tostring(itemID)
    end
    return names
end

function Q.Abandon()
    local chosen = Q.selected
    if not chosen then return end
    Q.SelectInGame(chosen)
    if C_QuestLog and type(C_QuestLog.SetAbandonQuest) == "function" then pcall(C_QuestLog.SetAbandonQuest) end
    local name
    if C_QuestLog and type(C_QuestLog.GetAbandonQuestName) == "function" then
        local fine, answer = pcall(C_QuestLog.GetAbandonQuestName)
        name = fine and Q.Words(answer) or nil
    end
    local entry = Q.EntryFor(chosen)
    name = name or (entry and Q.Words(entry.info.title)) or ""
    local items = AbandonItems()
    if #items > 0 then
        if StaticPopup_Hide then StaticPopup_Hide("ABANDON_QUEST") end
        if StaticPopup_Show then StaticPopup_Show("ABANDON_QUEST_WITH_ITEMS", name, table.concat(items, ", ")) end
    else
        if StaticPopup_Hide then StaticPopup_Hide("ABANDON_QUEST_WITH_ITEMS") end
        if StaticPopup_Show then StaticPopup_Show("ABANDON_QUEST", name) end
    end
    Q.Sound("IG_QUEST_LOG_ABANDON_QUEST")
end

local function RedLine(text)
    local errors = UIErrorsFrame
    if errors and errors.AddMessage then errors:AddMessage(text, 1, 0.1, 0.1) end
end

function Q.Share()
    local chosen = Q.selected
    if not chosen or type(QuestLogPushQuest) ~= "function" then return end
    if not Q.InGroup() then
        RedLine("You are not in a party.")
        return
    end
    local entry = Q.EntryFor(chosen)
    if entry and Q.Yes(C_QuestLog and C_QuestLog.IsPushableQuest, chosen) then pcall(QuestLogPushQuest, entry.index) end
end

-- Show Map's own click: only when its secure pad isn't over it (a fight).
function Q.ShowMapClicked()
    if Look.InFight() then
        RedLine(Q.Say("ERR_NOT_IN_COMBAT", "You can't do that while in combat"))
        return
    end
    Q.Hide()
    if type(ToggleWorldMap) == "function" then
        Look.Try(ToggleWorldMap)
    elseif WorldMapFrame and type(ShowUIPanel) == "function" then
        Look.Try(ShowUIPanel, WorldMapFrame)
    end
end

---------------------------------------------------------------------------
-- The window's own scripts, events and manners
---------------------------------------------------------------------------

-- The saved place (from a drag), from the table or, when that was lost,
-- from its text in the settings mirror.
local function SavedPlace()
    local saved = ns.db
    if not saved then return nil end
    local place = saved.questLogPos
    if type(place) == "table" and type(place[1]) == "string" and Look.Number(place[3]) and Look.Number(place[4]) then
        return place
    end
    place = Look.DecodePlace(saved.questLogPosText)
    if place then saved.questLogPos = place end
    return place
end

-- Wherever the window manager (or anything) puts it, a saved place wins.
local settling = false
local function Settle()
    if settling or not Q.window then return end
    local place = SavedPlace()
    if not place then return end
    settling = true
    Look.Pin(Q.window, place[1], UIParent, place[2] or place[1], place[3], place[4])
    settling = false
end

local function StartingPlace(window)
    if SavedPlace() then Settle() else Look.Pin(window, "TOPLEFT", UIParent, "TOPLEFT", 0, -104) end
end

local function Dropped(window)
    window:StopMovingOrSizing()
    local point, _, relativePoint, x, y = window:GetPoint(1)
    x, y = Look.Number(x), Look.Number(y)
    local saved = ns.db
    if not saved or type(point) ~= "string" or not x or not y then return end
    saved.questLogPos = { point, type(relativePoint) == "string" and relativePoint or point, x, y }
    saved.questLogPosText = Look.EncodePlace(saved.questLogPos)
    Look.Save()
end

-- While the window manager places windows: a window with a saved place
-- keeps its spot.
local function HoldsAt()
    if not (Q.window and SavedPlace()) then return nil end
    local left = Look.Number(Q.window:GetLeft())
    return left and math.floor(left + 0.5) or nil
end

local function Opened()
    Q.Sound("IG_QUEST_LOG_OPEN")
    Settle()
    Q.Refresh()
    if type(ns.RefreshMicroButtons) == "function" then Look.Try(ns.RefreshMicroButtons) end
end

-- A row or reward plate of the window: its tooltip goes with the window.
local function OursTip()
    local holder = Look.TipOwner()
    local owner = holder
    while holder do
        if holder == Q.window then return owner end
        holder = holder.GetParent and holder:GetParent() or nil
    end
    return nil
end

local function Closed()
    Q.Sound("IG_QUEST_LOG_CLOSE")
    local owner = OursTip()
    if owner then Look.HideTip(owner) end
    if type(ns.RefreshMicroButtons) == "function" then Look.Try(ns.RefreshMicroButtons) end
end

-- Once a second while a timed quest shows: the detail drawn again.
local ticked = 0
local function Ticking(_, elapsed)
    if not Q.timed then
        ticked = 0
        return
    end
    ticked = ticked + (Look.Number(elapsed) or 0)
    if ticked < 1 then return end
    ticked = 0
    Q.DrawDetail()
end

local function Listener(window)
    local listener = Look.Build("Frame", window, nil, { size = { 1, 1 } })
    local refreshing, closing = {}, {}
    for _, event in ipairs(REFRESH_EVENTS) do
        refreshing[event] = true
        Look.Listen(listener, event)
    end
    refreshing.UNIT_QUEST_LOG_CHANGED = true
    Look.Listen(listener, "UNIT_QUEST_LOG_CHANGED", "player")
    for _, event in ipairs(NPC_EVENTS) do
        closing[event] = true
        Look.Listen(listener, event)
    end
    listener:SetScript("OnEvent", function(_, event, unit)
        if not window:IsShown() then return end
        if closing[event] then
            Q.Hide()
        elseif refreshing[event] and (event ~= "UNIT_QUEST_LOG_CHANGED" or unit == "player") then
            Q.Refresh()
        end
    end)
end

-- Everything that comes with the window, once, as it is built.
function Q.Wire(window)
    window:SetScript("OnShow", Opened)
    window:SetScript("OnHide", Closed)
    window:SetScript("OnUpdate", Ticking)
    window:SetScript("OnDragStart", function(self) self:StartMoving() end)
    window:SetScript("OnDragStop", Dropped)
    Listener(window)
    Look.Hook(window, "SetPoint", Settle)
    Look.WindowTraits(window, { hold = HoldsAt })
    StartingPlace(window)
    if type(ns.RegisterClassicWindow) == "function" then Look.Try(ns.RegisterClassicWindow, window) end
    if type(ns.CloseOnEscape) == "function" then ns.CloseOnEscape(window, Q.Hide) end
    if type(ns.MicroButtonFollows) == "function" and QuestLogMicroButton then
        ns.MicroButtonFollows(QuestLogMicroButton, function()
            return Q.active == true and Q.window ~= nil and Q.window:IsShown()
        end)
    end
end

---------------------------------------------------------------------------
-- The ways in from outside the window
---------------------------------------------------------------------------

-- The named click target. The micro button's pad and a /click macro send
-- one (up) click; a key set on Classic Quest Log in the game's Key Bindings
-- (Bindings.xml) sends a down click as it goes down and an up click as it
-- comes up. One toggle a press: the down click toggles and that key's up
-- click is passed over, however long the key is held; an up click with no
-- down click before it toggles.
local lastPress, keyHeld = -1, false
local function TargetClicked(_, _, down)
    if down then
        keyHeld = true
    elseif keyHeld then
        keyHeld = false
        return
    end
    local now = Now()
    if now - lastPress < 0.2 then return end
    lastPress = now
    if Q.active then ns.ToggleQuestLog() end
end

local function ClickTarget()
    if Q.target then return Q.target end
    local target = Look.Build("Button", UIParent, nil, { name = "EraUIClassicQuestLogBind", size = { 1, 1 } })
    Look.Pin(target, "TOPLEFT", UIParent, "TOPLEFT", -500, 500)
    target:EnableMouse(false)
    target:RegisterForClicks("AnyDown", "AnyUp")
    target:SetScript("OnClick", TargetClicked)
    Q.target = target
    return target
end

-- The micro button's pad: up while the window is on, aside while the
-- player binds keys with the game's quick keybind mode.
local function PadWanted()
    return Q.active == true and not QuickBinding()
end

-- A quest title clicked in the tracker: after the game's own handler (which
-- opens the map on the quest), the map closes and the window opens on it.
-- A right click, a link or a watch toggle is the game's; so is a fight.
local function TitleClicked(_, block, mouse)
    if not Q.active or mouse == "RightButton" or Look.InFight() then return end
    if Q.Modified("CHATLINK") or Q.Modified("QUESTWATCHTOGGLE") then return end
    local questID = type(block) == "table" and Look.Number(block.id) or nil
    if not questID then return end
    if WorldMapFrame and WorldMapFrame:IsShown() then Look.HidePanel(WorldMapFrame) end
    ns.ShowQuestLog(questID)
end

-- Questie's "open quest log" action: wrapped once; its own handler stays
-- the fallback, with the same receiver, arguments and results.
local questieOwn = Look.Weak() -- Questie's tracker module: its own handler
local function WrapQuestie()
    local loader = QuestieLoader
    if type(loader) ~= "table" or type(loader.ImportModule) ~= "function" then return end
    local fine, utilities = pcall(loader.ImportModule, loader, "TrackerUtils")
    if not fine or type(utilities) ~= "table" or questieOwn[utilities] then return end
    local own = utilities.ShowQuestLog
    if type(own) ~= "function" then return end
    questieOwn[utilities] = own
    utilities.ShowQuestLog = function(self, quest, ...)
        local questID = type(quest) == "table" and Look.Number(quest.Id) or nil
        if questID and questID > 0 and Q.active and Look.Enabled() and not Look.InFight()
            and (Q.IndexOf(questID) or 0) > 0 and ns.ShowQuestLog(questID) then
            return
        end
        return own(self, quest, ...)
    end
end

-- The map's own quest side list kept shut while the window is on.
local function MapListShut()
    if not Q.active then return end
    local settings = C_CVar
    if type(settings) ~= "table" or type(settings.GetCVar) ~= "function" or type(settings.SetCVar) ~= "function" then return end
    local fine, value = pcall(settings.GetCVar, "questLogOpen")
    if fine and not Look.Secret(value) and value == "1" then pcall(settings.SetCVar, "questLogOpen", "0") end
end

-- What comes once per session (at login, or the first apply).
local function Prepare()
    if Q.prepared then return end
    Q.prepared = true
    ClickTarget()
    for _, name in ipairs({ "QuestObjectiveTracker", "CampaignQuestObjectiveTracker" }) do
        local tracker = _G[name]
        if type(tracker) == "table" then Look.HookOrMiss(tracker, name, "OnBlockHeaderClick", TitleClicked) end
    end
    Look.Every(0.5, MapListShut)
    if GameMenuFrame then
        Look.HookScript(GameMenuFrame, "OnShow", function()
            if not Look.InFight() then Q.Hide() end
        end, "questLog")
    end
    WrapQuestie()
end

---------------------------------------------------------------------------
-- The registry entries
---------------------------------------------------------------------------

local function AtLogin()
    Q.active = true
    Prepare()
end

local function QuestLogOn()
    Q.active = true
    Prepare()
    local micro = QuestLogMicroButton
    if micro and type(ns.MapPad) == "function" then ns.MapPad(micro, nil, nil, ClickTarget(), PadWanted) end
    WrapQuestie()
end

local function QuestLogOff()
    Q.active = false
    Q.Hide()
end

-- The window's own Double pane choice: the layout switched on every pass.
local function DoublePane() ns.QuestLogSetDual(true) end
local function SinglePane() ns.QuestLogSetDual(false) end

ns.RegisterModule("questLog", { init = AtLogin, apply = QuestLogOn, restore = QuestLogOff })
ns.RegisterModule("questLogDual", { apply = DoublePane, restore = SinglePane })

-- Questie may load after EraUI.
do
    local loads = CreateFrame("Frame")
    Look.Listen(loads, "ADDON_LOADED")
    loads:SetScript("OnEvent", function(_, _, addon)
        if addon == "Questie" then WrapQuestie() end
    end)
end
