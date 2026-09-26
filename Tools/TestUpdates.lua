-- Exercise the actual release-note layout with overflowing text, resizing and
-- dismissal. Run from the addon directory with Lua or Fengari.
local checks=0
local function check(value,label)
 checks=checks+1;assert(value,label)
end
local function Frame(parent)
 local f={parent=parent,scripts={},points={},shown=true,scroll=0}
 function f:SetSize(w,h)self.width,self.height=w,h end
 function f:SetWidth(w)self.width=w end
 function f:SetHeight(h)self.height=h end
 function f:GetWidth()return self.width end
 function f:GetHeight()
  if self.child then return self.parent:GetHeight()-162 end
  return self.height
 end
 function f:SetPoint(...)self.points[#self.points+1]={...}end
 function f:ClearAllPoints()self.points={}end
 function f:SetScript(event,fn)self.scripts[event]=fn end
 function f:Show()self.shown=true end
 function f:Hide()self.shown=false end
 function f:IsShown()return self.shown end
 function f:CreateTexture()return Frame(self)end
 function f:CreateFontString()return Frame(self)end
 function f:SetText(text)self.text=text end
 function f:SetFont(_,size)self.fontSize=size end
 function f:GetStringHeight()
  return math.max(1,math.ceil(#(self.text or "")*(self.fontSize*.55)/self.width))*self.fontSize
 end
 function f:SetScrollChild(child)self.child=child end
 function f:UpdateScrollChildRect()end
 function f:GetVerticalScrollRange()return math.max(0,self.child:GetHeight()-self:GetHeight())end
 function f:GetVerticalScroll()return self.scroll end
 function f:SetVerticalScroll(v)self.scroll=v end
 for _,name in ipairs({"SetFrameStrata","SetClampedToScreen","EnableMouse","SetMovable","RegisterForDrag",
  "StartMoving","StopMovingOrSizing","SetBackdrop","SetBackdropColor","SetBackdropBorderColor",
  "SetTextColor","SetJustifyH","EnableMouseWheel","RegisterEvent","SetColorTexture"})do f[name]=function()end end
 return f
end
UIParent=Frame();UIParent:SetSize(2560/.65,1440/.65)
CreateFrame=function(_,name,parent)local f=Frame(parent);if name then _G[name]=f end;return f end
GameFontHighlight={GetFont=function()return "font",12,""end}
UISpecialFrames={};UnitClass=function()return "Hunter","HUNTER"end
RAID_CLASS_COLORS={HUNTER={r=.67,g=.83,b=.45}}
local E={version="1.0.4"}
assert(loadfile("Core/Updates.lua"))("EraUI",E)
E.ShowUpdateNotes()
local w=EraUIUpdates;local s=w.scroll
check(w:GetHeight()<=640,"long history has a bounded height")
check(s:GetVerticalScrollRange()>0,"long history overflows inside the scroll area")
check(w.title.parent==w and w.button.parent==w,"title and dismissal stay outside scrolling content")
check(w.blocks[1].header.parent==w.content,"section headers scroll with notes")
check(w.blocks[1].lines[1].parent==w.content,"bullet text belongs to the scrolling child")
check(#w.blocks>3,"previous releases remain available")
check(UISpecialFrames[1]=="EraUIUpdates","Escape dismissal remains registered")
s.scripts.OnMouseWheel(s,-1)
check(s:GetVerticalScroll()==40,"mouse wheel moves down")
s.scripts.OnMouseWheel(s,-100000)
check(s:GetVerticalScroll()==s:GetVerticalScrollRange(),"wheel reaches final notes without overshooting")
s.scripts.OnMouseWheel(s,100000)
check(s:GetVerticalScroll()==0,"wheel clamps to the first note")
local originalContentHeight=w.content:GetHeight()
UIParent:SetSize(440,420);w.scripts.OnEvent(w,"DISPLAY_SIZE_CHANGED")
check(w:GetWidth()==400 and w:GetHeight()==380,"small screen keeps margins on both axes")
check(w.content:GetHeight()>originalContentHeight,"narrow screen reflows wrapped notes")
for _,block in ipairs(w.blocks)do
 local previous=block.header
 for _,line in ipairs(block.lines)do
  local py=-previous.points[1][3];local y=-line.points[1][3]
  check(y>=py+previous:GetStringHeight(),"wrapped bullets do not overlap")
  previous=line
 end
end
check(s:GetHeight()>0,"small screen retains a usable viewport")
UIParent:SetSize(1024,600);w.scripts.OnEvent(w,"UI_SCALE_CHANGED")
check(w:GetHeight()==560,"UI scale change recalculates screen-height bound")
s.scripts.OnMouseWheel(s,-10)
w.button.scripts.OnClick()
check(not w:IsShown(),"Got it dismisses the window")
E.ShowUpdateNotes()
check(w:IsShown() and s:GetVerticalScroll()==0,"reopening starts at the current release")
check(w.title.text=="EraUI 1.0.4","current release title remains intact")
print("Update-note scrolling checks passed: "..checks.." assertions.")
