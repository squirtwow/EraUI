-- EraUI minimap.
-- The 1.x minimap cluster: a 192px stone ring with the zone name across the
-- top, the round map inside, tracking and mail on the left, zoom and day/night
-- on the right. Blizzard's frames are re-anchored inside the cluster and its
-- Layout hook keeps the size from drifting.
local _, EraUI = ...
local ns = EraUI.Classic

local CLUSTER = 192
local MAP = 140

local active = false
local hooked = false
-- The stone ring's art (EraUI's own textures), kept so Square Minimap can
-- put it aside and back.
local ringArt = {}

local function BuildRing()
    local cluster = MinimapCluster
    local backdrop = MinimapBackdrop
    if not cluster or not backdrop then return end
    local top = ns.OwnTexture(cluster, "borderTop", "ARTWORK")
    ns.SetTex(top, "minimapBorder")
    top:SetTexCoord(0.25, 1, 0, 0.125)
    top:SetSize(CLUSTER, 32)
    ns.SetPointOnce(top, "TOPRIGHT", cluster, "TOPRIGHT", 0, 0)
    local ring = ns.OwnTexture(backdrop, "ring", "ARTWORK")
    ns.SetTex(ring, "minimapBorder")
    ring:SetTexCoord(0.25, 1, 0.125, 0.875)
    ring:ClearAllPoints()
    ring:SetAllPoints(backdrop)
    ringArt.top, ringArt.ring = top, ring
    local north = ns.OwnTexture(backdrop, "north", "OVERLAY")
    ns.SetTex(north, "compassNorth")
    north:SetSize(16, 16)
    ns.SetPointOnce(north, "CENTER", Minimap, "CENTER", 0, 67)
    cluster.fcuiNorth = north
end

-- Square Minimap ----------------------------------------------------------------
-- Map & Minimap > Square Minimap (experimental, off unless ticked; it needs
-- Minimap, this look). The map goes square in a thin dark frame of EraUI's
-- own: a near-black edge with the Frame Style's fine line just inside it
-- (muted bronze in the Classic look, the Darkness grey in Dark Mode, live
-- with the slider), its top strip deep enough for the zone's name. The stone
-- ring, its top bar and the rotating compass ring step aside. The zoom
-- buttons and the queue eye move out of the square's corners to its edges;
-- tracking, mail, the calendar, day and night and the clock keep their
-- places, which already sit on its sides. EraUI's own button and the
-- drawer's go round the square too (Modules/MinimapTools.lua), and other
-- addons are told the map is square through the GetMinimapShape convention,
-- only while it's on and only when no other addon has claimed it. Square
-- Size, the slider under the switch, scales the whole square on top of Edit
-- Mode's Minimap Size (the cluster's scale, which this look already sets,
-- through Edit Mode's plain SetScaleBase: RescaleCluster); with the square
-- off it changes nothing.
-- The game's own pieces only get the cosmetic setters this look already
-- uses (mask, anchors, shown, the cluster's scale); the frame and its state
-- are EraUI's own. Switched or resized out of a fight only: a change in a
-- fight waits for its end (EraUI's own pass, booked); the line's tone
-- changes at once.
-- The game's own file and wrap for the hybrid map's mask, as its XML sets
-- them (Blizzard_HybridMinimap.xml), to give back.
local SQUARE_MASK = "Interface\\Buttons\\WHITE8X8"
local HYBRID_MASK, HYBRID_WRAP = "Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE"
-- The frame's edge round the map, the strip above it for the zone's name,
-- and its colours (Thick Frames' near black and bronze).
local EDGE, HEAD = 4, 18
local SHELL = { .05, .05, .06 }
local BRONZE = { .55, .46, .27 }
-- From the map's centre: the zoom buttons on the square's right edge, above
-- its corner, and the queue eye on its left edge, as far out as the mail and
-- tracking buttons sit (the round places, inside the square's corners, would
-- cover the map). The eye's is from the backdrop's top left, as PlaceEye
-- places it.
local SQUARE_ZOOM = { zoomIn = { 78, -20 }, zoomOut = { 78, -44 } }
local EYE_ROUND, EYE_SQUARE = { 38.5, -116.5 }, { 27, -112 }
-- Square Size (/era, under Square Minimap), in percent: the whole square
-- (map, frame, zone strip and buttons) on top of Edit Mode's Minimap Size.
local SIZE_MIN, SIZE_MAX, SIZE_DEFAULT = 75, 150, 100
-- on: the square look is worn now. size: Square Size as a scale, taken
-- with on (out of a fight only). shell, line: EraUI's frame's edge and line
-- strips, made the first time it's worn; r, g, b: the line's colour.
local square = { on = false, size = 1 }

-- What other addons read (LibDBIcon, HereBeDragons): only while the square
-- is worn, never over another addon's own answer, which is left as it is.
local function SquareShape() return "SQUARE" end
local function ClaimShape(on)
    local current = rawget(_G, "GetMinimapShape")
    if on then
        if current == nil then _G.GetMinimapShape = SquareShape end
    elseif current == SquareShape then
        _G.GetMinimapShape = nil
    end
end

local function SquareWanted()
    return active and EraUI:GetSetting("enabled") ~= false and EraUI:GetSetting("squareMinimap") == true
end

-- Square Size as a scale: 0.75 to 1.5, the nearest end when saved beyond
-- them; not a number (lost or broken): 100%.
local function SquareSize()
    local size = tonumber(EraUI:GetSetting("squareMinimapScale"))
    if not size or size ~= size or math.abs(size) == math.huge then size = SIZE_DEFAULT end
    return math.max(SIZE_MIN, math.min(SIZE_MAX, size)) / 100
end

function ns.SquareMinimapOn()
    return square.on
end

-- One of the frame's pieces pinned by two corners to the map's.
local function Span(piece, frame, from, x1, y1, to, x2, y2)
    piece:ClearAllPoints()
    piece:SetPoint("TOPLEFT", frame, from, x1, y1)
    piece:SetPoint("BOTTOMRIGHT", frame, to, x2, y2)
end

-- EraUI's own frame round the map: the edge's four strips (the top one with
-- the zone's strip), then the fine line's four, one unit wide, 1 to 2 units
-- out from the map, square at the corners. Drawn on the cluster itself, as
-- the stone ring's top bar is, so the zone's name and every button (all the
-- cluster's children) always draw over it, however the game layers them (a
-- frame of its own on the map was lifted over the zone's name in game).
local function BuildSquare(cluster, map)
    local shell, line = {}, {}
    for i = 1, 4 do
        shell[i] = cluster:CreateTexture(nil, "BACKGROUND")
        shell[i]:SetColorTexture(SHELL[1], SHELL[2], SHELL[3], 1)
        line[i] = cluster:CreateTexture(nil, "BORDER")
    end
    Span(shell[1], map, "TOPLEFT", -EDGE, EDGE + HEAD, "TOPRIGHT", EDGE, 0)
    Span(shell[2], map, "BOTTOMLEFT", -EDGE, 0, "BOTTOMRIGHT", EDGE, -EDGE)
    Span(shell[3], map, "TOPLEFT", -EDGE, 0, "BOTTOMLEFT", 0, 0)
    Span(shell[4], map, "TOPRIGHT", 0, 0, "BOTTOMRIGHT", EDGE, 0)
    Span(line[1], map, "TOPLEFT", -2, 2, "TOPRIGHT", 2, 1)
    Span(line[2], map, "BOTTOMLEFT", -2, -1, "BOTTOMRIGHT", 2, -2)
    Span(line[3], map, "TOPLEFT", -2, 1, "BOTTOMLEFT", -1, -1)
    Span(line[4], map, "TOPRIGHT", 1, 1, "BOTTOMRIGHT", 2, -1)
    square.shell, square.line = shell, line
end

-- The frame's strips shown or hidden together (once made).
local function ShowSquare(on)
    if not square.shell then return end
    for i = 1, 4 do
        square.shell[i]:SetShown(on)
        square.line[i]:SetShown(on)
    end
end

-- The line: the Darkness grey in Dark Mode, else muted bronze; set only when
-- it changes.
local function Tone()
    if not square.line then return end
    local r, g, b = BRONZE[1], BRONZE[2], BRONZE[3]
    if EraUI:GetSetting("darkMode") and ns.DarkGrey then r, g, b = ns.DarkGrey() end
    if square.r == r and square.g == g and square.b == b then return end
    square.r, square.g, square.b = r, g, b
    for _, strip in ipairs(square.line) do strip:SetColorTexture(r, g, b, 1) end
end

-- The hybrid map (the game's, loaded only where it's used) has a round mask
-- of its own: square with the rest, its own file back after.
local function HybridMask(on)
    local hybrid = rawget(_G, "HybridMinimap")
    local mask = type(hybrid) == "table" and hybrid.CircleMask
    if type(mask) ~= "table" or not mask.SetTexture then return end
    if on and square.hybrid ~= mask then
        mask:SetTexture(SQUARE_MASK, HYBRID_WRAP, HYBRID_WRAP)
        square.hybrid = mask
    elseif not on and square.hybrid == mask then
        mask:SetTexture(HYBRID_MASK, HYBRID_WRAP, HYBRID_WRAP)
        square.hybrid = nil
    end
end

-- The frame, the ring's art and the shape, as the square's on or off.
local function DressSquare(cluster, map)
    local on = square.on
    if ringArt.top then ringArt.top:SetShown(not on) end
    if ringArt.ring then ringArt.ring:SetShown(not on) end
    if on then
        if not square.shell then BuildSquare(cluster, map) end
        Tone()
    end
    ShowSquare(on)
    HybridMask(on)
    ClaimShape(on)
end

-- EraUI's button and the drawer's go round the square, or the ring again.
local function FollowSquare()
    local tools = EraUI.modules and EraUI.modules.MinimapTools
    if not tools then return end
    if tools.Position then tools:Position() end
    if tools.PlaceDrawerButton then tools:PlaceDrawerButton() end
end

local eyeWatch
local function EyeMoved(eye)
    if not eye.IsInDefaultPosition then return false end
    local ok, inDefault = pcall(eye.IsInDefaultPosition, eye)
    return ok and inDefault == false
end

local sizeReset
local function SizeResetButton()
    local dialog, eye = EditModeSystemSettingsDialog, QueueStatusButton
    local revert = dialog and dialog.Buttons and dialog.Buttons.RevertChangesButton
    if not revert or not eye then return end
    local show = active and dialog:IsShown() and dialog.attachedToSystem == eye and revert:IsVisible()
    if not sizeReset then
        if not show then return end
        sizeReset = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
        sizeReset:SetFrameStrata("DIALOG")
        sizeReset:SetText("Default Size")
        -- Dark Windows darkens it in Dark Mode, like the game's own red buttons.
        if ns.DarkNativeButton then ns.DarkNativeButton(sizeReset) end
        sizeReset:SetScript("OnClick", function()
            local setting = Enum.EditModeGroupFinderSetting and Enum.EditModeGroupFinderSetting.Size
            if not setting or InCombatLockdown() then return end
            if pcall(dialog.OnSettingValueChanged, dialog, setting, 100) then ns.editWrote = true end
        end)
    end
    if show then
        local scale = dialog:GetEffectiveScale() / UIParent:GetEffectiveScale()
        sizeReset:SetScale(scale > 0 and scale or 1)
        sizeReset:SetFrameLevel(dialog:GetFrameLevel() + 20)
        sizeReset:ClearAllPoints()
        sizeReset:SetPoint("LEFT", revert, "RIGHT", 6, 0)
        sizeReset:SetSize(144, 28)
        sizeReset:SetEnabled(math.abs((eye:GetScale() or 1) - 1) > 0.001)
    end
    sizeReset:SetShown(show)
end

local function PlaceEye()
    local eye, backdrop = QueueStatusButton, MinimapBackdrop
    if not eye or not backdrop then return end
    eye:SetSize(33, 33)
    local EYE_SCALE = 0.64
    if eye.Eye and eye.Eye.SetScale then
        eye.Eye:SetScale(EYE_SCALE)
        eye.Eye:ClearAllPoints()
        eye.Eye:SetPoint("CENTER", eye, "CENTER", 0.5 / EYE_SCALE, (0.5 - EYE_SCALE) / EYE_SCALE)
    end
    local over = eye.fcuiOver
    if not over then
        over = CreateFrame("Frame", nil, eye)
        over:SetAllPoints(eye)
        eye.fcuiOver = over
    end
    over:SetFrameLevel((eye.Eye and eye.Eye:GetFrameLevel() or eye:GetFrameLevel()) + 5)
    local border = ns.OwnTexture(over, "border", "OVERLAY")
    ns.SetTex(border, "trackingBorder")
    border:SetSize(52, 52)
    ns.SetPointOnce(border, "TOPLEFT", eye, "TOPLEFT", 1, -1)
    if eye.Selection and eye.Selection.SetFrameStrata and eye.Selection:GetFrameStrata() ~= "HIGH" then
        eye.Selection:SetFrameStrata("HIGH")
    end
    local dragging = eye.IsDragging and eye:IsDragging()
    if EyeMoved(eye) or dragging or InCombatLockdown() then return end
    if eye:GetParent() ~= UIParent then eye:SetParent(UIParent) end
    local own = eye:GetEffectiveScale()
    local k = (own and own > 0) and (backdrop:GetEffectiveScale() / own) or 1
    local spot = square.on and EYE_SQUARE or EYE_ROUND
    ns.SetPointOnce(eye, "CENTER", backdrop, "TOPLEFT", spot[1] * k, spot[2] * k)
end

-- In Dark Mode the zoom buttons' art goes dark with the rest, and their + and
-- - with it (they're painted into the art), so EraUI draws its own light ones
-- where the art has them: 10 across, bars 3 thick, 1.5 above the button's
-- middle. Dimmed while the map can't zoom any further.
local GLYPH = { .85, .85, .87 }
local glyphs = {}
local function ZoomGlyph(button, plus)
    if glyphs[button] or not EraUI:GetSetting("darkMode") then return end
    local bars = { button:CreateTexture(nil, "OVERLAY", nil, 7) }
    bars[1]:SetSize(10, 3)
    if plus then
        bars[2] = button:CreateTexture(nil, "OVERLAY", nil, 7)
        bars[2]:SetSize(3, 10)
    end
    for _, bar in ipairs(bars) do
        bar:SetColorTexture(GLYPH[1], GLYPH[2], GLYPH[3], 1)
        bar:SetPoint("CENTER", button, "CENTER", -0.5, 1.5)
    end
    glyphs[button] = bars
    local function Dim(self)
        for _, bar in ipairs(bars) do bar:SetAlpha(self:IsEnabled() and 1 or .4) end
    end
    button:HookScript("OnEnable", Dim)
    button:HookScript("OnDisable", Dim)
    Dim(button)
end

-- The day/night button: Forever's gold ring round the moon or sun takes Dark
-- Mode's grey like the stone ring; the moon and sun keep their colours. The
-- ring is the one texture on it that isn't its Background.
local function DarkDiel(diel)
    if not EraUI:GetSetting("darkMode") or not ns.ThemeTexture then return end
    for _, region in ipairs({ diel:GetRegions() }) do
        if region:IsObjectType("Texture") and region ~= diel.Background then ns.ThemeTexture(region, "dielBorder") end
    end
end

-- Edit Mode's Minimap Size as a scale (1 when it can't be read).
local function EditModeSize(cluster)
    if cluster.GetSettingValue and Enum and Enum.EditModeMinimapSetting and Enum.EditModeMinimapSetting.Size then
        local ok, value = pcall(cluster.GetSettingValue, cluster, Enum.EditModeMinimapSetting.Size)
        if ok and type(value) == "number" and value > 0 then return value / 100 end
    end
    return 1
end

-- The cluster is an Edit Mode frame: its own SetScale and SetPoint are Edit
-- Mode's, which record the frame it snaps to and mark every anchor changed.
-- Run from EraUI's code those records would carry EraUI's taint (as with the
-- unit frames, Classic/UnitFrames.lua Rescale), so the cluster takes its new
-- scale through Edit Mode's plain SetScaleBase, and its anchors go back
-- through SetPointBase where Edit Mode's own SetScale would keep them on the
-- screen. Never in a fight: then EraUI's pass after it is booked.
local function RescaleCluster(cluster, newScale)
    local oldScale = cluster:GetScale() or 1
    if math.abs(oldScale - newScale) <= 0.001 then return end
    if InCombatLockdown() then
        if ns.ApplyAll then ns.ApplyAll() end
        return
    end
    local base = cluster.SetScaleBase
    if not base then cluster:SetScale(newScale) return end
    local place = cluster.SetPointBase or cluster.SetPoint
    local points = {}
    for i = 1, cluster:GetNumPoints() do points[i] = { cluster:GetPoint(i) } end
    base(cluster, newScale)
    if oldScale <= 0 then return end
    for _, p in ipairs(points) do
        place(cluster, p[1], p[2], p[3], (p[4] or 0) * oldScale / newScale, (p[5] or 0) * oldScale / newScale)
    end
end

local function Layout()
    local cluster = MinimapCluster
    local backdrop = MinimapBackdrop
    local map = Minimap
    if not cluster or not backdrop or not map then ns.MissingPiece("MinimapCluster") return end
    -- The cluster takes Edit Mode's size (the game's container stays at 1),
    -- and while the square is worn its Square Size on top, so every place
    -- stays the same in the map's units.
    local size = EditModeSize(cluster) * (square.on and square.size or 1)
    if cluster.MinimapContainer and cluster.MinimapContainer:GetScale() ~= 1 then
        cluster.MinimapContainer:SetScale(1)
    end
    RescaleCluster(cluster, size)
    if cluster.BorderTop then cluster.BorderTop:SetScale(1) end
    if cluster.ZoneTextButton then cluster.ZoneTextButton:SetScale(1) end
    cluster:SetSize(CLUSTER, CLUSTER)
    if cluster.BorderTop then ns.Fade(cluster.BorderTop) end
    if cluster.MinimapContainer then
        cluster.MinimapContainer:SetSize(MAP, MAP)
        ns.SetPointOnce(cluster.MinimapContainer, "CENTER", cluster, "TOP", 9, -92)
    end
    map:SetSize(MAP, MAP)
    map:ClearAllPoints()
    if cluster.MinimapContainer then
        map:SetPoint("CENTER", cluster.MinimapContainer, "CENTER", 0, 0)
    else
        map:SetPoint("CENTER", cluster, "TOP", 9, -92)
    end
    if map.SetMaskTexture then map:SetMaskTexture(square.on and SQUARE_MASK or (ns.TexPath("portraitMask"))) end
    backdrop:SetSize(CLUSTER, CLUSTER)
    ns.SetPointOnce(backdrop, "CENTER", cluster, "CENTER", 0, -20)
    if backdrop.StaticOverlayTexture then ns.Fade(backdrop.StaticOverlayTexture) end
    if MinimapCompassTexture then
        ns.SetTex(MinimapCompassTexture, "compassRing")
        MinimapCompassTexture:SetTexCoord(0, 1, 0, 1)
        MinimapCompassTexture:SetSize(256, 256)
        ns.SetPointOnce(MinimapCompassTexture, "CENTER", map, "CENTER", -2, 0)
        MinimapCompassTexture:SetDrawLayer("OVERLAY")
    end
    if MinimapCompassTextureUnderlay then ns.Fade(MinimapCompassTextureUnderlay) end
    local rotate = C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("rotateMinimap")
    -- The rotating compass ring is round: the square has none.
    if MinimapCompassTexture then MinimapCompassTexture:SetShown((rotate and not square.on) and true or false) end
    if cluster.fcuiNorth then cluster.fcuiNorth:SetShown(not rotate) end

    -- The zone's name across the top: on the stone bar, or centred on the
    -- square's top strip.
    local zoneTo, zoneX, zoneY = cluster, 0, -12
    if square.on then zoneTo, zoneY = map, 2 + (EDGE + HEAD - 2) / 2 end
    if MinimapZoneText then
        MinimapZoneText:SetSize(MAP, 12)
        MinimapZoneText:SetJustifyH("CENTER")
        ns.SetPointOnce(MinimapZoneText, "CENTER", zoneTo, "TOP", zoneX, zoneY)
    end
    if cluster.ZoneTextButton then
        cluster.ZoneTextButton:SetSize(MAP, 12)
        ns.SetPointOnce(cluster.ZoneTextButton, "CENTER", zoneTo, "TOP", zoneX, zoneY)
    end

    local above = map:GetFrameLevel() + 5

    for _, entry in ipairs({ { map.ZoomIn, "zoomIn", 72, -25 }, { map.ZoomOut, "zoomOut", 50, -43 } }) do
        local button, key, x, y = entry[1], entry[2], entry[3], entry[4]
        if button then
            button:SetParent(backdrop)
            button:SetFrameLevel(above)
            button:SetSize(32, 32)
            ns.SetButtonTex(button, "Normal", key .. "Up")
            ns.SetButtonTex(button, "Pushed", key .. "Down")
            ns.SetButtonTex(button, "Disabled", key .. "Disabled")
            ns.SetButtonTex(button, "Highlight", "zoomHighlight")
            for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
                local tex = button["Get" .. state .. "Texture"](button)
                if tex then
                    tex:SetTexCoord(0, 1, 0, 1)
                    tex:ClearAllPoints()
                    tex:SetAllPoints(button)
                end
            end
            button:GetHighlightTexture():SetBlendMode("ADD")
            button:SetHitRectInsets(4, 4, 2, 6)
            local spot = square.on and SQUARE_ZOOM[key]
            if spot then ns.SetPointOnce(button, "CENTER", map, "CENTER", spot[1], spot[2])
            else ns.SetPointOnce(button, "CENTER", backdrop, "CENTER", x, y) end
            ZoomGlyph(button, key == "zoomIn")
            button:Show()
        end
    end

    local tracking = cluster.Tracking
    if tracking then
        tracking:SetParent(backdrop)
        tracking:SetFrameLevel(above)
        tracking:SetSize(32, 32)
        ns.SetPointOnce(tracking, "TOPLEFT", backdrop, "TOPLEFT", 9, -45)
        if tracking.Background then
            ns.SetTex(tracking.Background, "minimapBackground")
            tracking.Background:SetTexCoord(0, 1, 0, 1)
            tracking.Background:SetSize(25, 25)
            ns.SetPointOnce(tracking.Background, "TOPLEFT", tracking, "TOPLEFT", 2, -4)
            tracking.Background:SetAlpha(0.6)
        end
        local border = ns.OwnTexture(tracking, "border", "BORDER")
        ns.SetTex(border, "trackingBorder")
        border:SetSize(54, 54)
        ns.SetPointOnce(border, "TOPLEFT", tracking, "TOPLEFT", 0, 0)
        if tracking.Button then
            local button = tracking.Button
            button:SetSize(32, 32)
            button:SetFrameLevel(above + 1)
            ns.SetPointOnce(button, "TOPLEFT", tracking, "TOPLEFT", 0, 0)
            for _, state in ipairs({ "Normal", "Pushed" }) do
                local tex = button["Get" .. state .. "Texture"](button)
                if tex then
                    tex:SetSize(20, 20)
                    tex:ClearAllPoints()
                    tex:SetPoint("TOPLEFT", tracking, "TOPLEFT", state == "Pushed" and 8 or 6, state == "Pushed" and -8 or -6)
                end
            end
            local function OldGlass()
                for _, state in ipairs({ "Normal", "Pushed" }) do
                    local tex = button["Get" .. state .. "Texture"](button)
                    if tex and tex.GetAtlas and tex:GetAtlas() then
                        ns.SetTex(tex, "trackingNone")
                        tex:SetTexCoord(0, 1, 0, 1)
                        tex:SetSize(20, 20)
                    end
                end
            end
            OldGlass()
            if not tracking.fcuiGlassWatch then
                local watch = CreateFrame("Frame", nil, tracking)
                tracking.fcuiGlassWatch = watch
                watch:SetScript("OnUpdate", function(self, elapsed)
                    self.since = (self.since or 0) + elapsed
                    if self.since < 0.2 then return end
                    self.since = 0
                    if active then OldGlass() end
                end)
            end
            ns.SetButtonTex(button, "Highlight", "zoomHighlight")
            local hl = button:GetHighlightTexture()
            if hl then hl:SetTexCoord(0, 1, 0, 1); hl:ClearAllPoints(); hl:SetAllPoints(button); hl:SetBlendMode("ADD") end
        end
    end

    local indicator = cluster.IndicatorFrame
    if indicator then
        indicator:SetParent(cluster)
        indicator:SetFrameLevel(above)
        indicator:SetSize(33, 33)
        ns.SetPointOnce(indicator, "TOPRIGHT", map, "TOPRIGHT", 24, -37)
        if indicator.MailFrame then
            indicator.MailFrame:SetSize(33, 33)
            ns.SetPointOnce(indicator.MailFrame, "TOPRIGHT", map, "TOPRIGHT", 24, -37)
            local border = ns.OwnTexture(indicator.MailFrame, "border", "OVERLAY")
            ns.SetTex(border, "trackingBorder")
            border:SetSize(52, 52)
            ns.SetPointOnce(border, "TOPLEFT", indicator.MailFrame, "TOPLEFT", 0, 0)
            if MiniMapMailIcon then
                MiniMapMailIcon:SetTexture("Interface\\Icons\\INV_Letter_15")
                MiniMapMailIcon:SetSize(18, 18)
                ns.SetPointOnce(MiniMapMailIcon, "TOPLEFT", indicator.MailFrame, "TOPLEFT", 7, -6)
            end
        end
        if indicator.CraftingOrderFrame then
            indicator.CraftingOrderFrame:SetSize(33, 33)
            ns.SetPointOnce(indicator.CraftingOrderFrame, "TOPLEFT", indicator, "TOPLEFT", 0, 0)
        end
    end

    if cluster.DielFrame then
        ns.SetPointOnce(cluster.DielFrame, "TOPRIGHT", map, "TOPRIGHT", 20, -2)
        DarkDiel(cluster.DielFrame)
    end
    if GameTimeFrame then
        GameTimeFrame:SetParent(map)
        GameTimeFrame:SetFrameLevel(above)
        GameTimeFrame:SetSize(40, 40)
        ns.SetPointOnce(GameTimeFrame, "TOPRIGHT", map, "TOPRIGHT", 20, -2)
        GameTimeFrame:SetHitRectInsets(6, 0, 5, 10)
        ns.SkinCalendar()
    end

    if TimeManagerClockButton then
        local clock = TimeManagerClockButton
        clock:SetParent(map)
        clock:SetFrameLevel(above)
        clock:SetSize(60, 28)
        ns.SetPointOnce(clock, "CENTER", map, "CENTER", 0, -75)
        for _, region in ipairs({ clock:GetRegions() }) do
            if region:IsObjectType("Texture") and not (clock.fcui and clock.fcui.bg == region) then region:SetAlpha(0) end
        end
        local bg = ns.OwnTexture(clock, "bg", "BORDER")
        bg:SetAlpha(1)
        ns.SetTex(bg, "clockBackground")
        bg:SetTexCoord(0.015625, 0.8125, 0.015625, 0.390625)
        bg:SetAllPoints(TimeManagerClockButton)
        if TimeManagerClockTicker then ns.SetPointOnce(TimeManagerClockTicker, "CENTER", TimeManagerClockButton, "CENTER", 3, 1) end
    end

    if QueueStatusButton then
        PlaceEye()
        if not eyeWatch then
            eyeWatch = CreateFrame("Frame")
            eyeWatch:SetScript("OnUpdate", function(self, elapsed)
                self.since = (self.since or 0) + elapsed
                if self.since < 0.1 then return end
                self.since = 0
                SizeResetButton()
                if not active or not QueueStatusButton then return end
                local moved = EyeMoved(QueueStatusButton)
                local scale = QueueStatusButton:GetEffectiveScale()
                if moved ~= self.moved or scale ~= self.scale then
                    self.moved, self.scale = moved, scale
                    PlaceEye()
                end
            end)
        end
    end
    if cluster.InstanceDifficulty then
        ns.SetPointOnce(cluster.InstanceDifficulty, "TOPLEFT", cluster, "TOPLEFT", 22, -17)
    end
    if ExpansionLandingPageMinimapButton then
        ExpansionLandingPageMinimapButton:SetAlpha(0)
        ExpansionLandingPageMinimapButton:EnableMouse(false)
    end
    if AddonCompartmentFrame then AddonCompartmentFrame:Hide() end

    -- Square Minimap's frame and shape (or the ring again), before the
    -- library's buttons are placed, so they read the shape.
    DressSquare(cluster, map)

    local ldbi = LibStub and LibStub.GetLibrary and LibStub:GetLibrary("LibDBIcon-1.0", true)
    if ldbi and ldbi.GetButtonList and ldbi.Refresh then
        for _, name in ipairs(ldbi:GetButtonList()) do pcall(ldbi.Refresh, ldbi, name) end
    end
    if ns.OnMinimapLaid then ns.OnMinimapLaid(ldbi) end
end

function ns.SkinCalendar()
    local button = GameTimeFrame
    if not button or not active then return end
    ns.SetButtonTex(button, "Normal", "calendarButton")
    ns.SetButtonTex(button, "Pushed", "calendarButton")
    ns.SetButtonTex(button, "Highlight", "zoomHighlight")
    local normal, pushed, hl = button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture()
    if normal then normal:SetTexCoord(0, 0.390625, 0, 0.78125); normal:ClearAllPoints(); normal:SetAllPoints(button); normal:SetDrawLayer("BACKGROUND") end
    if pushed then pushed:SetTexCoord(0.5, 0.890625, 0, 0.78125); pushed:ClearAllPoints(); pushed:SetAllPoints(button); pushed:SetDrawLayer("BACKGROUND") end
    if hl then hl:SetTexCoord(0, 1, 0, 1); hl:ClearAllPoints(); hl:SetAllPoints(button); hl:SetBlendMode("ADD") end
    for _, region in ipairs({ button:GetRegions() }) do
        if region:IsObjectType("Texture") and region ~= normal and region ~= pushed and region ~= hl then region:SetAlpha(0) end
    end
    local day = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime().monthDay
    local fs = button:GetFontString()
    if not fs then
        button:SetNormalFontObject("GameFontBlack")
        fs = button:CreateFontString(nil, "OVERLAY", "GameFontBlack")
        button:SetFontString(fs)
    end
    fs:SetFontObject("GameFontBlack")
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", button, "CENTER", -1, -1)
    fs:SetDrawLayer("OVERLAY")
    if day then button:SetText(day) end
end

-- The game puts its own round mask back when map rotation is switched (its
-- Camelot minimap skin, on the rotateMinimap setting). Edit Mode's switch
-- runs Layout through the SetRotateMinimap hook below; the game's Options
-- window doesn't, so while the square is worn its mask goes back on the
-- frame after (EraUI's own event frame).
local rotationWatch
local function WatchRotation()
    if rotationWatch then return end
    rotationWatch = CreateFrame("Frame")
    if not pcall(rotationWatch.RegisterEvent, rotationWatch, "CVAR_UPDATE") then return end
    rotationWatch:SetScript("OnEvent", function(_, _, name)
        if type(name) ~= "string" or name:lower() ~= "rotateminimap" or not square.on then return end
        C_Timer.After(0, function() if active and square.on then Layout() end end)
    end)
end

local function Apply()
    active = true
    if not MinimapCluster then ns.MissingPiece("MinimapCluster") return end
    -- EraUI's passes never run in a fight (Classic/Core.lua ns.ApplyAll), so
    -- the square goes on or off here as wanted.
    local wanted = SquareWanted()
    local changed = wanted ~= square.on
    square.on = wanted
    square.size = SquareSize()
    BuildRing()
    Layout()
    if changed then FollowSquare() end
    if not hooked then
        hooked = true
        WatchRotation()
        ns.HookMethod(MinimapCluster, "Layout", function() if active then Layout() end end)
        ns.HookMethod(MinimapCluster, "SetRotateMinimap", function() if active then Layout() end end)
        if MinimapCluster.IndicatorFrame then
            ns.HookMethod(MinimapCluster.IndicatorFrame, "Layout", function() if active then Layout() end end)
        end
        if QueueStatusButton then
            ns.HookMethod(QueueStatusButton, "UpdatePosition", function() if active then Layout() end end)
        end
        if AddonCompartmentFrame then
            ns.HookMethod(AddonCompartmentFrame, "UpdateDisplay", function(self) if active then self:Hide() end end)
        end
        ns.HookGlobal("GameTimeFrame_SetDate", ns.SkinCalendar)
        if ExpansionLandingPageMinimapButton then
            ns.HookMethod(ExpansionLandingPageMinimapButton, "UpdateIcon", function(self)
                if active then self:SetAlpha(0); self:EnableMouse(false) end
            end)
        end
        if Minimap then
            ns.HookScriptOnce(Minimap, "OnLeave", function(self)
                if active then
                    if self.ZoomIn then self.ZoomIn:Show() end
                    if self.ZoomOut then self.ZoomOut:Show() end
                end
            end)
        end
    end
end

-- Square Minimap's switch and its Square Size slider in /era
-- (Core/Settings.lua): the square on or off, or its new size, at once, out
-- of a fight; in a fight nothing changes and EraUI's pass after it is
-- booked: returns false then. Without this look applied (Minimap off, or
-- waiting for a reload), or a new size with the square off, there is
-- nothing to change. A new size moves no button: EraUI's own sit on the
-- map and go with its scale.
function ns.RefreshSquareMinimap()
    local wanted, size = SquareWanted(), SquareSize()
    local turned = wanted ~= square.on
    if not turned and (not wanted or size == square.size) then return true end
    if InCombatLockdown() then
        if ns.ApplyAll then ns.ApplyAll() end
        return false
    end
    square.on = wanted
    square.size = size
    Layout()
    if turned then FollowSquare() end
    return true
end

-- The Darkness slider (Core/Appearance.lua RefreshDarkness): the line takes
-- the new grey at once (EraUI's own textures, so in a fight too).
function ns.RefreshSquareMinimapLine()
    if square.on then Tone() end
end

local function Restore()
    active = false
    if square.on then
        square.on = false
        ShowSquare(false)
        if Minimap and Minimap.SetMaskTexture then Minimap:SetMaskTexture((ns.TexPath("portraitMask"))) end
        -- Square Size goes with it: Edit Mode's size alone, as the round look.
        if MinimapCluster then RescaleCluster(MinimapCluster, EditModeSize(MinimapCluster)) end
        HybridMask(false)
        ClaimShape(false)
        FollowSquare()
    end
    if MinimapCluster and MinimapCluster.fcui then
        for _, tex in pairs(MinimapCluster.fcui) do tex:Hide() end
    end
    if MinimapBackdrop and MinimapBackdrop.fcui then
        for _, tex in pairs(MinimapBackdrop.fcui) do tex:Hide() end
    end
    if MinimapCluster and MinimapCluster.BorderTop then ns.Unfade(MinimapCluster.BorderTop) end
    ns.needsReload = true
end

ns.RegisterModule("minimap", { apply = Apply, restore = Restore })
