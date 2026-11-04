-- The bank window's 1.x dressing, the bank's own step in the shared window
-- chrome: the chrome frames BankFrame (only while Bags & Bank is on), then
-- calls ns.SkinBank(BankFrame) by name, before it darkens the frame art for
-- Dark Windows. On the game's frames this only sets textures, fonts and
-- colours, fades the modern backdrop (alpha) and hides the panel's edge
-- shadows and the bag slots' padlocks; the only things moved are EraUI's own
-- gravel floor and "Item Slots" heading. What it made and hooked is kept in
-- weak tables, never on the bank's frames or buttons.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local B = Look.Bags

local SLOT_RED, SLOT_WHITE = { 1, 0.1, 0.1 }, { 1, 1, 1 }

local hookedBanks = Look.Weak() -- bank frame: its hooks in
local readySlots = Look.Weak()  -- item slot or bag slot button: its hooks in
local panelsAtLogin             -- the window chrome's switch when the bank was first dressed

-- The hooks act only while the switches loaded at login allow the bank's
-- look (both are reload settings).
local function BankLookOn()
    return Look.Setting("bagsBank") ~= false and panelsAtLogin ~= false
end

-- Every active button of one of the bank's pools.
local function EachActive(pool, dress)
    if type(pool) ~= "table" or type(pool.EnumerateActive) ~= "function" then return end
    local list = {}
    pcall(function()
        for key, value in pool:EnumerateActive() do list[#list + 1] = type(key) == "table" and key or value end
    end)
    for _, button in ipairs(list) do Look.Try(dress, button) end
end

---------------------------------------------------------------------------
-- Slots
---------------------------------------------------------------------------

-- The 1.x ring sized by the slot (64 for the usual 37) over a dark hole.
local function SlotLook(button)
    B.Ring(button, B.Width(button) * 64 / 37)
    B.Hole(button)
end

local function SlotAgain(button)
    if BankLookOn() then Look.Try(SlotLook, button) end
end

-- An item slot. The game's own Refresh puts its slot frame back on the
-- normal face every time, so the art follows it.
local function ItemSlot(button)
    if not readySlots[button] then
        readySlots[button] = true
        for _, method in ipairs({ "Refresh", "UpdateBackgroundForBankType" }) do
            if type(button[method]) == "function" then Look.Hook(button, method, SlotAgain) end
        end
    end
    SlotLook(button)
end

-- A bank bag slot's picture: the old empty bag icon while the slot holds no
-- bag, red while the slot isn't bought; a bag's own icon stays, white.
local function BagPicture(button, picture)
    local note, buy = button.tooltipText, BANK_BAG_PURCHASE
    local unbought = buy ~= nil and not Look.Secret(note) and note == buy
    local fine, file = Look.Ask(picture, "GetTexture")
    if unbought or (fine and file == nil) then
        picture:SetTexture(Look.FirstPath("bankBagSlot"))
        Look.Crop(picture, 0, 1, 0, 1)
        picture:Show()
    end
    local colour = unbought and SLOT_RED or SLOT_WHITE
    picture:SetVertexColor(colour[1], colour[2], colour[3])
end

-- A bank bag slot: the item slot's art, no padlock, its picture.
local function BagSlotLook(button)
    SlotLook(button)
    Look.Shown(button.DisabledOverlay, false)
    if button.icon then BagPicture(button, button.icon) end
end

local function BagSlotAgain(button)
    if BankLookOn() then Look.Try(BagSlotLook, button) end
end

local function BagSlot(button)
    if not readySlots[button] then
        readySlots[button] = true
        if type(button.SetItemButtonTexture) == "function" then Look.Hook(button, "SetItemButtonTexture", BagSlotAgain) end
    end
    BagSlotLook(button)
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

local function IsDivider(piece)
    local fine, atlas = Look.Ask(piece, "GetAtlas")
    return fine and not Look.Secret(atlas) and atlas == "bank-divider"
end

-- EraUI's gravel floor under everything, tiled, set straight from its file
-- (Dark Mode leaves it its own colour).
local function Floor(bank)
    local gravel = Look.OwnPiece(bank, "bankFloor")
    if not gravel then
        gravel = Look.OwnTexture(bank, "bankFloor", "BACKGROUND", 1)
        gravel:SetTexture(B.FLOOR, "REPEAT", "REPEAT")
        gravel:SetHorizTile(true)
        gravel:SetVertTile(true)
        Look.Crop(gravel, 0, 1, 0, 1)
        Look.Inside(gravel, bank, 4, 20, 4, 4)
    end
    gravel:Show()
end

local function Heading(bank, panel)
    local heading = Look.OwnPiece(bank, "bankHeading")
    if not heading then
        heading = Look.OwnLabel(bank, "bankHeading", nil, "ARTWORK")
        heading:SetFontObject(Look.GoldFont())
        heading:SetText(ITEMSLOTTEXT or "Item Slots")
        Look.Pin(heading, "TOP", panel, "TOP", 0, -46)
    end
    heading:Show()
end

local function DressPanel(bank, panel)
    Look.EachRegion(panel.NineSlice, function(piece)
        if B.IsTexture(piece) then Look.Fade(piece) end
    end)
    Look.Shown(panel.EdgeShadows, false)
    Floor(bank)
    local till = panel.MoneyFrame or {}
    for _, button in ipairs({ panel.PurchaseButton or false, till.WithdrawButton or false, till.DepositButton or false }) do
        if button then Look.SkinRedButton(button) end
    end
    Heading(bank, panel)
    EachActive(panel.itemButtonPool, ItemSlot)
end

-- At login the ring is empty until the bank first opens (the game puts the
-- banker's face there itself): the banker's face, or the player's.
local function FillPortrait(bank)
    local face = Look.Path(bank, "PortraitContainer", "portrait")
    if not face or type(SetPortraitTexture) ~= "function" then return end
    local fine, file = Look.Ask(face, "GetTexture")
    if not fine or file ~= nil then return end
    local asked, there = pcall(UnitExists, "npc")
    local who = (asked and not Look.Secret(there) and there) and "npc" or "player"
    pcall(SetPortraitTexture, face, who)
end

local function DressBank(bank)
    Look.Fade(bank.Background)
    Look.EachRegion(bank, function(piece)
        if IsDivider(piece) then Look.Fade(piece) end
    end)
    if bank.BankPanel then DressPanel(bank, bank.BankPanel) end
    local gold = Look.GoldFont()
    for _, label in ipairs({ bank.BagText or false, bank.BagCost or false }) do
        if label then label:SetFontObject(gold) end
    end
    EachActive(bank.itemButtonBagPool, BagSlot)
    FillPortrait(bank)
end

local function BankAgain(bank)
    if BankLookOn() then Look.Try(DressBank, bank) end
end

local function ItemSlotsAgain(panel)
    if BankLookOn() then EachActive(panel.itemButtonPool, ItemSlot) end
end

local function BagSlotsAgain(bank)
    if BankLookOn() then EachActive(bank.itemButtonBagPool, BagSlot) end
end

-- The bank's own step: dressed now (closed at login, ready for its first
-- opening), then, once, followed through its own refreshes and showing.
-- A method this client lacks is named in the debug report's missing pieces.
function ns.SkinBank(bank)
    if not bank then return end
    if panelsAtLogin == nil then panelsAtLogin = not (ns.db and ns.db.panels == false) end
    Look.Try(DressBank, bank)
    if hookedBanks[bank] then return end
    hookedBanks[bank] = true
    local panel = bank.BankPanel
    Look.HookOrMiss(panel, "BankPanel", "GenerateItemSlotsForSelectedTab", ItemSlotsAgain)
    Look.HookOrMiss(panel, "BankPanel", "RefreshBankPanel", ItemSlotsAgain)
    Look.HookOrMiss(bank, "BankFrame", "RefreshBagButtons", BagSlotsAgain)
    Look.HookScript(bank, "OnShow", BankAgain, "bank")
end
