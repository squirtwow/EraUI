local _,E=...
local M={};E:RegisterModule("MovableMap",M)
local frame,border,dragHandle
local grips={}

local function Enabled()return E:GetSetting("enabled") and E:GetSetting("movableMap")end

local function SavePosition()
 local x,y=frame:GetCenter();local cx,cy=UIParent:GetCenter()
 E:SetSetting("mapPosition",{x=x-cx,y=y-cy})
 E:SetSetting("mapSize",{w=frame:GetWidth(),h=frame:GetHeight()})
end

local function Grip(point,sizing,ox,oy,glyph)
 local g=CreateFrame("Frame",nil,border)
 g:SetSize(18,18);g:SetPoint(point,border,point,ox or 0,oy or 0)
 g:EnableMouse(true)
 g:SetScript("OnMouseDown",function()if Enabled()and not InCombatLockdown()then frame:StartSizing(sizing)end end)
 g:SetScript("OnMouseUp",function()if Enabled()and not InCombatLockdown()then frame:StopMovingOrSizing();SavePosition()end end)
 if glyph then
  local tex=g:CreateTexture(nil,"ARTWORK")
  tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  tex:SetSize(16,16)
  tex:SetAlpha(0.85)
  if glyph=="left" then
   tex:SetPoint("BOTTOMLEFT",g,"BOTTOMLEFT",-1,1)
   tex:SetTexCoord(1,0,0,1)
  else
   tex:SetPoint("BOTTOMRIGHT",g,"BOTTOMRIGHT",1,1)
  end
 end
 grips[#grips+1]=g
end

-- The client keeps the map canvas at a fixed size when the window is resized;
-- stretch the canvas to follow the window so a bigger map shows more world.
local function FitCanvas()
 if not frame or not Enabled()then return end
 local w,h=frame:GetWidth(),frame:GetHeight()
 if not w or not h then return end
 if frame.OnFrameSizeChanged then pcall(frame.OnFrameSizeChanged,frame,w,h)end
 local scroll=frame.ScrollContainer
 if not scroll then return end
 if scroll:GetNumPoints()==0 and scroll.SetSize then
  scroll:SetSize(math.max(200,w-10),math.max(200,h-10))
 end
 local canvas=(scroll.GetCanvas and scroll:GetCanvas())or scroll.Canvas or scroll.MapCanvas
 if not canvas or not canvas.SetSize then return end
 local sw,sh=scroll:GetWidth(),scroll:GetHeight()
 if not sw or not sh then return end
 if canvas:GetNumPoints()>0 then canvas:ClearAllPoints()end
 if math.abs((canvas:GetWidth()or 0)-sw)>2 or math.abs((canvas:GetHeight()or 0)-sh)>2 then
  canvas:SetSize(sw,sh)
 end
end

-- Fog of war: this client draws the fog as a dedicated overlay frame
-- (object type "FogOfWarFrame") inside the map's scroll container, over
-- the terrain drawn beneath it. Revealing fades that overlay out.
local fogFrame
local function FindFogFrame()
 if fogFrame then return fogFrame end
 local sc=frame and frame.ScrollContainer
 if not sc then return nil end
 local function check(node,depth)
  if not node or depth<=0 then return end
  for _,child in ipairs({node:GetChildren()})do
   if child.GetObjectType and child:GetObjectType()=="FogOfWarFrame" then
    fogFrame=child
    return fogFrame
   end
   check(child,depth-1)
  end
 end
 check(sc,6)
 return fogFrame
end
local function ApplyReveal()
 local fog=FindFogFrame()
 if not fog then return end
 local on=E:GetSetting("revealMap")==true and E:GetSetting("enabled")==true
 local want=on and 0 or 1
 if fog.SetAlpha and math.abs((fog:GetAlpha()or 1)-want)>0.01 then fog:SetAlpha(want)end
 if fog.SetShown then fog:SetShown(not on)end
 if fog.SetMaskTexture and on then pcall(fog.SetMaskTexture,fog,nil)end
 local function tintTex(tex)
  if tex.SetAlpha and tex.GetObjectType and tex:GetObjectType()=="Texture" and math.abs((tex:GetAlpha()or 1)-want)>0.01 then
   tex:SetAlpha(want)
  end
 end
 if fog.GetRegions then
  for _,region in ipairs({fog:GetRegions()})do tintTex(region)end
 end
 local function tint(node,depth)
  if not node or depth<=0 then return end
  for _,child in ipairs({node:GetChildren()})do
   tintTex(child)
   tint(child,depth-1)
  end
 end
 tint(fog,3)
end

function M:Apply()
 if not frame then return end
 local on=Enabled()
 for _,g in ipairs(grips)do g:SetShown(on)end
 if dragHandle then dragHandle:EnableMouse(on)end
 ApplyReveal()
end

function M:Setup()
 frame=_G.WorldMapFrame;border=frame and frame.BorderFrame
 if not frame or not border then return end
 frame:SetMovable(true);frame:SetClampedToScreen(true);frame:SetResizable(true)
 frame:SetResizeBounds(380,300,UIParent:GetWidth()+200,UIParent:GetHeight()+200)
 -- Drag only from the header strip, so the map itself keeps its own
 -- right-click zoom and zone clicks. The strip stops short of the
 -- maximize and close buttons.
 dragHandle=CreateFrame("Frame",nil,border)
 dragHandle:SetHeight(34)
 dragHandle:SetPoint("TOPLEFT",border,"TOPLEFT",0,0)
 local sizer=border.MaximizeMinimizeFrame
 if sizer then
  dragHandle:SetPoint("RIGHT",sizer,"LEFT",-2,0)
 else
  dragHandle:SetPoint("TOPRIGHT",border,"TOPRIGHT",-80,0)
 end
 dragHandle:EnableMouse(true)
 dragHandle:RegisterForDrag("LeftButton")
 dragHandle:SetScript("OnDragStart",function()if Enabled()and not InCombatLockdown()then frame:StartMoving()end end)
 dragHandle:SetScript("OnDragStop",function()if Enabled()and not InCombatLockdown()then frame:StopMovingOrSizing();SavePosition()end end)
 frame:HookScript("OnSizeChanged",function()if not InCombatLockdown()then C_Timer.After(0,FitCanvas)end end)
 frame:HookScript("OnShow",function()C_Timer.After(0,FitCanvas)end)
 -- The client can redraw its fog when the map changes; keep the reveal
 -- applied while the map is open.
 local revealDriver=CreateFrame("Frame")
 revealDriver.elapsed=0
 revealDriver:SetScript("OnUpdate",function(self,dt)
  self.elapsed=(self.elapsed or 0)+dt
  if self.elapsed<0.5 then return end
  self.elapsed=0
  if frame and frame:IsShown()then ApplyReveal()end
 end)
 -- Bottom and side grips; the top edge stays for dragging (the close and
 -- maximize buttons live up there).
 Grip("BOTTOMLEFT","BOTTOMLEFT",3,-3,"left")
 Grip("BOTTOMRIGHT","BOTTOMRIGHT",-3,-3,"right")
 Grip("BOTTOM","BOTTOM")
 Grip("LEFT","LEFT",3,0)
 Grip("RIGHT","RIGHT",-3,0)
 self:Apply()
 -- Restore the saved spot and size from the last session.
 local pos=E:GetSetting("mapPosition")
 if type(pos)=="table" and tonumber(pos.x)and tonumber(pos.y)then
  frame:ClearAllPoints();frame:SetPoint("CENTER",UIParent,"CENTER",pos.x,pos.y)
 end
 local size=E:GetSetting("mapSize")
 if type(size)=="table" and tonumber(size.w)and tonumber(size.h)then
  frame:SetSize(size.w,size.h)
 end
 C_Timer.After(0,FitCanvas)
end

function M:Initialize()
 if _G.WorldMapFrame then M:Setup()return end
 local f=CreateFrame("Frame");f:RegisterEvent("ADDON_LOADED")
 f:SetScript("OnEvent",function()
  if _G.WorldMapFrame then M:Setup();f:SetScript("OnEvent",nil);f:UnregisterEvent("ADDON_LOADED")end
 end)
end
