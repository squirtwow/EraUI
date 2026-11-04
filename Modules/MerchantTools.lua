local _, EraUI = ...
local Module = {}
EraUI:RegisterModule("MerchantTools", Module)
local session = 0
function Module:Initialize()
    local events = CreateFrame("Frame")
    events:RegisterEvent("MERCHANT_SHOW")
    events:RegisterEvent("MERCHANT_CLOSED")
    events:SetScript("OnEvent", function(_, event)
        session = session + 1
        if event ~= "MERCHANT_SHOW" then return end
        local current, attempted = session, {}
        local function Repair()
            if current ~= session or not EraUI:GetSetting("autoRepair") or not CanMerchantRepair() then return end
            local cost, needed = GetRepairAllCost()
            if needed and cost > 0 then
                if GetMoney() >= cost then RepairAllItems(false)
                else EraUI:Print("Not enough money to repair all items.") end
            end
        end
        local function SellNext()
            if current ~= session or not MerchantFrame or not MerchantFrame:IsShown() then return end
            if InCombatLockdown() then return end
            if EraUI:GetSetting("autoSellJunk") and C_Container then
                for bag = 0, (NUM_BAG_SLOTS or 4) do
                    for slot = 1, C_Container.GetContainerNumSlots(bag) do
                        local info = C_Container.GetContainerItemInfo(bag, slot)
                        if info and info.quality == 0 and not info.isLocked and not info.hasNoValue then
                            local key = bag .. ":" .. slot .. ":" .. (info.itemID or "")
                            local price = select(11, C_Item.GetItemInfo(info.hyperlink or info.itemID))
                            if price and price > 0 and not attempted[key] then
                                attempted[key] = true
                                C_Container.UseContainerItem(bag, slot)
                                C_Timer.After(0.2, SellNext)
                                return
                            end
                        end
                    end
                end
            end
            Repair()
        end
        C_Timer.After(0.2, SellNext)
    end)
end
