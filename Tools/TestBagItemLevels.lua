-- Bag Item Levels on the real module. Blizzard's bag buttons are proxies that
-- log every key read and refuse every key write, so the checks prove the marks
-- never write on a bag button. Items, worn gear, tooltips and the game's
-- usable-item answer are all driven from one table per case.
local checks=0
local function equal(got,want,label)
 checks=checks+1;assert(got==want,label..": expected "..tostring(want)..", got "..tostring(got))
end
local combat,made,timers,hooks=false,0,{},0
local reads={}
-- A hidden value: any read of it fails, as in the client.
local SECRET=setmetatable({},{__index=function()error("read a secret value")end})
issecretvalue=function(v)return v==SECRET end
InCombatLockdown=function()return combat end
C_Timer={After=function(_,fn)timers[#timers+1]=fn end}
local function Flush()
 for _=1,10 do if #timers==0 then return end;local list=timers;timers={};for _,fn in ipairs(list)do fn()end end
 error("timers did not settle")
end
hooksecurefunc=function(t,key,fn)
 local old=t[key];hooks=hooks+1;t[key]=function(...)old(...);fn(...)end
end
-- Our own frames, textures and font strings.
local function Region(kind,parent,layer,template)
 local r={kind=kind,parent=parent,layer=layer,template=template,shown=true,points={}}
 function r:SetAllPoints(to)self.all=to end
 function r:SetPoint(p,to,rp,x,y)self.points[p]={to,rp,x,y}end
 function r:SetSize(w,h)self.w,self.h=w,h end
 function r:SetTexture(t)self.texture=t end
 function r:SetBlendMode(m)self.blend=m end
 function r:SetVertexColor(a,b,c)self.colour={a,b,c}end
 function r:SetTexCoord(...)self.coords={...}end
 function r:SetText(t)self.text=t end
 function r:SetTextColor(a,b,c)self.textColour={a,b,c}end
 function r:SetJustifyH(j)self.justify=j end
 function r:SetAlpha(a)self.alpha=a end
 function r:Show()self.shown=true end
 function r:Hide()self.shown=false end
 function r:SetShown(v)self.shown=v and true or false end
 function r:IsShown()return self.shown end
 return r
end
local eventFrame
CreateFrame=function(kind,name,parent)
 made=made+1
 local f=Region("Frame",parent)
 f.events={}
 function f:EnableMouse(v)self.mouse=v end
 function f:SetFrameLevel(l)self.frameLevel=l end
 function f:CreateTexture(_,layer)local t=Region("Texture",self,layer);self.children=(self.children or 0)+1;return t end
 function f:CreateFontString(_,layer,template)return Region("FontString",self,layer,template)end
 function f:SetScript(_,fn)self.handler=fn;eventFrame=self end
 function f:RegisterEvent(e)self.events[e]=true end
 function f:UnregisterAllEvents()self.events={}end
 return f
end
local function Fire(event)if eventFrame and eventFrame.events[event]then eventFrame.handler(eventFrame,event)end end

-- The game: items by link, bags, worn gear, the player.
local RED,WHITE,GREEN={r=1,g=.125,b=.125},{r=1,g=1,b=1},{r=.1,g=1,b=.1}
local player={level=60,dual=false,plate=true,mail=true}
local items,lastID={},0
local function Item(link,loc,level,extra)
 lastID=lastID+1
 local it={link=link,id=lastID,loc=loc,level=level,minLevel=1,quality=2,cached=true}
 for k,v in pairs(extra or{})do it[k]=v end
 items[link]=it;return link
end
-- A tooltip in the order the game builds it: name, binding, slot and armour type, then requirements.
local tipCalls,tipsFor,infoCalls=0,{},0
local function Tip(it)
 local lines={{leftText=it.link,leftColor=RED}} -- a red name line must not count
 lines[#lines+1]={leftText="Soulbound",leftColor=WHITE}
 local kind=it.armour
 local known=kind==nil or(kind=="Plate"and player.plate)or(kind=="Mail"and player.mail)or kind=="Cloth"
 lines[#lines+1]={leftText="Slot",leftColor=WHITE,rightText=kind or "",rightColor=known and WHITE or RED}
 if it.broken then lines[#lines+1]={leftText="Durability 0 / 45",leftColor=RED}end
 if it.class then lines[#lines+1]={leftText="Classes: "..it.class,leftColor=it.class==player.class and WHITE or RED}end
 lines[#lines+1]={leftText="Requires Level "..it.minLevel,leftColor=player.level>=it.minLevel and WHITE or RED}
 lines[#lines+1]={leftText="Equip: Improves your chance to hit by 1%.",leftColor=GREEN}
 if it.retrieving then lines[#lines+1]={leftText="Retrieving item information",leftColor=RED}end
 if it.secretTip then return SECRET end
 return {lines=lines}
end
local bags,worn={},{}
C_Container={GetContainerItemInfo=function(bag,slot)
 infoCalls=infoCalls+1
 local link=bags[bag]and bags[bag][slot]
 if link==SECRET then return SECRET end
 local it=link and items[link]
 if not it then return nil end
 return {hyperlink=it.link,quality=it.quality,itemID=it.id,stackCount=1}
end}
C_Item={
 GetItemInfoInstant=function(link)local it=items[link];if it then return it.id,"Armor","",it.loc end end,
 GetDetailedItemLevelInfo=function(link)local it=items[link];if it and it.cached then return it.level,false,it.level end end,
 GetItemInfo=function(link)local it=items[link];if it and it.cached then return it.link,it.link,it.quality,it.level,it.minLevel end end,
}
C_TooltipInfo={GetBagItem=function(bag,slot)
 tipCalls=tipCalls+1
 local it=items[bags[bag][slot]]
 tipsFor[it.link]=(tipsFor[it.link]or 0)+1
 return Tip(it)
end}
local canUse={}
C_PlayerInfo={CanUseItem=function(id)for _,it in pairs(items)do if it.id==id then return canUse[it.link]~=false end end;return true end}
GetInventoryItemLink=function(_,slot)return worn[slot]end
CanDualWield=function()return player.dual end
UnitLevel=function()return player.level end
ITEM_QUALITY_COLORS={[0]={r=.62,g=.62,b=.62},[1]={r=1,g=1,b=1},[2]={r=.12,g=1,b=0},[3]={r=0,g=.44,b=.87},[4]={r=.64,g=.21,b=.93}}

-- Blizzard's bag buttons and windows. Only the proxy is handed to the addon.
local function Native()
 local n={calls=0}
 for _,m in ipairs({"Show","Hide","SetShown","SetAtlas","SetTexture","SetVertexColor","SetText","SetAlpha","SetPoint"})do
  n[m]=function(self)self.calls=self.calls+1 end
 end
 return n
end
local backs={}
local function Button(bag,slot,extra)
 local back={bag=bag,slot=slot,level=10,icon=Native(),Count=Native(),JunkIcon=Native(),UpgradeIcon=Native(),IconBorder=Native()}
 for k,v in pairs(extra or{})do back[k]=v end
 function back.GetBagID(self)return back.bag end
 function back.GetID(self)return back.slot end
 function back.GetFrameLevel(self)return back.level end
 function back.IsProtected(self)return back.protected==true end
 function back.GetMatchesSearch(self)return back.matches end
 local proxy=setmetatable({},{
  __index=function(_,key)reads[key]=(reads[key]or 0)+1;return back[key]end,
  __newindex=function(_,key)error("wrote "..tostring(key).." on a Blizzard bag button")end,
 })
 backs[proxy]=back
 return proxy
end
local function Window(name,buttons,shown)
 local f={Items=buttons,size=#buttons,shown=shown,updates=0}
 function f:IsShown()return self.shown end
 function f:EnumerateValidItems()
  local i=0
  return function()i=i+1;if i<=self.size then return i,self.Items[i]end end,self,0
 end
 function f:UpdateItems()self.updates=self.updates+1 end
 function f:IsCombinedBagContainer()return name=="ContainerFrameCombinedBags"end
 _G[name]=f
 return f
end
local backpack,bag1={},{}
for slot=1,16 do backpack[slot]=Button(0,slot)end
for slot=1,6 do bag1[slot]=Button(1,slot)end
Window("ContainerFrame1",backpack,true)
Window("ContainerFrame2",bag1,false)
local combined={}
for slot=1,16 do combined[#combined+1]=Button(0,slot)end
for slot=1,6 do combined[#combined+1]=Button(1,slot)end
Window("ContainerFrameCombinedBags",combined,false)
ContainerFrameContainer={ContainerFrames={ContainerFrame1,ContainerFrame2}}

-- Gear worn: head 40, rings 50 and 35, no trinkets, main hand 40 and off hand 30.
worn[1]=Item("worn-head","INVTYPE_HEAD",40)
worn[5]=Item("worn-chest","INVTYPE_CHEST",30)
worn[11]=Item("worn-ring-a","INVTYPE_FINGER",50)
worn[12]=Item("worn-ring-b","INVTYPE_FINGER",35)
worn[16]=Item("worn-dagger","INVTYPE_WEAPON",40)
worn[17]=Item("worn-dirk","INVTYPE_WEAPONOFFHAND",30)
worn[18]=Item("worn-bow","INVTYPE_RANGED",25)
local function Put(bag,slot,link)bags[bag]=bags[bag]or{};bags[bag][slot]=link end
Put(0,1,Item("helm-high","INVTYPE_HEAD",45,{quality=3}))
Put(0,2,Item("helm-low","INVTYPE_HEAD",30,{quality=0}))
Put(0,3,Item("helm-same","INVTYPE_HEAD",40))
Put(0,4,Item("ring-mid","INVTYPE_FINGER",40))
Put(0,5,Item("ring-poor","INVTYPE_FINGER",30))
Put(0,6,Item("trinket","INVTYPE_TRINKET",10))
Put(0,7,Item("potion","",5))
Put(0,8,Item("arrows","INVTYPE_AMMO",50))
Put(0,9,Item("shirt","INVTYPE_BODY",1))
Put(0,10,Item("tabard","INVTYPE_TABARD",1))
Put(0,11,Item("pouch","INVTYPE_BAG",20))
Put(0,12,Item("plate-chest","INVTYPE_CHEST",42,{armour="Plate",minLevel=40}))
Put(0,13,Item("sword","INVTYPE_WEAPON",35))
Put(0,14,Item("greatsword","INVTYPE_2HWEAPON",38))
Put(0,15,Item("shield","INVTYPE_SHIELD",28))
-- 0,16 is empty
Put(1,1,Item("gun","INVTYPE_RANGEDRIGHT",33))
Put(1,2,Item("libram","INVTYPE_RELIC",20))
Put(1,3,Item("cloak","INVTYPE_CLOAK",12))
Put(1,4,Item("quiver","INVTYPE_QUIVER",30))
Put(1,5,Item("broken-legs","INVTYPE_LEGS",44,{broken=true}))
Put(1,6,Item("knives","INVTYPE_THROWN",22))

local E={modules={},settings={enabled=true}}
function E:RegisterModule(name,m)self.modules[name]=m end
function E:GetSetting(key)return self.settings[key]end
assert(loadfile("Modules/BagItemLevels.lua"))("EraUI",E)
local M=E.modules.BagItemLevels
local W=E.settings

-- The mark on a button, if any, as the player sees it.
local marks={}
local function Mark(button)
 for _,f in ipairs(marks)do if f.parent==button then return f end end
end
local realCreate=CreateFrame
CreateFrame=function(kind,name,parent)
 local f=realCreate(kind,name,parent)
 if parent and backs[parent]then marks[#marks+1]=f end
 return f
end
local function Seen(button)
 local o=Mark(button);if not o or not o.shown then return nil end
 return {level=o.level.text,arrow=o.arrow.shown and(o.arrow.coords[3]==0 and "up"or "down")or nil,red=o.tint.shown,o=o}
end
local function Expect(button,level,arrow,red,label)
 local s=Seen(button)
 if level==nil then equal(s,nil,label.." shows no mark");return end
 equal(s and s.level,level,label.." item level")
 equal(s.arrow,arrow,label.." arrow")
 equal(s.red,red,label.." can't-equip tint")
end

-- Ships as Coming soon: inert even with the option saved on.
equal(M.comingSoon,true,"Bag Item Levels ships as Coming soon")
W.bagItemLevels=true
M:Initialize();M:Refresh();M:PaintAll()
equal(hooks,0,"coming soon: no bag window hooked")
equal(eventFrame,nil,"coming soon: no events")
ContainerFrame1:UpdateItems()
equal(#marks,0,"coming soon: nothing made on any bag button")
-- The rest of the suite runs the finished feature.
W.bagItemLevels=nil;M.comingSoon=false

-- Off by default: nothing hooked, no event frame, no marks.
M:Initialize()
equal(hooks,0,"off by default: no bag window hooked")
equal(eventFrame,nil,"off by default: no events")
equal(#marks,0,"off by default: nothing made on any bag button")
ContainerFrame1:UpdateItems()
equal(#marks,0,"a native bag update while off makes nothing")

-- Switched on: every bag window is hooked once and shown bags are painted.
W.bagItemLevels=true;M:Refresh()
equal(hooks,3,"each of the three bag windows hooked once")
M:Refresh();equal(hooks,3,"refreshing never hooks twice")
for _,e in ipairs({"PLAYER_EQUIPMENT_CHANGED","GET_ITEM_INFO_RECEIVED","PLAYER_LEVEL_UP","SKILL_LINES_CHANGED","SPELLS_CHANGED","UPDATE_FACTION"})do
 equal(eventFrame.events[e],true,"listens for "..e)
end
Expect(backpack[1],"45","up",false,"higher helm")
Expect(backpack[2],"30","down",false,"lower helm")
Expect(backpack[3],"40",nil,false,"same item level as worn")
Expect(backpack[4],"40","up",false,"ring above the weaker worn ring (35)")
Expect(backpack[5],"30","down",false,"ring below both worn rings")
Expect(backpack[6],"10","up",false,"trinket into an empty trinket slot")
Expect(backpack[7],nil,nil,nil,"potion")
Expect(backpack[8],nil,nil,nil,"ammo")
Expect(backpack[9],nil,nil,nil,"shirt")
Expect(backpack[10],nil,nil,nil,"tabard")
Expect(backpack[11],nil,nil,nil,"bag")
Expect(backpack[12],"42","up",false,"plate chest a trained warrior can wear")
Expect(backpack[16],nil,nil,nil,"empty slot")
equal(Seen(bag1[1]),nil,"a closed bag window is not painted")
-- Quality colours on the number.
equal(Seen(backpack[1]).o.level.textColour[3],.87,"rare item level in rare blue")
equal(Seen(backpack[2]).o.level.textColour[1],.62,"poor item level in poor grey")

-- The look: sized over the button, mouse-free, above it, arrow bottom left, level top right.
do
 local o=Seen(backpack[1]).o
 equal(o.all,backpack[1],"mark covers its button, sized at creation")
 equal(o.mouse,false,"mark never takes the mouse")
 equal(o.frameLevel>backs[backpack[1]].level,true,"mark drawn above the button")
 equal(o.tint.all,backs[backpack[1]].icon,"tint pinned to the icon only")
 equal(o.tint.blend,"MOD","tint multiplies the icon, like Classic's red can't-use icons")
 equal(o.tint.colour[1]==1 and o.tint.colour[2]<.2 and o.tint.colour[3]<.2,true,"tint is red")
 equal(o.arrow.texture,"Interface\\AddOns\\EraUI\\Media\\BagArrow.tga","arrow uses EraUI's own art")
 equal(o.level.points.TOPRIGHT~=nil,true,"item level top right")
 -- Blizzard's junk coin (JunkIcon, on grey items while a merchant is open) is
 -- TOPLEFT (1,0) on a 37px bag button; the stack count is BOTTOMRIGHT. The
 -- arrow keeps to the free bottom left, its top in the lower half.
 local at=o.arrow.points.BOTTOMLEFT
 equal(o.arrow.points.TOPLEFT,nil,"arrow clear of the junk coin's top left corner")
 equal(at and at[1]==o and at[2]=="BOTTOMLEFT"and at[4]>=0 and at[4]+o.arrow.h<=37/2,true,"arrow bottom left, in the lower half of the button")
 equal(at[3]>=0 and at[3]+o.arrow.w<=37/2,true,"and the left half, clear of the stack count")
 equal(o.level.template,"NumberFontNormal","item level in the game's stack-count font")
 equal(o.arrow.colour[2]==1 and o.arrow.colour[1]<.5,true,"up arrow green")
 local down=Seen(backpack[2]).o
 equal(down.arrow.coords[3]==1 and down.arrow.coords[4]==0,true,"down arrow is the art flipped")
 equal(down.arrow.colour[1]==1 and down.arrow.colour[2]<.5,true,"down arrow red")
end

-- Nothing written on, or changed in, Blizzard's buttons; only these keys read.
for key in pairs(reads)do
 equal(key=="GetBagID"or key=="GetID"or key=="GetFrameLevel"or key=="IsProtected"or key=="GetMatchesSearch"or key=="Icon"or key=="icon",true,"reads only where the button is and its icon: "..key)
end
for proxy,back in pairs(backs)do
 for _,key in ipairs({"icon","Count","JunkIcon","UpgradeIcon","IconBorder"})do
  if back[key].calls~=0 then equal(back[key].calls,0,"native "..key.." untouched")end
 end
end
equal(true,true,"no native region of any bag button changed")

-- Weapons.
Expect(backpack[13],"35","down",false,"one-hand sword vs main hand 40 (no dual wield)")
Expect(backpack[14],"38","down",false,"two-hander vs main hand 40")
Expect(backpack[15],"28","down",false,"shield vs off hand 30")
player.dual=true;Fire("PLAYER_EQUIPMENT_CHANGED");Flush()
Expect(backpack[13],"35","up",false,"dual wield: one-hander vs the weaker of 40 and 30")
worn[17]=Item("worn-buckler","INVTYPE_SHIELD",45);Fire("PLAYER_EQUIPMENT_CHANGED");Flush()
Expect(backpack[13],"35","down",false,"dual wield with a shield: one-hander vs main hand")
worn[16]=Item("worn-maul","INVTYPE_2HWEAPON",36);worn[17]=nil;Fire("PLAYER_EQUIPMENT_CHANGED");Flush()
Expect(backpack[13],"35","down",false,"one-hander vs a worn two-hander")
Expect(backpack[15],"28","down",false,"shield vs the two-hander that fills both hands")
Expect(backpack[14],"38","up",false,"two-hander vs worn two-hander")
worn[16]=nil;Fire("PLAYER_EQUIPMENT_CHANGED");Flush()
Expect(backpack[13],"35","up",false,"one-hander into empty hands")
worn[16]=Item("worn-dagger","INVTYPE_WEAPON",40);worn[17]=Item("worn-dirk","INVTYPE_WEAPONOFFHAND",30)
player.dual=false;Fire("PLAYER_EQUIPMENT_CHANGED");Flush()

-- The separate bag and One bag (the game's combined bags) both use each button's own bag.
ContainerFrame2.shown=true;ContainerFrame2:UpdateItems()
Expect(bag1[1],"33","up",false,"gun vs worn bow (ranged slot)")
Expect(bag1[2],"20","down",false,"libram vs the ranged/relic slot")
Expect(bag1[3],"12","up",false,"cloak into an empty back slot")
Expect(bag1[4],nil,nil,nil,"quiver")
Expect(bag1[5],"44","up",false,"a broken item: red durability line is not a can't-equip")
Expect(bag1[6],"22","down",false,"throwing knives vs the ranged slot")
ContainerFrame1.shown,ContainerFrame2.shown,ContainerFrameCombinedBags.shown=false,false,true
ContainerFrameCombinedBags:UpdateItems()
Expect(combined[1],"45","up",false,"One bag: backpack slot painted")
Expect(combined[17],"33","up",false,"One bag: second bag's slot painted from its own bag")
Expect(combined[21],"44","up",false,"One bag: broken item not tinted")
ContainerFrame1.shown,ContainerFrameCombinedBags.shown=true,false

-- A native update repaints only its own window, and follows moved items.
local count=#marks
Put(0,1,"helm-low");Put(0,2,"helm-high")
ContainerFrame1:UpdateItems()
Expect(backpack[1],"30","down",false,"moved item: new item level and arrow")
Expect(backpack[2],"45","up",false,"moved item: swapped mark")
Put(0,1,nil)
ContainerFrame1:UpdateItems()
Expect(backpack[1],nil,nil,nil,"item taken out of the bag")
Put(0,1,"helm-high");Put(0,2,"helm-low");ContainerFrame1:UpdateItems()
equal(#marks,count,"marks are reused, never made twice")

-- A bag search fades the marks of the items it leaves out, like the items.
equal(Seen(backpack[1]).o.alpha,1,"marks at full strength with no search")
backs[backpack[1]].matches=false;backs[backpack[2]].matches=true
Fire("INVENTORY_SEARCH_UPDATE");Flush()
equal(Seen(backpack[1]).o.alpha,.3,"left out by a search: mark faded")
equal(Seen(backpack[2]).o.alpha,1,"matching a search: mark stays clear")
backs[backpack[1]].matches=nil;backs[backpack[2]].matches=nil
Fire("INVENTORY_SEARCH_UPDATE");Flush()
equal(Seen(backpack[1]).o.alpha,1,"search cleared: full strength again")

-- Worn gear changes: arrows follow at once.
worn[1]=Item("worn-crown","INVTYPE_HEAD",50);Fire("PLAYER_EQUIPMENT_CHANGED")
Expect(backpack[1],"45","up",false,"waits for the queued repaint")
Flush()
Expect(backpack[1],"45","down",false,"new helm worn: bag helm now a downgrade")
worn[1]=Item("worn-head","INVTYPE_HEAD",40);Fire("PLAYER_EQUIPMENT_CHANGED");Flush()

-- Can't equip: the game's own tooltip check, following level and armour skills.
-- A level 39 warrior before plate: red plate chest, no arrow even though it's higher.
player.level=39;player.plate=false;player.class="WARRIOR"
Fire("PLAYER_LEVEL_UP");Flush()
Expect(backpack[12],"42",nil,true,"level 39 without plate: tinted red, no arrow")
-- Level 40, plate not trained yet: still red.
player.level=40;Fire("PLAYER_LEVEL_UP");Flush()
Expect(backpack[12],"42",nil,true,"level 40, plate not learned: still red")
-- Plate learned at the trainer: the game's check says yes, with no class table involved.
player.plate=true
ContainerFrame1:UpdateItems()
Expect(backpack[12],"42",nil,true,"cached until skills change (no rescan on every bag update)")
local before=tipCalls
Fire("SKILL_LINES_CHANGED");Flush()
Expect(backpack[12],"42","up",false,"plate learned: red gone, upgrade arrow back")
equal(tipCalls>before,true,"skills changing asks the game again")
-- The same for mail at 40 (hunters and shamans).
Put(0,16,Item("mail-legs","INVTYPE_LEGS",41,{armour="Mail",minLevel=40}))
player.mail=false;Fire("SPELLS_CHANGED");Flush()
Expect(backpack[16],"41",nil,true,"mail before it's learned: red")
player.mail=true;Fire("SKILL_LINES_CHANGED");Flush()
Expect(backpack[16],"41","up",false,"mail learned: usable")
-- Class-restricted and level-restricted gear.
items["helm-same"].class="PALADIN";Fire("SKILL_LINES_CHANGED");Flush()
Expect(backpack[3],"40",nil,true,"another class's item: red")
items["helm-same"].class=nil;items["helm-same"].minLevel=55;Fire("UPDATE_FACTION");Flush()
Expect(backpack[3],"40",nil,true,"too high a level: red")
items["helm-same"].minLevel=1;Fire("UPDATE_FACTION");Flush()
Expect(backpack[3],"40",nil,false,"requirements met: not red")

-- A tooltip still loading is not a verdict: no red, asked again once the item arrives.
items["ring-mid"].retrieving=true;Fire("SKILL_LINES_CHANGED");Flush()
Expect(backpack[4],"40","up",false,"tooltip still loading: no red mark")
items["ring-mid"].retrieving=nil;items["ring-mid"].class="PALADIN"
before=tipCalls;Fire("GET_ITEM_INFO_RECEIVED");Flush()
equal(tipCalls>before,true,"item info arriving repaints while something was loading")
Expect(backpack[4],"40",nil,true,"then the real verdict: red")
items["ring-mid"].class=nil;Fire("SKILL_LINES_CHANGED");Flush()
before=infoCalls;Fire("GET_ITEM_INFO_RECEIVED");Flush()
equal(infoCalls,before,"item info arriving does nothing when nothing was loading")

-- Tooltip hidden from addons, or missing: the game's usable-item check and the level.
items["helm-same"].secretTip=true;canUse["helm-same"]=false;Fire("SKILL_LINES_CHANGED");Flush()
Expect(backpack[3],"40",nil,true,"secret tooltip: the game's usable-item check says no")
canUse["helm-same"]=nil;Fire("SKILL_LINES_CHANGED");Flush()
Expect(backpack[3],"40",nil,false,"secret tooltip: usable-item check says yes")
items["helm-same"].minLevel=55;Fire("SKILL_LINES_CHANGED");Flush()
Expect(backpack[3],"40",nil,true,"secret tooltip: required level above yours")
items["helm-same"].minLevel=1;items["helm-same"].secretTip=nil
local tooltip=C_TooltipInfo;C_TooltipInfo=nil;canUse["helm-high"]=false;Fire("SKILL_LINES_CHANGED");Flush()
Expect(backpack[1],"45",nil,true,"no tooltip API: the usable-item check decides")
C_TooltipInfo=tooltip;canUse["helm-high"]=nil;Fire("SKILL_LINES_CHANGED");Flush()
Expect(backpack[1],"45","up",false,"tooltip back: its verdict wins")

-- Item data not cached yet: nothing shown, painted when it arrives.
Put(1,4,Item("new-boots","INVTYPE_FEET",19,{cached=false}))
ContainerFrame2.shown=true;ContainerFrame2:UpdateItems()
Expect(bag1[4],nil,nil,nil,"uncached boots: nothing yet")
items["new-boots"].cached=true;Fire("GET_ITEM_INFO_RECEIVED");Flush()
Expect(bag1[4],"19","up",false,"boots painted when their data arrives")
-- Worn item not cached: level shown, no arrow until it is.
items["worn-head"].cached=false;Fire("PLAYER_EQUIPMENT_CHANGED");Flush()
Expect(backpack[1],"45",nil,false,"worn helm unknown: no arrow")
items["worn-head"].cached=true;Fire("GET_ITEM_INFO_RECEIVED");Flush()
Expect(backpack[1],"45","up",false,"worn helm known: arrow back")

-- Secret values leave a slot unmarked and never error.
Put(0,5,SECRET);ContainerFrame1:UpdateItems()
Expect(backpack[5],nil,nil,nil,"secret bag item")
Put(0,5,"ring-poor")
local link=GetInventoryItemLink;GetInventoryItemLink=function(_,slot)if slot==1 then return SECRET end;return worn[slot]end
Fire("PLAYER_EQUIPMENT_CHANGED");Flush()
Expect(backpack[1],"45",nil,false,"secret worn helm: no arrow")
GetInventoryItemLink=link;Fire("PLAYER_EQUIPMENT_CHANGED");Flush()
local bagID=backs[backpack[6]].bag;backs[backpack[6]].bag=SECRET;ContainerFrame1:UpdateItems()
Expect(backpack[6],nil,nil,nil,"secret bag id")
backs[backpack[6]].bag=bagID;ContainerFrame1:UpdateItems()

-- In combat: bag buttons aren't protected, so marks paint at once; a
-- protected one would wait for combat to end.
Put(0,7,Item("gloves","INVTYPE_HAND",14))
combat=true;ContainerFrame1:UpdateItems();combat=false
Expect(backpack[7],"14","up",false,"painted in combat")
backs[bag1[4]].protected=true
local guarded=Button(1,4,{protected=true});ContainerFrame2.Items[4]=guarded
combat=true;ContainerFrame2:UpdateItems()
equal(Mark(guarded),nil,"never adds to a protected button in combat")
combat=false;Fire("PLAYER_REGEN_ENABLED");Flush()
Expect(guarded,"19","up",false,"marked once combat ends")

-- Switched off: every mark hidden at once, native updates make nothing, events stop.
count=#marks
W.bagItemLevels=false;M:Refresh()
for _,o in ipairs(marks)do if o.shown then equal(o.shown,false,"switched off: marks hidden")end end
equal(next(eventFrame.events),nil,"switched off: events stop")
ContainerFrame1:UpdateItems()
equal(Seen(backpack[1]),nil,"native updates keep them hidden while off")
equal(#marks,count,"and make nothing new")
W.bagItemLevels=true;M:Refresh()
Expect(backpack[1],"45","up",false,"switched on again: back at once")
equal(#marks,count,"toggling reuses the same marks")
equal(hooks,3,"and never hooks again")
W.enabled=false;M:Refresh()
equal(Seen(backpack[1]),nil,"EraUI turned off: no marks")
W.enabled=true;M:Refresh()

-- Coming soon again after it was on: every mark hidden, events stop, native
-- updates paint nothing.
M.comingSoon=true;M:Refresh()
equal(Seen(backpack[1]),nil,"coming soon: marks hidden")
equal(next(eventFrame.events),nil,"coming soon: events stop")
ContainerFrame1:UpdateItems()
equal(Seen(backpack[1]),nil,"coming soon: native updates paint nothing")
M.comingSoon=false;M:Refresh()
Expect(backpack[1],"45","up",false,"finished again: back at once")

-- Level up: asked again straight away and once more a moment later.
before=tipsFor["helm-high"];Fire("PLAYER_LEVEL_UP");Flush()
equal(tipsFor["helm-high"]-before,2,"level up asks the game twice (the new level can arrive late)")

-- Nothing ever written on a button (the proxies would have errored), final read check.
for key in pairs(reads)do
 equal(key=="GetBagID"or key=="GetID"or key=="GetFrameLevel"or key=="IsProtected"or key=="GetMatchesSearch"or key=="Icon"or key=="icon",true,"final: reads only "..key)
end
print("Bag item level checks passed: "..checks.." assertions.")
