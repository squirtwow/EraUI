local _,E=...
local M={};E:RegisterModule("CursorEffects",M)
local host,cast,trail,events,state
local Run
local clearing=false
local dots={}
local lastX,lastY,sample= nil,nil,0
local POOL=160
local nextDot=1
local path="Interface\\AddOns\\EraUI\\Media\\"
local function Public(v)return not(issecretvalue and issecretvalue(v))end
local function Number(key,default,low,high)
 local v=E:GetSetting(key)
 if not Public(v)then return default end
 v=tonumber(v)or default
 return math.max(low,math.min(high,v))
end
function M:Colour(prefix)
 if E:GetSetting(prefix.."ClassColour")then
  local _,class=UnitClass("player")
  if class=="PALADIN"then return .96,.55,.73 end
  local c=RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r,c.g,c.b end
 end
 local hex=E:GetSetting(prefix.."Colour")
 if type(hex)~="string"or not hex:match("^%x%x%x%x%x%x$")then hex="FFFFFF"end
 return tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255
end
local function Cursor()
 local x,y=GetCursorPosition()
 local scale=UIParent:GetEffectiveScale()
 if not Public(x)or not Public(y)or type(x)~="number"or type(y)~="number"or not scale or scale<=0 then return end
 return x/scale,y/scale
end
local function ClearTrail()
 lastX,lastY,sample=nil,nil,0
 for _,dot in ipairs(dots)do dot.born=nil;dot:Hide()end
end
local function StopCast()
 state=nil
 if cast then
  cast:Hide()
  if not clearing then clearing=true;cast.cooldown:Clear();clearing=false end
 end
end
local function Update(_,elapsed)
 local x,y=Cursor()
 if not x then StopCast();ClearTrail();Run();return end
 if state then
  if state.finish and GetTime()>=state.finish then StopCast();Run()
  else cast:ClearAllPoints();cast:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x,y)end
 end
 if not trail.enabled then return end
 local now=GetTime()
 sample=sample+elapsed
 if sample>=1/60 then
  sample=0
  if lastX then
   local dx,dy=x-lastX,y-lastY
   local distance=math.sqrt(dx*dx+dy*dy)
   -- Do not draw across cursor warps (including mouse-look recentering).
   if distance>300 then ClearTrail()
   elseif distance>=1 then
    local count=math.min(4,math.max(1,math.ceil(distance/math.max(2,trail.size*.4))))
    for i=1,count do
     local dot=dots[nextDot];nextDot=nextDot%POOL+1
     dot:ClearAllPoints();dot:SetPoint("CENTER",UIParent,"BOTTOMLEFT",lastX+dx*i/count,lastY+dy*i/count)
     dot.born=now;dot:SetSize(trail.size,trail.size);dot:SetAlpha(trail.opacity);dot:Show()
    end
   end
  end
  lastX,lastY=x,y
 end
 for _,dot in ipairs(dots)do
  if dot.born then
   local fade=1-(now-dot.born)/trail.life
   if fade<=0 then dot.born=nil;dot:Hide()
   else dot:SetAlpha(trail.opacity*fade*fade)end
  end
 end
end
Run=function()
 if not host then return end
 local active=state or trail.enabled
 host:SetScript("OnUpdate",active and Update or nil)
 host:SetShown(not not active)
end
local function Build()
 if host then return end
 host=CreateFrame("Frame","EraUICursorEffects",UIParent)
 host:SetAllPoints(UIParent);host:EnableMouse(false);host:SetFrameStrata("TOOLTIP");host:SetFrameLevel(98)
 trail={enabled=false}
 cast=CreateFrame("Frame","EraUICursorCastRing",host)
 cast:EnableMouse(false);cast:SetFrameLevel(101)
 local bg=cast:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetTexture(path.."CursorCastRing")
 bg:SetVertexColor(.08,.08,.08,.45)
 local cd=CreateFrame("Cooldown",nil,cast)
 cd:SetAllPoints();cd:EnableMouse(false);cd:SetDrawEdge(false);cd:SetDrawBling(false)
 cd:SetDrawSwipe(true);cd:SetHideCountdownNumbers(true);cd:SetSwipeTexture(path.."CursorCastRing",1,1,1,1)
 cast.cooldown=cd
 cd:SetScript("OnCooldownDone",function()if not clearing then StopCast();Run()end end)
 cast:Hide()
end
function M:UpdateCast(event,retry)
 if not E:GetSetting("enabled")or not E:GetSetting("cursorCastRing")then StopCast();Run();return end
 Build()
 local ok,name,_,_,startMS,endMS,_,_,_,spellID=pcall(UnitCastingInfo,"player")
 local channel=false
 if ok and Public(name)and not name then
  ok,name,_,_,startMS,endMS,_,_,spellID=pcall(UnitChannelInfo,"player");channel=true
 end
 if not ok or(Public(name)and not name)then
  if state and event=="UNIT_SPELLCAST_CHANNEL_UPDATE"and not retry then
   local previous=state
   C_Timer.After(0,function()if state==previous then M:UpdateCast(event,true)end end)
   return
  end
  StopCast();Run();return
 end
 local fresh=event=="UNIT_SPELLCAST_START"or event=="UNIT_SPELLCAST_CHANNEL_START"
 local snapshot=E.CastTiming.Snapshot(state,channel,name,startMS,endMS,spellID,fresh)
 local cd=cast.cooldown
 cd:SetReverse(not channel)
 local driven=false
 if snapshot then
  -- Keep the original channel scale after pushback, as on the normal cast bar.
  local start=channel and snapshot.finish-snapshot.total or snapshot.start
  cd:SetCooldown(start,snapshot.total);driven=true
 else
  local getter=channel and UnitChannelDuration or UnitCastingDuration
  if getter and cd.SetCooldownFromDurationObject then
   local success,duration=pcall(getter,"player")
   if success and(not Public(duration)or duration)then
    driven=pcall(cd.SetCooldownFromDurationObject,cd,duration)
   end
  end
 end
 if not driven then StopCast();Run();return end
 state=snapshot or {channel=channel}
 cast:Show();Run();Update(host,0)
end
function M:Refresh()
 local enabled=E:GetSetting("enabled")
 local useCast=enabled and E:GetSetting("cursorCastRing")
 local useTrail=enabled and E:GetSetting("cursorTrail")
 if not useCast and not useTrail then
  StopCast();ClearTrail()
  if host then trail.enabled=false;Run()end
  return
 end
 Build()
 local size=Number("cursorCastSize",60,24,200)
 if E:GetSetting("cursorRing")then size=math.max(size,(Number("cursorRingSize",48,24,160)+6)/.88)end
 cast:SetSize(size,size);cast:SetAlpha(Number("cursorCastOpacity",90,10,100)/100)
 local r,g,b=self:Colour("cursorCast");cast.cooldown:SetSwipeColor(r,g,b,1)
 ClearTrail();trail.enabled=not not useTrail
 trail.size=Number("cursorTrailSize",10,4,32)
 trail.opacity=Number("cursorTrailOpacity",55,10,100)/100
 trail.life=Number("cursorTrailLength",25,10,60)/100
 if useTrail then
  r,g,b=self:Colour("cursorTrail")
  for i=1,POOL do
   if not dots[i]then
    local dot=host:CreateTexture(nil,"ARTWORK");dot:SetTexture(path.."CursorTrailDot")
    dot:SetSnapToPixelGrid(false);dot:SetTexelSnappingBias(0);dot:Hide();dots[i]=dot
   end
   dots[i]:SetVertexColor(r,g,b,1)
  end
 end
 self:UpdateCast();Run()
end
function M:Initialize()
 events=CreateFrame("Frame")
 for _,event in ipairs({"UNIT_SPELLCAST_START","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_INTERRUPTED","UNIT_SPELLCAST_DELAYED","UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_CHANNEL_UPDATE","UNIT_SPELLCAST_CHANNEL_STOP"})do
  events:RegisterUnitEvent(event,"player")
 end
 for _,event in ipairs({"PLAYER_ENTERING_WORLD","UI_SCALE_CHANGED"})do events:RegisterEvent(event)end
 events:SetScript("OnEvent",function(_,event)
  if event=="PLAYER_ENTERING_WORLD"or event=="UI_SCALE_CHANGED"then self:Refresh()
  elseif event=="UNIT_SPELLCAST_INTERRUPTED"or event=="UNIT_SPELLCAST_FAILED"then StopCast();Run()
  else self:UpdateCast(event)end
 end)
 self:Refresh()
end
