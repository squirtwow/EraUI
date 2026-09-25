local ADDON, EraUI = ...
local ns = EraUI.Classic

-- One addon, two internal concerns: the skinning layer owns presentation;
-- EraUI owns user preferences and the independent QoL modules.
local mapping = {
    classicBar="actionBars", buttons="actionBars", castAnim="actionBars",
    castBars="castBars", mirrorTimers="castBars", unitFrames="unitFrames",
    comboPoints="unitFrames", minimap="minimap", characterSheet="characterPanel",
    talents="talentWindow", spellBook="spellbook", spellDrag="spellbookCombatDrag", questTracker="questTracker",
    questLog="questLog", questMapPane="questLog", bags="bagsBank",
    professionsBook="professions", tradeSkill="professions", trainer="trainer",
    guildRoster="socialWindows", whoList="socialWindows", groupFinder="groupFinderPvp",
    gameMenu="gameMenu", settingsPanel="blizzardSettings",
}
EraUI.classicMapping = mapping
ns.DB_DEFAULTS.erauiMigrated = false
ns.DB_DEFAULTS.erauiWelcomeSeen = false
ns.DB_DEFAULTS.erauiSetupComplete = false
ns.DB_DEFAULTS.erauiSettingsMenuMigrated = false
ns.DB_DEFAULTS.erauiNumericSettingsMirrored = false
for key, value in pairs(EraUI.settingDefaults) do
    if type(value) == "boolean" or type(value) == "number" then ns.DB_DEFAULTS["eraui_"..key] = value end
end
ns.DB_DEFAULTS.eraui_showAllSpellRanks = false

local function Sync()
    if not ns.db then return end
    for native, setting in pairs(mapping) do ns.db[native] = EraUI:GetSetting(setting) ~= false end
    if EraUI:GetSetting("floatingComboPoints") then ns.db.comboPoints=true end
    ns.db.namePlates = EraUI:GetSetting("friendlyNameplates") or EraUI:GetSetting("enemyNameplates")
    ns.db.emptySlots = EraUI:GetSetting("hideEmptyActionSlots") == true
    ns.db.spellBookTopRank = not EraUI:GetSavedSetting("showAllSpellRanks")
    ns.db.hideLastNames = EraUI:GetSetting("hideSecondaryNames") == true -- EraUI owns application.
    ns.db.minimapButton = false -- MinimapTools.lua supplies the EraUI button.
end
local mirrorSave = ns.MirrorSave
function ns.MirrorSave()
    if ns.db and EraUIDB then
        ns.db.erauiNumericSettingsMirrored=true
        for key, value in pairs(EraUIDB) do
            if type(value) == "boolean" or (type(value) == "number" and type(EraUI.settingDefaults[key]) == "number") then
                local mirrorKey = "eraui_"..key
                if ns.DB_DEFAULTS[mirrorKey] == nil then ns.DB_DEFAULTS[mirrorKey] = not value end
                ns.db[mirrorKey] = value
            end
        end
    end
    return mirrorSave()
end
local apply = ns.ApplyAll
function ns.ApplyAll()
    Sync()
    return apply()
end
function EraUI:SyncClassicQoL()
    Sync()
    ns.QueueApply()
end

-- Keep the skinning layer's visual toggles native; extend the same menu with QoL.
local function ToggleFeedback(key)
    local label = key
    for _, entry in ipairs(ns.TOGGLES) do
        if entry[1] == key then label = entry[2]:gsub("^QoL: ", ""); break end
    end
    local message = label .. (ns.db[key] and " enabled." or " disabled.")
    if key == "eraui_autoSellJunk" or key == "eraui_autoRepair" then
        message = message .. " Applies on your next merchant visit."
    elseif key == "eraui_vendorPrice" then
        message = message .. " Applies on your next item hover."
    elseif key == "eraui_classColors" then
        message = message .. " Applies to new chat messages."
    elseif ns.RELOAD_KEYS[key] and not ns.db[key] then
        message = message .. " Reload UI to finish applying this change."
    end
    if key == "eraui_hideStatusMessages" then EraUI:Print(message)
    else EraUI:Status(message) end
end

local toggle = ns.ToggleChanged
function ns.ToggleChanged(key)
    local setting = key:match("^eraui_(.+)$")
    if setting then
        EraUI:SetSetting(setting, ns.db[key] == true)
        local qol, map = EraUI.modules.QoL, EraUI.modules.MinimapTools
        if setting == "coordinates" and map then map:UpdateCoordinates()
        elseif setting == "cleanMinimap" and map then map:Discover(); map:Refresh()
        elseif setting == "bagSpace" and qol then qol:UpdateBagSpace()
        elseif setting == "questLevels" and qol then qol:RefreshQuestLevels()
        elseif setting == "classColors" and qol then qol:ApplyChatClassColors()
        elseif setting == "gryphons" or setting == "disableAggroHighlight" then ns.QueueApply()
        elseif setting == "comboPointRed" then
            if ns.RefreshComboPointColor then ns.RefreshComboPointColor() end
        elseif setting == "movableMap" then
            if EraUI.modules.MovableMap then EraUI.modules.MovableMap:Apply() end
        end
        ns.MirrorSave()
        ToggleFeedback(key)
        return
    end
    if key == "emptySlots" then EraUI:SetSetting("hideEmptyActionSlots", ns.db.emptySlots) end
    if key == "hideLastNames" then
        EraUI:SetSetting("hideSecondaryNames",ns.db.hideLastNames)
        local names = EraUI.modules.SecondaryNames
        if names then names:Apply() end
    end
    if key == "spellBookTopRank" then
        if InCombatLockdown() then Sync(); return end
        SetCVar("ShowAllSpellRanks", ns.db.spellBookTopRank and "0" or "1")
        EraUI:SetSetting("showAllSpellRanks",not ns.db.spellBookTopRank)
    end
    toggle(key)
    ToggleFeedback(key)
end

-- Existing EraUI QoL callbacks delegate to the single action-bar owner.
EraUI:RegisterModule("ActionBars", {
    RefreshEmptySlots=function() EraUI:SyncClassicQoL() end,
    ApplyGryphons=function() EraUI:SyncClassicQoL() end,
})
local qolOptions = {
    {"vendorPrice", "QoL: Vendor prices", "Add missing selling prices to item tooltips."},
    {"bagSpace", "QoL: Bag space", "Show free slots on the backpack."},
    {"questLevels", "QoL: Quest levels", "Show levels on tracked quests."},
    {"cleanMinimap", "QoL: Clean minimap", "Hide supported addon buttons until hover; native controls stay visible."},
    {"coordinates", "QoL: Coordinates", "Show your map position beneath the minimap."},
    {"autoSellJunk", "QoL: Sell junk", "Sell grey items on your next merchant visit."},
    {"autoRepair", "QoL: Auto repair", "Repair using your own money on your next repair-vendor visit."},
    {"classColors", "QoL: Chat class colours", "Colour player names by class in new chat messages."},
    {"gryphons", "QoL: Gryphons", "Show the Classic action-bar end caps."},
    {"comboPointRed", "QoL: Red combo points", "Draw the floating combo point orbs red instead of gold."},
    {"movableMap", "QoL: Movable world map", "Drag the world map by its edge and resize it from the corners."},
    {"disableAggroHighlight", "QoL: Hide aggro flash", "Hide the player and target frame aggro flash."},
    {"hideStatusMessages", "QoL: Quiet startup", "Hide EraUI status notices; errors and command replies remain visible."},
}
for _, entry in ipairs(qolOptions) do
    ns.TOGGLES[#ns.TOGGLES+1] = {"eraui_"..entry[1], entry[2], entry[3]}
end

-- Reuse the approved EraUI settings presentation; visual application stays in Classic.
ns.OpenDetailedOptions = ns.OpenOptions
function ns.OpenOptions()
    local module = EraUI.modules.Settings
    if not module then return end
    module:OpenSettings()
end
local setSetting = EraUI.SetSetting
function EraUI:SetSetting(key, value)
    setSetting(self, key, value)
    if ns.db then ns.MirrorSave() end
end
function ns.PlateAllowed(frame)
    if not frame or not frame.unit then return false end
    local friend = UnitIsFriend("player", frame.unit)
    if issecretvalue and issecretvalue(friend) then return false end
    return EraUI:GetSetting(friend and "friendlyNameplates" or "enemyNameplates")
end
local windowSettings = {
    CharacterFrame="characterPanel", PaperDollFrame="characterPanel",
    MerchantFrame="merchantSkin", MailFrame="mailSkin", OpenMailFrame="mailSkin", SendMailFrame="mailSkin",
    AuctionHouseFrame="auctionHouse", BankFrame="bagsBank", BankPanel="bagsBank", GuildBankFrame="bagsBank",
    QuestFrame="questDialogs", GossipFrame="questDialogs", LootFrame="lootWindow",
    ClassTrainerFrame="trainer", ProfessionsFrame="professions", ProfessionsBookFrame="professions",
    FriendsFrame="socialWindows", CommunitiesFrame="socialWindows", PVPUIFrame="groupFinderPvp",
    PVPFrame="groupFinderPvp", LFGListFrame="groupFinderPvp",
}
function ns.WindowAllowed(frame)
    local name = frame and frame.GetName and frame:GetName()
    local key = name and windowSettings[name]
    return not key or EraUI:GetSetting(key) ~= false
end

local welcome, waitingForCombat
local initialLogin = false
local welcomeChecked = false
local function CharacterWelcome()
    EraUIClassicCharDB = EraUIClassicCharDB or {}
    EraUIClassicCharDB.onboarding = EraUIClassicCharDB.onboarding or {}
    return EraUIClassicCharDB.onboarding
end
-- The Forever client does not reliably restore per-character SavedVariables,
-- so the onboarding state (welcome seen, setup complete) is mirrored into a
-- CVar keyed by character and read back at load.
local ONBOARD_CVAR = "EraUIOnboarding"
if C_CVar and C_CVar.RegisterCVar then
    C_CVar.RegisterCVar(ONBOARD_CVAR, "")
end
local function CharKey()
    if UnitFullName then
        local ok, name = pcall(UnitFullName, "player")
        if ok and name and not (issecretvalue and issecretvalue(name)) then return name end
    end
    local ok, name = pcall(UnitName, "player")
    return ok and name or "?"
end
local function SerializeOnboarding(state)
    local flags = (state.welcomeSeen and "1" or "0")
        .. (state.setupComplete and "1" or "0")
        .. (state.exploreSettings and "1" or "0")
    local version = tostring(state.discoveryHintsVersion or 0)
    local tabs = {}
    for k in pairs(state.discoverTabs or {}) do tabs[#tabs + 1] = tostring(k) end
    table.sort(tabs)
    return flags .. "," .. version .. "," .. table.concat(tabs, ".")
end
local function SaveCharOnboarding()
    if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return end
    local key = CharKey()
    local existing = {}
    local text = C_CVar.GetCVar(ONBOARD_CVAR) or ""
    for entry in text:gmatch("[^;]+") do
        local k, payload = entry:match("^(.-):(.*)$")
        if k and payload then existing[k] = payload end
    end
    existing[key] = SerializeOnboarding(CharacterWelcome())
    local parts = {}
    for k, payload in pairs(existing) do parts[#parts + 1] = k .. ":" .. payload end
    table.sort(parts)
    pcall(C_CVar.SetCVar, ONBOARD_CVAR, table.concat(parts, ";"))
end
EraUI.SaveCharOnboarding = SaveCharOnboarding
local function LoadCharOnboarding()
    if not (C_CVar and C_CVar.GetCVar) then return end
    local key = CharKey()
    local text = C_CVar.GetCVar(ONBOARD_CVAR) or ""
    for entry in text:gmatch("[^;]+") do
        local k, payload = entry:match("^(.-):(.*)$")
        if k == key and payload then
            local flags, version, tabs = payload:match("^([01][01][01]),(%d+),(.*)$")
            if flags then
                local state = CharacterWelcome()
                state.welcomeSeen = flags:sub(1, 1) == "1"
                state.setupComplete = flags:sub(2, 2) == "1"
                state.exploreSettings = flags:sub(3, 3) == "1"
                state.discoveryHintsVersion = tonumber(version)
                local tabMap = {}
                for tab in tabs:gmatch("[^.]+") do
                    tabMap[tonumber(tab)] = true
                end
                state.discoverTabs = tabMap
            end
            return
        end
    end
end
function ns.CharacterSetupComplete()
    return CharacterWelcome().setupComplete == true
end
function ns.CompleteCharacterSetup()
    local state = CharacterWelcome()
    state.welcomeSeen = true
    state.setupComplete = true
    SaveCharOnboarding()
end
local function OpenQoL()
    ns.OpenOptions()
end
function ns.ShowWelcome()
    if InCombatLockdown() then waitingForCombat=true; return end
    if not welcome then
        welcome = CreateFrame("Frame", "EraUIWelcome", UIParent, "BackdropTemplate")
        welcome:SetSize(640, 420)
        welcome:SetPoint("CENTER")
        welcome:SetFrameStrata("DIALOG")
        welcome:SetClampedToScreen(true)
        welcome:EnableMouse(true)
        welcome:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",
            edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        welcome:SetBackdropColor(.026,.029,.037,1)
        welcome:SetBackdropBorderColor(.19,.20,.24,1)
        local _, class=UnitClass("player")
        local colour=(CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
        local r,g,b=.7,.7,.7
        if colour then r,g,b=colour.r,colour.g,colour.b end
        local function Label(value,size,x,y,width,muted)
            local text=welcome:CreateFontString(nil,"OVERLAY")
            local font,_,flags=GameFontHighlight:GetFont()
            text:SetFont(font,size,flags or "")
            text:SetTextColor(muted and .58 or .94,muted and .62 or .95,muted and .68 or .98)
            text:SetJustifyH("LEFT")
            text:SetPoint("TOPLEFT",x,y)
            if width then text:SetWidth(width) end
            text:SetText(value)
            return text
        end
        local stripe=welcome:CreateTexture(nil,"ARTWORK")
        stripe:SetPoint("TOPLEFT",1,-1);stripe:SetPoint("TOPRIGHT",-1,-1);stripe:SetHeight(3)
        stripe:SetColorTexture(r,g,b,1)
        local panel=welcome:CreateTexture(nil,"BACKGROUND")
        panel:SetPoint("TOPLEFT",1,-4);panel:SetSize(306,314)
        panel:SetColorTexture(.014,.016,.022,1)
        local eyebrow=Label("WELCOME TO",11,28,-30,nil,true)
        eyebrow:SetTextColor(r,g,b)
        Label("EraUI",42,26,-54)
        Label("Classic UI,\nthe way you remember it.",20,28,-117,255)
        Label("Old-school looks, with modern conveniences bolted on.",13,28,-180,250,true)
        Label("Every piece is optional - turn any of it off.",13,28,-250,250)
        local shortcut=Label("Settings are always one /era away.",11,28,-276,255,true)
        shortcut:SetTextColor(r,g,b)
        local function Feature(y,icon,title,description)
            local image=welcome:CreateTexture(nil,"ARTWORK")
            image:SetSize(28,28);image:SetPoint("TOPLEFT",330,y)
            image:SetTexture("Interface\\Icons\\"..icon)
            image:SetTexCoord(.07,.93,.07,.93)
            Label(title,14,370,y,235)
            Label(description,12,370,y-24,235,true)
        end
        Feature(-50,"INV_Helmet_03","The Classic look","Old bars, frames and windows - pick which ones.")
        Feature(-135,"INV_Misc_Map_01","Handy extras","Auto-loot, auto-repair, coordinates and other small helpers.")
        Feature(-220,"INV_Misc_Gear_01","Set it up your way","Every toggle is yours - change it any time.")
        local line=welcome:CreateTexture(nil,"ARTWORK")
        line:SetPoint("TOPLEFT",24,-320);line:SetPoint("TOPRIGHT",-24,-320);line:SetHeight(1)
        line:SetColorTexture(.14,.15,.18,1)
        local function Button(text,width,x,primary)
            local button=CreateFrame("Button",nil,welcome,"BackdropTemplate")
            button:SetSize(width,34);button:SetPoint("BOTTOMRIGHT",x,42)
            button:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
            local function Paint(hover)
                button:SetBackdropColor(primary and r*.25 or .045,primary and g*.25 or .05,primary and b*.25 or .065,1)
                button:SetBackdropBorderColor(hover and r or (primary and r*.65 or .22),hover and g or (primary and g*.65 or .23),hover and b or (primary and b*.65 or .27),1)
            end
            local label=button:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            label:SetPoint("CENTER");label:SetText(text)
            Paint(false)
            button:SetScript("OnEnter",function()Paint(true)end)
            button:SetScript("OnLeave",function()Paint(false)end)
            return button
        end
        local settings=Button("Make it yours",152,-24,true)
        settings:SetScript("OnClick",function()
            welcome:Hide()
            local module=EraUI.modules.Settings
            if module then
                if ns.setupRequested or not ns.CharacterSetupComplete() then
                    ns.setupRequested = false
                    module:OpenSetup()
                else module:OpenSettings() end
            end
        end)
        local close=Button("Let's play",104,-188,false)
        close:SetScript("OnClick",function()welcome:Hide()end)
        local login=CreateFrame("CheckButton",nil,welcome)
        login:SetSize(18,18);login:SetPoint("BOTTOMLEFT",28,51)
        local box=login:CreateTexture(nil,"BACKGROUND");box:SetAllPoints();box:SetColorTexture(.15,.16,.19,1)
        local check=login:CreateTexture(nil,"ARTWORK");check:SetPoint("TOPLEFT",3,-3);check:SetPoint("BOTTOMRIGHT",-3,3);check:SetColorTexture(r,g,b,1)
        login:SetCheckedTexture(check)
        local caption=login:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        caption:SetPoint("LEFT",login,"RIGHT",8,0);caption:SetText("Show on login");caption:SetTextColor(.58,.62,.68)
        login:SetScript("OnClick",function(self)EraUI:SetSetting("showWelcomeOnLogin",self:GetChecked() and true or false)end)
        local signature=Label("Made with |TInterface\\AddOns\\EraUI\\Media\\Heart:10:10:0:0|t by Squirt",10,28,-394,nil,true)
        signature:SetTextColor(.48,.49,.52)
        local dismiss=CreateFrame("Button",nil,welcome)
        dismiss:SetSize(28,28);dismiss:SetPoint("TOPRIGHT",-10,-10)
        local cross=dismiss:CreateFontString(nil,"OVERLAY","GameFontHighlight");cross:SetPoint("CENTER");cross:SetText("X");cross:SetTextColor(.58,.62,.68)
        dismiss:SetScript("OnClick",function()welcome:Hide()end)
        welcome:SetScript("OnShow",function()
            welcome:SetScale(math.min(1,math.max(.1,(UIParent:GetWidth()-32)/640),math.max(.1,(UIParent:GetHeight()-32)/420)))
            login:SetChecked(EraUI:GetSetting("showWelcomeOnLogin") and true or false)
        end)
        welcome:SetScript("OnHide",function()
            CharacterWelcome().welcomeSeen=true
            ns.db.erauiWelcomeSeen=true
            ns.MirrorSave()
            SaveCharOnboarding()
        end)
        table.insert(UISpecialFrames,"EraUIWelcome")
    end
    welcome:Show()
end
local firstRun=ns.FirstRun
function ns.FirstRun()
    if not EraUI:GetSetting("enabled") then return end
    if CharacterWelcome().exploreSettings then
        welcomeChecked=true
        if InCombatLockdown() then return end
        local settings=EraUI.modules.Settings
        if settings and settings.ShowSettings then
            settings:ShowSettings()
            CharacterWelcome().exploreSettings=nil
            SaveCharOnboarding()
            EraUI:Print("Explore Casting and your class section for more options. Open EraUI settings anytime with /era.")
        end
        return
    end
    if not welcomeChecked then
        if initialLogin or not CharacterWelcome().welcomeSeen then
            EraUI:Status("Open EraUI settings anytime by typing /era in chat.")
        end
        welcomeChecked = true
        if not CharacterWelcome().welcomeSeen or (initialLogin and EraUI:GetSetting("showWelcomeOnLogin")) then
            ns.ShowWelcome()
        end
    end
    -- Retain the native-layout selection/check machinery and its link.
    ns.db.welcomeNote=false
    firstRun()
end

local loader=CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent",function(_,event,name)
    if event=="PLAYER_ENTERING_WORLD" then initialLogin = name == true; return end
    if event=="PLAYER_REGEN_ENABLED" then
        if CharacterWelcome().exploreSettings then ns.FirstRun();return end
        if waitingForCombat then waitingForCombat=false;ns.ShowWelcome() end
        return
    end
    if name~=ADDON or not ns.db then return end
    -- Per-character onboarding state (welcome seen, setup complete) is kept
    -- in a CVar because this client does not reliably restore its per-character
    -- SavedVariables.
    LoadCharOnboarding()
    -- The skinning layer's mirror has already loaded; recover EraUI scalar choices
    -- on Forever clients which do not reliably restore SavedVariables.
    if ns.db.erauiMigrated then
        for key in pairs(EraUI.settingDefaults) do
            local saved=ns.db["eraui_"..key]
            if type(saved)==type(EraUI.settingDefaults[key]) and (type(saved)=="boolean" or type(saved)=="number" and ns.db.erauiNumericSettingsMirrored) then EraUIDB[key]=saved end
        end
    else
        -- These switches were disabled Later placeholders in the old UI, not
        -- usable opt-outs. The skinning layer now supplies them.
        for _,key in ipairs({"questLog","bagsBank","merchantSkin","mailSkin","auctionHouse","groupFinderPvp","blizzardSettings"}) do
            EraUIDB[key]=true
        end
        ns.db.erauiMigrated=true
    end
    if not ns.db.erauiSettingsMenuMigrated then
        -- Import the active visual choices once, before the settings menu owns them.
        local grouped = {}
        for native, setting in pairs(mapping) do
            if grouped[setting] == nil then grouped[setting] = true end
            grouped[setting] = grouped[setting] and ns.db[native] ~= false
        end
        for key,value in pairs(grouped) do EraUIDB[key] = value end
        EraUIDB.friendlyNameplates = ns.db.namePlates ~= false
        EraUIDB.enemyNameplates = ns.db.namePlates ~= false
        EraUIDB.hideEmptyActionSlots = ns.db.emptySlots == true
        EraUIDB.showAllSpellRanks = not ns.db.spellBookTopRank
        ns.db.erauiSettingsMenuMigrated = true
    end
    for key in pairs(EraUI.reloadSettings) do EraUI.loadedVisualSettings[key]=EraUIDB[key] end
    Sync()
end)
