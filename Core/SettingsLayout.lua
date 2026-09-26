local _,E=...

-- Expanded pages pack complete card + inline-panel blocks into measured rows.
function E:CreateSettingsViewport(frame)
 local scroll=CreateFrame("ScrollFrame",nil,frame)
 scroll:SetPoint("TOPLEFT",202,-148);scroll:SetPoint("BOTTOMRIGHT",-40,72)
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
 local range=0
 function frame:RefreshInlineActions()
  local mage=E.modules.MageSupplies
  if mage and mage.SyncButtons then mage:SyncButtons()end
 end
 function frame:SetSettingsScroll(value)
  value=math.max(0,math.min(range,value or 0))
  scroll:SetVerticalScroll(value)
  if slider:GetValue()~=value then slider:SetValue(value)end
  self:RefreshInlineActions()
 end
 slider:SetScript("OnValueChanged",function(_,value)frame:SetSettingsScroll(value)end)
 scroll:SetScript("OnMouseWheel",function(_,delta)frame:SetSettingsScroll(scroll:GetVerticalScroll()-delta*48)end)
 function frame:LayoutSettings(reset)
  if self.layoutBusy then return end
  self.layoutBusy=true
  local bottom=0
  local function Height(card)
   local inline=card.inlinePanel
   return card:GetHeight()+((inline and inline:IsShown())and(6+inline:GetHeight())or 0)
  end
  if self.settingsEntries then
   local y=0
   for i=1,#self.settingsEntries,2 do
    local height=0
    for j=i,math.min(i+1,#self.settingsEntries)do
     local card=self.settingsEntries[j]
     card:ClearAllPoints();card:SetPoint("TOPLEFT",content,"TOPLEFT",(j-i)*366,-y)
     height=math.max(height,Height(card))
    end
    bottom=y+height;y=bottom+4
   end
  else
   for _,card in pairs(self.checks)do
    if card:IsShown()then
     local _,_,_,_,y=card:GetPoint()
     bottom=math.max(bottom,-(y or 0)+Height(card))
    end
   end
  end
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
