-- AFK screen: the real module under a frame mock. Protected calls throw in
-- combat, and any UIParent visibility change or view/CVar write always throws.
-- The ModelScene mock is a pinhole camera in pixels from the scene's
-- bottom-left, like Blizzard's drop shadow code reads Project3DPointTo2D.
local checks=0
unpack=table.unpack or unpack
local function Equal(a,b,label)checks=checks+1;assert(a==b,label..": expected "..tostring(b)..", got "..tostring(a))end
local function Near(a,b,label,eps)
 checks=checks+1;assert(type(a)=="number"and math.abs(a-b)<(eps or 1e-6),label..": expected "..tostring(b)..", got "..tostring(a))
end
local function Wrapped(v)local r=v%360;return math.min(r,360-r)end
-- A secret value, as strict as the client: asking issecretvalue is the only
-- safe thing. Reading from it, comparing, ordering, joining it into text or
-- doing sums with it throws, and so does using it as a key in the game's
-- lookup tables below (NoSecretKeys).
local secretReads=0
local function Refuse(what)return function()error("a secret value was "..what,2)end end
local secret=setmetatable({},{__index=Refuse("read from"),__newindex=Refuse("written to"),__call=Refuse("called"),
 __eq=Refuse("compared"),__lt=Refuse("compared"),__le=Refuse("compared"),__concat=Refuse("joined into text"),__len=Refuse("measured"),
 __unm=Refuse("used in a sum"),__add=Refuse("used in a sum"),__sub=Refuse("used in a sum"),__mul=Refuse("used in a sum"),
 __div=Refuse("used in a sum"),__mod=Refuse("used in a sum"),__pow=Refuse("used in a sum"),__idiv=Refuse("used in a sum")})
issecretvalue=function(v)if rawequal(v,secret)then secretReads=secretReads+1;return true end;return false end
local function NoSecretKeys(t)
 return setmetatable(t,{__index=function(_,k)if rawequal(k,secret)then error("a secret value was used as a table key",2)end end})
end
local forbidden={} -- every call that must never happen, across the whole suite
local function Forbid(name)forbidden[#forbidden+1]=name;error(name.." must never be called")end
local EXIT={"PLAYER_REGEN_DISABLED","PLAYER_STARTED_MOVING","PLAYER_DEAD","CINEMATIC_START","PLAY_MOVIE",
 "LFG_PROPOSAL_SHOW","READY_CHECK","ROLE_POLL_BEGIN","CONFIRM_SUMMON","RESURRECT_REQUEST","PARTY_INVITE_REQUEST",
 "TRADE_SHOW","DUEL_REQUESTED","PLAYER_CAMPING","PLAYER_QUITING","START_LOOT_ROLL","PLAYER_CONTROL_LOST",
 "PLAYER_LEAVING_WORLD","PLAYER_LOGOUT"}
local MEDIA="Interface\\AddOns\\EraUI\\Media\\"
local CLASS_ICONS="Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local s
local methods={}
local function Frame(kind,name,parent,template)
 local f=setmetatable({kind=kind,name=name,parent=parent,template=template,shown=true,alpha=1,points={},scripts={},events={},
  setTextCount=0,sized=false,rotations={}},{__index=methods})
 s.frames[#s.frames+1]=f;if name then s.named[name]=f end;return f
end
local function Guarded(self,name)if s.combat then error(name.." on "..(self.name or self.kind).." in combat")end end
function methods:SetPropagateKeyboardInput(v)Guarded(self,"SetPropagateKeyboardInput");self.propagate=v end
function methods:EnableKeyboard(v)Guarded(self,"EnableKeyboard");self.keyboard=v end
function methods:EnableMouse(v)Guarded(self,"EnableMouse");self.mouse=v end
function methods:EnableMouseWheel(v)Guarded(self,"EnableMouseWheel");self.wheel=v end
function methods:SetFrameStrata(v)Guarded(self,"SetFrameStrata");self.strata=v end
function methods:SetFrameLevel(v)self.level=v end
local function IgnoreParentAlpha(self,v)self.ignoreParentAlpha=v end
function methods:Show()self:SetShown(true)end
function methods:Hide()self:SetShown(false)end
function methods:SetShown(v)
 v=not not v
 if v and not self.sized and self.kind~="Texture"and self.kind~="FontString"then s.unsizedShows[#s.unsizedShows+1]=self end
 self.shown=v
end
function methods:IsShown()return self.shown end
function methods:SetSize(w,h)self.w,self.h,self.sized=w,h,true end
function methods:SetWidth(w)self.w=w end
function methods:SetHeight(h)self.h=h end
function methods:GetWidth()if self.allPoints then return self.allPoints:GetWidth()end;return self.w or 0 end
function methods:GetHeight()if self.allPoints then return self.allPoints:GetHeight()end;return self.h or 0 end
function methods:GetEffectiveScale()if s.esSecret then return secret end;return s.es end
function methods:SetAllPoints(r)self.allPoints=r or self.parent;self.sized=true;self.points={{"ALL",self.allPoints}}end
function methods:SetPoint(...)self.points[#self.points+1]={...}end
function methods:ClearAllPoints()self.points={}end
function methods:SetAlpha(v)self.alpha=v;self.alphaCalls=(self.alphaCalls or 0)+1 end
function methods:GetAlpha()return self.alpha end
function methods:SetScript(k,fn)self.scripts[k]=fn end
function methods:RegisterEvent(e)if s.unknown[e]then error("unknown event "..e)end;self.events[e]=true end
function methods:RegisterUnitEvent(e,u)self.events[e]=u end
function methods:UnregisterAllEvents()self.events={}end
function methods:CreateTexture(_,layer)local t=Frame("Texture",nil,self);t.layer=layer;return t end
function methods:CreateFontString(_,layer)local t=Frame("FontString",nil,self);t.layer=layer;return t end
function methods:SetTexture(path)self.texture=path;self.gradient=nil;if s.missing[path]then return false end;return true end
function methods:SetColorTexture(...)self.colour={...};self.texture="colour";self.gradient=nil end
function methods:SetVertexColor(...)self.colour={...}end
function methods:SetGradient(orient,a,b)self.gradient={orient,a,b}end
function methods:SetTexCoord(...)self.coords={...}end
function methods:SetFont(font,size,flags)if s.missing[font]then return false end;self.font={font,size,flags}end
function methods:SetText(v)self.text=v;self.setTextCount=self.setTextCount+1 end
function methods:SetTextColor(...)self.textColour={...}end
function methods:SetJustifyH(v)self.justify=v end
function methods:SetBackdrop(b)self.backdrop=b end
function methods:SetBackdropColor(...)self.backdropColour={...}end
function methods:SetBackdropBorderColor(...)self.borderColour={...}end
function methods:SetUnit(unit)
 s.setUnit[#s.setUnit+1]=unit
 -- A model given its unit while it or its parent is hidden can stay blank.
 s.setUnitVisible[#s.setUnitVisible+1]=self.shown==true and self.parent~=nil and self.parent.shown==true
 if s.setUnitError then error("no model")end
 return s.setUnitResult
end
function methods:SetRotation(v,animate)self.rotations[#self.rotations+1]={v,animate};self.rotation=v end
function methods:SetCamDistanceScale(v)self.camScale=v end
function methods:ClearModel()self.cleared=(self.cleared or 0)+1;self.unit=nil end
function methods:SetWordWrap(v)self.wrap=v end
function methods:SetMaxLines(n)self.maxLines=n end
for _,k in ipairs({"SetShadowColor","SetShadowOffset","SetPortraitZoom"})do methods[k]=function()end end

-- A ModelScene actor: loads after a delay, reports its box as six numbers
-- (as Blizzard reads it) or two vectors (as documented).
local function Vector(x,y,z)return {GetXYZ=function()return x,y,z end}end
local function Actor(template)
 local a={template=template,yaws={},cleared=0,calls={}}
 function a:SetModelByUnit(...)s.actorUnit={...};if s.actorSetFail then return false end;self.loadAt=s.clock+(s.loadDelay or 0);return true end
 function a:IsLoaded()if s.neverLoads then return false end;return self.loadAt~=nil and s.clock>=self.loadAt-1e-9 end
 function a:GetActiveBoundingBox()
  local b=s.bounds or{-.35,-.3,0,.35,.3,2.2}
  if s.boundsSecret then return secret,secret end
  if s.boundsVectors then return Vector(b[1],b[2],b[3]),Vector(b[4],b[5],b[6])end
  return unpack(b)
 end
 function a:GetScale()return s.actorScale or 1 end
 function a:SetYaw(v)self.yaws[#self.yaws+1]=v end
 function a:ClearModel()self.cleared=self.cleared+1;self.loadAt=nil end
 for _,k in ipairs({"SetUseCenterForOrigin","SetPosition","SetPitch","SetRoll","SetAnimationBlendOperation","SetAnimation"})do
  a[k]=function(self,...)self.calls[k]={...}end
 end
 return a
end
local function Scene(f)
 f.cam={x=0,y=0,z=0};f.camCalls=0;f.lights={};f.actors={}
 function f:SetCameraFieldOfView(v)self.setFov=v end
 function f:GetCameraFieldOfView()if s.reportFov then return s.reportFov end;return self.setFov end
 function f:SetCameraPosition(x,y,z)self.camCalls=self.camCalls+1;self.cam={x=x,y=y,z=z}end
 function f:SetCameraOrientationByYawPitchRoll(y,p,r)self.orient={y,p,r}end
 function f:Project3DPointTo2D(x,y,z)
  if s.projectNothing then return end
  assert(self.orient and self.orient[1]==math.pi and self.orient[2]==0,"camera must look back along -X")
  local W,H=self.w*s.es,self.h*s.es
  local depth=self.cam.x-x;if depth<=0 then return end
  local k=H/2/(depth*math.tan(s.realFov/2))
  local px,py=W/2+(y-self.cam.y)*k,H/2+(z-self.cam.z)*k
  if s.projectNormalized then return px/W,py/H,depth end
  if s.projectFlipped then py=H-py end
  if s.projectOffset then px,py=px+s.projectOffset,py+s.projectOffset end -- as if from the screen's corner
  return px,py,depth
 end
 for _,k in ipairs({"SetCameraNearClip","SetCameraFarClip","ClearFog","SetLightVisible","SetLightType","SetLightAmbientColor","SetLightDiffuseColor","SetLightDirection"})do
  f[k]=function(self,...)self.lights[k]={...}end
 end
 function f:CreateActor(name,template)
  if s.noActor then return nil end
  if s.actorNeedsTemplate and template==nil then error("CreateActor needs a template")end
  local a=Actor(template);a.name=name;self.actors[#self.actors+1]=a;return a
 end
 if s.noProject then f.Project3DPointTo2D=nil end
 return f
end
-- Frame and pixel positions of a projected point in the current scene camera.
local function Projected(z)local sc=s.M.scene;local x,y=sc:Project3DPointTo2D(0,0,z);return x/s.es,y/s.es end

local function Session(settings,opts)
 opts=opts or{}
 s={frames={},named={},timers={},clock=100,afk=false,combat=false,yawNet=0,flips=0,zoomNet=0,zoomCalls=0,camStart=20,
  moves={},missing={},unknown={},prints={},statuses={},cvars={},bg={},dateFormats={},hooks={},setUnit={},setUnitVisible={},unsizedShows={},
  now={year=2026,month=9,day=29,hour=15,min=7,sec=0,wday=3},guild="Guild",zone="Zone",subzone="Sub",level=60,
  es=.75,realFov=.6,class="PALADIN",className="Paladin",mapHides=0,mapShows=0,setTexCalls=0,
  faction="Alliance",rolls={},rng=12345,randCalls=0}
 for k,v in pairs(opts)do s[k]=v end
 if opts.noGuild then s.guild=nil end
 methods.SetIgnoreParentAlpha=not opts.noIgnoreAlpha and IgnoreParentAlpha or nil
 methods.RegisterUnitEvent=not opts.noUnitEvents and function(self,e,u)self.events[e]=u end or nil
 UIParent=Frame("UIParent");UIParent.w,UIParent.h,UIParent.sized=1920,1080,true
 UIParent.Hide=function()Forbid("UIParent:Hide")end
 UIParent.Show=function()Forbid("UIParent:Show")end
 UIParent.SetShown=function()Forbid("UIParent:SetShown")end
 for _,k in ipairs({"SetUIVisibility","SetInWorldUIVisibility","SaveView","SetView","ResetView","SetCVar","UpdateUIPanelPositions"})do
  _G[k]=function()Forbid(k)end
 end
 CreateFrame=function(kind,name,parent,template)
  if kind=="ModelScene"then
   if s.noModelScene then error("unknown frame type ModelScene")end
   return Scene(Frame(kind,name,parent,template))
  end
  return Frame(kind,name,parent,template)
 end
 CreateColor=not opts.noCreateColor and function(r,g,b,a)return {r=r,g=g,b=b,a=a}end or nil
 -- The minimap: shown, not protected; a protected one throws when hidden or shown in combat.
 Minimap=nil
 if not opts.noMinimap then
  Minimap={shown=not opts.mapOff,protected=opts.mapProtected}
  function Minimap:IsShown()if s.mapShownSecret then return secret end;return self.shown end
  function Minimap:IsProtected()if s.mapProtectedSecret then return secret,false end;return self.protected and true or false,false end
  function Minimap:Hide()if self.protected and s.combat then error("Minimap:Hide blocked in combat")end;s.mapHides=s.mapHides+1;self.shown=false end
  function Minimap:Show()if self.protected and s.combat then error("Minimap:Show blocked in combat")end;s.mapShows=s.mapShows+1;self.shown=true end
 end
 -- editMode: true (open), "secret" (an unreadable answer) or "error" (the call fails).
 EditModeManagerFrame=opts.editMode and{IsEditModeActive=function(self)
  assert(rawequal(self,EditModeManagerFrame))
  if s.editMode=="error"then error("Edit Mode unavailable")end
  if s.editMode=="secret"then return secret end
  return true
 end}or nil
 C_Timer={After=function(_,fn)s.timers[#s.timers+1]=fn end}
 hooksecurefunc=function(name,fn)assert(type(name)=="string","global post-hook");s.hooks[name]=s.hooks[name]or{};table.insert(s.hooks[name],fn)end
 StaticPopup_Show=function(...)for _,fn in ipairs(s.hooks.StaticPopup_Show or{})do fn(...)end end
 GetTime=function()return s.clock end
 date=function(f)
  if f=="*t"then local t={};for k,v in pairs(s.now)do t[k]=v end;return t end
  s.dateFormats[#s.dateFormats+1]=f;return "Fallback date"
 end
 InCombatLockdown=function()return s.combat end
 UnitAffectingCombat=function()return s.combat or s.affecting end
 UnitIsAFK=function(unit)assert(unit=="player");if s.afkError then error("AFK unavailable")end;return s.afk end
 UnitName=function()return "Ann",s.surname==nil and "Smith"or s.surname end
 UnitClass=function()return s.className,s.class end
 UnitRace=function()return "Human","Human"end
 UnitLevel=function()return s.level end
 GetGuildInfo=function()return s.guild end
 GetRealZoneText=function()return s.zone end
 GetZoneText=function()return s.zone end
 GetSubZoneText=function()return s.subzone end
 UnitIsDeadOrGhost=function()return s.dead end
 UnitOnTaxi=function()return s.taxi end
 InCinematic=function()return s.cinematic end
 GetCurrentKeyBoardFocus=function()return s.focus end
 local binds={F12="SCREENSHOT",W="MOVEFORWARD",SPACE="JUMP",ENTER="OPENCHAT",["1"]="ACTIONBUTTON1",ESCAPE="TOGGLEGAMEMENU",X=secret}
 GetBindingFromClick=function(key)return binds[key]end
 -- Documented: every restriction reads inactive while its change event is dispatched.
 C_RestrictedActions={IsAddOnRestrictionActive=function(t)if s.dispatching then return false end;return s.restricted==t end}
 Enum={AddOnRestrictionState={Inactive=0,Activating=1,Active=2},ModelBlendOperation={None=0},ModelLightType={Directional=0,Point=1}}
 GetMaxBattlefieldID=function()return 2 end
 GetBattlefieldStatus=function(i)return s.bg[i]or "none"end
 GetCVar=function(name)return s.cvars[name]end
 ClassTrainerFrame=s.trainer
 FlipCameraYaw=function(d)s.yawNet=s.yawNet+d;s.flips=s.flips+1 end
 CameraZoomIn=function(d)s.zoomNet=s.zoomNet+d;s.zoomCalls=s.zoomCalls+1 end
 CameraZoomOut=function(d)s.zoomNet=s.zoomNet-d;s.zoomCalls=s.zoomCalls+1 end
 GetCameraZoom=function()if s.camSecret then return secret end;return s.camStart-s.zoomNet end
 for _,k in ipairs({"MoveViewLeftStart","MoveViewRightStart","MoveViewLeftStop","MoveViewRightStop"})do
  _G[k]=function(v)s.moves[#s.moves+1]={k,v}end
 end
 for _,k in ipairs(opts.without or{})do _G[k]=nil end
 CALENDAR_WEEKDAY_NAMES={"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"}
 CALENDAR_FULLDATE_MONTH_NAMES={"January","February","March","April","May","June","July","August","September","October","November","December"}
 TIMEMANAGER_AM,TIMEMANAGER_PM="AM","PM"
 -- Warlock is left out on purpose: a class the tables don't know.
 RAID_CLASS_COLORS=NoSecretKeys({PALADIN={r=.1,g=.2,b=.3},MAGE={r=.4,g=.8,b=1},HUNTER={r=.67,g=.83,b=.45},PRIEST={r=1,g=1,b=1},
  ROGUE={r=1,g=.96,b=.41},DRUID={r=1,g=.49,b=.04},WARRIOR={r=.78,g=.61,b=.43},SHAMAN={r=0,g=.44,b=.87}})
 CUSTOM_CLASS_COLORS=opts.custom and NoSecretKeys(opts.custom)or nil
 CLASS_ICON_TCOORDS=not opts.noClassCoords and NoSecretKeys({PALADIN={0,.25,.5,.75},MAGE={.25,.49609375,0,.25},HUNTER={0,.25,.25,.5}})or nil
 -- The player's faction: a name, a secret, an error or no API at all.
 UnitFactionGroup=not opts.noFactionAPI and function(unit)
  assert(unit=="player");s.factionCalls=(s.factionCalls or 0)+1;if s.factionError then error("faction unavailable")end;return s.faction,s.faction
 end or nil
 -- Chance: scripted rolls first, else a fixed pseudo-random sequence (the same every run).
 math.random=function(n)
  assert(type(n)=="number"and n>=1 and n%1==0,"math.random needs a whole count, got "..tostring(n))
  s.randCalls=s.randCalls+1
  local r=table.remove(s.rolls,1);if r==nil then s.rng=(s.rng*1103515245+12345)%2147483648;r=math.floor(s.rng/65536)%n+1 end
  assert(r>=1 and r<=n,"a scripted roll within 1.."..n);return r
 end
 local E={modules={},settings={enabled=true,afkScreen=true,afkZoom=true,afkShowGuild=true,afkShowZone=true,afkShowDate=true,afkShowQuote=true}}
 for k,v in pairs(settings or{})do E.settings[k]=v end
 function E:RegisterModule(k,v)self.modules[k]=v end
 function E:GetSetting(k)return self.settings[k]end
 function E:Print(m)s.prints[#s.prints+1]=m end
 function E:Status(m)s.statuses[#s.statuses+1]=m end
 -- Dark Mode greys every texture drawn through the skin; the AFK screen never uses it.
 E.Classic={SetTex=function(t,key)s.setTexCalls=s.setTexCalls+1;t:SetTexture("Interface\\"..key);t:SetVertexColor(.42,.44,.48)end}
 -- In the TOC's order: the quotes, then the screen. The quote table refuses secret keys too.
 if not opts.noQuotes then assert(loadfile("Modules/AFKQuotes.lua"))("EraUI",E);NoSecretKeys(E.AFKQuotes)end
 if opts.quotes then E.AFKQuotes=opts.quotes end
 assert(loadfile("Modules/AFKScreen.lua"))("EraUI",E)
 s.E,s.M=E,E.modules.AFKScreen
 s.shipped=s.M.comingSoon
 if opts.comingSoon~=nil then s.M.comingSoon=opts.comingSoon end
 local before=#s.frames
 s.M:Initialize()
 s.events=s.frames[before+1]
 s.created=#s.frames-before
 return s
end
local function Event(e,...)local f=s.events;if f.events[e]then f.scripts.OnEvent(f,e,...)end end
local function Flags(afk)s.afk=afk;Event("PLAYER_FLAGS_CHANGED","player")end
local function Restrict(t,state)s.dispatching=true;Event("ADDON_RESTRICTION_STATE_CHANGED",t,state);s.dispatching=false end
local function Root()return s.named.EraUIAFKScreen end
local function Run(seconds,dt)
 dt=dt or .05
 for _=1,math.floor(seconds/dt+.5)do
  s.clock=s.clock+dt
  local r=Root();if r and r.shown and r.scripts.OnUpdate then r.scripts.OnUpdate(r,dt)end
 end
end
local function Flush()
 for _=1,20 do if #s.timers==0 then return end;local p=s.timers;s.timers={};for _,fn in ipairs(p)do fn()end end
 error("timers did not settle")
end
local function Active()return s.M.active==true end
local function Line(key)return s.M.lines[key]end
local function Firsts(t)local p=t.points[1];return p and p[2]end
local function Join(t,n)local out={};for i=1,n or #t do out[i]=tostring(t[i])end;return table.concat(out,",")end
local function Colour(t,c)local v=t.colour or t.textColour or{};return math.abs(v[1]-c[1])<1e-6 and math.abs(v[2]-c[2])<1e-6 and math.abs(v[3]-c[3])<1e-6 end
local function Grad(t)local g=t.gradient;return g and g[1],g and g[2].a,g and g[3].a end
local NAVY,VIOLET,SILVER,MUTED,LAVENDER={.02,.035,.08},{.58,.4,1},{.9,.92,.97},{.6,.64,.76},{.76,.7,1}

-- 0. Ships finished and on by default; the Coming soon switch still works.
Session()
Equal(s.shipped,false,"the AFK Screen ships finished, not Coming soon")
do -- the real defaults, from Core/Init.lua
 local make,cvar,global=CreateFrame,C_CVar,_G.EraUI
 CreateFrame=function()return {RegisterEvent=function()end,SetScript=function()end}end;C_CVar=nil
 local Init={};assert(loadfile("Core/Init.lua"))("EraUI",Init)
 CreateFrame,C_CVar,_G.EraUI=make,cvar,global
 Equal(Init.settingDefaults.afkScreen,true,"Core/Init.lua: AFK Screen on by default")
 Equal(Init.settingDefaults.afkZoom==true and Init.settingDefaults.afkShowGuild==true and Init.settingDefaults.afkCameraNormal==false,true,"its options keep their defaults")
 Equal(Init.settingDefaults.afkShowQuote,true,"Core/Init.lua: the class quote on by default")
end
Session(nil,{comingSoon=true})
local made=#s.frames
Equal(s.E.settings.afkScreen,true,"coming soon, with the option saved on")
Equal(s.created,0,"coming soon: no frames made")
Equal(s.events,nil,"coming soon: no event frame")
Equal(s.hooks.StaticPopup_Show,nil,"coming soon: no popup hook")
s.afk=true;s.M:OnFlags();s.M:Refresh()
Equal(Root(),nil,"coming soon: an AFK flag builds no screen")
Equal(Active(),false,"coming soon: not active")
s.M:Enter(true)
Equal(Root()==nil and not Active(),true,"coming soon: nothing opens even when asked directly")
s.M:Preview();Flush()
Equal(s.prints[1],"The AFK screen is coming soon.","/era afk says it is coming soon")
Equal(#s.prints,1,"and only that")
Equal(Root()==nil and not Active(),true,"coming soon: /era afk opens nothing")
Equal(#s.frames,made,"coming soon: nothing made at all")
Equal(UIParent.alpha,1,"coming soon: interface alpha untouched")
Equal(#s.moves+s.flips+s.zoomCalls,0,"coming soon: the camera is never touched")

-- 1. Switched off: only the event frame, nothing registered, flags ignored.
Session({afkScreen=false})
Equal(s.created,1,"off: only the plain event frame is created")
Equal(next(s.events.events),nil,"off: no events registered")
s.M:OnFlags();Flags(true);s.M:Enter()
Equal(Root(),nil,"off: an AFK flag builds no screen")
Equal(UIParent.alpha,1,"off: interface alpha untouched")
Equal(Active(),false,"off: not active")

-- 2. On: unit event for the player, every exit event, unknown names survive.
Session(nil,{unknown={ROLE_POLL_BEGIN=true,LFG_PROPOSAL_SHOW=true}})
Equal(s.events.events.PLAYER_FLAGS_CHANGED,"player","flags registered as a player unit event")
Equal(s.events.events.UNIT_PORTRAIT_UPDATE,"player","portrait registered as a player unit event")
Equal(s.events.events.PLAYER_REGEN_DISABLED,true,"combat start registered")
Equal(s.events.events.PLAYER_STARTED_MOVING,true,"movement registered")
for _,e in ipairs(EXIT)do
 if not s.unknown[e]then Equal(s.events.events[e],true,e.." registered")end
end
Equal(s.events.events.ROLE_POLL_BEGIN,nil,"an unknown event name is skipped")
Equal(s.events.events.PLAYER_LOGOUT,true,"events after an unknown name still register")
Equal(s.events.events.ADDON_RESTRICTION_STATE_CHANGED,true,"restriction changes registered")
Equal(Root(),nil,"enabling builds nothing until the first AFK")

-- 3. An AFK transition enters with a sized, input-catching root above everything,
-- in EraUI's own look.
Session()
Flags(true)
local root=Root()
Equal(Active(),true,"AFK transition enters")
Equal(root.shown,true,"root shown")
Equal(root.strata,"TOOLTIP","root sits in TOOLTIP strata")
Equal(root.ignoreParentAlpha,true,"root ignores UIParent alpha")
Equal(root.allPoints,UIParent,"root covers UIParent")
Equal(root.parent,UIParent,"root keeps UIParent scale")
Equal(root.mouse and root.wheel and root.keyboard,true,"mouse, wheel and keyboard caught")
Equal(root.propagate,true,"keys still reach their bindings")
Equal(#s.unsizedShows,0,"every frame sized before its first Show")
for _,f in ipairs(s.frames)do
 if f.kind~="Texture"and f.kind~="FontString"and f~=UIParent and f~=s.events then
  Equal(f.sized,true,(f.name or f.kind).." sized at creation")
  Equal(#f.points>0,true,(f.name or f.kind).." anchored at creation")
  if f~=root then Equal(f.mouse,nil,(f.name or f.kind).." leaves every click to the root")end
 end
end
Equal(s.setTexCalls,0,"no texture goes through the skin, so Dark Mode can't grey it")
-- Shading from the top and bottom edges.
local shades=s.M.shades
Equal(shades.top.points[1][1]=="TOPLEFT"and shades.top.points[2][1]=="TOPRIGHT",true,"top shade spans the top edge")
Equal(shades.bottom.points[1][1]=="BOTTOMLEFT"and shades.bottom.points[2][1]=="BOTTOMRIGHT",true,"bottom shade spans the bottom edge")
Equal(shades.top.layer=="BACKGROUND"and shades.bottom.layer=="BACKGROUND",true,"shades sit behind everything")
Near(shades.top.h,1080*.34,"top shade a third of the screen")
Near(shades.bottom.h,1080*.3,"bottom shade under a third of the screen")
do
 local o,a1,a2=Grad(shades.top);Equal(o,"VERTICAL","top shade fades vertically")
 Equal(a1==0 and a2>.8,true,"top shade: dark at the edge, clear toward the middle")
 o,a1,a2=Grad(shades.bottom);Equal(a1>.8 and a2==0,true,"bottom shade: dark at the edge, clear toward the middle")
 local c=shades.top.gradient[3];Equal(c.r==NAVY[1]and c.g==NAVY[2]and c.b==NAVY[3],true,"shades are deep navy")
end
-- The crest: the EraUI banner (no box) on a wide violet glow, the title under it.
local crest=s.M.crest
Equal(crest.logo,nil,"the square logo is gone")
Equal(crest.drop.texture,MEDIA.."EraUIBannerShadow.tga","the banner's blurred letter shadow")
Equal(crest.base.texture,MEDIA.."EraUIBannerBase.tga","the banner's violet swirl, letters cut out")
Equal(crest.letters.texture,MEDIA.."EraUIBannerLetters.tga","the banner's grey letters")
Equal(crest.drop.layer=="BORDER"and crest.base.layer=="ARTWORK"and crest.letters.layer=="OVERLAY",true,"drawn shadow first, then the swirl, then the letters")
for _,k in ipairs({"drop","base","letters"})do
 Equal(Join(crest[k].coords),"0,1,0,"..tostring(243/256),k..": the art's clear bottom rows cut off (texcoords 0,1,0,243/256)")
end
Equal(crest.base.allPoints==crest and crest.letters.allPoints==crest,true,"swirl and letters fill the banner")
do local a,b=crest.drop.points[1],crest.drop.points[2]
 Equal(a[1]=="TOPLEFT"and a[2]==crest and a[3]=="TOPLEFT"and a[4]==0 and a[5]==-3,true,"the shadow drops 3 below the letters (top)")
 Equal(b[1]=="BOTTOMRIGHT"and b[2]==crest and b[3]=="BOTTOMRIGHT"and b[4]==0 and b[5]==-3,true,"the shadow drops 3 below the letters (bottom)")end
Equal(Colour(crest.drop,{0,0,0})and crest.drop.colour[4],.9,"the shadow is black at .9")
Equal(Colour(crest.letters,{.96,.55,.73}),true,"a paladin's letters in Classic paladin pink, like the card")
Near(crest.h,1080*.235-1080*.03,"the banner ends just under a quarter of the way down")
Near(crest.w,crest.h*512/243,"and keeps the art's shape")
Equal(crest.points[1][1]=="TOP"and crest.points[1][2]==Root()and crest.points[1][3]=="TOP"and crest.points[1][4]==0,true,"banner top centre")
Near(crest.points[1][5],-1080*.03,"the banner's top gap as before")
Near(-crest.points[1][5]+crest.h,1080*.235,"its bottom at 23.5% of the screen")
Equal(crest.level,3,"crest above the character")
Equal(crest.glow.texture,MEDIA.."LogoGlow.tga","glow uses the generated radial glow")
Equal(crest.glow.layer,"BACKGROUND","glow behind the banner")
Equal(Colour(crest.glow,VIOLET),true,"glow tinted arcane violet")
Near(crest.glow.h,crest.h*2.3,"glow reaches well past the banner")
Near(crest.glow.w,crest.glow.h*1.9,"and is stretched wide like the banner")
Equal(crest.glow.points[1][1]=="CENTER"and crest.glow.points[1][2]==crest,true,"glow centred on the banner")
Equal(crest.title.text,"Away from keyboard","title under the banner")
Equal(crest.title.font[1]=="Fonts\\MORPHEUS.TTF"and crest.title.font[3],"OUTLINE","title in Morpheus, outlined")
Equal(crest.title.font[2],31,"title sized with the banner")
Equal(Colour(crest.title,SILVER),true,"title silver-white")
Equal(crest.title.justify,"CENTER","title centred under the banner")
do local p=crest.title.points[1]
 Equal(p[1]=="TOP"and p[2]==crest and p[3]=="BOTTOM"and p[4]==0 and p[5]==-2,true,"title just under the banner")end
do local o,a1,a2=Grad(crest.rules[1]);local _,b1,b2=Grad(crest.rules[2])
 Equal(o=="HORIZONTAL"and a1==0 and a2>0 and b1>0 and b2==0,true,"a violet rule fading out both ways under the title")
 Equal(crest.rules[1].points[1][2]==crest.title and crest.rules[2].points[1][2]==crest.title,true,"the rules under the title")end
Equal(s.M.hint.text,"Move or press any key to come back","hint line")
Equal(s.M.hint.points[1][1]=="BOTTOM"and s.M.hint.points[1][3]=="BOTTOM"and s.M.hint.points[1][4]==0,true,"hint bottom centre")
Equal(s.M.hint.parent.level>crest.level and s.M.hint.parent.allPoints==root,true,"hint drawn above everything")
-- The banner size is clamped to sensible limits, and never over 60% of the screen wide.
UIParent.h=400;Event("DISPLAY_SIZE_CHANGED")
Equal(crest.h,100,"a short screen keeps the banner at least 100 tall")
Near(crest.w,100*512/243,"at the art's shape")
Equal(crest.title.font[2],20,"and the title at least 20")
UIParent.h=1500;Event("UI_SCALE_CHANGED")
Equal(crest.h,300,"a tall screen caps the banner at 300")
Equal(#crest.points,1,"relayout clears the old anchor")
Near(crest.glow.h,300*2.3,"the glow follows the banner");Near(crest.glow.w,300*2.3*1.9,"wide")
Equal(crest.title.font[2],34,"the title at most 34")
UIParent.h=1080;UIParent.w=600;Event("DISPLAY_SIZE_CHANGED")
Near(crest.w,600*.6,"a narrow screen keeps the banner within 60% of its width")
Near(crest.h,600*.6*243/512,"at the art's shape")
UIParent.w=1920;Event("DISPLAY_SIZE_CHANGED")
Near(crest.h,1080*.235-1080*.03,"back to the usual size")
Session(nil,{missing={["Fonts\\MORPHEUS.TTF"]=true}});Flags(true)
Equal(s.M.crest.title.font[1]~="Fonts\\MORPHEUS.TTF"and s.M.crest.title.font[2],29,"missing title font falls back to the normal font")
-- The letters take the class colour, as the card does; the swirl stays violet.
for _,case in ipairs({{"HUNTER","Hunter",{.67,.83,.45},"hunter green"},{"ROGUE","Rogue",{1,.96,.41},"rogue yellow"},
 {"DRUID","Druid",{1,.49,.04},"druid orange"},{"PRIEST","Priest",{1,1,1},"white: a priest stays white"},
 {"WARLOCK","Warlock",SILVER,"silver: a class the tables don't know"},{secret,secret,SILVER,"silver: a secret class"}})do
 Session(nil,{class=case[1],className=case[2]});Flags(true)
 Equal(Colour(s.M.crest.letters,case[3]),true,"banner letters in "..case[4])
 Equal(s.M.crest.base.colour,nil,"the swirl keeps its own violet ("..case[4]..")")
end
Session(nil,{class="ROGUE",className="Rogue",custom={ROGUE={r=.2,g=.3,b=.4}}});Flags(true)
Equal(Colour(s.M.crest.letters,{.2,.3,.4})and Colour(Line("name"),{.2,.3,.4}),true,"custom class colours tint the letters and the name alike")
Session(nil,{class="HUNTER",className="Hunter"});Flags(true);Flags(false)
s.class,s.className="MAGE","Mage";Flags(true)
Equal(Colour(s.M.crest.letters,{.4,.8,1}),true,"the letters are tinted again each time the screen opens")
Session(nil,{noCreateColor=true});Flags(true)
Equal(s.M.shades.top.gradient,nil,"without CreateColor no gradient is forced")
Equal(s.M.shades.top.colour[4]>0 and s.M.shades.top.colour[4]<1,true,"a soft flat shade stands in")
-- Our own art the client refuses (a file added after the game started, then a
-- /reload): hidden, never a missing-texture block; the title and rules stay.
Session();Flags(true);Run(.05,.05)
do local c=s.M.crest
 Equal(c.drop.shown and c.base.shown and c.letters.shown and c.glow.shown and s.M.shadow.shown,true,"every layer shows when its art loads")end
for _,case in ipairs({{"EraUIBannerBase","the swirl"},{"EraUIBannerLetters","the letters"}})do
 Session(nil,{missing={[MEDIA..case[1]..".tga"]=true}});Flags(true);Run(.05,.05)
 local c=s.M.crest
 Equal(c.drop.shown or c.base.shown or c.letters.shown,false,case[2].." refused: no banner at all, not half of one")
 Equal(c.title.shown and c.title.text=="Away from keyboard"and c.rules[1].shown and c.rules[2].shown,true,case[2].." refused: the title and its rules stay")
 Equal(c.glow.shown and s.M.shadow.shown and Active(),true,case[2].." refused: the glow, the ground shadow and the screen stay")
end
Session(nil,{missing={[MEDIA.."EraUIBannerShadow.tga"]=true}});Flags(true)
Equal(not s.M.crest.drop.shown and s.M.crest.base.shown and s.M.crest.letters.shown,true,"the letter shadow refused: the banner shows without it")
Session(nil,{missing={[MEDIA.."LogoGlow.tga"]=true}});Flags(true);Run(.05,.05)
Equal(s.M.crest.glow.shown,false,"the glow refused: hidden")
Equal(s.M.framed,true,"the character still framed")
Equal(s.M.shadow.shown,false,"the ground shadow, the same art, never shows")
Run(10,.05);Equal(s.M.crest.glow.shown or s.M.shadow.shown,false,"not even as the glow breathes")
UIParent.h=900;Event("DISPLAY_SIZE_CHANGED");Run(.05,.05)
Equal(s.M.framed==true and not s.M.shadow.shown,true,"nor when a new size frames the character again")
Flags(false);Flags(true);Run(.05,.05);Equal(s.M.shadow.shown,false,"nor at the next AFK")
Session(nil,{noModelScene=true,missing={[MEDIA.."LogoGlow.tga"]=true}});Flags(true)
Equal(s.M.modelPath=="model"and s.M.model.shown and not s.M.shadow.shown,true,"the PlayerModel stand-in shows without the refused shadow")

-- 4. The info card: EraUI's dark tooltip panel, class accent, class icon.
Session();Flags(true)
local card=s.M.card
Equal(card.template,"BackdropTemplate","card uses the backdrop template")
Equal(card.backdrop.edgeFile,MEDIA.."TooltipBorder.tga","EraUI's grey bevelled tooltip border")
Equal(card.backdrop.bgFile,"Interface\\Buttons\\WHITE8X8","a flat dark fill, not the Blizzard dialog")
Equal(card.backdrop.edgeSize,16,"tooltip border size")
Equal(Colour({colour=card.backdropColour},NAVY)and card.backdropColour[4]>.7 and card.backdropColour[4]<1,true,"dark translucent navy")
do local b=card.borderColour or{}
 Equal(b[1]~=nil and b[1]==b[2]and b[2]==b[3]and b[1]>.5,true,"the border keeps its own neutral grey bevel, never a gold one")end
Equal(card.points[1][1]=="BOTTOMRIGHT"and card.points[1][2]==Root(),true,"card bottom right")
Near(card.points[1][4],-1920*.03,"card in from the right edge")
Near(card.points[1][5],1080*.08,"card up from the bottom edge")
Equal(card.w,380,"card width")
local accent,icon=s.M.accent,s.M.icon
Equal(accent.w==3 and accent.points[1][1]=="TOPLEFT"and accent.points[2][1]=="BOTTOMLEFT",true,"a thin accent bar down the left edge")
Equal(Colour(accent,{.96,.55,.73}),true,"accent in the class colour")
Equal(icon.texture,CLASS_ICONS,"Blizzard's class circles")
Equal(icon.shown,true,"class icon shown")
Equal(table.concat(icon.coords,","),"0,0.25,0.5,0.75","the paladin circle")
Equal(icon.points[1][4]==20 and icon.points[1][5]==-14,true,"icon top left of the card")

-- 5. Info lines.
Equal(Line("name").text,"Ann Smith","first name and surname")
Equal(Colour(Line("name"),{.96,.55,.73}),true,"name in Classic Paladin pink")
Equal(Line("name").font[2]==22 and Line("name").font[3],"OUTLINE","name large with a dark outline")
Equal(Line("info").text,"Level 60 Human Paladin","level, race and class")
Equal(Line("guild").text,"<Guild>","guild in brackets")
Equal(Line("zone").text,"Sub, Zone","subzone and zone")
Equal(Line("date").text,"Tuesday, 29 September","date from the calendar names")
Equal(Line("away").text,"Away for 00:00","away timer starts at zero")
Equal(Line("away").font[2]==22 and Line("away").font[3],"OUTLINE","time away large")
Equal(Line("clock").text,"3:07 PM","12-hour local time")
Equal(Line("clockLabel").text,"Local time","clock label")
for _,case in ipairs({{"info",SILVER,"silver"},{"guild",LAVENDER,"lavender"},{"zone",MUTED,"muted blue-grey"},
 {"away",SILVER,"silver"},{"clock",SILVER,"silver"},{"date",MUTED,"muted blue-grey"},{"clockLabel",MUTED,"muted blue-grey"}})do
 Equal(Colour(Line(case[1]),case[2]),true,"the "..case[1].." line in "..case[3])
end
Equal(Firsts(Line("name")),card,"name at the top of the card")
Equal(Line("name").points[1][4],76,"name beside the class icon")
Equal(Firsts(Line("info")),Line("name"),"info under the name")
Equal(Firsts(Line("guild")),Line("info"),"guild under the info")
Equal(Firsts(Line("zone")),Line("guild"),"zone under the guild")
Near(s.M.divider.points[1][5],-107,"divider under the header")
Equal(s.M.divider.points[2][1],"TOPRIGHT","divider spans the card")
Equal((Grad(s.M.divider)),"HORIZONTAL","divider a violet fade")
Near(Line("away").points[1][5],-119,"time away under the divider")
Equal(Firsts(Line("date")),Line("away"),"date under the time away")
Equal(Line("clock").points[1][1]=="TOPRIGHT"and Line("clock").points[1][5]==-119,true,"clock on the right, level with the time away")
Equal(Firsts(Line("clockLabel")),Line("clock"),"clock label under the clock")
Near(card.h,177,"card fits its lines")
Session(nil,{class="HUNTER",className="Hunter"});Flags(true)
Equal(Colour(Line("name"),{.67,.83,.45}),true,"a hunter's name in hunter green")
Equal(Colour(s.M.accent,{.67,.83,.45}),true,"and the accent too")
Equal(Line("name").font[3],"OUTLINE","pale class colours keep the outline")
Equal(table.concat(s.M.icon.coords,","),"0,0.25,0.25,0.5","the hunter circle")
Session(nil,{noClassCoords=true});Flags(true)
Equal(s.M.icon.shown,false,"no class coordinates: no icon")
Equal(Line("name").points[1][4],20,"and the name moves left")
Near(s.M.divider.points[1][5],-107,"lines alone set the header height")
Session(nil,{missing={[CLASS_ICONS]=true}});Flags(true)
Equal(s.M.icon.shown,false,"missing class circles: no icon")
Session(nil,{class="WARLOCK",className="Warlock"});Flags(true)
Equal(s.M.icon.shown,false,"a class with no circle: no icon")
Equal(Colour(Line("name"),{.7,.7,.7}),true,"and a grey name")
Session(nil,{class=secret,className=secret});Flags(true)
Equal(s.M.icon.shown,false,"a secret class: no icon")
Equal(Line("info").text,"Level 60 Human","a secret class name is dropped")

-- 6. Secondary names, no guild, subzone equal to zone.
Session({hideSecondaryNames=true},{noGuild=true,subzone="Zone"})
Flags(true)
Equal(Line("name").text,"Ann","Hide Secondary Names shows the first name only")
Equal(Line("guild").shown,false,"no guild: guild line hidden")
Equal(Firsts(Line("zone")),Line("info"),"zone moves up under the info")
Equal(Line("zone").text,"Zone","subzone equal to the zone shows the zone once")
Near(s.M.card.h,158,"the card shrinks without the guild")
s.guild="Later";Event("PLAYER_GUILD_UPDATE")
Equal(Line("guild").shown and Line("guild").text,"<Later>","joining a guild refills the card")
Near(s.M.card.h,177,"and it grows again")
Session(nil,{surname=""});Flags(true)
Equal(Line("name").text,"Ann","an empty surname adds no space")
Session(nil,{surname=secret,level=secret});Flags(true)
Equal(Line("name").text,"Ann","a secret surname is dropped")
Equal(Line("info").text,"Human Paladin","a secret level is dropped")

-- 7. Display options, applied live through Refresh.
Session()
Flags(true)
s.E.settings.afkShowGuild=false;s.M:Refresh()
Equal(Line("guild").shown,false,"Show Guild off hides the guild")
s.E.settings.afkShowZone=false;s.M:Refresh()
Equal(Line("zone").shown,false,"Show Zone off hides the zone")
Near(s.M.divider.points[1][5],-72,"the header is the icon's height with name and info only")
s.E.settings.afkShowDate=false;s.M:Refresh()
Equal(Line("date").shown,false,"Show Date off hides the date")
s.E.settings.afk24Hour=true;s.M:Refresh()
Equal(Line("clock").text,"15:07","24-hour clock")
Equal(Active(),true,"changing a display option keeps the screen open")

-- 8. Pure formatters.
local M=s.M
for _,case in ipairs({{0,"00:00"},{59,"00:59"},{61,"01:01"},{3599,"59:59"},{3600,"1:00:00"},{3725,"1:02:05"}})do
 Equal(M.FormatAway(case[1]),case[2],"FormatAway "..case[1])
end
Equal(M.FormatClock(0,5),"12:05 AM","midnight hour")
Equal(M.FormatClock(12,0),"12:00 PM","noon")
Equal(M.FormatClock(15,7,true),"15:07","24-hour afternoon")
Equal(M.FormatClock(9,3,true),"09:03","24-hour padding")
CALENDAR_WEEKDAY_NAMES=nil
Equal(M.FormatDate({wday=3,month=9,day=29}),"Fallback date","date falls back without calendar names")
Equal(s.dateFormats[#s.dateFormats],"%A, %d %B","fallback uses the OS date format")

-- 9. The text is throttled; the glow breathes slowly.
Session()
Flags(true)
local away=Line("away");local count=away.setTextCount
for _=1,20 do s.clock=s.clock+.01;Root().scripts.OnUpdate(Root(),.01)end
Equal(away.setTextCount-count<=1,true,"20 quick frames set the timer text at most once more")
Run(1,.05)
Equal(away.text,"Away for 00:01","timer after one more second")
s.now.hour,s.now.min=9,5;Run(.5,.05)
Equal(Line("clock").text,"9:05 AM","clock follows local time")
do
 local glow,low,high,step=s.M.crest.glow,1,0,0
 for _=1,100 do local a=glow.alpha;Run(.05,.05);low,high=math.min(low,glow.alpha),math.max(high,glow.alpha);step=math.max(step,math.abs(glow.alpha-a))end
 Equal(low<.45 and high>.8,true,"the glow breathes between faint and bright within 5 s")
 Equal(step<.02,true,"and slowly: never more than a small change a frame")
end

-- 10. Camera spin, speed and direction.
Session();Flags(true);Run(10,.05)
Near(s.yawNet,30,"slow circle left: 30 degrees in 10 s",1e-6)
Equal(#s.moves,0,"no MoveView calls while FlipCameraYaw works")
Session({afkCameraNormal=true});Flags(true);Run(10,.05)
Near(s.yawNet,60,"normal speed: 60 degrees in 10 s",1e-6)
Session({afkTurnRight=true});Flags(true);Run(10,.05)
Near(s.yawNet,-30,"circle right turns the other way",1e-6)

-- 11. Yaw returns to where it was.
Session({afkCameraNormal=true});Flags(true);Run(130,.05)
Near(s.yawNet,780,"two circles and a bit",1e-6)
Flags(false)
Near(Wrapped(s.yawNet),0,"leaving restores the camera yaw")
Session({afkCameraNormal=true,afkTurnRight=true});Flags(true);Run(130,.05)
Flags(false)
Near(Wrapped(s.yawNet),0,"leaving restores yaw after circling right")
Session();Flags(true);Run(100,.05);Flags(false)
Near(Wrapped(s.yawNet),0,"leaving restores yaw at 300 degrees")

-- 12. Zoom in, capped, and back out.
Session();Flags(true);Run(30,.05)
Equal(s.zoomNet,6,"zoom stops at exactly 30% of 20")
local calls=s.zoomCalls;Run(5,.05)
Equal(s.zoomCalls,calls,"no zoom calls once the goal is reached")
Flags(false)
Equal(GetCameraZoom(),20,"leaving returns the zoom")
Session(nil,{camStart=40});Flags(true);Run(30,.05)
Equal(s.zoomNet,8,"zoom capped at 8")
Flags(false);Equal(GetCameraZoom(),40,"capped zoom returns")
Session(nil,{camStart=4});Flags(true);Run(5,.05);Flags(false)
Equal(s.zoomCalls,0,"a close camera is not zoomed")
Session({afkZoom=false});Flags(true);Run(5,.05);Flags(false)
Equal(s.zoomCalls,0,"Zoom In off: no zoom")
Session(nil,{without={"GetCameraZoom"}});Flags(true);Run(5,.05);Flags(false)
Equal(s.zoomCalls,0,"no GetCameraZoom: no zoom")
Session(nil,{camSecret=true});Flags(true);Run(5,.05);Flags(false)
Equal(s.zoomCalls,0,"a secret zoom value: no zoom")

-- 13. Fallback spin through MoveView.
Session(nil,{without={"FlipCameraYaw"}});Flags(true)
Equal(s.moves[1][1],"MoveViewLeftStart","fallback spins left through MoveView")
Near(s.moves[1][2],3/180,"speed from the default yaw move speed")
Flags(false)
Equal(s.moves[2][1]=="MoveViewLeftStop"and s.moves[3][1],"MoveViewRightStop","leaving stops both directions")
Session({afkTurnRight=true},{without={"FlipCameraYaw"},cvars={cameraYawMoveSpeed="90"}});Flags(true)
Equal(s.moves[1][1],"MoveViewRightStart","fallback circles right")
Near(s.moves[1][2],3/90,"speed follows cameraYawMoveSpeed")
Session(nil,{without={"FlipCameraYaw","MoveViewLeftStart"}});Flags(true);Run(2,.05);Flags(false)
Equal(#s.moves,0,"no spin API: the screen still works without spinning")

-- 14. Coming back restores the interface.
Session();UIParent.alpha=.8;Flags(true);Run(1,.1)
Near(UIParent.alpha,0,"faded from 0.8")
local sceneActor=s.M.actor
Flags(false)
Equal(UIParent.alpha,.8,"a saved 0.8 stays 0.8")
Equal(Root().shown,false,"screen hidden")
Equal(sceneActor.cleared,2,"the character is cleared (once before loading, once on leaving)")
Equal(s.M.scene.alpha,0,"the scene hides its character")
Equal(s.M.shadow.shown,false,"and the ground shadow")
Equal(s.M.dismissed,false,"back from AFK is not a dismissal")
Flags(true);Equal(Active(),true,"the next AFK enters again")
Equal(#sceneActor.yaws,2,"one turn for each time the screen opens")
Session();UIParent.alpha=.05;Flags(true);Run(1,.1);Flags(false)
Equal(UIParent.alpha,1,"an almost invisible interface comes back at full alpha")
Session();Flags(true);Flags(false);Equal(UIParent.alpha,1,"leaving during the fade restores alpha")

-- 15. Combat closes the screen with nothing protected, and it stays closed.
Session();Flags(true);Run(5,.05)
s.combat=true;Event("PLAYER_REGEN_DISABLED")
Equal(Active(),false,"combat closes the screen")
Equal(UIParent.alpha,1,"interface back in combat")
Near(Wrapped(s.yawNet),0,"camera restored in combat")
Equal(Minimap.shown,true,"minimap back in combat")
Equal(s.M.dismissed,true,"combat counts as a dismissal")
Flags(true)
Equal(Active(),false,"a flag change while still AFK does not reopen")
s.combat=false;Event("PLAYER_REGEN_ENABLED");Flush()
Equal(Active(),false,"the end of combat does not reopen a dismissed screen")
Flags(false);Flags(true)
Equal(Active(),true,"a fresh AFK after combat enters")
s.combat=true;Root().scripts.OnKeyDown(Root(),"W")
Equal(Active(),false,"a key in combat leaves without touching propagation")
s.combat=false

-- 16. Addon restrictions leave before lockdown.
Session();Flags(true)
Restrict(4,1)
Equal(Active(),true,"a Map restriction does not leave")
Restrict(0,0);Flush()
Equal(Active(),true,"an inactive combat restriction does not leave")
Restrict(0,1)
Equal(Active(),false,"an activating combat restriction leaves")
Flags(false);Flags(true);Restrict(secret,1)
Equal(Active(),true,"a secret restriction type is ignored")
Restrict(5,2)
Equal(Active(),false,"a chat restriction leaves")

-- 16b. When a restriction ends, a flag change hidden by it is read again.
Session();Flags(true)
s.restricted=1;Restrict(1,1)
Equal(Active(),false,"an encounter pull closes the screen")
s.afk=secret;Event("PLAYER_FLAGS_CHANGED","player") -- moved: the flag cleared, but reads secret
Equal(s.M.wasAFK,true,"a secret clear is not seen yet")
s.afk=false;s.restricted=nil;Restrict(1,0)
Equal(s.M.wasAFK,true,"nothing is read while the change is dispatched")
Flush()
Equal(s.M.wasAFK,false,"the end of the restriction reads the cleared flag")
Flags(true)
Equal(Active(),true,"the next AFK after the fight enters")
Session();Flags(true);s.restricted=1;Restrict(1,1);s.restricted=nil;Restrict(1,0);Flush()
Equal(Active(),false,"still AFK after the fight: a closed screen stays closed")
Session();Flags(true);Restrict(5,1);s.afk=secret;Restrict(5,0);Flush()
Equal(s.M.wasAFK==true and not Active(),true,"a flag still secret after the restriction changes nothing")
-- An AFK a restriction blocked opens when it ends, but not while another holds.
Session();s.restricted=1;Flags(true)
Equal(Active(),false,"no screen during an encounter")
Equal(s.M.pending,true,"waits for the encounter to end")
s.restricted=nil;Restrict(1,0)
Equal(Active(),false,"waits a moment after the encounter")
Flush()
Equal(Active(),true,"opens when the encounter ends")
Session();s.restricted=2;Flags(true);Restrict(1,0);Flush()
Equal(Active(),false,"another restriction still active: stays closed")
Equal(s.M.pending,true,"and keeps waiting")
s.restricted=nil;Restrict(2,0);Flush()
Equal(Active(),true,"then opens when that one ends")
Session();s.restricted=1;Flags(true);Flags(false);s.restricted=nil;Restrict(1,0);Flush()
Equal(Active(),false,"no longer AFK when the encounter ends: stays closed")
Session();s.restricted=1;Flags(true);s.restricted=nil;Restrict(1,0);s.combat=true;Flush()
Equal(Active(),false,"combat when the encounter ends: stays closed")
s.combat=false;Event("PLAYER_REGEN_ENABLED");Flush()
Equal(Active(),true,"and opens after combat")

-- 17. AFK set during combat opens after combat.
Session();s.combat=true;Flags(true)
Equal(Active(),false,"no screen in combat")
Equal(s.M.pending,true,"waits for combat to end")
Equal(Root(),nil,"nothing built in combat")
s.combat=false;Event("PLAYER_REGEN_ENABLED")
Equal(Active(),false,"waits a moment after combat")
Flush()
Equal(Active(),true,"opens after combat")
Session();s.combat=true;Flags(true);s.combat=false;Event("PLAYER_REGEN_ENABLED");s.afk=false;Flush()
Equal(Active(),false,"no longer AFK after combat: stays closed")
Session();s.combat=true;Flags(true);s.combat=false;Event("PLAYER_REGEN_ENABLED");s.combat=true;Flush()
Equal(Active(),false,"combat again before the timer: stays closed")
Equal(s.M.pending,true,"and keeps waiting")
s.combat=false;Event("PLAYER_REGEN_ENABLED");Flush()
Equal(Active(),true,"then opens after that fight")
Session();s.combat=true;Flags(true);Flags(false)
Equal(s.M.pending,false,"clearing AFK in combat drops the wait")

-- 18. Keys and the mouse.
Session();Flags(true)
for _,key in ipairs({"LALT","RSHIFT","LCTRL","PRINTSCREEN","F12"})do
 Root().scripts.OnKeyDown(Root(),key)
 Equal(Active(),true,key.." keeps the screen open")
end
Equal(Root().propagate,true,"modifiers and screenshots still propagate")
Root().scripts.OnKeyDown(Root(),"W")
Equal(Active(),false,"W leaves")
Equal(Root().propagate,true,"W still walks")
Equal(s.M.dismissed,true,"a key is a dismissal")
Flags(true);Equal(Active(),false,"a dismissed screen does not pop back while AFK")
Flags(false);Flags(true)
Root().scripts.OnKeyDown(Root(),"ESCAPE")
Equal(Root().propagate,false,"Escape is swallowed so the Game Menu stays shut")
Equal(Active(),false,"Escape leaves")
Flags(false);Flags(true)
Equal(Root().propagate,true,"propagation back on at the next entry")
-- Only movement and chat keys keep their binding; nothing else may cast or open.
for _,case in ipairs({{"SPACE",true,"Jump"},{"ENTER",true,"Open Chat"},{"1",false,"an action button key"},
 {"X",false,"a secret binding"},{"K",false,"an unbound key"}})do
 Flags(false);Flags(true)
 Root().scripts.OnKeyDown(Root(),case[1])
 Equal(Active(),false,case[3].." leaves")
 Equal(Root().propagate,case[2],case[3]..(case[2]and " keeps its binding"or " is swallowed"))
end
Flags(false);Flags(true)
Root().scripts.OnMouseDown(Root(),"LeftButton")
Equal(Active(),false,"a click leaves")
Flags(false);Flags(true)
Root().scripts.OnMouseWheel(Root(),1)
Equal(Active(),false,"the mouse wheel leaves")
Equal(s.zoomNet,0,"and never changes the tracked zoom")
Session(nil,{without={"GetBindingFromClick"}});Flags(true)
Root().scripts.OnKeyDown(Root(),"W")
Equal(Active()==false and Root().propagate,false,"no binding lookup: a key leaves and is swallowed")

-- 19. Every exit event, popups and battleground invites leave.
Session()
for _,e in ipairs(EXIT)do
 Flags(false);Flags(true)
 Equal(Active(),true,"entered before "..e)
 Event(e)
 Equal(Active(),false,e.." leaves")
end
Flags(false);Flags(true);StaticPopup_Show("PARTY_INVITE")
Equal(Active(),false,"any StaticPopup leaves")
Flags(false);Flags(true);Event("UPDATE_BATTLEFIELD_STATUS",1)
Equal(Active(),true,"a battlefield update without an invite stays")
s.bg[2]="confirm";Event("UPDATE_BATTLEFIELD_STATUS",2)
Equal(Active(),false,"a battleground invite leaves")
s.bg[2]=nil
Flags(false);Flags(true);Event("ZONE_CHANGED");Event("UNIT_PORTRAIT_UPDATE","player");Event("UI_SCALE_CHANGED")
Equal(Active(),true,"info, portrait and scale updates keep the screen open")

-- 20. Secret AFK values never enter or error.
Session();s.afk=secret;Event("PLAYER_FLAGS_CHANGED","player")
Equal(Active(),false,"a secret flag does not enter")
Equal(s.M.ReadAFK(),nil,"a secret flag reads as unknown")
Flags(true);s.afk=secret;Event("PLAYER_FLAGS_CHANGED","player")
Equal(Active(),true,"a secret flag while away changes nothing")
s.afkError=true;Event("PLAYER_FLAGS_CHANGED","player")
Equal(Active(),true,"an erroring flag read changes nothing")
Session(nil,{noUnitEvents=true})
Equal(s.events.events.PLAYER_FLAGS_CHANGED,true,"without unit events the flag event is plain")
s.afk=true;Event("PLAYER_FLAGS_CHANGED","target")
Equal(Active(),false,"another unit's flags are ignored")
Event("PLAYER_FLAGS_CHANGED",secret)
Equal(Active(),false,"a secret unit is ignored")
Event("PLAYER_FLAGS_CHANGED","player")
Equal(Active(),true,"the player's flags enter")

-- 21. Guards: no entry and UIParent untouched.
for _,case in ipairs({
 {"dead",nil,{dead=true}},{"on a taxi",nil,{taxi=true}},{"in a cinematic",nil,{cinematic=true}},
 {"typing",nil,{focus={}}},{"an encounter restriction",nil,{restricted=1}},{"a combat restriction",nil,{restricted=0}},
 {"the trainer open",nil,{trainer={IsShown=function()return true end}}},{"Edit Mode open",nil,{editMode=true}},
 {"no SetIgnoreParentAlpha",nil,{noIgnoreAlpha=true}},{"EraUI disabled",{enabled=false}},
})do
 Session(case[2],case[3]);Flags(true)
 Equal(Active(),false,"no entry when "..case[1])
 Equal(UIParent.alpha,1,"UIParent alpha untouched when "..case[1])
 Equal(Minimap.shown and s.mapHides,0,"minimap untouched when "..case[1])
end
Equal(s.M.unsupported,nil,"a disabled EraUI is not marked unsupported")
Session(nil,{editMode="secret"});secretReads=0;Flags(true)
Equal(Active(),false,"an unreadable Edit Mode answer counts as open")
Equal(secretReads>0,true,"a secret Edit Mode answer is recognised, never tested as a boolean")
Session(nil,{editMode="error"});Flags(true)
Equal(Active(),true,"a failing Edit Mode read does not stop the screen")
Session(nil,{noIgnoreAlpha=true});Flags(true)
Equal(s.M.unsupported,true,"a client without SetIgnoreParentAlpha is marked unsupported")
Equal(Root(),nil,"and nothing is built")
Session();UIParent.shown=false;Flags(true)
Equal(Active(),false,"no entry with the interface hidden (Alt+Z)")

-- 22. Reload or login while AFK needs a fresh AFK.
Session(nil,{afk=true})
Event("PLAYER_ENTERING_WORLD",false,true)
Equal(Active(),false,"a reload while AFK does not pop up")
Flags(true)
Equal(Active(),false,"a later DND or PvP flag change does not pop up")
Flags(false);Flags(true)
Equal(Active(),true,"a fresh AFK enters")
Session(nil,{afk=true})
Event("PLAYER_ENTERING_WORLD",false,true)
s.M:Preview();s.combat=true;Flush()
Equal(s.M.pending,true,"a preview cut off by combat waits")
s.combat=false;Event("PLAYER_REGEN_ENABLED");Flush()
Equal(Active(),false,"and never opens for an AFK that began before the reload")
Session()
Event("PLAYER_ENTERING_WORLD",true,false)
Equal(s.moves[1]and s.moves[1][1],"MoveViewLeftStop","login stops a leftover left spin")
Equal(s.moves[2]and s.moves[2][1],"MoveViewRightStop","and a right spin")
Flags(true);Event("PLAYER_ENTERING_WORLD",false,false)
Equal(Active(),false,"a loading screen leaves")
Equal(#s.moves,2,"a zone change does not stop view moves")
Session({afkScreen=false},{afk=true})
s.E.settings.afkScreen=true;s.M:Refresh()
Equal(Active(),false,"turning the option on while AFK does not pop up")
Flags(false);Flags(true)
Equal(Active(),true,"the next AFK does")

-- 23. Turning the option off while active.
Session();UIParent.alpha=.9;Flags(true);Run(2,.1)
Equal(Minimap.shown,false,"minimap hidden while away")
s.E.settings.afkScreen=false;s.M:Refresh()
Equal(Active(),false,"turning off leaves")
Equal(UIParent.alpha,.9,"and restores alpha")
Equal(next(s.events.events),nil,"and unregisters every event")
Near(Wrapped(s.yawNet),0,"and restores the camera")
Equal(Minimap.shown,true,"and the minimap")

-- 24. Leaving the world and logging out restore the camera and the minimap.
for _,e in ipairs({"PLAYER_LEAVING_WORLD","PLAYER_LOGOUT"})do
 Session();Flags(true);Run(20,.05)
 Equal(s.zoomNet>0 and Wrapped(s.yawNet)>0 and not Minimap.shown,true,"camera moved and minimap hidden before "..e)
 Event(e)
 Near(Wrapped(s.yawNet),0,e.." restores yaw")
 Near(s.zoomNet,0,e.." restores zoom")
 Equal(Minimap.shown,true,e.." shows the minimap")
end

-- 25. The character: a ModelScene actor, steady, framed from its real bounds.
Session();Flags(true)
local scene,actor=s.M.scene,s.M.actor
Equal(scene.kind,"ModelScene","a ModelScene")
Equal(scene.template,nil,"a plain scene: no Blizzard mixin with mouse scripts")
Equal(scene.level,2,"character under the crest and the card")
Equal(actor.template,nil,"a plain actor when the client allows it")
Equal(s.M.model.shown,false,"the PlayerModel waits unused")
Equal(Join(s.actorUnit,5),"player,true,true,false,true","the player, weapons sheathed, dressed, native form")
Equal(Join(actor.calls.SetUseCenterForOrigin,3),"true,true,false","centred across, feet at the origin")
Equal(#actor.yaws,1,"one turn when it opens")
Near(actor.yaws[1],.6,"a 3/4 turn toward the screen centre")
Equal(actor.calls.SetAnimation[1],0,"standing")
Equal(scene.alpha,0,"hidden until framed, so it never jumps")
Equal(scene.setFov,.6,"its own field of view")
Equal(scene.lights.SetLightVisible[1],true,"a light is on")
Equal(scene.lights.SetLightType[1],0,"a directional light")
do local d=scene.lights.SetLightDirection;Near(d[1]^2+d[2]^2+d[3]^2,1,"light direction normalised",1e-9)
 Equal(d[1]<0 and d[3]<0,true,"light from the camera side, from above")end
Equal(scene.lights.SetLightAmbientColor[1]>.5,true,"ambient light so it is never dark")
Run(.05,.05)
Equal(s.M.framed,true,"framed on the first frame once loaded")
Equal(scene.alpha,1,"then shown")
Equal(scene.points[1][1]=="BOTTOMLEFT"and scene.points[1][2]==Root(),true,"the character stands on the left")
Near(scene.points[1][4],1920*.03,"in from the left edge")
do
 local _,feet=Projected(0);local _,head=Projected(2.2)
 Near(head-feet,1080*.63,"the character fills 63% of the screen height",1080*.63*.01)
 Near(feet,1080*.05,"feet near the bottom",.5)
 local sh=s.M.shadow;local p=sh.points[1]
 Equal(sh.shown and p[1]=="CENTER"and p[2]==scene and p[3]=="BOTTOMLEFT",true,"ground shadow at the feet")
 local fx=Projected(0)
 Near(p[4],fx,"shadow under the feet across",1e-6);Near(p[5],feet,"shadow at the feet height",1e-6)
 Equal(sh.texture,MEDIA.."LogoGlow.tga","a soft round shadow")
 Equal(sh.colour[1]==0 and sh.colour[2]==0 and sh.colour[3]==0,true,"black")
 Equal(sh.w>sh.h*3,true,"flattened on the ground")
 Near(sh.w,1080*.63*.32,"a small shadow: about a third of the character's height wide")
 Near(sh.h,1080*.63*.06,"and thin")
 Equal(sh.colour[4],.55,"soft: .55 alpha")
 Equal(sh.layer=="BORDER"and sh.parent==Root(),true,"drawn under the character")
end
-- Steady: the world camera circles, the character and its camera never move.
local camCalls,yaws=scene.camCalls,#actor.yaws
Run(10,.05)
Equal(s.flips>100,true,"the world camera keeps circling")
Equal(#actor.yaws,yaws,"the character is never turned again")
Equal(scene.camCalls,camCalls,"its camera is never touched again")
Equal(#s.M.model.rotations,0,"the PlayerModel is never turned")
-- A new screen size frames it again.
UIParent.h=900;Event("DISPLAY_SIZE_CHANGED");Run(.05,.05)
do local _,feet=Projected(0);local _,head=Projected(2.2)
 Near(head-feet,900*.63,"a new screen size frames it again",900*.63*.01);Near(feet,900*.05,"feet follow",.5)end
Equal(#actor.yaws,yaws,"still no new turn")
-- A new size gets the full wait again, even when the first framing took most of it.
Session(nil,{loadDelay=2.5});Flags(true);Run(2.6,.05)
Equal(s.M.framed==true and s.M.modelPath=="scene",true,"a slow first load is framed in time")
s.projectNothing=true;UIParent.h=900;Event("DISPLAY_SIZE_CHANGED");Run(.6,.05)
Equal(s.M.framed==false and s.M.modelPath=="scene",true,"a new size waits for the scene again")
s.projectNothing=nil;Run(.2,.05)
Equal(s.M.modelPath=="scene"and s.M.framed==true and s.M.sceneSlow==nil,true,"and frames it without falling back to the PlayerModel")
Equal(s.M.model.shown,false,"the PlayerModel stays unused")
-- The first guess uses the reported field of view; one correction fixes a wrong one.
Session(nil,{reportFov=.6,realFov=1.1});Flags(true);Run(.05,.05)
do local _,feet=Projected(0);local _,head=Projected(2.2)
 Near(head-feet,1080*.63,"a wrong field of view is corrected",1080*.63*.01)end
Session(nil,{reportFov=secret});Flags(true);Run(.05,.05)
Equal(s.M.framed and s.M.modelPath,"scene","a secret field of view falls back to our own")
-- Bounds as two vectors, a scaled actor, a model that loads late.
Session(nil,{boundsVectors=true});Flags(true);Run(.05,.05)
Equal(s.M.modelPath=="scene"and s.M.framed,true,"bounds as two vectors frame too")
Session(nil,{actorScale=1.5});Flags(true);Run(.05,.05)
do local _,feet=Projected(0);local _,head=Projected(2.2*1.5)
 Near(head-feet,1080*.63,"the actor's scale is counted",1080*.63*.01)end
Session(nil,{loadDelay=.5});Flags(true);Run(.3,.05)
Equal(s.M.framed==false and s.M.scene.alpha==0 and not s.M.shadow.shown,true,"still loading: nothing shows")
Run(.4,.05)
Equal(s.M.framed==true and s.M.scene.alpha==1 and s.M.modelPath=="scene",true,"shown once loaded")
-- A wide model is fitted to the scene's width.
Session(nil,{bounds={-1.6,-1.2,0,1.6,1.2,2.2}});Flags(true);Run(.05,.05)
do
 local sc=s.M.scene;local r=math.sqrt(1.6^2+1.2^2)
 local left=sc:Project3DPointTo2D(0,-r,0);local right=sc:Project3DPointTo2D(0,r,0)
 Equal(left>=0 and right<=sc.w*s.es,true,"a wide model stays inside the scene")
 local _,feet=Projected(0);local _,head=Projected(2.2)
 Equal(head-feet<1080*.63,true,"by standing a little smaller")
 Near(feet,1080*.05,"feet still near the bottom",.5)
end
-- CreateActor with a template when the client needs one.
Session(nil,{actorNeedsTemplate=true});Flags(true);Run(.05,.05)
Equal(s.M.actor.template,"ModelSceneActorTemplate","falls back to Blizzard's actor template")
Equal(s.M.modelPath=="scene"and s.M.framed,true,"and frames it")

-- 25b. The PlayerModel stands in when the scene can't be trusted, and never spins.
local function Fallback(label)
 Equal(s.M.modelPath,"model",label..": the PlayerModel stands in")
 local m=s.M.model
 Equal(m.shown,true,label..": the PlayerModel shows")
 Equal(s.setUnit[#s.setUnit],"player",label..": for the player")
 Equal(#s.setUnit,1,label..": given its unit once")
 Equal(s.setUnitVisible[#s.setUnitVisible],true,label..": given its unit while it and the screen show, so it never stays blank")
 Equal(#m.rotations,1,label..": turned once")
 Equal(m.rotations[1][1]==.6 and m.rotations[1][2],false,label..": to the same 3/4 angle, without the turn animation")
 Equal(m.camScale,.8,label..": its camera a little closer")
 Equal(s.M.scene==nil or s.M.scene.alpha==0,true,label..": the scene stays hidden")
 local p=s.M.shadow.points[1]
 Equal(s.M.shadow.shown and p[1]=="CENTER"and p[2]==m and p[3]=="BOTTOM",true,label..": shadow at its feet")
 Near(p[5],m.h*.1,label..": at the estimated feet")
 Near(s.M.shadow.w,1080*.63*.32,label..": a small shadow, about a third of the character's height wide")
 Near(s.M.shadow.h,1080*.63*.06,label..": and thin")
 Equal(s.M.shadow.colour[4],.55,label..": soft, .55 alpha")
 Run(10,.05)
 Equal(#m.rotations,1,label..": never turned again")
end
Session(nil,{noModelScene=true});Flags(true)
Equal(s.M.scene,nil,"no ModelScene on this client")
Fallback("no ModelScene")
Near(s.M.model.h,1080*.63/.775,"the PlayerModel sized so the character fills about 63%")
Near(s.M.model.points[1][5],1080*.05-s.M.model.h*.1,"its feet near the bottom")
Session(nil,{noActor=true});Flags(true)
Equal(s.M.scene,nil,"no actor: the scene is not used")
Fallback("no actor")
Session(nil,{noProject=true});Flags(true)
Fallback("no projection")
Session(nil,{actorSetFail=true});Flags(true)
Fallback("SetModelByUnit fails")
for _,case in ipairs({{"never loads",{neverLoads=true}},{"secret bounds",{boundsSecret=true}},{"no projection yet",{projectNothing=true}}})do
 Session(nil,case[2]);Flags(true);Run(2.9,.05)
 Equal(s.M.modelPath=="scene"and s.M.model.shown==false,true,case[1]..": waits for the scene first")
 Run(.2,.05)
 Fallback(case[1])
 Flags(false);Flags(true)
 Equal(s.M.modelPath=="model"and s.M.model.shown,true,case[1]..": the next AFK uses the PlayerModel at once")
end
Session(nil,{projectNormalized=true});Flags(true);Run(.05,.05);Flags(false);s.projectNormalized=nil;Flags(true);Run(.05,.05)
Equal(s.M.modelPath=="scene"and s.M.framed,true,"a quick failure is tried again at the next AFK")
for _,case in ipairs({{"projection in unknown units",{projectNormalized=true}},{"projection upside down",{projectFlipped=true}},
 {"projection from the screen's corner",{projectOffset=60}},{"secret scale",{esSecret=true}}})do
 Session(nil,case[2]);Flags(true);Run(.05,.05)
 Fallback(case[1])
end
Session(nil,{noModelScene=true,setUnitResult=false});Flags(true)
Equal(s.M.model.shown or s.M.shadow.shown,false,"no model at all: model and shadow hidden")
Equal(Active(),true,"the screen still opens")
Session(nil,{noModelScene=true,setUnitError=true});Flags(true)
Equal(s.M.model.shown,false,"a model error hides the model")
Session(nil,{noModelScene=true});Flags(true);Flags(false)
Equal(s.M.model.cleared,1,"leaving clears the PlayerModel")
Equal(s.M.model.shown or s.M.shadow.shown,false,"and hides it")
Flags(true);Equal(#s.M.model.rotations,2,"one turn for each time the screen opens")
UIParent.h=900;Event("DISPLAY_SIZE_CHANGED")
Near(s.M.shadow.points[1][5],900*.63/.775*.1,"a new screen size moves the fallback shadow too")
Near(s.M.shadow.w,900*.63*.32,"and resizes it");Near(s.M.shadow.h,900*.63*.06,"thin as before")

-- 25c. The class quote: a famous Classic line for your class above the hint,
-- like a loading-screen tip, from Modules/AFKQuotes.lua.
local QUOTE_FONT=MEDIA.."Fonts\\IMFellEnglish-Italic.ttf"
local OPEN,CLOSE,DASH="\226\128\156","\226\128\157","\226\128\148 "
local QUOTES do local E0={};assert(loadfile("Modules/AFKQuotes.lua"))("EraUI",E0);QUOTES=E0.AFKQuotes end
local CLASSES={"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","SHAMAN","MAGE","WARLOCK","DRUID"}
local function Said()local t=s.M.quoteText.text;return t and t:sub(#OPEN+1,-#CLOSE-1)end
local function Find(text)for key,list in pairs(QUOTES)do for _,q in ipairs(list)do if q.text==text then return q,key end end end end
-- The data: nine classes and General, every line short, plain and tagged right.
do
 local keys,total=0,0
 for key,list in pairs(QUOTES)do
  keys=keys+1
  local known=key=="GENERAL";for _,c in ipairs(CLASSES)do if c==key then known=true end end
  Equal(known,true,"quote key "..tostring(key).." is a class token or GENERAL")
  Equal(#list>=(key=="GENERAL"and 3 or 5),true,key.." has enough lines ("..#list..")")
  local seen={}
  for i,q in ipairs(list)do
   total=total+1
   local label=key.." line "..i
   for k in pairs(q)do Equal(k=="text"or k=="speaker"or k=="where",true,label..": only text, speaker and where, no faction lock ("..tostring(k)..")")end
   Equal(type(q.text)=="string"and #q.text>0,true,label..": has its words")
   local words=0;for _ in q.text:gmatch("%S+")do words=words+1 end
   Equal(words<=14,true,label..": at most 14 words ("..words..")")
   Equal(q.text:find("\226\128\148",1,true),nil,label..": no em dash inside the text")
   Equal(q.text:sub(1,1)~='"'and q.text:sub(-1)~='"'and q.text:find(OPEN,1,true)==nil and q.text:find(CLOSE,1,true)==nil,true,label..": no quote marks of its own")
   Equal(type(q.speaker)=="string"and #q.speaker>0 and type(q.where)=="string"and #q.where>0,true,label..": speaker and where set")
   Equal((q.text..q.speaker..q.where):find("[^\32-\126]"),nil,label..": plain characters every font can draw")
   Equal(seen[q.text],nil,label..": no repeat within "..key);seen[q.text]=true
  end
 end
 Equal(keys,10,"nine classes and General");Equal(total,71,"all 71 lines of the approved shortlist")
 -- A few lines word for word, and where each one goes.
 local q,key=Find("You no take candle!");Equal(key=="GENERAL"and q.speaker=="Kobolds"and q.where=="Elwynn Forest",true,"the kobolds, in General")
 q,key=Find("A huge gnoll, Hogger, is prowling the woods in southwestern Elwynn.")
 Equal(key=="GENERAL"and q.where=='Quest: Wanted: "Hogger"',true,"Hogger's wanted poster, in General")
 q,key=Find("Be bathed in my power! Drink in my might!");Equal(key=="SHAMAN"and q.speaker,"Thrall","Thrall, for shamans")
 q,key=Find("Ah - I've been waiting for a real challenge!");Equal(key=="WARRIOR"and q.speaker,"Herod","Herod's line exactly as in the shortlist")
end
-- Word for word as the user approved them: text, speaker and place, in order,
-- for every class (Tools/AFKQuotesApproved.lua, frozen from the approved shortlist).
do
 local approved,listed=assert(loadfile("Tools/AFKQuotesApproved.lua"))(),{}
 Equal(#approved,10,"the approved shortlist: nine classes and General")
 for _,entry in ipairs(approved)do
  local key,lines=entry[1],entry[2];listed[key]=true
  local list=QUOTES[key]or{}
  Equal(#list,#lines,key..": the approved number of lines")
  for i,a in ipairs(lines)do
   local q=list[i]or{}
   Equal(q.text,a[1],key.." line "..i..": the approved words")
   Equal(q.speaker,a[2],key.." line "..i..": the approved speaker")
   Equal(q.where,a[3],key.." line "..i..": the approved place")
  end
 end
 for key in pairs(QUOTES)do Equal(listed[key],true,key..": in the approved shortlist")end
end
-- How it looks: italic parchment above the hint, the speaker muted under it.
Session();Flags(true)
local box,qt,qb=s.M.quoteBox,s.M.quoteText,s.M.quoteBy
Equal(box.shown and box.alpha,1,"a quote shows as the screen opens")
Equal(box.parent,s.M.hint.parent,"on the front layer with the hint, above the character and the card")
Equal(box.allPoints,s.M.hint.parent,"its own frame, sized at creation, so it can fade")
do local q,key=Find(Said())
 Equal(key,"PALADIN","a paladin gets a paladin line")
 Equal(qt.text,OPEN..q.text..CLOSE,"in curly quote marks")
 Equal(qb.text,DASH..q.speaker..", "..q.where,"who said it and where, after a dash")end
Equal(qt.font[1]==QUOTE_FONT and qt.font[3],"OUTLINE","in the bundled IM Fell English italic, outlined")
Equal(qt.font[2],28,"about 20 at 768 tall, so 28 at 1080")
Equal(Colour(qt,{.93,.89,.78}),true,"warm parchment")
Equal(qt.justify,"CENTER","centred")
Equal(qt.wrap==true and qt.maxLines,2,"wraps, to two lines at most")
Equal(Colour(qb,MUTED)and qb.font[1]~=QUOTE_FONT and qb.font[2],15,"the speaker line smaller and muted, in the normal font")
Equal(qb.justify=="CENTER"and qb.wrap,false,"on one centred line")
do local p=qb.points[1];Equal(p[1]=="BOTTOM"and p[2]==s.M.hint and p[3]=="TOP"and p[4]==0 and p[5]==10,true,"the speaker line just above the hint")end
do local p=qt.points[1];Equal(p[1]=="BOTTOM"and p[2]==qb and p[3]=="TOP"and p[4]==0 and p[5]==4,true,"the quote above the speaker line")end
Near(qt.w,720,"45% of the screen, capped at 720");Equal(qb.w,qt.w,"the speaker line as wide")
-- Never over the character or the card: checked against the framed character's
-- shadow and the card on common screens, and hidden where there is no room.
-- Each case: width, height, quote size, speaker line size. 2560x1440 would give
-- 38 by height and 32 by width: the cap of 28 decides; the speaker line stops at 15.
for _,case in ipairs({{1920,1080,28,15},{1365,768,20,11},{1229,768,16,11},{1600,900,23,13},{2560,1080,28,15},{2560,1440,28,15}})do
 Session();UIParent.w,UIParent.h=case[1],case[2];Flags(true);Run(.05,.05)
 local label=case[1].."x"..case[2]
 local w,qw,size=UIParent.w,s.M.quoteText.w,s.M.quoteText.font[2]
 Equal(s.M.quoteBy.font[2],case[4],label..": the speaker line sized "..case[4])
 local l,r=w/2-qw/2,w/2+qw/2
 local cardLeft=w+s.M.card.points[1][4]-s.M.card.w
 local sc,sp=s.M.scene,s.M.shadow.points[1]
 Equal(s.M.framed and sp[2]==sc,true,label..": the character framed")
 local charRight=sc.points[1][4]+sp[4]+s.M.shadow.w/2
 Equal(s.M.quoteBox.shown,true,label..": the quote shows")
 Equal(size,case[3],label..": sized "..case[3])
 Equal(r<=cardLeft-16+1e-6,true,label..": clear of the card")
 Equal(l>=charRight+16-1e-6,true,label..": clear of the character and its shadow")
 Equal(qw<=w*.45+1e-6 and qw<=720+1e-6,true,label..": within 45% of the screen and 720")
 Equal(qw>=size*22,true,label..": at least 22 of its size wide a line, so the longest quote takes two lines")
end
-- 3:2 at 768 tall: room for size 13 only, under the readable 14, so no quote.
Session();UIParent.w,UIParent.h=1152,768;Flags(true)
Equal(s.M.quoteSize,13,"1152x768: the room left gives 13")
Equal(s.M.quoteBox.shown or s.M.quoteOn,false,"1152x768: under 14 is too small to read, so no quote")
Session();UIParent.w,UIParent.h=1024,768;Flags(true)
Equal(s.M.quoteBox.shown,false,"4:3: no room beside the card, so no quote")
Equal(s.M.quoteText.text,nil,"and no line picked")
Equal(Active(),true,"the screen still opens")
UIParent.w,UIParent.h=1920,1080;Event("DISPLAY_SIZE_CHANGED")
Equal(s.M.quoteBox.shown and Said()~=nil,true,"a wider screen brings the quote")
UIParent.w,UIParent.h=1024,768;Event("DISPLAY_SIZE_CHANGED")
Equal(s.M.quoteBox.shown or s.M.quoteOn,false,"a narrower one hides it again")
-- A new line every 40 seconds, fading out and back in; nothing is written in between.
Session();Flags(true)
do
 local first,sets,alphas=Said(),s.M.quoteText.setTextCount,s.M.quoteBox.alphaCalls or 0
 Run(38,.05)
 Equal(Said(),first,"the same line for most of 40 seconds")
 Equal(s.M.quoteBox.alpha,1,"fully shown")
 Equal((s.M.quoteBox.alphaCalls or 0)-alphas,0,"no alpha writes while it holds")
 Equal(s.M.quoteText.setTextCount,sets,"and no text writes")
 Run(.8,.05)
 Equal(Said(),first,"fading out, still the same line")
 Near(s.M.quoteBox.alpha,.5,"half faded out",.07)
 Run(.6,.05)
 local second=Said()
 Equal(second~=nil and second~=first,true,"a new line after 40 seconds")
 Equal(s.M.quoteBox.alpha<.5,true,"fading back in")
 Equal(s.M.quoteText.setTextCount,sets+1,"its text set once")
 Run(1,.05)
 Equal(s.M.quoteBox.alpha,1,"fully back")
 Run(40,.05)
 Equal(Said()~=second,true,"and another 40 seconds later")
 Equal(s.M.quoteText.setTextCount,sets+2,"one text write per change")
 Flags(false);Equal(s.M.quoteOn,false,"leaving stops the quotes")
end
-- Leaving mid-fade: the next AFK's line starts fully shown, not half faded.
Session();Flags(true);Run(39.6,.05)
Equal(s.M.quoteBox.alpha<.9,true,"left while the line was fading")
Flags(false);Flags(true)
Equal(s.M.quoteBox.alpha,1,"the next AFK shows its line fully")
Run(1,.05);Equal(s.M.quoteBox.alpha,1,"and it stays fully shown")
-- Random, but never the same line twice in a row, even across AFKs.
Session(nil,{rolls={3,3,1}});Flags(true)
Equal(Said(),QUOTES.PALADIN[3].text,"the first line picked at random from the pool")
s.M:NextQuote()
Equal(Said(),QUOTES.PALADIN[4].text,"a roll landing on the line just shown moves past it")
s.M:NextQuote()
Equal(Said(),QUOTES.PALADIN[1].text,"other rolls land where they fall")
Session(nil,{rolls={2,2}});Flags(true);Flags(false);Flags(true)
Equal(Said(),QUOTES.PALADIN[3].text,"a new line each time the screen opens, never the one just shown")
Session(nil,{class="HUNTER",className="Hunter"});Flags(true)
do local prev,calls=Said(),s.randCalls
 for i=1,60 do s.M:NextQuote();local now=Said();Equal(now~=prev,true,"never the same line twice in a row ("..i..")");prev=now end
 Equal(s.randCalls-calls,60,"one roll per new line")end
-- The pool: your class's lines whatever your faction (the user: "Everyone can see em, not
-- locked to faction"), General lines when fewer than three.
local function Expected(class)
 local set,n={},0
 local function Add(list)for _,q in ipairs(list or{})do set[q.text]=true;n=n+1 end end
 Add(class and QUOTES[class]);if n<3 then Add(QUOTES.GENERAL)end
 return set,n
end
local function Seen(times)
 local set,n={},0
 local function Note()local t=Said();if t and not set[t]then set[t]=true;n=n+1 end end
 Note();for _=1,times do s.M:NextQuote();Note()end
 return set,n
end
local function Same(a,b)for k in pairs(a)do if not b[k]then return false end end;for k in pairs(b)do if not a[k]then return false end end;return true end
for _,class in ipairs(CLASSES)do
 for _,faction in ipairs({"Alliance","Horde","secret"})do
  Session(nil,{class=class,className=class,faction=faction=="secret"and secret or faction});Flags(true)
  local want,n=Expected(class)
  local got,m=Seen(n*8)
  Equal(m,n,class.." "..faction..": "..n.." lines in the pool")
  Equal(Same(want,got),true,class.." "..faction..": every "..class.." line, for either faction")
  Equal(s.factionCalls,nil,class.." "..faction..": the faction is never read")
 end
end
do
 local UZZEK,BARTLEBY,THRALL="We are the shield of the Horde, and we keep our weaker brethren safe.","You're a lot tougher than you look!","Be bathed in my power! Drink in my might!"
 local HOGGER="A huge gnoll, Hogger, is prowling the woods in southwestern Elwynn."
 for _,faction in ipairs({"Horde","Alliance"})do
  Session(nil,{class="WARRIOR",className="Warrior",faction=faction});Flags(true)
  local got,n=Seen(60)
  Equal(n==7 and got[UZZEK]==true and got[BARTLEBY]==true,true,"a "..faction.." warrior hears both Uzzek and Bartleby")
 end
 Session(nil,{class="SHAMAN",className="Shaman",faction="Alliance"});Flags(true)
 local got,n=Seen(80)
 Equal(n==7 and got[THRALL]==true and got["You no take candle!"]==nil,true,"an Alliance shaman: all seven shaman lines, Thrall too, no General needed")
 for _,case in ipairs({{"an erroring faction",{factionError=true}},{"no faction API",{noFactionAPI=true}},{"a neutral faction",{faction="Neutral"}}})do
  Session(nil,case[2]);Flags(true);got,n=Seen(60)
  Equal(n==7 and got["At long last, your time has come!"]==true,true,case[1]..": every line still shows")
 end
 Session(nil,{class=secret,className=secret});Flags(true)
 got,n=Seen(80)
 Equal(n==8 and got[HOGGER]and got["You no take candle!"],true,"a secret class: all eight General lines")
 Session(nil,{class="DEATHKNIGHT",className="Death Knight"});Flags(true)
 got,n=Seen(80)
 Equal(n,8,"a class with no lines: the General lines")
end
-- The top-up boundary, on made-up lines: two get the General lines, three do not.
do
 local function Q(text)return {text=text,speaker="Someone",where="Somewhere"}end
 local GENERAL={Q("g1"),Q("g2"),Q("g3")}
 for _,case in ipairs({{{Q("m1"),Q("m2")},5,true,"two class lines: topped up with the General lines"},
  {{Q("m1"),Q("m2"),Q("m3")},3,false,"three class lines: no General lines"}})do
  Session(nil,{class="MAGE",className="Mage",quotes={MAGE=case[1],GENERAL=GENERAL}});Flags(true)
  local got,n=Seen(60)
  Equal(n,case[2],case[4].." ("..case[2].." in the pool)")
  Equal(got.m1==true and got.m2==true and(got.g1==true and got.g2==true and got.g3==true)==case[3],true,case[4])
 end
end
-- The option, missing data and a refused font.
Session({afkShowQuote=false});Flags(true)
Equal(s.M.quoteBox.shown,false,"Class Quote off: no quote")
Equal(s.M.quoteText.text==nil and s.randCalls,0,"and no line picked")
Run(90,.05)
Equal(s.M.quoteText.text==nil and not s.M.quoteBox.shown,true,"not even after 90 seconds")
s.E.settings.afkShowQuote=true;s.M:Refresh()
Equal(s.M.quoteBox.shown and Said()~=nil,true,"switched on while away: a line shows at once")
s.E.settings.afkShowQuote=false;s.M:Refresh()
Equal(s.M.quoteBox.shown or s.M.quoteOn,false,"switched off: gone")
do local n=s.M.quoteText.setTextCount;Run(90,.05);Equal(s.M.quoteText.setTextCount,n,"and it no longer changes")end
Session(nil,{noQuotes=true});Flags(true)
Equal(Active()and not s.M.quoteBox.shown,true,"no quote data: the screen opens without a quote")
Session(nil,{quotes={GENERAL={}}});Flags(true);Run(45,.05)
Equal(Active()and not s.M.quoteBox.shown and s.M.quoteText.text==nil,true,"an empty pool: no quote and no error")
Session(nil,{missing={[QUOTE_FONT]=true}});Flags(true)
Equal(s.M.quoteText.font[1],"Fonts\\FRIZQT__.TTF","a refused quote font falls back to the normal font")
Equal(s.M.quoteText.font[2],22,"a little smaller")
Equal(s.M.quoteBox.shown and Said()~=nil,true,"and the quote still shows")

-- 26. The minimap: its arrow and blips ignore the fade, so it is hidden while away.
Session();Flags(true);Run(.3,.05)
Equal(Minimap.shown,true,"the minimap fades with the interface first")
Run(.4,.05)
Equal(Minimap.shown,false,"hidden once the interface is gone")
Equal(s.mapHides,1,"hidden once")
Run(5,.05);Equal(s.mapHides,1,"and only once")
Flags(false)
Equal(Minimap.shown,true,"back when you come back")
Equal(s.mapShows,1,"shown once")
Session(nil,{mapOff=true});Flags(true);Run(1,.05);Flags(false)
Equal(Minimap.shown==false and s.mapShows+s.mapHides,0,"a minimap you turned off stays off")
Session(nil,{mapProtected=true});Flags(true);Run(1,.05)
Equal(Minimap.shown==true and s.mapHides,0,"a protected minimap is never hidden")
Flags(false);Equal(s.mapShows,0,"nor shown")
Session(nil,{mapProtectedSecret=true});secretReads=0;Flags(true);Run(1,.05)
Equal(Minimap.shown==true and s.mapHides,0,"an unreadable protection is treated as protected")
Equal(secretReads>0,true,"a secret protection answer is recognised, never tested as a boolean")
Session(nil,{mapShownSecret=true});Flags(true);Run(1,.05);Flags(false)
Equal(s.mapHides+s.mapShows,0,"an unreadable shown state leaves it alone")
Session();Flags(true);Run(.2,.05);Flags(false)
Equal(s.mapHides+s.mapShows,0,"leaving during the fade never touches it")
Session(nil,{noMinimap=true});Flags(true);Run(1,.05);Flags(false)
Equal(Active(),false,"no minimap at all: nothing breaks")
Session();Flags(true);Run(1,.05)
s.combat=true;Event("PLAYER_REGEN_DISABLED")
Equal(Minimap.shown,true,"combat: an unprotected minimap comes back at once")
s.combat=false
-- Something made it protected while we had it hidden: it waits for combat to end.
Session();Flags(true);Run(1,.05)
Minimap.protected=true;s.combat=true;Event("PLAYER_REGEN_DISABLED")
Equal(Active(),false,"combat leaves")
Equal(Minimap.shown,false,"a protected minimap is not shown in combat")
Equal(s.M.mapPending,true,"it waits")
s.combat=false;Event("PLAYER_REGEN_ENABLED")
Equal(Minimap.shown,true,"and comes back when combat ends")
Equal(s.M.mapPending,false,"done waiting")
Session();Flags(true);Run(1,.05)
Minimap.protected=true;s.combat=true;s.E.settings.afkScreen=false;s.M:Refresh()
Equal(Minimap.shown==false and s.M.mapPending,true,"switched off in combat: the minimap still waits")
s.combat=false;Event("PLAYER_REGEN_ENABLED")
Equal(Minimap.shown,true,"and comes back after combat even with the screen off")
Session();s.combat=true;s.M:HideMap();s.combat=false
Equal(s.mapHides,0,"never hidden in combat")

-- 27. Preview.
Session({afkScreen=false})
s.M:Preview();Flush()
Equal(s.prints[1],"Turn on AFK Screen in /era > Text & Camera first.","preview asks to turn the option on")
Equal(Active(),false,"no preview while off")
Session()
s.combat=true;s.M:Preview();Flush();s.combat=false
Equal(s.prints[1],"The AFK screen can't open in combat.","no preview in combat")
s.M:Preview()
Equal(Active(),false,"preview waits for the chat box")
Flush()
Equal(Active(),true,"preview opens without the AFK flag")
Equal(s.M.preview,true,"marked as a preview")
Run(1,.05);Equal(Minimap.shown,false,"the preview hides the minimap too")
Root().scripts.OnKeyDown(Root(),"SPACE")
Equal(Active(),false,"a key leaves the preview")
Equal(s.M.preview,false,"preview cleared")
Equal(Minimap.shown,true,"and the minimap is back")
Session({enabled=false});s.M:Preview();Flush()
Equal(s.prints[1],"EraUI is turned off, so the AFK screen can't open.","preview with EraUI off says so")
Equal(#s.prints,1,"and only that")
-- Every other block explains itself instead of doing nothing.
for _,case in ipairs({
 {"on a flight path",{taxi=true}},{"while you are dead",{dead=true}},{"during a cinematic",{cinematic=true}},
 {"while the trainer is open",{trainer={IsShown=function()return true end}}},{"while Edit Mode is open",{editMode=true}},
 {"during a boss encounter",{restricted=1}},{"during a keystone run",{restricted=2}},{"during a PvP match",{restricted=3}},
 {"in combat",{affecting=true}},{"on this client",{noIgnoreAlpha=true}},
})do
 Session(nil,case[2]);s.M:Preview();Flush()
 Equal(s.prints[1],"The AFK screen can't open "..case[1]..".","preview explains: "..case[1])
 Equal(#s.prints==1 and not Active(),true,"no preview "..case[1])
end
Session();UIParent.shown=false;s.M:Preview();Flush()
Equal(s.prints[1],"The AFK screen can't open while the interface is hidden (Alt+Z).","preview explains a hidden interface")
-- The automatic path stays silent.
for _,opts in ipairs({{taxi=true},{affecting=true},{restricted=1},{noIgnoreAlpha=true},{editMode=true}})do
 Session(nil,opts);Flags(true)
 Equal(#s.prints==0 and not Active(),true,"a blocked automatic AFK prints nothing")
end

-- 28. Across the suite: UIParent was never hidden or shown, no views, CVars or panel layout written.
Equal(#forbidden,0,"no UIParent Hide/Show/SetShown, SetCVar, SaveView, SetView or UpdateUIPanelPositions calls: "..table.concat(forbidden,", "))
print("AFK screen checks passed: "..checks.." assertions.")
