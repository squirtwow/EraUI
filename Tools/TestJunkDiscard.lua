-- Inventory transaction tests use the real selection/event code, including failed deletion.
local checks=0
local function Equal(a,b,label)checks=checks+1;assert(a==b,label..": expected "..tostring(b)..", got "..tostring(a))end
local secret={};issecretvalue=function(v)return v==secret end
ERR_INV_FULL="Inventory is full."
local function Item(id,price,count,quality)
 return {itemID=id,hyperlink="|Hitem:"..id.."|h[Item "..id.."]|h",price=price,stackCount=count or 1,quality=quality or 0,isLocked=false}
end
local function Session()
 local s={bags={[0]={slots=3,family=0}},settings={enabled=true,discardCheapestJunk=true},messages={},timers={},deletes=0,pickups=0,retries=0}
 local bag=s.bags[0];bag[1]=Item(1,1,20);bag[2]=Item(2,5,1);bag[3]=Item(3,1,1,1)
 CreateFrame=function()
  local f={RegisterEvent=function()end,SetScript=function(self,_,fn)self.event=fn end};s.events=f;return f
 end
 local function InputFrame()
  return {hooks={},HookScript=function(self,event,fn)
   self.hooks[event]=self.hooks[event]or{};table.insert(self.hooks[event],fn)
  end}
 end
 WorldFrame=InputFrame();LootButton1=InputFrame()
 for i=2,4 do _G["LootButton"..i]=nil end
 C_Timer={After=function(_,fn)s.timers[#s.timers+1]=fn end}
 InCombatLockdown=function()return s.combat end
 IsShiftKeyDown=function()return s.shift end
 GetTime=function()return s.time or 10 end
 UnitGUID=function(unit)Equal(unit,"mouseover","preflight checks the actual hovered unit");return s.mouseover end
 UnitIsDead=function()return s.dead end
 CanLootUnit=function(guid)
  Equal(guid,s.mouseover,"loot rights checked for the hovered corpse")
  if s.lootAPIError then error("loot rights unavailable")end
  return s.hasLoot,s.canLoot
 end
 GetCursorInfo=function()if s.cursor then return "item",s.cursor.itemID,s.cursor.hyperlink end end
 C_Container={
  GetContainerNumSlots=function(b)return s.bags[b]and s.bags[b].slots or 0 end,
  GetContainerNumFreeSlots=function(b)
   local current=s.bags[b];if not current then return end
   local free=0;for slot=1,current.slots do if not current[slot]then free=free+1 end end
   return free,current.family
  end,
  GetContainerItemInfo=function(b,slot)
   if s.changeOnRead then s.changeOnRead(b,slot)end
   if s.ghost and s.ghost.bag==b and s.ghost.slot==slot then return s.ghost.item end
   return s.bags[b]and s.bags[b][slot]
  end,
  GetContainerItemQuestInfo=function(b,slot)return s.bags[b][slot].quest end,
  PickupContainerItem=function(b,slot)
   s.pickups=s.pickups+1
   if s.blockPickup then error("blocked pickup")end
   if s.asyncDelete and not s.cursor then s.ghost={bag=b,slot=slot,item=s.bags[b][slot]}end
   s.cursor,s.bags[b][slot]=s.bags[b][slot],s.cursor
  end,
 }
 C_Item={GetItemInfo=function(link)
  for _,current in pairs(s.bags)do for slot=1,current.slots do
   local i=current[slot];if i and i.hyperlink==link then return "Item",nil,nil,nil,nil,nil,nil,nil,nil,nil,i.price end
  end end
 end}
  DeleteCursorItem=function()
   if not s.hardware then s.blocked=(s.blocked or 0)+1;error("DeleteCursorItem requires hardware input")end
   if s.blockDelete then error("blocked deletion")end
   if not s.noopDelete then s.deleted=s.cursor;s.cursor=nil;s.deletes=s.deletes+1 end
  end
 StaticPopup_Show=function(which)
  s.dialog={which=which,shown=true,data=s.popupData,IsShown=function(self)return self.shown end,Hide=function(self)self.shown=false end}
  if s.onPopup then s.onPopup()end
  return s.dialog
 end
 StaticPopup_FindVisible=function(which)return s.dialog and s.dialog.shown and s.dialog.which==which and s.dialog or nil end
 StaticPopup_OnClick=function(dialog,index)
  Equal(index,1,"native delete uses accept button")
  s.accepts=(s.accepts or 0)+1;s.nativeConfirmed=true;DeleteCursorItem();dialog:Hide()
 end
 hooksecurefunc=function(name,fn)
  local original=_G[name]
  _G[name]=function(...)
   local result=original(...);fn(...);return result
  end
 end
 s.originalPopup=StaticPopup_Show
 GetNumLootItems=function()return 2 end
 LootSlot=function()s.retries=s.retries+1 end
 local E={modules={}}
 function E:RegisterModule(k,v)self.modules[k]=v end
 function E:GetSetting(k)return s.settings[k]end
 function E:Print(text)s.messages[#s.messages+1]=text end
 assert(loadfile("Modules/JunkDiscard.lua"))("EraUI",E)
 s.M=E.modules.JunkDiscard;s.M:Initialize()
 function s:Event(event,...)self.events.event(self.events,event,...)end
 function s:Flush()local timers=self.timers;self.timers={};for _,fn in ipairs(timers)do fn()end end
 function s:Click(frame,event,button)
  frame=frame or WorldFrame;event=event or "OnMouseDown";button=button or "RightButton"
  self.hardware=true
  if frame==LootButton1 then self.nativeLootClicks=(self.nativeLootClicks or 0)+1 end
  for _,fn in ipairs(frame.hooks[event]or{})do fn(frame,button)end
  self.hardware=false
 end
 function s:Full(auto)
  self:Event("LOOT_OPENED",auto);self:Event("UI_ERROR_MESSAGE",1,ERR_INV_FULL)
  for _=1,3 do self:Flush()end
  Equal(self.blocked,nil,"loot/timer path never attempts hardware-only deletion")
  self:Click()
 end
 return s
end
local s=Session()
Equal(s.M:Cheapest().id,2,"compares stack value rather than unit price")
s:Full(true)
Equal(s.deletes,1,"full automatic loot deletes one stack")
Equal(s.deleted.itemID,2,"lowest total value stack deleted")
Equal(s.cursor,nil,"cursor empty after deletion")
Equal(#s.messages,1,"successful deletion reports once")
Equal(s.messages[1],"Bags full: discarded |Hitem:2|h[Item 2]|h x1.","report includes clickable link and quantity")
s:Event("BAG_UPDATE_DELAYED");Equal(s.retries,2,"automatic loot retried after bag update")
s:Event("BAG_UPDATE_DELAYED");Equal(s.retries,2,"bag updates do not repeat retry")
s.bags[0][2]=Item(2,5);s:Event("UI_ERROR_MESSAGE",1,ERR_INV_FULL);s:Flush();s:Click()
Equal(s.deletes,1,"one stack maximum per loot window")
s:Event("LOOT_CLOSED");s:Full(false);Equal(s.deletes,2,"next loot window can discard again")
s:Event("BAG_UPDATE_DELAYED");Equal(s.retries,2,"manual loot never retried automatically")
for _,key in ipairs({"enabled","discardCheapestJunk"})do
 s=Session();s.settings[key]=false;s:Full(true);Equal(s.deletes,0,key.." off blocks deletion")
end
for _,key in ipairs({"combat","shift","blockPickup","blockDelete","noopDelete"})do
 s=Session();s[key]=true;s:Full(true)
 Equal(s.deletes,0,key.." blocks destruction")
 Equal(#s.messages,0,key.." never claims deletion")
 Equal(s.bags[0][2].itemID,2,key.." retains original stack")
 Equal(s.cursor,nil,key.." does not strand item on cursor")
end
s=Session();s.cursor=Item(9,100);s:Full(true)
Equal(s.pickups,0,"occupied cursor never touched");Equal(s.cursor.itemID,9,"cursor item preserved")
s=Session();s.bags[0][3]=nil;s:Full(true);Equal(s.deletes,0,"general free space blocks deletion")
s=Session();s.bags[1]={slots=2,family=32};s:Full(true)
Equal(s.deletes,1,"unused specialist slots do not count as general space")
s=Session();s.bags[0][1].price=nil;s:Full(true);Equal(s.deletes,0,"uncached grey price prevents choosing a more costly stack")
s=Session();s.bags[0][1].price=secret;s:Full(true);Equal(s.deletes,0,"restricted price never participates in comparisons")
s=Session();s.bags[0][2].isLocked=true;s:Full(true);Equal(s.deleted.itemID,1,"locked grey stack skipped")
s=Session();s.bags[0][2].quest={isQuestItem=true};s:Full(true);Equal(s.deleted.itemID,1,"quest grey stack skipped")
s=Session();s.bags[0][2].quest={questID=123};s:Full(true);Equal(s.deleted.itemID,1,"quest-starting grey stack skipped")
s=Session();s.bags[0][2].quality=secret;s:Full(true);Equal(s.deleted.itemID,1,"restricted quality skipped")
s=Session();s.bags[0][2].price=0;s:Full(true);Equal(s.deleted.itemID,2,"known zero-value grey is eligible")
s=Session();s.bags[0][1].quality=1;s.bags[0][2].quality=2;s:Full(true);Equal(s.deletes,0,"never deletes non-grey items")
s=Session();s:Event("UI_ERROR_MESSAGE",1,ERR_INV_FULL);s:Flush();s:Click();Equal(s.deletes,0,"inventory errors outside loot ignored")
s=Session();s:Event("LOOT_OPENED",true);s:Event("UI_ERROR_MESSAGE",1,"Other error");s:Flush();s:Click();Equal(s.deletes,0,"other errors do not delete")
s=Session();s:Event("LOOT_OPENED",true);s:Event("UI_ERROR_MESSAGE",1,secret);s:Flush();s:Click();Equal(s.deletes,0,"restricted error ignored")
s=Session();s:Event("LOOT_OPENED",true);Equal(s.deletes,0,"opening loot with full bags alone never deletes")
s:Event("UI_ERROR_MESSAGE",1,ERR_INV_FULL);s:Event("UI_ERROR_MESSAGE",1,ERR_INV_FULL)
Equal(#s.timers,0,"error burst never schedules destructive timer callbacks")
s:Event("LOOT_CLOSED");s:Flush();s:Click();Equal(s.deletes,0,"closed loot cancels queued deletion")
s=Session();s:Event("LOOT_OPENED",true);s:Event("UI_ERROR_MESSAGE",1,ERR_INV_FULL);s.shift=true;s:Flush();s:Click()
Equal(s.deletes,0,"Shift checked again at execution")
s=Session();s:Event("LOOT_OPENED",true);s:Event("UI_ERROR_MESSAGE",1,ERR_INV_FULL);s.settings.discardCheapestJunk=false;s:Flush();s:Click()
Equal(s.deletes,0,"disable cancels pending deletion")
s=Session();s.settings.fastAutoLoot=true;s:Full(false);s:Event("BAG_UPDATE_DELAYED")
Equal(s.retries,2,"EraUI fast loot gets one retry")
s=Session();local reads=0
s.changeOnRead=function(b,slot)
 if b==0 and slot==2 then reads=reads+1;if reads==2 then s.bags[0][2]=Item(8,100)end end
end
s:Full(true);Equal(s.deletes,0,"changed candidate is revalidated before pickup")
s=Session();s.asyncDelete=true;s:Full(true)
Equal(s.deletes,1,"asynchronous deletion requested once")
Equal(#s.messages,0,"report waits for bag state to confirm asynchronous deletion")
s.ghost=nil;s:Event("BAG_UPDATE_DELAYED")
Equal(#s.messages,1,"asynchronous deletion reports after bag update")
Equal(s.retries,2,"asynchronous deletion retries loot after confirmation")
s=Session();s.asyncDelete=true;s:Full(true);s:Event("LOOT_CLOSED");s.ghost=nil;s:Event("BAG_UPDATE_DELAYED")
Equal(#s.messages,1,"confirmed deletion still reports after loot window closes")
Equal(s.retries,0,"closed loot never retried after asynchronous deletion")
s=Session();s.asyncDelete=true;s:Full(true);s.time=13;s.ghost=nil;s:Event("BAG_UPDATE_DELAYED")
Equal(#s.messages,0,"stale unconfirmed transactions never report a later unrelated change")
s=Session();StaticPopup_Show("DELETE_ITEM")
Equal(s.accepts,nil,"manual delete prompt has no automatic acceptance")
s:Full(true);Equal(s.pickups,0,"existing unrelated prompt prevents starting a transaction")
s=Session();s:Event("LOOT_OPENED",true);s:Event("UI_ERROR_MESSAGE",1,ERR_INV_FULL);s:Flush()
Equal(s.deletes,0,"full-bag events only queue a candidate")
s.M:Discard();Equal(s.pickups,0,"direct non-input invocation cannot move items")
s:Event("BAG_UPDATE_DELAYED");Equal(s.deletes,0,"bag event cannot execute queued deletion")
s:Click(WorldFrame,"OnMouseDown","MiddleButton");Equal(s.deletes,0,"unrelated mouse button does not delete")
s:Click(WorldFrame,"OnMouseUp")
Equal(s.deletes,1,"normal world mouse-up performs queued deletion")
Equal(s.blocked,nil,"world input produces no protected-call refusal")
Equal(s.dialog,nil,"hardware deletion opens no confirmation window")
Equal(StaticPopup_Show,s.originalPopup,"popup system is not hooked for automatic acceptance")
s:Click();Equal(s.deletes,1,"down/up sequence cannot delete a second stack")
s=Session();s:Event("LOOT_OPENED",false);s:Event("UI_ERROR_MESSAGE",1,ERR_INV_FULL)
s:Click(LootButton1,"OnClick","LeftButton")
Equal(s.deletes,1,"native loot-button click can free space")
Equal(s.nativeLootClicks,1,"native loot click still runs")
Equal(s.blocked,nil,"loot-button path preserves hardware context")
s:Event("LOOT_OPENED",false)
Equal(#LootButton1.hooks.OnClick,1,"reopening loot does not duplicate input hooks")
s=Session();s:Event("LOOT_OPENED",true);s:Event("UI_ERROR_MESSAGE",1,ERR_INV_FULL);s.bags[0][3]=nil;s:Click()
Equal(s.deletes,0,"bag space rechecked on eventual input")
s=Session();s:Event("LOOT_OPENED",true);s:Event("UI_ERROR_MESSAGE",1,ERR_INV_FULL);s.combat=true;s:Click()
Equal(s.deletes,0,"entering combat before input cancels deletion")
s=Session();s:Event("LOOT_OPENED",true);s:Event("UI_ERROR_MESSAGE",1,ERR_INV_FULL);s.cursor=Item(99,100);s:Click()
Equal(s.deletes,0,"cursor occupancy rechecked on eventual input")
Equal(s.cursor.itemID,99,"user cursor item preserved while request is pending")
local function Corpse(s)
 s.mouseover="Creature-1-2-3-4-5-6";s.dead=true;s.hasLoot=true;s.canLoot=true
end
s=Session();Corpse(s);s:Click()
Equal(s.deletes,1,"initial corpse click deletes without a previous loot error")
Equal(s.blocked,nil,"first-click deletion retains hardware permission")
Equal(#s.messages,1,"first-click deletion reports the selected stack")
s.bags[0][2]=Item(9,5);s:Event("LOOT_READY");s:Event("LOOT_OPENED",true)
s:Click(WorldFrame,"OnMouseUp");s:Event("UI_ERROR_MESSAGE",1,ERR_INV_FULL);s:Click()
Equal(s.deletes,1,"first-click allowance carries into the opened loot session")
s:Event("LOOT_CLOSED");s:Click()
Equal(s.deletes,2,"later corpse interaction gets its own allowance")
s=Session();Corpse(s);s:Event("LOOT_READY");s:Click()
Equal(s.deletes,1,"first click works if native loot-ready arrives before the mouse hook")
for _,case in ipairs({"noRights","noLoot","alive","secretGUID","secretRights","error","missingAPI","shift","combat","disabled","emptySlot","occupiedCursor"})do
 s=Session();Corpse(s)
 if case=="noRights"then s.canLoot=false
 elseif case=="noLoot"then s.hasLoot=false
 elseif case=="alive"then s.dead=false
 elseif case=="secretGUID"then s.mouseover=secret
 elseif case=="secretRights"then s.canLoot=secret
 elseif case=="error"then s.lootAPIError=true
 elseif case=="missingAPI"then CanLootUnit=nil
 elseif case=="shift"then s.shift=true
 elseif case=="combat"then s.combat=true
 elseif case=="disabled"then s.settings.discardCheapestJunk=false
 elseif case=="emptySlot"then s.bags[0][3]=nil
 elseif case=="occupiedCursor"then s.cursor=Item(99,100)end
 s:Click();Equal(s.deletes,0,"first-click preflight skips "..case)
 Equal(s.blocked,nil,"first-click "..case.." causes no protected refusal")
end
s=Session();Corpse(s);s:Click(WorldFrame,"OnMouseDown","LeftButton")
Equal(s.deletes,0,"selecting a corpse with left-click does not discard")
s=Session();Corpse(s);s.asyncDelete=true;s:Click();s:Event("LOOT_READY");s:Event("LOOT_OPENED",true)
s.ghost=nil;s:Event("BAG_UPDATE_DELAYED")
Equal(#s.messages,1,"delayed first-click deletion confirms after loot opens")
Equal(s.retries,2,"delayed first-click deletion respects native automatic-loot choice")
s=Session();Corpse(s);s:Click();s.time=13;s.bags[0][2]=Item(9,5);s:Click()
Equal(s.deletes,2,"expired opening state cannot permanently prevent later attempts")
s=Session();Corpse(s);s.bags[0][3]=nil;s:Click();s.time=13;s.mouseover=nil;s.bags[0][3]=Item(3,1,1,1)
s:Click(WorldFrame,"OnMouseUp")
Equal(s.deletes,0,"expired opening cannot discard on an unrelated later mouse-up")
print("Junk discard transaction checks passed: "..checks.." assertions.")
