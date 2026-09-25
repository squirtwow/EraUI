-- EraUI bank window.
-- The bank window in the old manner: the old gravel floor under everything,
-- Item Slots and Bag Slots in gold, the item slots in the old quickslot rings
-- over the old dark holes, the bag row's empty slots wearing the old bag (red
-- for a slot not yet bought), and the banker in the portrait ring.
local _, EraUI = ...
local ns = EraUI.Classic

local QUICKSLOT = "Interface\\Buttons\\UI-Quickslot2"

local function SlotArt(button)
    local normal = button:GetNormalTexture()
    if normal then
        normal:SetTexture(QUICKSLOT)
        normal:SetTexCoord(0, 1, 0, 1)
        normal:ClearAllPoints()
        local w = button:GetWidth()
        if not w or w < 1 then w = 37 end
        normal:SetSize(w * 64 / 37, w * 64 / 37)
        normal:SetPoint("CENTER", button, "CENTER", 0, -1)
    end
    local bg = button.Background
    if bg then
        bg:SetColorTexture(0.06, 0.06, 0.06, 1)
        bg:ClearAllPoints()
        bg:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        bg:SetAlpha(1)
    end
end

local function SkinSlot(button)
    if not button then return end
    if not button.fcuiBankSlot then
        button.fcuiBankSlot = true
        if type(button.Refresh) == "function" then
            hooksecurefunc(button, "Refresh", SlotArt)
        end
        if type(button.UpdateBackgroundForBankType) == "function" then
            hooksecurefunc(button, "UpdateBackgroundForBankType", SlotArt)
        end
    end
    SlotArt(button)
end

local function SkinSlots(panel)
    if not panel or not panel.itemButtonPool then return end
    for button in panel.itemButtonPool:EnumerateActive() do SkinSlot(button) end
end

local function BagArt(button)
    SlotArt(button)
    if button.DisabledOverlay then button.DisabledOverlay:Hide() end
    local icon = button.icon
    if not icon then return end
    local unbought = button.tooltipText == BANK_BAG_PURCHASE
    if unbought or not icon:GetTexture() then
        icon:SetTexture(ns.TexPath("bagSlotIcon"))
        icon:SetTexCoord(0, 1, 0, 1)
        icon:Show()
        if unbought then icon:SetVertexColor(1, 0.1, 0.1) else icon:SetVertexColor(1, 1, 1) end
    else
        icon:SetVertexColor(1, 1, 1)
    end
end

local function SkinBagSlot(button)
    if not button then return end
    if not button.fcuiBankBag then
        button.fcuiBankBag = true
        if type(button.SetItemButtonTexture) == "function" then
            hooksecurefunc(button, "SetItemButtonTexture", BagArt)
        end
    end
    BagArt(button)
end

local function SkinBagSlots(frame)
    if not frame.itemButtonBagPool then return end
    for button in frame.itemButtonBagPool:EnumerateActive() do SkinBagSlot(button) end
end

local function FillPortrait(frame)
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    if not portrait or portrait:GetTexture() then return end
    if UnitExists("npc") then
        SetPortraitTexture(portrait, "npc")
    else
        SetPortraitTexture(portrait, "player")
    end
end

local function FadeTextures(frame)
    if not frame then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
end

local function Dress(frame)
    local panel = frame.BankPanel
    if frame.Background then frame.Background:SetAlpha(0) end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") and region.GetAtlas and region:GetAtlas() == "bank-divider" then
            region:SetAlpha(0)
        end
    end
    if frame.fcui and frame.fcui.insetFloor then frame.fcui.insetFloor:Hide() end
    if panel then
        if panel.NineSlice then FadeTextures(panel.NineSlice) end
        if panel.EdgeShadows then panel.EdgeShadows:Hide() end
        local floor = ns.OwnTexture(frame, "bankFloor", "BACKGROUND", 1)
        floor:SetTexture(ns.TexPath("bankFloor"), "REPEAT", "REPEAT")
        floor:SetHorizTile(true)
        floor:SetVertTile(true)
        floor:SetTexCoord(0, 1, 0, 1)
        floor:ClearAllPoints()
        floor:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -20)
        floor:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
        floor:Show()
        if panel.PurchaseButton then ns.SkinRedButton(panel.PurchaseButton) end
        local money = panel.MoneyFrame
        if money then
            if money.WithdrawButton then ns.SkinRedButton(money.WithdrawButton) end
            if money.DepositButton then ns.SkinRedButton(money.DepositButton) end
        end
        local title = frame.fcui and frame.fcui.itemSlotsTitle
        if not title then
            title = frame:CreateFontString(nil, "ARTWORK")
            title:SetFontObject(ns.FONT_GOLD)
            title:SetText(ITEMSLOTTEXT or "Item Slots")
            frame.fcui.itemSlotsTitle = title
        end
        title:ClearAllPoints()
        title:SetPoint("TOP", panel, "TOP", 0, -46)
        title:Show()
        SkinSlots(panel)
    end
    if frame.BagText then frame.BagText:SetFontObject(ns.FONT_GOLD) end
    if frame.BagCost then frame.BagCost:SetFontObject(ns.FONT_GOLD) end
    SkinBagSlots(frame)
    FillPortrait(frame)
end

function ns.SkinBank(frame)
    frame.fcui = frame.fcui or {}
    Dress(frame)
    if frame.fcuiBank then return end
    frame.fcuiBank = true
    local panel = frame.BankPanel
    if panel then
        ns.HookMethod(panel, "GenerateItemSlotsForSelectedTab", function(self) SkinSlots(self) end)
        ns.HookMethod(panel, "RefreshBankPanel", function(self) SkinSlots(self) end)
    end
    ns.HookMethod(frame, "RefreshBagButtons", SkinBagSlots)
    frame:HookScript("OnShow", Dress)
end
