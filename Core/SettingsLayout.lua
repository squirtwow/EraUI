local _,E=...

-- /era's scrolling page. The viewport is pinned by two corners (so it always
-- has a size), just right of the tab list; its content is sized when made.
-- A page is a list of items from Core/SettingsNav.lua: section headings and
-- column blocks (an option with the sub-options under it). A heading starts
-- a new line across the page; a wide block takes a line of its own; other
-- blocks go two to a line, and a line is as tall as its taller block. A
-- class option's box (row.inlinePanel) opens under its row and is measured
-- with it. Any page may scroll, with the hint under it while there's more.
local ROW_GAP,COLUMN,WIDE,WIDTH,INDENT=4,366,718,352,22
local HEADING,HEADING_GAP=18,8

function E:CreateSettingsViewport(frame)
 local scroll=CreateFrame("ScrollFrame",nil,frame)
 -- Just right of the tab list (frame.viewLeft, frame.viewTop and
 -- frame.viewBottom, set by Core/Settings.lua before this is made).
 scroll:SetPoint("TOPLEFT",frame,"TOPLEFT",frame.viewLeft or 226,frame.viewTop or -88)
 scroll:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-40,frame.viewBottom or 114)
 scroll:EnableMouseWheel(true)
 local content=CreateFrame("Frame",nil,scroll)
 content:SetSize(718,1);scroll:SetScrollChild(content)
 frame.settingsScroll,frame.settingsContent=scroll,content
 local slider=CreateFrame("Slider",nil,frame,"BackdropTemplate")
 slider:SetPoint("TOPLEFT",scroll,"TOPRIGHT",10,0);slider:SetPoint("BOTTOMLEFT",scroll,"BOTTOMRIGHT",10,0)
 slider:SetWidth(10);slider:SetOrientation("VERTICAL");slider:SetMinMaxValues(0,0);slider:SetValueStep(1)
 slider:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"});slider:SetBackdropColor(.06,.065,.075,1)
 slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
 slider:GetThumbTexture():SetSize(10,30)
 local _,class=UnitClass("player")
 local colour=RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
 slider:GetThumbTexture():SetVertexColor(colour and colour.r or .7,colour and colour.g or .7,colour and colour.b or .7)
 frame.settingsScrollbar=slider
 local hint=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
 hint:SetPoint("TOP",scroll,"BOTTOM",0,-5);hint:SetHeight(16)
 hint:SetText("Scroll down for more options");hint:SetTextColor(.9,.75,.42)
 hint:Hide();frame.settingsScrollHint=hint
 local range=0
 function frame:RefreshInlineActions()
  local mage=E.modules.MageSupplies
  if mage and mage.SyncButtons then mage:SyncButtons()end
 end
 function frame:SetSettingsScroll(value)
  value=math.max(0,math.min(range,value or 0))
  scroll:SetVerticalScroll(value)
  if slider:GetValue()~=value then slider:SetValue(value)end
  hint:SetShown(range>0 and value<range-1)
  self:RefreshInlineActions()
 end
 slider:SetScript("OnValueChanged",function(_,value)frame:SetSettingsScroll(value)end)
 scroll:SetScript("OnMouseWheel",function(_,delta)frame:SetSettingsScroll(scroll:GetVerticalScroll()-delta*48)end)
 local function RowHeight(row)
  local inline=row.inlinePanel
  return row:GetHeight()+((inline and inline:IsShown())and(6+inline:GetHeight())or 0)
 end
 -- Places one block's rows down a column from x,y; returns its height.
 local function PlaceBlock(block,x,y,width,order)
  local top=y
  for i,row in ipairs(block.rows)do
   local depth=block.depth and block.depth[row] or 0
   if i>1 then y=y+ROW_GAP end
   row:SetWidth(width-depth*INDENT)
   row:ClearAllPoints();row:SetPoint("TOPLEFT",content,"TOPLEFT",x+depth*INDENT,-y)
   y=y+RowHeight(row)
   order[#order+1]=row
  end
  return y-top
 end
 function frame:LayoutSettings(reset)
  if self.layoutBusy then return end
  self.layoutBusy=true
  local y,column,line,first,used=0,0,0,true,false
  local order={}
  local function Finish()
   if column>0 or line>0 then y=y+line+ROW_GAP;used=true end
   column,line=0,0
  end
  for _,item in ipairs(self.settingsItems or {})do
   if item.heading then
    Finish()
    if not first then y=y+HEADING_GAP end
    item.fs:ClearAllPoints();item.fs:SetPoint("TOPLEFT",content,"TOPLEFT",2,-y)
    y=y+HEADING;first=false
   elseif item.wide then
    Finish()
    line=PlaceBlock(item,0,y,WIDE,order);first=false
    Finish()
   else
    if column>=2 then Finish()end
    line=math.max(line,PlaceBlock(item,column*COLUMN,y,WIDTH,order));first=false
    column=column+1
    if column>=2 then Finish()end
   end
  end
  Finish()
  local bottom=used and y-ROW_GAP or y
  self.visibleRows=order
  local height=math.max(1,scroll:GetHeight())
  content:SetHeight(math.max(height,bottom+8))
  range=math.max(0,content:GetHeight()-height)
  slider:SetMinMaxValues(0,range);slider:SetShown(range>0)
  self:SetSettingsScroll(reset and 0 or scroll:GetVerticalScroll())
  self.layoutBusy=false
 end
 function frame:QueueSettingsLayout()
  if self.layoutQueued then return end
  self.layoutQueued=true
  C_Timer.After(0,function()self.layoutQueued=false;self:LayoutSettings()end)
 end
 scroll:SetScript("OnSizeChanged",function(_,width)
  content:SetWidth(math.max(1,width));frame:QueueSettingsLayout()
 end)
 return content
end
