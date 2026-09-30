local _,E=...
local M={};E:RegisterModule("AFKScreen",M)
-- AFK Screen: while you are away the interface and the minimap fade out and
-- EraUI shows its banner, your character, an info card and a famous line for
-- your class while the camera slowly circles. Leaving only sets UIParent
-- alpha, touches our own frames, shows the minimap it hid and makes camera
-- calls, so it is safe in combat.
-- UIParent is never hidden or shown.
-- Coming soon: while this is true the AFK Screen never runs, whatever is
-- saved, and its /era card shows SOON.
M.comingSoon=false
local floor,min,max,abs,format,sin,tan,pi,sqrt=math.floor,math.min,math.max,math.abs,string.format,math.sin,math.tan,math.pi,math.sqrt
local FONT=STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local TITLE_FONT="Fonts\\MORPHEUS.TTF"
local MEDIA="Interface\\AddOns\\EraUI\\Media\\"
local GLOW,BORDER=MEDIA.."LogoGlow.tga",MEDIA.."TooltipBorder.tga"
-- The banner: the EraUI letters and violet swirl of the CurseForge art, with no
-- box. Three 512x256 layers with the art in the top 243 rows: the letters'
-- blurred black shadow, the swirl with the letters cut out, and grey letters
-- tinted in your class colour.
local BANNER_SHADOW,BANNER_BASE,BANNER_LETTERS=MEDIA.."EraUIBannerShadow.tga",MEDIA.."EraUIBannerBase.tga",MEDIA.."EraUIBannerLetters.tga"
local BANNER_ROWS,BANNER_ASPECT=243/256,512/243
local QUOTE_FONT=MEDIA.."Fonts\\IMFellEnglish-Italic.ttf"
local OPEN,CLOSE,DASH="\226\128\156","\226\128\157","\226\128\148 " -- curly quote marks, and the dash before the speaker
local WHITE="Interface\\Buttons\\WHITE8X8"
local CLASS_ICONS="Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
-- EraUI's own look, from the logo art: deep navy, arcane violet and silver.
local NAVY,VIOLET,SILVER,MUTED,LAVENDER={.02,.035,.08},{.58,.4,1},{.9,.92,.97},{.6,.64,.76},{.76,.7,1}
local GREY,PARCHMENT={.7,.7,.7},{.93,.89,.78}
local SPEED_SLOW,SPEED_NORMAL=3,6      -- degrees a second (2 min / 1 min a circle)
local FADE=0.6                          -- seconds, fade in only; leaving is instant
local ZOOM_TIME,ZOOM_SHARE,ZOOM_MAX,ZOOM_MIN_START=20,.3,8,6
local TICK=.25
local BANNER_SHARE,BANNER_MIN,BANNER_MAX,BANNER_DROP=.235,100,300,3 -- the banner ends this far down the screen; its height clamped; the shadow's drop
local GLOW_SIZE,GLOW_WIDE,BREATH=2.3,1.9,5 -- glow: its height per banner height, its width per its height; seconds a breath
-- The class quote: sized with the screen (20 at 768 tall), clamped, and never
-- under QUOTE_EM of its size wide a line, so the longest quote takes two lines.
-- It shows QUOTE_EVERY seconds, fading out and in over QUOTE_FADE.
local QUOTE_SIZE,QUOTE_MIN,QUOTE_MAX,QUOTE_EM=20,14,28,22
local QUOTE_SHARE,QUOTE_WIDE,QUOTE_CLEAR=.45,720,16 -- width: share of the screen, cap, room kept clear of the character and the card
local QUOTE_EVERY,QUOTE_FADE=40,.8
local SHADOW_W,SHADOW_H,SHADOW_A=.32,.06,.55 -- the ground shadow: shares of the character's height, and its alpha
-- The character never turns: one 3/4 turn toward the screen centre, set once.
-- It stands about 63% of the screen tall with its feet near the bottom.
local MODEL_YAW,MODEL_SHARE,FEET_SHARE=.6,.63,.05 -- radians (+ faces screen right); shares of the screen height
local SCENE_FOV,FRAME_TIMEOUT,FRAME_RETRY=.6,3,.1   -- radians; seconds to wait for the scene before the fallback; seconds between tries
local CAM_SCALE,CAM_FEET,CAM_FILL=.8,.1,.775        -- fallback PlayerModel: camera distance, and where the feet land and how much it fills (estimates)
local BLEND_NONE=Enum and Enum.ModelBlendOperation and Enum.ModelBlendOperation.None or 0
local LIGHT_DIRECTIONAL=Enum and Enum.ModelLightType and Enum.ModelLightType.Directional or 0
local LIGHT={-.8,-.3,-.5} -- from the camera, a little above and to the right, so the face is lit
do local n=sqrt(LIGHT[1]^2+LIGHT[2]^2+LIGHT[3]^2);for i=1,3 do LIGHT[i]=LIGHT[i]/n end end
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
-- The info card: header lines, their heights, and the card's measures.
local ORDER={"name","info","guild","zone"}
local LINE_H={name=25,info=16,guild=16,zone=15}
local CARD_W,PAD,ICON,ICON_X,TEXT_X=380,14,46,20,76
local events,root,model,scene,actor,shadow,crest,card,accent,icon,divider,hint,quoteBox,quoteText,quoteBy,unitEvents
local L,pool={},{}
local random=math.random
M.last={};M.yaw,M.zoomed,M.zoomGoal,M.sign,M.rate=0,0,0,1,0

local function Secret(v)return issecretvalue and issecretvalue(v)end
local function Clean(v)if v==nil or Secret(v)then return nil end;return v end
-- True when every value is a readable, finite number.
local function Nums(...)
 for i=1,select("#",...)do local v=select(i,...);if Secret(v)or type(v)~="number"or v~=v or v==math.huge or v==-math.huge then return false end end
 return true
end
-- pcall of o:m(...), false when the method is missing.
local function Call(o,m,...)
 local fn=o and o[m];if type(fn)~="function"then return false end
 return pcall(fn,o,...)
end
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
-- none: the colour for a secret or unknown class (grey unless given).
local function ClassColour(class,none)
 class=Clean(class)
 if class=="PALADIN"then return .96,.55,.73 end
 local c=class and((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])or(RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
 if c then return c.r,c.g,c.b end
 none=none or GREY;return none[1],none[2],none[3]
end
-- A font file the client refuses falls back to the normal font, a little smaller.
local function SetFont(t,size,flags,font,fallback)
 if t:SetFont(font or FONT,size,flags or "")==false then t:SetFont(FONT,fallback or(font and size-2)or size,flags or "")end
end
local function Text(parent,size,c,flags,font)
 local t=parent:CreateFontString(nil,"OVERLAY");SetFont(t,size,flags,font)
 t:SetShadowColor(0,0,0,1);t:SetShadowOffset(1,-1);t:SetJustifyH("LEFT");t:SetTextColor(c[1],c[2],c[3])
 return t
end
-- A soft wash of colour c, alpha a1 at the bottom or left and a2 at the top or right.
local function Gradient(t,orient,c,a1,a2)
 t:SetTexture(WHITE)
 if CreateColor and t.SetGradient and pcall(t.SetGradient,t,orient,CreateColor(c[1],c[2],c[3],a1),CreateColor(c[1],c[2],c[3],a2))then return end
 if t.SetGradientAlpha and pcall(t.SetGradientAlpha,t,orient,c[1],c[2],c[3],a1,c[1],c[2],c[3],a2)then return end
 t:SetColorTexture(c[1],c[2],c[3],(a1+a2)/2)
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

-- A plain ModelScene (no Blizzard mixin, and no mouse, so the root keeps every
-- click) with one actor, its own camera and a light from the front. Nil when
-- the client can't make one: the PlayerModel stands in then.
local function MakeScene()
 local ok,s=pcall(CreateFrame,"ModelScene",nil,root)
 if not ok or type(s)~="table"then return end
 s:SetSize(560,700);s:SetPoint("BOTTOMLEFT",root,"BOTTOMLEFT",40,0);s:SetFrameLevel(2);s:SetAlpha(0)
 local a
 if type(s.CreateActor)=="function"then
  ok,a=pcall(s.CreateActor,s)
  if not ok or type(a)~="table"then ok,a=pcall(s.CreateActor,s,nil,"ModelSceneActorTemplate")end
 end
 if not ok or type(a)~="table"or type(a.SetModelByUnit)~="function"or type(s.Project3DPointTo2D)~="function"then s:Hide();return end
 Call(s,"SetCameraFieldOfView",SCENE_FOV);Call(s,"SetCameraNearClip",.1);Call(s,"SetCameraFarClip",200);Call(s,"ClearFog")
 Call(s,"SetLightVisible",true);Call(s,"SetLightType",LIGHT_DIRECTIONAL)
 Call(s,"SetLightAmbientColor",.7,.7,.74);Call(s,"SetLightDiffuseColor",.95,.93,1)
 Call(s,"SetLightDirection",LIGHT[1],LIGHT[2],LIGHT[3])
 return s,a
end

local function Build()
 root=CreateFrame("Frame","EraUIAFKScreen",UIParent)
 root:SetAllPoints(UIParent);root:SetFrameStrata("TOOLTIP");root:SetFrameLevel(1)
 root:SetIgnoreParentAlpha(true);root:EnableMouse(true);root:EnableMouseWheel(true)
 root:EnableKeyboard(true);root:SetPropagateKeyboardInput(true);root:Hide()
 -- Cinematic shading from the top and bottom edges, so the text reads over any scene.
 local top=root:CreateTexture(nil,"BACKGROUND");top:SetPoint("TOPLEFT",root,"TOPLEFT",0,0);top:SetPoint("TOPRIGHT",root,"TOPRIGHT",0,0)
 top:SetHeight(260);Gradient(top,"VERTICAL",NAVY,0,.88)
 local bottom=root:CreateTexture(nil,"BACKGROUND");bottom:SetPoint("BOTTOMLEFT",root,"BOTTOMLEFT",0,0);bottom:SetPoint("BOTTOMRIGHT",root,"BOTTOMRIGHT",0,0)
 bottom:SetHeight(230);Gradient(bottom,"VERTICAL",NAVY,.85,0)
 M.shades={top=top,bottom=bottom}
 -- The character: a ModelScene actor framed from its own bounds, or the
 -- PlayerModel when that fails. Both are sized at creation.
 model=CreateFrame("PlayerModel",nil,root);model:SetSize(430,620);model:SetPoint("BOTTOMLEFT",root,"BOTTOMLEFT",40,0);model:SetFrameLevel(2);model:Hide()
 if model.SetPortraitZoom then pcall(model.SetPortraitZoom,model,0)end
 scene,actor=MakeScene()
 -- A small, soft shadow at the character's feet. Our own art the client
 -- refuses (a file added after the game started) stays hidden, never a
 -- placeholder: ok says whether it loaded.
 shadow=root:CreateTexture(nil,"BORDER");shadow:SetSize(140,26);shadow:SetPoint("CENTER",root,"BOTTOMLEFT",260,40)
 shadow.ok=shadow:SetTexture(GLOW)~=false;shadow:SetVertexColor(0,0,0,SHADOW_A);shadow:Hide()
 -- The crest, top centre: the EraUI banner on a slowly breathing violet glow,
 -- stretched wide like the banner.
 crest=CreateFrame("Frame",nil,root);crest:SetSize(330,157);crest:SetPoint("TOP",root,"TOP",0,-24);crest:SetFrameLevel(3)
 local glow=crest:CreateTexture(nil,"BACKGROUND");glow:SetSize(686,361);glow:SetPoint("CENTER",crest,"CENTER",0,0)
 glow:SetShown(glow:SetTexture(GLOW)~=false);glow:SetVertexColor(VIOLET[1],VIOLET[2],VIOLET[3],1);glow:SetAlpha(.6)
 -- Shadow, swirl, then the letters in your class colour (Fill tints them).
 local drop=crest:CreateTexture(nil,"BORDER");drop:SetPoint("TOPLEFT",crest,"TOPLEFT",0,-BANNER_DROP);drop:SetPoint("BOTTOMRIGHT",crest,"BOTTOMRIGHT",0,-BANNER_DROP)
 local okDrop=drop:SetTexture(BANNER_SHADOW)~=false;drop:SetVertexColor(0,0,0,.9)
 local base=crest:CreateTexture(nil,"ARTWORK");base:SetAllPoints(crest);local okBase=base:SetTexture(BANNER_BASE)~=false
 local letters=crest:CreateTexture(nil,"OVERLAY");letters:SetAllPoints(crest);local okLetters=letters:SetTexture(BANNER_LETTERS)~=false;letters:SetVertexColor(SILVER[1],SILVER[2],SILVER[3])
 for _,t in ipairs({drop,base,letters})do t:SetTexCoord(0,1,0,BANNER_ROWS)end -- the art's clear bottom rows cut off
 -- Half a banner would look broken: unless the swirl and the letters both load, only the title and rules show.
 local art=okBase and okLetters;drop:SetShown(art and okDrop);base:SetShown(art);letters:SetShown(art)
 local title=Text(crest,22,SILVER,"OUTLINE",TITLE_FONT);title:SetWidth(600);title:SetJustifyH("CENTER")
 title:SetPoint("TOP",crest,"BOTTOM",0,-2);title:SetText("Away from keyboard")
 local ruleL=crest:CreateTexture(nil,"ARTWORK");ruleL:SetSize(130,1);ruleL:SetPoint("TOPRIGHT",title,"BOTTOM",0,-8);Gradient(ruleL,"HORIZONTAL",VIOLET,0,.8)
 local ruleR=crest:CreateTexture(nil,"ARTWORK");ruleR:SetSize(130,1);ruleR:SetPoint("TOPLEFT",title,"BOTTOM",0,-8);Gradient(ruleR,"HORIZONTAL",VIOLET,.8,0)
 crest.glow,crest.drop,crest.base,crest.letters,crest.title,crest.rules=glow,drop,base,letters,title,{ruleL,ruleR}
 -- The info card, lower right: EraUI's dark tooltip panel and grey bevel.
 card=CreateFrame("Frame",nil,root,"BackdropTemplate");card:SetSize(CARD_W,200)
 card:SetPoint("BOTTOMRIGHT",root,"BOTTOMRIGHT",-40,64);card:SetFrameLevel(3)
 if card.SetBackdrop then
  card:SetBackdrop({bgFile=WHITE,edgeFile=BORDER,edgeSize=16,insets={left=3,right=3,top=3,bottom=3}})
  card:SetBackdropColor(NAVY[1],NAVY[2],NAVY[3],.86);card:SetBackdropBorderColor(1,1,1,1)
 end
 accent=card:CreateTexture(nil,"ARTWORK");accent:SetWidth(3)
 accent:SetPoint("TOPLEFT",card,"TOPLEFT",4,-5);accent:SetPoint("BOTTOMLEFT",card,"BOTTOMLEFT",4,5);accent:SetColorTexture(.7,.7,.7,1)
 icon=card:CreateTexture(nil,"ARTWORK");icon:SetSize(ICON,ICON);icon:SetPoint("TOPLEFT",card,"TOPLEFT",ICON_X,-PAD)
 icon.ok=icon:SetTexture(CLASS_ICONS)~=false
 local function Line(key,size,c,flags,width)
  local t=Text(card,size,c,flags);t:SetWidth(width);t:SetWordWrap(false);L[key]=t;return t
 end
 -- The name has a dark outline so pale class colours still read.
 Line("name",22,{1,1,1},"OUTLINE",290);Line("info",13,SILVER,nil,290);Line("guild",13,LAVENDER,nil,290);Line("zone",12,MUTED,nil,290)
 divider=card:CreateTexture(nil,"ARTWORK");divider:SetHeight(1);Gradient(divider,"HORIZONTAL",VIOLET,.7,.05)
 Line("away",22,SILVER,"OUTLINE",220);Line("date",12,MUTED,nil,220)
 local clock=Line("clock",22,SILVER,"OUTLINE",130);clock:SetJustifyH("RIGHT")
 local label=Line("clockLabel",11,MUTED,nil,130);label:SetJustifyH("RIGHT");label:SetText("Local time")
 -- The hint, bottom centre, above everything else.
 local front=CreateFrame("Frame",nil,root);front:SetAllPoints(root);front:SetFrameLevel(4)
 hint=Text(front,13,SILVER,"OUTLINE");hint:SetWidth(500);hint:SetJustifyH("CENTER");hint:SetPoint("BOTTOM",root,"BOTTOM",0,22)
 hint:SetText("Move or press any key to come back")
 -- The class quote above the hint, italic in parchment, and who said it under
 -- it. Its own frame fades both lines between quotes.
 quoteBox=CreateFrame("Frame",nil,front);quoteBox:SetAllPoints(front);quoteBox:SetFrameLevel(4);quoteBox:Hide()
 quoteText=Text(quoteBox,QUOTE_SIZE,PARCHMENT,"OUTLINE",QUOTE_FONT);quoteText:SetWidth(600);quoteText:SetJustifyH("CENTER");quoteText:SetWordWrap(true)
 Call(quoteText,"SetMaxLines",2)
 quoteBy=Text(quoteBox,11,MUTED);quoteBy:SetWidth(600);quoteBy:SetJustifyH("CENTER");quoteBy:SetWordWrap(false)
 quoteBy:SetPoint("BOTTOM",hint,"TOP",0,10);quoteText:SetPoint("BOTTOM",quoteBy,"TOP",0,4)
 M.root,M.model,M.scene,M.actor,M.shadow,M.crest,M.card,M.accent,M.icon,M.divider,M.hint,M.lines=root,model,scene,actor,shadow,crest,card,accent,icon,divider,hint,L
 M.quoteBox,M.quoteText,M.quoteBy=quoteBox,quoteText,quoteBy
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

-- Header lines stack under each other beside the class icon; the divider, the
-- time away and the clock follow, and the card grows to fit.
local function Stack()
 local x=icon:IsShown()and TEXT_X or ICON_X
 local y,prev=PAD,nil
 for _,key in ipairs(ORDER)do
  local t=L[key]
  if t:IsShown()then
   t:ClearAllPoints()
   if prev then t:SetPoint("TOPLEFT",prev,"BOTTOMLEFT",0,-3)else t:SetPoint("TOPLEFT",card,"TOPLEFT",x,-PAD)end
   y=y+LINE_H[key]+(prev and 3 or 0);prev=t
  end
 end
 if icon:IsShown()then y=max(y,PAD+ICON)end
 local d=y+12
 divider:ClearAllPoints();divider:SetPoint("TOPLEFT",card,"TOPLEFT",ICON_X,-d);divider:SetPoint("TOPRIGHT",card,"TOPRIGHT",-18,-d)
 L.away:ClearAllPoints();L.away:SetPoint("TOPLEFT",card,"TOPLEFT",ICON_X,-(d+12))
 L.date:ClearAllPoints();L.date:SetPoint("TOPLEFT",L.away,"BOTTOMLEFT",0,-5)
 L.clock:ClearAllPoints();L.clock:SetPoint("TOPRIGHT",card,"TOPRIGHT",-18,-(d+12))
 L.clockLabel:ClearAllPoints();L.clockLabel:SetPoint("TOPRIGHT",L.clock,"BOTTOMRIGHT",0,-5)
 card:SetHeight(d+12+25+5+14+PAD)
end

-- The PlayerModel stand-in: its own camera frames the character, so its
-- size and feet are estimates. Turned once, never again.
local function PlaceFallbackShadow()
 shadow:ClearAllPoints();shadow:SetPoint("CENTER",model,"BOTTOM",0,model:GetHeight()*CAM_FEET)
 shadow:SetSize(M.charH*SHADOW_W,M.charH*SHADOW_H)
end
local function UseFallback()
 M.modelPath="model";M.framed=true
 if scene then scene:SetAlpha(0);scene:Hide();Call(actor,"ClearModel")end
 -- Shown before it gets its unit: a model given its unit while hidden can stay blank.
 model:Show()
 local ok,res=pcall(model.SetUnit,model,"player")
 local good=ok and(Secret(res)or res~=false)
 if not good then model:Hide();shadow:Hide();return end
 shadow:SetShown(shadow.ok)
 if model.SetCamDistanceScale then pcall(model.SetCamDistanceScale,model,CAM_SCALE)end
 if model.SetRotation then pcall(model.SetRotation,model,MODEL_YAW,false)elseif model.SetFacing then pcall(model.SetFacing,model,MODEL_YAW)end
 PlaceFallbackShadow()
end
-- Runs after the root is shown: a model given its unit while hidden can stay blank.
local function SetupModel()
 shadow:Hide();model:Hide()
 M.framed,M.frameWait,M.frameLeft=false,0,FRAME_TIMEOUT
 if not scene or M.sceneSlow then UseFallback();return end
 M.modelPath="scene";scene:SetAlpha(0);scene:Show()
 Call(actor,"ClearModel")
 local ok,res=Call(actor,"SetModelByUnit","player",true,true,false,true) -- sheathed, dressed, native form
 if not ok or(not Secret(res)and res==false)then UseFallback();return end
 Call(actor,"SetUseCenterForOrigin",true,true,false) -- centred across, feet at z 0
 Call(actor,"SetPosition",0,0,0);Call(actor,"SetPitch",0);Call(actor,"SetRoll",0)
 Call(actor,"SetYaw",MODEL_YAW) -- the only turn it ever gets
 Call(actor,"SetAnimationBlendOperation",BLEND_NONE);Call(actor,"SetAnimation",0)
end
-- The actor's box, times its scale: six numbers, or two vectors as documented.
local function Bounds()
 local ok,a,b,c,d,e,f=Call(actor,"GetActiveBoundingBox")
 if not ok or Secret(a)or Secret(b)then return end
 if type(a)=="table"and type(b)=="table"then
  if type(a.GetXYZ)~="function"or type(b.GetXYZ)~="function"then return end
  local ok1,x1,y1,z1=pcall(a.GetXYZ,a);local ok2,x2,y2,z2=pcall(b.GetXYZ,b)
  if not ok1 or not ok2 then return end
  a,b,c,d,e,f=x1,y1,z1,x2,y2,z2
 end
 if not Nums(a,b,c,d,e,f)or f<=c then return end
 local okS,k=Call(actor,"GetScale");if not okS or not Nums(k)or k<=0 then k=1 end
 return a*k,b*k,c*k,d*k,e*k,f*k
end
local function Project(x,y,z)
 local ok,px,py=pcall(scene.Project3DPointTo2D,scene,x,y,z)
 if ok and Nums(px,py)then return px,py end
end
-- The camera sits in front of the actor on +X, level, looking back at it.
local function Aim(dist,z)Call(scene,"SetCameraPosition",dist,0,z);Call(scene,"SetCameraOrientationByYawPitchRoll",pi,0,0)end
-- Frames the character from its real bounds: MODEL_SHARE of the screen tall
-- (less if it would be wider than the scene), feet FEET_SHARE up, and the
-- shadow at the projected feet. True when done, nil to try again, "fail" when
-- the scene's answers can't be trusted (the PlayerModel stands in then).
local function FrameModel()
 local okL,loaded=Call(actor,"IsLoaded")
 if not okL or Secret(loaded)or loaded~=true then return end
 local x1,y1,z1,x2,y2,z2=Bounds();if not x1 then return end
 local okE,es=pcall(scene.GetEffectiveScale,scene)
 local sw,sh=scene:GetWidth(),scene:GetHeight()
 if not okE or not Nums(es,sw,sh)or es<=0 or sw<=0 or sh<=0 then return "fail"end
 sw,sh=sw*es,sh*es
 local tall,r=z2-z1,sqrt(max(x1*x1,x2*x2)+max(y1*y1,y2*y2))
 local want=min(M.charH*es,r>0 and sw*tall/(2.2*r)or math.huge) -- pixels tall
 local okF,fov=Call(scene,"GetCameraFieldOfView");if not okF or not Nums(fov)or fov<=0 or fov>=3 then fov=SCENE_FOV end
 local zc=(z1+z2)/2
 local dist=tall*sh/want/(2*tan(fov/2)) -- first guess
 Aim(dist,zc)
 -- The point the camera looks at must land on the scene's centre, or its units are unknown.
 local cx,cy=Project(0,0,zc);if not cx then return end
 if abs(cx-sw/2)>sw*.05 or abs(cy-sh/2)>sh*.05 then return "fail"end
 local _,fy=Project(0,0,z1);local _,hy=Project(0,0,z2)
 if not fy or not hy or hy<=fy then return "fail"end
 dist=dist*(hy-fy)/want;Aim(dist,zc) -- the projected height follows 1/distance
 _,fy=Project(0,0,z1);_,hy=Project(0,0,z2)
 if not fy or not hy or hy<=fy then return "fail"end
 -- Raise the camera until the feet stand near the bottom of the screen.
 local feet=M.feetY*es
 Aim(dist,zc+(fy-feet)*tall/(hy-fy))
 local fx;fx,fy=Project(0,0,z1);_,hy=Project(0,0,z2)
 if not fx or not hy or abs(fy-feet)>2 or abs(hy-fy-want)>want*.03 or hy>sh+2 then return "fail"end
 shadow:ClearAllPoints();shadow:SetPoint("CENTER",scene,"BOTTOMLEFT",fx/es,fy/es)
 shadow:SetSize(want/es*SHADOW_W,want/es*SHADOW_H);shadow:SetShown(shadow.ok)
 M.frame={feet=fy/es,height=(hy-fy)/es}
 return true
end
function M:StepModel(elapsed)
 if self.modelPath~="scene"or self.framed then return end
 self.frameLeft=self.frameLeft-elapsed;self.frameWait=self.frameWait-elapsed
 if self.frameWait>0 then return end
 self.frameWait=FRAME_RETRY
 local ok,done=pcall(FrameModel)
 if ok and done==true then self.framed=true;scene:SetAlpha(1)
 elseif not ok or done=="fail"or self.frameLeft<=0 then
  if ok and done==nil then self.sceneSlow=true end -- timed out: the PlayerModel from now on, until a reload
  UseFallback()
 end
end
local function ClearModels()
 if scene then scene:SetAlpha(0);Call(actor,"ClearModel")end
 if model.ClearModel then pcall(model.ClearModel,model)end
 model:Hide();shadow:Hide();M.modelPath=nil
end

function M:Layout()
 if not root then return end
 local w,h=root:GetWidth(),root:GetHeight()
 if not Nums(w,h)or w<=0 or h<=0 then w,h=UIParent:GetWidth(),UIParent:GetHeight()end
 if not Nums(w,h)or w<=0 or h<=0 then w,h=1024,768 end
 self.shades.top:SetHeight(h*.34);self.shades.bottom:SetHeight(h*.3)
 -- The banner ends just under a quarter of the way down, within sensible limits
 -- (and never over 60% of the screen wide); the glow is stretched to it.
 local gap=max(16,h*.03)
 local bh=max(BANNER_MIN,min(BANNER_MAX,h*BANNER_SHARE-gap,w*.6/BANNER_ASPECT));local bw=bh*BANNER_ASPECT
 self.bannerW,self.bannerH=bw,bh
 crest:SetSize(bw,bh);crest:ClearAllPoints();crest:SetPoint("TOP",root,"TOP",0,-gap)
 crest.glow:SetSize(bh*GLOW_SIZE*GLOW_WIDE,bh*GLOW_SIZE)
 SetFont(crest.title,max(20,min(34,floor(bh*.14+.5))),"OUTLINE",TITLE_FONT)
 -- The character stands on the left with its feet near the bottom.
 self.charH,self.feetY=h*MODEL_SHARE,h*FEET_SHARE
 local left,sh=max(16,w*.03),h*.8
 local sw=min(w*.42,sh)
 if scene then scene:SetSize(sw,sh);scene:ClearAllPoints();scene:SetPoint("BOTTOMLEFT",root,"BOTTOMLEFT",left,0)end
 local mh=self.charH/CAM_FILL
 model:SetSize(mh*.7,mh);model:ClearAllPoints();model:SetPoint("BOTTOMLEFT",root,"BOTTOMLEFT",left,self.feetY-mh*CAM_FEET)
 local right=max(24,w*.03)
 card:ClearAllPoints();card:SetPoint("BOTTOMRIGHT",root,"BOTTOMRIGHT",-right,max(56,h*.08))
 -- The quote, centred: 45% of the screen wide at most, and clear of the
 -- character (its shadow's reach either side of the scene's middle) and of the
 -- card. With no room for two lines at a readable size it stays hidden.
 local cx=w/2
 local qw=min(w*QUOTE_SHARE,QUOTE_WIDE,2*(cx-left-sw/2-self.charH*SHADOW_W/2-QUOTE_CLEAR),2*(w-right-CARD_W-cx-QUOTE_CLEAR))
 local size=min(QUOTE_MAX,floor(h*QUOTE_SIZE/768+.5),floor(qw/QUOTE_EM))
 self.quoteRoom,self.quoteWidth,self.quoteSize=size>=QUOTE_MIN,qw,size
 if self.quoteRoom then
  SetFont(quoteText,size,"OUTLINE",QUOTE_FONT,floor(size*.8+.5));quoteText:SetWidth(qw)
  SetFont(quoteBy,max(10,min(15,floor(h*11/768+.5))));quoteBy:SetWidth(qw)
 end
 if self.active then self:SyncQuote()end
 -- A new size frames the character again.
 if self.modelPath=="scene"then self.framed,self.frameWait,self.frameLeft=false,0,FRAME_TIMEOUT
 elseif self.modelPath=="model"then PlaceFallbackShadow()end
end
function M:Fill()
 if not root then return end
 local first,surname=UnitName("player");first,surname=Clean(first),Clean(surname)
 local name=first or ""
 if surname and surname~="" and not E:GetSetting("hideSecondaryNames")then name=name.." "..surname end
 local className,class=UnitClass("player");class=Clean(class);self.class=class
 local r,g,b=ClassColour(class)
 L.name:SetText(name);L.name:SetTextColor(r,g,b);accent:SetColorTexture(r,g,b,1)
 crest.letters:SetVertexColor(ClassColour(class,SILVER)) -- a secret or unknown class keeps silver letters
 local coords=icon.ok and class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
 if type(coords)=="table"and Nums(coords[1],coords[2],coords[3],coords[4])then icon:SetTexCoord(coords[1],coords[2],coords[3],coords[4]);icon:Show()else icon:Hide()end
 local level=Clean(UnitLevel("player"));local race=Clean((UnitRace("player")))
 local parts={}
 if type(level)=="number"then parts[1]=format("Level %d",level)end
 if race and race~="" then parts[#parts+1]=race end
 className=Clean(className);if className and className~="" then parts[#parts+1]=className end
 L.info:SetText(table.concat(parts," "))
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
 Stack()
end
local function Set(line,text)if M.last[line]~=text then M.last[line]=text;line:SetText(text)end end

-- The class quote: your class's lines, for either faction, topped up with
-- the General lines when fewer than three. The pool is filled as the screen
-- opens; a line is never picked twice in a row.
local function AddLines(list)
 if type(list)~="table"then return end
 for _,q in ipairs(list)do if type(q)=="table"then pool[#pool+1]=q end end
end
local function FillPool(class)
 for i=#pool,1,-1 do pool[i]=nil end
 local data=E.AFKQuotes;if type(data)~="table"then return end
 AddLines(class and data[class])
 if #pool<3 then AddLines(data.GENERAL)end
end
local function Pick(last)
 local n=#pool;if n==0 then return end
 local skip;for i=1,n do if pool[i]==last then skip=i end end
 if skip and n>1 then local i=random(n-1);if i>=skip then i=i+1 end;return pool[i]end
 return pool[random(n)]
end
function M:NextQuote()
 local q=Pick(self.quote);if not q then return false end
 self.quote=q
 quoteText:SetText(OPEN..q.text..CLOSE);quoteBy:SetText(DASH..q.speaker..", "..q.where)
 return true
end
-- Shows a quote when the option is on and there is room, else hides it.
function M:SyncQuote()
 if not(E:GetSetting("afkShowQuote")and self.quoteRoom)then self.quoteOn=false;quoteBox:Hide();return end
 if self.quoteOn then return end
 FillPool(self.class)
 if not self:NextQuote()then quoteBox:Hide();return end
 self.quoteOn,self.quoteAge,self.quoteAlpha=true,QUOTE_FADE,1
 quoteBox:SetAlpha(1);quoteBox:Show()
end
function M:Tick(force)
 if not root then return end
 if force then self.last={}end
 Set(L.away,"Away for "..M.FormatAway(GetTime()-(self.since or GetTime())))
 local t=date("*t")
 Set(L.clock,M.FormatClock(t.hour,t.min,E:GetSetting("afk24Hour")))
 if L.date:IsShown()then Set(L.date,M.FormatDate(t))end
end

-- The Minimap draws its arrow, blips and quest rings itself and ignores
-- UIParent alpha, so it is hidden while the screen shows: only when it is
-- shown, readable and not protected. It comes back only if we hid it, so a
-- minimap you turned off stays off; a protected one waits for combat to end.
local function Protected(f)
 local ok,a,b=Call(f,"IsProtected")
 if not ok or Secret(a)or Secret(b)then return true end
 return(a or b)and true or false
end
function M:HideMap()
 local map=Minimap
 if self.mapHidden or type(map)~="table"or InCombat()then return end
 local ok,shown=Call(map,"IsShown")
 if not ok or Secret(shown)or not shown or Protected(map)then return end
 if Call(map,"Hide")then self.mapHidden=true end
end
function M:ShowMap()
 if not self.mapHidden then self.mapPending=false;return end
 local map=Minimap
 if type(map)~="table"then self.mapHidden,self.mapPending=false,false;return end
 if InCombat()and Protected(map)then self.mapPending=true;return end
 self.mapHidden,self.mapPending=false,false
 Call(map,"Show")
end

local function StopSpin()
 if MoveViewLeftStop then pcall(MoveViewLeftStop)end
 if MoveViewRightStop then pcall(MoveViewRightStop)end
end
local function StartCamera()
 M.yaw,M.zoomed,M.zoomGoal=0,0,0
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
 -- Edit Mode's selection boxes ignore the fade and would show through.
 local editMode=EditModeManagerFrame
 if type(editMode)=="table"and Yes(editMode.IsEditModeActive,editMode)then return false,"while Edit Mode is open"end
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
 self:Layout();self:Fill();self.quoteOn=false;self:SyncQuote();StartCamera()
 root:SetAlpha(0);root:Show();self.active=true
 SetupModel();self:Tick(true)
end
function M:Leave(reason)
 if not self.active then return end
 self.active=false
 UIParent:SetAlpha(self.savedAlpha or 1)
 self:ShowMap()
 root:Hide()
 RestoreCamera()
 ClearModels()
 self.preview=false;self.pending=false;self.quoteOn=false
 self.dismissed=reason~="back"
end
function M:Step(elapsed)
 if not self.active then return end
 elapsed=elapsed or 0
 if self.fade<FADE then
  self.fade=min(FADE,self.fade+elapsed);local k=self.fade/FADE
  root:SetAlpha(k);UIParent:SetAlpha(self.savedAlpha*(1-k))
  if self.fade>=FADE then self:HideMap()end -- the interface is gone: now the minimap's own marks
 end
 if self.spin=="flip"then local d=self.rate*elapsed;self.yaw=self.yaw+d;pcall(FlipCameraYaw,d)end
 if self.zoomed<self.zoomGoal then
  local d=min(self.zoomGoal-self.zoomed,self.zoomGoal/ZOOM_TIME*elapsed);self.zoomed=self.zoomed+d;pcall(CameraZoomIn,d)
 end
 self:StepModel(elapsed)
 local now=GetTime()
 crest.glow:SetAlpha(.62+.22*sin(now*2*pi/BREATH))
 hint:SetAlpha(.7+.3*sin(now*1.5))
 -- A new quote every QUOTE_EVERY seconds: fade out, change, fade in.
 if self.quoteOn then
  local age=self.quoteAge+elapsed
  if age>=QUOTE_EVERY then age=0;self:NextQuote()end
  self.quoteAge=age
  local a=max(0,min(1,age/QUOTE_FADE,(QUOTE_EVERY-age)/QUOTE_FADE))
  if a~=self.quoteAlpha then self.quoteAlpha=a;quoteBox:SetAlpha(a)end
 end
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
 elseif event=="PLAYER_REGEN_ENABLED"then
  if M.mapPending then M:ShowMap()end
  if M.pending then C_Timer.After(1,Resume)end
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
 if not Enabled()then
  self.on=false;self:Leave("off");events:UnregisterAllEvents()
  -- A minimap still waiting for combat to end comes back then.
  if self.mapPending then pcall(events.RegisterEvent,events,"PLAYER_REGEN_ENABLED")end
  return
 end
 if not self.on then self.on=true;Register();self:Sync()end
 if self.active then self:Fill();self:Tick(true);self:SyncQuote()end
end
function M:Initialize()
 if self.comingSoon then return end -- no frames, events or hooks at all
 events=CreateFrame("Frame");events:SetScript("OnEvent",OnEvent)
 if type(StaticPopup_Show)=="function"and hooksecurefunc then
  hooksecurefunc("StaticPopup_Show",function()if M.active then M:Leave("popup")end end)
 end
 self:Refresh()
end
