-- Original, embedded spellbook training tab. Bundled game metadata populates
-- immediately; optional live trainer quotes refine the reference base prices.
local _,E=...
local M={};E:RegisterModule("TrainingGuide",M)
local T=E.ClassTools
local window,book,trainerOpen,scanning,queued
local function Public(v)return not(issecretvalue and issecretvalue(v))end
local function Number(v)return Public(v)and type(v)=="number"end
local function Key(name,rank)return name.."\031"..(rank or "")end
local function Cache()
 local options=T.Options()
 if type(options.trainingGuide)~="table"then options.trainingGuide={entries={}}end
 local cache=options.trainingGuide
 cache.entries=cache.entries or{}
 return cache
end
function M:Enabled()return E:GetSetting("enabled")and E:GetSetting("trainingGuide")end

-- Read actual ranks, including hidden lower ranks. Future spells are kept out
-- of the known set; their client level is useful even before a trainer visit.
function M:BookData()
 local known,labels,ranks,future,categories,ids={},{},{},{},{},{}
 local class=UnitClass("player");if class then categories[class]=true end
 local api=C_SpellBook
 if not api or not api.GetNumSpellBookSkillLines then return known,labels,ranks,future,categories,ids end
 local bank=Enum.SpellBookSpellBank.Player
 for line=1,api.GetNumSpellBookSkillLines()do
  local info=api.GetSpellBookSkillLineInfo(line)
  if info and not info.shouldHide and not info.isGuild and(not info.offSpecID or info.offSpecID==0)then
   if line>1 then categories[info.name]=true end
   for slot=info.itemIndexOffset+1,info.itemIndexOffset+info.numSpellBookItems do
    local item=api.GetSpellBookItemInfo(slot,bank)
    if item and Public(item.name)and type(item.name)=="string"and Public(item.subName)and Public(item.itemType)then
     local rank=item.subName or ""
     if item.itemType==Enum.SpellBookItemType.FutureSpell then
      local level=C_Spell and C_Spell.GetSpellLevelLearned and C_Spell.GetSpellLevelLearned(item.spellID)
      if Number(level)and level>1 and level<=60 then
       future[Key(item.name,rank)]={name=item.name,rank=rank,level=level,spellID=item.spellID,icon=item.iconID}
      end
     elseif item.itemType==Enum.SpellBookItemType.Spell then
      if Number(item.spellID)then ids[item.spellID]=true end
      known[Key(item.name,rank)]=true;labels[item.name]=true
      labels[item.name.." ("..rank..")"]=true;labels[item.name.." "..rank]=true
      local n=tonumber(rank:match("%d+"))
      if n then ranks[item.name]=math.max(ranks[item.name]or 0,n)end
     end
    end
   end
  end
 end
 return known,labels,ranks,future,categories,ids
end
function M:Catalog()
 local _,class=UnitClass("player")
 local race=UnitRace and select(3,UnitRace("player"))
 local entries={}
 for _,data in ipairs(E.TrainingData and E.TrainingData.classes[class]or{})do
  local mask=data[4];if mask<0 then mask=mask+4294967296 end
  if mask==0 or not race or math.floor(mask/2^(race-1))%2==1 then
   local name,icon
   if T.Spell then name,icon=T.Spell(data[1])end
   local rank=data[7]
   if C_Spell and C_Spell.GetSpellSubtext then rank=C_Spell.GetSpellSubtext(data[1])or rank end
   local row={spellID=data[1],level=data[2],previous=data[3],cost=data[5],name=name or data[6],rank=rank,
    icon=icon,trainer=true,reference=true}
   entries[Key(row.name,row.rank)]=row
  end
 end
 return entries
end
local function Learned(row,known,ranks)
 if row.learned or known[Key(row.name,row.rank)]then return true end
 local rank=tonumber((row.rank or ""):match("%d+"))
 if rank and ranks[row.name]and ranks[row.name]>=rank then return true end
 if row.spellID then return T.Known(row.spellID)end
 return false
end
function M:Collect()
 local known,labels,ranks,future,_,ids=self:BookData()
 local merged=self:Catalog()
 for k,row in pairs(future)do if not merged[k]then merged[k]=row end end
 for k,row in pairs(Cache().entries)do
  local base=merged[k]
  if base then
   local quote={};for field,value in pairs(base)do quote[field]=value end
   for field,value in pairs(row)do quote[field]=value end
   quote.reference=false;merged[k]=quote
  else merged[k]=row end
 end
 for _,row in pairs(merged)do
  if Learned(row,known,ranks)then
   labels[row.name]=true
   if row.spellID then ids[row.spellID]=true end
   labels[row.name.." ("..row.rank..")"]=true;labels[row.name.." "..row.rank]=true
  end
 end
 local rows,summary={},{now=0,all=0,unknown=0,nowUnknown=0,count=0,nowCount=0}
 local level=UnitLevel("player")or 1
 for _,row in pairs(merged)do
  if not Learned(row,known,ranks)then
   local ready=row.trainer and row.level<=level and not row.skillBlocked
   local missing=row.skillBlocked
   if row.previous and row.previous>0 and not ids[row.previous]and not T.Known(row.previous)then missing=true end
   for name,met in pairs(row.requirements or{})do
    if not met and not labels[name]then missing=true end
   end
   if missing then ready=false end
   local group=row.level>level and(row.level<=level+2 and 3 or 4)or(missing and 2 or 1)
   local result={data=row,ready=ready==true,group=group}
   rows[#rows+1]=result;summary.count=summary.count+1
   if Number(row.cost)then summary.all=summary.all+row.cost else summary.unknown=summary.unknown+1 end
   if ready then
    summary.nowCount=summary.nowCount+1
    if Number(row.cost)then summary.now=summary.now+row.cost else summary.nowUnknown=summary.nowUnknown+1 end
   end
  end
 end
 table.sort(rows,function(a,b)
  if a.group~=b.group then return a.group<b.group end
  a,b=a.data,b.data
  if a.level~=b.level then return a.level<b.level end
  if a.name~=b.name then return a.name<b.name end
  return (tonumber((a.rank or ""):match("%d+"))or 0)<(tonumber((b.rank or ""):match("%d+"))or 0)
 end)
 return rows,summary
end

function M:Capture()
 if scanning or not trainerOpen or not self:Enabled()or InCombatLockdown()then return end
 if not C_Trainer or C_Trainer.GetTrainerType()~=Enum.TrainerType.General then return end
 if not GetNumTrainerServices or not GetTrainerServiceInfo then return end
 scanning=true
 local filters={}
 local ok,result=pcall(function()
  -- Service indices are filtered by the client. Read every state, then put all
  -- three filters back before returning, including when an API call fails.
  for _,kind in ipairs({"available","unavailable","used"})do
   if GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter then
    filters[kind]=GetTrainerServiceTypeFilter(kind)
    SetTrainerServiceTypeFilter(kind,true)
   end
  end
  local _,_,_,_,categories=self:BookData()
  local entries,matchedClass={},false
  for index=1,GetNumTrainerServices()do
   local name,kind,icon,level,rank,category=GetTrainerServiceInfo(index)
   if Public(name)and type(name)=="string"and Public(category)
    and Number(level)and(kind=="available"or kind=="unavailable"or kind=="used")then
    local cost,profession=GetTrainerServiceCost(index)
    if not profession then
     if categories[category]then matchedClass=true end
     rank=type(rank)=="string"and rank or ""
     local row={name=name,rank=rank,icon=icon,level=level,trainer=true,learned=kind=="used"}
     if Number(cost)and cost>=0 then row.cost=cost end
     local link=GetTrainerServiceItemLink and GetTrainerServiceItemLink(index)
     if Public(link)and type(link)=="string"then row.spellID=tonumber(link:match("spell:(%d+)"))end
     if GetTrainerServiceSkillReq then
      local skill,_,has=GetTrainerServiceSkillReq(index)
      if skill and not has then row.skillBlocked=true;row.skill=skill end
     end
     if GetTrainerServiceNumAbilityReq and GetTrainerServiceAbilityReq then
      for reqIndex=1,GetTrainerServiceNumAbilityReq(index)do
       local ability,has=GetTrainerServiceAbilityReq(index,reqIndex)
       if type(ability)=="string"then
        row.requirements=row.requirements or{}
        row.requirements[ability]=has==true
       end
      end
     end
     entries[Key(name,rank)]=row
    end
   end
  end
  return matchedClass and entries or{}
 end)
 for kind,value in pairs(filters)do pcall(SetTrainerServiceTypeFilter,kind,value)end
 scanning=false
 if not ok then self.lastError="Trainer data could not be read. Reopen your class trainer to retry.";return end
 if not next(result)then return end
 local cache=Cache()
 for key,row in pairs(result)do cache.entries[key]=row end
 cache.trainer=UnitName("npc")or "Class trainer"
 cache.updated=date and date("%Y-%m-%d")or ""
 self.lastError=nil
 E:SaveSettings()
 self:Refresh()
end

local function Money(n)
 if GetMoneyString then return GetMoneyString(n,true)end
 return string.format("%dg %ds %dc",math.floor(n/10000),math.floor(n/100)%100,n%100)
end
local function Total(n,unknown)
 return Money(n)..(unknown>0 and(" + "..unknown.." ?")or "")
end
local function Build(owner)
 if window then return end
 window=CreateFrame("Frame","EraUITrainingGuide",owner,"BackdropTemplate")
 -- Clear the spellbook's round portrait and its surrounding frame artwork.
 window:SetPoint("TOPLEFT",owner,"TOPLEFT",22,-76)
 window:SetPoint("BOTTOMRIGHT",owner,"BOTTOMRIGHT",-38,86)
 window:SetFrameLevel(owner:GetFrameLevel()+8);T.Skin(window);window:EnableMouse(true)
 window.search=CreateFrame("EditBox",nil,window,"InputBoxTemplate")
 window.search:SetPoint("TOPLEFT",10,-9);window.search:SetSize(292,20);window.search:SetAutoFocus(false)
 window.search:SetMaxLetters(60)
 local hint=T.Text(window.search,"Search training",11);hint:SetPoint("LEFT",3,0);hint:SetTextColor(.55,.55,.55)
 window.search:SetScript("OnTextChanged",function(self)
  hint:SetShown((self:GetText()or "")=="")
  if window.scroll then window.scroll:SetVerticalScroll(0);M:Refresh()end
 end)
 window.search:SetScript("OnEscapePressed",function(self)self:SetText("");self:ClearFocus()end)
 window.search:SetScript("OnEnterPressed",function(self)self:ClearFocus()end)
 window.now=T.Text(window,"",10);window.now:SetPoint("BOTTOMLEFT",8,34)
 window.total=T.Text(window,"",10);window.total:SetPoint("BOTTOMLEFT",8,20)
 window.note=T.Text(window,"Reference prices; ? = unverified. Hover for details.",9)
 window.note:SetPoint("BOTTOMLEFT",8,6);window.note:SetTextColor(.65,.65,.65)
 local scroll=CreateFrame("ScrollFrame",nil,window,"UIPanelScrollFrameTemplate")
 scroll:SetPoint("TOPLEFT",5,-36);scroll:SetPoint("BOTTOMRIGHT",-25,55)
 local content=CreateFrame("Frame",nil,scroll);content:SetSize(290,1);scroll:SetScrollChild(content)
 window.scroll,window.content,window.rows=scroll,content,{}
 window:Hide()
end
local groups={"Available Now","Available but Missing Requirements","Coming Soon","Not Yet Available"}
local colours={{.2,1,.2},{1,.55,.1},{.35,.7,1},{1,.2,.2}}
function M:Refresh()
 if not self:Enabled()then if window then window:Hide()end;return end
 if not window or not book or not book.trainingShown or not window:IsShown()then return end
 local rows,s=self:Collect()
 window.now:SetText("Now: "..Total(s.now,s.nowUnknown))
 window.total:SetText("All unlearned: "..Total(s.all,s.unknown))
 local query=(window.search:GetText()or ""):lower()
 local display,lastGroup={}
 for _,result in ipairs(rows)do
  if query==""or(result.data.name.." "..result.data.rank):lower():find(query,1,true)then
   if lastGroup~=result.group then display[#display+1]={header=groups[result.group],group=result.group};lastGroup=result.group end
   display[#display+1]=result
  end
 end
 if #display==0 then display[1]={header=query~=""and "No matching spells"or "All listed spells learned",group=1}end
 for index,result in ipairs(display)do
  local row=window.rows[index]
  if not row then
   row=CreateFrame("Frame",nil,window.content);row:SetSize(290,22)
   row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("LEFT",0,0);row.icon:SetSize(16,16)
   row.title=T.Text(row,"",11);row.title:SetPoint("LEFT",20,0);row.title:SetWidth(216);row.title:SetHeight(20)
   row.level=T.Text(row,"",10);row.level:SetPoint("RIGHT",-2,0);row.level:SetJustifyH("RIGHT")
   row:EnableMouse(true)
   row:SetScript("OnEnter",function(self)
    local data=self.data;if not data then return end
    GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
    if data.spellID and GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(data.spellID)
    else GameTooltip:SetText(data.name..(data.rank~=""and(" ("..data.rank..")")or ""))end
    GameTooltip:AddLine("Required level: "..data.level,1,.82,0)
    GameTooltip:AddLine(Number(data.cost)and((data.reference and "Classic base-price reference: "or "Recorded trainer quote: ")..Money(data.cost))or "Price not verified for this Forever spell.",.8,.8,.8,true)
    if data.reference then GameTooltip:AddLine("Reference prices may differ on Forever and exclude discounts.",.65,.65,.65,true)end
    if data.previous and data.previous>0 then local prev=T.Spell(data.previous);GameTooltip:AddLine("Requires previous rank: "..(prev or tostring(data.previous)),1,.55,.1,true)end
    for name in pairs(data.requirements or{})do GameTooltip:AddLine("Requires: "..name,.85,.85,.85,true)end
    if data.skill then GameTooltip:AddLine("Requires: "..data.skill,.85,.85,.85,true)end
    GameTooltip:Show()
   end)
   row:SetScript("OnLeave",function()GameTooltip:Hide()end)
   window.rows[index]=row
  end
  local data=result.data;row.data=data;row:SetPoint("TOPLEFT",0,-(index-1)*22)
  row.icon:SetShown(data~=nil);row.level:SetShown(data~=nil)
  if data then
   row.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_Book_09")
   row.title:SetText(data.name..(data.rank~=""and(" |cffaaaaaa("..data.rank..")|r")or ""))
   row.title:SetTextColor(1,.82,0);row.title:SetJustifyH("LEFT")
   row.level:SetText("Lv "..data.level);row.level:SetTextColor(unpack(colours[result.group]))
  else
   row.title:SetText(result.header);row.title:SetTextColor(unpack(colours[result.group]));row.title:SetJustifyH("CENTER")
  end
  row:Show()
 end
 for index=#display+1,#window.rows do window.rows[index]:Hide()end
 window.content:SetHeight(math.max(1,#display*22))
 window.scroll:SetVerticalScroll(math.min(window.scroll:GetVerticalScroll(),math.max(0,#display*22-window.scroll:GetHeight())))
end
function M:Toggle(owner)
 if not self:Enabled()or not owner or InCombatLockdown()then return end
 book=owner;Build(owner)
 if not book.trainingShown then
  book.trainingShown=true;window.previous={}
  local hide={book.Search,book.Ranks,book.PageText,book.PrevPage,book.NextPage}
  for _,b in ipairs(book.Buttons or{})do hide[#hide+1]=b end
  for _,f in ipairs(hide)do window.previous[f]=f:IsShown();f:Hide()end
  book:SetLayer(false)
 end
 for _,tab in ipairs(book.SkillTabs)do tab:SetChecked(false)end
 book.TrainTab:SetChecked(true);book.Title:SetText("Training Guide")
 if book.BookTabs and book.BookTabs[1]then book.BookTabs[1]:SetEnabled(true)end
 window:Show();self:Refresh()
end
function M:Close()
 if not book or not book.trainingShown or InCombatLockdown()then return end
 book.trainingShown=false;window:Hide()
 for f,shown in pairs(window.previous or{})do f:SetShown(shown)end
 book.TrainTab:SetChecked(false);book:SetLayer(book:IsShown());book:Refresh()
end
function M:BindBook(owner)
 book=owner
end
function M:Initialize()
 local events=CreateFrame("Frame")
 for _,event in ipairs({"TRAINER_SHOW","TRAINER_CLOSED","TRAINER_UPDATE","TRAINER_SERVICE_INFO_NAME_UPDATE",
  "SPELLS_CHANGED","LEARNED_SPELL_IN_SKILL_LINE","PLAYER_LEVEL_UP","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED"})do events:RegisterEvent(event)end
 events:SetScript("OnEvent",function(_,event)
  if event=="TRAINER_SHOW"then trainerOpen=true elseif event=="TRAINER_CLOSED"then trainerOpen=false end
  if scanning or queued then return end
  queued=true
  C_Timer.After(0,function()
   queued=false
   if trainerOpen then M:Capture()end
   M:Refresh()
  end)
 end)
end
