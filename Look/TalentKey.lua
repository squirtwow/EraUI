-- The classic talents key offer (Squirt's go, 2026-10-24): a small window of
-- EraUI's own asks once whether N should open the classic talent window, so
-- nobody has to find Key Bindings > AddOns > Classic Talents first.
--
-- When: once a session, at the first of two moments that finds all of the
-- below true: a few seconds after entering the world (login or /reload;
-- while EraUI's welcome or What's New is up it waits for that to close), or
-- the classic talent window opening (Look/TalentModule.lua calls
-- T.OfferKey). Only while:
--   * the classic talent window is on (T.active, the Talents setting);
--   * the offer was never answered "never" or "used" (EraUIDB's
--     talentKeyPrompt, account-wide, backed up by Core/Persistence.lua);
--   * no fight and no addon restriction;
--   * N opens the game's own talents, or nothing. It is read through a
--     protected call; an error or a hidden answer is unknown, and unknown
--     never asks. A key the player set to something else is never offered.
--
-- Use N is the one place EraUI changes a key binding. On Forever a binding
-- changed from addon code set off the hidden-health error flood, so this one
-- happens only from that button's own click, never in a fight or under a
-- restriction, kept the way the game's own Key Bindings panel keeps a key
-- (the key set, then the current binding set saved), and the game reloads at
-- once: nothing the change could upset lives on in that session, and after
-- the reload the game loads the key itself, like one set by hand.
-- Not now (and Escape) closes it, to be asked again next session; Don't ask
-- again keeps "never". /era talentkey (Core/Commands.lua) offers it again.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local T = Look.Talent

-- The talent window's click target (Bindings.xml's Classic Talents entry)
-- and the game's own talents key.
local OURS, GAME_TALENTS = "CLICK EraUIClassicTalentsBind:LeftButton", "TOGGLETALENTS"
local WAIT = 5 -- seconds after entering the world
-- The addon restrictions that hold the key back: combat, an encounter, a
-- timed dungeon, a PvP match, a restricted map (Enum.AddOnRestrictionType).
local RESTRICTIONS = { 0, 1, 2, 3, 4 }
-- EraUI's own big windows the offer waits behind: the welcome, What's New.
local BUSY = { "EraUIWelcome", "EraUIUpdates" }

local WORDS = {
    title = "Classic Talents",
    question = "Use N to open the classic talents?",
    quiet = "N will no longer open the game's own talent window. (experimental)",
    fight = "Use N works once you're out of combat.",
    blocked = "Use N can't change keys here right now. Try again later.",
    failed = "The game didn't take N. Nothing was changed.",
}

local parts = {}         -- the window and its pieces, made the first time it shows
local asked = false      -- this session: the offer was shown (it shows once)
local starting = false   -- a fight starting: the lockdown follows the event

local function Say(text)
    if type(ns.Print) == "function" then ns.Print(text) end
end

---------------------------------------------------------------------------
-- What the offer reads
---------------------------------------------------------------------------

local function Answer()
    local saved = EraUIDB
    return type(saved) == "table" and saved.talentKeyPrompt or nil
end

-- The answer kept (nil forgets it), and the settings backup told.
local function Remember(answer)
    if type(EraUIDB) ~= "table" then return end
    EraUIDB.talentKeyPrompt = answer
    if type(EraUI.SaveSettings) == "function" then Look.Try(EraUI.SaveSettings, EraUI) end
end

-- Any of those restrictions in force. A hidden answer counts as one; a kind
-- this client doesn't know doesn't.
local function Restricted()
    local api = C_RestrictedActions
    local active = type(api) == "table" and api.IsAddOnRestrictionActive or nil
    if type(active) ~= "function" then return false end
    for _, kind in ipairs(RESTRICTIONS) do
        local fine, on = pcall(active, kind)
        if fine and (Look.Secret(on) or on == true) then return true end
    end
    return false
end

-- What N does now: "ours", "offer" (the game's own talents, or nothing),
-- "other", or nil when it can't be read.
local function KeyNow()
    if type(GetBindingAction) ~= "function" then return nil end
    local fine, action = pcall(GetBindingAction, "N")
    if not fine or Look.Secret(action) or type(action) ~= "string" then return nil end
    if action == OURS then return "ours" end
    if action == "" or action == GAME_TALENTS then return "offer" end
    return "other"
end

local function MayAsk()
    local answer = Answer()
    return T.active == true and answer ~= "never" and answer ~= "used" and not Look.InFight() and not Restricted()
        and KeyNow() == "offer"
end

local function Fighting()
    return starting or Look.InFight()
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

-- Use N enabled only when it may work; the note says why not, or that the
-- game refused the key.
local function Refresh()
    if not parts.window then return end
    local note = (Fighting() and WORDS.fight) or (Restricted() and WORDS.blocked) or nil
    parts.use:SetEnabled(note == nil)
    parts.note:SetText(note or (parts.failed and WORDS.failed) or "")
end

-- Use N's click, the one place EraUI changes a key binding: never in a fight
-- or under a restriction; a key the game refuses changes nothing. The window
-- stays up through the reload (the game refuses a reload once the clicked
-- window is hidden).
local function UseN()
    if InCombatLockdown() or Restricted() then return Refresh() end
    local took = SetBinding("N", "CLICK EraUIClassicTalentsBind:LeftButton")
    if Look.Secret(took) or not took then
        parts.failed = true
        return Refresh()
    end
    SaveBindings(GetCurrentBindingSet())
    Remember("used")
    ReloadUI()
end

local function NotNow()
    parts.window:Hide()
end

local function Never()
    Remember("never")
    parts.window:Hide()
end

-- A centred line of words, 336 wide, its top under `over`.
local function Line(window, purpose, font, over, gap)
    local line = Look.OwnLabel(window, purpose, font, "OVERLAY")
    line:SetWidth(336)
    line:SetJustifyH("CENTER")
    line:ClearAllPoints()
    line:SetPoint("TOP", over, over == window and "TOP" or "BOTTOM", 0, gap)
    return line
end

-- Fights and restrictions coming and going while the window is up.
local function Watch(window)
    for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED" }) do
        Look.Listen(window, event)
    end
    window:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then starting = true elseif event == "PLAYER_REGEN_ENABLED" then starting = false end
        if not window:IsShown() then return end
        -- A restriction reads as on only once its event is over.
        if event == "ADDON_RESTRICTION_STATE_CHANGED" and C_Timer and C_Timer.After then
            C_Timer.After(0, Refresh)
            return
        end
        Refresh()
    end)
end

-- 380 x 150 at the top of the screen, in the old dialog box with its header
-- plate (both handed to Dark Mode), the words, and three red buttons.
local function Build()
    if parts.window then return parts.window end
    local window = Look.Build("Frame", UIParent, "BackdropTemplate", { name = "EraUIClassicTalentKey", size = { 380, 150 },
        strata = "DIALOG", mouse = true, clamped = true, hidden = true })
    window:SetToplevel(true)
    Look.Pin(window, "TOP", UIParent, "TOP", 0, -150)
    window:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    window:SetBackdropColor(1, 1, 1, 1)
    window:SetBackdropBorderColor(1, 1, 1, 1)
    if ns.DarkBackdrop then ns.DarkBackdrop(window) end
    local shade = Look.OwnTexture(window, "shade", "BACKGROUND", -8)
    shade:SetColorTexture(0.03, 0.03, 0.03, 0.45)
    Look.Inside(shade, window, 11, 12, 12, 11)
    local plate = Look.HeaderPlate(window, "ARTWORK")
    local title = Look.OwnLabel(window, "title", "GameFontNormal", "OVERLAY")
    Look.Pin(title, "TOP", plate, "TOP", 0, -14)
    title:SetText(WORDS.title)
    parts.question = Line(window, "question", "GameFontHighlight", window, -30)
    parts.question:SetText(WORDS.question)
    parts.quiet = Line(window, "quiet", "GameFontHighlightSmall", parts.question, -8)
    parts.quiet:SetTextColor(0.7, 0.7, 0.7)
    parts.quiet:SetText(WORDS.quiet)
    parts.note = Line(window, "note", "GameFontHighlightSmall", parts.quiet, -6)
    parts.note:SetTextColor(1, 0.45, 0.4)
    local use = Look.PanelButton(window, "Use N", 100)
    Look.Pin(use, "BOTTOMLEFT", window, "BOTTOMLEFT", 22, 18)
    use:SetScript("OnClick", UseN)
    local later = Look.PanelButton(window, "Not now", 100)
    Look.Pin(later, "LEFT", use, "RIGHT", 6, 0)
    later:SetScript("OnClick", NotNow)
    local never = Look.PanelButton(window, "Don't ask again", 124)
    Look.Pin(never, "LEFT", later, "RIGHT", 6, 0)
    never:SetScript("OnClick", Never)
    parts.window, parts.title, parts.use, parts.later, parts.never = window, title, use, later, never
    -- Escape closes it as Not now, through the game's own list.
    if type(ns.CloseOnEscape) == "function" then ns.CloseOnEscape(window) end
    Watch(window)
    return window
end

local function Show()
    local window = Build()
    parts.failed = false
    Refresh()
    window:Show()
    window:Raise()
end

---------------------------------------------------------------------------
-- When it shows
---------------------------------------------------------------------------

-- The offer on its own: once a session, only when everything holds.
local function Offer()
    if asked or not MayAsk() then return end
    asked = true
    Show()
end

local function Busy()
    for _, name in ipairs(BUSY) do
        local window = _G[name]
        if type(window) == "table" and type(window.IsShown) == "function" and window:IsShown() then return true end
    end
    return false
end

-- A few seconds into the world, after EraUI's welcome and What's New.
local function AfterEntering()
    if asked then return end
    if Busy() then
        C_Timer.After(WAIT, AfterEntering)
        return
    end
    Offer()
end

-- /era talentkey: the offer whenever asked for, "never" forgotten. It still
-- needs the classic talents on and never takes a key set to something else;
-- in a fight it opens with Use N waiting.
local function Ask()
    if T.active ~= true then return Say("The classic talents are off. Turn on Talents in /era first.") end
    local now = KeyNow()
    if now == "ours" then return Say("N already opens the classic talents.") end
    if now == "other" then return Say("N is set to something else. Pick a key for Classic Talents in Key Bindings > AddOns.") end
    if now == nil then return Say("Your keys can't be read right now. Try again in a moment.") end
    if Answer() == "never" then Remember(nil) end
    asked = true
    Show()
end

-- The first entering of the world this session (login or /reload) only.
do
    local entering = CreateFrame("Frame")
    Look.Listen(entering, "PLAYER_ENTERING_WORLD")
    entering:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        if C_Timer and C_Timer.After then C_Timer.After(WAIT, AfterEntering) end
    end)
end

T.OfferKey, ns.AskTalentKey = Offer, Ask
