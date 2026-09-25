local _,E=...
local T=E.ClassTools
local M={};E:RegisterModule("MageSupplies",M)
-- Spell, output item, minimum consumer level. The client confirms learned ranks
-- and supplies current item level requirements and stack sizes when cached.
local ranks={
 food={{587,5349,1},{597,1113,5},{990,1114,15},{6129,1487,25},{10144,8075,35},{10145,8076,45},{28612,22895,55}},
 water={{5504,5350,1},{5505,2288,5},{5506,2136,15},{6127,3772,25},{10138,8077,35},{10139,8078,45},{10140,8079,55}},
}
local window,heading
local buttons={}
local session=0
local function ValidLevel(unit)
 local player=UnitIsPlayer(unit);if not T.Public(player) or not player then return end
 local level=UnitLevel(unit);if T.Number(level) and level>0 then return level end
end
function M:Suggestion(kind,level)
 if not level then return end
 local chosen
 for _,entry in ipairs(ranks[kind])do
  local required=select(5,T.Item(entry[2]));if not T.Number(required)then required=entry[3]end
  if required<=level and T.Known(entry[1])then chosen=entry end
 end
 return chosen
end
local function SetConjure(b,kind,entry)
 b:SetAttribute("type","spell");b:SetAttribute("spell",entry and entry[1]or nil)
 b.label:SetText(entry and ("Conjure "..kind.." · rank "..(function()for i,v in ipairs(ranks[kind])do if v==entry then return i end end end)()) or ("No learned "..kind.." for this level"))
 b:SetAlpha(entry and 1 or .45)
end
function M:Refresh()
 if not window or InCombatLockdown()then return end
 local level=ValidLevel("target")
 local active=E:GetSetting("enabled") and E:GetSetting("mageSupplies")
 heading:SetText(not active and "Enable Conjuring Suggestions in Mage settings." or level and ("Target level "..level.." · highest suitable learned ranks") or "Target a player to see suitable food and water.")
 for kind,b in pairs(buttons)do SetConjure(b,kind,active and self:Suggestion(kind,level))end
end
function M:Open()
 if not window then
  window=T.Window("EraUIMageTools","Mage · Food & Water",420,390)
  heading=T.Text(window,"",12);heading:SetPoint("TOPLEFT",18,-56);heading:SetWidth(380)
  for i,kind in ipairs({"food","water"})do
   local b=T.Button(window,"",380,34,true);b:SetPoint("TOPLEFT",18,-94-(i-1)*42);buttons[kind]=b
  end
  T.Slider(window,"Food stacks to offer","mageFoodStacks",-198,0,6,1)
  T.Slider(window,"Water stacks to offer","mageWaterStacks",-252,0,6,1)
  local note=T.Text(window,"Auto-fill Trade is toggled in Mage settings. Full stacks only; up to six trade slots. You confirm the trade.",12)
  note:SetPoint("TOPLEFT",18,-314);note:SetWidth(380)
 end
 window:Show();self:Refresh()
end
function M:FillTrade()
 session=session+1;local current=session
 if not E:GetSetting("enabled") or not E:GetSetting("mageAutoTrade") or InCombatLockdown() or IsShiftKeyDown()then return end
 local level=ValidLevel("NPC")
 if not level then E:Print("Trade supplies: partner level unavailable; add supplies manually.");return end
 local offered,desired={},{}
 for _,kind in ipairs({"food","water"})do
  local key=kind=="food" and "mageFoodStacks" or "mageWaterStacks"
  desired[kind]=math.max(0,math.min(6,tonumber(T.Options()[key])or 1));offered[kind]=0
 end
 local itemKinds={}
 for kind,list in pairs(ranks)do for _,entry in ipairs(list)do itemKinds[entry[2]]={kind=kind,entry=entry}end end
 local attempts=0
 local function Step()
  if current~=session or not E:GetSetting("mageAutoTrade") or not E:GetSetting("enabled") or InCombatLockdown() or IsShiftKeyDown() or not TradeFrame or not TradeFrame:IsShown()then return end
  if GetCursorInfo and GetCursorInfo()then return end
  local free
  local existing={food=0,water=0}
  for i=1,6 do
   local link=GetTradePlayerItemLink(i)
   if not link then free=free or i
   else
    local id=tonumber(link:match("item:(%d+)"));local record=itemKinds[id]
    if record then existing[record.kind]=existing[record.kind]+1 end
   end
  end
  if not free or attempts>=6 then return end
  local candidate
  T.Bags(function(bag,slot,info)
   local record=itemKinds[info.itemID];if not record then return end
   local kind=record.kind
   if math.max(existing[kind],offered[kind])>=desired[kind]then return end
   local name,_,_,_,required,_,_,stack=T.Item(info.itemID)
   if not name or not T.Number(required) or not T.Number(stack) or stack<=1 or info.stackCount~=stack or required>level then return end
   if not candidate or required>candidate.required then candidate={bag=bag,slot=slot,kind=kind,required=required,id=info.itemID,count=stack}end
  end)
  if not candidate then return end
  local info=C_Container.GetContainerItemInfo(candidate.bag,candidate.slot)
  if not info or info.itemID~=candidate.id or info.stackCount~=candidate.count or info.isLocked then return end
  attempts=attempts+1
  C_Container.PickupContainerItem(candidate.bag,candidate.slot)
  if CursorHasItem()then
   ClickTradeButton(free)
   if CursorHasItem()then ClearCursor();return end
   offered[candidate.kind]=offered[candidate.kind]+1
   C_Timer.After(.25,Step)
  end
 end
 C_Timer.After(.25,Step)
end
function M:Initialize()
 local _,class=UnitClass("player");if class~="MAGE"then return end
 local f=CreateFrame("Frame")
 for _,event in ipairs({"PLAYER_TARGET_CHANGED","SPELLS_CHANGED","GET_ITEM_INFO_RECEIVED","TRADE_SHOW","TRADE_CLOSED","TRADE_REQUEST_CANCEL","PLAYER_REGEN_ENABLED"})do f:RegisterEvent(event)end
 f:SetScript("OnEvent",function(_,event)
  if event=="TRADE_SHOW"then M:FillTrade()
  elseif event=="TRADE_CLOSED" or event=="TRADE_REQUEST_CANCEL"then session=session+1
  else M:Refresh()end
 end)
end
