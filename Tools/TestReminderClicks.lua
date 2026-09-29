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
  [5118]="Aspect of the Cheetah",[1243]="Power Word: Fortitude",[688]="Summon Imp",[697]="Summon Voidwalker",
  [6201]="Create Healthstone",[19740]="Blessing of Might",[19742]="Blessing of Wisdom",
  [25291]="Blessing of Might",[25782]="Greater Blessing of Might",[25916]="Greater Blessing of Might",
  [25894]="Greater Blessing of Wisdom",[10938]="Power Word: Fortitude",[21564]="Prayer of Fortitude",
  [10157]="Arcane Intellect",[23028]="Arcane Brilliance",[9885]="Mark of the Wild",[21850]="Gift of the Wild",
  [25289]="Battle Shout"}
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
  local a=row.action
  return a and a:IsShown()and a.attrs.type1=="macro"and a.attrs.macrotext1 or nil
 end
 function s:event(...)
  for _,f in ipairs(frames)do if f.scripts.OnEvent and f.scripts.OnUpdate then f.scripts.OnEvent(f,...)end end
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
print("Reminder click lifecycle: "..checks.." assertions passed")
