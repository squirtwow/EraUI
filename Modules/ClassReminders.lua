local _,E=...
local T=E.ClassTools
local M={};E:RegisterModule("ClassReminders",M)
local class,panel,rows,dropdown,preview
local dragging=false
local mapHooked

local AURA_MAX=80
local GROUP_EVERY=5
local DEFAULT_Y=120
local SIZES={
 {key="Small",text=20,icon=40,sub=10,row=108},
 {key="Normal",text=25,icon=52,sub=12,row=134},
 {key="Large",text=32,icon=68,sub=14,row=172},
}

local function Enabled()return E:GetSetting("enabled") and E:GetSetting("classReminders")end
local function Definitions()return E.ReminderSpells[class]or{}end
local function Save()if E.Classic and E.Classic.MirrorSave then E.Classic.MirrorSave()end end
local function Opt(key)return EraUIDB and EraUIDB[key]end
local function SetOpt(key,value)EraUIDB=EraUIDB or{};EraUIDB[key]=value;Save()end
local function DefKey(def)return "reminder_"..tostring(class).."_"..def.key end
local function DefOn(def)
 local v=Opt(DefKey(def))
 if v==nil then return not def.off end
 return v==true
end
local function GroupOn()return Opt("reminderGroup")~=false end
local function CombatOn()return Opt("reminderCombat")==true end
local function Clickable()return Opt("reminderClickable")==true end
local function SizeIndex()
 local v=tonumber(Opt("reminderSize"))or 2
 if v<1 or v>#SIZES then v=2 end
 return v
end

local function Friendly(unit)
 local exists=UnitExists(unit)
 if not T.Public(exists)or not exists then return false end
 local friendly=UnitCanAssist("player",unit)
 return T.Public(friendly)and friendly==true
end
local function Eligible(unit,def,choice)
 if not Friendly(unit)then return false end
 for _,check in ipairs({{UnitIsConnected,true},{UnitIsDeadOrGhost,false}})do
  if not check[1]then return false end
  local ok,value=pcall(check[1],unit)
  if not ok or not T.Public(value)or value~=check[2]then return false end
 end
 if unit~="player"and UnitInRange then
  local ok,near,checked=pcall(UnitInRange,unit)
  if not ok or not T.Public(near)or not T.Public(checked)then return false end
  if checked and not near then return false end
 end
 if def.mana or(choice and choice.mana)then
  local _,c=UnitClass(unit)
  if not T.Public(c)or c=="WARRIOR"or c=="ROGUE"then return false end
 end
 return true
end
local groupCache={units={},at=0}
local function Cache()
 local now=GetTime()
 if now-groupCache.at>GROUP_EVERY then groupCache.units={};groupCache.at=now end
 return groupCache.units
end
local function AuraSet(unit,cache)
 if cache and unit~="player"then
  local hit=cache[unit]
  if hit~=nil then return hit end
 end
 local fn=C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
 if not fn then return nil end
 local set={}
 for i=1,AURA_MAX do
  local ok,aura=pcall(fn,unit,i,"HELPFUL")
  if not ok then return nil end
  if not aura then break end
  local id=aura.spellId
   if not T.Public(id)then return nil end
   if T.Number(id)then set[id]=true end
 end
 if cache and unit~="player"then cache[unit]=set end
 return set
end
local function AuraByName(unit,match)
 local fn=C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
 if not fn then return nil end
 for i=1,AURA_MAX do
  local ok,aura=pcall(fn,unit,i,"HELPFUL")
  if not ok then return nil end
  if not aura then return false end
  local name=aura.name
   if not T.Public(name)then return nil end
   if type(name)=="string"and name:find(match,1,true)then return true end
 end
 return false
end
local function UnitsToCheck(def)
 local list={"player"}
 if def.group and not def.self and GroupOn()then
  local raid=false
  if IsInRaid then local ok,v=pcall(IsInRaid);raid=ok and T.Public(v)and v==true end
  local n
  if raid then n=GetNumGroupMembers and GetNumGroupMembers()or 0
  else n=GetNumSubgroupMembers and GetNumSubgroupMembers()or 0 end
   local count=T.Number(n)and math.min(n,raid and 40 or 4)or 0
   local ownGroup
   if raid and def.subgroup and GetRaidRosterInfo then
    for i=1,count do
     local same=UnitIsUnit and UnitIsUnit("player","raid"..i)
     if T.Public(same)and same then ownGroup=select(3,GetRaidRosterInfo(i));break end
    end
   end
   for i=1,count do
    local unit=(raid and "raid"or "party")..i
    local same=UnitIsUnit and UnitIsUnit("player",unit)
    local subgroup=raid and def.subgroup and GetRaidRosterInfo and select(3,GetRaidRosterInfo(i))
    local allowed=not(raid and def.subgroup)or(T.Number(ownGroup)and T.Number(subgroup)and ownGroup==subgroup)
    if T.Public(same)and not same and allowed then list[#list+1]=unit end
   end
 end
 return list
end
local function ItemCount(ids)
 local n=0
 for _,id in ipairs(ids or{})do n=n+T.Count(id)end
 return n
end
local function HighestKnown(ids)
 local best
 for _,id in ipairs(ids or{})do if T.Known(id)then best=id end end
 return best
end
-- A reminder never fires for a spell the character cannot use yet.
local function Applicable(def)
 if def.minLevel then
  local level=UnitLevel("player")
  if not T.Number(level)or level<def.minLevel then return false end
 end
 if def.ids and not HighestKnown(def.ids)then return false end
 if def.requires and not HighestKnown(def.requires)then return false end
 return true
end
local function ChoiceKey(def)return "reminderChoice_"..tostring(class).."_"..def.key end
local function ChoiceId(def)return tonumber(Opt(ChoiceKey(def)))or 0 end
local function ChoiceOf(def)
 if not def.choices then return nil end
 local id=ChoiceId(def)
 if id==0 then return nil end
 for _,choice in ipairs(def.choices)do
   for _,cid in ipairs(choice.ids or{})do if cid==id and HighestKnown(choice.ids)then return choice end end
 end
 return nil
end
local function ChoiceList(def)
 local list={}
 for _,choice in ipairs(def.choices or{})do
  if choice.key=="any"or HighestKnown(choice.ids)then list[#list+1]=choice end
 end
 return list
end
local function CycleChoice(def)
 local list=ChoiceList(def)
 if #list==0 then return end
 local current=ChoiceId(def)
 local index=0
 for i,choice in ipairs(list)do
  if choice.key=="any"and current==0 then index=i end
  for _,cid in ipairs(choice.ids or{})do if cid==current then index=i end end
 end
 local choice=list[index%#list+1]
 SetOpt(ChoiceKey(def),choice.key=="any"and 0 or choice.ids[1])
end
local function AlertText(def)
 local choice=ChoiceOf(def)
 if choice then return string.upper(choice.name).."!"end
 if def.dynamic then
  local id=HighestKnown(def.ids)
  local name=id and select(1,T.Spell(id))
  if name and type(name)=="string"then return string.upper(name).."!"end
 end
 return def.text or def.name or"?"
end
local function Icon(def)
 local choice=ChoiceOf(def)
 local id=HighestKnown(choice and choice.ids or def.ids)
 if id then local _,icon=T.Spell(id);if icon then return icon end end
 return def.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function DefColor(def)
 if def.color then return def.color[1],def.color[2],def.color[3]end
 return T.Colour()
end
-- Each alert can be parked on its own spot; unplaced ones keep stacking.
local function SpotXKey(def)return "reminderPX_"..tostring(class).."_"..def.key end
local function SpotYKey(def)return "reminderPY_"..tostring(class).."_"..def.key end
local function Spot(def)
 local x=tonumber(Opt(SpotXKey(def)))
 local y=tonumber(Opt(SpotYKey(def)))
 if x==nil or y==nil then return nil end
 return x,y
end
local function SetSpot(def,x,y)
 SetOpt(SpotXKey(def),x);SetOpt(SpotYKey(def),y)
end
local function ClearSpots()
 for _,def in ipairs(Definitions())do
  if EraUIDB then EraUIDB[SpotXKey(def)]=nil;EraUIDB[SpotYKey(def)]=nil end
 end
 Save()
end

local function PetState()
 local dead=UnitIsDeadOrGhost("pet")
 if not T.Public(dead)then return nil end
 if dead then return "dead"end
 local exists=UnitExists("pet")
 if not T.Public(exists)then return nil end
 return exists and "alive"or "missing"
end
local function DefState(def,cache)
 local kind=def.kind or "aura"
 if kind=="petDead"then
  local state=PetState()
  if not state then return nil end
  return state=="dead",state=="dead"and "Revive your pet"or "Pet is not dead"
 end
 if kind=="pet"then
   local state=PetState()
   if not state then return nil end
   if state=="missing"then return true,"No pet summoned"end
   if state=="dead"then return not def.missingOnly,"Pet is dead"end
   local choice=ChoiceOf(def)
   if choice and choice.family then
    if not UnitCreatureFamily or not(C_CreatureInfo and C_CreatureInfo.GetCreatureFamilyInfo)then return nil end
    local ok,family=pcall(UnitCreatureFamily,"pet")
    local good,info=pcall(C_CreatureInfo.GetCreatureFamilyInfo,choice.family)
    if not ok or not good or not T.Public(family)or type(family)~="string"or not info or not T.Public(info.name)then return nil end
    return family~=info.name,family==info.name and "Selected demon is out"or "Different demon summoned"
   end
   return false,"Pet is alive"
 end
 if kind=="item"then
  local n=ItemCount(def.items)
  return n==0,n>0 and("In bags: "..n)or "None in bags"
 end
 if kind=="imbue"then
   local state=T.WeaponCoating(def.weapon=="off"and 17 or 16)
   if not state then return nil,"Coating data unavailable"end
   if not state.weapon then return false,"No weapon equipped"end
   local hand=(def.weapon=="off")and "Off hand"or "Main hand"
   if not state.has then return true,hand.." empty"end
   if class=="ROGUE"then
    local poison=T.CoatingIsPoison(state)
    if poison==nil then return nil,"Coating type unconfirmed"end
    return not poison,poison and(hand.." poison applied")or(hand.." has another coating")
   end
   local choice=ChoiceOf(def)
   if not state.kind then return nil,"Coating type unconfirmed"end
   if choice then return state.kind~=choice.key,state.kind==choice.key and "Selected imbue applied"or "Different coating applied"end
   local imbue=state.kind=="rockbiter"or state.kind=="flametongue"or state.kind=="frostbrand"or state.kind=="windfury"
   return not imbue,imbue and "Weapon imbue applied"or "Different coating applied"
 end
 if kind=="shards"then
  local n=T.Count(6265)
  local low=tonumber(Opt("reminderShards"))or 5
  return n<low,n.." of "..low
 end
 if kind=="totems"then
  if not GetTotemInfo then return nil end
   local unknown=false
   for i=1,4 do
    local ok,has,name,_,_,_,_,spell=pcall(GetTotemInfo,i)
    if not ok or not T.Public(has)then unknown=true
    elseif has then
     if not def.ids then return false,"At least one totem active"end
     if not T.Public(spell)or not T.Public(name)then unknown=true
     else
      for _,id in ipairs(def.ids)do
       local expected=T.Spell(id)
       if spell==id or(expected and name==expected)then return false,"Windfury Totem active"end
      end
     end
    end
   end
   if unknown then return nil end
   return true,def.ids and "Windfury Totem missing"or "No totems active"
 end
 if kind=="cooldown"then
  local known,ready=false,false
  for _,id in ipairs(def.ids or{})do
   if T.Known(id)then
    known=true
    if GetSpellCooldown then
     local ok,start,dur=pcall(GetSpellCooldown,id)
     if ok and T.Number(start)and T.Number(dur)and(start==0 or dur==0)then ready=true end
    end
   end
  end
  if not known then return nil end
  return ready,ready and "Ready to use"or "On cooldown"
 end
 if def.items then
  local n=ItemCount(def.items)
  if n==0 then return false,"No stone in bags"end
 end
 local choice=ChoiceOf(def)
 local ids,auras=def.ids,def.auras
 if choice then ids=choice.ids;auras=nil end
 local names={}
 local total,checked,unknown=0,0,false
 for _,unit in ipairs(UnitsToCheck(def))do
   if Eligible(unit,def,choice)then
    local set=AuraSet(unit,cache)
    if set then
     checked=checked+1
    local has=false
    for _,id in ipairs(ids or{})do if set[id]then has=true break end end
    if not has then
     for _,id in ipairs(auras or{})do if set[id]then has=true break end end
    end
     if not has and def.nameMatch and not choice then
      local found=AuraByName(unit,def.nameMatch)
      if found==nil then unknown=true;has=nil else has=found end
     end
     if has and def.anyTarget then return false,unit=="player"and "Soulstone active on you"or "Soulstone active on a group member"end
     if has==false then
      total=total+1
      if #names<3 then
       if unit=="player"then
        names[#names+1]="you"
       else
        local un=UnitName(unit)
        names[#names+1]=(T.Public(un)and type(un)=="string"and un)or unit
       end
      end
     end
    else unknown=true end
   end
 end
 if def.anyTarget then
  if unknown or checked==0 then return nil end
  return true,"No checked member has Soulstone"
 end
 if total==0 then if unknown or checked==0 then return nil end;return false,"Active"end
 if total>#names then names[#names+1]="+"..(total-#names).." more"end
 if #names==1 and names[1]=="you"then return true,"Not active"end
 return true,"Missing on "..table.concat(names,", ")
end

-- Only spell-backed reminders have a click action. Ambiguous "Any" selections
-- need a chosen spell, unless the definition supplies an explicit cast default.
local function ClickSpell(def)
 if def.noCast then return nil end
 local choice=ChoiceOf(def)
 if def.choices and not choice and not def.castIds then return nil end
 return HighestKnown(choice and choice.ids or def.castIds or def.ids)
end
local function Disarm(row)
 if InCombatLockdown()or not row.action then return end
 row.action:SetAttribute("type1",nil)
 row.action:SetAttribute("macrotext1",nil)
 row.action:Hide()
end
local function DisarmAll()
 for _,row in ipairs(rows or{})do Disarm(row)end
end
local function SyncClick(row,def,missing)
 if InCombatLockdown()then return end
 local id=Clickable()and not preview and missing and ClickSpell(def)
 local name=id and T.Spell(id)
 if not T.Public(name)or type(name)~="string"or name==""then Disarm(row);return end
 local x,y=row.iconFrame:GetCenter()
 if not T.Number(x)or not T.Number(y)then Disarm(row);return end
 local action=row.action
 if not action then
  -- Independent parent AND screen-space anchors: alert rows remain free to
  -- show, hide, move and recycle while in combat, without protected descendants.
  action=CreateFrame("Button",nil,UIParent,"SecureActionButtonTemplate,SecureHandlerStateTemplate")
  row.action=action
  action:Hide();action:SetFrameStrata("HIGH")
  action:RegisterForClicks("LeftButtonUp","LeftButtonDown")
  action:SetAttribute("_onstate-combat",[[
   if newstate == "1" then
    self:SetAttribute("type1", nil)
    self:SetAttribute("macrotext1", nil)
    self:Hide()
   end
  ]])
  RegisterStateDriver(action,"combat","[combat] 1; 0")
  local glow=action:CreateTexture(nil,"HIGHLIGHT")
  glow:SetAllPoints();glow:SetColorTexture(1,1,1,.12)
 end
 local ratio=row.iconFrame:GetEffectiveScale()/UIParent:GetEffectiveScale()
 action:SetSize(row.iconFrame:GetWidth()*ratio,row.iconFrame:GetHeight()*ratio)
 action:ClearAllPoints();action:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x*ratio,y*ratio)
 action:SetFrameLevel(row.iconFrame:GetFrameLevel()+5)
 local group=def.group and not def.subgroup
 local condition=group and "[nocombat,@target,help,nodead][nocombat,@player]"
  or(def.self and "[nocombat,@player]"or "[nocombat]")
 action:SetAttribute("macrotext1","/cast "..condition.." "..name)
 action:SetAttribute("type1","macro")
 action:Show()
end

-- Alerts remain display-only, independently draggable. The optional secure
-- icon overlay exists only out of combat; text is always the drag handle.
local function Row(index)
 if not panel then return nil end
 local row=rows[index]
 if not row then
   -- Build presentation out of combat.
  if InCombatLockdown()then return nil end
  row=CreateFrame("Button",nil,panel)
  row:SetSize(380,134)
  row:SetMovable(true)
  row:SetClampedToScreen(true)
  row:RegisterForDrag("LeftButton")
  row.text=row:CreateFontString(nil,"OVERLAY")
  row.text:SetPoint("TOP",0,0);row.text:SetJustifyH("CENTER")
  row.text:SetShadowColor(0,0,0,1);row.text:SetShadowOffset(1.5,-1.5)
  row.iconFrame=CreateFrame("Frame",nil,row,"BackdropTemplate")
  row.iconFrame:SetSize(52,52)
  row.iconFrame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
  row.iconFrame:SetBackdropColor(0,0,0,.55)
  row.icon=row.iconFrame:CreateTexture(nil,"ARTWORK")
  row.icon:SetPoint("TOPLEFT",2,-2);row.icon:SetPoint("BOTTOMRIGHT",-2,2);row.icon:SetTexCoord(.07,.93,.07,.93)
  row.sub=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  row.sub:SetJustifyH("CENTER");row.sub:SetTextColor(.85,.87,.9)
  row:SetScript("OnDragStart",function(self)
   if InCombatLockdown()then return end
   DisarmAll()
   dragging=true
   self:StartMoving()
  end)
  row:HookScript("OnHide",function(self)Disarm(self)end)
  row:SetScript("OnDragStop",function(self)
   if InCombatLockdown()then dragging=false;return end
   self:StopMovingOrSizing()
   if panel and self.def then
    local left,top=self:GetLeft(),self:GetTop()
    local pl,pt=panel:GetLeft(),panel:GetTop()
    if left and top and pl and pt then
     local x,y=left-pl,top-pt
     self:ClearAllPoints();self:SetPoint("TOPLEFT",panel,"TOPLEFT",x,y)
     SetSpot(self.def,x,y)
    end
   end
   dragging=false
   M:Refresh()
  end)
  rows[index]=row
 end
 return row
end

local function Paint()
 if not panel or dragging then return end
 local mapOpen=WorldMapFrame and WorldMapFrame:IsShown()
 if not Enabled()or(mapOpen)or(InCombatLockdown()and not CombatOn())then
  for _,row in ipairs(rows)do row:Hide();Disarm(row)end
  panel:Hide()
  return
 end
 local size=SIZES[SizeIndex()]
 local cache=Cache()
 local n=0
 local stacked=0
 for _,def in ipairs(Definitions())do
   local show=false
   local detail
   local actionable=false
  if Applicable(def)then
   local on=DefOn(def)
   if on then
    local missing,info=DefState(def,cache)
     if missing==true then show=true;detail=info;actionable=true
    elseif preview then show=true;detail=(info or "Check unavailable").."  (preview)"end
   elseif preview then
    show=true;detail="Switched off"
   end
  end
  if show then
   n=n+1
   local row=Row(n)
   if row then
    local r,g,b=DefColor(def)
    row.def=def
    row.text:SetFont(select(1,GameFontHighlight:GetFont()),size.text,"")
    row.text:SetText(AlertText(def))
    row.text:SetTextColor(r,g,b)
    row.text:SetPoint("TOP",0,0)
    row.iconFrame:SetSize(size.icon,size.icon)
    row.iconFrame:SetPoint("TOP",0,-(size.text+4))
    row.iconFrame:SetBackdropBorderColor(r*.65,g*.65,b*.65,1)
    row.icon:SetTexture(Icon(def))
    row.sub:SetFont(select(1,GameFontHighlightSmall:GetFont()),size.sub,"")
    row.sub:SetPoint("TOP",0,-(size.text+size.icon+8))
    row.sub:SetText(detail or"")
    local width=row.text:GetStringWidth()
     row:SetWidth(math.max(190,math.min(460,(tonumber(width)or 260)+36)))
     row.sub:SetWidth(row:GetWidth()-8)
     row.sub:SetWordWrap(true)
    row:SetHeight(size.row-6)
    row:EnableMouse(true)
    local spotX,spotY=Spot(def)
    row:ClearAllPoints()
    if spotX then
     spotX=math.max(-1900,math.min(1900,spotX))
     spotY=math.max(-1600,math.min(950,spotY))
     row:SetPoint("TOPLEFT",panel,"TOPLEFT",spotX,spotY)
    else
     stacked=stacked+1
     row:SetPoint("TOP",0,-(stacked-1)*size.row)
    end
     row:Show()
     SyncClick(row,def,actionable)
   end
  end
 end
 for i=n+1,#rows do rows[i]:Hide();Disarm(rows[i])end
 if n==0 then panel:Hide()else panel:SetHeight(math.max(stacked,1)*SIZES[SizeIndex()].row);panel:Show()end
end

local function Build()
 if panel then return end
 rows={}
 panel=CreateFrame("Frame","EraUIClassReminderAlerts",UIParent)
 panel:SetSize(460,134)
 panel:SetPoint("TOP",UIParent,"CENTER",0,DEFAULT_Y)
 panel:SetFrameStrata("HIGH")
 panel:HookScript("OnHide",DisarmAll)
end

local function ToggleRow(parent,label,get,set,width)
 local b=CreateFrame("CheckButton",nil,parent)
 b:SetSize(width or 328,24)
 b.label=T.Text(b,label,11);b.label:SetPoint("LEFT",8,0);b.label:SetWidth((width or 328)-50)
 b.label:SetJustifyH("LEFT")
 b.track=CreateFrame("Frame",nil,b,"BackdropTemplate")
 b.track:SetSize(30,16);b.track:SetPoint("RIGHT",-6,0)
 b.track:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
 b.thumb=b.track:CreateTexture(nil,"ARTWORK");b.thumb:SetSize(12,12)
 local function paint()
  local v=get()
  local r,g,bl=T.Colour()
  b.track:SetBackdropColor(.08,.09,.11,1)
  b.track:SetBackdropBorderColor(v and r or .28,v and g or .30,v and bl or .34,1)
  if v then b.thumb:SetColorTexture(r,g,bl,1)else b.thumb:SetColorTexture(.3,.32,.36,1)end
  b.thumb:ClearAllPoints()
  b.thumb:SetPoint("CENTER",b.track,v and 6 or -6,0)
  b.label:SetTextColor(v and r or .7,v and g or .73,v and bl or .78)
 end
 b:SetScript("OnClick",function()
  if InCombatLockdown()then return end
  set(not get());paint();M:Refresh()
 end)
 paint()
 b.draw=paint
 return b
end
local function ActionButton(parent,label,width)
 local b=T.Button(parent,label or"",width or 328,24)
 b.label:ClearAllPoints();b.label:SetPoint("CENTER")
 b.label:SetFont(select(1,GameFontHighlight:GetFont()),11,"")
 local r,g,bl=T.Colour()
 b:SetBackdropColor(r*.1,g*.1,bl*.1,1)
 b:SetScript("OnEnter",function(self)self:SetBackdropColor(r*.24,g*.24,bl*.24,1)end)
 b:SetScript("OnLeave",function(self)self:SetBackdropColor(r*.1,g*.1,bl*.1,1)end)
 return b
end

local function BuildOptions(parent,anchor)
 if dropdown then return dropdown end
 local items={}
 dropdown=CreateFrame("Frame",nil,parent,"BackdropTemplate")
 T.BindInlinePanel(dropdown,anchor)
 dropdown:SetSize(352,190)
 dropdown:SetPoint("TOPLEFT",anchor,"BOTTOMLEFT",0,-6)
 dropdown:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
 dropdown:SetBackdropColor(.026,.029,.037,.99)
 local r,g,b=T.Colour()
 dropdown:SetBackdropBorderColor(.19,.20,.24,1)
 local group=ToggleRow(dropdown,"Check my party and raid",GroupOn,function(v)SetOpt("reminderGroup",v)end)
  local combat=ToggleRow(dropdown,"Show during combat",CombatOn,function(v)SetOpt("reminderCombat",v)end)
  local clickable=ToggleRow(dropdown,"Clickable reminders (outside combat)",Clickable,function(v)SetOpt("reminderClickable",v)end)
 local prev=ToggleRow(dropdown,"Show all reminders",function()return preview end,function(v)preview=v end)
 local size=ActionButton(dropdown,"",158)
 size.draw=function()size.label:SetText("Alert size: "..SIZES[SizeIndex()].key.."  >")end
 size:SetScript("OnClick",function()
  if InCombatLockdown()then return end
  local next=SizeIndex()+1
  if next>#SIZES then next=1 end
  SetOpt("reminderSize",next);size.draw();M:Refresh()
 end)
 local reset=ActionButton(dropdown,"Reset alert positions",158)
 reset:SetScript("OnClick",function()
  if InCombatLockdown()then return end
  ClearSpots();M:Refresh()
 end)
 local adv=ActionButton(dropdown,"Advanced v")
 adv:SetScript("OnClick",function()
  if InCombatLockdown()then return end
  local advanced=dropdown.advanced
  dropdown.advanced=not advanced
  adv.label:SetText(dropdown.advanced and "Advanced ^"or "Advanced v")
  M:LayoutDropdown()
 end)
 local advRows={}
 for _,def in ipairs(Definitions())do
  local key=DefKey(def)
  local default=not def.off
  local get=function()
   local v=Opt(key)
   if v==nil then return default end
   return v==true
  end
  advRows[#advRows+1]=ToggleRow(dropdown,def.text or def.key,get,function(v)SetOpt(key,v)end,170)
  if def.choices then
   local cbtn=ActionButton(dropdown,"",170)
   cbtn.draw=function()
    local choice=ChoiceOf(def)
    cbtn.label:SetText((def.choiceLabel or "Spell")..": "..(choice and choice.name or "Any").."  >")
   end
   cbtn:SetScript("OnClick",function()
    if InCombatLockdown()then return end
    CycleChoice(def);cbtn.draw();M:Refresh()
   end)
   cbtn.draw()
   advRows[#advRows+1]=cbtn
  end
 end
  items[#items+1]=group;items[#items+1]=combat;items[#items+1]=clickable;items[#items+1]=prev
 items[#items+1]=size;items[#items+1]=reset;items[#items+1]=adv
 for _,frame in ipairs(advRows)do items[#items+1]=frame end
 dropdown.offHint=T.Text(dropdown,"Turn on Class Reminders & Buffs to use these options.",10,true)
 dropdown.offHint:SetPoint("BOTTOMLEFT",12,8);dropdown.offHint:SetWidth(326);dropdown.offHint:SetJustifyH("LEFT")
 dropdown.items=items
  dropdown.group,dropdown.combat,dropdown.prev=group,combat,prev
  dropdown.clickable=clickable
 dropdown.size,dropdown.reset,dropdown.adv,dropdown.advRows=size,reset,adv,advRows
 dropdown:Hide()
 return dropdown
end

function M:LayoutDropdown()
 if not dropdown then return end
 dropdown.group.draw();dropdown.combat.draw();dropdown.prev.draw()
 local y=-8
 local function place(frame)
  if not frame then return end
  if frame.draw then frame.draw()end
  frame:ClearAllPoints();frame:SetPoint("TOPLEFT",12,y);frame:Show();y=y-26
 end
  place(dropdown.group);place(dropdown.combat);place(dropdown.clickable);place(dropdown.prev)
 if dropdown.size then
  if dropdown.size.draw then dropdown.size.draw()end
  dropdown.size:ClearAllPoints();dropdown.size:SetPoint("TOPLEFT",12,y);dropdown.size:Show()
 end
 if dropdown.reset then
  dropdown.reset:ClearAllPoints();dropdown.reset:SetPoint("TOPLEFT",182,y);dropdown.reset:Show()
 end
 y=y-26
 place(dropdown.adv)
 local column=0
 for _,frame in ipairs(dropdown.advRows)do
  if dropdown.advanced then
   if frame.draw then frame.draw()end
   frame:ClearAllPoints()
   frame:SetPoint("TOPLEFT",12+column*170,y)
   frame:Show()
   column=column+1
   if column>=2 then column=0;y=y-26 end
  else
   frame:Hide()
  end
 end
 if column>0 then y=y-26 end
 dropdown:SetHeight(-y+24)
 self:UpdateOptionsState()
end
function M:UpdateOptionsState()
 if not dropdown then return end
 local on=Enabled()
 dropdown:SetAlpha(on and 1 or .45)
 for _,frame in ipairs(dropdown.items)do
  if on then if frame.Enable then frame:Enable()end
  else if frame.Disable then frame:Disable()end end
 end
 if dropdown.offHint then dropdown.offHint:SetShown(not on)end
end
function M:OptionsPanel()
 return dropdown
end
function M:AttachOptions(parent,anchor)
 parent=anchor:GetParent()
 if not dropdown then BuildOptions(parent,anchor)end
 if dropdown:GetParent()~=parent then dropdown:SetParent(parent)end
 dropdown:ClearAllPoints()
 dropdown:SetPoint("TOPLEFT",anchor,"BOTTOMLEFT",0,-6)
 self:LayoutDropdown()
 dropdown:Show()
end
function M:HideOptions()
 if dropdown then dropdown:Hide()end
end

function M:Refresh()
 if not class then local _,c=UnitClass("player");class=c end
 if not E.ReminderSpells[class]then return end
 if not panel then Build()end
 -- Combat can produce the first alert of a session (for example a pet death).
 -- Prepare ordinary display rows beforehand so that case needs no new frames.
 if Enabled()and not InCombatLockdown()then
  for i=#rows+1,#Definitions()do Row(i):Hide()end
 end
 if WorldMapFrame and mapHooked~=WorldMapFrame then
  mapHooked=WorldMapFrame
  mapHooked:HookScript("OnShow",function()M:Refresh()end)
  mapHooked:HookScript("OnHide",function()M:Refresh()end)
 end
 Paint()
end
function M:Open()
 if InCombatLockdown()then E:Print("Open class reminders after combat.");return end
 if not class then local _,c=UnitClass("player");class=c end
 if not E.ReminderSpells[class]then E:Print("No class reminders for this class.");return end
 if not Enabled()then E:Print("Turn on Class Reminders & Buffs in your class settings first (/era).");return end
 if E.Classic and E.Classic.OpenOptions then E.Classic.OpenOptions()end
 C_Timer.After(.25,function()
  local frame,anchor=M.settingsFrame,M.settingsAnchor
  if frame and anchor and frame:IsShown()then M:AttachOptions(frame,anchor)end
 end)
end
function M:Initialize()
 local _,c=UnitClass("player");class=c
 if not E.ReminderSpells[class]then return end
 -- Positions saved by the earlier dragging build can be off screen; clear once.
 if Opt("reminderSpotVersion")~=2 then
  ClearSpots()
  SetOpt("reminderSpotVersion",2)
 end
 self:Refresh()
 local events=CreateFrame("Frame")
 for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","SPELLS_CHANGED",
  "BAG_UPDATE_DELAYED","UNIT_AURA","UNIT_PET","PLAYER_TOTEM_UPDATE","UNIT_INVENTORY_CHANGED","GROUP_ROSTER_UPDATE",
  "PLAYER_LEVEL_UP","PLAYER_EQUIPMENT_CHANGED","UNIT_HEALTH","UNIT_FLAGS","UNIT_CONNECTION"})do
  pcall(events.RegisterEvent,events,event)
 end
 local dirty=true;local elapsed=0
 events:SetScript("OnEvent",function(_,event)
  if event=="UNIT_AURA"or event=="GROUP_ROSTER_UPDATE"or event=="PLAYER_ENTERING_WORLD"or event=="PLAYER_REGEN_ENABLED"then
   groupCache.units={};groupCache.at=GetTime()
  end
  dirty=true
 end)
 events:SetScript("OnUpdate",function(_,dt)
  elapsed=elapsed+dt
  if(dirty and elapsed>.5)or elapsed>2 then elapsed=0;dirty=false;M:Refresh()end
 end)
end
