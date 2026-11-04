-- The talent window's registry entry ("talents", from /era's Talents, a
-- reload setting) and its ways in and out:
--   * the talents micro buttons (TalentMicroButton, PlayerSpellsMicroButton)
--     open EraUI's window instead of the game's: their click is EraUI's while
--     the window is on, and the game's own click comes back when it is off;
--   * the inspect window's talents button, where this client has one, opens
--     the window on the inspected player, read only;
--   * EraUIClassicTalentsBind, a named click target: Key Bindings > AddOns >
--     Classic Talents (Bindings.xml) and a /click macro open the window with
--     it. Nothing here changes a key binding: on Forever a binding changed
--     from addon code sets off the hidden-health error flood, so the game's
--     talents key keeps opening the game's own talent window unless the
--     player takes N in the key offer (Look/TalentKey.lua, which asks once
--     and reloads straight after; the window's first opening offers it too);
--   * Escape (the game's own list of windows), the game menu, and EraUI's
--     shared window manager (it may stand beside the classic spellbook).
-- A pass runs the apply again (login, entering the world, Edit Mode...), so
-- it is cheap and safe to repeat; the restore runs on every pass while the
-- window is off. Passes never run in a fight.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local T = Look.Talent

-- The Classic setting this area reads, with its default (only where the
-- engine has none of its own).
do
    local engine = type(ns.DB_DEFAULTS) == "table" and ns.DB_DEFAULTS or nil
    if engine and engine.talents == nil then engine.talents = true end
end

local MICRO = { "TalentMicroButton", "PlayerSpellsMicroButton" }
local REFRESH_EVENTS = Look.Words([[TRAIT_CONFIG_UPDATED TRAIT_TREE_CURRENCY_INFO_UPDATED TRAIT_NODE_CHANGED
    PLAYER_TALENT_UPDATE ACTIVE_COMBAT_CONFIG_CHANGED PLAYER_LEVEL_UP PLAYER_LEVEL_CHANGED]])

local function NextFrame(fn)
    if C_Timer and C_Timer.After then C_Timer.After(0, fn) else fn() end
end

-- The inspect window's unit, when it can be read.
local function InspectedUnit()
    local unit = InspectFrame and InspectFrame.unit
    if Look.Secret(unit) or type(unit) ~= "string" or unit == "" then return nil end
    return unit
end

---------------------------------------------------------------------------
-- Opening and closing
---------------------------------------------------------------------------

local function Portrait()
    local face = T.parts.portrait
    if face and SetPortraitTexture then pcall(SetPortraitTexture, face, T.unit or "player") end
end

-- Shown: hidden, or shown again on your own trees after another player's.
function T.Toggle()
    local window = T.Build()
    if not window:IsShown() then
        window:Show()
        return
    end
    local wasInspecting = T.unit ~= nil
    window:Hide()
    if wasInspecting then window:Show() end
end

-- The window on another player's trees, from their first tab.
function T.OpenOn(unit)
    local window = T.Build()
    if window:IsShown() then window:Hide() end
    T.unit, T.tab = unit, 1
    window:Show()
end

local function Opened()
    Portrait()
    T.Sound("IG_CHARACTER_INFO_OPEN")
    T.Refresh()
    -- The key offer (Look/TalentKey.lua), once a session when it may ask.
    if T.OfferKey then Look.Try(T.OfferKey) end
end

local function Closed()
    T.unit = nil
    if T.hovered then
        Look.HideTip(T.hovered)
        T.hovered = nil
    end
    T.Sound("IG_CHARACTER_INFO_CLOSE")
end

-- While inspecting, five times a second: the inspect window gone takes this
-- one with it; a new player in it is followed.
local waited = 0
local function FollowInspect(window, elapsed)
    waited = waited + (Look.Number(elapsed) or 0)
    if waited < 0.2 then return end
    waited = 0
    if not T.unit then return end
    if not (InspectFrame and InspectFrame:IsShown()) then
        window:Hide()
        return
    end
    local now = InspectedUnit()
    if now and now ~= T.unit then
        T.unit = now
        Portrait()
        T.Refresh()
    end
end

-- Asked by the shared window manager before it places the window: while
-- inspecting, the inspect window stays open and this one stands right of it.
local function StandsBeside()
    if T.unit then return InspectFrame end
    return nil
end

---------------------------------------------------------------------------
-- Keeping it current
---------------------------------------------------------------------------

local booked = false
local function BookedRefresh()
    booked = false
    if T.window and T.window:IsShown() then T.Refresh() end
end

-- One refresh on the next frame, however many events come before it; none
-- while the window is closed (opening it refreshes anyway).
local function Book()
    if booked or not (T.window and T.window:IsShown()) then return end
    booked = true
    NextFrame(BookedRefresh)
end

-- The hovered talent's tooltip rebuilt when the game's tooltip data comes
-- in late (a spell seen for the first time), at most once per 0.2 s: a
-- rebuild that comes sooner waits for the rest of the 0.2 s.
local lastTip, tipBooked = -1, false
local function TipStillOurs()
    local button = T.hovered
    return button ~= nil and T.window ~= nil and T.window:IsShown() and Look.TipOwner() == button
end

local function RetipNow()
    tipBooked = false
    if not TipStillOurs() then return end
    lastTip = T.Now()
    T.ShowTalentTip(T.hovered)
end

local function Retip()
    if tipBooked or not TipStillOurs() then return end
    local wait = 0.2 - (T.Now() - lastTip)
    if wait <= 0 or not (C_Timer and C_Timer.After) then return RetipNow() end
    tipBooked = true
    C_Timer.After(wait, RetipNow)
end

local function Listener()
    local listener = Look.Build("Frame", T.window, nil, { size = { 1, 1 } })
    local refreshing = {}
    for _, event in ipairs(REFRESH_EVENTS) do
        refreshing[event] = true
        Look.Listen(listener, event)
    end
    Look.Listen(listener, "TOOLTIP_DATA_UPDATE")
    listener:SetScript("OnEvent", function(_, event)
        if refreshing[event] then Book() else Retip() end
    end)
end

-- Everything that comes with the window, once, as it is built.
function T.Wire(window)
    window:SetScript("OnShow", Opened)
    window:SetScript("OnHide", Closed)
    window:SetScript("OnUpdate", FollowInspect)
    Look.WindowTraits(window, { keep = StandsBeside })
    if type(ns.RegisterClassicWindow) == "function" then ns.RegisterClassicWindow(window, true) end
    if type(ns.CloseOnEscape) == "function" then ns.CloseOnEscape(window) end
    -- The talent window's own hook on the menu (kept beside any other area's).
    if GameMenuFrame then
        Look.HookScript(GameMenuFrame, "OnShow", function()
            if not Look.InFight() and window:IsShown() then window:Hide() end
        end, "talents")
    end
    Listener()
end

---------------------------------------------------------------------------
-- The game's buttons: their own click kept aside while EraUI's is on
---------------------------------------------------------------------------

local ownClicks = Look.Weak() -- the game's button: its own click (false: it had none)

local function TakeClick(button, click)
    if not button or type(button.GetScript) ~= "function" then return end
    local current = button:GetScript("OnClick")
    if current == click then return end
    if ownClicks[button] == nil then ownClicks[button] = current or false end
    button:SetScript("OnClick", click)
end

-- The game's own click back (only over EraUI's). forget: drop the memory
-- too (a button that may be made again).
local function GiveClick(button, click, forget)
    local own = button and ownClicks[button]
    if own == nil then return end
    if button:GetScript("OnClick") == click then button:SetScript("OnClick", own or nil) end
    if forget then ownClicks[button] = nil end
end

local function QuickBinding()
    local check = KeybindFrames_InQuickKeybindMode
    if type(check) ~= "function" then return false end
    local fine, binding = pcall(check)
    return fine and not Look.Secret(binding) and binding == true
end

-- A micro button's click: nothing while you bind keys with the game's quick
-- keybind mode; in a fight the window opens on the next frame.
local function MicroClick()
    if QuickBinding() then return end
    if Look.InFight() then NextFrame(T.Toggle) else T.Toggle() end
end

local function InspectButton()
    local paper = InspectPaperDollFrame
    return paper and paper.InspectTalents or nil
end

local function InspectClick()
    local traits = C_Traits
    local valid = type(traits) == "table" and traits.HasValidInspectData
    if type(valid) == "function" then
        local fine, ready = pcall(valid)
        if fine and not Look.Secret(ready) and ready == false then return end
    end
    T.OpenOn(InspectedUnit() or "target")
end

-- The named click target: one key press sends a down and an up click,
-- which toggle the window once.
local lastPress = -1
local function KeyClick()
    local now = T.Now()
    if now - lastPress < 0.2 then return end
    lastPress = now
    if T.active then T.Toggle() end
end

local function MakeClickTarget()
    if T.clickTarget then return end
    local target = Look.Build("Button", UIParent, nil, { name = "EraUIClassicTalentsBind", size = { 1, 1 }, hidden = true })
    Look.Pin(target, "TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    target:RegisterForClicks("AnyDown", "AnyUp")
    target:SetScript("OnClick", KeyClick)
    T.clickTarget = target
end

---------------------------------------------------------------------------
-- On (each pass, never in a fight) and off
---------------------------------------------------------------------------

local function TalentsOn()
    T.active = true
    MakeClickTarget()
    for _, name in ipairs(MICRO) do TakeClick(_G[name], MicroClick) end
    TakeClick(InspectButton(), InspectClick)
end

local function TalentsOff()
    T.active = false
    for _, name in ipairs(MICRO) do GiveClick(_G[name], MicroClick) end
    GiveClick(InspectButton(), InspectClick, true)
    if T.window then T.window:Hide() end
end

ns.RegisterModule("talents", { apply = TalentsOn, restore = TalentsOff })

-- The inspect window loads the first time it is wanted: its button is
-- taken then, while the window is on.
do
    local loads = CreateFrame("Frame")
    Look.Listen(loads, "ADDON_LOADED")
    loads:SetScript("OnEvent", function(_, _, addon)
        if addon == "Blizzard_InspectUI" and T.active then TakeClick(InspectButton(), InspectClick) end
    end)
end

-- Opens or closes the window (false while it is off).
function ns.ToggleTalents()
    if not T.active then return false end
    T.Toggle()
    return true
end
