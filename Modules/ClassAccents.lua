local _,EraUI=...
local M={};EraUI:RegisterModule("ClassAccents",M)
local watched={}
local outlines={}
local function Public(v)return not (issecretvalue and issecretvalue(v))end
local function PlayerColour(unit)
 if not EraUI:GetSetting("enabled") or not EraUI:GetSetting("unitFrames") then return end
 local player=UnitIsPlayer(unit)
 if not Public(player) or not player then return end
 local _,class=UnitClass(unit)
 if not Public(class) then return end
 if class=="PALADIN" then return .96,.55,.73 end
 local colour=(CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
 if colour then return colour.r,colour.g,colour.b end
end
local function Paint(texture,state)
 if state.writing then return end
 state.writing=true
 local r,g,b=PlayerColour(state.unit)
 if r then texture:SetVertexColor(r,g,b,1)
 elseif state.original then texture:SetVertexColor(unpack(state.original)) end
 state.writing=false
end
function M:Refresh()
 for _,entry in ipairs({{TargetFrame,"target"},{FocusFrame,"focus"}})do
  local frame,unit=entry[1],entry[2]
  local content=frame and frame.TargetFrameContent
  local main=content and content.TargetFrameContentMain
  local texture=main and main.ReputationColor
  if texture then
   local state=watched[texture]
   if not state then
    state={unit=unit,original={texture:GetVertexColor()}};watched[texture]=state
    hooksecurefunc(texture,"SetVertexColor",function(self,...)
     if state.writing then return end
     state.original={...};Paint(self,state)
    end)
   end
   Paint(texture,state)
  end
 end
 local function Accent(cast,unit)
  if not cast then return end
  local outline=outlines[cast]
  local player=UnitIsPlayer(unit)
  if not EraUI:GetSetting("enabled") or not EraUI:GetSetting("castBarClassBorder") or not Public(player) or not player then
   if outline then outline:Hide() end;return
  end
  local _,class=UnitClass(unit)
  if not Public(class) then if outline then outline:Hide() end;return end
  local colour=(CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
  if not colour then if outline then outline:Hide() end;return end
  local border=cast.Border
  if not border or not border.GetTexture or not border:GetTexture() then
   if outline then outline:Hide() end;return
  end
  if not outline then
   outline=CreateFrame("Frame",nil,cast,"BackdropTemplate");outlines[cast]=outline
   outline:SetPoint("TOPLEFT",-2,2);outline:SetPoint("BOTTOMRIGHT",2,-2);outline:EnableMouse(false)
   -- Share the native bar's draw layers so its OVERLAY spell text stays above the tint.
   outline.art=cast:CreateTexture(nil,"ARTWORK",nil,7)
   outline:HookScript("OnHide",function()outline.art:Hide()end)
   outline:HookScript("OnShow",function()outline.art:Show()end)
   cast:HookScript("OnShow",function()M:Refresh()end)
  end
  local r,g,b=colour.r,colour.g,colour.b
  if class=="PALADIN" then r,g,b=.96,.55,.73 end
  outline.art:ClearAllPoints();outline.art:SetAllPoints(border)
  outline.art:SetTexture(border:GetTexture())
  outline.art:SetTexCoord(border:GetTexCoord())
  outline.art:SetVertexColor(r,g,b,.8);outline:Show()
 end
 Accent(PlayerCastingBarFrame or CastingBarFrame,"player")
 Accent(TargetFrame and TargetFrame.spellbar,"target")
 Accent(FocusFrame and FocusFrame.spellbar,"focus")
 if C_NamePlate and C_NamePlate.GetNamePlates then
  for _,plate in ipairs(C_NamePlate.GetNamePlates()) do
   local frame=plate.UnitFrame
   local unit=plate.namePlateUnitToken
   if frame and Public(unit) and type(unit)=="string" then
    local container=frame.CastBarsContainer
    Accent(container and container.castBar or frame.castBar,unit)
   end
  end
 end
end
function M:Initialize()
 local f=CreateFrame("Frame")
 for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","ADDON_LOADED","NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED"})do f:RegisterEvent(event)end
 f:SetScript("OnEvent",function(_,event)
  if event=="NAME_PLATE_UNIT_REMOVED" then for _,outline in pairs(outlines)do outline:Hide()end end
  self:Refresh()
 end)
 self:Refresh()
end

