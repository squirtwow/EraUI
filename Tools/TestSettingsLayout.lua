-- Real settings, class panels and mage action overlays under a geometric frame
-- mock. Protected parents/anchors throw on combat mutations.
local checks=0
unpack=table.unpack or unpack
local function equal(got,want,label)
 checks=checks+1;assert(got==want,label..": expected "..tostring(want)..", got "..tostring(got))
end
local frames,timers,combat,token
local methods={}
local function Depends(f,target,seen)
 if f==target then return true end
 if not f or f==UIParent then return false end
 seen=seen or{};if seen[f]then return false end;seen[f]=true
 if Depends(f.parent,target,seen)then return true end
 for _,p in ipairs(f.points)do if Depends(p[2],target,seen)then return true end end
 return false
end
local function Guard(f)
 if not combat or f==UIParent then return end
 for _,other in ipairs(frames)do
  if other.secure and Depends(other,f)then error("protected mutation of "..(f.name or f.kind))end
 end
end
local function Frame(kind,name,parent,template)
 local f=setmetatable({kind=kind,name=name,parent=parent,shown=true,points={},scripts={},hooks={},w=0,h=0,
  value=0,scale=1,attributes={},secure=template and template:find("SecureActionButton",1,true)~=nil},{__index=methods})
 frames[#frames+1]=f;if name then _G[name]=f end;return f
end
function methods:Fire(event,...)
 if self.scripts[event]then self.scripts[event](self,...)end
 for _,fn in ipairs(self.hooks[event]or{})do fn(self,...)end
end
function methods:SetScript(event,fn)self.scripts[event]=fn end
function methods:HookScript(event,fn)self.hooks[event]=self.hooks[event]or{};table.insert(self.hooks[event],fn)end
function methods:IsShown()return self.shown and(not self.parent or self.parent:IsShown())end
function methods:SetShown(v)
 Guard(self);v=not not v;if self.shown==v then return end
 local before={};for _,f in ipairs(frames)do before[f]=f:IsShown()end
 self.shown=v
 for f,old in pairs(before)do local now=f:IsShown();if now~=old then f:Fire(now and "OnShow"or"OnHide")end end
end
function methods:Hide()self:SetShown(false)end
function methods:Show()self:SetShown(true)end
function methods:SetParent(p)Guard(self);self.parent=p end
function methods:GetParent()return self.parent end
function methods:SetScale(s)Guard(self);self.scale=s end
function methods:GetEffectiveScale()return self.scale*(self.parent and self.parent:GetEffectiveScale()or 1)end
function methods:GetFrameLevel()return 1 end
local factors={TOPLEFT={0,1},TOP={.5,1},TOPRIGHT={1,1},LEFT={0,.5},CENTER={.5,.5},RIGHT={1,.5},BOTTOMLEFT={0,0},BOTTOM={.5,0},BOTTOMRIGHT={1,0}}
function methods:SetPoint(p,r,rp,x,y)
 Guard(self)
 if type(r)=="number"or r==nil then x,y=r or 0,rp or 0;r=self.parent;rp=p
 elseif type(rp)=="number"then x,y=rp,x or 0;rp=p end
 local point={p,r,rp or p,x or 0,y or 0}
 for i,old in ipairs(self.points)do if old[1]==p then self.points[i]=point;return end end
 self.points[#self.points+1]=point
end
function methods:ClearAllPoints()Guard(self);self.points={}end
function methods:GetPoint()return table.unpack(self.points[1]or{})end
function methods:SetAllPoints(r)r=r or self.parent;self:ClearAllPoints();self:SetPoint("TOPLEFT",r,"TOPLEFT",0,0);self:SetPoint("BOTTOMRIGHT",r,"BOTTOMRIGHT",0,0)end
local function Anchor(f,p)
 local r=p[2];local x,y,w,h=r:Rect();local ratio=r:GetEffectiveScale()/f:GetEffectiveScale();local a=factors[p[3]]
 y=y+((f.parent and f.parent.scrollChild==f)and(f.parent.scroll or 0)or 0)
 return(x+w*a[1])*ratio+p[4],(y+h*a[2])*ratio+p[5]
end
function methods:Rect()
 if self==UIParent then return 0,0,self.w,self.h end
 local p=self.points[1];local w,h=self.w,self.h
 if not p then return 0,0,w,h end
 local x,y=Anchor(self,p);local a=factors[p[1]]
 for i=2,#self.points do
  local other=self.points[i];local ox,oy=Anchor(self,other);local b=factors[other[1]]
  if a[1]~=b[1]then w=(ox-x)/(b[1]-a[1])end
  if a[2]~=b[2]then h=(oy-y)/(b[2]-a[2])end
 end
 return x-a[1]*w,y-a[2]*h,w,h
end
function methods:GetWidth()local _,_,w=self:Rect();return w end
function methods:GetHeight()local _,_,_,h=self:Rect();return h end
function methods:GetLeft()return self:Rect()end
function methods:GetBottom()local _,y=self:Rect();return y end
function methods:GetTop()local _,y,_,h=self:Rect();return y+h end
function methods:GetRight()local x,_,w=self:Rect();return x+w end
function methods:SetSize(w,h)Guard(self);local changed=self.w~=w or self.h~=h;self.w,self.h=w,h;if changed then self:Fire("OnSizeChanged",w,h)end end
function methods:SetWidth(w)self:SetSize(w,self.h)end
function methods:SetHeight(h)self:SetSize(self.w,h)end
function methods:SetText(text)self.text=text;self:Fire("OnTextChanged")end
function methods:GetText()return self.text or""end
function methods:SetFont(...)self.font={...};self.h=self.font[2]or 12 end
function methods:GetFont()return "font",12,""end
function methods:GetStringWidth()return #self:GetText()*6 end
function methods:SetChecked(v)self.checked=not not v end
function methods:GetChecked()return self.checked end
function methods:SetEnabled(v)self.enabled=v end
function methods:Enable()self.enabled=true end
function methods:Disable()self.enabled=false end
function methods:SetAttribute(k,v)Guard(self);self.attributes[k]=v end
function methods:CreateTexture()return Frame("Texture",nil,self)end
function methods:CreateFontString()return Frame("FontString",nil,self)end
function methods:SetThumbTexture()self.thumbTexture=Frame("Texture",nil,self)end
function methods:GetThumbTexture()return self.thumbTexture end
function methods:SetValue(v)if v~=self.value then self.value=v;self:Fire("OnValueChanged",v)end end
function methods:GetValue()return self.value end
function methods:SetMinMaxValues(low,high)self.low,self.high=low,high end
function methods:SetScrollChild(f)self.scrollChild=f;f:SetPoint("TOPLEFT",self,"TOPLEFT",0,0)end
function methods:SetVerticalScroll(v)Guard(self);self.scroll=v end
function methods:GetVerticalScroll()return self.scroll or 0 end
for _,key in ipairs({"SetBackdrop","SetBackdropColor","SetBackdropBorderColor","SetTextColor","SetJustifyH","SetJustifyV","SetWordWrap","SetTexCoord","SetTexture","SetColorTexture","SetVertexColor","SetShadowColor","SetShadowOffset","SetAlpha","SetFrameStrata","SetFrameLevel","SetMovable","SetClampedToScreen","EnableMouse","EnableMouseWheel","RegisterForDrag","RegisterForClicks","RegisterEvent","SetOrientation","SetValueStep","SetObeyStepOnDrag","SetAutoFocus","SetMaxLetters","SetTextInsets","ClearFocus","StartMoving","StopMovingOrSizing"})do
 methods[key]=function(self)Guard(self)end
end
CreateFrame=Frame
methods.SetStatusBarTexture=function()end
methods.SetStatusBarColor=function()end
InCombatLockdown=function()return combat end
UnitClass=function()return token,token end
UnitIsPlayer=function()return true end
UnitLevel=function()return 20 end
GetTime=function()return 10 end
IsPlayerSpell=function(id)return id==587 or id==5504 end
C_Spell={GetSpellInfo=function(id)return {name="Spell"..id,iconID=id}end}
C_Item={GetItemInfo=function()return "Item",nil,nil,nil,1,nil,nil,20 end,GetItemCount=function()return 0 end}
RAID_CLASS_COLORS={MAGE={r=.4,g=.8,b=1},HUNTER={r=.6,g=.8,b=.4}}
GetCVarBool=function()return false end
hooksecurefunc=function(f,key,fn)local old=f[key];f[key]=function(self,...)old(self,...);fn(self,...)end end
RegisterStateDriver=function(f,_,rule)Guard(f);f.rule=rule;f:SetShown(rule~="hide"and not combat)end
local function Flush()
 for _=1,20 do if #timers==0 then return end;local pending=timers;timers={};for _,fn in ipairs(pending)do fn()end end
 error("layout queue did not settle")
end
local function Session(c)
 frames,timers,combat,token={},{},false,c
 UIParent=Frame("Root");UIParent.w=2560/.65;UIParent.h=1440/.65;UIParent.scale=.65
 GameFontHighlight=Frame("Font");GameFontHighlightSmall=GameFontHighlight
 C_Timer={After=function(_,fn)timers[#timers+1]=fn end}
  EraUIDB={};EraUIClassicCharDB={};UISpecialFrames={};SlashCmdList={}
 local E={modules={},reloadSettings={},settingDefaults={},charSettingKeys={},settings={enabled=true,mageSupplies=true,hunterFeed=true}}
 function E:RegisterModule(name,m)self.modules[name]=m end
 function E:GetSetting(key)return self.settings[key]end
 E.GetSavedSetting=E.GetSetting
 function E:SetSetting(key,value)self.settings[key]=value end
 function E:SaveSettings()end
 function E:Print()end
  function E:Status()end
  E.Persistence={}
  E.Classic={DB_DEFAULTS={},TOGGLES={},RELOAD_KEYS={},MirrorSave=function()end,
   OpenOptions=function()end,ApplyAll=function()end,ToggleChanged=function()end,FirstRun=function()end}
 assert(loadfile("Modules/ClassTools.lua"))("EraUI",E)
 assert(loadfile("Modules/ClassReminderData.lua"))("EraUI",E)
 assert(loadfile("Modules/ClassReminders.lua"))("EraUI",E)
 assert(loadfile("Modules/HunterFeed.lua"))("EraUI",E)
  assert(loadfile("Modules/MageSupplies.lua"))("EraUI",E)
  assert(loadfile("Modules/RoguePoisons.lua"))("EraUI",E)
  -- Load the real Classic -> settings toggle bridge. Omitting this previously
  -- let the layout suite pass without exercising broken Configure navigation.
  assert(loadfile("Core/Integration.lua"))("EraUI",E)
  assert(loadfile("Core/Commands.lua"))("EraUI",E)
 assert(loadfile("Core/SettingsLayout.lua"))("EraUI",E)
 assert(loadfile("Core/Settings.lua"))("EraUI",E)
 E.modules.ClassReminders:Initialize()
 E.modules.MageSupplies:Initialize()
 E.modules.Settings:Initialize()
 local f=E.settingsFrame;f.selectedCategory=12;f:Show();Flush()
 return E,f
end
local function Fits(f,label)
 local s=f.settingsScroll
 equal(s:GetBottom()>f:GetBottom()+64,true,label.." viewport clears footer")
 for i,card in ipairs(f.settingsEntries or{})do
  equal(card:GetParent(),f.settingsContent,label.." card in clipped content")
  if card.inlinePanel then
   equal(card.inlinePanel:GetParent(),f.settingsContent,label.." inline panel in clipped content")
   equal(card.inlinePanel:GetRight()<=s:GetRight()+.01,true,label.." right panel border fits viewport")
  end
  if i>2 then
   local above=f.settingsEntries[i-2];local bottom=above.inlinePanel and above.inlinePanel:IsShown()and above.inlinePanel:GetBottom()or above:GetBottom()
   equal(card:GetTop()<=bottom-4+.01,true,label.." expanded block clears following row")
  end
 end
end
local function NoCardOverlaps(f,label)
 local visible={}
 for key,card in pairs(f.checks)do if card:IsShown()then visible[#visible+1]={key=key,card=card}end end
 for i=1,#visible do
  for j=i+1,#visible do
   local a,b=visible[i].card,visible[j].card
   local intersects=a:GetLeft()<b:GetRight()-.01 and b:GetLeft()<a:GetRight()-.01
    and a:GetBottom()<b:GetTop()-.01 and b:GetBottom()<a:GetTop()-.01
   equal(intersects,false,label.." "..visible[i].key.." / "..visible[j].key.." do not overlap")
  end
 end
end
for _,c in ipairs({"HUNTER","MAGE","ROGUE","WARRIOR","PALADIN","SHAMAN","PRIEST","WARLOCK","DRUID"})do
  local E,f=Session(c)
  f.selectedCategory=1;f:SetSetupMode(false);Flush()
  NoCardOverlaps(f,c.." HUD")
  equal(f.checks.portraitDebuffs:IsShown(),true,c.." portrait setting visible on HUD")
  equal(f.checks.matchFocusSize:IsShown(),true,c.." focus sizing remains visible on HUD")
  for _,category in ipairs({9,10})do
   f.selectedCategory=category;f:SetSetupMode(false);Flush()
   NoCardOverlaps(f,c.." category "..category)
   equal(f.settingsContent:GetHeight()>=f.settingsScroll:GetHeight(),true,c.." effects/automation scroll extent")
  end
  equal(f.checks.cursorCastRing:IsShown(),true,c.." cast ring visible beside existing cursor options")
  equal(f.checks.cursorTrail:IsShown(),true,c.." trail visible beside existing cursor options")
  equal(f.settingsScrollHint:IsShown(),true,c.." long page indicates options below")
  equal(f.settingsScrollHint:GetTop()<f.settingsScroll:GetBottom(),true,c.." hint below clipped controls")
  equal(f.settingsScrollHint:GetBottom()>=f:GetBottom()+72,true,c.." hint clears footer")
  f:SetSettingsScroll(99999)
  equal(f.settingsScrollHint:IsShown(),false,c.." hint disappears at page bottom")
  f:SetSettingsScroll(0)
  equal(f.settingsScrollHint:IsShown(),true,c.." hint returns after scrolling up")
  f.searchBox:SetText("no matching cursor option");Flush()
  equal(f.settingsScrollHint:IsShown(),false,c.." no scroll hint for empty search")
  f.searchBox:SetText("");Flush()
  if c=="DRUID"then
   local refreshed=0;E.modules.CursorEffects={Refresh=function()refreshed=refreshed+1 end}
   E.settings.cursorTrailClassColour=true;E.settings.cursorTrailColour="123456"
   local picker
   ColorPickerFrame={SetupColorPickerAndShow=function(_,info)picker=info end,GetColorRGB=function()return 1,.5,0 end}
   f.checks.cursorTrailColour:Fire("OnClick")
   picker.swatchFunc()
   equal(E.settings.cursorTrailColour,"FF8000","custom trail colour saved")
   equal(E.settings.cursorTrailClassColour,false,"custom selection switches off class colour")
   picker.cancelFunc()
   equal(E.settings.cursorTrailColour,"123456","colour cancel restores original colour")
   equal(E.settings.cursorTrailClassColour,true,"colour cancel restores original class mode")
   equal(refreshed,2,"colour preview and cancellation apply immediately")
   ColorPickerFrame=nil
  end
  f.selectedCategory=12;f:SetSetupMode(false);Flush()
  Fits(f,c.." collapsed")
  local p=E.modules.ClassReminders:OptionsPanel()
  equal(f.checks.classTools:IsShown(),c=="HUNTER"or c=="MAGE"or c=="ROGUE",c.." only useful tool cards shown")
  equal(p.group:IsShown(),c~="ROGUE"and c~="SHAMAN",c.." group checking matches supported reminders")
  equal(p.clickable:IsShown(),c~="ROGUE",c.." reminder clicking matches supported actions")
  if c=="HUNTER"or c=="MAGE"then
   equal(f.checks.classTools.kind,"Frame",c.." inline heading is not a button")
   equal(f.checks.classTools.scripts.OnClick,nil,c.." inline heading has no click action")
  end
 p.adv:Fire("OnClick");Flush();Fits(f,c.." expanded")
 local endHeight=f.settingsContent:GetHeight()
 equal(endHeight>=f.settingsScroll:GetHeight(),true,c.." measured scroll extent")
 f:SetSettingsScroll(99999)
 equal(f.settingsScroll:GetVerticalScroll(),endHeight-f.settingsScroll:GetHeight(),c.." scroll reaches last panel")
 p.adv:Fire("OnClick");Flush()
 equal(f.settingsScroll:GetVerticalScroll()<=f.settingsContent:GetHeight()-f.settingsScroll:GetHeight(),true,c.." collapse clamps offset")
 f.searchBox:SetText("class");Flush();Fits(f,c.." search expanded cards")
 f.searchBox:SetText("");Flush();Fits(f,c.." restored class page")
 f:SetSetupMode(true);Flush()
 equal(f.settingsScroll:GetLeft()-f:GetLeft(),30,c.." setup viewport position")
 f:SetSetupMode(false);Flush();Fits(f,c.." return from setup")
end

for _,c in ipairs({"DRUID","WARRIOR","PALADIN","SHAMAN","PRIEST","WARLOCK","HUNTER","MAGE","ROGUE"})do
 local E,f=Session(c)
 E.settings.classReminders=true
 local expected=c=="HUNTER"and "HunterFeed"or c=="MAGE"and "MageSupplies"or c=="ROGUE"and "RoguePoisons"or "ClassReminders"
 equal(E.ClassTools:ActiveModule(),E.modules[expected],c.." real class route")
 local button=f.checks.classTools
 local function OpenTools()
   if button:IsShown() and button.scripts.OnClick then button:Fire("OnClick")else E.ClassTools:Open()end
  Flush()
 end
 OpenTools()
 equal(f:IsShown(),true,c.." Configure keeps settings open")
 local key=(c=="HUNTER"or c=="MAGE")and "classTools"or "classReminders"
 local function Focused(label)
  equal(f:IsShown(),true,label.." settings shown")
  equal(f.selectedCategory,12,label.." class tab selected")
  equal(f.searchBox:GetText(),"",label.." search cleared")
  local anchor=f.checks[key]
  equal(anchor:IsShown(),true,label.." destination anchor shown")
  equal(anchor.inlinePanel:IsShown(),true,label.." actual controls shown")
  equal(anchor:GetTop()<=f.settingsScroll:GetTop()+.01,true,label.." anchor below viewport top")
  equal(anchor:GetBottom()>=f.settingsScroll:GetBottom()-.01,true,label.." anchor above viewport bottom")
 end
 if c=="ROGUE"then
  equal(EraUIRogueTools:IsShown(),true,"rogue Configure opens real poison window")
  equal(Depends(EraUIRogueTools,f),false,"rogue tool window independent of settings")
  OpenTools();equal(EraUIRogueTools:IsShown(),true,"repeat rogue click leaves poison window open")
  EraUIRogueTools:Hide()
 else
  Focused(c.." first click")
  OpenTools();Focused(c.." repeat click")
  f:Hide();f.selectedCategory=1
  E.ClassTools:Open();Flush();Focused(c.." initially closed")
  f.searchBox:SetText("no matching control");Flush()
  E.ClassTools:Open();Flush();Focused(c.." from search")
  f:SetSetupMode(true)
  E.ClassTools:Open();Flush();Focused(c.." from setup")
  equal(f.setupMode,false,c.." tool navigation exits setup")
 end
 -- Exercise actual command wiring and disabled reminders on every class,
 -- including classes whose Configure card opens a different tool module.
 E.settings.classReminders=false
 f:Hide();f.selectedCategory=1
 SlashCmdList.ERAUI("reminders");Flush()
 key="classReminders";Focused(c.." disabled reminder command")
 equal(E.settings.classReminders,false,c.." navigation does not enable reminders")
 equal(E.modules.ClassReminders:OptionsPanel().offHint:IsShown(),true,c.." disabled explanation remains visible")
 SlashCmdList.ERAUI("reminders");Flush();Focused(c.." repeated reminder command")
 -- Ordinary /era remains a toggle, using the actual Integration bridge.
 SlashCmdList.ERAUI("");Flush();equal(f:IsShown(),false,c.." normal slash still closes")
 SlashCmdList.ERAUI("");Flush();equal(f:IsShown(),true,c.." normal slash still opens")
 E.ClassTools:Open();f:Hide();Flush()
 equal(f:IsShown(),false,c.." closing immediately after navigation stays closed")
 if c=="ROGUE"then EraUIRogueTools:Hide()end
 combat=true
 E.ClassTools:Open();E.modules.ClassReminders:Open();Flush()
 equal(f:IsShown(),false,c.." combat attempt does not open settings")
 if c=="ROGUE"then equal(EraUIRogueTools:IsShown(),false,"combat attempt does not open poison window")end
 combat=false
end

local E,f=Session("MAGE")
local M=E.modules.MageSupplies
local function Actions()
 local out={};for _,b in ipairs(frames)do if b.secure then out[#out+1]=b end end;return out
end
local actions=Actions()
equal(#actions,2,"both mage actions created")
for _,b in ipairs(actions)do
 equal(b.parent,UIParent,"secure button independent parent")
 equal(Depends(b,f),false,"secure button has no settings dependency")
 equal(b:IsShown(),true,"fully visible inline action enabled")
 equal(b.attributes.type,"spell","conjure action retains secure spell route")
end
local panel=f.checks.classTools.inlinePanel
equal(panel.items[3].label:GetTop()<=panel.items[2]:GetBottom()-4,true,"food slider label clears conjure button")
equal(panel.items[4].label:GetTop()<=panel.items[3]:GetBottom()-4,true,"water slider label clears food slider")
local slot=panel.items[1]
local function Aligned(label)
 M:SyncButtons()
 for _,b in ipairs(actions)do
  if b:IsShown()and b.attributes.spell==587 then
   equal(math.abs(b:GetLeft()*b:GetEffectiveScale()-slot:GetLeft()*slot:GetEffectiveScale())<.01,true,label.." x")
   equal(math.abs(b:GetTop()*b:GetEffectiveScale()-slot:GetTop()*slot:GetEffectiveScale())<.01,true,label.." y")
  end
 end
end
Aligned("initial")
f:ClearAllPoints();f:SetPoint("CENTER",UIParent,"CENTER",150,-40);f:Fire("OnDragStop");Aligned("moved")
f:SetScale(.7);Aligned("scaled")
f.searchBox:SetText("conjure");Flush();Fits(f,"mage search")
Aligned("search")
f:Hide();for _,b in ipairs(actions)do equal(b:IsShown(),false,"close hides independent action")end
f:Show();Flush()

combat=true
for _,b in ipairs(actions)do b.shown=false end -- Secure visibility driver, not insecure Lua.
M:Refresh()
f.searchBox:SetText("class");Flush();f:SetSettingsScroll(99999)
f:SetSetupMode(true);Flush();f:SetSetupMode(false);Flush()
f:Hide();f:Show();Flush();f:Fire("OnEvent","UI_SCALE_CHANGED")
for _,b in ipairs(actions)do equal(b:IsShown(),false,"combat navigation never shows conjure action")end
equal(true,true,"combat close, search, setup, scrolling and scaling have no protected mutations")
combat=false
for _,b in ipairs(actions)do b.shown=b.rule~="hide"end -- Native driver exits combat.
M:Refresh();Flush()
for _,b in ipairs(actions)do equal(b:IsShown(),true,"combat exit restores visible actions")end
-- A small viewport must never leave a clipped or offscreen secure click target.
f.settingsScroll:ClearAllPoints();f.settingsScroll:SetPoint("TOPLEFT",202,-148);f.settingsScroll:SetSize(718,100)
f:LayoutSettings(true);M:SyncButtons()
for _,b in ipairs(actions)do equal(b:IsShown(),false,"clipped action hidden")end
f:SetSettingsScroll(99999);M:SyncButtons()
Fits(f,"short viewport")

-- Setup walkthrough: a quest tracker step appears only with Questie installed,
-- and every later page is still reachable.
do
 local E,f=Session("DRUID")
 f:SetSetupMode(true);Flush()
 f.setupNext:Fire("OnClick");Flush()
 equal(f.setupYes:IsShown(),true,"without Questie page 2 is everyday helpers")
 equal(f.trackerChoices[1]:IsShown(),false,"without Questie there is no tracker step")
 f:SetSetupMode(false);Flush()

 local choice,reloadNeeded,calls="",false,{}
 E.modules.QuestTrackerChoice={
  QuestieInstalled=function()return true end,
  CurrentChoice=function()return choice end,
  SetChoice=function(_,c)choice=c;calls[#calls+1]=c;reloadNeeded=c=="classic"end,
  NeedsReload=function()return reloadNeeded end,
 }
 local reloads=0
 ReloadUI=function()reloads=reloads+1 end
 f:SetSetupMode(true);Flush()
 f.setupNext:Fire("OnClick");Flush()
 equal(f.trackerChoices[1]:IsShown(),true,"Questie installed: tracker step shown")
 equal(f.trackerChoices[2]:IsShown(),true,"both tracker choices shown")
 equal(f.setupYes:IsShown(),false,"helpers wait for the next page")
 equal(f.setupNext:IsShown(),true,"tracker step can be passed with Next")
 f.trackerChoices[1]:Fire("OnClick");Flush()
 equal(calls[#calls],"classic","Classic choice applied")
 equal(f.trackerChoices[1].label:GetText():find("Selected",1,true)~=nil,true,"Classic shows as selected")
 f.trackerChoices[2]:Fire("OnClick");Flush()
 equal(choice,"questie","choice can be changed")
 f.trackerChoices[1]:Fire("OnClick");Flush()
 f.setupNext:Fire("OnClick");Flush()
 equal(f.setupYes:IsShown(),true,"everyday helpers follow the tracker step")
 f.setupSkip:Fire("OnClick");Flush()
 equal(f.setupNext.label:GetText(),"Reload & explore","Classic choice asks for the final reload")
 f.setupBack:Fire("OnClick");Flush()
 equal(f.setupYes:IsShown(),true,"back from finish returns to helpers")
 f.setupBack:Fire("OnClick");Flush()
 equal(f.trackerChoices[1]:IsShown(),true,"back again returns to the tracker step")
 f.setupNext:Fire("OnClick");Flush()
 f.setupYes:Fire("OnClick");Flush()
 for _=1,6 do f.setupNext:Fire("OnClick");Flush() end
 equal(f.setupNext.label:GetText(),"Reload & explore","all six option pages still lead to finish")
 f.setupNext:Fire("OnClick")
 equal(reloads,1,"finish reloads straight from the click")
 f:SetSetupMode(false);Flush()
 equal(f.trackerChoices[1]:IsShown(),false,"tracker choices hidden outside setup")
end
print("Settings layout/combat checks passed: "..checks.." assertions.")
