local _, EraUI = ...

local SettingsModule = {}
EraUI:RegisterModule("Settings", SettingsModule)

local reloadSettings = EraUI.reloadSettings
local classIconCoords = CLASS_ICON_TCOORDS or {
    WARRIOR={0,.25,0,.25}, MAGE={.25,.49609375,0,.25},
    ROGUE={.49609375,.7421875,0,.25}, DRUID={.7421875,.98828125,0,.25},
    HUNTER={0,.25,.25,.5}, SHAMAN={.25,.49609375,.25,.5},
    PRIEST={.49609375,.7421875,.25,.5}, WARLOCK={.7421875,.98828125,.25,.5},
    PALADIN={0,.25,.5,.75},
}

local settingHelp = {
    classColourBorders = "Use each player's class colour on normal player, target and focus borders in Dark Mode. Keeps dark interiors, health/power colours and special rare/elite artwork. Reload to apply. Off by default.",
    darkMode = "Dark decorative artwork. Character, party and raid frames keep their appearance. Reload to apply either style; QoL choices are unchanged.",
    trainer = "Classic trainer presentation and training controls, independent of profession window styling.",
    gameMenu = "Classic game-menu borders and red buttons.",
    popups = "Classic borders and buttons for native confirmation prompts.",
    coordinates = "Show EraUI coordinates beneath the minimap. Off by default to avoid duplicating another addon's coordinates. No coordinate text is shown when a map position is unavailable.",
    showAllSpellRanks = "Show every spell rank, using the game's spell-rank preference. This also updates EraUI's spellbook. Unavailable during combat.",
    hideEmptyActionSlots = "Hide unused slots during normal play; reveal them when arranging abilities.",
    autoSellJunk = "Sell grey-quality items on your next merchant visit.",
    autoRepair = "Repair using your own money on your next repair-vendor visit.",
    hideSecondaryNames = "Hide Forever secondary names using the supported game display settings. Turning this off shows secondary names again. New chat messages follow this setting; existing chat history is unchanged.",
    classicDialogs = "Classic grey borders and red buttons for confirmation prompts and the game menu. Includes resurrection prompts. Reload UI to apply or restore.",
    socialWindows = "Classic frame borders for Friends and Who, with existing social actions. Reload UI to apply or restore.",
    talentWindow = "Classic outer frame around supported talent trees. Keeps existing talent choices and controls. Reload UI to apply or restore.",
    friendlyNameplates = "Classic artwork and lettering on friendly nameplates. Keeps your existing nameplate visibility settings. Reload UI to apply.",
    enemyNameplates = "Classic artwork and lettering on enemy and neutral nameplates. Keeps native threat colours, casts, targeting and auras. Reload UI to apply.",
    lootWindow = "Classic loot frame and item artwork. Keeps native looting, tooltips and scrolling. Reload UI to apply or restore.",
    disableAggroHighlight = "Hide combat and threat glows on Classic player, target and focus frames, including the player status glow. Requires Classic unit frames. Reload UI to apply.",
    questTracker = "Classic text and collapse buttons without modern header plates. Keeps tracking, quest items and completion colours. Reload UI to apply or restore.",
    cleanMinimap = "Hide supported addon minimap buttons until you hover over the minimap. Clock, mail, tracking and zoom stay visible. Changes wait until combat ends.",
    questDialogs = "Classic quest acceptance and turn-in window. Keeps quest text, reward selection and the existing buttons. Reload UI to apply or restore.",
    professions = "Classic window artwork, profession progress bars and spell buttons. Keeps the client's recipes and profession controls. Reload UI to apply or restore.",
    spellbook = "Classic parchment, frame artwork and spell buttons. Keeps the client's spell categories, casting and drag-to-bar controls. Reload UI to apply or restore.",
    characterPanel = "Replaces the character window's side icons with labelled bottom tabs. The existing character panes retain their data and controls. Reload UI to apply or restore the original tabs.",
    actionBars = "Places the main buttons, menu, bags and XP bar on a Classic stone bar at the bottom of the screen. Keeps your spells and keybinds. Also skins extra action buttons. Reload UI to apply or restore the client layout.",
    gryphons = "Show the gryphons at the ends of the action bar. Applies immediately.",
    minimap = "Uses the original round Classic minimap border and zoom-button artwork, fitted to your map size. Reload UI to apply.",
    unitFrames = "Uses Classic artwork and bar proportions on player, target and focus frames. Keeps native unit data, buffs and controls. Reload UI to apply.",
    castBars = "Classic borders and fill on player, target, focus and styled nameplate cast bars. Keeps native timing, colours and interrupt indicators. Reload UI to apply.",
    vendorPrice = "Adds a vendor price to item tooltips only when one is missing. Applies the next time you hover an item.",
    questLevels = "Shows a level in brackets before quest titles in the right-hand quest tracker. Applies immediately.",
    bagSpace = "Shows empty bag slots on the backpack button at the end of the action bar. Filling an empty slot lowers the count; adding to an existing stack does not. Applies immediately.",
    classColors = "Colours player names in new chat messages by class. Untick to use the chat channel's colour. Earlier messages keep their original colours.",
    hideStatusMessages = "Hides EraUI's startup and setting-change notices immediately. Errors and replies to commands still appear. Messages already in chat stay visible.",
}

local function HideSettingTooltip(owner)
    if GameTooltip and GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
end

local function UpdateReloadHint(frame)
    if frame.setupMode then
        frame.reloadHint:SetText("Your choices are saved as you go.")
        if frame.reloadButton then frame.reloadButton:Hide() end
        return
    end
    local pending = false
    for key in pairs(reloadSettings) do
        local enabled = EraUI:GetSavedSetting(key) and true or false
        if enabled ~= frame.loadedSettings[key] then pending = true; break end
    end
    frame.reloadHint:SetText(pending
        and "Changes saved. Click Reload UI to apply them."
        or "No reload needed for your current settings.")
    if frame.reloadButton then frame.reloadButton:SetShown(pending) end
end

local function ClassColour()
    local _, class = UnitClass("player")
    local colour = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if colour then return colour.r, colour.g, colour.b end
    return 0.7, 0.7, 0.7
end

local function Text(parent, value, size, muted)
    local text = parent:CreateFontString(nil, "OVERLAY")
    local font, _, flags = GameFontHighlight:GetFont()
    text:SetFont(font, size, flags or "")
    text:SetTextColor(muted and 0.58 or 0.94, muted and 0.62 or 0.95, muted and 0.68 or 0.98)
    text:SetJustifyH("LEFT")
    text:SetText(value)
    return text
end

local function PaintToggle(check)
    local enabled = check:GetChecked()
    local r, g, b = ClassColour()
    check.track:SetBackdropColor(enabled and r * 0.65 or 0.06,
        enabled and g * 0.65 or 0.07, enabled and b * 0.65 or 0.09, 1)
    check.track:SetBackdropBorderColor(enabled and r or 0.24,
        enabled and g or 0.26, enabled and b or 0.3, 1)
    check.thumb:ClearAllPoints()
    check.thumb:SetPoint(enabled and "RIGHT" or "LEFT", check.track,
        enabled and "RIGHT" or "LEFT", enabled and -3 or 3, 0)
    check.thumb:SetColorTexture(enabled and 0.98 or 0.48, enabled and 0.98 or 0.5,
        enabled and 1 or 0.55, 1)
    check.state:SetText(enabled and "ON" or "OFF")
    check.state:SetTextColor(enabled and r or 0.58, enabled and g or 0.62, enabled and b or 0.68)
end

local featureIcons = {
    spellbookCombatDrag = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    autoQuests = "Interface\\Icons\\INV_Misc_ScrollInfo",
    autoSummon = "Interface\\Icons\\Spell_Shadow_Twilight",
    autoResurrect = "Interface\\Icons\\Spell_Holy_Resurrection",
    releasePvP = "Interface\\Icons\\Ability_DualWield",
    blockDuels = "Interface\\Icons\\Ability_DualWield",
    blockPartyInvites = "Interface\\Icons\\INV_Misc_GroupLooking",
    partyFromFriends = "Interface\\Icons\\INV_Misc_GroupLooking",
    inviteFromWhispers = "Interface\\Icons\\INV_Letter_15",
    hideKeybindText = "Interface\\Icons\\INV_Misc_StoneTablet_01",
    hideMacroText = "Interface\\Icons\\INV_Misc_Note_01",
    hideZoneText = "Interface\\Icons\\INV_Misc_Map_01",
    maxCameraZoom = "Interface\\Icons\\Spell_Nature_FarSight",

    fastAutoLoot = "Interface\\Icons\\INV_Misc_TreasureChest01",
    autoGossip = "Interface\\Icons\\INV_Misc_Note_01",
    durabilityWarning = "Interface\\Icons\\Trade_BlackSmithing",
    tooltipIDs = "Interface\\Icons\\INV_Misc_QuestionMark",
    junkValueSummary = "Interface\\Icons\\INV_Misc_Coin_01",
    showWelcomeOnLogin = "Interface\\Icons\\INV_Letter_15",
    matchFocusSize = "Interface\\Icons\\Ability_Hunter_SniperShot",
    actionBars = "Interface\\Icons\\Ability_Warrior_BattleShout",
    castBars = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    unitFrames = "Interface\\Icons\\INV_Helmet_03",
    minimap = "Interface\\Icons\\INV_Misc_Map_01",
    friendlyNameplates = "Interface\\Icons\\Spell_Holy_PrayerOfHealing",
    enemyNameplates = "Interface\\Icons\\Ability_Creature_Cursed_02",
    disableAggroHighlight = "Interface\\Icons\\Ability_Warrior_Challange",
    characterPanel = "Interface\\Icons\\INV_Chest_Plate04",
    talentWindow = "Interface\\Icons\\Ability_Marksmanship",
    spellbook = "Interface\\Icons\\INV_Misc_Book_09",
    questDialogs = "Interface\\Icons\\INV_Misc_Note_01",
    questTracker = "Interface\\Icons\\INV_Misc_ScrollInfo",
    questLog = "Interface\\Icons\\INV_Misc_Book_11",
    professions = "Interface\\Icons\\Trade_BlackSmithing",
    trainer = "Interface\\Icons\\Trade_Engineering",
    bagsBank = "Interface\\Icons\\INV_Misc_Bag_08",
    merchantSkin = "Interface\\Icons\\INV_Misc_Coin_01",
    mailSkin = "Interface\\Icons\\INV_Letter_15",
    auctionHouse = "Interface\\Icons\\INV_Misc_Coin_02",
    socialWindows = "Interface\\Icons\\INV_Misc_GroupLooking",
    groupFinderPvp = "Interface\\Icons\\Ability_Warrior_BattleShout",
    gameMenu = "Interface\\Icons\\INV_Misc_Gear_01",
    blizzardSettings = "Interface\\Icons\\Trade_Engineering",
    tooltipSkin = "Interface\\Icons\\INV_Misc_Note_05",
    contextMenus = "Interface\\Icons\\INV_Misc_Note_02",
    popups = "Interface\\Icons\\INV_Misc_QuestionMark",
    lootWindow = "Interface\\Icons\\INV_Misc_TreasureChest01",
    vendorPrice = "Interface\\Icons\\INV_Misc_Coin_01",
    bagSpace = "Interface\\Icons\\INV_Misc_Bag_10",
    questLevels = "Interface\\GossipFrame\\AvailableQuestIcon",
    cleanMinimap = "Interface\\Icons\\Spell_Nature_FarSight",
    coordinates = "Interface\\Icons\\INV_Misc_Map_01",
    showAllSpellRanks = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    gryphons = "Interface\\Icons\\Ability_Mount_Gryphon_01",
    hideEmptyActionSlots = "Interface\\Icons\\INV_Misc_StoneTablet_01",
    autoSellJunk = "Interface\\Icons\\INV_Misc_Coin_05",
    autoRepair = "Interface\\Icons\\Trade_BlackSmithing",
    hideSecondaryNames = "Interface\\Icons\\INV_Misc_Idol_03",
    classColors = "Interface\\Icons\\INV_Misc_Desecrated_ClothShoulder",
    hideStatusMessages = "Interface\\Icons\\Spell_Shadow_Silence",
}

local function MakeCheck(parent, label, key, category, column, row, icon, summary, unavailable)
    local check = CreateFrame("CheckButton", nil, parent)
    check.searchText = string.lower(label .. " " .. (summary or "") .. " " .. key)
    check.category = category
    check:SetSize(350, 74)
    check:SetPoint("TOPLEFT", 202 + column * 366, -148 - row * 78)
    local separator = check:CreateTexture(nil, "BACKGROUND")
    separator:SetPoint("TOPLEFT")
    separator:SetPoint("TOPRIGHT")
    separator:SetHeight(1)
    separator:SetColorTexture(0.14, 0.15, 0.18, 1)
    local highlight = check:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.035)
    local picture = check:CreateTexture(nil, "ARTWORK")
    picture:SetSize(28, 28)
    picture:SetPoint("TOPLEFT", 8, -18)
    picture:SetTexture(featureIcons[key] or ("Interface\\Icons\\" .. icon))
    if key ~= "questLevels" then picture:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
    if key=="energyBar" or key=="floatingComboPoints" or key=="swingTimer" or key=="rageBar" or key=="manaBar" or key=="druidResourceBar" or key=="rangedSwingTimer" then
        local _,class=UnitClass("player")
        picture:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        local coords=classIconCoords[class] or classIconCoords.ROGUE
        picture:SetTexCoord(unpack(coords))
    end
    check.text = Text(check, label, 14)
    check.text:SetPoint("TOPLEFT", 46, -10)
    check.text:SetWidth(244)
    check.text:SetWordWrap(true)
    check.text:SetHeight(30)
    check.text:SetJustifyV("TOP")
    local description = Text(check, summary, 12, true)
    description:SetPoint("TOPLEFT", 46, -40)
    description:SetWidth(244)
    description:SetHeight(26)
    description:SetJustifyV("TOP")
    check.track = CreateFrame("Frame", nil, check, "BackdropTemplate")
    check.track:SetSize(42, 22)
    check.track:SetPoint("TOPRIGHT", -8, -18)
    check.track:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    check.thumb = check.track:CreateTexture(nil, "ARTWORK")
    check.thumb:SetSize(16, 16)
    check.state = Text(check, "", 10, true)
    check.state:SetPoint("TOP", check.track, "BOTTOM", 0, -5)
    local checked = EraUI:GetSavedSetting(key) and true or false
            
            check:SetChecked(not check.unavailable and checked)
            if check.unavailable then check.state:SetText("SOON") end
    hooksecurefunc(check, "SetChecked", PaintToggle)
    PaintToggle(check)
    local function ShowSettingTooltip(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label, ClassColour())
        if check.dependencyDisabled then
            GameTooltip:AddLine("Enable Advanced Cast Bar to use this feature.",1,.82,.3,true)
        end
        GameTooltip:AddLine(settingHelp[key] or summary, 1, 1, 1, true)
        if unavailable then
            GameTooltip:AddLine("Coming soon - not finished yet.",1,.82,0,true)
        elseif reloadSettings[key] then
            GameTooltip:AddLine("Requires /reload to apply or restore native appearance. Until then, your current appearance stays active.",1,.82,0,true)
        end
        local default = EraUI.settingDefaults[key]
        GameTooltip:AddLine(key=="showAllSpellRanks" and "Default: keep your existing game preference."
            or ("Default: " .. (default and "On" or "Off")),.7,.7,.7,true)
        GameTooltip:Show()
    end
    check:HookScript("OnEnter", ShowSettingTooltip)
    check:HookScript("OnLeave", HideSettingTooltip)
    check:HookScript("OnHide", HideSettingTooltip)
    if key=="advancedCastClassFill" or key=="advancedCastTicks" or key=="advancedCastLatency" then
        -- Disabled buttons do not reliably receive mouse motion on every client.
        -- A motion-only cover retains the explanation without enabling clicks.
        local cover=CreateFrame("Frame",nil,check)
        cover:SetAllPoints();cover:EnableMouse(true)
        cover:SetFrameLevel((check:GetFrameLevel()or 0)+1)
        cover:SetScript("OnEnter",ShowSettingTooltip)
        cover:SetScript("OnLeave",HideSettingTooltip)
        cover:SetScript("OnHide",HideSettingTooltip)
        cover:Hide();check.dependencyHelp=cover
    end
    parent.checks[key] = check
    check.unavailable = unavailable
    if unavailable then
        check:SetEnabled(false)
        check:SetChecked(false)
        check.state:SetText("SOON")
        check.text:SetTextColor(.58,.62,.68)
    end
    check:SetScript("OnClick", function(self)
        if unavailable or self.dependencyDisabled then return end
        PaintToggle(self)
        local previous = EraUI:GetSavedSetting(key)
        local value = self:GetChecked() and true or false
        EraUI:SetSetting(key, value)
        UpdateReloadHint(parent)
        if parent.setupMode and reloadSettings[key] then return end
        if key=="cursorRing" or key=="cursorRingClassColour" then
            if EraUI.modules.CursorRing then EraUI.modules.CursorRing:Refresh()end
            return
        end
        if key=="advancedCastBar" or key=="advancedCastClassFill" or key=="advancedCastLatency" or key=="advancedCastTicks" then
            if key=="advancedCastBar" and not value then
                for _,dependent in ipairs({"advancedCastTicks","advancedCastLatency"}) do
                    EraUI:SetSetting(dependent,false);parent.checks[dependent]:SetChecked(false)
                end
            end
            if parent.RefreshCastDependencies then parent:RefreshCastDependencies()end
            if EraUI.modules.AdvancedCastBar then EraUI.modules.AdvancedCastBar:Refresh()end
            return
        end
        if key=="castBarClassBorder" then
            if EraUI.modules.AdvancedCastBar then EraUI.modules.AdvancedCastBar:Refresh()end
            if EraUI.modules.ClassAccents then EraUI.modules.ClassAccents:Refresh() end
            return
        end
        if key=="poisonReminders" then
            if EraUI.modules.PoisonReminders then EraUI.modules.PoisonReminders:Refresh()end
            return
        end
        if key=="hunterFeed" or key=="mageSupplies" or key=="mageAutoTrade" or key=="roguePoisons" or key=="classReminders" then
            local tools=EraUI.modules.ClassTools
            if tools then tools:Refresh() end
            return
        end
        if key=="mapQuestObjectives" or key=="rewardUpgradeHighlight" then
            local tools=EraUI.modules.QuestTools
            if tools then if key=="mapQuestObjectives" then tools:ApplyMap() else tools:RefreshRewards() end end
            return
        end
        if key=="rageBar" or key=="manaBar" or key=="druidResourceBar" then
            if EraUI.modules.ResourceBar then EraUI.modules.ResourceBar:Refresh() end
            return
        end
        if key=="rangedSwingTimer" then
            if EraUI.modules.RangedSwingTimer then EraUI.modules.RangedSwingTimer:Refresh() end
            return
        end
        if key=="swingTimer" then
            if EraUI.modules.SwingTimer then EraUI.modules.SwingTimer:Refresh() end
            return
        end
        if key=="energyBar" then
            if EraUI.modules.EnergyBar then EraUI.modules.EnergyBar:Refresh() end
            return
        end
        local applied = false
        if EraUI.convenienceSettings and EraUI.convenienceSettings[key] then
            if EraUI.modules.Convenience then EraUI.modules.Convenience:Refresh() end
            EraUI:Status(label .. (value and " enabled." or " disabled.") .. (InCombatLockdown() and " Applies after combat." or ""))
            return
        end
        if key == "durabilityWarning" and EraUI.modules.ExtraQoL then EraUI.modules.ExtraQoL:CheckDurability() end
        if key == "fastAutoLoot" or key == "autoGossip" or key == "durabilityWarning" or key == "tooltipIDs" or key == "junkValueSummary" or key == "showWelcomeOnLogin" then
            EraUI:Status(label .. (value and " enabled." or " disabled.")); return
        end
        if key == "coordinates" and EraUI.modules.MinimapTools then
            EraUI.modules.MinimapTools:UpdateCoordinates()
            applied = true
        elseif key == "showAllSpellRanks" then
            if InCombatLockdown() then
                EraUI:SetSetting(key,previous);self:SetChecked(previous)
                EraUI:Print("Finish combat before changing spell ranks.");return
            end
            SetCVar("ShowAllSpellRanks",value and "1" or "0")
            if EraUI.SyncClassicQoL then EraUI:SyncClassicQoL() end
            applied = true
        elseif key == "cleanMinimap" and EraUI.modules.MinimapTools then
            EraUI.modules.MinimapTools:Discover()
            EraUI.modules.MinimapTools:Refresh()
            applied = true
        elseif key == "hideStatusMessages" then
            applied = true
        elseif key == "classColors" then
            local qol = EraUI.modules.QoL
            if not qol or not qol:ApplyChatClassColors() then
                EraUI:SetSetting(key, previous)
                self:SetChecked(previous and true or false)
                EraUI:Print("Could not change class colours in chat on this client.")
                return
            end
            EraUI:Status(label .. " " .. (self:GetChecked() and "enabled" or "disabled") .. ". Applies to new chat messages.")
            return
        elseif key == "bagSpace" and EraUI.modules.QoL then
            EraUI.modules.QoL:UpdateBagSpace()
            applied = true
        elseif key == "questLevels" and EraUI.modules.QoL then
            EraUI.modules.QoL:RefreshQuestLevels()
            applied = true
        elseif key == "hideSecondaryNames" and EraUI.modules.SecondaryNames then
            EraUI.modules.SecondaryNames:Apply()
            applied = true
        elseif key == "hideEmptyActionSlots" and EraUI.modules.ActionBars then
            EraUI.modules.ActionBars:RefreshEmptySlots()
            applied = true
        elseif key == "gryphons" and EraUI.modules.ActionBars then
            EraUI.modules.ActionBars:ApplyGryphons(_G.MainActionBar or _G.MainMenuBar)
            EraUI:Status(self:GetChecked() and "Gryphons shown." or "Gryphons hidden.")
            return
        elseif key == "comboPointRed" then
            applied = true
            if EraUI.Classic and EraUI.Classic.RefreshComboPointColor then EraUI.Classic.RefreshComboPointColor() end
        elseif key == "movableMap" then
            applied = true
            if EraUI.modules.MovableMap then EraUI.modules.MovableMap:Apply() end
        elseif key == "revealMap" then
            applied = true
            if EraUI.modules.MovableMap then EraUI.modules.MovableMap:Apply() end
        elseif key == "autoSellJunk" or key == "autoRepair" then
            EraUI:Status(label .. " applies on your next merchant visit."); return
        elseif key == "vendorPrice" then
            EraUI:Status(label .. " " .. (self:GetChecked() and "enabled" or "disabled") .. ". Applies on your next item hover.")
            return
        end
        if applied then
            EraUI:Status(label .. " " .. (self:GetChecked() and "enabled" or "disabled") .. ".")
            return
        end
        local changed = (self:GetChecked() and true or false) ~= parent.loadedSettings[key]
        EraUI:Status(label .. " " .. (self:GetChecked() and "enabled" or "disabled")
            .. (changed and ". Click Reload UI to apply." or ". Restored the loaded setting."))
    end)
    return check
end

function SettingsModule:Initialize()
    local onboarding=EraUIClassicCharDB and EraUIClassicCharDB.onboarding
    if onboarding and onboarding.setupComplete and not onboarding.discoveryHintsVersion then
        onboarding.discoverTabs={[12]=true,[13]=true}
        onboarding.discoveryHintsVersion=1
    end
    if self.frame then return end

    local frame = CreateFrame("Frame", "EraUISettingsFrame", UIParent, "BackdropTemplate")
    frame.checks = {}
    frame.loadedSettings = {}
    for key in pairs(reloadSettings) do
        frame.loadedSettings[key] = EraUI:GetSetting(key) and true or false
    end
    frame:SetSize(960, 650)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "EraUISettingsFrame") end
    frame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    frame:SetBackdropColor(0.026, 0.029, 0.037, 1)
    frame:SetBackdropBorderColor(0.19, 0.20, 0.24, 1)

    local navigation = frame:CreateTexture(nil, "BACKGROUND")
    navigation:SetPoint("TOPLEFT", 1, -1)
    navigation:SetPoint("BOTTOMLEFT", 1, 1)
    navigation:SetWidth(188)
    navigation:SetColorTexture(0.014, 0.016, 0.022, 1)
    local divider = frame:CreateTexture(nil, "BORDER")
    divider:SetPoint("TOPLEFT", 189, -1)
    divider:SetPoint("BOTTOMLEFT", 189, 64)
    divider:SetWidth(1)
    divider:SetColorTexture(0.14, 0.15, 0.18, 1)

    local title = Text(frame, "EraUI", 26)
    title:SetPoint("TOPLEFT", 24, -20)

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(36, 36)
    close:SetPoint("TOPRIGHT", -12, -12)
    local closeLabel = Text(close, "X", 20, true)
    closeLabel:SetPoint("CENTER")
    close:SetScript("OnClick", function() frame:Hide() end)
    close:SetScript("OnEnter", function() closeLabel:SetTextColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() closeLabel:SetTextColor(0.58, 0.62, 0.68) end)

    local categories = {
        {"HUD", "HUD", "Classic artwork for the interface you use while playing."},
        {"Character", "CHARACTER", "Character, spells and talents."},
        {"Quests", "QUESTS", "Quest dialogue, tracking and your quest log."},
        {"Commerce", "COMMERCE", "Crafting, training, items and storage."},
        {"Social", "SOCIAL", "Friends, guild and group activities."},
        {"Interface", "INTERFACE", "Menus, windows and shared controls."},
        {"Quality of Life", "QUALITY OF LIFE", "Independent convenience options. Unfinished conversions are marked Later."},
        {"Chat & Names", "CHAT & NAMES", "Player names, chat colours and EraUI notices."},
        {"Automation", "AUTOMATION", "Optional shortcuts, alerts and useful information."},
        {"Text & Camera", "TEXT & CAMERA", "Choose which labels you see and how far the camera can zoom."},
    }
    categories[#categories+1] = {"Appearance", "APPEARANCE"}
    local className,classToken=UnitClass("player")
    local meleeClasses={ROGUE=true,DRUID=true,WARRIOR=true,PALADIN=true,SHAMAN=true,HUNTER=true}
    local manaClasses={HUNTER=true,MAGE=true,PRIEST=true,WARLOCK=true,PALADIN=true,SHAMAN=true}
    local rangedClasses={HUNTER=true,ROGUE=true,WARRIOR=true,MAGE=true,PRIEST=true,WARLOCK=true}
    local hasClassControls=meleeClasses[classToken] or manaClasses[classToken]
    if hasClassControls then categories[12]={className,"CLASS"} end
    categories[13]={"Casting","CASTING"}
    local ResetSearch, ApplySearch
    local RenderAppearance
    local section = Text(frame, "", 24)
    section:SetPoint("TOPLEFT", 208, -38)
    local tabs = {}
    local function SelectCategory(index, keepSearch)
        if ResetSearch and not keepSearch then ResetSearch() end
        frame.selectedCategory = index
        if RenderAppearance then RenderAppearance(index == 11) end
        section:SetText(categories[index][1])
        local r, g, b = ClassColour()
        for i, tab in ipairs(tabs) do
            local active = i == index
            tab.underline:SetColorTexture(r, g, b, 1)
            tab.underline:SetShown(active)
            tab.selected:SetColorTexture(r, g, b, active and 0.12 or 0)
            tab.text:SetTextColor(active and r or 0.58, active and g or 0.62, active and b or 0.68)
        end
        for _, check in pairs(frame.checks) do check:SetShown(check.category == index and check.classAllowed~=false) end
    end
    for i, category in ipairs(categories) do
        local index = i
        local tab = CreateFrame("Button", nil, frame)
        tab:SetSize(164, hasClassControls and 36 or 40)
        local slot=i==13 and 13 or hasClassControls and (i==12 and 2 or (i>=2 and i+1 or i)) or i
        tab:SetPoint("TOPLEFT", 12, -104 - (slot - 1) * (hasClassControls and 36 or 40))
        tab.text = Text(tab, category[1], 14)
        tab.text:SetPoint("LEFT", 36, 0)
        tab.text:SetFont(select(1, GameFontHighlight:GetFont()), 13, "")
        tab.underline = tab:CreateTexture(nil, "ARTWORK")
        tab.underline:SetPoint("TOPLEFT", 0, -6)
        tab.underline:SetPoint("BOTTOMLEFT", 0, 6)
        tab.underline:SetWidth(3)
        tab.selected = tab:CreateTexture(nil, "BACKGROUND")
        tab.selected:SetAllPoints()
        local navIcon = tab:CreateTexture(nil, "ARTWORK")
        navIcon:SetSize(20,20)
        navIcon:SetPoint("LEFT",10,0)
        local navKeys = {"actionBars", "characterPanel", "questLevels", "merchantSkin", "socialWindows", "gameMenu", "gryphons", "classColors", "autoRepair", "coordinates", "gameMenu"}
        if i==12 then
            navIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
            navIcon:SetTexCoord(unpack(classIconCoords[classToken] or classIconCoords.ROGUE))
        elseif i==13 then navIcon:SetTexture("Interface\\Icons\\Spell_Arcane_Blast")
        else navIcon:SetTexture(featureIcons[navKeys[i]]) end
        local hover = tab:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1,1,1,0.04)
        if i==12 or i==13 then
            local hint=tab:CreateTexture(nil,"BACKGROUND",nil,1)
            hint:SetAllPoints()
            local r,g,b=ClassColour()
            hint:SetColorTexture(r,g,b,1)
            hint:Hide()
            local elapsed=0
            tab:SetScript("OnUpdate",function(_,dt)
                elapsed=elapsed+dt
                local state=EraUIClassicCharDB and EraUIClassicCharDB.onboarding
                local pending=state and state.discoverTabs and state.discoverTabs[index]
                hint:SetShown(not frame.setupMode and pending==true and frame.selectedCategory~=index)
                if pending then hint:SetAlpha(.055+.03*(.5+.5*math.sin(elapsed*2)))end
            end)
        end
        tab:SetScript("OnClick", function()
            local state=EraUIClassicCharDB and EraUIClassicCharDB.onboarding
            if state and state.discoverTabs then state.discoverTabs[index]=nil end
            SelectCategory(index)
        end)
        tabs[i] = tab
    end

    MakeCheck(frame, "Action Bars", "actionBars", 1, 0, 0, "INV_Misc_Book_09", "Stone dock and Classic action buttons.", false)
    MakeCheck(frame, "Cast Bars", "castBars", 1, 1, 0, "INV_Misc_Book_09", "Player, target, focus and nameplate casts.", false)
    MakeCheck(frame, "Unit Frames", "unitFrames", 1, 0, 1, "INV_Misc_Book_09", "Player, target and focus styling.", false)
    MakeCheck(frame, "Minimap", "minimap", 1, 1, 1, "INV_Misc_Book_09", "Classic round map and controls.", false)
    MakeCheck(frame, "Friendly Nameplates", "friendlyNameplates", 1, 0, 2, "INV_Misc_Book_09", "Classic friendly unit presentation.", false)
    MakeCheck(frame, "Enemy Nameplates", "enemyNameplates", 1, 1, 2, "INV_Misc_Book_09", "Classic enemy and neutral presentation.", false)
    MakeCheck(frame, "Hide Aggro Highlight", "disableAggroHighlight", 1, 0, 3, "INV_Misc_Book_09", "Hide unit-frame threat decoration.", false)
    MakeCheck(frame, "Character / Reputation / Skills", "characterPanel", 2, 0, 0, "INV_Misc_Book_09", "Classic panels, rows and bottom tabs.", false)
    MakeCheck(frame, "Talents", "talentWindow", 2, 1, 0, "INV_Misc_Book_09", "Classic talent trees and native talent actions.", false)
    MakeCheck(frame, "Spellbook", "spellbook", 2, 0, 1, "INV_Misc_Book_09", "Classic book and native spell actions.", false)
    MakeCheck(frame, "Combat Spell Dragging", "spellbookCombatDrag", 2, 1, 1, "Spell_Holy_MagicalSentry", "Use native spell buttons to drag spells during combat. Reload to apply.", false)
    MakeCheck(frame, "Quest Dialogue", "questDialogs", 3, 0, 0, "INV_Misc_Book_09", "Quest offers, rewards and turn-ins.", false)
    MakeCheck(frame, "Quest Tracker", "questTracker", 3, 1, 0, "INV_Misc_Book_09", "Classic quest watch presentation.", false)
    MakeCheck(frame, "Quest Log", "questLog", 3, 0, 1, "INV_Misc_Book_09", "Classic presentation.", false)
    MakeCheck(frame, "Professions", "professions", 4, 0, 0, "INV_Misc_Book_09", "Classic profession windows.", false)
    MakeCheck(frame, "Trainer", "trainer", 4, 1, 0, "INV_Misc_Book_09", "Trainer presentation and training controls.", false)
    MakeCheck(frame, "Bags / Bank", "bagsBank", 4, 0, 1, "INV_Misc_Book_09", "Classic presentation.", false)
    MakeCheck(frame, "Merchant", "merchantSkin", 4, 1, 1, "INV_Misc_Book_09", "Classic presentation.", false)
    MakeCheck(frame, "Mail", "mailSkin", 4, 0, 2, "INV_Misc_Book_09", "Classic presentation.", false)
    MakeCheck(frame, "Auction House", "auctionHouse", 4, 1, 2, "INV_Misc_Book_09", "Classic presentation.", false)
    MakeCheck(frame, "Friends / Guild", "socialWindows", 5, 0, 0, "INV_Misc_Book_09", "Classic Friends, Who and Guild presentation.", false)
    MakeCheck(frame, "Group Finder / PvP", "groupFinderPvp", 5, 1, 0, "INV_Misc_Book_09", "Classic presentation.", false)
    MakeCheck(frame, "Game Menu", "gameMenu", 6, 0, 0, "INV_Misc_Book_09", "Classic menu border and buttons.", false)
    MakeCheck(frame, "Blizzard Settings Skin", "blizzardSettings", 6, 1, 0, "INV_Misc_Book_09", "Classic presentation.", false)
    MakeCheck(frame, "Tooltips", "tooltipSkin", 6, 0, 1, "INV_Misc_Book_09", "Not implemented; vendor prices are separate.", true)
    MakeCheck(frame, "Context Menus", "contextMenus", 6, 1, 1, "INV_Misc_Book_09", "Not implemented yet.", true)
    MakeCheck(frame, "Popups", "popups", 6, 0, 2, "INV_Misc_Book_09", "Classic confirmation prompts.", false)
    MakeCheck(frame, "Loot", "lootWindow", 6, 1, 2, "INV_Misc_Book_09", "Classic loot window and item rows.", false)
    MakeCheck(frame, "Vendor Prices", "vendorPrice", 7, 0, 0, "INV_Misc_Book_09", "Add missing item selling prices.", false)
    MakeCheck(frame, "Bag Space", "bagSpace", 7, 1, 0, "INV_Misc_Book_09", "Show free slots on the backpack.", false)
    MakeCheck(frame, "Quest Levels", "questLevels", 7, 0, 1, "INV_Misc_Book_09", "Show levels on tracked quests.", false)
    MakeCheck(frame, "Clean Minimap", "cleanMinimap", 7, 1, 1, "INV_Misc_Book_09", "Addon buttons appear on hover.", false)
    MakeCheck(frame, "Coordinates", "coordinates", 7, 0, 2, "INV_Misc_Book_09", "Optional position beneath the minimap.", false)
    MakeCheck(frame, "Show All Spell Ranks", "showAllSpellRanks", 7, 1, 2, "INV_Misc_Book_09", "Keep every rank visible in the spellbook.", false)
    MakeCheck(frame, "Show Gryphons", "gryphons", 7, 0, 3, "INV_Misc_Book_09", "Show action-bar end decorations.", false)
    MakeCheck(frame, "Hide Empty Action Slots", "hideEmptyActionSlots", 7, 1, 3, "INV_Misc_Book_09", "Reveal empty slots when arranging spells.", false)
    MakeCheck(frame, "Auto-sell Junk", "autoSellJunk", 7, 0, 4, "INV_Misc_Book_09", "Sell grey items at merchants.", false)
    MakeCheck(frame, "Auto-repair", "autoRepair", 7, 1, 4, "INV_Misc_Book_09", "Repair using your own gold.", false)
    MakeCheck(frame, "Hide Secondary Names", "hideSecondaryNames", 8, 0, 0, "INV_Misc_Book_09", "Hide Forever surnames.", false)
    MakeCheck(frame, "Class Colours in Chat", "classColors", 8, 1, 0, "INV_Misc_Book_09", "Colour new player names by class.", false)
    MakeCheck(frame,"Classic Chat Dragging","classicChatDragging",8,1,1,"INV_Misc_Note_01","Right-click General or a docked chat tab to unlock, drag and lock the chat window. Remembers your position and lock state. Reload to apply.",false)
    MakeCheck(frame, "Quiet Mode", "hideStatusMessages", 8, 0, 1, "INV_Misc_Book_09", "Hide EraUI startup and change notices.", false)
    MakeCheck(frame, "Match Focus Size", "matchFocusSize", 1, 1, 3, "INV_Misc_Book_09", "Use target size for focus. Reload to apply; off uses your native layout.", false)
    MakeCheck(frame, "Faster Auto Loot", "fastAutoLoot", 9, 0, 0, "INV_Misc_Book_09", "Loot immediately. Hold Shift for manual looting; inactive in combat.", false)
    MakeCheck(frame, "Auto Gossip", "autoGossip", 9, 1, 0, "INV_Misc_Book_09", "Choose a single free dialogue option. Hold Shift to bypass. Leaves quests alone.", false)
    MakeCheck(frame, "Low Durability Warning", "durabilityWarning", 9, 0, 1, "INV_Misc_Book_09", "Warn once when equipped gear falls to 20% or less; resets after repair.", false)
    MakeCheck(frame, "Tooltip IDs", "tooltipIDs", 9, 1, 1, "INV_Misc_Book_09", "Item, spell and NPC IDs when exposed by this client. Re-hover to update.", false)
    MakeCheck(frame, "Junk Value Summary", "junkValueSummary", 9, 0, 2, "INV_Misc_Book_09", "Report grey-item vendor value when opening a merchant, before sales.", false)
    MakeCheck(frame, "Welcome on Login", "showWelcomeOnLogin", 9, 1, 2, "INV_Misc_Book_09", "Show the EraUI welcome on login, not ordinary UI reloads.", false)
    MakeCheck(frame, "Automate Quests", "autoQuests", 9, 0, 3, "INV_Misc_ScrollInfo", "Accept quests and turn in completed quests with zero or one reward choice. Hold Shift to pause; multiple choices stay manual.", false)
    MakeCheck(frame, "Accept Summons", "autoSummon", 9, 1, 3, "Spell_Shadow_Twilight", "Accept after one second outside combat. Hold Shift to bypass.", false)
    MakeCheck(frame, "Accept Resurrection", "autoResurrect", 9, 0, 4, "Spell_Holy_Resurrection", "Accept resurrection requests outside combat. Hold Shift to bypass.", false)
    MakeCheck(frame, "Release in Battlegrounds", "releasePvP", 9, 1, 4, "Ability_DualWield", "Release after one second in battlegrounds only. Hold Shift to bypass.", false)
    MakeCheck(frame, "Block Duels", "blockDuels", 5, 0, 1, "Ability_DualWield", "Decline duel requests. Hold Shift to handle a request manually.", false)
    MakeCheck(frame, "Block Party Invites", "blockPartyInvites", 5, 1, 1, "INV_Misc_GroupLooking", "Decline invitations, except enabled friend acceptance. Shift bypasses.", false)
    MakeCheck(frame, "Party from Friends", "partyFromFriends", 5, 0, 2, "INV_Misc_GroupLooking", "Accept invites from character friends. Takes priority over invite blocking.", false)
    MakeCheck(frame, "Invite from Whispers", "inviteFromWhispers", 5, 1, 2, "INV_Letter_15", "Character friends can whisper invite to join. Requires permission to invite.", false)
    MakeCheck(frame, "Hide Keybind Text", "hideKeybindText", 10, 0, 0, "INV_Misc_StoneTablet_01", "Hide action-button key labels; bindings still work. Combat changes wait.", false)
    MakeCheck(frame, "Hide Macro Names", "hideMacroText", 10, 1, 0, "INV_Misc_Note_01", "Hide action-button macro names. Combat changes wait.", false)
    MakeCheck(frame, "Hide Zone Announcements", "hideZoneText", 10, 0, 1, "INV_Misc_Map_01", "Hide large zone/subzone announcements; minimap names remain.", false)
    MakeCheck(frame, "Maximum Camera Distance", "maxCameraZoom", 10, 1, 1, "Spell_Nature_FarSight", "Raise the camera limit to 2.6. Scroll out normally; off restores prior limit.", false)
    MakeCheck(frame,"Cursor Ring","cursorRing",10,0,2,"INV_Misc_EngGizmos_18","A ring follows your mouse pointer. Adjust its diameter and thickness below. Applies immediately.",false)
    MakeCheck(frame,"Class-coloured Cursor Ring","cursorRingClassColour",10,1,2,"INV_Misc_ArmorKit_17","Use your current class colour for the mouse ring. Off uses white.",false)
    local function RingSlider(key,label,column,low,high,default)
        local card=CreateFrame("Frame",nil,frame)
        card.category=10;card.searchText=string.lower("cursor mouse ring "..label)
        card:SetSize(350,74);card:SetPoint("TOPLEFT",202+column*366,-148-3*78)
        card.text=Text(card,label,14);card.text:SetPoint("TOPLEFT",12,-10)
        local slider=CreateFrame("Slider",nil,card,"BackdropTemplate")
        slider:SetSize(310,12);slider:SetPoint("TOPLEFT",12,-45)
        slider:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        slider:SetBackdropColor(.06,.065,.075,1);slider:SetBackdropBorderColor(.3,.32,.36,1)
        slider:SetOrientation("HORIZONTAL");slider:SetMinMaxValues(low,high);slider:SetValueStep(1);slider:SetObeyStepOnDrag(true)
        slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8");slider:GetThumbTexture():SetSize(10,20);slider:GetThumbTexture():SetVertexColor(ClassColour())
        slider:SetScript("OnValueChanged",function(_,value)
            value=math.max(low,math.min(high,math.floor(value+.5)))
            card.text:SetText(label..": "..value)
            if not card.syncing then EraUI:SetSetting(key,value);if EraUI.modules.CursorRing then EraUI.modules.CursorRing:Refresh()end end
        end)
        card.SetChecked=function()
            card.syncing=true;slider:SetValue(math.max(low,math.min(high,tonumber(EraUI:GetSavedSetting(key))or default)));card.syncing=false
        end
        card.slider=slider;card:SetChecked();frame.checks[key]=card
    end
    RingSlider("cursorRingSize","Ring diameter",0,24,160,48)
    RingSlider("cursorRingThickness","Ring thickness",1,1,10,2)
    MakeCheck(frame, "Class-coloured Unit Borders", "classColourBorders", 11, 0, 2, "INV_Misc_ArmorKit_17", "Each player's class colour on player, target and focus borders. Dark Mode only; reload to apply.", false)
    MakeCheck(frame, "Floating Combo Points", "floatingComboPoints", 12, 0, 0, "Ability_Rogue_Eviscerate", "Hover orbs for controls. Right-click + to unlock; left-click to lock. Reload to enable.", false)
    MakeCheck(frame, "Red Combo Points", "comboPointRed", 12, 0, 0, "Ability_Rogue_Rupture", "Draw the combo point orbs red instead of gold. Applies immediately.", false)
    MakeCheck(frame, "Energy Bar", "energyBar", 12, 1, 0, "ClassIcon_Rogue", "Floating energy and current value. Hover + to move or resize. Applies immediately.", false)
    frame.checks.energyBar.classAllowed=classToken=="ROGUE"
    frame.checks.floatingComboPoints.classAllowed=classToken=="ROGUE" or classToken=="DRUID"
    frame.checks.comboPointRed.classAllowed=classToken=="ROGUE" or classToken=="DRUID"
    MakeCheck(frame, "Swing Timer", "swingTimer", 12, 0, 1, "INV_Sword_04", "Main-hand and off-hand swings. Hover + to move or resize. Applies immediately.", false)
    frame.checks.swingTimer.classAllowed=meleeClasses[classToken] or false
    local resourceColumn=(classToken=="DRUID") and 1 or 0
    MakeCheck(frame, "Rage Bar", "rageBar", 12, resourceColumn, 0, "ClassIcon_Warrior", "Floating rage and current value. Hover + to move or resize.", false)
    frame.checks.rageBar.classAllowed=classToken=="WARRIOR"
    MakeCheck(frame, "Mana Bar", "manaBar", 12, resourceColumn, 0, "INV_Potion_76", "Floating mana and current value. Hover + to move or resize.", false)
    frame.checks.manaBar.classAllowed=manaClasses[classToken] or false
    MakeCheck(frame, "Resource Bar", "druidResourceBar", 12, resourceColumn, 0, "ClassIcon_Druid", "Mana, cat energy or bear rage. Switches automatically with your form.", false)
    frame.checks.druidResourceBar.classAllowed=classToken=="DRUID"
    MakeCheck(frame, "Ranged Swing Timer", "rangedSwingTimer", 12, 1, 1, "INV_Weapon_Bow_07", "Ranged attacks and wands. Equip a ranged weapon. Hover + to move or resize.", false)
    frame.checks.rangedSwingTimer.classAllowed=rangedClasses[classToken] or false
    for _,entry in ipairs({
        {"hunterFeed","Pet Feeding","HUNTER","Movable feeding button when happiness is low, plus Feed Pet duration. Configure food in Class Tools."},
        {"mageSupplies","Conjuring Suggestions","MAGE","Suggest learned food and water for your target's level. Open Class Tools to conjure."},
        {"mageAutoTrade","Auto-fill Trade","MAGE","Place full stacks of suitable conjured food and water in trade. Stack counts are in Class Tools."},
        {"poisonReminders","Poison Reminders","ROGUE","Missing weapon coatings, low time and charges. Preview while settings are open; right-click header to move/resize."},
        {"roguePoisons","Poison Supplies","ROGUE","Poison vendor quantities, material purchases, crafting and Flash Powder. Open Class Tools for controls."},
    }) do
        MakeCheck(frame,entry[2],entry[1],12,0,0,"INV_Misc_Bag_10",entry[4],false)
        frame.checks[entry[1]].classAllowed=classToken==entry[3]
    end
    local reminderClasses={WARLOCK=true,PALADIN=true,SHAMAN=true,PRIEST=true,DRUID=true,WARRIOR=true}
    MakeCheck(frame,"Class Reminders & Buffs","classReminders",12,0,0,"Spell_Holy_MagicalSentry","Coming soon - being redesigned. Movable reminders, supplies and click-to-buff controls.",true)
    frame.checks.classReminders.classAllowed=reminderClasses[classToken] or false
    local toolsButton=CreateFrame("Button",nil,frame,"BackdropTemplate")
    toolsButton.category=12;toolsButton.classAllowed=hasClassControls
    toolsButton.searchText="class tools pet feeding food water conjure trade poison supplies flash powder options"
    toolsButton:SetSize(350,74);toolsButton:SetPoint("TOPLEFT",202,-148)
    toolsButton:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    local tr,tg,tb=ClassColour()
    toolsButton:SetBackdropColor(tr*.16,tg*.16,tb*.16,1);toolsButton:SetBackdropBorderColor(tr,tg,tb,1)
    local toolsIcon=toolsButton:CreateTexture(nil,"ARTWORK");toolsIcon:SetSize(30,30);toolsIcon:SetPoint("LEFT",12,0)
    toolsIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
    toolsIcon:SetTexCoord(unpack(classIconCoords[classToken] or classIconCoords.ROGUE))
    local toolsArrow=Text(toolsButton,">",24);toolsArrow:SetPoint("RIGHT",-14,0);toolsArrow:SetTextColor(tr,tg,tb)
    toolsButton:SetScript("OnEnter",function(self)self:SetBackdropColor(tr*.28,tg*.28,tb*.28,1)end)
    toolsButton:SetScript("OnLeave",function(self)self:SetBackdropColor(tr*.16,tg*.16,tb*.16,1)end)
    toolsButton.text=Text(toolsButton,"Configure "..className.." Tools",14);toolsButton.text:SetPoint("TOPLEFT",54,-14);toolsButton.text:SetTextColor(tr,tg,tb)
    local toolsDetail=Text(toolsButton,"Click to open options and controls.",12,true)
    toolsDetail:SetPoint("TOPLEFT",54,-40);toolsDetail:SetWidth(266)
    toolsButton.SetChecked=function()end
    toolsButton:SetScript("OnClick",function()
        if EraUI.modules.ClassTools then EraUI.modules.ClassTools:Open() end
    end)
    frame.checks.classTools=toolsButton
    -- Compact class controls so unavailable features never leave empty cells.
    local classOrder={"floatingComboPoints","comboPointRed","energyBar","rageBar","manaBar","druidResourceBar","swingTimer","rangedSwingTimer","hunterFeed","mageSupplies","mageAutoTrade","roguePoisons","poisonReminders","classReminders","classTools"}
    local slot=0
    for _,key in ipairs(classOrder) do
        local check=frame.checks[key]
        if check.classAllowed then
            check:ClearAllPoints();check:SetPoint("TOPLEFT",202+(slot%2)*366,-148-math.floor(slot/2)*78)
            slot=slot+1
        end
    end
    MakeCheck(frame,"Map Quest Objectives","mapQuestObjectives",3,1,1,"INV_Misc_Map_01","Show Blizzard's quest objectives on the world map. Updates the native map filter.",false)
    MakeCheck(frame,"Movable World Map","movableMap",3,0,3,"INV_Misc_Map_03","Drag the world map by its edge and resize it from the corners or edges. Your spot and size are remembered.",false)
    MakeCheck(frame,"Reveal World Map","revealMap",3,1,3,"INV_Misc_Map_02","Coming soon - being worked on. Will show the whole map while keeping unexplored areas marked.",true)
    MakeCheck(frame,"Highlight Reward Upgrades","rewardUpgradeHighlight",3,0,2,"INV_Misc_ArmorKit_17","Suggest a usable reward using your chosen stat profile. You choose the reward.",false)
    local profile=CreateFrame("Button",nil,frame,"BackdropTemplate")
    profile.category=3;profile:SetSize(350,74);profile:SetPoint("TOPLEFT",568,-304)
    profile:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    profile:SetBackdropColor(.075,.078,.085,1);profile:SetBackdropBorderColor(.25,.27,.3,1)
    profile.label=Text(profile,"",14);profile.label:SetPoint("TOPLEFT",12,-12)
    local detail=Text(profile,"Click: next profile. Right-click: previous.\nHover to inspect the scoring weights.",12,true)
    detail:SetPoint("TOPLEFT",12,-36)
    local function ProfileLabel()
        local tools=EraUI.modules.QuestTools
        profile.label:SetText("Reward profile: "..(tools and tools:Profile()[1] or "Loading"))
    end
    profile.SetChecked=ProfileLabel -- Participate in the settings refresh/layout only.
    profile:RegisterForClicks("LeftButtonUp","RightButtonUp")
    profile:SetScript("OnClick",function(_,button)
        local tools=EraUI.modules.QuestTools
        if tools then tools:CycleProfile(button=="RightButton" and -1 or 1);ProfileLabel() end
    end)
    profile:SetScript("OnEnter",function(self)
        local tools=EraUI.modules.QuestTools
        if tools and GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Reward scoring");GameTooltip:AddLine(tools:ProfileDescription(),1,1,1,true);GameTooltip:Show()end
    end)
    profile:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide()end end)
    profile:SetScript("OnShow",ProfileLabel)
    frame.checks.rewardProfile=profile
    MakeCheck(frame,"Class-coloured Cast Border","castBarClassBorder",13,0,1,"Spell_Arcane_Blast","Class-coloured outlines for player, target, focus and player nameplate casts. NPCs stay unchanged.",false)
    MakeCheck(frame,"Advanced Cast Bar","advancedCastBar",13,0,0,"Spell_Arcane_Blast","Icon, time and latency. Preview appears while settings are open; hover + to move/resize.",false)
    MakeCheck(frame,"Class-coloured Fill","advancedCastClassFill",13,1,0,"INV_Misc_ArmorKit_17","Use a muted class colour instead of gold. Priest uses dark silver for readable text.",false)
    MakeCheck(frame,"Channel Tick Marks","advancedCastTicks",13,1,1,"Spell_Shadow_DrainSoul","Marks explicit tick intervals from the spell description when available. Not all channels supply them.",false)
    MakeCheck(frame,"Latency Zone","advancedCastLatency",13,0,2,"INV_Misc_PocketWatch_01","Red end zone based on world latency. Shown when cast duration is readable.",false)
    function frame:RefreshCastDependencies()
        local enabled=EraUI:GetSavedSetting("advancedCastBar")==true
        for _,key in ipairs({"advancedCastClassFill","advancedCastLatency","advancedCastTicks"})do
            local check=self.checks[key]
            check.dependencyDisabled=not enabled;check:SetEnabled(enabled);check:SetAlpha(enabled and 1 or .4)
            check.dependencyHelp:SetShown(not enabled)
        end
        if EraUI.modules.ClassAccents then EraUI.modules.ClassAccents:Refresh()end
    end
    local footerLine = frame:CreateTexture(nil, "ARTWORK")
    footerLine:SetPoint("BOTTOMLEFT", 24, 64)
    footerLine:SetPoint("BOTTOMRIGHT", -24, 64)
    footerLine:SetHeight(1)
    footerLine:SetColorTexture(0.14, 0.15, 0.18, 1)
    local hint = Text(frame, "", 13, true)
    hint:SetPoint("BOTTOMLEFT", 26, 29)
    hint:SetWidth(560)
    frame.reloadHint = hint

    local signature = Text(frame, "Made with |TInterface\\AddOns\\EraUI\\Media\\Heart:10:10:0:0|t by Squirt", 10, true)
    signature:SetPoint("BOTTOMRIGHT", -24, 5)
    signature:SetJustifyH("RIGHT")
    signature:SetTextColor(0.48, 0.49, 0.52, 1)

    local reload = CreateFrame("Button", nil, frame, "BackdropTemplate")
    reload:SetSize(142, 32)
    reload:SetPoint("BOTTOMRIGHT", -24, 20)
    reload:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    local reloadText = Text(reload, "Reload UI", 15)
    reloadText:SetPoint("CENTER")
    frame.reloadButton = reload
    reload:SetScript("OnClick", function()
        if InCombatLockdown and InCombatLockdown() then
            hint:SetText("Finish combat before reloading the UI.")
            return
        end
        ReloadUI()
    end)
    -- The setup uses the same controls and callbacks as the regular menu.
    -- Only navigation and placement change; there is one settings implementation.
    local setupSummary = Text(frame, "", 15, true)
    setupSummary:SetPoint("TOPLEFT", 30, -156)
    setupSummary:SetWidth(730)
    setupSummary:SetJustifyV("TOP")
    setupSummary:Hide()
    local setupProgress = Text(frame, "", 12, true)
    setupProgress:SetPoint("TOPRIGHT", -64, -30)
    setupProgress:Hide()
    local function SetupButton(label, x, width)
        local button=CreateFrame("Button",nil,frame,"BackdropTemplate")
        button:SetSize(width,32)
        button:SetPoint("BOTTOMRIGHT",x,20)
        button:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        local r,g,b=ClassColour()
        button:SetBackdropColor(r*.22,g*.22,b*.22,1)
        button:SetBackdropBorderColor(r,g,b,1)
        button.label=Text(button,label,14)
        button.label:SetPoint("CENTER")
        button:Hide()
        return button
    end
    local nextPage=SetupButton("Next >",-24,160)
    local previousPage=SetupButton("< Back",-196,92)
    local originalPoints={}
    for key,check in pairs(frame.checks) do originalPoints[key]={check:GetPoint()} end
    local function Pending()
        local labels={}
        for key in pairs(reloadSettings) do
            if (EraUI:GetSavedSetting(key) and true or false)~=frame.loadedSettings[key] then
                labels[#labels+1]=key=="darkMode" and "Appearance" or (frame.checks[key] and frame.checks[key].text:GetText() or key)
            end
        end
        table.sort(labels)
        return labels
    end
    -- Appearance only changes the theme; it never overwrites feature/QoL choices.
    local appearanceButtons={}
    local function Choice(label, description, column, callback)
        local button=SetupButton(label,-24,330)
        button:ClearAllPoints()
        button:SetSize(330,112)
        button.label:ClearAllPoints()
        button.label:SetPoint("TOPLEFT",18,-18)
        local detail=Text(button,description,13,true)
        detail:SetPoint("TOPLEFT",18,-46);detail:SetWidth(292)
        button:SetScript("OnClick",callback)
        button.column=column
        return button
    end
    local function PlaceChoice(button)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT",frame,"TOPLEFT",(frame.setupMode and 30 or 208)+button.column*366,-156)
    end
    RenderAppearance=function(shown)
        frame.checks.classColourBorders:SetShown(shown)
        local dark=EraUI:GetSavedSetting("darkMode")
        for i,button in ipairs(appearanceButtons) do
            PlaceChoice(button);button:SetShown(shown)
            local selected=(i==2)==not not dark
            local r,g,b=ClassColour()
            if selected then
                button:SetBackdropColor(r*.26,g*.26,b*.26,1)
                button:SetBackdropBorderColor(r,g,b,1)
                button.label:SetTextColor(r,g,b,1)
            else
                button:SetBackdropColor(.075,.078,.085,1)
                button:SetBackdropBorderColor(.25,.27,.3,1)
                button.label:SetTextColor(.7,.72,.76,1)
            end
            button.label:SetText((selected and "Selected: " or "")..(i==1 and "Classic" or "Dark Mode"))
        end
    end
    local function ChooseAppearance(dark)
        EraUI:SetSetting("darkMode",dark)
        RenderAppearance(true);UpdateReloadHint(frame)
    end
    appearanceButtons[1]=Choice("Classic","Original Classic artwork. Requires a reload when switching styles.",0,function()ChooseAppearance(false)end)
    appearanceButtons[2]=Choice("Dark Mode","Darker decorative artwork. Character, party and raid frames stay unchanged. Reload to apply.",1,function()ChooseAppearance(true)end)

    -- Reuse the actual controls so search preserves their normal actions and dependencies.
    local search = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    frame.searchBox=search
    search:SetSize(440,28);search:SetPoint("TOPLEFT",208,-96)
    search:SetAutoFocus(false);search:SetMaxLetters(80)
    search:SetFont(select(1,GameFontHighlight:GetFont()),13,"")
    search:SetTextInsets(9,9,0,0)
    search:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    search:SetBackdropColor(.06,.065,.075,1);search:SetBackdropBorderColor(.25,.27,.3,1)
    local placeholder=Text(search,"Search settings...",13,true)
    placeholder:SetPoint("LEFT",9,0)
    local results=Text(frame,"",12,true);results:SetPoint("LEFT",search,"RIGHT",12,0)
    local page=1
    local prev=SetupButton("<",-24,28);prev:ClearAllPoints();prev:SetSize(28,28);prev:SetPoint("TOPLEFT",856,-96)
    local next=SetupButton(">",-24,28);next:ClearAllPoints();next:SetSize(28,28);next:SetPoint("TOPLEFT",892,-96)
    local clearing=false
    local function RestorePoints()
        for key,check in pairs(frame.checks) do
            check:ClearAllPoints();check:SetPoint(unpack(originalPoints[key]))
        end
    end
    ResetSearch=function()
        clearing=true;search:SetText("");search:ClearFocus();clearing=false
        placeholder:Show();results:SetText("");prev:Hide();next:Hide();page=1
        if not frame.setupMode then RestorePoints() end
    end
    ApplySearch=function()
        if frame.setupMode then return end
        local query=string.lower(search:GetText() or ""):match("^%s*(.-)%s*$")
        placeholder:SetShown(query=="")
        if query=="" then
            RestorePoints();results:SetText("");prev:Hide();next:Hide()
            SelectCategory(frame.selectedCategory or 1,true);return
        end
        RenderAppearance(false)
        local matches={}
        for key,check in pairs(frame.checks) do
            check:Hide()
            local text=(check.searchText or string.lower(key.." reward profile specialization stats")).." "..string.lower(categories[check.category][1])
            local matched=check.classAllowed~=false
            for word in query:gmatch("%S+") do
                if not text:find(word,1,true) then matched=false;break end
            end
            if matched then matches[#matches+1]={key=key,check=check} end
        end
        table.sort(matches,function(a,b)
            if a.check.category~=b.check.category then return a.check.category<b.check.category end
            return a.key<b.key
        end)
        local pages=math.max(1,math.ceil(#matches/10));page=math.min(page,pages)
        section:SetText("Search results")
        for _,tab in ipairs(tabs) do
            tab.underline:Hide();tab.selected:SetColorTexture(0,0,0,0);tab.text:SetTextColor(.58,.62,.68)
        end
        results:SetText(#matches==0 and "No matching settings" or (#matches.." found  |  "..page.." / "..pages))
        prev:SetShown(pages>1);next:SetShown(pages>1);prev:SetEnabled(page>1);next:SetEnabled(page<pages)
        for i=(page-1)*10+1,math.min(page*10,#matches) do
            local check=matches[i].check;local slot=(i-1)%10
            check:ClearAllPoints();check:SetPoint("TOPLEFT",202+(slot%2)*366,-148-math.floor(slot/2)*78);check:Show()
        end
    end
    search:SetScript("OnTextChanged",function()if not clearing then page=1;ApplySearch() end end)
    search:SetScript("OnEscapePressed",function()ResetSearch();SelectCategory(frame.selectedCategory or 1,true)end)
    search:SetScript("OnEnterPressed",function(self)self:ClearFocus()end)
    prev:SetScript("OnClick",function()page=page-1;ApplySearch()end)
    next:SetScript("OnClick",function()page=page+1;ApplySearch()end)

    local qos={3,7,8,9,10,5}
    local finalPage=#qos+3
    local yes=Choice("Yes, choose my options","Pick what to turn on. Nothing gets enabled for you.",0,function()
        frame.setupQoL=true;frame.setupPage=3;frame:RenderSetup()
    end)
    local skip=Choice("Skip","Keep your settings as they are.",1,function()
        frame.setupQoL=false;frame.setupPage=finalPage;frame:RenderSetup()
    end)
    function frame:RenderSetup()
        local final=self.setupPage==finalPage
        for _,check in pairs(self.checks) do check:Hide() end
        RenderAppearance(false);yes:Hide();skip:Hide();setupSummary:Hide()
        navigation:Hide();divider:Hide()
        if self.setupPage==1 then
            section:SetText("Choose your style");RenderAppearance(true)
        elseif self.setupPage==2 then
            section:SetText("Everyday helpers")
            setupSummary:SetText("Want to pick your convenience options?")
            setupSummary:ClearAllPoints();setupSummary:SetPoint("TOPLEFT",30,-128);setupSummary:Show()
            PlaceChoice(yes);PlaceChoice(skip);yes:Show();skip:Show()
        elseif not final then
            SelectCategory(qos[self.setupPage-2])
            -- Keep visual skins out, but include chat dragging even though its
            -- native tab handlers need a reload to change ownership.
            for key,check in pairs(self.checks) do
                if reloadSettings[key] and key~="classicChatDragging" then check:Hide() end
            end
        else
            section:SetText("You're ready")
            local pending=Pending()
            self.setupNeedsReload=#pending>0
            local message="All saved. The rest of the settings are here when you want them.\n\nCasting: advanced cast bar, class borders, ticks and latency.\n"..className..": resource bars and class tools.\nEverything else is in the other categories.\n\n/era opens this window any time."
            if #pending>0 then
                message=message.."\n\nReload to apply these changes, then settings will open:\n\n"..table.concat(pending,", ")
            else message=message.."\n\nNo reload needed. Continue to explore the settings." end
            setupSummary:ClearAllPoints();setupSummary:SetPoint("TOPLEFT",30,-156)
            setupSummary:SetText(message);setupSummary:Show()
        end
        for _,tab in ipairs(tabs) do tab:Hide() end
        nextPage.label:SetText(final and (self.setupNeedsReload and "Reload & explore" or "Explore settings") or "Next >")
        nextPage:SetShown(self.setupPage~=2)
        previousPage:Show()
        setupProgress:SetText(final and "FINISH" or (self.setupPage==1 and "APPEARANCE" or self.setupPage==2 and "QUALITY OF LIFE" or "OPTIONS  "..(self.setupPage-2).." / "..#qos))
        setupProgress:Show();UpdateReloadHint(self)
    end
    function frame:SetSetupMode(enabled)
        ResetSearch()
        search:SetShown(not enabled)
        self.setupMode=enabled
        self:SetWidth(enabled and 800 or 960)
        self:SetScale(math.min(1,math.max(.1,(UIParent:GetWidth()-32)/self:GetWidth()),math.max(.1,(UIParent:GetHeight()-32)/650)))
        section:ClearAllPoints()
        section:SetPoint("TOPLEFT",enabled and 30 or 208,enabled and -84 or -38)
        for key,check in pairs(self.checks) do
            local point=originalPoints[key]
            check:ClearAllPoints()
            if enabled then check:SetPoint(point[1],point[2],point[3],point[4]-172,point[5])
            else check:SetPoint(unpack(point)) end
        end
        hint:SetWidth(enabled and 330 or 560)
        if enabled then
            self.setupPage=1
            self:RenderSetup()
        else
            navigation:Show();divider:Show()
            for _,tab in ipairs(tabs) do tab:Show() end
            yes:Hide();skip:Hide()
            setupSummary:Hide();setupProgress:Hide();nextPage:Hide();previousPage:Hide()
            SelectCategory(self.selectedCategory or 1)
            UpdateReloadHint(self)
        end
    end
    local function FinishSetup(reloadNow)
        if reloadNow and InCombatLockdown() then hint:SetText("Finish combat before reloading.");return end
        if EraUI.Classic and EraUI.Classic.db then
            if EraUI.Classic.CompleteCharacterSetup then EraUI.Classic.CompleteCharacterSetup() end
            EraUI.Classic.db.erauiSetupComplete=true
            EraUI.Classic.MirrorSave()
        end
        EraUIClassicCharDB=EraUIClassicCharDB or {}
        EraUIClassicCharDB.onboarding=EraUIClassicCharDB.onboarding or {}
        EraUIClassicCharDB.onboarding.exploreSettings=true
        EraUIClassicCharDB.onboarding.discoverTabs={[12]=true,[13]=true}
        EraUIClassicCharDB.onboarding.discoveryHintsVersion=1
        if EraUI.SaveCharOnboarding then EraUI.SaveCharOnboarding() end
        -- Keep the click path direct: do not rebuild/hide the settings window
        -- before the client receives the reload request.
        if reloadNow then ReloadUI();return end
        frame:SetSetupMode(false)
        frame.selectedCategory=1
        SelectCategory(1)
        frame:Show()
        EraUIClassicCharDB.onboarding.exploreSettings=nil
        if EraUI.SaveCharOnboarding then EraUI.SaveCharOnboarding() end
        EraUI:Print("Casting and your class tab have more. /era opens settings any time.")
    end
    nextPage:SetScript("OnClick",function()
        if frame.setupPage==finalPage then FinishSetup(#Pending()>0)
        else frame.setupPage=frame.setupPage+1;frame:RenderSetup() end
    end)
    previousPage:SetScript("OnClick",function()
        if frame.setupPage==1 then
            frame:Hide();frame:SetSetupMode(false)
            EraUI.Classic.setupRequested=true;EraUI.Classic.ShowWelcome();return
        end
        frame.setupPage=(frame.setupPage==finalPage and not frame.setupQoL) and 2 or frame.setupPage-1
        frame:RenderSetup()
    end)

    local function Refresh()
        frame:RefreshCastDependencies()
        for key, check in pairs(frame.checks) do
            local checked = EraUI:GetSavedSetting(key) and true or false
            
            check:SetChecked(not check.unavailable and checked)
            if check.unavailable then check.state:SetText("SOON") end
        end
        local r, g, b = ClassColour()
        reload:SetBackdropColor(r * 0.22, g * 0.22, b * 0.22, 1)
        reload:SetBackdropBorderColor(r, g, b, 1)
        SelectCategory(frame.selectedCategory or 1,true)
        ApplySearch()
        UpdateReloadHint(frame)
        if frame.setupMode then frame:RenderSetup() end
    end
    -- Inherit the chosen UI scale; shrink only if the window would exceed the screen.
    local function FitToScreen()
        frame:SetScale(math.min(1, math.max(0.1, (UIParent:GetWidth() - 32) / frame:GetWidth()),
            math.max(0.1, (UIParent:GetHeight() - 32) / 650)))
    end
    frame:SetScript("OnShow", function() FitToScreen(); Refresh() end)
    frame:RegisterEvent("UI_SCALE_CHANGED")
    frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    frame:SetScript("OnEvent", function() if frame:IsShown() then FitToScreen() end end)
    Refresh()

    self.frame = frame
    EraUI.settingsFrame = frame
end



function SettingsModule:OpenSetup()
    if not self.frame then self:Initialize() end
    self.frame:SetSetupMode(true)
    self.frame:Show()
end

function SettingsModule:OpenSettings()
    if not self.frame then self:Initialize() end
    local wasSetup=self.frame.setupMode
    self.frame:SetSetupMode(false)
    if wasSetup then self.frame:Show()
    else self.frame:SetShown(not self.frame:IsShown()) end
end


-- Explicit show avoids the normal /era toggle closing an already open window.
function SettingsModule:ShowSettings()
    if not self.frame then self:Initialize() end
    self.frame.selectedCategory=1
    self.frame:SetSetupMode(false)
    self.frame:Show()
end

