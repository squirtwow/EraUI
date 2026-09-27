local _, EraUI = ...
local Module = {}
EraUI:RegisterModule("QoL", Module)

local function HasVendorPrice(tooltip, data)
    local sellPriceType = Enum and Enum.TooltipDataLineType
        and Enum.TooltipDataLineType.SellPrice
    if sellPriceType and data and data.lines then
        for _, line in ipairs(data.lines) do
            if line.type == sellPriceType then return true end
        end
    end

    -- Older clients may expose only the rendered, localized price label.
    local label = _G.SELL_PRICE or "Sell Price"
    label = label:gsub("%%.*", ""):gsub(":%s*$", "")
    local name = tooltip:GetName()
    if name and label ~= "" then
        for index = 1, tooltip:NumLines() do
            local line = _G[name .. "TextLeft" .. index]
            local text = line and line:GetText()
            if text and text:find(label, 1, true) then return true end
        end
    end
    return false
end

local function AddVendorPrice(tooltip, data)
    if tooltip ~= _G.GameTooltip then return end
    if tooltip.IsForbidden and tooltip:IsForbidden() then return end
    if not EraUI:GetSetting("vendorPrice") then return end
    if tooltip.__EraUIVendorAdded then return end
    if HasVendorPrice(tooltip, data) then return end

    local itemLink
    if tooltip.GetItem then
        local _, link = tooltip:GetItem()
        itemLink = link
    end
    local item = itemLink or (data and data.id)
    if not item then return end

    local getItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not getItemInfo then return end
    local sellPrice = select(11, getItemInfo(item))
    if sellPrice and sellPrice > 0 then
        tooltip.__EraUIVendorAdded = true
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("Vendor price", GetMoneyString(sellPrice, true), 0.82, 0.68, 0.42, 1, 1, 1)
    end
end

local function ResetVendorFlag(tooltip)
    tooltip.__EraUIVendorAdded = nil
end

local questTracker
local questBlocks = setmetatable({}, { __mode = "k" })

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end

local function PaintQuestTitle(block)
    local state, label = questBlocks[block], block.HeaderText
    if not state or not label then return end
    local title, id = label:GetText(), block.id
    if not Public(title) or not Public(id) or type(title) ~= "string" then return end
    -- Restore only our own text. Pool reuse and other addons may have replaced it.
    if title == state.shown and id == state.questID then
        title = state.title
        label:SetText(title)
    end
    state.title, state.questID, state.shown = title, id, nil
    if not EraUI:GetSetting("enabled") or not EraUI:GetSetting("questLevels") then return end
    if title == "" or title:match("^%[%d+[^%]]*%]") then return end
    if type(id) ~= "number" or not C_QuestLog or not C_QuestLog.GetQuestDifficultyLevel then return end
    local ok, level = pcall(C_QuestLog.GetQuestDifficultyLevel, id)
    if not ok or not Public(level) or type(level) ~= "number" or level <= 0 then return end
    if not label.GetHeight or not label.IsTruncated then return end
    local height = label:GetHeight()
    if not Public(height) or type(height) ~= "number" or height <= 0 then return end

    -- SetHeader writes native layout state, including the accumulated block
    -- height. Never reenter it or MarkDirty from an addon hook/timer: the native
    -- tracker also performs restricted aura reads. Paint only the font string,
    -- retaining the complete original title if a prefix needs more layout space.
    local shown = "[" .. level .. "] " .. title
    label:SetText(shown)
    local newHeight, truncated = label:GetHeight(), label:IsTruncated()
    if not Public(newHeight) or type(newHeight) ~= "number" or not Public(truncated)
        or truncated or newHeight > height + .01 then
        label:SetText(title)
        return
    end
    state.shown = shown
end

local function HookQuestBlock(_, block)
    if not block or not block.SetHeader or questBlocks[block] then return end
    questBlocks[block] = {}
    hooksecurefunc(block, "SetHeader", function(self)
        -- Native SetHeader has supplied fresh text, possibly for another
        -- quest using the same pooled block. Do not restore cached text.
        local state = questBlocks[self]
        state.title, state.questID, state.shown = nil, nil, nil
        PaintQuestTitle(self)
    end)
    PaintQuestTitle(block)
end

function Module:SetupQuestLevels()
    if questTracker then return end
    local tracker = _G.QuestObjectiveTracker
    if not tracker or not tracker.AddBlock then return end
    questTracker = tracker
    hooksecurefunc(tracker, "AddBlock", HookQuestBlock)
    if tracker.GetExistingBlock and C_QuestLog and C_QuestLog.GetNumQuestWatches
        and C_QuestLog.GetQuestIDForQuestWatchIndex then
        for index = 1, C_QuestLog.GetNumQuestWatches() do
            local id = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
            if id then HookQuestBlock(tracker, tracker:GetExistingBlock(id)) end
        end
    end
end

function Module:RefreshQuestLevels()
    self:SetupQuestLevels()
    for block in pairs(questBlocks) do PaintQuestTitle(block) end
end

local bagButtonHooked

local function ApplyBagCountVisibility(button)
    if button.SetCountShown then
        button:SetCountShown(EraUI:GetSetting("bagSpace") and true or false)
    end
end

function Module:UpdateBagSpace()
    local button = _G.MainMenuBarBackpackButton
    if not button then return end

    if button.UpdateFreeSlots and button.SetCountShown then
        if bagButtonHooked ~= button then
            hooksecurefunc(button, "UpdateFreeSlots", ApplyBagCountVisibility)
            bagButtonHooked = button
        end
        button:UpdateFreeSlots()
        return
    end

    -- Older clients share the existing count region rather than a second label.
    local count = button.Count or _G.MainMenuBarBackpackButtonCount or self.bagCount
    local enabled = EraUI:GetSetting("bagSpace")
    if not count and not enabled then return end
    if not count then
        self.bagCount = self.bagCount or button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        count = self.bagCount
        count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    end
    count:SetShown(enabled and true or false)
    if not enabled then return end

    local getFreeSlots = C_Container and C_Container.GetContainerNumFreeSlots
        or GetContainerNumFreeSlots
    if not getFreeSlots then count:Hide(); return end
    local total = 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local free, family = getFreeSlots(bag)
        -- Specialty-bag space cannot hold ordinary loot.
        if free and (family == nil or family == 0) then total = total + free end
    end
    count:SetText(total)
end

function Module:ApplyChatClassColors()
    local getCVar = C_CVar and C_CVar.GetCVar or GetCVar
    local setCVar = C_CVar and C_CVar.SetCVar or SetCVar
    if not getCVar or not setCVar then return false end
    local ok, current = pcall(getCVar, "chatClassColorOverride")
    if not ok or current == nil then return false end
    -- Blizzard's override uses 0 to show class colours and 1 to hide them.
    local value = EraUI:GetSetting("classColors") and "0" or "1"
    if current == value then return true end
    if not pcall(setCVar, "chatClassColorOverride", value) then return false end
    local readOK, actual = pcall(getCVar, "chatClassColorOverride")
    return readOK and actual == value
end

function Module:Initialize()
    if not self.bagEvents then
        self.bagEvents = CreateFrame("Frame")
        self.bagEvents:RegisterEvent("BAG_UPDATE_DELAYED")
        self.bagEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
        self.bagEvents:RegisterEvent("ADDON_LOADED")
        self.bagEvents:SetScript("OnEvent", function(_, event)
            self:UpdateBagSpace()
            if event ~= "BAG_UPDATE_DELAYED" then self:SetupQuestLevels() end
        end)
    end
    self:UpdateBagSpace()
    self:SetupQuestLevels()

    local tooltip = _G.GameTooltip
    if tooltip and not self.tooltipHooked then
        local modernTooltips = TooltipDataProcessor
            and TooltipDataProcessor.AddTooltipPostCall
            and Enum and Enum.TooltipDataType
            and Enum.TooltipDataType.Item ~= nil
        local legacyTooltips = tooltip.HasScript
            and tooltip:HasScript("OnTooltipSetItem")

        if modernTooltips or legacyTooltips then
            -- ClearLines also runs when moving between items without hiding.
            hooksecurefunc(tooltip, "ClearLines", ResetVendorFlag)
            tooltip:HookScript("OnHide", ResetVendorFlag)

            if modernTooltips then
                TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddVendorPrice)
            else
                tooltip:HookScript("OnTooltipSetItem", function(self)
                    AddVendorPrice(self)
                    self:Show()
                end)
            end
            self.tooltipHooked = true
        end
    end

    if not self:ApplyChatClassColors() then
        EraUI:Print("Could not apply class colours in chat on this client.")
    end
end
