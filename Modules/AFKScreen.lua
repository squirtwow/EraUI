local _,E=...
local M={};E:RegisterModule("AFKScreen",M)
local ns=E.Classic
-- AFK Screen: while you are away the interface fades out and EraUI shows your
-- character, a Classic info panel and a slowly circling camera. Leaving only
-- sets UIParent alpha, touches our own frames and makes camera calls, so it is
-- safe in combat. UIParent is never hidden or shown.
-- Coming soon: while this is true the AFK Screen never runs, whatever is
-- saved, and its /era card shows SOON. Tests switch it off.
M.comingSoon=true
local floor,min,max,abs,format=math.floor,math.min,math.max,math.abs,string.format
local FONT=STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local TITLE_FONT="Fonts\\MORPHEUS.TTF"
local LOGO="Interface\\AddOns\\EraUI\\Media\\EraUIIcon.tga"
local HEADER="Interface\\DialogFrame\\UI-DialogBox-Header"
local BG="Interface\\DialogFrame\\UI-DialogBox-Background"
local GOLD_EDGE="Interface\\DialogFrame\\UI-DialogBox-Gold-Border"
local PLAIN_EDGE="Interface\\DialogFrame\\UI-DialogBox-Border"
local GOLD=E.Media and E.Media.gold or {.93,.75,.32,1}
local SPEED_SLOW,SPEED_NORMAL=3,6      -- degrees a second (2 min / 1 min a circle)
local FADE=0.6                          -- seconds, fade in only; leaving is instant
local ZOOM_TIME,ZOOM_SHARE,ZOOM_MAX,ZOOM_MIN_START=20,.3,8,6
local MODEL_TURN=.18                    -- radians a second
local TICK=.25
local MODIFIERS={LSHIFT=true,RSHIFT=true,LCTRL=true,RCTRL=true,LALT=true,RALT=true,LMETA=true,RMETA=true}
-- Keys bound to these keep their binding as they close the screen, so W walks
-- and Enter opens chat. Any other key only closes it: a number key must not cast.
local PASS={MOVEFORWARD=true,MOVEBACKWARD=true,STRAFELEFT=true,STRAFERIGHT=true,TURNLEFT=true,TURNRIGHT=true,
 JUMP=true,TOGGLEAUTORUN=true,OPENCHAT=true,OPENCHATSLASH=true,REPLY=true}
local EXIT_EVENTS={"PLAYER_REGEN_DISABLED","PLAYER_STARTED_MOVING","PLAYER_DEAD","CINEMATIC_START","PLAY_MOVIE",
 "LFG_PROPOSAL_SHOW","READY_CHECK","ROLE_POLL_BEGIN","CONFIRM_SUMMON","RESURRECT_REQUEST","PARTY_INVITE_REQUEST",
 "TRADE_SHOW","DUEL_REQUESTED","PLAYER_CAMPING","PLAYER_QUITING","START_LOOT_ROLL","PLAYER_CONTROL_LOST",
 "PLAYER_LEAVING_WORLD","PLAYER_LOGOUT"}
local INFO_EVENTS={PLAYER_GUILD_UPDATE=true,ZONE_CHANGED=true,ZONE_CHANGED_INDOORS=true,ZONE_CHANGED_NEW_AREA=true}
local OTHER_EVENTS={"PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","ADDON_RESTRICTION_STATE_CHANGED","UPDATE_BATTLEFIELD_STATUS","DISPLAY_SIZE_CHANGED","UI_SCALE_CHANGED"}
local RESTRICT={[0]=true,[1]=true,[2]=true,[3]=true,[5]=true} -- combat, encounter, keystone, pvp match, chat
local BLOCKED={[0]="in combat",[1]="during a boss encounter",[2]="during a keystone run",[3]="during a PvP match"}
local ORDER={"name","info","guild","zone"}
local events,root,model,shadow,panel,holder,badge,hint,unitEvents
local L={}
M.last={};M.yaw,M.zoomed,M.zoomGoal,M.turn,M.sign,M.rate=0,0,0,0,1,0

local function Secret(v)return issecretvalue and issecretvalue(v)end
local function Clean(v)if v==nil or Secret(v)then return nil end;return v end
local function ReadAFK()
 local ok,v=pcall(UnitIsAFK,"player");if not ok or Secret(v)or v==nil then return nil end;return v==true
end
M.ReadAFK=ReadAFK
local function Enabled()return not M.comingSoon and E:GetSetting("enabled")and E:GetSetting("afkScreen")end
local function InCombat()return InCombatLockdown and InCombatLockdown()end
-- True when fn(...) answers yes. A secret answer counts as yes, so we stay out.
local function Yes(fn,...)
 if type(fn)~="function"then return false end
 local ok,v=pcall(fn,...);if not ok then return false end
 return Secret(v)or(v and true or false)
end
local function ClassColour(class)
 class=Clean(class)
 if class=="PALADIN"then return .96,.55,.73 end
 local c=class and((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])or(RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
 if c then return c.r,c.g,c.b end
 return .7,.7,.7
end
local function Text(parent,size,r,g,b,flags,font)
 local t=parent:CreateFontString(nil,"OVERLAY")
 if t:SetFont(font or FONT,size,flags or "")==false then t:SetFont(FONT,font and size-2 or size,flags or "")end
 t:SetShadowColor(0,0,0,1);t:SetShadowOffset(1,-1);t:SetJustifyH("LEFT");t:SetTextColor(r,g,b)
 return t
end
local function Tex(t,key)
 if ns and ns.SetTex then ns.SetTex(t,key)
 else t:SetTexture(key=="trackingBorder"and "Interface\\Minimap\\MiniMap-TrackingBorder"or "Interface\\CharacterFrame\\TempPortraitAlphaMask")end
end

function M.FormatAway(s)
 s=max(0,floor(s or 0))
 if s<3600 then return format("%02d:%02d",floor(s/60),s%60)end
 return format("%d:%02d:%02d",floor(s/3600),floor(s%3600/60),s%60)
end
function M.FormatClock(h,m,use24)
 if use24 then return format("%02d:%02d",h,m)end
 local h12=h%12;if h12==0 then h12=12 end
 return format("%d:%02d %s",h12,m,h<12 and(TIMEMANAGER_AM or "AM")or(TIMEMANAGER_PM or "PM"))
end
function M.FormatDate(t)
 local wd=CALENDAR_WEEKDAY_NAMES and CALENDAR_WEEKDAY_NAMES[t.wday]
 local mo=CALENDAR_FULLDATE_MONTH_NAMES and CALENDAR_FULLDATE_MONTH_NAMES[t.month]
 if wd and mo then return wd..", "..t.day.." "..mo end
 return date("%A, %d %B")
end

local function Build()
 root=CreateFrame("Frame","EraUIAFKScreen",UIParent)
 root:SetAllPoints(UIParent);root:SetFrameStrata("TOOLTIP");root:SetFrameLevel(1)
 root:SetIgnoreParentAlpha(true);root:EnableMouse(true);root:EnableMouseWheel(true)
 root:EnableKeyboard(true);root:SetPropagateKeyboardInput(true);root:Hide()
 model=CreateFrame("PlayerModel",nil,root);model:SetSize(372,600)
 model:SetPoint("BOTTOMLEFT",root,"BOTTOMLEFT",64,56);model:SetFrameLevel(2)
 if model.SetPortraitZoom then model:SetPortraitZoom(0)end
 if model.SetCamDistanceScale then model:SetCamDistanceScale(1)end
 shadow=root:CreateTexture(nil,"BACKGROUND");shadow:SetSize(230,40);shadow:SetPoint("CENTER",model,"BOTTOM",0,28)
 Tex(shadow,"portraitMask");shadow:SetVertexColor(0,0,0,.45)
 -- The EraUI plaque, top centre.
 local plaque=CreateFrame("Frame",nil,root);plaque:SetSize(320,84);plaque:SetPoint("TOP",root,"TOP",0,-16);plaque:SetFrameLevel(3)
 local header=plaque:CreateTexture(nil,"ARTWORK");header:SetTexture(HEADER);header:SetSize(320,80);header:SetPoint("TOP",plaque,"TOP",0,0)
 local title=Text(plaque,22,1,.82,0,nil,TITLE_FONT);title:SetPoint("TOP",header,"TOP",15,-13);title:SetText("EraUI")
 local logo=plaque:CreateTexture(nil,"OVERLAY");logo:SetSize(26,26);logo:SetPoint("RIGHT",title,"LEFT",-5,1);logo:SetTexture(LOGO)
 local sub=Text(plaque,15,.94,.95,.98,"OUTLINE");sub:SetWidth(300);sub:SetJustifyH("CENTER")
 sub:SetPoint("TOP",header,"TOP",0,-54);sub:SetText("Away from keyboard")
 plaque.header,plaque.title,plaque.logo,plaque.sub=header,title,logo,sub;M.plaque=plaque
 -- The Classic info panel, lower right. Gold edge when the client has it.
 panel=CreateFrame("Frame",nil,root,"BackdropTemplate");panel:SetSize(430,210)
 panel:SetPoint("BOTTOMRIGHT",root,"BOTTOMRIGHT",-56,72);panel:SetFrameLevel(3)
 local probe=panel:CreateTexture(nil,"BACKGROUND");local gold=probe:SetTexture(GOLD_EDGE)~=false;probe:Hide()
 if panel.SetBackdrop then
  panel:SetBackdrop({bgFile=BG,edgeFile=gold and GOLD_EDGE or PLAIN_EDGE,tile=true,tileSize=32,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}})
  if not gold then panel:SetBackdropBorderColor(1,.82,0)end
 end
 holder=CreateFrame("Frame",nil,panel);holder:SetSize(84,84);holder:SetPoint("TOPLEFT",panel,"TOPLEFT",22,-22);holder:SetFrameLevel(4)
 local function Disc(layer,size,r,g,b)
  local t=holder:CreateTexture(nil,layer);t:SetSize(size,size);t:SetPoint("CENTER",holder,"CENTER",0,0)
  Tex(t,"portraitMask");t:SetVertexColor(r,g,b,1);return t
 end
 holder.rim=Disc("BACKGROUND",84,GOLD[1],GOLD[2],GOLD[3]);holder.well=Disc("BORDER",80,.08,.07,.06)
 holder.portrait=holder:CreateTexture(nil,"ARTWORK");holder.portrait:SetSize(76,76);holder.portrait:SetPoint("CENTER",holder,"CENTER",0,0)
 -- Level badge: EraUI's minimap-button disc and ring.
 badge=CreateFrame("Frame",nil,panel);badge:SetSize(30,30);badge:SetPoint("CENTER",holder,"BOTTOMRIGHT",-10,10);badge:SetFrameLevel(6)
 badge.disc=badge:CreateTexture(nil,"BACKGROUND");badge.disc:SetSize(30,30);badge.disc:SetPoint("TOPLEFT",badge,"TOPLEFT",0,0)
 Tex(badge.disc,"portraitMask");badge.disc:SetVertexColor(.08,.065,.035,1)
 badge.ring=badge:CreateTexture(nil,"OVERLAY");badge.ring:SetSize(50,50);badge.ring:SetPoint("TOPLEFT",badge,"TOPLEFT",0,0);Tex(badge.ring,"trackingBorder")
 badge.ring:SetVertexColor(1,1,1,1) -- stays gold with the panel when Dark Mode greys the minimap ring
 badge.level=Text(badge,12,1,.82,.25,"OUTLINE");badge.level:SetJustifyH("CENTER");badge.level:SetPoint("CENTER",badge,"CENTER",0,0)
 local function Line(key,size,r,g,b,flags,width)
  local t=Text(panel,size,r,g,b,flags);t:SetWidth(width);t:SetWordWrap(false);L[key]=t;return t
 end
 Line("name",20,1,1,1,nil,282);Line("info",13,1,1,1,nil,282);Line("guild",13,.85,.85,.85,nil,282);Line("zone",13,1,.82,0,nil,282)
 local divider=panel:CreateTexture(nil,"ARTWORK");divider:SetHeight(1);divider:SetColorTexture(GOLD[1],GOLD[2],GOLD[3],.45)
 divider:SetPoint("TOPLEFT",panel,"TOPLEFT",22,-122);divider:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-22,-122)
 Line("away",24,1,.82,0,"OUTLINE",250):SetPoint("TOPLEFT",panel,"TOPLEFT",22,-134)
 Line("date",12,.8,.8,.8,nil,250):SetPoint("TOPLEFT",panel,"TOPLEFT",22,-172)
 local clock=Line("clock",20,.94,.95,.98,nil,130);clock:SetJustifyH("RIGHT");clock:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-24,-136)
 local label=Line("clockLabel",11,.62,.62,.62,nil,130);label:SetJustifyH("RIGHT");label:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-24,-164);label:SetText("Local time")
 hint=Text(root,13,.9,.9,.9,"OUTLINE");hint:SetWidth(500);hint:SetJustifyH("CENTER");hint:SetPoint("BOTTOM",root,"BOTTOM",0,26)
 hint:SetText("Move or press any key to come back")
 M.root,M.model,M.shadow,M.panel,M.holder,M.badge,M.hint,M.lines=root,model,shadow,panel,holder,badge,hint,L
 root:SetScript("OnMouseDown",function()M:Leave("click")end)
 root:SetScript("OnMouseWheel",function()M:Leave("wheel")end)
 root:SetScript("OnKeyDown",function(self,key)
  if MODIFIERS[key]or key=="PRINTSCREEN"then return end
  local ok,binding=pcall(GetBindingFromClick,key)
  if not ok or Secret(binding)then binding=nil end
  if binding=="SCREENSHOT"then return end
  -- Movement and chat keys keep their binding. Escape (the Game Menu would open
  -- unseen), action keys and unknown keys are swallowed.
  if not InCombat()then self:SetPropagateKeyboardInput(key~="ESCAPE"and PASS[binding]==true)end
  M:Leave("key")
 end)
 root:SetScript("OnUpdate",function(_,elapsed)M:Step(elapsed)end)
end

local function Stack()
 local prev
 for _,key in ipairs(ORDER)do
  local t=L[key]
  if t:IsShown()then
   t:ClearAllPoints()
   if prev then t:SetPoint("TOPLEFT",prev,"BOTTOMLEFT",0,-4)else t:SetPoint("TOPLEFT",panel,"TOPLEFT",124,-26)end
   prev=t
  end
 end
end
function M:Layout()
 if not root then return end
 local w,h=root:GetWidth(),root:GetHeight()
 if not w or not h or w<=0 or h<=0 then w,h=UIParent:GetWidth(),UIParent:GetHeight()end
 w,h=w or 1024,h or 768
 local mh=max(300,min(620,h*.72))
 model:SetSize(mh*.62,mh);model:ClearAllPoints()
 model:SetPoint("BOTTOMLEFT",root,"BOTTOMLEFT",max(24,w*.05),max(40,h*.07))
 shadow:SetSize(mh*.4,mh*.07)
end
function M:Fill()
 if not root then return end
 local first,surname=UnitName("player");first,surname=Clean(first),Clean(surname)
 local name=first or ""
 if surname and surname~="" and not E:GetSetting("hideSecondaryNames")then name=name.." "..surname end
 local className,class=UnitClass("player")
 L.name:SetText(name);L.name:SetTextColor(ClassColour(class))
 local level=Clean(UnitLevel("player"));local race=Clean((UnitRace("player")))
 local parts={}
 if type(level)=="number"then parts[1]=format("Level %d",level)end
 if race and race~="" then parts[#parts+1]=race end
 className=Clean(className);if className and className~="" then parts[#parts+1]=className end
 L.info:SetText(table.concat(parts," "))
 badge.level:SetText(type(level)=="number"and format("%d",level)or "")
 local guild=E:GetSetting("afkShowGuild")and GetGuildInfo and Clean((GetGuildInfo("player")))
 L.guild:SetShown(guild and guild~="" and true or false)
 if guild and guild~="" then L.guild:SetText("<"..guild..">")end
 local zoneText
 if E:GetSetting("afkShowZone")then
  local zone=GetRealZoneText and Clean(GetRealZoneText())
  if not zone or zone=="" then zone=GetZoneText and Clean(GetZoneText())end
  local subzone=GetSubZoneText and Clean(GetSubZoneText())
  zoneText=zone or ""
  if subzone and subzone~="" and subzone~=zone then zoneText=zoneText~="" and subzone..", "..zoneText or subzone end
  L.zone:SetText(zoneText)
 end
 L.zone:SetShown(zoneText and zoneText~="" and true or false)
 L.date:SetShown(E:GetSetting("afkShowDate")and true or false)
 if SetPortraitTexture then pcall(SetPortraitTexture,holder.portrait,"player")end
 Stack()
end
local function Set(line,text)if M.last[line]~=text then M.last[line]=text;line:SetText(text)end end
function M:Tick(force)
 if not root then return end
 if force then self.last={}end
 Set(L.away,"Away for "..M.FormatAway(GetTime()-(self.since or GetTime())))
 local t=date("*t")
 Set(L.clock,M.FormatClock(t.hour,t.min,E:GetSetting("afk24Hour")))
 if L.date:IsShown()then Set(L.date,M.FormatDate(t))end
end

local function StopSpin()
 if MoveViewLeftStop then pcall(MoveViewLeftStop)end
 if MoveViewRightStop then pcall(MoveViewRightStop)end
end
local function StartCamera()
 M.yaw,M.turn,M.zoomed,M.zoomGoal=0,0,0,0
 local sign=E:GetSetting("afkTurnRight")and -1 or 1 -- [PROBE] flip here if "left" turns right
 M.sign=sign;M.rate=sign*(E:GetSetting("afkCameraNormal")and SPEED_NORMAL or SPEED_SLOW)
 if FlipCameraYaw then M.spin="flip"
 elseif MoveViewLeftStart then
  M.spin="move"
  local ok,cvar=pcall(GetCVar,"cameraYawMoveSpeed");local full=ok and not Secret(cvar)and tonumber(cvar)
  if not full or full<=0 then full=180 end
  pcall(sign>0 and MoveViewLeftStart or MoveViewRightStart,abs(M.rate)/full)
 else M.spin=nil end
 if E:GetSetting("afkZoom")and GetCameraZoom and CameraZoomIn and CameraZoomOut then
  local ok,z=pcall(GetCameraZoom)
  if ok and not Secret(z)and type(z)=="number"and z>ZOOM_MIN_START then M.zoomGoal=min(z*ZOOM_SHARE,ZOOM_MAX)end
 end
end
local function RestoreCamera()
 if M.spin=="flip"then
  local back=M.yaw%360;if back>180 then back=back-360 end
  if back~=0 then pcall(FlipCameraYaw,-back)end
 elseif M.spin=="move"then StopSpin()end
 if M.zoomed>0 then pcall(CameraZoomOut,M.zoomed)end
 M.yaw,M.zoomed,M.zoomGoal,M.spin=0,0,0,nil
end
local function Rotate(v)
 local fn=model.SetRotation or model.SetFacing
 if fn then pcall(fn,model,v)end
end
-- Runs after the root is shown: a model given its unit while hidden can stay blank.
local function SetupModel()
 local ok,res=pcall(model.SetUnit,model,"player")
 local good=ok and res~=false
 model:SetShown(good);shadow:SetShown(good)
 if good then Rotate(0)end
end

-- False plus a short reason, which /era afk prints; the automatic path stays silent.
-- Combat and restriction blocks set pending, so the AFK is retried when they end.
local function CanEnter(preview)
 if not Enabled()then return false end
 local target=root or UIParent
 if not(target and target.SetIgnoreParentAlpha)then M.unsupported=true;return false,"on this client"end
 if InCombat()or Yes(UnitAffectingCombat,"player")then M.pending=true;return false,BLOCKED[0]end
 local restricted=C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
 for t=0,3 do if Yes(restricted,t)then M.pending=true;return false,BLOCKED[t]end end
 if Yes(UnitIsDeadOrGhost,"player")then return false,"while you are dead"end
 if Yes(UnitOnTaxi,"player")then return false,"on a flight path"end
 if Yes(InCinematic)then return false,"during a cinematic"end
 if not UIParent:IsShown()then return false,"while the interface is hidden (Alt+Z)"end
 -- Never lay a mouse-enabled screen over the trainer's Train button.
 if ClassTrainerFrame and ClassTrainerFrame.IsShown and ClassTrainerFrame:IsShown()then return false,"while the trainer is open"end
 if not preview then
  if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()then return false end
  if ReadAFK()~=true then return false end
 end
 return true
end
function M:Enter(preview)
 if self.active then return end
 local ok,why=CanEnter(preview)
 if not ok then if preview and why then E:Print("The AFK screen can't open "..why..".")end;return end
 if not root then Build()end
 local alpha=UIParent:GetAlpha();if Secret(alpha)or type(alpha)~="number"or alpha<.1 then alpha=1 end
 self.savedAlpha=alpha
 self.preview=preview and true or false;self.since=GetTime();self.fade=0;self.tickLeft=0;self.last={}
 root:SetPropagateKeyboardInput(true)
 self:Layout();self:Fill();StartCamera()
 root:SetAlpha(0);root:Show();self.active=true
 SetupModel();self:Tick(true)
end
function M:Leave(reason)
 if not self.active then return end
 self.active=false
 UIParent:SetAlpha(self.savedAlpha or 1)
 root:Hide()
 RestoreCamera()
 if model.ClearModel then pcall(model.ClearModel,model)end
 self.preview=false;self.pending=false
 self.dismissed=reason~="back"
end
function M:Step(elapsed)
 if not self.active then return end
 elapsed=elapsed or 0
 if self.fade<FADE then
  self.fade=min(FADE,self.fade+elapsed);local k=self.fade/FADE
  root:SetAlpha(k);UIParent:SetAlpha(self.savedAlpha*(1-k))
 end
 if self.spin=="flip"then local d=self.rate*elapsed;self.yaw=self.yaw+d;pcall(FlipCameraYaw,d)end
 if self.zoomed<self.zoomGoal then
  local d=min(self.zoomGoal-self.zoomed,self.zoomGoal/ZOOM_TIME*elapsed);self.zoomed=self.zoomed+d;pcall(CameraZoomIn,d)
 end
 if model:IsShown()then self.turn=self.turn+self.sign*MODEL_TURN*elapsed;Rotate(self.turn)end
 hint:SetAlpha(.7+.3*math.sin(GetTime()*1.5))
 self.tickLeft=self.tickLeft-elapsed
 if self.tickLeft<=0 then self:Tick();self.tickLeft=TICK end
end

function M:OnFlags()
 local afk=ReadAFK()
 if afk==nil then return end
 if afk and not self.wasAFK then self.wasAFK=true;self.dismissed=false;self:Enter()
 elseif not afk then self.wasAFK=false;self.dismissed=false;self.pending=false;self:Leave("back")end
end
-- A fresh AFK transition is needed: never pops up after a login, reload or
-- turning the option on while already away.
function M:Sync(login)
 self.wasAFK=ReadAFK()==true;self.dismissed=self.wasAFK;self.pending=false
 if login then StopSpin()end
end
local function Resume()
 if M.pending and ReadAFK()==true and not M.dismissed then M.pending=false;M:Enter()end
end
-- A restriction ended: re-read a flag change that was secret meanwhile, then
-- retry an AFK the restriction blocked. Run later, because every restriction
-- reads inactive while ADDON_RESTRICTION_STATE_CHANGED is being dispatched.
local function AfterRestriction()M:OnFlags();Resume()end
local function BattlefieldConfirm()
 if not GetBattlefieldStatus or not GetMaxBattlefieldID then return false end
 local ok,n=pcall(GetMaxBattlefieldID)
 if not ok or Secret(n)or type(n)~="number"then return false end
 for i=1,n do
  local fine,status=pcall(GetBattlefieldStatus,i)
  if fine and not Secret(status)and status=="confirm"then return true end
 end
 return false
end
local function OnEvent(_,event,a,b)
 if event=="PLAYER_FLAGS_CHANGED"or event=="UNIT_PORTRAIT_UPDATE"then
  if not unitEvents and(Secret(a)or a~="player")then return end
  if event=="PLAYER_FLAGS_CHANGED"then M:OnFlags()elseif M.active then M:Fill()end
 elseif event=="PLAYER_ENTERING_WORLD"then M:Leave("world");M:Sync(a or b)
 elseif event=="PLAYER_REGEN_ENABLED"then if M.pending then C_Timer.After(1,Resume)end
 elseif event=="ADDON_RESTRICTION_STATE_CHANGED"then
  local inactive=Enum and Enum.AddOnRestrictionState and Enum.AddOnRestrictionState.Inactive or 0
  if not Secret(a)and not Secret(b)and RESTRICT[a]then
   if b~=inactive then M:Leave("restricted")else C_Timer.After(1,AfterRestriction)end
  end
 elseif event=="UPDATE_BATTLEFIELD_STATUS"then if M.active and BattlefieldConfirm()then M:Leave("popup")end
 elseif INFO_EVENTS[event]then if M.active then M:Fill()end
 elseif event=="DISPLAY_SIZE_CHANGED"or event=="UI_SCALE_CHANGED"then if M.active then M:Layout()end
 else M:Leave(event)end
end
local function Register()
 events:UnregisterAllEvents()
 unitEvents=events.RegisterUnitEvent~=nil
 for _,e in ipairs({"PLAYER_FLAGS_CHANGED","UNIT_PORTRAIT_UPDATE"})do
  if unitEvents then pcall(events.RegisterUnitEvent,events,e,"player")else pcall(events.RegisterEvent,events,e)end
 end
 for _,e in ipairs(OTHER_EVENTS)do pcall(events.RegisterEvent,events,e)end
 for _,e in ipairs(EXIT_EVENTS)do pcall(events.RegisterEvent,events,e)end
 for e in pairs(INFO_EVENTS)do pcall(events.RegisterEvent,events,e)end
end

function M:Preview()
 if self.comingSoon then E:Print("The AFK screen is coming soon.");return end
 if not E:GetSetting("enabled")then E:Print("EraUI is turned off, so the AFK screen can't open.");return end
 if not E:GetSetting("afkScreen")then E:Print("Turn on AFK Screen in /era > Text & Camera first.");return end
 if InCombat()then E:Print("The AFK screen can't open in combat.");return end
 -- The short delay lets the chat box give up keyboard focus first.
 C_Timer.After(.3,function()M:Enter(true)end)
end
function M:Refresh()
 if not events then return end
 if not Enabled()then self.on=false;self:Leave("off");events:UnregisterAllEvents();return end
 if not self.on then self.on=true;Register();self:Sync()end
 if self.active then self:Fill();self:Tick(true)end
end
function M:Initialize()
 if self.comingSoon then return end -- no frames, events or hooks at all
 events=CreateFrame("Frame");events:SetScript("OnEvent",OnEvent)
 if type(StaticPopup_Show)=="function"and hooksecurefunc then
  hooksecurefunc("StaticPopup_Show",function()if M.active then M:Leave("popup")end end)
 end
 self:Refresh()
end
