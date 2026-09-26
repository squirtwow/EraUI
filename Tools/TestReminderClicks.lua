-- Real reminder rendering/options/action setup. Restricted state snippets run
-- separately from addon callbacks; protected parents/anchors reject combat edits.
local checks=0
local function Equal(a,b,label)
 checks=checks+1;assert(a==b,label..": expected "..tostring(b)..", got "..tostring(a))
end
local secret={}
local function Session(class)
 local frames,drivers={},{}
 local combat,restricted=false,false
 local known,pet,settings={}, {exists=false,dead=false}, {enabled=true,classReminders=true}
 local env=setmetatable({}, {__index=_G});env._G=env
 local methods={}
 local function Guard(f)assert(not(combat and f.protected and not restricted),"protected addon edit during combat")end
 local function Frame(parent,template)
  local f=setmetatable({parent=parent,scripts={},hooks={},attrs={},shown=true,width=52,height=52,
   x=1000,y=500,scale=.64,level=10,protected=not not(template and template:find("SecureActionButtonTemplate",1,true))}, {__index=methods})
  if f.protected then
   local p=parent
   while p and p~=env.UIParent do p.protected=true;p=p.parent end
  end
  frames[#frames+1]=f;return f
 end
 for _,name in ipairs({"SetBackdrop","SetBackdropColor","SetBackdropBorderColor","SetColorTexture","SetTexCoord",
  "SetTextColor","SetShadowColor","SetShadowOffset","SetJustifyH","SetWordWrap","SetClampedToScreen","SetMovable",
  "RegisterForDrag","EnableMouse","SetFont","SetAllPoints","RegisterEvent","Enable","Disable","SetAlpha"})do
  methods[name]=function(self)Guard(self)end
 end
 function methods:SetScript(event,fn)self.scripts[event]=fn end
 function methods:HookScript(event,fn)self.hooks[event]=self.hooks[event]or{};table.insert(self.hooks[event],fn)end
 function methods:Fire(event,...)
  local was=restricted;restricted=false
  if self.scripts[event]then self.scripts[event](self,...)end
  for _,fn in ipairs(self.hooks[event]or{})do fn(self,...)end
  restricted=was
 end
 function methods:SetShown(value)
  Guard(self);value=not not value
  if self.shown~=value then self.shown=value;self:Fire(value and "OnShow"or "OnHide")end
 end
 function methods:Show()self:SetShown(true)end
 function methods:Hide()self:SetShown(false)end
 function methods:IsShown()return self.shown and(not self.parent or self.parent:IsShown())end
 function methods:SetAttribute(key,value)Guard(self);self.attrs[key]=value end
 function methods:SetSize(w,h)Guard(self);self.width,self.height=w,h end
 function methods:SetWidth(w)Guard(self);self.width=w end
 function methods:SetHeight(h)Guard(self);self.height=h end
 function methods:GetWidth()return self.width end
 function methods:GetHeight()return self.height end
 function methods:SetPoint(...)
  Guard(self);self.point={...}
  local target=self.point[2]
  if self.protected and type(target)=="table"and target~=env.UIParent then target.protected=true end
 end
 function methods:ClearAllPoints()Guard(self);self.point=nil end
 function methods:GetCenter()return self.x,self.y end
 function methods:GetLeft()return self.x-self.width/2 end
 function methods:GetTop()return self.y+self.height/2 end
 function methods:GetEffectiveScale()return self.scale end
 function methods:SetFrameStrata(strata)Guard(self);self.strata=strata end
 function methods:SetFrameLevel(level)Guard(self);self.level=level end
 function methods:GetFrameLevel()return self.level end
 function methods:GetParent()return self.parent end
 function methods:CreateTexture()return Frame(self)end
 function methods:CreateFontString()return Frame(self)end
 function methods:SetText(text)self.text=text end
 function methods:GetText()return self.text end
 function methods:GetStringWidth()return #(self.text or "")*10 end
 function methods:GetFont()return "font",12 end
 function methods:SetTexture(texture)self.texture=texture end
 function methods:RegisterForClicks(...)self.clicks={...}end
 function methods:StartMoving()self.moving=true end
 function methods:StopMovingOrSizing()self.moving=false end
 env.UIParent=Frame();env.GameFontHighlight=Frame();env.GameFontHighlightSmall=Frame()
 env.CreateFrame=function(_,name,parent,template)
  assert(not(combat and template and template:find("Secure")),"secure creation during combat")
  local f=Frame(parent,template);if name then env[name]=f end;return f
 end
 env.RegisterStateDriver=function(f,state,condition)
  Guard(f);Equal(condition,"[combat] 1; 0","secure combat driver")
  drivers[f]=state
 end
 env.InCombatLockdown=function()return combat end
 env.issecretvalue=function(v)return v==secret end
 env.UnitClass=function()return class,class end
 env.UnitLevel=function()return 60 end
 env.UnitExists=function(unit)return unit=="player"or pet.exists end
 env.UnitIsDeadOrGhost=function(unit)return unit=="pet"and pet.dead or false end
 env.UnitCanAssist=function()return true end
 env.UnitIsConnected=function()return true end
 env.GetTime=function()return 10 end
 env.IsPlayerSpell=function(id)return known[id]==true end
 local names={[883]="Call Pet",[982]="Revive Pet",[13165]="Aspect of the Hawk",[14318]="Aspect of the Hawk",
  [5118]="Aspect of the Cheetah",[1243]="Power Word: Fortitude",[688]="Summon Imp",[6201]="Create Healthstone"}
 env.C_Spell={GetSpellInfo=function(id)return {name=names[id]or "Spell"..id,iconID=id}end}
 env.C_UnitAuras={GetAuraDataByIndex=function()return nil end}
 env.WorldMapFrame=Frame();env.WorldMapFrame:Hide()
 env.EraUIDB={reminderSpotVersion=2}
 local E={modules={}}
 function E:RegisterModule(name,module)self.modules[name]=module end
 function E:GetSetting(key)return settings[key]end
 assert(loadfile("Modules/ClassTools.lua","t",env))("EraUI",E)
 E.ClassTools.BindInlinePanel=function()end
 assert(loadfile("Modules/ClassReminderData.lua","t",env))("EraUI",E)
 assert(loadfile("Modules/ClassReminders.lua","t",env))("EraUI",E)
 local M=E.modules.ClassReminders
 local s={E=E,M=M,env=env,known=known,pet=pet,settings=settings,frames=frames}
 function s:combat(value)
  combat=value
  for f,state in pairs(drivers)do
   restricted=true
   assert(load(f.attrs["_onstate-"..state],"restricted state","t",{self=f,newstate=value and "1"or "0"}))()
   restricted=false
  end
 end
 function s:row(key)
  for _,f in ipairs(frames)do if f.def and f.def.key==key and f:IsShown()then return f end end
 end
 function s:options()
  local parent=Frame();local anchor=Frame(parent)
  M:AttachOptions(parent,anchor);return M:OptionsPanel()
 end
 function s:click(row)
  local a=row.action
  return a and a:IsShown()and a.attrs.type1=="macro"and a.attrs.macrotext1 or nil
 end
 return s
end

local s=Session("HUNTER")
s.known[883]=true;s.known[982]=true;s.M:Initialize()
local row=s:row("pet")
Equal(row.text.text,"SUMMON PET!","absent pet label")
Equal(row.action,nil,"clicks default off")
local options=s:options()
options.clickable:Fire("OnClick")
Equal(s.env.EraUIDB.reminderClickable,true,"user can enable reminder clicks")
Equal(s:click(row),"/cast [nocombat] Call Pet","Call Pet belongs to missing pet icon")
Equal(row.action.parent,s.env.UIParent,"secure click parent is independent")
Equal(row.action.point[2],s.env.UIParent,"secure click anchor is independent")
Equal(row.protected,false,"presentation row is not protected")
row.iconFrame.x,row.iconFrame.y,row.iconFrame.scale=1800,900,.32
s.M:Refresh()
Equal(row.action.point[4],900,"overlay x correct with differing effective scale")
Equal(row.action.point[5],450,"overlay y correct with differing effective scale")
Equal(row.action.width,26,"overlay hit width matches scaled icon")
row:Fire("OnDragStart")
Equal(s:click(row),nil,"dragging text disarms click overlay")
row:Fire("OnDragStop")
Equal(s:click(row),"/cast [nocombat] Call Pet","drag stop restores aligned action")
s.pet.exists=true;s.pet.dead=true;s.M:Refresh()
Equal(s:row("pet"),nil,"no duplicate summon reminder for a dead pet")
row=s:row("petDead")
Equal(row.text.text,"PET DEAD!","dead pet has distinct title")
Equal(row.icon.texture,982,"dead pet uses Revive Pet icon")
Equal(s:click(row),"/cast [nocombat] Revive Pet","recycled row uses Revive Pet instead of Call Pet")
options.prev:Fire("OnClick")
Equal(s:click(s:row("petDead")),nil,"preview never casts even for genuinely missing effects")
options.prev:Fire("OnClick")
s.env.WorldMapFrame:Show()
Equal(s:click(row),nil,"opening map immediately disarms overlay")
s.env.WorldMapFrame:Hide()
Equal(s:click(s:row("petDead")),"/cast [nocombat] Revive Pet","map close restores live action")
options.clickable:Fire("OnClick")
Equal(s.env.EraUIDB.reminderClickable,false,"user can disable reminder clicks")
Equal(s:click(row),nil,"disabling removes live click target")
options.clickable:Fire("OnClick")
s.env.EraUIDB.reminderCombat=true
s:combat(true)
Equal(row.action.shown,false,"secure state hides click immediately on combat entry")
Equal(row.action.attrs.type1,nil,"combat removes action type")
Equal(row.action.attrs.macrotext1,nil,"combat removes previous spell")
s.M:Refresh()
Equal(s:row("petDead")~=nil,true,"combat reminder continues displaying without protected edits")
options.clickable:Fire("OnClick")
Equal(s.env.EraUIDB.reminderClickable,true,"options do not mutate click policy in combat")
s.pet.dead=false;s.M:Refresh()
Equal(s:row("petDead"),nil,"revival hides informational combat reminder")
s.pet.exists=false;s.M:Refresh()
Equal(s:row("pet")~=nil,true,"combat recycling can display another reminder")
s:combat(false)
Equal(row.action.shown,false,"combat exit cannot resurrect stale click target")
Equal(row.action.attrs.type1,nil,"combat exit remains disarmed until current state is read")
s.M:Refresh()
Equal(s:click(s:row("pet")),"/cast [nocombat] Call Pet","post-combat reconciliation selects current spell")
s.settings.classReminders=false;s.M:Refresh()
Equal(s:click(row),nil,"module disable clears independent overlay")
s.settings.classReminders=true;s.pet.dead=secret;s.M:Refresh()
Equal(s:row("pet"),nil,"secret death state has no speculative summon")
Equal(s:row("petDead"),nil,"secret death state has no speculative revival")
s.pet.exists=true;s.pet.dead=false;s.M:Refresh()
s:combat(true);s.pet.dead=true;s.M:Refresh()
Equal(s:row("petDead")~=nil,true,"prebuilt display can report a new combat death")
Equal(s:click(s:row("petDead")),nil,"new combat alert has no click action")
s:combat(false)
s.known[883]=nil;s.known[982]=nil;s.known[13165]=true;s.known[14318]=true;s.M:Refresh()
row=s:row("aspect")
Equal(s:click(row),"/cast [nocombat,@player] Aspect of the Hawk","aspect uses supported cast default")
s.env.EraUIDB.reminderChoice_HUNTER_aspect=5118;s.known[5118]=true;s.M:Refresh()
Equal(s:click(row),"/cast [nocombat,@player] Aspect of the Cheetah","selected aspect changes action")
s.env.EraUIDB.reminder_HUNTER_aspect=false;s.M:Refresh()
Equal(s:click(row),nil,"per-reminder opt-out disarms action")

local priest=Session("PRIEST")
priest.known[1243]=true;priest.env.EraUIDB.reminderClickable=true;priest.M:Initialize()
Equal(priest:click(priest:row("fortitude")),"/cast [nocombat,@target,help,nodead][nocombat,@player] Power Word: Fortitude","buff uses explicit friendly-target/self fallback")
local warlock=Session("WARLOCK")
warlock.known[688]=true;warlock.known[6201]=true;warlock.env.EraUIDB.reminderClickable=true;warlock.M:Initialize()
Equal(warlock:click(warlock:row("pet")),nil,"Any demon never chooses a summon arbitrarily")
warlock.env.EraUIDB.reminderChoice_WARLOCK_pet=688;warlock.M:Refresh()
Equal(warlock:click(warlock:row("pet")),"/cast [nocombat] Summon Imp","chosen demon is clickable")
Equal(warlock:click(warlock:row("healthstone")),"/cast [nocombat] Create Healthstone","creation reminder casts spell rather than uses item")
Equal(warlock:click(warlock:row("shards")),nil,"supply count reminder has no invented action")
local quiet=Session("HUNTER")
quiet.known[883]=true;quiet.known[982]=true;quiet.pet.exists=true
quiet.env.EraUIDB.reminderCombat=true;quiet.M:Initialize()
Equal(quiet:row("petDead"),nil,"healthy login starts without pet-dead alert")
quiet:combat(true);quiet.pet.dead=true;quiet.M:Refresh()
Equal(quiet:row("petDead")~=nil,true,"first ever alert can appear during combat")
Equal(quiet:click(quiet:row("petDead")),nil,"first combat alert stays informational")
print("Reminder click lifecycle: "..checks.." assertions passed")
