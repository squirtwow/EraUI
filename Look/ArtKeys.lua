-- The 1.x art by name, for the files kept from before the rewrite (Thick
-- Frames, the raid-style Party Outline, the damage meter skin) and Modules/
-- (the minimap drawer's tracking ring, Portrait Debuffs' round mask): each
-- name gives the game's own file and EraUI's copy in Media/Classic, the
-- fallback between them, and Dark Mode's tint under the same name
-- (Core/Appearance.lua darkens only the frame art among them). The Look/
-- files keep their own art table (Look.ART, Look/Base.lua); both record
-- what was set in Look.artResults for /eraui-classic debug.
local _, EraUI = ...
local ns, Look = EraUI.Classic, EraUI.Look

-- name: { first file, second file, EraUI's copy first }
local TEX = {}
ns.TEX = TEX

local function Copy(file)
    return Look.MEDIA .. file
end

-- The game's file in folder, and EraUI's copy of the same name (or another
-- name on disk).
local function FromFolder(folder, list, bundledFirst)
    for pair in list:gmatch("%S+") do
        local key, file, copy = pair:match("^(%w+):([^:]+):?(.*)$")
        TEX[key] = { folder .. file, Copy(copy ~= "" and copy or file), bundledFirst == true }
    end
end

-- Pieces that only EraUI's copy gets right (the client ships a stand-in or
-- a wider redraw): the copy both ways.
local function CopyOnly(list)
    for pair in list:gmatch("%S+") do
        local key, file = pair:match("^(%w+):(.+)$")
        TEX[key] = { Copy(file), Copy(file), true }
    end
end

FromFolder("Interface\\MainMenuBar\\", [[endCap:UI-MainMenuBar-EndCap-Dwarf barBody:UI-MainMenuBar-Dwarf
    barKeyring:UI-MainMenuBar-KeyRing maxLevel:UI-MainMenuBar-MaxLevel performanceBar:UI-MainMenuBar-PerformanceBar]])
FromFolder("Interface\\TargetingFrame\\", [[statusBar:UI-StatusBar targetingFrame:UI-TargetingFrame
    targetingElite:UI-TargetingFrame-Elite targetingRare:UI-TargetingFrame-Rare targetingRareElite:UI-TargetingFrame-Rare-Elite
    targetingMinus:UI-TargetingFrame-Minus targetingFlash:UI-TargetingFrame-Flash
    targetingMinusFlash:UI-TargetingFrame-Minus-Flash levelBackground:UI-TargetingFrame-LevelBackground
    skull:UI-TargetingFrame-Skull targetOfTarget:UI-TargetofTargetFrame smallTargetingFrame:UI-SmallTargetingFrame
    partyFrame:UI-PartyFrame partyFlash:UI-PartyFrame-Flash petAttackStatus:UI-Player-AttackStatus
    questBadge:PortraitQuestBadge barFill:UI-TargetingFrame-BarFill lootSkull:TargetDead]])
FromFolder("Interface\\PaperDollInfoFrame\\", [[repBar:UI-ReputationWatchBar
    charGeneralTopLeft:UI-Character-General-TopLeft charGeneralTopRight:UI-Character-General-TopRight
    charGeneralBotLeft:UI-Character-General-BottomLeft charGeneralBotRight:UI-Character-General-BottomRight
    charTabTopLeft:UI-Character-CharacterTab-L1 charTabTopRight:UI-Character-CharacterTab-R1
    charTabBotLeft:UI-Character-CharacterTab-BottomLeft charTabBotRight:UI-Character-CharacterTab-BottomRight
    charStatBox:UI-Character-StatBackground charResistIcons:UI-Character-ResistanceIcons
    tabActive:UI-Character-ActiveTab tabInactive:UI-Character-InActiveTab tabHighlight:UI-Character-Tab-RealHighlight]])
FromFolder("Interface\\Buttons\\", [[slotEmpty:UI-Quickslot slotNormal:UI-Quickslot2 slotPushed:UI-Quickslot-Depress
    slotFlash:UI-QuickslotRed highlight:ButtonHilight-Square checked:CheckButtonHilight
    equippedBorder:UI-ActionButton-Border backpackIcon:Button-Backpack-Up microHighlight:UI-MicroButton-Hilight
    keyRingUp:UI-Button-KeyRing keyRingDown:UI-Button-KeyRing-Down keyRingHighlight:UI-Button-KeyRing-Highlight
    questTrackerButtons:QuestTrackerButtons roundHighlight:ButtonHilight-Round
    rotateLeftUp:UI-RotationLeft-Button-Up rotateLeftDown:UI-RotationLeft-Button-Down
    rotateRightUp:UI-RotationRight-Button-Up rotateRightDown:UI-RotationRight-Button-Down
    microCharacterUp:UI-MicroButtonCharacter-Up microCharacterDown:UI-MicroButtonCharacter-Down
    microCharacterDisabled:UI-MicroButtonCharacter-Up]])
FromFolder("Interface\\CastingBar\\", [[castBorder:UI-CastingBar-Border castBorderSmall:UI-CastingBar-Border-Small
    castSmallShield:UI-CastingBar-Small-Shield castSpark:UI-CastingBar-Spark castFlash:UI-CastingBar-Flash
    castFlashSmall:UI-CastingBar-Flash-Small]])
FromFolder("Interface\\Minimap\\", [[minimapBorder:UI-Minimap-Border minimapBackground:UI-Minimap-Background
    compassNorth:CompassNorthTag compassRing:CompassRing zoomHighlight:UI-Minimap-ZoomButton-Highlight
    trackingBorder:MiniMap-TrackingBorder]])
FromFolder("Interface\\QuestFrame\\", [[questLogBook:UI-QuestLog-BookIcon questLogTabLeft:UI-QuestLogSortTab-Left
    questLogTabMiddle:UI-QuestLogSortTab-Middle questLogTabRight:UI-QuestLogSortTab-Right
    questLogHighlight:UI-QuestLogTitleHighlight]])
FromFolder("Interface\\CharacterFrame\\", "portraitMask:TempPortraitAlphaMask stateIcon:UI-StateIcon playerStatus:UI-Player-Status")
FromFolder("Interface\\FrameGeneral\\", "frameMetal:UIFrameMetal frameMetalH:UIFrameMetalHorizontal frameMetalV:UIFrameMetalVertical")
FromFolder("Interface\\Common\\", "iconFrame:WhiteIconFrame")
FromFolder("Interface\\GroupFrame\\", "leaderIcon:UI-Group-LeaderIcon")
FromFolder("Interface\\PaperDoll\\", "bagSlotIcon:UI-PaperDoll-Slot-Bag")
FromFolder("Interface\\ComboFrame\\", "comboPoint:ComboPoint")
FromFolder("Interface\\Calendar\\", "calendarButton:UI-Calendar-Button")
FromFolder("Interface\\TimeManager\\", "clockBackground:ClockBackground")
-- The client's "no tracking" icon is no longer the glass: the copy first.
FromFolder("Interface\\Minimap\\Tracking\\", "trackingNone:None:Tracking-None", true)

-- Every state of a few button sheets: name prefix .. state, file prefix .. state.
local function States(folder, prefix, filePrefix, states)
    for state in states:gmatch("%S+") do
        FromFolder(folder, prefix .. state .. ":" .. filePrefix .. state)
    end
end
States("Interface\\Minimap\\", "zoomIn", "UI-Minimap-ZoomInButton-", "Up Down Disabled")
States("Interface\\Minimap\\", "zoomOut", "UI-Minimap-ZoomOutButton-", "Up Down Disabled")
States("Interface\\Buttons\\", "close", "UI-Panel-MinimizeButton-", "Up Down Disabled Highlight")
States("Interface\\Buttons\\", "bigger", "UI-Panel-BiggerButton-", "Up Down Disabled")
States("Interface\\Buttons\\", "smaller", "UI-Panel-SmallerButton-", "Up Down Disabled")
States("Interface\\MainMenuBar\\", "arrowUp", "UI-MainMenu-ScrollUpButton-", "Up Down Disabled Highlight")
States("Interface\\MainMenuBar\\", "arrowDown", "UI-MainMenu-ScrollDownButton-", "Up Down Disabled Highlight")

CopyOnly([[statusBarFlat:UI-StatusBar-Flat.tga nameplateBorder:Nameplate-Border gryphonIcon:Gryphon-Icon
    questLogTopLeft:UI-QuestLog-TopLeft questLogTopRight:UI-QuestLog-TopRight questLogBotLeft:UI-QuestLog-BotLeft
    questLogBotRight:UI-QuestLog-BotRight questLogDualLeft:UI-QuestLogDualPane-Left
    questLogDualRight:UI-QuestLogDualPane-Right questLogEmptyTopLeft:UI-QuestLog-Empty-TopLeft
    questLogEmptyTopRight:UI-QuestLog-Empty-TopRight questLogEmptyBotLeft:UI-QuestLog-Empty-BotLeft
    questLogEmptyBotRight:UI-QuestLog-Empty-BotRight scrollKnob:UI-ScrollBar-Knob
    repPlate:UI-Character-ReputationBar repHighlight:UI-Character-ReputationBar-Highlight
    skillsBar:UI-Character-Skills-Bar skillsBarBorder:UI-Character-Skills-BarBorder charScrollBar:UI-Character-ScrollBar
    lootNameFrame:UI-QuestItemNameFrame lootIcon:LootPanel-Icon lootPanel:UI-LootPanel marbleBg:UI-Background-Marble
    rockBg:UI-Background-Rock frameSheet:_UI-Frame merchantBottom:UI-Merchant-BottomBorder
    merchantLabelSlots:UI-Merchant-LabelSlots bagComponents:UI-Bag-Components backpackBg:UI-BackpackBackground
    bankFloor:UI-BankFrame-Floor optionsTabActive:UI-OptionsFrame-ActiveTab
    optionsTabInactive:UI-OptionsFrame-InActiveTab questParchment:QuestBG]])
for _, way in ipairs({ "Up", "Down" }) do
    for state in ("Up Down Disabled Highlight"):gmatch("%S+") do
        CopyOnly("scroll" .. way .. "Button" .. state .. ":UI-ScrollBar-Scroll" .. way .. "Button-" .. state)
    end
end

-- The client's own file both ways (no copy of it ships).
for pair in ([[statusBarSolid:Buttons\WHITE8X8 questMapButton:QuestFrame\UI-QuestMap_Button
    exhaustionTick:MainMenuBar\UI-ExhaustionTickNormal exhaustionTickHighlight:MainMenuBar\UI-ExhaustionTickHighlight]]):gmatch("%S+") do
    local key, file = pair:match("^(%w+):(.+)$")
    TEX[key] = { "Interface\\" .. file, "Interface\\" .. file, false }
end

-- The micro button sheets. The client's Socials file is a guild banner now
-- (the copy first); the World sheets ship only as EraUI's copies, so the
-- client's name is refused and the copy used.
for sheet in ("CharacterNightElf Abilities Spellbook Talents Achievement Quest Socials LFG Mounts EJ Help BStore MainMenu World"):gmatch("%S+") do
    local onDisk = sheet == "World" and sheet or sheet:lower()
    for state in ("Up Down Disabled"):gmatch("%S+") do
        TEX["micro" .. sheet .. state] = { "Interface\\Buttons\\UI-MicroButton-" .. sheet .. "-" .. state,
            Copy("UI-MicroButton-" .. onDisk .. "-" .. state:lower()), sheet == "Socials" }
    end
end

-- The 1.x spellbook's pieces (its own files under Interface\Spellbook and
-- Interface\Buttons); the copies keep the case they have on disk.
FromFolder("Interface\\Spellbook\\", [[sbTopLeft:UI-SpellbookPanel-TopLeft sbTopRight:UI-SpellbookPanel-TopRight
    sbBotLeft:UI-SpellbookPanel-BotLeft sbBotRight:UI-SpellbookPanel-BotRight sbIcon:Spellbook-Icon:SpellBook-Icon
    sbSkillTab:SpellBook-SkillLineTab sbEmptySlot:UI-Spellbook-SpellBackground:UI-SpellBook-SpellBackground
    sbTabUnselected:UI-SpellBook-Tab-Unselected sbTab1Selected:UI-SpellBook-Tab1-Selected
    sbTab3Selected:UI-SpellBook-Tab3-Selected sbTabHighlight:UI-SpellbookPanel-Tab-Highlight]])
States("Interface\\Buttons\\", "sbPrev", "UI-SpellbookIcon-PrevPage-", "Up Down Disabled")
States("Interface\\Buttons\\", "sbNext", "UI-SpellbookIcon-NextPage-", "Up Down Disabled")
FromFolder("Interface\\Buttons\\", "mouseHighlight:UI-Common-MouseHilight")

---------------------------------------------------------------------------
-- Reading and setting
---------------------------------------------------------------------------

-- The two files for a name, the one to try first first: the game's own,
-- unless the copies are chosen (/eraui-classic textures bundled) or the
-- name always wants its copy. An unknown name is an error.
function ns.TexPath(key)
    local piece = TEX[key]
    if not piece then error("EraUI: no 1.x art named " .. tostring(key), 2) end
    local saved = ns.db
    if piece[3] or (saved and saved.textureSource == "bundled") then return piece[2], piece[1] end
    return piece[1], piece[2]
end

-- A texture given a piece of art: the first file, the second if the game
-- refuses it, then Dark Mode's look for that name (even when both were
-- refused). False only when both were refused.
function ns.SetTex(texture, key)
    local first, second = ns.TexPath(key)
    if not texture then return false end
    local outcome = Look.PutFile(texture, first, second)
    Look.artResults[key] = outcome
    if type(ns.ThemeTexture) == "function" then ns.ThemeTexture(texture, key) end
    return outcome ~= "missing"
end

-- A button's state texture (Normal, Pushed, Disabled, Highlight or
-- Checked) wearing a piece of art; a button with none for that state yet is
-- given one from the first file. Returns the texture.
function ns.SetButtonTex(button, state, key)
    local read = button and button["Get" .. state .. "Texture"]
    local give = button and button["Set" .. state .. "Texture"]
    if type(read) ~= "function" or type(give) ~= "function" then return nil end
    local face = read(button)
    if not face then
        give(button, (ns.TexPath(key)))
        face = read(button)
    end
    if face then ns.SetTex(face, key) end
    return face
end

-- A bar's fill: the client's solid white square while Flat Bars is on
-- (/era, live), else the first file of the given art.
function ns.BarFill(key)
    local flat = type(EraUI.GetSetting) == "function" and EraUI:GetSetting("flatBars") == true
    return (ns.TexPath(flat and "statusBarSolid" or key or "statusBar"))
end
