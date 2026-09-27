-- Geometry/lifecycle simulations for the actual movable map module. Blizzard
-- owns the map's size and canvas fit: the fixture errors if addon code refits
-- the canvas. Resizing scales the window, and Blizzard's window manager
-- re-anchoring the map (in combat too) is undone within the same call.
local checks=0
local function equal(got,want,label)
 checks=checks+1;assert(got==want,label..": expected "..tostring(want)..", got "..tostring(got))
end
local function near(got,want,label)equal(math.abs(got-want)<.01,true,label.." ("..tostring(got).." vs "..tostring(want)..")")end
local frames,timers,combat,cursorX,cursorY,down
local methods={}
local function New(parent)
 local f=setmetatable({parent=parent,w=1,h=1,scale=1,shown=true,scripts={},hooks={},points={}},{__index=methods})
 frames[#frames+1]=f;return f
end
function methods:Fire(event,...)
 if self.scripts[event]then self.scripts[event](self,...)end
 for _,fn in ipairs(self.hooks[event]or{})do fn(self,...)end
end
function methods:SetScript(event,fn)self.scripts[event]=fn end
function methods:HookScript(event,fn)self.hooks[event]=self.hooks[event]or{};table.insert(self.hooks[event],fn)end
-- The client refuses addon geometry changes on protected frames in combat;
-- Blizzard's secure code (secureDepth > 0) may make them.
local secureDepth=0
local function Guard(f)assert(not(combat and f.protected)or secureDepth>0,"protected layout mutation in combat")end
function methods:SetSize(w,h)Guard(self);self.w,self.h=w,h end
function methods:SetWidth(w)self:SetSize(w,self.h)end
function methods:SetHeight(h)self:SetSize(self.w,h)end
function methods:GetWidth()return self.w end
function methods:GetHeight()return self.h end
function methods:SetScale(s)Guard(self);self.scale=s end
function methods:GetScale()return self.scale end
function methods:IsProtected()return self.protected==true end
function methods:GetEffectiveScale()return self.scale*(self.parent and self.parent:GetEffectiveScale()or 1)end
function methods:ClearAllPoints()Guard(self);self.points={}end
function methods:SetPoint(...)
 Guard(self);local args={...}
 for i,p in ipairs(self.points)do if p[1]==args[1]then self.points[i]=args;return end end
 self.points[#self.points+1]=args
end
function methods:GetFrameLevel()return self.level or 1 end
function methods:SetFrameLevel(n)self.level=n end
function methods:GetFrameStrata()return self.strata or "MEDIUM"end
function methods:SetFrameStrata(s)self.strata=s end
function methods:SetAllPoints(f)self.points={{"ALL",f}}end
function methods:GetNumPoints()return #self.points end
-- Centre in the frame's own coordinates (UIParent units divided by scale).
function methods:GetCenter()
 if self==UIParent then return self.w/2,self.h/2 end
 local p=self.points[1]
 if not p then return 0,0 end
 local anchor,relative,relativeAnchor,x,y=table.unpack(p)
 local ratio=relative:GetEffectiveScale()/self:GetEffectiveScale()
 local rx,ry=relative:GetCenter()
 if relativeAnchor=="BOTTOMLEFT"then rx=rx-relative:GetWidth()/2;ry=ry-relative:GetHeight()/2 end
 local cx,cy=rx*ratio+(x or 0),ry*ratio+(y or 0)
 if anchor=="TOPLEFT"then cx=cx+self.w/2;cy=cy-self.h/2
 elseif anchor=="TOPRIGHT"then cx=cx-self.w/2;cy=cy-self.h/2
 elseif anchor=="TOP"then cy=cy-self.h/2 end
 return cx,cy
end
function methods:GetLeft()return self:GetCenter()-self.w/2 end
function methods:GetRight()return self:GetCenter()+self.w/2 end
function methods:GetTop()return select(2,self:GetCenter())+self.h/2 end
function methods:IsShown()return self.shown end
function methods:SetShown(v)self.shown=v end
function methods:Show()self.shown=true;self:Fire("OnShow")end
function methods:Hide()self.shown=false;self:Fire("OnHide")end
function methods:CreateTexture()return New(self)end
function methods:SetHitRectInsets(...)self.insets={...}end
function methods:GetHighlightTexture()return self.highlight end
for _,key in ipairs({"EnableMouse","RegisterForDrag","SetMovable","SetClampedToScreen","SetTexture","SetAlpha","SetTexCoord","RegisterEvent","UnregisterEvent"})do methods[key]=function()end end
CreateFrame=function(_,_,parent)return New(parent)end
InCombatLockdown=function()return combat end
GetCursorPosition=function()return cursorX,cursorY end
IsMouseButtonDown=function()return down end
-- Like the client: the original runs first, then the hook as addon code.
hooksecurefunc=function(t,key,callback)
 if type(t)=="string"then callback=key;key=t;t=_G end
 local old=t[key];t[key]=function(...)
  local result={old(...)}
  local depth=secureDepth;secureDepth=0;callback(...);secureDepth=depth
  return table.unpack(result)
 end
end
local function Flush()
 for _=1,12 do if #timers==0 then return end;local pending=timers;timers={};for _,fn in ipairs(pending)do fn()end end
 error("restore loop")
end
local BLIZZ_X,BLIZZ_Y=-200,50 -- Where Blizzard's window manager puts the map.
local function Session(db)
 frames,timers,combat,cursorX,cursorY,down={},{},false,500,500,true
 C_Timer={After=function(delay,fn)equal(delay,0,"no delayed timers");timers[#timers+1]=fn end}
 UIParent=New();UIParent.w,UIParent.h,UIParent.scale=2560/.65,1440/.65,.65
 local map=New(UIParent);WorldMapFrame=map;map.w,map.h,map.shown=702,534,false
 map.points={{"CENTER",UIParent,"CENTER",0,0}}
 map.BorderFrame=New(map)
 map.ScrollContainer=New(map)
 map.TitleCanvasSpacerFrame=New(map)
 map.QuestLog=New(map);map.SidePanelToggle=New(map)
 local scroll=map.ScrollContainer
 scroll.GetWidth=function()
  for _,p in ipairs(scroll.points)do if p[1]=="RIGHT"and p[2]==map then return map.w-5 end end
  return map.w-5-(map.sidebar or 0)
 end
 scroll.GetHeight=function()return map.h-69 end
 -- Only Blizzard's own code may refit the canvas.
 local blizzard=0
 local function Blizzard(fn,...)blizzard=blizzard+1;fn(...);blizzard=blizzard-1 end
 map.fits=0
 function map:OnFrameSizeChanged()
  assert(blizzard>0,"addon code refit the map canvas")
  self.fits=self.fits+1
  self.fittedW=scroll:GetWidth()
 end
 function map:IsMaximized()return self.expanded==true end
 -- Blizzard's window manager (secure code).
 UpdateUIPanelPositions=function()
  secureDepth=secureDepth+1
  map:ClearAllPoints()
  if map.expanded then map:SetPoint("TOP",UIParent,"TOP",0,0)
  else map:SetPoint("CENTER",UIParent,"CENTER",BLIZZ_X,BLIZZ_Y)end
  secureDepth=secureDepth-1
 end
 function map:SynchronizeDisplayState()UpdateUIPanelPositions()end
 function map:Minimize()Blizzard(function()
  self.expanded=false;self:SetSize(702+(self.sidebar or 0),534);self:SynchronizeDisplayState();self:OnFrameSizeChanged()end)end
 function map:Maximize()Blizzard(function()
  self.expanded=true;self:SetSize(1400,999);self:SynchronizeDisplayState();self:OnFrameSizeChanged()end)end
 function map:UpdateSpacerFrameAnchoring()Blizzard(function()self:OnFrameSizeChanged()end)end
 function map:SetQuestLogPanelShown(shown)
  self.sidebar=shown and 333 or 0
  self:SetWidth(702+self.sidebar)
  UpdateUIPanelPositions()
 end
 function map:ToggleQuests(shown)
  self:SetQuestLogPanelShown(shown)
  self:UpdateSpacerFrameAnchoring();self:SynchronizeDisplayState()
 end
 function map:AdjustOverlayFrames()
  self.WorldMapTrackingPinButton:SetPoint("TOPRIGHT",self.ScrollContainer,"TOPRIGHT",0,0)
 end
 map:SetScript("OnShow",function(self)
  UpdateUIPanelPositions()
  if self:IsMaximized()then self:Maximize()else self:Minimize()end
 end)
 map.WorldMapTrackingPinButton=New(map);map.WorldMapTrackingPinButton.w=1300
 map.WorldMapTrackingPinButton.highlight=New(map.WorldMapTrackingPinButton)
 local E={modules={},db=db or{},on=true}
 function E:RegisterModule(name,m)self.modules[name]=m end
 function E:GetSetting(key)if key=="enabled"or key=="movableMap"then return self.on end;return self.db[key]end
 function E:SetSetting(key,value)self.db[key]=value end
 assert(loadfile("Modules/MovableMap.lua"))("EraUI",E)
 local M=E.modules.MovableMap;M:Initialize();map:Show();Flush()
 local drag,grips,events=nil,{},nil
 for _,f in ipairs(frames)do
  if f.scripts.OnDragStart then drag=f end
  if f.scripts.OnMouseDown then grips[f.points[1][1]]=f end
  if f.scripts.OnEvent then events=f end
 end
 return E,M,map,drag,grips,events
end
-- Screen (UIParent-unit) geometry of the map.
local function OffsetX(map)return map:GetCenter()*map:GetScale()-UIParent:GetCenter()end
local function OffsetY(map)return select(2,map:GetCenter())*map:GetScale()-select(2,UIParent:GetCenter())end
local function ScreenW(map)return map:GetWidth()*map:GetScale()end

-- Legacy width records migrate to a scale ---------------------------------------------

local E,M,map,drag,grips,events=Session({mapPosition={x=120,y=-40},mapSize={w=1000,h=400}})
near(map:GetScale(),1000/702,"legacy width becomes a scale")
equal(map:GetWidth(),702,"Blizzard keeps its own width")
equal(E.db.mapSize.version,4,"saved in the new format once")
near(OffsetX(map),120,"legacy position restored after native open")
near(OffsetY(map),-40,"legacy vertical position restored")
local pin=map.WorldMapTrackingPinButton
equal(pin:GetWidth(),32,"pin button width repaired")
equal(pin:GetHeight(),32,"pin button height repaired")
equal(pin:GetNumPoints(),1,"pin no longer spans multiple anchors")
equal(pin.highlight.points[1][2],pin,"pin highlight restricted to button")
map:AdjustOverlayFrames();equal(pin:GetNumPoints(),1,"native adjustment cannot stretch pin")
equal(map.ScrollContainer:GetWidth(),map:GetWidth()-5,"quest overlay: the map spans the whole window")

-- Resizing scales the window around the opposite top corner -----------------------------

for _,edge in ipairs({"BOTTOMRIGHT","BOTTOMLEFT","BOTTOM","LEFT","RIGHT"})do
 local oldW,oldScale=ScreenW(map),map:GetScale()
 local top=map:GetTop()*oldScale
 local fixed=edge=="LEFT"or edge=="BOTTOMLEFT"
 local x=(fixed and map:GetRight()or map:GetLeft())*oldScale
 cursorX,cursorY,down=700,700,true
 grips[edge]:Fire("OnMouseDown","LeftButton")
 cursorX=cursorX+(fixed and -60 or 60);cursorY=cursorY-60
 map:Fire("OnUpdate",.016)
 equal(ScreenW(map)>oldW,true,edge.." resizes before mouse release")
 equal(map:GetWidth(),702,edge.." Blizzard's own width untouched")
 near(map:GetTop()*map:GetScale(),top,edge.." opposite top edge fixed on screen")
 near((fixed and map:GetRight()or map:GetLeft())*map:GetScale(),x,edge.." opposite side fixed on screen")
 local w=ScreenW(map)
 grips[edge]:Fire("OnMouseUp","LeftButton");down=false;Flush()
 near(ScreenW(map),w,edge.." no release size jump")
 near(E.db.mapSize.scale,map:GetScale(),edge.." scale saved")
end
cursorX,cursorY,down=700,700,true
grips.BOTTOMRIGHT:Fire("OnMouseDown","LeftButton")
cursorX,cursorY=99999,-99999;map:Fire("OnUpdate",.016)
equal(map:GetHeight()*map:GetScale()<=UIParent:GetHeight()-16+.01,true,"never scales past the screen")
cursorX,cursorY=-99999,99999;map:Fire("OnUpdate",.016)
near(map:GetScale(),.5,"never scales below half size")
cursorX,cursorY=760,640;map:Fire("OnUpdate",.016)
grips.BOTTOMRIGHT:Fire("OnMouseUp","LeftButton");down=false;Flush()
local normalScale=map:GetScale()

-- Dragging and reopening -------------------------------------------------------------------

cursorX,cursorY,down=600,600,true;drag:Fire("OnDragStart")
cursorX,cursorY=700,650;map:Fire("OnUpdate",.016);drag:Fire("OnDragStop");down=false
local normalX,normalY=E.db.mapPosition.x,E.db.mapPosition.y
map:Hide();map:Show();Flush()
near(map:GetScale(),normalScale,"scale survives close/open")
near(OffsetX(map),normalX,"position survives close/open")

-- Blizzard's window manager is undone at once, in combat too -------------------------------

local fits=map.fits
UpdateUIPanelPositions()
near(OffsetX(map),normalX,"re-anchored map put back within the same call: no visible jump")
near(OffsetY(map),normalY,"vertical position put back too")
equal(map.fits,fits,"putting it back never refits the canvas")
combat=true
UpdateUIPanelPositions()
near(OffsetX(map),normalX,"in combat: the map stays where the player left it")
equal(#timers,0,"nothing waits for combat to end")
cursorX,cursorY,down=600,600,true;drag:Fire("OnDragStart")
cursorX=640;map:Fire("OnUpdate",.016);drag:Fire("OnDragStop");down=false
equal(E.db.mapPosition.x~=normalX,true,"the map can be dragged in combat")
combat=false
normalX=E.db.mapPosition.x

-- Quest log panel: Blizzard changes the width; scale and position stay ---------------------

for _,shown in ipairs({true,false,true,false})do
 map:ToggleQuests(shown);Flush()
 equal(map:GetWidth(),702+(shown and 333 or 0),"Blizzard sets the width for the quest panel")
 near(map:GetScale(),normalScale,"quest panel keeps the scale")
 near(OffsetX(map),normalX,"quest panel keeps the position")
 near(map.ScrollContainer:GetWidth(),map:GetWidth()-5,"quest overlay does not squeeze the map")
end

-- Maximised map: its own scale (Blizzard's size) and position -----------------------------

map:Maximize();Flush()
near(map:GetScale(),1,"maximised map starts at Blizzard's own size")
cursorX,cursorY,down=600,600,true;drag:Fire("OnDragStart")
cursorX,cursorY=550,550;map:Fire("OnUpdate",.016);drag:Fire("OnDragStop");down=false
local expandedX=E.db.mapPosition.expanded.x
near(E.db.mapPosition.x,normalX,"expanded drag does not overwrite normal position")
map:Hide();map:Show();Flush()
near(OffsetX(map),expandedX,"expanded position survives close/open")
map:Minimize();Flush()
near(OffsetX(map),normalX,"minimising returns to the normal position")
near(map:GetScale(),normalScale,"minimising returns to the normal scale")
map:Maximize();Flush()
near(OffsetX(map),expandedX,"maximising returns to its own position")

-- UI scale changes keep the physical location ---------------------------------------------

UIParent.scale=.8;events:Fire("OnEvent","UI_SCALE_CHANGED");Flush()
near(OffsetX(map),expandedX,"saved position survives a UI scale change")

-- A protected map is never moved in combat ------------------------------------------------

map:Minimize();Flush()
map.protected=true;combat=true
UpdateUIPanelPositions()
near(OffsetX(map),BLIZZ_X*map:GetScale(),"a protected map is left to Blizzard in combat")
combat=false;map.protected=false

-- New session, disabling -------------------------------------------------------------------

local data=E.db
E,M,map,drag,grips,events=Session(data)
near(OffsetX(map),normalX,"normal position survives new session")
near(map:GetScale(),normalScale,"normal scale survives new session")
local count=#frames;M:Setup();equal(#frames,count,"setup is idempotent")
E.on=false;M:Apply();UpdateUIPanelPositions();Flush()
near(map:GetScale(),1,"disabled mover returns to Blizzard's size")
near(OffsetX(map),BLIZZ_X,"disabled mover leaves Blizzard's position alone")
map:ToggleQuests(true);Flush()
near(map.ScrollContainer:GetWidth(),map:GetWidth()-338,"disabled mover restores native sidebar viewport")
E,M,map=Session()
near(map:GetScale(),1,"first use keeps Blizzard's size")
near(OffsetX(map),BLIZZ_X,"first use keeps Blizzard's position")
equal(E.db.mapSize.version,4,"first use recorded in the new format")
print("Movable map checks passed: "..checks.." assertions.")
