local _,E=...
-- POISON!, the rogue's class reminder: which hand needs a poison, which
-- poison a click puts on, and that click. Poisons, ranks and levels come from
-- Forever's own item data (Modules/PoisonData.lua), so a rank Forever adds or
-- moves is followed. A click is the game's own item use through one secure
-- button (type "item", then "target-slot" 16 or 17 picks the weapon), whose
-- attributes change only out of combat; a fight takes the click away at once.
local T=E.ClassTools
local P={}
E.ReminderPoisons=P

local HANDS={"main","off"}
local SLOTS={main=16,off=17}
local LABELS={main="Main hand",off="Off hand"}
-- Under a minute or 10 charges left counts as about to run out. Zero charges
-- is also how uncharged enchants are reported, so it never counts.
local LOW_SECONDS,LOW_CHARGES=60,10
-- Poisons, the skill: Classic's spell and Forever's own copy of it.
local SKILL={2842,1298494}
-- The order the /era buttons go through; a family Forever adds comes last.
local ORDER={"instant","deadly","crippling","numbing","wound"}
-- Each hand's default: the first of these your level allows. Before any of
-- them, the one your level allows first, so the button already shows the
-- poison you'll get.
local DEFAULTS={main={"instant"},off={"deadly","instant"}}
local NOTE="|cffffb35c"

local families
local function Families()
 if families then return families end
 local data=E.PoisonData and E.PoisonData.families or{}
 local list,seen={},{}
 for _,key in ipairs(ORDER)do
  for _,f in ipairs(data)do if f.key==key and not seen[f]then list[#list+1]=f;seen[f]=true end end
 end
 for _,f in ipairs(data)do if not seen[f]then list[#list+1]=f;seen[f]=true end end
 families=list
 return list
end
P.Families=Families
local function Level()
 local level=UnitLevel("player")
 if T.Number(level)then return level end
end
local function First(f)return f and f.ranks and f.ranks[1]end
local function CanUse(f,level)
 local first=First(f)
 return level~=nil and first~=nil and first.level<=level
end
-- The first level any poison can be used at (20 in Forever 1.60.1.70170).
function P.MinLevel()
 local low
 for _,f in ipairs(Families())do
  local first=First(f)
  if first and(not low or first.level<low)then low=first.level end
 end
 return low
end
-- A family's name in the game's language (its rank 1 recipe), else English.
function P.Name(f)
 local first=First(f)
 local name=first and first.recipe and T.Spell(first.recipe)
 if T.Public(name)and type(name)=="string"and name~=""then return name end
 return f and f.name or"?"
end
local function Find(key)
 for _,f in ipairs(Families())do if f.key==key then return f end end
end
function P.Default(hand,level)
 level=level or Level()
 local fallback
 for _,key in ipairs(DEFAULTS[hand]or DEFAULTS.main)do
  local f=Find(key)
  if f then
   if CanUse(f,level)then return f end
   if not fallback or First(f).level<First(fallback).level then fallback=f end
  end
 end
 return fallback
end
-- Each rogue's own picks (one at 60 and one at 25 want different poisons),
-- in its class tools settings, which the settings backup keeps per character.
-- Saved by the family's rank 1 item.
local function ChoiceKey(hand)return hand=="off"and "poisonPickOff"or "poisonPickMain"end
P.ChoiceKey=ChoiceKey
-- The poison a hand's clicks use: the one picked in /era while your level
-- allows it, otherwise that hand's default.
function P.Choice(hand)
 local level=Level()
 local id=tonumber(T.Options()[ChoiceKey(hand)])
 if id then
  for _,f in ipairs(Families())do
   local first=First(f)
   if first and first.item==id and CanUse(f,level)then return f end
  end
 end
 return P.Default(hand,level)
end
-- Only poisons your level allows are offered.
function P.ChoiceList()
 local list,level={},Level()
 for _,f in ipairs(Families())do if CanUse(f,level)then list[#list+1]=f end end
 return list
end
function P.Cycle(hand)
 local list=P.ChoiceList()
 if #list==0 then return end
 local current,index=P.Choice(hand),0
 for i,f in ipairs(list)do if f==current then index=i end end
 local f=list[index%#list+1]
 T.Options()[ChoiceKey(hand)]=First(f).item
 if E.SaveSettings then E:SaveSettings()end
end
-- The highest rank of a family in your bags that your level allows, or nil
-- and why: "none" in your bags, or only ranks above your level ("level").
function P.Best(f)
 if not f then return nil,"none"end
 local level,carried=Level(),false
 for i=#f.ranks,1,-1 do
  local rank=f.ranks[i]
  if T.Count(rank.item)>0 then
   if level and rank.level<=level then return rank end
   carried=true
  end
 end
 return nil,carried and "level"or "none"
end
-- Only once you can use poisons: from the first level one can be used, with
-- Poisons learned or a poison your level allows in your bags.
function P.Usable()
 local level,low=Level(),P.MinLevel()
 if not level or not low or level<low then return false end
 for _,id in ipairs(SKILL)do if T.Known(id)then return true end end
 for _,f in ipairs(Families())do if P.Best(f)then return true end end
 return false
end
-- One hand: nil when the game won't say, "none" without a weapon there
-- (shields and empty hands need no poison), "ok", or what it needs.
function P.Hand(hand)
 local state=T.WeaponCoating(SLOTS[hand])
 if not state then return nil end
 if not state.weapon then return "none"end
 if not state.has then return "need","no poison"end
 local poison=T.CoatingIsPoison(state)
 if poison==nil then return nil end
 if not poison then return "need","another coating"end
 if T.Number(state.ms)and state.ms>0 and state.ms<=LOW_SECONDS*1000 then
  local s=math.ceil(state.ms/1000)
  return "need",string.format("%d:%02d left",math.floor(s/60),s%60)
 end
 if T.Number(state.charges)and state.charges>0 and state.charges<=LOW_CHARGES then
  return "need",state.charges..(state.charges==1 and " charge left"or " charges left")
 end
 return "ok"
end
-- Whether POISON! shows, what it says under it, and which hands need one.
-- A hand without a weapon is never mentioned. clicks: a click can put a
-- poison on (Clickable reminders and Click to apply poisons). Then a hand
-- that needs one and has none of its pick to use says so. Otherwise the
-- picks don't matter: it only says so when no poison at all can be used.
function P.State(clicks)
 local need,phrase,unknown,fine=nil,{},false,false
 for _,hand in ipairs(HANDS)do
  local status,text=P.Hand(hand)
  if status==nil then unknown=true
  elseif status=="need"then need=need or{};need[hand]=true;phrase[hand]=text
  elseif status=="ok"then fine=true end
 end
 P.need=need
 if not need then
  if unknown then return nil,"Poison check unavailable"end
  return false,fine and "Poison applied"or "No weapon equipped"
 end
 local lines={}
 if need.main and need.off and phrase.main==phrase.off then
  lines[1]="Main and off hand: "..phrase.main
 else
  for _,hand in ipairs(HANDS)do if need[hand]then lines[#lines+1]=LABELS[hand]..": "..phrase[hand]end end
 end
 if clicks then
  local said={}
  for _,hand in ipairs(HANDS)do
   local f=need[hand]and P.Choice(hand)
   if f and not said[f]then
    said[f]=true
    local rank,why=P.Best(f)
    if not rank then
     lines[#lines+1]=NOTE..(why=="level"and("Your "..P.Name(f).." needs a higher level")or("No "..P.Name(f).." in your bags")).."|r"
    end
   end
  end
 else
  local why="none"
  for _,f in ipairs(Families())do
   local rank,reason=P.Best(f)
   if rank then why=nil;break end
   if reason=="level"then why="level"end
  end
  if why then lines[#lines+1]=NOTE..(why=="level"and "Your poisons need a higher level"or "No poison in your bags").."|r"end
 end
 return true,table.concat(lines,"\n"),need
end
local function ItemIcon(id)
 local info=C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
 if not info then return nil end
 local ok,_,_,_,_,icon=pcall(info,id)
 if ok and T.Public(icon)and(type(icon)=="number"or type(icon)=="string")then return icon end
end
local function ItemName(rank,f)
 local fn=C_Item and C_Item.GetItemNameByID
 local ok,name
 if fn then ok,name=pcall(fn,rank.item)end
 if not(ok and T.Public(name)and type(name)=="string"and name~="")then
  ok,name=pcall(T.Item,rank.item)
 end
 if ok and T.Public(name)and type(name)=="string"and name~=""then return name end
 return P.Name(f)
end
-- The icon of the poison a click would put on (the main hand's first).
function P.Icon()
 for _,hand in ipairs(HANDS)do
  if not P.need or P.need[hand]then
   local rank=P.Best(P.Choice(hand))
   local icon=rank and ItemIcon(rank.item)
   if icon then return icon end
  end
 end
end

-- The click: one secure button over POISON!'s icon, parented and anchored
-- to UIParent only, so the alert rows never turn protected.
local button
local ATTRIBUTES={"type1","item1","target-slot1","type2","item2","target-slot2"}
function P.Disarm()
 if not button or InCombatLockdown()then return end
 for _,key in ipairs(ATTRIBUTES)do button:SetAttribute(key,nil)end
 button:Hide()
 button.row,button.tip=nil,nil
end
local function Build()
 button=CreateFrame("Button",nil,UIParent,"SecureActionButtonTemplate,SecureHandlerStateTemplate")
 button:Hide();button:SetFrameStrata("HIGH")
 button:RegisterForClicks("LeftButtonUp","LeftButtonDown","RightButtonUp","RightButtonDown")
 -- The game's own code takes the click away the moment a fight starts. Its
 -- state driver hands the state on as a number (1), not the text "1".
 button:SetAttribute("_onstate-combat",[[
  if newstate == 1 or newstate == "1" then
   self:SetAttribute("type1", nil)
   self:SetAttribute("type2", nil)
   self:Hide()
  end
 ]])
 RegisterStateDriver(button,"combat","[combat] 1; 0")
 local glow=button:CreateTexture(nil,"HIGHLIGHT")
 glow:SetAllPoints();glow:SetColorTexture(1,1,1,.12)
 button:SetScript("OnEnter",function(self)
  if not self.tip or not GameTooltip then return end
  GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
  GameTooltip:SetText("POISON!",.52,1,.4)
  for _,line in ipairs(self.tip)do GameTooltip:AddLine(line,1,1,1,true)end
  GameTooltip:Show()
 end)
 button:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide()end end)
end
-- Out of combat only. on: clicks are wanted for this row. need: the hands
-- that need a poison (P.State). Each such hand with a poison to use gets its
-- click: left for the main hand, right for the off hand. With none, the
-- button is put away.
function P.Sync(row,on,need)
 if InCombatLockdown()then return end
 local picks={}
 if on and need then
  for _,hand in ipairs(HANDS)do
   if need[hand]then
    local f=P.Choice(hand)
    local rank=P.Best(f)
    if rank then picks[hand]={rank=rank,family=f}end
   end
  end
 end
 if not(picks.main or picks.off)then P.Disarm();return end
 local icon=row.iconFrame
 local x,y=icon:GetCenter()
 if not T.Number(x)or not T.Number(y)then P.Disarm();return end
 if not button then Build()end
 local ratio=icon:GetEffectiveScale()/UIParent:GetEffectiveScale()
 button:SetSize(icon:GetWidth()*ratio,icon:GetHeight()*ratio)
 button:ClearAllPoints();button:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x*ratio,y*ratio)
 button:SetFrameLevel(icon:GetFrameLevel()+5)
 local tip={}
 for i,hand in ipairs(HANDS)do
  local pick=picks[hand]
  button:SetAttribute("type"..i,pick and "item"or nil)
  button:SetAttribute("item"..i,pick and("item:"..pick.rank.item)or nil)
  button:SetAttribute("target-slot"..i,pick and SLOTS[hand]or nil)
  if pick then
   tip[#tip+1]=(i==1 and "Left-click: "or "Right-click: ")..ItemName(pick.rank,pick.family).." on your "..string.lower(LABELS[hand])
  end
 end
 button.row,button.tip=row,tip
 button:Show()
 return tip
end
-- When the button was over this row, put it away (the row hid or moved on).
function P.DisarmRow(row)
 if button and button.row==row then P.Disarm()end
end

-- /era help.
function P.ClickHelp()
 return "With Clickable reminders on, a left-click on POISON!'s icon puts your main hand's poison on your main hand, and a right-click puts your off hand's poison on your off hand. "
  .."It uses the game's own item use, outside combat only, with the highest rank you carry that your level allows. "
  .."Pick each hand's poison with the buttons below. Needs testing."
end
function P.ChoiceHelp(hand)
 local low=P.MinLevel()
 return "Picks the poison a "..(hand=="off"and "right-click"or "left-click").." on POISON! puts on your "..string.lower(LABELS[hand])
  ..": the highest rank you carry that your level allows. Only poisons your level allows are offered"..(low and(", from level "..low)or"")
  ..". With none in your bags, POISON! says so. Each rogue keeps its own picks."
end
function P.DefaultText(hand)
 local wanted,fallback=DEFAULTS[hand]or DEFAULTS.main,nil
 local first=Find(wanted[1])
 if #wanted>1 then fallback=Find(wanted[#wanted])end
 if not first then return "Default: none"end
 local level=First(first).level
 if fallback and fallback~=first then
  return "Default: "..P.Name(first)..", or "..P.Name(fallback).." before level "..level.."."
 end
 return "Default: "..P.Name(first).."."
end
function P.Label(hand)
 local f=P.Choice(hand)
 return LABELS[hand]..": "..(f and P.Name(f)or "None").."  >"
end

-- Once, after every saved copy has loaded (Core/Integration.lua). The old
-- Poison Reminders panel's users keep poison alerts: Class Reminders & Buffs
-- and POISON! go on, and the old switch is spent. Class Reminders & Buffs is
-- one switch for the whole account, so when it was off, every other class
-- still shows nothing: its alerts that are on by default go off (each can be
-- switched on again under Advanced). The two old alerts become one, off only
-- if both were. A spot the main-hand alert was dragged to is kept.
-- mirror: the skinning layer's copy, cleared of the old keys too.
local OLD={"reminder_ROGUE_poisonMain","reminder_ROGUE_poisonOff","reminderPX_ROGUE_poisonMain","reminderPY_ROGUE_poisonMain",
 "reminderPX_ROGUE_poisonOff","reminderPY_ROGUE_poisonOff"}
function P.Migrate(db,mirror)
 if type(db)~="table"then return false end
 local changed=false
 if db.poisonReminders==true then
  if db.classReminders~=true then
   for class,defs in pairs(E.ReminderSpells or{})do
    if class~="ROGUE"then
     for _,def in ipairs(defs)do
      local key="reminder_"..class.."_"..def.key
      if not def.off and db[key]==nil then db[key]=false end
     end
    end
   end
  end
  db.classReminders=true;db.reminder_ROGUE_poison=true;db.poisonReminders=false;changed=true
  if type(mirror)=="table"then mirror.eraui_poisonReminders=false;mirror.eraui_classReminders=true end
 end
 local main,off=db.reminder_ROGUE_poisonMain,db.reminder_ROGUE_poisonOff
 if db.reminder_ROGUE_poison==nil and main==false and off~=true then db.reminder_ROGUE_poison=false;changed=true end
 local x,y=db.reminderPX_ROGUE_poisonMain,db.reminderPY_ROGUE_poisonMain
 if db.reminderPX_ROGUE_poison==nil and type(x)=="number"and type(y)=="number"then
  db.reminderPX_ROGUE_poison,db.reminderPY_ROGUE_poison=x,y;changed=true
 end
 for _,key in ipairs(OLD)do
  if db[key]~=nil then db[key]=nil;changed=true end
  if type(mirror)=="table"then mirror["eraui_"..key]=nil end
 end
 return changed
end
