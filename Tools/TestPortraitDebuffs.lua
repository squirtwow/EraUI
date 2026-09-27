-- Run the actual portrait module against native-frame/aura fixtures. Restricted
-- values, pooled party ownership and expiry must never leak an old unit's icon.
local checks=0
local function Equal(actual, expected, label)
    checks=checks+1
    assert(actual==expected, label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local frames, now, combat, restricted, failRead = {}, 100, false, false, false
local secret=setmetatable({}, {__sub=function()error("secret arithmetic")end, __lt=function()error("secret comparison")end})
issecretvalue=function(value)return value==secret end
GetTime=function()return now end
InCombatLockdown=function()return combat end
STANDARD_TEXT_FONT="font"
local function Frame(parent)
    local f={parent=parent, shown=true, scripts={}, hooks={}, events={}, level=parent and parent.level+1 or 1}
    function f:SetScript(key,fn)self.scripts[key]=fn end
    function f:HookScript(key,fn)self.hooks[key]=self.hooks[key]or{};table.insert(self.hooks[key],fn)end
    function f:Fire(key,...)
        if self.scripts[key]then self.scripts[key](self,...)end
        for _,fn in ipairs(self.hooks[key]or{})do fn(self,...)end
    end
    function f:Show()if not self.shown then self.shown=true;self:Fire("OnShow")end end
    function f:Hide()if self.shown then self.shown=false;self:Fire("OnHide")end end
    function f:IsShown()return self.shown end
    function f:IsVisible()return self.shown and (not self.parent or self.parent:IsVisible())end
    function f:GetParent()return self.parent end
    function f:SetFrameLevel(level)self.level=level end
    function f:GetFrameLevel()return self.level end
    function f:EnableMouse(value)self.mouse=value end
    function f:SetPoint(...)self.point={...}end
    function f:SetAllPoints()end
    function f:CreateTexture()return Frame(self)end
    function f:CreateFontString()return Frame(self)end
    function f:SetTexture(value)self.texture=value end
    function f:SetText(value)self.text=value end
    function f:SetTextColor(...)self.colour={...}end
    function f:SetFont(path,size)self.fontSize=size end
    function f:SetDrawEdge(value)self.edge=value end
    function f:SetDrawBling(value)self.bling=value end
    function f:SetSwipeTexture(value)self.swipe=value end
    function f:SetSwipeColor(...)self.swipeColour={...}end
    function f:SetUseCircularEdge(value)self.circular=value end
    function f:SetHideCountdownNumbers(value)self.hideNumbers=value end
    function f:SetCooldown(start,duration)self.start,self.duration=start,duration;self.writes=(self.writes or 0)+1 end
    function f:RegisterEvent(event)self.events[event]=true end
    frames[#frames+1]=f
    return f
end
CreateFrame=function(kind,_,parent)
    assert(not combat or kind=="Frame" and not parent,"created display in combat")
    return Frame(parent)
end
local function Native(unit,style)
    local owner=Frame();owner.unit=unit
    local container=Frame(owner)
    local portrait=Frame(container)
    portrait.texture="native face"
    portrait.SetTexture=function()error("native portrait changed")end
    owner.SetAttribute=function()error("native secure attributes changed")end
    if style=="player"then owner.PlayerFrameContainer=container;container.PlayerPortrait=portrait
    elseif style=="target"then owner.TargetFrameContainer=container;container.Portrait=portrait
    else owner.Portrait=portrait end
    return owner,portrait
end
PlayerFrame=Native("player","player")
TargetFrame=Native("target","target")
FocusFrame=Native("focus","target")
local party={Native("party1"),Native("party2"),Native("party3"),(Native("party4"))}
PartyFrame={PartyMemberFramePool={EnumerateActive=function()
    local i=0
    return function()i=i+1;return party[i]end
end}}
local auras, reads, absent, alias = {}, 0, {}, {}
UnitExists=function(unit)return not absent[unit]end
UnitIsUnit=function(a,b)return alias[a]==b end
C_Secrets={ShouldAurasBeSecret=function()return restricted end}
C_UnitAuras={GetAuraDataByIndex=function(unit,index,filter)
    reads=reads+1
    assert(filter=="HARMFUL","helpful auras scanned")
    if failRead then error("aura access restricted")end
    return auras[unit]and auras[unit][index]
end}
local E={settings={enabled=true,unitFrames=true,portraitDebuffs=false},modules={},Classic={}}
function E:RegisterModule(name,module)self.modules[name]=module end
function E:GetSetting(key)return self.settings[key]end
function E.Classic.RoundIcon(icon)icon.round=true end
function E.Classic.TexPath(key)return key end
assert(loadfile("Modules/PortraitDebuffs.lua"))("EraUI",E)
local M=E.modules.PortraitDebuffs
M:Initialize()
local function Event(event,unit)
    for _,f in ipairs(frames)do if f.events[event]then f:Fire("OnEvent",event,unit)end end
end
local function Overlay(owner)
    for _,f in ipairs(frames)do
        if f.icon and f.point and f.point[2]:GetParent():GetParent()==owner then return f end
    end
end
local function Aura(id,duration,expiry)
    return {spellId=id,icon=id+100000,duration=duration or 10,expirationTime=expiry or now+10}
end
local function Tick(delta)
    now=now+delta
    for _,f in ipairs(frames)do if f:IsVisible()then f:Fire("OnUpdate",delta)end end
end
Equal(reads,0,"disabled module does not query auras")
Equal(Overlay(PlayerFrame),nil,"disabled module creates no portrait overlay")
E.settings.portraitDebuffs=true;M:Refresh()
for _,owner in ipairs({PlayerFrame,TargetFrame,FocusFrame,party[1],party[2],party[3],party[4]})do
    local overlay=assert(Overlay(owner),"missing supported portrait")
    Equal(overlay:IsShown(),false,"ordinary portrait without important debuff")
    Equal(overlay.mouse,false,"portrait click-through")
    Equal(overlay.icon.round,true,"circular icon mask")
    Equal(overlay.cooldown.circular,true,"circular cooldown sweep")
    Equal(overlay.cooldown.hideNumbers,true,"no duplicate native countdown")
end
local p,t,f=Overlay(PlayerFrame),Overlay(TargetFrame),Overlay(FocusFrame)
auras.player={Aura(339,20),Aura(15487),Aura(118),Aura(853,6,106),Aura(172)}
Event("UNIT_AURA","player")
Equal(p.icon.texture,100853,"stun beats polymorph, silence and root")
Equal(p.cooldown.start,100,"cooldown begins at expiry minus duration")
Equal(p.cooldown.duration,6,"actual aura duration drives sweep")
Equal(p.time.text,"6","remaining seconds shown")
local before=reads
Tick(1.1)
Equal(p.time.text,"5","countdown advances")
Equal(reads,before,"countdown does not poll auras")
Event("UNIT_AURA","player")
Equal(p.cooldown.writes,1,"unrelated aura event does not restart sweep")
table.remove(auras.player,4);Event("UNIT_AURA","player")
Equal(p.icon.texture,100118,"dispel selects next highest priority")
table.remove(auras.player,3);Event("UNIT_AURA","player")
Equal(p.icon.texture,115487,"silence beats root")
table.remove(auras.player,2);Event("UNIT_AURA","player")
Equal(p.icon.texture,100339,"root when stronger effects removed")
auras.player={Aura(172),Aura(116)};Event("UNIT_AURA","player")
Equal(p:IsShown(),false,"ordinary damage and slows leave face visible")
auras.player={Aura(853,0,now+10)};Event("UNIT_AURA","player")
Equal(p:IsShown(),false,"missing duration does not manufacture countdown")
auras.player={Aura(8643,5,now+5),Aura(853,10,now+10)};Event("UNIT_AURA","player")
Equal(p.icon.texture,100853,"equal priority prefers longer remaining effect")
auras.player={Aura(853,1,now+1),Aura(339,15,now+15)};Event("UNIT_AURA","player")
Tick(1.1)
Equal(p.icon.texture,100339,"expiry falls back without waiting for aura event")
auras.player={};Tick(15)
Equal(p:IsShown(),false,"expiry restores ordinary portrait")

for _,unit in ipairs({"target","focus","party1","party2","party3","party4"})do auras[unit]={Aura(118)}end
M:Refresh()
for _,owner in ipairs({TargetFrame,FocusFrame,party[1],party[2],party[3],party[4]})do
    Equal(Overlay(owner):IsShown(),true,"all supported units show their CC")
end
absent.target=true;Event("PLAYER_TARGET_CHANGED")
Equal(t:IsShown(),false,"target clear hides previous target debuff")
absent.target=nil;auras.target={};Event("PLAYER_TARGET_CHANGED")
Equal(t:IsShown(),false,"new target cannot inherit old icon")
FocusFrame:Hide();Equal(f:IsShown(),false,"hidden frame clears its overlay")
FocusFrame:Show();Equal(f:IsShown(),true,"reshown frame rescans auras")
local member=party[1];local memberOverlay=Overlay(member)
member.unit="party2";auras.party2={};Event("UNIT_AURA","party2")
Equal(memberOverlay:IsShown(),false,"recycled party frame clears old member aura")
member.unit="raid1";M:Refresh()
Equal(memberOverlay:IsShown(),false,"raid tokens are outside portrait scope")
member.unit="party1";M:Refresh()
table.remove(party,1);Event("GROUP_ROSTER_UPDATE")
Equal(memberOverlay:IsShown(),false,"released pool frame cleared")
party[#party+1]=member;Event("GROUP_ROSTER_UPDATE")
Equal(memberOverlay:IsShown(),true,"reacquired party frame updates")

auras.player={Aura(5211)};alias.target="player";auras.target=auras.player
Event("UNIT_AURA","player")
Equal(t.icon.texture,105211,"alias aura event updates matching target")
alias.target=nil
before=reads;Event("UNIT_AURA","nameplate1")
Equal(reads,before,"unrelated units do not trigger scans")
Event("UNIT_AURA",secret)
Equal(reads,before,"restricted event unit ignored")
for _,key in ipairs({"spellId","duration","expirationTime","icon"})do
    auras.player={Aura(853)};auras.player[1][key]=secret
    Event("UNIT_AURA","player")
    Equal(p:IsShown(),false,"restricted "..key.." preserves normal portrait")
end
auras.player={secret};Event("UNIT_AURA","player")
Equal(p:IsShown(),false,"restricted aura record rejected before indexing")
auras.player={Aura(853)};failRead=true;Event("UNIT_AURA","player")
Equal(p:IsShown(),false,"failed query safely clears overlay")
failRead=false;restricted=true;before=reads;M:Refresh()
Equal(reads,before,"secret policy prevents restricted API calls")
Equal(p:IsShown(),false,"restriction clears formerly visible CC")
restricted=false;combat=true;Event("PLAYER_REGEN_DISABLED")
Equal(p:IsShown(),true,"existing cosmetic overlays work with public combat auras")
local newParty=Native("party2");party[#party+1]=newParty
Event("GROUP_ROSTER_UPDATE")
Equal(Overlay(newParty),nil,"new frames deferred during combat")
combat=false;Event("PLAYER_REGEN_ENABLED")
Equal(Overlay(newParty)~=nil,true,"deferred overlay created on combat exit")
for _,key in ipairs({"portraitDebuffs","unitFrames","enabled"})do
    E.settings[key]=false;before=reads;M:Refresh()
    Equal(p:IsShown(),false,key.." off restores portrait immediately")
    Equal(reads,before,key.." off stops aura queries")
    E.settings[key]=true;M:Refresh()
end
local count=#frames
for _=1,5 do Event("ADDON_LOADED")end
Equal(#frames,count,"repeated discovery does not create extra overlays")
Equal(#PlayerFrame.hooks.OnShow,1,"one native visibility hook per owner")
p:Fire("OnSizeChanged",34)
Equal(p.time.fontSize,34*.47,"countdown scales to small party portraits")
Equal(PlayerFrame.PlayerFrameContainer.PlayerPortrait.texture,"native face","native face texture never overwritten")
print("Portrait debuff checks passed: "..checks.." assertions.")
