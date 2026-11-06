local _, EraUI = ...

-- Open Clams (/era > Bags & Vendors > Bags & Loot; off by default; seen
-- working in game 2026-11-07). The clams in your bags (Small Barnacled Clam and the rest:
-- an item with loot whose name ends in "Clam", so Clam Meat is left alone)
-- open one at a time by themselves once your bags settle or a loot window
-- closes. A clam button shows while you carry clams and opens one per click;
-- drag it to move it (kept per character, EraUIClassicCharDB.clamButton).
-- Never in a fight, while looting, dead, casting or holding something, with
-- full bags (the loot would stay stuck in the loot window), or with a vendor,
-- bank, mailbox, trade or auction house open: using a bag item there sells
-- or moves it. The game's own record of who you're talking to decides that,
-- so a window that closed without its closing event can't keep clams shut
-- until a /reload (seen on the live client). It does nothing while the
-- separate Clam Opener addon is loaded, which does the same job.
-- Only C_Container reads and UseContainerItem are used on the game's side;
-- nothing of the game's is hooked or written on, and the tooltip is EraUI's
-- own frame, not the game's.
local Clams = {open = {}, looting = false}
EraUI:RegisterModule("OpenClams", Clams)

local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
local WAIT = .4 -- seconds after bags settle before the next clam opens
local PREFIX = "Open Clams: "

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end

-- A clam: an item with loot whose name ends in "Clam".
local function IsClam(info)
    return type(info) == "table" and Public(info.hasLoot) and info.hasLoot == true
        and Public(info.itemName) and type(info.itemName) == "string" and info.itemName:find("Clam$") ~= nil
end

-- The first clam that can be opened now, its icon, and how many you carry.
function Clams:Find()
    local api = C_Container
    if not (api and api.GetContainerNumSlots and api.GetContainerItemInfo) then return nil, nil, nil, 0 end
    local bag, slot, icon, count = nil, nil, nil, 0
    for b = 0, LAST_BAG do
        local slots = api.GetContainerNumSlots(b)
        if Public(slots) and type(slots) == "number" then
            for s = 1, slots do
                local info = api.GetContainerItemInfo(b, s)
                if IsClam(info) then
                    local stack = Public(info.stackCount) and tonumber(info.stackCount) or 1
                    count = count + stack
                    if not bag and Public(info.isLocked) and not info.isLocked then
                        bag, slot, icon = b, s, info.iconFileID
                    end
                end
            end
        end
    end
    return bag, slot, icon, count
end

-- Windows where using a bag item sells, banks, mails, trades or lists it.
local FRAMES = {"MerchantFrame", "BankFrame", "MailFrame", "TradeFrame", "AuctionHouseFrame", "AuctionFrame", "GuildBankFrame"}
local NPCS = {"Merchant", "Banker", "MailInfo", "Auctioneer", "GuildBanker"}
-- Their events, only for a client that can't say who you're talking to.
local WINDOWS = {
    MERCHANT_SHOW = "merchant", MERCHANT_CLOSED = "merchant",
    BANKFRAME_OPENED = "bank", BANKFRAME_CLOSED = "bank",
    MAIL_SHOW = "mail", MAIL_CLOSED = "mail",
    TRADE_SHOW = "trade", TRADE_CLOSED = "trade",
    AUCTION_HOUSE_SHOW = "auction", AUCTION_HOUSE_CLOSED = "auction",
}
local SHOWN = {MERCHANT_SHOW = true, BANKFRAME_OPENED = true, MAIL_SHOW = true, TRADE_SHOW = true, AUCTION_HOUSE_SHOW = true}

-- Whether you're talking to a vendor, banker, mailbox, auctioneer or guild
-- bank, by the game's own record; nil when this client can't say.
local function Talking()
    local manager = C_PlayerInteractionManager
    local check = manager and manager.IsInteractingWithNpcOfType
    local types = Enum and Enum.PlayerInteractionType
    if type(check) ~= "function" or type(types) ~= "table" then return nil end
    for _, name in ipairs(NPCS) do
        local id = types[name]
        if id ~= nil then
            local ok, yes = pcall(check, id)
            if not ok or not Public(yes) then return nil end
            if yes then return true end
        end
    end
    return false
end

function Clams:WindowOpen()
    for _, name in ipairs(FRAMES) do
        local frame = _G[name]
        if frame and frame.IsShown and frame:IsShown() then return true end
    end
    local talking = Talking()
    if talking ~= nil then return talking end
    return next(self.open) ~= nil
end

-- A free slot in a normal bag (a profession bag can't take clam meat or
-- pearls).
local function HasRoom()
    local free = C_Container and C_Container.GetContainerNumFreeSlots
    if not free then return true end
    for b = 0, LAST_BAG do
        local slots, family = free(b)
        if Public(slots) and Public(family) and type(slots) == "number" and slots > 0 and (family == 0 or family == nil) then
            return true
        end
    end
    return false
end

-- Why a clam can't be opened right now, or nil when it can.
function Clams:Blocked()
    if InCombatLockdown() then return "not in a fight" end
    if self:WindowOpen() then return "close the vendor, bank, mailbox or trade window first" end
    if self.looting then return "finish looting first" end
    if UnitIsDeadOrGhost("player") then return "not while dead" end
    if GetCursorInfo() then return "put down what's on your cursor first" end
    if UnitCastingInfo("player") or UnitChannelInfo("player") then return "not while casting" end
    if not HasRoom() then return "make room in your bags first" end
end

function Clams:OpenOne()
    if self:Blocked() then return false end
    local bag, slot = self:Find()
    if not bag then return false end
    C_Container.UseContainerItem(bag, slot)
    return true
end

-- The separate Clam Opener addon does the same job: EraUI steps aside.
local function Standalone()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if type(loaded) ~= "function" then return false end
    local ok, yes = pcall(loaded, "ClamOpener")
    return ok and Public(yes) and yes and true or false
end
Clams.Standalone = Standalone

function Clams:On()
    return EraUI:GetSetting("enabled") ~= false and EraUI:GetSetting("openClams") == true and not Standalone()
end

-- The clam button -----------------------------------------------------------

local function Saved()
    local char = EraUIClassicCharDB
    local point = type(char) == "table" and char.clamButton
    if type(point) == "table" and type(point[1]) == "string" then return point end
end

local function Place(button)
    button:ClearAllPoints()
    local p = Saved()
    if p then
        button:SetPoint(p[1], UIParent, type(p[2]) == "string" and p[2] or p[1], tonumber(p[3]) or 0, tonumber(p[4]) or 0)
    else
        button:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    end
end

-- A small tooltip of EraUI's own, in the game's tooltip look.
local function ShowTip(button)
    local tip = Clams.tip
    if not tip then
        tip = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        tip:SetFrameStrata("TOOLTIP")
        tip:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16, insets = {left = 4, right = 4, top = 4, bottom = 4}})
        tip:SetBackdropColor(0, 0, 0, .9)
        tip.text = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tip.text:SetPoint("TOPLEFT", 10, -10)
        tip.text:SetWidth(200)
        tip.text:SetJustifyH("LEFT")
        Clams.tip = tip
    end
    local _, _, _, count = Clams:Find()
    tip.text:SetText("|cffffd200Open Clams|r\nClams in your bags: " .. count
        .. "\nClick to open one. Drag to move.\n|cff99ccffThey also open by themselves out of a fight.|r")
    tip:SetSize(220, (tip.text:GetStringHeight() or 48) + 20)
    tip:ClearAllPoints()
    tip:SetPoint("BOTTOMLEFT", button, "TOPRIGHT", 4, 4)
    tip:Show()
end

local function HideTip()
    if Clams.tip then Clams.tip:Hide() end
end

-- A click: open one, or say why not.
function Clams:Click()
    local why = self:Blocked()
    if why then
        EraUI:Print(PREFIX .. why .. ".")
    elseif not self:OpenOne() then
        self:Update()
    end
end

-- The game's default action button look: icon, square frame, press and
-- hover, and the count in the corner.
function Clams:Button()
    if self.button then return self.button end
    local button = CreateFrame("Button", "EraUIClamButton", UIParent)
    button:SetSize(37, 37)
    button.icon = button:CreateTexture(nil, "BACKGROUND")
    button.icon:SetAllPoints()
    local normal = button:CreateTexture(nil, "ARTWORK")
    normal:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    normal:SetSize(64, 64)
    normal:SetPoint("CENTER")
    button:SetNormalTexture(normal)
    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)
    button:SetFrameStrata("MEDIUM")
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnDragStart", function(self) self:StartMoving() end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relative, x, y = self:GetPoint(1)
        if type(EraUIClassicCharDB) ~= "table" then EraUIClassicCharDB = {} end
        EraUIClassicCharDB.clamButton = {point, relative, x, y}
        if EraUI.SaveSettings then EraUI:SaveSettings() end
    end)
    button:SetScript("OnClick", function() Clams:Click() end)
    button:SetScript("OnEnter", ShowTip)
    button:SetScript("OnLeave", HideTip)
    button:SetScript("OnHide", HideTip)
    Place(button)
    button:Hide()
    self.button = button
    return button
end

-- Shows the button while you carry clams (and the option is on).
function Clams:Update()
    local _, _, icon, count = self:Find()
    if self.active and count > 0 then
        local button = self:Button()
        button.icon:SetTexture(icon)
        button.count:SetText(count > 1 and count or "")
        button:Show()
    elseif self.button then
        self.button:Hide()
    end
end

-- Opening by itself -------------------------------------------------------------

function Clams:Soon()
    if self.pending or not self.active then return end
    self.pending = true
    C_Timer.After(WAIT, function()
        self.pending = false
        if self.active then self:OpenOne() end
    end)
end

local EVENTS = {"BAG_UPDATE_DELAYED", "LOOT_OPENED", "LOOT_CLOSED", "PLAYER_REGEN_ENABLED", "PLAYER_UNGHOST",
    "PLAYER_ENTERING_WORLD"}

local function OnEvent(_, event)
    if WINDOWS[event] then
        Clams.open[WINDOWS[event]] = SHOWN[event] or nil
        if not SHOWN[event] then Clams:Soon() end
        return
    end
    if event == "LOOT_OPENED" then
        Clams.looting = true
    elseif event == "LOOT_CLOSED" then
        Clams.looting = false
    end
    Clams:Update()
    Clams:Soon()
end

-- Follows the option (and Clam Opener being loaded).
function Clams:Refresh()
    local want = self:On()
    if want ~= (self.active == true) then
        if not self.frame then
            self.frame = CreateFrame("Frame")
            self.frame:SetScript("OnEvent", OnEvent)
        end
        for _, event in ipairs(EVENTS) do
            if want then self.frame:RegisterEvent(event) else self.frame:UnregisterEvent(event) end
        end
        for event in pairs(WINDOWS) do
            if want then pcall(self.frame.RegisterEvent, self.frame, event) else pcall(self.frame.UnregisterEvent, self.frame, event) end
        end
        self.active = want
        if not want then self.open, self.looting = {}, false end
    end
    self:Update()
    if want then self:Soon() end
end

function Clams:Initialize()
    self.open, self.looting = {}, false
    self:Refresh()
end
