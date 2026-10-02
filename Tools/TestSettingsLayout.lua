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
-- As in the client: IsShown is a frame's own flag, IsVisible also needs its parents.
function methods:IsShown()return self.shown end
function methods:IsVisible()return self.shown and(not self.parent or self.parent:IsVisible())end
function methods:SetShown(v)
 Guard(self);v=not not v;if self.shown==v then return end
 local before={};for _,f in ipairs(frames)do before[f]=f:IsVisible()end
 self.shown=v
 for f,old in pairs(before)do local now=f:IsVisible();if now~=old then f:Fire(now and "OnShow"or"OnHide")end end
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
-- Kept, so a label's wrapping and justification can be checked.
function methods:SetWordWrap(v)Guard(self);self.wordWrap=v end
function methods:SetJustifyH(v)Guard(self);self.justifyH=v end
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
local function Session(c,ready,soon,char,setup)
 frames,timers,combat,token={},{},false,c
 UIParent=Frame("Root");UIParent.w=2560/.65;UIParent.h=1440/.65;UIParent.scale=.65
 GameFontHighlight=Frame("Font");GameFontHighlightSmall=GameFontHighlight
 C_Timer={After=function(_,fn)timers[#timers+1]=fn end}
  EraUIDB={};EraUIClassicCharDB=char or {};UISpecialFrames={};SlashCmdList={}
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
  assert(loadfile("Core/Presets.lua"))("EraUI",E)
  assert(loadfile("Modules/CombatFont.lua"))("EraUI",E)
  -- The real Coming soon flags; ready runs the finished features instead.
  assert(loadfile("Modules/AFKScreen.lua"))("EraUI",E)
  assert(loadfile("Modules/BagItemLevels.lua"))("EraUI",E)
  if ready then E.modules.AFKScreen.comingSoon=false;E.modules.BagItemLevels.comingSoon=false end
  -- soon: Bag Item Levels switched back to Coming soon, to check how a Coming soon card behaves.
  if soon then E.modules.BagItemLevels.comingSoon=true end
  E.settingDefaults.darkAuraBorders=true -- as Core/Init.lua; TestPersistence checks the real default
  E.settingDefaults.darkAuraShadows=true -- as Core/Init.lua; TestPersistence checks the real default
  E.settingDefaults.afkScreen=true -- as Core/Init.lua; TestAFKScreen and TestPersistence check the real default
  E.settingDefaults.afkShowQuote=true -- as Core/Init.lua; TestAFKScreen checks the real default
  E.cvarSettings={classIconPortraitMine="ReplaceMyPlayerPortrait",classIconPortraitOthers="ReplaceOtherPlayerPortraits"} -- as Core/Init.lua; TestPersistence checks the real mapping
 assert(loadfile("Core/Settings.lua"))("EraUI",E)
 E.modules.ClassReminders:Initialize()
 E.modules.MageSupplies:Initialize()
 if setup then setup(E)end -- e.g. spies, before settings initialise
 E.modules.Settings:Initialize()
 local f=E.settingsFrame;f.selectedCategory=f.tabIndex.class;f:Show();Flush()
 return E,f
end
-- Tabs by their fixed ids; the numbers are only their place in the list.
local function Tab(f,id)return f.tabIndex[id]end
local function Open(f,id)f.selectedCategory=f.tabIndex[id];f:SetSetupMode(false);Flush()end
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
  Open(f,"frames")
  NoCardOverlaps(f,c.." Frames & Nameplates")
  equal(f.checks.portraitDebuffs:IsShown(),true,c.." portrait setting visible on Frames & Nameplates")
  equal(f.checks.matchFocusSize:IsShown(),true,c.." focus sizing remains visible on Frames & Nameplates")
  -- Dark Aura Borders: heads the Dark Mode extras column on Appearance, on by
  -- default, greyed out until Dark Mode is chosen, applied live.
  do
   local aura,class=f.checks.darkAuraBorders,f.checks.classColourBorders
   equal(aura and aura.category,Tab(f,"appearance"),c.." Dark Aura Borders card under Appearance")
   equal(aura.text:GetText(),"Dark Aura Borders",c.." Dark Aura Borders has a plain label")
   Open(f,"appearance")
   NoCardOverlaps(f,c.." Appearance")
   equal(aura:IsShown()and class:IsShown(),true,c.." both Dark Mode options on the Appearance page")
   local extras=f.sectionLabels["#darkExtras"]
   equal(extras:IsShown()and extras.text:GetText(),"DARK MODE EXTRAS",c.." the Dark Mode extras label shows")
   equal(aura:GetLeft()==extras:GetLeft()and aura:GetTop()<extras:GetBottom()and aura:GetTop()>extras:GetBottom()-10,true,c.." Dark Aura Borders heads the Dark Mode extras column")
   equal(class:GetLeft()==aura:GetLeft()and class:GetTop()<aura:GetBottom(),true,c.." Class-coloured Unit Borders lower in the same column")
   E.settings.darkMode=nil;f:RefreshDependencies()
   equal(aura.dependencyDisabled,true,c.." greyed out while Dark Mode is off")
   equal(aura.dependencyHelp:IsShown(),true,c.." with its explanation on hover")
   aura:SetChecked(true);aura:Fire("OnClick")
   equal(E.settings.darkAuraBorders,nil,c.." cannot be switched on without Dark Mode")
   if c=="DRUID"then
    local lines={}
    GameTooltip={SetOwner=function()end,SetText=function(_,t)lines={t}end,AddLine=function(_,t)lines[#lines+1]=t end,
     Show=function()end,Hide=function()end,IsOwned=function()return true end}
    aura.dependencyHelp:Fire("OnEnter")
    local text=table.concat(lines,"\n")
    equal(text:find("Enable Dark Mode to use this feature.",1,true)~=nil,true,"hover names Dark Mode as the missing option")
    equal(text:find("Needs testing",1,true),nil,"Dark Aura Borders help no longer says Needs testing")
    equal(text:find("On by default, so choosing Dark Mode adds them; switch this off to keep plain icons.",1,true)~=nil,true,"help says choosing Dark Mode adds them")
    equal(text:find("Default: On",1,true)~=nil,true,"help text shows the default as On")
    equal(text:find("reload",1,true)==nil and text:find("—",1,true)==nil,true,"no reload line and no em dash")
    GameTooltip=nil
    -- Choosing Dark Mode in the style buttons makes it available at once.
    local darkChoice
    for _,f2 in ipairs(frames)do if f2.label and f2.label.text=="Dark Mode"then darkChoice=f2 end end
    darkChoice:Fire("OnClick")
    equal(E.settings.darkMode,true,"Dark Mode chosen")
    equal(aura.dependencyDisabled,false,"Dark Aura Borders available once Dark Mode is chosen")
    local refreshed,status=0
    E.modules.AuraStyle={RefreshBorders=function()refreshed=refreshed+1 end}
    local print=E.Status;E.Status=function(_,m)status=m end
    aura:SetChecked(true);aura:Fire("OnClick")
    equal(E.settings.darkAuraBorders,true,"Dark Aura Borders switched on")
    equal(refreshed,1,"applies live through AuraStyle, no reload")
    equal(status,"Dark Aura Borders enabled.","says so in chat")
    aura:SetChecked(false);aura:Fire("OnClick")
    equal(E.settings.darkAuraBorders==false and refreshed,2,"switching off applies live too")
    E.modules.AuraStyle=nil;E.Status=print
    E.settings.darkMode=nil;E.settings.darkAuraBorders=nil;f:RefreshDependencies()
    -- The walkthrough's style page shows it with the class-coloured borders.
    f:SetSetupMode(true);Flush()
    f.setupPreset="classicqol";f.setupPage=2;f:RenderSetup();Flush()
    equal(class:IsShown()and aura:IsShown(),true,"setup style page offers Dark Aura Borders too")
    f:SetSetupMode(false);Flush()
   end
  end
  -- Aura Shadows: its own card directly under Dark Aura Borders, on by
  -- default, greyed out while Dark Mode or Dark Aura Borders is off (every
  -- option up the chain counts), applied live, labelled Needs testing.
  do
   local shade,aura=f.checks.darkAuraShadows,f.checks.darkAuraBorders
   equal(shade and shade.category,Tab(f,"appearance"),c.." Aura Shadows card under Appearance")
   equal(shade.text:GetText(),"Aura Shadows (Needs testing)",c.." Aura Shadows labelled Needs testing where it is switched on")
   Open(f,"appearance")
   NoCardOverlaps(f,c.." Appearance with Aura Shadows")
   equal(shade:IsShown(),true,c.." Aura Shadows on the Appearance page")
   equal(shade:GetLeft()==aura:GetLeft()and shade:GetTop()<aura:GetBottom()and shade:GetTop()>aura:GetBottom()-10,true,c.." Aura Shadows directly under Dark Aura Borders")
   -- Dark Mode off greys it out even while Dark Aura Borders is still ticked.
   E.settings.darkMode=nil;E.settings.darkAuraBorders=true;f:RefreshDependencies()
   equal(shade.dependencyDisabled,true,c.." Aura Shadows greyed while Dark Mode is off, with Dark Aura Borders ticked")
   equal(shade.enabled==false and shade.dependencyHelp:IsShown(),true,c.." disabled, with its explanation on hover")
   shade:SetChecked(true);shade:Fire("OnClick")
   equal(E.settings.darkAuraShadows,nil,c.." Aura Shadows cannot be switched on without Dark Mode")
   E.settings.darkMode=true;E.settings.darkAuraBorders=false;f:RefreshDependencies()
   equal(shade.dependencyDisabled,true,c.." Aura Shadows greyed while Dark Aura Borders is off")
   equal(aura.dependencyDisabled,false,c.." Dark Aura Borders itself available with Dark Mode")
   shade:SetChecked(true);shade:Fire("OnClick")
   equal(E.settings.darkAuraShadows,nil,c.." Aura Shadows cannot be switched on without Dark Aura Borders")
   E.settings.darkAuraBorders=true;f:RefreshDependencies()
   equal(shade.dependencyDisabled==false and shade.enabled==true,true,c.." Aura Shadows available with Dark Mode and Dark Aura Borders")
   equal(shade.dependencyHelp:IsShown(),false,c.." no hover cover once available")
   if c=="DRUID"then
    local lines={}
    GameTooltip={SetOwner=function()end,SetText=function(_,t)lines={t}end,AddLine=function(_,t)lines[#lines+1]=t end,
     Show=function()end,Hide=function()end,IsOwned=function()return true end}
    E.settings.darkMode=nil;f:RefreshDependencies()
    shade.dependencyHelp:Fire("OnEnter")
    local text=table.concat(lines,"\n")
    equal(text:find("Enable Dark Mode to use this feature.",1,true)~=nil,true,"Aura Shadows hover names Dark Mode first, even with Dark Aura Borders ticked")
    E.settings.darkAuraBorders=false;f:RefreshDependencies()
    shade.dependencyHelp:Fire("OnEnter")
    text=table.concat(lines,"\n")
    equal(text:find("Enable Dark Mode to use this feature.",1,true)~=nil,true,"Aura Shadows hover names Dark Mode first with both off")
    E.settings.darkMode=true;f:RefreshDependencies()
    shade.dependencyHelp:Fire("OnEnter")
    text=table.concat(lines,"\n")
    equal(text:find("Enable Dark Aura Borders to use this feature.",1,true)~=nil,true,"Aura Shadows hover names Dark Aura Borders when only it is off")
    equal(text:find("Requires Dark Mode and Dark Aura Borders.",1,true)~=nil,true,"Aura Shadows help names both options it needs")
    equal(text:find("Needs testing",1,true)~=nil,true,"Aura Shadows help says Needs testing")
    equal(text:find("Default: On",1,true)~=nil,true,"Aura Shadows help shows the default as On")
    local card=shade.text:GetText()..text..shade.searchText
    equal(card:find("reload",1,true)==nil and card:find("—",1,true)==nil,true,"Aura Shadows: no reload line and no em dash")
    GameTooltip=nil
    -- Applied live through AuraStyle, with a chat notice.
    E.settings.darkAuraBorders=true;f:RefreshDependencies()
    local refreshed,status=0
    E.modules.AuraStyle={RefreshBorders=function()refreshed=refreshed+1 end}
    local print=E.Status;E.Status=function(_,m)status=m end
    shade:SetChecked(false);shade:Fire("OnClick")
    equal(E.settings.darkAuraShadows,false,"Aura Shadows switched off")
    equal(refreshed,1,"Aura Shadows applies live through AuraStyle, no reload")
    equal(status,"Aura Shadows disabled.","Aura Shadows says so in chat")
    shade:SetChecked(true);shade:Fire("OnClick")
    equal(E.settings.darkAuraShadows==true and refreshed,2,"switching Aura Shadows on applies live too")
    equal(status,"Aura Shadows enabled.","Aura Shadows on says so in chat")
    -- Clicking Dark Aura Borders off greys Aura Shadows at once, and back on.
    aura:SetChecked(false);aura:Fire("OnClick")
    equal(E.settings.darkAuraBorders,false,"Dark Aura Borders clicked off")
    equal(shade.dependencyDisabled==true and shade.enabled==false and shade.dependencyHelp:IsShown(),true,"clicking Dark Aura Borders off greys Aura Shadows at once")
    aura:SetChecked(true);aura:Fire("OnClick")
    equal(E.settings.darkAuraBorders,true,"Dark Aura Borders clicked on")
    equal(shade.dependencyDisabled==false and shade.enabled==true and not shade.dependencyHelp:IsShown(),true,"and clicking it on makes Aura Shadows available at once")
    -- Dark Mode saved but not loaded yet: says when they show.
    local get=E.GetSetting
    E.GetSetting=function(self,key)if key=="darkMode"then return false end;return get(self,key)end
    shade:SetChecked(false);shade:Fire("OnClick");shade:SetChecked(true);shade:Fire("OnClick")
    equal(status,"Aura Shadows enabled. They show once Dark Mode is applied.","Aura Shadows waits for Dark Mode to be applied")
    E.GetSetting=get;E.modules.AuraStyle=nil;E.Status=print
    -- The walkthrough's style page shows it under Dark Aura Borders.
    E.settings.darkMode=nil;E.settings.darkAuraBorders=nil;E.settings.darkAuraShadows=nil;f:RefreshDependencies()
    f:SetSetupMode(true);Flush()
    f.setupPreset="classicqol";f.setupPage=2;f:RenderSetup();Flush()
    equal(aura:IsShown()and shade:IsShown(),true,"setup style page offers Aura Shadows too")
    equal(shade:GetLeft()==aura:GetLeft()and shade:GetTop()<aura:GetBottom(),true,"setup style page: Aura Shadows under Dark Aura Borders")
    equal(shade.dependencyDisabled,true,"setup style page: greyed until Dark Mode is chosen")
    NoCardOverlaps(f,"setup style page")
    -- Every other walkthrough page keeps the Appearance cards away, and the
    -- quality-of-life preset has no style page at all.
    for _,preset in ipairs({"classicqol","classic","qol"})do
     f.setupPreset=preset
     local checked=0
     for page=1,40 do
      f.setupPage=page;f:RenderSetup();Flush()
      if f.setupPage<page then break end
      checked=checked+1
      if not(preset~="qol"and page==2)then
       equal(shade:IsShown()or aura:IsShown()or f.checks.classColourBorders:IsShown(),false,"setup "..preset.." page "..page..": no Appearance cards")
      end
     end
     equal(checked>=3,true,"setup "..preset..": every page checked")
    end
    f:SetSetupMode(false);Flush()
   end
   E.settings.darkMode=nil;E.settings.darkAuraBorders=nil;E.settings.darkAuraShadows=nil;f:RefreshDependencies()
  end
  -- Class-coloured Tooltips: in the class colours column on Appearance, under
  -- Class-coloured Chat Names, available with the Tooltips skin on or off,
  -- applied live.
  do
   local card,chat=f.checks.tooltipClassColours,f.checks.classColors
   equal(card and card.category,Tab(f,"appearance"),c.." Class-coloured Tooltips card on Appearance")
   equal(card.text:GetText(),"Class-coloured Tooltips",c.." Class-coloured Tooltips has a plain label")
   Open(f,"appearance")
   NoCardOverlaps(f,c.." Appearance with class colours")
   equal(card:IsShown(),true,c.." Class-coloured Tooltips shown on Appearance")
   local colours=f.sectionLabels["#classColours"]
   equal(colours:IsShown()and colours.text:GetText(),"CLASS COLOURS",c.." the class colours label shows")
   equal(chat:GetLeft()==colours:GetLeft()and chat:GetTop()<colours:GetBottom()and chat:GetTop()>colours:GetBottom()-10,true,c.." Class-coloured Chat Names heads the class colours column")
   equal(card:GetLeft()==chat:GetLeft()and card:GetTop()<chat:GetBottom(),true,c.." Class-coloured Tooltips under Class-coloured Chat Names")
   equal(card.dependencyHelp,nil,c.." Class-coloured Tooltips needs no other option")
   equal(card:GetParent()==f.settingsContent and card:GetBottom()>=f.settingsScroll:GetBottom()-.01,true,c.." shown without scrolling")
   if c=="DRUID"then
    local lines={}
    GameTooltip={SetOwner=function()end,SetText=function(_,t)lines={t}end,AddLine=function(_,t)lines[#lines+1]=t end,
     Show=function()end,Hide=function()end,IsOwned=function()return true end}
    card:Fire("OnEnter")
    local text=table.concat(lines,"\n")
    equal(lines[1],"Class-coloured Tooltips","tooltip title")
    equal(text:find("Needs testing",1,true),nil,"Class-coloured Tooltips help no longer says Needs testing")
    equal(text:find("rogue's name and \"Rogue\" in rogue yellow",1,true)~=nil,true,"help gives the rogue example")
    equal(text:find("Classic tooltips or the game's own",1,true)~=nil,true,"help says it works with or without the Classic skin")
    equal(text:find("Default: Off",1,true)~=nil,true,"Class-coloured Tooltips default shown as Off")
    equal(text:find("Requires /reload",1,true)==nil and text:find("—",1,true)==nil,true,"no reload line and no em dash")
    GameTooltip=nil
    local refreshed,status=0
    E.modules.AuraStyle={RefreshClassTooltips=function()refreshed=refreshed+1 end}
    local print=E.Status;E.Status=function(_,m)status=m end
    card:SetChecked(true);card:Fire("OnClick")
    equal(E.settings.tooltipClassColours,true,"Class-coloured Tooltips switched on")
    equal(refreshed,1,"applies live through AuraStyle, no reload")
    equal(status,"Class-coloured Tooltips enabled. Hover a player to see it.","says so in chat")
    card:SetChecked(false);card:Fire("OnClick")
    equal(E.settings.tooltipClassColours==false and refreshed,2,"switching off applies live too")
    equal(status,"Class-coloured Tooltips disabled.","says it is off")
    E.modules.AuraStyle=nil;E.Status=print;E.settings.tooltipClassColours=nil
   end
  end
  -- Bag Item Levels: its own card in Bags & Vendors, under Bags & Bank,
  -- needing no other option, off by default, switched on and off live.
  do
   local card,bags=f.checks.bagItemLevels,f.checks.bagsBank
   equal(card and card.category,Tab(f,"bags"),c.." Bag Item Levels card in Bags & Vendors")
   equal(card.text:GetText(),"Bag Item Levels",c.." Bag Item Levels label, confirmed in game")
   Open(f,"bags")
   NoCardOverlaps(f,c.." Bags & Vendors")
   equal(card:IsShown(),true,c.." Bag Item Levels shown in Bags & Vendors")
   equal(card:GetLeft()==bags:GetLeft()and card:GetTop()<bags:GetBottom()and card:GetTop()>bags:GetBottom()-10,true,c.." Bag Item Levels directly under Bags & Bank")
   equal(card.dependencyHelp,nil,c.." Bag Item Levels needs no other option")
   equal(card:GetParent()==f.settingsContent and card:GetBottom()>=f.settingsContent:GetBottom()-.01,true,c.." Bags & Vendors page scrolls far enough for the card")
   equal(card.unavailable==false and card.enabled~=false,true,c.." Bag Item Levels can be switched, no longer coming soon")
   equal(card.state:GetText(),"OFF",c.." off by default, and its switch says OFF")
   equal(card:GetChecked()and true or false,false,c.." shown off")
   equal(card.searchText:find("quality colours",1,true)~=nil,true,c.." its summary mentions the quality colours")
   if c=="DRUID"then
    local lines={}
    GameTooltip={SetOwner=function()end,SetText=function(_,t)lines={t}end,AddLine=function(_,t)lines[#lines+1]=t end,
     Show=function()end,Hide=function()end,IsOwned=function()return true end}
    card:Fire("OnEnter")
    local text=table.concat(lines,"\n")
    equal(lines[1],"Bag Item Levels","Bag Item Levels tooltip title")
    equal(text:find("Coming soon",1,true),nil,"hover no longer says coming soon")
    equal(text:find("Needs testing",1,true),nil,"hover no longer says Needs testing")
    equal(text:find("big number at the bottom right, in the item's quality colour",1,true)~=nil,true,"hover describes the big quality-coloured number")
    equal(text:find("small green arrow at the top right",1,true)~=nil,true,"hover says where the arrow is")
    equal(text:find("not bags, quivers, ammo, shirts or tabards",1,true)~=nil,true,"hover says which items get no number")
    equal(text:find("not the bank yet",1,true)~=nil,true,"hover says the bank isn't covered yet")
    equal(text:find("Default: Off",1,true)~=nil and text:find("Off by default.",1,true)~=nil,true,"Bag Item Levels default shown as Off")
    equal(text:find("Requires /reload",1,true),nil,"applies without a reload")
    equal(text:find("\226\128\148",1,true),nil,"no em dash")
    GameTooltip=nil
    local real,refreshed,status=E.modules.BagItemLevels,0
    E.modules.BagItemLevels={Refresh=function()refreshed=refreshed+1 end}
    local say=E.Status;E.Status=function(_,m)status=m end
    card:SetChecked(true);card:Fire("OnClick")
    equal(E.settings.bagItemLevels,true,"Bag Item Levels switched on")
    equal(refreshed,1,"applies live through its module, no reload")
    equal(status,"Bag Item Levels enabled. Open your bags to see it.","says so in chat")
    card:SetChecked(false);card:Fire("OnClick")
    equal(E.settings.bagItemLevels==false and refreshed,2,"switching off applies live too")
    -- A choice saved earlier is kept and shown.
    E.settings.bagItemLevels=true;f:Hide();f:Show();Flush()
    equal(card:GetChecked()and true or false,true,"a saved on shows on")
    equal(card.state:GetText(),"ON","and ON")
    E.settings.bagItemLevels=nil;f:Hide();f:Show();Flush()
    E.modules.BagItemLevels=real;E.Status=say
   end
  end
  for _,id in ipairs({"bags","screen"})do
   Open(f,id)
   NoCardOverlaps(f,c.." "..id)
   equal(f.settingsContent:GetHeight()>f.settingsScroll:GetHeight(),true,c.." "..id.." is the one long page that scrolls")
  end
  -- AFK Screen: on by default. Its card and its eight options sit in Screen &
  -- Cursor, not folded; the options are greyed out while it is off.
  do
   local afk=f.checks.afkScreen
   equal(afk and afk.category,Tab(f,"screen"),c.." AFK Screen card in Screen & Cursor")
   equal(afk.text:GetText(),"AFK Screen",c.." AFK Screen label, confirmed in game")
   equal(afk.unavailable==false and afk.enabled~=false,true,c.." AFK Screen can be switched")
   equal(afk.state:GetText()~="SOON",true,c.." AFK Screen no longer says SOON")
   equal(afk.searchText:find("try /era afk",1,true)~=nil,true,c.." its summary offers the /era afk preview")
   Open(f,"screen")
   NoCardOverlaps(f,c.." Screen & Cursor with every AFK card")
   equal(afk:IsShown(),true,c.." AFK Screen card shown")
   for _,key in ipairs({"afkCameraNormal","afkTurnRight","afkZoom","afk24Hour","afkShowGuild","afkShowZone","afkShowDate","afkShowQuote"})do
    local card=f.checks[key]
    equal(card and card.category,Tab(f,"screen"),c.." "..key.." card in Screen & Cursor")
    equal(card:IsShown()and card.unavailable==false,true,c.." "..key.." shown and available")
    equal(card:GetParent()==f.settingsContent and card:GetBottom()>=f.settingsContent:GetBottom()-.01,true,c.." "..key.." within the page's scroll")
   end
   -- Class Quote: the eighth option, directly under Show Zone, on by default.
   -- AFK Screen starts its row, so its options follow it from the left.
   do
    local quote,zone,date=f.checks.afkShowQuote,f.checks.afkShowZone,f.checks.afkShowDate
    equal(quote.text:GetText(),"AFK Screen: Class Quote",c.." Class Quote label follows the other AFK options")
    equal(quote:GetLeft()==zone:GetLeft()and quote:GetTop()<zone:GetBottom()and quote:GetTop()>zone:GetBottom()-10,true,c.." Class Quote directly under Show Zone")
    equal(date:GetTop()==zone:GetTop()and date:GetLeft()>zone:GetRight()and quote:GetTop()<date:GetBottom(),true,c.." Class Quote after Show Date, the last AFK option")
    equal(math.abs(afk:GetLeft()-f.settingsContent:GetLeft())<.01 and f.checks.afkCameraNormal:GetTop()==afk:GetTop(),true,c.." AFK Screen in the left column, its first option beside it")
    equal(quote.searchText:find("quote",1,true)~=nil and quote.searchText:find("class",1,true)~=nil,true,c.." Class Quote found by searching quote or class")
   end
   E.settings.afkScreen=nil;f:RefreshDependencies()
   equal(afk.dependencyDisabled,nil,c.." AFK Screen itself is never greyed out by another option")
   equal(f.checks.afkZoom.dependencyDisabled,true,c.." its options greyed out while it is off")
   equal(f.checks.afkShowQuote.dependencyDisabled,true,c.." Class Quote greyed out while it is off")
   if c=="DRUID"then
    local lines={}
    GameTooltip={SetOwner=function()end,SetText=function(_,t)lines={t}end,AddLine=function(_,t)lines[#lines+1]=t end,
     Show=function()end,Hide=function()end,IsOwned=function()return true end}
    afk:Fire("OnEnter")
    local text=table.concat(lines,"\n")
    equal(lines[1],"AFK Screen","AFK Screen tooltip title")
    equal(text:find("Coming soon",1,true),nil,"hover no longer says coming soon")
    equal(text:find("Needs testing",1,true),nil,"hover no longer says Needs testing")
    equal(text:find("the interface and the minimap fade away",1,true)~=nil,true,"hover says the minimap goes too")
    equal(text:find("Your character stays still while the camera slowly circles.",1,true)~=nil,true,"hover says the character stays still")
    equal(text:find("On by default.",1,true)~=nil and text:find("Default: On",1,true)~=nil,true,"on by default")
    equal(text:find("\226\128\148",1,true),nil,"no em dash")
    equal(text:find("a famous line for your class",1,true)~=nil,true,"hover mentions the class quote")
    lines={};f.checks.afkShowQuote.dependencyHelp:Fire("OnEnter")
    text=table.concat(lines,"\n")
    equal(lines[1],"AFK Screen: Class Quote","Class Quote tooltip title")
    equal(text:find("Enable AFK Screen to use this feature.",1,true)~=nil,true,"Class Quote hover names the AFK Screen while it is off")
    equal(text:find("A famous line from World of Warcraft Classic for your class, like a loading-screen tip. A new one each time you're away.",1,true)~=nil,true,"Class Quote hover help says it needs testing")
    equal(text:find("Default: On",1,true)~=nil,true,"Class Quote on by default")
    equal(text:find("\226\128\148",1,true)==nil and text:find("reload",1,true)==nil,true,"Class Quote: no em dash, no reload")
    GameTooltip=nil
    local real,refreshed,status=E.modules.AFKScreen,0
    E.modules.AFKScreen={Refresh=function()refreshed=refreshed+1 end}
    local say=E.Status;E.Status=function(_,m)status=m end
    afk:SetChecked(true);afk:Fire("OnClick")
    equal(E.settings.afkScreen,true,"AFK Screen switched on")
    equal(refreshed,1,"applies live through its module, no reload")
    equal(status,"AFK Screen enabled. Type /era afk to preview it.","says so in chat")
    equal(f.checks.afkZoom.dependencyDisabled,false,"its options available once it is on")
    local quote=f.checks.afkShowQuote
    equal(quote.dependencyDisabled,false,"Class Quote available once it is on")
    quote:SetChecked(false);quote:Fire("OnClick")
    equal(E.settings.afkShowQuote==false and refreshed,2,"Class Quote off applies live through the AFK Screen")
    equal(status,"AFK Screen: Class Quote disabled.","says so in chat")
    quote:SetChecked(true);quote:Fire("OnClick")
    equal(E.settings.afkShowQuote==true and refreshed,3,"and back on")
    E.settings.afkShowQuote=nil
    afk:SetChecked(false);afk:Fire("OnClick")
    equal(E.settings.afkScreen==false and refreshed,4,"switching off applies live too")
    E.modules.AFKScreen=real;E.Status=say;E.settings.afkScreen=nil;f:RefreshDependencies()
    local printed={}
    local print=E.Print;E.Print=function(_,m)printed[#printed+1]=m end
    SlashCmdList.ERAUI("afk");Flush()
    equal(printed[1],"Turn on AFK Screen in /era > Screen & Cursor first.","/era afk reaches the real preview")
    printed={};SlashCmdList.ERAUI("help")
    equal(printed[1]~=nil and printed[1]:find("/era afk previews the AFK screen.",1,true)~=nil,true,"/era help lists /era afk")
    E.Print=print
   end
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
  Open(f,"class")
  Fits(f,c.." collapsed")
  local p=E.modules.ClassReminders:OptionsPanel()
  equal(f.checks.classTools:IsShown(),c=="HUNTER"or c=="MAGE"or c=="ROGUE",c.." only useful tool cards shown")
  equal(p.group:IsShown(),c~="ROGUE"and c~="SHAMAN",c.." group checking matches supported reminders")
  equal(p.clickable:IsShown(),c~="ROGUE",c.." reminder clicking matches supported actions")
  -- Click pet reminders in combat: pet classes only, its label fits, and it
  -- waits for Clickable reminders.
  equal(p.combatClick:IsShown(),c=="HUNTER"or c=="WARLOCK",c.." pet clicks in combat only for pet classes")
  equal(p.combatClick.label:GetStringWidth()<=p.combatClick.label:GetWidth(),true,c.." its label fits its width")
  equal(p.combatClick.dependencyDisabled,true,c.." greyed out until Clickable reminders is on")
  if p.combatClick:IsShown()then
   equal(p.combatClick:GetTop()<=p.clickable:GetBottom()+.01 and p.mana:GetTop()<=p.combatClick:GetBottom()+.01,true,c.." it sits between Clickable reminders and the mana note")
   equal(p.combatClick:GetLeft()>=p:GetLeft()+11.99 and p.combatClick:GetRight()<=p:GetRight()+.01,true,c.." it fits the panel")
  end
  if c=="HUNTER"or c=="MAGE"then
   equal(f.checks.classTools.kind,"Frame",c.." inline heading is not a button")
   equal(f.checks.classTools.scripts.OnClick,nil,c.." inline heading has no click action")
  end
 p.adv:Fire("OnClick");Flush();Fits(f,c.." expanded")
 -- PET LOW HEALTH!: a whole line whose label and Below button fit.
 local low
 for _,row in ipairs(p.advRows)do if row.label:GetText()=="PET LOW HEALTH!"then low=row end end
 equal(low~=nil,c=="HUNTER"or c=="WARLOCK",c.." pet low health switch only for pet classes")
 if low then
  equal(low:IsShown()and low:GetLeft()>=p:GetLeft()+11.99 and low:GetRight()<=p:GetRight()+.01,true,c.." pet low health line fits the panel")
  equal(low.label:GetStringWidth()<=low.label:GetWidth(),true,c.." its label fits its width")
  equal(low.label:GetRight()<=low.limit:GetLeft()-4,true,c.." its label clears the Below button")
  equal(low.limit:GetRight()<=low.track:GetLeft()-4,true,c.." the Below button clears the switch")
  equal(low.limit.label:GetStringWidth()<=low.limit:GetWidth()-8,true,c.." the Below button's text fits")
  for _,row in ipairs(p.advRows)do
   if row~=low and row:IsShown()then
    equal(row:GetTop()<=low:GetBottom()+.01 or row:GetBottom()>=low:GetTop()-.01,true,c.." nothing shares the pet low health line")
   end
  end
 end
 -- SEAL! and AURA!: whole lines too, with the choice button in
 -- the line. The label and every choice's text fit.
 local choiceLines=0
 for _,row in ipairs(p.advRows)do
  local cb=row.choice
  if cb then
   choiceLines=choiceLines+1
   local name=c.." "..row.label:GetText()
   equal(row.label:GetText()=="SEAL!"or row.label:GetText()=="AURA!",true,name.." has a plain label")
   equal(row:IsShown()and row:GetLeft()>=p:GetLeft()+11.99 and row:GetRight()<=p:GetRight()+.01,true,name.." line fits the panel")
   equal(row.label:GetStringWidth()<=row.label:GetWidth(),true,name.." label fits its width")
   equal(row.label:GetRight()<=cb:GetLeft()-4,true,name.." label clears the choice button")
   equal(cb:IsShown()and cb:GetRight()<=row.track:GetLeft()-4,true,name.." choice button clears the switch")
   for _,def in ipairs(E.ReminderSpells.PALADIN)do
    if row.label:GetText()==def.text then
     for _,choice in ipairs(def.choices)do
      cb.label:SetText(choice.name.."  >")
      equal(cb.label:GetStringWidth()<=cb:GetWidth()-8,true,name.." "..choice.name.." fits its button")
     end
    end
   end
   cb.draw()
   for _,other in ipairs(p.advRows)do
    if other~=row and other:IsShown()then
     equal(other:GetTop()<=row:GetBottom()+.01 or other:GetBottom()>=row:GetTop()-.01,true,name.." shares its line with nothing")
    end
   end
  end
 end
 equal(choiceLines,c=="PALADIN"and 2 or 0,c.." whole choice lines only for SEAL! and AURA!")
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
  equal(f.selectedCategory,Tab(f,"class"),label.." class tab selected")
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

-- Coming soon features as they will be once finished: the same cards switch
-- on and apply live through their modules.
do
 local E,f=Session("DRUID",true)
 local c="DRUID ready"
 -- Bag Item Levels, beside Click Links Again to Close.
 do
  local card=f.checks.bagItemLevels
  Open(f,"bags")
  equal(card.unavailable,false,"finished: Bag Item Levels is not coming soon")
  equal(card.enabled~=false and card.state:GetText()=="OFF",true,"finished: its switch works and shows OFF")
  local lines={}
  GameTooltip={SetOwner=function()end,SetText=function(_,t)lines={t}end,AddLine=function(_,t)lines[#lines+1]=t end,
   Show=function()end,Hide=function()end,IsOwned=function()return true end}
  card:Fire("OnEnter")
  local text=table.concat(lines,"\n")
  equal(lines[1],"Bag Item Levels","Bag Item Levels tooltip title")
  equal(text:find("Coming soon",1,true),nil,"no Coming soon line")
  equal(text:find("Upgrade means item level only for now",1,true)~=nil,true,"help says an upgrade is item level only for now")
  equal(text:find("weaker of the two you wear",1,true)~=nil,true,"help explains rings, trinkets and one-hand weapons")
  equal(text:find("tinted red, using the game's own check",1,true)~=nil,true,"help explains the red can't-equip mark")
  equal(text:find("One bag",1,true)~=nil,true,"help says it works with One bag")
  equal(text:find("Default: Off",1,true)~=nil,true,"Bag Item Levels default shown as Off")
  equal(text:find("Requires /reload",1,true)==nil and text:find("\226\128\148",1,true)==nil,true,"no reload line and no em dash")
  GameTooltip=nil
  local refreshed,status=0
  E.modules.BagItemLevels={Refresh=function()refreshed=refreshed+1 end}
  local print=E.Status;E.Status=function(_,m)status=m end
  card:SetChecked(true);card:Fire("OnClick")
  equal(E.settings.bagItemLevels,true,"Bag Item Levels switched on")
  equal(refreshed,1,"applies live through its module, no reload")
  equal(status,"Bag Item Levels enabled. Open your bags to see it.","says so in chat")
  card:SetChecked(false);card:Fire("OnClick")
  equal(E.settings.bagItemLevels==false and refreshed,2,"switching off applies live too")
  equal(status,"Bag Item Levels disabled.","says it is off")
  E.modules.BagItemLevels=nil;E.Status=print;E.settings.bagItemLevels=nil
  -- The walkthrough's Bags & Vendors page offers it too.
  f:SetSetupMode(true);Flush()
  f.setupPreset="classicqol";f.setupPage=7;f:RenderSetup();Flush()
  equal(f.setupProgress:GetText(),"OPTIONS  4 / 7","walkthrough on its Bags & Vendors page")
  equal(f.sectionTitle:GetText(),"Bags & Vendors","the page is named after its tab")
  equal(card:IsShown(),true,"the walkthrough's Bags & Vendors page offers Bag Item Levels")
  f:SetSetupMode(false);Flush()
 end
 -- AFK Screen: its own cards in Screen & Cursor, options greyed out until it is on.
 do
  local printed={}
  local print=E.Print;E.Print=function(_,m)printed[#printed+1]=m end
  SlashCmdList.ERAUI("help")
  equal(printed[1]~=nil and printed[1]:find("/era afk previews the AFK screen.",1,true)~=nil,true,"finished: /era help lists /era afk")
  E.Print=print
  equal(f.checks.afkScreen.unavailable,false,"finished: AFK Screen is not coming soon")
  equal(f.checks.afkScreen.searchText:find("try /era afk",1,true)~=nil,true,"finished: its summary offers /era afk")
  Open(f,"screen")
  NoCardOverlaps(f,c.." Screen & Cursor with every AFK card")
  for _,key in ipairs({"afkScreen","afkCameraNormal","afkTurnRight","afkZoom","afk24Hour","afkShowGuild","afkShowZone","afkShowDate","afkShowQuote"})do
   equal(f.checks[key]and f.checks[key].category,Tab(f,"screen"),c.." "..key.." card in Screen & Cursor")
  end
  f:RefreshDependencies()
  equal(f.checks.afkZoom.dependencyDisabled,true,c.." AFK options greyed out while AFK Screen is off")
  equal(f.checks.afkScreen.dependencyDisabled,nil,c.." AFK Screen itself is never greyed out")
  local refreshed=0;E.modules.AFKScreen={Refresh=function()refreshed=refreshed+1 end}
  f.checks.afkScreen:SetChecked(true);f.checks.afkScreen:Fire("OnClick")
  equal(E.settings.afkScreen,true,"AFK Screen switched on")
  equal(refreshed,1,"AFK Screen applies live, no reload")
  equal(f.checks.afkZoom.dependencyDisabled,false,"AFK options available once it is on")
  f.checks.afkShowDate:SetChecked(false);f.checks.afkShowDate:Fire("OnClick")
  equal(E.settings.afkShowDate==false and refreshed,2,"AFK display options apply live too")
  E.modules.AFKScreen=nil;E.settings.afkScreen=nil;E.settings.afkShowDate=nil;f:RefreshDependencies()
 end
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

-- Setup walkthrough: presets come first, the pages that follow depend on the
-- preset, and a quest tracker step appears only with Questie installed.
do
 local E,f=Session("DRUID")
 local P=E.Presets
 -- As in the addon: the Classic skins are reload settings, loaded as on.
 for _,key in ipairs(P.LOOK)do E.settings[key]=true;E.reloadSettings[key]=true;f.loadedSettings[key]=true end
 local reloads=0
 ReloadUI=function()reloads=reloads+1 end
 local function Next()f.setupNext:Fire("OnClick");Flush()end
 local function Final()return f.setupNext.label:GetText()~="Next >"end
 -- Clicks from the first page to the finish page.
 local function Steps()
  local steps=0
  while not Final()and steps<20 do Next();steps=steps+1 end
  return steps
 end
 local function Restart()f:SetSetupMode(false);Flush();f:SetSetupMode(true);Flush()end

 f:SetSetupMode(true);Flush()
 local choices=f.presetChoices
 equal(#choices,3,"three presets on the first page")
 equal(choices[1]:IsShown()and choices[2]:IsShown()and choices[3]:IsShown(),true,"presets are the first page")
 equal(choices[1].label:GetText(),"Classic + Quality of Life","preset names fit without a Selected: prefix");equal(choices[1].tag:IsShown(),true,"the Classic look starts on Classic + Quality of Life");equal(choices[2].tag:IsShown(),false,"only one preset tagged")
 equal(choices[3]:GetRight()<=f:GetRight(),true,"third preset fits inside the walkthrough")
 equal(f.presetButton:IsShown(),false,"no Presets button during the walkthrough")
 Next()
 equal(f.checks.classColourBorders:IsShown(),true,"Classic + QoL: style page next")
 f.setupBack:Fire("OnClick");Flush()
 equal(Steps(),10,"Classic + QoL without Questie: style, damage text, seven option pages, finish")
 -- A new damage font waits for a log out: the finish page asks whether to
 -- log out now, with a secure button that never holds on to the window.
 E.settings.damageFont="pepsi";E.combatFontAtLoad=nil;E:ApplyCombatFont()
 f:RenderSetup()
 equal(f.fontQuestion:IsShown(),false,"no question with the font the game loaded")
 E:SetSetting("damageFont","bangers");E:ApplyCombatFont()
 f:RenderSetup()
 equal(f.fontQuestion:IsShown(),true,"a new font: asked whether to log out now")
 local logout=EraUISetupLogout
 equal(logout:IsShown()and logout.attributes.type1=="macro"and logout.attributes.macrotext1,"/logout","Yes logs out through the game's own secure macro")
 local loose=logout.parent==UIParent
 for _,p in ipairs(logout.points)do if p[2]~=UIParent then loose=false end end
 equal(loose,true,"laid over its spot on the screen, not joined to the window")
 f.logoutWatch:Fire("OnEvent","PLAYER_REGEN_DISABLED")
 equal(logout:IsShown(),false,"hidden as combat starts")
 combat=true;f:Hide();f:Show();combat=false
 f.logoutWatch:Fire("OnEvent","PLAYER_REGEN_ENABLED")
 equal(logout:IsShown(),true,"the window closed and opened in combat, and the button came back after")
 EraUIClassicCharDB.onboarding=nil
 logout:Fire("PreClick")
 equal(EraUIClassicCharDB.onboarding.exploreSettings,true,"logging out finishes setup first")
 local hints=EraUIClassicCharDB.onboarding
 equal(hints.discoveryHintsVersion==2 and hints.discoverTabs[f.tabIndex.class]==true and hints.discoverTabs[f.tabIndex.casting]==true and hints.discoverTabs[12]==nil,true,"finishing setup saves the class and Casting hints in the new order")
 f.fontLaterButton:Fire("OnClick")
 equal(f.fontQuestion:IsShown()or logout:IsShown(),false,"No, later puts it off")
 equal(f.setupSummary:GetText():find("Your new damage font shows next time you log in.",1,true)~=nil,true,"and says when it'll show")
 E:SetSetting("damageFont","pepsi");E:ApplyCombatFont();f.fontLater=nil
 f:RenderSetup()
 equal(f.fontQuestion:IsShown()or f.setupSummary:GetText():find("log in",1,true)~=nil,false,"picking the loaded font again clears it")
 -- Explore settings instead of answering: the question and its button stay
 -- in setup, and No, later never draws setup pages over /era.
 E:SetSetting("damageFont","bangers");E:ApplyCombatFont();f:RenderSetup()
 equal(f.fontQuestion:IsVisible()and logout:IsShown(),true,"asked again with a new font")
 f.setupNext:Fire("OnClick");Flush()
 equal(f.setupMode or reloads>0,false,"Explore settings leaves setup without a reload")
 equal(f:IsShown()and f.presetButton:IsShown(),true,"the normal /era window opens")
 equal(f.fontQuestion:IsShown()or logout:IsShown(),false,"no question or log out button left in /era")
 f.fontLaterButton:Fire("OnClick");Flush()
 equal(f.setupNext:IsShown()or f.setupBack:IsShown(),false,"No, later does nothing outside setup")
 -- Closing the window on the finish page: the button stays away after fights.
 Restart();Steps()
 equal(f.fontQuestion:IsVisible()and logout:IsShown(),true,"asked again after rerunning setup")
 f:Hide()
 equal(logout:IsShown(),false,"closing the window hides the log out button")
 f.logoutWatch:Fire("OnEvent","PLAYER_REGEN_DISABLED");f.logoutWatch:Fire("OnEvent","PLAYER_REGEN_ENABLED")
 f:Fire("OnDragStop");Flush()
 equal(logout:IsShown(),false,"and it stays hidden after the next fight")
 SlashCmdList.ERAUI("");Flush()
 equal(f:IsShown()and not f.setupMode,true,"/era then opens the normal settings")
 equal(f.fontQuestion:IsShown()or logout:IsShown(),false,"without the question or its button")
 -- Leaving setup in combat never touches the secure button, and it stays
 -- hidden once the fight ends.
 Restart();Steps()
 equal(logout:IsShown(),true,"asked on the finish page once more")
 f.logoutWatch:Fire("OnEvent","PLAYER_REGEN_DISABLED");combat=true
 SlashCmdList.ERAUI("");Flush()
 combat=false;f.logoutWatch:Fire("OnEvent","PLAYER_REGEN_ENABLED");Flush()
 equal(f.fontQuestion:IsShown()or logout:IsShown(),false,"leaving setup in combat keeps it hidden after")
 E:SetSetting("damageFont","pepsi");E:ApplyCombatFont()

 Restart()
 Next();Next()
 equal(f.checks.damageFont:IsShown()and f.checks.damageTextScale:IsShown(),true,"damage text page after the style page")
 equal(f.settingsEntries[1]==f.checks.damageFont and f.settingsEntries[2],f.checks.damageTextScale,"font and size side by side")
 equal(f.setupProgress:GetText(),"DAMAGE TEXT","its step is named")
 local oldCVar=C_CVar;C_CVar={GetCVar=function(name)return name=="WorldTextScale_v2"and"1"or nil end,SetCVar=function()end}
 local scale=f.checks.damageTextScale
 scale:SetChecked()
 equal(scale.slider:IsShown(),true,"the size found under the game's newer name")
 scale.slider:SetValue(250)
 local big=scale.preview.font[2]
 scale.slider:SetValue(50)
 equal(big>scale.preview.font[2]and scale.preview:GetText(),"1234","a sample number grows and shrinks with the size")
 C_CVar=oldCVar
 Next()
 equal(f.sectionTitle:GetText(),"Action Bars","the first options page is Action Bars")
 equal(f.checks.hideKeybindText:IsShown()and f.checks.showAllSpellRanks:IsShown(),true,"Action Bars offers keybind text and, joining it, Show All Spell Ranks")
 equal(f.checks.actionBars:IsShown(),false,"but not the reload-only Action Bars look")
 Next();Next();Next();Next();Next();Next()
 equal(f.sectionTitle:GetText(),"Screen & Cursor","the last options page is Screen & Cursor")
 equal(f.checks.cursorRing:IsShown()and f.checks.afkScreen:IsShown(),true,"with the cursor effects and the AFK Screen")
 equal(f.checks.damageFont:IsShown()or f.checks.damageTextScale:IsShown(),false,"the damage text cards aren't repeated there")

 Restart()
 choices[2]:Fire("OnClick");Flush()
 equal(choices[2].tag:IsShown()and not choices[1].tag:IsShown(),true,"Classic look only selected")
 equal(Steps(),3,"Classic look only: style page, damage text, then finish; QoL pages skipped")

 Restart()
 E.settings.vendorPrice=true;E.settings.darkMode=true
 choices[3]:Fire("OnClick");Flush()
 equal(E.settings.unitFrames,false,"QoL only switches the Classic look off")
 equal(E.settings.darkMode,false,"and the optional Classic looks")
 equal(E.settings.vendorPrice,true,"quality-of-life options stay as they are")
 Next()
 equal(f.checks.classColourBorders:IsShown(),false,"QoL only: no style page")
 f.setupBack:Fire("OnClick");Flush()
 equal(Steps(),9,"QoL only: damage text, seven option pages, then finish")
 equal(f.setupNext.label:GetText(),"Reload & explore","switching the look asks for the final reload")

 -- Questie installed: the tracker step follows the style page.
 local choice,reloadNeeded="",false
 E.modules.QuestTrackerChoice={
  QuestieInstalled=function()return true end,
  CurrentChoice=function()return choice end,
  SetChoice=function(_,c)choice=c;reloadNeeded=c=="classic"end,
  NeedsReload=function()return reloadNeeded end,
 }
 Restart()
 equal(choices[3].tag:IsShown(),true,"the modern look starts on Quality of Life only")
 Next()
 equal(f.trackerChoices[1]:IsShown(),false,"QoL only has no tracker step")
 f.setupBack:Fire("OnClick");Flush()
 choices[1]:Fire("OnClick");Flush()
 equal(E.settings.unitFrames,true,"Classic + QoL switches the Classic look back on")
 Next();Next()
 equal(f.trackerChoices[1]:IsShown(),true,"tracker step after the style page")
 equal(f.trackerChoices[1]:GetLeft()-f:GetLeft(),30,"the tracker choices start at the walkthrough's edge")
 f.trackerChoices[1]:Fire("OnClick");Flush()
 equal(choice,"classic","tracker choice applied")
 f.setupBack:Fire("OnClick");Flush();f.setupBack:Fire("OnClick");Flush()
 equal(Steps(),11,"Classic + QoL with Questie: style, tracker, damage text, seven option pages, finish")
 f.setupNext:Fire("OnClick")
 equal(reloads,1,"finish reloads straight from the click")
 f:SetSetupMode(false);Flush()
 equal(f.trackerChoices[1]:IsShown()or choices[1]:IsShown(),false,"walkthrough choices hidden outside setup")
 -- Outside setup they sit where the pages start, never under the tab list.
 for i,button in ipairs(f.trackerChoices)do
  equal(button:GetLeft()-f:GetLeft(),f.searchBox:GetLeft()-f:GetLeft()+(i-1)*366,"tracker choice "..i.." lines up with the pages outside setup")
  equal(button:GetLeft()>f.navDivider:GetLeft(),true,"tracker choice "..i.." clear of the tab list")
 end

 -- /era: the active preset is a label, never a warning.
 equal(f.presetButton:IsShown(),true,"Presets button in /era")
 -- The update notice: a small tick under Presets, on no page; search finds
 -- it as a card that is the same switch.
 local notice=f.updateNotice
 equal(notice:IsShown()and notice.on,true,"Update notice ticked under Presets")
 equal(f.checks.updateCheck.category,nil,"and on no page")
 local tickSay,tickStatus=E.Status
 E.Status=function(_,m)tickStatus=m end
 notice:Fire("OnClick")
 equal(E.settings.updateCheck,false,"unticking turns it off")
 equal(tickStatus,"Update Notice off.","and says so in chat")
 equal(f.checks.updateCheck:GetChecked(),false,"search's Update Notice card follows the tick")
 notice:Fire("OnClick")
 equal(E.settings.updateCheck,true,"and on again")
 equal(tickStatus,"Update Notice on.","and says that too")
 equal(f.checks.updateCheck:GetChecked(),true,"both ways")
 E.Status=tickSay
 -- Changelog in the middle of the footer.
 local point,_,relative,x=f.changelogButton:GetPoint()
 equal(point=="BOTTOM"and relative=="BOTTOM"and x,0,"Changelog centred in the footer")
 -- Discord right beside it, for bugs and ideas.
 local discord=f.discordButton
 local dpoint,dto,drel,dx=discord:GetPoint()
 equal(dpoint=="LEFT"and dto==f.changelogButton and drel=="RIGHT"and dx,8,"Discord beside Changelog")
 equal(discord:IsShown()and discord.label.text,"Discord","Discord shown in the footer")
 local invited=0;E.ShowDiscord=function()invited=invited+1 end
 discord:Fire("OnClick");SlashCmdList.ERAUI("discord")
 equal(invited,2,"the button and /era discord give the invite")
 f:SetSetupMode(true);equal(discord:IsShown(),false,"hidden during guided setup, like Changelog")
 f:SetSetupMode(false);Flush();equal(discord:IsShown(),true,"and back after it")
 -- More from Squirt: the other addons, with a way to open them.
 local more=f.checks.moreFECM
 equal(more.category,Tab(f,"more"),"More from Squirt has its own tab")
 -- Its text never runs under a button: it stops short of the leftmost one on
 -- show, and still fits two lines (6 per letter) above the status line.
 local function TextClear(label)
  local about=more.about
  for _,button in ipairs({more.open,more.curse,more.github})do
   if button:IsShown()then equal(about:GetRight()<=button:GetLeft()-12+.01,true,label..": the text ends left of its "..button.label.text.." button")end
  end
  local lines,line=0,""
  for word in about:GetText():gmatch("%S+")do
   if line==""then line=word elseif(#line+1+#word)*6<=about:GetWidth()then line=line.." "..word else lines=lines+1;line=word end
  end
  lines=lines+(line~=""and 1 or 0)
  equal(lines<=2,true,label..": the text fits two lines ("..lines..")")
  equal(about:GetLeft()>=more:GetLeft()and about:GetRight()<=more:GetRight(),true,label..": the text stays in its card")
 end
 more:SetChecked()
 TextClear("not installed")
 equal(more.open.shown,false,"not installed: no Open button")
 equal(more.state:GetText(),"Get it on CurseForge or GitHub: click one for its link.","out now: where to get it")
 equal(more.curse.shown and more.github.shown,true,"with both links")
 local copied
 E.Classic=E.Classic or {}
 local copy=E.Classic.CopyLink
 E.Classic.CopyLink=function(_,url)copied=url end
 more.curse:Fire("OnClick")
 equal(copied,"https://www.curseforge.com/wow/addons/forever-enhanced-cooldown-manager","CurseForge gives its page to copy")
 more.github:Fire("OnClick")
 equal(copied,"https://github.com/squirtwow/ForeverEnhancedCooldownManager","and GitHub its repo")
 E.Classic.CopyLink=copy
 local opened
 C_AddOns={IsAddOnLoaded=function(name)return name=="ForeverEnhancedCooldownManager"end}
 SlashCmdList.FECM=function()opened=true end
 more:SetChecked()
 TextClear("installed")
 equal(more.open.shown,true,"installed: an Open button")
 more.open:Fire("OnClick")
 equal(opened,true,"which opens it")
 C_AddOns=nil;SlashCmdList.FECM=nil
 f:Show();Flush()
 equal(f.presetLabel:GetText(),"Preset: Classic look","Classic look recognised")
 E.settings.minimap=false;f:UpdatePresetLabel()
 equal(f.presetLabel:GetText(),"Preset: Custom","any change to the look shows Custom")
 for _,key in ipairs(P.LOOK)do E.settings[key]=false end;f:UpdatePresetLabel()
 equal(f.presetLabel:GetText(),"Preset: Quality of Life only","modern look recognised")

 -- Options that need a Classic piece are greyed out and cannot be switched on.
 E.settings.portraitDebuffs=false
 f:RefreshDependencies()
 local portrait=f.checks.portraitDebuffs
 equal(portrait.dependencyDisabled,true,"portrait debuffs greyed out without Classic Unit Frames")
 portrait:Fire("OnClick");Flush()
 equal(E.settings.portraitDebuffs,false,"a greyed-out option cannot be switched on")
 equal(f.checks.trainingGuide.dependencyDisabled,true,"Training Guide needs the Classic Spellbook")
 equal(f.checks.spellbookCombatDrag.dependencyDisabled,true,"Combat Spell Dragging needs the Classic Spellbook")
 equal(f.checks.vendorPrice.dependencyDisabled,nil,"ordinary QoL options are never greyed out")
 E.settings.unitFrames=true;f:RefreshDependencies()
 equal(portrait.dependencyDisabled,false,"available again with Classic Unit Frames")

 -- Class icon portraits: the game's own switches (Options > Interface), mirrored on Frames & Nameplates.
 do
  local cvars,refuse={},false
  local oldSet,oldBool,oldGet,oldPrint=SetCVar,GetCVarBool,E.GetSavedSetting,E.Print
  SetCVar=function(name,v)if refuse then return false end;cvars[name]=v;return true end
  GetCVarBool=function(name)return cvars[name]=="1"end
  -- As Core/Init.lua: these cards read the game's switch, not EraUIDB.
  E.GetSavedSetting=function(self,key)
   local cvar=self.cvarSettings[key]
   if cvar then return GetCVarBool~=nil and GetCVarBool(cvar)and true or false end
   return self.settings[key]
  end
  -- The game's unit frames: reading them is fine, any key written on them fails.
  local function Game(fields)return setmetatable(fields,{__newindex=function(_,k)error("wrote "..tostring(k).." on a game frame")end})end
  PlayerFrame=Game({portrait={},unit="player"})
  TargetFrame=Game({portrait={},unit="target",totFrame=Game({portrait={},unit="targettarget"})})
  FocusFrame=Game({portrait={},unit="focus",totFrame=Game({portrait={},unit="focustarget"})})
  local party1,party2,bare=Game({portrait={},unit="party1"}),Game({portrait={},unit="party2"}),Game({unit="party3"})
  local active={[party1]=true,[party2]=true,[bare]=true}
  PartyFrame=Game({PartyMemberFramePool=Game({EnumerateActive=function()return pairs(active)end})})
  local all={PlayerFrame,TargetFrame,FocusFrame,TargetFrame.totFrame,FocusFrame.totFrame,party1,party2}
  local redrawn,times,printed={},{},{}
  UnitFramePortrait_Update=function(frame)redrawn[#redrawn+1]=frame;times[frame]=(times[frame]or 0)+1 end
  E.Print=function(_,m)printed[#printed+1]=m end
  local function Reset()redrawn,times,printed={},{},{}end
  for key,cvar in pairs({classIconPortraitMine="ReplaceMyPlayerPortrait",classIconPortraitOthers="ReplaceOtherPlayerPortraits"})do
   local card=f.checks[key]
   equal(card~=nil and card.category==Tab(f,"frames")and card.dependencyDisabled~=true,true,key.." card on Frames & Nameplates, never greyed out")
   cvars[cvar]="0";Reset();card:SetChecked(true);card:Fire("OnClick");Flush()
   equal(cvars[cvar],"1",key.." switches the game's own "..cvar.." on")
   equal(card:GetChecked(),true,key.." on: the card shows the game's value")
   equal(#redrawn,7,key.." on: every portrait the game draws is redrawn at once")
   for _,frame in ipairs(all)do equal(times[frame],1,key.." on: the "..frame.unit.." portrait redrawn once")end
   equal(times[bare],nil,key.." a frame without a portrait is left alone")
   equal(#printed,0,key.." on: no warning")
   Reset();card:SetChecked(false);card:Fire("OnClick");Flush()
   equal(cvars[cvar],"0",key.." and off again")
   equal(card:GetChecked(),false,key.." off: the card shows the game's value")
   equal(#redrawn,7,key.." off: every portrait redrawn at once")
   for _,frame in ipairs(all)do equal(times[frame],1,key.." off: the "..frame.unit.." portrait redrawn once")end
   -- The game keeps its value: the card follows the game and says where to change it.
   refuse=true;Reset();card:SetChecked(true);card:Fire("OnClick");Flush();refuse=false
   equal(cvars[cvar].." "..tostring(card:GetChecked()),"0 false",key.." refused: the card goes back to the game's value")
   equal(#redrawn,0,key.." refused: nothing redrawn")
   equal(printed[1],"The game kept its own portrait setting. Change it in Options > Interface.",key.." refused: says where to change it")
   combat=true;Reset();card:SetChecked(true);card:Fire("OnClick");Flush();combat=false
   equal(cvars[cvar].." "..tostring(card:GetChecked()),"0 false",key.." in combat: nothing changes, the card goes back")
   equal(#redrawn,0,key.." in combat: nothing redrawn")
   equal(printed[1],"Finish combat before changing portraits.",key.." in combat: says why")
   -- The game's Options window flips it: the card follows, both ways, with /era open.
   Reset();cvars[cvar]="1";f.cvarWatch:Fire("OnEvent","CVAR_UPDATE",cvar,"1")
   equal(card:GetChecked(),true,key.." follows the game's Options window on")
   cvars[cvar]="0";f.cvarWatch:Fire("OnEvent","CVAR_UPDATE",string.lower(cvar),"0")
   equal(card:GetChecked(),false,key.." and off (any letter case)")
   equal(#redrawn,0,key.." the game redraws its own change, EraUI doesn't")
   combat=true;cvars[cvar]="1";f.cvarWatch:Fire("OnEvent","CVAR_UPDATE",cvar,"1");combat=false
   equal(card:GetChecked(),true,key.." follows in combat too (only the card changes)")
   equal(#redrawn,0,key.." and nothing is redrawn in combat")
   f:Hide();cvars[cvar]="0";f:Show();Flush()
   equal(card:GetChecked(),false,key.." reopening /era shows the game's value")
  end
  -- The other card is left alone, and so is every other setting's change.
  local mine,others=f.checks.classIconPortraitMine,f.checks.classIconPortraitOthers
  cvars.ReplaceMyPlayerPortrait="1";f.cvarWatch:Fire("OnEvent","CVAR_UPDATE","ReplaceOtherPlayerPortraits","0")
  equal(tostring(mine:GetChecked()).." "..tostring(others:GetChecked()),"false false","one switch's change leaves the other card alone")
  f.cvarWatch:Fire("OnEvent","CVAR_UPDATE","chatBubbles","1");f.cvarWatch:Fire("OnEvent","CVAR_UPDATE",nil,nil)
  equal(mine:GetChecked(),false,"another setting's change, or none, leaves the cards alone")
  cvars.ReplaceMyPlayerPortrait="0"
  -- One portrait that fails to redraw doesn't stop the others.
  UnitFramePortrait_Update=function(frame)if frame==TargetFrame then error("no unit")end;redrawn[#redrawn+1]=frame end
  Reset();mine:SetChecked(true);mine:Fire("OnClick");Flush()
  equal(#redrawn.." "..tostring(mine:GetChecked()).." "..cvars.ReplaceMyPlayerPortrait,"6 true 1","one portrait failing: the rest are redrawn, the switch flips")
  -- A client without the game's portrait function: the switch still flips.
  UnitFramePortrait_Update=nil
  Reset();mine:SetChecked(false);mine:Fire("OnClick");Flush()
  equal(cvars.ReplaceMyPlayerPortrait.." "..tostring(mine:GetChecked()).." "..#printed,"0 false 0","no portrait function: the switch still flips")
  -- A game without the setting.
  SetCVar=function()error("no such cvar")end
  Reset();mine:SetChecked(true);mine:Fire("OnClick");Flush()
  equal(tostring(mine:GetChecked()),"false","a game without the setting: the card goes back")
  equal(printed[1],"This game version doesn't have that portrait setting.","and says so")
  SetCVar=function(name,v)cvars[name]=v;return true end;GetCVarBool=nil
  Reset();mine:SetChecked(true);mine:Fire("OnClick");Flush()
  equal(tostring(mine:GetChecked()).." "..tostring(printed[1]),"false This game version doesn't have that portrait setting.","a game that can't read it back: the card goes back")
  -- As the real client: a game without the switch quietly takes no write and
  -- gives nothing back when it is read.
  local writes=0
  SetCVar=function()writes=writes+1 end
  GetCVarBool=function()return nil end
  Reset();mine:SetChecked(true);mine:Fire("OnClick");Flush()
  equal(tostring(mine:GetChecked()).." "..tostring(printed[1]),"false This game version doesn't have that portrait setting.","a game without the switch (nothing back): the card goes back and says so")
  -- A switch the game keeps for its own Options window (secure or read-only)
  -- ignores addon writes: the card writes nothing, goes back and says where.
  local oldCVar=C_CVar
  SetCVar=function(name,v)writes=writes+1;cvars[name]=v;return true end
  GetCVarBool=function(name)return cvars[name]=="1"end
  UnitFramePortrait_Update=function(frame)redrawn[#redrawn+1]=frame end
  local info={}
  C_CVar={GetCVarInfo=function(name)
   local i=info[name]
   if i=="error" then error("no info") end
   if i then return cvars[name],"0",false,false,i.locked or false,i.secure or false,i.readOnly or false end
  end}
  local switches={classIconPortraitMine="ReplaceMyPlayerPortrait",classIconPortraitOthers="ReplaceOtherPlayerPortraits"}
  for _,kind in ipairs({"secure","readOnly"})do
   for key,cvar in pairs(switches)do
    local card=f.checks[key]
    cvars[cvar]="0";info[cvar]={[kind]=true};writes=0;Reset();card:SetChecked(true);card:Fire("OnClick");Flush()
    equal(writes.." "..cvars[cvar].." "..tostring(card:GetChecked()).." "..#redrawn,"0 0 false 0",key.." "..kind..": nothing written or redrawn, the card goes back")
    equal(printed[1],"Only Options > Interface can change this portrait setting.",key.." "..kind..": says where to change it")
   end
  end
  -- A switch addons may change flips as usual, and so does one whose details
  -- can't be read.
  for _,state in ipairs({{},"error"})do
   for key,cvar in pairs(switches)do
    local card=f.checks[key]
    cvars[cvar]="0";info[cvar]=state;writes=0;Reset();card:SetChecked(true);card:Fire("OnClick");Flush()
    equal(writes.." "..cvars[cvar].." "..tostring(card:GetChecked()).." "..#redrawn.." "..#printed,"1 1 true 7 0",key.." "..(state=="error"and"details unreadable"or"open switch")..": flips and redraws")
   end
  end
  C_CVar=oldCVar
  SetCVar,GetCVarBool,E.GetSavedSetting,E.Print=oldSet,oldBool,oldGet,oldPrint
  PlayerFrame,TargetFrame,FocusFrame,PartyFrame,UnitFramePortrait_Update=nil,nil,nil,nil,nil
 end

 -- Other Windows: the windows without a switch of their own follow it.
 local function Window(name)return {GetName=function()return name end}end
 local allowed=E.Classic.WindowAllowed
 E.settings.otherWindows=false;E.settings.merchantSkin=true
 equal(allowed(Window("TradeFrame")),false,"Other Windows off: trade window stays modern")
 equal(allowed(Window(nil)),false,"unnamed extra windows follow Other Windows too")
 equal(allowed(Window("MerchantFrame")),true,"windows with their own switch ignore Other Windows")
 E.settings.otherWindows=true
 equal(allowed(Window("TaxiFrame")),true,"Other Windows on: taxi window skinned")
 E.settings.merchantSkin=false
 equal(allowed(Window("MerchantFrame")),false,"merchant still follows its own switch")
 equal(f.checks.otherWindows~=nil,true,"Other Windows has an /era card")

 -- A Custom look selects no preset; a preset click re-syncs every toggle.
 for _,key in ipairs(P.LOOK)do E.settings[key]=true end
 E.settings.minimap=false
 f:SetSetupMode(true);Flush()
 equal(choices[1].tag:IsShown()or choices[2].tag:IsShown()or choices[3].tag:IsShown(),false,"Custom look: no preset pre-selected")
 E.settings.classColourBorders=true;f.checks.classColourBorders:SetChecked(true)
 choices[3]:Fire("OnClick");Flush()
 choices[1]:Fire("OnClick");Flush()
 equal(E.settings.classColourBorders,false,"Quality of Life only switched the optional look off")
 equal(f.checks.classColourBorders:GetChecked()and true or false,false,"its toggle shows the saved state after the preset click")
 equal(f.checks.bagItemLevels.state:GetText(),"OFF","a preset click leaves Bag Item Levels off: neither preset touches it")
 f:SetSetupMode(false);Flush()
end

-- Coming soon, as a feature would ship before it is finished (Bag Item Levels
-- switched back to Coming soon for this session): SOON, greyed out, can't be
-- switched on, a saved on still shows off, and a preset click keeps SOON.
do
 local E,f=Session("DRUID",nil,true)
 local card=f.checks.bagItemLevels
 Open(f,"bags")
 equal(card.text:GetText(),"Bag Item Levels","coming soon: a plain label")
 equal(card.unavailable,true,"coming soon: unavailable")
 equal(card.state:GetText(),"SOON","coming soon: its switch says SOON")
 equal(card.enabled==false and card:GetChecked()==false,true,"coming soon: greyed out and off")
 local lines={}
 GameTooltip={SetOwner=function()end,SetText=function(_,t)lines={t}end,AddLine=function(_,t)lines[#lines+1]=t end,
  Show=function()end,Hide=function()end,IsOwned=function()return true end}
 card:Fire("OnEnter")
 equal(lines[1],"Bag Item Levels","coming soon: tooltip title")
 equal(table.concat(lines,"\n"):find("Coming soon - not finished yet.",1,true)~=nil,true,"coming soon: hover says so")
 GameTooltip=nil
 local real,refreshed=E.modules.BagItemLevels,0
 E.modules.BagItemLevels={Refresh=function()refreshed=refreshed+1 end}
 E.settings.bagItemLevels=true;f:Hide();f:Show();Flush()
 equal(card:GetChecked(),false,"coming soon: a saved on still shows off")
 equal(card.state:GetText(),"SOON","coming soon: and SOON")
 E.settings.bagItemLevels=nil
 card:SetChecked(true);card:Fire("OnClick")
 equal(E.settings.bagItemLevels,nil,"coming soon: can't be switched on")
 equal(refreshed,0,"coming soon: and nothing runs")
 E.modules.BagItemLevels=real;card:SetChecked(false)
 f:SetSetupMode(true);Flush()
 f.presetChoices[1]:Fire("OnClick");Flush()
 equal(card.state:GetText(),"SOON","a preset click keeps a Coming soon card on SOON")
 f:SetSetupMode(false);Flush()
end
-- One home per topic (the approved Option A): the tabs, every card on exactly
-- one page in its approved place, sub-options right after their parent,
-- folding, search, the new-player hints, the walkthrough pages, the new
-- layout note and tidy labels.
local EXPECTED_TABS={
 {"appearance","Appearance"},{"class"},{"actionBars","Action Bars"},{"frames","Frames & Nameplates"},
 {"casting","Casting"},{"map","Map & Minimap"},{"quests","Quests"},{"character","Character & Spells"},
 {"bags","Bags & Vendors"},{"chat","Chat & Names"},{"group","Group & Invites"},{"windows","Windows & Tooltips"},
 {"screen","Screen & Cursor"},{"more","More from Squirt"},
}
local EXPECTED_PAGES={
 appearance={"appearanceChoice","darkAuraBorders","classColors","darkAuraShadows","tooltipClassColours","classColourBorders","castBarClassBorder"},
 actionBars={"actionBars","gryphons","hideEmptyActionSlots","hideKeybindText","hideMacroText"},
 frames={"unitFrames","matchFocusSize","disableAggroHighlight","portraitDebuffs","classIconPortraitMine","classIconPortraitOthers","friendlyNameplates","enemyNameplates"},
 casting={"castBars","advancedCastBar","advancedCastClassFill","advancedCastTicks","advancedCastLatency"},
 map={"minimap","cleanMinimap","coordinates","mapQuestObjectives","movableMap","revealMap"},
 quests={"questLog","questDialogs","questTracker","questLevels","autoQuests","autoGossip","rewardUpgradeHighlight","rewardProfile"},
 character={"characterPanel","talentWindow","spellbook","spellbookCombatDrag","trainingGuide","showAllSpellRanks","trainer","professions"},
 bags={"bagsBank","bagSpace","bagItemLevels","lootWindow","fastAutoLoot","discardCheapestJunk",
  "merchantSkin","autoSellJunk","autoRepair","vendorPrice","junkValueSummary","durabilityWarning"},
 chat={"hideSecondaryNames","classicChatDragging","linkToggle","hideStatusMessages","showWelcomeOnLogin"},
 group={"socialWindows","groupFinderPvp","blockDuels","blockPartyInvites","partyFromFriends","inviteFromWhispers","autoSummon","autoResurrect","releasePvP"},
 windows={"gameMenu","popups","blizzardSettings","tooltipSkin","tooltipIDs","damageMeterSkin","mailSkin","auctionHouse","otherWindows","contextMenus"},
 screen={"hideZoneText","maxCameraZoom","damageFont","damageTextScale",
  "cursorRing","cursorRingClassColour","cursorRingSize","cursorRingThickness",
  "cursorCastRing","cursorCastClassColour","cursorCastSize","cursorCastOpacity","cursorCastColour",
  "cursorTrail","cursorTrailClassColour","cursorTrailSize","cursorTrailOpacity","cursorTrailLength","cursorTrailColour",
  "afkScreen","afkCameraNormal","afkTurnRight","afkZoom","afk24Hour","afkShowGuild","afkShowZone","afkShowDate","afkShowQuote"},
 more={"moreFECM"},
}
-- Each sub-option and the card it belongs under (Dark Mode is the style choice).
local PARENT={
 darkAuraBorders="appearanceChoice",darkAuraShadows="darkAuraBorders",classColourBorders="appearanceChoice",
 gryphons="actionBars",matchFocusSize="unitFrames",disableAggroHighlight="unitFrames",portraitDebuffs="unitFrames",
 advancedCastClassFill="advancedCastBar",advancedCastTicks="advancedCastBar",advancedCastLatency="advancedCastBar",
 spellbookCombatDrag="spellbook",trainingGuide="spellbook",rewardProfile="rewardUpgradeHighlight",
 afkCameraNormal="afkScreen",afkTurnRight="afkScreen",afkZoom="afkScreen",afk24Hour="afkScreen",
 afkShowGuild="afkScreen",afkShowZone="afkScreen",afkShowDate="afkScreen",afkShowQuote="afkScreen",
}
-- Folded options: hidden until their switch is on.
local FOLDED={
 cursorRing={"cursorRingClassColour","cursorRingSize","cursorRingThickness"},
 cursorCastRing={"cursorCastClassColour","cursorCastSize","cursorCastOpacity","cursorCastColour"},
 cursorTrail={"cursorTrailClassColour","cursorTrailSize","cursorTrailOpacity","cursorTrailLength","cursorTrailColour"},
}
for parent,kids in pairs(FOLDED)do for _,kid in ipairs(kids)do PARENT[kid]=parent end end
-- The cards on show, in reading order: row by row, left to right.
local function Reading(f)
 local out={}
 for key,card in pairs(f.checks)do if card:IsShown()then out[#out+1]={key=key,card=card}end end
 table.sort(out,function(a,b)
  local at,bt=a.card:GetTop(),b.card:GetTop()
  if math.abs(at-bt)>.01 then return at>bt end
  return a.card:GetLeft()<b.card:GetLeft()
 end)
 return out
end
local function Keys(list)local out={};for i,e in ipairs(list)do out[i]=e.key end;return table.concat(out,",")end
-- Every card on show lies inside the scrolling content, so the scroll reaches it.
local function InsideContent(f,label)
 for key,card in pairs(f.checks)do
  if card:IsShown()then
   equal(card:GetBottom()>=f.settingsContent:GetBottom()-.01 and card:GetTop()<=f.settingsContent:GetTop()+.01,true,label.." "..key.." inside the scrolling content")
  end
 end
end
local function Under(key,top)
 local parent,depth=PARENT[key],0
 while parent and depth<8 do if parent==top then return true end;parent,depth=PARENT[parent],depth+1 end
 return false
end
-- upper and lower share a column (or upper spans both) and no card sits between.
local function DirectlyBelow(upper,lower,order)
 if lower:GetTop()>upper:GetBottom()+.01 then return false end
 if not(upper.fullWidth or math.abs(upper:GetLeft()-lower:GetLeft())<.01)then return false end
 for _,e in ipairs(order)do
  local x=e.card
  if x~=upper and x~=lower and x:GetLeft()<lower:GetRight()-.01 and lower:GetLeft()<x:GetRight()-.01
   and x:GetTop()<=upper:GetBottom()+.01 and x:GetBottom()>=lower:GetTop()-.01 then return false end
 end
 return true
end
-- A sub-option comes right after its parent's group: next in reading order,
-- or directly under the parent or one of its other sub-options.
local function SubOptionsFollow(f,label)
 local order=Reading(f)
 for i,e in ipairs(order)do
  local parent=PARENT[e.key]
  if parent and f.checks[parent]and f.checks[parent]:IsShown()then
   local ok=false
   for j=1,i-1 do
    local m=order[j]
    if(m.key==parent or Under(m.key,parent))and(j==i-1 or DirectlyBelow(m.card,e.card,order))then ok=true end
   end
   equal(ok,true,label..": "..e.key.." right after "..parent.." ("..Keys(order)..")")
   -- The parent starts its row, so its options follow it from the left
   -- column instead of sitting under another card.
   local owner=f.checks[parent]
   equal(math.abs(owner:GetLeft()-f.settingsContent:GetLeft())<.01,true,label..": "..parent.." with "..e.key.." on show is in the left column ("..Keys(order)..")")
  end
 end
end
methods.SetTexture=function(self,texture)Guard(self);self.texture=texture end

do
 local E,f=Session("DRUID")
 -- The tabs: at most fourteen, in the approved order, each with its own icon
 -- and a short description under its title, all above the footer.
 equal(#f.tabs<=14,true,"at most fourteen tabs")
 equal(#f.tabs,#EXPECTED_TABS,"the fourteen approved tabs")
 local icons,abouts={},{}
 for i,want in ipairs(EXPECTED_TABS)do
  local id,tab=want[1],f.tabs[i]
  equal(tab.id,id,"tab "..i.." is "..id)
  equal(Tab(f,id),i,id.." found by its id")
  equal(tab.text:GetText(),want[2]or"DRUID",id.." tab name")
  equal(tab:GetBottom()>f:GetBottom()+64,true,id.." tab above the footer")
  equal(type(tab.icon.texture)=="string"and icons[tab.icon.texture]==nil,true,id.." has its own icon")
  icons[tab.icon.texture]=true
  Open(f,id)
  equal(f.sectionTitle:GetText(),tab.text:GetText(),id.." title")
  local about=f.sectionAbout:GetText()
  equal(#about>0 and #about*6<=560 and about:sub(-1)=="." and about:find("\226\128\148",1,true)==nil,true,id.." has a short one-line description: "..about)
  equal(abouts[about],nil,id.." description is its own");abouts[about]=true
  equal(f.sectionAbout:IsShown()and f.sectionAbout:GetTop()<=f.sectionTitle:GetBottom()and f.sectionAbout:GetBottom()>=f.searchBox:GetTop(),true,id.." description under the title, above search")
  -- Every page fits the window's width; only the two long pages scroll with
  -- their folded groups closed.
  for _,e in ipairs(Reading(f))do
   equal(e.card:GetLeft()>=f.settingsScroll:GetLeft()-.01 and e.card:GetRight()<=f.settingsScroll:GetRight()+.01,true,id.." "..e.key.." fits the width")
  end
  if id~="class"then
   local long=id=="bags"or id=="screen"
   equal(f.settingsContent:GetHeight()>f.settingsScroll:GetHeight()+.01,long,id..(long and" is long and scrolls"or" fits without scrolling"))
   equal(f.settingsScrollHint:IsShown(),long,id.." scroll hint only when it scrolls")
   NoCardOverlaps(f,id)
  end
  InsideContent(f,id)
 end
 -- Every card is on exactly one page, in its approved place; the Update
 -- notice card is on none (search only).
 local seen={}
 for id,list in pairs(f.pages)do
  equal(Tab(f,id)~=nil,true,id.." page is a tab")
  for _,key in ipairs(list)do
   if key:sub(1,1)=="#"then
    equal(f.sectionLabels[key]~=nil,true,key.." is a section label")
   else
    equal(f.checks[key]~=nil,true,key.." on the "..id.." page is a card")
    equal(seen[key],nil,key.." is listed once")
    seen[key]=id
    equal(f.checks[key].category,Tab(f,id),key.." knows its tab")
   end
  end
 end
 for key,card in pairs(f.checks)do
  if key=="updateCheck"then equal(seen[key]==nil and card.searchOnly==true,true,"the Update Notice card is on no page")
  else equal(seen[key]~=nil,true,key.." is on a page")end
 end
 for id,want in pairs(EXPECTED_PAGES)do
  local got={}
  for _,key in ipairs(f.pages[id])do if key:sub(1,1)~="#"then got[#got+1]=key end end
  equal(table.concat(got,","),table.concat(want,","),id.." holds the approved cards, in order")
 end
 equal(table.concat(f.pages.class,","),"floatingComboPoints,comboPointRed,energyBar,rageBar,manaBar,druidResourceBar,swingTimer,rangedSwingTimer,hunterFeed,mageSupplies,mageAutoTrade,roguePoisons,poisonReminders,classReminders,classTools","the class tab is unchanged")
 -- Section labels in EraUI's small capitals: Bags & Vendors has two, each
 -- above its cards.
 Open(f,"bags")
 local bags,vendors=f.sectionLabels["#bagsLoot"],f.sectionLabels["#vendors"]
 equal(bags:IsShown()and vendors:IsShown()and bags.text:GetText().." / "..vendors.text:GetText(),"BAGS & LOOT / VENDORS","Bags & Vendors in two sections")
 equal(f.checks.bagsBank:GetTop()<bags:GetBottom()and f.checks.durabilityWarning:GetTop()<vendors:GetBottom()and vendors:GetTop()<=f.checks.discardCheapestJunk:GetBottom(),true,"each section's cards under its label")
 equal(bags:GetRight()-bags:GetLeft()>700 and f.checks.merchantSkin:GetLeft()==f.checks.bagsBank:GetLeft(),true,"a section label takes the full row")
 -- Sub-options right after their parent, on every page, with every folded
 -- group open.
 E.settings.cursorRing,E.settings.cursorCastRing,E.settings.cursorTrail,E.settings.afkScreen=true,true,true,true
 for _,want in ipairs(EXPECTED_TABS)do
  if want[1]~="class"then Open(f,want[1]);SubOptionsFollow(f,want[1])end
 end
 for key,parent in pairs(PARENT)do
  if f.checks[key]then equal(f.checks[key].category,f.checks[parent].category,key.." on its parent's page")end
 end
 E.settings.cursorRing,E.settings.cursorCastRing,E.settings.cursorTrail,E.settings.afkScreen=nil,nil,nil,nil
 -- Folding: a cursor effect's options are hidden (not greyed) until its
 -- switch is on, open right after it at once, and fold away again.
 Open(f,"screen")
 for parent,kids in pairs(FOLDED)do
  Open(f,"screen")
  for _,kid in ipairs(kids)do equal(f.checks[kid]:IsShown(),false,kid.." folded away while "..parent.." is off")end
  equal(f.checks[parent]:IsShown(),true,parent.." itself shows")
  f:SetSettingsScroll(40)
  local card=f.checks[parent];card:SetChecked(true);card:Fire("OnClick");Flush()
  equal(E.settings[parent],true,parent.." switched on")
  local order,at=Reading(f)
  for i,e in ipairs(order)do if e.key==parent then at=i end end
  for n,kid in ipairs(kids)do
   equal(order[at+n]and order[at+n].key,kid,kid.." opens right after "..parent.." at once")
   equal(f.checks[kid].dependencyDisabled,nil,kid.." is folded, never greyed")
  end
  equal(f.settingsScroll:GetVerticalScroll(),40,parent.." opening keeps the scroll")
  NoCardOverlaps(f,parent.." open")
  InsideContent(f,parent.." open")
  SubOptionsFollow(f,parent.." open alone")
  card:SetChecked(false);card:Fire("OnClick");Flush()
  equal(E.settings[parent],false,parent.." switched off")
  for _,kid in ipairs(kids)do equal(f.checks[kid]:IsShown(),false,kid.." folds away again")end
 end
 -- The AFK Screen's options are not folded: shown, greyed, while it is off.
 E.settings.afkScreen=false;Open(f,"screen")
 equal(f.checks.afkZoom:IsShown()and f.checks.afkZoom.dependencyDisabled,true,"the AFK Screen's options stay open, greyed while it is off")
 E.settings.afkScreen=nil
 -- Search still finds a folded option.
 f.searchBox:SetText("trail opacity");Flush()
 equal(f.checks.cursorTrailOpacity:IsShown(),true,"search finds a folded option")
 f.searchBox:SetText("");Flush()

 -- Search: colour and color, grey and gray, the tab of every result, the
 -- Dark Mode choice, the Update notice, and full-width cards.
 local function Results(query)
  f.searchBox:SetText(query);Flush()
  local out={}
  for i,e in ipairs(Reading(f))do out[i]=e.key end
  return out
 end
 Open(f,"appearance")
 local colours="classColors,tooltipClassColours,classColourBorders,castBarClassBorder,advancedCastClassFill,cursorRingClassColour,cursorCastClassColour,cursorTrailClassColour"
 equal(table.concat(Results("class colour"),","),colours,"class colour finds every class-colour switch, in tab order")
 equal(table.concat(Results("class color"),","),colours,"and so does class color")
 equal(table.concat(Results("Class Colored"),","),colours,"and class colored")
 equal(f.searchResultsText:GetText(),"8 found  |  1 / 1","on one page")
 for _,key in ipairs(Results("class colour"))do
  local card=f.checks[key];local tag=f.searchTags[card]
  equal(tag~=nil and tag:IsShown()and tag:GetText(),string.upper(f.tabs[card.category].text:GetText()),key.." result shows its tab")
  equal(tag:GetBottom()>=card:GetTop()-.01 and tag:GetTop()<=card:GetTop()+16.01,true,key.." tab name just above the card")
  for other,shown in pairs(f.checks)do
   if shown~=card and shown:IsShown()and shown:GetLeft()<=tag:GetLeft()and shown:GetRight()>=tag:GetLeft()then
    equal(shown:GetBottom()>=tag:GetTop()-.01 or shown:GetTop()<=tag:GetBottom()+.01,true,key.." tab name clear of "..other)
   end
  end
 end
 equal(f.searchTags[f.checks.classColors]:GetText().." / "..f.searchTags[f.checks.cursorTrailClassColour]:GetText(),"APPEARANCE / SCREEN & CURSOR","for example")
 NoCardOverlaps(f,"class colour results")
 Fits(f,"class colour results")
 local grey,gray=Results("grey"),Results("gray")
 equal(#grey>0 and table.concat(grey,",")==table.concat(gray,","),true,"grey and gray find the same")
 equal(table.concat(grey,","):find("autoSellJunk",1,true)~=nil and table.concat(grey,","):find("revealMap",1,true)~=nil,true,"such as Auto-sell Junk and Reveal World Map")
 f.searchBox:SetText("");Flush()
 equal(f.searchTags[f.checks.classColors]:IsShown(),false,"pages show no tab names")
 -- The Classic / Dark Mode choice.
 local dark=Results("dark mode")
 equal(dark[1],"appearanceChoice","search finds the Classic / Dark Mode choice")
 local row=f.checks.appearanceChoice
 equal(math.abs(row:GetLeft()-f.settingsContent:GetLeft())<.01 and row:GetRight()<=f.settingsScroll:GetRight()+.01,true,"the choice keeps its full row in search")
 equal(f.searchTags[row]:GetText(),"APPEARANCE","on Appearance")
 f.appearanceChoices[2]:Fire("OnClick")
 equal(E.settings.darkMode,true,"and Dark Mode can be chosen there")
 equal(f.appearanceChoices[2].label:GetText(),"Selected: Dark Mode","shown as selected")
 E.settings.darkMode=nil
 -- The Update notice tick.
 local update=table.concat(Results("update notice"),",")
 equal(update:find("updateCheck",1,true)~=nil,true,"search finds the Update notice")
 local notice=f.checks.updateCheck
 equal(f.searchTags[notice]:GetText(),"TOP RIGHT, UNDER PRESETS","and says where its tick is")
 equal(notice.text:GetText().." / "..f.updateNotice.text:GetText(),"Update Notice / Update Notice","named like the tick")
 local say,status=E.Status
 E.Status=function(_,m)status=m end
 E.settings.updateCheck=true;notice:SetChecked(false);notice:Fire("OnClick")
 equal(E.settings.updateCheck==false and f.updateNotice.on==false,true,"switching it off there unticks the tick")
 equal(status,"Update Notice off.","and says so in chat, like the tick")
 notice:SetChecked(true);notice:Fire("OnClick")
 equal(E.settings.updateCheck==true and f.updateNotice.on==true,true,"and on again")
 equal(status,"Update Notice on.","and says that too")
 E.Status=say
 f.searchBox:SetText("");Flush()
 for _,want in ipairs(EXPECTED_TABS)do Open(f,want[1]);equal(notice:IsShown(),false,"no Update Notice card on "..want[1])end
 -- More from Squirt keeps its full row, so its buttons are never cut off.
 Results("cast bar")
 local more=f.checks.moreFECM
 equal(more:IsShown(),true,"cast bar finds the More from Squirt card")
 equal(math.abs(more:GetLeft()-f.settingsContent:GetLeft())<.01 and more:GetRight()<=f.settingsScroll:GetRight()+.01,true,"the More card keeps its full row")
 for _,button in ipairs({more.open,more.curse,more.github})do
  equal(button:GetRight()<=f.settingsScroll:GetRight()+.01,true,"its buttons fit")
 end
 NoCardOverlaps(f,"cast bar results")
 -- Every page of a broad search fits without scrolling, in at most four rows,
 -- and every result is on one.
 local function Rows()
  local tops={}
  for _,card in ipairs(f.settingsEntries)do tops[math.floor(card:GetTop()+.5)]=true end
  local n=0;for _ in pairs(tops)do n=n+1 end;return n
 end
 local function AllPages(query,label)
  f.searchBox:SetText(query);Flush()
  local total=tonumber(f.searchResultsText:GetText():match("^(%d+) found"))
  local pages=tonumber(f.searchResultsText:GetText():match("/ (%d+)$"))
  local listed=0
  for page=1,pages do
   -- A class card opens its options panel under it; that page may scroll.
   local panel=false
   for _,card in ipairs(f.settingsEntries)do if card.inlinePanel and card.inlinePanel:IsShown()then panel=true end end
   if panel then Fits(f,label.." page "..page)
   else equal(f.settingsContent:GetHeight()<=f.settingsScroll:GetHeight()+.01,true,label.." page "..page.." fits without scrolling")end
   equal(Rows()<=4,true,label.." page "..page.." has at most four rows")
   NoCardOverlaps(f,label.." page "..page)
   InsideContent(f,label.." page "..page)
   listed=listed+#f.settingsEntries
   if page<pages then f.searchNext:Fire("OnClick");Flush()end
  end
  equal(listed,total,label..": every result on one of the pages")
  f.searchBox:SetText("");Flush()
  return total
 end
 equal(AllPages("e","search")>60,true,"a broad search finds most cards")
 -- A full-width result after an odd number of cards takes the rest of their
 -- row too. Today's full-width cards (the style choice and the More card) come
 -- first and last, so one in the middle is made here: Class-coloured
 -- Tooltips, second of the eight class colour results.
 f.checks.tooltipClassColours.fullWidth=true
 equal(AllPages("class colour","a full-width result second"),8,"all eight class colour results listed")
 f.checks.tooltipClassColours.fullWidth=nil
 -- Search results are listed as they come, two to a row (the paging counts
 -- on it): a switch with its options among them starts no row.
 equal(table.concat(Results("casting"),","),"castBars,advancedCastBar,advancedCastClassFill,advancedCastTicks,advancedCastLatency","casting finds the Casting tab")
 equal(f.checks.advancedCastBar:GetTop()==f.checks.castBars:GetTop()and Rows(),3,"in search Advanced Cast Bar stays beside Cast Bars")
 -- Cast Bars' hover says the boss bars follow Forever Enhanced Cooldown
 -- Manager's Raid Timers when that's on (Classic/CastBars.lua hands them over).
 do
  local lines={}
  GameTooltip={SetOwner=function()end,SetText=function(_,t)lines={t}end,AddLine=function(_,t)lines[#lines+1]=t end,
   Show=function()end,Hide=function()end,IsOwned=function()return true end}
  f.checks.castBars:Fire("OnEnter")
  GameTooltip=nil
  local text=table.concat(lines,"\n")
  equal(text:find("player, target, focus, boss and styled nameplate cast bars",1,true)~=nil,true,"Cast Bars hover names the boss bars")
  -- After the reload note, and saying the hand-over itself needs none.
  equal(text:find("Reload UI to apply. Boss bars follow Forever Enhanced Cooldown Manager's Raid Timers when that's on, with no reload.",1,true)~=nil,true,
   "Cast Bars hover: boss bars follow the Raid Timers, with no reload")
  equal(text:find("\226\128\148",1,true),nil,"Cast Bars hover: no em dash")
  -- The card's summary names the boss bars too.
  equal(f.checks.castBars.description:GetText(),"Player, target, focus, boss and nameplate casts.","Cast Bars summary names the boss bars")
 end

 -- A tab's name finds its cards: "vendors" all of Bags & Vendors, "group
 -- invites" all of Group & Invites, your class name all of your class tab.
 local function PageKeys(id)
  Open(f,id);local out={}
  for _,e in ipairs(Reading(f))do out[#out+1]=e.key end
  table.sort(out);return table.concat(out,",")
 end
 -- Every result, over all its pages.
 local function Found(query)
  local out=Results(query)
  local pages=tonumber(f.searchResultsText:GetText():match("/ (%d+)$"))or 1
  for _=2,pages do
   f.searchNext:Fire("OnClick");Flush()
   for _,e in ipairs(Reading(f))do out[#out+1]=e.key end
  end
  table.sort(out);return table.concat(out,",")
 end
 for query,id in pairs({vendors="bags",["group invites"]="group",druid="class",nameplates="frames"})do
  local want=PageKeys(id)
  equal(Found(query),want,"searching \""..query.."\" finds the whole "..id.." tab")
 end
 f.searchBox:SetText("");Flush()

 -- Old card names still find the renamed cards.
 for old,key in pairs({["Character / Reputation / Skills"]="characterPanel",["reputation"]="characterPanel",["skills"]="characterPanel",
  ["Bags / Bank"]="bagsBank",["Friends / Guild"]="socialWindows",["Group Finder / PvP"]="groupFinderPvp",
  ["Blizzard Settings Skin"]="blizzardSettings",["settings skin"]="blizzardSettings",["Hide Secondary Names"]="hideSecondaryNames",
  ["Class Colours in Chat"]="classColors",["Faster Auto Loot"]="fastAutoLoot",["Auto Gossip"]="autoGossip",
  ["Discard Cheapest Junk When Bags Are Full"]="discardCheapestJunk",["AFK Camera: Normal Speed"]="afkCameraNormal",
  ["normal speed"]="afkCameraNormal",["AFK Camera: Circle Right"]="afkTurnRight",["AFK Camera: Zoom In"]="afkZoom",
  ["Class-coloured Fill"]="advancedCastClassFill",["Custom cast-ring colour"]="cursorCastColour",["Loot"]="lootWindow"})do
  equal(table.concat(Results(old),","):find(key,1,true)~=nil,true,"the old name \""..old.."\" finds "..key)
 end
 f.searchBox:SetText("");Flush()

 -- Switching a folded group's switch on or off inside search results keeps
 -- the results: search always lists folded options, so nothing opens or
 -- closes, and the page behind search never shows through.
 E.settings.cursorRing=nil
 local before=table.concat(Results("cursor ring"),",")
 local count=f.searchResultsText:GetText()
 equal(before:find("cursorRingSize",1,true)~=nil,true,"cursor ring lists its folded options")
 for _,value in ipairs({true,false})do
  local ring=f.checks.cursorRing;ring:SetChecked(value);ring:Fire("OnClick");Flush()
  equal(E.settings.cursorRing,value,"Cursor Ring switched "..(value and "on" or "off").." in search results")
  local now={};for i,e in ipairs(Reading(f))do now[i]=e.key end
  equal(table.concat(now,","),before,"the same results after switching it "..(value and "on" or "off"))
  equal(f.searchResultsText:GetText().." / "..f.sectionTitle:GetText(),count.." / Search results","still searching after switching it "..(value and "on" or "off"))
  equal(f.checks.darkAuraBorders:IsShown()or f.checks.hideZoneText:IsShown(),false,"no page cards show through after switching it "..(value and "on" or "off"))
  equal(f.searchTags[ring]:IsShown(),true,"its tab name still shows")
 end
 E.settings.cursorRing=nil
 f.searchBox:SetText("");Flush()

 -- The Appearance style buttons scroll with the cards.
 Open(f,"appearance")
 equal(f.appearanceChoices[1]:GetParent()==row and f.appearanceChoices[2]:GetParent()==row and row:GetParent()==f.settingsContent,true,"the style buttons are in the scrolling content")
 f.settingsScroll:ClearAllPoints();f.settingsScroll:SetPoint("TOPLEFT",f,"TOPLEFT",202,-148);f.settingsScroll:SetSize(718,200)
 f:LayoutSettings(true)
 local top,gap=f.appearanceChoices[2]:GetTop(),f.appearanceChoices[2]:GetTop()-f.checks.darkAuraBorders:GetTop()
 f:SetSettingsScroll(60)
 equal(f.appearanceChoices[2]:GetTop(),top+60,"the style buttons move with the scroll")
 equal(f.appearanceChoices[2]:GetTop()-f.checks.darkAuraBorders:GetTop(),gap,"and keep their place above the cards")
 f.appearanceChoices[1]:Fire("OnClick")
 equal(E.settings.darkMode,false,"and still work scrolled")
 f:SetSetupMode(false);Flush()
end

-- Class-coloured Unit Borders needs Dark Mode and Unit Frames.
do
 local E,f=Session("HUNTER")
 local card=f.checks.classColourBorders
 local lines={}
 GameTooltip={SetOwner=function()end,SetText=function(_,t)lines={t}end,AddLine=function(_,t)lines[#lines+1]=t end,
  Show=function()end,Hide=function()end,IsOwned=function()return true end}
 E.settings.darkMode=nil;E.settings.unitFrames=true;f:RefreshDependencies()
 equal(card.dependencyDisabled,true,"Class-coloured Unit Borders greyed out without Dark Mode, even with Unit Frames")
 card.dependencyHelp:Fire("OnEnter")
 equal(table.concat(lines,"\n"):find("Enable Dark Mode to use this feature.",1,true)~=nil,true,"its hover names Dark Mode")
 card:SetChecked(true);card:Fire("OnClick")
 equal(E.settings.classColourBorders,nil,"and it can't be switched on")
 E.settings.darkMode=true;E.settings.unitFrames=false;f:RefreshDependencies()
 equal(card.dependencyDisabled,true,"greyed out without Unit Frames too")
 card.dependencyHelp:Fire("OnEnter")
 equal(table.concat(lines,"\n"):find("Enable Unit Frames on the Frames & Nameplates tab to use this feature.",1,true)~=nil,true,"then its hover names Unit Frames as its card is named, and its tab")
 equal(card.description:GetText(),"Class-coloured unit frame borders. Needs Dark Mode and Unit Frames.","its summary names both")
 -- Every hover names a switch by its card's label, with the tab only when it is another one.
 local names={}
 for key,check in pairs(f.checks)do if check.text then names[check.text:GetText()]=key end end
 E.settings.unitFrames=false;E.settings.spellbook=false;E.settings.actionBars=false;E.settings.advancedCastBar=false
 E.settings.afkScreen=false;E.settings.darkMode=true;E.settings.darkAuraBorders=false;f:RefreshDependencies()
 for key,check in pairs(f.checks)do
  if check.dependencyHelp and check.dependencyDisabled then
   lines={};check.dependencyHelp:Fire("OnEnter")
   local name,tab=lines[2]:match("^Enable (.-) on the (.-) tab to use this feature%.$")
   name=name or lines[2]:match("^Enable (.-) to use this feature%.$")
   local owner=name and f.checks[names[name]]
   equal(owner~=nil,true,key.." hover names a card: "..tostring(lines[2]))
   equal(tab,owner.category~=check.category and f.tabs[owner.category].text:GetText()or nil,key.." hover gives the tab only when it is another one")
  end
 end
 E.settings.unitFrames,E.settings.spellbook,E.settings.actionBars,E.settings.advancedCastBar=nil,nil,nil,nil
 E.settings.afkScreen,E.settings.darkAuraBorders=nil,nil
 E.settings.darkMode=nil;f:RefreshDependencies();card.dependencyHelp:Fire("OnEnter")
 equal(table.concat(lines,"\n"):find("Enable Dark Mode to use this feature.",1,true)~=nil,true,"with both off, Dark Mode first")
 equal(table.concat(lines,"\n"):find("Requires Dark Mode and Unit Frames.",1,true)~=nil,true,"its help names both")
 E.settings.darkMode=true;E.settings.unitFrames=true;f:RefreshDependencies()
 equal(card.dependencyDisabled,false,"available with Dark Mode and Unit Frames")
 card:SetChecked(true);card:Fire("OnClick")
 equal(E.settings.classColourBorders,true,"and it switches on")
 E.settings.darkMode=nil;E.settings.classColourBorders=nil;f:RefreshDependencies()
 Open(f,"appearance")
 equal(card.dependencyDisabled,true,"greyed again without Dark Mode")
 f.appearanceChoices[2]:Fire("OnClick")
 equal(card.dependencyDisabled,false,"choosing Dark Mode frees it at once")
 GameTooltip=nil
end

-- New-player hints pulse on the class and Casting tabs. They are saved by tab
-- number: the old numbers (version 1: class 12, Casting 13) move once.
do
 -- saved: what the onboarding save wrote while settings initialised (the
 -- per-character CVar copy), or nil when nothing was saved.
 local saved
 local function Hints(onboarding)
  saved=nil
  local E,f=Session("MAGE",nil,nil,{onboarding=onboarding},function(E)
   E.SaveCharOnboarding=function()
    local o=EraUIClassicCharDB.onboarding;local tabs={}
    for k in pairs(o.discoverTabs or{})do tabs[#tabs+1]=k end;table.sort(tabs)
    saved=tostring(o.discoveryHintsVersion)..":"..table.concat(tabs,".")
   end
  end)
  return E,f,EraUIClassicCharDB.onboarding
 end
 local E,f,o=Hints({setupComplete=true,discoveryHintsVersion=1,discoverTabs={[12]=true,[13]=true}})
 local class,casting=Tab(f,"class"),Tab(f,"casting")
 equal(class..","..casting,"2,5","the class and Casting tabs are second and fifth")
 equal(o.discoveryHintsVersion,2,"old hints move to the new order once (version 2)")
 equal(saved,"2:2.5","and the move is saved at once, so the CVar copy has it too")
 local n=0;for _ in pairs(o.discoverTabs)do n=n+1 end
 equal(o.discoverTabs[class]==true and o.discoverTabs[casting]==true and n,2,"the class and Casting hints follow their tabs, nothing else")
 Open(f,"appearance")
 for _,tab in ipairs(f.tabs)do if tab.scripts.OnUpdate then tab:Fire("OnUpdate",.1)end end
 local pulsing={}
 for i,tab in ipairs(f.tabs)do if tab.hint and tab.hint:IsShown()then pulsing[#pulsing+1]=tab.id end end
 equal(table.concat(pulsing,","),"class,casting","the class and Casting tabs pulse")
 f.tabs[class]:Fire("OnClick");f.tabs[class]:Fire("OnUpdate",.1)
 equal(o.discoverTabs[class]==nil and f.selectedCategory==class and not f.tabs[class].hint:IsShown(),true,"clicking the class tab opens it and ends its hint")
 equal(o.discoverTabs[casting],true,"Casting still pulses")
 E,f,o=Hints({setupComplete=true,discoveryHintsVersion=1,discoverTabs={[13]=true}})
 equal(o.discoverTabs[Tab(f,"casting")]==true and o.discoverTabs[Tab(f,"class")]==nil and o.discoverTabs[13]==nil,true,"a hint already seen stays seen")
 equal(saved,"2:5","a hint already seen is saved as seen")
 E,f,o=Hints({setupComplete=true})
 equal(o.discoveryHintsVersion==2 and o.discoverTabs[Tab(f,"class")]==true and o.discoverTabs[Tab(f,"casting")]==true,true,"setup done before the hints: both pulse")
 equal(saved,"2:2.5","and that is saved")
 -- The onboarding CVar stores no version as 0 (Core/Integration.lua), so a
 -- character loaded from it has version 0, not nil: the same case.
 E,f,o=Hints({setupComplete=true,discoveryHintsVersion=0,discoverTabs={}})
 equal(o.discoveryHintsVersion==2 and o.discoverTabs[Tab(f,"class")]==true and o.discoverTabs[Tab(f,"casting")]==true,true,"setup done before the hints, read from the CVar (version 0): both pulse")
 equal(saved,"2:2.5","and that is saved")
 E,f,o=Hints({setupComplete=true,discoveryHintsVersion=2,discoverTabs={[5]=true}})
 equal(o.discoverTabs[5]==true and o.discoverTabs[2]==nil and o.discoveryHintsVersion==2,true,"version 2 hints are not moved again")
 equal(saved,nil,"and nothing is saved again")
 E,f,o=Hints({})
 equal(o.discoverTabs,nil,"no hints before setup")
 E,f,o=Hints({discoveryHintsVersion=0})
 equal(o.discoverTabs==nil and saved==nil,true,"no hints before setup, even from the CVar")
end

-- The walkthrough: seven option pages, and every option it offered before is
-- still offered (Class-coloured Chat Names once: the style page, or Chat &
-- Names when the style page is skipped).
do
 local E,f=Session("DRUID")
 local era=_G.EraUI;local real={};assert(loadfile("Core/Init.lua"))("EraUI",real);_G.EraUI=era
 for key in pairs(real.reloadSettings)do E.reloadSettings[key]=true end
 for _,key in ipairs(E.Presets.LOOK)do E.settings[key]=true;f.loadedSettings[key]=true end
 local TODAY={"mapQuestObjectives","movableMap","revealMap","rewardUpgradeHighlight","rewardProfile",
  "vendorPrice","bagSpace","questLevels","cleanMinimap","coordinates","showAllSpellRanks","gryphons","hideEmptyActionSlots",
  "autoSellJunk","autoRepair","linkToggle","bagItemLevels","hideSecondaryNames","classColors","classicChatDragging","hideStatusMessages",
  "fastAutoLoot","autoGossip","durabilityWarning","tooltipIDs","junkValueSummary","showWelcomeOnLogin","autoQuests",
  "autoSummon","autoResurrect","releasePvP","discardCheapestJunk","hideKeybindText","hideMacroText","hideZoneText","maxCameraZoom",
  "cursorRing","cursorRingClassColour","cursorRingSize","cursorRingThickness","cursorCastRing","cursorCastClassColour",
  "cursorCastSize","cursorCastOpacity","cursorCastColour","cursorTrail","cursorTrailClassColour","cursorTrailSize",
  "cursorTrailOpacity","cursorTrailLength","cursorTrailColour","afkScreen","afkCameraNormal","afkTurnRight","afkZoom",
  "afk24Hour","afkShowGuild","afkShowZone","afkShowDate","afkShowQuote","blockDuels","blockPartyInvites","partyFromFriends",
  "inviteFromWhispers","damageFont","damageTextScale"}
 E.settings.cursorRing,E.settings.cursorCastRing,E.settings.cursorTrail=true,true,true
 local function Walk(preset)
  f:SetSetupMode(false);Flush();f:SetSetupMode(true);Flush()
  f.setupPreset=preset
  local offered,titles,count={},{},{}
  for page=1,40 do
   f.setupPage=page;f:RenderSetup();Flush()
   if f.setupPage<page then break end
   local progress=f.setupProgress:GetText()
   local option=progress:match("^OPTIONS  (%d+) / 7$")
   if option then
    titles[#titles+1]=f.sectionTitle:GetText()
    equal(#f.sectionAbout:GetText()>0,true,preset.." "..progress.." explains its page")
   end
   for key,card in pairs(f.checks)do
    if card:IsShown()then
     offered[key]=true;count[key]=(count[key]or 0)+1
     if option then equal(not E.reloadSettings[key]or key=="classicChatDragging",true,preset.." "..progress..": "..key.." is no reload-only look")end
    end
   end
   if option then
    NoCardOverlaps(f,preset.." "..progress);SubOptionsFollow(f,preset.." "..progress)
    -- Only Screen & Cursor is long enough to scroll.
    local long=f.sectionTitle:GetText()=="Screen & Cursor"
    equal(f.settingsContent:GetHeight()>f.settingsScroll:GetHeight()+.01,long,preset.." "..f.sectionTitle:GetText()..(long and " scrolls" or " fits without scrolling"))
   end
  end
  return offered,titles,count
 end
 local offered,titles,count=Walk("classicqol")
 equal(table.concat(titles,","),"Action Bars,Map & Minimap,Quests,Bags & Vendors,Chat & Names,Group & Invites,Screen & Cursor","the seven option pages")
 for _,key in ipairs(TODAY)do equal(offered[key],true,"Classic + QoL: "..key.." still in the walkthrough")end
 equal(count.classColors,1,"Class-coloured Chat Names once, on the style page")
 equal(count.tooltipIDs,1,"Tooltip IDs once")
 offered,titles,count=Walk("qol")
 equal(#titles,7,"QoL only: the same seven option pages")
 for _,key in ipairs(TODAY)do equal(offered[key],true,"QoL only: "..key.." still in the walkthrough")end
 equal(count.classColors,1,"QoL only: Class-coloured Chat Names on the Chat & Names page")
 -- Tooltip IDs joins Chat & Names, after Click Links Again to Close.
 local function Page(title)
  for page=1,40 do
   f.setupPage=page;f:RenderSetup();Flush()
   if f.sectionTitle:GetText()==title then return true end
  end
 end
 f:SetSetupMode(false);Flush();f:SetSetupMode(true);Flush();f.setupPreset="classicqol"
 Page("Chat & Names")
 local chat={};for i,e in ipairs(Reading(f))do chat[i]=e.key end
 equal(table.concat(chat,","),"hideSecondaryNames,classicChatDragging,linkToggle,tooltipIDs,hideStatusMessages,showWelcomeOnLogin","Tooltip IDs on Chat & Names, after Click Links Again to Close")
 Page("Bags & Vendors")
 equal(f.checks.tooltipIDs:IsShown(),false,"and no longer on Bags & Vendors")
 -- Show Gryphons waits on the Action Bars look, which the walkthrough leaves
 -- out: with the look off it can't be switched on, so it is left out too.
 E.settings.actionBars=false
 Page("Action Bars")
 equal(f.checks.gryphons:IsShown(),false,"Action Bars look off: no greyed Show Gryphons")
 equal(f.checks.hideEmptyActionSlots:IsShown()and f.checks.showAllSpellRanks:IsShown(),true,"the other Action Bars options stay")
 E.settings.actionBars=true;f:RenderSetup();Flush()
 equal(f.checks.gryphons:IsShown()and not f.checks.gryphons.dependencyDisabled,true,"Action Bars look on: Show Gryphons offered, and it can be switched")
 -- Folded options fold in the walkthrough too, and open at once.
 E.settings.cursorRing=nil
 f:SetSetupMode(false);Flush();f:SetSetupMode(true);Flush();f.setupPreset="classicqol"
 for page=1,40 do
  f.setupPage=page;f:RenderSetup();Flush()
  if f.sectionTitle:GetText()=="Screen & Cursor"then break end
 end
 equal(f.sectionTitle:GetText()=="Screen & Cursor"and f.checks.cursorRing:IsShown()and not f.checks.cursorRingSize:IsShown(),true,"walkthrough: the cursor ring's options folded while it is off")
 f.checks.cursorRing:SetChecked(true);f.checks.cursorRing:Fire("OnClick");Flush()
 equal(f.setupMode and f.checks.cursorRingSize:IsShown(),true,"and open when it is switched on")
 f:SetSetupMode(false);Flush()
end

-- The one-time new layout note, at the top of the window.
do
 local E,f=Session("PRIEST")
 local banner=f.layoutNotice
 f:Hide();f:Show();Flush()
 equal(banner:IsShown(),false,"no new layout note unless Integration asked for one")
 E.settings.layoutNotice=0;f:Hide();f:Show();Flush()
 equal(banner:IsShown(),false,"a fresh install never gets it")
 E.settings.layoutNotice=1;f:Hide();f:Show();Flush()
 equal(banner:IsShown(),true,"a returning player sees the new layout note")
 local words=banner.text:GetText()
 equal(words:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""),"New layout: every option now lives with its topic. Can't find something? Use Search.","its words")
 equal(words:find("^|cff%x%x%x%x%x%xNew layout:|r ")~=nil,true,"New layout: in your class colour")
 equal(banner:GetTop()<=f:GetTop()-7.99 and banner:GetBottom()>=f.sectionTitle:GetTop()+5.99 and banner:GetLeft()>=f.tabs[1]:GetRight(),true,"at the top of the window, above the title with room, beside the tabs")
 -- It ends before the Presets column, so its X is far from the window's own.
 equal(banner:GetRight()<=f.presetButton:GetLeft()-20 and banner:GetRight()<=f.presetLabel:GetRight()-8,true,"it ends before the Presets column")
 equal(banner.close:GetRight()<=f:GetRight()-150,true,"its X well clear of the window's own X")
 -- Colour codes take no room on screen; the words at 6 per letter.
 local drawn=banner.text:GetText():gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
 equal(#drawn*6<=banner:GetRight()-banner:GetLeft()-40,true,"its words fit one line beside its X")
 equal(banner.close:IsShown(),true,"with an X")
 f:SetSetupMode(true);Flush()
 equal(banner:IsShown(),false,"never in the setup walkthrough")
 f:SetSetupMode(false);Flush()
 equal(banner:IsShown()and E.settings.layoutNotice==1,true,"still waiting after the walkthrough")
 local saves,save=0,E.SaveSettings
 E.SaveSettings=function()saves=saves+1 end
 banner.close:Fire("OnClick")
 equal(banner:IsShown()or E.settings.layoutNotice~=0,false,"the X puts it away and saves that")
 equal(saves,1,"saved at once, so the backup keeps it")
 f:Hide();f:Show();Flush()
 equal(banner:IsShown(),false,"gone for good")
 E.settings.layoutNotice=1;f:Hide();f:Show();Flush()
 equal(banner:IsShown(),true,"shown again for this check")
 f:Hide()
 equal(E.settings.layoutNotice,0,"closing /era after seeing it uses it up")
 equal(saves,2,"and saves that too")
 f:Show();Flush()
 equal(banner:IsShown(),false,"so it shows once")
 f:Hide()
 equal(saves,2,"once used up, closing /era saves nothing more")
 E.SaveSettings=save
end

-- Tidy labels: Title Case, "&" not "/", "Class-coloured", summaries that fit
-- their two lines (the card's 244 wide box at 6 per letter) and one-line names.
do
 local E,f=Session("WARLOCK")
 local MINOR={a=true,an=true,["and"]=true,the=true,of=true,on=true,to=true,["in"]=true,from=true,["for"]=true,with=true}
 local function TitleCase(label)
  local first=true
  for word in label:gmatch("%S+")do
   if word:find("%w")then
    local lead=word:match("%w")
    if not(lead:match("[%u%d]")or(not first and MINOR[word]))then return false end
    first=false
   end
  end
  return true
 end
 local function Lines(text,chars)
  local lines,line=0,""
  for word in text:gmatch("%S+")do
   if line==""then line=word elseif #line+1+#word<=chars then line=line.." "..word else lines=lines+1;line=word end
  end
  return lines+(line~=""and 1 or 0)
 end
 local classPage,summaries={},{}
 for _,key in ipairs(f.pages.class)do classPage[key]=true end
 for key,card in pairs(f.checks)do
  if not classPage[key]and card.text then
   local label=card.text:GetText()
   if not card.description then label=label:gsub(":%s.*$","")end -- sliders show their value
   local name=label:gsub(" %(Needs testing%)$","")
   equal(TitleCase(name),true,key.." label in Title Case: "..label)
   equal(label:find("/",1,true),nil,key.." label uses & not /")
   equal(#label*7<=244,true,key.." label fits one line: "..label)
   local lower=label:lower()
   if lower:find("class",1,true)and lower:find("colo",1,true)then
    equal(label:find("^Class%-coloured ")~=nil,true,key.." says Class-coloured: "..label)
   end
   equal(lower:find("colored",1,true)==nil and lower:find("colors",1,true)==nil,true,key.." British spelling")
   if card.description then
    local summary=card.description:GetText()
    equal(Lines(summary,40)<=2,true,key.." summary fits two lines: "..summary)
    equal(summary:find("\226\128\148",1,true)==nil and summary~="Classic presentation.",true,key.." summary says what it does")
    equal(summaries[summary],nil,key.." summary is its own");summaries[summary]=true
   end
  end
 end
 for id,label in pairs(f.sectionLabels)do
  equal(label.text:GetText(),label.text:GetText():upper(),id.." label in small capitals")
  equal(label.text:GetText():find("/",1,true),nil,id.." uses & not /")
 end
 for _,tab in ipairs(f.tabs)do equal(tab.text:GetText():find("/",1,true),nil,tab.id.." tab uses & not /")end
 equal(f.checks.rewardProfile.label:GetText():find("^Reward Profile: ")~=nil,true,"the reward profile card in Title Case")
end

-- Every tab name fits inside its tab (its highlight) and ends before the
-- sidebar divider, for all nine classes. The mock's six-per-letter width is
-- no good here, so widths are honest for the tab font: the tab names as
-- measured in game (Friz Quadrata at 13, from the user's 2026-10-01
-- screenshots at 1.2 scale, edge anti-aliasing included), and for any other
-- name a glyph estimate that is never under those measurements.
do
 local MEASURED={["Appearance"]=80.1,["Hunter"]=45.0,["Action Bars"]=75.9,["Frames & Nameplates"]=145.9,
  ["Casting"]=49.2,["Map & Minimap"]=110.1,["Quests"]=45.9,["Character & Spells"]=123.4,["Bags & Vendors"]=105.1,
  ["Chat & Names"]=95.1,["Group & Invites"]=106.8,["Windows & Tooltips"]=135.9,["Screen & Cursor"]=108.4,
  ["More from Squirt"]=115.9}
 local function Glyphs(text)
  local width=0
  for c in text:gmatch(".")do
   width=width+(c==" "and 3.4 or("iljtfr"):find(c,1,true)and 5.4 or("mwMW&"):find(c,1,true)and 12.5 or 8.0)
  end
  return width*1.06
 end
 for name,width in pairs(MEASURED)do equal(Glyphs(name)>=width,true,"the glyph estimate is never under the game's width: "..name)end
 local function Width(text,size)return(MEASURED[text]or Glyphs(text))*(size or 13)/13 end
 local NAMES={WARRIOR="Warrior",PALADIN="Paladin",HUNTER="Hunter",ROGUE="Rogue",PRIEST="Priest",
  SHAMAN="Shaman",MAGE="Mage",WARLOCK="Warlock",DRUID="Druid"}
 local oldClass=UnitClass
 UnitClass=function()return NAMES[token]or token,token end
 for _,c in ipairs({"HUNTER","MAGE","ROGUE","WARRIOR","PALADIN","SHAMAN","PRIEST","WARLOCK","DRUID"})do
  local E,f=Session(c)
  local divider=f.navDivider:GetLeft()
  equal(#f.tabs,14,c.." 14 tabs")
  for _,tab in ipairs(f.tabs)do
   local name=tab.text:GetText()
   local size=tab.text.font and tab.text.font[2]
   local right=tab.text:GetLeft()+Width(name,size)
   equal(right+2<=tab:GetRight(),true,c.." "..name.." fits inside its tab: text to "..string.format("%.1f",right-f:GetLeft()).." of "..(tab:GetRight()-f:GetLeft()))
   equal(tab:GetRight()<divider,true,c.." "..name.." tab ends before the sidebar divider")
   -- The label is held inside its tab on one line, so a name that renders
   -- wider at another UI scale is cut short inside the highlight instead of
   -- running over the divider, and every tab name fits it whole.
   local label=tab.text
   equal(label.wordWrap==false and label.justifyH=="LEFT",true,c.." "..name.." label on one line from the left")
   equal(#label.points==2 and label:GetRight()<=tab:GetRight()-2,true,c.." "..name.." label held 2 inside its tab")
   equal(right<=label:GetRight(),true,c.." "..name.." fits its label whole: text to "..string.format("%.1f",right-f:GetLeft()).." of "..string.format("%.1f",label:GetRight()-f:GetLeft()))
  end
  equal(f.tabs[2].text:GetText(),NAMES[c],c.." the class tab shows the class name")
  -- The pages start just right of the list and keep their width.
  equal(f.settingsScroll:GetLeft()-divider,13,c.." the cards start 13 right of the divider")
  equal(f.settingsScroll:GetWidth(),718,c.." the cards keep their width")
  equal(f.searchBox:GetLeft()-divider,19,c.." search lines up with the page title")
  equal(f.navigation:GetRight(),divider,c.." the dark list backing ends at the divider")
 end
 UnitClass=oldClass
end
print("Settings layout/combat checks passed: "..checks.." assertions.")
