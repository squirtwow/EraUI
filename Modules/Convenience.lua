local _, EraUI = ...
local Module = {}
EraUI.convenienceSettings = {
    autoQuests=true,
    autoSummon=true,
    autoResurrect=true,
    releasePvP=true,
    blockDuels=true,
    blockPartyInvites=true,
    partyFromFriends=true,
    inviteFromWhispers=true,
    hideKeybindText=true,
    hideMacroText=true,
    hideZoneText=true,
    maxCameraZoom=true,
}
EraUI:RegisterModule("Convenience",Module)
local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function Allowed(key)
    return EraUI:GetSetting(key) and not InCombatLockdown() and not IsShiftKeyDown()
end
local function HidePopup(which) if StaticPopup_Hide then StaticPopup_Hide(which) end end

function Module:IsFriend(name)
    if not Public(name) or type(name)~="string" then return false end
    if not C_FriendList or not C_FriendList.GetNumFriends or not C_FriendList.GetFriendInfoByIndex then return false end
    for i=1,C_FriendList.GetNumFriends() do
        local info=C_FriendList.GetFriendInfoByIndex(i)
        if info and Public(info.name) and info.name then
            -- Do not discard a realm suffix and accidentally trust a different player.
            local full=info.name
            if not full:find("-",1,true) and GetNormalizedRealmName then full=full.."-"..GetNormalizedRealmName() end
            local candidate=name
            if not candidate:find("-",1,true) and GetNormalizedRealmName then candidate=candidate.."-"..GetNormalizedRealmName() end
            if full:lower()==candidate:lower() then return true end
        end
    end
    return false
end

local function QuestCosts()
    -- The native reward button uses GetQuestMoneyToGet for paid turn-ins.
    for _,api in ipairs({"GetQuestMoneyToGet","QuestRequiresGold","QuestRequiresCurrency"}) do
        local getter=_G[api]
        if getter then
            local value=getter()
            if not Public(value) then return true end
            if value==true or (type(value)=="number" and value>0) then return true end
        end
    end
    return false
end
function Module:Quest(event)
    if event=="GOSSIP_CLOSED" and self.questPhase~="GOSSIP_SHOW" then return end
    self.questGeneration=(self.questGeneration or 0)+1
    local generation=self.questGeneration
    if event=="QUEST_FINISHED" or event=="GOSSIP_CLOSED" then
        self.questPhase=nil;self.questClaimed=nil;return
    end
    if event~="QUEST_ITEM_UPDATE" then
        self.questPhase=event;self.questClaimed=nil
    end
    if not Allowed("autoQuests") then return end
    -- Let Blizzard populate the panel before reading reward choices or advancing.
    C_Timer.After(0,function()
        if generation~=self.questGeneration or not Allowed("autoQuests") then return end
        local phase=self.questPhase
        if phase=="GOSSIP_SHOW" then
            local api=C_GossipInfo
            if not api or not api.GetActiveQuests or not api.SelectActiveQuest then return end
            for _,quest in ipairs(api.GetActiveQuests() or {}) do
                if Public(quest.isComplete) and quest.isComplete==true and Public(quest.questID) and type(quest.questID)=="number" then
                    api.SelectActiveQuest(quest.questID);return
                end
            end
        elseif phase=="QUEST_GREETING" and GetNumActiveQuests and GetActiveTitle and SelectActiveQuest then
            local count=GetNumActiveQuests()
            if not Public(count) or type(count)~="number" then return end
            for i=1,count do
                local _,complete=GetActiveTitle(i)
                if Public(complete) and (complete==true or complete==1) then SelectActiveQuest(i);return end
            end
        elseif phase=="QUEST_DETAIL" and AcceptQuest then
            if not QuestGetAutoAccept or not QuestGetAutoAccept() then AcceptQuest() end
        elseif phase=="QUEST_PROGRESS" and CompleteQuest and IsQuestCompletable then
            local complete=IsQuestCompletable()
            if Public(complete) and complete and not QuestCosts() then CompleteQuest() end
        elseif phase=="QUEST_COMPLETE" and GetNumQuestChoices and GetQuestReward and not self.questClaimed and not QuestCosts() then
            local choices=GetNumQuestChoices()
            if Public(choices) and type(choices)=="number" and (choices==0 or choices==1) then
                self.questClaimed=true
                GetQuestReward(choices)
            end
        end
    end)
end

function Module:OnEvent(event,arg1,arg2)
    if event=="QUEST_DETAIL" or event=="QUEST_PROGRESS" or event=="QUEST_COMPLETE" or event=="QUEST_ITEM_UPDATE" or event=="QUEST_FINISHED" or event=="GOSSIP_SHOW" or event=="GOSSIP_CLOSED" or event=="QUEST_GREETING" then self:Quest(event)
    elseif event=="DUEL_REQUESTED" and Allowed("blockDuels") and CancelDuel then
        CancelDuel();HidePopup("DUEL_REQUESTED")
    elseif event=="PARTY_INVITE_REQUEST" then
        if Allowed("partyFromFriends") and self:IsFriend(arg1) and AcceptGroup then
            AcceptGroup();HidePopup("PARTY_INVITE");HidePopup("PARTY_INVITE_XREALM")
        elseif Allowed("blockPartyInvites") and DeclineGroup then
            DeclineGroup();HidePopup("PARTY_INVITE");HidePopup("PARTY_INVITE_XREALM")
        end
    elseif event=="CHAT_MSG_WHISPER" and Allowed("inviteFromWhispers") and Public(arg1) and type(arg1)=="string" then
        if arg1:lower():match("^%s*invite%s*$") and self:IsFriend(arg2) and C_PartyInfo and C_PartyInfo.InviteUnit then
            if not IsInGroup() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then C_PartyInfo.InviteUnit(arg2) end
        end
    elseif event=="CONFIRM_SUMMON" and Allowed("autoSummon") and C_SummonInfo then
        local api=C_SummonInfo
        if not api.GetSummonConfirmSummoner or not api.GetSummonConfirmAreaName or not api.ConfirmSummon then return end
        local summoner,area=api.GetSummonConfirmSummoner(),api.GetSummonConfirmAreaName()
        if not Public(summoner) or not Public(area) or not summoner then return end
        C_Timer.After(1,function()
            if not Allowed("autoSummon") then return end
            local current,place=api.GetSummonConfirmSummoner(),api.GetSummonConfirmAreaName()
            if Public(current) and Public(place) and current==summoner and place==area then api.ConfirmSummon() end
        end)
    elseif event=="RESURRECT_REQUEST" and Allowed("autoResurrect") and AcceptResurrect then
        AcceptResurrect();HidePopup("RESURRECT_NO_TIMER")
    elseif event=="PLAYER_DEAD" and Allowed("releasePvP") then
        C_Timer.After(1,function()
            if not Allowed("releasePvP") or not UnitIsDead("player") then return end
            local _,kind=IsInInstance()
            if kind~="pvp" then return end
            -- Follow the native release button, including its disabled state.
            local name=StaticPopup_Visible and StaticPopup_Visible("DEATH")
            local dialog=name and _G[name]
            local button=dialog and (dialog.button1 or (dialog.GetButton and dialog:GetButton(1)))
            if button and button:IsEnabled() and StaticPopup_OnClick then StaticPopup_OnClick(dialog,1) end
        end)
    elseif event=="PLAYER_REGEN_ENABLED" or event=="PLAYER_ENTERING_WORLD" or event=="UPDATE_BINDINGS" or event=="ACTIONBAR_SLOT_CHANGED" then
        self:Refresh()
    end
end

local regions=setmetatable({}, {__mode="k"})
function Module:Region(region,key)
    if not region or not region.SetAlpha then return end
    local state=regions[region]
    if not state then
        state={key=key};regions[region]=state
        -- Observe only decorative labels, never native health/status setters.
        hooksecurefunc(region,"SetAlpha",function(self)
            if state.writing or not EraUI:GetSetting(state.key) then return end
            if InCombatLockdown() then Module.pending=true;return end
            state.writing=true;self:SetAlpha(0);state.writing=false
        end)
    end
    state.writing=true
    if EraUI:GetSetting(key) then
        if state.before==nil then state.before=region:GetAlpha() end
        region:SetAlpha(0)
    elseif state.before~=nil then
        if region:GetAlpha()==0 then region:SetAlpha(state.before) end
        state.before=nil
    end
    state.writing=false
end

function Module:Refresh()
    if InCombatLockdown() then self.pending=true;return end
    self.pending=false
    for _,prefix in ipairs({"ActionButton","MultiBarBottomLeftButton","MultiBarBottomRightButton","MultiBarLeftButton","MultiBarRightButton","MultiBar5Button","MultiBar6Button","MultiBar7Button"}) do
        for i=1,12 do
            self:Region(_G[prefix..i.."HotKey"],"hideKeybindText")
            self:Region(_G[prefix..i.."Name"],"hideMacroText")
        end
    end
    self:Region(ZoneTextFrame,"hideZoneText");self:Region(SubZoneTextFrame,"hideZoneText")
    local get=C_CVar and C_CVar.GetCVar or GetCVar
    local set=C_CVar and C_CVar.SetCVar or SetCVar
    if get and set then
        local current=get("cameraDistanceMaxZoomFactor")
        if current then
            if EraUI:GetSetting("maxCameraZoom") then
                if not EraUIDB.cameraZoomBackup then EraUIDB.cameraZoomBackup=current end
                if tonumber(current)~=2.6 then set("cameraDistanceMaxZoomFactor",2.6) end
            elseif EraUIDB.cameraZoomBackup then
                if tonumber(current)==2.6 then set("cameraDistanceMaxZoomFactor",EraUIDB.cameraZoomBackup) end
                EraUIDB.cameraZoomBackup=nil
            end
        end
    end
end

function Module:Initialize()
    self.events=CreateFrame("Frame")
    for _,event in ipairs({"QUEST_DETAIL","QUEST_PROGRESS","QUEST_COMPLETE","QUEST_ITEM_UPDATE","QUEST_FINISHED","GOSSIP_SHOW","GOSSIP_CLOSED","QUEST_GREETING","DUEL_REQUESTED","PARTY_INVITE_REQUEST","CHAT_MSG_WHISPER","CONFIRM_SUMMON","RESURRECT_REQUEST","PLAYER_DEAD","PLAYER_REGEN_ENABLED","PLAYER_ENTERING_WORLD","UPDATE_BINDINGS","ACTIONBAR_SLOT_CHANGED"}) do
        self.events:RegisterEvent(event)
    end
    self.events:SetScript("OnEvent",function(_,event,...)self:OnEvent(event,...)end)
    self:Refresh()
end
