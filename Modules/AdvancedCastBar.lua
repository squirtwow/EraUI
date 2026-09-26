local _,EraUI=...
local Module={}
EraUI:RegisterModule("AdvancedCastBar",Module)
local bar,control,edge,text,resizePanel
local editing=false
local icon,spell,latency,iconEdge,spark,latencyText
local markers={}
local castState
local native,nativeAlpha
local settingsHooked=false
local function Public(value)return not (issecretvalue and issecretvalue(value))end
local suppressNative=false
local nativeHooks={}
local nativeWriting=false
local function Conceal(frame)
    if not suppressNative or nativeWriting then return end
    nativeWriting=true;frame:SetAlpha(0);nativeWriting=false
end
local function Native(show)
    local frame=PlayerCastingBarFrame or CastingBarFrame
    if not frame then return end
    if not nativeHooks[frame] then
        nativeHooks[frame]=true
        frame:HookScript("OnShow",function(self)Conceal(self)end)
        hooksecurefunc(frame,"SetAlpha",function(self,value)
            if nativeWriting or not suppressNative then return end
            nativeAlpha=value
            Conceal(self)
        end)
    end
    if show then
        suppressNative=false
        if native then native:SetAlpha(nativeAlpha);native,nativeAlpha=nil,nil end
    else
        if not native then native=frame;nativeAlpha=frame:GetAlpha() end
        suppressNative=true;Conceal(frame)
    end
end
local function Options()
    EraUIDB.advancedCastBarPosition=EraUIDB.advancedCastBarPosition or {x=0,y=-220,width=260,height=24}
    local p=EraUIDB.advancedCastBarPosition
    p.x=tonumber(p.x) or 0;p.y=tonumber(p.y) or -220
    p.width=math.max(220,math.min(480,tonumber(p.width) or 260))
    p.height=math.max(20,math.min(40,tonumber(p.height) or 24))
    return p
end
local function Enabled()
    local _,class=UnitClass("player")
    return EraUI:GetSetting("enabled") and EraUI:GetSetting("advancedCastBar")
end
local function Layout()
    local p=Options()
    if iconEdge then iconEdge:SetSize(p.height,p.height) end
    if spark then spark:SetSize(20,p.height*2.2) end
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
    bar=CreateFrame("StatusBar","EraUIAdvancedCastBar",UIParent)
    bar:SetFrameStrata("MEDIUM");bar:SetMovable(true);bar:SetClampedToScreen(true)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(1,.82,.08)
    local bg=bar:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.035,.035,.04,.95)
    edge=CreateFrame("Frame",nil,bar,"BackdropTemplate")
    edge:SetPoint("TOPLEFT",-2,2);edge:SetPoint("BOTTOMRIGHT",2,-2)
    edge:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16})
    edge:SetBackdropBorderColor(.38,.38,.4,1)
    text=edge:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");text:SetPoint("RIGHT",bar,"RIGHT",-4,0);text:SetWidth(76);text:SetJustifyH("RIGHT")
    control=CreateFrame("Button","EraUIAdvancedCastControl",bar,"BackdropTemplate")
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
        else Lock();Module:Refresh() end
    end)
    control:SetScript("OnEnter",function(self)
        Hover()
        if GameTooltip then
            GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:SetText("Advanced cast bar")
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
        Layout();Module:Refresh()
    end)
    resizePanel=CreateFrame("Frame","EraUIAdvancedCastResizeControls",bar,"BackdropTemplate")
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
            local p=Options();p[key]=p[key]+amount;Layout();Module:Refresh()
        end)
    end
    Adjust("Width -",4,"width",-8);Adjust("Width +",64,"width",8)
    Adjust("Height -",124,"height",-2);Adjust("Height +",184,"height",2)
    resizePanel:Hide()
    spell=edge:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    spell:SetPoint("LEFT",bar,"LEFT",4,0);spell:SetPoint("RIGHT",bar,"RIGHT",-88,0);spell:SetJustifyH("LEFT")
    spell:SetFont("Fonts\\FRIZQT__.TTF",14,"");spell:SetNonSpaceWrap(false)
    text:SetFont("Fonts\\FRIZQT__.TTF",12,"");text:SetNonSpaceWrap(false)
    spell:SetShadowColor(0,0,0,1);spell:SetShadowOffset(1,-1)
    text:SetShadowColor(0,0,0,1);text:SetShadowOffset(1,-1)
    iconEdge=CreateFrame("Frame",nil,bar,"BackdropTemplate")
    iconEdge:SetPoint("RIGHT",bar,"LEFT",-1,0)
    iconEdge:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
    iconEdge:SetBackdropColor(0,0,0,1)
    edge:ClearAllPoints();edge:SetPoint("TOPLEFT",iconEdge,"TOPLEFT",-4,4);edge:SetPoint("BOTTOMRIGHT",bar,"BOTTOMRIGHT",4,-4)
    icon=iconEdge:CreateTexture(nil,"ARTWORK");icon:SetAllPoints(iconEdge);icon:SetTexCoord(.07,.93,.07,.93)
    spark=bar:CreateTexture(nil,"OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD");spark:SetVertexColor(1,.95,.8,.7)
    spark:SetPoint("CENTER",bar:GetStatusBarTexture(),"RIGHT",0,0)
    latency=bar:CreateTexture(nil,"OVERLAY");latency:SetColorTexture(.8,.08,.08,.65);latency:Hide()
    latencyText=edge:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    latencyText:SetFont("Fonts\\FRIZQT__.TTF",8,"");latencyText:SetShadowOffset(1,-1)
    latencyText:SetShadowColor(0,0,0,1);latencyText:Hide()
    Layout()
end

local function ClearExtras()
    latency:Hide();latencyText:Hide();text:ClearAllPoints();text:SetPoint("RIGHT",bar,"RIGHT",-4,0)
    spell:ClearAllPoints();spell:SetPoint("LEFT",bar,"LEFT",4,0);spell:SetPoint("RIGHT",bar,"RIGHT",-88,0)
    for _,mark in ipairs(markers)do mark:Hide()end
end
local function Colours()
    local _,class=UnitClass("player")
    local c=(CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    local r,g,b=.7,.7,.7
    if c then r,g,b=c.r,c.g,c.b end
    if class=="PALADIN" then r,g,b=.96,.55,.73 end
    if EraUI:GetSetting("castBarClassBorder") then edge:SetBackdropBorderColor(r*.35,g*.35,b*.35,1) else edge:SetBackdropBorderColor(.1,.1,.1,1) end
    if EraUI:GetSetting("advancedCastClassFill") then bar:SetStatusBarColor(r*(class=="PRIEST" and .48 or .68),g*(class=="PRIEST" and .48 or .68),b*(class=="PRIEST" and .48 or .68))
    else bar:SetStatusBarColor(1,.62,.12)end
end
local function Extras(total,channel,spellID)
    ClearExtras()
    if not Public(total) or type(total)~="number" or total<=0 then return end
    local width=Options().width
    if EraUI:GetSetting("advancedCastLatency") and GetNetStats then
        local _,_,_,world=GetNetStats()
        if Public(world) and type(world)=="number" and world>0 then
            latency:ClearAllPoints();latency:SetPoint(channel and "TOPLEFT" or "TOPRIGHT",0,0)
            latency:SetPoint(channel and "BOTTOMLEFT" or "BOTTOMRIGHT",0,0)
            local zoneWidth=math.min(1,world/1000/total)*width
            latency:SetWidth(zoneWidth);latency:Show()
            latencyText:SetFormattedText("%dms",math.floor(world+.5))
            latencyText:ClearAllPoints();latencyText:SetPoint("CENTER",latency,"CENTER",0,0)
            if zoneWidth>=latencyText:GetStringWidth()+2 and zoneWidth+160<=width then
                latencyText:Show()
                text:ClearAllPoints();text:SetPoint("RIGHT",bar,"RIGHT",channel and -4 or -zoneWidth-5,0)
                spell:ClearAllPoints();spell:SetPoint("LEFT",bar,"LEFT",channel and zoneWidth+5 or 4,0)
                spell:SetPoint("RIGHT",bar,"RIGHT",channel and -88 or -zoneWidth-90,0)
            end
        end
    end
    if not channel or not EraUI:GetSetting("advancedCastTicks") or not Public(spellID) or type(spellID)~="number" then return end
    -- Only explicit timing from this client's current spell description, not a rank table.
    local description=C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(spellID)
    if not Public(description) or type(description)~="string" then return end
    local interval=tonumber(description:match("every%s+(%d+%.?%d*)%s+sec"))
    if not interval or interval<=0 then return end
    local count=math.ceil(total/interval)-1
    if count>20 then return end
    for i=1,count do
        local mark=markers[i]
        if not mark then mark=bar:CreateTexture(nil,"OVERLAY");mark:SetColorTexture(1,1,1,.45);markers[i]=mark end
        mark:ClearAllPoints();mark:SetPoint("TOPLEFT",width*(1-i*interval/total),0)
        mark:SetSize(1,Options().height);mark:Show()
    end
end
local function Tick()
    local s=castState;if not s then return end
    if s.duration then
        -- Let native formatting consume opaque numeric durations without Lua math.
        text:SetFormattedText("%.1f / %.1f",s.channel and s.duration:GetRemainingDuration()or s.duration:GetElapsedDuration(),s.duration:GetTotalDuration())
    elseif s.start then
        local value=EraUI.CastTiming.Value(s,GetTime())
        if not s.nativeDriven then bar:SetValue(value) end
        text:SetFormattedText("%.1f / %.1f",value,s.total)
    end
end
function Module:Refresh(event,retry)
    if not Enabled() then
        castState=nil;Native(true)
        if bar then Lock();bar:SetScript("OnUpdate",nil);bar:Hide()end
        return
    end
    Build();Colours()
    if EraUI.settingsFrame and not settingsHooked then
        settingsHooked=true
        EraUI.settingsFrame:HookScript("OnShow",function()self:Refresh()end)
        EraUI.settingsFrame:HookScript("OnHide",function()self:Refresh()end)
    end
    local name,_,texture,startMS,endMS,_,_,_,spellID=UnitCastingInfo("player")
    local channel=false
    if Public(name) and not name then
        name,_,texture,startMS,endMS,_,_,spellID=UnitChannelInfo("player");channel=true
    end
    if Public(name) and not name then
        if castState and event=="UNIT_SPELLCAST_CHANNEL_UPDATE"and not retry then
            -- The event may precede the replacement channel info by one frame.
            local previous=castState
            C_Timer.After(0,function()if castState==previous then self:Refresh(event,true)end end)
            return
        end
        castState=nil;Native(false);bar:SetScript("OnUpdate",nil);ClearExtras()
        if editing or (not InCombatLockdown() and EraUI.settingsFrame and EraUI.settingsFrame:IsShown()) then
            bar:SetFrameStrata("DIALOG")
            if EraUI.settingsFrame then bar:SetFrameLevel(EraUI.settingsFrame:GetFrameLevel()+20) end
            bar:SetMinMaxValues(0,1);bar:SetValue(.55);spell:SetText("Advanced cast bar");text:SetText("1.1 / 2.0")
            icon:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowBolt");bar:Show();Hover()
        else bar:Hide()end
        return
    end
    local fresh=event=="UNIT_SPELLCAST_START"or event=="UNIT_SPELLCAST_CHANNEL_START"
    local snapshot=EraUI.CastTiming.Snapshot(castState,channel,name,startMS,endMS,spellID,fresh)
    local raw=snapshot~=nil
    local total=raw and snapshot.total or nil
    local getter=channel and UnitChannelDuration or UnitCastingDuration
    local duration
    if not raw and getter then local ok,value=pcall(getter,"player");if ok then duration=value end end
    local durationPublic=Public(duration)
    local driven=false
    if not raw and bar.SetTimerDuration and (not durationPublic or duration) and Enum and Enum.StatusBarTimerDirection and Enum.StatusBarInterpolation then
        driven=pcall(bar.SetTimerDuration,bar,duration,Enum.StatusBarInterpolation.Immediate,
            channel and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime)
    end
    if not driven and not raw then
        castState=nil;bar:SetScript("OnUpdate",nil);bar:Hide();Native(true);return
    end
    if not driven then bar:SetMinMaxValues(0,total)end
    castState=snapshot or {channel=channel}
    castState.duration=driven and durationPublic and duration or nil
    castState.nativeDriven=driven
    spell:SetText(name);icon:SetTexture(texture);text:SetText("")
    Extras(total,channel,spellID)
    local function Update()
        local ok=pcall(Tick)
        if not ok then castState=nil;bar:SetScript("OnUpdate",nil);bar:Hide();Native(true)end
    end
    Update()
    if castState then bar:SetFrameStrata(editing and "DIALOG" or "MEDIUM");bar:SetScript("OnUpdate",Update);Native(false);bar:Show();Hover()end
end
function Module:Initialize()
    local events=CreateFrame("Frame")
    for _,event in ipairs({"UNIT_SPELLCAST_START","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_INTERRUPTED","UNIT_SPELLCAST_DELAYED","UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_CHANNEL_UPDATE","UNIT_SPELLCAST_CHANNEL_STOP"})do events:RegisterUnitEvent(event,"player")end
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","UI_SCALE_CHANGED"})do events:RegisterEvent(event)end
    events:SetScript("OnEvent",function(_,event)
        if event=="PLAYER_REGEN_DISABLED" and bar then Lock()end
        if event=="UI_SCALE_CHANGED" and bar then Layout()end
        self:Refresh(event)
    end)
    self:Refresh()
end
