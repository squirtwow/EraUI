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
  "SetScrollChild","SetTextColor","SetWidth","SetJustifyH","SetTexture"})do f[name]=function()end end
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
print("Training guide checks passed: "..checks.." assertions; "..total.." bundled class entries.")
