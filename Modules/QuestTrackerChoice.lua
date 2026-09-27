-- Asks which quest tracker to use when EraUI's Classic tracker and Questie's
-- own tracker are both on. They cannot show together: while Questie's tracker
-- is enabled, QuestieCompatibility hides Blizzard's Classic-styled tracker, so
-- a collapsed Questie tracker looks like no quests at all.
-- Asked in the /era setup walkthrough when Questie is installed, once at
-- login until answered, and whenever Quest Tracker is turned on in /era while
-- Questie's tracker is on.
local _, E = ...
local M = {}
E:RegisterModule("QuestTrackerChoice", M)

local window, pending, askedThisSession, choosing = nil, false, false, false
local loadedTrackerOn -- Questie's tracker state this session actually loaded with.

local function Questie()
    local questie = _G.Questie
    local db = questie and questie.db
    if type(db) ~= "table" or type(db.profile) ~= "table" then return end
    if type(questie.IsEnabled) == "function" and not questie:IsEnabled() then return end
    return db
end

local function Conflict()
    local db = Questie()
    return E:GetSetting("enabled") and db and db.profile.trackerEnabled == true
end

local function Import(name)
    if not QuestieLoader or type(QuestieLoader.ImportModule) ~= "function" then return end
    local ok, module = pcall(QuestieLoader.ImportModule, QuestieLoader, name)
    if ok and type(module) == "table" then return module end
end

local function ClassColour()
    local _, class = UnitClass("player")
    local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if c then return c.r, c.g, c.b end
    return .7, .7, .7
end

function M:QuestieInstalled()
    return Questie() ~= nil
end

function M:CurrentChoice()
    return E:GetSavedSetting("questTrackerChoice") or ""
end

-- True when Questie's tracker preference differs from what this session
-- loaded with, so only a reload can apply it.
function M:NeedsReload()
    local db = Questie()
    return db ~= nil and loadedTrackerOn ~= nil and (db.profile.trackerEnabled == true) ~= loadedTrackerOn
end

-- Save the choice and Questie's matching tracker preference. Never reloads:
-- the prompt and the setup walkthrough each reload from their own click.
function M:SetChoice(choice)
    local db = Questie()
    if not db or (choice ~= "classic" and choice ~= "questie") then return end
    choosing = true
    E:SetSetting("questTrackerChoice", choice)
    -- EraUI's Quest Tracker option follows the choice, so /era matches what is
    -- on screen: on means the Classic tracker, off means Questie's.
    E:SetSetting("questTracker", choice == "classic")
    local settings = E.settingsFrame
    local card = settings and settings.checks and settings.checks.questTracker
    if card then card:SetChecked(choice == "classic") end
    if choice == "classic" then
        -- Questie's own Disable() also wipes its tracked-quest list. Only the
        -- on/off preference changes here.
        db.profile.trackerEnabled = false
    else
        db.profile.trackerEnabled = true
        local tracker = Import("QuestieTracker")
        -- Unfold it now when it is running. Questie ignores header clicks in
        -- combat, so the saved state also covers that case from the next load.
        if loadedTrackerOn and tracker and type(tracker.Expand) == "function" and not InCombatLockdown() then
            pcall(tracker.Expand, tracker)
        end
        if type(db.char) == "table" then db.char.isTrackerExpanded = true end
    end
    choosing = false
end

function M:UseClassic()
    -- The client only honours a reload from a live click outside combat.
    if InCombatLockdown() then
        if window then window.footer:SetText("|cffff5555Finish combat first, then choose again.|r") end
        return
    end
    self:SetChoice("classic")
    -- Reload straight from the click: hiding this window first makes the
    -- client block the request (the settings Reload UI button works the same).
    ReloadUI()
end

function M:UseQuestie()
    if not Questie() then return end
    -- Questie's tracker only starts on a load, so switching it on reloads,
    -- straight from the click like the Classic choice; never in combat.
    if loadedTrackerOn == false and InCombatLockdown() then
        if window then window.footer:SetText("|cffff5555Finish combat first, then choose again.|r") end
        return
    end
    self:SetChoice("questie")
    if self:NeedsReload() then
        ReloadUI()
        return
    end
    if window then window:Hide() end
end

local function Button(parent, label, caption, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(190, 34)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER")
    text:SetText(label)
    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOP", button, "BOTTOM", 0, -6)
    note:SetWidth(190)
    note:SetJustifyH("CENTER")
    note:SetTextColor(.72, .74, .8)
    note:SetText(caption)
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(self)
        local r, g, b = ClassColour()
        self:SetBackdropColor(r * .3, g * .3, b * .3, 1)
    end)
    button:SetScript("OnLeave", function(self)
        local r, g, b = ClassColour()
        self:SetBackdropColor(r * .2, g * .2, b * .2, 1)
    end)
    button.note = note
    return button
end

local function Build()
    window = CreateFrame("Frame", "EraUIQuestTrackerChoice", UIParent, "BackdropTemplate")
    window:SetSize(460, 262)
    window:SetPoint("CENTER", 0, 80)
    -- The same foreground layer as the Changelog window, so /era and its
    -- DIALOG-level controls can never draw through or cover this prompt.
    window:SetFrameStrata("FULLSCREEN_DIALOG")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    window:SetBackdropColor(.026, .029, .037, 1)
    window:SetBackdropBorderColor(.19, .20, .24, 1)
    window:Hide()
    table.insert(UISpecialFrames, "EraUIQuestTrackerChoice")

    window.stripe = window:CreateTexture(nil, "ARTWORK")
    window.stripe:SetPoint("TOPLEFT", 1, -1)
    window.stripe:SetPoint("TOPRIGHT", -1, -1)
    window.stripe:SetHeight(3)

    window.title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    window.title:SetPoint("TOPLEFT", 24, -24)
    window.title:SetText("Choose your quest tracker")

    local body = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", 24, -56)
    body:SetWidth(412)
    body:SetJustifyH("LEFT")
    body:SetText("Questie's quest tracker is on, so EraUI hides Blizzard's Classic-look tracker to avoid showing two. Pick the one you'd like to use:")

    -- Questie's own tracker does not list quests on WoW Forever yet, and still
    -- hides Blizzard's; steer players to the tracker that shows their quests.
    window.classic = Button(window, "Classic Tracker", "|cff66dd66Recommended.|r EraUI's Classic look. Turns Questie's tracker off and reloads.", function() M:UseClassic() end)
    window.classic:SetPoint("TOPLEFT", 24, -116)
    window.questie = Button(window, "Questie Tracker", "Questie's own tracker. |cffffd24aDoes not list quests on WoW Forever yet.|r", function() M:UseQuestie() end)
    window.questie:SetPoint("TOPRIGHT", -24, -116)

    window.footer = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.footer:SetPoint("BOTTOM", 0, 18)
    window.footer:SetWidth(412)

    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() window:Hide() end)
end

function M:Show()
    if not window then Build() end
    local r, g, b = ClassColour()
    window.stripe:SetColorTexture(r, g, b, 1)
    window.footer:SetText("Ask again by turning Quest Tracker off and on in /era, under Quests.")
    for _, button in ipairs({ window.classic, window.questie }) do
        button:SetBackdropColor(r * .2, g * .2, b * .2, 1)
        button:SetBackdropBorderColor(r, g, b, 1)
    end
    window:Show()
    window:Raise()
end

local function InSetup()
    local settings = E.settingsFrame
    return settings and settings.setupMode and settings:IsShown()
end

function M:Check(fromToggle)
    -- The setup walkthrough asks this itself.
    if InSetup() then return end
    -- Turning Quest Tracker on in /era always asks while Questie is installed;
    -- login only asks while both trackers are actually on.
    if fromToggle then
        if not (E:GetSetting("enabled") and Questie()) then return end
    elseif not Conflict() then
        return
    end
    if not fromToggle then
        -- Login: only while the Classic tracker is actually loaded and no
        -- choice has been made. A later Questie re-enable is respected.
        -- Players who have not finished setup are asked there instead.
        if askedThisSession or not E:GetSetting("questTracker") then return end
        if self:CurrentChoice() ~= "" then return end
        local classic = E.Classic and E.Classic.db
        if classic and not classic.erauiSetupComplete then return end
        askedThisSession = true
    end
    if InCombatLockdown() then pending = true; return end
    self:Show()
end

local function RememberLoadedState()
    if loadedTrackerOn ~= nil then return end
    local db = Questie()
    if db then loadedTrackerOn = db.profile.trackerEnabled == true end
end

function M:Initialize()
    RememberLoadedState()
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if pending then pending = false; M:Show() end
            return
        end
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        RememberLoadedState()
        -- Give Questie a moment to finish loading its profile and tracker.
        C_Timer.After(2, function() M:Check(false) end)
    end)
    hooksecurefunc(E, "SetSetting", function(_, key, value)
        if key == "questTracker" and value == true and not choosing then M:Check(true) end
    end)
end
