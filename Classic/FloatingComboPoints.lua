local _, EraUI = ...
local ns = EraUI.Classic
local row, handle, control
local running, editing = false, false
local capacity=5
local media="Interface\\AddOns\\EraUI\\Media\\ComboPoints\\"
local muted=setmetatable({}, {__mode="k"})
local function Safe(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value)~="number" then return nil end
    return value
end
local function Options()
    EraUIDB.comboPointPosition=EraUIDB.comboPointPosition or {}
    local p=EraUIDB.comboPointPosition
    p.x=tonumber(p.x) or 0;p.y=tonumber(p.y) or -130
    p.size=math.max(12,math.min(48,tonumber(p.size) or 24))
    return p
end
local function MuteNative(frame)
    if not frame then return end
    if muted[frame]==nil then
        muted[frame]=frame:GetAlpha()
        frame:HookScript("OnShow",function(self) if running then self:SetAlpha(0) end end)
    end
    frame:SetAlpha(0)
end
local function SuppressNative()
    if not running then return end
    MuteNative(ComboFrame);MuteNative(ComboPointPlayerFrame);MuteNative(DruidComboPointBarFrame)
end
local function Layout()
    local p=Options()
    row:ClearAllPoints();row:SetPoint("CENTER",UIParent,"CENTER",p.x,p.y)
    row:SetSize(capacity*(p.size+3)-3,p.size)
    for i,orb in ipairs(row.orbs) do
        orb:SetSize(p.size,p.size);orb:ClearAllPoints()
        orb:SetPoint("LEFT",row,"LEFT",(i-1)*(p.size+3),0)
    end
    handle:ClearAllPoints();handle:SetAllPoints(row)
end
local function Paint(points,max)
    capacity=max
    for i,orb in ipairs(row.orbs) do
        orb:SetShown(i<=max)
        -- The native renderer clamps the unchanged count to this orb's
        -- fixed interval. Lua never branches on, formats or calculates it.
        orb:SetValue(points)
    end
end
local function Update()
    if not row then return end
    if editing then Paint(3,5);row:Show();return end
    if not running then row:Hide();return end
    local _,class=UnitClass("player")
    local eligible=class=="ROGUE" or (class=="DRUID" and Safe(UnitPowerType("player"))==3)
    if not eligible then row:Hide();return end
    local kind=Enum.PowerType.ComboPoints
    local points=UnitPower("player",kind)
    local max=Safe(UnitPowerMax("player",kind))
    -- Only capacity is inspected in Lua; current points may remain secret.
    if not max or max<=0 then row:Hide();return end
    max=math.min(10,math.floor(max))
    local changed=capacity~=max
    Paint(points,max)
    -- Only our own unprotected frames are resized, never native unit frames.
    if changed then Layout() end
    row:Show()
end
local function RefreshControl()
    if not control then return end
    local allowed=running and not InCombatLockdown()
    row:EnableMouse(allowed)
    control:EnableMouse(allowed)
    local hovered=allowed and (row:IsMouseOver() or control:IsMouseOver())
    control:SetAlpha(allowed and (editing or hovered) and 1 or 0)
end
local function SavePosition()
    row:StopMovingOrSizing()
    local x,y=row:GetCenter();local cx,cy=UIParent:GetCenter();local p=Options()
    p.x=x-cx;p.y=y-cy
end
local function Lock()
    SavePosition();editing=false;handle:Hide();row:SetFrameStrata("MEDIUM")
    Layout();Update();RefreshControl()
end
-- Gold is the default orb colour; the red option tints both the lit fill
-- and the empty background so the whole row reads as red points.
function ns.RefreshComboPointColor()
    if not row then return end
    local red = EraUI:GetSetting("comboPointRed")
    for _, orb in ipairs(row.orbs) do
        if red then
            orb:SetStatusBarColor(1, 0.22, 0.15)
            if orb.empty then orb.empty:SetVertexColor(1, 0.42, 0.35) end
        else
            orb:SetStatusBarColor(1, 1, 1)
            if orb.empty then orb.empty:SetVertexColor(1, 1, 1) end
        end
    end
end

local function Build()
    if row then return end
    row=CreateFrame("Frame","EraUIFloatingComboPoints",UIParent)
    row:SetFrameStrata("MEDIUM");row:SetMovable(true);row:SetClampedToScreen(true)
    row.orbs={}
    for i=1,10 do
        -- Plain addon-owned StatusBars, with no TextStatusBar template,
        -- OnValueChanged script, or native unit-frame setter hooks.
        -- Orbs are EraUI's own art: the lit orb on the fill, the empty
        -- orb on the background.
        local orb=CreateFrame("StatusBar",nil,row)
        orb:SetMinMaxValues(i-1,i)
        orb:SetStatusBarTexture(media.."combofull.tga")
        local empty=orb:CreateTexture(nil,"BACKGROUND")
        empty:SetAllPoints(orb);empty:SetTexture(media.."comboempty.tga")
        orb.empty=empty
        orb:SetValue(0)
        row.orbs[i]=orb
    end
    ns.RefreshComboPointColor()
    handle=CreateFrame("Frame","EraUIComboPointMoveHandle",row,"BackdropTemplate")
    handle:EnableMouse(true);handle:EnableMouseWheel(true);handle:RegisterForDrag("LeftButton")
    handle:SetFrameLevel(row:GetFrameLevel()+3)
    handle:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    handle:SetBackdropBorderColor(.6,.6,.6,.7)
    control=CreateFrame("Button","EraUIComboPointControl",row,"BackdropTemplate")
    control:SetSize(20,20);control:SetPoint("LEFT",row,"RIGHT",3,0)
    control:SetFrameLevel(handle:GetFrameLevel()+2)
    control:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    control:SetBackdropColor(.08,.08,.09,.9);control:SetBackdropBorderColor(.5,.5,.5,1)
    local label=control:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    label:SetPoint("CENTER");label:SetText("+")
    control:RegisterForClicks("LeftButtonUp","RightButtonUp")
    control:SetScript("OnClick",function(_,button)
        if InCombatLockdown() then return end
        if button=="RightButton" then ns.PreviewComboPoints() else Lock() end
    end)
    control:SetScript("OnEnter",function(self)
        RefreshControl()
        if GameTooltip then
            GameTooltip:SetOwner(self,"ANCHOR_TOP")
            GameTooltip:SetText("Combo points")
            GameTooltip:AddLine("Right-click: unlock. Left-click: lock.",1,1,1)
            GameTooltip:AddLine("Unlocked: drag the row; mouse wheel changes size.",1,1,1)
            GameTooltip:Show()
        end
    end)
    local function Leave()
        if GameTooltip and GameTooltip:IsOwned(control) then GameTooltip:Hide() end
        C_Timer.After(0,RefreshControl)
    end
    control:SetScript("OnLeave",Leave)
    row:SetScript("OnEnter",RefreshControl);row:SetScript("OnLeave",Leave)
    handle:SetScript("OnEnter",RefreshControl);handle:SetScript("OnLeave",Leave)
    handle:SetScript("OnDragStart",function()if not InCombatLockdown() then row:StartMoving() end end)
    handle:SetScript("OnDragStop",function()
        SavePosition();Layout()
    end)
    handle:SetScript("OnMouseWheel",function(_,delta)
        if InCombatLockdown() then return end
        local p=Options();p.size=math.max(12,math.min(48,p.size+delta*2));Layout()
    end)
    handle:Hide();Layout();row:Hide()
end
function ns.PreviewComboPoints()
    if InCombatLockdown() then EraUI:Print("Leave combat before positioning combo points.");return end
    if not running then return end
    if EraUI.settingsFrame then EraUI.settingsFrame:Hide() end
    Build();editing=true;Update();Layout();row:SetFrameStrata("DIALOG");handle:Show();RefreshControl()
end
function ns.StartFloatingCombo()
    running=true;Build();SuppressNative();Update();Layout();RefreshControl()
end
function ns.StopFloatingCombo()
    running=false;editing=false
    if row then row:Hide();handle:Hide() end
    for frame,alpha in pairs(muted) do frame:SetAlpha(alpha) end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_TARGET_CHANGED","UPDATE_SHAPESHIFT_FORM","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","UI_SCALE_CHANGED","ADDON_LOADED"}) do events:RegisterEvent(event) end
for _,event in ipairs({"UNIT_POWER_UPDATE","UNIT_POWER_FREQUENT","UNIT_MAXPOWER","UNIT_DISPLAYPOWER"}) do events:RegisterUnitEvent(event,"player") end
events:SetScript("OnEvent",function(_,event,unit,power)
    if not running and not editing then return end
    if event=="PLAYER_REGEN_DISABLED" and editing then
        Lock()
    end
    if event=="ADDON_LOADED" or event=="PLAYER_ENTERING_WORLD" then SuppressNative() end
    if (event=="UNIT_POWER_UPDATE" or event=="UNIT_POWER_FREQUENT") and power~="COMBO_POINTS" then return end
    Update()
    if event=="UI_SCALE_CHANGED" then Layout() end
    if event=="PLAYER_REGEN_DISABLED" or event=="PLAYER_REGEN_ENABLED" then RefreshControl() end
end)

-- Read-only diagnostics: never stringify sealed resource values.
function ns.ComboPointStatus()
    local function Describe(value)
        if issecretvalue and issecretvalue(value) then return "unavailable (secret)" end
        return tostring(value)
    end
    local kind=Enum.PowerType.ComboPoints
    EraUI:Print("Combo: enabled="..tostring(EraUI:GetSetting("floatingComboPoints"))..", running="..tostring(running)..", row="..tostring(row~=nil))
    EraUI:Print("Combo resource: current="..Describe(UnitPower("player",kind))..", maximum="..Describe(UnitPowerMax("player",kind)))
    local result=ns.applyResults and ns.applyResults.comboPoints
    EraUI:Print("Combo apply: "..(result and (result.ok and "OK" or tostring(result.error)) or "not run"))
end
