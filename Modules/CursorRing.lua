local _,E=...
local M={};E:RegisterModule("CursorRing",M)
local ring
-- A single antialiased annulus avoids the seams and short/thick-line
-- rendering failures of a circle assembled from native Line regions.
local atlas="Interface\\AddOns\\EraUI\\Media\\CursorRings"
local function Number(key,default,minimum,maximum)
 local value=tonumber(E:GetSetting(key))or default
 return math.max(minimum,math.min(maximum,value))
end
function M:Colour()
 if E:GetSetting("cursorRingClassColour")then
  local _,class=UnitClass("player")
  if class=="PALADIN"then return .96,.55,.73 end
  local colour=RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if colour then return colour.r,colour.g,colour.b end
 end
 return 1,1,1
end
local function Follow()
 local x,y=GetCursorPosition()
 local scale=UIParent:GetEffectiveScale()
 if not x or not y or not scale or scale<=0 then return end
 ring:ClearAllPoints();ring:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x/scale,y/scale)
end
function M:Refresh()
 local enabled=E:GetSetting("enabled")and E:GetSetting("cursorRing")
 if not enabled then if ring then ring:Hide()end;return end
 if not ring then
  ring=CreateFrame("Frame","EraUICursorRing",UIParent)
  ring:EnableMouse(false);ring:SetFrameStrata("TOOLTIP");ring:SetFrameLevel(100)
  ring.texture=ring:CreateTexture(nil,"OVERLAY")
  ring.texture:SetTexture(atlas)
  ring.texture:SetPoint("CENTER")
  ring.texture:SetSnapToPixelGrid(false)
  ring.texture:SetTexelSnappingBias(0)
  ring:SetScript("OnUpdate",Follow)
 end
 local diameter=Number("cursorRingSize",48,24,160)
 local thickness=Number("cursorRingThickness",2,1,10)
 local r,g,b=self:Colour()
 ring:SetSize(diameter,diameter)
 -- 8x8 atlas, 128px cells with a 120px outer circle and transparent gutters.
 -- Width ratios are quantized to 1/128 of diameter (at most 0.625px error).
 local index=math.max(1,math.min(64,math.floor(thickness/diameter*128+.5)))-1
 local column,row=index%8,math.floor(index/8)
 ring.texture:SetTexCoord(column/8,(column+1)/8,row/8,(row+1)/8)
 ring.texture:SetSize(diameter*128/120,diameter*128/120)
 ring.texture:SetVertexColor(r,g,b,1)
 Follow();ring:Show()
end
function M:Initialize()
 self:Refresh()
 local events=CreateFrame("Frame")
 events:RegisterEvent("PLAYER_ENTERING_WORLD");events:RegisterEvent("UI_SCALE_CHANGED")
 events:SetScript("OnEvent",function()M:Refresh()end)
end
