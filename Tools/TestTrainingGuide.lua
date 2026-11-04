-- Trainer catalogs, quotes, ranks and character isolation using the real module.
local checks=0
local function equal(a,b,label)checks=checks+1;assert(a==b,label..": "..tostring(a).." ~= "..tostring(b))end
local frames,timers,options,settings={},{},{},{enabled=true,trainingGuide=true}
local knownIDs,level,trainerType={},10,0
local filters={available=true,unavailable=false,used=false}
local offers={
 {name="Serpent Sting",rank="Rank 1",level=4,kind="used",cost=20,id=1},
 {name="Serpent Sting",rank="Rank 2",level=10,kind="available",cost=100,id=2,req="Serpent Sting (Rank 1)"},
 {name="Arcane Shot",rank="Rank 2",level=12,kind="unavailable",cost=300,id=3},
 {name="Beast Lore",rank="",level=10,kind="available",id=4},
 {name="General Passive",rank="",level=10,kind="available",cost=0,id=5,category="General"},
}
local items={
 {name="Serpent Sting",subName="Rank 1",itemType=1,spellID=1,iconID=1},
 {name="Arcane Shot",subName="Rank 2",itemType=2,spellID=3,iconID=3},
}
Enum={SpellBookSpellBank={Player=0},SpellBookItemType={Spell=1,FutureSpell=2},TrainerType={General=0,Tradeskills=2,Pet=3}}
UnitClass=function()return "Hunter","HUNTER"end
UnitLevel=function()return level end
UnitName=function()return "Hunter teacher"end
InCombatLockdown=function()return false end
C_Trainer={GetTrainerType=function()return trainerType end}
C_Spell={GetSpellLevelLearned=function()return 12 end}
C_SpellBook={GetNumSpellBookSkillLines=function()return 2 end,
 GetSpellBookSkillLineInfo=function(i)return {name=i==1 and "General"or "Marksmanship",itemIndexOffset=0,numSpellBookItems=i==1 and 0 or #items}end,
 GetSpellBookItemInfo=function(i)return items[i]end}
C_Timer={After=function(_,fn)timers[#timers+1]=fn end}
CreateFrame=function()
 local f={events={}}
 function f:RegisterEvent(event)self.events[event]=true end
 function f:SetScript(_,fn)self.onEvent=fn end
 frames[#frames+1]=f;return f
end
local function Fire(event)for _,f in ipairs(frames)do if f.events[event]then f.onEvent(f,event)end end end
local function Flush()
 for _=1,8 do
  if #timers==0 then return end
  local pending=timers;timers={};for _,fn in ipairs(pending)do fn()end
 end
 error("trainer event loop")
end
local function Visible()
 local out={};for _,row in ipairs(offers)do if filters[row.kind]then out[#out+1]=row end end;return out
end
GetTrainerServiceTypeFilter=function(kind)return filters[kind]end
SetTrainerServiceTypeFilter=function(kind,v)filters[kind]=v;Fire("TRAINER_UPDATE")end
GetNumTrainerServices=function()return #Visible()end
GetTrainerServiceInfo=function(index)
 local row=Visible()[index];return row.name,row.kind,row.id,row.level,row.rank,row.category or "Marksmanship"
end
local fail
GetTrainerServiceCost=function(index)if fail then error("temporary API failure")end;return Visible()[index].cost,false end
GetTrainerServiceItemLink=function(index)return "|Hspell:"..Visible()[index].id.."|h"end
GetTrainerServiceNumAbilityReq=function(index)return Visible()[index].req and 1 or 0 end
GetTrainerServiceAbilityReq=function(index)return Visible()[index].req,false end
local saves=0
local E={modules={},ClassTools={Options=function()return options end,Known=function(id)return knownIDs[id]==true end}}
function E:RegisterModule(name,module)self.modules[name]=module end
function E:GetSetting(key)return settings[key]end
function E:SaveSettings()saves=saves+1 end
assert(loadfile("Modules/TrainingGuide.lua"))("EraUI",E)
local M=E.modules.TrainingGuide;M:Initialize()
local rows,s=M:Collect()
equal(#rows,1,"future spell displayed before visiting a trainer")
equal(rows[1].data.level,12,"future level comes from client")
equal(s.unknown,1,"unquoted price is not treated as free")
Fire("TRAINER_SHOW");Flush()
rows,s=M:Collect()
equal(filters.available,true,"available filter preserved")
equal(filters.unavailable,false,"future filter restored")
equal(filters.used,false,"learned filter restored")
equal(#rows,4,"used spell excluded and future spell deduplicated")
equal(s.all,400,"all known unlearned rank costs totalled")
equal(s.unknown,1,"unknown price explicitly counted")
equal(s.nowCount,3,"known prerequisite unlocks current training")
equal(s.now,100,"current-level total excludes future spells")
equal(s.nowUnknown,1,"unpriced current offer not silently free")
equal(saves,1,"one capture writes once despite synchronous filter events")
Fire("TRAINER_CLOSED");Flush()
level=12;Fire("PLAYER_LEVEL_UP");Flush();rows,s=M:Collect()
equal(s.nowCount,4,"level-up updates eligibility away from trainer")
equal(s.now,400,"newly available spell joins current total")
-- Build 70170: PLAYER_LEVEL_UP can come before the new level is in, so the
-- guide also refreshes on PLAYER_LEVEL_CHANGED, which comes after it.
do
 local refreshes,refresh=0,M.Refresh
 M.Refresh=function(...)refreshes=refreshes+1;return refresh(...)end
 Fire("PLAYER_LEVEL_CHANGED");Flush()
 equal(refreshes,1,"the level change refreshes the guide")
 M.Refresh=refresh
end
knownIDs[2]=true;Fire("SPELLS_CHANGED");Flush();rows,s=M:Collect()
equal(s.count,3,"newly learned spell disappears without trainer visit")
equal(s.all,300,"learned spell removed from cost total")
-- A higher known rank covers hidden lower ranks even without their spell IDs.
knownIDs={};items[#items+1]={name="Serpent Sting",subName="Rank 3",itemType=1,spellID=20}
rows,s=M:Collect();equal(s.count,3,"hidden lower rank recognized as learned")
local cache=options.trainingGuide
trainerType=2;Fire("TRAINER_SHOW");Flush()
equal(options.trainingGuide,cache,"profession trainer does not replace class cache")
equal(saves,1,"profession visit writes no class quotes")
trainerType=3;Fire("TRAINER_UPDATE");Flush();equal(saves,1,"pet trainer excluded")
trainerType=0;offers={{name="Riding",rank="",level=40,kind="available",cost=999,id=100,category="Riding"}}
Fire("TRAINER_UPDATE");Flush();equal(saves,1,"unrelated general trainer excluded")
offers={{name="Arcane Shot",rank="Rank 2",level=12,kind="available",cost=240,id=3}}
Fire("TRAINER_UPDATE");Flush();rows,s=M:Collect()
equal(s.all,240,"next trainer visit updates discounted quote")
fail=true;Fire("TRAINER_UPDATE");Flush()
equal(filters.unavailable,false,"filters restored after capture failure")
equal(filters.used,false,"learned filter restored after capture failure")
equal(M.lastError~=nil,true,"failed read reported rather than clearing catalog")
rows,s=M:Collect();equal(s.all,240,"failed read retains prior quotes")
fail=false;settings.trainingGuide=false;local saved=saves;Fire("TRAINER_UPDATE");Flush()
equal(saves,saved,"disabled guide does not collect")
options={};settings.trainingGuide=true;rows,s=M:Collect()
equal(s.unknown,1,"new character does not inherit trainer quote")
equal(s.all,0,"new character has no stale training costs")
-- A quote joins its spell's row by spell ID when the name changed (build
-- 1.60.1.70425 renamed Blessing of Salvation to Salvation), so a renamed
-- spell is one row under its current name and counted once.
local function Arcane()
 local n,row=0;for _,r in ipairs(rows)do if r.data.spellID==3 then n=n+1;row=r.data end end;return n,row
end
options={trainingGuide={entries={["Arcane Strike\031Rank 2"]={name="Arcane Strike",rank="Rank 2",level=12,trainer=true,cost=300,spellID=3}}}}
rows,s=M:Collect()
local n,arcane=Arcane()
equal(n,1,"a quote under an old name joins its spell's row by ID")
equal(arcane.name,"Arcane Shot","under the spell's current name")
equal(arcane.cost,300,"with the quote's price");equal(arcane.reference,false,"as a recorded quote")
equal(s.all,300,"counted once");equal(s.unknown,0,"and no longer unknown")
options.trainingGuide.entries["Arcane Shot\031Rank 2"]={name="Arcane Shot",rank="Rank 2",level=12,trainer=true,cost=240,spellID=3}
rows,s=M:Collect();n,arcane=Arcane()
equal(n,1,"old and current names quoted: still one row")
equal(arcane.cost,240,"the current name's quote wins");equal(s.all,240,"and is the only one counted")
options={trainingGuide={entries={["Old Spell\031"]={name="Old Spell",rank="",level=12,trainer=true,cost=50},
 ["Gone Spell\031"]={name="Gone Spell",rank="",level=12,trainer=true,cost=70,spellID=999}}}}
rows,s=M:Collect()
equal(#rows,3,"a quote without a spell ID, or for a spell no row has, keeps its own row")
equal(s.all,120,"and is counted")
-- Quotes from another client build are dropped, as a patch can move levels,
-- prices and names. Caches from before the build was saved go once.
do
 local build="70425"
 GetBuildInfo=function()return "1.60.1",build,"Oct 15 2026",16001 end
 options={trainingGuide={entries={["Arcane Strike\031Rank 2"]={name="Arcane Strike",rank="Rank 2",level=12,trainer=true,cost=300,spellID=3}},
  trainer="Old teacher",updated="2026-10-01"}}
 local before=saves
 rows,s=M:Collect()
 equal(next(options.trainingGuide.entries),nil,"a cache with no build is cleared")
 equal(options.trainingGuide.build,"70425","and stamped with the client build")
 equal(options.trainingGuide.trainer==nil and options.trainingGuide.updated==nil,true,"with its trainer and date")
 equal(saves,before+1,"the cleared cache is saved")
 equal(s.all,0,"its old prices are gone");equal(s.unknown,1,"so the spell is unknown again")
 Fire("TRAINER_SHOW");Flush();rows,s=M:Collect()
 equal(s.all,240,"the next trainer visit records quotes again")
 equal(options.trainingGuide.build,"70425","on the same build")
 before=saves;rows,s=M:Collect()
 equal(s.all,240,"the same build keeps its quotes");equal(saves,before,"and saves nothing")
 build="70500";rows,s=M:Collect()
 equal(next(options.trainingGuide.entries),nil,"a new client build clears them");equal(options.trainingGuide.build,"70500","and is saved")
 options.trainingGuide.entries["Arcane Shot\031Rank 2"]={name="Arcane Shot",rank="Rank 2",level=12,trainer=true,cost=240,spellID=3}
 for _,answer in ipairs({function()error("unavailable")end,function()return "1.60.1",nil end,function()return "1.60.1",""end})do
  GetBuildInfo=answer;rows,s=M:Collect()
  equal(s.all,240,"no build answer clears nothing")
 end
 GetBuildInfo=nil;Fire("TRAINER_CLOSED");Flush()
end
options={}
-- Real bundled data populates without a trainer visit, for every class.
assert(loadfile("Modules/TrainingData.lua"))("EraUI",E)
local total=0
for class,data in pairs(E.TrainingData.classes)do
 local ids={}
 for _,row in ipairs(data)do
  equal(ids[row[1]],nil,"catalog has no duplicate spell IDs in "..class)
  ids[row[1]]=true;total=total+1
 end
 UnitClass=function()return class,class end
 options={};items={};rows,s=M:Collect()
 equal(#rows>60,true,class.." training populated before a trainer visit")
 equal(s.all>0,true,class.." has offline reference costs")
end
UnitClass=function()return "Hunter","HUNTER"end
options={};items={};rows,s=M:Collect()
local found=false;for _,r in ipairs(rows)do
 equal(r.data.spellID==409580 or r.data.spellID==415423,false,"unverified SoD level-one spells cannot appear in Hunter training")
 if r.data.spellID==1515 then found=true;equal(r.data.level,10,"offline Tame Beast level")end
end
equal(found,true,"hunter quest ability present before visiting a trainer")
items={{name="Aspect of the Viper",subName="",itemType=2,spellID=415423,iconID=1}}
local oldLevel=C_Spell.GetSpellLevelLearned;C_Spell.GetSpellLevelLearned=function()return 1 end
rows=M:Collect()
for _,r in ipairs(rows)do equal(r.data.spellID==415423,false,"default future-spell level does not reintroduce excluded data")end
items={};C_Spell.GetSpellLevelLearned=oldLevel
-- Forever's 30 Oct 2026 hotfix: paladin trainers stop teaching Blessing of
-- Light, Salvation and the like, but the client data still makes them
-- learnable, so the book can list them as coming. They stay out until a
-- trainer offers one.
do
 local listed={};for _,id in ipairs(E.TrainingData.notTaught)do listed[id]=true end
 for _,id in ipairs({19977,19978,19979,25890,1038,25895,1325499})do
  equal(listed[id],true,id.." is in the bundled no-longer-taught list")
 end
 UnitClass=function()return "Paladin","PALADIN"end
 local function Count(id)
  local n,row=0;for _,r in ipairs(rows)do if r.data.spellID==id then n=n+1;row=r.data end end;return n,row
 end
 items={{name="Blessing of Light",subName="Rank 1",itemType=2,spellID=19977,iconID=1},
  {name="Salvation",subName="",itemType=2,spellID=1038,iconID=1},
  {name="Future Light",subName="",itemType=2,spellID=990001,iconID=1}}
 C_Spell.GetSpellLevelLearned=function(id)return id==1038 and 26 or 40 end
 options={};rows=M:Collect()
 equal(Count(19977),0,"a coming spell trainers no longer teach is not listed")
 equal(Count(1038),0,"Salvation neither")
 equal(Count(990001),1,"other coming spells still are")
 -- A trainer that still offers one puts it back, once, at its price.
 offers={{name="Blessing of Light",rank="Rank 1",level=40,kind="unavailable",cost=20000,id=19977,category="Paladin"}}
 Fire("TRAINER_SHOW");Flush();rows=M:Collect()
 local n,light=Count(19977)
 equal(n,1,"listed once a trainer offers it")
 equal(light.cost,20000,"at the trainer's price");equal(light.level,40,"and level")
 equal(Count(1038),0,"one it doesn't offer stays out")
 Fire("TRAINER_CLOSED");Flush()
 items={};C_Spell.GetSpellLevelLearned=oldLevel;UnitClass=function()return "Hunter","HUNTER"end;options={}
end
-- The trained ranks of a talent wait for the rank before it, from the talent
-- on: Seal of Command rank 2 needs the talent (20375), rank 3 needs rank 2,
-- known or on sale on the same visit.
do
 UnitClass=function()return "Paladin","PALADIN"end
 local function Seal(id)for _,r in ipairs(rows)do if r.data.spellID==id then return r end end end
 local old=level;level=40;options={};items={};knownIDs={}
 rows=M:Collect()
 equal(Seal(20915).ready,false,"without the talent Seal of Command rank 2 is not ready");equal(Seal(20915).group,2,"it lacks a step")
 equal(Seal(20918).ready,false,"nor is rank 3")
 knownIDs[20375]=true;rows=M:Collect()
 equal(Seal(20915).ready,true,"with the talent rank 2 is ready at its level");equal(Seal(20915).group,1,"available now")
 equal(Seal(20918).ready,true,"rank 3 with it: one visit buys both")
 knownIDs={};items={{name="Seal of Command",subName="Rank 1",itemType=1,spellID=20375,iconID=1}};rows=M:Collect()
 equal(Seal(20915).ready,true,"the talent in the spellbook counts too")
 knownIDs[20915]=true;rows=M:Collect()
 equal(Seal(20915),nil,"rank 2 learned");equal(Seal(20918).ready,true,"then rank 3 is ready")
 equal(Seal(20919).group,4,"rank 4 comes later, at 50")
 level=old;knownIDs={};items={};options={};UnitClass=function()return "Hunter","HUNTER"end
end
-- Every trained rank waits for the rank before it: Fireball 2 for the rank 1
-- every mage starts with, Fireball 3 for rank 2, known or on sale on the same
-- visit. A higher rank you know covers the ones below it, even when the game
-- answers only for your highest.
do
 local function Find(id)for _,r in ipairs(rows)do if r.data.spellID==id then return r end end end
 local old=level;level=30;UnitClass=function()return "Mage","MAGE"end;options={};items={}
 knownIDs={[133]=true};rows=M:Collect()
 equal(Find(143).ready,true,"Fireball 2 is ready with the starting rank 1 known")
 equal(Find(145).ready,true,"Fireball 3 with it: one visit buys both");equal(Find(145).group,1,"available now")
 equal(Find(8400).group,1,"so does Fireball 5");equal(Find(8402).ready,false,"the first above your level stops them");equal(Find(8402).group,4,"and comes later")
 knownIDs={};rows=M:Collect()
 equal(Find(143).ready,false,"no rank 1: no rank 2");equal(Find(145).group,2,"nor anything above it")
 knownIDs={[3140]=true};items={{name="Fireball",subName="Rank 4",itemType=1,spellID=3140,iconID=1}};rows=M:Collect()
 equal(Find(143),nil,"rank 4 known: rank 2 is not listed");equal(Find(145),nil,"nor rank 3")
 equal(Find(8400).ready,true,"rank 5 is ready");equal(Find(8401).ready,true,"and rank 6 with it")
 level=old;knownIDs={};items={};options={};UnitClass=function()return "Hunter","HUNTER"end
end
-- Redemption's rank 1 comes from a class quest: rank 2 waits for it.
do
 local function Find(id)for _,r in ipairs(rows)do if r.data.spellID==id then return r end end end
 local old=level;level=36;UnitClass=function()return "Paladin","PALADIN"end;options={};items={};knownIDs={}
 assert(loadfile("Modules/ClassQuestData.lua"))("EraUI",E)
 rows=M:Collect()
 equal(Find(7328)~=nil,true,"Redemption 1 is listed");equal(Find(10322).ready,false,"rank 2 waits for the quest's rank 1")
 equal(Find(10324).ready,false,"so does rank 3");equal(Find(10324).group,2,"it lacks a step")
 knownIDs[7328]=true;rows=M:Collect()
 equal(Find(7328),nil,"rank 1 learned from the quest");equal(Find(10322).ready,true,"then rank 2 is ready")
 equal(Find(10324).ready,true,"and rank 3 with it")
 E.ClassQuests=nil
 level=old;knownIDs={};items={};options={};UnitClass=function()return "Hunter","HUNTER"end
end
-- Ranks one trainer visit can buy count together: a rank is ready at its level
-- when the rank it names is known or ready itself. Made-up rows, so the totals
-- are exact: Bolt's rank 1 and Blast's talent are no rows, Mend's rank 1 is a
-- quest's, Skip's rank 2 comes above its rank 3, and Loop names itself in a ring.
do
 local realData,realQuests=E.TrainingData,E.ClassQuests
 E.TrainingData={notTaught={},classes={MAGE={
  {300,2,0,0,nil,"Mend","Rank 1"},
  {101,4,100,0,100,"Bolt","Rank 2"},
  {201,4,200,0,1000,"Blast","Rank 2"},
  {301,4,300,0,10000,"Mend","Rank 2"},
  {102,8,101,0,200,"Bolt","Rank 3"},
  {202,8,201,0,2000,"Blast","Rank 3"},
  {302,8,301,0,20000,"Mend","Rank 3"},
  {402,8,401,0,600,"Skip","Rank 3"},
  {403,9,402,0,700,"Skip","Rank 4"},
  {501,9,502,0,50,"Loop","Rank 2"},
  {502,9,501,0,60,"Loop","Rank 3"},
  {601,9,600,0,nil,"Spark","Rank 3"},
  {103,20,102,0,400,"Bolt","Rank 4"},
  {203,20,202,0,4000,"Blast","Rank 4"},
  {401,20,400,0,500,"Skip","Rank 2"},
 }}}
 E.ClassQuests={[300]={Dwarf={name="Mending"}}} -- not your race: the rank above it still waits
 local function Find(id)for _,r in ipairs(rows)do if r.data.spellID==id then return r end end end
 local function Place(id)for i,r in ipairs(rows)do if r.data.spellID==id then return i end end end
 local old=level;UnitClass=function()return "Mage","MAGE"end;items={}
 local function Scan(l,known)level=l;knownIDs=known;options={};rows,s=M:Collect()end
 -- Only rank 1 known, ranks 2 and 3 in level, rank 4 above it.
 Scan(10,{[100]=true})
 equal(Find(101).ready,true,"Bolt 2 is ready");equal(Find(101).group,1,"available now")
 equal(Find(102).ready,true,"Bolt 3 too: one visit buys both");equal(Find(102).group,1,"available now too")
 equal(Find(103).ready,false,"Bolt 4 is above your level");equal(Find(103).group,4,"so it comes later")
 equal(Place(101)<Place(102),true,"rank 2 lists before rank 3")
 equal(Find(101).needsPrevious,false,"Bolt 2's rank is known");equal(Find(102).needsPrevious,true,"Bolt 3 still says it needs rank 2")
 Scan(19,{[100]=true});equal(Find(103).group,3,"one or two levels off, Bolt 4 is coming soon")
 -- A talent you don't have stops its ranks and all above them, whatever their level.
 Scan(10,{[100]=true})
 equal(Find(201).ready,false,"no talent: Blast 2 isn't ready");equal(Find(201).group,2,"it lacks a step")
 equal(Find(202).ready,false,"nor Blast 3");equal(Find(202).group,2,"it lacks a step too")
 equal(Find(203).ready,false,"nor Blast 4");equal(Find(203).group,4,"which is later anyway")
 Scan(30,{});equal(Find(203).ready,false,"nor at any level");equal(Find(203).group,2,"still lacking a step")
 Scan(10,{[200]=true});equal(Find(201).ready and Find(202).ready,true,"with the talent, both ranks in level are ready")
 equal(Find(203).ready,false,"the one above your level isn't")
 -- A quest's rank 1 is listed, but a trainer doesn't sell it.
 Scan(10,{})
 equal(Find(300).ready,true,"Mend 1 is listed as now");equal(Find(301).ready,false,"Mend 2 waits for it");equal(Find(301).group,2,"it lacks a step")
 equal(Find(302).ready,false,"so does Mend 3");equal(Find(302).group,2,"it lacks a step too")
 Scan(10,{[300]=true})
 equal(Find(300),nil,"the quest done");equal(Find(301).ready and Find(302).ready,true,"then both ranks are ready")
 -- A trainer that offers Mend 1 is selling it, whatever the list says.
 options={trainingGuide={entries={["Mend\031Rank 1"]={name="Mend",rank="Rank 1",level=2,trainer=true,cost=5,spellID=300}}}}
 knownIDs={};rows,s=M:Collect()
 equal(Find(301).ready and Find(302).ready,true,"a trainer selling rank 1 lets the ranks above it through")
 -- A higher rank known hides the lower ones; the next rank up is ready.
 items={{name="Bolt",subName="Rank 3",itemType=1,spellID=102,iconID=1}}
 Scan(20,{})
 equal(Find(101),nil,"Bolt 3 known: no rank 2");equal(Find(102),nil,"nor rank 3");equal(Find(103).ready,true,"rank 4 is ready")
 items={}
 -- Skip's rank 2 is above your level though rank 3 and 4 aren't: they wait for it.
 Scan(10,{[400]=true})
 equal(Find(401).ready,false,"Skip 2 is above your level");equal(Find(401).group,4,"so it comes later")
 equal(Find(402).ready,false,"Skip 3 can't come before it");equal(Find(402).group,2,"it lacks a step")
 equal(Find(403).ready,false,"nor Skip 4");equal(Find(403).group,2,"it lacks a step too")
 Scan(20,{[400]=true})
 equal(Find(401).ready and Find(402).ready and Find(403).ready,true,"at 20 all three, whatever order the rows come in")
 -- Two ranks that name each other never count, and never hang.
 equal(Find(501).ready or Find(502).ready,false,"a ring in the data is never ready");equal(Find(502).group,2,"it lacks a step")
 -- The book says Spark 2 is coming, but no trainer row has it: it isn't on sale.
 items={{name="Spark",subName="Rank 2",itemType=2,spellID=600,iconID=1}}
 Scan(14,{})
 equal(Find(600).ready,false,"Spark 2 is only listed as coming")
 equal(Find(601).ready,false,"so Spark 3 waits");equal(Find(601).group,2,"it lacks a step")
 items={}
 -- The totals count every ready rank and only those.
 Scan(10,{[100]=true})
 equal(s.nowCount,3,"Now: Bolt 2, Bolt 3 and Mend 1");equal(s.now,300,"Bolt 2 and 3's prices (a quest's spell is free)")
 equal(s.nowUnknown,1,"Mend 1's price is unknown: the list has no quest for you")
 UnitRace=function()return "Dwarf","Dwarf",3 end
 Scan(10,{[100]=true})
 equal(Find(300).quest.name,"Mending","the list's quest for your race");equal(s.nowUnknown,0,"a quest's spell has no price to find")
 equal(Find(301).ready,false,"and Mend 2 waits for it all the same")
 UnitRace=nil
 Scan(10,{[100]=true,[200]=true,[300]=true})
 equal(s.nowCount,6,"Bolt, Blast and Mend ranks 2 and 3");equal(s.now,33300,"all their prices")
 equal(s.all,33300+400+4000+500+600+700+50+60,"every unlearned rank's price for the whole list")
 -- A trainer's recorded requirement of the rank before it counts the same way;
 -- one of something else still blocks. Skill too, and all above it.
 local function Quote(id,name,rank,lvl,extra)
  local row={name=name,rank=rank,level=lvl,trainer=true,cost=1,spellID=id}
  for k,v in pairs(extra)do row[k]=v end
  options.trainingGuide.entries[name.."\031"..rank]=row
 end
 options={trainingGuide={entries={}}}
 knownIDs={[100]=true};level=10
 Quote(102,"Bolt","Rank 3",8,{requirements={["Bolt (Rank 2)"]=false}})
 rows,s=M:Collect();equal(Find(102).ready,true,"Bolt 3's requirement of Bolt 2 is on sale")
 Quote(102,"Bolt","Rank 3",8,{requirements={["Bolt Rank 2"]=false}})
 rows,s=M:Collect();equal(Find(102).ready,true,"however the trainer writes it")
 Quote(102,"Bolt","Rank 3",8,{requirements={["Bolt (Rank 2)"]=false,["Other Spell"]=false}})
 rows,s=M:Collect();equal(Find(102).ready,false,"another spell you lack still blocks");equal(Find(102).group,2,"it lacks a step")
 Quote(102,"Bolt","Rank 3",8,{requirements={["Mend (Rank 1)"]=false}})
 rows,s=M:Collect();equal(Find(102).ready,false,"a requirement a quest teaches isn't on sale")
 options.trainingGuide.entries={}
 Quote(101,"Bolt","Rank 2",4,{skillBlocked=true,skill="Fire"})
 rows,s=M:Collect()
 equal(Find(101).ready,false,"a skill you lack stops Bolt 2");equal(Find(102).ready,false,"and Bolt 3 above it");equal(Find(102).group,2,"which lacks a step")
 level=old;knownIDs={};items={};options={};UnitClass=function()return "Hunter","HUNTER"end
 E.TrainingData,E.ClassQuests=realData,realQuests
end
-- Rank 1s no trainer sells that the class quest list doesn't have yet: a priest's
-- racial spells and two book ranks. Rank 1 stays listed; the ranks above wait for
-- it. A trainer that has quoted rank 1 sells it, so a wrong guess corrects itself.
do
 local function Find(id)for _,r in ipairs(rows)do if r.data.spellID==id then return r end end end
 local function Row(class,id)for _,r in ipairs(E.TrainingData.classes[class])do if r[1]==id then return r end end end
 local function As(c,known)
  UnitClass=function()return c.class,c.class end
  UnitRace=function()return c.race,c.race,c.id end
  level=c.level;items={};knownIDs=known or{};options={}
  rows,s=M:Collect()
 end
 local old=level
 assert(loadfile("Modules/ClassQuestData.lua"))("EraUI",E)
 for _,c in ipairs({
  {class="PRIEST",race="Scourge",id=5,level=30,first=2652,above={19261,19262}}, -- Touch of Weakness
  {class="PRIEST",race="Scourge",id=5,level=28,first=2944,above={19276}}, -- Devouring Plague
  {class="PRIEST",race="Human",id=1,level=28,first=2944,above={19276}}, -- every race's row, but the quest is one race's
  {class="PRIEST",race="Troll",id=8,level=30,first=9035,above={19281,19282}}, -- Hex of Weakness
  {class="PRIEST",race="Troll",id=8,level=28,first=18137,above={19308}}, -- Shadowguard
  {class="PRIEST",race="NightElf",id=4,level=26,first=10797,above={19296,19299}}, -- Starshards
  {class="PRIEST",race="Dwarf",id=3,level=26,first=13908,above={19236,19238}}, -- Desperate Prayer
  {class="PRIEST",race="Human",id=1,level=30,first=13896,above={19271}}, -- Feedback
  {class="PRIEST",race="Human",id=1,level=26,first=1277370,above={1277371,1277372}}, -- Divine Grace
  {class="PRIEST",race="Gnome",id=7,level=30,first=1277462,above={1277634}}, -- Contingency Plan
  {class="PRIEST",race="Human",id=1,level=60,first=21562,above={21564}}, -- Prayer of Fortitude
  {class="DRUID",race="Tauren",id=6,level=60,first=21849,above={21850}}, -- Gift of the Wild
 })do
  local base,second=Row(c.class,c.first),Row(c.class,c.above[1])
  local name,tag=base[6],base[6]..": "
  equal(base[5],nil,tag.."rank 1 has no price");equal(second[3],c.first,tag.."rank 2 names it")
  local function Above(ready,group,why)
   for _,id in ipairs(c.above)do equal(Find(id).ready,ready,tag..id.." "..why);equal(Find(id).group,group,tag..id.." "..why)end
  end
  As(c)
  equal(Find(c.first).ready,true,tag.."rank 1 stays listed as now");equal(Find(c.first).group,1,tag.."under Available Now")
  Above(false,2,"waits for rank 1")
  equal(Find(c.above[1]).needsPrevious,true,tag.."its tooltip names rank 1")
  As(c,{[c.first]=true})
  equal(Find(c.first),nil,tag.."rank 1 learned");Above(true,1,"is ready once rank 1 is known")
  As(c)
  options={trainingGuide={entries={[name.."\031Rank 1"]={name=name,rank="Rank 1",level=base[2],trainer=true,spellID=c.first}}}}
  rows,s=M:Collect();Above(true,1,"is ready once a trainer has quoted rank 1")
  options={trainingGuide={entries={[name.."\031"..second[7]]={name=name,rank=second[7],level=second[2],trainer=true,cost=1,spellID=second[1],
   requirements={[name.." (Rank 1)"]=false}}}}}
  rows,s=M:Collect();Above(false,2,"waits when a trainer quotes it but not rank 1")
 end
 -- The totals: an Undead priest who has bought everything else at 30.
 local undead={class="PRIEST",race="Scourge",id=5,level=30}
 local all={}
 for _,r in ipairs(E.TrainingData.classes.PRIEST)do if r[2]<=30 then all[r[1]]=true end end
 for _,id in ipairs({2652,19261,19262,2944,19276})do all[id]=nil end
 As(undead,all)
 equal(s.nowCount,2,"Now: the two rank 1s only");equal(s.now,0,"no gold for the ranks above them");equal(s.nowUnknown,2,"their prices are unknown")
 all[2652]=true;As(undead,all)
 equal(s.nowCount,3,"Touch of Weakness 1 known: ranks 2 and 3 with Devouring Plague 1");equal(s.now,650,"their prices");equal(s.nowUnknown,1,"Devouring Plague 1's is unknown")
 -- A rank 1 a trainer does sell, priced or not, still lets the ranks above it through.
 As({class="WARRIOR",race="Human",id=1,level=38})
 equal(Find(1240193).ready and Find(1464).ready and Find(8820).ready,true,"Slam 1, 2 and 3 together")
 As({class="PALADIN",race="Human",id=1,level=30})
 equal(Find(26573).ready and Find(20116).ready,true,"Consecration 1 and 2 together")
 UnitRace=nil;E.ClassQuests=nil
 level=old;knownIDs={};items={};options={};UnitClass=function()return "Hunter","HUNTER"end
end
-- Build 70753: a druid's Lacerate starts with a talent (1328617, never a row), so
-- rank 2 and all above it wait for that; Ferocious Bite has a new rank 1 at 24;
-- Holy Shield's ranks wait for its talent; Primal Bite 4 and Lava Burst's ranks
-- are gone, and a book still listing Lava Burst as coming doesn't bring it back.
do
 local function Find(id)for _,r in ipairs(rows)do if r.data.spellID==id then return r end end end
 local function As(class,at,known,book)
  UnitClass=function()return class,class end
  level=at;knownIDs=known or{};items=book or{};options={}
  rows,s=M:Collect()
 end
 local old=level
 local LACERATE={1328616,414644,1235826,1235827}
 As("DRUID",60)
 for _,id in ipairs(LACERATE)do
  equal(Find(id).ready,false,id.." Lacerate waits without the talent");equal(Find(id).group,2,id.." it lacks a step")
 end
 equal(Find(1328616).needsPrevious,true,"its tooltip names the talent")
 As("DRUID",60,{[1328617]=true})
 for _,id in ipairs(LACERATE)do equal(Find(id).ready,true,id.." Lacerate is ready with the talent")end
 As("DRUID",33);equal(Find(1328618).ready,true,"Ferocious Bite 1 needs nothing");equal(Find(22568).ready,true,"rank 2 with it: one visit buys both")
 equal(Find(22827).group,4,"rank 3 comes later, at 40")
 As("DRUID",23);equal(Find(1328618).group,3,"rank 1 at 24 is coming soon")
 As("DRUID",33,{[22568]=true},{{name="Ferocious Bite",subName="Rank 2",itemType=1,spellID=22568,iconID=1}})
 equal(Find(22568),nil,"a druid who has the old rank has it");equal(Find(1328618),nil,"and the book's rank covers the new rank 1")
 As("DRUID",60);equal(Find(1238073),nil,"Primal Bite 4 is gone")
 As("PALADIN",60)
 for _,id in ipairs({20927,20928,1239570})do equal(Find(id).group,2,id.." Holy Shield waits for its talent")end
 As("PALADIN",60,{[20925]=true})
 for _,id in ipairs({20927,20928,1239570})do equal(Find(id).ready,true,id.." Holy Shield is ready with its talent")end
 As("SHAMAN",60,{[408490]=true},{{name="Lava Burst",subName="Rank 2",itemType=2,spellID=1238299,iconID=1}})
 for _,id in ipairs({1238299,1238300,1326047})do equal(Find(id),nil,id.." Lava Burst is gone, the book's coming rank too")end
 -- A client a build behind the list has none of the new spells. Its druid sees
 -- what it can buy, under its own rank text: no new row, ready or not, and no
 -- rank held back by one.
 local gone={[1328616]=true,[1328617]=true,[1328618]=true,[1239570]=true}
 local behind={[22568]="Rank 1",[22827]="Rank 2",[22828]="Rank 3",[22829]="Rank 4",[31018]="Rank 5",
  [414644]="Rank 1",[1235826]="Rank 2",[1235827]="Rank 3"}
 C_Spell.DoesSpellExist=function(id)return not gone[id]end
 C_Spell.GetSpellSubtext=function(id)return behind[id]end
 As("DRUID",60)
 for id in pairs(gone)do equal(Find(id),nil,id.." has no row on the older client")end
 for _,id in ipairs({414644,1235826,1235827,22568,22827,22828,22829,31018})do
  equal(Find(id).ready,true,id.." is ready on the older client")
 end
 equal(Find(414644).data.previous,0,"Lacerate's old rank 1 needs nothing there");equal(Find(414644).data.rank,"Rank 1","and keeps the client's label")
 equal(Find(414644).needsPrevious,false,"so its tooltip names no rank");equal(Find(22568).needsPrevious,false,"Ferocious Bite's neither")
 As("DRUID",42,{[414644]=true});equal(Find(414644),nil,"bought: gone");equal(Find(1235826).group,4,"its next rank comes later")
 As("PALADIN",60,{[20925]=true});equal(Find(1239570),nil,"Holy Shield 4 has no row there");equal(Find(20928).ready,true,"rank 3 still does")
 C_Spell.GetSpellSubtext=nil
 -- Only a plain false counts: an error or a secret answer leaves the list as it is.
 C_Spell.DoesSpellExist=function()error("no")end
 As("DRUID",60);equal(Find(1328616)~=nil,true,"an error keeps the row");equal(Find(414644).ready,false,"and its wait")
 issecretvalue=function(v)return v=="secret"end
 C_Spell.DoesSpellExist=function()return "secret"end
 As("DRUID",60);equal(Find(1328616)~=nil,true,"a secret answer keeps the row");equal(Find(414644).ready,false,"and its wait")
 issecretvalue=nil;C_Spell.DoesSpellExist=nil
 level=old;knownIDs={};items={};options={};UnitClass=function()return "Hunter","HUNTER"end
end
-- Who a row's race mask lets in. The two Skyborne (95 the Alliance's, 96 the Horde's)
-- have no bit in the list's masks: they take every race's rows and their own side's,
-- never the other side's or one race's own. Every other race goes by its bit.
do
 local Fits=M.RaceFits
 local ALLIANCE,HORDE=-1321907123,1309324210 -- the game's masks for a whole side
 for _,c in ipairs({
  {id=95,side="Alliance",own=ALLIANCE,other=HORDE,bit=2^32,otherBit=2^33},
  {id=96,side="Horde",own=HORDE,other=ALLIANCE,bit=2^33,otherBit=2^32},
 })do
  local tag="Skyborne "..c.id..": "
  equal(Fits(0,c.id,c.side),true,tag.."a row for every race")
  equal(Fits(-1,c.id,c.side),true,tag.."every bit is every race too")
  equal(Fits(c.own,c.id,c.side),true,tag.."its own side's row")
  equal(Fits(c.other,c.id,c.side),false,tag.."never the other side's")
  equal(Fits(c.bit,c.id,c.side),true,tag.."a row naming it")
  equal(Fits(c.otherBit,c.id,c.side),false,tag.."not one naming the other Skyborne")
  equal(Fits(2^32+2^33,c.id,c.side),true,tag.."one naming both")
  for bit=0,7 do equal(Fits(2^bit,c.id,c.side),false,tag.."one race's own row, bit "..bit)end
  equal(Fits(0,c.id,nil),true,tag.."no side given: every race's row");equal(Fits(-1,c.id,nil),true,tag.."and every bit")
  equal(Fits(c.own,c.id,nil),false,tag.."but no side's")
 end
 equal(Fits(1+4,95,"Alliance"),true,"two Alliance races count as that side's");equal(Fits(1+4,96,"Horde"),false,"not the Horde's")
 equal(Fits(2+16,96,"Horde"),true,"two Horde races count as that side's");equal(Fits(2+16,95,"Alliance"),false,"not the Alliance's")
 equal(Fits(HORDE,nil,"Alliance"),true,"a race the game won't say drops nothing")
 -- The real rows have only these kinds of mask, and every other race answers as
 -- the plain bit test always did, whichever side it's told.
 local masks={}
 for _,data in pairs(E.TrainingData.classes)do for _,row in ipairs(data)do masks[row[4]]=true end end
 local kinds={[0]=true,[-1]=true,[ALLIANCE]=true,[HORDE]=true}
 for bit=0,7 do kinds[2^bit]=true end
 for mask in pairs(masks)do equal(kinds[mask],true,"a kind of mask the Skyborne rule was checked against: "..mask)end
 equal(masks[0]and masks[-1]and masks[ALLIANCE]and masks[HORDE]and masks[4],true,"and the list has each kind")
 local function Old(mask,id)if mask<0 then mask=mask+4294967296 end;return mask==0 or math.floor(mask/2^(id-1))%2==1 end
 for mask in pairs(masks)do
  for id=1,30 do
   for _,side in ipairs({"Alliance","Horde",false})do
    equal(Fits(mask,id,side or nil),Old(mask,id),"race "..id.." on mask "..mask.." as before")
   end
  end
 end
 -- Whole lists from the module itself.
 local function Catalog(class,raceFile,id,side)
  UnitClass=function()return class,class end
  UnitRace=function()return raceFile,raceFile,id end
  UnitFactionGroup=function()return side end
  local got={};for _,row in pairs(M:Catalog())do got[row.spellID]=true end
  return got
 end
 local function All(got,ids,want,why)for _,id in ipairs(ids)do equal(got[id]==true,want,why.." "..id)end end
 local EVERY={6346,2944,19276,19277,19278,19279,19280} -- Fear Ward, Devouring Plague 1 to 6
 local OWN_RACES={13896,13908,10797,2652,1277462,9035} -- Feedback, Desperate Prayer, Starshards, Touch of Weakness, Contingency Plan, Hex of Weakness
 local ALLIANCE_TRAVEL={3561,3562,3565,10059,11416,11419,1297659} -- Stormwind, Ironforge, Darnassus and their portals, Dalaran
 local HORDE_TRAVEL={3567,3566,3563,11417,11420,11418} -- Orgrimmar, Thunder Bluff, Undercity and their portals
 for _,c in ipairs({
  {id=95,side="Alliance",mine=ALLIANCE_TRAVEL,theirs=HORDE_TRAVEL},
  {id=96,side="Horde",mine=HORDE_TRAVEL,theirs=ALLIANCE_TRAVEL},
 })do
  local tag="Skyborne "..c.id..": "
  local priest=Catalog("PRIEST","Skyborne",c.id,c.side)
  All(priest,EVERY,true,tag.."a priest's every-race row")
  All(priest,OWN_RACES,false,tag.."not one race's own")
  local mage=Catalog("MAGE","Skyborne",c.id,c.side)
  All(mage,c.mine,true,tag.."its own side's teleport or portal")
  All(mage,c.theirs,false,tag.."not the other side's")
 end
 -- Every other race's whole list is what the plain bit test lets in.
 for _,c in ipairs({{1,"Human","Alliance"},{2,"Orc","Horde"},{3,"Dwarf","Alliance"},{4,"NightElf","Alliance"},{5,"Scourge","Horde"},{6,"Tauren","Horde"},{7,"Gnome","Alliance"},{8,"Troll","Horde"}})do
  for class,data in pairs(E.TrainingData.classes)do
   local got=Catalog(class,c[2],c[1],c[3])
   for _,row in ipairs(data)do equal(got[row[1]]==true,Old(row[4],c[1]),c[2].." "..class.." "..row[1])end
  end
 end
 All(Catalog("MAGE","Human",1,"Alliance"),ALLIANCE_TRAVEL,true,"a Human mage's own side");All(Catalog("MAGE","Human",1,"Alliance"),HORDE_TRAVEL,false,"not the Horde's")
 All(Catalog("MAGE","Orc",2,"Horde"),HORDE_TRAVEL,true,"an Orc mage's own side");All(Catalog("MAGE","Orc",2,"Horde"),ALLIANCE_TRAVEL,false,"not the Alliance's")
 -- A side the game won't say: every race's rows stay, no side's.
 issecretvalue=function(v)return v=="Horde"end
 All(Catalog("MAGE","Skyborne",96,"Horde"),HORDE_TRAVEL,false,"a secret side: no side's row")
 All(Catalog("PRIEST","Skyborne",96,"Horde"),EVERY,true,"a secret side: every race's row")
 issecretvalue=nil
 All(Catalog("MAGE","Skyborne",95,nil),ALLIANCE_TRAVEL,false,"no side: no side's row")
 All(Catalog("PRIEST","Skyborne",95,nil),EVERY,true,"no side: every race's row")
 -- On through to the guide's groups: level 60, nothing known.
 local function Find(id)for _,r in ipairs(rows)do if r.data.spellID==id then return r end end end
 local old=level
 level,items,knownIDs,options=60,{},{},{}
 assert(loadfile("Modules/ClassQuestData.lua"))("EraUI",E)
 Catalog("MAGE","Skyborne",96,"Horde");rows,s=M:Collect()
 equal(Find(3567).ready,true,"a Horde Skyborne mage: Teleport: Orgrimmar is ready");equal(Find(11417).group,1,"Portal: Orgrimmar under Available Now")
 equal(Find(3561),nil,"no Teleport: Stormwind");equal(Find(10059),nil,"no Portal: Stormwind")
 Catalog("MAGE","Skyborne",95,"Alliance");rows,s=M:Collect()
 equal(Find(3561).ready,true,"an Alliance Skyborne mage: Teleport: Stormwind is ready");equal(Find(10059).group,1,"Portal: Stormwind under Available Now")
 equal(Find(3567),nil,"no Teleport: Orgrimmar");equal(Find(11417),nil,"no Portal: Orgrimmar")
 Catalog("PRIEST","Skyborne",96,"Horde");rows,s=M:Collect()
 equal(Find(6346).ready,true,"a Skyborne priest: Fear Ward is ready")
 equal(Find(2944).ready,true,"Devouring Plague 1 stays listed");equal(Find(19276).ready,false,"and rank 2 waits for it, as for every race")
 equal(Find(13908),nil,"no Dwarf's Desperate Prayer");equal(Find(9035),nil,"no Troll's Hex of Weakness")
 UnitRace=nil;UnitFactionGroup=nil;E.ClassQuests=nil
 level=old;knownIDs={};items={};options={};UnitClass=function()return "Hunter","HUNTER"end
end
-- The real list: within each spell a rank never lists before the one it names.
do
 local old=level;options={};items={};knownIDs={};level=60
 for class,data in pairs(E.TrainingData.classes)do
  UnitClass=function()return class,class end
  rows=M:Collect()
  local at={};for i,r in ipairs(rows)do at[r.data.spellID]=i end
  for _,row in ipairs(data)do
   if at[row[1]]and at[row[3]]then
    local a,b=rows[at[row[3]]],rows[at[row[1]]]
    if a.group==b.group then equal(at[row[3]]<at[row[1]],true,class.." "..row[1].." lists after the rank it names")end
   end
  end
 end
 level=old;UnitClass=function()return "Hunter","HUNTER"end
end

-- Exercise the actual embedded panel: it lives inside the book and suppresses
-- the native spell click layer while its searchable training rows are shown.
unpack=table.unpack
local combat=false
InCombatLockdown=function()return combat end
local function Widget(parent)
 local f={parent=parent,shown=true,scripts={},text="",scroll=0}
 function f:SetScript(key,fn)self.scripts[key]=fn end
 function f:IsShown()return self.shown end
 function f:Show()self.shown=true end
 function f:Hide()self.shown=false end
 function f:SetShown(v)self.shown=v end
 function f:GetParent()return self.parent end
 function f:GetFrameLevel()return 1 end
 function f:SetText(text)self.text=text;if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self)end end
 function f:GetText()return self.text end
 function f:SetHeight(h)self.height=h end
 function f:GetHeight()return self.height or 260 end
 function f:SetVerticalScroll(v)self.scroll=v end
 function f:GetVerticalScroll()return self.scroll end
 function f:CreateTexture()return Widget(self)end
 function f:SetChecked(v)self.checked=v end
 function f:SetEnabled(v)self.enabled=v end
 for _,name in ipairs({"SetPoint","SetFrameLevel","EnableMouse","SetSize","SetAutoFocus","SetMaxLetters","ClearFocus",
  "SetScrollChild","SetTextColor","SetWidth","SetJustifyH","SetTexture","SetWordWrap"})do f[name]=function()end end
 return f
end
CreateFrame=function(_,name,parent)local f=Widget(parent);if name then _G[name]=f end;return f end
E.ClassTools.Skin=function()end
E.ClassTools.Text=function(parent,text)local f=Widget(parent);f.text=text;return f end
E.ClassTools.Spell=function(id)return nil,id end
local owner=Widget()
for _,key in ipairs({"Search","Ranks","PageText","PrevPage","NextPage","TrainTab","Title"})do owner[key]=Widget(owner)end
owner.Buttons={Widget(owner),Widget(owner)};owner.SkillTabs={Widget(owner)};owner.BookTabs={Widget(owner)}
function owner:SetLayer(on)self.layer=on end
function owner:Refresh()self.refreshed=true end
M:Toggle(owner)
local panel=EraUITrainingGuide
equal(panel:GetParent(),owner,"training is part of the spellbook rather than a popout")
equal(owner.layer,false,"underlying spell actions disabled while training tab shown")
equal(owner.Buttons[1]:IsShown(),false,"normal spell artwork hidden")
equal(owner.TrainTab.checked,true,"training tab selected")
equal(owner.Title.text,"Training Guide","spellbook title follows training tab")
equal(panel.content.height>panel.scroll:GetHeight(),true,"full offline catalog scrolls")
panel.search:SetText("Tame Beast")
local visible=0;for _,r in ipairs(panel.rows)do if r:IsShown()and r.data then visible=visible+1;equal(r.data.name,"Tame Beast","search filters rows")end end
equal(visible,1,"search returns one matching training entry")
M:Close()
equal(owner.trainingShown,false,"class-tab exit clears training selection")
equal(owner.layer,true,"normal spell click layer restored")
equal(owner.Buttons[1]:IsShown(),true,"normal spell artwork restored")
equal(owner.Search:IsShown(),true,"normal spell search restored")
combat=true;M:Toggle(owner)
equal(owner.trainingShown,false,"combat cannot hide protected spell click layer")
-- Spells a class quest teaches show that quest, for your race and faction.
assert(loadfile("Modules/ClassQuestData.lua"))("EraUI",E)
local RACE_IDS={Human=1,Orc=2,Dwarf=3,NightElf=4,Scourge=5,Tauren=6,Gnome=7,Troll=8}
local FACTIONS={Alliance=true,Horde=true}
local spellRow={}
for _,data in pairs(E.TrainingData.classes)do for _,row in ipairs(data)do spellRow[row[1]]=row end end
local listed=0
for spellID,quests in pairs(E.ClassQuests)do
 local row=spellRow[spellID]
 equal(row~=nil,true,"quest spell "..spellID.." is a class spell")
 equal(row[5],nil,row[6].." has no trainer price")
 for key,quest in pairs(quests)do
  local race,side=key:match("^(%a+):(%a+)$")
  local known=race and(RACE_IDS[race]or race=="Skyborne")and FACTIONS[side]or RACE_IDS[key]or key=="Skyborne"or FACTIONS[key]
  equal(known and true,true,row[6].." quest keyed by a known race or faction: "..key)
  equal(type(quest.name)=="string"and quest.name~="",true,row[6].." quest named for "..key)
  for _,field in ipairs({"first","npc","spot","where"})do
   equal(quest[field]==nil or type(quest[field])=="string"and quest[field]~="",true,row[6].." "..field.." is text for "..key)
  end
  equal(quest.spot==nil or quest.where~=nil,true,row[6].." spot is in a zone for "..key)
  listed=listed+1
 end
end
equal(listed>80,true,"every class and race listed")
local race,side="Tauren","Horde"
UnitRace=function()return race,race,race=="Skyborne"and(side=="Horde"and 96 or 95)or RACE_IDS[race]end
UnitFactionGroup=function()return side end
local function Quest(id,row)return M.QuestFor(row or{spellID=id,trainer=true,reference=true})end
equal(Quest(5487).name,"Body and Heart","Tauren druids learn Bear Form from a quest")
equal(Quest(5487).npc,"Turak Runetotem","which starts in Thunder Bluff")
equal(Quest(6795),Quest(5487),"Growl comes with it")
race,side="NightElf","Alliance"
equal(Quest(18960).npc,"Mathrengyl Bearwalker","Night Elf druids go to Darnassus for Moonglade")
race,side="Skyborne","Horde"
equal(Quest(18960).npc,"Muln Earthfury","Horde Skyborne have their own Moonglade quest")
side="Alliance"
equal(Quest(18960).npc,"Archmage Ansirem Runeweaver","and so do Alliance Skyborne")
equal(Quest(5487).name,"Strength and Mercy","both Skyborne share their bear quest")
equal(Quest(8946),nil,"no label where no quest is known")
race,side="Human","Alliance"
equal(Quest(2458).npc,"Wu Shen","a faction's entry")
race="Dwarf"
equal(Quest(2458).npc,"Kelv Sternhammer","a race's own entry comes first")
race,side="Troll","Horde"
equal(Quest(20252).npc,"Sorek","Intercept comes with Berserker Stance")
race="Scourge"
equal(Quest(1122).where,"Felwood","one Inferno quest for every warlock")
race="Tauren"
equal(Quest(5487,{spellID=5487,trainer=true,reference=false}),nil,"a spell a trainer has offered isn't labelled")
equal(Quest(5487,{spellID=5487,trainer=true}),nil,"nor one only a trainer listed")
equal(Quest(5487,{spellID=5487})~=nil,true,"a spell the book says is coming is")
equal(Quest(768),nil,"trainer spells have no quest")
equal(M.QuestStart(Quest(5487)),"The chain starts with \"Moonglade\", from Turak Runetotem in Elder Rise, Thunder Bluff.","where the chain starts")
equal(M.QuestStart(Quest(1515)),"Given by Yaw Sharpmane in Bloodhoof Village, Mulgore.","or who gives the quest")
race="Orc"
equal(M.QuestStart(Quest(713)),"The chain starts with \"Love Hurts\".","only what's known")
race,side="Dwarf","Alliance"
equal(M.QuestStart(Quest(3599)),nil,"nothing more when only the name is known")
-- They aren't bought, so they aren't unknown trainer prices.
UnitClass=function()return "Druid","DRUID"end
race,side="Tauren","Horde";level=10;options={};items={}
local quests=E.ClassQuests
E.ClassQuests=nil;local _,plain=M:Collect()
E.ClassQuests=quests;rows,s=M:Collect()
local questRows,bear=0
for _,r in ipairs(rows)do
 if r.quest then questRows=questRows+1 end
 if r.data.spellID==5487 then bear=r end
end
equal(bear.quest.name,"Body and Heart","the guide's rows carry the quest")
equal(questRows,6,"Bear Form, Growl, Maul, Moonglade, Cure Poison and Aquatic Form")
equal(plain.unknown-s.unknown,6,"quest spells aren't unknown prices")
equal(plain.nowUnknown-s.nowUnknown,4,"nor in what you can train now")
equal(s.count,plain.count,"they're still listed")
-- In the panel: a second line under the spell, and the quest in its tooltip.
local tips={}
GameTooltip={SetOwner=function()end,SetSpellByID=function()end,SetText=function()end,Show=function()end,Hide=function()end,
 AddLine=function(_,text)tips[#tips+1]=text end}
local function Find(name)
 for _,r in ipairs(panel.rows)do if r:IsShown()and r.data and r.data.name==name then return r end end
end
combat=false;M:Toggle(owner)
panel.search:SetText("Growl")
local growl=Find("Growl")
equal(growl.height,36,"a quest spell's row has room for its quest")
equal(growl.questText:IsShown(),true,"shown under it")
equal(growl.questText:GetText(),"|cffffd24aQuest:|r Body and Heart  |cffaaaaaaThunder Bluff|r","its name and where it starts")
equal(panel.content.height,22+36,"the list makes room for it")
growl.scripts.OnEnter(growl)
local text=table.concat(tips,"\n")
equal(text:find("Learned from the quest \"Body and Heart\", not a trainer.",1,true)~=nil,true,"the tooltip names the quest")
equal(text:find("The chain starts with \"Moonglade\", from Turak Runetotem in Elder Rise, Thunder Bluff.",1,true)~=nil,true,"and where to start")
equal(text:lower():find("price",1,true),nil,"and no trainer price")
tips={}
panel.search:SetText("Teleport")
local teleport=Find("Teleport: Moonglade")
teleport.scripts.OnEnter(teleport)
equal(tips[2],"You learn it as you accept the quest \"Moonglade\", not from a trainer.","Moonglade is learned as you accept its quest")
equal(tips[3],"Given by Turak Runetotem in Elder Rise, Thunder Bluff.","from Turak")
panel.search:SetText("Cat Form")
local cat=Find("Cat Form")
equal(cat.height,22,"trainer spells keep one line")
equal(cat.questText:IsShown(),false,"with no quest")
-- The rank before it shows in the tooltip only while it isn't known: Wrath 2
-- needs the rank 1 every druid starts with.
do
 local subtext=C_Spell.GetSpellSubtext
 C_Spell.GetSpellSubtext=function(id)return id==5176 and "Rank 1"or nil end
 local function Wrath()for _,r in ipairs(panel.rows)do if r:IsShown()and r.data and r.data.spellID==5177 then return r end end end
 local function Tip()tips={};local r=Wrath();r.scripts.OnEnter(r);return table.concat(tips,"\n")end
 knownIDs={};panel.search:SetText("Wrath")
 equal(Tip():find("Requires previous rank: 5176 (Rank 1)",1,true)~=nil,true,"Wrath 2 names the rank it needs")
 knownIDs={[5176]=true};panel.search:SetText("Wrath")
 equal(Tip():find("Requires previous rank",1,true),nil,"and not once that rank is known")
 -- Wrath 3 sits under Available Now with Wrath 2 unbought, and still names it.
 local oldLevel=level;level=14
 C_Spell.GetSpellSubtext=function(id)return id==5177 and "Rank 2"or nil end
 panel.search:SetText("Wrath ")
 local two,three
 for index,r in ipairs(panel.rows)do
  if r:IsShown()and r.data then
   if r.data.spellID==5177 then two=index elseif r.data.spellID==5178 then three=index end
  end
 end
 equal(panel.rows[1].title:GetText(),"Available Now","Wrath 2 and 3 are under Available Now")
 equal(two~=nil and three==two+1,true,"rank 2, then rank 3")
 local wrath3=panel.rows[three];tips={};wrath3.scripts.OnEnter(wrath3)
 equal(table.concat(tips,"\n"):find("Requires previous rank: 5177 (Rank 2)",1,true)~=nil,true,"Wrath 3's tooltip names the rank it needs first")
 level=oldLevel
 knownIDs={};C_Spell.GetSpellSubtext=subtext
end
M:Close()
print("Training guide checks passed: "..checks.." assertions; "..total.." bundled class entries.")
