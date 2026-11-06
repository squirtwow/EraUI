-- Open Clams (/era > Bags & Vendors > Bags & Loot; Modules/OpenClams.lua) on
-- a small mock of the game: off by default; on, clams open one at a time by
-- themselves and a clam button shows while you carry some; never in a fight,
-- while looting, dead, casting, holding something, with full bags, or at a
-- vendor, bank, mailbox, trade or auction house. The game's own record of who
-- you're talking to wins over the windows' events (on the live client a
-- window closed without its closing event and clams stayed shut until a
-- /reload). Steps aside while Clam Opener is loaded. Run from the addon folder.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

-- Mock frames: just enough for the module.
local frames = {}
local Proto = {}
local function New(kind, name)
    local f = setmetatable({kind = kind, shown = true, scripts = {}, events = {}, points = {}}, {__index = function(_, k)
        if Proto[k] then return Proto[k] end
        if type(k) == "string" and k:match("^[A-Z]") then return function() end end
    end})
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
function Proto:Show() self.shown = true end
function Proto:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function Proto:IsShown() return self.shown end
function Proto:SetScript(k, fn) self.scripts[k] = fn end
function Proto:RegisterEvent(e) self.events[e] = true end
function Proto:UnregisterEvent(e) self.events[e] = nil end
function Proto:SetPoint(...) self.points[#self.points + 1] = {...} end
function Proto:ClearAllPoints() self.points = {} end
function Proto:GetPoint() return "TOPLEFT", UIParent, "BOTTOMLEFT", 120, 340 end
function Proto:CreateFontString() return New("FontString") end
function Proto:CreateTexture() return New("Texture") end
function Proto:SetText(t) self.text = t end
function Proto:SetTexture(t) self.texture = t end
function Proto:GetStringHeight() return 48 end

_G.CreateFrame = function(kind, name) return New(kind, name) end
_G.UIParent = New("Frame")
_G.GameTooltip = nil -- never used: the tooltip is the module's own
local timers = {}
_G.C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
local function RunTimers()
    local run = timers
    timers = {}
    for _, fn in ipairs(run) do fn() end
end
local combat, dead, cursor, casting = false, false, nil, nil
_G.InCombatLockdown = function() return combat end
_G.UnitIsDeadOrGhost = function() return dead end
_G.GetCursorInfo = function() return cursor end
_G.UnitCastingInfo = function() return casting end
_G.UnitChannelInfo = function() return nil end
_G.NUM_BAG_SLOTS = 4
local loadedAddons = {}
_G.C_AddOns = {IsAddOnLoaded = function(name) return loadedAddons[name] == true end}
-- Who you're talking to, by the game's own record.
local talkingTo = {}
_G.Enum = {PlayerInteractionType = {Merchant = 5, Banker = 8, GuildBanker = 10, MailInfo = 17, Auctioneer = 21}}
local manager = {IsInteractingWithNpcOfType = function(t) return talkingTo[t] == true end}
_G.C_PlayerInteractionManager = manager

-- Bags: bag 0 has 4 slots; bag 1 stands in for a profession bag's free slots.
local bags = {[0] = {}}
local used = {}
local profFree, profFamily = 0, 0
_G.C_Container = {
    GetContainerNumSlots = function(b) return b == 0 and 4 or 0 end,
    GetContainerNumFreeSlots = function(b)
        if b == 1 then return profFree, profFamily end
        if b ~= 0 then return 0, 0 end
        local n = 0
        for s = 1, 4 do if bags[0][s] == nil then n = n + 1 end end
        return n, 0
    end,
    GetContainerItemInfo = function(b, s) return bags[b] and bags[b][s] end,
    UseContainerItem = function(b, s) used[#used + 1] = b .. ":" .. s end,
}
local function Item(name, stack, hasLoot, locked)
    return {itemName = name, stackCount = stack, hasLoot = hasLoot, isLocked = locked or false, iconFileID = 777, itemID = 1}
end

local function Fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

-- A mock EraUI: its settings, chat lines and modules.
local settings, printed, saves
local function Load()
    frames, timers = {}, {}
    _G.EraUIClamButton = nil
    settings, printed, saves = {enabled = true, openClams = false}, {}, 0
    local E = {modules = {}}
    function E:RegisterModule(name, module) module.name = name; self.modules[name] = module end
    function E:GetSetting(key) return settings[key] end
    function E:Print(message) printed[#printed + 1] = message end
    function E:SaveSettings() saves = saves + 1 end
    assert(loadfile("Modules/OpenClams.lua"))("EraUI", E)
    local clams = E.modules.OpenClams
    clams:Initialize()
    return clams
end
local function Settle()
    Fire("BAG_UPDATE_DELAYED")
    RunTimers()
end
local function Last() return tostring(printed[#printed]) end
local WHY_WINDOW = "Open Clams: close the vendor, bank, mailbox or trade window first."

-- Off (the default): nothing listened to, opened or shown.
EraUIClassicCharDB = {}
bags[0] = {Item("Clam Meat", 5, false), Item("Small Barnacled Clam", 1, true, true), Item("Small Barnacled Clam", 2, true)}
local clams = Load()
Settle()
local listening = 0
for _, f in ipairs(frames) do for _ in pairs(f.events) do listening = listening + 1 end end
equal(#used .. " " .. listening .. " " .. tostring(EraUIClamButton), "0 0 nil", "off by default: no events, nothing opened, no button")

-- On: the first clam that isn't locked opens, never Clam Meat; the button
-- shows with every clam counted, locked or not.
settings.openClams = true
clams:Refresh()
RunTimers()
equal(table.concat(used, ","), "0:3", "switched on: the first clam that isn't locked opens, never Clam Meat")
local button = EraUIClamButton
equal(tostring(button.shown) .. " " .. tostring(button.count.text), "true 3", "the clam button shows with every clam counted")

-- While looting, nothing more opens; when the loot closes, the next one does.
used = {}
Fire("LOOT_OPENED")
Settle()
equal(#used, 0, "nothing opens while the loot window is open")
Fire("LOOT_CLOSED")
RunTimers()
equal(table.concat(used, ","), "0:3", "loot closed: the next clam opens")

-- Talking to a vendor, banker, mailbox, auctioneer or guild bank (the game
-- says so): never, by itself or by click, and a click says why.
for name, id in pairs(Enum.PlayerInteractionType) do
    used = {}
    talkingTo[id] = true
    Settle()
    button.scripts.OnClick(button)
    equal(#used .. " " .. Last(), "0 " .. WHY_WINDOW, "talking to a " .. name .. ": nothing opens, and a click says why")
    talkingTo[id] = nil
end

-- A window's show event without its closing one (seen on the live client),
-- while the game says you're talking to nobody: clams still open.
for _, stale in ipairs({"MAIL_SHOW", "MERCHANT_SHOW", "BANKFRAME_OPENED", "AUCTION_HOUSE_SHOW", "TRADE_SHOW"}) do
    used = {}
    Fire(stale)
    Settle()
    equal(table.concat(used, ","), "0:3", stale .. " without its closing event: the game says nothing is open, the clam opens")
end

-- One of the windows showing is enough, whatever the game's record says.
for _, name in ipairs({"MerchantFrame", "BankFrame", "MailFrame", "TradeFrame", "AuctionHouseFrame", "AuctionFrame", "GuildBankFrame"}) do
    used = {}
    New("Frame", name)
    Settle()
    button.scripts.OnClick(button)
    equal(#used, 0, name .. " showing: nothing opens")
    _G[name] = nil
end

-- A client that can't say who you're talking to: the windows' events decide.
_G.C_PlayerInteractionManager = nil
clams = Load()
settings.openClams = true
clams:Refresh()
RunTimers()
button = EraUIClamButton
for _, pair in ipairs({{"MERCHANT_SHOW", "MERCHANT_CLOSED"}, {"BANKFRAME_OPENED", "BANKFRAME_CLOSED"}, {"MAIL_SHOW", "MAIL_CLOSED"},
    {"TRADE_SHOW", "TRADE_CLOSED"}, {"AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED"}}) do
    used = {}
    Fire(pair[1])
    Settle()
    button.scripts.OnClick(button)
    equal(#used, 0, "no record from the game, " .. pair[1] .. ": nothing opens")
    Fire(pair[2])
    RunTimers()
    equal(#used, 1, "no record from the game, " .. pair[2] .. ": it opens again")
end
_G.C_PlayerInteractionManager = manager

-- In a fight, dead, holding something or casting: no, and a click says why.
local blocks = {
    {function(v) combat = v end, "not in a fight"},
    {function(v) dead = v end, "not while dead"},
    {function(v) cursor = v and "item" or nil end, "put down what's on your cursor first"},
    {function(v) casting = v and "Fireball" or nil end, "not while casting"},
}
for _, block in ipairs(blocks) do
    used = {}
    block[1](true)
    Settle()
    button.scripts.OnClick(button)
    equal(#used .. " " .. Last(), "0 Open Clams: " .. block[2] .. ".", "blocked (" .. block[2] .. "): nothing opens")
    block[1](false)
end
used = {}
button.scripts.OnClick(button)
equal(table.concat(used, ","), "0:3", "a click opens one when allowed")

-- Bags full: the loot would have nowhere to go. A profession bag's room doesn't count.
used = {}
bags[0][4] = Item("Linen Cloth", 1, false)
profFree, profFamily = 6, 8
Settle()
button.scripts.OnClick(button)
equal(#used .. " " .. Last(), "0 Open Clams: make room in your bags first.", "bags full: nothing opens, a click says why")
bags[0][4] = nil
Settle()
equal(table.concat(used, ","), "0:3", "a slot frees up: it opens by itself again")
profFree, profFamily = 0, 0

-- The tooltip is the module's own frame, never the game's.
button.scripts.OnEnter(button)
local tip = clams.tip
equal(tostring(tip and tip.shown) .. " " .. tostring(tip and tip.text.text:find("Clams in your bags: 3", 1, true) ~= nil),
    "true true", "hover: its own tooltip, with the count")
button.scripts.OnLeave(button)
equal(tip.shown, false, "the tooltip hides as the mouse leaves")

-- Dragging keeps the button's place for this character; the next login puts it there.
button.scripts.OnDragStop(button)
local kept = EraUIClassicCharDB.clamButton
equal(table.concat({tostring(kept[1]), tostring(kept[3]), tostring(kept[4])}, " ") .. " " .. saves, "TOPLEFT 120 340 1",
    "a drag keeps the button's place for this character, and saves")
clams = Load()
settings.openClams = true
clams:Refresh()
local point = EraUIClamButton.points[#EraUIClamButton.points]
equal(point[1] .. " " .. point[4] .. " " .. point[5], "TOPLEFT 120 340", "the next login puts the button where it was dragged")

-- No clams left: the button hides.
used = {}
bags[0] = {Item("Clam Meat", 5, false)}
Settle()
equal(tostring(EraUIClamButton.shown) .. " " .. #used, "false 0", "no clams: the button hides, nothing opened")

-- Switched off: the button hides and nothing opens.
bags[0] = {Item("Thick-shelled Clam", 1, true)}
Settle()
equal(EraUIClamButton.shown, true, "a clam: the button shows")
used = {}
settings.openClams = false
clams:Refresh()
Settle()
equal(tostring(EraUIClamButton.shown) .. " " .. #used, "false 0", "switched off: the button hides and nothing opens")

-- EraUI switched off as a whole: nothing either.
settings.openClams, settings.enabled = true, false
clams:Refresh()
Settle()
equal(#used, 0, "EraUI off: nothing opens")
settings.enabled = true

-- Clam Opener loaded: it does the job, so EraUI steps aside.
loadedAddons.ClamOpener = true
clams = Load()
settings.openClams = true
clams:Refresh()
Settle()
equal(#used .. " " .. tostring(EraUIClamButton), "0 nil", "Clam Opener loaded: EraUI opens nothing and shows no button")
equal(clams.Standalone(), true, "it knows Clam Opener is loaded")
loadedAddons.ClamOpener = nil

io.write("Open Clams checks passed: " .. checks .. " assertions.\n")
