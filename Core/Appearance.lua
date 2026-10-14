local _, EraUI = ...
local ns = EraUI.Classic
local decorative = {}
for key in ("questLogTopLeft questLogTopRight questLogBotLeft questLogBotRight questLogDualLeft questLogDualRight questLogEmptyTopLeft questLogEmptyTopRight questLogEmptyBotLeft questLogEmptyBotRight questLogTabLeft questLogTabMiddle questLogTabRight endCap barBody barKeyring maxLevel slotEmpty slotNormal targetingFrame targetingElite targetingRare targetingRareElite targetingMinus targetOfTarget smallTargetingFrame levelBackground castBorder castBorderSmall minimapBorder minimapBackground trackingBorder nameplateBorder frameMetal frameMetalH frameMetalV frameSheet marbleBg rockBg tabActive tabInactive optionsTabActive optionsTabInactive scrollKnob charScrollBar lootPanel merchantBottom merchantLabelSlots bagComponents backpackBg bankFloor skillsBarBorder charGeneralTopLeft charGeneralTopRight charGeneralBotLeft charGeneralBotRight"
    -- Added with the Darkness slider: the minimap's ring, zoom buttons and
    -- clock, the reputation bar's frame and the latency bar. Frame art only;
    -- icons (bags, micro menu) keep their colours.
    .." compassRing zoomInUp zoomInDown zoomInDisabled zoomOutUp zoomOutDown zoomOutDisabled clockBackground repBar performanceBar"
    -- And the gold ring of Forever's day/night button (its moon and sun keep their colours).
    .." dielBorder"):gmatch("%S+") do decorative[key]=true end

-- Darkness: 40 (light grey) to 90 (near black); 58 is the original Dark Mode
-- grey (.42, .44, .48). The slight blue of that grey is kept at every step.
ns.DARKNESS_MIN, ns.DARKNESS_MAX, ns.DARKNESS_DEFAULT = 40, 90, 58
function ns.DarkGrey()
    local d = tonumber(EraUI:GetSetting("darkModeDarkness")) or ns.DARKNESS_DEFAULT
    d = math.max(ns.DARKNESS_MIN, math.min(ns.DARKNESS_MAX, d))
    local v = 1 - d / 100
    return v, math.min(1, v * 44 / 42), math.min(1, v * 48 / 42)
end

-- Textures given the dark grey, so the slider can re-tint them live. Weak
-- keys: a texture the game lets go of drops out by itself.
local tinted = setmetatable({}, { __mode = "k" })
-- Class-coloured borders and their full class colour, for "Darken class
-- colours too" (off unless ticked).
local classTinted = setmetatable({}, { __mode = "k" })

-- How much darker than the original grey the slider is: 1 at 58 (or less),
-- down to about a quarter at 90. Class colours are multiplied by it.
local function ClassShade()
    if not EraUI:GetSetting("darkenClassColours") then return 1 end
    return math.min(1, (ns.DarkGrey()) / .42)
end

local function PaintClass(texture, r, g, b)
    local f = ClassShade()
    texture:SetVertexColor(r * f, g * f, b * f)
end

-- Texture-only, called by EraUI's existing artwork application. No scanning,
-- native setter hooks, timers, geometry changes, or protected value reads.
function ns.ThemeTexture(texture,key)
    if not texture or not EraUI:GetSetting("darkMode") or not decorative[key] then return end
    local borderUnit
    local owner=texture
    while owner do
        if owner==CharacterFrame or owner==PartyFrame or owner==CompactRaidFrameContainer then return end
        if owner==PlayerFrame then borderUnit="player"
        elseif owner==TargetFrame then borderUnit="target"
        elseif owner==FocusFrame then borderUnit="focus" end
        local name=owner.GetName and owner:GetName()
        if name and (name:match("^PartyMemberFrame") or name:match("^CompactParty") or name:match("^CompactRaid") or name:match("^RaidFrame")) then return end
        owner=owner.GetParent and owner:GetParent()
    end
    -- Normal frame shell only: leave rare/elite classification art and all
    -- fills, icons, flash/status textures under their existing ownership.
    local isPlayer=borderUnit and UnitIsPlayer(borderUnit)
    if issecretvalue and issecretvalue(isPlayer) then isPlayer=false end
    if isPlayer and key=="targetingFrame" and EraUI:GetSetting("classColourBorders") then
        local _,class=UnitClass(borderUnit)
        if not (issecretvalue and issecretvalue(class)) then
            local colour=(CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])
                or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
            if class=="PALADIN" then colour={r=.96,g=.55,b=.73} end
            if colour then
                tinted[texture]=nil
                classTinted[texture]={colour.r,colour.g,colour.b}
                PaintClass(texture,colour.r,colour.g,colour.b);return
            end
        end
    end
    classTinted[texture]=nil
    tinted[texture]=true
    texture:SetVertexColor(ns.DarkGrey())
end

-- A texture that stops being Dark Mode's art (Thick Frames' reaction line,
-- which the Classic look's backing made grey): the slider leaves it alone
-- from now on. Its colour isn't touched; the game sets it again.
function ns.UntintTexture(texture)
    if not texture then return end
    tinted[texture], classTinted[texture] = nil, nil
end

-- Dark Windows (on with Dark Mode, its own tick): what Dark Mode left light
-- in EraUI's classic windows follows the Darkness slider too. The red panel
-- buttons lose their red and take a lifted grey: a dark grey at Darkness 58,
-- near black with faint lighter edges at 90. Their glow only loses its
-- colour. Frame art (the dialog boxes' borders and header plates, the
-- skinned windows' metal edges, stone and title strip) takes the grey
-- itself, and a dialog box's fill darkens with the buttons' grey. Parchment
-- (the spellbook's and professions book's pages) goes a darker brown-grey,
-- held at PAGE_FLOOR from about Darkness 80 on so the text on it stays
-- readable, and the small dark text on it ("Passive", the page number) turns
-- a light warm grey-gold. Labels and spell names keep their gold. Only
-- colours are set, Blizzard's own pieces included; each piece keeps the look
-- it was last given, so a pass with nothing new sets nothing, and force
-- paints it again after the game redraws it. Off, a piece gets its own
-- colours back once and is then left alone; one Dark Mode tints by itself
-- keeps that grey.
-- Black Pages (its own tick under Dark Windows, off unless ticked): the
-- parchment loses its colour and goes near black, a dark neutral like the
-- game menu's fill, the same at every Darkness; the rings and bar frames
-- drawn on it ("trim") take Dark Mode's grey instead, so they still show and
-- follow the slider. The spellbook draws its frame, title strip and icon
-- ring into the same four pieces as its parchment, so those pieces are trim
-- too, and EraUI's own flat near black ("cover") goes over the parchment
-- alone, shown only with Black Pages. The light text and the gold names stay
-- as they are; the Professions window's dark small text on its spell plates
-- and cards (a spell's rank under its name), readable on the brown-grey,
-- turns light too while the pages are black.
local BUTTON_LIFT, BUTTON_GAIN = .1, 2
local PAGE_LIFT, PAGE_GAIN, PAGE_FLOOR = .36, .43, .45
local PAGE_TEXT = { .87, .81, .66 }
local BLACK_PAGE = { .13, .13, .14 }
-- The cover's colour: the spellbook's parchment (about .43 bright once
-- desaturated) given BLACK_PAGE, so it matches the Professions window's.
local PARCHMENT = .43
local BLACK_COVER = { BLACK_PAGE[1] * PARCHMENT, BLACK_PAGE[2] * PARCHMENT, BLACK_PAGE[3] * PARCHMENT }
local DESATURATED = { button = true, glow = true, page = true, cross = true }
local WHITE = { 1, 1, 1, 1 }
local darkArt = setmetatable({}, { __mode = "k" })      -- texture: its role
local darkText = setmetatable({}, { __mode = "k" })     -- font string: its own colour
local darkBackdrop = setmetatable({}, { __mode = "k" }) -- backdrop frame: its own colours
local darkLast = setmetatable({}, { __mode = "k" })     -- piece: the look it was last given
local blackText = setmetatable({}, { __mode = "k" })    -- font string: light only with Black Pages
-- Text counts as dark under this brightness: the small brown and black
-- fonts (about .22 and 0); gold names (.78), greys (.5) and white are not.
local DARK_TEXT = .35

function ns.DarkWindowsOn()
    return (EraUI:GetSetting("enabled") and EraUI:GetSetting("darkMode") and EraUI:GetSetting("darkWindows"))
        and true or false
end

function ns.BlackPagesOn()
    return (ns.DarkWindowsOn() and EraUI:GetSetting("blackPages")) and true or false
end

-- The buttons' grey: Dark Mode's, lifted so the art's own shading still shows.
local function Lifted()
    local r, g, b = ns.DarkGrey()
    return math.min(1, BUTTON_LIFT + r * BUTTON_GAIN), math.min(1, BUTTON_LIFT + g * BUTTON_GAIN),
        math.min(1, BUTTON_LIFT + b * BUTTON_GAIN)
end
ns.DarkButtonGrey = Lifted

-- The red close and minimise buttons' grey ("cross"): the buttons' lifted
-- grey, never darker than CROSS_FLOOR (about Darkness 75's), its slight blue
-- kept. Their cross is drawn in the same art as the red square round it: a
-- gold cross about 4.6 times as bright as the square once desaturated
-- (Forever's art; 6.9 in the classic one EraUI's windows wear), so it stays
-- the lighter part at every Darkness. Without the floor it would fade to
-- about .16 on .035 at Darkness 90; with it, about .32 on .07.
local CROSS_FLOOR = .6
local function CrossGrey()
    local r, g, b = Lifted()
    if r >= CROSS_FLOOR then return r, g, b end
    local f = CROSS_FLOOR / r
    return CROSS_FLOOR, math.min(1, g * f), math.min(1, b * f)
end
ns.DarkCrossGrey = CrossGrey

-- Parchment's shade: darker with the slider, never below the floor; a touch
-- more blue than red takes the yellow out, for a brown-grey.
local function PageShade()
    local v = math.max(PAGE_FLOOR, math.min(1, PAGE_LIFT + (ns.DarkGrey()) * PAGE_GAIN))
    return v, v, math.min(1, v * 1.06)
end
ns.DarkPageShade = PageShade
ns.DARK_PAGE_FLOOR, ns.DARK_PAGE_TEXT, ns.DARK_BLACK_PAGE = PAGE_FLOOR, PAGE_TEXT, BLACK_PAGE
ns.DARK_BLACK_COVER = BLACK_COVER

-- A piece's look for its role: desaturated or not (nil: left as it is), and
-- its colour. A page is desaturated only while it is black; a trim is
-- coloured like the page, or with Black Pages like the frame.
local function Look(role, on, texture)
    local desaturate
    if DESATURATED[role] then desaturate = false end
    if not on then
        if tinted[texture] then return desaturate, ns.DarkGrey() end
        return desaturate, 1, 1, 1
    end
    if role == "button" then return true, Lifted() end
    if role == "cross" then return true, CrossGrey() end
    if role == "glow" then return true, 1, 1, 1 end
    if role == "page" or role == "trim" then
        if not ns.BlackPagesOn() then return desaturate, PageShade() end
        if role == "page" then return true, BLACK_PAGE[1], BLACK_PAGE[2], BLACK_PAGE[3] end
    end
    return nil, ns.DarkGrey()
end

local function Unchanged(piece, d, r, g, b)
    local last = darkLast[piece]
    return last ~= nil and last[1] == d and last[2] == r and last[3] == g and last[4] == b
end

local function Remember(piece, on, d, r, g, b)
    if not on then darkLast[piece] = nil return end
    local last = darkLast[piece] or {}
    last[1], last[2], last[3], last[4] = d, r, g, b
    darkLast[piece] = last
end

-- A cover (EraUI's own texture over parchment drawn together with its frame,
-- the spellbook's): shown, in its flat near black, only with Black Pages;
-- hidden otherwise, Dark Windows off included.
local function PaintCover(texture, on, force)
    local show = ns.BlackPagesOn()
    if on and not force and Unchanged(texture, show) then return end
    if show then texture:SetColorTexture(BLACK_COVER[1], BLACK_COVER[2], BLACK_COVER[3], 1) end
    texture:SetShown(show)
    Remember(texture, on, show)
end

local function PaintArt(texture, force)
    local on = ns.DarkWindowsOn()
    if not on and not darkLast[texture] then return end
    if darkArt[texture] == "cover" then return PaintCover(texture, on, force) end
    local d, r, g, b = Look(darkArt[texture], on, texture)
    if on and not force and Unchanged(texture, d, r, g, b) then return end
    if d ~= nil then texture:SetDesaturated(d) end
    texture:SetVertexColor(r, g, b)
    Remember(texture, on, d, r, g, b)
end

local function PaintText(text, force)
    local on = ns.DarkWindowsOn()
    if blackText[text] then on = ns.BlackPagesOn() end
    if not on and not darkLast[text] then return end
    local own = darkText[text]
    local r, g, b, a = own[1], own[2], own[3], own[4]
    if on then r, g, b = PAGE_TEXT[1], PAGE_TEXT[2], PAGE_TEXT[3] end
    if on and not force and Unchanged(text, nil, r, g, b) then return end
    text:SetTextColor(r, g, b, a)
    Remember(text, on, nil, r, g, b)
end

-- A dialog box: its border times Dark Mode's grey, its fill times the
-- buttons' grey (so a black fill stays black); off, its own colours again.
local function PaintBackdrop(frame, force)
    local on = ns.DarkWindowsOn()
    if not on and not darkLast[frame] then return end
    local own = darkBackdrop[frame]
    local border, fill = own.border, own.fill
    local r, g, b = border[1], border[2], border[3]
    if on then
        local gr, gg, gb = ns.DarkGrey()
        r, g, b = r * gr, g * gg, b * gb
    end
    if on and not force and Unchanged(frame, nil, r, g, b) then return end
    frame:SetBackdropBorderColor(r, g, b, border[4])
    if fill then
        local fr, fg, fb = fill[1], fill[2], fill[3]
        if on then
            local lr, lg, lb = Lifted()
            fr, fg, fb = fr * lr, fg * lg, fb * lb
        end
        frame:SetBackdropColor(fr, fg, fb, fill[4])
    end
    Remember(frame, on, nil, r, g, b)
end

-- Registered only while Dark Mode is loaded: it needs a reload to come on,
-- so a piece made without it never needs anything.
-- role: "frame" (the grey), "page" (parchment), "trim" (art drawn on or round
-- parchment: rings, bar frames, the spellbook's frame), "cover" (EraUI's own
-- black over a page, made hidden), "button", "cross" (a close or minimise
-- button's art) or "glow".
function ns.DarkWindowArt(texture, role, force)
    if not texture or not EraUI:GetSetting("darkMode") then return end
    darkArt[texture] = role or "frame"
    PaintArt(texture, force)
end

-- A red panel button's Normal, Pushed and Disabled art, and its glow.
local BUTTON_STATES = { { "GetNormalTexture", "button" }, { "GetPushedTexture", "button" },
    { "GetDisabledTexture", "button" }, { "GetHighlightTexture", "glow" } }
function ns.DarkRedButton(button)
    if not button or not EraUI:GetSetting("darkMode") then return end
    for _, state in ipairs(BUTTON_STATES) do
        local get = button[state[1]]
        local texture = get and get(button)
        if texture then ns.DarkWindowArt(texture, state[2]) end
    end
end

-- Dark text on parchment; its own colour is kept for when Dark Windows is off.
-- force: painted again after the game has set the text up again.
function ns.DarkWindowText(text, force)
    if not text or not EraUI:GetSetting("darkMode") then return end
    if not darkText[text] then darkText[text] = { text:GetTextColor() } end
    PaintText(text, force)
end

-- Dark text that Dark Windows' brown-grey page leaves readable but Black
-- Pages' near black doesn't (the Professions window's spell plates and
-- cards): light only while Black Pages is on, its own colour otherwise.
-- Taken only when it is dark the first time it is seen, so gold names and
-- light text are left alone; text already handed to ns.DarkWindowText
-- keeps that. Only colours are read and set.
local function Readable(v) return not (issecretvalue and issecretvalue(v)) and type(v) == "number" end
function ns.DarkBlackPageText(text, force)
    if not text or not EraUI:GetSetting("darkMode") then return end
    if not darkText[text] then
        local r, g, b, a = text:GetTextColor()
        if not (Readable(r) and Readable(g) and Readable(b) and Readable(a)) then return end
        if .3 * r + .59 * g + .11 * b >= DARK_TEXT then return end
        darkText[text] = { r, g, b, a }
        blackText[text] = true
    elseif not blackText[text] then
        return
    end
    PaintText(text, force)
end

-- A dialog box's backdrop (the classic dialog border, with or without its
-- fill): its border takes the grey, its fill the buttons'. fill and border
-- are the colours the box was given ({ r, g, b, a }; white when nil), kept
-- for when Dark Windows is off; fill false: a border with no fill. The first
-- registration's colours are kept.
function ns.DarkBackdrop(frame, fill, border)
    if not frame or not frame.SetBackdropBorderColor or not EraUI:GetSetting("darkMode") then return end
    if not darkBackdrop[frame] then
        if fill == nil then fill = WHITE end
        darkBackdrop[frame] = { fill = fill, border = border or WHITE }
    end
    PaintBackdrop(frame)
end

-- The game's help tips (the gold glow box with an arrow, as "You have unspent
-- talent points" over the menu bar) and the help plates' tooltip, which is the
-- same box: its fill takes the frame grey, still fading to black at the top as
-- its gold-brown did, and its glow edges and arrow lose their gold for the
-- buttons' lifted grey, so the box still stands out. The white text and the
-- yellow close cross keep their colours. Off, the fill gets its gold-brown
-- back. Only colours are set.
local TIP_FOOT, TIP_TOP = { .23, .19, 0 }, { 0, 0, 0 }
local TIP_EDGES = { "GlowTopLeft", "GlowTopRight", "GlowBottomLeft", "GlowBottomRight", "GlowTop",
    "GlowBottom", "GlowLeft", "GlowRight", "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight",
    "ArrowGlowUp", "ArrowGlowDown", "ArrowGlowLeft", "ArrowGlowRight" }
local tipFill = setmetatable({}, { __mode = "k" }) -- a glow box's fill texture: true

local function PaintTipFill(texture, force)
    local on = ns.DarkWindowsOn()
    if not on and not darkLast[texture] then return end
    local r, g, b = TIP_FOOT[1], TIP_FOOT[2], TIP_FOOT[3]
    if on then r, g, b = ns.DarkGrey() end
    if on and not force and Unchanged(texture, nil, r, g, b) then return end
    if CreateColor and texture.SetGradient then
        pcall(texture.SetGradient, texture, "VERTICAL", CreateColor(r, g, b, 1),
            CreateColor(TIP_TOP[1], TIP_TOP[2], TIP_TOP[3], 1))
    end
    Remember(texture, on, nil, r, g, b)
end

local function DarkGlowBox(frame)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) or not EraUI:GetSetting("darkMode") then return end
    if frame.BG then
        tipFill[frame.BG] = true
        PaintTipFill(frame.BG)
    end
    for _, key in ipairs(TIP_EDGES) do ns.DarkWindowArt(frame[key], "button") end
    local arrow = frame.Arrow
    if type(arrow) == "table" and arrow.Arrow then
        ns.DarkWindowArt(arrow.Arrow, "button")
        ns.DarkWindowArt(arrow.Glow, "button")
    end
end
ns.DarkGlowBox = DarkGlowBox

-- Help tips all come from one pool; each is painted as it shows.
if HelpTip and type(HelpTip.Show) == "function" then
    hooksecurefunc(HelpTip, "Show", function(self)
        local pool = self.framePool
        if not pool or type(pool.EnumerateActive) ~= "function" then return end
        for frame in pool:EnumerateActive() do DarkGlowBox(frame) end
    end)
end
if HelpPlateTooltip and HelpPlateTooltip.HookScript then HelpPlateTooltip:HookScript("OnShow", DarkGlowBox) end

-- The game's own red buttons, wherever they show (Dark Windows): the panel
-- buttons (UIPanelButtonTemplate and every template built on it), the
-- three-slice ones in the red or gold-red art, and the dialog boxes' buttons
-- (the pop-ups', the quest session and add friend dialogs') take the lifted
-- grey like EraUI's own red buttons, their glow loses its colour, and their
-- labels keep their gold. A fixed list of the game's windows is looked at as
-- each one opens: its buttons up to RED_DEPTH levels down are told apart by
-- reads only (a panel button's three pieces and the game's own panel button
-- handlers on it, a three-slice button's red art name), and only colours are
-- set on the game's textures. Each window gets one OnShow post-hook, out of a
-- fight, in Dark Mode, once its Blizzard addon has loaded; nothing is written
-- on the game's frames (weak tables only), no handler is replaced, and
-- forbidden frames are never touched. The Dark Windows tick, the Darkness
-- slider and turning it off reach these pieces like any other.
-- The red close and minimise buttons in the corners (UIPanelCloseButton and
-- its kin, the minimise and maximise pair, told apart by their art's name:
-- the RedButton-Exit, -MiniCondense, -Condense and -Expand atlases, or the
-- classic UI-Panel-MinimizeButton files) go dark the same way in the same
-- windows, all their states, in the "cross" grey that keeps their light
-- cross readable; the bags', the item link tooltip's, the scoreboard's and
-- the world and flight maps' are listed by themselves, so their many item
-- buttons, rows and pins (and the tooltip) aren't looked through.
-- EraUI's own windows hand theirs over as they skin them
-- (ns.DarkCloseButton). Not covered: forbidden windows (the shop, the
-- authenticator), and buttons a window makes while it stays open (dark from
-- its next opening).
local RED_DEPTH = 7
-- Off: the colours are expected to outlast the game's redraws (a panel
-- button's SetTexture as it is pressed, shown, enabled or disabled; a
-- three-slice button's SetAtlas). On, should the game prove otherwise: each
-- red button is painted again after each of those, through its own
-- post-hooks, added out of a fight.
local REPAINT_AFTER_REDRAW = false
local REDRAWS = { "OnMouseDown", "OnMouseUp", "OnShow", "OnDisable", "OnEnable" }
local PANEL_HANDLERS = {} -- script: the game's panel button handler for it
for _, script in ipairs(REDRAWS) do PANEL_HANDLERS[script] = "UIPanelButton_" .. script end
local NATIVE_PIECES = { "Left", "Middle", "Right", "Center" }
local RED_WINDOWS = {
    -- Always there.
    "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4", "InstanceAbandonPopup",
    "QuestFrame", "GossipFrame", "StackSplitFrame", "MailFrame", "OpenMailFrame", "TradeFrame", "GameMenuFrame",
    "EditModeManagerFrame", "EditModeSystemSettingsDialog", "EditModeLayoutDialog", "EditModeImportLayoutDialog",
    "EditModeImportLayoutLinkDialog", "EditModeUnsavedChangesDialog",
    "ReadyCheckFrame", "RolePollPopup", "GuildInviteFrame", "LFGInvitePopup", "PVPReadyDialog", "PVPRoleCheckPopup",
    "PVPFramePopup", "PVPMatchResults", "PetBattleQueueReadyFrame",
    "RaidFrame", "RaidInfoFrame", "CompactRaidFrameManager",
    "FriendsFrame", "FriendsFriendsFrame", "AddFriendFrame", "BattleNetInviteFrame", "QuickJoinRoleSelectionFrame",
    "RecruitAFriendRewardsFrame", "RecruitAFriendRecruitmentFrame",
    "QuestMapFrame.QuestsFrame.DetailsFrame", "QuestLogPopupDetailFrame",
    "BankFrame", "BankCleanUpConfirmationPopup", "CharacterFrame", "GearManagerPopupFrame", "CurrencyTransferMenu",
    "DressUpFrame", "SideDressUpFrame", "WardrobeCustomSetEditFrame",
    "AddonList", "AddonDialog", "SettingsPanel", "ChatConfigFrame", "ChannelFrame", "CreateChannelPopup",
    "ColorPickerFrame", "QuickKeybindFrame",
    "CoinPickupFrame", "TutorialFrame", "BasicMessageDialog", "RatingMenuFrame", "UIWidgetCenterDisplayFrame",
    "VoiceChatPromptActivateChannel", "BrowserSettingsTooltip", "EventToastManagerFrame", "ModelPreviewFrame",
    "TabardFrame", "GuildRegistrarFrame", "PetitionFrame", "GuildRenameFrame", "PetStableFrame",
    "CommunitiesFrame", "CommunitiesSettingsDialog", "CommunitiesTicketManagerDialog", "CommunitiesGuildTextEditFrame",
    "CommunitiesGuildLogFrame", "CommunitiesAvatarPickerDialog",
    "ReportFrame", "ReportCheatingDialog", "ScriptErrorsFrame", "SplashFrame", "CinematicFrame", "MovieFrame",
    -- Windows seen every session whose only red button is the close one.
    "MerchantFrame", "LootFrame", "TaxiFrame", "ItemTextFrame", "WorldMapFrame.BorderFrame",
    "ContainerFrame1.CloseButton", "ContainerFrame2.CloseButton", "ContainerFrame3.CloseButton",
    "ContainerFrame4.CloseButton", "ContainerFrame5.CloseButton", "ContainerFrame6.CloseButton",
    "ContainerFrame7.CloseButton", "ContainerFrameCombinedBags.CloseButton",
    -- The item link tooltip and the battleground scoreboard: their close
    -- button alone (the tooltip itself is never hooked or looked through).
    "ItemRefTooltip.CloseButton", "PVPMatchScoreboard.CloseButton",
    -- With their Blizzard addon, loaded when first needed.
    "DeathRecapFrame", "AuctionHouseFrame", "MacroFrame", "MacroPopupFrame", "GuildBankFrame", "GuildBankPopupFrame",
    "GuildControlUI", "CalendarFrame", "CalendarViewEventFrame", "CalendarCreateEventFrame", "CalendarMassInviteFrame",
    "CalendarEventPickerFrame", "CalendarTexturePickerFrame", "ClassTrainerFrame", "PlayerSpellsFrame",
    "ClassTalentLoadoutImportDialog", "ClassTalentLoadoutEditDialog", "ClassTalentLoadoutCreateDialog",
    "ProfessionsFrame", "LFGListingFrame", "LFGBrowseFrame", "InspectFrame", "BarberShopFrame", "BlackMarketFrame",
    "ItemSocketingFrame", "ItemUpgradeFrame", "TransmogFrame", "CollectionsJournal", "AchievementFrame",
    "ClickBindingFrame", "PlayerChoiceFrame",
    "FlightMapFrame.BorderFrame", "ProfessionsBookFrame", "TimeManagerFrame", "StopwatchFrame", "LFGParentFrame",
}
-- The dialog boxes' red buttons (UI-DialogBox-Button art, no panel pieces),
-- by window: true for the pop-ups' ButtonContainer.Buttons and ExtraButton
-- (GameDialog.xml), or the buttons' own paths.
local DIALOG_BUTTONS = {
    StaticPopup1 = true, StaticPopup2 = true, StaticPopup3 = true, StaticPopup4 = true, InstanceAbandonPopup = true,
    AddFriendFrame = { "AddFriendFrame.InfoFrame.OkayButton", "AddFriendFrame.EntryFrame.EditBoxContainer.AcceptButton",
        "AddFriendFrame.EntryFrame.EditBoxContainer.CancelButton" },
    BasicMessageDialog = { "BasicMessageDialogButton" },
    TutorialFrame = { "TutorialFrameOkayButton" },
}
for _, key in ipairs({ "CheckStartDialog", "StartDialog", "CheckStopDialog", "CheckLeavePartyDialog",
    "CheckConvertToRaidDialog", "ConfirmJoinGroupRequestDialog", "ConfirmInviteToGroupDialog",
    "ConfirmInviteToGroupReceivedDialog", "ConfirmRequestToJoinGroupDialog", "ConfirmBNJoinGroupRequestDialog",
    "ConfirmInviteTravelPassConfirmationDialog" }) do
    local path = "QuestSessionManager." .. key
    RED_WINDOWS[#RED_WINDOWS + 1] = path
    DIALOG_BUTTONS[path] = true
end
local redWindows = setmetatable({}, { __mode = "k" }) -- window: hooked
local redrawHooked = setmetatable({}, { __mode = "k" }) -- button: its redraws hooked

-- A frame that may be read and coloured: never a forbidden one.
local function Usable(frame)
    return type(frame) == "table" and type(frame.IsForbidden) == "function" and not frame:IsForbidden()
end

local function IsTexture(region)
    return type(region) == "table" and type(region.IsObjectType) == "function" and region:IsObjectType("Texture")
end

-- "QuestMapFrame.QuestsFrame.DetailsFrame": read from the globals, key by key.
local function Resolve(path)
    local node = _G
    for key in path:gmatch("[^.]+") do
        if node ~= _G and not Usable(node) then return nil end
        node = node[key]
        if node == nil then return nil end
    end
    if Usable(node) then return node end
end

-- A panel button: its three pieces, and one of the game's own panel button
-- handlers on it (bound by name as the button was made, so the same function).
local function IsPanelRed(button)
    if not (IsTexture(button.Left) and IsTexture(button.Middle) and IsTexture(button.Right)) then return false end
    for script, name in pairs(PANEL_HANDLERS) do
        local native = _G[name]
        if native ~= nil and button:GetScript(script) == native then return true end
    end
    return false
end

-- A three-slice button in the red or gold-red art (128-RedButton,
-- 128-GoldRedButton): its three pieces.
local function IsSliceRed(button)
    local atlas = button.atlasName
    return type(atlas) == "string" and atlas:find("RedButton", 1, true) ~= nil
        and IsTexture(button.Left) and IsTexture(button.Center) and IsTexture(button.Right)
end

-- The close and minimise buttons' art, by the lower-case name of their
-- Normal texture's atlas or file ("redbutton-exit-c60" on Forever, or
-- "...\ui-panel-minimizebutton-up" for the classic one), and the role each
-- of their states takes.
local CROSS = {
    art = { "redbutton-exit", "redbutton-minicondense", "redbutton-condense", "redbutton-expand",
        "ui-panel-minimizebutton", "ui-panel-hidebutton", "ui-panel-biggerbutton", "ui-panel-smallerbutton" },
    states = { { "GetNormalTexture", "cross" }, { "GetPushedTexture", "cross" }, { "GetDisabledTexture", "cross" },
        { "GetHighlightTexture", "glow" } },
}

-- Reads only: the atlas, else the file path, never a number.
local function ArtName(texture)
    if not IsTexture(texture) then return nil end
    local name = type(texture.GetAtlas) == "function" and texture:GetAtlas() or nil
    if type(name) ~= "string" or name == "" then
        name = type(texture.GetTextureFilePath) == "function" and texture:GetTextureFilePath() or nil
        if type(name) ~= "string" then name = texture:GetTexture() end
    end
    if type(name) == "string" then return name:lower() end
end

local function IsCross(button)
    local get = button.GetNormalTexture
    local name = type(get) == "function" and ArtName(get(button)) or nil
    if not name then return false end
    for _, art in ipairs(CROSS.art) do
        if name:find(art, 1, true) then return true end
    end
    return false
end

-- Normal, pushed and disabled in the cross grey, the glow without its colour.
local function PaintCross(button)
    for _, state in ipairs(CROSS.states) do
        local get = button[state[1]]
        local texture = type(get) == "function" and get(button) or nil
        if IsTexture(texture) then ns.DarkWindowArt(texture, state[2]) end
    end
end

local function PaintNative(button, force)
    for _, key in ipairs(NATIVE_PIECES) do
        local piece = button[key]
        if IsTexture(piece) then ns.DarkWindowArt(piece, "button", force) end
    end
    local glow = button:GetHighlightTexture()
    if glow then ns.DarkWindowArt(glow, "glow", force) end
end

local function Repaint(button)
    if ns.DarkWindowsOn() then PaintNative(button, true) end
end

-- A close or minimise button's states are separate textures the game only
-- swaps art on (SetAtlas, SetNormalTexture), never through the redraws
-- above, so it needs no repaint hooks.
local function DarkButton(button)
    if IsCross(button) then
        PaintCross(button)
        return true
    end
    if not (IsPanelRed(button) or IsSliceRed(button)) then return false end
    PaintNative(button)
    if REPAINT_AFTER_REDRAW and not redrawHooked[button] and not InCombatLockdown() then
        redrawHooked[button] = true
        for _, script in ipairs(REDRAWS) do button:HookScript(script, Repaint) end
    end
    return true
end

-- One of the game's red panel, three-slice or close buttons, darkened like
-- EraUI's (EraUI's own UIPanelButtonTemplate buttons call it as they are
-- made). False when it isn't one.
function ns.DarkNativeButton(button)
    if not Usable(button) or not EraUI:GetSetting("darkMode") then return false end
    return DarkButton(button)
end

-- A close, minimise or maximise button EraUI makes or skins (its classic X
-- art, or the game's own): all its states in the cross grey, its glow
-- without its colour, in Dark Mode. Colours only.
function ns.DarkCloseButton(button)
    if not Usable(button) or not EraUI:GetSetting("darkMode") then return end
    PaintCross(button)
end

local function DarkRedIn(frame, depth)
    if not Usable(frame) then return end
    if frame:IsObjectType("Button") then DarkButton(frame) end
    if depth <= 0 then return end
    for _, child in ipairs({ frame:GetChildren() }) do DarkRedIn(child, depth - 1) end
end

-- Its pieces join Dark Windows even while the tick is off (nothing is set
-- then), so ticking it on darkens a window that is already open.
local function DarkWindow(frame, dialog)
    if not Usable(frame) then return end
    DarkRedIn(frame, RED_DEPTH)
    if dialog == true then
        local container = frame.ButtonContainer
        if Usable(container) and type(container.Buttons) == "table" then
            for _, button in ipairs(container.Buttons) do
                if Usable(button) then ns.DarkRedButton(button) end
            end
        end
        if Usable(frame.ExtraButton) then ns.DarkRedButton(frame.ExtraButton) end
    elseif dialog then
        for _, path in ipairs(dialog) do ns.DarkRedButton(Resolve(path)) end
    end
end

-- Hooked once, out of a fight; painted at once if it is already open.
local function HookRed(path, dialog)
    local frame = Resolve(path)
    if not frame then return false end
    if redWindows[frame] then return true end
    if InCombatLockdown() then return false end
    redWindows[frame] = true
    frame:HookScript("OnShow", function(self) DarkWindow(self, dialog) end)
    if frame:IsShown() then DarkWindow(frame, dialog) end
    return true
end

-- Each window as soon as it is there (its addon loaded, out of a fight).
-- Without Dark Mode nothing is ever hooked: it needs a reload to come on.
if CreateFrame then
    local pending = {} -- path: its dialog buttons, or false
    for _, path in ipairs(RED_WINDOWS) do pending[path] = DIALOG_BUTTONS[path] or false end
    local redWatch = CreateFrame("Frame")
    redWatch:RegisterEvent("ADDON_LOADED")
    redWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
    redWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
    redWatch:SetScript("OnEvent", function(self, event)
        if not EraUI:GetSetting("darkMode") then
            if event == "PLAYER_ENTERING_WORLD" then self:UnregisterAllEvents() end
            return
        end
        for path, dialog in pairs(pending) do
            if HookRed(path, dialog) then pending[path] = nil end
        end
    end)
end

-- Every piece, after the tick, Dark Mode or the Darkness slider changes.
function ns.RefreshDarkWindows()
    for texture in pairs(darkArt) do PaintArt(texture) end
    for text in pairs(darkText) do PaintText(text) end
    for frame in pairs(darkBackdrop) do PaintBackdrop(frame) end
    for texture in pairs(tipFill) do PaintTipFill(texture) end
end

-- The Darkness slider and its class colour tick: re-tint what Dark Mode has
-- already tinted, at once.
function ns.RefreshDarkness()
    if not EraUI:GetSetting("darkMode") then return end
    local r, g, b = ns.DarkGrey()
    for texture in pairs(tinted) do texture:SetVertexColor(r, g, b) end
    for texture, c in pairs(classTinted) do PaintClass(texture, c[1], c[2], c[3]) end
    -- Dark Aura Borders' grey line and the tooltips' bevel darken with the
    -- slider too, and so do the menu bar's frames (Dark Menu Bar) and the
    -- classic windows' buttons, boxes and pages (Dark Windows).
    local auras = EraUI.modules.AuraStyle
    if auras and auras.RefreshDarkness then auras:RefreshDarkness() end
    -- Rounded Cast Bars' fine line (Classic/CastBars.lua), the Advanced Cast Bar's too.
    if ns.RefreshRoundedCastLines then ns.RefreshRoundedCastLines() end
    -- Thick Frames' fine line (Classic/ThickFrames.lua).
    if ns.RefreshThickFrameLines then ns.RefreshThickFrameLines() end
    -- The Raid-style Party Outline's fine line (Classic/PartyOutline.lua).
    if ns.RefreshPartyOutlineLine then ns.RefreshPartyOutlineLine() end
    -- The Stat Tracker's edge (Modules/StatTracker.lua).
    local stats = EraUI.modules.StatTracker
    if stats and stats.Paint then stats:Paint() end
    if ns.RefreshDarkMenuBar then ns.RefreshDarkMenuBar() end
    ns.RefreshDarkWindows()
end
