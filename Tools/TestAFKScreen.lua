-- AFK screen: the real module under a frame mock. Protected calls throw in
-- combat, and any UIParent visibility change or view/CVar write always throws.
local checks=0
unpack=table.unpack or unpack
local function Equal(a,b,label)checks=checks+1;assert(a==b,label..": expected "..tostring(b)..", got "..tostring(a))end
local function Near(a,b,label,eps)
 checks=checks+1;assert(type(a)=="number"and math.abs(a-b)<(eps or 1e-6),label..": expected "..tostring(b)..", got "..tostring(a))
end
local function Wrapped(v)local r=v%360;return math.min(r,360-r)end
local secret={};issecretvalue=function(v)return v==secret end
local forbidden={} -- every call that must never happen, across the whole suite
local function Forbid(name)forbidden[#forbidden+1]=name;error(name.." must never be called")end
local EXIT={"PLAYER_REGEN_DISABLED","PLAYER_STARTED_MOVING","PLAYER_DEAD","CINEMATIC_START","PLAY_MOVIE",
 "LFG_PROPOSAL_SHOW","READY_CHECK","ROLE_POLL_BEGIN","CONFIRM_SUMMON","RESURRECT_REQUEST","PARTY_INVITE_REQUEST",
 "TRADE_SHOW","DUEL_REQUESTED","PLAYER_CAMPING","PLAYER_QUITING","START_LOOT_ROLL","PLAYER_CONTROL_LOST",
 "PLAYER_LEAVING_WORLD","PLAYER_LOGOUT"}
local AFK_KEYS={"afkScreen","afkCameraNormal","afkTurnRight","afkZoom","afk24Hour","afkShowGuild","afkShowZone","afkShowDate"}
local s
local methods={}
local function Frame(kind,name,parent,template)
 local f=setmetatable({kind=kind,name=name,parent=parent,template=template,shown=true,alpha=1,points={},scripts={},events={},
  setTextCount=0,sized=false},{__index=methods})
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
function methods:SetAllPoints(r)self.allPoints=r or self.parent;self.sized=true;self.points={{"ALL",self.allPoints}}end
function methods:SetPoint(...)self.points[#self.points+1]={...}end
function methods:ClearAllPoints()self.points={}end
function methods:SetAlpha(v)self.alpha=v end
function methods:GetAlpha()return self.alpha end
function methods:SetScript(k,fn)self.scripts[k]=fn end
function methods:RegisterEvent(e)if s.unknown[e]then error("unknown event "..e)end;self.events[e]=true end
function methods:RegisterUnitEvent(e,u)self.events[e]=u end
function methods:UnregisterAllEvents()self.events={}end
function methods:CreateTexture()return Frame("Texture",nil,self)end
function methods:CreateFontString()return Frame("FontString",nil,self)end
function methods:SetTexture(path)self.texture=path;if s.missing[path]then return false end;return true end
function methods:SetColorTexture(...)self.colour={...}end
function methods:SetVertexColor(...)self.colour={...}end
function methods:SetFont(font,size,flags)if s.missing[font]then return false end;self.font={font,size,flags}end
function methods:SetText(v)self.text=v;self.setTextCount=self.setTextCount+1 end
function methods:SetTextColor(...)self.textColour={...}end
function methods:SetJustifyH(v)self.justify=v end
function methods:SetBackdrop(b)self.backdrop=b end
function methods:SetBackdropBorderColor(...)self.borderColour={...}end
function methods:SetUnit(unit)
 s.setUnit[#s.setUnit+1]=unit
 if s.setUnitError then error("no model")end
 return s.setUnitResult
end
function methods:SetRotation(v)self.rotation=v end
function methods:ClearModel()self.cleared=(self.cleared or 0)+1;self.unit=nil end
for _,k in ipairs({"SetShadowColor","SetShadowOffset","SetWordWrap","SetPortraitZoom","SetCamDistanceScale"})do methods[k]=function()end end

local function Session(settings,opts)
 opts=opts or{}
 s={frames={},named={},timers={},clock=100,afk=false,combat=false,yawNet=0,flips=0,zoomNet=0,zoomCalls=0,camStart=20,
  moves={},missing={},unknown={},prints={},statuses={},cvars={},bg={},dateFormats={},portraits={},hooks={},setUnit={},unsizedShows={},
  now={year=2026,month=9,day=29,hour=15,min=7,sec=0,wday=3},guild="Guild",zone="Zone",subzone="Sub",level=60}
 for k,v in pairs(opts)do s[k]=v end
 if opts.noGuild then s.guild=nil end
 methods.SetIgnoreParentAlpha=not opts.noIgnoreAlpha and IgnoreParentAlpha or nil
 methods.RegisterUnitEvent=not opts.noUnitEvents and function(self,e,u)self.events[e]=u end or nil
 UIParent=Frame("UIParent");UIParent.w,UIParent.h,UIParent.sized=1920,1080,true
 UIParent.Hide=function()Forbid("UIParent:Hide")end
 UIParent.Show=function()Forbid("UIParent:Show")end
 UIParent.SetShown=function()Forbid("UIParent:SetShown")end
 for _,k in ipairs({"SetUIVisibility","SetInWorldUIVisibility","SaveView","SetView","ResetView","SetCVar"})do
  _G[k]=function()Forbid(k)end
 end
 CreateFrame=function(kind,name,parent,template)return Frame(kind,name,parent,template)end
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
 UnitClass=function()return "Paladin","PALADIN"end
 UnitRace=function()return "Human","Human"end
 UnitLevel=function()return s.level end
 GetGuildInfo=function()return s.guild end
 GetRealZoneText=function()return s.zone end
 GetZoneText=function()return s.zone end
 GetSubZoneText=function()return s.subzone end
 SetPortraitTexture=function(tex,unit)s.portraits[#s.portraits+1]={tex,unit}end
 UnitIsDeadOrGhost=function()return s.dead end
 UnitOnTaxi=function()return s.taxi end
 InCinematic=function()return s.cinematic end
 GetCurrentKeyBoardFocus=function()return s.focus end
 local binds={F12="SCREENSHOT",W="MOVEFORWARD",SPACE="JUMP",ENTER="OPENCHAT",["1"]="ACTIONBUTTON1",ESCAPE="TOGGLEGAMEMENU",X=secret}
 GetBindingFromClick=function(key)return binds[key]end
 -- Documented: every restriction reads inactive while its change event is dispatched.
 C_RestrictedActions={IsAddOnRestrictionActive=function(t)if s.dispatching then return false end;return s.restricted==t end}
 Enum={AddOnRestrictionState={Inactive=0,Activating=1,Active=2}}
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
 RAID_CLASS_COLORS={PALADIN={r=.1,g=.2,b=.3},MAGE={r=.4,g=.8,b=1}}
 local E={modules={},settings={enabled=true,afkScreen=true,afkZoom=true,afkShowGuild=true,afkShowZone=true,afkShowDate=true}}
 for k,v in pairs(settings or{})do E.settings[k]=v end
 function E:RegisterModule(k,v)self.modules[k]=v end
 function E:GetSetting(k)return self.settings[k]end
 function E:Print(m)s.prints[#s.prints+1]=m end
 function E:Status(m)s.statuses[#s.statuses+1]=m end
 E.Media={gold={.93,.75,.32,1}}
 E.Classic={TexPath=function(key)return "Interface\\"..key end,
  SetTex=function(t,key)t.texKey=key;local ok=t:SetTexture("Interface\\"..key)
   if E.settings.darkMode then t:SetVertexColor(.42,.44,.48)end -- worst case: Dark Mode greys every key
   return ok end}
 assert(loadfile("Modules/AFKScreen.lua"))("EraUI",E)
 s.E,s.M=E,E.modules.AFKScreen
 -- The file ships the screen as Coming soon; the suite runs the finished one.
 s.shipped=s.M.comingSoon
 s.M.comingSoon=opts.comingSoon==true
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

-- 0. Ships as Coming soon: inert even with the option saved on.
Session(nil,{comingSoon=true})
local made=#s.frames
Equal(s.shipped,true,"the AFK Screen ships as Coming soon")
Equal(s.E.settings.afkScreen,true,"with the option saved on")
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

-- 1. Off by default: only the event frame, nothing registered, flags ignored.
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

-- 3. An AFK transition enters with a sized, input-catching root above everything.
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
 end
end
Equal(s.M.model.kind,"PlayerModel","a real player model")
Equal(s.M.panel.template,"BackdropTemplate","panel uses the backdrop template")
Equal(s.M.plaque.title.text,"EraUI","plaque title")
Equal(s.M.plaque.sub.text,"Away from keyboard","plaque subtitle")
Equal(s.M.plaque.logo.texture,"Interface\\AddOns\\EraUI\\Media\\EraUIIcon.tga","EraUI logo on the plaque")
Equal(s.M.plaque.title.font[1],"Fonts\\MORPHEUS.TTF","Classic title font")
Equal(s.M.hint.text,"Move or press any key to come back","hint line")
Equal(s.M.badge.ring.texKey,"trackingBorder","level badge uses the minimap ring")
Equal(s.M.holder.rim.texKey,"portraitMask","portrait rim is round")
Near(s.M.model.h,620,"model height follows the screen")
Near(s.M.model.w,620*.62,"model width follows its height")
Near(s.M.model.points[1][4],96,"model 5% in from the left")
UIParent.h=500;Event("DISPLAY_SIZE_CHANGED")
Near(s.M.model.h,360,"display change resizes the model")
Equal(#s.M.model.points,1,"relayout clears the old anchor")

-- 4. Fade: UIParent and the screen cross over in 0.6 s.
Session()
Flags(true);root=Root()
Run(.3,.1)
Near(UIParent.alpha,.5,"UIParent half faded at 0.3 s")
Near(root.alpha,.5,"screen half shown at 0.3 s")
Run(.4,.1)
Near(UIParent.alpha,0,"UIParent gone at 0.6 s")
Near(root.alpha,1,"screen fully shown at 0.6 s")

-- 5. Info lines.
Session()
Flags(true)
Equal(Line("name").text,"Ann Smith","first name and surname")
local c=Line("name").textColour
Equal(c[1]==.96 and c[2]==.55 and c[3]==.73,true,"name in Classic Paladin pink")
Equal(Line("info").text,"Level 60 Human Paladin","level, race and class")
Equal(Line("guild").text,"<Guild>","guild in brackets")
Equal(Line("zone").text,"Sub, Zone","subzone and zone")
Equal(Line("date").text,"Tuesday, 29 September","date from the calendar names")
Equal(Line("away").text,"Away for 00:00","away timer starts at zero")
Equal(Line("clock").text,"3:07 PM","12-hour local time")
Equal(Line("clockLabel").text,"Local time","clock label")
Equal(s.M.badge.level.text,"60","level badge")
Equal(s.portraits[#s.portraits][1]==s.M.holder.portrait and s.portraits[#s.portraits][2],"player","portrait set for the player")
Equal(Firsts(Line("name")),s.M.panel,"name at the top of the panel")
Equal(Firsts(Line("info")),Line("name"),"info under the name")
Equal(Firsts(Line("guild")),Line("info"),"guild under the info")
Equal(Firsts(Line("zone")),Line("guild"),"zone under the guild")

-- 6. Secondary names, no guild, subzone equal to zone.
Session({hideSecondaryNames=true},{noGuild=true,subzone="Zone"})
Flags(true)
Equal(Line("name").text,"Ann","Hide Secondary Names shows the first name only")
Equal(Line("guild").shown,false,"no guild: guild line hidden")
Equal(Firsts(Line("zone")),Line("info"),"zone moves up under the info")
Equal(Line("zone").text,"Zone","subzone equal to the zone shows the zone once")
s.guild="Later";Event("PLAYER_GUILD_UPDATE")
Equal(Line("guild").shown and Line("guild").text,"<Later>","joining a guild refills the panel")
Session(nil,{surname=""});Flags(true)
Equal(Line("name").text,"Ann","an empty surname adds no space")
Session(nil,{surname=secret,level=secret});Flags(true)
Equal(Line("name").text,"Ann","a secret surname is dropped")
Equal(Line("info").text,"Human Paladin","a secret level is dropped")
Equal(s.M.badge.level.text,"","and the badge stays empty")

-- 7. Display options, applied live through Refresh.
Session()
Flags(true)
s.E.settings.afkShowGuild=false;s.M:Refresh()
Equal(Line("guild").shown,false,"Show Guild off hides the guild")
s.E.settings.afkShowZone=false;s.M:Refresh()
Equal(Line("zone").shown,false,"Show Zone off hides the zone")
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

-- 9. The text is throttled.
Session()
Flags(true)
local away=Line("away");local count=away.setTextCount
for _=1,20 do s.clock=s.clock+.01;Root().scripts.OnUpdate(Root(),.01)end
Equal(away.setTextCount-count<=1,true,"20 quick frames set the timer text at most once more")
Run(1,.05)
Equal(away.text,"Away for 00:01","timer after one more second")
s.now.hour,s.now.min=9,5;Run(.5,.05)
Equal(Line("clock").text,"9:05 AM","clock follows local time")

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
Flags(false)
Equal(UIParent.alpha,.8,"a saved 0.8 stays 0.8")
Equal(Root().shown,false,"screen hidden")
Equal(s.M.model.cleared,1,"model cleared")
Equal(s.M.dismissed,false,"back from AFK is not a dismissal")
Flags(true);Equal(Active(),true,"the next AFK enters again")
Session();UIParent.alpha=.05;Flags(true);Run(1,.1);Flags(false)
Equal(UIParent.alpha,1,"an almost invisible interface comes back at full alpha")
Session();Flags(true);Flags(false);Equal(UIParent.alpha,1,"leaving during the fade restores alpha")

-- 15. Combat closes the screen with nothing protected, and it stays closed.
Session();Flags(true);Run(5,.05)
s.combat=true;Event("PLAYER_REGEN_DISABLED")
Equal(Active(),false,"combat closes the screen")
Equal(UIParent.alpha,1,"interface back in combat")
Near(Wrapped(s.yawNet),0,"camera restored in combat")
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
 {"the trainer open",nil,{trainer={IsShown=function()return true end}}},
 {"no SetIgnoreParentAlpha",nil,{noIgnoreAlpha=true}},{"EraUI disabled",{enabled=false}},
})do
 Session(case[2],case[3]);Flags(true)
 Equal(Active(),false,"no entry when "..case[1])
 Equal(UIParent.alpha,1,"UIParent alpha untouched when "..case[1])
end
Equal(s.M.unsupported,nil,"a disabled EraUI is not marked unsupported")
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
s.E.settings.afkScreen=false;s.M:Refresh()
Equal(Active(),false,"turning off leaves")
Equal(UIParent.alpha,.9,"and restores alpha")
Equal(next(s.events.events),nil,"and unregisters every event")
Near(Wrapped(s.yawNet),0,"and restores the camera")

-- 24. Leaving the world and logging out restore the camera.
for _,e in ipairs({"PLAYER_LEAVING_WORLD","PLAYER_LOGOUT"})do
 Session();Flags(true);Run(20,.05)
 Equal(s.zoomNet>0 and Wrapped(s.yawNet)>0,true,"camera moved before "..e)
 Event(e)
 Near(Wrapped(s.yawNet),0,e.." restores yaw")
 Near(s.zoomNet,0,e.." restores zoom")
end

-- 25. The model.
Session();Flags(true)
Equal(s.setUnit[1],"player","the model shows the player")
Equal(s.M.model.shown and s.M.shadow.shown,true,"model and shadow shown")
Near(s.M.model.rotation,0,"model starts facing forward")
Run(1,.1)
Near(s.M.model.rotation,.18,"model turns left with the camera")
Session({afkTurnRight=true});Flags(true);Run(1,.1)
Near(s.M.model.rotation,-.18,"model turns right with the camera")
Session(nil,{setUnitResult=false});Flags(true)
Equal(s.M.model.shown or s.M.shadow.shown,false,"no model: model and shadow hidden")
Equal(Active(),true,"the screen still opens")
Session(nil,{setUnitError=true});Flags(true)
Equal(s.M.model.shown,false,"a model error hides the model")

-- 26. Border art and fonts.
Session(nil,{missing={["Interface\\DialogFrame\\UI-DialogBox-Gold-Border"]=true}});Flags(true)
Equal(s.M.panel.backdrop.edgeFile,"Interface\\DialogFrame\\UI-DialogBox-Border","no gold border: Classic border")
local b=s.M.panel.borderColour
Equal(b and b[1]==1 and b[2]==.82 and b[3]==0,true,"tinted gold")
Session();Flags(true)
Equal(s.M.panel.backdrop.edgeFile,"Interface\\DialogFrame\\UI-DialogBox-Gold-Border","gold border when the client has it")
Equal(s.M.panel.borderColour,nil,"no tint on the gold border")
Equal(s.M.panel.backdrop.bgFile,"Interface\\DialogFrame\\UI-DialogBox-Background","Classic dialog background")
Session({darkMode=true});Flags(true)
local function Tint(t)local c=t.colour or{};return table.concat({c[1],c[2],c[3],c[4]},",")end
Equal(Tint(s.M.badge.ring),"1,1,1,1","Dark Mode: the level badge ring stays gold")
Equal(Tint(s.M.holder.rim),table.concat({.93,.75,.32,1},","),"Dark Mode: the portrait rim stays gold")
Equal(Tint(s.M.badge.disc),table.concat({.08,.065,.035,1},","),"Dark Mode: the badge disc keeps its tint")
Equal(Tint(s.M.shadow),table.concat({0,0,0,.45},","),"Dark Mode: the ground shadow keeps its tint")
Session(nil,{missing={["Fonts\\MORPHEUS.TTF"]=true}});Flags(true)
Equal(s.M.plaque.title.font[1]~="Fonts\\MORPHEUS.TTF"and s.M.plaque.title.font[2],20,"missing title font falls back to the normal font")

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
Root().scripts.OnKeyDown(Root(),"SPACE")
Equal(Active(),false,"a key leaves the preview")
Equal(s.M.preview,false,"preview cleared")
Session({enabled=false});s.M:Preview();Flush()
Equal(s.prints[1],"EraUI is turned off, so the AFK screen can't open.","preview with EraUI off says so")
Equal(#s.prints,1,"and only that")
-- Every other block explains itself instead of doing nothing.
for _,case in ipairs({
 {"on a flight path",{taxi=true}},{"while you are dead",{dead=true}},{"during a cinematic",{cinematic=true}},
 {"while the trainer is open",{trainer={IsShown=function()return true end}}},
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
for _,opts in ipairs({{taxi=true},{affecting=true},{restricted=1},{noIgnoreAlpha=true}})do
 Session(nil,opts);Flags(true)
 Equal(#s.prints==0 and not Active(),true,"a blocked automatic AFK prints nothing")
end

-- 28. Across the suite: UIParent was never hidden or shown, no views or CVars written.
Equal(#forbidden,0,"no UIParent Hide/Show/SetShown, SetCVar, SaveView or SetView calls: "..table.concat(forbidden,", "))
print("AFK screen checks passed: "..checks.." assertions.")
