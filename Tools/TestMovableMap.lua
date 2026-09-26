-- Geometry/lifecycle simulations for the actual movable map module. The canvas
-- rejects addon writes: only the native frame-size callback may fit its view.
local checks=0
local function equal(got,want,label)
 checks=checks+1;assert(got==want,label..": expected "..tostring(want)..", got "..tostring(got))
end
local function near(got,want,label)equal(math.abs(got-want)<.001,true,label)end
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
local function Guard()assert(not combat,"combat layout mutation")end
function methods:SetSize(w,h)Guard();local changed=w~=self.w or h~=self.h;self.w,self.h=w,h;if changed then self:Fire("OnSizeChanged",w,h)end end
function methods:SetHeight(h)self:SetSize(self.w,h)end
function methods:GetWidth()return self.w end
function methods:GetHeight()return self.h end
function methods:GetEffectiveScale()return self.scale*(self.parent and self.parent:GetEffectiveScale()or 1)end
function methods:ClearAllPoints()Guard();self.points={}end
function methods:SetPoint(...)
 Guard();local args={...}
 for i,p in ipairs(self.points)do if p[1]==args[1]then self.points[i]=args;return end end
 self.points[#self.points+1]=args
end
function methods:GetFrameLevel()return self.level or 1 end
function methods:SetFrameLevel(n)self.level=n end
function methods:GetFrameStrata()return self.strata or "MEDIUM"end
function methods:SetFrameStrata(s)self.strata=s end
function methods:SetAllPoints(f)self.points={{"ALL",f}}end
function methods:GetNumPoints()return #self.points end
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
 elseif anchor=="TOPRIGHT"then cx=cx-self.w/2;cy=cy-self.h/2 end
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
hooksecurefunc=function(t,key,callback)
 if type(t)=="string"then callback=key;key=t;t=_G end
 local old=t[key];t[key]=function(...)local result={old(...)};callback(...);return table.unpack(result)end
end
local function Flush()
 for _=1,12 do if #timers==0 then return end;local pending=timers;timers={};for _,fn in ipairs(pending)do fn()end end
 error("restore loop")
end
local function Session(db)
 frames,timers,combat,cursorX,cursorY,down={},{},false,500,500,true
 C_Timer={After=function(delay,fn)equal(delay,0,"no delayed refit timers");timers[#timers+1]=fn end}
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
 local canvas={GetWidth=function()return 1002 end,GetHeight=function()return 668 end,
  SetSize=function()error("addon changed native canvas dimensions")end,
  ClearAllPoints=function()error("addon changed native canvas anchors")end}
 function map:GetCanvas()return canvas end
 function map:IsMaximized()return self.expanded==true end
 function map:OnFrameSizeChanged()
  self.nativeFits=(self.nativeFits or 0)+1
  self.fittedW,self.fittedH=scroll:GetWidth(),scroll:GetHeight()
 end
 UpdateUIPanelPositions=function()
  map:ClearAllPoints();map:SetPoint("CENTER",UIParent,"CENTER",-200,50)
 end
 function map:SynchronizeDisplayState()UpdateUIPanelPositions()end
 function map:Minimize()self.expanded=false;self:SetSize(702,534);self:SynchronizeDisplayState()end
 function map:Maximize()self.expanded=true;self:SetSize(1400,999);self:SynchronizeDisplayState()end
 function map:UpdateSpacerFrameAnchoring()self:OnFrameSizeChanged()end
 function map:SetQuestLogPanelShown(shown)
  self.sidebar=shown and 333 or 0
  self:SetSize(702+self.sidebar,self.h)
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
local E,M,map,drag,grips,events=Session({mapPosition={x=120,y=-40},mapSize={w=1000,h=400}})
near(map:GetWidth(),1000,"legacy width kept")
near(map:GetHeight(),(1000-5)/1.5+69,"legacy distorted height corrected with chrome accounted for")
near(map:GetCenter()-UIParent:GetCenter(),120,"legacy position restored after native open")
local pin=map.WorldMapTrackingPinButton
equal(pin:GetWidth(),32,"pin button width repaired")
equal(pin:GetHeight(),32,"pin button height repaired")
equal(pin:GetNumPoints(),1,"pin no longer spans multiple anchors")
equal(pin.highlight.points[1][2],pin,"pin highlight restricted to button")
map:AdjustOverlayFrames();equal(pin:GetNumPoints(),1,"native adjustment cannot stretch pin")

for _,edge in ipairs({"BOTTOMRIGHT","BOTTOMLEFT","BOTTOM","LEFT","RIGHT"})do
 local oldW=map:GetWidth();local top=map:GetTop()
 local fixed=edge=="LEFT"or edge=="BOTTOMLEFT";local x=fixed and map:GetRight()or map:GetLeft()
 cursorX,cursorY,down=700,700,true
 grips[edge]:Fire("OnMouseDown","LeftButton")
 cursorX=cursorX+(fixed and -60 or 60);cursorY=cursorY-60
 map:Fire("OnUpdate",.016)
 equal(map:GetWidth()>oldW,true,edge.." resizes before mouse release")
 near((map:GetWidth()-5)/(map:GetHeight()-69),1.5,edge.." canvas proportions preserved")
 near(map.fittedW,map:GetWidth()-5,edge.." native artwork follows border immediately")
 near(map:GetTop(),top,edge.." opposite vertical anchor fixed")
 near(fixed and map:GetRight()or map:GetLeft(),x,edge.." opposite horizontal anchor fixed")
 local w,h=map:GetWidth(),map:GetHeight()
 grips[edge]:Fire("OnMouseUp","LeftButton");down=false;Flush()
 near(map:GetWidth(),w,edge.." no release width jump")
 near(map:GetHeight(),h,edge.." no release height jump")
end
local normalW=map:GetWidth()
cursorX,cursorY,down=600,600,true;drag:Fire("OnDragStart")
cursorX,cursorY=700,650;map:Fire("OnUpdate",.016);drag:Fire("OnDragStop");down=false
local normalX,normalY=E.db.mapPosition.x,E.db.mapPosition.y
map:Hide();map:Show();Flush()
near(map:GetWidth(),normalW,"normal size survives close/open")
near(map:GetCenter()-UIParent:GetCenter(),normalX,"normal position survives close/open")
local fits=map.nativeFits
UpdateUIPanelPositions();Flush()
equal(map.nativeFits,fits,"position-only restore does not reset map zoom")
local normalH=map:GetHeight()
for _,shown in ipairs({true,false,true,false})do
 map:ToggleQuests(shown);Flush()
 near(map:GetWidth(),normalW,"sidebar toggle preserves outer width")
 near(map:GetHeight(),normalH,"sidebar toggle preserves outer height")
 near(map.ScrollContainer:GetWidth(),normalW-5,"quest overlay does not squeeze artwork viewport")
 near(map.ScrollContainer:GetWidth()/map.ScrollContainer:GetHeight(),1.5,"quest overlay leaves no letterbox bands")
 near(map:GetCenter()-UIParent:GetCenter(),normalX,"sidebar toggle preserves horizontal position")
 near(select(2,map:GetCenter())-select(2,UIParent:GetCenter()),normalY,"sidebar toggle preserves vertical position")
end
map:ToggleQuests(true);Flush();map:Hide();map:Show();Flush()
near(map:GetWidth(),normalW,"reopening with quests visible keeps width")
near(map:GetHeight(),normalH,"reopening with quests visible keeps height")
cursorX,cursorY,down=700,700,true
grips.BOTTOMRIGHT:Fire("OnMouseDown","LeftButton");map:Fire("OnUpdate",.016)
near(map:GetWidth(),normalW,"grabbing resize with quests visible has no width jump")
near(map:GetHeight(),normalH,"grabbing resize with quests visible has no height jump")
grips.BOTTOMRIGHT:Fire("OnMouseUp","LeftButton");down=false
map:ToggleQuests(false);Flush()

map:Maximize();Flush()
cursorX,cursorY,down=600,600,true;drag:Fire("OnDragStart")
cursorX,cursorY=550,550;map:Fire("OnUpdate",.016);drag:Fire("OnDragStop");down=false
local expandedX=E.db.mapPosition.expanded.x
near(E.db.mapPosition.x,normalX,"expanded drag does not overwrite normal position")
map:Hide();map:Show();Flush()
near(map:GetCenter()-UIParent:GetCenter(),expandedX,"expanded position survives close/open")
map:Minimize();Flush()
near(map:GetCenter()-UIParent:GetCenter(),normalX,"restore returns to normal position")
near(map:GetWidth(),normalW,"restore returns to normal size")
map:Maximize();Flush()
near(map:GetCenter()-UIParent:GetCenter(),expandedX,"expand returns to its own saved position")

map.scale=1.25;events:Fire("OnEvent","UI_SCALE_CHANGED");Flush()
near(map:GetCenter()*1.25-UIParent:GetCenter(),expandedX,"saved position survives differing map and UI scales")
cursorX,cursorY,down=600,600,true;drag:Fire("OnDragStart")
cursorX=650;map:Fire("OnUpdate",.016);drag:Fire("OnDragStop");down=false
local scaledX=E.db.mapPosition.expanded.x
map:Hide();map:Show();Flush()
near(map:GetCenter()*1.25-UIParent:GetCenter(),scaledX,"scaled drag saves physical location")

cursorX,cursorY,down=600,600,true;grips.BOTTOMRIGHT:Fire("OnMouseDown","LeftButton")
cursorX,cursorY=800,450;map:Fire("OnUpdate",.016)
local beforeCombatW=map:GetWidth()
combat=true;events:Fire("OnEvent","PLAYER_REGEN_DISABLED")
cursorX=1000;map:Fire("OnUpdate",.016);grips.BOTTOMRIGHT:Fire("OnMouseUp","LeftButton");Flush()
near(map:GetWidth(),beforeCombatW,"combat cancels active resizing without protected edits")
combat=false;events:Fire("OnEvent","PLAYER_REGEN_ENABLED");Flush()
near(map:GetWidth(),beforeCombatW,"combat exit preserves last applied size")

local data=E.db
local finalExpandedX=data.mapPosition.expanded.x
E,M,map,drag,grips,events=Session(data)
near(map:GetCenter()-UIParent:GetCenter(),normalX,"normal position survives new session")
map:Maximize();Flush();near(map:GetCenter()-UIParent:GetCenter(),finalExpandedX,"expanded position survives new session")
local count=#frames;M:Setup();equal(#frames,count,"setup is idempotent")
E.on=false;M:Apply();map:Minimize();Flush()
near(map:GetWidth(),702,"disabled mover leaves native size alone")
near(map:GetCenter()-UIParent:GetCenter(),-200,"disabled mover leaves native position alone")
map:ToggleQuests(true);Flush()
near(map.ScrollContainer:GetWidth(),map:GetWidth()-338,"disabled mover restores native sidebar viewport")
E,M,map=Session()
local initialW,initialH=map:GetWidth(),map:GetHeight()
map:ToggleQuests(true);Flush();map:ToggleQuests(false);Flush()
near(map:GetWidth(),initialW,"sidebar keeps first-use width before any manual resize")
near(map:GetHeight(),initialH,"sidebar keeps first-use height before any manual resize")
E,M,map=Session({mapSize={w=1300,h=1000,version=2},mapPosition={x=0,y=0,version=2}})
near(map:GetHeight(),(1300-5)/1.5+69,"previous squeezed layout migrates to full-art proportions")
equal(E.db.mapSize.version,3,"corrected layout saved once")
print("Movable map checks passed: "..checks.." assertions.")
