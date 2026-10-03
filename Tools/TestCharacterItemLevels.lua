-- Character Item Levels on the real module, with Bag Item Levels' real module
-- beside it (it shares that module's reading and look). Blizzard's character
-- slots are proxies that log every key read and refuse every key write, so
-- the checks prove nothing is written on a slot button. The game's own slot
-- repaint (PaperDollItemSlotButton_Update) is a global the module post-hooks.
-- Worn gear is driven from one table. No Classic character sheet is loaded:
-- this is Blizzard's own window; the Classic sheet's changes to the slots
-- (moved, gear-slot art faded) are made by hand further down.
local checks=0
local function equal(got,want,label)
 checks=checks+1;assert(got==want,label..": expected "..tostring(want)..", got "..tostring(got))
end
local combat,timers,globalHooks,methodHooks=false,{},0,0
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
-- A global hook (by name) or a method hook, as the client runs them: the
-- original first, then ours.
hooksecurefunc=function(a,b,c)
 if rawType(a)=="string"then
  globalHooks=globalHooks+1
  local old=_G[a];_G[a]=function(...)old(...);b(...)end
 else
  methodHooks=methodHooks+1
  local old=a[b];a[b]=function(...)old(...);c(...)end
 end
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
 function r:SetBlendMode(m)blends[#blends+1]=m;self.blend=m end
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
local frames,eventFrames,unknownEvents,textures={},{},{},0
CreateFrame=function(kind,name,parent)
 local f=Region("Frame",parent)
 f.events={}
 function f:EnableMouse(v)self.mouse=v end
 function f:SetFrameLevel(l)self.frameLevel=l end
 function f:CreateTexture(_,layer)textures=textures+1;return Region("Texture",self,layer)end
 function f:CreateFontString(_,layer,template)return Region("FontString",self,layer,template)end
 function f:SetScript(_,fn)self.handler=fn;eventFrames[#eventFrames+1]=self end
 -- A build without an event refuses it, as the client does.
 function f:RegisterEvent(e)if unknownEvents[e]then error('Attempt to register unknown event "'..e..'"')end;self.events[e]=true end
 function f:UnregisterAllEvents()self.events={}end
 frames[#frames+1]=f
 return f
end
local function Fire(event)for _,f in ipairs(eventFrames)do if f.events[event]then f.handler(f,event)end end end

-- The game: items by link, worn gear by inventory slot.
local items,lastID={},0
local function Item(link,level,extra)
 lastID=lastID+1
 local it={link=link,id=lastID,loc="INVTYPE_HEAD",level=level,detail=level,quality=2,cached=true}
 for k,v in pairs(extra or{})do it[k]=v end
 items[link]=it;return link
end
C_Item={
 GetItemInfoInstant=function(link)local it=items[link];if it then return it.id,"Armor","",it.loc,9000+it.id end end,
 -- The item level the game reports for this very item: what both modules read first.
 GetDetailedItemLevelInfo=function(link)local it=items[link];if it and it.cached then return it.detail,false,it.level end end,
 GetItemInfo=function(link)local it=items[link];if it and it.cached then return it.link,it.link,it.quality,it.level,1 end end,
 -- Slightly off the table's values, so a check can tell which one was used.
 GetItemQualityColor=function(q)if q==3 then return .01,.45,.88,"ff0173e0"end;return 1,1,1,"ffffffff"end,
}
local worn,linkReads={},{}
GetInventoryItemLink=function(_,slot)linkReads[slot]=(linkReads[slot]or 0)+1;return worn[slot]end
-- The quality the slot's own border shows (SetItemButtonQuality in the game's repaint).
GetInventoryItemQuality=function(_,slot)
 local it=items[worn[slot]];if not it then return nil end
 if it.border=="none"then return nil end
 if it.border~=nil then return it.border end
 return it.quality
end
GetInventoryItemCount=function(_,slot)local it=items[worn[slot]];if not it then return 0 end;return it.stack or 1 end
UnitLevel=function()return 60 end
CanDualWield=function()return false end
local QUALITY={[0]={r=.62,g=.62,b=.62},[1]={r=1,g=1,b=1},[2]={r=.12,g=1,b=0},[3]={r=0,g=.44,b=.87},[4]={r=.64,g=.21,b=.93}}
ITEM_QUALITY_COLORS=QUALITY

-- Blizzard's character slots, as named in the game's PaperDollFrame.xml, and
-- their inventory slots. Only the proxy is handed to the addon. The game sets
-- the gear-slot art's frame (BorderFrame) 2 under the slot, and the cooldown
-- is 1 over it.
local SLOT_IDS={CharacterHeadSlot=1,CharacterNeckSlot=2,CharacterShoulderSlot=3,CharacterShirtSlot=4,
 CharacterChestSlot=5,CharacterWaistSlot=6,CharacterLegsSlot=7,CharacterFeetSlot=8,CharacterWristSlot=9,
 CharacterHandsSlot=10,CharacterFinger0Slot=11,CharacterFinger1Slot=12,CharacterTrinket0Slot=13,
 CharacterTrinket1Slot=14,CharacterBackSlot=15,CharacterMainHandSlot=16,CharacterSecondaryHandSlot=17,
 CharacterRangedSlot=18,CharacterTabardSlot=19,CharacterAmmoSlot=0}
local ALL={}
for name in pairs(SLOT_IDS)do ALL[#ALL+1]=name end
table.sort(ALL)
local function Native(level)
 local n={calls=0,level=level}
 for _,m in ipairs({"Show","Hide","SetShown","SetAtlas","SetTexture","SetVertexColor","SetText","SetAlpha","SetPoint","SetFrameLevel"})do
  n[m]=function(self)self.calls=self.calls+1 end
 end
 return n
end
local backs,before={},{}
for _,name in ipairs(ALL)do
 local back={id=SLOT_IDS[name],level=101,width=37}
 back.icon,back.IconBorder,back.Count=Native(),Native(),Native()
 back.BorderFrame,back.Cooldown,back.popoutButton=Native(99),Native(102),Native(98)
 function back.GetID()return back.id end
 function back.GetName()return name end
 function back.GetFrameLevel()return back.level end
 function back.GetWidth()return back.width end
 function back.IsProtected()return back.protected==true end
 local proxy=setmetatable({},{
  __index=function(_,key)reads[key]=(reads[key]or 0)+1;return back[key]end,
  __newindex=function(_,key)error("wrote "..tostring(key).." on a Blizzard character slot")end,
 })
 backs[proxy]=back
 local keys={};for k in pairs(back)do keys[k]=true end;before[proxy]=keys
 _G[name]=proxy
end
-- The game's own repaint of one slot (on show, gear and bag changes).
local blizzard=0
PaperDollItemSlotButton_Update=function(button)blizzard=blizzard+1 end
local function Update(name)PaperDollItemSlotButton_Update(_G[name])end
-- Opening the window: every slot's OnShow repaints it.
local function Open()for _,name in ipairs(ALL)do Update(name)end end

-- Gear worn. The helm's own item level (41) differs from its base level
-- (40), so a check can tell which one is read. Legs and the second trinket
-- slot are empty.
worn[1]=Item("helm",40,{detail=41,quality=3})
worn[2]=Item("pendant",35,{quality=4,loc="INVTYPE_NECK"})
worn[3]=Item("spaulders",38,{loc="INVTYPE_SHOULDER"})
worn[4]=Item("shirt",1,{quality=1,loc="INVTYPE_BODY"})
worn[5]=Item("tunic",42,{quality=1,loc="INVTYPE_CHEST"})
worn[6]=Item("rope-belt",30,{quality=0,loc="INVTYPE_WAIST"})
worn[8]=Item("boots",33,{loc="INVTYPE_FEET"})
worn[9]=Item("bracers",31,{loc="INVTYPE_WRIST"})
worn[10]=Item("gloves",36,{loc="INVTYPE_HAND"})
worn[11]=Item("ring-a",50,{loc="INVTYPE_FINGER"})
worn[12]=Item("ring-b",35,{loc="INVTYPE_FINGER"})
worn[13]=Item("trinket",45,{quality=3,loc="INVTYPE_TRINKET"})
worn[15]=Item("cloak",28,{loc="INVTYPE_CLOAK"})
worn[16]=Item("sword",41,{loc="INVTYPE_WEAPON"})
worn[17]=Item("shield",39,{loc="INVTYPE_SHIELD"})
worn[18]=Item("bow",37,{loc="INVTYPE_RANGED"})
worn[19]=Item("tabard",20,{quality=1,loc="INVTYPE_TABARD"})
worn[0]=Item("arrows",25,{quality=1,loc="INVTYPE_AMMO",stack=1})

local E={modules={},settings={enabled=true}}
function E:RegisterModule(name,m)self.modules[name]=m end
function E:GetSetting(key)return self.settings[key]end
assert(loadfile("Modules/BagItemLevels.lua"))("EraUI",E)
assert(loadfile("Modules/CharacterItemLevels.lua"))("EraUI",E)
local C,B=E.modules.CharacterItemLevels,E.modules.BagItemLevels
local W=E.settings

-- The mark on a slot, if any, as the player sees it.
local function Mark(button)
 for _,f in ipairs(frames)do if rawequal(f.parent,button)then return f end end
end
local function Seen(name)
 local o=Mark(_G[name]);if not o or not o.shown or not o.level.shown then return nil end
 return o.level.text,o.level.textColour,o
end
local function Expect(name,text,label)
 local got=Seen(name)
 equal(got,text,label)
end
local function Colour(name)local _,c=Seen(name);return c end
local function Near(a,b)return math.abs(a-b)<1e-6 end
local function Is(c,r,g,b)return c~=nil and Near(c[1],r)and Near(c[2],g)and Near(c[3],b)end
-- What reaches the screen: UIParent's alpha (uiAlpha) and the slot's own
-- reach a mark through its slot.
local uiAlpha=1
local function Effective(r)
 local a=1
 while r do
  a=a*(r.alpha or 1)
  if r.ignoreAlpha then return a end
  local parent=r.parent
  if backs[parent]then return a*(backs[parent].alpha or 1)*uiAlpha end
  r=parent
 end
 return a
end
-- Off by default: nothing hooked, no events, nothing made.
C:Initialize()
equal(globalHooks,0,"off by default: the game's slot repaint is not hooked")
equal(#eventFrames,0,"off by default: no events")
Open()
equal(#frames,0,"off by default: opening the window makes nothing")
equal(blizzard,#ALL,"the game's own repaint still runs")

-- Switched on: the game's repaint is hooked once and the slots painted at once.
W.characterItemLevels=true;C:Refresh()
equal(globalHooks,1,"the game's slot repaint hooked once")
C:Refresh();equal(globalHooks,1,"refreshing never hooks twice")
equal(methodHooks,0,"no method hooked on any Blizzard frame")
local events=eventFrames[#eventFrames]
for _,e in ipairs({"PLAYER_EQUIPMENT_CHANGED","GET_ITEM_INFO_RECEIVED","PLAYER_REGEN_ENABLED","ITEM_DATA_LOAD_RESULT"})do
 equal(events.events[e],true,"listens for "..e)
end
Expect("CharacterHeadSlot","41","helm: its own item level, not its base level")
Expect("CharacterNeckSlot","35","neck")
Expect("CharacterShoulderSlot","38","shoulders")
Expect("CharacterChestSlot","42","chest")
Expect("CharacterWaistSlot","30","waist")
Expect("CharacterFeetSlot","33","feet")
Expect("CharacterWristSlot","31","wrists")
Expect("CharacterHandsSlot","36","hands")
Expect("CharacterFinger0Slot","50","first ring")
Expect("CharacterFinger1Slot","35","second ring")
Expect("CharacterTrinket0Slot","45","first trinket")
Expect("CharacterBackSlot","28","back")
Expect("CharacterMainHandSlot","41","main hand")
Expect("CharacterSecondaryHandSlot","39","off hand")
Expect("CharacterRangedSlot","37","ranged")
Expect("CharacterLegsSlot",nil,"empty legs: nothing")
Expect("CharacterTrinket1Slot",nil,"empty second trinket: nothing")
for _,name in ipairs({"CharacterShirtSlot","CharacterTabardSlot","CharacterAmmoSlot"})do
 equal(Mark(_G[name]),nil,name.." skipped: nothing made on it")
end
Open()
for _,name in ipairs({"CharacterShirtSlot","CharacterTabardSlot","CharacterAmmoSlot"})do
 equal(Mark(_G[name]),nil,name.." still skipped when the game repaints it")
end
equal(#frames,1+15,"one event frame and a mark on each of the 15 worn slots, no more")

-- Quality colours on the number, straight from the game's table.
equal(Is(Colour("CharacterHeadSlot"),0,.44,.87),true,"rare helm in rare blue")
equal(Is(Colour("CharacterNeckSlot"),.64,.21,.93),true,"epic pendant in epic purple")
equal(Is(Colour("CharacterShoulderSlot"),.12,1,0),true,"uncommon shoulders in green")
equal(Is(Colour("CharacterChestSlot"),1,1,1),true,"common tunic in white")
do
 local c=Colour("CharacterWaistSlot")
 equal(c[1]==c[2]and c[2]==c[3],true,"poor belt stays a neutral grey")
 equal(Near(c[1],.62+(1-.62)*.3),true,"poor grey lifted 30% toward white, as in the bags")
end

-- The look: Bag Item Levels' own. Sized over the slot, mouse-free, above the
-- slot, its gear-slot art and its cooldown; a big bold number bottom right.
do
 local _,_,o=Seen("CharacterHeadSlot")
 local slot=_G.CharacterHeadSlot
 local back=backs[slot]
 equal(o.all,slot,"mark covers its slot, sized at creation")
 equal(rawequal(o.parent,slot),true,"mark is the slot's own child, so it moves with the slot")
 equal(rawequal(o.parent,back.BorderFrame),false,"never inside the gear-slot art's frame")
 equal(o.mouse,false,"mark never takes the mouse")
 equal(o.frameLevel>back.level,true,"mark drawn above the slot")
 equal(o.frameLevel>back.BorderFrame.level,true,"and above the gear-slot art")
 equal(o.frameLevel>back.Cooldown.level,true,"and above the cooldown swipe")
 local n=o.level
 equal(n.font,LILITA,"item level in EraUI's bold Lilita One")
 equal(n.size,14,"item level size 14 on a normal 37 slot")
 equal(n.flags,"THICKOUTLINE","item level has a thick dark outline")
 equal(n.shadow[1]==0 and n.shadow[2]==0 and n.shadow[3]==0 and n.shadow[4]==1,true,"and a solid black shadow")
 equal(n.shadowOffset[1]==1 and n.shadowOffset[2]==-1,true,"a tight one-unit shadow down and to the right")
 equal(n.template~=nil,true,"made from a template, so it always has a font before its text")
 local at=n.points.BOTTOMRIGHT
 equal(at and at[1]==o and at[2]=="BOTTOMRIGHT"and at[3]==-2 and at[4]==1,true,"item level tucked into the bottom right corner")
 equal(n.justify,"RIGHT","right-justified")
 equal(n.layer,"OVERLAY","drawn over everything in the mark")
 equal(n.parent,o,"inside the mark, so fades with it")
 equal(textures,0,"no texture at all: no arrow and no red tint on worn gear")
end

-- Nothing written on, or changed in, Blizzard's slots; only these keys read.
local function NothingWritten(label)
 for key in pairs(reads)do
  equal(key=="GetFrameLevel"or key=="GetWidth"or key=="IsProtected",true,label..": reads only the slot's level, size and protection: "..key)
 end
 for proxy,back in pairs(backs)do
  equal(next(proxy),nil,label..": no key on "..back.GetName())
  for key in pairs(back)do if not before[proxy][key]then equal(key,nil,label..": no new key on "..back.GetName())end end
  for _,key in ipairs({"icon","IconBorder","Count","BorderFrame","Cooldown","popoutButton"})do
   if back[key].calls~=0 then equal(back[key].calls,0,label..": native "..key.." of "..back.GetName().." untouched")end
  end
 end
end
NothingWritten("painted")

-- The game's repaint of one slot repaints only our mark on it.
worn[1]=Item("crown",50,{quality=4})
for k in pairs(linkReads)do linkReads[k]=nil end
Update("CharacterHeadSlot")
Expect("CharacterHeadSlot","50","the game repaints the head slot: new helm's number")
equal(Is(Colour("CharacterHeadSlot"),.64,.21,.93),true,"in its own quality colour")
local others=0;for slot in pairs(linkReads)do if slot~=1 then others=others+1 end end
equal(others,0,"only the repainted slot is read")
equal(linkReads[1],1,"once")
worn[1]=nil;Update("CharacterHeadSlot")
Expect("CharacterHeadSlot",nil,"helm taken off: nothing")
worn[1]="helm";Update("CharacterHeadSlot")
Expect("CharacterHeadSlot","41","helm back on")
local count=#frames
local stranger=setmetatable({},{__index=function()error("read a key of a button that isn't ours")end,__newindex=function()error("wrote on a button that isn't ours")end})
PaperDollItemSlotButton_Update(stranger);PaperDollItemSlotButton_Update(nil)
equal(#frames,count,"the game repainting another button (a bag slot) makes nothing and reads nothing")
equal(Mark(stranger),nil,"nothing on it")

-- Gear changes: all slots repainted on the next frame, window open or not.
worn[13]=Item("idol",52,{loc="INVTYPE_TRINKET"})
Fire("PLAYER_EQUIPMENT_CHANGED")
Expect("CharacterTrinket0Slot","45","waits for the queued repaint")
Flush()
Expect("CharacterTrinket0Slot","52","new trinket shown")
worn[13]="trinket";Fire("PLAYER_EQUIPMENT_CHANGED");Flush()

-- The game's colours: its table (read when painting, so its colour
-- overrides apply), else its colour function; white when unknown. The
-- quality: what the slot's border shows, else the item's own.
items.helm.border=4;Update("CharacterHeadSlot")
equal(Is(Colour("CharacterHeadSlot"),.64,.21,.93),true,"the quality the slot's border shows comes first")
items.helm.border="none";Update("CharacterHeadSlot")
equal(Is(Colour("CharacterHeadSlot"),0,.44,.87),true,"none from the slot: the item's own (rare)")
items.helm.border=SECRET_NUMBER;Update("CharacterHeadSlot")
equal(Is(Colour("CharacterHeadSlot"),0,.44,.87),true,"a hidden slot quality is never read: the item's own")
items.helm.border="none";items.helm.quality=nil;Update("CharacterHeadSlot")
equal(Is(Colour("CharacterHeadSlot"),1,1,1),true,"quality unknown: white")
items.helm.border=nil;items.helm.quality=3
ITEM_QUALITY_COLORS=nil;Update("CharacterHeadSlot")
equal(Near(Colour("CharacterHeadSlot")[1],.01),true,"no colour table: the game's colour function")
ITEM_QUALITY_COLORS={[3]=SECRET};Update("CharacterHeadSlot")
equal(Near(Colour("CharacterHeadSlot")[1],.01),true,"a hidden colour entry is never read")
ITEM_QUALITY_COLORS={[3]={r=.2,g=.5,b=.9}};Update("CharacterHeadSlot")
equal(Near(Colour("CharacterHeadSlot")[1],.2),true,"a rebuilt colour table is used at the next repaint")
ITEM_QUALITY_COLORS=QUALITY;Update("CharacterHeadSlot")
equal(Is(Colour("CharacterHeadSlot"),0,.44,.87),true,"back to rare blue")

-- Sized to the slot, like the bags: 14 on a normal 37 slot, scaled with it,
-- 37 while the size is unknown or hidden, Friz Quadrata if Lilita One is refused.
do
 local back=backs[_G.CharacterHeadSlot]
 local function Size()local _,_,o=Seen("CharacterHeadSlot");return o.level.size,o.level.font end
 local calls=fontCalls;Update("CharacterHeadSlot")
 equal(fontCalls,calls,"a repaint at the same size leaves the font alone")
 back.width=45;Update("CharacterHeadSlot");equal(Size(),17,"a 45 slot: size 17")
 back.width=20;Update("CharacterHeadSlot");equal(Size(),9,"never below size 9")
 back.width=0;Update("CharacterHeadSlot");equal(Size(),14,"no size yet: sized for 37")
 back.width=SECRET_NUMBER;Update("CharacterHeadSlot");equal(Size(),14,"a hidden size is never read: sized for 37")
 refuse[LILITA]=true;back.width=40;Update("CharacterHeadSlot")
 local size,font=Size();equal(font,FRIZ,"Lilita One refused: Friz Quadrata");equal(size,15,"at the slot's size")
 refuse[LILITA]=nil;back.width=37;Update("CharacterHeadSlot")
 size,font=Size();equal(size==14 and font==LILITA,true,"back to Lilita One 14")
end

-- Thrown weapons stack: that corner is the game's count, so no number there.
worn[18]=Item("throwing-knives",30,{loc="INVTYPE_THROWN",stack=200})
Update("CharacterRangedSlot")
Expect("CharacterRangedSlot",nil,"a stack of throwing knives: the game's count keeps the corner")
items["throwing-knives"].stack=1;Update("CharacterRangedSlot")
Expect("CharacterRangedSlot","30","a single one: its number")
items["throwing-knives"].stack=SECRET_NUMBER;Update("CharacterRangedSlot")
Expect("CharacterRangedSlot","30","a hidden count is never read, and never errors")
worn[18]="bow";Update("CharacterRangedSlot")
Expect("CharacterRangedSlot","37","bow back")

-- Item data not loaded yet: nothing, painted when it arrives.
worn[7]=Item("new-legs",44,{cached=false,loc="INVTYPE_LEGS"})
Update("CharacterLegsSlot")
Expect("CharacterLegsSlot",nil,"legs not loaded yet: nothing")
items["new-legs"].cached=true;Fire("GET_ITEM_INFO_RECEIVED")
Expect("CharacterLegsSlot",nil,"waits for the queued repaint")
Flush()
Expect("CharacterLegsSlot","44","legs painted when their data arrives")
worn[15]=Item("new-cloak",29,{cached=false,loc="INVTYPE_CLOAK"});Update("CharacterBackSlot")
Expect("CharacterBackSlot",nil,"cloak not loaded yet: nothing")
items["new-cloak"].cached=true;Fire("ITEM_DATA_LOAD_RESULT");Flush()
Expect("CharacterBackSlot","29","and the newer item-data event paints it too")
for k in pairs(linkReads)do linkReads[k]=nil end
Fire("GET_ITEM_INFO_RECEIVED");Flush()
equal(next(linkReads),nil,"item data arriving does nothing when nothing was waiting")

-- Secret values leave a slot unmarked and never error.
local link=GetInventoryItemLink
GetInventoryItemLink=function(unit,slot)if slot==1 then linkReads[1]=(linkReads[1]or 0)+1;return SECRET end;return link(unit,slot)end
Update("CharacterHeadSlot")
Expect("CharacterHeadSlot",nil,"a hidden link: nothing")
local headReads=linkReads[1]
Fire("GET_ITEM_INFO_RECEIVED");Flush()
equal(linkReads[1],headReads,"a hidden link is not item data still loading: nothing waits on it")
GetInventoryItemLink=link;Update("CharacterHeadSlot")
Expect("CharacterHeadSlot","41","readable again: back")

-- In combat: the slots aren't protected, so marks paint at once; a
-- protected one would wait for combat to end.
worn[14]=Item("trinket-two",47,{loc="INVTYPE_TRINKET"})
combat=true;Update("CharacterTrinket1Slot");combat=false
Expect("CharacterTrinket1Slot","47","painted in combat")
worn[7]=nil;Update("CharacterLegsSlot")
do
 -- A slot that were protected would wait for the fight to end. Every slot
 -- here already has its mark, so a second copy of the module (listening to
 -- events only) shows the guard on first use.
 local legs=_G.CharacterLegsSlot
 local E3={modules={BagItemLevels=B},settings={enabled=true,characterItemLevels=true}}
 function E3:RegisterModule(name,m)self.modules[name]=m end
 function E3:GetSetting(key)return self.settings[key]end
 assert(loadfile("Modules/CharacterItemLevels.lua"))("EraUI",E3)
 local fresh=E3.modules.CharacterItemLevels
 local real=PaperDollItemSlotButton_Update;PaperDollItemSlotButton_Update=nil
 backs[legs].protected=true;worn[7]="new-legs"
 local first=#frames+1
 local function Made()local n,o=0;for i=first,#frames do if rawequal(frames[i].parent,legs)then n,o=n+1,frames[i]end end;return n,o end
 combat=true;fresh:Refresh()
 equal((Made()),0,"never adds to a protected slot in combat")
 combat=false;Fire("PLAYER_REGEN_ENABLED");Flush()
 local n,o=Made()
 equal(n,1,"marked once combat ends")
 equal(o and o.level.text,"44","with its number")
 PaperDollItemSlotButton_Update=real
 E3.settings.characterItemLevels=false;fresh:Refresh()
 equal(o.shown,false,"the copy switched off again")
 backs[legs].protected=nil;worn[7]=nil
end

-- It fades with the interface: the AFK screen fades UIParent to nothing.
do
 local _,_,o=Seen("CharacterHeadSlot")
 equal(Effective(o.level),1,"UI shown: the number seen")
 uiAlpha=0;equal(Effective(o.level),0,"UI faded out: the number goes too")
 uiAlpha=.5;equal(Effective(o.level),.5,"half faded UI: half faded number")
 uiAlpha=1
 equal(ignored,0,"nothing in a mark ignores its parent's alpha")
 equal(#blends,0,"no blend mode set: the number is plain text")
end

-- EraUI's Classic character window: it moves the slots and fades their
-- gear-slot art (BorderFrame). The marks go where the slots go and stay in view.
do
 for _,back in pairs(backs)do back.BorderFrame.alpha=0 end
 Open()
 for _,name in ipairs({"CharacterHeadSlot","CharacterFinger0Slot","CharacterMainHandSlot","CharacterRangedSlot"})do
  local text,_,o=Seen(name)
  equal(text~=nil,true,name.." still numbered with the Classic window")
  equal(o.all,_G[name],name.." still covers its moved slot")
  equal(Effective(o.level),1,name.." not faded with the slot's gear-slot art")
 end
 for _,back in pairs(backs)do back.BorderFrame.alpha=nil end
end
NothingWritten("after repaints")

-- The same number as Bag Item Levels weighs your bags against, in the same
-- look: a bag helm at the worn helm's own item level (41) gets no arrow, one
-- at its base level (40) a down arrow, while the head slot shows 41.
do
 local bagButtons={}
 local function BagButton(slot)
  local b={bag=0,slot=slot,level=10,width=37,icon={},JunkIcon={IsShown=function()return false end}}
  function b:GetBagID()return self.bag end
  function b:GetID()return self.slot end
  function b:GetFrameLevel()return self.level end
  function b:GetWidth()return self.width end
  function b:IsProtected()return false end
  function b:GetMatchesSearch()return nil end
  bagButtons[slot]=b
  return b
 end
 local bag={[1]=Item("bag-helm-41",41,{quality=3}),[2]=Item("bag-helm-40",40,{quality=3})}
 C_Container={GetContainerItemInfo=function(_,slot)
  local it=items[bag[slot]];if not it then return nil end
  return {hyperlink=it.link,quality=it.quality,itemID=it.id,stackCount=1,iconFileID=5000+it.id,isLocked=false}
 end}
 local window={Items={BagButton(1),BagButton(2)},shown=true}
 function window:IsShown()return self.shown end
 function window:EnumerateValidItems()local i=0;return function()i=i+1;if self.Items[i]then return i,self.Items[i]end end,self,0 end
 function window:UpdateItems()end
 ContainerFrame1=window
 W.bagItemLevels=true;B:Refresh()
 local function BagMark(b)for _,f in ipairs(frames)do if f.parent==b then return f end end end
 local same,lower=BagMark(bagButtons[1]),BagMark(bagButtons[2])
 Expect("CharacterHeadSlot","41","the head slot shows the helm's own item level")
 equal(same.level.text=="41"and same.arrow.shown==false,true,"a bag helm at 41: no arrow, so the bags weigh it against 41 too")
 equal(lower.level.text=="40"and lower.arrow.shown==true and lower.arrow.coords[3]==1,true,"a bag helm at 40: a down arrow")
 local _,_,o=Seen("CharacterHeadSlot")
 local a,b=o.level,same.level
 equal(a.font==b.font and a.size==b.size and a.flags==b.flags,true,"the same font, size and outline as the bags")
 equal(a.shadow[4]==b.shadow[4]and a.shadowOffset[1]==b.shadowOffset[1]and a.shadowOffset[2]==b.shadowOffset[2],true,"the same shadow")
 local pa,pb=a.points.BOTTOMRIGHT,b.points.BOTTOMRIGHT
 equal(pa[2]==pb[2]and pa[3]==pb[3]and pa[4]==pb[4]and a.justify==b.justify and a.layer==b.layer,true,"the same corner")
 equal(Is(a.textColour,b.textColour[1],b.textColour[2],b.textColour[3]),true,"the same rare blue")
 -- Bag Item Levels switched off: the character window's numbers stay.
 W.bagItemLevels=false;B:Refresh()
 equal(same.shown,false,"bag marks gone with Bag Item Levels off")
 Update("CharacterHeadSlot")
 Expect("CharacterHeadSlot","41","character numbers don't need Bag Item Levels on")
 ContainerFrame1=nil;C_Container=nil
end

-- Switched off: every mark hidden at once, the game's repaints make nothing,
-- events stop; on again: back at once with the same marks.
count=#frames
W.characterItemLevels=false;C:Refresh()
for _,name in ipairs(ALL)do equal(Seen(name),nil,"switched off: "..name.." hidden")end
equal(next(events.events),nil,"switched off: events stop")
Open()
for _,name in ipairs(ALL)do equal(Seen(name),nil,"the game's repaints keep "..name.." hidden while off")end
equal(#frames,count,"and make nothing new")
W.characterItemLevels=true;C:Refresh()
Expect("CharacterHeadSlot","41","switched on again: back at once")
Expect("CharacterNeckSlot","35","every slot")
equal(#frames,count,"toggling reuses the same marks")
equal(globalHooks,1,"and never hooks again")
W.enabled=false;C:Refresh()
equal(Seen("CharacterHeadSlot"),nil,"EraUI turned off: no marks")
Update("CharacterHeadSlot")
equal(Seen("CharacterHeadSlot"),nil,"and the game's repaint keeps it hidden")
W.enabled=true;C:Refresh()
Expect("CharacterHeadSlot","41","EraUI on again: back")

-- A build without the newer item-data event: the rest still listens.
unknownEvents.ITEM_DATA_LOAD_RESULT=true
W.characterItemLevels=false;C:Refresh();W.characterItemLevels=true
local ok=pcall(C.Refresh,C)
equal(ok,true,"an unknown event never stops the switch")
equal(events.events.PLAYER_EQUIPMENT_CHANGED==true and events.events.GET_ITEM_INFO_RECEIVED==true,true,"the other events still heard")
unknownEvents.ITEM_DATA_LOAD_RESULT=nil

-- Pieces missing: no game repaint to hook yet, or Bag Item Levels not loaded.
do
 local E2={modules={},settings={enabled=true,characterItemLevels=true}}
 function E2:RegisterModule(name,m)self.modules[name]=m end
 function E2:GetSetting(key)return self.settings[key]end
 local real=PaperDollItemSlotButton_Update
 PaperDollItemSlotButton_Update=nil
 assert(loadfile("Modules/CharacterItemLevels.lua"))("EraUI",E2)
 local lone=E2.modules.CharacterItemLevels
 local hooksBefore,made=globalHooks,#frames
 local ok=pcall(lone.Initialize,lone)
 equal(ok,true,"no game repaint and no Bag Item Levels: no error")
 equal(globalHooks,hooksBefore,"nothing to hook yet")
 local marks=0;for i=made+1,#frames do if frames[i].level then marks=marks+1 end end
 equal(marks,0,"without Bag Item Levels' reading, nothing is shown")
 -- A Bag Item Levels without the shared reading (a stand-in): the same.
 E2.modules.BagItemLevels={Refresh=function()end}
 ok=pcall(lone.Refresh,lone)
 equal(ok,true,"a Bag Item Levels without the shared reading: no error")
 marks=0;for i=made+1,#frames do if frames[i].level then marks=marks+1 end end
 equal(marks,0,"and nothing shown")
 -- One that has only part of it: the same, never a half-made number.
 E2.modules.BagItemLevels={ItemLevel=B.ItemLevel,LevelText=B.LevelText}
 ok=pcall(lone.Refresh,lone)
 equal(ok,true,"a Bag Item Levels with only part of the shared reading: no error")
 marks=0;for i=made+1,#frames do if frames[i].level then marks=marks+1 end end
 equal(marks,0,"and nothing made")
 E2.modules.BagItemLevels=nil
 PaperDollItemSlotButton_Update=real
 lone:Refresh()
 equal(globalHooks,hooksBefore+1,"the game's repaint hooked once it exists")
 E2.settings.characterItemLevels=false;lone:Refresh()
end

-- Nothing ever written on a slot (the proxies would have errored), final check.
NothingWritten("final")
print("Character item level checks passed: "..checks.." assertions.")
