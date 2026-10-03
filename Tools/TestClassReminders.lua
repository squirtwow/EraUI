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
local level=60
UnitLevel=function()return level end
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
 [8512]="Windfury Totem",[10613]="Windfury Totem",[10614]="Windfury Totem",[8681]="Instant Poison",
 [2835]="Deadly Poison",[3420]="Crippling Poison",[5763]="Mind-numbing Poison",[13220]="Wound Poison"}
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
local function Session(c,data)
 class=c;known={};units={player={exists=true},pet={}};auras={};raid=false;n=0;frames={};time=10;level=60
 weapons={[16]=100,[17]=100};coatings={};totems={};counts={}
 C_PaperDollInfo={GetTemporaryEnchantmentInfo=function(slot)return coatings[slot]end}
 EraUIDB={reminderSpotVersion=2};EraUIClassicCharDB={}
 local E={modules={},settingDefaults={}}
 function E:RegisterModule(name,m)self.modules[name]=m end
 function E:GetSetting()return false end -- No UI; detection below still uses real functions.
 assert(loadfile("Modules/PoisonData.lua"))("EraUI",E)
 if data then data(E.PoisonData)end
 assert(loadfile("Modules/ClassTools.lua"))("EraUI",E)
 assert(loadfile("Modules/ClassReminderData.lua"))("EraUI",E)
 assert(loadfile("Modules/ClassReminderPoisons.lua"))("EraUI",E)
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

-- POISON!: one reminder for both hands. It says which hand needs a poison,
-- never mentions a hand without a weapon, and names the poison a click would
-- use when there is none of it to use.
E,check,defs,event=Session("ROGUE")
local P=E.ReminderPoisons
local function plain(s)return(tostring(s):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""))end
local function poison()local a,b,c=check("poison");return a,b and plain(b),c end
local fine={enchantID=323,remainingTimeMs=600000,chargesRemaining=50}
local function copy(t)local o={};for k,v in pairs(t)do o[k]=v end;return o end
equal(#E.ReminderSpells.ROGUE,1,"rogues have one poison reminder")
equal(defs.poison.text.." "..defs.poison.kind,"POISON! poison","it is POISON!, for both hands")
equal(defs.poisonMain==nil and defs.poisonOff==nil,true,"the two hand alerts are gone")
equal(defs.poison.off,nil,"on by default")
equal(defs.poison.minLevel,nil,"its level comes from the poison data, not a number of its own")
counts[8928]=1;counts[20844]=1 -- Instant Poison VI and Deadly Poison V in bags
missing,detail=poison()
equal(missing,true,"bare weapons need poison");equal(detail,"Main and off hand: no poison","both hands, said once")
coatings[16]=copy(fine);coatings[17]={enchantID=7,remainingTimeMs=600000,chargesRemaining=50}
missing,detail=poison()
equal(missing,false,"both hands poisoned");equal(detail,"Poison applied","says so")
coatings[17]=nil;missing,detail=poison()
equal(missing,true,"main enchant cannot satisfy a bare off hand");equal(detail,"Off hand: no poison","only the off hand is named")
weapons[17]=200;missing,detail=poison()
equal(missing,false,"a shield needs no poison");equal(detail,"Poison applied","and the off hand is never mentioned")
weapons[17]=nil;equal(poison(),false,"an empty off-hand slot needs no poison")
coatings[16]=nil;missing,detail=poison()
equal(detail,"Main hand: no poison","a two-hander: only the main hand")
weapons[16]=nil;missing,detail=poison()
equal(missing,false,"no weapons: nothing to poison");equal(detail,"No weapon equipped","says so")
weapons[16]=100;weapons[17]=100;coatings[16]=copy(fine)
coatings[17]={enchantID=283,chargesRemaining=0};missing,detail=poison()
equal(missing,true,"Windfury is not poison");equal(detail,"Off hand: another coating","says it has another coating")
coatings[17]={enchantID=999999};missing,detail=poison()
equal(missing,nil,"an unknown coating is unconfirmed");equal(detail,"Poison check unavailable","said in the preview")
coatings[16]=nil;equal(poison(),true,"an unconfirmed hand never hides a bare one")
coatings[16]=copy(fine);coatings[17]={enchantID=22,chargesRemaining=0}
equal(poison(),false,"zero charges is still a poison, not running out")
coatings[16].remainingTimeMs=45000;missing,detail=poison()
equal(missing,true,"under a minute left is about to run out");equal(detail,"Main hand: 0:45 left","with the time left")
coatings[16].remainingTimeMs=60000;equal(select(2,poison()),"Main hand: 1:00 left","a minute exactly counts")
coatings[16].remainingTimeMs=61000;equal(poison(),false,"just over a minute does not")
coatings[16].chargesRemaining=10;equal(select(2,poison()),"Main hand: 10 charges left","10 charges or fewer counts")
coatings[16].chargesRemaining=1;equal(select(2,poison()),"Main hand: 1 charge left","one charge")
coatings[16].chargesRemaining=11;equal(poison(),false,"11 charges does not")
coatings[16].remainingTimeMs=secret;coatings[16].chargesRemaining=secret
equal(poison(),false,"hidden time and charges are never read as low")
coatings[16]=copy(fine);coatings[16].remainingTimeMs=30000;coatings[17]=nil;missing,detail=poison()
equal(detail,"Main hand: 0:30 left\nOff hand: no poison","two hands, two lines")
coatings[17]={enchantID=7,remainingTimeMs=30000,chargesRemaining=50}
equal(select(2,poison()),"Main and off hand: 0:30 left","the same for both is said once")
local need=select(3,check("poison"))
equal(need.main and need.off,true,"both hands need one")
-- Clicks off (the default): the picks don't matter, so only no usable
-- poison at all is said.
counts={}
coatings[16]=nil;coatings[17]=nil;missing,detail=poison()
equal(detail,"Main and off hand: no poison\nNo poison in your bags","clicks off: no poison at all in your bags")
counts[3775]=1;equal(select(2,poison()),"Main and off hand: no poison","clicks off: any usable poison, even one neither hand picked: no note")
level=40;counts={[3776]=1};equal(select(2,poison()),"Main and off hand: no poison\nYour poisons need a higher level","clicks off: only ranks above your level")
level=60;counts={}
EraUIDB.reminderClickable=true;equal(select(2,poison()),"Main and off hand: no poison\nNo poison in your bags","Clickable reminders alone: still no pick named")
EraUIDB.reminderClickable=nil;EraUIDB.reminderPoisonClick=true
equal(select(2,poison()),"Main and off hand: no poison\nNo poison in your bags","Click to apply poisons alone (greyed out): still no pick named")
-- With the click live, nothing of the hand's pick to use: said under it,
-- once per poison.
EraUIDB.reminderClickable=true
missing,detail=poison()
equal(detail,"Main and off hand: no poison\nNo Instant Poison in your bags\nNo Deadly Poison in your bags","names each hand's poison it has none of")
equal(select(2,check("poison")):find("|cff",1,true)~=nil,true,"in its own colour")
EraUIClassicCharDB.classTools.poisonPickOff=6947
equal(select(2,poison()),"Main and off hand: no poison\nNo Instant Poison in your bags","the same poison on both: said once")
EraUIClassicCharDB.classTools.poisonPickOff=nil
counts[8928]=1;coatings[16]=copy(fine)
equal(select(2,poison()),"Off hand: no poison\nNo Deadly Poison in your bags","only for a hand that needs one")
level=52;counts={[8928]=1};coatings[16]=nil;coatings[17]=copy(fine)
equal(select(2,poison()),"Main hand: no poison\nYour Instant Poison needs a higher level","only a rank above your level: says so")
EraUIDB.reminderClickable=nil;EraUIDB.reminderPoisonClick=nil
level=60;counts={[8928]=1,[20844]=1}
C_PaperDollInfo.GetTemporaryEnchantmentInfo=function()error("unavailable")end
equal(poison(),nil,"API failure is not missing poison")
C_PaperDollInfo=nil
GetWeaponEnchantInfo=function()return true,600000,50,323,true,600000,50,7 end
equal(poison(),false,"legacy fifth return is the off-hand flag")
GetWeaponEnchantInfo=function()return true,600000,50,323,false,0,0,nil end
equal(select(2,poison()),"Off hand: no poison","legacy false off hand never falls back to main")
GetWeaponEnchantInfo=function()return true,600000,50,nil,nil,0,0,nil end
equal(select(2,poison()),"Off hand: no poison","legacy nil off hand means no enchant")
GetWeaponEnchantInfo=function()return true,600000,50,323,secret,0,0,7 end
equal(poison(),nil,"restricted legacy flag")
GetWeaponEnchantInfo=nil

-- Only once you can use poisons: from the first level one can be used
-- (Forever's data says 20), with Poisons learned or one your level allows
-- in your bags.
E,check,defs,event=Session("ROGUE")
P=E.ReminderPoisons
local applies=assert(up(E.modules.ClassReminders.Refresh,"Applicable"))
equal(P.MinLevel(),20,"the first poison level is 20 in Forever's data")
level=1;known[2842]=true
equal(applies(defs.poison),false,"a level 1 rogue: no POISON!")
level=19;equal(applies(defs.poison),false,"level 19: not yet")
level=20;equal(applies(defs.poison),true,"level 20 with Poisons learned")
known[2842]=nil;equal(applies(defs.poison),false,"level 20 without Poisons and none in bags: no POISON!")
counts[6947]=3;equal(applies(defs.poison),true,"a poison your level allows in your bags is enough")
counts[6947]=nil;counts[2892]=3;equal(applies(defs.poison),false,"Deadly Poison at 20 is not one you can use")
counts[2892]=nil;known[1298494]=true;equal(applies(defs.poison),true,"Forever's own Poisons spell counts as learned")
level=secret;equal(applies(defs.poison),false,"a hidden level is never enough")
level=60

-- Each hand's pick: only poisons your level allows are offered, in the order
-- Instant, Deadly, Crippling, Mind-numbing, Wound, saved by rank 1's item.
local function keys(list)local t={};for _,f in ipairs(list)do t[#t+1]=f.key end;return table.concat(t,",")end
equal(keys(P.Families()),"instant,deadly,crippling,numbing,wound","every Forever poison family, in button order")
level=20;equal(keys(P.ChoiceList()),"instant,crippling","level 20: Instant and Crippling")
level=24;equal(keys(P.ChoiceList()),"instant,crippling,numbing","24: Mind-numbing too")
level=30;equal(keys(P.ChoiceList()),"instant,deadly,crippling,numbing","30: Deadly too")
level=32;equal(keys(P.ChoiceList()),"instant,deadly,crippling,numbing,wound","32: all five")
level=29;equal(P.Choice("main").key.." "..P.Choice("off").key,"instant instant","before 30 both hands default to Instant")
level=30;equal(P.Choice("main").key.." "..P.Choice("off").key,"instant deadly","from 30 the off hand defaults to Deadly")
equal(P.DefaultText("main"),"Default: Instant Poison.","the main hand's default, in words")
equal(P.DefaultText("off"),"Default: Deadly Poison, or Instant Poison before level 30.","the off hand's, with Deadly's level from the data")
-- Before any poison: each button already shows the one you'll get first,
-- as its hover's default says, and there is nothing to pick yet.
for _,l in ipairs({1,19})do
 level=l
 equal(P.Label("main").." / "..P.Label("off"),"Main hand: Instant Poison  > / Off hand: Instant Poison  >","level "..l..": both buttons show Instant Poison")
 equal(#P.ChoiceList(),0,"level "..l..": nothing to pick yet")
 P.Cycle("off");equal(EraUIClassicCharDB.classTools.poisonPickOff,nil,"level "..l..": cycling saves nothing")
end
level=20;equal(P.Label("off"),"Off hand: Instant Poison  >","level 20: Instant too")
equal(P.ChoiceHelp("main"),"Picks the poison a left-click on POISON! puts on your main hand: the highest rank you carry that your level allows. "
 .."Only poisons your level allows are offered, from level 20. With none in your bags, POISON! says so. Each rogue keeps its own picks.","the main hand's pick help, with the first poison level from the data")
equal(P.ChoiceHelp("off"),"Picks the poison a right-click on POISON! puts on your off hand: the highest rank you carry that your level allows. "
 .."Only poisons your level allows are offered, from level 20. With none in your bags, POISON! says so. Each rogue keeps its own picks.","the off hand's")
level=60
local order={}
local picks=EraUIClassicCharDB.classTools
for _=1,5 do P.Cycle("main");order[#order+1]=tostring(picks.poisonPickMain)end
equal(table.concat(order,","),"2892,3775,5237,10918,6947","the main hand cycles Deadly, Crippling, Mind-numbing, Wound and back to Instant")
P.Cycle("off");equal(picks.poisonPickOff,3775,"the off hand cycles on from its own default")
equal(P.Label("off"),"Off hand: Crippling Poison  >","its button names the pick")
equal(EraUIDB.reminderChoice_ROGUE_poisonMain==nil and EraUIDB.reminderChoice_ROGUE_poisonOff==nil,true,"each rogue's own picks, not the account's")
picks.poisonPickMain=10918;level=25
equal(P.Choice("main").key,"instant","a pick your level doesn't allow reads as the default")
level=25;P.Cycle("main");equal(picks.poisonPickMain,3775,"and cycling goes on from what is shown")
picks.poisonPickMain="x";equal(P.Choice("main").key,"instant","a saved pick that isn't a number reads as the default")
picks.poisonPickMain=1234;equal(P.Choice("main").key,"instant","nor does one that isn't a poison")
-- A click uses the highest rank you carry that your level allows.
local instant=P.Choice("main")
level=50;counts={[6947]=1,[8926]=2,[8927]=1}
equal(P.Best(instant).item,8926,"level 50: Instant Poison IV, not V (level 52)")
level=52;equal(P.Best(instant).item,8927,"level 52: V")
counts={};equal(select(2,P.Best(instant)),"none","none in your bags")
counts={[8928]=1};equal(select(2,P.Best(instant)),"level","only a rank above your level")
level=60;equal(P.Best(instant).item,8928,"at 60: VI")
equal(P.Name(instant),"Instant Poison","names come from the game's spell names")
-- A family Forever adds later comes after the five, wherever its data puts
-- it, and is offered from its own level.
E,check,defs,event=Session("ROGUE",function(data)
 table.insert(data.families,1,{key="madeUp",name="Made-up Poison",ranks={{item=99001,level=40,spell=99002,enchant=99003,recipe=99004}}})
end)
P=E.ReminderPoisons
equal(keys(P.Families()),"instant,deadly,crippling,numbing,wound,madeUp","a family Forever adds comes last")
level=39;equal(keys(P.ChoiceList()),"instant,deadly,crippling,numbing,wound","not offered before its level")
level=40;equal(keys(P.ChoiceList()),"instant,deadly,crippling,numbing,wound,madeUp","offered from its level")
level=60

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
auras.party2={25918};event("UNIT_AURA");equal(check("blessing"),false,"Greater Blessing of Wisdom counts as Wisdom")
EraUIDB.reminderChoice_PALADIN_blessing=0;auras.player={25916};auras.party1={25782};event("UNIT_AURA")
equal(check("blessing"),false,"on Any, Greater Blessings count as a blessing")

-- Reagent group versions (Greater Blessings, Prayer of Fortitude, Arcane
-- Brilliance, Gift of the Wild) count as the buff, but a click never casts one.
local classes={};for c in pairs(E.ReminderSpells)do classes[#classes+1]=c end;table.sort(classes)
local want={PALADIN={blessing=25291},PRIEST={fortitude=10938,shadow=10958,spirit=27841},MAGE={intellect=10157},DRUID={mark=9885}}
local reagents=0
for _,c in ipairs(classes)do
 E,check,defs,event=Session(c)
 local click=assert(up(E.modules.ClassReminders.Refresh,"ClickSpell"))
 for _,def in ipairs(E.ReminderSpells[c])do
  local reagent={}
  for _,id in ipairs(def.reagentIds or{})do
   reagent[id]=true;reagents=reagents+1
   local listed=false
   for _,x in ipairs(def.ids or{})do if x==id then listed=true end end
   equal(listed,true,c.." "..def.key.." "..id.." still counts as the buff")
  end
  for _,id in ipairs(def.ids or{})do known[id]=true end
  for _,choice in ipairs(def.choices or{})do
   if choice.ids then
    EraUIDB["reminderChoice_"..c.."_"..def.key]=choice.ids[1]
    local id=click(def)
    equal(id~=nil and not reagent[id],true,c.." "..def.key.." "..choice.key.." clicks a single-target spell")
   end
  end
  EraUIDB["reminderChoice_"..c.."_"..def.key]=(def.key=="blessing")and 19740 or nil
  local id=click(def)
  if id then equal(reagent[id],nil,c.." "..def.key.." never clicks a reagent version")end
  if want[c]and want[c][def.key]then equal(id,want[c][def.key],c.." "..def.key.." clicks the highest single-target rank")end
 end
end
equal(reagents,14,"every reagent group version is listed")
-- With its reagent in your bags a group version is cast again; paladins never
-- get Greater Blessings, reagent or not.
E,check,defs,event=Session("PRIEST")
local click=assert(up(E.modules.ClassReminders.Refresh,"ClickSpell"))
for _,def in ipairs(E.ReminderSpells.PRIEST)do for _,id in ipairs(def.ids or{})do known[id]=true end end
counts[17029]=5
equal(click(E.ReminderSpells.PRIEST[1]),21564,"with Sacred Candles, fortitude clicks Prayer of Fortitude")
counts[17029]=nil
equal(click(E.ReminderSpells.PRIEST[1]),10938,"without them, Power Word: Fortitude")
E,check,defs,event=Session("PALADIN")
click=assert(up(E.modules.ClassReminders.Refresh,"ClickSpell"))
for _,def in ipairs(E.ReminderSpells.PALADIN)do for _,id in ipairs(def.ids or{})do known[id]=true end end
counts[21177]=20;EraUIDB.reminderChoice_PALADIN_blessing=19740
equal(click(E.ReminderSpells.PALADIN[1]),25291,"a paladin with Symbols of Kings still clicks the normal blessing")

E,check,defs,event=Session("WARLOCK")
counts[5232]=1;n=2
units.party1={exists=true};units.party2={exists=true};auras.party1={20707}
equal(check("soulstoneApply"),false,"one protected member satisfies soulstone")
auras.party1={};event("UNIT_AURA");equal(check("soulstoneApply"),true,"no protected member with stone available")
auras.party1=false;event("UNIT_AURA");equal(check("soulstoneApply"),nil,"unknown member may already be protected")
counts[5232]=0;equal(check("soulstoneApply"),false,"no apply alert without a stone")
counts[5232]=1;EraUIDB.reminderGroup=false;auras.player={20707}
equal(check("soulstoneApply"),false,"self-only soulstone")

-- Forever's own ranks and choices: each counts as the buff, and a spell's
-- ranks run lowest to highest, so a click casts the highest one you know.
local function Rising(list,ranks,label)
 local at={};for i,id in ipairs(list)do at[id]=i end
 for i=2,#ranks do equal((at[ranks[i-1]]or 0)<(at[ranks[i]]or 0),true,label.." rank "..ranks[i].." follows "..ranks[i-1])end
end
local function Counts(key,ids,label)
 for _,id in ipairs(ids)do auras.player={id};event("UNIT_AURA");equal(check(key),false,label.." "..id.." counts")end
 auras.player={};event("UNIT_AURA");equal(check(key),true,label..": none up is missing")
end
E,check,defs,event=Session("HUNTER")
local applies=assert(up(E.modules.ClassReminders.Refresh,"Applicable"))
local casts=assert(up(E.modules.ClassReminders.Refresh,"ClickSpell"))
Rising(defs.trueshot.ids,{1299346,1299348,19506,20905,20906},"Trueshot Aura")
known[1299346]=true
equal(applies(defs.trueshot),true,"Trueshot Aura rank 1 alone enables its reminder")
Counts("trueshot",{1299346,1299348},"Trueshot Aura")
equal(casts(defs.trueshot),1299346,"a click casts rank 1")
known[1299348]=true;equal(casts(defs.trueshot),1299348,"then rank 2")
known[19506]=true;known[20906]=true;equal(casts(defs.trueshot),20906,"and rank 5 above Forever's lower ranks")
n=1;units.party1={exists=true,name="Ally"};auras.player={20906};auras.party1={1299346};event("UNIT_AURA")
equal(check("trueshot"),false,"another hunter's rank 1 on a party member counts")
n=0
local beast={13161,1299445,1299446,1299447}
local beastChoice;for _,c in ipairs(defs.aspect.choices)do if c.key=="beast"then beastChoice=c end end
Rising(defs.aspect.ids,beast,"Aspect of the Beast");Rising(beastChoice.ids,beast,"Beast choice")
known[13161]=true;known[1299447]=true;EraUIDB.reminderChoice_HUNTER_aspect=13161
Counts("aspect",beast,"chosen Aspect of the Beast")
equal(casts(defs.aspect),1299447,"the chosen Beast casts its highest rank")
EraUIDB.reminderChoice_HUNTER_aspect=0;auras.player={1299446};event("UNIT_AURA")
equal(check("aspect"),false,"on Any, Beast rank 3 counts by its ID")

E,check,defs,event=Session("PALADIN")
applies=assert(up(E.modules.ClassReminders.Refresh,"Applicable"))
casts=assert(up(E.modules.ClassReminders.Refresh,"ClickSpell"))
local fury={1311649,1311656,20163,20419,20421,20422,20423}
Rising(defs.seal.ids,fury,"Seal of Fury");Rising(defs.seal.ids,{20154,21084,20287},"Seal of Righteousness")
Rising(defs.seal.ids,{20166,20356,20357},"Seal of Wisdom");Rising(defs.seal.ids,{20375,20915,20918,20919,20920},"Seal of Command")
known[20154]=true
equal(applies(defs.seal),true,"the Seal of Righteousness paladins start with enables the seal reminder")
Counts("seal",{20154,20356,20357,20915,20918,20919,20920,1311649,1311656,20163,20419,20421,20422,20423},"seal")
equal(casts(defs.seal),20154,"a click casts the starting seal")
for _,id in ipairs(fury)do known[id]=true end
equal(casts(defs.seal),nil,"with Seal of Fury learned too and neither cast yet, Any never guesses")
Rising(defs.aura.ids,{7294,10298,10299,10300,10301},"Retribution Aura");Rising(defs.aura.ids,{19876,19895,19896},"Shadow Resistance Aura")
Rising(defs.aura.ids,{19891,19899,19900},"Fire Resistance Aura");Rising(defs.aura.ids,{19888,19897,19898},"Frost Resistance Aura")
Counts("aura",{10298,10299,10300,10301,19895,19896,19891,19899,19900,19888,19897,19898},"aura")
known[19876]=true
equal(casts(defs.aura),19876,"the only aura known is what a click casts")
known[19896]=true;equal(casts(defs.aura),19896,"at its highest rank")
known[19746]=true;known[19891]=true;known[19898]=true
equal(casts(defs.aura),nil,"several auras and none cast yet: no longer Shadow Resistance Aura by default")

-- Seals and auras are choices like blessings. Every id belongs to exactly one
-- choice, named and ranked as in Forever's TrainingData.
local training={}
assert(loadfile("Modules/TrainingData.lua"))("EraUI",training)
local taught={}
for _,row in ipairs(training.TrainingData.classes.PALADIN)do taught[row[1]]={name=row[6],rank=tonumber((row[7]or""):match("%d+"))or 1}end
local expectChoices={seal="any,righteousness,crusader,fury,command,justice,light,wisdom",
 aura="any,devotion,retribution,concentration,shadow,frost,fire"}
for _,key in ipairs({"seal","aura"})do
 local def,owner,names=defs[key],{},{}
 equal(def.choiceLabel,key=="seal"and "Seal"or "Aura",key.." has its own choice button")
 equal(def.wide==true and def.testing==nil,true,key.." choice takes a whole line, no longer marked Needs testing")
 for _,choice in ipairs(def.choices)do
  names[#names+1]=choice.key
  local last=0
  for _,id in ipairs(choice.ids or{})do
   equal(owner[id],nil,key.." "..id.." belongs to one choice only")
   owner[id]=choice.key
   local row=taught[id]
   if row then
    equal(row.name,choice.name,key.." "..id.." is "..choice.name)
    equal(row.rank>last,true,key.." "..choice.key.." rank "..row.rank.." of "..id.." follows the one before")
    last=row.rank
   end
  end
 end
 equal(table.concat(names,","),expectChoices[key],key.." choices")
 for _,id in ipairs(def.ids)do equal(owner[id]~=nil,true,key.." "..id.." can be picked")end
 local n=0;for _ in pairs(owner)do n=n+1 end
 equal(n,#def.ids,key.." choices list only the reminder's own ids")
end
local command;for _,c in ipairs(defs.seal.choices)do if c.key=="command"then command=c end end
equal(table.concat(command.ids,","),"20375,20915,20918,20919,20920","Seal of Command: the talent, then its trainer ranks")

-- Picking a seal or aura: only known ones are offered, detection counts only
-- the pick, and on Any a click casts the only one known or the one cast last.
E,check,defs,event=Session("PALADIN")
casts=assert(up(E.modules.ClassReminders.Refresh,"ClickSpell"))
local choiceOf=assert(up(E.modules.ClassReminders.Refresh,"ChoiceOf"))
local offered=assert(up(E.modules.ClassReminders.AttachOptions,"ChoiceList"))
local cycleChoice=assert(up(E.modules.ClassReminders.AttachOptions,"CycleChoice"))
local function Offered(def)local t={};for _,c in ipairs(offered(def))do t[#t+1]=c.key end;return table.concat(t,",")end
local function Cast(id)frames[#frames].scripts.OnEvent(nil,"UNIT_SPELLCAST_SUCCEEDED","player",nil,id)end
equal(Offered(defs.seal),"any","no seal known: only Any")
known[20154]=true;known[20287]=true
equal(Offered(defs.seal),"any,righteousness","Seal of Righteousness once known")
for _,id in ipairs(fury)do known[id]=true end;known[21082]=true;known[20165]=true;known[20349]=true
equal(Offered(defs.seal),"any,righteousness,crusader,fury,light","only the seals you know are offered")
local order={}
for _=1,5 do cycleChoice(defs.seal);order[#order+1]=tostring(EraUIDB.reminderChoice_PALADIN_seal)end
equal(table.concat(order,","),"20154,21082,1311649,20165,0","the Seal button cycles through them and back to Any")
equal(casts(defs.seal),nil,"level 60 on Any, none cast yet: no longer Seal of Light")
EraUIDB.reminderChoice_PALADIN_seal=20154
auras.player={20423};event("UNIT_AURA")
equal(check("seal"),true,"Righteousness picked: Seal of Fury up still reminds")
auras.player={20287};event("UNIT_AURA")
equal(check("seal"),false,"Righteousness rank 2 up does not")
equal(casts(defs.seal),20287,"a click casts the picked seal's highest known rank")
EraUIDB.reminderChoice_PALADIN_seal=20166
equal(choiceOf(defs.seal),nil,"a saved seal you don't know reads as Any")
EraUIDB.reminderChoice_PALADIN_seal=0;auras.player={20423};event("UNIT_AURA")
equal(check("seal"),false,"on Any, any seal counts")
Cast(20349)
equal(EraUIDB.reminderLast_PALADIN_seal,20165,"a seal you cast is remembered by its choice")
equal(casts(defs.seal),20349,"then a click casts it at its highest rank")
Cast(19740)
equal(EraUIDB.reminderLast_PALADIN_seal,20165,"a blessing is not a seal")
equal(EraUIDB.reminderLast_PALADIN_blessing,19740,"it is remembered as a blessing")
known[465]=true;known[10293]=true
equal(Offered(defs.aura),"any,devotion","Devotion Aura once known")
equal(casts(defs.aura),10293,"the only aura known: a click casts it")
known[10301]=true;known[19896]=true
equal(Offered(defs.aura),"any,devotion,retribution,shadow","only the auras you know are offered")
equal(casts(defs.aura),nil,"several auras on Any, none cast: no click")
Cast(10301)
equal(EraUIDB.reminderLast_PALADIN_aura,7294,"an aura you cast is remembered")
equal(EraUIDB.reminderLast_PALADIN_seal,20165,"apart from the seal")
equal(casts(defs.aura),10301,"then a click casts it")
EraUIDB.reminderChoice_PALADIN_aura=465
equal(casts(defs.aura),10293,"a picked aura always wins")
auras.player={10301};event("UNIT_AURA")
equal(check("aura"),true,"Devotion picked: Retribution Aura up still reminds")
auras.player={10293};event("UNIT_AURA")
equal(check("aura"),false,"Devotion up does not")
EraUIDB.reminderChoice_PALADIN_aura=0;auras.player={19896};event("UNIT_AURA")
equal(check("aura"),false,"on Any, any aura counts")
auras.player={};event("UNIT_AURA")
equal(check("aura"),true,"no aura up on Any reminds")

E,check,defs,event=Session("MAGE")
casts=assert(up(E.modules.ClassReminders.Refresh,"ClickSpell"))
Rising(defs.armor.ids,{7302,7320,10219,10220},"Ice Armor")
Counts("armor",{7320,10219,10220},"Ice Armor")
known[7302]=true;known[10220]=true;equal(casts(defs.armor),10220,"a click casts Ice Armor's highest rank")
known[22783]=true;equal(casts(defs.armor),22783,"Mage Armor still wins the click, as before")

-- Summon Incubus is a Demon choice. No game data yet ties the summoned Incubus
-- to a creature family, so while it is chosen any living demon counts.
E,check,defs,event=Session("WARLOCK")
local list=assert(up(E.modules.ClassReminders.AttachOptions,"ChoiceList"))
local cycle=assert(up(E.modules.ClassReminders.AttachOptions,"CycleChoice"))
local function Names()local t={};for _,c in ipairs(list(defs.pet))do t[#t+1]=c.key end;return table.concat(t,",")end
known[688]=true;known[712]=true
equal(Names(),"any,imp,succubus","no Incubus choice before it is learned")
known[713]=true
equal(Names(),"any,imp,succubus,incubus","learned, Incubus is a Demon choice")
local order={}
for _=1,4 do cycle(defs.pet);order[#order+1]=tostring(EraUIDB.reminderChoice_WARLOCK_pet)end
equal(table.concat(order,","),"688,712,713,0","the choice cycles through Incubus and back to Any")
EraUIDB.reminderChoice_WARLOCK_pet=713
units.pet={exists=true,family="Incubus"};equal(check("pet"),false,"chosen Incubus out")
units.pet.family="Succubus";equal(check("pet"),false,"without a family any living demon counts")
units.pet.dead=true;equal(check("pet"),true,"a dead one does not")
units.pet={};equal(check("pet"),true,"no demon out")

-- Forever is level 60 content: every spell a reminder learns, casts or offers
-- must be that class's trainer spell in EraUI's own Forever data, or one of
-- these (Forever's SkillLineAbility and Talent data, build 1.60.1.70009):
-- Frost Armor and Seal of Righteousness rank 1, which mages and paladins get
-- automatically; the talents Divine Spirit, Blessing of Kings, Seal of Command
-- and Trueshot Aura (Forever's rank 1 is 1299346), plus the trainer ranks of
-- the last two, which SkillLineAbility gives no class; and Aspect of the Beast
-- ranks 2 to 4, which TrainingData.lua leaves out for want of a Forever level
-- (Wowhead Forever: taught by hunter trainers at 40, 50 and 60).
local forever={}
assert(loadfile("Modules/TrainingData.lua"))("EraUI",forever)
local extra={MAGE={[168]=true},PRIEST={[14752]=true},
 PALADIN={[20217]=true,[20154]=true,[20375]=true,[20915]=true,[20918]=true,[20919]=true,[20920]=true},
 HUNTER={[1299346]=true,[1299348]=true,[19506]=true,[20905]=true,[20906]=true,[1299445]=true,[1299446]=true,[1299447]=true}}
local gone={[31687]="Summon Water Elemental",[2894]="Fire Elemental Totem",[2062]="Earth Elemental Totem",
 [30146]="Summon Felguard",[427733]="Summon Felguard",[20911]="Blessing of Sanctuary",[20912]="Blessing of Sanctuary",
 [20913]="Blessing of Sanctuary",[20914]="Blessing of Sanctuary",[25899]="Greater Blessing of Sanctuary",
 -- Season of Discovery spells in Forever's client that nothing in Forever
 -- teaches (no Forever level, no trainer or quest), and Martyrdom's hit.
 [415423]="Aspect of the Viper",[469145]="Aspect of the Falcon",[407798]="Seal of Martyrdom",[407799]="Seal of Martyrdom damage"}
local audited=0
for _,c in ipairs(classes)do
 local trainer={}
 for _,row in ipairs(forever.TrainingData.classes[c]or{})do trainer[row[1]]=true end
 local function Audit(list,where)
  for _,id in ipairs(list or{})do
   audited=audited+1
   equal(trainer[id]or(extra[c]and extra[c][id])or false,true,where.." "..id.." is a Forever "..c.." spell")
  end
 end
 for _,def in ipairs(E.ReminderSpells[c])do
  local where=c.." "..def.key
  Audit(def.ids,where);Audit(def.castIds,where);Audit(def.requires,where);Audit(def.reagentIds,where)
  for _,choice in ipairs(def.choices or{})do Audit(choice.ids,where.." "..choice.key)end
  for _,field in ipairs({"ids","castIds","requires","reagentIds","auras"})do
   for _,id in ipairs(def[field]or{})do equal(gone[id],nil,where.." "..field.." never lists "..tostring(gone[id]))end
  end
  for _,choice in ipairs(def.choices or{})do
   for _,id in ipairs(choice.ids or{})do equal(gone[id],nil,where.." "..choice.key.." never offers "..tostring(gone[id]))end
  end
  equal(def.kind~="cooldown"and def.text~="SUMMON ELEMENTAL!",true,where.." is not an elemental reminder")
 end
end
equal(audited>200,true,"the audit reached every reminder spell")
local keys={}
for _,c in ipairs(classes)do for _,def in ipairs(E.ReminderSpells[c])do
 keys[c.."_"..def.key]=true
 for _,choice in ipairs(def.choices or{})do keys[c.."_"..def.key.."_"..choice.key]=true end
end end
for _,key in ipairs({"MAGE_elemental","SHAMAN_elemental","WARLOCK_pet_felguard","PALADIN_blessing_sanctuary"})do
 equal(keys[key],nil,key.." is gone")
end

-- PET LOW HEALTH!: a living pet below the limit (default 35%).
-- In combat Forever hides pet health: a hidden value here errors when it is
-- compared, added up or joined to text, so any read fails the test.
local hiddenMeta={}
for _,op in ipairs({"__eq","__lt","__le","__add","__sub","__mul","__div","__mod","__pow","__unm","__idiv","__concat","__len","__index","__call"})do
 hiddenMeta[op]=function()error("a hidden health value was read")end
end
local function Hidden(v)return setmetatable({hidden=true,value=v},hiddenMeta)end
issecretvalue=function(v)return rawequal(v,secret)or(type(v)=="table"and rawget(v,"hidden")==true)end
local hp={health=100,max=100}
UnitHealth=function(u)if u~="pet"then return 1 end;return hp.hidden and Hidden(hp.health)or hp.health end
UnitHealthMax=function(u)return u=="pet"and hp.max or 1 end
local curves={}
Enum={LuaCurveType={Linear=0,Step=1,Cosine=2,Cubic=3}}
local function NewCurve()
 local c={points={}}
 function c:SetType(t)self.kind=t end
 function c:ClearPoints()self.points={}end
 function c:AddPoint(x,y)self.points[#self.points+1]={x,y}end
 -- Linear between points, flat past the ends (the curve's own evaluation).
 function c:Evaluate(x)
  local p=self.points;if #p==0 then return 0 end
  if x<=p[1][1]then return p[1][2]end
  for i=2,#p do
   if x==p[i][1]then return p[i][2]end
   if x<p[i][1]then local a,b=p[i-1],p[i];return a[2]+(b[2]-a[2])*(x-a[1])/(b[1]-a[1])end
  end
  return p[#p][2]
 end
 curves[#curves+1]=c;return c
end
C_CurveUtil={CreateCurve=NewCurve}
local percentCalls={}
UnitHealthPercent=function(u,predicted,c)
 percentCalls[#percentCalls+1]={u,predicted,c}
 local v=hp.health/hp.max;if c then v=c:Evaluate(v)end
 return hp.hidden and Hidden(v)or v
end
E,check,defs,event=Session("HUNTER")
local reminders=E.modules.ClassReminders
local defOn=assert(up(reminders.Refresh,"DefOn"))
local applies=assert(up(reminders.Refresh,"Applicable"))
local casts=assert(up(reminders.Refresh,"ClickSpell"))
local cycleLimit=assert(up(reminders.AttachOptions,"CycleLimit"))
local function Low()local a,b,c,d=check("petHealth");return a,b,c,d end
local low=defs.petHealth
equal(low.text,"PET LOW HEALTH!","hunters have PET LOW HEALTH!")
equal(low.wide==true and low.testing==nil,true,"a whole line in /era, no longer marked Needs testing")
equal(defOn(low),false,"off by default")
equal(applies(low),false,"no alert before Mend Pet is learned")
known[136]=true;known[3661]=true
equal(applies(low),true,"Mend Pet learned: it applies")
equal(casts(low),3661,"a click casts the highest Mend Pet rank known")
known[13544]=true;equal(casts(low),13544,"up to rank 7")
units.pet={}
local missing,detail=Low()
equal(missing,false,"no pet: no PET LOW HEALTH!");equal(detail,"No pet summoned","it says why")
equal(check("pet"),true,"SUMMON PET! instead")
units.pet={exists=true,dead=true};hp.health=0
missing,detail=Low()
equal(missing,false,"a dead pet: no PET LOW HEALTH!");equal(detail,"Pet is dead","it says why")
equal(check("petDead"),true,"PET DEAD! instead")
units.pet={exists=true}
for _,case in ipairs({{30,true,"Pet at 30% health"},{34,true,"Pet at 34% health"},{35,false,"Pet at 35% health"},{90,false,"Pet at 90% health"}})do
 hp.health=case[1]
 missing,detail=Low()
 equal(missing,case[2],"pet at "..case[1].."% against the default 35%");equal(detail,case[3],"says the pet's health at "..case[1].."%")
end
hp.max=3000;hp.health=1049;equal(Low(),true,"34.97% is below 35%")
hp.health=1050;equal(Low(),false,"exactly 35% is not")
hp.health=1;equal(select(2,Low()),"Pet at 1% health","a sliver of health still reads 1%")
hp.max=100
EraUIDB.reminderLimit_HUNTER_petHealth=45
hp.health=40;equal(Low(),true,"a 45% limit: 40% alerts")
hp.health=50;equal(Low(),false,"and 50% does not")
for _,bad in ipairs({99,5,"x"})do
 EraUIDB.reminderLimit_HUNTER_petHealth=bad
 hp.health=40;equal(Low(),false,"a saved limit of "..tostring(bad).." reads as 35%")
end
EraUIDB.reminderLimit_HUNTER_petHealth=nil
local order={}
for _=1,9 do cycleLimit(low);order[#order+1]=tostring(EraUIDB.reminderLimit_HUNTER_petHealth)end
equal(table.concat(order,","),"40,45,50,55,60,20,25,30,35","the limit cycles 20 to 60% in fives")
EraUIDB.reminderLimit_HUNTER_petHealth=33;cycleLimit(low)
equal(EraUIDB.reminderLimit_HUNTER_petHealth,35,"an odd saved limit steps to the next five")
EraUIDB.reminderLimit_HUNTER_petHealth=nil
hp.max=0;hp.health=0;equal(Low(),nil,"no maximum health yet: unknown, not low")
hp.max=100
units.pet={exists=true,dead=secret};equal(Low(),nil,"a hidden death state: unknown")
units.pet={exists=true}
-- In combat: never read, the game fades the alert through the curve.
hp.hidden=true;hp.health=20
local fourth
missing,detail,_,fourth=Low()
equal(missing,true,"hidden health: drawn for the game to fade");equal(fourth,true,"marked faded")
equal(detail,"Pet below 35% health","it names the limit, not the hidden health")
local shape=curves[#curves]
equal(shape and shape.kind,0,"a linear curve")
equal(#shape.points,4,"four points")
for _,x in ipairs({0,.1,.2,.3,.34,.345})do equal(shape:Evaluate(x),1,"fully shown at "..(x*100).."%")end
for _,x in ipairs({.35,.36,.5,.9,1})do equal(shape:Evaluate(x),0,"hidden at "..(x*100).."%")end
local fade=assert(up(reminders.Refresh,"Fade"))
local drawn={}
local row={SetAlpha=function(_,a)drawn[#drawn+1]=a end}
percentCalls={};fade(row,low)
equal(#drawn,1,"the alert's alpha is set once")
equal(type(drawn[1])=="table"and rawget(drawn[1],"hidden"),true,"to the hidden result itself")
equal(rawget(drawn[1],"value"),1,"which the game shows at 20%")
equal(percentCalls[1][1].." "..tostring(percentCalls[1][2]).." "..tostring(percentCalls[1][3]==shape),"pet true true","the pet's percent through the curve")
hp.health=90;drawn={};fade(row,low)
equal(rawget(drawn[1],"value"),0,"and hides at 90%")
hp.health=90;missing,_,_,fourth=Low()
equal(missing==true and fourth,true,"at 90% it is still drawn: only the game knows")
EraUIDB.reminderLimit_HUNTER_petHealth=50
missing,detail=Low()
equal(detail,"Pet below 50% health","a new limit")
equal(curves[#curves],shape,"reshapes the same curve")
equal(shape:Evaluate(.49),1,"shown just under 50%");equal(shape:Evaluate(.5),0,"hidden at 50%")
local made=#curves;Low();Low()
equal(#curves,made,"the curve is made once")
EraUIDB.reminderLimit_HUNTER_petHealth=nil
local keep=UnitHealthPercent;UnitHealthPercent=nil
equal(Low(),nil,"no percent API: hidden in combat")
drawn={};fade(row,low);equal(drawn[1],0,"a fade without it hides the alert")
UnitHealthPercent=keep
C_CurveUtil={CreateCurve=function()error("unavailable")end}
E,check,defs,event=Session("HUNTER")
units.pet={exists=true};known[136]=true;hp.hidden=true;hp.health=20
equal(check("petHealth"),nil,"no curve: hidden in combat")
C_CurveUtil=nil;equal(check("petHealth"),nil,"no curve API: hidden in combat")
C_CurveUtil={CreateCurve=NewCurve}
hp.hidden=false
Rising(defs.petHealth.ids,{136,3111,3661,3662,13542,13543,13544},"Mend Pet")
-- Warlocks: Health Funnel. A dead demon is SUMMON PET!'s job.
E,check,defs,event=Session("WARLOCK")
casts=assert(up(E.modules.ClassReminders.Refresh,"ClickSpell"))
Rising(defs.petHealth.ids,{755,3698,3699,3700,11693,11694,11695},"Health Funnel")
known[755]=true;known[11694]=true
equal(casts(defs.petHealth),11694,"a click casts the highest Health Funnel rank known")
units.pet={exists=true};hp.health=25
equal(check("petHealth"),true,"a demon at 25%: PET LOW HEALTH!")
units.pet={exists=true,dead=true}
equal(check("petHealth"),false,"a dead demon: no PET LOW HEALTH!")
missing,detail=check("pet")
equal(missing,true,"SUMMON PET! instead");equal(detail,"Pet is dead","saying it is dead")
units.pet={}
equal(check("petHealth"),false,"no demon: no PET LOW HEALTH!");equal(check("pet"),true,"SUMMON PET! instead")
local named={HUNTER="Mend Pet",WARLOCK="Health Funnel"}
for c,name in pairs(named)do
 local ranks={}
 for _,row in ipairs(forever.TrainingData.classes[c])do if row[6]==name then ranks[#ranks+1]=row[1]end end
 local def;for _,d in ipairs(E.ReminderSpells[c])do if d.key=="petHealth"then def=d end end
 equal(table.concat(def.ids,","),table.concat(ranks,","),c.." PET LOW HEALTH! lists every "..name.." rank, lowest first")
 equal(E.ReminderSpells[c][#E.ReminderSpells[c]],def,c.." PET LOW HEALTH! is listed last")
end
-- Click pet reminders in combat: only the pet reminders get a combat rule,
-- each read by the game from macro conditions, always hidden out of combat.
local combatRule=assert(up(E.modules.ClassReminders.Refresh,"CombatRule"))
local expected={
 HUNTER={pet="[nocombat][@pet,exists] hide; show",petDead="[nocombat] hide; [@pet,dead] show; hide",petHealth="[nocombat][@pet,noexists][@pet,dead] hide; show"},
 WARLOCK={pet="[nocombat][@pet,exists,nodead] hide; show",petHealth="[nocombat][@pet,noexists][@pet,dead] hide; show"},
}
for _,c in ipairs(classes)do
 for _,def in ipairs(E.ReminderSpells[c])do
  local want=(expected[c]or{})[def.key]
  equal(combatRule(def),want,c.." "..def.key..(want and " has its combat rule"or " is clickable outside combat only"))
  if want then equal(want:find("^%[nocombat%]")~=nil,true,c.." "..def.key.." always hides out of combat")end
 end
end
-- Learned spells on Forever: IsPlayerSpell and IsSpellKnown only exist in the
-- game's deprecated copies, which load while the loadDeprecationFallbacks
-- setting is on (the rest of this file mocks them). Without them a learned
-- spell comes from C_SpellBook.IsSpellKnown, whose bank defaults to the
-- player's spells, the same question the old names asked.
do
 E,check,defs,event=Session("HUNTER")
 local oldPlayerSpell,oldSpellKnown=IsPlayerSpell,IsSpellKnown
 IsPlayerSpell=nil;IsSpellKnown=nil
 local asked={}
 C_SpellBook={IsSpellKnown=function(id,bank)asked[#asked+1]={id=id,bank=bank};return known[id]==true end}
 local Known=E.ClassTools.Known
 local petApplies=assert(up(E.modules.ClassReminders.Refresh,"Applicable"))
 known[883]=true
 equal(Known(883),true,"no old names: a learned spell is known through C_SpellBook")
 equal(Known(982),false,"no old names: an unlearned spell is not")
 equal(#asked,2,"each asks C_SpellBook.IsSpellKnown")
 equal(asked[1].id,883,"about that spell")
 equal(asked[1].bank,nil,"in the default bank, the player's spells")
 equal(petApplies(defs.pet),true,"no old names: Call Pet learned, the pet alert applies")
 known[883]=nil
 equal(petApplies(defs.pet),false,"no old names: Call Pet not learned, no pet alert")
 known[883]=true
 C_SpellBook.IsSpellKnown=function()error("unavailable")end
 equal(Known(883),false,"an erroring answer is not known")
 C_SpellBook.IsSpellKnown=function()return secret end
 equal(Known(883),false,"a restricted answer is not known")
 C_SpellBook=nil
 equal(Known(883),false,"none of them: nothing is known, no error")
 -- A client that still has the old names, alone or with C_SpellBook, answers the same.
 IsSpellKnown=oldSpellKnown
 equal(Known(883),true,"only the old IsSpellKnown: still known")
 IsPlayerSpell=oldPlayerSpell
 C_SpellBook={IsSpellKnown=function(id)return known[id]==true end}
 equal(Known(883),true,"old and new: known")
 equal(Known(982),false,"old and new: not learned, not known")
 C_SpellBook=nil
end
print("Class reminder detection checks passed: "..checks.." assertions.")
