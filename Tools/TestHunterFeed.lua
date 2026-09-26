-- Simulated movement, click routing and combat lifecycle for the real hunter tool.
local checks=0
local function equal(actual,expected,label)
 checks=checks+1
 assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local combat,known,pet,food=false,false,false,false
local dead,happiness,canEat=false,2,true
local diet={"Meat"}
local secret={}
local time=10
local frames={}
local methods={}
local function Frame(kind,secure)
 local f=setmetatable({kind=kind,secure=secure,shown=true,scripts={},hooks={},attributes={},scale=.65,x=1000,y=500},{__index=methods})
 frames[#frames+1]=f
 return f
end
local function Guard(f)assert(not(f.secure and combat),"protected edit during combat")end
for _,name in ipairs({"SetTexCoord","SetColorTexture","SetBackdropBorderColor","SetTextColor","SetStatusBarTexture","SetStatusBarColor","SetMinMaxValues","SetValue","SetClampedToScreen"})do methods[name]=function()end end
function methods:SetSize(w,h)Guard(self);self.width,self.height=w,h end
function methods:SetPoint(...)Guard(self);self.point={...}end
function methods:ClearAllPoints()Guard(self);self.point=nil end
function methods:SetText(text)self.text=text end
function methods:SetTexture(texture)self.texture=texture end
function methods:SetFrameStrata(strata)Guard(self);self.strata=strata end
function methods:SetMovable(value)self.movable=value end
function methods:EnableMouse(value)self.mouse=value end
function methods:EnableMouseWheel(value)self.wheel=value end
function methods:RegisterForClicks(...)self.clicks={...}end
function methods:RegisterForDrag(...)self.drags={...}end
function methods:SetScript(name,fn)self.scripts[name]=fn end
function methods:HookScript(name,fn)self.hooks[name]=fn end
function methods:Fire(name,...)
 if self.scripts[name]then self.scripts[name](self,...)end
 if self.hooks[name]then self.hooks[name](self,...)end
end
function methods:RegisterEvent()end
function methods:IsShown()return self.shown end
function methods:SetShown(value)
 Guard(self)
 value=not not value
 if self.shown==value then return end
 self.shown=value;self:Fire(value and "OnShow"or"OnHide")
end
function methods:Hide()self:SetShown(false)end
function methods:Show()self:SetShown(true)end
function methods:CreateTexture()return Frame("Texture")end
function methods:SetAttribute(key,value)Guard(self);self.attributes[key]=value end
function methods:GetCenter()return self.x,self.y end
function methods:GetEffectiveScale()return self.scale end
function methods:StartMoving()assert(self.movable and self.mouse,"preview must accept dragging");self.moving=true end
function methods:StopMovingOrSizing()self.moving=false end
UIParent=Frame("Root")
CreateFrame=function(kind)return Frame(kind)end
GameTooltip=Frame("Tooltip")
InCombatLockdown=function()return combat end
GetTime=function()return time end
UnitClass=function()return "Hunter","HUNTER"end
UnitLevel=function()return 12 end
UnitExists=function()return pet end
UnitIsDead=function()return dead end
GetPetHappiness=nil;GetPetFoodTypes=nil
C_PetInfo={GetPetHappiness=function()return happiness end,GetPetFoodTypes=function()return diet end,
 CanPetEatItem=function()return canEat end}
RegisterStateDriver=function(f,_,rule)
 Guard(f);f.rule=rule;f:SetShown(rule~="hide"and not combat)
end
C_UnitAuras={GetAuraDataByIndex=function(_,index)
 if index==1 then return {spellId=1539,expirationTime=time+10,duration=10}end
end}
local options={}
local E={modules={},settings={enabled=true,hunterFeed=true},saves=0}
function E:RegisterModule(name,m)self.modules[name]=m end
function E:GetSetting(key)return self.settings[key]end
function E:SaveSettings()self.saves=self.saves+1 end
function E:Print(text)self.message=text end
E.settingsFrame=Frame("Settings")
local T={}
E.ClassTools=T
function T.Options()return options end
function T.Public(v)return v~=secret end
function T.Number(v)return T.Public(v)and type(v)=="number"end
function T.Colour()return .67,.83,.45 end
function T.Known()return known end
function T.Spell()return "Feed Pet"end
function T.Item()return "Test food",nil,nil,20 end
function T.Count()return 4 end
function T.Bags(callback)if food then callback(0,2,{itemID=117,stackCount=4,iconFileID=123})end end
function T.Button(_,text,w,h,secure)local f=Frame("Button",secure);f:SetSize(w,h);f.label=Frame("Text");f.label:SetText(text);return f end
function T.Text(_,text)local f=Frame("Text");f:SetText(text);return f end
function T.Skin()end
assert(loadfile("Modules/HunterFeed.lua"))("EraUI",E)
local M=E.modules.HunterFeed
M:Initialize()
local button,mover,driver,bar
for _,f in ipairs(frames)do
 if f.secure then button=f end
 if f.drags then mover=f end
 if f.scripts.OnUpdate then driver=f end
 if f.kind=="StatusBar"then bar=f end
end
equal(button:IsShown(),false,"no icon over settings")
equal(mover:IsShown(),false,"no unsolicited positioning preview")
M:BeginMove()
equal(E.settingsFrame:IsShown(),false,"move control closes settings")
equal(mover:IsShown(),true,"preview works before Feed Pet is learned")
equal(button:IsShown(),false,"secure feed button hidden while editing")
equal(mover.attributes.type,nil,"preview has no feeding action")
equal(mover.mouse,true,"entire icon receives mouse input")

mover:Fire("OnDragStart")
equal(mover.moving,true,"icon starts dragging")
mover.x,mover.y,mover.scale=2200,1200,.325
M:Refresh()
equal(mover.moving,true,"bag refresh does not interrupt dragging")
mover:Fire("OnDragStop")
equal(mover.moving,false,"drag stops on release")
equal(options.feedPosition.x,100,"x saved in UIParent scale")
equal(options.feedPosition.y,100,"y saved in UIParent scale")
equal(button.point[4],100,"feed icon uses saved x")
equal(button.point[5],100,"feed icon uses saved y")
mover:Fire("OnClick","LeftButton")
equal(mover:IsShown(),true,"drag-release click does not lock")
mover:Fire("OnMouseWheel",3)
equal(options.feedPosition.size,46,"wheel resizes preview")
equal(button.width,46,"feed icon receives preview size")
time=time+1
mover:Fire("OnClick","LeftButton")
equal(mover:IsShown(),false,"left click locks preview")
equal(button:IsShown(),false,"unlearned feeding stays hidden after lock")

known,pet,food=true,true,true
M:Refresh()
equal(button:IsShown(),true,"hungry pet shows locked icon")
equal(button.attributes.type,nil,"no all-button feeding action")
equal(button.attributes.type1,"macro","only left click feeds")
equal(button.attributes.type2,nil,"right click has no feeding action")
equal(button.attributes.macrotext1,"/cast [nocombat,pet] Feed Pet\n/use [nocombat,pet] 0 2","feeding macro still targets selected bag slot")
button:Fire("PostClick","RightButton",true)
equal(mover:IsShown(),false,"right-button down does not toggle twice")
button:Fire("PostClick","RightButton",false)
equal(mover:IsShown(),true,"right-button release unlocks icon")
equal(button.attributes.macrotext1,nil,"unlock clears feeding action")
mover:Fire("OnClick","LeftButton")
equal(button:IsShown(),true,"locking restores normal feeding icon")

driver:Fire("OnEvent","UNIT_AURA","pet")
driver:Fire("OnUpdate",.2)
equal(bar:IsShown(),true,"feeding duration still displays")
E.settingsFrame:Show();driver:Fire("OnUpdate",.2)
equal(button:IsShown(),false,"settings hides live feeding icon")
equal(bar:IsShown(),false,"settings hides feeding duration")
M:BeginMove()
mover:Fire("OnDragStart")
mover.x,mover.y,mover.scale=950,400,.65
combat=true
button.shown=false -- Native visibility driver, not addon Lua.
driver:Fire("OnEvent","PLAYER_REGEN_DISABLED")
equal(mover.moving,false,"combat stops independent preview drag")
equal(mover:IsShown(),false,"combat hides preview")
equal(options.feedPosition.x,-50,"combat interruption keeps last x")
equal(options.feedPosition.y,-100,"combat interruption keeps last y")
M:BeginMove()
equal(mover:IsShown(),false,"cannot unlock in combat")
combat=false
driver:Fire("OnEvent","PLAYER_REGEN_ENABLED")
equal(button.point[4],-50,"secure layout applied after combat")
equal(button:IsShown(),true,"normal feeding resumes after combat")
M:BeginMove()
E.settings.hunterFeed=false;M:Refresh()
equal(mover:IsShown(),false,"disable closes preview")
equal(button:IsShown(),false,"disable hides feeding button")
equal(E.saves>0,true,"movement and size queue persistence")
E.settings.hunterFeed=true;known,pet,food=true,true,true
M:Refresh();equal(button:IsShown(),true,"modern-only pet API shows hungry feed button")
equal(button.food.id,117,"modern table diet and item check select meat")
GetPetHappiness=function()return 3 end
GetPetFoodTypes=function()return "Fish"end
M:Refresh();equal(button:IsShown(),true,"modern happiness takes precedence over legacy global")
equal(button.food.id,117,"modern item compatibility takes precedence over legacy diet")
canEat=false;M:Refresh()
equal(button:IsShown(),true,"hungry pet still gets a no-food reminder")
equal(button.food,nil,"native incompatible food is rejected")
equal(button.attributes.macrotext1,nil,"no incompatible feeding action")
canEat=secret;M:Refresh();equal(button.food,nil,"restricted diet result is not used")
canEat=true;happiness=3;M:Refresh()
equal(button:IsShown(),false,"happy pet hides feeding button")
equal(M:StatusLine():find("happy",1,true)~=nil,true,"settings explains happy-pet visibility")
happiness=nil;M:Refresh();equal(button:IsShown(),false,"missing happiness does not fabricate hungry state")
happiness=1;driver:Fire("OnEvent","UNIT_HAPPINESS","pet")
equal(button:IsShown(),true,"unhappy event shows button using current API")
dead=true;M:Refresh();equal(button:IsShown(),false,"dead pet cannot show feed action")
dead=false;known=false;M:Refresh();equal(button:IsShown(),false,"Feed Pet must still be learned")
known=true;E.settingsFrame:Show();M:Refresh()
equal(M:StatusLine():find("Close settings",1,true)~=nil,true,"settings explains deliberate feeding-button hiding")
E.settingsFrame:Hide()
C_PetInfo.CanPetEatItem=nil;diet={"Meat","Fish"};M:Refresh()
equal(button.food.id,117,"table-valued modern diet fallback works")
C_PetInfo=nil;GetPetHappiness=function()return 1 end;GetPetFoodTypes=function()return "Meat","Fish"end
M:Refresh();equal(button:IsShown(),true,"legacy happiness fallback works")
equal(button.food.id,117,"legacy multiple-return diet fallback works")
print("Hunter feeding interaction checks passed: "..checks.." assertions.")
