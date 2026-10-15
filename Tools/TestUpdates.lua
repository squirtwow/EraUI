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
 function f:SetShown(v)self.shown=not not v end
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
  for _,name in ipairs({"SetFrameStrata","SetClampedToScreen","EnableMouse","SetMovable","RegisterForDrag","Raise",
  "StartMoving","StopMovingOrSizing","SetBackdrop",
  "SetJustifyH","EnableMouseWheel","RegisterEvent","SetColorTexture"})do f[name]=function()end end
 -- Kept, so the buttons' colours can be checked.
 function f:SetTextColor(r,g,b)self.colour={r,g,b}end
 function f:SetBackdropColor(r,g,b)self.fill={r,g,b}end
 function f:SetBackdropBorderColor(r,g,b)self.edge={r,g,b}end
 return f
end
UIParent=Frame();UIParent:SetSize(2560/.65,1440/.65)
CreateFrame=function(_,name,parent)local f=Frame(parent);if name then _G[name]=f end;return f end
GameFontHighlight={GetFont=function()return "font",12,""end}
UISpecialFrames={};UnitClass=function()return "Hunter","HUNTER"end
RAID_CLASS_COLORS={HUNTER={r=.67,g=.83,b=.45}}
local E={version="1.2.0"}
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
-- Found a bug? The Discord, beside Got it, with the question on the left.
check(w.button.points[1][1]=="BOTTOMRIGHT","Got it at the bottom right")
check(w.discord.parent==w and w.discord.points[1][1]=="RIGHT" and w.discord.points[1][2]==w.button,"Discord right beside Got it, outside the notes")
check(w.ask.text=="Found a bug or have an idea?" and w.ask:IsShown(),"asking about bugs and ideas")
-- The invite popup sits in a lower layer: What's New closes before it opens.
local invited,closedFirst=0,false
E.ShowDiscord=function()invited=invited+1;closedFirst=not w:IsShown()end
w.discord.scripts.OnClick()
check(invited==1,"the Discord button gives the invite")
check(closedFirst,"What's New closes first so the invite is not hidden behind it")
E.ShowUpdateNotes()
UIParent:SetSize(440,420);w.scripts.OnEvent(w,"DISPLAY_SIZE_CHANGED")
check(not w.ask:IsShown() and w.discord:IsShown(),"a narrow window drops the question, keeps the button")
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
check(w.title.text=="EraUI 1.2.0","current release title remains intact")
-- Show me: beside Got it while the release has new options in /era (the
-- settings walkthrough counts them, Core/SettingsTour.lua); What's New
-- closes first, then /era walks through them. None: no button, Discord
-- beside Got it again.
check(not w.showMe:IsShown() and w.discord.points[1][2]==w.button,"no settings walkthrough loaded: no Show me, Discord beside Got it")
local opened,closedBefore=0,false
E.SettingsTour={NewsCount=function()return 9 end,OpenNews=function()opened=opened+1;closedBefore=not w:IsShown()end}
w:Hide();UIParent:SetSize(2560/.65,1440/.65);E.ShowUpdateNotes()
check(w.showMe:IsShown() and w.showMe.parent==w,"Show me while the release has new options")
check(w.showMe.points[1][1]=="RIGHT" and w.showMe.points[1][2]==w.button and w.showMe.points[1][3]=="LEFT" and w.showMe.points[1][4]==-8,"right beside Got it")
check(#w.discord.points==1 and w.discord.points[1][2]==w.showMe,"Discord moves left of Show me")
check(w.ask:IsShown(),"the question still fits on a full-width window")
-- Show me stands out: its edge, fill and words in the class colour (Got
-- it's words are white); grey when the class can't be read (a secret
-- value is never used as a key) or has no colour.
local function RGB(c)return c and string.format("%.2f,%.2f,%.2f",c[1],c[2],c[3]) or "none" end
check(RGB(w.showMe.edge)=="0.67,0.83,0.45" and RGB(w.showMe.label.colour)=="0.67,0.83,0.45","Show me's edge and words in the hunter's colour")
check(RGB(w.showMe.fill)=="0.13,0.17,0.09","on a dark class-tinted fill, as Got it")
check(RGB(w.button.edge)=="0.67,0.83,0.45","Got it keeps its class edge")
local SECRET={}
issecretvalue=function(v)return v==SECRET end
setmetatable(RAID_CLASS_COLORS,{__index=function(_,k)if k==SECRET then error("a secret class used as a key")end end})
UnitClass=function()return SECRET,SECRET end
w:Hide();E.ShowUpdateNotes()
check(RGB(w.showMe.edge).." "..RGB(w.showMe.label.colour)=="0.70,0.70,0.70 0.70,0.70,0.70","a secret class: grey, never a key")
UnitClass=function()return "Paladin","PALADIN"end
w:Hide();E.ShowUpdateNotes()
check(RGB(w.showMe.label.colour)=="0.70,0.70,0.70","a class with no colour: grey")
CUSTOM_CLASS_COLORS={HUNTER={r=.1,g=.2,b=.3}}
UnitClass=function()return "Hunter","HUNTER"end
w:Hide();E.ShowUpdateNotes()
check(RGB(w.showMe.label.colour)=="0.10,0.20,0.30","a custom class colour wins")
CUSTOM_CLASS_COLORS=nil;issecretvalue=nil;setmetatable(RAID_CLASS_COLORS,nil)
w:Hide();E.ShowUpdateNotes()
UIParent:SetSize(560,420);w.scripts.OnEvent(w,"DISPLAY_SIZE_CHANGED")
check(not w.ask:IsShown() and w.showMe:IsShown() and w.discord:IsShown(),"narrower: the question goes, the buttons stay")
UIParent:SetSize(2560/.65,1440/.65);w.scripts.OnEvent(w,"DISPLAY_SIZE_CHANGED")
w.showMe.scripts.OnClick()
check(opened==1 and closedBefore,"Show me closes What's New, then opens the walkthrough")
E.SettingsTour.NewsCount=function()return 0 end
E.ShowUpdateNotes()
check(not w.showMe:IsShown() and #w.discord.points==1 and w.discord.points[1][2]==w.button,"nothing new: no Show me, Discord beside Got it")
E.SettingsTour=nil;w:Hide()
-- A version without notes of its own (a development copy runs as "dev", its
-- .toc having no number) gets the newest notes' title, never the oldest's.
E.version="dev";w:Hide();E.ShowUpdateNotes()
local newest=w.title.text:match("^EraUI (%d+)%.(%d+)%.(%d+)$")
local a,b,c=w.title.text:match("^EraUI (%d+)%.(%d+)%.(%d+)$")
check(newest~=nil and (tonumber(a)*10000+tonumber(b)*100+tonumber(c))>=10505,"a development copy titles the newest notes ("..tostring(w.title.text)..")")
local devTitle=w.title.text
E.version="99.0.0";w:Hide();E.ShowUpdateNotes()
check(w.title.text==devTitle,"so does a version newer than every note")
E.version=devTitle:match("^EraUI (.+)$");w:Hide();E.ShowUpdateNotes()
check(w.title.text==devTitle,"and that is a real release's notes")
-- Version order ("just added" counts by it) and the releases around the one
-- running.
local N=E.NewerVersion
check(N("1.7.0","1.6.0") and N("1.10.0","1.9.2") and N("2.0","1.99.99") and N("1.7.1","1.7"),"later versions are later")
check(not N("1.6.0","1.7.0") and not N("1.7.0","1.7.0") and not N("1.7","1.7.0"),"earlier or equal ones aren't")
check(not N("dev","1.0.0") and not N("1.0.0","dev") and not N("","1.0.0") and not N(nil,"1.0.0") and not N("1.7.0","0x"),"anything not a version is neither")
check(N("1.0.0","0"),"\"0\" is before every release")
E.version="1.7.0"
check(E.ReleaseVersion()=="1.7.0" and E.PreviousRelease()=="1.6.0","1.7.0: its own notes, and 1.6.0 before it")
E.version="1.8.0"
check(E.ReleaseVersion()=="1.7.0" and E.PreviousRelease()=="1.7.0","a version newer than every note: the newest notes, and they're the release before")
E.version="1.5.5"
check(E.ReleaseVersion()=="1.5.5" and E.PreviousRelease()=="1.5.4","an older release: its own, and the one under it")
E.version="dev"
check(E.ReleaseVersion()==devTitle:match("^EraUI (.+)$") and E.PreviousRelease()~="","a development copy: the newest notes, and one before")
print("Update-note scrolling checks passed: "..checks.." assertions.")
