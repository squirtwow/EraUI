local _,E=...
local T=E.ClassTools
local M={};E:RegisterModule("PoisonReminders",M)
local frame,header,lines
local unlocked=false
local function Options()
 local o=T.Options();o.poisonReminderPosition=o.poisonReminderPosition or {x=220,y=-140,scale=1}
 local p=o.poisonReminderPosition;p.scale=math.max(.6,math.min(1.8,tonumber(p.scale)or 1))
 return p
end
local function Enabled()return E:GetSetting("enabled") and E:GetSetting("poisonReminders")end
local function Weapon(slot)
 local id=GetInventoryItemID("player",slot)
 if not T.Number(id)then return false end
 local fn=C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
 if not fn then return nil end
 local _,_,_,_,_,classID=fn(id)
 if not T.Number(classID)then return nil end
 return classID==2
end
-- Inventory tooltips name the current enchant. Compare against localized poison
-- family names, rather than assuming every temporary enchant is poison.
local function PoisonName(slot)
 if not C_TooltipInfo or not C_TooltipInfo.GetInventoryItem then return end
 local ok,data=pcall(C_TooltipInfo.GetInventoryItem,"player",slot)
 if not ok or not data or not data.lines then return end
 local names={}
 for _,spell in ipairs({8681,2835,3420,5763,13220})do local name=T.Spell(spell);if name then names[#names+1]=name end end
 for _,line in ipairs(data.lines)do
  local text=line.leftText
  if T.Public(text) and type(text)=="string"then
   for _,name in ipairs(names)do if text:find(name,1,true)then return name end end
  end
 end
end
function M:Read(slot,has,ms,charges)
 local weapon=Weapon(slot)
 if weapon==false then return nil end
 if weapon==nil or not T.Public(has)then return {text="Weapon data unavailable",warning=false}end
 if not has then return {text="Missing poison",detail="Apply a poison",badge="MISSING",warning=true}end
 local name=PoisonName(slot)
 local text=name or "Weapon coating (type unconfirmed)"
 local warning=false;local details={}
 if T.Number(ms) and ms>0 then
  local seconds=math.ceil(ms/1000)
  text=text.." · "..math.floor(seconds/60)..":"..string.format("%02d",seconds%60)
  details[#details+1]=math.floor(seconds/60)..":"..string.format("%02d",seconds%60)
  warning=seconds<=60
 end
 if T.Number(charges) and charges>0 then
  text=text.." · "..charges.." charges"
  details[#details+1]=charges.." charges"
  warning=warning or charges<=10
 end
 -- Zero charges is also how uncharged enchants are reported; it is not proof
 -- of an empty poison. Only a missing enchant is treated as depleted.
 return {text=text,detail=table.concat(details," · "),name=name,badge=warning and "LOW" or name and "READY" or "CHECK",warning=warning}
end
function M:Snapshot(slot)
 if C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo then
  local ok,data=pcall(C_PaperDollInfo.GetTemporaryEnchantmentInfo,slot)
  if not ok then return {text="Coating data unavailable",warning=false}end
  return self:Read(slot,data~=nil,data and data.remainingTimeMs,data and data.chargesRemaining)
 end
 if not GetWeaponEnchantInfo then return {text="Coating data unavailable",warning=false}end
 local v={pcall(GetWeaponEnchantInfo)}
 if not v[1]then return {text="Coating data unavailable",warning=false}end
 local offset=slot==16 and 0 or 4
 return self:Read(slot,v[offset+2],v[offset+3],v[offset+4])
end
local function Layout()
 local p=Options();frame:SetScale(p.scale);frame:ClearAllPoints()
 frame:SetPoint("CENTER",UIParent,"CENTER",p.x/p.scale,p.y/p.scale)
 local preview=unlocked or E.settingsFrame and E.settingsFrame:IsShown()
 frame:SetFrameStrata(preview and "FULLSCREEN_DIALOG" or "MEDIUM")
end
local function Build()
 if frame then return end
 frame=CreateFrame("Frame","EraUIPoisonReminders",UIParent,"BackdropTemplate");T.Skin(frame)
 frame:SetSize(330,158);frame:SetMovable(true);frame:SetClampedToScreen(true)
 header=T.Button(frame,"Poison reminders  +",330,30);header:SetPoint("TOP");T.ReminderHeader(header)
 header:RegisterForClicks("LeftButtonUp","RightButtonUp");header:RegisterForDrag("LeftButton");header:EnableMouseWheel(true)
 header:SetScript("OnClick",function(_,button)unlocked=button=="RightButton";M:Refresh()end)
 header:SetScript("OnDragStart",function()if unlocked then frame:StartMoving()end end)
 header:SetScript("OnDragStop",function()
  frame:StopMovingOrSizing();local x,y=frame:GetCenter();local cx,cy=UIParent:GetCenter()
  local ratio=frame:GetEffectiveScale()/UIParent:GetEffectiveScale();local p=Options();p.x=x*ratio-cx;p.y=y*ratio-cy;Layout()
 end)
 header:SetScript("OnMouseWheel",function(_,delta)if unlocked then Options().scale=Options().scale+delta*.05;Layout()end end)
 header:SetScript("OnEnter",function(self)
  GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Poison reminders")
  GameTooltip:AddLine("Warns when a weapon coating is missing, below 1 minute, or at 10 charges or fewer. Zero-charge enchants are not treated as depleted.",1,1,1,true)
  GameTooltip:AddLine("Right-click to unlock; drag to move; scroll to resize; left-click to lock. Open /era for a positioning preview.",.7,.7,.7,true);GameTooltip:Show()
 end)
 header:SetScript("OnLeave",function()GameTooltip:Hide()end)
 lines={T.ReminderRow(frame,314),T.ReminderRow(frame,314)}
 Layout()
end
function M:Refresh()
 if not frame then Build()end
 if not Enabled()then frame:Hide();return end
 Layout()
 local preview=unlocked or E.settingsFrame and E.settingsFrame:IsShown()
 local warn=false;local visible=0
 for i,slot in ipairs({16,17})do
  local state=self:Snapshot(slot)
  local row=lines[i];local title=i==1 and "Main hand" or "Off hand"
  row:SetShown(state~=nil or preview)
  if state or preview then
   row:ClearAllPoints();row:SetPoint("TOPLEFT",8,-38-visible*60);visible=visible+1
   row.label:SetText(title..(state and state.name and (" · "..state.name)or " · Poison"))
   row.status:SetText(state and (state.detail~="" and state.detail or state.text)or "No equipped weapon")
   local icon=GetInventoryItemTexture and GetInventoryItemTexture("player",slot)
   row.icon:SetTexture(T.Public(icon)and icon or "Interface\\Icons\\Ability_Poisons")
   local active=nil;if state and state.badge and state.badge~="CHECK" then active=not state.warning end
   T.PaintReminder(row,active,state and state.badge or "CHECK")
  end
  if state and state.warning then warn=true end
 end
 header.label:SetText(unlocked and "Drag / scroll · left-click to lock" or "Poison reminders  +")
 frame:SetHeight(38+visible*60)
 frame:SetShown(not not (preview or warn))
end
function M:Initialize()
 local _,class=UnitClass("player");if class~="ROGUE"then return end
 Build();self:Refresh()
 local f=CreateFrame("Frame");local elapsed=0
 for _,event in ipairs({"PLAYER_ENTERING_WORLD","UNIT_INVENTORY_CHANGED","BAG_UPDATE_DELAYED","PLAYER_EQUIPMENT_CHANGED"})do f:RegisterEvent(event)end
 f:SetScript("OnEvent",function()M:Refresh()end)
 f:SetScript("OnUpdate",function(_,dt)elapsed=elapsed+dt;if elapsed>=.5 then elapsed=0;M:Refresh()end end)
end
