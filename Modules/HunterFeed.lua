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
local button,bar,mover,panel,editing
local dragging=false
local suppressClickUntil=0
local expires,duration=0,0
local function Enabled()return E:GetSetting("enabled") and E:GetSetting("hunterFeed")end
local function SettingsOpen()return E.settingsFrame and E.settingsFrame:IsShown()end
local function Happiness()
 local getter=C_PetInfo and C_PetInfo.GetPetHappiness or GetPetHappiness
 if not getter then return end
 local ok,value=pcall(getter)
 if ok and T.Number(value)then return value end
end
local function Diets()
 local kinds
 if C_PetInfo and C_PetInfo.GetPetFoodTypes then
  local ok,value=pcall(C_PetInfo.GetPetFoodTypes)
  if ok and T.Public(value)and type(value)=="table"then kinds=value end
 elseif GetPetFoodTypes then
  kinds={GetPetFoodTypes()}
 end
 local diets={}
 for _,kind in ipairs(kinds or{})do if T.Public(kind)and type(kind)=="string"then diets[kind]=true end end
 return diets
end
local function Position()
 local o=T.Options();o.feedPosition=o.feedPosition or {x=160,y=-150,size=40}
 return o.feedPosition
end
function M:ChooseFood()
 local diets=Diets()
 local o=T.Options();local candidates={}
 local petLevel=UnitLevel("pet")
 T.Bags(function(bag,slot,info)
  local f=foods[info.itemID]
   if not f then return end
   if C_PetInfo and C_PetInfo.CanPetEatItem then
    local ok,canEat=pcall(C_PetInfo.CanPetEatItem,info.itemID)
    if not ok or not T.Public(canEat)or canEat~=true then return end
   elseif not diets[f.kind]then return end
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
 mover:ClearAllPoints();mover:SetPoint("CENTER",UIParent,"CENTER",p.x,p.y);mover:SetSize(p.size,p.size)
 bar:ClearAllPoints();bar:SetPoint("TOP",button,"BOTTOM",0,-6);bar:SetSize(math.max(100,p.size*2.5),16)
 E:SaveSettings()
end
local function StopDrag()
 if not dragging then return end
 mover:StopMovingOrSizing()
 dragging=false
 local x,y=mover:GetCenter();local cx,cy=UIParent:GetCenter()
 if x and y and cx and cy then
  local ratio=mover:GetEffectiveScale()/UIParent:GetEffectiveScale()
  local p=Position();p.x=x*ratio-cx;p.y=y*ratio-cy
  E:SaveSettings()
 end
 suppressClickUntil=GetTime()+.2
 Layout()
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
 if not Enabled()or SettingsOpen()then StopDrag();editing=false end
 local food=Enabled() and self:ChooseFood()
 local spell=T.Spell(6991)
 -- Right-click only unlocks. The feeding action belongs to the locked left click.
 button:SetAttribute("type",nil)
 button:SetAttribute("type1","macro")
 button:SetAttribute("macrotext1", not editing and food and spell and T.Known(6991) and ("/cast [nocombat,pet] "..spell.."\n/use [nocombat,pet] "..food.bag.." "..food.slot) or nil)
 button.food=food
 button.icon:SetTexture(food and food.icon or "Interface\\Icons\\Ability_Hunter_BeastTraining")
 mover.icon:SetTexture(food and food.icon or "Interface\\Icons\\Ability_Hunter_BeastTraining")
 button.count:SetText(food and food.count or "")
 button:SetBackdropBorderColor(1,.63,.23,1)
 button.notice:SetText(food and "FEED PET" or "NO FOOD")
 local happiness=Happiness()
 local show=Enabled() and not editing and not SettingsOpen() and T.Known(6991)
  and T.Number(happiness) and happiness<3 and UnitExists("pet") and not UnitIsDead("pet")
 if RegisterStateDriver then RegisterStateDriver(button,"visibility",show and "[combat] hide; show" or "hide")else button:SetShown(show)end
 mover:SetShown(not not(Enabled()and editing))
 if editing or SettingsOpen()or not Enabled()then bar:Hide()end
 if panel then self:RefreshPanel(food)end
end
function M:BeginMove()
 if InCombatLockdown()then return end
 if not Enabled()then E:Print("Enable Pet Feeding in Hunter settings first.");return end
 if GameTooltip then GameTooltip:Hide()end
 if panel then panel:Hide()end
 if E.settingsFrame then E.settingsFrame:Hide()end
 editing=true
 Layout()
 self:Refresh()
end
local function Build()
 if button then return end
 button=T.Button(UIParent,"",40,40,true);button:SetClampedToScreen(true);button:SetFrameStrata("MEDIUM")
 button.icon=button:CreateTexture(nil,"ARTWORK");button.icon:SetPoint("TOPLEFT",3,-3);button.icon:SetPoint("BOTTOMRIGHT",-3,3);button.icon:SetTexCoord(.07,.93,.07,.93)
 button.count=T.Text(button,"",11);button.count:SetPoint("BOTTOMRIGHT",-3,3)
 local tag=button:CreateTexture(nil,"BACKGROUND");tag:SetSize(86,20);tag:SetPoint("BOTTOM",button,"TOP",0,3);tag:SetColorTexture(.08,.06,.035,.95)
 button.notice=T.Text(button,"FEED PET",10);button.notice:SetPoint("CENTER",tag,"CENTER");button.notice:SetTextColor(1,.73,.35)
 button:SetScript("OnEnter",function(self)
  GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Feed Pet")
  GameTooltip:AddLine(self.food and (T.Item(self.food.id)or "Food") or "No suitable food in bags",1,1,1)
  GameTooltip:AddLine("Left-click to feed. Right-click to unlock, then drag the icon or scroll to resize. Left-click again to lock.",.7,.7,.7,true);GameTooltip:Show()
 end)
 button:SetScript("OnLeave",function()GameTooltip:Hide()end)
 button:HookScript("PostClick",function(_,click,down)
  if click=="RightButton"and not down then M:BeginMove()end
 end)
 -- The positioning preview is independent of the secure feed button. Dragging,
 -- resizing and locking it cannot consume food or modify a protected frame in combat.
 mover=T.Button(UIParent,"",40,40)
 mover:SetFrameStrata("DIALOG");mover:SetMovable(true);mover:SetClampedToScreen(true);mover:EnableMouse(true)
 local r,g,b=T.Colour();mover:SetBackdropBorderColor(r,g,b,1)
 mover.icon=mover:CreateTexture(nil,"ARTWORK");mover.icon:SetPoint("TOPLEFT",3,-3);mover.icon:SetPoint("BOTTOMRIGHT",-3,3);mover.icon:SetTexCoord(.07,.93,.07,.93)
 local heading=T.Text(mover,"MOVE FEED PET",10);heading:SetPoint("BOTTOM",mover,"TOP",0,6);heading:SetTextColor(r,g,b)
 local hint=T.Text(mover,"Drag to move | Scroll to resize\nLeft-click to lock",11)
 hint:SetPoint("TOP",mover,"BOTTOM",0,-6)
 mover:RegisterForClicks("LeftButtonUp","RightButtonUp");mover:RegisterForDrag("LeftButton");mover:EnableMouseWheel(true)
 mover:SetScript("OnClick",function(_,click)
  if InCombatLockdown()or dragging or GetTime()<suppressClickUntil then return end
  if click=="LeftButton"then editing=false;M:Refresh()end
 end)
 mover:SetScript("OnDragStart",function()
  if editing and not InCombatLockdown()then dragging=true;mover:StartMoving()end
 end)
 mover:SetScript("OnDragStop",StopDrag)
 mover:SetScript("OnHide",StopDrag)
 mover:SetScript("OnMouseWheel",function(_,delta)
  if editing and not dragging and not InCombatLockdown()then Position().size=Position().size+delta*2;Layout()end
 end)
 mover:Hide()
 bar=CreateFrame("StatusBar",nil,UIParent,"BackdropTemplate");T.Skin(bar)
 bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");bar:SetStatusBarColor(.45,.7,.25)
 bar.text=T.Text(bar,"",11);bar.text:SetPoint("CENTER");bar:Hide()
 Layout()
end
function M:StatusLine(food)
 if not T.Known(6991)then return "Learn Feed Pet and summon a pet to begin."end
 if not UnitExists("pet")then return "Summon your pet to use the feeding button."end
 if UnitIsDead("pet")then return "Revive your pet before feeding it."end
 local happiness=Happiness()
 if not happiness then return "Waiting for the client to report pet happiness."end
 if happiness>=3 then return "Your pet is happy. The button appears when happiness drops."end
 if SettingsOpen()then return "Your pet needs feeding. Close settings to show the feeding button."end
 if food then return "Selected: "..(T.Item(food.id)or"Food").." ("..food.count..")"end
 return "No suitable food found. Check your pet's diet and food level."
end
function M:Attach(parent,anchor)
 parent=anchor:GetParent()
 if not panel then
  panel=T.SubPanel(parent,anchor)
  panel.items={}
  panel.items[1]=T.SubToggle(panel,"Allow non-vendor fish","feedFish",false,function()M:Refresh()end)
  panel.items[2]=T.SubToggle(panel,"Allow non-vendor meat","feedMeat",false,function()M:Refresh()end)
  panel.items[3]=T.SubToggle(panel,"Use lowest quantity first","feedLowest",true,function()M:Refresh()end)
  local move=T.SubButton(panel,"Move / resize feeding button")
  move:SetScript("OnClick",function()M:BeginMove()end)
  panel.items[4]=move
  T.SubLayout(panel,panel.items)
  self:RefreshPanel()
  return
 end
 if panel:GetParent()~=parent then panel:SetParent(parent)end
 panel:ClearAllPoints();panel:SetPoint("TOPLEFT",anchor,"BOTTOMLEFT",0,-6)
 panel:Show()
 self:RefreshPanel()
end
function M:HidePanel()
 if panel then panel:Hide()end
end
function M:RefreshPanel(food)
 if not panel then return end
 T.SubState(panel,not not Enabled(),"Enable Pet Feeding in the Hunter settings.")
 if Enabled()then panel.hint:SetText(self:StatusLine(food))end
end
function M:Open()
 if InCombatLockdown()then return end
 Build()
 if E.Classic and E.Classic.OpenOptions then E.Classic.OpenOptions()end
 C_Timer.After(.25,function()
  local f,a=M.settingsFrame,M.settingsAnchor
  if f and a and f:IsShown()then M:Attach(f,a)end
 end)
end
function M:Initialize()
 local _,class=UnitClass("player");if class~="HUNTER"then return end
 Build()
 local f=CreateFrame("Frame")
 for _,event in ipairs({"BAG_UPDATE_DELAYED","UNIT_PET","UNIT_HAPPINESS","UNIT_AURA","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","SPELLS_CHANGED","GET_ITEM_INFO_RECEIVED"})do f:RegisterEvent(event)end
 f:SetScript("OnEvent",function(_,event,unit)
  if event=="PLAYER_REGEN_DISABLED"then StopDrag();editing=false;expires=0;bar:Hide();mover:Hide();return end
  if event=="PLAYER_REGEN_ENABLED"then Layout()end
  if event=="UNIT_AURA" and unit~="pet"then return end
  if event=="UNIT_AURA" or event=="UNIT_PET" or event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_REGEN_ENABLED"then ReadFeedAura()end
  M:Refresh()
 end)
 local elapsed=0
 local arrangingWas
 f:SetScript("OnUpdate",function(_,dt)
  elapsed=elapsed+dt;if elapsed<.1 then return end;elapsed=0
  local arranging=not not SettingsOpen()
  if not InCombatLockdown() and arranging~=arrangingWas then arrangingWas=arranging;M:Refresh()end
  local left=expires-GetTime()
  if Enabled() and not editing and not SettingsOpen() and not InCombatLockdown() and left>0 and duration>0 then bar:SetMinMaxValues(0,duration);bar:SetValue(left);bar.text:SetText(string.format("Feed Pet  %.1fs",left));bar:Show()
  else bar:Hide()end
 end)
 self:Refresh()
end
