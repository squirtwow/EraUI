local _,E=...
local M={};E:RegisterModule("ChatDragging",M)
local ns=E.Classic
ns.DB_DEFAULTS.erauiChatPositions=""
local hooked={};local moving,queued,restoring=false,false,false
local records={};local identity
local function Editing()
 return EditModeManagerFrame and EditModeManagerFrame:IsShown()
end
local function State()
 if not identity then identity=UnitGUID("player")end
 if not identity then return end
 records[identity]=records[identity]or {locked=true}
 return records[identity]
end
function M:Load()
 records={}
 for id,x,y,lock in (ns.db.erauiChatPositions or ""):gmatch("([%w%-]+),([%d%.]+),([%d%.]+),([01])")do
  x,y=tonumber(x),tonumber(y)
  if x and y and x<=1 and y<=1 then records[id]={x=x,y=y,locked=lock=="1"}end
 end
end
function M:Save()
 local state=State();if not state or not ChatFrame1 then return end
 local x,y=ChatFrame1:GetCenter();if not x or not y then return end
 local ratio=ChatFrame1:GetEffectiveScale()/UIParent:GetEffectiveScale()
 state.x=math.max(0,math.min(1,x*ratio/UIParent:GetWidth()))
 state.y=math.max(0,math.min(1,y*ratio/UIParent:GetHeight()))
 local parts={}
 for id,p in pairs(records)do
  if p.x and p.y then parts[#parts+1]=string.format("%s,%.6f,%.6f,%d",id,p.x,p.y,p.locked and 1 or 0)end
 end
 table.sort(parts);ns.db.erauiChatPositions=table.concat(parts,"|");ns.MirrorSave()
end
function M:Restore()
 if moving or restoring or Editing()or InCombatLockdown()then return end
 local p=State();if not p or not p.x or not ChatFrame1 then return end
 restoring=true
 local ratio=UIParent:GetEffectiveScale()/ChatFrame1:GetEffectiveScale()
 ChatFrame1:ClearAllPoints()
 ChatFrame1:SetPoint("CENTER",UIParent,"BOTTOMLEFT",p.x*UIParent:GetWidth()*ratio,p.y*UIParent:GetHeight()*ratio)
 restoring=false
end
local function QueueRestore()
 if queued or restoring or moving or Editing()then return end
 queued=true;C_Timer.After(0,function()queued=false;M:Restore()end)
end
local function Docked(chat)
 return chat and (chat==ChatFrame1 or chat.isDocked)
end
function M:Discover()
 if InCombatLockdown()then return end
 for i=1,50 do
  local tab=_G["ChatFrame"..i.."Tab"]
  if tab and not hooked[tab]then
   hooked[tab]=true
   local start,stop=tab:GetScript("OnDragStart"),tab:GetScript("OnDragStop")
   tab:RegisterForDrag("LeftButton")
   tab:SetScript("OnDragStart",function(self,...)
    local chat=_G["ChatFrame"..self:GetID()]
    if not Docked(chat)or Editing()then if start then start(self,...)end;return end
    local p=State();if InCombatLockdown()or not p or p.locked then return end
    moving=true;ChatFrame1:SetMovable(true);ChatFrame1:StartMoving()
   end)
   tab:SetScript("OnDragStop",function(self,...)
    if moving then
     ChatFrame1:StopMovingOrSizing();moving=false;M:Save();M:Restore()
    elseif not Docked(_G["ChatFrame"..self:GetID()])or Editing()then
     if stop then stop(self,...)end
    end
   end)
  end
 end
end
function M:Initialize()
 if not E:GetSetting("enabled")or not E:GetSetting("classicChatDragging")then return end
 if not Menu or not Menu.ModifyMenu or not ChatFrame1 then return end
 self:Load();self:Discover();self:Restore()
 Menu.ModifyMenu("MENU_FCF_TAB",function(owner,root)
  local chat=owner and owner.GetID and _G["ChatFrame"..owner:GetID()]or (FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame())
  if not Docked(chat)then return end
  local p=State();if not p then return end
  root:CreateDivider();root:CreateTitle("EraUI")
  local item=root:CreateButton(p.locked and "Unlock chat"or "Lock chat",function()
   if InCombatLockdown()then return end
   p.locked=not p.locked;M:Save()
  end)
  item:SetEnabled(not InCombatLockdown())
  item:SetTooltip(function(tooltip)
   tooltip:AddLine("Drag the General or Combat Log tab while unlocked.")
   tooltip:AddLine("Docked tabs move together. Position and lock state are saved.")
  end)
 end)
 hooksecurefunc(ChatFrame1,"SetPoint",QueueRestore)
 if EditModeManagerFrame then EditModeManagerFrame:HookScript("OnHide",function()if not InCombatLockdown()then M:Save()end end)end
 local events=CreateFrame("Frame")
 for _,event in ipairs({"PLAYER_ENTERING_WORLD","UPDATE_CHAT_WINDOWS","UPDATE_FLOATING_CHAT_WINDOWS","PLAYER_REGEN_ENABLED","UI_SCALE_CHANGED"})do events:RegisterEvent(event)end
 events:SetScript("OnEvent",function()M:Discover();QueueRestore()end)
end
