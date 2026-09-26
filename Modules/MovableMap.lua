local _,E=...
local M={};E:RegisterModule("MovableMap",M)
local frame,border,dragHandle
local grips={}
local interaction,restoring,queued,canvasBusy
local Restore,StopInteraction
local overlayApplied
local overlayLevels={}

local function Enabled()return E:GetSetting("enabled") and E:GetSetting("movableMap")end

local function Expanded()return frame.IsMaximized and frame:IsMaximized()end
local function Ratio()return frame:GetEffectiveScale()/UIParent:GetEffectiveScale()end
local function Record(key)
 local all=E:GetSetting(key)
 if type(all)~="table"then return end
 if Expanded()then
  if type(all.expanded)=="table"then return all.expanded end
   if not all.version or all.version<2 then return all end -- Earlier builds shared one record for both modes.
  return nil
 end
 return all
end
local function Store(key,value)
 local old=E:GetSetting(key)
 local all={};for k,v in pairs(type(old)=="table"and old or{})do all[k]=v end
 if Expanded()then all.expanded=value
 else for k,v in pairs(value)do all[k]=v end end
 E:SetSetting(key,all)
end
local function SavePosition()
 local x,y=frame:GetCenter();local cx,cy=UIParent:GetCenter();local ratio=Ratio()
 if not x or not y then return end
 Store("mapPosition",{x=x*ratio-cx,y=y*ratio-cy,version=2})
 Store("mapSize",{w=frame:GetWidth(),h=frame:GetHeight(),version=3})
end

local function OverlayLayout()
 local scroll=frame and frame.ScrollContainer
 if not scroll or InCombatLockdown()then return end
 if Enabled()then
  -- Leave the native canvas and its pins intact. Only its viewport spans the
  -- full window; the opaque quest panel covers the right side when requested.
  scroll:SetPoint("RIGHT",frame,"RIGHT",-3,0)
  overlayApplied=true
  local quest=frame.QuestLog
  local toggle=frame.SidePanelToggle
  for _,f in pairs({quest,toggle})do
   if f and not overlayLevels[f]then overlayLevels[f]={f:GetFrameStrata(),f:GetFrameLevel()}end
  end
  if quest then quest:SetFrameStrata("HIGH");quest:SetFrameLevel(math.max(overlayLevels[quest][2],scroll:GetFrameLevel()+20))end
  if toggle then toggle:SetFrameStrata("HIGH");toggle:SetFrameLevel((quest and quest:GetFrameLevel()or scroll:GetFrameLevel())+30)end
 elseif overlayApplied then
  scroll:SetPoint("RIGHT",frame.TitleCanvasSpacerFrame,"RIGHT",0,0)
  for f,v in pairs(overlayLevels)do f:SetFrameStrata(v[1]);f:SetFrameLevel(v[2])end
  overlayApplied=false
 end
end

-- Only the native map canvas owns its dimensions, zoom, pins and texture pools.
-- OnFrameSizeChanged performs an immediate native fit, without delayed resizes.
local function FitCanvas()
 if canvasBusy or not frame or not Enabled()or InCombatLockdown()then return end
 canvasBusy=true
 OverlayLayout()
 if frame.OnFrameSizeChanged then frame:OnFrameSizeChanged()end
 canvasBusy=false
end
local function FixPinButton()
 local pin=frame and frame.WorldMapTrackingPinButton
 if not pin or InCombatLockdown()then return end
 -- Forever's AdjustOverlayFrames places this 32px button at the top left.
 pin:ClearAllPoints();pin:SetPoint("TOPLEFT",frame.ScrollContainer,"TOPLEFT",3,0)
 pin:SetSize(32,32);pin:SetHitRectInsets(0,0,0,0)
 local highlight=pin:GetHighlightTexture()
 if highlight then highlight:ClearAllPoints();highlight:SetAllPoints(pin)end
end
local function Metrics()
 local scroll=frame.ScrollContainer
 local cw=scroll and math.max(0,frame:GetWidth()-scroll:GetWidth())or 5
 local ch=scroll and math.max(0,frame:GetHeight()-scroll:GetHeight())or 69
 local canvas=frame.GetCanvas and frame:GetCanvas()
 local w,h=canvas and canvas:GetWidth(),canvas and canvas:GetHeight()
 local aspect=w and h and h>0 and w/h or 1.5
 return cw,ch,aspect
end
local function SizeForWidth(w,cw,ch,aspect)
 local ratio=Ratio()
 local maxW=math.min((UIParent:GetWidth()-16)/ratio,((UIParent:GetHeight()-16)/ratio-ch)*aspect+cw)
 maxW=math.max(cw+1,maxW)
 local minW=math.min(maxW,math.max(380,(300-ch)*aspect+cw))
 w=math.max(minW,math.min(maxW,w))
 return w,(w-cw)/aspect+ch
end
local function QueueRestore()
 if queued or restoring or interaction or not frame or not frame:IsShown()or not Enabled()then return end
 queued=true
 C_Timer.After(0,function()
  queued=false
  if frame and frame:IsShown()and not interaction then Restore()end
 end)
end
local function ResizeTick()
 local s=interaction
 if not s or InCombatLockdown()then return end
 local x,y=GetCursorPosition();x=x/frame:GetEffectiveScale();y=y/frame:GetEffectiveScale()
 if s.kind=="drag"then
  frame:ClearAllPoints();frame:SetPoint("CENTER",UIParent,"BOTTOMLEFT",s.cx+x-s.x,s.cy+y-s.y)
  return
 end
 local dx=(x-s.x)*(s.left and -1 or 1);local dy=s.y-y
 local delta
 if s.edge=="BOTTOM"then delta=dy*s.aspect
 elseif s.edge=="LEFT"or s.edge=="RIGHT"then delta=dx
 else delta=(dx+dy/s.aspect)/(1+1/(s.aspect*s.aspect))end
 local w,h=SizeForWidth(s.w+delta,s.cw,s.ch,s.aspect)
 frame:SetSize(w,h)
end
local function BeginResize(edge)
 if not Enabled()or InCombatLockdown()then return end
 local x,y=GetCursorPosition();local scale=frame:GetEffectiveScale()
 local cw,ch,aspect=Metrics();local left=edge=="LEFT"or edge=="BOTTOMLEFT"
 local px=left and frame:GetRight()or frame:GetLeft();local top=frame:GetTop()
 interaction={kind="resize",edge=edge,left=left,x=x/scale,y=y/scale,w=frame:GetWidth(),cw=cw,ch=ch,aspect=aspect}
 frame:ClearAllPoints();frame:SetPoint(left and "TOPRIGHT"or "TOPLEFT",UIParent,"BOTTOMLEFT",px,top)
end
StopInteraction=function()
 if not interaction then return end
 if InCombatLockdown()then interaction=nil;return end
 ResizeTick()
 interaction=nil
 local x,y=frame:GetCenter();local cx,cy=UIParent:GetCenter();local ratio=Ratio()
 if not x or not y then return end
 frame:ClearAllPoints();frame:SetPoint("CENTER",UIParent,"CENTER",x-cx/ratio,y-cy/ratio)
 SavePosition()
end
Restore=function()
 if not frame or not Enabled()or restoring or interaction or InCombatLockdown()then return end
 restoring=true
 OverlayLayout()
 local size=Record("mapSize")
 if size and tonumber(size.w)then
   if size.version==3 and tonumber(size.h)and size.w>0 and size.h>0 then
   local factor=math.min(1,(UIParent:GetWidth()-16)/(size.w*Ratio()),(UIParent:GetHeight()-16)/(size.h*Ratio()))
   frame:SetSize(size.w*factor,size.h*factor)
  else
   local cw,ch,aspect=Metrics()
   frame:SetSize(SizeForWidth(tonumber(size.w),cw,ch,aspect))
  end
 end
 local pos=Record("mapPosition")
 if pos and tonumber(pos.x)and tonumber(pos.y)then
  local ratio=Ratio()
  frame:ClearAllPoints();frame:SetPoint("CENTER",UIParent,"CENTER",pos.x/ratio,pos.y/ratio)
 end
 FixPinButton()
 -- Remember the initial layout too, before native sidebar code changes it.
 if not size or size.version~=3 then SavePosition()end
 restoring=false
end

local function Grip(point,sizing,ox,oy,glyph)
 local g=CreateFrame("Frame",nil,border)
 g:SetSize(18,18);g:SetPoint(point,border,point,ox or 0,oy or 0)
 g:EnableMouse(true)
 g:SetScript("OnMouseDown",function(_,button)if button=="LeftButton"then BeginResize(sizing)end end)
 g:SetScript("OnMouseUp",function(_,button)if button=="LeftButton"then StopInteraction()end end)
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

-- This size-based candidate is used only in the diagnostic report.
local function CanvasNode()
 local sc=frame and frame.ScrollContainer
 if not sc then return nil end
 local best,bw,bh
 for _,child in ipairs({sc:GetChildren()})do
  local w,h=child:GetWidth(),child:GetHeight()
  if w and h and w>1 and h>1 then
   if not bw or w*h>bw*bh then best,bw,bh=child,w,h end
  end
 end
 return best
end

function M:Refit()
 FitCanvas()
end
function M:Dump()
 if not frame then E:Print("World map has not been opened yet. Open it once, then run this again.")return end
 local function line(...)
  local parts={}
  for _,v in ipairs({...})do parts[#parts+1]=tostring(v)end
  E:Print(table.concat(parts," "))
 end
 line("map",frame:GetWidth(),"x",frame:GetHeight())
 local sc=frame.ScrollContainer
 if not sc then line("no ScrollContainer")return end
 line("scroll",sc:GetWidth(),"x",sc:GetHeight(),"points",sc:GetNumPoints())
 if sc.GetCanvas then local ok,v=pcall(sc.GetCanvas,sc);line("GetCanvas",ok and v or "error")end
 line("fields Canvas",sc.Canvas,"MapCanvas",sc.MapCanvas,"CanvasContainer",rawget(sc,"CanvasContainer"),"ScrollChild",rawget(sc,"ScrollChild"))
 for i,child in ipairs({sc:GetChildren()})do
  line("child",i,child:GetName(),child.GetObjectType and child:GetObjectType(),child:GetWidth(),"x",child:GetHeight(),child:IsShown()and "shown"or "hidden")
 end
 local regions={sc.GetRegions and sc:GetRegions()}
 for i=1,#regions do
  local r=regions[i]
  line("region",i,r:GetObjectType(),r.GetTexture and r:GetTexture(),r.GetWidth and r:GetWidth(),"x",r.GetHeight and r:GetHeight())
 end
end
function M:DumpText()
 local lines={}
 local function add(s)lines[#lines+1]=s end
 local function px(v)return tostring(v and math.floor(v)or 0)end
 if not frame then add("Open the world map once, then run this again.")return table.concat(lines,"\n")end
 add("window "..px(frame:GetWidth()).." x "..px(frame:GetHeight()).." strata "..tostring(frame:GetFrameStrata()))
 local kids={frame:GetChildren()}
 add("window children "..#kids)
 for i=1,math.min(#kids,22)do
  local c=kids[i]
  add("w"..i.." "..tostring(c:GetName()).." "..tostring(c.GetObjectType and c:GetObjectType()).." "..px(c:GetWidth()).." x "..px(c:GetHeight())..(c:IsShown()and" shown"or" hidden"))
 end
 local sc=frame.ScrollContainer
 local wregions={frame:GetRegions()}
 add("window regions "..#wregions)
 for i=1,math.min(#wregions,24)do
  local r=wregions[i]
  if r.GetObjectType and r:GetObjectType()=="Texture"then
   add("t"..i.." "..tostring(r.GetTexture and r:GetTexture()).." "..px(r.GetWidth and r:GetWidth()or 0).." x "..px(r.GetHeight and r:GetHeight()or 0).." a="..tostring(r.GetAlpha and math.floor((r:GetAlpha()or 0)*100)or"?").." p="..tostring(r.GetDrawLayer and r:GetDrawLayer()or"?"))
  end
 end
 if sc then
  add("scroll "..px(sc:GetWidth()).." x "..px(sc:GetHeight()))
  local skids={sc:GetChildren()}
  for i=1,#skids do
   local c=skids[i]
   add("s"..i.." "..tostring(c:GetName()).." "..tostring(c.GetObjectType and c:GetObjectType()).." "..px(c:GetWidth()).." x "..px(c:GetHeight()))
   local gkids={c.GetChildren and c:GetChildren()}
   for j=1,math.min(#gkids,8)do
    local g=gkids[j]
    add("  s"..i.."."..j.." "..tostring(g:GetName()).." "..tostring(g.GetObjectType and g:GetObjectType()).." "..px(g:GetWidth()).." x "..px(g:GetHeight()))
   end
  end
 end
 add("mapID field "..tostring(frame.mapID))
 if frame.GetMapID then local ok,id=pcall(frame.GetMapID,frame);add("GetMapID "..tostring(ok and id or"error"))end
 if C_Map and C_Map.GetBestMapForUnit then local ok,z=pcall(C_Map.GetBestMapForUnit,"player");add("player zone "..tostring(ok and z or"error"))end
 if C_Map and C_Map.GetMapInfo then
  local id=tonumber(frame.mapID)
  if id then local ok,info=pcall(C_Map.GetMapInfo,id);add("shown name "..tostring(ok and info and info.name or"?"))end
 end
 if C_Map and C_Map.GetMapArtLayers then
  local id=tonumber(frame.mapID)
  if id then
   local ok,layers=pcall(C_Map.GetMapArtLayers,id)
   if ok and type(layers)=="table"then
    add("layers "..#layers)
    for i=1,math.min(#layers,6)do
     local info=layers[i]
     if info then add("layer "..i.." tile "..tostring(info.tileWidth).."x"..tostring(info.tileHeight).." map "..tostring(info.mapID))end
    end
   end
   if C_Map.GetMapArtLayerTextures then
    for i=1,4 do
     local ok2,files=pcall(C_Map.GetMapArtLayerTextures,id,i)
     if ok2 and type(files)=="table"then add("layerTextures "..i.." count "..#files)end
    end
   end
   local canvas=CanvasNode()
    if canvas then add("canvas candidate "..px(canvas:GetWidth()).." x "..px(canvas:GetHeight()))end
  end
 end
 if frame.GetMap then
  local ok,m=pcall(frame.GetMap,frame)
  add("GetMap "..tostring(ok and"ok"or m))
  if ok and m then
   if m.GetMapID then local o,id=pcall(m.GetMapID,m);add("mapID "..tostring(o and id or"error"))
    if o and id and C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures then
     local o2,t=pcall(C_MapExplorationInfo.GetExploredMapTextures,id)
     if o2 and type(t)=="table"then
      add("explored tiles "..#t)
      local one=t[1]
      if one then add("  offset "..tostring(one.offsetX)..","..tostring(one.offsetY).." size "..tostring(one.textureWidth).."x"..tostring(one.textureHeight).." files "..tostring(one.fileDataIDs and#one.fileDataIDs or 0))end
     else add("explored error")end
    end
   end
   if m.GetCanvasContainer then
    local o,cc=pcall(m.GetCanvasContainer,m)
    add("canvasContainer "..tostring(o and cc or"error"))
    if o and cc then
     if cc.GetCanvas then local o3,cv=pcall(cc.GetCanvas,cc);add("  canvas "..tostring(o3 and cv or"error"));if o3 and cv then add("  canvas size "..px(cv:GetWidth()).." x "..px(cv:GetHeight()))end end
     if cc.GetCurrentLayerIndex then local o4,li=pcall(cc.GetCurrentLayerIndex,cc);add("  layer "..tostring(o4 and li or"error"))end
    end
   end
  end
 end
  local reveal=E.modules.MapReveal
  if reveal then add(reveal:DumpText())end
  return table.concat(lines,"\n")
end
function M:Apply()
 if not frame then return end
 local on=Enabled()
 if not on then StopInteraction()end
 for _,g in ipairs(grips)do g:SetShown(on)end
 if dragHandle then dragHandle:EnableMouse(on)end
 OverlayLayout()
 if not on and frame.OnFrameSizeChanged and not InCombatLockdown()then frame:OnFrameSizeChanged()end
 if on then QueueRestore()end
end

function M:Setup()
 if self.ready or InCombatLockdown()then return end
 frame=_G.WorldMapFrame;border=frame and frame.BorderFrame
 if not frame or not border then return end
 self.ready=true
 frame:SetMovable(true);frame:SetClampedToScreen(true)
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
 dragHandle:SetScript("OnDragStart",function()
  if Enabled()and not InCombatLockdown()then
   local x,y=GetCursorPosition();local cx,cy=frame:GetCenter();local scale=frame:GetEffectiveScale()
   interaction={kind="drag",x=x/scale,y=y/scale,cx=cx,cy=cy}
  end
 end)
 dragHandle:SetScript("OnDragStop",StopInteraction)
 frame:HookScript("OnSizeChanged",FitCanvas)
 frame:HookScript("OnShow",QueueRestore)
 frame:HookScript("OnHide",StopInteraction)
 frame:HookScript("OnUpdate",function()
  if interaction then
   if IsMouseButtonDown and not IsMouseButtonDown("LeftButton")then StopInteraction()else ResizeTick()end
  end
 end)
 for _,method in ipairs({"Maximize","Minimize","SynchronizeDisplayState","UpdateSpacerFrameAnchoring"})do
  if frame[method]then hooksecurefunc(frame,method,function()OverlayLayout();QueueRestore()end)end
 end
 if frame.SetQuestLogPanelShown then
  hooksecurefunc(frame,"SetQuestLogPanelShown",function()
   local size=Record("mapSize")
   if frame:IsShown()and size and size.version==3 then Restore()else QueueRestore()end
  end)
 end
 if frame.AdjustOverlayFrames then hooksecurefunc(frame,"AdjustOverlayFrames",function()if Enabled()then FixPinButton()end end)end
 if UpdateUIPanelPositions then hooksecurefunc("UpdateUIPanelPositions",QueueRestore)end
 local events=CreateFrame("Frame")
 for _,event in ipairs({"PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED"})do events:RegisterEvent(event)end
 events:SetScript("OnEvent",function(_,event)
  if event=="PLAYER_REGEN_DISABLED"then
   if interaction then SavePosition();interaction=nil end
  else QueueRestore()end
 end)
 -- Bottom and side grips; the top edge stays for dragging (the close and
 -- maximize buttons live up there).
 Grip("BOTTOMLEFT","BOTTOMLEFT",3,-3,"left")
 Grip("BOTTOMRIGHT","BOTTOMRIGHT",-3,-3,"right")
 Grip("BOTTOM","BOTTOM")
 Grip("LEFT","LEFT",3,0)
 Grip("RIGHT","RIGHT",-3,0)
 self:Apply()
 QueueRestore()
end

function M:Initialize()
 if _G.WorldMapFrame and not InCombatLockdown()then M:Setup()return end
 local f=CreateFrame("Frame");f:RegisterEvent("ADDON_LOADED");f:RegisterEvent("PLAYER_REGEN_ENABLED")
 f:SetScript("OnEvent",function()
  if _G.WorldMapFrame and not InCombatLockdown()then
   M:Setup();f:SetScript("OnEvent",nil);f:UnregisterEvent("ADDON_LOADED");f:UnregisterEvent("PLAYER_REGEN_ENABLED")
  end
 end)
end
