local _,E=...
local T={};E:RegisterModule("ClassTools",T)
E.ClassTools=T
function T.Public(v)return not (issecretvalue and issecretvalue(v))end
function T.Number(v)return T.Public(v) and type(v)=="number" end
-- Independently checked against SpellItemEnchantment, Forever 1.60.1.70009.
-- Totem coatings deliberately differ from the caster's own weapon imbues.
local coatingIDs={
 rockbiter={29,6,1,503,1663,683,1664,7568},
 flametongue={5,4,3,523,1665,1666,7567},
 frostbrand={2,12,524,1667,1668,7566},windfury={283,284,525,1669,7569},
 flametongueTotem={124,285,543,1683},windfuryTotem={1783,563,564},
 instant={323,324,325,623,624,625},deadly={7,8,626,627,2630},
 crippling={22,603},numbing={35,23,643},wound={703,704,705,706},
 poison={7254,7255,7256,7542,7651},
}
local coatingKinds={}
for kind,ids in pairs(coatingIDs)do for _,id in ipairs(ids)do coatingKinds[id]=kind end end
local poisonSpells={instant=8681,deadly=2835,crippling=3420,numbing=5763,wound=13220}
function T.WeaponCoating(slot)
 local get=GetInventoryItemID
 if not get then return nil end
 local ok,id=pcall(get,"player",slot)
 if not ok or not T.Public(id)then return nil end
 if not id then return {weapon=false}end
 local info=C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
 if not info then return nil end
 local good,_,_,_,_,_,classID=pcall(info,id)
 if not good or not T.Number(classID)then return nil end
 if classID~=2 then return {weapon=false}end
 local state={weapon=true}
 if C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo then
  local success,data=pcall(C_PaperDollInfo.GetTemporaryEnchantmentInfo,slot)
  if not success or not T.Public(data)then return nil end
  state.has=data~=nil
  if data then state.id=data.enchantID;state.ms=data.remainingTimeMs;state.charges=data.chargesRemaining end
 elseif GetWeaponEnchantInfo then
  local values={pcall(GetWeaponEnchantInfo)}
  if not values[1]then return nil end
  local offset=slot==16 and 0 or 4
  local has=values[offset+2]
  if not T.Public(has)then return nil end
  state.has=has==true
  state.ms=values[offset+3];state.charges=values[offset+4];state.id=values[offset+5]
 else return nil end
 if T.Number(state.id)then state.kind=coatingKinds[state.id]end
 return state
end
function T.CoatingIsPoison(state)
 if state.kind then return state.kind=="poison"or poisonSpells[state.kind]~=nil end
 -- An unfamiliar enchant is not proof of either poison or a missing poison.
 return nil
end
function T.CoatingName(state)
 local spell=state.kind and poisonSpells[state.kind]
 if spell then return T.Spell(spell)end
 if state.kind=="poison"then return "Poison"end
end
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
  T.Options()[key]=not v;E:SaveSettings();draw();if changed then changed()end
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
  v=math.floor(v+.5);T.Options()[key]=v;E:SaveSettings();title:SetText(label..": "..v)
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

-- Sub-category panel shown under a settings row by a class tool.
function T.BindInlinePanel(panel,anchor)
 anchor.inlinePanel=panel
 local function changed()
  local frame=E.settingsFrame
  if frame and frame.QueueSettingsLayout then frame:QueueSettingsLayout()end
 end
 panel:HookScript("OnSizeChanged",changed)
 panel:HookScript("OnShow",changed)
 panel:HookScript("OnHide",changed)
 changed()
end
function T.SubPanel(parent,anchor,width)
 local p=CreateFrame("Frame",nil,parent,"BackdropTemplate")
 p:SetSize(width or 352,40)
 p:SetPoint("TOPLEFT",anchor,"BOTTOMLEFT",0,-6)
 p:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
 p:SetBackdropColor(.026,.029,.037,.99)
 p:SetBackdropBorderColor(.19,.20,.24,1)
 p.items={}
 p.hint=T.Text(p,"",10,true)
 p.hint:SetPoint("BOTTOMLEFT",12,8);p.hint:SetWidth((width or 352)-24);p.hint:SetJustifyH("LEFT")
 T.BindInlinePanel(p,anchor)
 return p
end
function T.SubToggle(parent,label,key,default,changed,width)
 local b=CreateFrame("CheckButton",nil,parent)
 b:SetSize(width or 328,24)
 b.label=T.Text(b,label,11);b.label:SetPoint("LEFT",8,0);b.label:SetWidth((width or 328)-50);b.label:SetJustifyH("LEFT")
 b.track=CreateFrame("Frame",nil,b,"BackdropTemplate")
 b.track:SetSize(30,16);b.track:SetPoint("RIGHT",-6,0)
 b.track:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
 b.thumb=b.track:CreateTexture(nil,"ARTWORK");b.thumb:SetSize(12,12)
 local function paint()
  local v=T.Options()[key]
  if v==nil then v=default end
  local r,g,bl=T.Colour()
  b.track:SetBackdropColor(.08,.09,.11,1)
  b.track:SetBackdropBorderColor(v and r or .28,v and g or .30,v and bl or .34,1)
  if v then b.thumb:SetColorTexture(r,g,bl,1)else b.thumb:SetColorTexture(.3,.32,.36,1)end
  b.thumb:ClearAllPoints();b.thumb:SetPoint("CENTER",b.track,v and 6 or -6,0)
  b.label:SetTextColor(v and r or .7,v and g or .73,v and bl or .78)
 end
 b:SetScript("OnClick",function()
  if InCombatLockdown()then return end
  local v=T.Options()[key]
  if v==nil then v=default end
  T.Options()[key]=not v
  E:SaveSettings()
  paint()
  if changed then changed()end
 end)
 paint()
 b.draw=paint
 return b
end
function T.SubButton(parent,label,width,height,secure)
 local b=T.Button(parent,label or"",width or 328,height or 24,secure)
 b.label:ClearAllPoints();b.label:SetPoint("CENTER")
 b.label:SetFont(select(1,GameFontHighlight:GetFont()),11,"")
 return b
end
function T.SubSlider(parent,label,key,low,high,default,changed,width)
 local b=CreateFrame("Slider",nil,parent,"BackdropTemplate")
 b.layoutTop=22 -- Reserve the label above the slider, not just the track.
 b:SetSize(width or 328,12)
 T.Skin(b)
 b:SetOrientation("HORIZONTAL");b:SetMinMaxValues(low,high);b:SetValueStep(1);b:SetObeyStepOnDrag(true)
 b:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
 b:GetThumbTexture():SetSize(10,16);b:GetThumbTexture():SetVertexColor(T.Colour())
 b.label=T.Text(b,"",11);b.label:SetPoint("BOTTOMLEFT",0,8)
 b.draw=function()
  local v=tonumber(T.Options()[key])
  if v==nil then v=default end
  b.label:SetText(label..": "..v)
 end
 b:SetScript("OnValueChanged",function(_,value)
  local n=math.floor(value+.5)
  T.Options()[key]=n
  E:SaveSettings()
  b.label:SetText(label..": "..n)
  if changed then changed(n)end
 end)
 local start=tonumber(T.Options()[key])
 if start==nil then start=default end
 b:SetValue(math.max(low,math.min(high,start)))
 b.draw()
 return b
end
function T.SubLayout(p,items,step)
 local y=-8
 step=step or 26
 for _,f in ipairs(items or{})do
  if f then
   if f.draw then f.draw()end
   y=y-(f.layoutTop or 0)
   f:ClearAllPoints();f:SetPoint("TOPLEFT",12,y);f:Show()
   y=y-(f.layoutTop and(f:GetHeight()+8)or step)
  end
 end
 p:SetHeight(math.max(28,-y+24))
 return y
end
function T.SubState(p,on,offHint)
 p:SetAlpha(on and 1 or .45)
 for _,f in ipairs(p.items or{})do
  if on then if f.Enable then f:Enable()end
  else if f.Disable then f:Disable()end end
 end
 if p.hint then p.hint:SetText(on and""or(offHint or""))end
end
