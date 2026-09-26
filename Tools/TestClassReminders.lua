-- Run from the addon root. Exercise the real detection functions with public,
-- unavailable and restricted API data, without simulating protected UI behavior.
local checks=0
local function equal(got,want,label)
 checks=checks+1;assert(got==want,label..": expected "..tostring(want)..", got "..tostring(got))
end
local function up(fn,wanted,seen)
 seen=seen or{};if seen[fn]then return end;seen[fn]=true
 for i=1,100 do
  local name,value=debug.getupvalue(fn,i);if not name then break end
  if name==wanted then return value end
  if type(value)=="function"then local found=up(value,wanted,seen);if found~=nil then return found end end
 end
end
local secret={}
issecretvalue=function(v)return v==secret end
local class,known,units,auras,raid,n,frames,time
local weapons,coatings,totems
local function unit(token)return units[token]or{}end
UnitClass=function(token)return "Class",token=="player"and class or unit(token).class or "PRIEST"end
UnitLevel=function()return 60 end
UnitExists=function(token)return unit(token).exists==true end
UnitCanAssist=function(_,token)return unit(token).friendly~=false end
UnitIsConnected=function(token)return unit(token).online~=false end
UnitIsDeadOrGhost=function(token)return unit(token).dead or false end
UnitInRange=function(token)return unit(token).near~=false,true end
UnitIsUnit=function(a,b)return a==b or(unit(b).player==true and a=="player")end
UnitName=function(token)return unit(token).name or token end
IsInRaid=function()return raid end
GetNumGroupMembers=function()return n end
GetNumSubgroupMembers=function()return n end
GetRaidRosterInfo=function(i)return "Name",nil,unit("raid"..i).group end
GetTime=function()return time end
InCombatLockdown=function()return false end
GetInventoryItemID=function(_,slot)return weapons[slot]end
C_Item={GetItemInfoInstant=function(id)return id,nil,nil,nil,nil,id==200 and 4 or 2 end}
local spells={[688]="Summon Imp",[697]="Summon Voidwalker",[8232]="Windfury Weapon",[8024]="Flametongue Weapon",
 [8512]="Windfury Totem",[10613]="Windfury Totem",[10614]="Windfury Totem",[8681]="Instant Poison"}
C_Spell={GetSpellInfo=function(id)return {name=spells[id]or("Spell"..id),iconID=id}end}
GetSpellInfo=function(id)return spells[id]or("Spell"..id),nil,id end
IsPlayerSpell=function(id)return known[id]==true end
IsSpellKnown=function(id)return known[id]==true end
local counts={}
GetItemCount=function(id)return counts[id]or 0 end
C_Item.GetItemCount=GetItemCount
local families={[23]="Imp",[16]="Voidwalker",[17]="Succubus",[15]="Felhunter",[310]="Felguard"}
C_CreatureInfo={GetCreatureFamilyInfo=function(id)return {name=families[id]}end}
UnitCreatureFamily=function()return unit("pet").family end
C_UnitAuras={GetAuraDataByIndex=function(token,i)
 local list=auras[token];if list==false then error("unavailable")end
 local id=(list or{})[i];if id then return {spellId=id,name="Aura"}end
end}
GetTotemInfo=function(slot)
 local t=totems[slot];if t==secret then return secret end
 if t then return true,t.name,0,120,1,1,t.spell end
 return false,"",0,0,0,1,0
end
CreateFrame=function()
 local f={scripts={}}
 for _,method in ipairs({"SetSize","SetPoint","SetFrameStrata","Hide","RegisterEvent"})do f[method]=function()end end
  function f:SetScript(name,fn)self.scripts[name]=fn end
  function f:HookScript()end
 frames[#frames+1]=f;return f
end
local function Session(c)
 class=c;known={};units={player={exists=true},pet={}};auras={};raid=false;n=0;frames={};time=10
 weapons={[16]=100,[17]=100};coatings={};totems={};counts={}
 C_PaperDollInfo={GetTemporaryEnchantmentInfo=function(slot)return coatings[slot]end}
 EraUIDB={reminderSpotVersion=2}
 local E={modules={},settingDefaults={}}
 function E:RegisterModule(name,m)self.modules[name]=m end
 function E:GetSetting()return false end -- No UI; detection below still uses real functions.
 assert(loadfile("Modules/ClassTools.lua"))("EraUI",E)
 assert(loadfile("Modules/ClassReminderData.lua"))("EraUI",E)
 assert(loadfile("Modules/PoisonReminders.lua"))("EraUI",E)
 assert(loadfile("Modules/ClassReminders.lua"))("EraUI",E)
 local M=E.modules.ClassReminders
 M:Initialize()
 local state=assert(up(M.Refresh,"DefState"))
 local defs={};for _,d in ipairs(E.ReminderSpells[c])do defs[d.key]=d end
 local function check(key)return state(defs[key],up(M.Refresh,"Cache")())end
 local function event(name)frames[#frames].scripts.OnEvent(nil,name)end
 return E,check,defs,event
end
local E,check,defs,event=Session("HUNTER")
known[883]=true;known[982]=true
equal(check("pet"),true,"missing hunter pet")
equal(check("petDead"),false,"absent pet is not reported dead")
units.pet={exists=true,dead=true}
local missing,detail=check("pet")
equal(missing,false,"dead hunter pet does not also request Call Pet");equal(detail,"Pet is dead","dead pet explanation")
equal(check("petDead"),true,"dead hunter pet has dedicated reminder")
units.pet.exists=false
equal(check("petDead"),true,"known dead state wins over missing unit")
equal(check("pet"),false,"dead dismissed unit does not request Call Pet")
units.pet.exists=true
units.pet.dead=false;equal(check("pet"),false,"living hunter pet")
equal(check("petDead"),false,"living pet needs no revival")
units.pet.dead=secret;equal(check("pet"),nil,"restricted pet death state")
equal(check("petDead"),nil,"restricted state never proves death")
known[883]=nil
equal(up(E.modules.ClassReminders.Refresh,"Applicable")(defs.pet),false,"unlearned Call Pet does not alert")
known[982]=nil
equal(up(E.modules.ClassReminders.Refresh,"Applicable")(defs.petDead),false,"unlearned Revive Pet does not alert")

E,check,defs,event=Session("WARLOCK")
for _,choice in ipairs(defs.pet.choices)do
 if choice.family then
  known[choice.ids[1]]=true;EraUIDB.reminderChoice_WARLOCK_pet=choice.ids[1]
  units.pet={exists=true,family=families[choice.family]}
  equal(check("pet"),false,"correct "..choice.key)
  units.pet.family="Different demon";equal(check("pet"),true,"wrong "..choice.key)
 end
end
units.pet.family=secret;equal(check("pet"),nil,"restricted demon family")
EraUIDB.reminderChoice_WARLOCK_pet=0;equal(check("pet"),false,"any demon does not require identity")
units.pet.dead=true;equal(check("pet"),true,"dead demon does not count")

E,check,defs,event=Session("ROGUE")
equal(check("poisonMain"),true,"bare main-hand weapon")
coatings[16]={enchantID=323,remainingTimeMs=600000,chargesRemaining=50}
coatings[17]={enchantID=7,remainingTimeMs=600000,chargesRemaining=50}
equal(check("poisonMain"),false,"main-hand poison")
equal(check("poisonOff"),false,"off-hand poison")
coatings[17]=nil;equal(check("poisonOff"),true,"main enchant cannot satisfy bare off hand")
weapons[17]=200;equal(check("poisonOff"),false,"shield needs no poison")
equal(E.modules.PoisonReminders:Snapshot(17),nil,"poison panel also skips shield")
weapons[17]=nil;equal(check("poisonOff"),false,"empty off-hand slot needs no poison")
weapons[17]=100;coatings[17]={enchantID=283,chargesRemaining=0}
equal(check("poisonOff"),true,"Windfury is not poison")
equal(E.modules.PoisonReminders:Snapshot(17).warning,true,"poison panel agrees about different coating")
coatings[17]={enchantID=999999};equal(check("poisonOff"),nil,"unknown coating is unconfirmed")
equal(E.modules.PoisonReminders:Snapshot(17).badge,"CHECK","panel marks unknown coating")
coatings[17]={enchantID=22,chargesRemaining=0}
equal(check("poisonOff"),false,"zero-charge poison is still active")
equal(E.modules.PoisonReminders:Snapshot(17).warning,false,"zero charges not a low warning")
coatings[16].remainingTimeMs=59000
equal(E.modules.PoisonReminders:Snapshot(16).warning,true,"low-duration warning retained")
coatings[16].remainingTimeMs=600000;coatings[16].chargesRemaining=9
equal(E.modules.PoisonReminders:Snapshot(16).warning,true,"low-charge warning retained")
C_PaperDollInfo.GetTemporaryEnchantmentInfo=function()error("unavailable")end
equal(check("poisonMain"),nil,"API failure is not missing poison")
C_PaperDollInfo=nil
GetWeaponEnchantInfo=function()return true,600000,50,323,true,600000,50,7 end
equal(check("poisonOff"),false,"legacy fifth return is off-hand flag")
GetWeaponEnchantInfo=function()return true,600000,50,323,false,0,0,nil end
equal(check("poisonOff"),true,"legacy false off-hand never falls back to main")
GetWeaponEnchantInfo=function()return true,600000,50,nil,nil,0,0,nil end
equal(check("poisonOff"),true,"legacy nil off-hand means no enchant")
GetWeaponEnchantInfo=function()return true,600000,50,323,secret,0,0,7 end
equal(check("poisonOff"),nil,"restricted legacy flag")

E,check,defs,event=Session("SHAMAN")
local applicable=up(E.modules.ClassReminders.Refresh,"Applicable")
equal(applicable(defs.totems),false,"untrained shaman has no totem alert")
known[8071]=true;equal(applicable(defs.totems),true,"learned totem enables generic reminder")
equal(applicable(defs.windfuryTotem),false,"Windfury not shown before learned")
known[10614]=true;equal(applicable(defs.windfuryTotem),true,"higher Windfury rank enables reminder")
known[8232]=true;known[8024]=true;EraUIDB.reminderChoice_SHAMAN_imbue=8232
coatings[16]={enchantID=283}
equal(check("imbue"),false,"selected Windfury weapon")
coatings[16].enchantID=5;equal(check("imbue"),true,"Flametongue cannot satisfy selected Windfury")
EraUIDB.reminderChoice_SHAMAN_imbue=8024;equal(check("imbue"),false,"selected Flametongue")
coatings[16].enchantID=1783;equal(check("imbue"),true,"totem coating cannot satisfy own imbue")
EraUIDB.reminderChoice_SHAMAN_imbue=0;equal(check("imbue"),true,"any imbue still excludes totem coating")
coatings[16].enchantID=1668;equal(check("imbue"),false,"any imbue accepts Frostbrand")
equal(check("totems"),true,"no totems")
totems[1]={spell=3599,name="Searing Totem"}
equal(check("totems"),false,"generic check explicitly requires any totem")
equal(check("windfuryTotem"),true,"fire totem cannot satisfy Windfury")
totems[4]={spell=10614,name="Windfury Totem"}
equal(check("windfuryTotem"),false,"highest Windfury rank")
totems[4]={name="Windfury Totem"};equal(check("windfuryTotem"),false,"legacy name-only totem API")
totems[4]=secret;equal(check("windfuryTotem"),nil,"restricted totem data")

E,check,defs,event=Session("PRIEST")
raid=true;n=6;auras.player={1243}
for i=1,n do units["raid"..i]={exists=true,name="Member"..i}end
units.raid1.player=true
units.raid2.dead=true;units.raid3.online=false;units.raid4.near=false;units.raid5.friendly=false
auras.raid6={1243}
equal(check("fortitude"),false,"skip duplicate player, corpses, offline, distant, hostile")
auras.raid6={};event("UNIT_AURA")
missing,detail=check("fortitude")
equal(missing,true,"nearby missing buff detected");equal(detail,"Missing on Member6","only eligible name listed")
auras.raid6={1243};event("UNIT_AURA")
equal(check("fortitude"),false,"aura event invalidates cached group data immediately")
auras.raid6={};event("GROUP_ROSTER_UPDATE")
equal(check("fortitude"),true,"roster event invalidates reassigned tokens")
EraUIDB.reminderGroup=false;equal(check("fortitude"),false,"group toggle off checks only self")
EraUIDB.reminderGroup=true
for i=2,n do units["raid"..i]={exists=true,name="Member"..i}end
event("UNIT_AURA");missing,detail=check("fortitude")
equal(detail,"Missing on Member2, Member3, Member4, +2 more","compact raid summary")
auras.player={secret};for i=2,n do auras["raid"..i]=false end;event("UNIT_AURA")
equal(check("fortitude"),nil,"unreadable aura data cannot mean Active or Missing")

E,check,defs,event=Session("MAGE")
raid=false;n=3;auras.player={1459}
units.party1={exists=true,class="WARRIOR"};units.party2={exists=true,class="ROGUE"}
units.party3={exists=true,class="DRUID"};auras.party3={1459}
equal(check("intellect"),false,"intellect skips warriors and rogues")
auras.party3={};event("UNIT_AURA");equal(check("intellect"),true,"druid still needs intellect in animal form")

E,check,defs,event=Session("WARRIOR")
raid=true;n=3;auras.player={6673}
units.raid1={exists=true,player=true,group=1};units.raid2={exists=true,group=1};units.raid3={exists=true,group=2}
auras.raid2={6673}
equal(check("battleShout"),false,"party-only shout skips other raid subgroup")
auras.raid2={};event("UNIT_AURA");equal(check("battleShout"),true,"own subgroup still checked")

E,check,defs,event=Session("PALADIN")
known[19742]=true;EraUIDB.reminderChoice_PALADIN_blessing=19742
n=2;auras.player={19742};units.party1={exists=true,class="WARRIOR"};units.party2={exists=true,class="ROGUE"}
equal(check("blessing"),false,"selected Wisdom skips non-mana classes")
units.party2.class="MAGE";equal(check("blessing"),true,"selected Wisdom checks mana class")

E,check,defs,event=Session("WARLOCK")
counts[5232]=1;n=2
units.party1={exists=true};units.party2={exists=true};auras.party1={20707}
equal(check("soulstoneApply"),false,"one protected member satisfies soulstone")
auras.party1={};event("UNIT_AURA");equal(check("soulstoneApply"),true,"no protected member with stone available")
auras.party1=false;event("UNIT_AURA");equal(check("soulstoneApply"),nil,"unknown member may already be protected")
counts[5232]=0;equal(check("soulstoneApply"),false,"no apply alert without a stone")
counts[5232]=1;EraUIDB.reminderGroup=false;auras.player={20707}
equal(check("soulstoneApply"),false,"self-only soulstone")
print("Class reminder detection checks passed: "..checks.." assertions.")
