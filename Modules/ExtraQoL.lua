local _, EraUI = ...
local Module = {}
EraUI:RegisterModule("ExtraQoL", Module)

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end

function Module:CheckDurability()
    if not EraUI:GetSetting("durabilityWarning") or not GetInventoryItemDurability then
        self.warned = false
        return
    end
    local lowest = 1
    for slot = 1, 19 do
        local current, maximum = GetInventoryItemDurability(slot)
        if Public(current) and Public(maximum) and type(current)=="number" and type(maximum)=="number" and maximum>0 then
            lowest = math.min(lowest, current/maximum)
        end
    end
    if lowest > .2 then self.warned=false; return end
    if self.warned then return end
    self.warned=true
    local message = "Low durability: an equipped item is at "..math.floor(lowest*100).."%."
    EraUI:Print(message)
    if UIErrorsFrame then UIErrorsFrame:AddMessage(message,1,.35,.15) end
end

function Module:JunkSummary()
    if not EraUI:GetSetting("junkValueSummary") or not C_Container then return end
    local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not getInfo then return end
    local value, count, unknown = 0, 0, false
    for bag=0,(NUM_BAG_SLOTS or 4) do
        for slot=1,C_Container.GetContainerNumSlots(bag) do
            local info=C_Container.GetContainerItemInfo(bag,slot)
            if info and Public(info.quality) and info.quality==0 and not info.hasNoValue then
                local price=select(11,getInfo(info.hyperlink or info.itemID))
                if Public(price) and type(price)=="number" and Public(info.stackCount) then
                    local quantity=info.stackCount or 1
                    value=value+price*quantity;count=count+quantity
                else unknown=true end
            end
        end
    end
    EraUI:Print("Junk in bags: "..count.." items, "..GetMoneyString(value)..(unknown and " (some item prices are not loaded yet)." or "."))
end

-- Suppress presentation only during a quick-loot transaction. Do not Hide()
-- or reparent LootFrame: those can close the loot session or affect Edit Mode.
function Module:RevealLoot()
    local saved=self.lootPresentation
    self.lootPresentation=nil
    if saved then
        saved.frame:SetAlpha(saved.alpha)
        saved.frame:EnableMouse(saved.mouse)
    end
end
function Module:QuickLoot()
    if not EraUI:GetSetting("fastAutoLoot") or InCombatLockdown() or IsShiftKeyDown() then self:RevealLoot();return end
    if self.lootPending or not GetNumLootItems or not LootSlot then return end
    local count=GetNumLootItems()
    if count<=0 then return end
    self.lootPending=true
    self.lootGeneration=(self.lootGeneration or 0)+1
    local generation=self.lootGeneration
    if LootFrame then
        self.lootPresentation={frame=LootFrame,alpha=LootFrame:GetAlpha(),mouse=LootFrame:IsMouseEnabled()}
        if not self.lootShowHook then
            self.lootShowHook=true
            LootFrame:HookScript("OnShow",function(frame)
                if self.lootPresentation then frame:SetAlpha(0);frame:EnableMouse(false) end
            end)
        end
        LootFrame:SetAlpha(0);LootFrame:EnableMouse(false)
    end
    for slot=count,1,-1 do LootSlot(slot) end
    -- One bounded fallback, never an ongoing discovery/update loop.
    C_Timer.After(.45,function()
        if self.lootGeneration~=generation then return end
        self:RevealLoot()
    end)
end

function Module:AutoGossip()
    if not EraUI:GetSetting("autoGossip") or InCombatLockdown() or IsShiftKeyDown() then return end
    local api=C_GossipInfo
    if not api or not api.GetOptions or not api.SelectOption or not api.GetAvailableQuests or not api.GetActiveQuests then return end
    if #api.GetAvailableQuests()>0 or #api.GetActiveQuests()>0 then return end
    local options=api.GetOptions()
    if #options~=1 then return end
    local option=options[1]
    if not Public(option.gossipOptionID) or type(option.gossipOptionID)~="number" then return end
    if option.type~="gossip" or option.isSecret or option.hasSecret or option.isDisabled then return end
    if option.flags and option.flags~=0 then return end
    if option.cost and option.cost~=0 then return end
    if option.confirm or option.confirmText or option.confirmationText then return end
    if Enum and Enum.GossipOptionStatus and option.status and option.status~=Enum.GossipOptionStatus.Available then return end
    api.SelectOption(option.gossipOptionID)
end

local tooltipKeys=setmetatable({}, {__mode="k"})
local function AddID(tooltip,label,id)
    if not EraUI:GetSetting("tooltipIDs") or not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    if not Public(id) or type(id)~="number" or id<=0 then return end
    local key=label..":"..id
    local seen=tooltipKeys[tooltip]
    if not seen then seen={};tooltipKeys[tooltip]=seen end
    if seen[key] then return end
    seen[key]=true
    tooltip:AddDoubleLine(label.." ID",tostring(id),.65,.65,.65,1,1,1)
end
function Module:SetupTooltipIDs()
    for _,tooltip in ipairs({GameTooltip,ItemRefTooltip}) do
        if tooltip then tooltip:HookScript("OnTooltipCleared",function(self)tooltipKeys[self]=nil end) end
    end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        for _,label in ipairs({"Item","Spell","Unit"}) do
            local kind=Enum.TooltipDataType[label]
            if kind then
                local name=label
                TooltipDataProcessor.AddTooltipPostCall(kind,function(tooltip,data)
                    -- IDs come directly from this client's tooltip data, never a Retail database.
                    if data and name~="Unit" then AddID(tooltip,name,data.id)
                    elseif data and Public(data.guid) and type(data.guid)=="string" then
                        local unitKind,_,_,_,_,id=strsplit("-",data.guid)
                        if unitKind=="Creature" or unitKind=="Vehicle" then AddID(tooltip,"NPC",tonumber(id)) end
                    end
                end)
            end
        end
    else
        for _,tooltip in ipairs({GameTooltip,ItemRefTooltip}) do
            if tooltip and tooltip.HasScript and tooltip:HasScript("OnTooltipSetItem") then
                tooltip:HookScript("OnTooltipSetItem",function(self)
                    local _,link=self:GetItem()
                    if Public(link) and type(link)=="string" then AddID(self,"Item",tonumber(link:match("item:(%d+)"))) end
                end)
            end
        end
    end
end

function Module:Initialize()
    self.events=CreateFrame("Frame")
    for _,event in ipairs({"LOOT_READY","LOOT_OPENED","LOOT_CLOSED","LOOT_BIND_CONFIRM","UI_ERROR_MESSAGE","GOSSIP_SHOW","UPDATE_INVENTORY_DURABILITY","PLAYER_ENTERING_WORLD","MERCHANT_SHOW"}) do
        self.events:RegisterEvent(event)
    end
    self.events:SetScript("OnEvent",function(_,event)
        if event=="LOOT_READY" or event=="LOOT_OPENED" then self:QuickLoot()
        elseif event=="LOOT_CLOSED" then
            self.lootGeneration=(self.lootGeneration or 0)+1;self.lootPending=false;self:RevealLoot()
        elseif event=="LOOT_BIND_CONFIRM" or event=="UI_ERROR_MESSAGE" then self:RevealLoot()
        elseif event=="GOSSIP_SHOW" then self:AutoGossip()
        elseif event=="MERCHANT_SHOW" then self:JunkSummary()
        else self:CheckDurability() end
    end)
    self:SetupTooltipIDs()
end
