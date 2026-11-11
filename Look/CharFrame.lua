-- The character window's frame (Classic look, "characterSheet"): the 1.x
-- 384 x 512 window with its stone and parchment art, the ring over the
-- portrait, the title and "Level N Race Class" line, the red X, the gear
-- slots down both sides with the weapons under the model, the model zoomed
-- out a little, and the two round rotate buttons.
--
-- The game's own art is faded (alpha, never Hide: the game shows its pieces
-- again all the time). The slots are only re-anchored: never re-parented,
-- rescaled or faded themselves (Character Item Levels draws on them).
local _, EraUI = ...
local Look = EraUI.Look
local C = Look.Char

local LEFT_SLOTS = Look.Words("Head Neck Shoulder Back Chest Shirt Tabard Wrist")
local RIGHT_SLOTS = Look.Words("Hands Waist Legs Feet Finger0 Finger1 Trinket0 Trinket1")
local WEAPON_SLOTS = Look.Words("MainHand SecondaryHand Ranged")
local MODEL_BACKDROP = Look.Words("BackgroundTopLeft BackgroundTopRight BackgroundBotLeft BackgroundBotRight BackgroundOverlay")
local RING_W, RING_H = 80, 73

C.sheetArt = { general = {}, tab = {} } -- the eight pieces of 1.x art
C.rings = {}                            -- general, tab: EraUI's frames over the portrait

---------------------------------------------------------------------------
-- The 1.x art and the rings
---------------------------------------------------------------------------

-- One set of four pieces on a frame (general: under every tab; tab: the
-- Character tab's, over it).
function C.PutSheet(owner, set, sublevel, into)
    for i, piece in ipairs(C.SHEET_PIECES[set]) do
        local texture = Look.OwnTexture(owner, "sheet" .. set .. i, "BACKGROUND", sublevel)
        Look.Art(texture, piece[1])
        Look.Crop(texture, 0, 1, 0, 1)
        texture:SetSize(piece[2], 256)
        Look.Pin(texture, "TOPLEFT", owner, "TOPLEFT", piece[3], piece[4])
        if into then into[i] = texture end
    end
end

-- A frame over the portrait showing the art's top-left corner, so the
-- portrait sits under the art's ring.
function C.MakeRing(owner, artKey, level)
    local ring = Look.Build("Frame", owner, nil, { size = { RING_W, RING_H }, level = level })
    Look.Pin(ring, "TOPLEFT", owner, "TOPLEFT", 0, 0)
    local face = Look.OwnTexture(ring, "face", "ARTWORK")
    Look.Art(face, artKey)
    Look.Crop(face, 0, RING_W / 256, 0, RING_H / 256)
    Look.Fill(face, ring)
    return ring
end

local function PortraitLevel(window)
    local holder = window.PortraitContainer or window
    return Look.Number(holder:GetFrameLevel()) or 1
end

function C.MakeArt(sheet, paper)
    C.PutSheet(sheet, "general", -2, C.sheetArt.general)
    C.PutSheet(paper, "tab", -1, C.sheetArt.tab)
    local level = PortraitLevel(sheet)
    C.rings.general = C.MakeRing(sheet, "charGeneralTopLeft", level + 1)
    C.rings.tab = C.MakeRing(paper, "charTabTopLeft", level + 2)
end

function C.ShowArt(on)
    for _, set in pairs(C.sheetArt) do
        for _, texture in ipairs(set) do Look.Shown(texture, on) end
    end
    for _, ring in pairs(C.rings) do Look.Shown(ring, on) end
end

---------------------------------------------------------------------------
-- The window's size and the game's own art
---------------------------------------------------------------------------

function C.LayWindow(sheet, paper)
    if C.Free(sheet) then sheet:SetSize(C.SHEET_W, C.SHEET_H) end
    for _, key in ipairs(Look.Words("NineSlice Bg TopTileStreaks Inset InsetRight")) do Look.Fade(sheet[key]) end
    local model = C.Model()
    for _, key in ipairs(MODEL_BACKDROP) do
        Look.Fade(paper[key])
        if model then Look.Fade(model[key]) end
    end
    -- Forever's gold swirl after a poison or enchant lands on your gear
    -- (not in 1.x): faded only, its scripts and events left to the game.
    if model then Look.Fade(model.GearEnchantAnimation) end
    -- Forever's grey strip behind its level line (a tiled rock strip and its
    -- edge, across the left pane), newer than the 1.x window: faded as a
    -- whole, so the strip never shows across the top of the 1.x art. Its
    -- place stays, as the model and the level line are anchored to it.
    Look.Fade(paper and paper.TopBackgroundStripHost)
    local left = sheet.LeftPaneHost
    if left then
        Look.EachRegion(left, function(piece)
            if piece.IsObjectType and piece:IsObjectType("Texture") then Look.Fade(piece) end
        end)
        if C.Free(left) then
            left:ClearAllPoints()
            left:SetPoint("TOPLEFT", sheet, "TOPLEFT", 6, -60)
            left:SetPoint("BOTTOMRIGHT", sheet, "BOTTOMRIGHT", -6, 82)
        end
    end
    Look.Fade(sheet.RightPaneHost)
    Look.Fade(sheet.RightPaneToggleButton)
    C.Mouse(sheet.RightPaneToggleButton, false)
    Look.Fade(sheet.ModeTabs)
    C.Mouse(sheet.ModeTabs, false)
end

---------------------------------------------------------------------------
-- Portrait, title, level line, close button
---------------------------------------------------------------------------

function C.LayPortrait(sheet)
    local portrait = sheet.PortraitContainer and sheet.PortraitContainer.portrait
    if not portrait then return end
    portrait:SetSize(62, 62)
    Look.Pin(portrait, "TOPLEFT", sheet, "TOPLEFT", 9, -6)
    Look.WatchPortrait(portrait)
end

local function TitleText(sheet)
    return sheet.TitleContainer and sheet.TitleContainer.TitleText
end

-- "Level 12 Human Rogue": the game's word, the level (empty when the game
-- keeps it hidden), race and class, single spaces between.
function C.LevelWords()
    local level = UnitLevel("player")
    level = Look.Number(level) and C.Whole(level) or ""
    local race = UnitRace("player")
    local class = UnitClass("player")
    if Look.Secret(race) or type(race) ~= "string" then race = "" end
    if Look.Secret(class) or type(class) ~= "string" then class = "" end
    return table.concat({ C.Text("LEVEL", "Level"), level, race, class }, " ")
end

function C.WriteLevel()
    local line = C.levelLine
    if line and line:IsShown() then line:SetText(C.LevelWords()) end
    Look.Fade(CharacterLevelText)
end

-- The name in the middle of the art's top band, clear of the line under
-- it (at 24 down it sat on that line); the level line where it was, below.
C.TITLE_Y, C.LEVEL_GAP = -19, -11

function C.LayTitle(sheet)
    local title = TitleText(sheet)
    if not title then return end
    Look.Pin(title, "TOP", sheet, "TOP", 6, C.TITLE_Y)
    title:SetFontObject(GameFontNormal)
    if not C.levelLine then
        C.levelLine = Look.OwnLabel(sheet, "levelLine", "GameFontNormalSmall", "OVERLAY")
    end
    Look.Pin(C.levelLine, "TOP", title, "BOTTOM", 0, C.LEVEL_GAP)
    C.levelLine:Show()
    C.WriteLevel()
end

function C.LayClose(sheet)
    local close = sheet.CloseButton
    if not close or not C.Free(close) then return end
    Look.Pin(close, "CENTER", sheet, "TOPRIGHT", -44, -25)
    Look.SkinCloseButton(close)
end

---------------------------------------------------------------------------
-- Slots
---------------------------------------------------------------------------

local function FadeSlotArt(slot, name)
    Look.Fade(_G[name .. "Frame"])
    Look.Fade(slot.BorderFrame)
end

-- One column or row: each slot after the first hangs off the last slot
-- that exists.
local function LaySlotRun(paper, names, first, follow)
    local last
    for _, short in ipairs(names) do
        local name = "Character" .. short .. "Slot"
        local slot = _G[name]
        if slot then
            if C.Free(slot) then
                if last then
                    Look.Pin(slot, "TOPLEFT", last, follow[1], follow[2], follow[3])
                else
                    Look.Pin(slot, "TOPLEFT", paper, first[1], first[2], first[3])
                end
            end
            FadeSlotArt(slot, name)
            last = slot
        end
    end
end

function C.LaySlots(paper)
    LaySlotRun(paper, LEFT_SLOTS, { "TOPLEFT", 21, -74 }, { "BOTTOMLEFT", 0, -4 })
    LaySlotRun(paper, RIGHT_SLOTS, { "TOPLEFT", 306, -74 }, { "BOTTOMLEFT", 0, -4 })
    LaySlotRun(paper, WEAPON_SLOTS, { "BOTTOMLEFT", 122, 127 }, { "TOPRIGHT", 5, 0 })
    local ammo = CharacterAmmoSlot
    if ammo then
        FadeSlotArt(ammo, "CharacterAmmoSlot")
        C.FadeAtlas(ammo, "gearslot")
        for _, child in ipairs({ ammo:GetChildren() }) do C.FadeAtlas(child, "gearslot") end
    end
end

---------------------------------------------------------------------------
-- The model: its place, its controls hidden, its camera a little further out
---------------------------------------------------------------------------

local controlsWatched = Look.Weak()
local fittedCameras = Look.Weak()

function C.LayModel(paper)
    local model = C.Model()
    if model == nil then return end
    if C.Free(model) then
        Look.Pin(model, "TOPLEFT", paper, "TOPLEFT", 65, -78)
        -- 11 shorter while the stat panes stand under it.
        model:SetSize(233, (Look.Saved().statPanes == true) and 213 or 224)
    end
    local controls = model.ControlFrame
    if controls then
        Look.Fade(controls)
        controls:Hide()
        C.Mouse(controls, false)
        if not controlsWatched[controls] then
            controlsWatched[controls] = true
            Look.HookScript(controls, "OnShow", function(shown) if C.active then shown:Hide() end end)
        end
    end
    C.FitCamera()
end

-- The 1.x model showed more of the character than the game's camera: each
-- camera is wheeled out three notches once, through its own wheel (the
-- scene's wheel hands the notch to it the same way).
function C.FitCamera()
    local model = C.Model()
    local asked, camera = Look.Ask(model, "GetActiveCamera")
    if not asked or type(camera) ~= "table" or fittedCameras[camera] then return end
    fittedCameras[camera] = true
    local wheel, owner = camera.OnMouseWheel, camera
    if type(wheel) ~= "function" then wheel, owner = model.OnMouseWheel, model end
    if type(wheel) ~= "function" then return end
    for _ = 1, 3 do pcall(wheel, owner, -1) end
end

---------------------------------------------------------------------------
-- The rotate buttons
---------------------------------------------------------------------------

local turning = { way = 0 }
local turner = Look.Build("Frame", UIParent, nil, { size = { 1, 1 }, hidden = true })

local function TurnActor(scene)
    local asked, actor = Look.Ask(scene, "GetPlayerActor")
    if not asked or type(actor) ~= "table" then asked, actor = Look.Ask(scene, "GetActorByTag", "player") end
    if not asked or type(actor) ~= "table" then
        local tags = rawget(scene, "tagToActor")
        actor = type(tags) == "table" and select(2, next(tags)) or nil
    end
    if type(actor) == "table" and type(actor.GetYaw) == "function" and type(actor.SetYaw) == "function" then
        return actor
    end
end

local function StopTurning()
    turning.way = 0
    turner:Hide()
end
C.StopTurning = StopTurning

turner:SetScript("OnUpdate", function(_, elapsed)
    local scene = C.Model()
    if turning.way == 0 or not (scene and scene:IsVisible()) then return StopTurning() end
    -- Half a turn a second.
    local step = math.pi * (elapsed or 0) * turning.way
    local actor = TurnActor(scene)
    if actor then
        local yaw = Look.Number(actor:GetYaw())
        if yaw then actor:SetYaw(yaw + step) end
        return
    end
    local asked, camera = Look.Ask(scene, "GetActiveCamera")
    if asked and type(camera) == "table" and type(camera.GetYaw) == "function" then
        local yaw = Look.Number(camera:GetYaw())
        if yaw then camera:SetYaw(yaw - step) end
        if type(camera.SnapToTargetInterpolationYaw) == "function" then camera:SnapToTargetInterpolationYaw() end
        return
    end
    StopTurning()
end)

local function RotateButton(paper, scene, side, way)
    local button = Look.Build("Button", paper, nil, { size = { 35, 35 } })
    for state, look in pairs({ Normal = "Up", Pushed = "Down" }) do
        button["Set" .. state .. "Texture"](button, C.BUTTONS .. "UI-Rotation" .. side .. "-Button-" .. look)
        Look.StateArt(button, state, "rotate" .. side .. look)
    end
    Look.StateArt(button, "Highlight", "roundHighlight")
    local glow = button:GetHighlightTexture()
    if glow then glow:SetBlendMode("ADD") end
    button:SetFrameLevel((Look.Number(scene:GetFrameLevel()) or 1) + 10)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetScript("OnMouseDown", function()
        turning.way = way
        turner:Show()
        if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_INVENTORY_ROTATE_CHARACTER) end
    end)
    button:SetScript("OnMouseUp", StopTurning)
    button:SetScript("OnHide", StopTurning)
    return button
end

function C.MakeRotate(paper)
    local scene = C.Model()
    if C.rotate or scene == nil then return end
    local first = RotateButton(paper, scene, "Left", -1)
    Look.Pin(first, "TOPLEFT", scene, "TOPLEFT", 0, 0)
    local second = RotateButton(paper, scene, "Right", 1)
    Look.Pin(second, "TOPLEFT", first, "TOPRIGHT", 0, 0)
    C.rotate = { first, second }
end
