local _,E=...
local T={};E:RegisterModule("ClassTools",T)
E.ClassTools=T
function T.Public(v)return not (issecretvalue and issecretvalue(v))end
function T.Number(v)return T.Public(v) and type(v)=="number" end
function T.Options()
 EraUIClassicCharDB=EraUIClassicCharDB or {}
 EraUIClassicCharDB.classTools=EraUIClassicCharDB.classTools or {}
 return EraUIClassicCharDB.classTools
end
function T.Colour()
 local _,class=UnitClass("player")
 local c=RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
 return c and c.r or .85,c and c.g or .7,c and c.b or .36
end
function T.Skin(f)
 f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
 f:SetBackdropColor(.045,.048,.055,.98)
 local r,g,b=T.Colour();f:SetBackdropBorderColor(r*.5,g*.5,b*.5,1)
end
function T.Text(f,text,size)
 local label=f:CreateFontString(nil,"OVERLAY","GameFontHighlight")
 label:SetFont(select(1,GameFontHighlight:GetFont()),size or 13,"")
 label:SetText(text or "");label:SetJustifyH("LEFT");label:SetShadowColor(0,0,0,1);label:SetShadowOffset(1,-1)
 return label
end
function T.Button(f,text,w,h,secure)
 local b=CreateFrame("Button",nil,f,secure and "SecureActionButtonTemplate,BackdropTemplate" or "BackdropTemplate")
 b:SetSize(w or 140,h or 28);T.Skin(b)
 b.label=T.Text(b,text);b.label:SetPoint("CENTER")
 if secure then b:RegisterForClicks("AnyUp","AnyDown") end
 return b
end
-- Shared presentation for buff, weapon, reagent and totem reminders.
-- Cosmetic state never changes a secure button's action or position.
function T.ReminderRow(parent,width,secure)
 local row
 if secure then row=T.Button(parent,"",width,54,true)
 else row=CreateFrame("Frame",nil,parent,"BackdropTemplate");row:SetSize(width,54);T.Skin(row);row.label=T.Text(row,"",12)end
 row.tint=row:CreateTexture(nil,"BACKGROUND",nil,1);row.tint:SetPoint("TOPLEFT",1,-1);row.tint:SetPoint("BOTTOMRIGHT",-1,1)
 row.edge=row:CreateTexture(nil,"ARTWORK");row.edge:SetPoint("TOPLEFT",0,-1);row.edge:SetPoint("BOTTOMLEFT",0,1);row.edge:SetWidth(3)
 row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(38,38);row.icon:SetPoint("LEFT",9,0);row.icon:SetTexCoord(.07,.93,.07,.93)
 row.label:ClearAllPoints();row.label:SetPoint("TOPLEFT",57,-9);row.label:SetWidth(width-66);row.label:SetJustifyH("LEFT")
 row.status=T.Text(row,"",11);row.status:SetPoint("BOTTOMLEFT",57,9);row.status:SetWidth(width-133)
 row.badge=T.Text(row,"",9);row.badge:SetPoint("BOTTOMRIGHT",-9,10);row.badge:SetJustifyH("RIGHT")
 if secure then
  local hover=row:CreateTexture(nil,"HIGHLIGHT");hover:SetAllPoints();hover:SetColorTexture(1,1,1,.055)
 end
 return row
end
function T.PaintReminder(row,active,badge)
 local r,g,b=.6,.65,.73
 if active==false then r,g,b=1,.63,.23 elseif active==true then r,g,b=.45,.8,.55 end
 row.edge:SetColorTexture(r,g,b,.9);row.tint:SetColorTexture(r,g,b,active==false and .09 or .035)
 row:SetBackdropBorderColor(r*.4,g*.4,b*.4,1)
 row.badge:SetText(badge or (active==nil and "CHECK" or active and "READY" or "MISSING"));row.badge:SetTextColor(r,g,b)
 row.status:SetTextColor(.8,.83,.88)
end
function T.ReminderHeader(header)
 local r,g,b=T.Colour()
 header:SetBackdropColor(r*.1,g*.1,b*.1,.98)
 header.label:SetTextColor(r,g,b)
 local line=header:CreateTexture(nil,"ARTWORK");line:SetHeight(2);line:SetPoint("BOTTOMLEFT",1,0);line:SetPoint("BOTTOMRIGHT",-1,0);line:SetColorTexture(r,g,b,.65)
end
function T.Window(name,title,w,h)
 local f=CreateFrame("Frame",name,UIParent,"BackdropTemplate")
 f:SetSize(w,h);f:SetPoint("CENTER");f:SetFrameStrata("FULLSCREEN_DIALOG");T.Skin(f)
 f:SetMovable(true);f:SetClampedToScreen(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
 f:SetScript("OnDragStart",function(self)if not InCombatLockdown() then self:StartMoving()end end)
 f:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end)
 local heading=T.Text(f,title,20);heading:SetPoint("TOPLEFT",18,-18)
 local close=T.Button(f,"X",24,24);close:SetPoint("TOPRIGHT",-10,-10)
 close:SetScript("OnClick",function()if not InCombatLockdown()then f:Hide()end end)
 -- These panels contain secure spell buttons. Their guarded close button avoids
 -- asking the ordinary Escape handler to hide a protected parent during combat.
 f:Hide();return f
end
function T.Toggle(f,label,key,y,default,changed)
 local b=T.Button(f,"",380,30);b:SetPoint("TOPLEFT",18,y)
 b.label:ClearAllPoints();b.label:SetPoint("LEFT",10,0)
 local function draw()
  local v=T.Options()[key];if v==nil then v=default end
  b.label:SetText(label..": "..(v and "On" or "Off"))
  local r,g,bl=T.Colour();b.label:SetTextColor(v and r or .65,v and g or .68,v and bl or .72)
 end
 b:SetScript("OnClick",function()
  if InCombatLockdown()then return end
  local v=T.Options()[key];if v==nil then v=default end
  T.Options()[key]=not v;draw();if changed then changed()end
 end)
 draw();return b
end
function T.Slider(f,label,key,y,low,high,default,changed)
 local title=T.Text(f,"");title:SetPoint("TOPLEFT",18,y)
 local s=CreateFrame("Slider",nil,f,"BackdropTemplate")
 s:SetPoint("TOPLEFT",18,y-24);s:SetSize(300,12);T.Skin(s)
 s:SetOrientation("HORIZONTAL");s:SetMinMaxValues(low,high);s:SetValueStep(1);s:SetObeyStepOnDrag(true)
 s:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
 local thumb=s:GetThumbTexture();thumb:SetSize(10,18);thumb:SetVertexColor(T.Colour())
 s:SetScript("OnValueChanged",function(_,v)
  v=math.floor(v+.5);T.Options()[key]=v;title:SetText(label..": "..v)
  if changed then changed(v)end
 end)
 s:SetValue(math.max(low,math.min(high,tonumber(T.Options()[key]) or default)))
 return s
end
function T.Spell(id)
 if C_Spell and C_Spell.GetSpellInfo then local s=C_Spell.GetSpellInfo(id);return s and s.name,s and s.iconID end
 if GetSpellInfo then return GetSpellInfo(id) end
end
function T.Known(id)
 local fn=IsPlayerSpell or (C_SpellBook and C_SpellBook.IsSpellKnown) or IsSpellKnown
 if fn then local ok,v=pcall(fn,id);return ok and T.Public(v) and v==true end
 return false
end
function T.Item(id)
 local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
 if fn then return fn(id) end
end
function T.Count(id)
 local fn=C_Item and C_Item.GetItemCount or GetItemCount
 local v=fn and fn(id,false,false,false)
 return T.Number(v) and v or 0
end
function T.Bags(callback)
 if not C_Container then return end
 for bag=0,(NUM_BAG_SLOTS or 4)do
  for slot=1,C_Container.GetContainerNumSlots(bag)do
   local info=C_Container.GetContainerItemInfo(bag,slot)
   if info and T.Number(info.itemID) and T.Number(info.stackCount) and T.Public(info.isLocked) and not info.isLocked then
    callback(bag,slot,info)
   end
  end
 end
end
function T:ActiveModule()
 local _,class=UnitClass("player")
 return E.modules[({HUNTER="HunterFeed",MAGE="MageSupplies",ROGUE="RoguePoisons",WARLOCK="ClassReminders",PALADIN="ClassReminders",SHAMAN="ClassReminders",PRIEST="ClassReminders",DRUID="ClassReminders",WARRIOR="ClassReminders"})[class]]
end
function T:Open()
 if InCombatLockdown()then E:Print("Open class tools after combat.");return end
 local m=self:ActiveModule()
 if m and m.Open then
  m:Open()
  -- New and previously created tool windows use the same layer above settings.
 end
end
function T:Refresh()
 local m=self:ActiveModule();if m and m.Refresh then m:Refresh()end
end
