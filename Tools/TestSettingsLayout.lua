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
  assert(loadfile("Core/Presets.lua"))("EraUI",E)
  assert(loadfile("Modules/CombatFont.lua"))("EraUI",E)
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
 equal(Steps(),9,"Classic + QoL without Questie: style, damage text, six option pages, finish")
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
 Next();Next();Next();Next();Next()
 equal(f.checks.hideKeybindText:IsShown(),true,"Text & Camera options page")
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
 equal(Steps(),8,"QoL only: damage text, six option pages, then finish")
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
 f.trackerChoices[1]:Fire("OnClick");Flush()
 equal(choice,"classic","tracker choice applied")
 f.setupBack:Fire("OnClick");Flush();f.setupBack:Fire("OnClick");Flush()
 equal(Steps(),10,"Classic + QoL with Questie: style, tracker, damage text, six option pages, finish")
 f.setupNext:Fire("OnClick")
 equal(reloads,1,"finish reloads straight from the click")
 f:SetSetupMode(false);Flush()
 equal(f.trackerChoices[1]:IsShown()or choices[1]:IsShown(),false,"walkthrough choices hidden outside setup")

 -- /era: the active preset is a label, never a warning.
 equal(f.presetButton:IsShown(),true,"Presets button in /era")
 -- The update notice: a small tick under Presets, not a card.
 local notice=f.updateNotice
 equal(notice:IsShown()and notice.on,true,"Update notice ticked under Presets")
 equal(f.checks.updateCheck,nil,"and not a card in Quality of Life")
 notice:Fire("OnClick")
 equal(E.settings.updateCheck,false,"unticking turns it off")
 notice:Fire("OnClick")
 equal(E.settings.updateCheck,true,"and on again")
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
 equal(more.category,14,"More from Squirt has its own tab")
 more:SetChecked()
 equal(more.open.shown,false,"not installed: no Open button")
 equal(more.state:GetText(),"Coming soon to CurseForge and GitHub.","not out yet: coming soon")
 equal(more.curse.shown or more.github.shown,false,"with no links until it has pages")
 local opened
 C_AddOns={IsAddOnLoaded=function(name)return name=="ForeverEnhancedCooldownManager"end}
 SlashCmdList.FECM=function()opened=true end
 more:SetChecked()
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
 f:SetSetupMode(false);Flush()
end
print("Settings layout/combat checks passed: "..checks.." assertions.")
