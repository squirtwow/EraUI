local _,E=...
local M={};E:RegisterModule("JunkDiscard",M)
local active,attempted,requested,autoLoot,pending,receipt
local opening
local hardware=false
local hooked={}
local generation=0
local function Public(v)return not(issecretvalue and issecretvalue(v))end
local function Allowed()
 return (active or(opening and GetTime()<=opening))and E:GetSetting("enabled")and E:GetSetting("discardCheapestJunk")
  and not InCombatLockdown()and not IsShiftKeyDown()
end
local function Info(bag,slot)
 local info=C_Container.GetContainerItemInfo(bag,slot)
 if not info or not Public(info.quality)or info.quality~=0
  or not Public(info.isLocked)or info.isLocked
  or not Public(info.itemID)or type(info.itemID)~="number"
  or not Public(info.stackCount)or type(info.stackCount)~="number"or info.stackCount<1
  or not Public(info.hyperlink)or type(info.hyperlink)~="string"then return end
 local quest=C_Container.GetContainerItemQuestInfo(bag,slot)
 if quest and(not Public(quest.isQuestItem)or quest.isQuestItem
  or not Public(quest.questID)or quest.questID)then return end
 return info
end
function M:Cheapest()
 local api=C_Container
 local getInfo=C_Item and C_Item.GetItemInfo or GetItemInfo
 if not api or not api.GetContainerNumFreeSlots or not api.GetContainerItemQuestInfo or not getInfo then return end
 local best
 for bag=0,(NUM_BAG_SLOTS or 4)do
  local slots=api.GetContainerNumSlots(bag)
  if not Public(slots)or type(slots)~="number"then return end
  if slots>0 then
   local free,family=api.GetContainerNumFreeSlots(bag)
   if not Public(free)or not Public(family)or type(free)~="number"or type(family)~="number"then return end
   -- A specialist bag cannot provide a general-purpose loot slot.
   if family==0 then
    if free>0 then return end
    for slot=1,slots do
     local info=Info(bag,slot)
     if info then
      local price=select(11,getInfo(info.hyperlink))
      -- An uncached grey price means we cannot establish the cheapest stack.
      if not Public(price)or type(price)~="number"or price<0 then return end
      local value=price*info.stackCount
      if not best or value<best.value then
       best={bag=bag,slot=slot,id=info.itemID,count=info.stackCount,link=info.hyperlink,value=value}
      end
     end
    end
   end
  end
 end
 return best
end
local function ConfirmDeletion()
 if not receipt then return end
 if GetTime()>receipt.expires then receipt=nil;return end
 local kind=GetCursorInfo()
 if Public(kind)and kind==nil and not C_Container.GetContainerItemInfo(receipt.bag,receipt.slot)then
  E:Print("Bags full: discarded "..receipt.link.." x"..receipt.count..".")
  pending=active and receipt.generation==generation and receipt.auto
  receipt=nil
 end
end
local function DeleteDialog()
 return StaticPopup_FindVisible and StaticPopup_FindVisible("DELETE_ITEM")
end
function M:Discard()
 -- DeleteCursorItem is hardware-only on this client. Loot/error/timer callbacks
 -- may request cleanup, but only a genuine world/loot click may execute it.
 if not hardware or not requested then return end
 ConfirmDeletion()
 if not Allowed()or attempted or receipt or DeleteDialog()or not GetCursorInfo or GetCursorInfo()~=nil or not DeleteCursorItem
  or not C_Container or not C_Container.PickupContainerItem then return end
 local best=self:Cheapest()
 if not best then return end
 -- Recheck the exact stack immediately before transferring it to the cursor.
 local current=Info(best.bag,best.slot)
 if not current or current.itemID~=best.id or current.stackCount~=best.count or current.hyperlink~=best.link then return end
 attempted=true;requested=nil -- At most one stack per loot window, including blocked attempts.
 local ok=pcall(C_Container.PickupContainerItem,best.bag,best.slot)
 local kind,id=GetCursorInfo()
 if not ok or not Public(kind)or not Public(id)or kind~="item"or id~=best.id then return end
 best.expires=GetTime()+2;best.generation=generation
 best.auto=autoLoot or E:GetSetting("fastAutoLoot")
 local deleted=pcall(DeleteCursorItem)
 local link
 kind,id,link=GetCursorInfo()
 if deleted and Public(kind)and kind==nil then
  receipt=best;ConfirmDeletion()
 elseif Public(kind)and Public(id)and Public(link)and kind=="item"and id==best.id and link==best.link then
  if not C_Container.GetContainerItemInfo(best.bag,best.slot)then
   pcall(C_Container.PickupContainerItem,best.bag,best.slot)
  end
 end
end
local function PrepareClick(frame,button,script)
 -- Recognize the initial corpse-loot click before LOOT_READY/error delivery.
 -- Unknown/restricted loot rights keep the existing error-first fallback.
 if frame~=WorldFrame or button~="RightButton"or script~="OnMouseDown"
  or not E:GetSetting("enabled")or not E:GetSetting("discardCheapestJunk")
  or InCombatLockdown()or IsShiftKeyDown()then return end
 if opening and GetTime()>opening then
  opening=nil
  if not active then attempted,requested=nil,nil end
 end
 if attempted or not UnitGUID or not UnitIsDead or not CanLootUnit then return end
 local ok,guid=pcall(UnitGUID,"mouseover")
 if not ok or not Public(guid)or type(guid)~="string"then return end
 local deadOK,dead=pcall(UnitIsDead,"mouseover")
 if not deadOK or not Public(dead)or dead~=true then return end
 local lootOK,hasLoot,canLoot=pcall(CanLootUnit,guid)
 if not lootOK or not Public(hasLoot)or not Public(canLoot)or hasLoot~=true or canLoot~=true then return end
 if not active and not opening then
  generation=generation+1;opening=GetTime()+2
  attempted=false;autoLoot,pending=nil,nil
 end
 requested=true
end
local function Input(frame,button,script)
 if hardware or(button~="LeftButton"and button~="RightButton")then return end
 hardware=true
 local ok,err=pcall(function()PrepareClick(frame,button,script);M:Discard()end)
 hardware=false
 if not ok then error(err)end
end
local function HookInput()
 local function Hook(frame,script)
  if not frame or not frame.HookScript then return end
  local scripts=hooked[frame]
  if not scripts then scripts={};hooked[frame]=scripts end
  if scripts[script]then return end
  scripts[script]=true;frame:HookScript(script,function(self,button)Input(self,button,script)end)
 end
 Hook(WorldFrame,"OnMouseDown");Hook(WorldFrame,"OnMouseUp")
 for i=1,(LOOTFRAME_NUMBUTTONS or 4)do Hook(_G["LootButton"..i],"OnClick")end
end
function M:Initialize()
 HookInput()
 local events=CreateFrame("Frame")
 for _,event in ipairs({"LOOT_READY","LOOT_OPENED","LOOT_CLOSED","UI_ERROR_MESSAGE","BAG_UPDATE_DELAYED"})do events:RegisterEvent(event)end
 events:SetScript("OnEvent",function(_,event,arg,message)
  if event=="LOOT_READY"or event=="LOOT_OPENED"then
   if not active then
    if not opening or GetTime()>opening then generation=generation+1;attempted=false end
    active=true;opening=nil;requested=nil
   end
   if event=="LOOT_OPENED"then
    autoLoot=Public(arg)and(arg==true or arg==1);HookInput()
    if receipt and receipt.generation==generation then receipt.auto=autoLoot or E:GetSetting("fastAutoLoot")end
   end
  elseif event=="LOOT_CLOSED"then
   generation=generation+1;active,attempted,requested,autoLoot,pending,opening=nil,nil,nil,nil,nil,nil
  elseif event=="UI_ERROR_MESSAGE"then
   -- Wait for an actual failed loot attempt, not merely an already-full bag.
   if not Allowed()or attempted or not Public(message)or not ERR_INV_FULL or message~=ERR_INV_FULL then return end
   requested=true
  elseif event=="BAG_UPDATE_DELAYED"then
   ConfirmDeletion()
   if pending then
    pending=nil
    if Allowed()and GetCursorInfo()==nil and GetNumLootItems and LootSlot then
     -- One retry for automatic looting; manual loot remains manual.
     for slot=GetNumLootItems(),1,-1 do LootSlot(slot)end
    end
   end
  end
 end)
end
