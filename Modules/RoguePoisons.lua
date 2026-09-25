local _,E=...
local T=E.ClassTools
local M={};E:RegisterModule("RoguePoisons",M)
local groups={
 {name="Instant Poison",spells={8681,8687,8691,11341,11342,11343},items={6947,6949,6950,8926,8927,8928},icon="Ability_Poisons"},
 {name="Deadly Poison",spells={2835,2837,11357,11358,25347},items={2892,2893,8984,8985,20844},icon="Ability_Rogue_DualWeild"},
 {name="Crippling Poison",spells={3420,3421},items={3775,3776},icon="Ability_PoisonSting"},
 {name="Mind-numbing Poison",spells={5763,8694,11400},items={5237,6951,9186},icon="Spell_Nature_NullifyDisease"},
 {name="Wound Poison",spells={13220,13228,13229,13230},items={10918,10920,10921,10922},icon="Ability_PoisonSting"},
}
local window,status,rows,buy,craft
local vendorStrip
local plans={};local purchase,crafting;local generation=0
local function Enabled()return E:GetSetting("enabled") and E:GetSetting("roguePoisons")end
local function ItemID(link)return type(link)=="string" and tonumber(link:match("item:(%d+)"))end
local function MerchantOpen()return MerchantFrame and MerchantFrame:IsShown()end
local function Recipe(id)
 local api=C_TradeSkillUI
 if not api or not api.GetRecipeInfo or not api.GetRecipeSchematic then return end
 local ok,info=pcall(api.GetRecipeInfo,id)
 if not ok or not info or info.learned~=true then return end
 local success,s=pcall(api.GetRecipeSchematic,id,false)
 if not success or not s or not s.reagentSlotSchematics then return end
 local needs={}
 for _,slot in ipairs(s.reagentSlotSchematics)do
  local reagent=slot.reagents and slot.reagents[1]
  if reagent and reagent.itemID and (slot.quantityRequired or 0)>0 then needs[#needs+1]={id=reagent.itemID,count=slot.quantityRequired}end
 end
 if #needs==0 then return end
 return {id=id,name=info.name,icon=info.icon,needs=needs,output=s.quantityMin or 1}
end
function M:Recipes()
 local result={}
 for i,group in ipairs(groups)do
  for rank=#group.spells,1,-1 do
   local r=Recipe(group.spells[rank])
   if r then r.rank=rank;r.item=group.items[rank];result[i]=r;break end
  end
 end
 return result
end
local function Inventory(group)
 local count=0;for _,id in ipairs(group.items)do count=count+T.Count(id)end;return count
end
local function MerchantItems()
 local result={}
 if not MerchantOpen()then return result end
 for i=1,GetMerchantNumItems()do
  local id=ItemID(GetMerchantItemLink(i))
  local name,_,price,bundle,available,usable,extended=GetMerchantItemInfo(i)
  if id and name and price and bundle and bundle>0 and not extended then
   result[id]={index=i,id=id,name=name,price=price,bundle=bundle,available=available,max=GetMerchantItemMaxStack and GetMerchantItemMaxStack(i)or bundle}
  end
 end
 return result
end
function M:MaterialPlan(selected,recipes)
 local needs={};local queue={}
 for i,group in ipairs(groups)do
  local quantity=selected[i]or 0
  if quantity>0 then
   local recipe=recipes[i];if not recipe then return nil,"Open your Poison book to load learned recipes."end
   local casts=math.ceil(quantity/math.max(1,recipe.output))
   queue[#queue+1]={recipe=recipe,casts=casts,quantity=quantity,index=i}
   for _,r in ipairs(recipe.needs)do needs[r.id]=(needs[r.id]or 0)+r.count*casts end
  end
 end
 -- Flash Powder is a purchased consumable, not a crafted poison.
 if (selected.powder or 0)>0 then needs[5140]=(needs[5140]or 0)+selected.powder end
 return needs,queue
end
local function Selection()
 local selected={powder=tonumber(T.Options().poisonPowder)or 0}
 for i=1,#groups do selected[i]=tonumber(T.Options()["poisonQuantity"..i])or 0 end
 return selected
end
function M:PurchasePlan(selected,recipes)
 local needs,queue=self:MaterialPlan(selected,recipes);if not needs then return nil,queue end
 local merchant=MerchantItems();local list={};local cost=0
 for id,quantity in pairs(needs)do
  local missing=math.max(0,quantity-T.Count(id))
  if missing>0 then
   local item=merchant[id];if not item then return nil,"Vendor does not sell "..(T.Item(id)or ("item "..id)).."."end
   local units=math.ceil(missing/item.bundle)*item.bundle
   if item.available and item.available>=0 and item.available<units then return nil,"Vendor has insufficient "..item.name.."."end
   local chunk=math.max(item.bundle,math.floor((item.max or item.bundle)/item.bundle)*item.bundle)
   list[#list+1]={id=id,index=item.index,units=units,chunk=chunk,goal=T.Count(id)+units,bundle=item.bundle,price=item.price}
   cost=cost+units/item.bundle*item.price
  end
 end
 table.sort(list,function(a,b)return a.index<b.index end)
 return {list=list,cost=cost,queue=queue,needs=needs}
end
local function Tell(message)if status then status:SetText(message)else E:Print(message)end end
local function ResetQuantities()
 for i=1,#groups do T.Options()["poisonQuantity"..i]=0;if rows and rows[i]then rows[i].slider:SetValue(0)end end
 T.Options().poisonPowder=0;if rows and rows.powder then rows.powder.slider:SetValue(0)end
end
function M:Buy()
 if not Enabled() or InCombatLockdown() or not MerchantOpen() or purchase or crafting then return end
 local selection=Selection();local plan,err=self:PurchasePlan(selection,self:Recipes())
 if not plan then Tell(err);return end
 if plan.cost>GetMoney()then Tell("Not enough money for all selected materials.");return end
 plans=plan.queue
 if #plan.list==0 then ResetQuantities();Tell("Materials already in bags. Click Craft to begin.");return end
 generation=generation+1;local current=generation
 purchase={plan=plan,index=1};local pending,deadline
 local function Stop(message)purchase=nil;Tell(message)end
 local function Step()
  if current~=generation or not purchase then return end
  if not Enabled() or InCombatLockdown() or not MerchantOpen()then Stop("Purchase stopped. Quantities kept; click Buy to resume.");return end
  if pending then
   if T.Count(pending.id)<pending.expected then
    if GetTime()>deadline then Stop("Purchase incomplete (check bag space). Quantities kept.");return end
    C_Timer.After(.2,Step);return
   end
   pending=nil
  end
  local item=plan.list[purchase.index]
  if not item then purchase=nil;ResetQuantities();Tell("Materials purchased. Click Craft for your selected poisons.");return end
  local missing=item.goal-T.Count(item.id)
  if missing<=0 then purchase.index=purchase.index+1;C_Timer.After(.1,Step);return end
  local currentItem=MerchantItems()[item.id]
  if not currentItem or currentItem.index~=item.index or currentItem.price~=item.price or currentItem.bundle~=item.bundle then Stop("Vendor inventory changed; click Buy to recalculate.");return end
  local amount=math.min(item.chunk,math.ceil(missing/item.bundle)*item.bundle)
  if amount/item.bundle*item.price>GetMoney()then Stop("Not enough money to finish purchase.");return end
  pending={id=item.id,expected=T.Count(item.id)+amount};deadline=GetTime()+4
  BuyMerchantItem(item.index,amount);C_Timer.After(.2,Step)
 end
 Tell("Buying selected materials...");Step()
end
function M:Craft()
 if not Enabled() or InCombatLockdown() or crafting or purchase then return end
 local selected=Selection();local chosen=false
 for i=1,#groups do if selected[i]>0 then chosen=true end end
 local queue=plans
 if chosen then local needs,q=self:MaterialPlan(selected,self:Recipes());if not needs then Tell(q);return end;queue=q end
 if not queue or #queue==0 then Tell("Choose a poison quantity first.");return end
 local total={}
 for _,entry in ipairs(queue)do for _,r in ipairs(entry.recipe.needs)do total[r.id]=(total[r.id]or 0)+r.count*entry.casts end end
 for id,count in pairs(total)do if T.Count(id)<count then Tell("Missing materials: "..(T.Item(id)or id)..". Buy them first.");return end end
 if not C_TradeSkillUI or not C_TradeSkillUI.CraftRecipe then Tell("Crafting API unavailable on this client.");return end
 generation=generation+1;local current=generation
 crafting={queue=queue,index=1};plans={}
 local function Next()
  if current~=generation or not crafting then return end
  if not Enabled() or InCombatLockdown()then crafting=nil;Tell("Crafting stopped.");return end
  local entry=queue[crafting.index]
  if not entry then crafting=nil;ResetQuantities();Tell("Selected poisons crafted.");return end
  local recipe=Recipe(entry.recipe.id)
  if not recipe then crafting=nil;Tell("Open the Poison book, then click Craft again.");plans=queue;return end
  crafting.item=entry.recipe.item;crafting.goal=T.Count(crafting.item)+entry.casts*math.max(1,recipe.output)
  crafting.deadline=GetTime()+math.max(15,entry.casts*5+10)
  local ok=pcall(C_TradeSkillUI.CraftRecipe,recipe.id,entry.casts)
  if not ok then crafting=nil;Tell("Open the Poison book and click Craft again.");plans=queue;return end
  Tell("Crafting "..recipe.name.."...")
  local function Check()
   if current~=generation or not crafting then return end
   if not Enabled() or InCombatLockdown() then crafting=nil;Tell("Crafting stopped.");return end
   if T.Count(crafting.item)>=crafting.goal then crafting.index=crafting.index+1;C_Timer.After(.3,Next)
   elseif GetTime()>crafting.deadline then crafting=nil;Tell("Crafting interrupted or unavailable. Select the remaining quantities to retry.")
   else C_Timer.After(.3,Check)end
  end
  C_Timer.After(.3,Check)
 end
 Next()
end
-- Non-secure vendor shortcuts: purchases and crafting still require the
-- explicit Buy/Craft controls. Parenting keeps the strip with the merchant.
function M:RefreshVendor()
 local vendor=MerchantItems()
 local relevant=vendor[5140]or vendor[2928]or vendor[2930]or vendor[8923]or vendor[8924]
 if not Enabled() or not MerchantOpen() or not relevant then
  if vendorStrip then vendorStrip:Hide()end
  return
 end
 if InCombatLockdown()then return end
 if not vendorStrip then
  vendorStrip=CreateFrame("Frame","EraUIRogueVendorStrip",MerchantFrame)
  vendorStrip:SetSize(38,250)
  vendorStrip:SetPoint("TOPLEFT",MerchantFrame,"TOPRIGHT",6,-70)
  vendorStrip.buttons={}
  for i=1,#groups+1 do
   local index=i
   local button=T.Button(vendorStrip,"",38,38)
   button.icon=button:CreateTexture(nil,"ARTWORK")
   button.icon:SetPoint("TOPLEFT",2,-2);button.icon:SetPoint("BOTTOMRIGHT",-2,2)
   button.count=T.Text(button,"0",12);button.count:SetPoint("BOTTOMRIGHT",-3,3)
   button.count:SetDrawLayer("OVERLAY",1)
   button:RegisterForClicks("LeftButtonUp")
   button:SetScript("OnEnter",function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
    GameTooltip:SetText(self.title or "Poison Supplies",1,1,1)
    GameTooltip:AddLine("In bags: "..self.total,1,1,1)
    GameTooltip:AddLine("Click to set quantities, buy materials and craft.",.8,.8,.8,true)
    GameTooltip:Show()
   end)
   button:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide()end end)
   button:SetScript("OnClick",function()
    if GameTooltip then GameTooltip:Hide()end
    M:Open()
    if status then status:SetText(index<=#groups and ("Choose the quantity for "..groups[index].name..", then Buy or Craft.")or "Set the total Flash Powder you want in your bags, then click Buy.")end
   end)
   vendorStrip.buttons[i]=button
  end
 end
 local recipes=self:Recipes();local visible=0
 for i,button in ipairs(vendorStrip.buttons)do
  local group=groups[i];local recipe=recipes[i];local rank
  if group then
   for n=#group.spells,1,-1 do if T.Known(group.spells[n])then rank=n;break end end
   rank=recipe and recipe.rank or rank
  end
  local show=group and rank~=nil or not group and vendor[5140]~=nil
  button:SetShown(show)
  if show then
   button:ClearAllPoints();button:SetPoint("TOPLEFT",0,-visible*41);visible=visible+1
   local total=group and Inventory(group)or T.Count(5140)
   if button.previous and total>button.previous then button.greenUntil=GetTime()+5 end
   button.previous=total;button.total=total;button.count:SetText(total)
   local green=button.greenUntil and button.greenUntil>GetTime()
   button.count:SetTextColor(green and .25 or 1,1,green and .35 or 1)
   button.title=group and (group.name.." · rank "..rank)or "Flash Powder"
   local icon=recipe and recipe.icon
   if group and not icon then local name;name,icon=T.Spell(group.spells[rank])end
   button.icon:SetTexture(icon or ("Interface\\Icons\\"..(group and group.icon or "INV_Misc_Ammo_Gunpowder_03")))
  end
 end
 vendorStrip:SetHeight(math.max(1,visible*41));vendorStrip:SetShown(visible>0)
end
function M:Refresh()
 self:RefreshVendor()
 if not window then return end
 local recipes=self:Recipes()
 local visible=0
 for i,group in ipairs(groups)do
  local row=rows[i];local r=recipes[i];local count=Inventory(group)
  for _,part in ipairs({row.icon,row.title,row.count,row.slider,row.amount})do part:SetShown(r~=nil)end
  if r then row.place(visible+1);visible=visible+1 end
  row.title:SetText(r and ((r.name or group.name).." · rank "..r.rank)or (group.name.." · not learned / open book"))
  row.icon:SetTexture(r and r.icon or ("Interface\\Icons\\"..group.icon))
  if row.previous and count>row.previous then row.greenUntil=GetTime()+5 end
  row.previous=count;row.count:SetText(count);local green=row.greenUntil and row.greenUntil>GetTime()
  row.count:SetTextColor(green and .25 or 1,1,green and .35 or 1)
  row.slider:SetEnabled(r~=nil and not purchase and not crafting)
 end
 rows.powder.place(visible+1)
 if not InCombatLockdown()then window:SetHeight(255+visible*62)end
 rows.powder.count:SetText(T.Count(5140))
 if not purchase and not crafting then
  if not Enabled()then Tell("Enable Poison Supplies in Rogue settings.")
  elseif visible==0 then Tell("Open your Poison book to load your learned ranks. Flash Powder can still be bought here.")
  elseif MerchantOpen()then
   local plan,err=self:PurchasePlan(Selection(),recipes)
   Tell(plan and ("Materials: "..(GetCoinTextureString and GetCoinTextureString(plan.cost)or plan.cost.." copper").." · existing bag materials deducted")or err)
  else Tell("Set quantities, then visit a poison vendor to buy materials.")end
 end
 buy:SetEnabled(Enabled() and MerchantOpen() and not purchase and not crafting)
 craft:SetEnabled(Enabled() and not purchase and not crafting)
end
function M:Open()
 if InCombatLockdown()then return end
 if not window then
  window=T.Window("EraUIRogueTools","Rogue · Poison Supplies",490,565);rows={}
  local book=T.Button(window,"Open Poison Book",160,26,true);book:SetPoint("TOPLEFT",18,-53)
  book:SetAttribute("type","spell");book:SetAttribute("spell",2842)
  local note=T.Text(window,"Craft quantities · current rank",12);note:SetPoint("TOPLEFT",192,-60)
  local function Row(index,name,key,icon)
   local y=-94-(index-1)*62
   local r={};r.icon=window:CreateTexture(nil,"ARTWORK");r.icon:SetSize(36,36);r.icon:SetPoint("TOPLEFT",18,y);r.icon:SetTexture(icon)
   r.count=T.Text(window,"0",12);r.count:SetPoint("TOPLEFT",60,y-22)
   r.title=T.Text(window,name,12);r.title:SetPoint("TOPLEFT",64,y);r.title:SetWidth(395)
   r.slider=CreateFrame("Slider",nil,window,"BackdropTemplate");r.slider:SetSize(265,12);r.slider:SetPoint("TOPLEFT",110,y-27);T.Skin(r.slider)
   r.slider:SetOrientation("HORIZONTAL");r.slider:SetMinMaxValues(0,100);r.slider:SetValueStep(1);r.slider:SetObeyStepOnDrag(true)
   r.slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8");r.slider:GetThumbTexture():SetSize(10,18);r.slider:GetThumbTexture():SetVertexColor(T.Colour())
   r.amount=T.Text(window,"0",13);r.amount:SetPoint("TOPLEFT",390,y-23)
   r.place=function(position)
    local top=-94-(position-1)*62
    r.icon:ClearAllPoints();r.icon:SetPoint("TOPLEFT",18,top)
    r.title:ClearAllPoints();r.title:SetPoint("TOPLEFT",64,top)
    r.count:ClearAllPoints();r.count:SetPoint("TOPLEFT",60,top-22)
    r.slider:ClearAllPoints();r.slider:SetPoint("TOPLEFT",110,top-27)
    r.amount:ClearAllPoints();r.amount:SetPoint("TOPLEFT",390,top-23)
   end
   r.slider:SetScript("OnValueChanged",function(_,value)
    local n=math.floor(value+.5);T.Options()[key]=n;r.amount:SetText(n)
    if rows.powder then M:Refresh()end
   end)
   r.slider:SetValue(tonumber(T.Options()[key])or 0)
   return r
  end
  for i,g in ipairs(groups)do rows[i]=Row(i,g.name,"poisonQuantity"..i,"Interface\\Icons\\"..g.icon)end
  rows.powder=Row(6,"Flash Powder · desired amount in bags","poisonPowder","Interface\\Icons\\INV_Misc_Ammo_Gunpowder_03")
  buy=T.Button(window,"Buy",135,30);buy:SetPoint("BOTTOMLEFT",18,49);buy:SetScript("OnClick",function()M:Buy()end)
  craft=T.Button(window,"Craft",135,30);craft:SetPoint("LEFT",buy,"RIGHT",12,0);craft:SetScript("OnClick",function()M:Craft()end)
  local stop=T.Button(window,"Stop",135,30);stop:SetPoint("LEFT",craft,"RIGHT",12,0)
  stop:SetScript("OnClick",function()
   generation=generation+1;purchase=nil;crafting=nil;plans={}
   if C_TradeSkillUI and C_TradeSkillUI.StopRecipeRepeat then C_TradeSkillUI.StopRecipeRepeat()end
   Tell("Stopped. Any completed purchases or crafts are kept.")
  end)
  status=T.Text(window,"",12);status:SetPoint("BOTTOMLEFT",18,12);status:SetWidth(454);status:SetHeight(30)
 end
 if MerchantOpen()then window:ClearAllPoints();window:SetPoint("TOPLEFT",MerchantFrame,"TOPRIGHT",50,0)end
 window:Show();self:Refresh()
end
function M:Initialize()
 local _,class=UnitClass("player");if class~="ROGUE"then return end
 local f=CreateFrame("Frame")
 for _,event in ipairs({"MERCHANT_SHOW","MERCHANT_UPDATE","MERCHANT_CLOSED","BAG_UPDATE_DELAYED","TRADE_SKILL_SHOW","TRADE_SKILL_LIST_UPDATE","TRADE_SKILL_UPDATE","SPELLS_CHANGED","PLAYER_REGEN_ENABLED"})do f:RegisterEvent(event)end
 f:SetScript("OnEvent",function(_,event)
  if event=="MERCHANT_CLOSED" then
   if vendorStrip then vendorStrip:Hide()end
   if purchase then generation=generation+1;purchase=nil end
   if window and not InCombatLockdown()then window:Hide()end
   return
  end
  M:Refresh()
 end)
 local elapsed=0
 f:SetScript("OnUpdate",function(_,dt)elapsed=elapsed+dt;if elapsed>1 then elapsed=0;if MerchantOpen()or window and window:IsShown()then M:Refresh()end end end)
end
