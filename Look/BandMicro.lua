-- The micro menu on the band: its buttons in their 1.x art in the band's
-- right half (or in a stone tray of their own wherever the player puts them),
-- EraUI's World Map button after the quest button, EraUI's own Edit Mode
-- handle and size dialog for the menu, and the buttons shown pressed while
-- their windows are open. Also the secure click pad other windows put over a
-- micro button (MapPad), which works with the band on or off.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Shape = Look.Shape
local Number, Pin, Shown, Saved = Look.Number, Look.Pin, Look.Shown, Look.Saved
local band = Look.band

---------------------------------------------------------------------------
-- Which buttons
---------------------------------------------------------------------------

local NAMED = Look.Words([[CharacterMicroButton ProfessionMicroButton SpellbookMicroButton TalentMicroButton
    PlayerSpellsMicroButton AchievementMicroButton QuestLogMicroButton LegacyMicroButton GuildMicroButton
    LFDMicroButton CollectionsMicroButton EJMicroButton HousingMicroButton HelpMicroButton StoreMicroButton
    MainMenuMicroButton]])
Look.MICRO_NAMED = NAMED

local order, mapButton

local function Seen(window)
    return window ~= nil and window.IsShown ~= nil and window:IsShown() and (Number(window:GetAlpha()) or 1) > 0
end

-- The World Map button's tip: its name and key, in white, beside it.
local function MapTip(owner)
    local words = WORLDMAP_BUTTON or "World Map"
    local key = GetBindingKey and GetBindingKey("TOGGLEWORLDMAP")
    if key then words = words .. " (" .. (GetBindingText and GetBindingText(key) or key) .. ")" end
    Look.ShowTip(owner, "RIGHT", { { words, 1, 1, 1 } })
end

local function MapPressed()
    if not mapButton then return end
    local open = WorldMapFrame ~= nil and WorldMapFrame:IsShown()
    mapButton:SetButtonState(open and "PUSHED" or "NORMAL", open or nil)
end

-- EraUI's World Map button: the 1.x World sheet, a click opens the map (in a
-- fight through the secure pad), pressed while the map is open.
function Look.WorldMapButton()
    if mapButton then return mapButton end
    mapButton = CreateFrame("Button", "EraUIClassicWorldMapMicroButton", Look.BuildBand())
    mapButton:SetSize(28, 38)
    mapButton:RegisterForClicks("AnyUp")
    mapButton:SetScript("OnClick", function()
        if ToggleWorldMap and not Look.InFight() then ToggleWorldMap() end
    end)
    mapButton:SetScript("OnEnter", MapTip)
    mapButton:SetScript("OnLeave", Look.HideTip)
    ns.SkinMicroButton(mapButton)
    Look.HookScript(WorldMapFrame, "OnShow", MapPressed)
    Look.HookScript(WorldMapFrame, "OnHide", MapPressed)
    ns.MapPad(mapButton)
    return mapButton
end

-- The game's layout-indexed micro buttons in order (else the named ones),
-- with EraUI's World Map button after the quest button. Built once.
function Look.MicroList()
    if order then return order end
    local found = {}
    if MicroMenu and MicroMenu.GetChildren then
        for _, child in ipairs({ MicroMenu:GetChildren() }) do
            if Number(child.layoutIndex) and type(child.PostAddButtonCallback) == "function" then found[#found + 1] = child end
        end
        table.sort(found, function(a, b) return a.layoutIndex < b.layoutIndex end)
    end
    if #found == 0 then
        for _, called in ipairs(NAMED) do found[#found + 1] = _G[called] end
    end
    local after = #found
    for index, entry in ipairs(found) do
        if entry == QuestLogMicroButton then after = index end
    end
    table.insert(found, after + 1, Look.WorldMapButton())
    order = found
    return order
end

-- The shown buttons (the shop never counts).
function Look.MicroCount()
    local shown = 0
    for _, entry in ipairs(Look.MicroList()) do
        if entry ~= StoreMicroButton and entry:IsShown() then shown = shown + 1 end
    end
    return shown
end

---------------------------------------------------------------------------
-- The micro group: EraUI's frame holding the buttons' place, with its own
-- stone tray while it is off the band.
---------------------------------------------------------------------------

local group, tray

local function Group()
    if group then return group end
    group = Look.Build("Frame", Look.BuildBand(), nil, { size = { 300, Shape.BODY }, movable = true, clamped = true })
    Pin(group, "BOTTOMLEFT", band.frame, "BOTTOMLEFT", 512, 0)
    band.group = group
    return group
end
Look.MicroGroup = Group

-- piece: 3 or 4; from and to: the sheet's columns.
local function TraySlice(face, piece, from, to, x, width, mirrored)
    local rows = Shape.PIECES[piece]
    Look.Art(face, rows.sheet)
    local left, right = from / 256, to / 256
    if mirrored then left, right = right, left end
    Look.Crop(face, left, right, rows.rows[1] / rows.sheetHeight, rows.rows[2] / rows.sheetHeight)
    face:SetSize(width, Shape.BODY)
    Pin(face, "BOTTOMLEFT", group, "BOTTOMLEFT", x, 0)
    face:Show()
end

local function ShowTray(width)
    tray = tray or { group:CreateTexture(nil, "BACKGROUND"), group:CreateTexture(nil, "BACKGROUND"),
        group:CreateTexture(nil, "BORDER"), group:CreateTexture(nil, "BORDER") }
    local stone = math.min(width, 220)
    TraySlice(tray[1], 3, 36, 36 + stone, 0, stone)
    if width > stone then TraySlice(tray[2], 4, 0, width - stone, stone, width - stone) else tray[2]:Hide() end
    local post = Shape.POST_COLUMNS
    TraySlice(tray[3], 4, post[1], post[2], 0, Shape.POST, true)
    TraySlice(tray[4], 4, post[1], post[2], width - Shape.POST, Shape.POST)
end

local function HideTray()
    for _, face in ipairs(tray or {}) do face:Hide() end
end

-- The micro buttons' frame level: over the band and Action Bar 1.
function Look.ButtonLevel()
    local main = Look.MainBar()
    local over = main and Number(main:GetFrameLevel()) or 0
    return math.max((Number(band.frame:GetFrameLevel()) or 1) + 20, over + 10)
end

local function AnyProtected(entries)
    for _, entry in ipairs(entries) do
        if entry.IsProtected and entry:IsProtected() then return true end
    end
    return false
end

-- The buttons on the group: 25 units apart (28 wide, overlapping by 3), the
-- first 7 in, 2.5 up. False when a fight forbids it.
function Look.LayMicroButtons(shape)
    shape = shape or band.shape
    if not shape or not group then return false end
    local entries = Look.MicroList()
    if Look.InFight() and AnyProtected(entries) then return false end
    local sized = Number(Saved().microScale) or 1
    local docked = shape.microOn
    local against = docked and shape.fit or shape.fitAtOne -- a button's scale against the group
    local ownScale = docked and shape.fit or (shape.fitAtOne * sized / band.scale)
    local lift = docked and 38 * (shape.fitAtOne - shape.fit) / 2 or 0
    local level = Look.ButtonLevel()
    local slot = 0
    for _, entry in ipairs(entries) do
        if entry == StoreMicroButton then
            -- Never on the band: unseen, and parked off the screen rather than
            -- left with no anchors. The game's micro menu reads its edge
            -- buttons' centres as Edit Mode closes, and an unplaced shop
            -- button (the last one left in it) has none.
            Pin(entry, "TOPRIGHT", UIParent, "BOTTOMLEFT", -64, -64)
            Look.Fade(entry)
        elseif entry:IsShown() then
            Look.Remember(entry)
            if entry:GetParent() ~= band.frame then entry:SetParent(band.frame) end
            entry:SetSize(28, 38)
            entry:SetScale(ownScale)
            entry:SetFrameLevel(level)
            Pin(entry, "BOTTOMLEFT", group, "BOTTOMLEFT", 7 / against + Shape.MICRO_PITCH * slot, (2.5 + lift) / against)
            Look.microOnBand[entry] = true
            ns.SkinMicroButton(entry)
            Look.PaintMenu(entry)
            slot = slot + 1
        elseif entry ~= mapButton and entry:GetParent() == MicroMenu and entry:GetNumPoints() == 0 then
            -- A hidden button the game never placed, left in its menu once the
            -- shown ones are on the band: parked off the screen like the shop,
            -- so the menu's edge buttons always have a centre.
            Pin(entry, "TOPRIGHT", UIParent, "BOTTOMLEFT", -64, -64)
            Look.parkedMicro[entry] = true
        end
    end
    return true
end

function Look.LayMicro(shape)
    if band.microMoving or Look.InFight() then return end
    local holder = Group()
    if MicroMenu then
        Look.Fade(MicroMenu.BorderArt)
        Look.Fade(MicroMenu.BackgroundArt)
    end
    holder:ClearAllPoints()
    if shape.microOn then
        holder:SetScale(1)
        holder:SetPoint("BOTTOMLEFT", band.frame, "BOTTOMLEFT", shape.microX - 7, 0)
        holder:SetSize(math.max(1, shape.microEnd - (shape.microX - 7)), Shape.BODY)
        HideTray()
    else
        holder:SetScale((Number(Saved().microScale) or 1) / band.scale)
        local place = Look.MicroPlace()
        if place then
            holder:SetPoint(place[1], UIParent, place[2], place[3], place[4])
        else
            holder:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -6, 0)
        end
        local width = math.max(Shape.POST * 2, Shape.MicroFit(Look.MicroCount(), 1) - 36)
        holder:SetSize(width, Shape.BODY)
        ShowTray(width)
    end
    holder:SetFrameLevel(math.max(1, Look.ButtonLevel() - 1))
    Look.LayMicroButtons(shape)
end

-- The game's help ticket button over the menu button's corner.
function Look.AnchorHelpTicket()
    local ticket, corner = HelpOpenWebTicketButton, MainMenuMicroButton
    if band.active and ticket and corner then Pin(ticket, "CENTER", corner, "TOPRIGHT", -3, -5) end
end

---------------------------------------------------------------------------
-- Moving and sizing the menu: EraUI's own handle in Edit Mode
---------------------------------------------------------------------------

-- The nine-slice Blizzard's Edit Mode selection wears, built piece by piece.
local function SelectionLayout()
    local layout = {}
    for _, corner in ipairs({ { "TopLeft", -1, 1 }, { "TopRight", 1, 1 }, { "BottomLeft", -1, -1 }, { "BottomRight", 1, -1 } }) do
        layout[corner[1] .. "Corner"] = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8 * corner[2], y = 8 * corner[3] }
    end
    for _, edge in ipairs({ { "Top", "_" }, { "Bottom", "_" }, { "Left", "!" }, { "Right", "!" } }) do
        layout[edge[1] .. "Edge"] = { atlas = edge[2] .. "%s-NineSlice-Edge" .. edge[1] }
    end
    layout.Center = { atlas = "%s-NineSlice-Center", x = -8, y = 8, x1 = 8, y1 = -8 }
    return layout
end
local GRIP_LAYOUT = SelectionLayout()
local GRIP_IDLE, GRIP_HELD = "editmode-actionbar-highlight", "editmode-actionbar-selected"
local MENU_TITLE = HUD_EDIT_MODE_MICRO_MENU_LABEL or "Micro Menu"
local GRIP_HINTS = { "Drag to move. Let go near the bar to put it back.",
    "Click for its size and reset. The mouse wheel sizes it too." }

local grip, sizer
local before -- the menu's place, size and order before this Edit Mode session's first change

local function Kit(kit)
    if not grip or grip.kit == kit then return end
    grip.kit = kit
    if NineSliceUtil and NineSliceUtil.ApplyLayout then pcall(NineSliceUtil.ApplyLayout, grip, GRIP_LAYOUT, kit) end
end

local function Copied(place)
    return type(place) == "table" and { place[1], place[2], place[3], place[4] } or nil
end

local function Refill()
    if Look.RefreshMicroDialog then Look.RefreshMicroDialog() end
end

local function Undo()
    local record = before
    before = nil
    if not record or not ns.db then return end
    ns.db.microPos, ns.db.microScale, ns.db.bagsFirst = record.place, record.size, record.first
    Look.Save()
    Look.Queue()
    Refill()
end

-- The first micro change in an Edit Mode session is recorded, so Edit
-- Mode's Revert can put it back; Save just forgets it.
local function Touch()
    if before or not Look.EditModeOpen() then return end
    local saved = Saved()
    before = { place = Copied(saved.microPos), size = saved.microScale, first = saved.bagsFirst }
    local editor = EditModeManagerFrame
    if editor then
        Look.HookScript(editor.RevertAllChangesButton, "OnClick", Undo)
        Look.HookScript(editor.SaveChangesButton, "OnClick", function() before = nil end)
    end
end

function Look.ForgetMicroChange()
    before = nil
end

-- While a micro change waits and Edit Mode is open, its Save and Revert stay
-- usable (Edit Mode itself sees no change of its own).
function Look.KeepSaveRevert()
    local editor = EditModeManagerFrame
    if not before or not editor or not Look.EditModeOpen() then return end
    for _, which in ipairs({ editor.SaveChangesButton or false, editor.RevertAllChangesButton or false }) do
        if which and which.IsEnabled and not which:IsEnabled() then which:SetEnabled(true) end
    end
end

local function Changed()
    Look.Save()
    Look.Queue()
    Refill()
end

-- The middle of the right part of a band laid out with both the menu and the
-- bags (a band that isn't dragged is centred on the screen to find it), in
-- screen pixels.
local function SideLine()
    local saved, now = Saved(), band.shape
    local both = Shape.Compute({ microOn = true, bagsOn = true, pages = now and now.pages, icons = now and now.icons,
        microCount = Look.MicroCount(), microScale = Number(saved.microScale) or 1 })
    local pixels = Number(UIParent:GetEffectiveScale()) or 1
    local leftEdge
    if band.dragged and band.frame then
        leftEdge = (Number(band.frame:GetLeft()) or 0) * (Number(band.frame:GetEffectiveScale()) or pixels)
    else
        local across = Number(UIParent:GetWidth()) or 0
        leftEdge = (across / 2 + ((Number(saved.barOffsetX) or 0) - both.width / 2) * band.scale) * pixels
    end
    return leftEdge + (both.base + (both.width - both.base) / 2) * band.scale * pixels
end
Look.SideLine = SideLine

local function Pixels(region)
    local l, b, r = Number(region:GetLeft()), Number(region:GetBottom()), Number(region:GetRight())
    local s = Number(region:GetEffectiveScale())
    if l and b and r and s then return l * s, b * s, r * s end
    return nil
end

-- Near the band: a dropped piece's bottom near the band's, its middle over the
-- band's right half. Returns near, and its middle (pixels).
function Look.NearBand(piece)
    if not piece or not band.frame or not band.shape then return false end
    local l, b, r = Pixels(piece)
    local bl, bb, br = Pixels(band.frame)
    if not l or not bl then return false end
    local pixels = Number(UIParent:GetEffectiveScale()) or 1
    local bandPixels = Number(band.frame:GetEffectiveScale()) or pixels
    local middle = (l + r) / 2
    return Shape.NearBand(b, middle, bb, bl + band.shape.base * bandPixels, br, 48 * pixels), middle
end

-- Whether the bags go first once the menu (or, mirrored, the bag bar) lands
-- there; the menu's own side when the bags aren't on the band.
function Look.DropSide(middle, menuMoving)
    local saved, now = Saved(), band.shape
    local margin = 16 * (Number(UIParent:GetEffectiveScale()) or 1)
    if menuMoving then
        if now and not now.bagsOn then return false end
        return not Shape.GoesFirst(middle, SideLine(), not saved.bagsFirst, margin)
    end
    if now and not now.microOn then return saved.bagsFirst == true end
    return Shape.GoesFirst(middle, SideLine(), saved.bagsFirst == true, margin)
end

-- While the menu is in the player's hand, the band shows where it would go.
local function Preview()
    local now = band.shape
    if Saved().oneBar or not now then return end
    local near, middle = Look.NearBand(group)
    local want = { microOn = near and true or false, bagsOn = now.bagsOn,
        bagsFirst = near and Look.DropSide(middle, true) or false }
    local shown = band.preview
    if shown and shown.microOn == want.microOn and shown.bagsFirst == want.bagsFirst and shown.bagsOn == want.bagsOn then return end
    band.preview = want
    if Look.RunBandLayout and not Look.InFight() then Look.RunBandLayout() end
end

local function Drop()
    local saved = ns.db
    if not saved then return end
    band.preview = nil
    local near, middle = Look.NearBand(group)
    if near and not saved.oneBar then
        saved.microPos, saved.microScale = nil, nil
        saved.bagsFirst = Look.DropSide(middle, true)
    else
        local point, _, relativePoint, x, y = group:GetPoint(1)
        x, y = Number(x), Number(y)
        if type(point) == "string" and x and y then
            -- Kept in the units the menu has once dropped (its own size).
            local held = Number(group:GetEffectiveScale()) or 1
            local landed = (Number(UIParent:GetEffectiveScale()) or 1) * (Number(saved.microScale) or 1)
            local ratio = landed > 0 and held / landed or 1
            saved.microPos = { point, relativePoint or point, x * ratio, y * ratio }
        end
    end
    Changed()
    if Look.InFight() and Look.LayMicroButtons() and Look.SnapshotRows then Look.SnapshotRows() end
end

local function Wheel(_, delta)
    local saved = ns.db
    if not saved then return end
    Touch()
    local size = (Number(saved.microScale) or 1) + (delta > 0 and 0.05 or -0.05)
    saved.microScale = Look.Clamp(math.floor(size * 100 + 0.5) / 100, 0.5, 2)
    Changed()
end

local function ResetPlace()
    local saved = ns.db
    if not saved then return end
    Touch()
    saved.microPos, saved.microScale = nil, nil
    Changed()
end

local function ResetSize()
    local saved = ns.db
    if not saved then return end
    Touch()
    saved.microScale = nil
    Changed()
end

local function GripTip(owner)
    Look.ShowTip(owner, "TOP", { { MENU_TITLE, 1, 1, 1 }, { GRIP_HINTS[1], 1, 0.82, 0 }, { GRIP_HINTS[2], 1, 0.82, 0 } })
end

local function GripTake()
    if Look.InFight() and group:IsProtected() then return end
    Touch()
    band.microMoving, grip.dragged = true, true
    Kit(GRIP_HELD)
    group:StartMoving()
end

local function GripLet()
    group:StopMovingOrSizing()
    band.microMoving = false
    if not (sizer and sizer:IsShown()) then Kit(GRIP_IDLE) end
    Drop()
end

local function GripUp(self, which)
    if which == "RightButton" then ResetPlace()
    elseif which == "LeftButton" and not self.dragged then Look.OpenMicroDialog() end
end

local function Grip()
    if grip then return grip end
    grip = Look.Build("Frame", Group(), nil, { strata = "MEDIUM", level = 1010, mouse = true, wheel = true,
        drag = "LeftButton", hidden = true })
    grip:SetAllPoints(group)
    Kit(GRIP_IDLE)
    local caption = Look.Label(grip, "GameFontHighlightLarge", "OVERLAY")
    caption:SetPoint("CENTER")
    caption:SetText(MENU_TITLE)
    local scripts = {
        OnShow = function(self) self:SetFrameLevel(1010) end,
        OnEnter = GripTip,
        OnLeave = Look.HideTip,
        OnDragStart = GripTake,
        OnDragStop = GripLet,
        OnUpdate = function() if band.microMoving then Preview() end end,
        OnMouseWheel = Wheel,
        OnMouseDown = function(self) self.dragged = false end,
        OnMouseUp = GripUp,
    }
    for script, run in pairs(scripts) do grip:SetScript(script, run) end
    return grip
end

-- Shown only while Edit Mode is open.
function Look.ShowMicroHandle(open)
    if not open and not grip then return end
    Shown(Grip(), open)
    if not open and sizer then Shown(sizer, false) end
end

---------------------------------------------------------------------------
-- The Micro Menu dialog: its size, and resets
---------------------------------------------------------------------------

local filling = false

-- Each reset button usable only while there is something to reset.
local function ResetsUsable()
    if not sizer then return end
    local saved = Saved()
    sizer.placeReset:SetEnabled(type(saved.microPos) == "table")
    sizer.sizeReset:SetEnabled(math.abs((Number(saved.microScale) or 1) - 1) > 0.001)
end

local function SliderLabels(format)
    local labels = {}
    if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
        labels[MinimalSliderWithSteppersMixin.Label.Right] = format
    end
    return labels
end

local function OnSizeSlid(_, value)
    if filling or not ns.db then return end
    Touch()
    ns.db.microScale = Look.Clamp((Number(value) or 100) / 100, 0.5, 2)
    Look.Save()
    Look.Queue()
    ResetsUsable()
end

local function Backing(box)
    local fine, border = pcall(CreateFrame, "Frame", nil, box, "DialogBorderTranslucentTemplate")
    if fine and border then
        border:SetAllPoints(box)
        return
    end
    local shade = box:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.85)
end

local function WideButton(box, words, onClick)
    local wide = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    if ns.DarkNativeButton then ns.DarkNativeButton(wide) end
    wide:SetSize(330, 28)
    wide:SetText(words)
    wide:SetScript("OnClick", onClick)
    return wide
end

local function Sizer()
    if sizer then return sizer end
    sizer = Look.Build("Frame", UIParent, nil, { size = { 383, 204 }, strata = "DIALOG", level = 200, movable = true,
        clamped = true, mouse = true, drag = "LeftButton", hidden = true })
    sizer:SetScript("OnDragStart", sizer.StartMoving)
    sizer:SetScript("OnDragStop", sizer.StopMovingOrSizing)
    Backing(sizer)
    local heading = Look.Label(sizer, "GameFontHighlightLarge")
    heading:SetPoint("TOP", 0, -15)
    heading:SetText(MENU_TITLE)
    local shut = CreateFrame("Button", nil, sizer, "UIPanelCloseButton")
    if ns.DarkCloseButton then ns.DarkCloseButton(shut) end
    Pin(shut, "TOPRIGHT", sizer, "TOPRIGHT")
    shut:SetScript("OnClick", function() sizer:Hide() end)
    local named = Look.Label(sizer, "GameFontHighlightMedium")
    named:SetSize(100, 32)
    Pin(named, "TOPLEFT", sizer, "TOPLEFT", 20, -48)
    named:SetJustifyH("LEFT")
    named:SetText(HUD_EDIT_MODE_SETTING_MICRO_MENU_SIZE or "Size")
    local made, knob = pcall(CreateFrame, "Frame", nil, sizer, "MinimalSliderWithSteppersTemplate")
    if made and knob then
        knob:SetSize(200, 32)
        Pin(knob, "LEFT", named, "RIGHT", 5, 0)
        knob:Init((Number(Saved().microScale) or 1) * 100, 50, 200, 30,
            SliderLabels(function(value) return math.floor(value + 0.5) .. "%" end))
        if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Event then
            knob:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, OnSizeSlid, sizer)
        end
        sizer.knob = knob
    end
    sizer.placeReset = WideButton(sizer, HUD_EDIT_MODE_RESET_POSITION or "Reset To Default Position", ResetPlace)
    Pin(sizer.placeReset, "BOTTOM", sizer, "BOTTOM", 0, 22)
    sizer.sizeReset = WideButton(sizer, "Reset To Default Size", ResetSize)
    Pin(sizer.sizeReset, "BOTTOM", sizer.placeReset, "TOP", 0, 2)
    sizer:SetScript("OnShow", function()
        Kit(GRIP_HELD)
        Refill()
    end)
    sizer:SetScript("OnHide", function() Kit(GRIP_IDLE) end)
    return sizer
end

function Look.RefreshMicroDialog()
    if not sizer or not sizer:IsShown() then return end
    local saved = Saved()
    local size = Number(saved.microScale) or 1
    if sizer.knob then
        filling = true
        pcall(sizer.knob.SetValue, sizer.knob, size * 100)
        filling = false
    end
    ResetsUsable()
end

function Look.OpenMicroDialog()
    local box = Sizer()
    Pin(box, "BOTTOM", Group(), "TOP", 0, 40)
    box:Show()
    Refill()
end

---------------------------------------------------------------------------
-- Pressed while their windows are open
---------------------------------------------------------------------------

local function AnyOpen(...)
    for i = 1, select("#", ...) do
        if Seen((select(i, ...))) then return true end
    end
    return false
end

local function TalentsOpen()
    return AnyOpen(EraUIClassicTalents) or (Saved().talents == false and AnyOpen(PlayerSpellsFrame))
end

local WINDOWS_OF = {
    CharacterMicroButton = function() return AnyOpen(CharacterFrame) end,
    ProfessionMicroButton = function() return AnyOpen(ProfessionsFrame, ProfessionsBookFrame) end,
    SpellbookMicroButton = function()
        return AnyOpen(EraUIClassicSpellBook) or (Saved().spellBook == false and AnyOpen(PlayerSpellsFrame))
    end,
    TalentMicroButton = TalentsOpen,
    PlayerSpellsMicroButton = TalentsOpen,
    AchievementMicroButton = function() return AnyOpen(AchievementFrame) end,
    QuestLogMicroButton = function()
        return AnyOpen(EraUIClassicQuestLog) or (Saved().questLog == false and AnyOpen(WorldMapFrame))
    end,
    GuildMicroButton = function()
        return AnyOpen(FriendsFrame, GuildFrame) or (not ns.guildGhost and AnyOpen(CommunitiesFrame))
    end,
    LFDMicroButton = function() return AnyOpen(LFGParentFrame, PVEFrame) end,
    CollectionsMicroButton = function() return AnyOpen(CollectionsJournal) end,
    EJMicroButton = function() return AnyOpen(EncounterJournal) end,
    HelpMicroButton = function() return AnyOpen(HelpFrame) end,
    MainMenuMicroButton = function() return AnyOpen(GameMenuFrame) end,
    EraUIClassicWorldMapMicroButton = function() return AnyOpen(WorldMapFrame) end,
}

local function HeldDown(entry)
    return entry:IsMouseOver() and IsMouseButtonDown ~= nil and IsMouseButtonDown("LeftButton")
end

local function PressFollow()
    for _, entry in ipairs(order or {}) do
        local called = entry.GetName and entry:GetName()
        local isOpen = called and WINDOWS_OF[called]
        if isOpen and Look.microWorn[entry] and entry:IsEnabled() and not HeldDown(entry) then
            local fine, open = pcall(isOpen)
            local state = (fine and open) and "PUSHED" or "NORMAL"
            if entry:GetButtonState() ~= state then
                entry:SetButtonState(state, state == "PUSHED" or nil)
                if called == "CharacterMicroButton" then Look.MicroPortrait(entry) end
            end
        end
    end
end

-- Another window's button kept pressed after the game's own update while
-- that window shows (the band on or off).
local watchers = Look.Weak()

local function AfterOwnUpdate(entry)
    local fine, open = pcall(watchers[entry])
    if not (fine and open) or not entry:IsEnabled() then return end
    if type(entry.SetPushed) == "function" then entry:SetPushed() else entry:SetButtonState("PUSHED", true) end
end

local function FollowsWindow(entry, isShown)
    if not entry or watchers[entry] or type(isShown) ~= "function" then return end
    watchers[entry] = isShown
    Look.HookOwn(entry, "UpdateMicroButton", AfterOwnUpdate)
end

ns.RefreshMicroButtons = PressFollow
ns.MicroButtonFollows = FollowsWindow

---------------------------------------------------------------------------
-- The secure click pad: a secure button over a micro button that clicks the
-- target (by default the minimap's zone text button, which opens the map),
-- so a click works in a fight too. Made out of a fight only.
---------------------------------------------------------------------------

local padOf = Look.Weak()   -- micro button: its pad
local padFor = Look.Weak()  -- pad: { real button, after, target, when }
local asked = {}            -- pads asked for in a fight

local function PadEnter(clickPad)
    local spec = padFor[clickPad]
    local real = spec and spec[1]
    if not real then return end
    real:LockHighlight()
    -- The tip belongs to the pad (it lies exactly over the button), so the
    -- pad's leave takes it away again.
    if real == mapButton then
        MapTip(clickPad)
    elseif type(real.tooltipText) == "string" then
        Look.ShowTip(clickPad, "RIGHT", { { real.tooltipText, 1, 1, 1 } })
    end
end

local function PadLeave(clickPad)
    local spec = padFor[clickPad]
    if spec then spec[1]:UnlockHighlight() end
    Look.HideTip(clickPad)
end

local function MakePad(real, strata, after, target, when)
    local clicks = target or (MinimapCluster and MinimapCluster.ZoneTextButton)
    if not clicks then return nil end
    local clickPad = Look.Build("Button", UIParent, "SecureActionButtonTemplate", { size = { 28, 38 },
        strata = strata or "MEDIUM", hidden = true })
    for attribute, value in pairs({ type = "click", clickbutton = clicks, useOnKeyDown = false }) do
        clickPad:SetAttribute(attribute, value)
    end
    clickPad:RegisterForClicks("AnyUp", "AnyDown")
    padFor[clickPad] = { real, after, target, when }
    clickPad:SetScript("OnMouseDown", function() real:SetButtonState("PUSHED") end)
    clickPad:SetScript("OnMouseUp", function()
        local mapStaysDown = not after and not target and WorldMapFrame and WorldMapFrame:IsShown()
        if not mapStaysDown then real:SetButtonState("NORMAL") end
    end)
    if after then
        clickPad:SetScript("PostClick", function(_, _, isDown)
            if not isDown then after() end
        end)
    end
    clickPad:SetScript("OnEnter", PadEnter)
    clickPad:SetScript("OnLeave", PadLeave)
    padOf[real] = clickPad
    return clickPad
end

local function AskPad(real, strata, after, target, when)
    if not real or padOf[real] then return end
    if not (target or (MinimapCluster and MinimapCluster.ZoneTextButton)) then return end
    if Look.InFight() then
        asked[#asked + 1] = { real, strata, after, target, when }
        return
    end
    MakePad(real, strata, after, target, when)
end
ns.MapPad = AskPad

-- Where a pad goes: over its button (UIParent units), or nowhere.
local function PadSpot(real, spec, editing)
    if editing or not real:IsVisible() then return nil end
    local l, b = Number(real:GetLeft()), Number(real:GetBottom())
    local w, h = Number(real:GetWidth()), Number(real:GetHeight())
    if not (l and b and w and h) then return nil end
    if spec[4] then
        local fine, allowed = pcall(spec[4])
        if not (fine and allowed) then return nil end
    end
    local root = Number(UIParent:GetEffectiveScale()) or 1
    local f = (Number(real:GetEffectiveScale()) or root) / root
    return l * f, b * f, w * f, h * f
end

-- Every 0.2 s out of a fight: each pad over its button, or hidden.
local function KeepPads()
    if Look.InFight() then return end
    local editing = Look.EditModeOpen()
    for real, clickPad in pairs(padOf) do
        local x, y, w, h = PadSpot(real, padFor[clickPad], editing)
        if x then
            local px, py = Number(clickPad:GetLeft()), Number(clickPad:GetBottom())
            local off = not px or math.abs(px - x) > 0.5 or math.abs(py - y) > 0.5
                or math.abs((Number(clickPad:GetWidth()) or 0) - w) > 0.5
            if off then
                Pin(clickPad, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
                clickPad:SetSize(w, h)
            end
            clickPad:SetFrameLevel((Number(real:GetFrameLevel()) or 1) + 5)
        end
        Shown(clickPad, x ~= nil)
    end
end

local padWatch = CreateFrame("Frame")
padWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
padWatch:RegisterEvent("PLAYER_REGEN_DISABLED")
padWatch:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- A pad that opens one of EraUI's own windows stands down in a fight.
        for _, clickPad in pairs(padOf) do
            if padFor[clickPad][2] then Shown(clickPad, false) end
        end
        return
    end
    local waiting = asked
    asked = {}
    for _, ask in ipairs(waiting) do
        if not padOf[ask[1]] then MakePad(ask[1], ask[2], ask[3], ask[4], ask[5]) end
    end
end)
Look.Every(0.2, KeepPads)
