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
    elseif msg == "help" then
        EraUI:Print("/era opens settings; /era welcome opens the welcome; /era setup starts guided setup; /era version shows the version; /era updates reopens the update notes; /era status or audit shows diagnostics.")
        EraUI:Print("/era reload reloads the UI; /era reset clears your EraUI settings (reload afterward).")
        return
    elseif msg == "version" then
        EraUI:Print("Version " .. EraUI.version)
        return
    elseif msg == "reload" then
        ReloadUI()
        return
    elseif msg == "reset" then
        if EraUI.Classic then EraUI.Classic.db = nil end
        EraUIClassicDB = nil; EraUIClassicCharDB = nil
        if C_CVar then C_CVar.SetCVar("EraUIClassicSettings", "") end
        if C_CVar then C_CVar.SetCVar("EraUICharSwing", "") end
        if C_CVar then C_CVar.SetCVar("EraUIOnboarding", "") end
        EraUIDB = nil
        EraUI:Print("Settings cleared. Use /reload to restore defaults.")
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
