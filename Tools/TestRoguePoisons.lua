-- Run from the addon root. Poison Supplies (Modules/RoguePoisons.lua) must
-- start on a client that lacks some of the events it listens for: Forever has
-- no TRADE_SKILL_UPDATE, and the game refuses to register an event it doesn't
-- know. Each event is registered on its own, so a missing one is skipped and
-- the module still starts: the startup loop (Core/Init.lua, PLAYER_LOGIN)
-- runs each Initialize in a pcall and says "could not initialise" when it fails.
-- It must also read a vendor's items on Forever's new patch, which removed
-- GetMerchantItemInfo (talking to a vendor errored at RoguePoisons.lua:50):
-- the game's own vendor window reads C_MerchantFrame.GetItemInfo now.
local checks=0
local function equal(got,want,label)
 checks=checks+1;assert(got==want,label..": expected "..tostring(want)..", got "..tostring(got))
end
-- Forever 1.60.1.70170's own event list has these; TRADE_SKILL_UPDATE is not one.
local KNOWN={MERCHANT_SHOW=true,MERCHANT_UPDATE=true,MERCHANT_CLOSED=true,BAG_UPDATE_DELAYED=true,
 TRADE_SKILL_SHOW=true,TRADE_SKILL_LIST_UPDATE=true,SPELLS_CHANGED=true,PLAYER_REGEN_ENABLED=true}
local known,frames,class,refreshed,named,printed,bought
-- Only the widget methods the module uses: anything else is a nil call, as in game.
local methods={}
local function nop()end
for _,k in ipairs({"SetSize","SetPoint","ClearAllPoints","SetHeight","SetWidth","SetBackdrop","SetBackdropColor",
 "SetBackdropBorderColor","SetFont","SetJustifyH","SetShadowColor","SetShadowOffset","SetDrawLayer","SetTextColor",
 "SetTexture","RegisterForClicks",
 -- The Poison Supplies window's frame, slider and buttons.
 "SetFrameStrata","SetMovable","SetClampedToScreen","EnableMouse","RegisterForDrag","SetAttribute",
 "SetOrientation","SetMinMaxValues","SetValueStep","SetObeyStepOnDrag","SetThumbTexture","SetVertexColor",
 "SetEnabled"})do methods[k]=nop end
function methods:SetValue(v)self.value=v end
-- As the game does: an unknown event is an error, not a no-op.
function methods:RegisterEvent(event)
 if not known[event]then error('Attempt to register unknown event "'..event..'"')end
 self.events[event]=true
end
function methods:SetScript(name,fn)self.scripts[name]=fn end
function methods:Show()self.shown=true end
function methods:Hide()self.shown=false end
function methods:SetShown(v)self.shown=v and true or false end
function methods:IsShown()return self.shown end
function methods:SetText(t)self.text=t end
local widgets
local function Widget(kind,name)
 local w=setmetatable({kind=kind,name=name,shown=true,events={},scripts={}},{__index=methods})
 if name then named[name]=w end
 widgets[#widgets+1]=w
 return w
end
function methods:CreateTexture()return Widget("Texture")end
function methods:CreateFontString()return Widget("FontString")end
function methods:GetThumbTexture()self.thumb=self.thumb or Widget("Texture");return self.thumb end
local bags,spells
local NAMES={[5140]="Flash Powder",[2928]="Dust of Decay",[8924]="Dust of Deterioration",[159]="Refreshing Spring Water"}
local function Session(c,events)
 class,known,frames,refreshed,named,printed,bought=c,events,{},0,{},{},{}
 bags,spells,widgets={},{},{}
 UnitClass=function()return "Class",class end
 CreateFrame=function(kind,name)local f=Widget(kind,name);frames[#frames+1]=f;return f end
 InCombatLockdown=function()return false end
 GetTime=function()return 100 end
 GetMoney=function()return 10000 end
 GameFontHighlight={GetFont=function()return "Fonts\\FRIZQT__.TTF",12 end}
 -- As on Forever: IsPlayerSpell only exists in the game's deprecated copies
 -- (loadDeprecationFallbacks), so known recipes come from C_SpellBook.
 IsPlayerSpell=nil;IsSpellKnown=nil
 C_SpellBook={IsSpellKnown=function(id)return spells[id]==true end}
 C_Item={GetItemCount=function(id)return bags[id]or 0 end,GetItemInfo=function(id)return NAMES[id]end}
 C_Timer={After=nop}
 BuyMerchantItem=function(index,amount)bought[#bought+1]={index=index,amount=amount}end
 EraUIClassicCharDB={}
 MerchantFrame=nil;C_MerchantFrame=nil;GetMerchantItemInfo=nil
 C_CurrencyInfo=nil;GetCoinTextureString=nil;C_TradeSkillUI=nil;UIParent=nil
 GetMerchantNumItems=nil;GetMerchantItemLink=nil;GetMerchantItemMaxStack=nil
 local E={modules={}}
 function E:RegisterModule(name,m)self.modules[name]=m end
 function E:GetSetting()return true end
 function E:SaveSettings()end
 function E:Print(message)printed[#printed+1]=message end
 assert(loadfile("Modules/ClassTools.lua"))("EraUI",E)
 assert(loadfile("Modules/RoguePoisons.lua"))("EraUI",E)
 local M=E.modules.RoguePoisons
 local refresh=M.Refresh
 M.Refresh=function(self,...)refreshed=refreshed+1;return refresh(self,...)end
 return E,M
end

local E,M=Session("ROGUE",KNOWN)
local ok,err=pcall(M.Initialize,M)
equal(ok,true,"Poison Supplies starts on Forever without TRADE_SKILL_UPDATE ("..tostring(err)..")")
local f=frames[#frames]
equal(f~=nil and f.events.TRADE_SKILL_UPDATE,nil,"the unknown event is skipped")
local count=0
for event in pairs(KNOWN)do
 equal(f.events[event],true,"it still listens for "..event)
 count=count+1
end
equal(count,8,"all eight events Forever has")
equal(type(f.scripts.OnEvent),"function","its event handler is set after the skipped event")
equal(type(f.scripts.OnUpdate),"function","and its refresh clock")
f.scripts.OnEvent(f,"BAG_UPDATE_DELAYED")
equal(refreshed,1,"an event it listens for refreshes it")
f.scripts.OnEvent(f,"MERCHANT_CLOSED")
equal(refreshed,1,"closing a merchant with nothing open needs no refresh")

-- A client that knows TRADE_SKILL_UPDATE gets it too.
local all={TRADE_SKILL_UPDATE=true};for k in pairs(KNOWN)do all[k]=true end
E,M=Session("ROGUE",all)
ok=pcall(M.Initialize,M)
equal(ok and frames[#frames].events.TRADE_SKILL_UPDATE,true,"where the game has it, it is used")

-- Even a client that knows none of them starts the module.
E,M=Session("ROGUE",{})
ok,err=pcall(M.Initialize,M)
equal(ok,true,"no known events: still starts ("..tostring(err)..")")
equal(type(frames[#frames].scripts.OnEvent),"function","and is ready for events")

-- Other classes never start it.
E,M=Session("MAGE",KNOWN)
ok=pcall(M.Initialize,M)
equal(ok and #frames,0,"a mage makes no frame for it")

-- ---- Talking to a vendor ----------------------------------------------------
-- A poison vendor: Dust of Decay sold in fives, Flash Powder, an item bought
-- with something other than gold (left out), and water (not a poison item).
local POISON_VENDOR={
 {id=2928,name="Dust of Decay",price=100,stack=5},
 {id=5140,name="Flash Powder",price=25,stack=1},
 {id=8924,name="Dust of Deterioration",price=0,stack=1,extended=true},
 {id=159,name="Refreshing Spring Water",price=25,stack=5},
}
local oldCalls
-- api: "new" (only C_MerchantFrame.GetItemInfo, Forever's new patch), "old"
-- (only GetMerchantItemInfo), "both", or "none".
local function Vendor(stock,api)
 MerchantFrame=Widget("Frame","MerchantFrame")
 GetMerchantNumItems=function()return #stock end
 GetMerchantItemLink=function(i)local s=stock[i];return s and ("|cffffffff|Hitem:"..s.id.."::::::::60:::::|h["..s.name.."]|h|r")end
 GetMerchantItemMaxStack=function(i)return stock[i]and(stock[i].max or 20)end
 oldCalls=0
 if api=="new" or api=="both" then
  -- The MerchantItemInfo table of Forever 1.60.1.70170's API docs; nothing for a bad index.
  C_MerchantFrame={GetItemInfo=function(i)
   local s=stock[i];if not s then return nil end
   if s.broken then error("bad merchant index")end
   return {name=s.name,texture=134400,price=s.price,stackCount=s.stack,numAvailable=s.available or -1,
    isPurchasable=true,isUsable=true,hasExtendedCost=s.extended or false,isQuestStartItem=false}
  end}
 end
 if api=="old" or api=="both" then
  GetMerchantItemInfo=function(i)
   oldCalls=oldCalls+1
   local s=stock[i];if not s then return end
   -- Under "both" the old answer differs, so a test sees which one was read.
   return s.name,134400,api=="both" and s.price*7 or s.price,s.stack,s.available or -1,true,s.extended or false
  end
 end
end
local DUST_RECIPE={[1]={needs={{id=2928,count=1}},output=1}}

for _,api in ipairs({"new","old"})do
 local label=api=="new" and "new patch" or "old client"
 E,M=Session("ROGUE",KNOWN);M:Initialize();f=frames[#frames]
 spells[8681]=true -- Instant Poison rank 1 known.
 Vendor(POISON_VENDOR,api)
 -- The reported error's path: a merchant event refreshes the vendor strip.
 ok,err=pcall(f.scripts.OnEvent,f,"MERCHANT_SHOW")
 equal(ok,true,label..": talking to a poison vendor is not an error ("..tostring(err)..")")
 local strip=named.EraUIRogueVendorStrip
 equal(strip~=nil,true,label..": the vendor strip is made for a poison vendor")
 equal(strip and strip.shown,true,label..": and shown")
 equal(strip and strip.buttons[1].shown,true,label..": with the known Instant Poison")
 equal(strip and strip.buttons[2].shown,false,label..": not an unknown poison")
 equal(strip and strip.buttons[6].shown,true,label..": and Flash Powder, which this vendor sells")
 ok,err=pcall(f.scripts.OnUpdate,f,2)
 equal(ok,true,label..": the refresh clock at a vendor is not an error ("..tostring(err)..")")
 ok,err=pcall(f.scripts.OnEvent,f,"MERCHANT_UPDATE")
 equal(ok,true,label..": nor a vendor update ("..tostring(err)..")")
 -- Price, stack size and position read from the vendor.
 local plan,why=M:PurchasePlan({powder=5},{})
 equal(plan and #plan.list,1,label..": Flash Powder can be bought ("..tostring(why)..")")
 local item=plan and plan.list[1]or{}
 equal(item.id,5140,label..": the Flash Powder entry")
 equal(item.index,2,label..": at its place in the vendor's list")
 equal(item.price,25,label..": its price")
 equal(item.bundle,1,label..": sold one at a time")
 equal(item.units,5,label..": five to buy")
 equal(plan and plan.cost,125,label..": for 1 silver 25 copper")
 plan,why=M:PurchasePlan({[1]=3,powder=0},DUST_RECIPE)
 item=plan and plan.list[1]or{}
 equal(item.bundle,5,label..": Dust of Decay comes in fives (stack count read)")
 equal(item.units,5,label..": so 3 needed buys one bundle of 5")
 equal(plan and plan.cost,100,label..": at the bundle price")
 plan,why=M:PurchasePlan({[1]=1},{[1]={needs={{id=8924,count=1}},output=1}})
 equal(plan,nil,label..": an item bought with something other than gold is left out")
 equal(why,"Vendor does not sell Dust of Deterioration.",label..": and said so")
 -- Limited stock is read too.
 Vendor({{id=5140,name="Flash Powder",price=25,stack=1,available=3}},api)
 plan,why=M:PurchasePlan({powder=5},{})
 equal(why,"Vendor has insufficient Flash Powder.",label..": a vendor with only 3 in stock can't sell 5")
 Vendor({{id=5140,name="Flash Powder",price=25,stack=1,available=9}},api)
 plan=M:PurchasePlan({powder=5},{})
 equal(plan and plan.list[1].units,5,label..": one with 9 can")
 -- Buy spends at the vendor: 5 Flash Powder from its place in the list.
 Vendor(POISON_VENDOR,api)
 EraUIClassicCharDB={classTools={poisonPowder=5}}
 ok,err=pcall(M.Buy,M)
 equal(ok,true,label..": Buy is not an error ("..tostring(err)..")")
 equal(#bought,1,label..": Buy buys")
 equal(bought[1]and bought[1].index,2,label..": Flash Powder")
 equal(bought[1]and bought[1].amount,5,label..": five of it")
 -- Closing the vendor hides the strip.
 MerchantFrame:Hide()
 f.scripts.OnEvent(f,"MERCHANT_CLOSED")
 equal(strip and strip.shown,false,label..": closing the vendor hides the strip")
 -- A vendor without poison supplies: no strip, no error.
 E,M=Session("ROGUE",KNOWN);M:Initialize();f=frames[#frames]
 Vendor({{id=159,name="Refreshing Spring Water",price=25,stack=5}},api)
 ok,err=pcall(f.scripts.OnEvent,f,"MERCHANT_SHOW")
 equal(ok,true,label..": another vendor is not an error ("..tostring(err)..")")
 equal(named.EraUIRogueVendorStrip,nil,label..": and gets no strip")
end

-- Both present: the new one is read, the old one never called.
E,M=Session("ROGUE",KNOWN);M:Initialize();f=frames[#frames]
Vendor(POISON_VENDOR,"both")
ok,err=pcall(f.scripts.OnEvent,f,"MERCHANT_SHOW")
equal(ok,true,"both: no error ("..tostring(err)..")")
local plan=M:PurchasePlan({powder=5},{})
equal(plan and plan.list[1].price,25,"both: the price comes from C_MerchantFrame.GetItemInfo")
equal(oldCalls,0,"both: GetMerchantItemInfo is never called")

-- Neither present: no error, just nothing found.
E,M=Session("ROGUE",KNOWN);M:Initialize();f=frames[#frames]
Vendor(POISON_VENDOR,"none")
ok,err=pcall(f.scripts.OnEvent,f,"MERCHANT_SHOW")
equal(ok,true,"neither: talking to a vendor is not an error ("..tostring(err)..")")
equal(named.EraUIRogueVendorStrip,nil,"neither: no strip")
local why
plan,why=M:PurchasePlan({powder=5},{})
equal(why,"Vendor does not sell Flash Powder.","neither: nothing can be bought")

-- An entry the game answers with nothing, or an error, is skipped; the rest still read.
E,M=Session("ROGUE",KNOWN);M:Initialize();f=frames[#frames]
Vendor({{id=2928,name="Dust of Decay",price=100,stack=5,broken=true},{id=5140,name="Flash Powder",price=25,stack=1}},"new")
local stock=GetMerchantNumItems
GetMerchantNumItems=function()return stock()+1 end -- one more than C_MerchantFrame answers for
ok,err=pcall(f.scripts.OnEvent,f,"MERCHANT_SHOW")
equal(ok,true,"a bad entry is not an error ("..tostring(err)..")")
plan,why=M:PurchasePlan({powder=5},{})
equal(plan and plan.list[1].index,2,"the good entry is still read ("..tostring(why)..")")
plan,why=M:PurchasePlan({[1]=1},DUST_RECIPE)
equal(why,"Vendor does not sell Dust of Decay.","the erroring entry is skipped")

-- ---- The window's materials line --------------------------------------------
-- The global GetCoinTextureString is gone on Forever's new patch too; the
-- game's own code has C_CurrencyInfo.GetCoinTextureString. At a vendor the
-- Poison Supplies window prices the selection: 5 Flash Powder at 25 copper.
local coinCalls
-- api: "new" (only C_CurrencyInfo.GetCoinTextureString), "old" (only the old
-- global), "both", "none", "error" (the new one errors, the old one is there)
-- or "empty" (the new one answers an empty string, the old one is there).
local function Coins(api)
 coinCalls={new=0,old=0}
 if api=="new" or api=="both" or api=="error" or api=="empty" then
  C_CurrencyInfo={GetCoinTextureString=function(amount)
   coinCalls.new=coinCalls.new+1
   if api=="error" then error("bad amount")end
   if api=="empty" then return "" end
   return "NEW:"..string.format("%d",amount)
  end}
 end
 if api=="old" or api=="both" or api=="error" or api=="empty" then
  GetCoinTextureString=function(amount)coinCalls.old=coinCalls.old+1;return "OLD:"..string.format("%d",amount)end
 end
end
-- The text after "Materials: " on the window's status line, if it shows one.
local function MaterialsLine()
 local found
 for _,w in ipairs(widgets)do
  local cost=type(w.text)=="string" and w.text:match("^Materials: (.-) \194\183 existing bag materials deducted$")
  if cost then found=cost end
 end
 return found
end
local function MaterialsAt(api)
 E,M=Session("ROGUE",KNOWN);M:Initialize();f=frames[#frames]
 spells[8681]=true
 C_TradeSkillUI={
  GetRecipeInfo=function(id)if id==8681 then return {learned=true,name="Instant Poison",icon=136007}end end,
  GetRecipeSchematic=function()return {reagentSlotSchematics={{reagents={{itemID=2928}},quantityRequired=1}},quantityMin=1}end,
 }
 EraUIClassicCharDB={classTools={poisonPowder=5}}
 Vendor(POISON_VENDOR,"new")
 Coins(api)
 local ok,err=pcall(M.Open,M)
 equal(ok,true,api..": the Poison Supplies window opens at a vendor ("..tostring(err)..")")
 equal(named.EraUIRogueTools~=nil and named.EraUIRogueTools.shown,true,api..": and is shown")
 return MaterialsLine()
end
equal(MaterialsAt("new"),"NEW:125","new patch: the cost in the game's coins")
equal(coinCalls.old,0,"new patch: nothing else asked")
equal(MaterialsAt("old"),"OLD:125","old client: the cost from the old GetCoinTextureString")
equal(MaterialsAt("both"),"NEW:125","both: the cost from C_CurrencyInfo")
equal(coinCalls.old,0,"both: the old GetCoinTextureString is never called")
equal(MaterialsAt("error"),"OLD:125","a C_CurrencyInfo that errors: the old one")
equal(MaterialsAt("empty"),"OLD:125","a C_CurrencyInfo that answers an empty string: the old one")
equal(MaterialsAt("none"),(5/1*25).." copper","neither: the cost in copper, no error")
print("Rogue Poisons checks passed: "..checks.." assertions.")
