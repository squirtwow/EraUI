-- Cosmetic player aura borders and Classic tooltips. Native aura data, timers,
-- dispel symbols, cancellation and tooltip text remain owned by the client.
local _,E=...
local M={};E:RegisterModule("AuraStyle",M)
local owners=setmetatable({}, {__mode="k"})
local tips=setmetatable({}, {__mode="k"})
local hooked=setmetatable({}, {__mode="k"})
local function Public(v)return not(issecretvalue and issecretvalue(v))end
local function Enabled()return E:GetSetting("enabled")and E:GetSetting("unitFrames")end
local function GeneralTooltips()return E:GetSetting("enabled")and E:GetSetting("tooltipSkin")end

local function RestoreTooltip(tip)
 local state=tips[tip]
 if not state then return end
 state.aura=false;state.styled=false;state.backdrop:Hide()
 if state.originalAlpha~=nil and tip.NineSlice then
  tip.NineSlice:SetAlpha(state.originalAlpha);state.originalAlpha=nil
 end
end
local function PaintTooltip(tip)
 local state=tips[tip]
 if not state then return end
 if state.embedded or tip.IsEmbedded or(not GeneralTooltips()and not(Enabled()and state.aura))then RestoreTooltip(tip);return end
 state.styled=true
 if tip.NineSlice then
  if state.originalAlpha==nil then state.originalAlpha=tip.NineSlice:GetAlpha()end
  tip.NineSlice:SetAlpha(0)
 end
 state.backdrop:SetFrameLevel(math.max(0,tip:GetFrameLevel()-1))
 state.backdrop:Show()
end
local function AuraTooltip(tip)
 if not tips[tip]then return end
 tips[tip].aura=true;PaintTooltip(tip)
end
local function AttachTooltip(tip)
 if not tip or tips[tip]or(tip.IsForbidden and tip:IsForbidden())then return end
 local backdrop=CreateFrame("Frame",nil,tip,"BackdropTemplate")
 backdrop:SetAllPoints(tip)
  -- Authored neutral-grey bevel and curved corners, independent of the client's
  -- recoloured tooltip assets. Text and item-quality colours remain native.
  backdrop:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",
   edgeFile="Interface\\AddOns\\EraUI\\Media\\TooltipBorder.tga",edgeSize=16,
   insets={left=3,right=3,top=3,bottom=3}})
  backdrop:SetBackdropColor(.016,.016,.02,.9);backdrop:SetBackdropBorderColor(1,1,1,1)
 backdrop:Hide();tips[tip]={backdrop=backdrop}
 if tip.NineSlice then
  hooksecurefunc(tip.NineSlice,"SetAlpha",function(slice,value)
   if tips[tip].styled and Public(value)and value~=0 then slice:SetAlpha(0)end
  end)
 end
 tip:HookScript("OnShow",function(self)
   local owner=self.GetOwner and self:GetOwner()
  if Public(owner)and owners[owner]then tips[self].aura=true end
  PaintTooltip(self)
 end)
 tip:HookScript("OnHide",RestoreTooltip)
 if not tip.HasScript or tip:HasScript("OnTooltipCleared")then
  tip:HookScript("OnTooltipCleared",function(self)
   RestoreTooltip(self)
   if GeneralTooltips()then PaintTooltip(self)end
  end)
 end
 for _,method in ipairs({"SetUnitAura","SetUnitBuff","SetUnitDebuff","SetUnitAuraByAuraInstanceID","SetUnitBuffByAuraInstanceID","SetUnitDebuffByAuraInstanceID"})do
  if tip[method]then hooksecurefunc(tip,method,AuraTooltip)end
 end
 if tip:IsShown()then PaintTooltip(tip)end
end

local function StyleButton(button)
 if not button or button.isAuraAnchor then return end
 owners[button]=true
 if not Enabled()then return end
 local border=button.DebuffBorder
 local kind=button.auraType
 if not border or not Public(kind)or(kind~="Debuff"and kind~="DeadlyDebuff")then return end
 local info=button.buttonInfo
 local dispel=info and info.debuffType
 -- Keep the native border when its type is restricted; never infer a dispel.
 if not Public(dispel)then return end
 local colour=DebuffTypeColor and(DebuffTypeColor[dispel or "none"]or DebuffTypeColor.none)
 border:SetTexture("Interface\\Buttons\\UI-Debuff-Border")
 border:SetTexCoord(0,1,0,1)
 border:SetVertexColor(colour and colour.r or .8,colour and colour.g or 0,colour and colour.b or 0)
  if button.Icon then
   -- Native aura geometry can be secret. Let anchors follow the icon without
   -- reading or performing arithmetic on its width/height.
   border:ClearAllPoints()
   border:SetPoint("TOPLEFT",button.Icon,"TOPLEFT",-3,3)
   border:SetPoint("BOTTOMRIGHT",button.Icon,"BOTTOMRIGHT",3,-3)
  end
end
local function StyleFrame(frame)
 if not frame then return end
 if not hooked[frame]and frame.UpdateAuraButtons then
  hooked[frame]=true
  hooksecurefunc(frame,"UpdateAuraButtons",StyleFrame)
 end
 for _,button in ipairs(frame.auraFrames or{})do StyleButton(button)end
end
function M:Refresh()
 for _,name in ipairs({"GameTooltip","BuffFrameTooltip","ItemRefTooltip","ShoppingTooltip1","ShoppingTooltip2",
  "ItemRefShoppingTooltip1","ItemRefShoppingTooltip2"})do AttachTooltip(_G[name])end
 StyleFrame(BuffFrame);StyleFrame(DebuffFrame);StyleFrame(ExternalDefensivesFrame)
 local consolidated=BuffFrame and BuffFrame.ConsolidatedBuffs
 StyleFrame(consolidated and consolidated.Tooltip and consolidated.Tooltip.Auras)
end
function M:Initialize()
 self:Refresh()
 if SharedTooltip_SetBackdropStyle then
  hooksecurefunc("SharedTooltip_SetBackdropStyle",function(tip,_,embedded)
   if not tips[tip]and GeneralTooltips()then AttachTooltip(tip)end
   if tips[tip]then tips[tip].embedded=embedded;PaintTooltip(tip)end
  end)
 end
 local events=CreateFrame("Frame")
 events:RegisterEvent("ADDON_LOADED");events:RegisterEvent("PLAYER_ENTERING_WORLD")
 events:SetScript("OnEvent",function()M:Refresh()end)
end
