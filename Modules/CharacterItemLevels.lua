local _,E=...
local M={};E:RegisterModule("CharacterItemLevels",M)
-- Character Item Levels: the item level of each piece of gear you wear, at
-- the bottom right of its slot in the character window, in the item's quality
-- colour. The reading and the look are Bag Item Levels' own, so a helm shows
-- the same number here as the one your bags are weighed against. Not on the
-- shirt, tabard or ammo slots, nor on a stack of thrown weapons (the game's
-- count is in that corner). Works with EraUI's Classic character window
-- (it only moves the slots and fades their gear-slot art) and with Blizzard's
-- own. Nothing is written on the slot buttons: each number is in a mouse-free
-- frame of ours, kept in a table here, a child of its slot drawn above the
-- icon, its quality border and its cooldown, repainted by a post-hook on the
-- game's own slot repaint and a few events. It blends normally, so it fades
-- with the interface (the AFK screen hides the UI that way).
-- Blizzard's slot buttons and the inventory slot each one shows.
local SLOTS={CharacterHeadSlot=1,CharacterNeckSlot=2,CharacterShoulderSlot=3,CharacterChestSlot=5,
 CharacterWaistSlot=6,CharacterLegsSlot=7,CharacterFeetSlot=8,CharacterWristSlot=9,CharacterHandsSlot=10,
 CharacterFinger0Slot=11,CharacterFinger1Slot=12,CharacterTrinket0Slot=13,CharacterTrinket1Slot=14,
 CharacterBackSlot=15,CharacterMainHandSlot=16,CharacterSecondaryHandSlot=17,CharacterRangedSlot=18}
-- The game's repaint of one slot: when the window opens and when gear or bags change.
local UPDATE="PaperDollItemSlotButton_Update"
local EVENTS={"PLAYER_EQUIPMENT_CHANGED","GET_ITEM_INFO_RECEIVED","PLAYER_REGEN_ENABLED"}
local LATE_ITEM="ITEM_DATA_LOAD_RESULT" -- asked for with care: not every build has it
local marks=setmetatable({},{__mode="k"}) -- Blizzard slot button -> our mark
local hooked,events,queued,pending,waiting

local function Public(v)return not(issecretvalue and issecretvalue(v))end
local function Active()return E:GetSetting("enabled")and E:GetSetting("characterItemLevels")and true or false end
local function Number(fn,...)
 if type(fn)~="function"then return end
 local ok,v=pcall(fn,...)
 if ok and Public(v)and type(v)=="number"then return v end
end
-- Bag Item Levels' reading and look, whether that option is on or off.
local SHARED={"ItemLevel","QualityColour","LevelText","SizeLevel","SlotWidth"}
local function Shared()
 local B=E.modules.BagItemLevels
 if type(B)~="table"then return end
 for _,key in ipairs(SHARED)do if type(B[key])~="function"then return end end
 return B
end
local function SlotOf(button)
 for name,slot in pairs(SLOTS)do if rawequal(_G[name],button)then return slot end end
end
local function Hide(button)local o=marks[button];if o then o:Hide()end end
-- Made once per slot, on first use, and only shown or hidden after that.
local function Mark(button,B)
 local o=marks[button];if o then return o end
 if InCombatLockdown and InCombatLockdown()and type(button.IsProtected)=="function"and button:IsProtected()then
  waiting=true;return
 end
 o=CreateFrame("Frame",nil,button)
 o:SetAllPoints(button)
 o:EnableMouse(false)
 -- Over the slot and the frames the game keeps on it (cooldown, sockets);
 -- the gear-slot art sits under the slot.
 o:SetFrameLevel((Number(button.GetFrameLevel,button)or 0)+3)
 B.LevelText(o)
 marks[button]=o
 return o
end
local function Link(slot)
 if type(GetInventoryItemLink)~="function"then return end
 local ok,link=pcall(GetInventoryItemLink,"player",slot)
 if ok and Public(link)and type(link)=="string"then return link end
end
-- The quality the slot's own border shows, else the item's; white while unknown.
local function Quality(slot,link,B)
 local q=Number(GetInventoryItemQuality,"player",slot)
 if q then return q end
 if type(B.ItemQuality)=="function"then q=B.ItemQuality(link)end
 if type(q)=="number"then return q end
end
-- Only called while switched on (PaintAll and AfterUpdate check first).
local function Paint(button,slot)
 local B=Shared()
 if not B then Hide(button);return end
 local link=Link(slot)
 if not link then Hide(button);return end
 local level=B.ItemLevel(link)
 if not level then pending=true;Hide(button);return end
 -- Should gear stack (thrown weapons), that corner is the game's count.
 local count=Number(GetInventoryItemCount,"player",slot)
 if count and count>1 then Hide(button);return end
 local o=Mark(button,B);if not o then return end
 B.SizeLevel(o,B.SlotWidth(button))
 o.level:SetText(tostring(math.floor(level+.5)))
 o.level:SetTextColor(B.QualityColour(Quality(slot,link,B)))
 o.level:Show()
 o:Show()
end

function M:PaintAll()
 pending,waiting=false,false
 if not Active()then
  for _,o in pairs(marks)do o:Hide()end
  return
 end
 for name,slot in pairs(SLOTS)do
  local button=_G[name]
  if type(button)=="table"then Paint(button,slot)end
 end
end
local function Queue()
 if queued then return end
 queued=true
 C_Timer.After(0,function()queued=false;M:PaintAll()end)
end
local function OnEvent(_,event)
 if not Active()then return end
 if event=="GET_ITEM_INFO_RECEIVED"or event==LATE_ITEM then
  if pending then Queue()end
 elseif event=="PLAYER_REGEN_ENABLED"then
  if waiting then Queue()end
 else
  Queue()
 end
end
-- After the game repaints a slot, only our own mark on it changes.
local function AfterUpdate(button)
 if type(button)~="table"then return end
 if not Active()then Hide(button);return end
 local slot=SlotOf(button)
 if slot then Paint(button,slot)end
end
local function Setup()
 if not hooked and type(_G[UPDATE])=="function"then
  hooked=true
  hooksecurefunc(UPDATE,AfterUpdate)
 end
 if not events then
  events=CreateFrame("Frame")
  events:SetScript("OnEvent",OnEvent)
 end
 for _,event in ipairs(EVENTS)do events:RegisterEvent(event)end
 pcall(events.RegisterEvent,events,LATE_ITEM)
end

function M:Refresh()
 if Active()then Setup()elseif events then events:UnregisterAllEvents()end
 self:PaintAll()
end
function M:Initialize()
 if Active()then self:Refresh()end
end
