local _,E=...
local T=E.ClassTools
local M={};E:RegisterModule("ClassReminders",M)
local class,panel,window,header,recipientButton,summary
local rows={};local totemRows={};local shardRow;local unlocked=false
local recipient="player"
local function O()return T.Options()end
local function Enabled()return E:GetSetting("enabled") and E:GetSetting("classReminders")end
local function Definitions()return E.ReminderSpells[class] or {}end
function M:Learned(def)
 for i=#def.ids,1,-1 do if T.Known(def.ids[i])then return def.ids[i]end end
end
local function Friendly(unit)
 local exists=UnitExists(unit);if not T.Public(exists) or not exists then return false end
 local friendly=UnitCanAssist("player",unit);return T.Public(friendly) and friendly==true
end
-- A protected/secret aura is unknown, never a missing buff. No native frame is modified.
function M:Aura(unit,def)
 if not Friendly(unit)then return nil end
 local wanted={};for _,id in ipairs(def.ids)do wanted[id]=true end
 for _,id in ipairs(def.auras or {})do wanted[id]=true end
 local fn=C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
 if not fn then return nil end
 local unknown=false
 for index=1,80 do
  local ok,aura=pcall(fn,unit,index,"HELPFUL")
  if not ok then return nil end
  if not aura then if unknown then return nil end;return false end
  if not T.Public(aura.spellId)then unknown=true
  elseif wanted[aura.spellId]then
   local remaining=T.Number(aura.expirationTime) and aura.expirationTime>0 and math.max(0,aura.expirationTime-GetTime()) or nil
   return true,remaining
  end
 end
 return nil
end
local function Duration(seconds)
 if not seconds then return "Active" end
 if seconds>=60 then return math.ceil(seconds/60).."m"end
 return math.ceil(seconds).."s"
end
local function Position()
 O().reminderPosition=O().reminderPosition or {x=250,y=-60,scale=1}
 local p=O().reminderPosition;p.scale=math.max(.6,math.min(1.8,tonumber(p.scale)or 1));return p
end
local function Layout()
 if not panel or InCombatLockdown()then return end
 local p=Position();panel:SetScale(p.scale);panel:ClearAllPoints()
 panel:SetPoint("CENTER",UIParent,"CENTER",p.x/p.scale,p.y/p.scale)
 panel:SetFrameStrata((unlocked or E.settingsFrame and E.settingsFrame:IsShown()) and "FULLSCREEN_DIALOG" or "MEDIUM")
end
local function SavePosition()
 panel:StopMovingOrSizing()
 local x,y=panel:GetCenter();local cx,cy=UIParent:GetCenter();local ratio=panel:GetEffectiveScale()/UIParent:GetEffectiveScale()
 local p=Position();p.x=x*ratio-cx;p.y=y*ratio-cy
end
function M:Recipients()
 local list={"player"}
 if Friendly("target")then list[#list+1]="target"end
 if IsInRaid and IsInRaid()then
  for i=1,(GetNumGroupMembers()or 0)do local unit="raid"..i;if Friendly(unit)then list[#list+1]=unit end end
 else
  for i=1,(GetNumSubgroupMembers and GetNumSubgroupMembers()or 0)do local unit="party"..i;if Friendly(unit)then list[#list+1]=unit end end
 end
 return list
end
local function ChoiceSet(def)
 if def.blessing then return def.key==(O().reminderBlessing or "might")end
 if def.kind=="imbue"then return def.key==(O().reminderImbue or "rockbiter")end
 return O()["reminder_"..def.key]~=false
end
local function CastTarget(def)return def.self and "player" or recipient end
local function CountItems(def)
 local total=0;local best
 for _,id in ipairs(def.items or {})do local n=T.Count(id);total=total+n;if n>0 then best=id end end
 return total,best
end
function M:State(def)
 if def.kind=="healthstone" then local n=CountItems(def);return n>0,n>0 and ("Ready: "..n)or "Create Healthstone"end
 if def.kind=="soulstone" then
  local applied,time=self:Aura(recipient,{ids=def.auras})
  if applied then return true,"Soulstone · "..Duration(time)end
  local n=CountItems(def)
  return false,n>0 and "Click to apply Soulstone" or "Create Soulstone"
 end
 if def.kind=="imbue"then
  if not GetWeaponEnchantInfo then return nil,"Unavailable"end
  local ok,has,ms=pcall(GetWeaponEnchantInfo)
  if not ok or not T.Public(has)then return nil,"Unavailable"end
  return has==true,has and ("Weapon enchanted · "..(T.Number(ms)and Duration(ms/1000)or "Active"))or "Missing weapon enchant"
 end
 local active,time=self:Aura(CastTarget(def),def)
 if active==nil then return nil,"Check target / aura unavailable"end
 return active,active and Duration(time)or "Missing · click to buff"
end
local function Build()
 if panel then return end
 panel=CreateFrame("Frame","EraUIClassReminderPanel",UIParent,"BackdropTemplate");T.Skin(panel)
 panel:SetSize(330,100);panel:SetMovable(true);panel:SetClampedToScreen(true)
 header=T.Button(panel,"",330,30);header:SetPoint("TOP");T.ReminderHeader(header);header:RegisterForClicks("LeftButtonUp","RightButtonUp")
 header:RegisterForDrag("LeftButton");header:EnableMouseWheel(true)
 header:SetScript("OnClick",function(_,button)
  if InCombatLockdown()then return end
  unlocked=button=="RightButton";Layout();M:Refresh()
 end)
 header:SetScript("OnDragStart",function()if unlocked and not InCombatLockdown()then panel:StartMoving()end end)
 header:SetScript("OnDragStop",function()if not InCombatLockdown()then SavePosition();Layout()end end)
 header:SetScript("OnMouseWheel",function(_,delta)if unlocked and not InCombatLockdown()then Position().scale=Position().scale+delta*.05;Layout()end end)
 header:SetScript("OnEnter",function(self)
  GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Class reminders")
  GameTooltip:AddLine("Right-click to unlock. Drag header to move; scroll to resize. Left-click to lock. Changes wait until combat ends.",1,1,1,true);GameTooltip:Show()
 end)
 header:SetScript("OnLeave",function()GameTooltip:Hide()end)
 recipientButton=T.Button(panel,"",314,24);recipientButton:SetPoint("TOP",0,-36)
 recipientButton:SetScript("OnClick",function()
  if InCombatLockdown()then return end
  local units=M:Recipients();local next=1
  for i,u in ipairs(units)do if u==recipient then next=i%#units+1;break end end
  recipient=units[next];M:Refresh()
 end)
 summary=T.Text(panel,"",12);summary:SetPoint("TOPLEFT",8,-72);summary:SetWidth(314)
 if class=="WARLOCK"then
  shardRow=T.ReminderRow(panel,314);shardRow.icon:SetTexture("Interface\\Icons\\INV_Misc_Gem_Amethyst_02");shardRow.label:SetText("Soul Shards")
 end
 if class=="SHAMAN"then
  for i,element in ipairs({"Fire","Earth","Water","Air"})do
   local row=T.ReminderRow(panel,314);row.label:SetText(element.." Totem")
   row.icon:SetTexture("Interface\\Icons\\"..({"Spell_Fire_SearingTotem","Spell_Nature_StoneSkinTotem","Spell_Nature_ManaRegenTotem","Spell_Nature_GroundingTotem"})[i])
   totemRows[i]=row
  end
 end
 for _,def in ipairs(Definitions())do
  local b=T.ReminderRow(panel,314,true)
  b.def=def;b:Hide();rows[#rows+1]=b
 end
 Layout()
end
local function PaintTotems(y,combat)
 if class~="SHAMAN"then return y,0 end
 local enabled=O().reminderTotems~=false
 for i,row in ipairs(totemRows)do
  if not combat then row:SetShown(enabled)end
  if enabled then
   local active,text=nil,"Timer unavailable"
   row.label:SetText(({"Fire","Earth","Water","Air"})[i].." Totem")
   if GetTotemInfo then
    local ok,has,name,start,duration=pcall(GetTotemInfo,i)
    if ok and T.Public(has)then
     active=has==true
     if active and T.Public(name)and T.Number(start)and T.Number(duration)then
      row.label:SetText(name);text="Remaining: "..Duration(math.max(0,start+duration-GetTime()))
     elseif not active then text="No active totem"end
    end
   end
   row.status:SetText(text);T.PaintReminder(row,active,active==false and "INACTIVE" or nil)
   if not combat then row:ClearAllPoints();row:SetPoint("TOPLEFT",8,y)end
   y=y-60
  end
 end
 return y,enabled and 4 or 0
end
function M:Refresh()
 if not class then local _,c=UnitClass("player");class=c end
 if not E.ReminderSpells[class]then return end
 if not panel then if InCombatLockdown()then return end;Build()end
 local combat=InCombatLockdown()
 if not combat then panel:SetShown(Enabled());Layout()end
 if not Enabled()then return end
 if not combat and not Friendly(recipient)then recipient="player"end
 local name=UnitName(recipient);if not T.Public(name)then name=nil end
 recipientButton.label:SetText("Buff: "..(name or recipient).."  >")
 header.label:SetText(unlocked and "Drag / scroll · left-click to lock" or "Class reminders  +")
 summary:SetText("")
 local y=-68;local shown=0
 if shardRow then
  local count=T.Count(6265);local low=count<(tonumber(O().shardWarning)or 5)
  shardRow.status:SetText(count.." in bags � minimum "..(tonumber(O().shardWarning)or 5))
  T.PaintReminder(shardRow,not low,low and "LOW" or "READY")
  if not combat then shardRow:ClearAllPoints();shardRow:SetPoint("TOPLEFT",8,y)end
  y=y-60;shown=shown+1
 end
 for _,row in ipairs(rows)do
  local def=row.def;local spell=self:Learned(def)
  local active,text=self:State(def)
  local visible=spell and ChoiceSet(def) and (unlocked or O().reminderMissingOnly==false or active~=true)
  if not combat then
   row:SetShown(not not visible)
   if visible then
    row:ClearAllPoints();row:SetPoint("TOPLEFT",8,y);y=y-60;shown=shown+1
    local name,icon=T.Spell(spell);row.label:SetText(name or def.name);row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    row:SetAttribute("type","spell");row:SetAttribute("spell",spell);row:SetAttribute("unit",CastTarget(def))
    if def.kind=="soulstone"then
     local _,item=CountItems(def)
     if item then row:SetAttribute("type","item");row:SetAttribute("item","item:"..item)end
    end
   end
  end
  row.status:SetText(text);T.PaintReminder(row,active)
 end
 local totemCount;y,totemCount=PaintTotems(y,combat)
 if not combat then
  if shown==0 and totemCount==0 then summary:SetText("All set � no missing learned buffs");y=-94 end
  panel:SetHeight(-y+8)
 end
end
local function Cycle(field,predicate,button)
 local choices={}
 for _,def in ipairs(Definitions())do if predicate(def) and M:Learned(def)then choices[#choices+1]=def end end
 if #choices==0 then button.label:SetText("Learn a matching spell first");return end
 local index=0;for i,def in ipairs(choices)do if def.key==O()[field]then index=i end end
 local chosen=choices[index%#choices+1];O()[field]=chosen.key;button.label:SetText(chosen.name.."  >");M:Refresh()
end
function M:Open()
 if InCombatLockdown()then return end
 if not Enabled()then E:Print("Class reminders are coming soon - still being redesigned.");return end
 self:Refresh()
 if not window then
  window=T.Window("EraUIReminderOptions",(UnitClass("player")).." · Reminders",420,550)
  local move=T.Button(window,"Move / resize reminder panel",380,30);move:SetPoint("TOPLEFT",18,-56)
  move:SetScript("OnClick",function()
   if InCombatLockdown()then return end
   if not Enabled()then E:Print("Enable Class Reminders & Buffs in your class settings first.");return end
   unlocked=true;window:Hide();if E.settingsFrame then E.settingsFrame:Hide()end;M:Refresh()
  end)
  T.Toggle(window,"Show only missing buffs","reminderMissingOnly",-94,true,function()M:Refresh()end)
  local note=T.Text(window,"Choose recipients on the reminder panel. Each button casts one learned spell. Group buffs use their normal reagents. Combat keeps button positions and assignments fixed.",12)
  note:SetPoint("TOPLEFT",18,-136);note:SetWidth(380)
  local y=-208
  if class=="PALADIN" or class=="SHAMAN"then
   local field=class=="PALADIN" and "reminderBlessing" or "reminderImbue"
   local predicate=function(d)return class=="PALADIN" and d.blessing or class=="SHAMAN" and d.kind=="imbue"end
   local choose=T.Button(window,class=="PALADIN" and "Choose tracked blessing >" or "Choose weapon enchant >",380,30);choose:SetPoint("TOPLEFT",18,y);y=y-38
   choose:SetScript("OnClick",function()if not InCombatLockdown()then Cycle(field,predicate,choose)end end)
  end
  for _,def in ipairs(Definitions())do
   if not def.blessing and def.kind~="imbue"then
    T.Toggle(window,def.name,"reminder_"..def.key,y,true,function()M:Refresh()end);y=y-34
   end
  end
  if class=="SHAMAN"then T.Toggle(window,"Show totem timers","reminderTotems",y,true,function()M:Refresh()end);y=y-38 end
  if class=="WARLOCK"then T.Slider(window,"Warn below this many shards","shardWarning",y,0,40,5,function()M:Refresh()end);y=y-65 end
  window:SetHeight(math.max(350,-y+20))
 end
 window:Show()
end
function M:Initialize()
 local _,c=UnitClass("player");class=c;if not E.ReminderSpells[class]then return end
 self:Refresh()
 local events=CreateFrame("Frame")
 for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","SPELLS_CHANGED","BAG_UPDATE_DELAYED","PLAYER_TARGET_CHANGED","GROUP_ROSTER_UPDATE","UNIT_AURA","PLAYER_TOTEM_UPDATE","UNIT_INVENTORY_CHANGED"})do events:RegisterEvent(event)end
 local dirty=true;local elapsed=0
 events:SetScript("OnEvent",function()dirty=true end)
 events:SetScript("OnUpdate",function(_,dt)
  elapsed=elapsed+dt
  if elapsed>1 or dirty and elapsed>.15 then elapsed=0;dirty=false;M:Refresh()end
 end)
end
