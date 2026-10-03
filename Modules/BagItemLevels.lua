local _,E=...
local M={};E:RegisterModule("BagItemLevels",M)
-- Bag Item Levels: a big item level at the bottom right of every piece of gear
-- in your bags, in the item's quality colour, a small green up arrow at the top
-- right when it's higher than what you wear in that slot, a red down arrow when
-- it's lower, and a red icon when you can't equip it right now. Upgrade means
-- item level only. The marks sit on Blizzard's own bag buttons, which EraUI's
-- Classic bags and One bag (the game's combined bags) reuse; the bank's buttons
-- are different and not covered yet. Nothing is written on those buttons: each
-- mark is a mouse-free child frame of ours, kept in a table here, repainted by
-- a post-hook on each bag window's item update and by a few events. Every part
-- of a mark blends normally, so it fades with the interface (the AFK screen
-- hides the UI that way) and with a bag search.
-- Coming soon: while this is true Bag Item Levels never runs, whatever is
-- saved, and its /era card shows SOON. It ships for testing, off by default.
M.comingSoon=false
local ARROW="Interface\\AddOns\\EraUI\\Media\\BagArrow.tga" -- Tools/GenerateBagArrow.mjs
local FONT="Interface\\AddOns\\EraUI\\Media\\Fonts\\LilitaOne-Regular.ttf" -- bold, OFL, also a damage text font
local FALLBACK="Fonts\\FRIZQT__.TTF" -- the game's own, should Lilita One ever be refused
local OUTLINE="THICKOUTLINE"
local WHITE="Interface\\Buttons\\WHITE8X8"
-- A normal bag slot is 37 wide; the number, the arrow and the red icon's inset
-- are sized for it and scale with the slot.
local SLOT,TEXT,ARROW_SIZE,INSET=37,14,12,2
local UP,DOWN={.25,1,.3},{1,.22,.2}
local TINT={1,.12,.12} -- the item's own icon drawn again in red, the way Classic shows gear you can't use
local LIFT=.3 -- Poor grey moved this far toward white, so it still reads on dark icons
local MAX_FRAMES=13
-- Where each kind of gear is worn. Shirts, tabards, bags, quivers and ammo have no entry.
local SLOTS={INVTYPE_HEAD={1},INVTYPE_NECK={2},INVTYPE_SHOULDER={3},INVTYPE_CHEST={5},INVTYPE_ROBE={5},
 INVTYPE_WAIST={6},INVTYPE_LEGS={7},INVTYPE_FEET={8},INVTYPE_WRIST={9},INVTYPE_HAND={10},
 INVTYPE_FINGER={11,12},INVTYPE_TRINKET={13,14},INVTYPE_CLOAK={15},
 INVTYPE_RANGED={18},INVTYPE_RANGEDRIGHT={18},INVTYPE_THROWN={18},INVTYPE_RELIC={18}}
local HANDS={INVTYPE_WEAPON="one",INVTYPE_WEAPONMAINHAND="main",INVTYPE_2HWEAPON="two",
 INVTYPE_WEAPONOFFHAND="off",INVTYPE_SHIELD="off",INVTYPE_HOLDABLE="off"}
local OFF_WEAPON={INVTYPE_WEAPON=true,INVTYPE_WEAPONOFFHAND=true}
-- ITEM_LOCK_CHANGED: picking an item up greys its icon without a bag update.
local EVENTS={"PLAYER_EQUIPMENT_CHANGED","GET_ITEM_INFO_RECEIVED","PLAYER_LEVEL_UP","SKILL_LINES_CHANGED",
 "SPELLS_CHANGED","UPDATE_FACTION","PLAYER_REGEN_ENABLED","INVENTORY_SEARCH_UPDATE","ITEM_LOCK_CHANGED"}
-- Level, armour and weapon skills (plate or mail at 40) and reputation change what you can equip.
local FORGET={PLAYER_LEVEL_UP=true,SKILL_LINES_CHANGED=true,SPELLS_CHANGED=true,UPDATE_FACTION=true}
local SIDES={{"leftText","leftColor"},{"rightText","rightColor"}}
local marks=setmetatable({},{__mode="k"}) -- Blizzard bag button -> our mark
local usable={} -- item link -> can equip, until level, skills or reputation change
local hooked,events,queued,pending,waiting,durability={}

local function Public(v)return not(issecretvalue and issecretvalue(v))end
local function Clean(v)if Public(v)then return v end end
local function Active()return not M.comingSoon and E:GetSetting("enabled")and E:GetSetting("bagItemLevels")and true or false end
local function Number(fn,...)
 if type(fn)~="function"then return end
 local ok,v=pcall(fn,...)
 if ok and Public(v)and type(v)=="number"then return v end
end

local function ItemInfo(link)
 local get=C_Item and C_Item.GetItemInfo or GetItemInfo
 if type(get)~="function"then return end
 local ok,name,_,quality,level,minLevel=pcall(get,link)
 if not ok or not Public(name)or name==nil then return end
 return Clean(level),Clean(minLevel),Clean(quality)
end
local function Level(link)
 local level=Number(C_Item and C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo,link)
 if level and level>0 then return level end
 level=ItemInfo(link)
 if type(level)=="number"and level>0 then return level end
end
local function EquipLoc(link)
 local get=C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
 if type(get)~="function"then return end
 local ok,id,_,_,loc,icon=pcall(get,link)
 if ok and Public(id)and Public(loc)and type(loc)=="string"then return loc,id,Clean(icon)end
end

-- The item level worn in a slot (0 when empty) and its kind, or nil while unknown.
local function Worn(slot)
 if type(GetInventoryItemLink)~="function"then return end
 local ok,link=pcall(GetInventoryItemLink,"player",slot)
 if not ok or not Public(link)then return end
 if link==nil then return 0,""end
 local level=Level(link)
 if not level then pending=true;return end
 return level,EquipLoc(link)or""
end
local function CanDual()
 if type(CanDualWield)~="function"then return false end
 local ok,v=pcall(CanDualWield)
 return ok and Public(v)and v and true or false
end
-- What an item is weighed against: the weaker of two rings or trinkets, the
-- weaker of two dual-wielded one-hand weapons, else what's worn where it goes.
local function Reference(loc)
 local slots=SLOTS[loc]
 if slots then
  local low
  for _,slot in ipairs(slots)do
   local level=Worn(slot);if not level then return end
   low=math.min(low or level,level)
  end
  return low
 end
 local hand=HANDS[loc];if not hand then return end
 local main,mainLoc=Worn(16);local off,offLoc=Worn(17)
 if not main or not off then return end
 if hand=="off"then
  if off==0 and mainLoc=="INVTYPE_2HWEAPON"then return main end
  return off
 elseif hand=="two"then
  if main==0 then return off end
  return main
 elseif hand=="one"and mainLoc~="INVTYPE_2HWEAPON"and CanDual()and(off==0 or OFF_WEAPON[offLoc])then
  return math.min(main,off)
 end
 return main
end

local function Red(c)
 local r,g,b=c.r,c.g,c.b
 if not(Public(r)and Public(g)and Public(b))or type(r)~="number"or type(g)~="number"or type(b)~="number"then return end
 return r>.85 and g<.3 and b<.3
end
-- A broken item's red durability line doesn't stop you equipping it.
local function Durability(text)
 if not durability then
  local t=type(DURABILITY_TEMPLATE)=="string"and DURABILITY_TEMPLATE or "Durability %d / %d"
  t=t:gsub("%%%d*%$?d","\1"):gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]","%%%0"):gsub("\1","%%d+")
  durability="^"..t.."$"
 end
 return text:find(durability)~=nil
end
-- The game's own verdict, from the item's tooltip: a requirement it shows in
-- red (class, race, level, armour or weapon skill, profession, reputation).
-- nil while the tooltip isn't ready or is hidden from addons.
local function TooltipRed(bag,slot)
 local get=C_TooltipInfo and C_TooltipInfo.GetBagItem
 if type(get)~="function"then return end
 local ok,data=pcall(get,bag,slot)
 if not ok or not Public(data)or type(data)~="table"then return end
 local lines=data.lines
 if not Public(lines)or type(lines)~="table"or #lines==0 then return end
 local retrieving=RETRIEVING_ITEM_INFO or "Retrieving item information"
 local red=false
 for i=2,#lines do -- line 1 is the item's name in its quality colour
  local line=lines[i]
  if not Public(line)or type(line)~="table"then return end
  for _,side in ipairs(SIDES)do
   local text,colour=line[side[1]],line[side[2]]
   if not Public(text)or not Public(colour)then return end
   if text==retrieving then pending=true;return end
   if type(text)=="string"and text~=""and type(colour)=="table"then
    local isRed=Red(colour)
    if isRed==nil then return end
    if isRed and not Durability(text)then red=true end
   end
  end
 end
 return red
end
local function Usable(bag,slot,link,id,minLevel)
 local known=usable[link];if known~=nil then return known end
 local red=TooltipRed(bag,slot)
 local answer=red==false
 if red==nil then
  -- Tooltip not ready: fall back on the game's usable-item check.
  answer=true
  local can=C_PlayerInfo and C_PlayerInfo.CanUseItem
  if type(can)=="function"and id then
   local ok,v=pcall(can,id)
   if ok and Public(v)and v==false then answer=false end
  end
 end
 local level=Number(UnitLevel,"player")
 if type(minLevel)=="number"and level and level<minLevel then answer=false end
 if red~=nil then usable[link]=answer end
 return answer
end

local function Colour(r,g,b)
 if Public(r)and Public(g)and Public(b)and type(r)=="number"and type(g)=="number"and type(b)=="number"then return r,g,b end
end
-- The game's colour for a quality (read at paint time: the table is rebuilt
-- when the game's colour overrides change), white while unknown.
local function QualityColour(q)
 if type(q)~="number"then return 1,1,1 end
 local c=ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
 local r,g,b
 if type(c)=="table"and Public(c)then r,g,b=Colour(c.r,c.g,c.b)end
 local get=C_Item and C_Item.GetItemQualityColor
 if not r and type(get)=="function"then
  local ok,cr,cg,cb=pcall(get,q)
  if ok then r,g,b=Colour(cr,cg,cb)end
 end
 if not r then return 1,1,1 end
 if q==0 then r,g,b=r+(1-r)*LIFT,g+(1-g)*LIFT,b+(1-b)*LIFT end
 return r,g,b
end
local function Hide(button)local o=marks[button];if o then o:Hide()end end
-- The item level, bottom right of a mark, where gear never has a stack count.
-- The template is only a font to start from; Face sets the real one.
local function LevelText(o)
 local text=o:CreateFontString(nil,"OVERLAY","NumberFontNormal")
 text:SetPoint("BOTTOMRIGHT",o,"BOTTOMRIGHT",-2,1);text:SetJustifyH("RIGHT")
 text:SetShadowColor(0,0,0,1);text:SetShadowOffset(1,-1)
 o.level=text
 return text
end
-- Made once per button, on first use, and only shown or hidden after that.
local function Mark(button)
 local o=marks[button];if o then return o end
 if InCombatLockdown and InCombatLockdown()and type(button.IsProtected)=="function"and button:IsProtected()then
  waiting=true;return
 end
 o=CreateFrame("Frame",nil,button)
 o:SetAllPoints(button)
 o:EnableMouse(false)
 o:SetFrameLevel((Number(button.GetFrameLevel,button)or 0)+3)
 -- Can't equip: the item's icon drawn again in red, just inside the slot's
 -- edge so the quality border and the slot's frame stay in view.
 local icon=button.Icon or button.icon or o
 o.tint=o:CreateTexture(nil,"ARTWORK")
 o.tint:SetPoint("TOPLEFT",icon,"TOPLEFT",INSET,-INSET);o.tint:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT",-INSET,INSET)
 o.tint:SetBlendMode("BLEND")
 -- Top right, a corner the game leaves free on bag buttons: its junk coin
 -- (a merchant open, grey items) is top left and the stack count bottom right.
 o.arrow=o:CreateTexture(nil,"OVERLAY")
 o.arrow:SetPoint("TOPRIGHT",o,"TOPRIGHT",-2,-2);o.arrow:SetTexture(ARROW)
 LevelText(o)
 marks[button]=o
 return o
end
-- The slot's width, 37 unless the button says otherwise.
local function Width(button)
 local w=Number(button.GetWidth,button)
 if w and w>1 then return w end
 return SLOT
end
-- The number's font at its size: Lilita One with a thick dark outline, or the
-- game's own font should Lilita One be refused.
local function Face(o,size)
 if o.size==size then return end
 o.size=size
 local text=o.level
 local ok,done=pcall(text.SetFont,text,FONT,size,OUTLINE)
 if not ok or done==false then pcall(text.SetFont,text,FALLBACK,size,OUTLINE)end
end
-- The number's size on a slot this wide: 14 on a normal 37 slot, never below 9.
local function TextSize(w)return math.max(9,math.floor(w*TEXT/SLOT+.5))end
local function Tint(o,w,icon)
 local t=o.tint
 if icon then
  -- The icon fills the slot, so the copy's corners are cut by the same inset.
  local f=INSET/w
  t:SetTexture(icon);t:SetTexCoord(f,1-f,f,1-f);t:SetVertexColor(TINT[1],TINT[2],TINT[3],1)
 else
  t:SetTexture(WHITE);t:SetTexCoord(0,1,0,1);t:SetVertexColor(TINT[1],TINT[2],TINT[3],.5)
 end
 t:Show()
end
local function IconOf(v)v=Clean(v);if type(v)=="number"or type(v)=="string"then return v end end
-- The game's junk coin (grey items, a merchant open) would be under the red
-- icon, so while it shows the coin has the slot to itself.
local function Junk(button)
 local coin=button.JunkIcon
 if type(coin)~="table"or type(coin.IsShown)~="function"then return false end
 local ok,shown=pcall(coin.IsShown,coin)
 return ok and Public(shown)and shown==true
end
local function Where(button)
 if type(button.GetBagID)~="function"or type(button.GetID)~="function"then return end
 local bag,slot=Number(button.GetBagID,button),Number(button.GetID,button)
 if bag and slot then return bag,slot end
end
local function Paint(button)
 if not Active()then Hide(button);return end
 local bag,slot=Where(button)
 local get=C_Container and C_Container.GetContainerItemInfo
 local info
 if bag and type(get)=="function"then
  local ok,got=pcall(get,bag,slot)
  if ok and Public(got)and type(got)=="table"then info=got end
 end
 local link=info and Clean(info.hyperlink)
 local loc,id,icon
 if type(link)=="string"then loc,id,icon=EquipLoc(link)end
 if not loc or not(SLOTS[loc]or HANDS[loc])then Hide(button);return end
 local level=Level(link)
 if not level then pending=true;Hide(button);return end
 local o=Mark(button);if not o then return end
 local _,minLevel,quality=ItemInfo(link)
 local w=Width(button)
 -- The number, in the item's quality colour. Should gear ever stack, that
 -- corner is the game's count, so a stack shows no number.
 local count=Clean(info.stackCount)
 if type(count)=="number"and count>1 then
  o.level:Hide()
 else
  Face(o,TextSize(w))
  local q=Clean(info.quality)
  if type(q)~="number"then q=quality end
  if type(q)~="number"and id then q=Number(C_Item and C_Item.GetItemQualityByID,id)end
  o.level:SetText(tostring(math.floor(level+.5)))
  o.level:SetTextColor(QualityColour(q))
  o.level:Show()
 end
 local can=Usable(bag,slot,link,id,minLevel)
 -- Picked up (or held by a trade, mail or sale): the game greys the icon to
 -- show it, so the red copy stands aside until the item is put down.
 if can or Junk(button)or Clean(info.isLocked)==true then o.tint:Hide()else Tint(o,w,IconOf(info.iconFileID)or IconOf(icon))end
 local size=math.floor(w*ARROW_SIZE/SLOT+.5)
 o.arrow:SetSize(size,size)
 local worn=can and Reference(loc)
 if worn and level~=worn then
  local up=level>worn
  local c=up and UP or DOWN
  o.arrow:SetTexCoord(0,1,up and 0 or 1,up and 1 or 0) -- the art points up; flipped for down
  o.arrow:SetVertexColor(c[1],c[2],c[3])
  o.arrow:Show()
 else
  o.arrow:Hide()
 end
 -- Faded with the item while a bag search leaves it out.
 local ok,matches=false
 if type(button.GetMatchesSearch)=="function"then ok,matches=pcall(button.GetMatchesSearch,button)end
 o:SetAlpha(ok and Public(matches)and matches==false and .3 or 1)
 o:Show()
end
local function PaintFrame(frame)
 if not Active()or type(frame)~="table"or type(frame.EnumerateValidItems)~="function"then return end
 local ok,iter,state,start=pcall(frame.EnumerateValidItems,frame)
 if not ok or type(iter)~="function"then return end
 for _,button in iter,state,start do
  if type(button)=="table"then Paint(button)end
 end
end

-- Blizzard's bag windows, separate or One bag (the game's combined bags).
local function Frames()
 local list,seen={},{}
 local function Add(f)if type(f)=="table"and not seen[f]then seen[f]=true;list[#list+1]=f end end
 local container=ContainerFrameContainer
 if container and type(container.ContainerFrames)=="table"then
  for _,f in ipairs(container.ContainerFrames)do Add(f)end
 end
 for i=1,MAX_FRAMES do Add(_G["ContainerFrame"..i])end
 Add(ContainerFrameCombinedBags)
 return list
end

function M:PaintAll()
 pending,waiting=false,false
 if not Active()then
  for _,o in pairs(marks)do o:Hide()end
  return
 end
 for _,frame in ipairs(Frames())do
  if type(frame.IsShown)=="function"and frame:IsShown()then PaintFrame(frame)end
 end
end
local function Queue()
 if queued then return end
 queued=true
 C_Timer.After(0,function()queued=false;M:PaintAll()end)
end
local function OnEvent(_,event)
 if not Active()then return end
 if FORGET[event]then
  usable={};Queue()
  -- Your new level can reach the tooltips a moment after the event.
  if event=="PLAYER_LEVEL_UP"then C_Timer.After(1,function()usable={};M:PaintAll()end)end
 elseif event=="GET_ITEM_INFO_RECEIVED"then
  if pending then Queue()end
 elseif event=="PLAYER_REGEN_ENABLED"then
  if waiting then Queue()end
 else
  Queue()
 end
end
local function Setup()
 for _,frame in ipairs(Frames())do
  if not hooked[frame]and type(frame.UpdateItems)=="function"then
   hooked[frame]=true
   hooksecurefunc(frame,"UpdateItems",PaintFrame)
  end
 end
 if not events then
  events=CreateFrame("Frame")
  events:SetScript("OnEvent",OnEvent)
 end
 for _,event in ipairs(EVENTS)do events:RegisterEvent(event)end
end

function M:Refresh()
 if Active()then Setup()elseif events then events:UnregisterAllEvents()end
 usable={}
 self:PaintAll()
end
function M:Initialize()
 if Active()then self:Refresh()end
end

-- Shared with Character Item Levels, so the gear you wear shows the same
-- number the arrows here weigh your bags against, in the same look. These
-- work whether Bag Item Levels is on or off.
M.ItemLevel=Level
function M.ItemQuality(link)local _,_,quality=ItemInfo(link);return quality end
M.QualityColour=QualityColour
M.LevelText=LevelText
function M.SizeLevel(o,w)Face(o,TextSize(w))end
M.SlotWidth=Width
