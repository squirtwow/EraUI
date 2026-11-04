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
 GetItemInfoInstant=function(link)local it=items[link];if it then return it.id,"Armor","",it.loc,not it.noInstantIcon and 9000+it.id or nil end end,
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

-- Nothing ever written on a button (the proxies would have errored), final read check.
for key in pairs(reads)do
 equal(key=="GetBagID"or key=="GetID"or key=="GetFrameLevel"or key=="GetWidth"or key=="IsProtected"or key=="GetMatchesSearch"or key=="Icon"or key=="icon"or key=="JunkIcon",true,"final: reads only "..key)
end
-- Normal blending only: MOD ignores alpha, so it would stay on screen with the
-- UI faded out. (Tools/TestBlendModes.mjs checks the whole addon's source.)
equal(#blends>0,true,"blend modes were set")
for _,m in ipairs(blends)do if m~="BLEND"then equal(m,"BLEND","every texture in a mark blends normally")end end
print("Bag item level checks passed: "..checks.." assertions.")
