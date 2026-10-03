-- Real reminder rendering/options/action setup. Restricted state snippets run
-- separately from addon callbacks; protected parents/anchors reject combat edits.
local checks=0
local function Equal(a,b,label)
 checks=checks+1;assert(a==b,label..": expected "..tostring(b)..", got "..tostring(a))
end
local secret={}
-- The icon of an alert on Any with nothing to cast yet: no one spell's.
local UNDECIDED="Interface\\Icons\\INV_Misc_QuestionMark"
-- Pet health the game hides in combat: comparing it, adding it up or joining
-- it to text errors, so the addon can only hand it on.
local hiddenMeta={}
for _,op in ipairs({"__eq","__lt","__le","__add","__sub","__mul","__div","__mod","__pow","__unm","__idiv","__concat","__len","__index","__call"})do
 hiddenMeta[op]=function()error("a hidden health value was read")end
end
local function Hidden(v)return setmetatable({hidden=true,value=v},hiddenMeta)end
local function IsHidden(v)return rawequal(v,secret)or(type(v)=="table"and rawget(v,"hidden")==true)end
local function Session(class)
 local frames,drivers={},{}
 local combat,restricted=false,false
 local known,pet,settings={}, {exists=false,dead=false}, {enabled=true,classReminders=true}
 local noMana={} -- spells you lack the mana for
 local env=setmetatable({}, {__index=_G});env._G=env
 local methods={}
 local function Guard(f)assert(not(combat and f.protected and not restricted),"protected addon edit during combat")end
 -- Layout (show, hide, move, size, mouse, attributes) is refused in combat on a
 -- secure frame and on anything drawn inside one; recolouring and fading are not.
 local function Locked(f)
  while f and f~=env.UIParent do if f.protected then return true end;f=f.parent end
  return false
 end
 local function Lock(f)assert(not(combat and Locked(f)and not restricted),"protected addon layout during combat")end
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
  "SetTextColor","SetShadowColor","SetShadowOffset","SetJustifyH","SetClampedToScreen","SetMovable",
  "RegisterForDrag","EnableMouseWheel"})do
  methods[name]=function(self)Guard(self)end
 end
 for _,name in ipairs({"SetWordWrap","SetAllPoints","SetScale"})do methods[name]=function(self)Lock(self)end end
 function methods:SetFont(file,size)Lock(self);self.fontFile,self.fontSize=file,size end
 function methods:Enable()Guard(self);self.enabled=true end
 function methods:Disable()Guard(self);self.enabled=false end
 -- As the game does, SetAlpha takes a hidden value and draws with it.
 function methods:SetAlpha(a)
  Guard(self)
  if IsHidden(a)then self.alpha=rawget(a,"value");self.hiddenAlpha=true
  else assert(type(a)=="number","alpha must be a number");self.alpha=a;self.hiddenAlpha=false end
 end
 function methods:EnableMouse(v)Lock(self);self.mouse=v end
 function methods:SetScript(event,fn)self.scripts[event]=fn end
 function methods:RegisterEvent(event)Guard(self);self.events=self.events or{};self.events[event]=true end
 function methods:HookScript(event,fn)self.hooks[event]=self.hooks[event]or{};table.insert(self.hooks[event],fn)end
 function methods:Fire(event,...)
  local was=restricted;restricted=false
  if self.scripts[event]then self.scripts[event](self,...)end
  for _,fn in ipairs(self.hooks[event]or{})do fn(self,...)end
  restricted=was
 end
 function methods:SetShown(value)
  Lock(self);value=not not value
  if self.shown~=value then self.shown=value;self:Fire(value and "OnShow"or "OnHide")end
 end
 function methods:Show()self:SetShown(true)end
 function methods:Hide()self:SetShown(false)end
 function methods:IsShown()return self.shown and(not self.parent or self.parent:IsShown())end
 function methods:SetAttribute(key,value)Lock(self);self.attrs[key]=value end
 function methods:SetSize(w,h)Lock(self);self.width,self.height=w,h end
 function methods:SetWidth(w)Lock(self);self.width=w end
 function methods:SetHeight(h)Lock(self);self.height=h end
 function methods:GetWidth()return self.width end
 function methods:GetHeight()return self.height end
 function methods:SetPoint(...)
  Lock(self);self.point={...}
  local target=self.point[2]
  if self.protected and type(target)=="table"and target~=env.UIParent then target.protected=true end
 end
 function methods:ClearAllPoints()Lock(self);self.point=nil end
 function methods:GetCenter()return self.x,self.y end
 function methods:GetLeft()return self.x-self.width/2 end
 function methods:GetTop()return self.y+self.height/2 end
 function methods:GetEffectiveScale()return self.scale end
 function methods:SetFrameStrata(strata)Lock(self);self.strata=strata end
 function methods:SetFrameLevel(level)Lock(self);self.level=level end
 function methods:GetFrameLevel()return self.level end
 function methods:GetParent()return self.parent end
 function methods:CreateTexture()return Frame(self)end
 function methods:CreateFontString()return Frame(self)end
 function methods:SetText(text)self.text=text end
 function methods:GetText()return self.text end
 function methods:GetStringWidth()return #(self.text or "")*10 end
 function methods:GetFont()return "font",12 end
 function methods:SetTexture(texture)self.texture=texture end
 function methods:SetVertexColor(r,g,b)self.tint={r,g,b}end
 function methods:RegisterForClicks(...)Lock(self);self.clicks={...}end
 function methods:StartMoving()self.moving=true end
 function methods:StopMovingOrSizing()self.moving=false end
 env.UIParent=Frame();env.GameFontHighlight=Frame();env.GameFontHighlightSmall=Frame()
 env.CreateFrame=function(_,name,parent,template)
  assert(not(combat and template and template:find("Secure")),"secure creation during combat")
  local f=Frame(parent,template);if name then env[name]=f end;return f
 end
 -- The game's macro conditions for the pet: [combat], [@pet,exists],
 -- [@pet,dead], each with its no- form. Groups in one clause are either/or.
 local function Condition(group)
  local unit,met="target",true
  for word in group:gmatch("[^,]+")do
   word=word:match("^%s*(.-)%s*$")
   if word:sub(1,1)=="@"then unit=word:sub(2)
   else
    local negate=word:sub(1,2)=="no";local key=negate and word:sub(3)or word
    local v
    if key=="combat"then v=combat
    elseif key=="exists"then v=unit=="pet"and pet.exists==true
    elseif key=="dead"then v=unit=="pet"and pet.exists==true and pet.dead==true
    else error("unknown macro condition "..word)end
    if negate then v=not v end
    if not v then met=false end
   end
  end
  return met
 end
 local function Parse(rule)
  for clause in rule:gmatch("[^;]+")do
   local groups={}
   local value=clause:gsub("%[(.-)%]",function(g)groups[#groups+1]=g;return ""end):match("^%s*(.-)%s*$")
   local hit=#groups==0
   for _,g in ipairs(groups)do if Condition(g)then hit=true end end
   if hit then return value end
  end
 end
 -- A visibility driver is the game's own secure code showing or hiding.
 local function Resolve(f,rule)
  local v=Parse(rule)
  restricted=true
  if v=="show"then f:Show()elseif v=="hide"then f:Hide()end
  restricted=false
 end
 local registered={}
 env.RegisterStateDriver=function(f,state,condition)
  Guard(f);assert(not combat,"state driver registered during combat")
  if state=="combat"then Equal(condition,"[combat] 1; 0","secure combat driver")
  else Equal(state,"visibility","only combat and visibility drivers")end
  drivers[f]=drivers[f]or{};drivers[f][state]=condition
  registered[#registered+1]={frame=f,state=state,rule=condition}
  if state=="visibility"then Resolve(f,condition)end
 end
 env.InCombatLockdown=function()return combat end
 env.issecretvalue=IsHidden
 -- Pet health: public out of combat, hidden in combat (or when pet.hideHealth).
 local function Health(v)if combat or pet.hideHealth then return Hidden(v)end;return v end
 env.UnitHealth=function(unit)return unit=="pet"and Health(pet.health or 100)or 100 end
 env.UnitHealthMax=function(unit)return unit=="pet"and(pet.max or 100)or 100 end
 env.Enum={LuaCurveType={Linear=0,Step=1}}
 env.C_CurveUtil={CreateCurve=function()
  local c={points={}}
  function c:SetType(t)self.kind=t end
  function c:ClearPoints()self.points={}end
  function c:AddPoint(x,y)self.points[#self.points+1]={x,y}end
  function c:Evaluate(x)
   local p=self.points;if #p==0 then return 0 end
   if x<=p[1][1]then return p[1][2]end
   for i=2,#p do
    if x==p[i][1]then return p[i][2]end
    if x<p[i][1]then local a,b=p[i-1],p[i];return a[2]+(b[2]-a[2])*(x-a[1])/(b[1]-a[1])end
   end
   return p[#p][2]
  end
  return c
 end}
 env.UnitHealthPercent=function(unit,_,c)
  local v=unit=="pet"and(pet.health or 100)/(pet.max or 100)or 1
  return Health(c and c:Evaluate(v)or v)
 end
 env.UnitClass=function()return class,class end
 env.UnitLevel=function()return 60 end
 env.UnitExists=function(unit)return unit=="player"or pet.exists end
 env.UnitIsDeadOrGhost=function(unit)return unit=="pet"and pet.dead or false end
 env.UnitCanAssist=function()return true end
 env.UnitIsConnected=function()return true end
 env.GetTime=function()return 10 end
 env.IsPlayerSpell=function(id)return known[id]==true end
 local names={[883]="Call Pet",[982]="Revive Pet",[13165]="Aspect of the Hawk",[14318]="Aspect of the Hawk",
  [5118]="Aspect of the Cheetah",[1243]="Power Word: Fortitude",[688]="Summon Imp",[697]="Summon Voidwalker",
  [6201]="Create Healthstone",[19740]="Blessing of Might",[19742]="Blessing of Wisdom",
  [25291]="Blessing of Might",[25782]="Greater Blessing of Might",[25916]="Greater Blessing of Might",
  [25894]="Greater Blessing of Wisdom",[10938]="Power Word: Fortitude",[21564]="Prayer of Fortitude",
  [10157]="Arcane Intellect",[23028]="Arcane Brilliance",[9885]="Mark of the Wild",[21850]="Gift of the Wild",
  [25289]="Battle Shout",[712]="Summon Succubus",[713]="Summon Incubus",[1299346]="Trueshot Aura",
  [20154]="Seal of Righteousness",[20293]="Seal of Righteousness",[1311649]="Seal of Fury",[20423]="Seal of Fury",
  [20165]="Seal of Light",[20349]="Seal of Light",[465]="Devotion Aura",[10293]="Devotion Aura",
  [7294]="Retribution Aura",[10301]="Retribution Aura",[19876]="Shadow Resistance Aura",[19896]="Shadow Resistance Aura",
  [136]="Mend Pet",[3661]="Mend Pet",[13544]="Mend Pet",[755]="Health Funnel",[11695]="Health Funnel",
  [8681]="Instant Poison",[2835]="Deadly Poison",[3420]="Crippling Poison",[5763]="Mind-numbing Poison",[13220]="Wound Poison"}
 env.C_Spell={GetSpellInfo=function(id)return {name=names[id]or "Spell"..id,iconID=id}end,
  IsSpellUsable=function(id)if noMana[id]==secret then return false,secret end;if noMana[id]then return false,true end;return true,false end}
 env.C_UnitAuras={GetAuraDataByIndex=function()return nil end}
 env.WorldMapFrame=Frame();env.WorldMapFrame:Hide()
 env.EraUIDB={reminderSpotVersion=2}
 local E={modules={}}
 function E:RegisterModule(name,module)self.modules[name]=module end
 function E:GetSetting(key)return settings[key]end
 assert(loadfile("Modules/PoisonData.lua","t",env))("EraUI",E)
 assert(loadfile("Modules/ClassTools.lua","t",env))("EraUI",E)
 E.ClassTools.BindInlinePanel=function()end
 assert(loadfile("Modules/ClassReminderData.lua","t",env))("EraUI",E)
 assert(loadfile("Modules/ClassReminderPoisons.lua","t",env))("EraUI",E)
 assert(loadfile("Modules/ClassReminders.lua","t",env))("EraUI",E)
 local M=E.modules.ClassReminders
 local s={E=E,M=M,env=env,known=known,pet=pet,settings=settings,frames=frames,noMana=noMana,registered=registered}
 -- The game's 0.2 s driver pass: every visibility rule is read again.
 function s:drivers()
  for f,list in pairs(drivers)do if list.visibility then Resolve(f,list.visibility)end end
 end
 -- As Forever 70170's SecureStateDriver (resolveDriver): the rule's answer
 -- turns into a number when it reads as one ("1" is sent as 1), and the
 -- state's snippet runs only when the state changes.
 function s:combat(value)
  combat=value
  for f,list in pairs(drivers)do
   if list.combat then
    local state=Parse(list.combat)
    if state=="nil"then state=nil else state=tonumber(state)or state end
    if f.attrs["state-combat"]~=state then
     restricted=true
     f.attrs["state-combat"]=state
     assert(load(f.attrs["_onstate-combat"],"restricted state","t",{self=f,newstate=state}))()
     restricted=false
    end
   end
  end
  s:drivers()
 end
 -- The secure pet alert that stands in for a reminder in combat.
 function s:alert(key)
  for _,f in ipairs(frames)do if f.combatKey==key then return f end end
 end
 function s:parse(rule)return Parse(rule)end
 function s:row(key)
  for _,f in ipairs(frames)do if f.def and f.def.key==key and f:IsShown()then return f end end
 end
 function s:options()
  local parent=Frame();local anchor=Frame(parent)
  M:AttachOptions(parent,anchor);return M:OptionsPanel()
 end
 function s:click(row)
  local a=row and row.action
  return a and a:IsShown()and a.attrs.type1=="macro"and a.attrs.macrotext1 or nil
 end
 function s:event(...)
  for _,f in ipairs(frames)do if f.scripts.OnEvent and f.scripts.OnUpdate then f.scripts.OnEvent(f,...)end end
 end
 -- The module's event frame: its registrations and its refresh clock.
 function s:listener()
  for _,f in ipairs(frames)do if f.scripts.OnEvent and f.scripts.OnUpdate then return f end end
 end
 function s:tick(dt)local f=s:listener();f.scripts.OnUpdate(f,dt)end
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
s:event("UNIT_SPELLCAST_SUCCEEDED","player","cast-1",5118);s.M:Refresh()
Equal(s:click(row),"/cast [nocombat,@player] Aspect of the Hawk","aspects keep their own default, whatever you cast last")
Equal(s.env.EraUIDB.reminderLast_HUNTER_aspect,nil,"so nothing is remembered for them")
s.env.EraUIDB.reminderChoice_HUNTER_aspect=5118;s.known[5118]=true;s.M:Refresh()
Equal(s:click(row),"/cast [nocombat,@player] Aspect of the Cheetah","selected aspect changes action")
s.env.EraUIDB.reminder_HUNTER_aspect=false;s.M:Refresh()
Equal(s:click(row),nil,"per-reminder opt-out disarms action")

local priest=Session("PRIEST")
priest.known[1243]=true;priest.env.EraUIDB.reminderClickable=true;priest.M:Initialize()
Equal(priest:click(priest:row("fortitude")),"/cast [nocombat,@player] Power Word: Fortitude","missing on you: a click buffs you, whoever is targeted")
local fort=priest:row("fortitude")
Equal(fort.sub.text:find("Not enough mana",1,true),nil,"no mana note while you can cast it")
priest.noMana[1243]=true;priest.M:Refresh()
Equal(fort.sub.text:find("Not enough mana",1,true)~=nil,true,"out of mana: said under the icon")
Equal(fort.icon.tint[3]==1 and fort.icon.tint[1],.5,"the icon takes the mana tint")
Equal(priest:click(fort),nil,"and can't be clicked until you can cast it")
priest.noMana[1243]=nil;priest.M:Refresh()
Equal(fort.sub.text:find("Not enough mana",1,true),nil,"the note goes once you have the mana")
Equal(fort.icon.tint[1],1,"the tint too")
Equal(priest:click(fort)~=nil,true,"and it can be clicked again")
priest.noMana[1243]=secret;priest.M:Refresh()
Equal(fort.sub.text:find("Not enough mana",1,true),nil,"a hidden answer is never read as out of mana")
priest.noMana[1243]=true;priest.env.EraUIDB.reminderMana=false;priest.M:Refresh()
Equal(fort.sub.text:find("Not enough mana",1,true),nil,"the note can be switched off")
Equal(priest:options().mana~=nil,true,"with its own option")
priest.noMana[1243]=nil;priest.env.EraUIDB.reminderMana=nil
-- Missing only on a party member: a friendly target first, then you.
priest.env.GetNumSubgroupMembers=function()return 1 end
priest.env.UnitIsUnit=function(a,b)return a==b end
priest.env.UnitName=function(unit)return unit=="party1"and "Bob"or "Me"end
priest.env.UnitExists=function(unit)return unit=="player"or unit=="party1"end
priest.env.C_UnitAuras={GetAuraDataByIndex=function(unit,i)if unit=="player"and i==1 then return {spellId=1243}end end}
priest.M:Refresh()
Equal(priest:row("fortitude").sub.text,"Missing on Bob","only the party member lacks it")
Equal(priest:click(priest:row("fortitude")),"/cast [nocombat,@target,help,nodead][nocombat,@player] Power Word: Fortitude","for others, a friendly target first")
-- Prayer of Fortitude needs a candle: it counts as the buff, but a click
-- casts the highest single-target rank, and the alert is named after that.
priest.known[10938]=true;priest.known[21564]=true;priest.M:Refresh()
fort=priest:row("fortitude")
Equal(priest:click(fort),"/cast [nocombat,@target,help,nodead][nocombat,@player] Power Word: Fortitude","Prayer of Fortitude known: a click still casts Power Word: Fortitude")
Equal(fort.text.text,"POWER WORD: FORTITUDE!","the alert names the single-target spell")
Equal(fort.icon.texture,10938,"and shows its icon")
Equal(priest.M:OptionsPanel().mana.label.text,"Say when you're out of mana","a priest's option says mana")
-- Carrying Sacred Candles, the click casts Prayer of Fortitude again.
priest.env.GetItemCount=function(id)return id==17029 and 5 or 0 end;priest.M:Refresh()
Equal(priest:click(fort),"/cast [nocombat,@target,help,nodead][nocombat,@player] Prayer of Fortitude","with candles in your bags a click casts Prayer of Fortitude")
Equal(fort.text.text,"PRAYER OF FORTITUDE!","and the alert names it")
priest.env.GetItemCount=nil;priest.M:Refresh()
-- Arcane Brilliance and Gift of the Wild need reagents too.
for _,case in ipairs({{"MAGE","intellect",10157,23028,"Arcane Intellect"},{"DRUID","mark",9885,21850,"Mark of the Wild"}})do
 local caster=Session(case[1])
 caster.known[case[3]]=true;caster.known[case[4]]=true;caster.env.EraUIDB.reminderClickable=true;caster.M:Initialize()
 Equal(caster:click(caster:row(case[2])),"/cast [nocombat,@player] "..case[5],case[5].." known with its group version: a click casts "..case[5])
end
-- Battle Shout costs rage, so a warrior short of it is told rage, not mana.
local warrior=Session("WARRIOR")
warrior.known[25289]=true;warrior.env.EraUIDB.reminderClickable=true;warrior.M:Initialize()
local shout=warrior:row("battleShout")
Equal(warrior:click(shout),"/cast [nocombat,@player] Battle Shout","Battle Shout is clickable with the rage for it")
Equal(shout.sub.text:find("Not enough",1,true),nil,"no note while you can cast it")
warrior.noMana[25289]=true;warrior.M:Refresh()
Equal(shout.sub.text:find("Not enough rage",1,true)~=nil,true,"short of rage: says Not enough rage")
Equal(shout.sub.text:find("mana",1,true),nil,"never mana")
Equal(shout.icon.tint[1]==1 and shout.icon.tint[3],.5,"the icon takes a rage tint, not the mana one")
Equal(warrior:click(shout),nil,"and can't be clicked until you have the rage")
Equal(warrior:options().mana.label.text,"Say when you're out of rage","the warrior's option says rage")
warrior.M:OptionsPanel().mana:Fire("OnClick")
Equal(tostring(warrior.env.EraUIDB.reminderRage).." "..tostring(warrior.env.EraUIDB.reminderMana),"false nil","it has its own switch, so mana notes stay on for other classes")
Equal(shout.sub.text:find("Not enough rage",1,true),nil,"switched off, the rage note goes")
warrior.M:OptionsPanel().mana:Fire("OnClick")
warrior.noMana[25289]=nil;warrior.M:Refresh()
Equal(shout.sub.text:find("Not enough",1,true),nil,"the note goes once you have the rage")
Equal(warrior:click(shout)~=nil,true,"and it can be clicked again")
local warlock=Session("WARLOCK")
warlock.known[688]=true;warlock.known[6201]=true;warlock.env.EraUIDB.reminderClickable=true;warlock.M:Initialize()
Equal(warlock:click(warlock:row("pet")),"/cast [nocombat] Summon Imp","Any demon with only the Imp known summons the Imp")
Equal(warlock:row("pet").hint,nil,"with nothing to explain")
warlock.known[697]=true;warlock.M:Refresh()
Equal(warlock:click(warlock:row("pet")),nil,"two known and neither cast yet: Any never guesses")
Equal(warlock:row("pet").icon.texture,UNDECIDED,"nor shows either demon's icon")
Equal(warlock:row("pet").hint,"Use a demon once and clicking here casts that one from then on. Or pick one in /era: Advanced, then Demon.",
 "hovering says what to do")
warlock:event("UNIT_SPELLCAST_SUCCEEDED","player","cast-1",697);warlock.M:Refresh()
Equal(warlock:click(warlock:row("pet")),"/cast [nocombat] Summon Voidwalker","then it summons the one you cast last")
Equal(warlock:row("pet").hint,nil,"and the hint goes")
Equal(warlock:row("pet").icon.texture,697,"its icon shows that one")
warlock:event("UNIT_SPELLCAST_SUCCEEDED","party1","cast-2",688)
warlock:event("UNIT_SPELLCAST_SUCCEEDED","player","cast-3",secret);warlock.M:Refresh()
Equal(warlock:click(warlock:row("pet")),"/cast [nocombat] Summon Voidwalker","others' casts and hidden spell IDs don't count")
warlock.env.EraUIDB.reminderChoice_WARLOCK_pet=688;warlock.M:Refresh()
Equal(warlock:click(warlock:row("pet")),"/cast [nocombat] Summon Imp","chosen demon is clickable")
Equal(warlock:click(warlock:row("healthstone")),"/cast [nocombat] Create Healthstone","creation reminder casts spell rather than uses item")
Equal(warlock:click(warlock:row("shards")),nil,"supply count reminder has no invented action")
-- Blessings on Any: the only one you know, or the one you cast last.
local paladin=Session("PALADIN")
paladin.known[19740]=true;paladin.env.EraUIDB.reminderClickable=true;paladin.M:Initialize()
local blessing=paladin:row("blessing")
Equal(paladin:click(blessing),"/cast [nocombat,@player] Blessing of Might","Any blessing with only Might known casts Might")
paladin.known[19742]=true;paladin.M:Refresh()
Equal(paladin:click(blessing),nil,"Might and Wisdom known, none cast yet: no guess")
Equal(blessing.icon.texture,UNDECIDED,"and no one blessing's icon either")
Equal(blessing.hint,"Use a blessing once and clicking here casts that one from then on. Or pick one in /era: Advanced, then Blessing.",
 "hovering says to use one first, or pick one")
paladin:event("UNIT_SPELLCAST_SUCCEEDED","player","cast-1",19742);paladin.M:Refresh()
Equal(paladin:click(blessing),"/cast [nocombat,@player] Blessing of Wisdom","then a click casts the one you cast last")
Equal(paladin.env.EraUIDB.reminderLast_PALADIN_blessing,19742,"remembered for next time")
paladin.env.EraUIDB.reminderChoice_PALADIN_blessing=19740;paladin.M:Refresh()
Equal(paladin:click(blessing),"/cast [nocombat,@player] Blessing of Might","a blessing you pick always wins")
paladin.env.EraUIDB.reminderChoice_PALADIN_blessing=0;paladin.env.EraUIDB.reminderLast_PALADIN_blessing=nil
paladin.env.EraUIDB.reminderClickable=false;paladin.M:Refresh()
Equal(blessing.hint,nil,"no hint while reminder clicks are off")
-- Greater Blessings need Symbol of Kings: they count as the buff, but a click
-- casts the single-target blessing's highest known rank.
paladin.env.EraUIDB.reminderClickable=true;paladin.known[19742]=nil
paladin.known[25291]=true;paladin.known[25782]=true;paladin.known[25916]=true;paladin.M:Refresh()
Equal(paladin:click(blessing),"/cast [nocombat,@player] Blessing of Might","Any with Greater Might known casts Blessing of Might")
Equal(blessing.icon.texture,25291,"and shows its highest single-target rank's icon")
paladin.known[19742]=true;paladin.known[25894]=true
paladin:event("UNIT_SPELLCAST_SUCCEEDED","player","cast-2",25894);paladin.M:Refresh()
Equal(paladin.env.EraUIDB.reminderLast_PALADIN_blessing,19742,"a Greater Blessing you cast counts as its blessing")
Equal(paladin:click(blessing),"/cast [nocombat,@player] Blessing of Wisdom","then a click casts the single-target one")
paladin.env.EraUIDB.reminderChoice_PALADIN_blessing=19740;paladin.M:Refresh()
Equal(paladin:click(blessing),"/cast [nocombat,@player] Blessing of Might","a picked blessing also casts the single-target one")
paladin.env.C_UnitAuras={GetAuraDataByIndex=function(unit,i)if unit=="player"and i==1 then return {spellId=25916}end end}
paladin.M:Refresh()
Equal(paladin:row("blessing"),nil,"Greater Blessing of Might on you counts as the buff")
paladin.env.C_UnitAuras={GetAuraDataByIndex=function()return nil end}
paladin.env.EraUIDB.reminderChoice_PALADIN_blessing=0;paladin.env.EraUIDB.reminderLast_PALADIN_blessing=nil
-- Seals and auras have a choice button each, like blessings.
local sealer=Session("PALADIN")
local tip={}
sealer.env.GameTooltip={SetOwner=function(_,owner)tip={owner=owner}end,SetText=function(_,text)tip.title=text end,
 AddLine=function(_,text)tip[#tip+1]=text end,Show=function()tip.shown=true end,Hide=function()tip.shown=false end}
sealer.known[20154]=true;sealer.known[465]=true
for key,value in pairs({reminder_PALADIN_seal=true,reminder_PALADIN_aura=true,reminderClickable=true})do sealer.env.EraUIDB[key]=value end
sealer.M:Initialize()
Equal(sealer:click(sealer:row("seal")),"/cast [nocombat,@player] Seal of Righteousness","one seal known: a click casts it")
Equal(sealer:click(sealer:row("aura")),"/cast [nocombat,@player] Devotion Aura","one aura known: a click casts it")
Equal(sealer:row("seal").icon.texture.." "..sealer:row("aura").icon.texture,"20154 465","each showing that spell's icon")
Equal(sealer:row("seal").text.text,"SEAL!","on Any the alert says SEAL!")
sealer.known[20293]=true;sealer.known[20349]=true;sealer.known[20423]=true
sealer.known[10293]=true;sealer.known[10301]=true;sealer.known[19896]=true;sealer.M:Refresh()
Equal(sealer:click(sealer:row("seal")),nil,"at 60 on Any, a seal click no longer casts Seal of Light")
Equal(sealer:click(sealer:row("aura")),nil,"nor an aura click Shadow Resistance Aura")
Equal(sealer:row("seal").icon.texture,UNDECIDED,"and SEAL! shows no one seal's icon, Seal of Light's included")
Equal(sealer:row("aura").icon.texture,UNDECIDED,"nor AURA! Shadow Resistance Aura's")
Equal(sealer:row("seal").hint,"Use a seal once and clicking here casts that one from then on. Or pick one in /era: Advanced, then Seal.","hovering SEAL! says what to do")
Equal(sealer:row("aura").hint,"Use an aura once and clicking here casts that one from then on. Or pick one in /era: Advanced, then Aura.","and AURA! too")
sealer:event("UNIT_SPELLCAST_SUCCEEDED","player","cast-1",20423);sealer.M:Refresh()
Equal(sealer:click(sealer:row("seal")),"/cast [nocombat,@player] Seal of Fury","then a click casts the seal you cast last")
Equal(sealer:row("seal").icon.texture,20423,"with its icon")
Equal(sealer:row("seal").hint,nil,"and the hint goes")
Equal(sealer:click(sealer:row("aura")),nil,"a seal cast leaves the aura on Any")
sealer:event("UNIT_SPELLCAST_SUCCEEDED","player","cast-2",10301);sealer.M:Refresh()
Equal(sealer:click(sealer:row("aura")),"/cast [nocombat,@player] Retribution Aura","and the aura you cast last")
Equal(sealer:click(sealer:row("seal")),"/cast [nocombat,@player] Seal of Fury","each remembered on its own")
local sealOptions=sealer:options();sealOptions.adv:Fire("OnClick")
local blessButton,blessSwitch,sealSwitch,auraSwitch
for _,f in ipairs(sealOptions.advRows)do
 local text=f.label.text or ""
 if text:find("^Blessing:")then blessButton=f elseif text=="BLESSING!"then blessSwitch=f
 elseif text=="SEAL!"then sealSwitch=f elseif text=="AURA!"then auraSwitch=f end
end
-- Their switches have plain labels and take a whole line each, like PET LOW
-- HEALTH!, with the choice button in the line, just left of the switch.
Equal(sealSwitch~=nil and auraSwitch~=nil,true,"/era Advanced labels SEAL! and AURA! plainly")
Equal(sealSwitch:IsShown()and sealSwitch.width.." "..sealSwitch.point[2],"340 12","SEAL! takes a whole line")
Equal(sealSwitch.point[3],blessSwitch.point[3]-26,"under the BLESSING! line")
Equal(auraSwitch.width.." "..auraSwitch.point[2].." "..auraSwitch.point[3],"340 12 "..(sealSwitch.point[3]-26),"and AURA! the line under it")
Equal(blessButton.point[3]==blessSwitch.point[3]and blessButton.point[2]-blessSwitch.point[2],170,"the Blessing button still sits beside BLESSING!")
local sealButton,auraButton=sealSwitch.choice,auraSwitch.choice
Equal(sealButton.parent==sealSwitch and sealButton.point[2]==sealSwitch.track and sealButton.point[1],"RIGHT","the Seal button is in SEAL!'s line, left of the switch")
Equal(auraButton.parent==auraSwitch and auraButton.point[2],auraSwitch.track,"the Aura button in AURA!'s")
Equal(sealButton.label.text,"Any seal  >","the Seal button shows the choice, on Any")
Equal(auraButton.label.text,"Any aura  >","and the Aura button")
Equal(sealSwitch.label.width,126,"the label keeps the rest of the line")
local greyed=0
for _,f in ipairs(sealOptions.items)do if f==sealButton or f==auraButton then greyed=greyed+1 end end
Equal(greyed,2,"both buttons grey out with the other options")
local seen={}
for _=1,4 do sealButton:Fire("OnClick");seen[#seen+1]=sealButton.label.text end
Equal(table.concat(seen," | "),"Seal of Righteousness  > | Seal of Fury  > | Seal of Light  > | Any seal  >",
 "the Seal button cycles through the seals you know and back to Any")
sealButton:Fire("OnClick")
Equal(sealer.env.EraUIDB.reminderChoice_PALADIN_seal,20154,"a picked seal is saved")
Equal(sealer:click(sealer:row("seal")),"/cast [nocombat,@player] Seal of Righteousness","and is what a click casts, whatever you cast last")
Equal(sealer:row("seal").text.text,"SEAL OF RIGHTEOUSNESS!","the alert names it")
Equal(sealer:row("seal").icon.texture,20293,"with its highest known rank's icon")
sealer.env.C_UnitAuras={GetAuraDataByIndex=function(unit,i)if unit=="player"and i==1 then return {spellId=20423}end end}
sealer.M:Refresh()
Equal(sealer:row("seal")~=nil,true,"Seal of Fury up while Righteousness is picked: still reminded")
sealer.env.C_UnitAuras={GetAuraDataByIndex=function(unit,i)if unit=="player"and i==1 then return {spellId=20293}end end}
sealer.M:Refresh()
Equal(sealer:row("seal"),nil,"Righteousness up: no SEAL!")
Equal(sealer:row("aura")~=nil,true,"a seal is not an aura")
seen={}
for _=1,4 do auraButton:Fire("OnClick");seen[#seen+1]=auraButton.label.text end
Equal(table.concat(seen," | "),"Devotion Aura  > | Retribution Aura  > | Shadow Resistance Aura  > | Any aura  >",
 "the Aura button cycles through the auras you know and back to Any")
auraButton:Fire("OnClick")
Equal(sealer:click(sealer:row("aura")),"/cast [nocombat,@player] Devotion Aura","a picked aura is what a click casts")
Equal(sealer:row("aura").text.text,"DEVOTION AURA!","the alert names it")
sealer.env.C_UnitAuras={GetAuraDataByIndex=function(unit,i)if unit=="player"and i==1 then return {spellId=10301}end end}
sealer.M:Refresh()
Equal(sealer:row("aura")~=nil,true,"Retribution Aura up while Devotion is picked: still reminded")
sealer.env.C_UnitAuras={GetAuraDataByIndex=function(unit,i)if unit=="player"and i==1 then return {spellId=10293}end end}
sealer.M:Refresh()
Equal(sealer:row("aura"),nil,"Devotion up: no AURA!")
sealButton:Fire("OnEnter")
Equal(tip.title,"SEAL!","hovering the Seal button names SEAL!")
Equal(tip[1],"Picks the seal this reminder looks for and a click casts. On Any, a click casts the only seal you know, or else the one you cast last.",
 "and what it does")
Equal(tip[2],"Default: Off, Any seal","and its defaults")
Equal(tip.owner==sealButton and tip.shown,true,"shown beside the button")
sealButton:Fire("OnLeave");Equal(tip.shown,false,"leaving hides it")
sealSwitch:Fire("OnEnter")
Equal(tip.owner==sealSwitch and tip.title.." | "..tip[2],"SEAL! | Default: Off, Any seal","the SEAL! switch explains the same")
sealSwitch:Fire("OnLeave")
auraButton:Fire("OnEnter");Equal(tip.title,"AURA!","the Aura button too")
Equal(tip[1]:find("the only aura you know",1,true)~=nil,true,"in its own words")
Equal(tip[1]:find("\226\128\148",1,true),nil,"with no em dash")
tip={};blessButton:Fire("OnEnter");Equal(tip.title,nil,"the Blessing button is unchanged")
-- Seals change all fight long: one cast in combat is remembered at once, but
-- the settings backup waits for the fight to end.
local saves=0;sealer.E.Classic={MirrorSave=function()saves=saves+1 end}
sealer:combat(true)
sealer:event("UNIT_SPELLCAST_SUCCEEDED","player","cast-3",20349)
Equal(sealer.env.EraUIDB.reminderLast_PALADIN_seal,20165,"a seal cast in combat is remembered")
sealer:event("UNIT_SPELLCAST_SUCCEEDED","player","cast-4",20423)
Equal(sealer.env.EraUIDB.reminderLast_PALADIN_seal,1311649,"and the next one")
Equal(saves,0,"without saving settings mid-fight")
sealer:combat(false);sealer:event("PLAYER_REGEN_ENABLED")
Equal(saves,1,"saved once when the fight ends")
sealer:event("PLAYER_REGEN_ENABLED");Equal(saves,1,"and only once")
sealer:event("UNIT_SPELLCAST_SUCCEEDED","player","cast-5",20165);Equal(saves,2,"out of combat a new seal saves straight away")
local quiet=Session("HUNTER")
quiet.known[883]=true;quiet.known[982]=true;quiet.pet.exists=true
quiet.env.EraUIDB.reminderCombat=true;quiet.M:Initialize()
Equal(quiet:row("petDead"),nil,"healthy login starts without pet-dead alert")
quiet:combat(true);quiet.pet.dead=true;quiet.M:Refresh()
Equal(quiet:row("petDead")~=nil,true,"first ever alert can appear during combat")
Equal(quiet:click(quiet:row("petDead")),nil,"first combat alert stays informational")
-- POISON!: a click puts the picked poison on, left-click on the main hand
-- and right-click on the off hand, through one secure button whose
-- attributes change only out of combat. Weapons, coatings and bags are the
-- game's own answers here, read by the real ClassTools.
local ITEM_NAMES={[8928]="Instant Poison VI",[8927]="Instant Poison V",[6947]="Instant Poison",[20844]="Deadly Poison V",
 [3776]="Crippling Poison II",[2892]="Deadly Poison"}
local function Rogue(level)
 local s=Session("ROGUE")
 local env=s.env
 s.level,s.weapons,s.coatings,s.bags=level or 60,{[16]=100,[17]=100},{},{}
 env.UnitLevel=function()return s.level end
 env.GetInventoryItemID=function(_,slot)return s.weapons[slot]end
 env.C_Item={GetItemInfoInstant=function(id)return id,nil,nil,nil,"icon"..id,id==200 and 4 or 2 end,
  GetItemCount=function(id)return s.bags[id]or 0 end,GetItemNameByID=function(id)return ITEM_NAMES[id]end}
 env.C_PaperDollInfo={GetTemporaryEnchantmentInfo=function(slot)return s.coatings[slot]end}
 s.known[2842]=true -- Poisons
 function s:poisonButton()
  for _,f in ipairs(self.frames)do if f.clicks and f.clicks[3]=="RightButtonUp"then return f end end
 end
 -- "type item target-slot | ..." for the left and right click, or nil while put away.
 function s:clicks()
  local b=self:poisonButton()
  if not b or not b:IsShown()then return nil end
  local a=b.attrs
  return tostring(a.type1).." "..tostring(a.item1).." "..tostring(a["target-slot1"]).." | "
   ..tostring(a.type2).." "..tostring(a.item2).." "..tostring(a["target-slot2"])
 end
 return s
end
local FINE={enchantID=323,remainingTimeMs=600000,chargesRemaining=50}
local function Fine()local t={};for k,v in pairs(FINE)do t[k]=v end;return t end
local rogue=Rogue()
rogue.env.EraUIDB.reminderGroup=true
rogue.M:Initialize()
local poisonRow=rogue:row("poison")
Equal(poisonRow and poisonRow.text.text,"POISON!","bare weapons: POISON!")
Equal(poisonRow.sub.text,"Main and off hand: no poison\n|cffffb35cNo poison in your bags|r",
 "it says which hands; with clicks off the picks don't matter, so only that no poison at all is in your bags")
Equal(poisonRow.icon.texture,"Interface\\Icons\\Trade_BrewPoison","with none to use, the poison icon")
Equal(rogue:poisonButton(),nil,"clicks are off by default: no secure button is even made")
local poisonOptions=rogue:options()
Equal(poisonOptions.group:IsShown(),false,"rogues have no group toggle")
Equal(rogue.env.EraUIDB.reminderGroup,true,"a hidden group setting is kept")
Equal(poisonOptions.clickable:IsShown(),true,"rogues now have Clickable reminders")
Equal(poisonOptions.poisonClick:IsShown(),true,"and Click to apply poisons")
Equal(poisonOptions.poisonClick.label.text,"Click to apply poisons (Needs testing)","labelled Needs testing")
Equal(poisonOptions.poisonClick.dependencyDisabled,true,"greyed out until Clickable reminders is on")
Equal(poisonOptions.mana:IsShown(),false,"no out-of-mana note: poisons cost none")
Equal(poisonOptions.combatClick:IsShown(),false,"no pet clicks in combat")
Equal(poisonOptions.mainPoison.label.text,"Main hand: Instant Poison  >","the main hand's pick: Instant by default")
Equal(poisonOptions.offPoison.label.text,"Off hand: Deadly Poison  >","the off hand's: Deadly by default at 60")
local function Below(a,b)return a:IsShown()and b:IsShown()and a.point[3]<b.point[3]end
Equal(Below(poisonOptions.poisonClick,poisonOptions.clickable)and Below(poisonOptions.mainPoison,poisonOptions.poisonClick)
 and Below(poisonOptions.offPoison,poisonOptions.mainPoison)and Below(poisonOptions.prev,poisonOptions.offPoison),true,
 "Click to apply poisons and the two picks sit under Clickable reminders, before Show all reminders")
poisonOptions.poisonClick:Fire("OnClick")
Equal(rogue.env.EraUIDB.reminderPoisonClick,nil,"can't be switched on before Clickable reminders")
poisonOptions.clickable:Fire("OnClick")
Equal(poisonOptions.poisonClick.dependencyDisabled,false,"available once Clickable reminders is on")
Equal(rogue:clicks(),nil,"Clickable reminders alone puts no poison on")
poisonOptions.poisonClick:Fire("OnClick")
Equal(rogue.env.EraUIDB.reminderPoisonClick,true,"Click to apply poisons switched on")
Equal(rogue:clicks(),nil,"with none of either pick in your bags there is nothing to click")
Equal(poisonRow.sub.text,"Main and off hand: no poison\n|cffffb35cNo Instant Poison in your bags|r\n|cffffb35cNo Deadly Poison in your bags|r",
 "with the click live it names each hand's pick there's none of")
rogue.bags={[3776]=1};rogue.M:Refresh()
Equal(rogue:clicks(),nil,"only a poison neither hand picked: still nothing to click")
Equal(poisonRow.sub.text,"Main and off hand: no poison\n|cffffb35cNo Instant Poison in your bags|r\n|cffffb35cNo Deadly Poison in your bags|r",
 "and still names the picks")
poisonOptions.poisonClick:Fire("OnClick")
Equal(poisonRow.sub.text,"Main and off hand: no poison","clicks off with a usable poison in your bags: no note about picks")
rogue.level=40;rogue.bags={[3776]=1};rogue.M:Refresh()
Equal(poisonRow.sub.text,"Main and off hand: no poison\n|cffffb35cYour poisons need a higher level|r","only ranks above your level: says so, without naming a pick")
rogue.level=60;rogue.bags={};poisonOptions.poisonClick:Fire("OnClick")
rogue.bags={[8928]=2,[20844]=1,[6947]=4};rogue.M:Refresh()
local poisonButton=rogue:poisonButton()
Equal(rogue:clicks(),"item item:8928 16 | item item:20844 17","left-click: Instant Poison VI on the main hand; right-click: Deadly Poison V on the off hand")
Equal(table.concat(poisonButton.clicks,","),"LeftButtonUp,LeftButtonDown,RightButtonUp,RightButtonDown","left and right clicks, down or up")
Equal(poisonButton.parent,rogue.env.UIParent,"the secure button's parent is independent")
Equal(poisonButton.point[2],rogue.env.UIParent,"and so is its anchor")
Equal(poisonButton.point[4]==1000 and poisonButton.point[5]==500 and poisonButton.width==52,true,"over the alert's icon, its size")
Equal(poisonButton.strata,"HIGH","above the alert panel's layer")
Equal(poisonButton.level>poisonRow.iconFrame:GetFrameLevel(),true,"and above the icon it covers")
poisonRow.iconFrame.x,poisonRow.iconFrame.y,poisonRow.iconFrame.scale=1800,900,.32
rogue.M:Refresh()
Equal(poisonButton.point[4]==900 and poisonButton.point[5]==450,true,"with a differing effective scale it still sits over the icon")
Equal(poisonButton.width==26 and poisonButton.height==26,true,"and is the icon's size on screen")
poisonRow.iconFrame.x=nil;rogue.M:Refresh()
Equal(poisonButton:IsShown()or poisonButton.attrs.type1~=nil,false,"an icon the game can't place yet: the click is put away")
poisonRow.iconFrame.x,poisonRow.iconFrame.y,poisonRow.iconFrame.scale=1000,500,.64;rogue.M:Refresh()
Equal(rogue:clicks(),"item item:8928 16 | item item:20844 17","placed again: armed again")
Equal(poisonRow.protected,false,"the alert row stays unprotected")
Equal(poisonRow.sub.text,"Main and off hand: no poison","with poisons to use, no note")
Equal(poisonRow.icon.texture,"icon8928","the icon is the poison a left-click puts on")
local poisonHides=0
poisonButton.Hide=function(self)poisonHides=poisonHides+1;return getmetatable(self).__index.Hide(self)end
rogue.M:Refresh();rogue.M:Refresh()
Equal(poisonHides,0,"refreshing never hides the armed click in between, so it never flickers under the mouse")
poisonButton.Hide=nil
local poisonTip={}
rogue.env.GameTooltip={SetOwner=function(_,o)poisonTip.owner=o end,SetText=function(_,t)poisonTip.title=t end,
 AddLine=function(_,t)poisonTip[#poisonTip+1]=t end,Show=function()poisonTip.shown=true end,Hide=function()poisonTip.shown=false end}
poisonButton:Fire("OnEnter")
Equal(poisonTip.title.." | "..tostring(poisonTip[1]).." | "..tostring(poisonTip[2]),
 "POISON! | Left-click: Instant Poison VI on your main hand | Right-click: Deadly Poison V on your off hand","hovering the icon says what each click puts on")
Equal(poisonTip.owner==poisonButton and poisonTip.shown,true,"beside it")
poisonButton:Fire("OnLeave");Equal(poisonTip.shown,false,"leaving hides it")
poisonTip={};poisonRow:Fire("OnEnter")
Equal(poisonTip.title,"Left-click: Instant Poison VI on your main hand\nRight-click: Deadly Poison V on your off hand","hovering the words says the same")
poisonRow:Fire("OnLeave");rogue.env.GameTooltip=nil
-- Only a hand that needs a poison can be clicked.
rogue.coatings[16]=Fine();rogue.M:Refresh()
Equal(rogue:clicks(),"nil nil nil | item item:20844 17","only the off hand needs one: only a right-click")
Equal(poisonRow.sub.text,"Off hand: no poison","and only it is named")
Equal(poisonRow.icon.texture,"icon20844","the icon is the off hand's poison")
rogue.weapons[17]=200;rogue.M:Refresh()
Equal(rogue:row("poison"),nil,"a shield in the off hand: nothing needs poison, POISON! goes")
Equal(poisonButton:IsShown(),false,"and its click with it")
Equal(poisonButton.attrs.type1,nil,"nothing left armed")
rogue.weapons[17]=100;rogue.coatings[16].remainingTimeMs=30000;rogue.M:Refresh()
Equal(rogue:clicks(),"item item:8928 16 | item item:20844 17","under a minute left: the main hand can be clicked again")
Equal(rogue:row("poison").sub.text,"Main hand: 0:30 left\nOff hand: no poison","saying how long is left")
rogue.coatings={[16]=Fine(),[17]=Fine()};rogue.M:Refresh()
Equal(rogue:row("poison"),nil,"both hands poisoned: POISON! goes")
Equal(poisonButton:IsShown(),false,"with its click")
rogue.coatings={}
-- The highest rank you carry that your level allows.
rogue.bags={[6947]=5,[8927]=1,[20844]=1};rogue.M:Refresh()
Equal(poisonButton.attrs.item1,"item:8927","Instant Poison V is the highest carried")
rogue.level=50;rogue.M:Refresh()
Equal(poisonButton.attrs.item1,"item:6947","at 50, V (level 52) can't be used: rank 1 instead")
Equal(poisonButton.attrs.item2,nil,"Deadly Poison V needs 60: no right-click")
Equal(rogue:row("poison").sub.text,"Main and off hand: no poison\n|cffffb35cYour Deadly Poison needs a higher level|r","and it says why")
rogue.level=60;rogue.M:Refresh()
-- None of the hand's pick in your bags: that hand has no click.
rogue.bags={[8928]=1};rogue.M:Refresh()
Equal(rogue:clicks(),"item item:8928 16 | nil nil nil","no Deadly Poison: no right-click")
Equal(rogue:row("poison").sub.text,"Main and off hand: no poison\n|cffffb35cNo Deadly Poison in your bags|r","and it says so")
-- The picks in /era: a click puts the new pick on at once.
rogue.bags={[8928]=1,[3776]=1,[20844]=1}
local pickSaves=0
rogue.E.SaveSettings=function()pickSaves=pickSaves+1 end
poisonOptions.mainPoison:Fire("OnClick")
Equal(poisonOptions.mainPoison.label.text,"Main hand: Deadly Poison  >","the main hand's button cycles to Deadly")
Equal(rogue.env.EraUIClassicCharDB.classTools.poisonPickMain,2892,"saved for this rogue, by Deadly's rank 1 item")
Equal(rogue.env.EraUIDB.reminderChoice_ROGUE_poisonMain,nil,"not for every rogue on the account")
Equal(pickSaves,1,"and the settings backup is saved")
Equal(poisonButton.attrs.item1,"item:20844","a left-click now puts Deadly on")
poisonOptions.mainPoison:Fire("OnClick")
Equal(poisonButton.attrs.item1,"item:3776","then Crippling Poison II")
poisonOptions.offPoison:Fire("OnClick")
Equal(poisonOptions.offPoison.label.text,"Off hand: Crippling Poison  >","the off hand's button cycles on its own")
Equal(poisonButton.attrs.item2,"item:3776","a right-click puts Crippling on too")
-- Never armed by Show all reminders, the map, a drag or a switch turned off.
poisonOptions.prev:Fire("OnClick")
Equal(poisonButton:IsShown(),false,"Show all reminders never arms a click")
poisonOptions.prev:Fire("OnClick")
Equal(poisonButton:IsShown(),true,"back after the preview")
rogue.env.WorldMapFrame:Show()
Equal(poisonButton:IsShown(),false,"opening the map puts the click away at once")
rogue.env.WorldMapFrame:Hide()
Equal(poisonButton:IsShown(),true,"closing it brings it back")
local liveRow=rogue:row("poison")
liveRow:Fire("OnDragStart")
Equal(poisonButton:IsShown(),false,"dragging the alert puts the click away")
liveRow:Fire("OnDragStop")
Equal(poisonButton:IsShown(),true,"and dropping it brings it back")
poisonOptions.poisonClick:Fire("OnClick")
Equal(poisonButton:IsShown()or poisonButton.attrs.type1~=nil,false,"Click to apply poisons off: put away")
poisonOptions.poisonClick:Fire("OnClick")
poisonOptions.clickable:Fire("OnClick")
Equal(poisonButton:IsShown(),false,"Clickable reminders off: put away too")
Equal(poisonOptions.poisonClick.dependencyDisabled,true,"and Click to apply poisons greys out")
poisonOptions.clickable:Fire("OnClick")
Equal(poisonButton:IsShown(),true,"both on again: armed")
rogue.env.EraUIDB.reminder_ROGUE_poison=false;rogue.M:Refresh()
Equal(rogue:row("poison"),nil,"POISON! switched off in Advanced: no alert")
Equal(poisonButton:IsShown(),false,"and no click")
rogue.env.EraUIDB.reminder_ROGUE_poison=nil
rogue.settings.classReminders=false;rogue.M:Refresh()
Equal(poisonButton:IsShown(),false,"Class Reminders & Buffs off: no click")
rogue.M:UpdateOptionsState()
local greyedPicks=0
for _,f in ipairs(poisonOptions.items)do if f==poisonOptions.mainPoison or f==poisonOptions.offPoison then greyedPicks=greyedPicks+1 end end
Equal(greyedPicks,2,"both picks grey out with the other options")
Equal(poisonOptions.mainPoison.enabled==false and poisonOptions.offPoison.enabled==false,true,"Class Reminders & Buffs off: the picks are greyed out")
rogue.settings.classReminders=true;rogue.M:Refresh();rogue.M:UpdateOptionsState()
Equal(poisonOptions.mainPoison.enabled and poisonOptions.offPoison.enabled,true,"on again: the picks work again")
-- A fight takes the click away at once, and nothing secure is touched until
-- it ends. (This harness errors on any change to a protected frame in combat.)
-- Without Show during combat (the default) the alert hides in the fight, and
-- the game's own code hides the click too: nothing unseen is left on screen
-- to catch a click or start a poison mid-fight.
Equal(rogue:clicks(),"item item:3776 16 | item item:3776 17","armed before the fight")
rogue:combat(true)
Equal(poisonButton.shown,false,"the fight hides the click at once, by the game's own code, with the state as the number it sends")
Equal(poisonButton.attrs.type1==nil and poisonButton.attrs.type2==nil,true,"and clears both clicks")
rogue.M:Refresh()
Equal(rogue:row("poison"),nil,"without Show during combat POISON! hides in the fight")
Equal(poisonButton.shown,false,"and its click stays hidden")
rogue:combat(false);rogue:event("PLAYER_REGEN_ENABLED");rogue:tick(.6)
Equal(rogue:clicks(),"item item:3776 16 | item item:3776 17","after the fight: armed again")
rogue.env.EraUIDB.reminderCombat=true
rogue:combat(true)
Equal(poisonButton.shown,false,"the fight hides the click at once, by the game's own code")
Equal(poisonButton.attrs.type1==nil and poisonButton.attrs.type2==nil,true,"and clears both clicks")
rogue.M:Refresh()
Equal(rogue:row("poison")~=nil,true,"POISON! still shows in the fight with Show during combat")
Equal(poisonButton.shown,false,"without its click")
rogue.coatings={[17]=Fine()};rogue.M:Refresh()
Equal(rogue:row("poison").sub.text,"Main hand: no poison","it still updates in the fight")
local picked=rogue.env.EraUIClassicCharDB.classTools.poisonPickMain
poisonOptions.mainPoison:Fire("OnClick")
Equal(rogue.env.EraUIClassicCharDB.classTools.poisonPickMain,picked,"a pick can't change in the fight")
poisonOptions.poisonClick:Fire("OnClick")
Equal(rogue.env.EraUIDB.reminderPoisonClick,true,"nor can Click to apply poisons")
rogue:combat(false)
Equal(poisonButton.shown,false,"the fight's end alone doesn't bring it back")
rogue:event("PLAYER_REGEN_ENABLED");rogue:tick(.6)
Equal(rogue:clicks(),"item item:3776 16 | nil nil nil","the next refresh after the fight arms what's needed now")
rogue.env.EraUIDB.reminderCombat=nil
-- A first click wanted in a fight waits for its end to be made. (This
-- harness also errors on any secure frame made in combat.)
local late=Rogue()
late.bags={[8928]=1};late.env.EraUIDB.reminderClickable=true;late.env.EraUIDB.reminderPoisonClick=true
late.env.EraUIDB.reminderCombat=true;late.coatings={[16]=Fine(),[17]=Fine()}
late.M:Initialize()
Equal(late:row("poison"),nil,"poisoned at login: no POISON!")
late:combat(true);late.coatings[16]=nil;late.M:Refresh()
Equal(late:row("poison")~=nil,true,"POISON! can first show in a fight")
Equal(late:poisonButton(),nil,"its secure button isn't made in the fight")
late:combat(false);late.M:Refresh()
Equal(late:clicks(),"item item:8928 16 | nil nil nil","it's made once the fight ends")
-- Only once you can use poisons; the off hand only with a weapon there.
local young=Rogue(19);young.bags={[6947]=1}
young.env.EraUIDB.reminderClickable=true;young.env.EraUIDB.reminderPoisonClick=true
young.M:Initialize()
Equal(young:row("poison"),nil,"level 19: no POISON!")
young.level=1;young.weapons[17]=nil;young.M:Refresh()
Equal(young:row("poison"),nil,"a level 1 rogue with no off-hand weapon: nothing about poisons")
local youngOptions=young:options()
Equal(youngOptions.mainPoison.label.text.." / "..youngOptions.offPoison.label.text,"Main hand: Instant Poison  > / Off hand: Instant Poison  >",
 "level 1: both picks show Instant Poison, the first poison you'll get")
youngOptions.offPoison:Fire("OnClick");youngOptions.mainPoison:Fire("OnClick")
Equal(young.env.EraUIClassicCharDB.classTools.poisonPickOff or young.env.EraUIClassicCharDB.classTools.poisonPickMain,nil,"none to pick yet: nothing is saved")
young.level=19;youngOptions.mainPoison.draw();youngOptions.offPoison.draw()
Equal(youngOptions.mainPoison.label.text.." / "..youngOptions.offPoison.label.text,"Main hand: Instant Poison  > / Off hand: Instant Poison  >","level 19 too")
young.level=20;young.M:Refresh()
Equal(young:row("poison").sub.text,"Main hand: no poison","level 20: POISON!, for the main hand only")
Equal(young:clicks(),"item item:6947 16 | nil nil nil","a left-click puts Instant Poison on")
young.known[2842]=nil;young.bags={};young.M:Refresh()
Equal(young:row("poison"),nil,"without Poisons learned or any poison in bags: no POISON!")
young.bags={[6947]=1};young.weapons[17]=100;young.level=25;young.M:Refresh()
Equal(young:clicks(),"item item:6947 16 | item item:6947 17","before 30 the off hand uses Instant Poison too")
youngOptions.offPoison.draw()
Equal(youngOptions.offPoison.label.text,"Off hand: Instant Poison  >","and its button says so")

-- On a flight path every alert goes, clicks included, until a moment after
-- landing, so a pet the game puts away and brings back never flashes.
local flier=Session("HUNTER")
local now,taxi=100,false
flier.env.GetTime=function()return now end
flier.env.UnitOnTaxi=function(unit)return unit=="player"and taxi end
flier.known[883]=true;flier.env.EraUIDB.reminderClickable=true;flier.M:Initialize()
local listener=flier:listener()
for _,name in ipairs({"PLAYER_CONTROL_LOST","PLAYER_CONTROL_GAINED","UNIT_FLAGS","UNIT_PET"})do
 Equal(listener.events[name],true,name.." refreshes the alerts")
end
local call=flier:row("pet")
Equal(flier:click(call),"/cast [nocombat] Call Pet","before the flight SUMMON PET! is clickable")
flier:tick(3) -- settle the refresh clock
taxi=true;flier:event("PLAYER_CONTROL_LOST");flier:tick(.6)
Equal(flier:row("pet"),nil,"taking off hides SUMMON PET!")
Equal(flier:click(call),nil,"and disarms its click")
Equal(flier.env.EraUIClassReminderAlerts:IsShown(),false,"the whole panel goes")
local flierOptions=flier:options();flierOptions.prev:Fire("OnClick")
Equal(flier:row("pet"),nil,"even Show all reminders waits for landing")
flierOptions.prev:Fire("OnClick")
now=160;taxi=false;flier:event("PLAYER_CONTROL_GAINED");flier:tick(.6)
Equal(flier:row("pet"),nil,"just landed: still hidden while the game brings the pet back")
now=161.5;flier.M:Refresh()
Equal(flier:row("pet"),nil,"1.5 seconds after landing: still hidden")
now=162.1;flier:tick(.3)
Equal(flier:row("pet"),nil,"a refresh waits its half second")
flier:tick(.3)
Equal(flier:click(flier:row("pet")),"/cast [nocombat] Call Pet","2 seconds after landing a missing pet is shown and clickable again, before the 2-second refresh")
-- The pet was out: the game puts it away for the flight and brings it back.
flier.pet.exists=true;flier.M:Refresh()
Equal(flier:row("pet"),nil,"pet out before the flight")
taxi=true;flier.pet.exists=false;flier:event("UNIT_PET","player");flier:tick(.6)
Equal(flier:row("pet"),nil,"the game puts the pet away in flight: no SUMMON PET!")
now=200;taxi=false;flier:event("UNIT_FLAGS","player");flier:tick(.6)
Equal(flier:row("pet"),nil,"landed, pet not back yet: no flash")
now=201;flier.pet.exists=true;flier:event("UNIT_PET","player");flier:tick(.6)
now=202.5;flier:tick(.6)
Equal(flier:row("pet"),nil,"the pet it brings back never flashes SUMMON PET!")
-- Hidden, failing or missing taxi answers behave as today.
flier.pet.exists=false
flier.env.UnitOnTaxi=function()return secret end;flier.M:Refresh()
Equal(flier:row("pet")~=nil,true,"a hidden taxi answer is not a flight")
flier.env.UnitOnTaxi=function()error("unavailable")end;flier.M:Refresh()
Equal(flier:row("pet")~=nil,true,"a failing taxi check is not a flight")
flier.env.UnitOnTaxi=nil;flier.M:Refresh()
Equal(flier:click(flier:row("pet")),"/cast [nocombat] Call Pet","a client without the taxi check keeps its alerts")
-- In combat nothing secure is touched: the combat driver already disarmed it.
flier.env.UnitOnTaxi=function(unit)return unit=="player"and taxi end
flier.env.EraUIDB.reminderCombat=true;flier:combat(true);flier.M:Refresh()
Equal(flier:row("pet")~=nil,true,"combat alert shows")
taxi=true;flier.M:Refresh()
Equal(flier:row("pet"),nil,"a flight in combat hides alerts without protected edits")
now=300;taxi=false;flier.M:Refresh();flier:combat(false);now=302.1;flier.M:Refresh()
Equal(flier:click(flier:row("pet")),"/cast [nocombat] Call Pet","after combat and landing the click is rebuilt")
taxi=true;flier.M:Refresh();flier.env.WorldMapFrame:Show()
now=400;taxi=false;flier.M:Refresh()
now=403;flier.env.WorldMapFrame:Hide()
Equal(flier:click(flier:row("pet")),"/cast [nocombat] Call Pet","landing with the map open still counts: closing it later shows alerts at once")
-- Every reminder panel reads one flight clock. When another panel notices the
-- landing first, these alerts still come back the moment the pause ends.
taxi=true;flier.M:Refresh()
Equal(flier:row("pet"),nil,"flying again")
now=500;taxi=false
Equal(flier.E.ClassTools.Flying(),true,"another panel notices the landing first")
flier:tick(3);Equal(flier:row("pet"),nil,"the alerts wait out the same pause")
now=502.1;Equal(flier.E.ClassTools.Flying(),false,"the other panel sees the pause end first too")
flier:tick(.6)
Equal(flier:click(flier:row("pet")),"/cast [nocombat] Call Pet","yet the alerts still return on time, not at the 2-second refresh")
local asked=0
flier.env.UnitOnTaxi=function()asked=asked+1;return false end
flier:tick(.6);flier:tick(.6);flier:tick(.6)
Equal(asked,0,"then the refresh clock is back to its usual pace")
flier:tick(.6);Equal(asked,1,"and refreshes after 2 seconds as before")

-- POISON! waits for landing like every alert, and its click goes with it.
local poisoner=Rogue()
local pnow,ptaxi=100,false
poisoner.env.GetTime=function()return pnow end
poisoner.env.UnitOnTaxi=function(unit)return unit=="player"and ptaxi end
poisoner.bags={[8928]=1};poisoner.env.EraUIDB.reminderClickable=true;poisoner.env.EraUIDB.reminderPoisonClick=true
poisoner.M:Initialize()
Equal(poisoner:clicks(),"item item:8928 16 | nil nil nil","on the ground POISON! is clickable")
poisoner:tick(3)
ptaxi=true;poisoner:event("PLAYER_CONTROL_LOST");poisoner:tick(.6)
Equal(poisoner:row("poison"),nil,"taking off hides POISON!")
Equal(poisoner:clicks(),nil,"and puts its click away")
pnow=160;ptaxi=false;poisoner:event("PLAYER_CONTROL_GAINED");poisoner:tick(.6)
Equal(poisoner:row("poison"),nil,"just landed: still hidden")
pnow=162.1;poisoner:tick(.6)
Equal(poisoner:clicks(),"item item:8928 16 | nil nil nil","2 seconds after landing it is back, clickable")

-- Reminders for spells Forever lacks are gone; old saved settings for them
-- (switches, spots, a Felguard or Sanctuary choice) are ignored safely.
local mage=Session("MAGE")
mage.known[1459]=true;mage.known[31687]=true
for key,value in pairs({reminder_MAGE_elemental=true,reminderPX_MAGE_elemental=40,reminderPY_MAGE_elemental=-20,
 reminder_SHAMAN_elemental=true,reminderClickable=true})do mage.env.EraUIDB[key]=value end
mage.M:Initialize()
local mageOptions=mage:options();mageOptions.adv:Fire("OnClick")
local elemental=false
for _,f in ipairs(mage.frames)do if f.text=="SUMMON ELEMENTAL!"or f.text=="elemental"then elemental=true end end
Equal(elemental,false,"no Summon Elemental alert or Advanced switch, even when saved on")
Equal(mage:row("intellect")~=nil,true,"the mage's other reminders carry on")
local demon=Session("WARLOCK")
demon.known[688]=true;demon.known[697]=true
demon.env.EraUIDB.reminderChoice_WARLOCK_pet=427733;demon.env.EraUIDB.reminderLast_WARLOCK_pet=30146
demon.env.EraUIDB.reminderClickable=true;demon.M:Initialize()
local demonOptions=demon:options();demonOptions.adv:Fire("OnClick")
local cycle
for _,f in ipairs(demonOptions.advRows)do if f.label.text and f.label.text:find("^Demon:")then cycle=f end end
Equal(cycle.label.text,"Demon: Any  >","a saved Felguard choice reads as Any")
Equal(demon:click(demon:row("pet")),nil,"and Any with two demons and no valid last cast still never guesses")
cycle:Fire("OnClick")
Equal(demon.env.EraUIDB.reminderChoice_WARLOCK_pet,0,"cycling from it lands on a real choice")
cycle:Fire("OnClick")
Equal(cycle.label.text,"Demon: Summon Imp  >","then the next demon")
local blesser=Session("PALADIN")
blesser.known[19740]=true;blesser.env.EraUIDB.reminderChoice_PALADIN_blessing=20911
blesser.env.EraUIDB.reminderClickable=true;blesser.M:Initialize()
Equal(blesser:click(blesser:row("blessing")),"/cast [nocombat,@player] Blessing of Might","a saved Sanctuary choice reads as Any: the only blessing known")

-- Summon Incubus is a Demon choice of its own in /era, and clickable.
local incubus=Session("WARLOCK")
incubus.known[688]=true;incubus.known[712]=true;incubus.known[713]=true
incubus.env.EraUIDB.reminderClickable=true;incubus.M:Initialize()
local incubusOptions=incubus:options();incubusOptions.adv:Fire("OnClick")
local picker
for _,f in ipairs(incubusOptions.advRows)do if f.label.text and f.label.text:find("^Demon:")then picker=f end end
local shown={}
for _=1,4 do picker:Fire("OnClick");shown[#shown+1]=picker.label.text end
Equal(table.concat(shown," | "),"Demon: Summon Imp  > | Demon: Summon Succubus  > | Demon: Summon Incubus  > | Demon: Any  >",
 "the Demon button cycles through Incubus and back to Any")
picker:Fire("OnClick");picker:Fire("OnClick");picker:Fire("OnClick")
Equal(incubus:click(incubus:row("pet")),"/cast [nocombat] Summon Incubus","a chosen Incubus is what a click summons")
Equal(incubus:row("pet").icon.texture,713,"with its icon")
picker:Fire("OnClick")
incubus:event("UNIT_SPELLCAST_SUCCEEDED","player","cast-1",713);incubus.M:Refresh()
Equal(incubus:click(incubus:row("pet")),"/cast [nocombat] Summon Incubus","on Any, the Incubus you summoned last")
-- A hunter with only Forever's Trueshot Aura rank 1 is reminded, and not once it's up.
local marksman=Session("HUNTER")
marksman.known[1299346]=true;marksman.env.EraUIDB.reminderClickable=true;marksman.M:Initialize()
Equal(marksman:click(marksman:row("trueshot")),"/cast [nocombat,@player] Trueshot Aura","rank 1 missing: TRUESHOT AURA! casts it")
marksman.env.C_UnitAuras={GetAuraDataByIndex=function(unit,i)if unit=="player"and i==1 then return {spellId=1299346}end end}
marksman.M:Refresh()
Equal(marksman:row("trueshot"),nil,"rank 1 up: no alert")

-- PET LOW HEALTH!: off by default; Mend Pet below the limit.
local mender=Session("HUNTER")
local mtip={}
mender.env.GameTooltip={SetOwner=function(_,owner)mtip={owner=owner}end,SetText=function(_,text)mtip.title=text end,
 AddLine=function(_,text)mtip[#mtip+1]=text end,Show=function()mtip.shown=true end,Hide=function()mtip.shown=false end}
for _,id in ipairs({883,982,136,3661,13165})do mender.known[id]=true end
mender.pet.exists=true;mender.pet.health=30
mender.env.EraUIDB.reminderClickable=true;mender.M:Initialize()
Equal(mender:row("petHealth"),nil,"PET LOW HEALTH! is off by default")
Equal(mender:row("aspect")~=nil,true,"the hunter's other alerts carry on")
local menderOptions=mender:options();menderOptions.adv:Fire("OnClick")
local lowSwitch,trueSwitch,aspectSwitch,aspectButton
for _,f in ipairs(menderOptions.advRows)do
 local text=f.label.text
 if text=="PET LOW HEALTH!"then lowSwitch=f elseif text=="TRUESHOT AURA!"then trueSwitch=f
 elseif text=="ASPECT!"then aspectSwitch=f elseif text and text:find("^Aspect:")then aspectButton=f end
end
Equal(lowSwitch~=nil,true,"/era Advanced has its switch, with a plain label")
Equal(lowSwitch:IsShown()and lowSwitch.width,340,"on a whole line")
Equal(lowSwitch.point[2],12,"starting at the left")
Equal(lowSwitch.point[3],trueSwitch.point[3]-26,"on the line under TRUESHOT AURA!")
Equal(aspectButton.point[3]==aspectSwitch.point[3]and aspectButton.point[2]-aspectSwitch.point[2],170,"the Aspect button still sits beside ASPECT!")
Equal(lowSwitch.limit.parent,lowSwitch,"its Below button is on the same line")
Equal(lowSwitch.limit.point[2],lowSwitch.track,"just left of the switch")
Equal(lowSwitch.limit.label.text,"Below 35%  >","the limit starts at 35%")
local listed=false
for _,f in ipairs(menderOptions.items)do if f==lowSwitch.limit then listed=true end end
Equal(listed,true,"the Below button greys out with the other options")
lowSwitch:Fire("OnEnter")
Equal(mtip.title,"PET LOW HEALTH!","hovering the switch names it")
Equal(mtip[1]:find("^Shows PET LOW HEALTH! while your pet is alive")~=nil and mtip[1]:find("Needs testing",1,true)==nil,true,"its help starts with what it does, no Needs testing")
Equal(mtip[1]:find("highest rank of Mend Pet",1,true)~=nil,true,"it names Mend Pet")
Equal(mtip[1]:find("In combat the game hides your pet's health from addons",1,true)~=nil,true,"it explains combat")
Equal(mtip[1]:find("Show during combat",1,true)~=nil,true,"and Show during combat")
Equal(mtip[1]:find("\226\128\148",1,true),nil,"with no em dash")
Equal(mtip[2],"Default: Off, below 35%","and its defaults")
Equal(mtip.owner==lowSwitch and mtip.shown,true,"shown beside the switch")
lowSwitch:Fire("OnLeave");Equal(mtip.shown,false,"leaving hides it")
lowSwitch.limit:Fire("OnEnter")
Equal(mtip.owner==lowSwitch.limit and mtip.title,"PET LOW HEALTH!","the Below button explains the same")
lowSwitch:Fire("OnClick")
Equal(mender.env.EraUIDB.reminder_HUNTER_petHealth,true,"the switch turns it on")
local low=mender:row("petHealth")
Equal(low~=nil and low.text.text,"PET LOW HEALTH!","pet at 30%: PET LOW HEALTH!")
Equal(low.sub.text,"Pet at 30% health","saying how low")
Equal(mender:click(low),"/cast [nocombat] Mend Pet","a click casts Mend Pet")
Equal(low.icon.texture,3661,"with the highest known rank's icon")
Equal(tostring(low.alpha).." "..tostring(low.hiddenAlpha).." "..tostring(low.mouse),"1 false true","fully shown, taking the mouse")
Equal(mender:row("aspect").point[3],0,"ASPECT! keeps the top of the stack")
mender.pet.health=35;mender.M:Refresh()
Equal(mender:row("petHealth"),nil,"at the limit: no alert")
Equal(mender:click(low),nil,"and no click")
local seen={}
for _=1,9 do lowSwitch.limit:Fire("OnClick");seen[#seen+1]=lowSwitch.limit.label.text:match("%d+")end
Equal(table.concat(seen,","),"40,45,50,55,60,20,25,30,35","Below cycles 20 to 60% in fives")
lowSwitch.limit:Fire("OnClick")
Equal(mender.env.EraUIDB.reminderLimit_HUNTER_petHealth,40,"a picked limit is saved")
Equal(mender:row("petHealth")~=nil,true,"and applies at once: 35% is below 40%")
mender.noMana[3661]=true;mender.M:Refresh()
Equal(mender:row("petHealth").sub.text:find("Not enough mana",1,true)~=nil,true,"out of mana: said, as for other alerts")
Equal(mender:click(mender:row("petHealth")),nil,"and not clickable")
mender.noMana[3661]=nil
mender.pet.dead=true;mender.M:Refresh()
Equal(mender:row("petHealth"),nil,"a dead pet: no PET LOW HEALTH!")
Equal(mender:row("petDead")~=nil,true,"PET DEAD! instead")
mender.pet.dead=false;mender.pet.exists=false;mender.M:Refresh()
Equal(mender:row("petHealth"),nil,"no pet: no PET LOW HEALTH!")
Equal(mender:click(mender:row("pet")),"/cast [nocombat] Call Pet","SUMMON PET! instead")
mender.pet.exists=true;mender.pet.health=20
-- Combat: hidden health. Only with Show during combat, drawn for the game to fade.
mender:combat(true);mender.M:Refresh()
Equal(mender:row("petHealth"),nil,"in combat it hides unless Show during combat is on")
mender.env.EraUIDB.reminderCombat=true;mender.M:Refresh()
low=mender:row("petHealth")
Equal(low~=nil,true,"with Show during combat on it is drawn in combat")
Equal(low.hiddenAlpha,true,"its alpha is the game's hidden result, never read")
Equal(low.alpha,1,"which shows it at 20%")
Equal(low.mouse,false,"it takes no mouse")
Equal(mender:click(low),nil,"and can't be clicked in combat")
Equal(low.sub.text,"Pet below 40% health","it names the limit")
Equal(mender:row("aspect").point[3],0,"ASPECT! keeps the top of the stack")
Equal(low.point[3],-134,"PET LOW HEALTH! comes after it")
mender.noMana[3661]=true;mender.M:Refresh()
Equal(low.sub.text,"Pet below 40% health","no mana note on a faded alert")
mender.noMana[3661]=nil
mender.pet.health=60;mender.M:Refresh()
Equal(low:IsShown()and low.alpha,0,"at 60% the game hides it")
Equal(low.mouse,false,"unseen, it never blocks a click")
mender.pet.health=39;mender.M:Refresh()
Equal(low.alpha,1,"at 39% the game shows it again")
mender.env.UnitHealthPercent=nil;mender.M:Refresh()
Equal(mender:row("petHealth"),nil,"a client without the percent API: hidden in combat")
mender.env.UnitHealthPercent=function(_,_,c)return Hidden(c:Evaluate(mender.pet.health/100))end
mender.env.UnitOnTaxi=function()return true end;mender.M:Refresh()
Equal(mender:row("petHealth"),nil,"on a flight path it hides like every alert")
mender.env.UnitOnTaxi=nil;mender.M:Refresh()
Equal(mender:row("petHealth"),nil,"just landed: still hidden")
mender.env.GetTime=function()return 13 end;mender.M:Refresh()
Equal(mender:row("petHealth")==low and low.hiddenAlpha,true,"and back, faded by the game, after the landing pause")
-- The pet dies mid-fight: PET DEAD! takes the top row, ASPECT! the faded one.
mender.pet.dead=true;mender.M:Refresh()
Equal(mender:row("aspect"),low,"a faded row is reused for another alert")
Equal(tostring(low.alpha).." "..tostring(low.hiddenAlpha).." "..tostring(low.mouse),"1 false true","which is fully shown and takes the mouse again")
mender.pet.dead=false;mender.pet.health=20;mender:combat(false);mender.M:Refresh()
low=mender:row("petHealth")
Equal(tostring(low.alpha).." "..tostring(low.hiddenAlpha).." "..tostring(low.mouse),"1 false true","after combat it is plain again")
Equal(mender:click(low),"/cast [nocombat] Mend Pet","and clickable")
mender.pet.hideHealth=true;mender.M:Refresh()
Equal(low.hiddenAlpha,true,"health hidden out of combat too: the game fades it")
Equal(mender:click(low),nil,"with no click over an alert that may be unseen")
Equal(low.mouse,false,"or mouse")
mender.pet.hideHealth=nil;mender.M:Refresh()
lowSwitch:Fire("OnClick")
Equal(mender:row("petHealth"),nil,"switched off, it goes")
-- Warlocks channel Health Funnel; a dead demon is SUMMON PET!'s.
local funnel=Session("WARLOCK")
funnel.known[688]=true;funnel.known[755]=true;funnel.known[11695]=true
funnel.env.EraUIDB.reminderClickable=true;funnel.env.EraUIDB.reminder_WARLOCK_petHealth=true
funnel.pet.exists=true;funnel.pet.health=25;funnel.M:Initialize()
Equal(funnel:click(funnel:row("petHealth")),"/cast [nocombat] Health Funnel","a warlock's click casts Health Funnel")
Equal(funnel:row("petHealth").icon.texture,11695,"at its highest known rank")
funnel.pet.dead=true;funnel.M:Refresh()
Equal(funnel:row("petHealth"),nil,"a dead demon: no PET LOW HEALTH!")
Equal(funnel:row("pet")and funnel:row("pet").sub.text,"Pet is dead","SUMMON PET! says it is dead instead")
local funnelOptions=funnel:options();funnelOptions.adv:Fire("OnClick")
local demonLow
for _,f in ipairs(funnelOptions.advRows)do if f.label.text=="PET LOW HEALTH!"then demonLow=f end end
Equal(demonLow and demonLow.point[2],12,"the warlock's switch has its own line too")
-- A wide switch fills its line: a switch listed after it starts the next one.
local wide=Session("HUNTER")
table.insert(wide.E.ReminderSpells.HUNTER,{key="later",text="LATER!",kind="shards"})
wide.M:Initialize()
local wideOptions=wide:options();wideOptions.adv:Fire("OnClick")
local wideLow,later
for _,f in ipairs(wideOptions.advRows)do
 if f.label.text=="PET LOW HEALTH!"then wideLow=f elseif f.label.text=="LATER!"then later=f end
end
Equal(later.point[2].." "..later.point[3],"12 "..(wideLow.point[3]-26),"a switch after the wide one starts the next line")
Equal(wideOptions.height,-(later.point[3]-26)+24,"and the panel grows to fit it")

-- Click pet reminders in combat (Needs testing): off by default; SUMMON PET!,
-- PET DEAD! and PET LOW HEALTH! get secure alerts the game shows by macro
-- conditions. The mock refuses any secure layout, show, hide or attribute
-- change in combat, so every combat step below also proves none happens.
local function At(a)return ("%g %g"):format(a.point[4],a.point[5])end
local function Tooltip(s)
 local t={}
 s.env.GameTooltip={SetOwner=function(_,owner)for k in pairs(t)do t[k]=nil end;t.owner=owner end,SetText=function(_,text)t.title=text end,
  AddLine=function(_,text)t[#t+1]=text end,Show=function()t.shown=true end,Hide=function()t.shown=false end}
 return t
end
local function Visibility(s)
 local list={}
 for _,r in ipairs(s.registered)do if r.state=="visibility"then list[#list+1]=r end end
 return list
end
local fighter=Session("HUNTER")
local ftip=Tooltip(fighter)
for _,id in ipairs({883,982,136,3661})do fighter.known[id]=true end
fighter.env.EraUIDB.reminderClickable=true;fighter.env.EraUIDB.reminder_HUNTER_petHealth=true
fighter.M:Initialize()
Equal(fighter.env.EraUIDB.reminderCombatClick,nil,"Click pet reminders in combat is off by default")
Equal(fighter:alert("pet")or fighter:alert("petDead")or fighter:alert("petHealth"),nil,"off: no secure pet alert is built")
fighter:combat(true);fighter:event("PLAYER_REGEN_DISABLED");fighter.M:Refresh()
Equal(fighter:row("pet"),nil,"off: in combat the pet rows hide as before")
fighter:combat(false);fighter:event("PLAYER_REGEN_ENABLED")
Equal(fighter:click(fighter:row("pet")),nil,"off: no early refresh at the end of a fight, as before")
fighter.M:Refresh()
Equal(fighter:click(fighter:row("pet")),"/cast [nocombat] Call Pet","off: the next refresh restores the click, as before")
Equal(#Visibility(fighter),0,"off: no visibility driver is ever registered")
local fo=fighter:options()
local cc=fo.combatClick
Equal(cc:IsShown(),true,"hunters get the option")
Equal(cc.label.text,"Click pet reminders in combat","labelled plainly, confirmed in game")
Equal(cc.point[3],fo.clickable.point[3]-26,"right under Clickable reminders")
Equal(fo.mana.point[3],cc.point[3]-26,"with the mana note under it")
local listedCc=false
for _,f in ipairs(fo.items)do if f==cc then listedCc=true end end
Equal(listedCc,true,"it greys out with the other options")
Equal(cc.dependencyDisabled==false and cc.alpha==1 and cc.dependencyHelp:IsShown(),false,"with Clickable reminders on it is available")
fo.clickable:Fire("OnClick")
Equal(fighter.env.EraUIDB.reminderClickable,false,"Clickable reminders off")
Equal(cc.dependencyDisabled,true,"greys it out")
Equal(cc.alpha,.4,"drawn faded")
Equal(cc.enabled,false,"and disabled")
cc:Fire("OnClick")
Equal(fighter.env.EraUIDB.reminderCombatClick,nil,"so it can't be turned on")
Equal(cc.dependencyHelp:IsShown(),true,"its hover help still works")
cc.dependencyHelp:Fire("OnEnter")
Equal(ftip.owner==cc and ftip[1],"Turn on Clickable reminders to use this.","saying what to turn on first")
cc.dependencyHelp:Fire("OnLeave");Equal(ftip.shown,false,"leaving hides it")
fo.clickable:Fire("OnClick")
Equal(cc.dependencyDisabled==false and cc.enabled==true and cc.alpha==1 and not cc.dependencyHelp:IsShown(),true,"Clickable reminders on: available again")
cc:Fire("OnEnter")
Equal(ftip.title,"Click pet reminders in combat","hovering names it")
Equal(ftip[1]:find("^SUMMON PET!, PET DEAD! and PET LOW HEALTH! stay clickable in combat: Call Pet, Revive Pet and Mend Pet%.")~=nil,true,"it says which alerts and spells")
for _,words in ipairs({"even with Show during combat off","The game hides your pet's health, so",
 "a faint Mend Pet icon stays up all fight while your pet is alive",
 "A click casts even when it's faint.","They stay up with the world map open","a click with too little mana still tries to cast",
 "Other reminders are clickable outside combat only."})do
 Equal(ftip[1]:find(words,1,true)~=nil,true,"it says: "..words)
end
Equal(ftip[1]:find("It hides",1,true)==nil and ftip[1]:find("different demon",1,true)==nil,true,"a hunter's help names the game, and says nothing about demons")
Equal(ftip[1]:find("\226\128\148",1,true),nil,"with no em dash")
Equal(ftip[2],"Default: Off.","and its default")
cc:Fire("OnLeave")
cc:Fire("OnClick")
Equal(fighter.env.EraUIDB.reminderCombatClick,true,"the user can turn it on")
local call,revive,mend=fighter:alert("pet"),fighter:alert("petDead"),fighter:alert("petHealth")
Equal(call~=nil and revive~=nil and mend~=nil,true,"SUMMON PET!, PET DEAD! and PET LOW HEALTH! each get a secure alert")
Equal(call.protected and call.parent==fighter.env.UIParent and call.point[2]==fighter.env.UIParent,true,"parented and anchored to UIParent only")
Equal(fighter.env.EraUIClassReminderAlerts.protected,false,"so the alert panel stays unprotected")
Equal(next(call.scripts)==nil and next(call.hooks)==nil,true,"no script or hook on the secure alert")
Equal(not not(call.face.protected or call.face.mouse),false,"its look sits on a plain face that takes no mouse")
Equal(table.concat(call.clicks,","),"LeftButtonUp,LeftButtonDown","left click, down or up")
local rules={}
for _,r in ipairs(Visibility(fighter))do rules[r.frame.combatKey]=r.rule end
Equal(rules.pet,"[nocombat][@pet,exists] hide; show","SUMMON PET! shows in combat only while no pet exists")
Equal(rules.petDead,"[nocombat] hide; [@pet,dead] show; hide","PET DEAD! in combat only while the pet is dead")
Equal(rules.petHealth,"[nocombat][@pet,noexists][@pet,dead] hide; show","PET LOW HEALTH! in combat only while the pet is alive")
Equal(call.attrs.type1.." | "..call.attrs.macrotext1,"macro | /cast [combat] Call Pet","SUMMON PET! casts Call Pet")
Equal(revive.attrs.macrotext1,"/cast [combat] Revive Pet","PET DEAD! casts Revive Pet")
Equal(mend.attrs.macrotext1,"/cast [combat,@pet,exists,nodead] Mend Pet","PET LOW HEALTH! casts Mend Pet on a living pet")
Equal(call:IsShown()or revive:IsShown()or mend:IsShown(),false,"out of combat every pet alert hides")
Equal(fighter:click(fighter:row("pet")),"/cast [nocombat] Call Pet","and SUMMON PET!'s row keeps its normal click")
Equal(At(call),"1000 500","the SUMMON PET! alert sits on its row's icon")
Equal(("%g %g"):format(call.width,call.height),"52 52","only the icon square is the button")
Equal(At(revive),"1000 565","PET DEAD! waits where its row would stack: the top slot")
Equal(At(mend),"1000 565","PET LOW HEALTH! too, with nothing else up")
Equal(call.text.text.." | "..call.sub.text,"SUMMON PET! | No pet summoned","it reads like the row")
Equal(call.icon.texture,883,"with Call Pet's icon")
Equal(mend.face.alpha,.35,"PET LOW HEALTH! starts faint, never unseen")
Equal(mend.text.alpha+mend.sub.alpha,0,"and without its words")
-- Into combat: the game shows SUMMON PET!, nothing else changes a secure frame.
local armedCount=#Visibility(fighter)
fighter:combat(true);fighter:event("PLAYER_REGEN_DISABLED")
Equal(call:IsShown(),true,"no pet in combat: the game shows SUMMON PET!")
Equal(revive:IsShown()or mend:IsShown(),false,"and only it")
Equal(fighter:row("pet"),nil,"its row goes at once, even with Show during combat off")
Equal(call.attrs.macrotext1,"/cast [combat] Call Pet","a click casts Call Pet")
Equal(At(call),"1000 500","in the spot it had when the fight began")
local function ShownArmed(s)
 for _,key in ipairs({"pet","petDead","petHealth"})do
  local a=s:alert(key)
  if a and a:IsShown()and not(a.attrs.type1=="macro"and a.attrs.macrotext1)then return false end
 end
 return true
end
Equal(ShownArmed(fighter),true,"a shown alert always has its click")
fighter.pet.exists=true;fighter.pet.health=100;fighter:drivers();fighter.M:Refresh()
Equal(call:IsShown(),false,"pet summoned mid-fight: SUMMON PET! goes")
Equal(mend:IsShown(),true,"and the PET LOW HEALTH! icon is up")
Equal(mend.face.hiddenAlpha,true,"faded by the game's hidden answer, never read")
Equal(mend.face.alpha,.35,"faint while the pet is healthy")
Equal(mend.text.alpha+mend.sub.alpha,0,"with no words")
Equal(mend.alpha,nil,"the secure button itself is never faded")
fighter.pet.health=20;fighter.M:Refresh()
Equal(mend.face.alpha,1,"below 35% the icon lights up")
Equal(mend.text.alpha==1 and mend.sub.alpha==1 and mend.text.hiddenAlpha,true,"and its words, by the game's answer too")
Equal(mend.sub.text,"Pet below 35% health","saying so")
Equal(ShownArmed(fighter),true,"its click is Mend Pet's")
local lowest,highest=1,0
for health=0,100,5 do
 fighter.pet.health=health;fighter.M:Refresh()
 lowest=math.min(lowest,mend.face.alpha);highest=math.max(highest,mend.text.alpha)
 Equal(mend:IsShown(),true,"PET LOW HEALTH! stays up at "..health.."%")
end
Equal(lowest,.35,"the icon is never less than faint, at any health")
Equal(highest,1,"the words light up only below the limit")
-- Your own Below limit, not the default: 50% here.
fighter.env.EraUIDB.reminderLimit_HUNTER_petHealth=50
fighter.pet.health=45;fighter.M:Refresh()
Equal(mend.face.alpha==1 and mend.text.alpha==1 and mend.sub.alpha==1,true,"Below 50%: at 45% the icon and its words light up")
Equal(mend.sub.text,"Pet below 50% health","saying your limit")
fighter.pet.health=55;fighter.M:Refresh()
Equal(mend.face.alpha==.35 and mend.text.alpha==0 and mend.sub.alpha==0,true,"Below 50%: at 55% it stays faint, with no words")
for health=0,100,5 do
 fighter.pet.health=health;fighter.M:Refresh()
 Equal(mend.face.alpha==1 and mend.text.alpha==1,health<50,"Below 50%: lit at "..health.."% only under the limit")
end
fighter.env.EraUIDB.reminderLimit_HUNTER_petHealth=nil
fighter.pet.health=100;fighter.M:Refresh()
fighter.noMana[3661]=true;fighter.M:Refresh()
Equal(mend.sub.text,"Pet below 35% health\n|cff8fa8ffNot enough mana|r","out of mana: said under the icon")
Equal(mend.icon.tint[1]==.5 and mend.icon.tint[3],1,"in the mana tint")
Equal(mend.attrs.macrotext1,"/cast [combat,@pet,exists,nodead] Mend Pet","the click can't be taken away mid-fight: the game says why it fails")
fighter.noMana[3661]=secret;fighter.M:Refresh()
Equal(mend.sub.text,"Pet below 35% health","a hidden mana answer is never read as out of mana")
Equal(mend.icon.tint[1],1,"nor tinted")
fighter.noMana[3661]=nil
local keepPercent=fighter.env.UnitHealthPercent
fighter.env.UnitHealthPercent=nil;fighter.M:Refresh()
Equal(mend.face.alpha==.35 and mend.face.hiddenAlpha,false,"no percent API: a fixed faint icon")
Equal(mend.text.alpha,0,"with no words")
fighter.env.UnitHealthPercent=function()error("unavailable")end;fighter.M:Refresh()
Equal(mend.face.alpha==.35 and mend.text.alpha==0,true,"a failing percent API: the same")
fighter.env.UnitHealthPercent=keepPercent
fighter.pet.dead=true;fighter:drivers();fighter.M:Refresh()
Equal(mend:IsShown(),false,"the pet dies: PET LOW HEALTH! goes")
Equal(revive:IsShown(),true,"the game shows PET DEAD!")
Equal(call:IsShown(),false,"not SUMMON PET!")
Equal(revive.attrs.macrotext1.." | "..revive.sub.text,"/cast [combat] Revive Pet | Revive your pet","a click casts Revive Pet")
fighter.env.EraUIDB.reminderCombat=true;fighter.M:Refresh()
Equal(fighter:row("petDead"),nil,"Show during combat on: still never a PET DEAD! row as well")
fighter.pet.dead=secret;fighter:drivers();fighter.M:Refresh()
Equal(call.sub.text,"No pet summoned","a hidden death state is never read")
fighter.pet.dead=true;fighter:drivers()
-- The options and the map can't change anything mid-fight.
cc:Fire("OnClick");Equal(fighter.env.EraUIDB.reminderCombatClick,true,"the option can't be changed in combat")
fighter.env.WorldMapFrame:Show()
Equal(revive:IsShown(),true,"the map opened in combat can't hide the alert, and nothing tries")
Equal(fighter.env.EraUIClassReminderAlerts:IsShown(),false,"the rows hide for the map as before")
fighter.env.WorldMapFrame:Hide()
Equal(#Visibility(fighter),armedCount,"no driver was registered in combat")
-- Out of combat: the rows and their clicks are back at once.
fighter:combat(false)
Equal(revive:IsShown(),false,"combat over: the game hides PET DEAD!")
fighter:event("PLAYER_REGEN_ENABLED")
Equal(fighter:click(fighter:row("petDead")),"/cast [nocombat] Revive Pet","and its row and normal click are back at once")
Equal(revive.rule,"[nocombat] hide; [@pet,dead] show; hide","still armed for the next fight")
Equal(At(revive),"1000 500","out of combat PET DEAD!'s alert moves onto its row's icon")
fighter.env.WorldMapFrame:Show()
Equal(revive.rule.." "..At(revive),"[nocombat] hide; [@pet,dead] show; hide 1000 500","the map open out of combat leaves the alerts as they are")
fighter.env.WorldMapFrame:Hide()
-- A dragged alert: its own spot, and it leaves the stack alone.
fighter.pet.dead=false;fighter.pet.health=100
fighter.env.EraUIDB.reminderPX_HUNTER_petDead=-100;fighter.env.EraUIDB.reminderPY_HUNTER_petDead=-50;fighter.M:Refresh()
Equal(At(revive),"765 515","a dragged PET DEAD! waits at its own spot")
Equal(revive.slot,nil,"outside the stack")
fo.reset:Fire("OnClick")
Equal(("%g %s"):format(revive.point[5],tostring(revive.slot)),"565 1","Reset alert positions puts it back in the stack")
-- The drag handle is the row, out of combat only; a drop moves the alert too.
fighter.pet.exists=false;fighter.M:Refresh()
local callRow=fighter:row("pet")
callRow.iconFrame.x,callRow.iconFrame.y=700,300
callRow:Fire("OnDragStart");callRow:Fire("OnDragStop")
Equal(At(call),"700 300","after a drag SUMMON PET!'s alert follows its row")
callRow.iconFrame.x,callRow.iconFrame.y=1000,500
fighter:combat(true)
callRow:Fire("OnDragStart");Equal(callRow.moving==true,false,"no dragging in combat")
fighter:combat(false);fo.reset:Fire("OnClick")
-- Whatever stops the normal click puts the alerts away too.
local function AllAway(s)
 for _,key in ipairs({"pet","petDead","petHealth"})do
  local a=s:alert(key)
  if a and(a.rule~="hide"or a.attrs.type1 or a.attrs.macrotext1 or a:IsShown())then return false end
 end
 return true
end
local function Rearmed(s)return s:alert("pet").rule=="[nocombat][@pet,exists] hide; show"and s:alert("pet").attrs.type1=="macro"end
fo.prev:Fire("OnClick")
Equal(AllAway(fighter),true,"Show all reminders puts them away: a preview never casts")
fighter:combat(true);Equal(AllAway(fighter),true,"so none shows in combat")
fighter:combat(false);fo.prev:Fire("OnClick")
Equal(Rearmed(fighter),true,"preview off: armed again")
fo.clickable:Fire("OnClick")
Equal(AllAway(fighter),true,"Clickable reminders off: put away")
fo.clickable:Fire("OnClick");Equal(Rearmed(fighter),true,"and back")
fighter.settings.classReminders=false;fighter.M:Refresh()
Equal(AllAway(fighter),true,"Class Reminders off: put away")
fighter.settings.classReminders=true;fighter.M:Refresh();Equal(Rearmed(fighter),true,"and back")
fighter.env.EraUIDB.reminder_HUNTER_petHealth=false;fighter.M:Refresh()
Equal(mend.rule.." "..tostring(mend.attrs.type1),"hide nil","PET LOW HEALTH! switched off: its alert is put away")
Equal(Rearmed(fighter)and revive.attrs.type1,"macro","the others stay armed")
fighter.env.EraUIDB.reminder_HUNTER_petHealth=true
cc:Fire("OnClick")
Equal(fighter.env.EraUIDB.reminderCombatClick,false,"the option off again")
Equal(AllAway(fighter),true,"every pet alert is put away")
fighter.pet.exists=true;fighter.pet.dead=true;fighter:combat(true);fighter.M:Refresh()
Equal(AllAway(fighter),true,"and none shows in a fight")
Equal(fighter:row("petDead")~=nil and fighter:click(fighter:row("petDead")),nil,"PET DEAD! is the plain row again, with no click in combat")
fighter:combat(false)

-- The slot under ASPECT!: nothing jumps when the fight begins.
local stacker=Session("HUNTER")
for _,id in ipairs({883,982,136,3661,13165})do stacker.known[id]=true end
for key,value in pairs({reminderClickable=true,reminderCombatClick=true,reminderCombat=true,reminder_HUNTER_petHealth=true})do stacker.env.EraUIDB[key]=value end
stacker.pet.exists=true;stacker.M:Initialize()
local sMend,sRevive=stacker:alert("petHealth"),stacker:alert("petDead")
Equal(stacker:row("aspect").point[3],0,"ASPECT! on top out of combat")
Equal(("%g %g"):format(sMend.point[5],sMend.slot),"431 2","PET LOW HEALTH!'s alert waits in the slot under it, where its row would go")
Equal(("%g %g"):format(sRevive.point[5],sRevive.slot),"565 1","PET DEAD!'s in the top slot, where its row would go")
stacker:combat(true);stacker:event("PLAYER_REGEN_DISABLED")
Equal(sMend:IsShown(),true,"in combat the faint heal icon is up")
Equal(stacker:row("aspect").point[3],0,"ASPECT! keeps the top slot")
Equal(stacker:row("petHealth"),nil,"with no PET LOW HEALTH! row as well")
stacker.pet.dead=true;stacker:drivers();stacker.M:Refresh()
Equal(sRevive:IsShown(),true,"the pet dies: PET DEAD! in the top slot")
Equal(stacker:row("aspect").point[3],-134,"ASPECT! moves under it, as out of combat")
stacker:combat(false);stacker:event("PLAYER_REGEN_ENABLED")
Equal(stacker:row("petDead").point[3]..","..stacker:row("aspect").point[3],"0,-134","out of combat the rows stack the same way")
-- Alert size: Small and Large set the alert's square, its words and its stack
-- slots the way they set the rows'. (Normal is 52, words 25 and 12, slots 134 apart.)
stacker.pet.dead=false
for _,case in ipairs({{1,"Small",40,20,10,576,468},{3,"Large",68,32,14,550,378},{2,"Normal",52,25,12,565,431}})do
 stacker.env.EraUIDB.reminderSize=case[1];stacker.M:Refresh()
 Equal(("%g %g"):format(sMend.width,sMend.height),("%g %g"):format(case[3],case[3]),case[2]..": the alert is the row's icon square")
 Equal(("%g %g %g"):format(sMend.text.fontSize,sMend.sub.fontSize,sRevive.text.fontSize),("%g %g %g"):format(case[4],case[5],case[4]),case[2]..": its words at the row's sizes")
 Equal(("%g %g"):format(sRevive.point[5],sMend.point[5]),("%g %g"):format(case[6],case[7]),case[2]..": waiting on the icons of the row slots, a row's height apart")
 Equal(sRevive.slot..","..sMend.slot,"1,2",case[2]..": in the top slot and the one under ASPECT!")
end
stacker.env.EraUIDB.reminderSize=nil
-- A dragged PET LOW HEALTH! with a title wider than the 190 minimum: its alert
-- lands on the icon of the wide row it stands for.
sMend.text.GetStringWidth=function()return 250 end
stacker.env.EraUIDB.reminderPX_HUNTER_petHealth=-100;stacker.env.EraUIDB.reminderPY_HUNTER_petHealth=-50;stacker.M:Refresh()
Equal(At(sMend),"813 515","a wide dragged alert is centred where its wide row's icon would be")
Equal(sMend.slot,nil,"outside the stack")
stacker.env.EraUIDB.reminderPX_HUNTER_petHealth=nil;stacker.env.EraUIDB.reminderPY_HUNTER_petHealth=nil
sMend.text.GetStringWidth=nil;stacker.M:Refresh()
Equal(At(sMend),"1000 431","back in the stack")
-- A /reload in combat: nothing secure is built until the fight ends.
local reloaded=Session("HUNTER")
reloaded.known[883]=true;reloaded.env.EraUIDB.reminderClickable=true;reloaded.env.EraUIDB.reminderCombatClick=true
reloaded:combat(true);reloaded.M:Initialize()
Equal(reloaded:alert("pet"),nil,"a reload in combat builds no secure alert")
reloaded:combat(false);reloaded:event("PLAYER_REGEN_ENABLED")
Equal(reloaded:alert("pet")and reloaded:alert("pet").rule,"[nocombat][@pet,exists] hide; show","it is built when the fight ends")
Equal(reloaded:alert("petDead"),nil,"no PET DEAD! alert before Revive Pet is learned")
reloaded.known[982]=true;reloaded.M:Refresh()
Equal(reloaded:alert("petDead")and reloaded:alert("petDead").attrs.macrotext1,"/cast [combat] Revive Pet","learned later: built then")
-- Paint reads the map every time, so counting those reads counts refreshes.
local function Paints(s)local n=0;s.env.WorldMapFrame.IsShown=function(self)n=n+1;return self.shown end;return function()return n end end
-- The game's own order: PLAYER_REGEN_DISABLED runs just before the fight's
-- lockdown starts, so its refresh is an out-of-combat one. The next frame,
-- inside the fight, puts away the row its alert now covers.
local order=Session("HUNTER")
order.known[883]=true
for key,value in pairs({reminderClickable=true,reminderCombatClick=true,reminderCombat=true})do order.env.EraUIDB[key]=value end
order.M:Initialize()
local orderPaints=Paints(order)
Equal(order:row("pet")~=nil,true,"no pet: SUMMON PET!'s row out of combat")
order:event("PLAYER_REGEN_DISABLED")
Equal(orderPaints(),1,"the start of a fight refreshes at once")
order:combat(true)
Equal(order:alert("pet"):IsShown(),true,"then the game shows SUMMON PET!'s alert")
order:tick(.01)
Equal(order:row("pet"),nil,"and on the next frame its row goes, with Show during combat on")
Equal(orderPaints(),2,"one more refresh did it")
order:tick(.01);Equal(orderPaints(),2,"then the usual half-second pace")
order:combat(false);order:event("PLAYER_REGEN_ENABLED")
Equal(orderPaints(),3,"the end of a fight refreshes at once too")
order:tick(.01);Equal(orderPaints(),3,"and needs no second refresh on the next frame")
Equal(order:click(order:row("pet")),"/cast [nocombat] Call Pet","and the row's click is back")
-- A saved "on" that can't act (EraUIDB is shared by every character) keeps
-- today's timing: no early refresh when a fight starts or ends.
local greyed=Session("HUNTER")
greyed.known[883]=true;greyed.env.EraUIDB.reminderCombatClick=true -- Clickable reminders off: the option is greyed out
greyed.M:Initialize()
local greyedPaints=Paints(greyed)
greyed:event("PLAYER_REGEN_DISABLED");greyed:combat(true);greyed:combat(false);greyed:event("PLAYER_REGEN_ENABLED")
Equal(greyedPaints(),0,"Clickable reminders off: a saved on adds no refresh")
Equal(greyed:alert("pet"),nil,"and builds nothing")
local cleric=Session("PRIEST")
cleric.known[1243]=true;cleric.env.EraUIDB.reminderClickable=true;cleric.env.EraUIDB.reminderCombatClick=true
cleric.M:Initialize()
local clericPaints=Paints(cleric)
Equal(cleric:click(cleric:row("fortitude")),"/cast [nocombat,@player] Power Word: Fortitude","a priest's reminder clicks out of combat")
cleric:event("PLAYER_REGEN_DISABLED");cleric:combat(true);cleric:combat(false);cleric:event("PLAYER_REGEN_ENABLED")
Equal(clericPaints(),0,"a class without a pet: a saved on adds no refresh")
Equal(cleric:click(cleric:row("fortitude")),nil,"so after a fight the click waits for the usual refresh, as before")
cleric:tick(.6)
Equal(cleric:click(cleric:row("fortitude")),"/cast [nocombat,@player] Power Word: Fortitude","which brings it back")

-- Warlocks: the demon you set and Health Funnel; no PET DEAD!.
local summoner=Session("WARLOCK")
local wtip=Tooltip(summoner)
for _,id in ipairs({688,755,11695})do summoner.known[id]=true end
for key,value in pairs({reminderClickable=true,reminderCombatClick=true,reminder_WARLOCK_petHealth=true})do summoner.env.EraUIDB[key]=value end
summoner.M:Initialize()
local demonAlert,funnelAlert=summoner:alert("pet"),summoner:alert("petHealth")
Equal(demonAlert.rule,"[nocombat][@pet,exists,nodead] hide; show","a warlock's SUMMON PET! shows while no living demon is out")
Equal(demonAlert.attrs.macrotext1,"/cast [combat] Summon Imp","and summons the Imp, the only demon known")
Equal(funnelAlert.attrs.macrotext1,"/cast [combat,@pet,exists,nodead] Health Funnel","PET LOW HEALTH! channels Health Funnel")
Equal(funnelAlert.icon.texture,11695,"at its highest known rank")
local wo=summoner:options()
Equal(wo.combatClick:IsShown(),true,"warlocks get the option")
wo.combatClick:Fire("OnEnter")
Equal(wtip[1]:find("^SUMMON PET! and PET LOW HEALTH! stay clickable in combat: your demon and Health Funnel%.")~=nil,true,"in the warlock's words")
Equal(wtip[1]:find("PET DEAD!",1,true),nil,"warlocks have no PET DEAD!")
Equal(wtip[1]:find("With a different demon out, SUMMON PET! can't be clicked until the fight ends.",1,true)~=nil,true,"it says a different demon out can't be swapped mid-fight")
Equal(wtip[1]:find("\226\128\148",1,true),nil,"with no em dash")
summoner.pet.exists=true;summoner.pet.dead=true;summoner:combat(true);summoner.M:Refresh()
Equal(demonAlert:IsShown()and demonAlert.sub.text,"Pet is dead","the demon dies mid-fight: SUMMON PET! says so")
Equal(funnelAlert:IsShown(),false,"no Health Funnel for a dead demon")
summoner:combat(false);summoner.pet.dead=false
-- A living demon of another family: the game can't tell, so the row says it.
summoner.known[697]=true;summoner.env.EraUIDB.reminderChoice_WARLOCK_pet=697;summoner.env.EraUIDB.reminderCombat=true
summoner.env.UnitCreatureFamily=function()return "Imp"end
summoner.env.C_CreatureInfo={GetCreatureFamilyInfo=function(id)return {name=({[16]="Voidwalker",[23]="Imp"})[id]}end}
summoner.M:Refresh()
Equal(demonAlert.attrs.macrotext1,"/cast [combat] Summon Voidwalker","the demon you set is what a click summons")
summoner:combat(true);summoner.M:Refresh()
Equal(demonAlert:IsShown(),false,"the Imp is out: the game hides SUMMON PET!")
Equal(summoner:row("pet")and summoner:row("pet").sub.text,"Different demon summoned","its row still says so in combat")
Equal(summoner:click(summoner:row("pet")),nil,"without a click, as before")
summoner:combat(false)
summoner.env.EraUIDB.reminderChoice_WARLOCK_pet=0;summoner.M:Refresh()
Equal(demonAlert.rule.." "..tostring(demonAlert.attrs.macrotext1),"hide nil","Any with two demons and none cast yet: no demon is guessed")
Equal(funnelAlert.rule,"[nocombat][@pet,noexists][@pet,dead] hide; show","Health Funnel stays armed")
-- Classes without a pet: no option, no alerts, whatever is saved.
local caster=Session("PRIEST")
caster.known[1243]=true;caster.env.EraUIDB.reminderClickable=true;caster.env.EraUIDB.reminderCombatClick=true
caster.M:Initialize()
Equal(caster:options().combatClick:IsShown(),false,"a priest has no Click pet reminders in combat")
Equal(#Visibility(caster),0,"and no alert or driver")
Equal(caster:click(caster:row("fortitude")),"/cast [nocombat,@player] Power Word: Fortitude","their reminders click outside combat as before")
-- The mock's macro conditions, as the drivers read them.
Equal(caster:parse("[nocombat] hide; [@pet,dead] show; hide"),"hide","out of combat: hide")
caster:combat(true)
Equal(caster:parse("[nocombat][@pet,exists] hide; show"),"show","in combat with no pet: show")
caster:combat(false)
print("Reminder click lifecycle: "..checks.." assertions passed")
