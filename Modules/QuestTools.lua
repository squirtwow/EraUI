local _,EraUI=...
local M={};EraUI:RegisterModule("QuestTools",M)
local function Public(v)return not (issecretvalue and issecretvalue(v))end
local profiles={
 WARRIOR={{"Arms","strength"},{"Fury","strength"},{"Protection","tank"}},
 ROGUE={{"Assassination","agility"},{"Combat","agility"},{"Subtlety","agility"}},
 HUNTER={{"Beast Mastery","hunter"},{"Marksmanship","hunter"},{"Survival","hunter"}},
 MAGE={{"Arcane","caster"},{"Fire","caster"},{"Frost","caster"}},
 WARLOCK={{"Affliction","caster"},{"Demonology","caster"},{"Destruction","caster"}},
 PRIEST={{"Discipline","healer"},{"Holy","healer"},{"Shadow","caster"}},
 PALADIN={{"Holy","healer"},{"Protection","tank"},{"Retribution","strength"}},
 SHAMAN={{"Elemental","caster"},{"Enhancement","strength"},{"Restoration","healer"}},
 DRUID={{"Balance","caster"},{"Feral Cat","cat"},{"Feral Bear","bear"},{"Restoration","healer"}},
}
-- Transparent starter weights, not simulations or talent/weapon-speed models.
local weights={
 strength={STRENGTH=2,AGILITY=1,STAMINA=.3,ATTACK_POWER=1,DAMAGE_PER_SECOND=6,CRIT_RATING=1,HIT_RATING=1.3},
 agility={STRENGTH=1,AGILITY=2,STAMINA=.3,ATTACK_POWER=1,DAMAGE_PER_SECOND=6,CRIT_RATING=1.2,HIT_RATING=1.4},
 hunter={AGILITY=2,INTELLECT=.3,STAMINA=.3,RANGED_ATTACK_POWER=1,ATTACK_POWER=.2,CRIT_RATING=1.2,HIT_RATING=1.3},
 caster={INTELLECT=1,SPIRIT=.2,STAMINA=.3,SPELL_POWER=1.5,SPELL_DAMAGE_DONE=1.5,SPELL_CRIT_RATING=1,SPELL_HIT_RATING=1.2},
 healer={INTELLECT=1,SPIRIT=.8,STAMINA=.2,SPELL_POWER=1,SPELL_HEALING_DONE=1.5,MANA_REGENERATION=2},
 tank={STRENGTH=.6,AGILITY=.6,STAMINA=2,ARMOR=.025,DEFENSE_SKILL_RATING=1.5,DODGE_RATING=1.2,PARRY_RATING=1.2,BLOCK_RATING=1},
 cat={STRENGTH=2,AGILITY=2.2,STAMINA=.3,ATTACK_POWER=1,CRIT_RATING=1.2,HIT_RATING=1.3},
 bear={STRENGTH=.7,AGILITY=1,STAMINA=2,ARMOR=.04,DEFENSE_SKILL_RATING=1,DODGE_RATING=1.3},
}
local slots={INVTYPE_HEAD={1},INVTYPE_NECK={2},INVTYPE_SHOULDER={3},INVTYPE_CHEST={5},INVTYPE_ROBE={5},INVTYPE_WAIST={6},INVTYPE_LEGS={7},INVTYPE_FEET={8},INVTYPE_WRIST={9},INVTYPE_HAND={10},INVTYPE_FINGER={11,12},INVTYPE_TRINKET={13,14},INVTYPE_CLOAK={15},INVTYPE_WEAPON={16},INVTYPE_WEAPONMAINHAND={16},INVTYPE_2HWEAPON={16},INVTYPE_WEAPONOFFHAND={17},INVTYPE_SHIELD={17},INVTYPE_HOLDABLE={17},INVTYPE_RANGED={18},INVTYPE_RANGEDRIGHT={18},INVTYPE_THROWN={18}}
function M:Profile()
 local _,class=UnitClass("player")
 local list=profiles[class] or profiles.MAGE
 EraUIDB.rewardProfiles=EraUIDB.rewardProfiles or {}
 local i=EraUIDB.rewardProfiles[class] or 1
 if type(i)~="number" or not list[i] then i=1 end
 return list[i],list,i,class
end
function M:CycleProfile(direction)
 local _,list,i,class=self:Profile()
 EraUIDB.rewardProfiles[class]=(i-1+direction)%#list+1
 self:RefreshRewards()
end
function M:ProfileDescription()
 local profile=self:Profile();local parts={}
 for stat,value in pairs(weights[profile[2]])do parts[#parts+1]=stat:gsub("_"," "):lower()..": "..value end
 table.sort(parts)
 return profile[1].." — starter weights\n"..table.concat(parts,"\n").."\nNo proc, set-bonus, stat-cap or weapon-speed modelling."
end
local function Info(link)
 local get=C_Item and C_Item.GetItemInfo or GetItemInfo
 if not get then return end
 local name,_,_,_,_,_,_,_,loc=get(link)
 if Public(name) and name and Public(loc) then return loc end
end
function M:Score(link,loc)
 local get=C_Item and C_Item.GetItemStats or GetItemStats
 local stats=get and get(link)
 if not stats or not Public(stats) then return end
 local profile=self:Profile();local w=weights[profile[2]];local score=0
 for stat,value in pairs(stats)do
  if not Public(value) or type(value)~="number" then return end
  local key=stat:match("^ITEM_MOD_(.-)_SHORT$") or ((stat=="RESISTANCE0_NAME" or stat=="ARMOR_TEMPLATE") and "ARMOR")
  local weight=w[key] or (key=="ARMOR" and .01) or 0
  if profile[2]=="hunter" and key=="DAMAGE_PER_SECOND" and (loc=="INVTYPE_RANGED" or loc=="INVTYPE_RANGEDRIGHT" or loc=="INVTYPE_THROWN") then weight=6 end
  score=score+value*weight
 end
 return score
end
function M:Gain(link)
 local loc=Info(link);if not loc then return end
 local candidates=slots[loc]
 if not candidates then return false end
 local score=self:Score(link,loc);if not score then return end
 local lowest,empty
 for _,slot in ipairs(candidates)do
  local equipped=GetInventoryItemLink("player",slot)
  if not Public(equipped) then return end
  local old=0
  if equipped then
   local oldloc=Info(equipped);if not oldloc then return end
   -- Do not compare incompatible weapon configurations or add two DPS scores.
   if slot==16 and (oldloc=="INVTYPE_2HWEAPON")~=(loc=="INVTYPE_2HWEAPON") then return false end
   old=self:Score(equipped,oldloc);if not old then return end
  elseif slot==17 then
   local main=GetInventoryItemLink("player",16)
   if not Public(main) then return end
   if main and Info(main)=="INVTYPE_2HWEAPON" then return false end
  end
  if not equipped then empty=true end
  lowest=math.min(lowest or old,old)
 end
 return score-lowest,empty
end
local highlights={}
function M:Clear()
 for _,f in pairs(highlights)do f:Hide()end
end
function M:RefreshRewards()
 self:Clear()
 if not self.rewardOpen or not EraUI:GetSetting("rewardUpgradeHighlight") then return end
 if not GetNumQuestChoices or not GetQuestItemLink or not GetQuestItemInfo then return end
 local count=GetNumQuestChoices();if not Public(count) or type(count)~="number" or count<2 then return end
 local best,gain=nil,0
 local emptyChoices={} 
 for i=1,count do
  local _,_,_,_,usable=GetQuestItemInfo("choice",i)
  local link=GetQuestItemLink("choice",i)
  if not Public(link) or not Public(usable) then return end
  if usable and link then
   local delta,empty=self:Gain(link)
   if delta==nil then return end -- Wait for item data rather than recommend from partial data.
   if empty then emptyChoices[i]=true end
   if delta and delta>gain then best,gain=i,delta end
  end
 end
 if not best and not next(emptyChoices) then return end
 local rewards=QuestInfoFrame and QuestInfoFrame.rewardsFrame
 for _,button in ipairs(rewards and rewards.RewardButtons or {})do
  if button.type=="choice" and (button:GetID()==best or emptyChoices[button:GetID()]) and button:IsShown() then
   local f=highlights[button]
   if not f then
    f=CreateFrame("Frame",nil,button,"BackdropTemplate");highlights[button]=f
    f:SetPoint("TOPLEFT",-2,2);f:SetPoint("BOTTOMRIGHT",2,-2);f:EnableMouse(false)
    f:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=2});f:SetBackdropBorderColor(.3,1,.5,1)
    f.label=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    f.label:SetPoint("BOTTOMRIGHT",-4,2);f.label:SetTextColor(.3,1,.5)
    button:HookScript("OnEnter",function()
     if f:IsShown() and GameTooltip then
      GameTooltip:AddLine((f.empty and "Fills an empty equipment slot: " or "EraUI suggestion: ")..f.profile,.3,1,.5)
      GameTooltip:AddLine(f.empty and "Usable equipment for a currently empty slot. Compare the other rewards before choosing." or "Greatest positive stat-score gain among comparable rewards. Starter weights; not a simulation.",1,1,1,true)
      GameTooltip:Show()
     end
    end)
   end
   f.profile=self:Profile()[1]
   f.empty=emptyChoices[button:GetID()]
   if f.empty then f.label:SetText("Empty slot") else f.label:SetFormattedText("+%.1f",gain) end
   f:Show()
  end
 end
end
function M:ApplyMap()
 local get=C_CVar and C_CVar.GetCVar or GetCVar
 local set=C_CVar and C_CVar.SetCVar or SetCVar
 if not get or not set or get("questPOI")==nil then return end
 set("questPOI",EraUI:GetSetting("mapQuestObjectives") and "1" or "0")
end
function M:ReadMap()
 local get=C_CVar and C_CVar.GetCVar or GetCVar
 local value=get and get("questPOI")
 if value~=nil and Public(value) then EraUI:SetSetting("mapQuestObjectives",value=="1") end
end
function M:Initialize()
 self:ReadMap() -- Adopt Blizzard's current choice; setup Skip must not change it.
 local f=CreateFrame("Frame")
 for _,e in ipairs({"QUEST_COMPLETE","QUEST_FINISHED","QUEST_DETAIL","QUEST_PROGRESS","QUEST_ITEM_UPDATE","GET_ITEM_INFO_RECEIVED","PLAYER_EQUIPMENT_CHANGED","CVAR_UPDATE","PLAYER_ENTERING_WORLD"})do f:RegisterEvent(e)end
 f:SetScript("OnEvent",function(_,event,name)
  if event=="CVAR_UPDATE" then if Public(name) and type(name)=="string" and name:lower()=="questpoi" then self:ReadMap()end;return end
  if event=="PLAYER_ENTERING_WORLD" then self:ReadMap();return end
  if event=="QUEST_FINISHED" or event=="QUEST_DETAIL" or event=="QUEST_PROGRESS" then self.rewardOpen=false;self:Clear();return end
  if event=="QUEST_COMPLETE" then self.rewardOpen=true end
  if self.rewardOpen then C_Timer.After(0,function()self:RefreshRewards()end)end
 end)
end
