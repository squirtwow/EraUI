-- Load the full ClassicBar module. Supply band geometry through its existing
-- private upvalues so the fixture need not manufacture the entire action UI.
-- Native managed layout must finish with the final cast position before a frame
-- can be rendered, rather than waiting for an addon polling tick.
local checks=0
local function Equal(actual,expected,label)
    checks=checks+1
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function Upvalue(fn,key,value)
    for index=1,200 do
        local name=debug.getupvalue(fn,index)
        if not name then break end
        if name==key then debug.setupvalue(fn,index,value);return end
    end
    error("missing fixture upvalue "..key)
end
local function Session()
    local env=setmetatable({}, {__index=_G});env._G=env
    local frames,combat,editing={},false,false
    local nativeWrite=false
    local secret={}
    local function Frame(name,top,left,right)
        local f={name=name,top=top or 0,left=left or 0,right=right or 1024,scale=1,
            shown=true,alpha=1,default=true,scripts={},hooks={},events={},moves=0,clears=0,bottom=0}
        function f:GetName()return self.name end
        function f:SetScript(key,fn)self.scripts[key]=fn end
        function f:HookScript(key,fn)
            self.hooks[key]=self.hooks[key]or{};table.insert(self.hooks[key],fn)
        end
        function f:RegisterEvent(event)self.events[event]=true end
        function f:RegisterUnitEvent(event)self.events[event]=true end
        function f:IsShown()return self.shown end
        function f:IsVisible()return self.shown end
        function f:IsProtected()return self.protected end
        function f:IsInitialized()return true end
        function f:IsInDefaultPosition()if self.defaultError then error("unavailable")end;return self.default end
        function f:IsAttachedToPlayerFrame()return self.attached end
        function f:GetEffectiveScale()return self.scale end
        function f:GetWidth()return self.right-self.left end
        function f:GetTop()return self.top end
        function f:GetLeft()return self.left end
        function f:GetRight()return self.right end
        function f:GetAlpha()return self.alpha end
        function f:GetBottom()return self.bottom end
        function f:GetPoint()return "BOTTOM",env.UIParent,"BOTTOM",0,self.bottom end
        function f:GetNumPoints()return 1 end
        function f:GetParent()return self.parent end
        function f:ClearAllPoints()
            assert(nativeWrite or not combat or not self.protected,"addon cleared protected anchors in combat")
            if not nativeWrite then self.clears=self.clears+1 end
        end
        function f:SetPoint(point,relative,relativePoint,x,y)
            assert(nativeWrite or not combat or not self.protected,"addon moved protected frame in combat")
            if not nativeWrite then self.moves=self.moves+1 end
            self.bottom=y
        end
        function f:Show()
            if self.shown then return end
            self.shown=true
            if self.scripts.OnShow then self.scripts.OnShow(self)end
            for _,fn in ipairs(self.hooks.OnShow or{})do fn(self)end
        end
        function f:Hide()self.shown=false end
        frames[#frames+1]=f
        return f
    end
    env.CreateFrame=function(_,name)return Frame(name)end
    env.InCombatLockdown=function()return combat end
    env.issecretvalue=function(value)return value==secret end
    env.EditModeManagerFrame={IsEditModeActive=function()return editing end}
    env.UIParent=Frame("UIParent",768,0,1024)
    local band=Frame("band",53,0,1024)
    local bar=Frame("PlayerCastingBarFrame");bar:Hide()
    env.PlayerCastingBarFrame=bar
    local manager=Frame("managed")
    local layout=Frame("bottomLayout")
    manager.BottomManagedLayoutContainer=layout
    bar.layoutParent=manager;bar.parent=layout
    local function NativeAnchor()
        nativeWrite=true
        bar:ClearAllPoints();bar:SetPoint("BOTTOM",env.UIParent,"BOTTOM",0,160)
        nativeWrite=false
    end
    function layout:Layout()if bar:IsShown()then NativeAnchor()end end
    function manager:Layout()end
    function manager:UpdateFrame()self:Layout();self.BottomManagedLayoutContainer:Layout()end
    bar:SetScript("OnShow",function()manager:UpdateFrame()end)
    function bar:ApplySystemAnchor()NativeAnchor()end
    function bar:UpdateSystemSettingBarSize()NativeAnchor()end
    local hooks={}
    env.hooksecurefunc=function(object,key,callback)
        hooks[object]=hooks[object]or{}
        hooks[object][key]=(hooks[object][key]or 0)+1
        local original=assert(object[key])
        object[key]=function(...)
            local result=original(...);callback(...);return result
        end
    end
    local mod
    local ns={db={},RegisterModule=function(_,module)mod=module end}
    function ns.HookMethod(object,key,callback)
        if object and type(object[key])=="function"then env.hooksecurefunc(object,key,callback)end
    end
    local E={Classic=ns,settings={enabled=true,advancedCastBar=false}}
    function E:GetSetting(key)return self.settings[key]end
    assert(loadfile("Classic/ClassicBar.lua","t",env))("EraUI",E)
    Upvalue(mod.apply,"art",band);Upvalue(mod.apply,"active",true)
    local function Event(event)
        for _,f in ipairs(frames)do if f.events[event]then f.scripts.OnEvent(f,event)end end
    end
    Event("PLAYER_ENTERING_WORLD")
    return {env=env,E=E,bar=bar,band=band,layout=layout,manager=manager,frames=frames,hooks=hooks,
        event=Event,frame=Frame,secret=secret,combat=function(value)combat=value end,
        editing=function(value)editing=value end,active=function(value)Upvalue(mod.apply,"active",value)end}
end

local s=Session()
s.bar:Show()
Equal(s.bar.bottom,79,"first cast positioned before Show returns, without polling")
for _=1,8 do
    s.bar:Hide();s.bar:Show()
    Equal(s.bar.bottom,79,"successive Wrath/heal casts never render at native height")
end
s.layout:Layout()
Equal(s.bar.bottom,79,"mid-cast native managed layout corrected synchronously")
s.bar:ApplySystemAnchor()
Equal(s.bar.bottom,79,"native anchor refresh corrected synchronously")
s.bar.scale=2;s.bar:UpdateSystemSettingBarSize()
Equal(s.bar.bottom,39.5,"cast bar scale accounted for immediately")
s.bar.scale=1
s.env.UIParent.scale=.64;s.band.scale=.64;s.bar.scale=.64
s.event("UI_SCALE_CHANGED")
Equal(s.bar.bottom,79,"UI scaling keeps the same logical band clearance")
s.env.UIParent.scale=1;s.band.scale=1;s.bar.scale=1

-- Missing optional bars must not stop the scan before later pet/status rows.
local pet=s.frame("PetActionBar",130,400,600);s.env.PetActionBar=pet
s.event("PET_BAR_UPDATE")
Equal(s.bar.bottom,156,"pet row clears missing optional action bars")
pet.default=false;s.event("PET_BAR_UPDATE")
Equal(s.bar.bottom,79,"custom-positioned pet row excluded")
pet.default=true;pet.isDragging=true;s.event("PET_BAR_UPDATE")
Equal(s.bar.bottom,79,"dragged row excluded")
pet.isDragging=false;pet.left=800;pet.right=1000;s.event("PET_BAR_UPDATE")
Equal(s.bar.bottom,79,"off-centre row excluded")
pet.left=400;pet.right=600;pet.alpha=0;s.event("PET_BAR_UPDATE")
Equal(s.bar.bottom,79,"invisible row excluded")
pet.alpha=1;pet.top=300;s.event("PET_BAR_UPDATE")
Equal(s.bar.bottom,79,"distant row excluded")
pet.top=s.secret;s.event("PET_BAR_UPDATE")
Equal(s.bar.bottom,79,"secret row geometry excluded without arithmetic")
pet:Hide()

local row=s.frame("MultiBarBottomLeft",220,0,1024)
row.actionButtons={s.frame("firstButton",90,400,436),s.frame("lastButton",90,564,600)}
s.env.MultiBarBottomLeft=row;s.event("UPDATE_BONUS_ACTIONBAR")
Equal(s.bar.bottom,116,"uses actual button bounds instead of oversized row container")
row:Hide()
s.bar.scale=0;s.event("UI_SCALE_CHANGED")
Equal(s.bar.bottom,116,"zero cast scale avoids invalid coordinates")
s.bar.scale=s.secret;s.event("UI_SCALE_CHANGED")
Equal(s.bar.bottom,116,"restricted cast scale is not divided")
s.bar.scale=1;s.event("UI_SCALE_CHANGED")
Equal(s.bar.bottom,79,"valid geometry resumes normal positioning")

local function NativeUntouched(label)
    local moves=s.bar.moves
    s.layout:Layout()
    Equal(s.bar.bottom,160,label.." keeps native position")
    Equal(s.bar.moves,moves,label.." receives no addon anchor writes")
end
s.bar.default=false;NativeUntouched("custom Edit Mode placement");s.bar.default=true
s.editing(true);NativeUntouched("Edit Mode open");s.editing(false)
s.bar.isInEditMode=true;NativeUntouched("cast bar Edit Mode preview");s.bar.isInEditMode=false
s.bar.isDragging=true;NativeUntouched("cast bar dragging");s.bar.isDragging=false
s.bar.attached=true;NativeUntouched("cast bar attached to player frame");s.bar.attached=false
s.E.settings.advancedCastBar=true;NativeUntouched("advanced cast bar enabled");s.E.settings.advancedCastBar=false
s.bar.defaultError=true;NativeUntouched("unreadable position policy");s.bar.defaultError=false
s.bar.default=s.secret;NativeUntouched("restricted position policy");s.bar.default=true
s.active(false);NativeUntouched("Classic action bar disabled");s.active(true)
s.E.settings.enabled=false;NativeUntouched("addon disabled");s.E.settings.enabled=true
s.combat(true);s.bar.protected=true;NativeUntouched("protected bar in combat")
s.bar.protected=false;s.layout:Layout()
Equal(s.bar.bottom,79,"unprotected cast bar remains stable during combat")
s.combat(false);s.bar.protected=true;s.event("PLAYER_REGEN_ENABLED")
Equal(s.bar.bottom,79,"out-of-combat positioning allowed")

local moves=s.bar.moves
for _=1,5 do s.event("ADDON_LOADED");s.event("PLAYER_ENTERING_WORLD")end
Equal(s.bar.moves,moves,"unchanged geometry avoids redundant anchor writes")
Equal(s.hooks[s.layout].Layout,1,"one post-layout hook per container")
Equal(#s.bar.hooks.OnShow,1,"one OnShow hook per cast bar")
local newLayout=s.frame("replacementLayout")
function newLayout:Layout()
    s.bar.bottom=160
end
s.manager.BottomManagedLayoutContainer=newLayout
s.bar:Hide();s.bar:Show()
Equal(s.bar.bottom,79,"OnShow discovers a replaced managed container immediately")
newLayout:Layout()
Equal(s.bar.bottom,79,"replacement container also corrects mid-cast layouts")
Equal(s.hooks[newLayout].Layout,1,"replacement container hooked once")
s.bar:Hide();moves=s.bar.moves;s.event("UI_SCALE_CHANGED")
Equal(s.bar.moves,moves,"hidden cast bar is not positioned")
for _,f in ipairs(s.frames)do
    if f.events.PLAYER_ENTERING_WORLD then Equal(f.scripts.OnUpdate,nil,"cast positioning has no polling timer")end
end
print("Cast-bar position checks passed: "..checks.." assertions.")
