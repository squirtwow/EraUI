-- Exercise both real cast-bar paths with damage-shortened channel timestamps
-- and a deliberately stale Duration API. A channel must never use both clocks.
local checks=0
local function equal(a,b,label)checks=checks+1;assert(a==b,label..": "..tostring(a).." ~= "..tostring(b))end
local all,timers={},{}
local now,start,finish,name,spell=105,100000,120000,"Taming Rod",99
local secret={}
issecretvalue=function(v)return v==secret end
GetTime=function()return now end
InCombatLockdown=function()return false end
UnitClass=function()return "Hunter","HUNTER"end
UnitCastingInfo=function()end
UnitChannelInfo=function()if name then return name,name,1,start,finish,false,false,spell end end
C_Timer={After=function(_,fn)timers[#timers+1]=fn end}
Enum={StatusBarTimerDirection={RemainingTime=1,ElapsedTime=2},StatusBarInterpolation={Immediate=0}}
local durationCalls,timerCalls=0,0
UnitChannelDuration=function()
 durationCalls=durationCalls+1
 return {GetElapsedDuration=function()return 5 end,GetRemainingDuration=function()return 15 end,GetTotalDuration=function()return 20 end}
end
local methods={}
local function Frame(parent)
 local f=setmetatable({parent=parent,scripts={},hooks={},shown=false,alpha=1},{__index=methods})
 all[#all+1]=f;return f
end
function methods:SetScript(event,fn)self.scripts[event]=fn end
function methods:HookScript(event,fn)self.hooks[event]=self.hooks[event]or{};table.insert(self.hooks[event],fn)end
function methods:Fire(event,...)
 if self.scripts[event]then self.scripts[event](self,...)end
 for _,fn in ipairs(self.hooks[event]or{})do fn(self,...)end
end
function methods:Show()local change=not self.shown;self.shown=true;if change then self:Fire("OnShow")end end
function methods:Hide()local change=self.shown;self.shown=false;if change then self:Fire("OnHide")end end
function methods:IsShown()return self.shown end
function methods:SetAlpha(a)self.alpha=a end
function methods:GetAlpha()return self.alpha end
function methods:GetParent()return self.parent end
function methods:SetSize(w,h)self.w,self.h=w,h end
function methods:GetWidth()return self.w or 195 end
function methods:GetHeight()return self.h or 13 end
function methods:GetFrameLevel()return 1 end
function methods:IsMouseOver()return false end
function methods:GetStringWidth()return 0 end
function methods:SetText(t)self.text=t end
function methods:SetFormattedText(format,...)self.text=string.format(format,...)end
function methods:CreateTexture()return Frame(self)end
function methods:CreateFontString()return Frame(self)end
function methods:GetStatusBarTexture()self.fill=self.fill or Frame(self);return self.fill end
function methods:SetMinMaxValues(low,high)self.low,self.high=low,high end
function methods:SetValue(value)self.value=value end
function methods:SetTimerDuration(duration)timerCalls=timerCalls+1;self:SetValue(duration:GetRemainingDuration())end
function methods:RegisterEvent(event)self.events=self.events or{};self.events[event]=true end
methods.RegisterUnitEvent=methods.RegisterEvent
function methods:GetAtlas()return nil end
for _,method in ipairs({"SetFrameStrata","SetFrameLevel","SetMovable","SetClampedToScreen","SetStatusBarTexture","SetStatusBarColor",
 "SetPoint","ClearAllPoints","SetAllPoints","SetBackdrop","SetBackdropColor","SetBackdropBorderColor","SetJustifyH",
 "SetWidth","SetHeight","RegisterForClicks","RegisterForDrag","EnableMouse","EnableMouseWheel","SetFont","SetNonSpaceWrap",
 "SetShadowColor","SetShadowOffset","SetTexture","SetTexCoord","SetColorTexture","SetBlendMode","SetVertexColor","SetFontObject","SetAtlas","SetTextColor"})do
 methods[method]=function()end
end
hooksecurefunc=function(t,key,fn)
 if type(t)=="string"then fn=key;key=t;t=_G end
 local old=t[key];t[key]=function(...)old(...);fn(...)end
end
CreateFrame=function(_,global,parent)local f=Frame(parent);if global then _G[global]=f end;return f end
CreateColor=function(r,g,b)return {GetRGB=function()return r,g,b end}end
UIParent=Frame()
GameFontHighlight={GetFont=function()return "Font"end}
EraUIDB={}
local settings={enabled=true,advancedCastBar=true}
local E={modules={}}
function E:RegisterModule(key,value)self.modules[key]=value end
function E:GetSetting(key)return settings[key]end
function E:SaveSettings()end
assert(loadfile("Core/CastTiming.lua"))("EraUI",E)
assert(loadfile("Modules/AdvancedCastBar.lua"))("EraUI",E)
local M=E.modules.AdvancedCastBar;M:Initialize()
local bar=EraUIAdvancedCastBar
equal(bar.shown,true,"active channel shown")
equal(bar.high,20,"initial full channel scale")
equal(bar.value,15,"initial remaining time")
equal(durationCalls,0,"public timestamps never mix in stale duration API")
now=105.5;finish=117000;M:Refresh("UNIT_SPELLCAST_CHANNEL_UPDATE")
equal(bar.high,20,"damage keeps original denominator")
equal(bar.value,11.5,"damage removes real remaining channel time")
now=106;bar:Fire("OnUpdate",.5)
equal(bar.value,11,"next frame continues from new endpoint")
M:Refresh("UNIT_SPELLCAST_CHANNEL_UPDATE");equal(bar.value,11,"duplicate update cannot jump backwards")
equal(timerCalls,0,"native timer cannot overwrite corrected fill on next frame")
local before=bar.value;name=nil;M:Refresh("UNIT_SPELLCAST_CHANNEL_UPDATE")
equal(bar.shown,true,"one-frame channel info gap does not flash native bar")
equal(bar.value,before,"one-frame info gap preserves current progress")
name="Taming Rod";finish=114000
local pending=timers;timers={};for _,fn in ipairs(pending)do fn()end
equal(bar.value,8,"deferred update consumes authoritative channel endpoint")
equal(bar.high,20,"repeated damage does not renormalize channel")
name=nil;M:Refresh("UNIT_SPELLCAST_CHANNEL_STOP")
equal(bar.shown,false,"channel stop hides immediately")
name="Taming Rod";start=106000;finish=116000;M:Refresh("UNIT_SPELLCAST_CHANNEL_START")
equal(bar.high,10,"new same-name channel resets its baseline")
equal(bar.value,10,"new channel starts full")
-- Restricted timestamps use the native duration path, without comparing them.
start,finish=secret,secret;M:Refresh("UNIT_SPELLCAST_CHANNEL_START")
equal(timerCalls,1,"restricted timing retains duration fallback")
equal(bar.shown,true,"duration-backed channel remains visible")

-- Actual Classic player-bar hooks preserve native events and cosmetic ownership.
settings.advancedCastBar=false
name,start,finish,now="Taming Rod",100000,120000,105
PlayerCastingBarFrame=Frame(UIParent)
local native=PlayerCastingBarFrame
native.Text,native.Spark=Frame(native),Frame(native)
function native:HandleCastStart()self:SetMinMaxValues(0,(finish-start)/1000);self:SetValue(finish/1000-now);self:Show()end
function native:HandleChannelUpdateDelayed()self:SetMinMaxValues(0,(finish-start)/1000);self:SetValue(finish/1000-now)end
function native:FinishSpell()end
function native:HandleCastStop()end
function native:HandleInterruptOrSpellFailed()end
local modules={}
local ns={RegisterModule=function(key,value)modules[key]=value end,SetTex=function()end,
 HookMethod=function(frame,method,fn)if frame[method]then hooksecurefunc(frame,method,fn)end end}
E.Classic=ns
assert(loadfile("Classic/CastBars.lua"))("EraUI",E)
modules.castBars.apply()
native:HandleCastStart("UNIT_SPELLCAST_CHANNEL_START")
equal(native.high,20,"Classic channel initial scale")
now=106;finish=117000;native:HandleChannelUpdateDelayed()
equal(native.high,20,"Classic damage keeps full channel scale")
equal(native.value,11,"Classic damage uses new endpoint")
now=107;native:Fire("OnUpdate",1)
equal(native.value,10,"Classic channel advances using same clock")
native:HandleInterruptOrSpellFailed();native:SetValue(0);native:Fire("OnUpdate",1)
equal(native.value,0,"interrupted Classic channel cannot be redrawn")
finish=127000;start=107000;native:HandleCastStart("UNIT_SPELLCAST_CHANNEL_START")
native:HandleCastStop();native:SetValue(0);native:Fire("OnUpdate",1)
equal(native.value,0,"stopped Classic channel cannot be redrawn")
print("Channel timing checks passed: "..checks.." assertions.")
