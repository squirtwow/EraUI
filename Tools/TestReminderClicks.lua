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
  "RegisterForDrag","SetFont","SetAllPoints","Enable","Disable","SetScale","EnableMouseWheel"})do
  methods[name]=function(self)Guard(self)end
 end
 -- As the game does, SetAlpha takes a hidden value and draws with it.
 function methods:SetAlpha(a)
  Guard(self)
  if IsHidden(a)then self.alpha=rawget(a,"value");self.hiddenAlpha=true
  else assert(type(a)=="number","alpha must be a number");self.alpha=a;self.hiddenAlpha=false end
 end
 function methods:EnableMouse(v)Guard(self);self.mouse=v end
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
 function methods:SetVertexColor(r,g,b)self.tint={r,g,b}end
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
  [136]="Mend Pet",[3661]="Mend Pet",[13544]="Mend Pet",[755]="Health Funnel",[11695]="Health Funnel"}
 env.C_Spell={GetSpellInfo=function(id)return {name=names[id]or "Spell"..id,iconID=id}end,
  IsSpellUsable=function(id)if noMana[id]==secret then return false,secret end;if noMana[id]then return false,true end;return true,false end}
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
 local s={E=E,M=M,env=env,known=known,pet=pet,settings=settings,frames=frames,noMana=noMana}
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
local rogue=Session("ROGUE")
rogue.E.ClassTools.WeaponCoating=function()return {weapon=true,has=false}end
rogue.env.EraUIDB.reminder_ROGUE_poisonOff=true
rogue.env.EraUIDB.reminderGroup=true;rogue.env.EraUIDB.reminderClickable=true
rogue.M:Initialize()
Equal(rogue:row("poisonMain")~=nil,true,"generic main-hand poison alert initially visible")
Equal(rogue:row("poisonOff")~=nil,true,"generic off-hand poison alert initially visible")
local poisonOptions=rogue:options()
Equal(poisonOptions.group:IsShown(),false,"Rogue has no ineffective group toggle")
Equal(poisonOptions.clickable:IsShown(),false,"Rogue has no unsupported click toggle")
Equal(rogue.env.EraUIDB.reminderGroup,true,"hidden group setting preserved")
Equal(rogue.env.EraUIDB.reminderClickable,true,"hidden click setting preserved")
rogue.settings.poisonReminders=true;rogue.M:Refresh();rogue.M:UpdateOptionsState()
Equal(rogue:row("poisonMain"),nil,"dedicated poison panel suppresses duplicate main-hand alert")
Equal(rogue:row("poisonOff"),nil,"dedicated poison panel suppresses duplicate off-hand alert")
Equal(poisonOptions.offHint:IsShown(),true,"settings explain dedicated poison ownership")
poisonOptions.prev:Fire("OnClick")
Equal(rogue:row("poisonMain"),nil,"preview does not reintroduce duplicate poison alerts")
rogue.settings.poisonReminders=false;poisonOptions.prev:Fire("OnClick");rogue.M:UpdateOptionsState()
Equal(rogue:row("poisonMain")~=nil,true,"turning dedicated panel off restores generic main-hand alert")
Equal(rogue:row("poisonOff")~=nil,true,"turning dedicated panel off restores generic off-hand alert")
Equal(rogue.env.EraUIDB.reminder_ROGUE_poisonOff,true,"deduplication preserves per-alert preference")
Equal(poisonOptions.offHint:IsShown(),false,"ownership explanation clears when generic alerts resume")

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

-- A rogue with Poison Reminders on gets missing-poison alerts from that panel
-- instead, and it waits for landing too. Its positioning preview still shows.
local poisoner=Session("ROGUE")
local pnow,ptaxi=100,false
poisoner.env.GetTime=function()return pnow end
poisoner.env.UnitOnTaxi=function(unit)return unit=="player"and ptaxi end
poisoner.E.ClassTools.WeaponCoating=function()return {weapon=true,has=false}end
poisoner.settings.poisonReminders=true;poisoner.M:Initialize()
local classClock=poisoner:listener()
assert(loadfile("Modules/PoisonReminders.lua","t",poisoner.env))("EraUI",poisoner.E)
poisoner.E.modules.PoisonReminders:Initialize()
local poisonPanel=poisoner.env.EraUIPoisonReminders
local poisonClock
for _,f in ipairs(poisoner.frames)do if f~=classClock and f.scripts.OnEvent and f.scripts.OnUpdate then poisonClock=f end end
local function PoisonEvent(name)poisonClock.scripts.OnEvent(poisonClock,name)end
local function PoisonTick(dt)poisonClock.scripts.OnUpdate(poisonClock,dt)end
for _,name in ipairs({"PLAYER_CONTROL_LOST","PLAYER_CONTROL_GAINED","PLAYER_EQUIPMENT_CHANGED"})do
 Equal(poisonClock.events[name],true,"the poison panel refreshes on "..name)
end
Equal(poisonPanel:IsShown(),true,"on the ground a missing poison shows")
Equal(poisoner:row("poisonMain"),nil,"and the class alerts leave it to the poison panel")
ptaxi=true;PoisonEvent("PLAYER_CONTROL_LOST")
Equal(poisonPanel:IsShown(),false,"taking off hides the poison panel")
pnow=130;PoisonTick(.6)
Equal(poisonPanel:IsShown(),false,"its half-second refresh keeps it hidden in flight")
Equal(poisoner:row("poisonMain"),nil,"the class alerts stay out of it in flight")
poisoner.E.settingsFrame=poisoner.env.CreateFrame("Frame");poisoner.E.settingsFrame:Show();PoisonTick(.6)
Equal(poisonPanel:IsShown(),true,"with /era open its positioning preview still shows in flight")
poisoner.E.settingsFrame:Hide();PoisonTick(.6)
Equal(poisonPanel:IsShown(),false,"closing /era hides it again")
pnow=160;ptaxi=false;PoisonEvent("PLAYER_CONTROL_GAINED")
Equal(poisonPanel:IsShown(),false,"just landed: still hidden")
pnow=161.9;PoisonTick(.6)
Equal(poisonPanel:IsShown(),false,"1.9 seconds after landing: still hidden")
pnow=162.1;PoisonTick(.6)
Equal(poisonPanel:IsShown(),true,"2 seconds after landing the missing poison shows again")
poisoner.env.UnitOnTaxi=function()return secret end;PoisonTick(.6)
Equal(poisonPanel:IsShown(),true,"a hidden taxi answer is not a flight")
poisoner.env.UnitOnTaxi=nil;PoisonTick(.6)
Equal(poisonPanel:IsShown(),true,"a client without the taxi check keeps the poison panel")

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
print("Reminder click lifecycle: "..checks.." assertions passed")
