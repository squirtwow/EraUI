-- Bag Item Levels on the real module. Blizzard's bag buttons are proxies that
-- log every key read and refuse every key write, so the checks prove the marks
-- never write on a bag button. Items, worn gear, tooltips and the game's
-- usable-item answer are all driven from one table per case. The look: a big
-- quality-coloured number bottom right, a small arrow top right, and a red
-- copy of the icon (normal blending, so it fades with the UI) for gear you
-- can't equip.
local checks=0
local function equal(got,want,label)
 checks=checks+1;assert(got==want,label..": expected "..tostring(want)..", got "..tostring(got))
end
local combat,made,timers,hooks=false,0,{},0
local reads={}
-- A hidden value: any read of it fails, as in the client.
local SECRET=setmetatable({},{__index=function()error("read a secret value")end})
-- A hidden number: the game says it is a number, but comparing or doing sums
-- with it fails.
local function Refuse()error("compared a secret number")end
local SECRET_NUMBER=setmetatable({},{__index=Refuse,__lt=Refuse,__le=Refuse,__add=Refuse,__sub=Refuse,__mul=Refuse,__div=Refuse,__concat=Refuse})
local rawType=type
type=function(v)if rawequal(v,SECRET_NUMBER)then return "number"end;return rawType(v)end
issecretvalue=function(v)return rawequal(v,SECRET)or rawequal(v,SECRET_NUMBER)end
InCombatLockdown=function()return combat end
C_Timer={After=function(_,fn)timers[#timers+1]=fn end}
local function Flush()
 for _=1,10 do if #timers==0 then return end;local list=timers;timers={};for _,fn in ipairs(list)do fn()end end
 error("timers did not settle")
end
hooksecurefunc=function(t,key,fn)
 local old=t[key];hooks=hooks+1;t[key]=function(...)old(...);fn(...)end
end
-- Our own frames, textures and font strings. A font string needs a font
-- before it can take text, as in the client; a refused font file leaves the
-- one it had.
local LILITA="Interface\\AddOns\\EraUI\\Media\\Fonts\\LilitaOne-Regular.ttf"
local FRIZ="Fonts\\FRIZQT__.TTF"
local refuse,blends,ignored,fontCalls={},{},0,0
local function Region(kind,parent,layer,template)
 local r={kind=kind,parent=parent,layer=layer,template=template,shown=true,points={},font=template}
 function r:SetAllPoints(to)self.all=to end
 function r:SetPoint(p,to,rp,x,y)self.points[p]={to,rp,x,y}end
 function r:SetSize(w,h)self.w,self.h=w,h end
 function r:SetTexture(t)self.texture=t end
 function r:SetBlendMode(m)self.blend=m;blends[#blends+1]=m end
 function r:SetVertexColor(a,b,c,d)self.colour={a,b,c,d or 1}end
 function r:SetTexCoord(...)self.coords={...}end
 function r:SetText(t)if not self.font then error("SetText on a font string with no font")end;self.text=t end
 function r:SetFont(file,size,flags)
  fontCalls=fontCalls+1
  if refuse[file]=="error"then error("not a valid font asset")elseif refuse[file]then return false end
  self.font,self.size,self.flags=file,size,flags;return true
 end
 function r:SetShadowColor(a,b,c,d)self.shadow={a,b,c,d}end
 function r:SetShadowOffset(x,y)self.shadowOffset={x,y}end
 function r:SetIgnoreParentAlpha(v)ignored=ignored+1;self.ignoreAlpha=v end
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
 return {hyperlink=it.link,quality=it.hide~="info"and it.hide~="both"and it.quality or nil,itemID=it.id,
  stackCount=it.stack or 1,iconFileID=not it.noIcon and 5000+it.id or nil,isLocked=it.locked or false}
end}
C_Item={
 GetItemInfoInstant=function(link)local it=items[link];if it then return it.id,"Armor","",it.loc,not it.noInstantIcon and 9000+it.id or nil,it.classID,it.subID end end,
 GetDetailedItemLevelInfo=function(link)local it=items[link];if it and it.cached then return it.level,false,it.level end end,
 GetItemInfo=function(link)local it=items[link];if it and it.cached then return it.link,it.link,it.hide~="both"and it.quality or nil,it.level,it.minLevel end end,
 GetItemQualityByID=function(id)for _,it in pairs(items)do if it.id==id then return it.quality end end end,
 -- Slightly off the table's values, so a check can tell which one was used.
 GetItemQualityColor=function(q)if q==3 then return .01,.45,.88,"ff0173e0"end;return 1,1,1,"ffffffff"end,
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
local QUALITY={[0]={r=.62,g=.62,b=.62},[1]={r=1,g=1,b=1},[2]={r=.12,g=1,b=0},[3]={r=0,g=.44,b=.87},[4]={r=.64,g=.21,b=.93}}
ITEM_QUALITY_COLORS=QUALITY

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
 local back={bag=bag,slot=slot,level=10,width=37,icon=Native(),Count=Native(),JunkIcon=Native(),UpgradeIcon=Native(),IconBorder=Native()}
 for k,v in pairs(extra or{})do back[k]=v end
 function back.GetBagID(self)return back.bag end
 function back.GetWidth(self)return back.width end
 -- The junk coin: shown by the game on grey items while a merchant is open.
 function back.JunkIcon.IsShown(self)if back.junk==nil then return false end;return back.junk end
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
for slot=1,10 do bag1[slot]=Button(1,slot)end
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
Put(1,7,Item("linen","",20,{stack=20,quality=1}))
Put(1,8,Item("stacked-knives","INVTYPE_THROWN",30,{stack=200}))
Put(1,9,Item("epic-ring","INVTYPE_FINGER",60,{quality=4}))
Put(1,10,Item("white-belt","INVTYPE_WAIST",8,{quality=1}))

local E={modules={},settings={enabled=true}}
function E:RegisterModule(name,m)self.modules[name]=m end
function E:GetSetting(key)return self.settings[key]end
assert(loadfile("Modules/BagItemLevels.lua"))("EraUI",E)
local M=E.modules.BagItemLevels
local W=E.settings

-- The mark on a button, if any, as the player sees it.
local marks={}
local function Mark(button)
 for _,f in ipairs(marks)do if f.parent==button and f.all==button then return f end end
end
local realCreate=CreateFrame
CreateFrame=function(kind,name,parent)
 local f=realCreate(kind,name,parent)
 if parent and backs[parent]then marks[#marks+1]=f end
 return f
end
local function Seen(button)
 local o=Mark(button);if not o or not o.shown then return nil end
 return {level=o.level.shown and o.level.text or nil,arrow=o.arrow.shown and(o.arrow.coords[3]==0 and "up"or "down")or nil,red=o.tint.shown,o=o}
end
-- What reaches the screen. UIParent's alpha (uiAlpha) reaches the marks
-- through their Blizzard bag button. A MOD texture multiplies what is behind
-- it whatever its alpha, so it is seen even with the whole UI faded out: the
-- red square left on the AFK screen.
local uiAlpha=1
local function Effective(r)
 local a=1
 while r do
  a=a*(r.alpha or 1)
  if r.ignoreAlpha then return a end
  local parent=r.parent
  if backs[parent]then return a*uiAlpha end
  r=parent
 end
 return a
end
local function Visible(r)
 local o=r
 while o and not backs[o]do if not o.shown then return false end;o=o.parent end
 return r.blend=="MOD"or Effective(r)>0
end
local function Near(a,b)return math.abs(a-b)<1e-6 end
local function Expect(button,level,arrow,red,label)
 local s=Seen(button)
 if level==nil then equal(s,nil,label.." shows no mark");return end
 equal(s and s.level,level,label.." item level")
 equal(s.arrow,arrow,label.." arrow")
 equal(s.red,red,label.." can't-equip tint")
end

-- Ships for testing: no longer Coming soon.
equal(M.comingSoon,false,"Bag Item Levels ships for testing, not Coming soon")
-- Coming soon, should it ever be switched back: inert even with the option saved on.
M.comingSoon=true
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
for _,e in ipairs({"PLAYER_EQUIPMENT_CHANGED","GET_ITEM_INFO_RECEIVED","PLAYER_LEVEL_UP","SKILL_LINES_CHANGED","SPELLS_CHANGED","UPDATE_FACTION","ITEM_LOCK_CHANGED"})do
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
-- Quality colours on the number, straight from the game's table.
local function Text(button)return Seen(button).o.level.textColour end
equal(Text(backpack[1])[1]==0 and Text(backpack[1])[2]==.44 and Text(backpack[1])[3]==.87,true,"rare item level in rare blue")
equal(Text(backpack[4])[1]==.12 and Text(backpack[4])[2]==1 and Text(backpack[4])[3]==0,true,"uncommon item level in green")
-- Poor grey, lifted a little so it reads on dark icons, and still a clear grey.
do
 local c=Text(backpack[2])
 equal(c[1]==c[2]and c[2]==c[3],true,"poor item level stays a neutral grey")
 equal(c[1]>.62 and c[1]<.8,true,"poor grey a little lighter than the game's .62, not white: "..c[1])
 equal(Near(c[1],.62+(1-.62)*.3),true,"poor grey lifted 30% toward white")
end

-- The look: sized over the button, mouse-free, above it; a big bold number
-- bottom right, a small arrow top right.
do
 local o=Seen(backpack[1]).o
 equal(o.all,backpack[1],"mark covers its button, sized at creation")
 equal(o.mouse,false,"mark never takes the mouse")
 equal(o.frameLevel>backs[backpack[1]].level,true,"mark drawn above the button")
 -- The number: EraUI's bold Lilita One, 14 on a 37 slot, a thick dark
 -- outline and a solid black shadow, right-justified in the bottom right.
 local n=o.level
 equal(n.font,LILITA,"item level in EraUI's bold Lilita One")
 equal(n.size,14,"item level size 14 on a normal 37 slot")
 equal(n.flags,"THICKOUTLINE","item level has a thick dark outline")
 equal(n.shadow[1]==0 and n.shadow[2]==0 and n.shadow[3]==0 and n.shadow[4]==1,true,"and a solid black shadow")
 equal(n.shadowOffset[1]==1 and n.shadowOffset[2]==-1,true,"a tight one-unit shadow down and to the right")
 equal(n.template~=nil,true,"made from a template, so it always has a font before its text")
 local at=n.points.BOTTOMRIGHT
 equal(at and at[1]==o and at[2]=="BOTTOMRIGHT",true,"item level anchored bottom right")
 equal(at[3]<=0 and at[3]>=-3 and at[4]>=0 and at[4]<=3,true,"tucked into the corner")
 equal(n.points.TOPRIGHT==nil and n.points.TOPLEFT==nil and n.points.BOTTOMLEFT==nil,true,"no other anchor")
 equal(n.justify,"RIGHT","right-justified, so 2 and 3 digits end at the same edge")
 equal(n.layer,"OVERLAY","item level drawn over the icon")
 -- The arrow: small, top right, in the corner the game leaves free.
 equal(o.arrow.texture,"Interface\\AddOns\\EraUI\\Media\\BagArrow.tga","arrow uses EraUI's own art")
 local a=o.arrow.points.TOPRIGHT
 equal(a and a[1]==o and a[2]=="TOPRIGHT"and a[3]<=0 and a[4]<=0,true,"arrow top right")
 equal(o.arrow.points.BOTTOMLEFT==nil and o.arrow.points.TOPLEFT==nil,true,"arrow clear of the junk coin's top left corner")
 equal(o.arrow.w,12,"arrow 12 on a normal slot: small")
 equal(o.arrow.w==o.arrow.h,true,"arrow square, never stretched")
 equal(-a[3]+o.arrow.w<=37/2 and -a[4]+o.arrow.h<=37/2,true,"arrow inside the top right quarter")
 -- The arrow's bottom stays above the number's top (its font size above its anchor).
 equal(37-(-a[4]+o.arrow.h)>at[4]+n.size,true,"arrow never touches the number")
 equal(o.arrow.colour[2]==1 and o.arrow.colour[1]<.5,true,"up arrow green")
 local down=Seen(backpack[2]).o
 equal(down.arrow.coords[3]==1 and down.arrow.coords[4]==0,true,"down arrow is the art flipped")
 equal(down.arrow.colour[1]==1 and down.arrow.colour[2]<.5,true,"down arrow red")
 equal(o.tint.shown,false,"no red icon on gear you can equip")
 equal(o.tint.layer,"ARTWORK","red icon drawn under the number and the arrow")
 equal(o.tint.parent==o and o.arrow.parent==o and n.parent==o,true,"every part is inside the mark, so fades with it")
end

-- Nothing written on, or changed in, Blizzard's buttons; only these keys read.
for key in pairs(reads)do
 equal(key=="GetBagID"or key=="GetID"or key=="GetFrameLevel"or key=="GetWidth"or key=="IsProtected"or key=="GetMatchesSearch"or key=="Icon"or key=="icon"or key=="JunkIcon",true,"reads only where the button is, its size, its icon and its junk coin: "..key)
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
Expect(bag1[7],nil,nil,nil,"a stack of cloth")
-- Stacked gear, should the game ever stack it: the game's stack count keeps
-- the bottom right, so no number there; the arrow still shows, top right.
do
 local s=Seen(bag1[8])
 equal(s~=nil and s.o.level.shown,false,"stacked throwing knives: no number over the stack count")
 equal(s.arrow,"up","stacked knives still get their arrow, top right")
 items["stacked-knives"].stack=SECRET_NUMBER;ContainerFrame2:UpdateItems()
 equal(Seen(bag1[8]).level,"30","a hidden stack count is never read, and never errors")
 items["stacked-knives"].stack=1;ContainerFrame2:UpdateItems()
 equal(Seen(bag1[8]).level,"30","a single one: its number back, bottom right")
 items["stacked-knives"].stack=200;ContainerFrame2:UpdateItems()
 equal(Seen(bag1[8]).level,nil,"stacked again: number gone")
end
Expect(bag1[9],"60","up",false,"epic ring above the weaker worn ring")
equal(Text(bag1[9])[1]==.64 and Text(bag1[9])[2]==.21 and Text(bag1[9])[3]==.93,true,"epic item level in epic purple")
Expect(bag1[10],"8","up",false,"common belt into an empty waist")
equal(Text(bag1[10])[1]==1 and Text(bag1[10])[2]==1 and Text(bag1[10])[3]==1,true,"common item level in white")
ContainerFrame1.shown,ContainerFrame2.shown,ContainerFrameCombinedBags.shown=false,false,true
ContainerFrameCombinedBags:UpdateItems()
Expect(combined[1],"45","up",false,"One bag: backpack slot painted")
Expect(combined[17],"33","up",false,"One bag: second bag's slot painted from its own bag")
Expect(combined[21],"44","up",false,"One bag: broken item not tinted")
equal(Seen(combined[1]).o.level.font==LILITA and Seen(combined[1]).o.level.size==14,true,"One bag: the same big number")
ContainerFrame1.shown,ContainerFrameCombinedBags.shown=true,false

-- Where the quality comes from: the bag's answer, else the item's info, else
-- its ID. The colour: the game's table (read when painting, so the game's
-- colour overrides apply), else its colour function; white when unknown.
local byID=C_Item.GetItemQualityByID;C_Item.GetItemQualityByID=nil
items["helm-high"].hide="info";ContainerFrame1:UpdateItems()
equal(Text(backpack[1])[3],.87,"quality missing from the bag: the item's info says rare")
items["helm-high"].hide="both";ContainerFrame1:UpdateItems()
equal(Text(backpack[1])[1]==1 and Text(backpack[1])[2]==1 and Text(backpack[1])[3]==1,true,"quality unknown: white")
C_Item.GetItemQualityByID=byID;ContainerFrame1:UpdateItems()
equal(Text(backpack[1])[3],.87,"missing from both: the item's ID says rare")
items["helm-high"].hide=nil
ITEM_QUALITY_COLORS=nil;ContainerFrame1:UpdateItems()
equal(Text(backpack[1])[1],.01,"no colour table: the game's colour function")
ITEM_QUALITY_COLORS={[3]={r=SECRET,g=SECRET,b=SECRET}};ContainerFrame1:UpdateItems()
equal(Text(backpack[1])[1],.01,"hidden colours are never read: the colour function instead")
ITEM_QUALITY_COLORS={[3]=SECRET};ContainerFrame1:UpdateItems()
equal(Text(backpack[1])[1],.01,"a hidden colour entry is never read either")
ITEM_QUALITY_COLORS={[3]={r=.2,g=.5,b=.9}};ContainerFrame1:UpdateItems()
equal(Text(backpack[1])[1],.2,"a rebuilt colour table is used at the next paint")
ITEM_QUALITY_COLORS=QUALITY;ContainerFrame1:UpdateItems()
equal(Text(backpack[1])[3],.87,"back to rare blue")

-- Sized to the slot: 14 and 12 on a normal 37 slot, scaled with a bigger or
-- smaller one; sized for 37 while the size is unknown or hidden.
do
 local back=backs[backpack[3]]
 local function Sizes()local o=Seen(backpack[3]).o;return o.level.size,o.arrow.w,o.level.font end
 local calls=fontCalls;ContainerFrame1:UpdateItems()
 equal(fontCalls,calls,"a repaint at the same size leaves the font alone")
 back.width=45;ContainerFrame1:UpdateItems()
 local t,a=Sizes();equal(t,17,"a 45 slot: size 17 number");equal(a,15,"and a 15 arrow")
 back.width=30;ContainerFrame1:UpdateItems()
 t,a=Sizes();equal(t,11,"a 30 slot: size 11 number");equal(a,10,"and a 10 arrow")
 back.width=20;ContainerFrame1:UpdateItems()
 t,a=Sizes();equal(t,9,"a tiny 20 slot: the number never drops below size 9");equal(a,6,"the arrow still scales")
 back.width=0;ContainerFrame1:UpdateItems()
 t,a=Sizes();equal(t==14 and a==12,true,"no size yet: sized for 37")
 back.width=SECRET_NUMBER;ContainerFrame1:UpdateItems()
 t,a=Sizes();equal(t==14 and a==12,true,"a hidden size is never read: sized for 37")
 -- Lilita One refused or erroring: the game's Friz Quadrata at the same size.
 refuse[LILITA]=true;back.width=40;ContainerFrame1:UpdateItems()
 local font;t,_,font=Sizes();equal(font,FRIZ,"Lilita One refused: Friz Quadrata");equal(t,15,"at the slot's size")
 equal(Seen(backpack[3]).o.level.flags,"THICKOUTLINE","still with the thick outline")
 refuse[LILITA]="error";back.width=41;ContainerFrame1:UpdateItems()
 t,_,font=Sizes();equal(font,FRIZ,"Lilita One erroring: Friz Quadrata, no error");equal(t,16,"size 16")
 refuse[FRIZ]=true;back.width=44;ContainerFrame1:UpdateItems()
 equal(Seen(backpack[3]).level,"40","both refused: the font it had, and the number still shows")
 refuse[LILITA],refuse[FRIZ]=nil,nil;back.width=37;ContainerFrame1:UpdateItems()
 t,a,font=Sizes();equal(t==14 and a==12 and font==LILITA,true,"back to Lilita One 14 and a 12 arrow")
end

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
-- The red icon: the item's own icon drawn again in red with normal blending,
-- just inside the slot's edge, so the quality border and the slot's frame show.
do
 local o=Seen(backpack[12]).o
 local t=o.tint
 local icon=backs[backpack[12]].icon
 equal(t.blend,"BLEND","red icon blends normally, never MOD")
 equal(t.texture,5000+items["plate-chest"].id,"red icon is the item's own icon")
 equal(t.colour[1]==1 and t.colour[2]<.2 and t.colour[3]<.2 and t.colour[4]==1,true,"tinted red, fully drawn")
 local tl,br=t.points.TOPLEFT,t.points.BOTTOMRIGHT
 equal(tl and tl[1]==icon and tl[2]=="TOPLEFT"and tl[3]==2 and tl[4]==-2,true,"red icon 2 inside the icon's top left")
 equal(br and br[1]==icon and br[2]=="BOTTOMRIGHT"and br[3]==-2 and br[4]==2,true,"and 2 inside its bottom right")
 equal(t.all,nil,"never over the whole slot, so the quality border stays")
 equal(Near(t.coords[1],2/37)and Near(t.coords[2],35/37)and Near(t.coords[3],2/37)and Near(t.coords[4],35/37),true,"its edges cut to match, so it lines up with the icon")
 equal(o.level.shown and o.level.text,"42","the number stays on top")
 -- No icon in the bag's answer: the item's icon from its info; none at all: a red wash.
 items["plate-chest"].noIcon=true;ContainerFrame1:UpdateItems()
 equal(t.texture,9000+items["plate-chest"].id,"icon missing from the bag: the item's icon instead")
 items["plate-chest"].noInstantIcon=true;ContainerFrame1:UpdateItems()
 equal(t.texture,"Interface\\Buttons\\WHITE8X8","no icon at all: a plain red wash")
 equal(t.colour[1]==1 and t.colour[4]==.5,true,"half see-through")
 equal(t.coords[1]==0 and t.coords[2]==1,true,"uncut")
 items["plate-chest"].noIcon=nil;items["plate-chest"].noInstantIcon=nil;ContainerFrame1:UpdateItems()
 equal(t.texture,5000+items["plate-chest"].id,"icon back")
 -- The game's junk coin (grey items, a merchant open) would be under the red
 -- icon: while it shows, the red icon stands aside and the number stays.
 backs[backpack[12]].junk=true;ContainerFrame1:UpdateItems()
 equal(t.shown,false,"junk coin shown: no red icon over it")
 equal(o.level.shown and o.level.text,"42","and the number stays")
 backs[backpack[12]].junk=nil;ContainerFrame1:UpdateItems()
 equal(t.shown,true,"merchant closed: red icon back")
 backs[backpack[12]].junk=SECRET;ContainerFrame1:UpdateItems()
 equal(t.shown,true,"a hidden answer about the coin is never read: red icon stays")
 backs[backpack[12]].junk=nil;ContainerFrame1:UpdateItems()
 -- Picked up onto the cursor: the game greys the icon on ITEM_LOCK_CHANGED
 -- alone (no bag update), so the red icon stands aside until it is put down.
 items["plate-chest"].locked=true;Fire("ITEM_LOCK_CHANGED")
 equal(t.shown,true,"waits for the queued repaint")
 Flush()
 equal(t.shown,false,"picked up: no red icon over the game's greyed-out one")
 equal(o.level.shown and o.level.text,"42","and the number stays")
 items["plate-chest"].locked=nil;Fire("ITEM_LOCK_CHANGED");Flush()
 equal(t.shown,true,"put down: red icon back")
 items["plate-chest"].locked=SECRET;Fire("ITEM_LOCK_CHANGED");Flush()
 equal(t.shown,true,"a hidden lock state is never read: red icon stays")
 items["plate-chest"].locked=nil;ContainerFrame1:UpdateItems()
 -- The cut follows the slot: a 45 slot cuts 2/45 off each edge.
 backs[backpack[12]].width=45;ContainerFrame1:UpdateItems()
 equal(Near(t.coords[1],2/45)and Near(t.coords[2],43/45)and Near(t.coords[3],2/45)and Near(t.coords[4],43/45),true,"a bigger slot: the cut scales with it")
 backs[backpack[12]].width=37;ContainerFrame1:UpdateItems()
 -- It fades with the interface: the AFK screen fades UIParent to nothing.
 local up=Seen(backpack[1]).o
 equal(Visible(t)and Visible(up.arrow)and Visible(up.level),true,"UI shown: red icon, arrow and number seen")
 uiAlpha=0
 equal(Visible(t),false,"UI faded out: the red icon goes too, no red square left on the AFK screen")
 equal(Visible(o.level)or Visible(up.arrow)or Visible(up.level),false,"and the numbers and arrows")
 uiAlpha=.5;equal(Effective(t),.5,"half faded UI: half faded red icon")
 uiAlpha=1;equal(Visible(t),true,"UI back: red icon back")
 -- And with a bag search.
 backs[backpack[12]].matches=false;Fire("INVENTORY_SEARCH_UPDATE");Flush()
 equal(Effective(t),.3,"left out by a search: the red icon fades with the item")
 equal(Effective(o.level),.3,"and its number")
 backs[backpack[12]].matches=nil;Fire("INVENTORY_SEARCH_UPDATE");Flush()
 equal(Effective(t),1,"search cleared: full red again")
 equal(ignored,0,"nothing in a mark ever ignores its parent's alpha")
end
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

-- Arrow Colour by Armour: off by default; on, an upgrade arrow on body armour
-- takes the armour's type, and every other arrow keeps its green or red.
do
 local enum={ItemClass={Weapon=2,Armor=4},ItemArmorSubclass={Generic=0,Cloth=1,Leather=2,Mail=3,Plate=4,Cosmetic=5,Shield=6}}
 local enumReads=0
 Enum=setmetatable({},{__index=function(_,key)enumReads=enumReads+1;return enum[key]end})
 local function Set(link,classID,subID)items[link].classID,items[link].subID=classID,subID end
 Set("helm-high",4,1);Set("gloves",4,2);Set("mail-legs",4,3);Set("plate-chest",4,4)
 Set("helm-low",4,4);Set("ring-mid",4,0);Set("cloak",4,1);Set("white-belt",4,0);Set("gun",2,3)
 local function Repaint()ContainerFrame1:UpdateItems();ContainerFrame2:UpdateItems()end
 local function Arrow(button)local c=Seen(button).o.arrow.colour;return {c[1],c[2],c[3]}end
 local function Same(a,b)return a[1]==b[1]and a[2]==b[2]and a[3]==b[3]end
 local function Is(button,want,label)
  equal(Seen(button)~=nil and Seen(button).arrow~=nil,true,label.." has an arrow")
  equal(Same(Arrow(button),want),true,label)
 end
 local ARMOUR_SET={backpack[1],backpack[7],backpack[16],backpack[12]}

 -- Off by default: every upgrade arrow green, the armour's type never looked up.
 equal(W.bagArrowArmourColour,nil,"Arrow Colour by Armour not set: off")
 Repaint()
 local green,red=Arrow(backpack[1]),Arrow(backpack[2])
 equal(green[2]==1 and green[1]<.5,true,"off: the up arrow is green")
 equal(red[1]==1 and red[2]<.5,true,"off: the down arrow is red")
 for _,button in ipairs(ARMOUR_SET)do Is(button,green,"off: armour stays green")end
 equal(enumReads,0,"off: the game's armour types are never read")
 local count=#marks

 -- Switched on: live, no new frames, each armour type its own colour.
 W.bagArrowArmourColour=true;M:Refresh()
 equal(#marks,count,"switching on makes nothing new")
 equal(Seen(backpack[1]).arrow,"up","cloth still points up")
 local cloth,leather,mail,plate=Arrow(backpack[1]),Arrow(backpack[7]),Arrow(backpack[16]),Arrow(backpack[12])
 equal(cloth[3]==1 and cloth[1]>cloth[2],true,"cloth arrow purple")
 equal(leather[1]==1 and leather[2]>leather[3],true,"leather arrow orange")
 equal(mail[3]==1 and mail[1]<mail[2],true,"mail arrow blue")
 equal(plate[1]>.8 and plate[2]>.8 and plate[3]>.8,true,"plate arrow silver")
 local all={cloth,leather,mail,plate,green,red}
 for i=1,#all do for j=i+1,#all do equal(Same(all[i],all[j]),false,"each arrow colour is its own: "..i.." and "..j)end end
 for i=1,4 do equal(all[i][1]>.85 and all[i][2]<.4,false,"an upgrade colour never reads as a downgrade's red")end

 -- A downgrade stays red, whatever it's made of.
 equal(Seen(backpack[2]).arrow,"down","plate helm below what you wear points down")
 Is(backpack[2],red,"a plate downgrade stays red")
 -- Everything else stays green: no type worth showing, or not armour at all.
 Is(backpack[4],green,"a ring stays green")
 Is(bag1[3],green,"a cloak stays green, though the game calls it cloth")
 Is(bag1[10],green,"a belt of no armour type stays green")
 Is(bag1[1],green,"a gun stays green, though its subclass number is mail's")
 for _,loc in ipairs({"INVTYPE_HEAD","INVTYPE_SHOULDER","INVTYPE_CHEST","INVTYPE_ROBE","INVTYPE_WAIST","INVTYPE_LEGS","INVTYPE_FEET","INVTYPE_WRIST","INVTYPE_HAND"})do
  Put(0,8,Item("mail-"..loc,loc,99,{classID=4,subID=3}));Repaint()
  Is(backpack[8],mail,loc.." takes the armour's colour")
 end
 for _,loc in ipairs({"INVTYPE_NECK","INVTYPE_FINGER","INVTYPE_TRINKET","INVTYPE_CLOAK","INVTYPE_SHIELD","INVTYPE_HOLDABLE","INVTYPE_RELIC"})do
  Put(0,8,Item("cloth-"..loc,loc,99,{classID=4,subID=1}));Repaint()
  Is(backpack[8],green,loc.." stays green, armour class or not")
 end
 Put(0,8,Item("weapon-one","INVTYPE_WEAPON",99,{classID=2,subID=1}));Repaint()
 Is(backpack[8],green,"a one-hander stays green")
 Put(0,8,Item("cosmetic-chest","INVTYPE_CHEST",99,{classID=4,subID=5}));Repaint()
 Is(backpack[8],green,"body armour of another type stays green")
 Put(0,8,Item("odd-chest","INVTYPE_CHEST",99,{classID=2,subID=1}));Repaint()
 Is(backpack[8],green,"a chest item the game doesn't call armour stays green")
 Put(0,8,"arrows");Repaint()
 Expect(backpack[8],nil,nil,nil,"ammo back: no mark")
 count=#marks -- the gear put in that slot needed a mark of its own

 -- Gear you can't equip still has no arrow to colour.
 items["plate-chest"].class="PALADIN";Fire("SKILL_LINES_CHANGED");Flush()
 Expect(backpack[12],"42",nil,true,"another class's plate: red icon, no arrow")
 items["plate-chest"].class=nil;Fire("SKILL_LINES_CHANGED");Flush()
 Is(backpack[12],plate,"usable again: its colour back")

 -- Hidden or missing answers: green, and never an error. Comparing a hidden
 -- value fails in game, so here any comparison with these answers fails too.
 local NO_COMPARE=setmetatable({},{__eq=Refuse})
 local armor,armorSubs=enum.ItemClass.Armor,enum.ItemArmorSubclass
 enum.ItemClass.Armor=NO_COMPARE
 enum.ItemArmorSubclass={Cloth=NO_COMPARE,Leather=NO_COMPARE,Mail=NO_COMPARE,Plate=NO_COMPARE}
 items["helm-high"].classID=SECRET_NUMBER;Repaint();Is(backpack[1],green,"hidden item class: never compared, green")
 enum.ItemClass.Armor=armor
 items["helm-high"].classID=4;items["helm-high"].subID=SECRET_NUMBER;Repaint();Is(backpack[1],green,"hidden armour type: never compared, green")
 enum.ItemArmorSubclass=armorSubs
 Set("helm-high",nil,nil);Repaint();Is(backpack[1],green,"no class or type from the game: green")
 Set("helm-high",4,1);Repaint();Is(backpack[1],cloth,"known again: cloth")
 local real=Enum
 Enum=nil;Repaint();Is(backpack[1],green,"no Enum: green")
 Enum={ItemClass={},ItemArmorSubclass={}};Repaint();Is(backpack[1],green,"Enum without these names: green")
 Enum=real;Repaint();Is(backpack[1],cloth,"Enum back: cloth")

 -- Off again: green at once, nothing new, nothing looked up.
 W.bagArrowArmourColour=false;M:Refresh()
 enumReads=0;Repaint()
 for _,button in ipairs(ARMOUR_SET)do Is(button,green,"switched off: back to green")end
 equal(enumReads,0,"switched off: the armour types aren't read")
 equal(#marks,count,"switching off makes nothing new")

 -- On, with Bag Item Levels off: nothing painted, hooked or looked up.
 W.bagArrowArmourColour=true;W.bagItemLevels=false;M:Refresh()
 enumReads=0;Repaint()
 equal(Seen(backpack[1]),nil,"Bag Item Levels off: no mark, whatever this says")
 equal(next(eventFrame.events),nil,"Bag Item Levels off: no events")
 equal(enumReads,0,"Bag Item Levels off: the armour types aren't read")
 equal(#marks,count,"Bag Item Levels off: nothing made")
 W.bagItemLevels=true;M:Refresh()
 Is(backpack[1],cloth,"Bag Item Levels back: the armour colour with it")
 W.bagArrowArmourColour=nil;M:Refresh()
 Enum=nil
end

-- Big Stack Numbers: the button's own count takes the item level's font on gear
-- and everything else, and gets its old font back.
do
 local OLD="Fonts\\ARIALN.TTF 14 OUTLINE"
 local BIG="Interface\\AddOns\\EraUI\\Media\\Fonts\\LilitaOne-Regular.ttf 14 THICKOUTLINE"
 for _,back in pairs(backs)do
  local c=back.Count
  c.font,c.fontSize,c.flags,c.setFont="Fonts\\ARIALN.TTF",14,"OUTLINE",0
  function c:GetFont()return self.font,self.fontSize,self.flags end
  function c:SetFont(file,size,flags)self.setFont=self.setFont+1;self.font,self.fontSize,self.flags=file,size,flags;return true end
 end
 -- The countdown takes a font object, from fonts the addon makes.
 local fontsMade=0
 CreateFont=function(name)
  fontsMade=fontsMade+1
  local f={name=name}
  function f:SetFont(file,size,flags)self.file,self.fontSize,self.flags=file,size,flags;return true end
  return f
 end
 for _,back in pairs(backs)do
  local text={font="Fonts\\FRIZQT__.TTF",fontSize=12,flags="OUTLINE"}
  function text:GetFont()return self.font,self.fontSize,self.flags end
  local clock={text=text,used=0}
  function clock:GetCountdownFontString()return self.text end
  function clock:SetCountdownFont(font)self.used=self.used+1;self.text.font,self.text.fontSize,self.text.flags=font.file,font.fontSize,font.flags end
  back.Cooldown=clock
 end
 local function Font(button)
  local c=backs[button].Count
  return c.font.." "..c.fontSize.." "..c.flags
 end
 local function Clock(button)
  local c=backs[button].Cooldown.text
  return c.font.." "..c.fontSize.." "..c.flags
 end
 local OLD_CLOCK="Fonts\\FRIZQT__.TTF 12 OUTLINE"
 local gear,potion=backpack[1],backpack[7]
 M:Refresh()
 equal(Font(gear).." / "..Font(potion),OLD.." / "..OLD,"off: the counts keep their font")
 equal(backs[potion].Count.setFont,0,"off: the count's font is never set")
 equal(backs[potion].Cooldown.used.." "..fontsMade.." "..Clock(potion),"0 0 "..OLD_CLOCK,"off: the countdown is never touched, no fonts made")

 W.bagBigCounts=true;M:Refresh()
 equal(Font(gear).." / "..Font(potion),BIG.." / "..BIG,"on: gear and a potion alike, live")
 equal(Clock(gear).." / "..Clock(potion),BIG.." / "..BIG,"on: the countdowns too")
 equal(fontsMade,1,"one font made for all of them")
 local clockUsed=backs[potion].Cooldown.used
 ContainerFrame1:UpdateItems()
 equal(backs[potion].Cooldown.used,clockUsed,"a repaint doesn't set the countdown's again")
 local set=backs[potion].Count.setFont
 ContainerFrame1:UpdateItems()
 equal(backs[potion].Count.setFont,set,"a repaint doesn't set it again")
 equal(backs[potion].Count.calls,0,"only the font changes: its text and showing stay the game's")

 backs[potion].width=74;ContainerFrame1:UpdateItems()
 equal(backs[potion].Count.fontSize,28,"a wider slot: a bigger number")
 backs[potion].width=37;ContainerFrame1:UpdateItems()

 W.bagBigCounts=false;M:Refresh()
 equal(Font(gear).." / "..Font(potion),OLD.." / "..OLD,"off again: the old font back")
 equal(Clock(gear).." / "..Clock(potion),OLD_CLOCK.." / "..OLD_CLOCK,"off again: the countdown's old font back")

 W.bagBigCounts=true;M:Refresh()
 equal(Font(potion),BIG,"on again")
 W.bagItemLevels=false;M:Refresh()
 equal(Font(potion),OLD,"Bag Item Levels off: the old font back too")
 W.bagItemLevels=true;M:Refresh()
 equal(Font(potion),BIG,"Bag Item Levels back: big again")

 -- Not yet big when a fight starts on a protected button: it waits for the fight to end.
 W.bagBigCounts=false;M:Refresh()
 W.bagBigCounts=true
 backs[potion].protected,combat=true,true
 ContainerFrame1:UpdateItems()
 equal(Font(potion).." / "..Clock(potion),OLD.." / "..OLD_CLOCK,"in a fight, a protected button: left alone")
 combat=false;Fire("PLAYER_REGEN_ENABLED");Flush()
 equal(Font(potion).." / "..Clock(potion),BIG.." / "..BIG,"after the fight: big")
 backs[potion].protected=nil

 -- A button with no countdown, and a countdown whose font can't be read: skipped.
 local clock=backs[potion].Cooldown
 W.bagBigCounts=false;M:Refresh()
 backs[potion].Cooldown=nil
 W.bagBigCounts=true;M:Refresh()
 equal(Font(potion),BIG,"no countdown on the button: its count still big")
 W.bagBigCounts=false;M:Refresh()
 backs[potion].Cooldown=clock
 local read=clock.GetCountdownFontString
 clock.GetCountdownFontString=function()error("no font string")end
 local before=clock.used
 W.bagBigCounts=true;M:Refresh()
 equal(clock.used,before,"a countdown that can't be read: left alone")
 clock.GetCountdownFontString=read
 W.bagBigCounts=false;M:Refresh()

 -- Never makes a bag update fail.
 local c=backs[potion].Count
 W.bagBigCounts=false;M:Refresh()
 local get=c.GetFont
 c.GetFont=function()error("no font")end
 W.bagBigCounts=true;M:Refresh()
 equal(c.font,"Fonts\\ARIALN.TTF","a font that can't be read: left alone")
 c.GetFont=get
 W.bagBigCounts=nil;M:Refresh()
 equal(Font(potion),OLD,"left as it was found")
end

-- Bag addons: fake versions of both routes, on fresh copies of the module (each
-- copy joins a bag addon once). Their buttons refuse every key write, as the
-- game's do above, and only a post-hook (hooksecurefunc) may touch them.
do
 local foreignReads,foreignHooks={},0
 local realHook=hooksecurefunc
 hooksecurefunc=function(t,key,fn)
  local back=backs[t]
  if not(back and back.foreign)then return realHook(t,key,fn)end
  foreignHooks=foreignHooks+1
  local old=back[key]
  back[key]=function(...)old(...);fn(...)end
 end
 local function Fresh(settings)
  local e={modules={},settings=settings or{enabled=true,bagItemLevels=true}}
  function e:RegisterModule(name,m)self.modules[name]=m end
  function e:GetSetting(key)return self.settings[key]end
  assert(loadfile("Modules/BagItemLevels.lua"))("EraUI",e)
  return e.modules.BagItemLevels,e.settings,e
 end
 local function Foreign(extra)
  local back={foreign=true,bag=7,slot=1,level=10,width=37,visible=true,icon=Native(),JunkIcon=Native(),scripts={}}
  for k,v in pairs(extra or{})do back[k]=v end
  function back.HookScript(_,script,fn)back.scripts[script]=fn end
  function back.GetID()return back.slot end
  function back.GetWidth()return back.width end
  function back.GetFrameLevel()return back.level end
  function back.IsProtected()return false end
  function back.IsVisible()return back.visible end
  function back.GetMatchesSearch()return back.matches end
  function back.JunkIcon.IsShown()return back.junk==true end
  local proxy=setmetatable({},{
   __index=function(_,key)foreignReads[key]=(foreignReads[key]or 0)+1;return back[key]end,
   __newindex=function(_,key)error("wrote "..tostring(key).." on a bag addon's button")end,
  })
  backs[proxy]=back
  return proxy,back
 end
 -- The API one bag addon offers: a list of its frames, corner widgets, a refresh.
 local function ListedAddon()
  local a={frames={},listeners={},widgets={},asked=0}
  a.addon={API={Skins={
   RegisterListener=function(fn)a.listeners[#a.listeners+1]=fn end,
   GetAllFrames=function()return a.frames end,
  },
   RegisterCornerWidget=function(label,id)a.widgets[#a.widgets+1]={label=label,id=id}end,
   RequestItemButtonsRefresh=function()a.asked=a.asked+1 end,
  }}
  -- A frame it makes: in its list, and told to its listeners.
  function a.Add(button,kind)
   local details={regionType=kind or "ItemButton",region=button}
   a.frames[#a.frames+1]=details
   for _,fn in ipairs(a.listeners)do fn(details)end
  end
  -- A corner widget it makes for a button: on a frame of its own there, or on the button.
  function a.Corner(button,plugin,flat)
   local parent=flat and button or {GetParent=function()return button end}
   local w=Region("FontString",parent);w.shown=false
   function w:GetParent()return self.parent end
   local details={regionType="CornerWidget",region=w,tags={plugin}}
   a.frames[#a.frames+1]=details
   for _,fn in ipairs(a.listeners)do fn(details)end
   return w
  end
  return a
 end
 -- Its corner loop: each widget in turn, stopping at the first that shows.
 local function Turn(corner,details)
  for _,e in ipairs(corner)do e.w:Hide()end
  for _,e in ipairs(corner)do
   if e.update(details)then e.w:Show();return e.w end
  end
 end
 local function ListedButton(bag,slot,extra)
  local proxy,back=Foreign(extra);back.bag,back.slot=bag,slot
  function back.GetBagID()return back.bag end
  function back.SetItemDetails()end
  function back.SetItemFiltered()end
  return proxy,back
 end
 -- The other: a grid of buttons with an update each, and no API for them.
 local function GridAddon()
  local group={Layout=function(self)self.laidOut=(self.laidOut or 0)+1 end}
  local a={ContainerGroup=group,registry={}}
  a.Frames={Iterate=function(self)return ipairs(a.registry)end}
  function a.NewGroup(buttons)return setmetatable({buttons=buttons},{__index=group})end
  return a
 end
 local function GridButton(bag,slot,extra)
  local proxy,back=Foreign(extra);back.bag,back.slot=bag,slot
  function back.GetBag()return back.bag end
  function back.IsCached()return back.cached end
  function back.Update()end
  return proxy,back
 end
 local function LoadedLater(name)
  eventFrame.handler(eventFrame,"ADDON_LOADED",name);Flush()
 end
 local function Armour()
  Enum={ItemClass={Weapon=2,Armor=4},ItemArmorSubclass={Generic=0,Cloth=1,Leather=2,Mail=3,Plate=4,Cosmetic=5,Shield=6}}
 end
 local function Colour(button)local c=Seen(button).o.arrow.colour;return c[1],c[2],c[3]end
 Put(7,1,Item("bag-helm","INVTYPE_HEAD",45,{quality=3,classID=4,subID=1}))
 Put(7,2,Item("bag-old-helm","INVTYPE_HEAD",30,{quality=0}))
 Put(7,3,Item("bag-potion","",5))
 Put(7,4,Item("bag-plate-helm","INVTYPE_HEAD",55,{classID=4,subID=4}))
 Put(7,5,Item("bag-paladin-helm","INVTYPE_HEAD",50,{class="PALADIN"}))
 local game=Mark(backpack[1])

 -- Neither addon loaded: nothing registered or hooked, and no error.
 Baganator,Bagnon=nil,nil
 do
  local m=Fresh();local before=foreignHooks
  m:Initialize();m:Refresh();m:PaintAll()
  equal(foreignHooks,before,"no bag addon: no button hooked")
  equal(eventFrame.events.ADDON_LOADED,true,"listens for a bag addon loading later")
  eventFrame.handler(eventFrame,"ADDON_LOADED","SomeOtherAddon");Flush()
  equal(foreignHooks,before,"another addon loading changes nothing")
 end

 -- A listed-frames addon loaded first: buttons it already made and buttons it makes later.
 local a=ListedAddon();Baganator=a.addon
 local early,earlyBack=ListedButton(7,1);a.Add(early)
 local notItem=ListedButton(7,2);a.Add(notItem,"Dialog")
 local cached,cachedBack=Foreign();function cachedBack.SetItemDetails()end;a.Add(cached) -- another character's: no bag ID
 local m,s=Fresh()
 m:Initialize()
 equal(#a.listeners,1,"joins that addon's list of frames, once")
 m:Refresh();equal(#a.listeners,1,"refreshing doesn't join twice")
 early:SetItemDetails({itemLink="bag-helm"})
 Expect(early,"45","up",false,"a button it made first: number and up arrow")
 local later=ListedButton(7,2);a.Add(later)
 later:SetItemDetails({itemLink="bag-old-helm"})
 Expect(later,"30","down",false,"a button it makes afterwards: number and down arrow")
 notItem:SetItemDetails({itemLink="bag-helm"})
 equal(Seen(notItem),nil,"only its item buttons")
 cached:SetItemDetails({itemLink="bag-helm"})
 equal(Seen(cached),nil,"never a button with no live bag behind it")

 -- The look: exactly the game's bag number and arrow, not that addon's smaller text.
 local function SameLook(button,label)
  local o=Seen(button).o
  for _,key in ipairs({"font","size","flags","justify","layer"})do
   equal(o.level[key],game.level[key],label..": number "..key)
  end
  equal(o.level.font,LILITA,label..": Lilita One")
  equal(o.level.size,14,label..": size 14")
  equal(o.level.flags,"THICKOUTLINE",label..": thick outline")
  equal(o.level.template,game.level.template,label..": same starting font")
  equal(o.level.shadow[4],game.level.shadow[4],label..": same shadow")
  equal(o.level.shadowOffset[1],game.level.shadowOffset[1],label..": same shadow offset")
  local n,gn=o.level.points.BOTTOMRIGHT,game.level.points.BOTTOMRIGHT
  equal(n[2],gn[2],label..": number's corner");equal(n[3],gn[3],label..": number x");equal(n[4],gn[4],label..": number y")
  equal(o.arrow.w,game.arrow.w,label..": arrow width");equal(o.arrow.h,game.arrow.h,label..": arrow height")
  equal(o.arrow.w,12,label..": arrow 12")
  equal(o.arrow.texture,game.arrow.texture,label..": EraUI's arrow art")
  local p,gp=o.arrow.points.TOPRIGHT,game.arrow.points.TOPRIGHT
  equal(p[2],gp[2],label..": arrow's corner");equal(p[3],gp[3],label..": arrow x");equal(p[4],gp[4],label..": arrow y")
  equal(o.all,button,label..": covers the button");equal(o.mouse,false,label..": never takes the mouse")
  equal(o.frameLevel-backs[button].level,game.frameLevel-backs[backpack[1]].level,label..": same level above the button")
 end
 SameLook(early,"listed button")

 -- Their bigger or smaller slots: scaled as a game slot of that width would be.
 earlyBack.width=45;early:SetItemDetails({itemLink="bag-helm"})
 equal(Seen(early).o.level.size,17,"a really bigger button: scaled like the game's");equal(Seen(early).o.arrow.w,15,"its arrow too")
 earlyBack.width=37;early:SetItemDetails({itemLink="bag-helm"})

 -- A reused button never keeps an old mark.
 local marksMade=#marks
 early:SetItemDetails({})
 equal(Seen(early),nil,"reused for an empty slot: cleared")
 earlyBack.slot=3;early:SetItemDetails({itemLink="bag-potion"})
 equal(Seen(early),nil,"reused for something that isn't gear: cleared")
 earlyBack.slot=2;early:SetItemDetails({itemLink="bag-old-helm"})
 Expect(early,"30","down",false,"reused for other gear: its own number and arrow")
 earlyBack.slot=9;early:SetItemDetails({itemLink="bag-old-helm"})
 equal(Seen(early),nil,"slot empty in the bag: cleared")
 -- Told it's empty while the bag still holds the item: nothing drawn over an empty button.
 earlyBack.slot=1;early:SetItemDetails({itemLink="bag-helm"})
 Expect(early,"45","up",false,"back on the helm")
 early:SetItemDetails({})
 equal(Seen(early),nil,"told it's showing nothing: cleared, even with an item still in the bag")
 early:SetItemDetails({itemLink="bag-helm"})
 equal(#marks,marksMade,"the mark is reused, never made twice")

 -- Several pieces drawn as one button: that addon's count sits where our number goes.
 early:SetItemDetails({itemLink="bag-helm",itemCount=2})
 equal(Seen(early).level,nil,"drawn as a group: no number over its count")
 equal(Seen(early).arrow,"up","the arrow stays")
 Fire("PLAYER_EQUIPMENT_CHANGED");Flush()
 equal(Seen(early).level,nil,"and a repaint doesn't bring the number back")
 early:SetItemDetails({itemLink="bag-helm",itemCount=1})
 Expect(early,"45","up",false,"back to one: the number returns")
 early:SetItemDetails({itemLink="bag-helm",itemCount=SECRET_NUMBER})
 Expect(early,"45","up",false,"a hidden count: treated as one")
 early:SetItemDetails({itemLink="bag-helm"})

 -- A secret item or slot: unmarked, and no error.
 Put(7,6,SECRET);earlyBack.slot=6;early:SetItemDetails({itemLink=SECRET})
 equal(Seen(early),nil,"a secret item: no mark")
 local real=earlyBack.bag;earlyBack.bag=SECRET;early:SetItemDetails({itemLink="bag-helm"})
 equal(Seen(early),nil,"a secret bag: no mark")
 earlyBack.bag=real;earlyBack.slot=1;early:SetItemDetails({itemLink="bag-helm"})

 -- A red icon for gear you can't equip, the same as on the game's bags.
 player.class="WARRIOR"
 local redButton=ListedButton(7,5);a.Add(redButton)
 redButton:SetItemDetails({itemLink="bag-paladin-helm"})
 Expect(redButton,"50",nil,true,"can't equip: red icon and no arrow")

 -- Search fading.
 earlyBack.matches=false;early:SetItemFiltered("x")
 equal(Seen(early).o.alpha,.3,"left out by its search: faded")
 earlyBack.matches=true;early:SetItemFiltered("")
 equal(Seen(early).o.alpha,1,"search cleared: full strength")

 -- Events repaint the buttons showing, and only those.
 local hidden,hiddenBack=ListedButton(7,1);a.Add(hidden);hiddenBack.visible=false
 worn[1]=Item("worn-crown","INVTYPE_HEAD",50)
 Fire("PLAYER_EQUIPMENT_CHANGED");Flush()
 Expect(early,"45","down",false,"worn gear changed: its arrow follows")
 equal(Seen(hidden),nil,"a hidden button isn't painted")
 worn[1]=Item("worn-head","INVTYPE_HEAD",40);Fire("PLAYER_EQUIPMENT_CHANGED");Flush()
 Expect(early,"45","up",false,"and back")
 hiddenBack.visible=SECRET;Fire("PLAYER_EQUIPMENT_CHANGED");Flush()
 equal(Seen(hidden),nil,"a hidden answer about showing: left alone")
 -- Item data arriving late, once the game has it.
 local slow=ListedButton(7,7);a.Add(slow)
 Put(7,7,Item("bag-slow-boots","INVTYPE_FEET",19,{cached=false}))
 slow:SetItemDetails({itemLink="bag-slow-boots"})
 equal(Seen(slow),nil,"data not there yet: nothing")
 items["bag-slow-boots"].cached=true;Fire("GET_ITEM_INFO_RECEIVED");Flush()
 Expect(slow,"19","up",false,"painted when it arrives")

 -- That addon's own smaller number stands aside on gear we number, and nothing else does.
 equal(#a.widgets,0,"adds nothing to that addon's own corner options")
 local pawn,coin=Region("Texture"),Region("Texture");pawn.shown,coin.shown=false,false
 local own=a.Corner(early,"item_level")
 local corner={{w=pawn,update=function(d)return d.upgrade end},{w=coin,update=function(d)return d.isJunk end},
  {w=own,update=function(d)return d.itemLink~=nil end}}
 equal(Turn(corner,{itemLink="bag-helm"}),own,"gear: its own number takes its turn as usual")
 equal(own.shown,false,"and is hidden, for ours")
 Turn(corner,{itemLink="bag-helm",upgrade=true})
 equal(pawn.shown,true,"a widget ranked ahead keeps its turn on gear")
 Turn(corner,{itemLink="bag-helm",isJunk=true})
 equal(coin.shown,true,"so does the junk coin")
 local apart={{w=own,update=function()return true end}}
 Turn(apart,{itemLink="bag-helm",isJunk=true})
 equal(own.shown,false,"poor gear in a corner with no coin: still only ours")
 earlyBack.slot=3;own:Show();equal(own.shown,true,"not gear: its own number stays")
 earlyBack.slot=9;own:Show();equal(own.shown,true,"an empty slot: stays")
 earlyBack.slot=6;own:Show();equal(own.shown,true,"a secret item: stays")
 earlyBack.slot=1;own:Show();equal(own.shown,false,"back on the helm: hidden")
 local flat=a.Corner(early,"item_level",true)
 flat:Show();equal(flat.shown,false,"right on the button: found too")
 local other=a.Corner(early,"pawn")
 other:Show();equal(other.shown,true,"its other widgets are never touched")
 local stranger=a.Corner(cached,"item_level")
 stranger:Show();equal(stranger.shown,true,"another character's bags: its own number stays")
 local bad=a.Corner(early,"item_level")
 function bad:GetParent()error("gone")end
 equal(pcall(bad.Show,bad),true,"an error hiding it never escapes")
 equal(bad.shown,true,"and it's left as it was")
 equal(pcall(a.listeners[1],{regionType="CornerWidget",tags={"item_level"}}),true,"a widget with no frame: no error")
 equal(pcall(a.listeners[1],{regionType="CornerWidget",region=own,tags="item_level"}),true,"odd tags: no error")

 -- Follows the option live: nothing shows while it's off.
 local asked=a.asked
 s.bagItemLevels=false;m:Refresh()
 equal(Seen(early),nil,"Bag Item Levels off: nothing on their buttons")
 equal(a.asked,asked+1,"that addon asked to run its corner widgets again")
 own:Show();equal(own.shown,true,"off: its own number comes back")
 early:SetItemDetails({itemLink="bag-helm"})
 equal(Seen(early),nil,"and its updates bring none back")
 s.bagItemLevels=true;m:Refresh()
 Expect(early,"45","up",false,"on again: back at once")
 own:Show();equal(own.shown,false,"on again: its own number hidden, no reload needed")
 equal(#a.listeners,1,"and never joined twice")
 s.enabled=false;m:Refresh();equal(Seen(early),nil,"EraUI off: nothing");s.enabled=true;m:Refresh()

 -- Arrow Colour by Armour, live on their buttons.
 Armour()
 local green={Colour(early)}
 equal(green[2]==1 and green[1]<.5,true,"colour option off: green")
 s.bagArrowArmourColour=true;m:Refresh()
 local cr,cg,cb=Colour(early)
 equal(cr==.78 and cg==.58 and cb==1,true,"colour option on: cloth purple on their button")
 local plate=ListedButton(7,4);a.Add(plate);plate:SetItemDetails({itemLink="bag-plate-helm"})
 local pr,pg,pb=Colour(plate)
 equal(pr==.86 and pg==.9 and pb==.96,true,"plate silver")
 local down=ListedButton(7,2);a.Add(down);down:SetItemDetails({itemLink="bag-old-helm"})
 equal(Seen(down).arrow,"down","a downgrade still points down")
 local dr,dg=Colour(down)
 equal(dr==1 and dg<.5,true,"and stays red")
 s.bagArrowArmourColour=nil;m:Refresh()
 equal(select(2,Colour(early)),1,"colour option off again: green")
 Enum=nil

 -- Big Stack Numbers on their buttons too.
 local number={font="Fonts\\ARIALN.TTF",fontSize=14,flags="OUTLINE"}
 function number:GetFont()return self.font,self.fontSize,self.flags end
 function number:SetFont(file,size,flags)self.font,self.fontSize,self.flags=file,size,flags;return true end
 local stacked=ListedButton(7,4,{Count=number});a.Add(stacked)
 stacked:SetItemDetails({itemLink="bag-plate-helm"})
 equal(number.font,"Fonts\\ARIALN.TTF","Big Stack Numbers off: their count's font left alone")
 s.bagBigCounts=true;m:Refresh()
 stacked:SetItemDetails({itemLink="bag-plate-helm"})
 equal(number.font.." "..number.fontSize.." "..number.flags,"Interface\\AddOns\\EraUI\\Media\\Fonts\\LilitaOne-Regular.ttf 14 THICKOUTLINE","Big Stack Numbers: their count in the big font")
 s.bagBigCounts=nil;m:Refresh()
 equal(number.font.." "..number.fontSize.." "..number.flags,"Fonts\\ARIALN.TTF 14 OUTLINE","off: their count's font back")

 -- Its window reopening with the bag unchanged runs no update of its own, so
 -- only showing fires here: what changed while it was closed is picked up then.
 do
  local shut,shutBack=ListedButton(7,1);a.Add(shut)
  local peer,peerBack=ListedButton(7,2);a.Add(peer)
  local function Close()shutBack.visible=false;peerBack.visible=false end
  local function Reopen()
   shutBack.visible=true;peerBack.visible=true
   shutBack.scripts.OnShow(shut);peerBack.scripts.OnShow(peer)
   equal(#timers,1,"reopening: one repaint for all its buttons")
   Flush()
  end
  shut:SetItemDetails({itemLink="bag-helm"});peer:SetItemDetails({itemLink="bag-old-helm"})
  Expect(shut,"45","up",false,"before closing")
  Close()
  worn[1]=Item("worn-crown","INVTYPE_HEAD",50);Fire("PLAYER_EQUIPMENT_CHANGED");Flush()
  Expect(shut,"45","up",false,"worn gear changed while closed: not painted yet")
  Reopen()
  Expect(shut,"45","down",false,"reopened: the arrow follows what you wear now")
  Close()
  worn[1]=Item("worn-head","INVTYPE_HEAD",40);Fire("PLAYER_EQUIPMENT_CHANGED");Flush()
  Reopen()
  Expect(shut,"45","up",false,"and back")
  -- Ticked while closed.
  Close()
  s.bagItemLevels=false;m:Refresh();equal(Seen(shut),nil,"option off while closed: cleared")
  s.bagItemLevels=true;m:Refresh();equal(Seen(shut),nil,"ticked while closed: a hidden button stays as it was")
  Reopen()
  Expect(shut,"45","up",false,"reopened after ticking: numbers back")
  -- Arrow colour changed while closed.
  Armour();Close()
  s.bagArrowArmourColour=true;m:Refresh()
  Reopen()
  local r,g,b=Colour(shut)
  equal(r==.78 and g==.58 and b==1,true,"colour option changed while closed: follows on reopening")
  Close();s.bagArrowArmourColour=nil;m:Refresh();Reopen();Enum=nil
  equal(select(2,Colour(shut)),1,"and back to green")
  -- A level gained while closed.
  Put(7,8,Item("bag-tall-helm","INVTYPE_HEAD",48,{minLevel=62}))
  local tall,tallBack=ListedButton(7,8);a.Add(tall)
  tall:SetItemDetails({itemLink="bag-tall-helm"})
  Expect(tall,"48",nil,true,"too high a level: red, no arrow")
  tallBack.visible=false
  player.level=62;Fire("PLAYER_LEVEL_UP");Flush()
  Expect(tall,"48",nil,true,"levelled up while closed: not painted yet")
  tallBack.visible=true;tallBack.scripts.OnShow(tall);Flush()
  Expect(tall,"48","up",false,"reopened: wearable now")
  player.level=60;Fire("PLAYER_LEVEL_UP");Flush()
  -- Off when it opens.
  Close();s.bagItemLevels=false;m:Refresh()
  Reopen();equal(Seen(shut),nil,"reopened with the option off: nothing")
  s.bagItemLevels=true;m:Refresh()
  Expect(shut,"45","up",false,"on again")
  -- A group stays a group on reopening.
  shut:SetItemDetails({itemLink="bag-helm",itemCount=2});Close();Reopen()
  equal(Seen(shut).level,nil,"a group reopened: still no number over its count")
  shut:SetItemDetails({itemLink="bag-helm"})
 end

 -- An error while painting never reaches the bag addon.
 local function Throws()error("painting failed")end
 local realInst=C_Item.GetItemInfoInstant
 C_Item.GetItemInfoInstant=Throws
 equal(pcall(early.SetItemDetails,early,{itemLink="bag-helm"}),true,"an API failing is caught")
 C_Item.GetItemInfoInstant=realInst
 local realGet=CreateFrame
 local fresh=ListedButton(7,1);a.Add(fresh)
 CreateFrame=function(kind,name,parent)if parent==fresh then error("no frames today")end;return realGet(kind,name,parent)end
 equal(pcall(fresh.SetItemDetails,fresh,{itemLink="bag-helm"}),true,"an error in painting never escapes into their update")
 equal(Seen(fresh),nil,"and that button simply has no mark")
 CreateFrame=realGet
 fresh:SetItemDetails({itemLink="bag-helm"})
 Expect(fresh,"45","up",false,"painted again once it can be")

 -- Its own number not in any corner: the buttons still painted.
 do
  local b=ListedAddon();Baganator=b.addon
  local button=ListedButton(7,1);b.Add(button)
  local m2=Fresh();m2:Initialize()
  button:SetItemDetails({itemLink="bag-helm"})
  Expect(button,"45","up",false,"still painted")
 end
 -- Loaded after EraUI: joins as it loads, a frame later.
 do
  Baganator=nil
  local m2=Fresh();m2:Initialize()
  local b=ListedAddon();Baganator=b.addon
  local button=ListedButton(7,1);b.Add(button)
  equal(#b.listeners,0,"nothing joined before it has loaded")
  LoadedLater("Baganator")
  equal(#b.listeners,1,"loaded after EraUI: joined")
  local theirs=b.Corner(button,"item_level")
  theirs:Show();equal(theirs.shown,false,"and its own number hidden")
  button:SetItemDetails({itemLink="bag-helm"})
  Expect(button,"45","up",false,"painted")
 end
 -- Off at login, ticked later: joins then, buttons it already made included.
 do
  local b=ListedAddon();Baganator=b.addon
  local button=ListedButton(7,1);b.Add(button)
  local theirs=b.Corner(button,"item_level")
  local m2,s2=Fresh({enabled=true,bagItemLevels=false});m2:Initialize()
  equal(#b.listeners,0,"Bag Item Levels off: nothing registered with it")
  theirs:Show();equal(theirs.shown,true,"off: its own number left alone")
  s2.bagItemLevels=true;m2:Refresh()
  equal(#b.listeners,1,"ticked: joined")
  theirs:Show();equal(theirs.shown,false,"its number already made: hidden too")
  button:SetItemDetails({itemLink="bag-helm"})
  Expect(button,"45","up",false,"its buttons painted")
 end
 -- API missing or changed: quietly nothing.
 for _,broken in ipairs({{},{API=false},{API={}},{API={Skins={}}},{API={Skins={RegisterListener=Refuse,GetAllFrames=Refuse}}}})do
  Baganator=broken
  local m2=Fresh()
  equal(pcall(m2.Initialize,m2),true,"a changed API: no error")
 end
 Baganator=nil

 -- The grid addon: no API, so a post-hook on its grid's layout and each button's update.
 local g=GridAddon();Bagnon=g
 local cell,cellBack=GridButton(7,1)
 local cellLow=GridButton(7,2)
 local off,offBack=GridButton(7,1,{cached=true})
 local group=g.NewGroup({cell,cellLow,off})
 local m3,s3=Fresh();m3:Initialize()
 local before=foreignHooks
 group:Layout()
 equal(group.laidOut,1,"its own layout still runs")
 equal(foreignHooks,before+3,"each button's update post-hooked once")
 Expect(cell,"45","up",false,"grid: number and up arrow")
 Expect(cellLow,"30","down",false,"grid: down arrow")
 equal(Seen(off),nil,"grid: another character's bags stay clear")
 SameLook(cell,"grid button")
 group:Layout();equal(foreignHooks,before+3,"a second layout never hooks again")
 -- Reused, moved and emptied.
 cellBack.slot=9;cell:Update();equal(Seen(cell),nil,"grid: an empty slot clears it")
 cellBack.slot=2;cell:Update();Expect(cell,"30","down",false,"grid: reused for other gear")
 cellBack.slot=3;cell:Update();equal(Seen(cell),nil,"grid: reused for something that isn't gear")
 cellBack.slot=1;cell:Update();Expect(cell,"45","up",false,"grid: back")
 cellBack.cached=true;cell:Update();equal(Seen(cell),nil,"grid: switched to another character")
 cellBack.cached=nil;cell:Update();Expect(cell,"45","up",false,"grid: and back")
 cellBack.cached=SECRET;cell:Update();equal(Seen(cell),nil,"grid: a hidden answer is never used");cellBack.cached=nil;cell:Update()
 -- Search: that addon fades the whole button, so a mark needn't.
 equal(Seen(cell).o.alpha,1,"grid: no search of ours")
 -- Option, colour, and errors.
 s3.bagItemLevels=false;m3:Refresh()
 equal(Seen(cell),nil,"grid: option off clears it")
 cell:Update();equal(Seen(cell),nil,"grid: and updates bring none back")
 s3.bagItemLevels=true;m3:Refresh()
 Expect(cell,"45","up",false,"grid: on again")
 Armour();s3.bagArrowArmourColour=true;m3:Refresh()
 local r2,g2,b2=Colour(cell)
 equal(r2==.78 and g2==.58 and b2==1,true,"grid: colour option honoured")
 s3.bagArrowArmourColour=nil;m3:Refresh();Enum=nil
 local failing,failingBack=GridButton(7,1)
 local failGroup=g.NewGroup({failing})
 failGroup:Layout()
 local realMake=CreateFrame
 local brand=GridButton(7,2);failGroup.buttons[2]=brand
 CreateFrame=function(kind,name,parent)if parent==brand then error("no frames today")end;return realMake(kind,name,parent)end
 equal(pcall(failGroup.Layout,failGroup),true,"grid: an error while painting never escapes its layout")
 equal(pcall(brand.Update,brand),true,"grid: nor its update")
 CreateFrame=realMake
 brand:Update();Expect(brand,"30","down",false,"grid: fine once it can draw")
 equal(pcall(group.Layout,setmetatable({buttons="not a list"},{__index=g.ContainerGroup})),true,"grid: an odd layout is ignored")
 -- Built before EraUI joined: picked up straight away, from its list of windows.
 do
  local h=GridAddon();Bagnon=h
  local early2=GridButton(7,1)
  local built=h.NewGroup({early2})
  h.registry[1]={id="plain"}
  h.registry[2]={ItemGroup=built}
  local m4=Fresh();m4:Initialize()
  Expect(early2,"45","up",false,"grid: a window already built")
 end
 -- Loaded after EraUI.
 do
  Bagnon=nil
  local m4=Fresh();m4:Initialize()
  local h=GridAddon();Bagnon=h
  local b1=GridButton(7,1)
  local built=h.NewGroup({b1})
  LoadedLater("Bagnon")
  built:Layout()
  Expect(b1,"45","up",false,"grid loaded after EraUI: painted")
 end
 -- Layout hook only on its containers' grid; a changed API is quiet.
 for _,broken in ipairs({{},{ContainerGroup={}},{ContainerGroup={Layout=1}}})do
  Bagnon=broken
  local m4=Fresh()
  equal(pcall(m4.Initialize,m4),true,"grid with a changed API: no error")
 end
 Bagnon=nil
 hooksecurefunc=realHook
 for key in pairs(foreignReads)do
  local allowed={GetBagID=1,GetID=1,GetBag=1,IsCached=1,GetWidth=1,GetFrameLevel=1,IsProtected=1,IsVisible=1,GetMatchesSearch=1,
   Icon=1,icon=1,JunkIcon=1,SetItemDetails=1,SetItemFiltered=1,Update=1,HookScript=1,Count=1,Cooldown=1}
  equal(allowed[key],1,"reads only what it needs from their buttons: "..key)
 end
end

-- Nothing ever written on a button (the proxies would have errored), final read
-- check. Count and Cooldown: only with Big Bag Numbers on (the first read check, before it, has neither).
for key in pairs(reads)do
 equal(key=="GetBagID"or key=="GetID"or key=="GetFrameLevel"or key=="GetWidth"or key=="IsProtected"or key=="GetMatchesSearch"or key=="Icon"or key=="icon"or key=="JunkIcon"or key=="Count"or key=="Cooldown",true,"final: reads only "..key)
end
-- Normal blending only: MOD ignores alpha, so it would stay on screen with the
-- UI faded out. (Tools/TestBlendModes.mjs checks the whole addon's source.)
equal(#blends>0,true,"blend modes were set")
for _,m in ipairs(blends)do if m~="BLEND"then equal(m,"BLEND","every texture in a mark blends normally")end end
print("Bag item level checks passed: "..checks.." assertions.")
