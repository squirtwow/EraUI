local _,E=...
local T=E.ClassTools
local M={};E:RegisterModule("HunterFeed",M)
-- Plain vendor foods only by default. Fish/meat from fishing, drops and cooking
-- are opt-in; stat-buff foods are deliberately not candidates.
local foods={}
local function Add(kind,vendor,ids)for _,id in ipairs(ids)do foods[id]={kind=kind,vendor=vendor}end end
Add("Meat",true,{117,2287,3770,3771,4599,8952})
Add("Fish",true,{787,4592,4593,4594,21552,8957})
Add("Bread",true,{4540,4541,4542,4544,4601,8950})
Add("Cheese",true,{2070,414,422,1707,3927,8932})
Add("Fruit",true,{4536,4537,4538,4539,4602,8953})
Add("Fungus",true,{4604,4605,4606,4607,4608,8948})
Add("Fish",false,{6291,6289,6308,6317,6361,6362,13754,13755,13756,13758,13759,13760,6887,8364})
Add("Meat",false,{2672,2673,2674,2675,3667,5465,5467,5469,5470,5471,1080,12202,12203,12204,12205,12208,12037})
local button,bar,handle,window,status,editing
local expires,duration=0,0
local function Enabled()return E:GetSetting("enabled") and E:GetSetting("hunterFeed")end
local function Position()
 local o=T.Options();o.feedPosition=o.feedPosition or {x=160,y=-150,size=40}
 return o.feedPosition
end
function M:ChooseFood()
 if not GetPetFoodTypes then return end
 local diets={};for _,kind in ipairs({GetPetFoodTypes()})do if T.Public(kind)then diets[kind]=true end end
 local o=T.Options();local candidates={}
 local petLevel=UnitLevel("pet")
 T.Bags(function(bag,slot,info)
  local f=foods[info.itemID]
  if not f or not diets[f.kind] then return end
  if not f.vendor and not (f.kind=="Fish" and o.feedFish or f.kind=="Meat" and o.feedMeat)then return end
  local _,_,_,level= T.Item(info.itemID)
  -- Food 30+ item levels below the pet provides no happiness.
  if not T.Number(level) or not T.Number(petLevel) or level<=petLevel-30 then return end
  candidates[#candidates+1]={bag=bag,slot=slot,id=info.itemID,count=T.Count(info.itemID),stack=info.stackCount,icon=info.iconFileID}
 end)
 table.sort(candidates,function(a,b)
  if a.count~=b.count then if o.feedLowest==false then return a.count>b.count else return a.count<b.count end end
  if a.id~=b.id then return a.id<b.id end
  if a.stack~=b.stack then return a.stack<b.stack end
  return a.bag==b.bag and a.slot<b.slot or a.bag<b.bag
 end)
 return candidates[1]
end
local function Layout()
 if not button or InCombatLockdown()then return end
 local p=Position();p.size=math.max(24,math.min(80,tonumber(p.size)or 40))
 button:ClearAllPoints();button:SetPoint("CENTER",UIParent,"CENTER",p.x,p.y);button:SetSize(p.size,p.size)
 bar:ClearAllPoints();bar:SetPoint("TOP",button,"BOTTOM",0,-6);bar:SetSize(math.max(100,p.size*2.5),16)
end
local function ReadFeedAura()
 -- Never inspect restricted aura data in combat.
 if InCombatLockdown()then expires=0;return end
 expires,duration=0,0
 if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return end
 for i=1,40 do
  local ok,aura=pcall(C_UnitAuras.GetAuraDataByIndex,"pet",i,"HELPFUL")
  if not ok or not aura then break end
  if T.Public(aura.spellId) and aura.spellId==1539 and T.Number(aura.expirationTime) and T.Number(aura.duration)then
   expires,duration=aura.expirationTime,aura.duration;break
  end
 end
end
function M:Refresh()
 if not button or InCombatLockdown()then return end
 local arranging=editing or (E.settingsFrame and E.settingsFrame:IsShown()) or (window and window:IsShown())
 button:SetFrameStrata(arranging and "FULLSCREEN_DIALOG" or "MEDIUM")
 button:SetFrameLevel(100)
 handle:SetFrameStrata(arranging and "FULLSCREEN_DIALOG" or "MEDIUM");handle:SetFrameLevel(110)
 bar:SetFrameStrata(arranging and "FULLSCREEN_DIALOG" or "MEDIUM");bar:SetFrameLevel(100)
 local food=Enabled() and self:ChooseFood()
 local spell=T.Spell(6991)
 button:SetAttribute("type","macro")
 button:SetAttribute("macrotext", food and spell and T.Known(6991) and ("/cast [nocombat,pet] "..spell.."\n/use [nocombat,pet] "..food.bag.." "..food.slot) or nil)
 button.food=food
 button.icon:SetTexture(food and food.icon or "Interface\\Icons\\Ability_Hunter_BeastTraining")
 button.count:SetText(food and food.count or "")
 button:SetBackdropBorderColor(1,.63,.23,1)
 button.notice:SetText(food and "FEED PET" or "NO FOOD")
 local happiness=GetPetHappiness and GetPetHappiness()
 local show=Enabled() and (editing or (T.Number(happiness) and happiness<3 and UnitExists("pet") and not UnitIsDead("pet")))
 if RegisterStateDriver then RegisterStateDriver(button,"visibility",show and "[combat] hide; show" or "hide")else button:SetShown(show)end
 handle:SetShown(Enabled() and (show or editing))
 if status then status:SetText(not Enabled() and "Enable Pet Feeding in the Hunter settings." or not T.Known(6991) and "Learn Feed Pet and summon a pet to begin." or food and ("Selected: "..(T.Item(food.id)or "Food").." ("..food.count..")") or "No suitable food found. Check your pet's diet and food level.")end
 if not Enabled()then bar:Hide()end
end
local function Build()
 if button then return end
 button=T.Button(UIParent,"",40,40,true);button:SetMovable(true);button:SetClampedToScreen(true)
 button.icon=button:CreateTexture(nil,"ARTWORK");button.icon:SetPoint("TOPLEFT",3,-3);button.icon:SetPoint("BOTTOMRIGHT",-3,3);button.icon:SetTexCoord(.07,.93,.07,.93)
 button.count=T.Text(button,"",11);button.count:SetPoint("BOTTOMRIGHT",-3,3)
 local tag=button:CreateTexture(nil,"BACKGROUND");tag:SetSize(86,20);tag:SetPoint("BOTTOM",button,"TOP",0,3);tag:SetColorTexture(.08,.06,.035,.95)
 button.notice=T.Text(button,"FEED PET",10);button.notice:SetPoint("CENTER",tag,"CENTER");button.notice:SetTextColor(1,.73,.35)
 button:SetScript("OnEnter",function(self)
  GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Feed Pet")
  GameTooltip:AddLine(self.food and (T.Item(self.food.id)or "Food") or "No suitable food in bags",1,1,1)
  GameTooltip:AddLine("Right-click + to unlock. Drag + to move; scroll + to resize. Left-click + to lock.",.7,.7,.7,true);GameTooltip:Show()
 end)
 button:SetScript("OnLeave",function()GameTooltip:Hide()end)
 handle=T.Button(UIParent,"+",20,20);handle:SetPoint("TOPLEFT",button,"TOPRIGHT",4,0)
 handle:RegisterForClicks("LeftButtonUp","RightButtonUp");handle:RegisterForDrag("LeftButton");handle:EnableMouseWheel(true)
 handle:SetScript("OnClick",function(_,click)
  if InCombatLockdown()then return end
  editing=click=="RightButton";handle.label:SetText(editing and "L" or "+");M:Refresh()
 end)
 handle:SetScript("OnDragStart",function()if editing and not InCombatLockdown()then button:StartMoving()end end)
 handle:SetScript("OnDragStop",function()
  if InCombatLockdown()then return end
  button:StopMovingOrSizing();local x,y=button:GetCenter();local cx,cy=UIParent:GetCenter();local p=Position();p.x=x-cx;p.y=y-cy;Layout()
 end)
 handle:SetScript("OnMouseWheel",function(_,delta)if editing and not InCombatLockdown()then Position().size=Position().size+delta*2;Layout()end end)
 bar=CreateFrame("StatusBar",nil,UIParent,"BackdropTemplate");T.Skin(bar)
 bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");bar:SetStatusBarColor(.45,.7,.25)
 bar.text=T.Text(bar,"",11);bar.text:SetPoint("CENTER");bar:Hide()
 Layout()
end
function M:Open()
 Build()
 if not window then
  window=T.Window("EraUIHunterTools","Hunter · Pet Feeding",420,320)
  T.Toggle(window,"Allow non-vendor fish","feedFish",-58,false,function()M:Refresh()end)
  T.Toggle(window,"Allow non-vendor meat","feedMeat",-96,false,function()M:Refresh()end)
  T.Toggle(window,"Use lowest quantity first","feedLowest",-134,true,function()M:Refresh()end)
  local move=T.Button(window,"Move / resize feeding button",380,30);move:SetPoint("TOPLEFT",18,-178)
  move:SetScript("OnClick",function()
   if InCombatLockdown()then return end
   if not Enabled()then E:Print("Enable Pet Feeding in Hunter settings first.");return end
   editing=true;window:Hide();if E.settingsFrame then E.settingsFrame:Hide()end;M:Refresh()
  end)
  status=T.Text(window,"",12);status:SetPoint("TOPLEFT",18,-224);status:SetWidth(380)
 end
 window:Show();self:Refresh()
end
function M:Initialize()
 local _,class=UnitClass("player");if class~="HUNTER"then return end
 Build()
 local f=CreateFrame("Frame")
 for _,event in ipairs({"BAG_UPDATE_DELAYED","UNIT_PET","UNIT_HAPPINESS","UNIT_AURA","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","SPELLS_CHANGED","GET_ITEM_INFO_RECEIVED"})do f:RegisterEvent(event)end
 f:SetScript("OnEvent",function(_,event,unit)
  if event=="PLAYER_REGEN_DISABLED"then expires=0;bar:Hide();handle:Hide();return end
  if event=="UNIT_AURA" and unit~="pet"then return end
  if event=="UNIT_AURA" or event=="UNIT_PET" or event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_REGEN_ENABLED"then ReadFeedAura()end
  M:Refresh()
 end)
 local elapsed=0
 local arrangingWas
 f:SetScript("OnUpdate",function(_,dt)
  elapsed=elapsed+dt;if elapsed<.1 then return end;elapsed=0
  local arranging=not not (editing or (E.settingsFrame and E.settingsFrame:IsShown()) or (window and window:IsShown()))
  if not InCombatLockdown() and arranging~=arrangingWas then arrangingWas=arranging;M:Refresh()end
  local left=expires-GetTime()
  if Enabled() and left>0 and duration>0 then bar:SetMinMaxValues(0,duration);bar:SetValue(left);bar.text:SetText(string.format("Feed Pet  %.1fs",left));bar:Show()
  else bar:Hide()end
 end)
 self:Refresh()
end
