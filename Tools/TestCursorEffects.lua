-- Exercise the real effects module with native timing/frames at the API boundary.
local checks=0
local function Equal(a,b,label)checks=checks+1;assert(a==b,label..": expected "..tostring(b)..", got "..tostring(a))end
local function Near(a,b,label)checks=checks+1;assert(math.abs(a-b)<.00001,label)end
local secret={}
issecretvalue=function(v)return v==secret end
local frames,named={},{}
local methods={}
local function Frame(kind,name,parent)
 local f=setmetatable({kind=kind,parent=parent,scripts={},shown=true,alpha=1,events={}}, {__index=methods})
 frames[#frames+1]=f;if name then named[name]=f end;return f
end
function methods:CreateTexture()return Frame("Texture",nil,self)end
function methods:SetScript(k,v)self.scripts[k]=v end
function methods:Fire(event,...)if self.scripts[event]then self.scripts[event](self,...)end end
function methods:Show()self.shown=true end
function methods:Hide()self.shown=false end
function methods:SetShown(v)self.shown=not not v end
function methods:SetSize(w,h)self.w,self.h=w,h end
function methods:SetAlpha(v)self.alpha=v end
function methods:SetPoint(...)self.point={...}end
function methods:SetTexture(v)self.texture=v end
function methods:SetVertexColor(...)self.colour={...}end
function methods:SetSwipeColor(...)self.colour={...}end
function methods:EnableMouse(v)self.mouse=v end
function methods:SetReverse(v)self.reverse=v end
function methods:SetCooldown(start,total)self.start,self.total=start,total;self.duration=nil end
function methods:SetCooldownFromDurationObject(d)assert(d~=false);self.duration=d end
function methods:Clear()self.start,self.total,self.duration=nil,nil,nil;self:Fire("OnCooldownDone")end
function methods:RegisterEvent(e)self.events[e]=true end
function methods:RegisterUnitEvent(e,u)self.events[e]=u end
function methods:GetEffectiveScale()return self.scale or .5 end
for _,k in ipairs({"SetAllPoints","ClearAllPoints","SetFrameStrata","SetFrameLevel","SetDrawEdge","SetDrawBling","SetDrawSwipe","SetHideCountdownNumbers","SetSwipeTexture","SetSnapToPixelGrid","SetTexelSnappingBias"})do methods[k]=function()end end
CreateFrame=Frame;UIParent=Frame("Root")
local clock,x,y=10,300,200
GetTime=function()return clock end
GetCursorPosition=function()return x,y end
UnitClass=function()return "Druid","DRUID"end
RAID_CLASS_COLORS={DRUID={r=1,g=.49,b=.04}}
local castInfo,channelInfo
local function Info(info)
 if info=="error"then error("unavailable")end
 if info then return table.unpack(info)end
end
UnitCastingInfo=function()return Info(castInfo)end
UnitChannelInfo=function()return Info(channelInfo)end
local duration
UnitCastingDuration=function()return duration end
UnitChannelDuration=UnitCastingDuration
local timers={};C_Timer={After=function(_,fn)timers[#timers+1]=fn end}
local E={modules={},settings={enabled=true,cursorCastClassColour=true,cursorTrailClassColour=true}}
function E:RegisterModule(k,v)self.modules[k]=v end
function E:GetSetting(k)return self.settings[k]end
assert(loadfile("Core/CastTiming.lua"))("EraUI",E)
assert(loadfile("Modules/CursorEffects.lua"))("EraUI",E)
local M=E.modules.CursorEffects;M:Initialize()
local events=frames[#frames]
Equal(named.EraUICursorEffects,nil,"defaults allocate no visual frames or update loop")
E.settings.cursorCastRing=true;M:Refresh()
local host=named.EraUICursorEffects;local ring=named.EraUICursorCastRing;local cd=ring.cooldown
Equal(host.shown,false,"cast-only idle host hidden")
Equal(host.scripts.OnUpdate,nil,"cast-only idle has no polling")
castInfo={"Heal","Heal",1,10000,14000,false,7,false,123}
events:Fire("OnEvent","UNIT_SPELLCAST_START","player")
Equal(ring.shown,true,"cast starts ring")
Equal(cd.reverse,true,"casts fill elapsed sweep")
Equal(cd.start,10,"cast starts on game clock")
Equal(cd.total,4,"cast duration in seconds")
Equal(ring.point[4],600,"cursor x corrected for UI scale")
Equal(ring.point[5],400,"cursor y corrected for UI scale")
clock=11;castInfo[5]=15000;events:Fire("OnEvent","UNIT_SPELLCAST_DELAYED","player")
Equal(cd.total,5,"cast delay extends sweep")
events:Fire("OnEvent","UNIT_SPELLCAST_INTERRUPTED","player")
Equal(ring.shown,false,"interruption immediately hides ring")
Near(cd.colour[2],.49,"interruption never changes class colour to red")
Equal(host.scripts.OnUpdate,nil,"interruption stops idle loop")
castInfo=nil;channelInfo={"Channel","Channel",1,11000,16000,false,false,456}
events:Fire("OnEvent","UNIT_SPELLCAST_CHANNEL_START","player")
Equal(cd.reverse,false,"channels drain remaining sweep")
clock=12;channelInfo[5]=15000;events:Fire("OnEvent","UNIT_SPELLCAST_CHANNEL_UPDATE","player")
Equal(cd.total,5,"channel pushback retains original scale")
Equal(cd.start,10,"channel pushback uses shortened finish")
channelInfo=nil;events:Fire("OnEvent","UNIT_SPELLCAST_CHANNEL_UPDATE","player")
Equal(ring.shown,true,"one-frame missing channel update retains ring")
for _,fn in ipairs(timers)do fn()end;timers={}
Equal(ring.shown,false,"missing replacement channel clears ring next frame")
castInfo={secret,secret,secret,secret,secret,false,7,false,secret};duration={opaque=true}
M:UpdateCast()
Equal(cd.duration,duration,"restricted timestamps use native duration object")
Equal(ring.shown,true,"native duration ring visible")
duration=nil;M:UpdateCast()
Equal(ring.shown,false,"unavailable restricted timing hides ring")
castInfo="error";M:UpdateCast()
Equal(ring.shown,false,"API exception handled without UI error")
castInfo={"Heal","Heal",1,12000,13000,false,7,false,123};M:UpdateCast()
clock=13;host:Fire("OnUpdate",1)
Equal(ring.shown,false,"expired public cast hides immediately")
Equal(host.scripts.OnUpdate,nil,"expired cast releases frame update")
castInfo=nil;E.settings.cursorRing=true;E.settings.cursorRingSize=160;M:Refresh()
Equal(ring.w*.88>=166,true,"large existing cursor ring retains an outer gap")
E.settings.cursorCastRing=false;E.settings.cursorRing=false;E.settings.cursorTrail=true;M:Refresh()
Equal(host.shown,true,"trail works with both rings disabled")
local function VisibleDots()
 local out={}
 for _,f in ipairs(frames)do if f.texture and f.texture:find("CursorTrailDot",1,true)and f.shown then out[#out+1]=f end end
 return out
end
local allocated=#frames
host:Fire("OnUpdate",1/60)
x=x+15;clock=13.02;host:Fire("OnUpdate",1/60)
Equal(#VisibleDots()>0,true,"movement emits trail")
local dot=VisibleDots()[1]
Near(dot.colour[2],.49,"trail defaults to class colour")
local alpha=dot.alpha
clock=13.12;host:Fire("OnUpdate",.1)
Equal(dot.alpha<alpha,true,"stationary trail fades")
clock=14;host:Fire("OnUpdate",.9)
Equal(#VisibleDots(),0,"stationary trail disappears completely")
for i=1,200 do x=x+5;clock=clock+.02;host:Fire("OnUpdate",.02)end
Equal(#frames,allocated,"continuous motion reuses fixed texture pool")
x=x+500;host:Fire("OnUpdate",.02)
Equal(#VisibleDots(),0,"cursor warp does not create a screen-wide streak")
E.settings.cursorTrailClassColour=false;E.settings.cursorTrailColour="FF8000";M:Refresh()
local r,g,b=M:Colour("cursorTrail")
Equal(r,1,"custom trail red");Near(g,128/255,"custom trail green");Equal(b,0,"custom trail blue")
E.settings.cursorTrailColour="bad";r,g,b=M:Colour("cursorTrail")
Equal(g,1,"invalid saved colour falls back to white")
E.settings.enabled=false;M:Refresh()
Equal(host.shown,false,"master disable hides all effects")
Equal(host.scripts.OnUpdate,nil,"master disable removes update loop")
Equal(#VisibleDots(),0,"master disable clears old trail")
for _,f in ipairs(frames)do if f.kind~="Texture"and f~=UIParent and f~=events then Equal(f.mouse,false,"visual frames never intercept cursor input")end end
print("Cursor effect lifecycle checks passed: "..checks.." assertions.")
