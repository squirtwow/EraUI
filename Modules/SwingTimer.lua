local _,EraUI=...
local Module={}
EraUI:RegisterModule("SwingTimer",Module)
local bar,control,edge,text,resizePanel
local editing=false
local timers={}
local offbar,offtext
local nativeAlpha={}
local unavailable=false
local classes={ROGUE=true,DRUID=true,WARRIOR=true,PALADIN=true,SHAMAN=true,HUNTER=true}
local function Public(value) return not issecretvalue or not issecretvalue(value) end
local function Options()
    EraUIDB.swingTimerPosition=EraUIDB.swingTimerPosition or {x=0,y=-198,width=160,height=20}
    local p=EraUIDB.swingTimerPosition
    p.x=tonumber(p.x) or 0;p.y=tonumber(p.y) or -198
    p.width=math.max(80,math.min(360,tonumber(p.width) or 160))
    p.height=math.max(12,math.min(40,tonumber(p.height) or 20))
    return p
end
local function Enabled()
    local _,class=UnitClass("player")
    return EraUI:GetSetting("enabled") and EraUI:GetCharSetting("swingTimer") and classes[class]
end
local function Layout()
    local p=Options()
    if offbar then offbar:SetHeight(p.height) end
    bar:SetSize(p.width,p.height);bar:ClearAllPoints();bar:SetPoint("CENTER",UIParent,"CENTER",p.x,p.y)
    EraUI:SaveSettings()
end
local function Save()
    bar:StopMovingOrSizing()
    local x,y=bar:GetCenter();local cx,cy=UIParent:GetCenter()
    local p=Options();p.x=x-cx;p.y=y-cy
    EraUI:SaveSettings()
end
local function Hover()
    local allowed=Enabled() and not InCombatLockdown()
    bar:EnableMouse(allowed);bar:EnableMouseWheel(allowed and editing);control:EnableMouse(allowed)
    control:SetAlpha(allowed and (editing or bar:IsMouseOver() or control:IsMouseOver()) and 1 or 0)
end
local function Lock()
    if editing then Save() end
    editing=false;resizePanel:Hide();bar:SetFrameStrata("MEDIUM");Hover()
end
local function Build()
    if bar then return end
    bar=CreateFrame("StatusBar","EraUISwingTimer",UIParent)
    bar:SetFrameStrata("MEDIUM");bar:SetMovable(true);bar:SetClampedToScreen(true)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(.76,.68,.45)
    local bg=bar:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.018,.018,.022,1)
    edge=CreateFrame("Frame",nil,bar,"BackdropTemplate")
    edge:SetPoint("TOPLEFT",-4,4);edge:SetPoint("BOTTOMRIGHT",4,-4)
    edge:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16})
    local _,class=UnitClass("player")
    local colour=(CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    local r,g,b=.3,.3,.3
    if colour then r,g,b=colour.r*.35,colour.g*.35,colour.b*.35 end
    if class=="PALADIN" then r,g,b=.336,.1925,.2555 end
    edge:SetBackdropBorderColor(r,g,b,1)
    text=edge:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");text:SetPoint("CENTER",bar,"CENTER",0,0);text:SetFont("Fonts\\FRIZQT__.TTF",12,"");text:SetShadowColor(0,0,0,1);text:SetShadowOffset(.8,-.8);text:SetJustifyV("MIDDLE")
    control=CreateFrame("Button","EraUISwingControl",bar,"BackdropTemplate")
    control:SetSize(20,20);control:SetPoint("LEFT",bar,"RIGHT",5,0)
    control:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    control:SetBackdropColor(.08,.08,.09,.9);control:SetBackdropBorderColor(.5,.5,.5,1)
    local label=control:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");label:SetPoint("CENTER");label:SetText("+")
    control:RegisterForClicks("LeftButtonUp","RightButtonUp")
    control:SetScript("OnClick",function(_,button)
        if InCombatLockdown() then return end
        if button=="RightButton" then
            editing=true;resizePanel:Show();bar:SetFrameStrata("DIALOG")
            if EraUI.settingsFrame then EraUI.settingsFrame:Hide() end
            Hover()
        else Lock() end
    end)
    control:SetScript("OnEnter",function(self)
        Hover()
        if GameTooltip then
            GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:SetText("Swing timer")
            GameTooltip:AddLine("Right-click: unlock. Left-click: lock.",1,1,1)
            GameTooltip:AddLine("Drag to move. Wheel: width. Shift + wheel: height.",1,1,1);GameTooltip:Show()
        end
    end)
    local function Leave()
        if GameTooltip and GameTooltip:IsOwned(control) then GameTooltip:Hide() end
        C_Timer.After(0,Hover)
    end
    control:SetScript("OnLeave",Leave);bar:SetScript("OnEnter",Hover);bar:SetScript("OnLeave",Leave)
    bar:RegisterForDrag("LeftButton");bar:EnableMouseWheel(true)
    bar:SetScript("OnDragStart",function()if editing and not InCombatLockdown() then bar:StartMoving() end end)
    bar:SetScript("OnDragStop",function()if editing then Save();Layout() end end)
    bar:SetScript("OnMouseWheel",function(_,delta)
        if not editing or InCombatLockdown() then return end
        local p=Options()
        if IsShiftKeyDown() then p.height=p.height+delta*2 else p.width=p.width+delta*8 end
        Layout()
    end)
    resizePanel=CreateFrame("Frame","EraUISwingResizeControls",bar,"BackdropTemplate")
    resizePanel:SetSize(244,30);resizePanel:SetPoint("TOP",bar,"BOTTOM",0,-7)
    resizePanel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    resizePanel:SetBackdropColor(.06,.06,.07,.95);resizePanel:SetBackdropBorderColor(.4,.4,.4,1)
    local function Adjust(label,x,key,amount)
        local b=CreateFrame("Button",nil,resizePanel,"BackdropTemplate")
        b:SetSize(56,22);b:SetPoint("LEFT",x,0)
        local _,class=UnitClass("player")
        local colour=(CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])
            or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
        local r,g,blue=.7,.7,.7
        if colour then r,g,blue=colour.r,colour.g,colour.b end
        b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        b:SetBackdropColor(r*.22,g*.22,blue*.22,1)
        b:SetBackdropBorderColor(r,g,blue,1)
        local caption=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        caption:SetPoint("CENTER");caption:SetText(label);caption:SetTextColor(.94,.95,.98,1)
        b:SetScript("OnEnter",function()b:SetBackdropColor(r*.34,g*.34,blue*.34,1)end)
        b:SetScript("OnLeave",function()b:SetBackdropColor(r*.22,g*.22,blue*.22,1)end)
        b:SetScript("OnClick",function()
            if not editing or InCombatLockdown() then return end
            local p=Options();p[key]=p[key]+amount;Layout()
        end)
    end
    Adjust("Width -",4,"width",-8);Adjust("Width +",64,"width",8)
    Adjust("Height -",124,"height",-2);Adjust("Height +",184,"height",2)
    resizePanel:Hide()
    offbar=CreateFrame("StatusBar",nil,bar)
    offbar:SetPoint("TOPLEFT",bar,"BOTTOMLEFT",0,-9)
    offbar:SetPoint("TOPRIGHT",bar,"BOTTOMRIGHT",0,-9)
    offbar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    offbar:SetStatusBarColor(.55,.58,.64)
    local offbg=offbar:CreateTexture(nil,"BACKGROUND");offbg:SetAllPoints();offbg:SetColorTexture(.018,.018,.022,1)
    local offedge=CreateFrame("Frame",nil,offbar,"BackdropTemplate")
    offedge:SetPoint("TOPLEFT",-4,4);offedge:SetPoint("BOTTOMRIGHT",4,-4)
    offedge:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16})
    offedge:SetBackdropBorderColor(r,g,b,1)
    offtext=offedge:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");offtext:SetPoint("CENTER",offbar,"CENTER",0,0);offtext:SetFont("Fonts\\FRIZQT__.TTF",12,"");offtext:SetShadowColor(0,0,0,1);offtext:SetShadowOffset(.8,-.8);offtext:SetJustifyV("MIDDLE")
    bar:SetMinMaxValues(0,1);offbar:SetMinMaxValues(0,1)
    bar:SetValue(0);offbar:SetValue(0);text:SetText("Main hand");offtext:SetText("Off hand")
    Layout()
end

-- Keep Blizzard timing and Edit Mode ownership untouched. Only suppress the
-- duplicate artwork while this display is enabled; restore its prior alpha.
local function NativeVisibility()
    for _,name in ipairs({"SwingTimerMainHandFrame","SwingTimerOffHandFrame"}) do
        local frame=_G[name]
        if frame then
            if Enabled() and not unavailable then
                if nativeAlpha[frame]==nil then nativeAlpha[frame]=frame:GetAlpha() end
                frame:SetAlpha(0)
            elseif nativeAlpha[frame]~=nil then
                frame:SetAlpha(nativeAlpha[frame]);nativeAlpha[frame]=nil
            end
        end
    end
end
local function Clear()
    timers={}
    if bar then
        bar:SetScript("OnUpdate",nil);bar:SetValue(0);offbar:SetValue(0)
        text:SetText("Main hand");offtext:SetText("Off hand")
    end
end
local function Tick()
    local active=false
    for kind,timer in pairs(timers) do
        local remaining=math.max(0,timer.ends-GetTime())
        local target=kind==0 and bar or offbar
        local label=kind==0 and text or offtext
        if remaining>0 then
            active=true;target:SetValue(1-remaining/timer.duration)
            label:SetFormattedText("%s  %.1f",kind==0 and "MH" or "OH",remaining)
        else
            target:SetValue(0);label:SetText(kind==0 and "Main hand" or "Off hand");timers[kind]=nil
        end
    end
    if not active then bar:SetScript("OnUpdate",nil) end
end
function Module:Refresh()
    NativeVisibility()
    if not Enabled() then
        Clear();if bar then Lock();bar:Hide() end
        return
    end
    Build()
    local _,off=UnitAttackSpeed("player")
    local hasOff=Public(off) and type(off)=="number" and off>0
    offbar:SetShown(hasOff)
    if not hasOff then timers[1]=nil;offbar:SetValue(0);offtext:SetText("Off hand") end
    offbar:SetHeight(Options().height)
    resizePanel:ClearAllPoints();resizePanel:SetPoint("TOP",hasOff and offbar or bar,"BOTTOM",0,-7)
    bar:Show();Hover()
end
function Module:Initialize()
    local events=CreateFrame("Frame")
    for _,event in ipairs({"PLAYER_SWING","PLAYER_ENTERING_WORLD","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","WEAPON_SLOT_CHANGED","UI_SCALE_CHANGED","ADDON_LOADED"}) do events:RegisterEvent(event) end
    events:RegisterUnitEvent("UNIT_ATTACK_SPEED","player")
    events:SetScript("OnEvent",function(_,event,duration,kind)
        if event=="PLAYER_SWING" then
            if not Enabled() then return end
            -- Never calculate with restricted combat values or estimate a swing.
            if not Public(duration) or not Public(kind) then
                unavailable=true;Clear();NativeVisibility()
                if text then text:SetText("Timing unavailable") end
                return
            end
            if (kind~=0 and kind~=1) or type(duration)~="number" or duration<=0 then return end
            unavailable=false;self:Refresh()
            timers[kind]={duration=duration,ends=GetTime()+duration}
            Tick();bar:SetScript("OnUpdate",Tick)
            return
        end
        if event=="PLAYER_ENTERING_WORLD" or event=="WEAPON_SLOT_CHANGED" then Clear() end
        if event=="PLAYER_REGEN_DISABLED" and bar then Lock() end
        if event=="UI_SCALE_CHANGED" and bar then Layout() end
        self:Refresh()
    end)
    self:Refresh()
end
