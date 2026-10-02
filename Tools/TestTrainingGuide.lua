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
M:Close()
print("Training guide checks passed: "..checks.." assertions; "..total.." bundled class entries.")
