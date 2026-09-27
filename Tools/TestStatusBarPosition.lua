-- Exercise real ClassicBar layout and native-style anchor resets. No OnUpdate
-- polling runs between a native position change and the visible-position check.
local checks=0
local function Equal(actual,expected,label)
    checks=checks+1;assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function Upvalue(fn,key,value)
    for i=1,200 do
        local name,old=debug.getupvalue(fn,i)
        if not name then break end
        if name==key then if value~=nil then debug.setupvalue(fn,i,value)end;return old end
    end
    error("missing upvalue "..key)
end
local frames,combat,editing,secret={},false,false,{}
local native=false
local function Frame(name)
    local f={name=name,points={},width=100,height=10,scale=1,shown=true,scripts={},hooks={},events={},writes=0}
    function f:GetName()return self.name end
    function f:GetParent()return UIParent end
    function f:GetNumPoints()return #self.points end
    function f:GetPoint(i)return table.unpack(self.points[i or 1]or{})end
    function f:ClearAllPoints()
        assert(native or not combat or not self.protected,"protected anchors cleared in combat")
        self.points={}
    end
    function f:SetPoint(...)
        assert(native or not combat or not self.protected,"protected anchors written in combat")
        if not native then self.writes=self.writes+1 end
        local p={...}
        for i,old in ipairs(self.points)do if old[1]==p[1]then self.points[i]=p;return end end
        self.points[#self.points+1]=p
    end
    function f:SetAllPoints(relative)
        self.points={{"TOPLEFT",relative,"TOPLEFT",0,0},{"BOTTOMRIGHT",relative,"BOTTOMRIGHT",0,0}}
    end
    function f:SetScale(scale)self.scale=scale end
    function f:GetScale()return self.scale end
    function f:GetEffectiveScale()return self.scale end
    function f:GetTop()return 53 end
    function f:GetLeft()return 0 end
    function f:GetRight()return self.width end
    function f:GetBottom()return self.points[1] and self.points[1][5] or 0 end
    function f:IsInDefaultPosition()return true end
    function f:GetWidth()return self.width end
    function f:GetHeight()return self.height end
    function f:SetSize(w,h)
        assert(not combat or not self.protected,"protected size written in combat")
        self.width,self.height=w,h
    end
    function f:IsProtected()return self.protected end
    function f:IsShown()return self.shown end
    function f:GetAlpha()return 1 end
    function f:SetShown(shown)self.shown=shown end
    function f:Show()
        if self.shown then return end
        self.shown=true
        if self.scripts.OnShow then self.scripts.OnShow(self)end
        for _,fn in ipairs(self.hooks.OnShow or{})do fn(self)end
    end
    function f:Hide()self.shown=false end
    function f:SetScript(key,fn)self.scripts[key]=fn end
    function f:HookScript(key,fn)self.hooks[key]=self.hooks[key]or{};table.insert(self.hooks[key],fn)end
    function f:RegisterEvent(event)self.events[event]=true end
    function f:SetBarTexture()end
    function f:ApplySystemAnchor()self:ClearAllPoints();self:SetPoint("TOP",UIParent,"TOP",0,-5)end
    frames[#frames+1]=f;return f
end
UIParent=Frame("UIParent")
UIParent.width=1024
CreateFrame=function(_,name)return Frame(name)end
InCombatLockdown=function()return combat end
issecretvalue=function(value)return value==secret end
EditModeManagerFrame={IsEditModeActive=function()return editing end}
local function Native(fn,...)
    -- Hooks are addon writes even when the original call came from Blizzard.
    native=true;fn(...);native=false
end
local installed={}
hooksecurefunc=function(frame,key,callback)
    local old=frame[key]
    frame[key]=function(...)
        old(...)
        local wasNative=native;native=false;callback(...);native=wasNative
    end
end
local module
local ns={db={},Capture=function()return {}end,RegisterModule=function(_,mod)module=mod end}
function ns.HookMethod(frame,key,callback)
    if type(frame[key])~="function"then return end
    installed[frame]=installed[frame]or{}
    if installed[frame][key]then return end
    installed[frame][key]=true;hooksecurefunc(frame,key,callback)
end
local E={Classic=ns,settings={enabled=true,advancedCastBar=false}}
function E:GetSetting(key)return self.settings[key]end
assert(loadfile("Classic/ClassicBar.lua"))("EraUI",E)
local band=Frame("EraUIBand");band.maxLevel={}
Upvalue(module.apply,"art",band);Upvalue(module.apply,"active",true)
local layout=Upvalue(Upvalue(module.apply,"Layout"),"LayoutStatusBars")
local layoutOne=Upvalue(layout,"LayoutStatusBar")
local width,scale=1024,1
Upvalue(layoutOne,"ArtWidth",function()return width end)
Upvalue(layoutOne,"BandNow",function()return scale end)
Upvalue(layoutOne,"RecolorStatus",function()end)
Upvalue(layoutOne,"HookRestedState",function()end)
Upvalue(layoutOne,"EnsureStrips",function()return {}end)
local function Container(name,xp)
    local c=Frame(name);local bar=Frame(name.."Bar");bar.StatusBar=Frame(name.."Fill")
    if xp then bar.ExhaustionTick={fcuiSkinned=true}end
    c.bars={bar};return c
end
MainStatusTrackingBarContainer=Container("MainStatusTrackingBarContainer",true)
SecondaryStatusTrackingBarContainer=Container("SecondaryStatusTrackingBarContainer",false)
SecondaryStatusTrackingBarContainer.bars[1].shown=false
local xp=MainStatusTrackingBarContainer
local rep=SecondaryStatusTrackingBarContainer
layout()
local function Anchored(frame,point,relative,relativePoint,label)
    Equal(frame:GetNumPoints(),1,label.." has one anchor")
    local p,r,rp=frame:GetPoint()
    Equal(p,point,label.." point");Equal(r,relative,label.." relative frame");Equal(rp,relativePoint,label.." relative point")
end
Native(function()xp:ApplySystemAnchor()end)
Anchored(xp,"TOP",band,"TOP","first native XP reset corrected before return")
for _=1,12 do
    Native(function()xp:ClearAllPoints();xp:SetPoint("TOP",UIParent,"TOP",0,-5)end)
    Anchored(xp,"TOP",band,"TOP","repeated cast/damage-style layout reset")
end
-- Exercise both actual placement paths in the same native managed-layout call.
PlayerCastingBarFrame=Frame("PlayerCastingBarFrame");PlayerCastingBarFrame:Hide()
local managed=Frame("managed");managed.BottomManagedLayoutContainer=Frame("bottomLayout")
PlayerCastingBarFrame.layoutParent=managed
function managed.BottomManagedLayoutContainer:Layout()
    xp:ApplySystemAnchor()
    PlayerCastingBarFrame:ClearAllPoints();PlayerCastingBarFrame:SetPoint("BOTTOM",UIParent,"BOTTOM",0,160)
end
PlayerCastingBarFrame:SetScript("OnShow",function()Native(function()managed.BottomManagedLayoutContainer:Layout()end)end)
for _,f in ipairs(frames)do if f.events.PLAYER_ENTERING_WORLD then f.scripts.OnEvent(f,"PLAYER_ENTERING_WORLD")end end
for _=1,6 do
    PlayerCastingBarFrame:Hide();PlayerCastingBarFrame:Show()
    Anchored(xp,"TOP",band,"TOP","XP steady at cast start")
    Equal(PlayerCastingBarFrame:GetBottom(),79,"cast bar retains its stable clearance")
end
combat=true
Native(function()managed.BottomManagedLayoutContainer:Layout()end)
Equal(PlayerCastingBarFrame:GetBottom(),79,"mid-cast combat layout preserves cast clearance")
Native(function()xp:ApplySystemAnchor()end)
Anchored(xp,"TOP",band,"TOP","unprotected XP container stable in combat")
Native(function()xp.bars[1]:ApplySystemAnchor();xp.bars[1].StatusBar:SetAllPoints(UIParent)end)
Anchored(xp.bars[1],"TOPLEFT",xp,"TOPLEFT","XP child stays inside container")
Anchored(xp.bars[1].StatusBar,"TOPLEFT",xp.bars[1],"TOPLEFT","XP fill stays inside child")
xp.protected=true;local writes=xp.writes
Native(function()xp:ApplySystemAnchor()end)
Equal(select(2,xp:GetPoint()),UIParent,"protected combat position left to native code")
Equal(xp.writes,writes,"no protected combat anchor writes")
layout() -- Existing size/skin fallback must also respect combat protection.
combat=false;xp.protected=false
for _,f in ipairs(frames)do if f.events.PLAYER_REGEN_ENABLED then f.scripts.OnEvent(f,"PLAYER_REGEN_ENABLED")end end
Anchored(xp,"TOP",band,"TOP","deferred anchors restored at combat exit")
editing=true;Native(function()xp:ApplySystemAnchor()end)
Equal(select(2,xp:GetPoint()),UIParent,"Edit Mode can control native anchors")
editing=false;layout()
xp.isDragging=true;Native(function()xp:ApplySystemAnchor()end)
Equal(select(2,xp:GetPoint()),UIParent,"dragging not interrupted")
xp.isDragging=false;layout()
for _,key in ipairs({"inactive","disabled"})do
    if key=="inactive"then Upvalue(module.apply,"active",false)else E.settings.enabled=false end
    Native(function()xp:ApplySystemAnchor()end)
    Equal(select(2,xp:GetPoint()),UIParent,key.." gives native ownership back")
    Upvalue(module.apply,"active",true);E.settings.enabled=true;layout()
end
-- Container roles can swap when tracking reputation. The latest completed
-- EraUI layout, not the first-ever position, must be kept.
xp.bars[1].ExhaustionTick=nil
rep.bars[1].ExhaustionTick={fcuiSkinned=true};rep.bars[1].shown=true
width=850;scale=.8;layout()
Native(function()xp:ApplySystemAnchor();rep:ApplySystemAnchor()end)
Anchored(xp,"BOTTOM",band,"TOP","rep moves to upper strip")
Anchored(rep,"TOP",band,"TOP","XP stays in lower strip after role swap")
Equal(xp.scale,.8,"new legitimate band scale accepted")
local before=xp.writes
Native(function()xp:SetPoint("BOTTOM",band,"TOP",0,2)end)
Equal(xp.writes,before,"unchanged native anchor causes no addon rewrite")
Native(function()xp.points={{secret,UIParent,"TOP",0,0}};xp:SetPoint(secret,UIParent,"TOP",0,0)end)
Equal(xp:GetPoint(),secret,"restricted geometry is not compared")
layout()
Equal(xp:GetNumPoints(),1,"normal layout resumes after restricted geometry")
print("Status-bar position checks passed: "..checks.." assertions.")
