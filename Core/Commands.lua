local _, EraUI = ...

local reportWindow

local function ShowReport(text)
    if not reportWindow then
        local frame = CreateFrame("Frame", "EraUIReportFrame", UIParent, "BackdropTemplate")
        frame:SetSize(590, 480)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        EraUI:AddClassicBackdrop(frame, 3)
        local background = frame:CreateTexture(nil, "BACKGROUND")
        background:SetPoint("TOPLEFT", 6, -6)
        background:SetPoint("BOTTOMRIGHT", -6, 6)
        background:SetColorTexture(0.035, 0.03, 0.025, 1)
        local title = EraUI:CreateLabel(frame, "EraUI status report", 20)
        title:SetPoint("TOP", 0, -20)
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -3, -3)
        close:SetScript("OnClick", function() frame:Hide() end)

        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 24, -62)
        scroll:SetPoint("BOTTOMRIGHT", -44, 76)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject("GameFontHighlight")
        edit:SetWidth(522)
        edit:SetHeight(320)
        scroll:SetScrollChild(edit)
        local measure = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        measure:SetWidth(522)
        measure:SetWordWrap(true)
        measure:Hide()
        edit:SetScript("OnTextChanged", function(self)
            measure:SetText(self:GetText())
            self:SetHeight(math.max(320, measure:GetStringHeight() + 24))
            scroll:UpdateScrollChildRect()
        end)
        edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        frame:SetScript("OnHide", function() edit:ClearFocus() end)
        if UISpecialFrames then table.insert(UISpecialFrames, "EraUIReportFrame") end

        local hint = EraUI:CreateLabel(frame, "Select the report, then press Ctrl+C to copy it.", 11)
        hint:SetPoint("BOTTOM", 0, 53)
        local selectButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        selectButton:SetSize(150, 26)
        selectButton:SetPoint("BOTTOM", 0, 20)
        selectButton:SetText("Select report")
        selectButton:SetScript("OnClick", function()
            edit:SetFocus()
            edit:HighlightText()
        end)
        frame.edit, frame.scroll = edit, scroll
        reportWindow = frame
    end
    if EraUI.settingsFrame then EraUI.settingsFrame:Hide() end
    reportWindow:Show()
    reportWindow:Raise()
    reportWindow.edit:SetText(text)
    reportWindow.edit:SetCursorPosition(0)
    reportWindow.edit:ClearFocus()
    reportWindow.scroll:SetVerticalScroll(0)
end

local function PrintStatus()
    local lines = {}
    local function AddLine(text) lines[#lines + 1] = text end
    AddLine("Version " .. EraUI.version .. " - status report")
    if GetBuildInfo then
        local version, build, _, interface = GetBuildInfo()
        AddLine("Client " .. tostring(version) .. ", build " .. tostring(build)
            .. ", interface " .. tostring(interface))
    end
    local names = {}
    for name in pairs(EraUI.modules) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local result = EraUI.moduleResults[name]
        if not result then
            AddLine(name .. ": initialization not run")
        elseif result.ok then
            AddLine(name .. ": initialized without error")
        else
            AddLine(name .. ": initialization failed - " .. result.error)
        end
    end
    local options = {
        {"actionBars", "Action bars"}, {"gryphons", "Gryphons"},
        {"minimap", "Minimap"}, {"unitFrames", "Unit frames"},
        {"professions", "Professions"}, {"spellbook", "Spellbook"}, {"questDialogs", "Quest dialogue"}, {"questTracker", "Quest tracker"}, {"cleanMinimap", "Clean minimap"},
        {"castBars", "Cast bars"}, {"characterPanel", "Character tabs"}, {"vendorPrice", "Vendor price"},
        {"questLevels", "Quest levels"}, {"bagSpace", "Bag counter"},
        {"classColors", "Chat class colours"}, {"hideStatusMessages", "Quiet mode"},
    }
    local enabled, disabled = {}, {}
    for _, option in ipairs(options) do
        local list = EraUI:GetSetting(option[1]) and enabled or disabled
        list[#list + 1] = option[2]
    end
    local update = EraUI.modules.UpdateCheck
    if update and update.Status then AddLine(update:Status()) end
    AddLine("")
    AddLine("Enabled: " .. (#enabled > 0 and table.concat(enabled, ", ") or "none"))
    AddLine("Disabled: " .. (#disabled > 0 and table.concat(disabled, ", ") or "none"))
    AddLine("")
    AddLine("Options show saved choices. Initialization results do not verify visuals or later events.")
    ShowReport(table.concat(lines, "\n"))
end

-- Fixed, shallow inventory. Addon names are reference-derived candidates;
-- absent targets are observations, never automatic skin failures.
local auditTargets = {
    {"MainActionBar", "ActionBars"},
    {"EraUIClassicActionDock", "ActionBars"}, {"MicroMenu", "ActionBars", "Blizzard_MicroMenu"},
    {"EraUIMicroOverflowButton", "ActionBars"}, {"BagsBar", "ActionBars", "Blizzard_MainMenuBarBagButtons"},
    {"MainStatusTrackingBarContainer", "ActionBars", "Blizzard_StatusTrackingBar"}, {"Minimap", "Minimap", "Blizzard_Minimap"},
    {"EraUIClassicMinimapArt.border", "Minimap"},
    {"MinimapCluster.ZoneTextButton", "Minimap", "Blizzard_Minimap"},
    {"Minimap.ZoomIn", "Minimap", "Blizzard_Minimap"}, {"Minimap.ZoomOut", "Minimap", "Blizzard_Minimap"},
    {"MinimapCluster.Tracking", "Minimap", "Blizzard_Minimap"},
    {"MinimapCluster.IndicatorFrame.MailFrame", "Minimap", "Blizzard_Minimap"},
    {"MinimapCluster.IndicatorFrame.CraftingOrderFrame", "Minimap", "Blizzard_Minimap"},
    {"MinimapCluster.InstanceDifficulty", "Minimap", "Blizzard_Minimap"},
    {"MinimapCluster.DielFrame", "Minimap", "Blizzard_Minimap"},
    {"GameTimeFrame", "Minimap", "Blizzard_Minimap"},
    {"AddonCompartmentFrame", "Minimap", "Blizzard_Minimap"},
    {"TimeManagerClockButton", "Minimap", "Blizzard_TimeManager"},
    {"QueueStatusButton", "Minimap", "Blizzard_QueueStatusFrame"},
    {"PlayerFrame", "UnitFrames"}, {"CharacterFrame", "CharacterPanel"},
    {"PaperDollFrame", "CharacterPanel"}, {"CharacterModelScene", "CharacterPanel"},
    {"SkillsFrame", "CharacterPanel"}, {"ReputationFrame", "CharacterPanel"},
    {"CharacterStatsPanePetScrollBox", "CharacterPanel"},
    {"QuestFrame", "QuestDialog"}, {"LootFrame", "LootWindow"},
    {"GameMenuFrame", "ClassicPanels"}, {"StaticPopup1", "ClassicPanels"},
    {"FriendsFrame", "ClassicPanels"}, {"WhoFrame", "ClassicPanels"},
    {"PlayerTalentFrame", "ClassicPanels"}, {"PlayerSpellsFrame", "ClassicPanels"},
    {"ObjectiveTrackerFrame", "QuestTracker"},
    {"ProfessionsFrame", "ClassicWindows", "Blizzard_Professions"},
    {"ProfessionsBookFrame", "ClassicWindows", "Blizzard_ProfessionsBook"},
    {"ClassTrainerFrame", "Training", "Blizzard_TrainerUI"},
    {"AuctionHouseFrame", nil, "Blizzard_AuctionHouseUI"},
    {"CommunitiesFrame", nil, "Blizzard_Communities"},
    {"GuildControlUI", nil, "Blizzard_GuildControlUI"},
    {"GuildBankFrame", nil, "Blizzard_GuildBankUI"},
    {"CollectionsJournal", nil, "Blizzard_Collections"},
    {"MacroFrame", nil, "Blizzard_MacroUI"},
    {"CalendarFrame", nil, "Blizzard_Calendar"},
    {"InspectFrame", nil, "Blizzard_InspectUI"},
    {"AchievementFrame", nil, "Blizzard_AchievementUI"},
}

function EraUI:BuildAuditReport()
    local out={"EraUI "..self.version.." — audit (read only)",
        "EraUI skinning and QoL; recorded calls do not prove visual/taint correctness.","", "SKIN MODULES"}
    local ns=self.Classic
    for _,entry in ipairs(ns and ns.modules or {}) do
        local r=ns.applyResults and ns.applyResults[entry.key]
        local state=ns.db and ns.db[entry.key]==false and "DISABLED" or
            (r and (r.ok and "SKIN APPLIED" or "ERROR: "..tostring(r.error)) or "SKIN REGISTERED")
        out[#out+1]=entry.key..": "..state
    end
    out[#out+1]="";out[#out+1]="ERAUI SETTINGS / QOL"
    for name,result in pairs(self.moduleResults) do
        out[#out+1]=name..": "..(result.ok and "initialized" or "ERROR: "..tostring(result.error))
    end
    out[#out+1]="";out[#out+1]="VISUAL SETTINGS WAITING FOR RELOAD"
    local pending=false
    for key in pairs(self.reloadSettings) do
        if self:GetSavedSetting(key)~=self:GetSetting(key) then out[#out+1]=key;pending=true end
    end
    if not pending then out[#out+1]="None" end
    out[#out+1]="";out[#out+1]="RECORDED BLOCKED ACTIONS"
    for _,entry in ipairs(ns and ns.blocked or {}) do out[#out+1]=entry.event..": "..entry.func end
    if not ns or not ns.blocked or #ns.blocked==0 then out[#out+1]="None recorded" end
    out[#out+1]="";out[#out+1]="KNOWN TARGETS"
    for _,name in ipairs({"CharacterFrame","SkillsFrame","ReputationFrame","PlayerCastingBarFrame","TargetFrame","Minimap","BankFrame","MerchantFrame","MailFrame","ProfessionsFrame"}) do
        out[#out+1]=name..": "..(_G[name] and "FOUND" or "NOT FOUND (may be unopened/lazy-loaded)")
    end
    return table.concat(out,"\n")
end

-- /era reset, the "Reset toggles" button on the game's Options > AddOns >
-- EraUI page and /eraui-classic reset each ask first, in one small window of
-- EraUI's own with the Presets window's look (the game's shared popups are
-- left alone). It shows one question at a time. Only its Reset button resets;
-- Cancel, the X and Escape just close it, and it takes no keys, so Enter
-- never resets.
local COMBAT_NOTE = "|cffff5555Finish combat first, then click Reset again.|r"
local resetPrompt, asking

local function PromptColour()
    local _, class = UnitClass("player")
    local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if c then return c.r, c.g, c.b end
    return .7, .7, .7
end

local function PaintPromptButton(button, strong)
    local r, g, b = PromptColour()
    local k = strong and .3 or .2
    button:SetBackdropColor(r * k, g * k, b * k, 1)
    button:SetBackdropBorderColor(r, g, b, 1)
end

local function PromptButton(parent, label, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(150, 32)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetPoint("CENTER")
    button.label:SetText(label)
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(self) PaintPromptButton(self, true) end)
    button:SetScript("OnLeave", function(self) PaintPromptButton(self, false) end)
    return button
end

-- Exactly what /era reset did before it asked. The reload goes straight from
-- this click with the prompt still up: the client refuses a reload once the
-- clicked window is hidden. A fight or a failed request reloads nothing, and
-- Persistence says why in chat.
local function ResetEverything()
    if not EraUI.Persistence:Reset() then
        if InCombatLockdown and InCombatLockdown() then
            resetPrompt.note:SetText(COMBAT_NOTE)
        else
            resetPrompt:Hide()
        end
        return
    end
    EraUI:Print("Resetting settings to defaults. Reloading UI...")
    ReloadUI()
end

-- /era reset's question. Persistence refuses a fight on its own.
local RESET_EVERYTHING = {
    title = "Reset EraUI",
    question = "Reset all EraUI settings to defaults? This reloads your UI.",
    combat = "Finish combat before resetting EraUI settings.",
    run = ResetEverything,
    refusesCombat = true,
}

-- The Reset button. The other resets refuse a fight the way /era reset does
-- (a chat line and a red note, the prompt stays up to try again); otherwise
-- the prompt closes and their reset runs just as it did before it asked.
local function ConfirmReset()
    local ask = asking
    if ask.refusesCombat then return ask.run() end
    if InCombatLockdown and InCombatLockdown() then
        EraUI:Print(ask.combat)
        resetPrompt.note:SetText(COMBAT_NOTE)
        return
    end
    resetPrompt:Hide()
    ask.run()
end

local function BuildResetPrompt()
    local frame = CreateFrame("Frame", "EraUIResetPrompt", UIParent, "BackdropTemplate")
    frame:SetSize(440, 170)
    frame:SetPoint("CENTER", 0, 80)
    -- The Presets window's layer, above /era and its controls.
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(.026, .029, .037, 1)
    frame:SetBackdropBorderColor(.19, .20, .24, 1)
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "EraUIResetPrompt") end

    frame.stripe = frame:CreateTexture(nil, "ARTWORK")
    frame.stripe:SetPoint("TOPLEFT", 1, -1)
    frame.stripe:SetPoint("TOPRIGHT", -1, -1)
    frame.stripe:SetHeight(3)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 24, -24)
    frame.message = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.message:SetPoint("TOPLEFT", 24, -60)
    frame.message:SetWidth(392)
    frame.message:SetJustifyH("LEFT")
    frame.note = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.note:SetPoint("TOPLEFT", frame.message, "BOTTOMLEFT", 0, -8)
    frame.note:SetWidth(392)
    frame.note:SetJustifyH("LEFT")

    frame.cancel = PromptButton(frame, "Cancel", function() frame:Hide() end)
    frame.cancel:SetPoint("BOTTOMLEFT", 24, 22)
    frame.reset = PromptButton(frame, "Reset", ConfirmReset)
    frame.reset:SetPoint("BOTTOMRIGHT", -24, 22)
    frame.reset.label:SetTextColor(1, .45, .4)
    if EraUI.CreateCloseX then frame.close = EraUI:CreateCloseX(frame, function() frame:Hide() end) end
    resetPrompt = frame
end

-- Opens the prompt for one reset: ask = { title, question, combat = the chat
-- line for a fight, run = the reset }. In a fight it only prints that line.
function EraUI:AskReset(ask)
    if InCombatLockdown and InCombatLockdown() then
        self:Print(ask.combat)
        return false
    end
    if not resetPrompt then BuildResetPrompt() end
    asking = ask
    resetPrompt.title:SetText(ask.title)
    resetPrompt.message:SetText(ask.question)
    local r, g, b = PromptColour()
    resetPrompt.stripe:SetColorTexture(r, g, b, 1)
    PaintPromptButton(resetPrompt.cancel, false)
    PaintPromptButton(resetPrompt.reset, false)
    resetPrompt.note:SetText("")
    resetPrompt:Show()
    resetPrompt:Raise()
    return true
end

function EraUI:AskResetSettings()
    return self:AskReset(RESET_EVERYTHING)
end

-- Closes the prompt, resetting nothing, if it is asking that question.
function EraUI:CloseResetPrompt(ask)
    if resetPrompt and asking == ask then resetPrompt:Hide() end
end

SLASH_ERAUI1 = "/eraui"
SLASH_ERAUI2 = "/era"
SlashCmdList.ERAUI = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "combo status" then
        if EraUI.Classic and EraUI.Classic.ComboPointStatus then EraUI.Classic.ComboPointStatus() end;return
    elseif msg == "classic" or msg == "visuals" then
        if EraUI.Classic then EraUI.Classic.OpenOptions() else EraUI:Print("Classic interface did not load. Check the addon load errors.") end; return
    elseif msg == "welcome" then
        if EraUI.Classic then EraUI.Classic.ShowWelcome() end; return
    elseif msg == "setup" then
        if EraUI.Classic then
            EraUI.Classic.setupRequested = true
            if EraUI.settingsFrame then EraUI.settingsFrame:Hide() end
            EraUI.Classic.ShowWelcome()
        end
        return
    elseif msg == "audit" then
        ShowReport(EraUI:BuildAuditReport())
        return
    elseif msg == "status" then
        PrintStatus()
        return
    elseif msg == "updates" or msg == "update" or msg == "updates again" then
        if msg == "updates again" and EraUI.Classic and EraUI.Classic.db then
            EraUI.Classic.db.updateNotesSeen = "0"
            EraUI.Classic.MirrorSave()
            EraUI:Print("Update notes will reappear after you /reload.")
            return
        end
        if EraUI.ShowUpdateNotes then EraUI.ShowUpdateNotes() else EraUI:Print("Update notes are not available.") end
        return
    elseif msg == "mapdebug" then
        if EraUI.modules.MovableMap and EraUI.modules.MovableMap.DumpText then
            ShowReport(EraUI.modules.MovableMap:DumpText())
        else
            EraUI:Print("Map module is not available.")
        end
        return
    elseif msg == "reminders" then
        if EraUI.modules.ClassReminders and EraUI.modules.ClassReminders.Open then
            EraUI.modules.ClassReminders:Open()
        else
            EraUI:Print("Class reminders are not available.")
        end
        return
    elseif msg == "discord" then
        if EraUI.ShowDiscord then EraUI.ShowDiscord() else EraUI:Print("Discord: https://discord.gg/FVfcDWJncr") end
        return
    elseif msg == "afk" then
        local m = EraUI.modules.AFKScreen; if m then m:Preview() end
        return
    elseif msg == "help" then
        local afk = EraUI.modules.AFKScreen
        EraUI:Print("/era opens settings; /era welcome opens the welcome; /era setup starts guided setup; /era version shows the version; /era updates reopens the update notes; /era reminders opens class reminders; /era discord gives the Discord invite; /era status or audit shows diagnostics"
            .. ((afk and not afk.comingSoon) and "; /era afk previews the AFK screen." or "."))
        EraUI:Print("/era reload reloads the UI; /era reset asks first, then restores default settings and reloads (outside combat).")
        return
    elseif msg == "version" then
        EraUI:Print("Version " .. EraUI.version)
        return
    elseif msg == "reload" then
        ReloadUI()
        return
    elseif msg == "reset" then
        EraUI:AskResetSettings()
        return
    end

    if msg ~= "" then
        EraUI:Print("Unknown command. Type /era help for available commands.")
        return
    end
    if EraUI.Classic then
        EraUI.Classic.OpenOptions()
    else
        EraUI:Print("Classic interface did not load. Check the addon load errors.")
    end
end
