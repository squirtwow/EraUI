local _,EraUI=...
local Module={}
EraUI:RegisterModule("ResourceBar",Module)
local bar,control,edge,text,resizePanel
local editing=false
local manaClasses={HUNTER=true,MAGE=true,PRIEST=true,WARLOCK=true,PALADIN=true,SHAMAN=true}
local function Class() local _,class=UnitClass("player");return class end
local function PowerType()
    local class=Class()
    if class=="WARRIOR" then return 1 end
    if class=="DRUID" then
        local power=UnitPowerType("player")
        if issecretvalue and issecretvalue(power) then return nil end
        if power==0 or power==1 or power==3 then return power end
        return nil
    end
    return 0
end
local function Options()
    EraUIDB.resourceBarPositions=EraUIDB.resourceBarPositions or {}
    local class=Class()
    EraUIDB.resourceBarPositions[class]=EraUIDB.resourceBarPositions[class] or {x=0,y=-164,width=160,height=20}
    local p=EraUIDB.resourceBarPositions[class]
    p.x=tonumber(p.x) or 0;p.y=tonumber(p.y) or -164
    p.width=math.max(80,math.min(360,tonumber(p.width) or 160))
    p.height=math.max(12,math.min(40,tonumber(p.height) or 20))
    return p
end
local function Enabled()
    local _,class=UnitClass("player")
    local key=class=="WARRIOR" and "rageBar" or class=="DRUID" and "druidResourceBar" or manaClasses[class] and "manaBar"
    return key and EraUI:GetSetting("enabled") and EraUI:GetSetting(key)
end
local function Layout()
    local p=Options()
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
    bar=CreateFrame("StatusBar","EraUIResourceBar",UIParent)
    bar:SetFrameStrata("MEDIUM");bar:SetMovable(true);bar:SetClampedToScreen(true)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(1,.82,.08)
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
    control=CreateFrame("Button","EraUIResourceControl",bar,"BackdropTemplate")
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
            GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:SetText("Resource bar")
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
    resizePanel=CreateFrame("Frame","EraUIResourceResizeControls",bar,"BackdropTemplate")
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
    Layout()
end
function Module:Refresh()
    if not Enabled() then
        if bar then Lock();bar:Hide() end
        return
    end
    local power=PowerType()
    if power==nil then if bar then Lock();bar:Hide() end;return end
    Build()
    if power==1 then bar:SetStatusBarColor(.9,.12,.12)
    elseif power==3 then bar:SetStatusBarColor(1,.82,.08)
    else bar:SetStatusBarColor(.15,.4,1) end
    -- Native sinks only. No arithmetic, comparisons, caching, or Lua formatting
    -- of player power, and no TextStatusBar/OnValueChanged callbacks.
    bar:SetMinMaxValues(0,UnitPowerMax("player",power))
    bar:SetValue(UnitPower("player",power))
    text:SetFormattedText("%d",UnitPower("player",power))
    bar:Show();Hover()
end
function Module:Initialize()
    local events=CreateFrame("Frame")
    for _,event in ipairs({"UNIT_POWER_FREQUENT","UNIT_POWER_UPDATE","UNIT_MAXPOWER","UNIT_DISPLAYPOWER"}) do events:RegisterUnitEvent(event,"player") end
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","UI_SCALE_CHANGED","UPDATE_SHAPESHIFT_FORM"}) do events:RegisterEvent(event) end
    events:SetScript("OnEvent",function(_,event,unit,power)
        if event=="PLAYER_REGEN_DISABLED" and bar then Lock() end
        if event=="UI_SCALE_CHANGED" and bar then Layout() end
        self:Refresh()
    end)
    self:Refresh()
end
