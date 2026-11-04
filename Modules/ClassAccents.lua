local _,EraUI=...
local M={};EraUI:RegisterModule("ClassAccents",M)
local watched={}
local outlines={}
local function Public(v)return not (issecretvalue and issecretvalue(v))end
-- The outline's art is a texture on the cast bar itself, so hiding the
-- outline frame alone isn't enough: hidden while the bar was hidden, no
-- OnHide fires and the art showed again with the bar (seen in game
-- 2026-10-11 over Rounded Cast Bars). Both go together.
local function HideOutline(outline)
 if not outline then return end
 outline:Hide();outline.art:Hide()
end
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
-- The reputation strip behind the target's and focus's names.
local REPUTATION={{"TargetFrame","target"},{"FocusFrame","focus"}}
-- Each of EraUI's own bars' units (player, target, focus) and each
-- nameplate cast bar's plate, whose token is only read, when the bar shows
-- (plates are reused for other units). Weak, like the outlines.
local barUnits=setmetatable({},{__mode="k"})
local barPlates=setmetatable({},{__mode="k"})
local function On()return EraUI:GetSetting("enabled") and EraUI:GetSetting("castBarClassBorder")end
-- Nameplate casts are left to Forever Enhanced Nameplates while it is loaded.
local function HandedOver()return EraUI.NamePlatesHandedOver and EraUI:NamePlatesHandedOver()end
-- Rounded Cast Bars (Look/CastRound.lua): the player, target and focus bars
-- (own) also tell the rounded shell their class colour, or none. A bar
-- wearing the shell shows it on the shell's own fine line; the copy of its
-- faded Classic border isn't drawn.
local function Line(cast,r,g,b)
 local classic=EraUI.Classic
 if classic and classic.TintRoundedCast then classic.TintRoundedCast(cast,r,g,b) end
end
local CastShown
local function Accent(cast,unit,own)
 if not cast then return end
 local outline=outlines[cast]
 local player=UnitIsPlayer(unit)
 if not On() or not Public(player) or not player then
  HideOutline(outline);if own then Line(cast) end;return
 end
 local _,class=UnitClass(unit)
 if not Public(class) then HideOutline(outline);if own then Line(cast) end;return end
 local colour=(CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
 if not colour then HideOutline(outline);if own then Line(cast) end;return end
 if own then
  local r,g,b=colour.r,colour.g,colour.b
  if class=="PALADIN" then r,g,b=.96,.55,.73 end
  Line(cast,r,g,b)
  local classic=EraUI.Classic
  if classic and classic.RoundedCastShown and classic.RoundedCastShown(cast) then
   HideOutline(outline);return
  end
 end
 local border=cast.Border
 if not border or not border.GetTexture or not border:GetTexture() then
  HideOutline(outline);return
 end
 if not outline then
  outline=CreateFrame("Frame",nil,cast,"BackdropTemplate");outlines[cast]=outline
  outline:SetPoint("TOPLEFT",-2,2);outline:SetPoint("BOTTOMRIGHT",2,-2);outline:EnableMouse(false)
  -- Share the native bar's draw layers so its OVERLAY spell text stays above the tint.
  outline.art=cast:CreateTexture(nil,"ARTWORK",nil,7)
  outline:HookScript("OnHide",function()outline.art:Hide()end)
  outline:HookScript("OnShow",function()outline.art:Show()end)
  cast:HookScript("OnShow",CastShown)
 end
 local r,g,b=colour.r,colour.g,colour.b
 if class=="PALADIN" then r,g,b=.96,.55,.73 end
 outline.art:ClearAllPoints();outline.art:SetAllPoints(border)
 -- The border's own piece: its atlas when it wears one (the game's cast bar
 -- art is one piece of a big sheet; its file alone drew the whole sheet,
 -- the striped bar seen in game), else its file and coords.
 local atlas=border.GetAtlas and border:GetAtlas()
 if Public(atlas) and type(atlas)=="string" and atlas~="" then outline.art:SetAtlas(atlas)
 else
  outline.art:SetTexture(border:GetTexture())
  outline.art:SetTexCoord(border:GetTexCoord())
 end
 outline.art:SetVertexColor(r,g,b,.8);outline:Show();outline.art:Show()
end
-- One nameplate's cast bar, painted for its plate's unit now.
local function PlateCast(plate)
 local frame=plate and plate.UnitFrame
 local unit=plate and plate.namePlateUnitToken
 if not frame or not Public(unit) or type(unit)~="string" then return end
 local container=frame.CastBarsContainer
 local cast=container and container.castBar or frame.castBar
 if not cast then return end
 barPlates[cast]=plate
 Accent(cast,unit)
end
-- A bar showing (a new cast) repaints only itself.
CastShown=function(cast)
 local unit=barUnits[cast]
 if unit then return Accent(cast,unit,true) end
 local plate=barPlates[cast]
 if plate and not HandedOver() then PlateCast(plate) end
end
-- The target and focus reputation strips and EraUI's own three bars.
function M:RefreshFrames()
 for _,entry in ipairs(REPUTATION)do
  local frame,unit=_G[entry[1]],entry[2]
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
 local player=PlayerCastingBarFrame or CastingBarFrame
 local target=TargetFrame and TargetFrame.spellbar
 local focus=FocusFrame and FocusFrame.spellbar
 if player then barUnits[player]="player" end
 if target then barUnits[target]="target" end
 if focus then barUnits[focus]="focus" end
 Accent(player,"player",true)
 Accent(target,"target",true)
 Accent(focus,"focus",true)
end
-- Every nameplate's cast bar. Switched off, only the outlines already made
-- are hidden: no plate is looked at.
function M:RefreshPlates()
 if not On() then
  for cast,outline in pairs(outlines)do
   if barPlates[cast] then HideOutline(outline) end
  end
  return
 end
 if HandedOver() or not(C_NamePlate and C_NamePlate.GetNamePlates)then return end
 for _,plate in ipairs(C_NamePlate.GetNamePlates()) do PlateCast(plate) end
end
function M:Refresh()
 self:RefreshFrames()
 self:RefreshPlates()
end
-- Rounded Cast Bars puts its shell on a bar: the copy of the faded Classic
-- border goes at once (drawn before the shell went on, at login or a switch,
-- it showed over the rounded bar: the striped and gold-framed bars the user
-- saw on 2026-10-11).
function M:HideCastOutline(cast)
 local outline=cast and outlines[cast]
 HideOutline(outline)
end
-- A plate given a unit or losing one: only that plate. Nothing at all while
-- Class-coloured Cast Border has never made an outline and is off.
local function PlateEvent(unit,removed)
 if HandedOver() or not Public(unit) or type(unit)~="string" then return end
 if not On() and next(outlines)==nil then return end
 local plate=C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
 if not plate then return end
 if removed then
  local frame=plate.UnitFrame
  local container=frame and frame.CastBarsContainer
  local cast=container and container.castBar or(frame and frame.castBar)
  HideOutline(cast and outlines[cast])
  return
 end
 PlateCast(plate)
end
function M:Initialize()
 local f=CreateFrame("Frame")
 for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","ADDON_LOADED","NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED"})do f:RegisterEvent(event)end
 f:SetScript("OnEvent",function(_,event,unit)
  if event=="NAME_PLATE_UNIT_ADDED" or event=="NAME_PLATE_UNIT_REMOVED" then
   PlateEvent(unit,event=="NAME_PLATE_UNIT_REMOVED")
  elseif event=="PLAYER_TARGET_CHANGED" or event=="PLAYER_FOCUS_CHANGED" then
   self:RefreshFrames()
  else
   self:Refresh()
  end
 end)
 self:Refresh()
end

