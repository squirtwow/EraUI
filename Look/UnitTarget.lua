-- The target and focus frames in their 1.x dress (Classic look,
-- "unitFrames" with unitFrameTarget / unitFrameFocus): the old targeting
-- frame art with the portrait on the right, EraUI's bars on the left, the
-- name on the reaction-coloured plate, the level badge or a skull, the
-- dragons for elites, rares and world bosses, the small art for minor mobs.
-- The keeper runs on every keeper pass (fights too) and follows the game's
-- changes of target and classification.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local UF = Look.UF

local FULL = UF.FULL
local ART_CROP = { 0.09375, 1, 0, 0.78125 }
local SMALL_FLASH = { 0, 0.9453125, 0, 0.181640625 }
local TALL_FLASH = { 0, 0.9453125, 0.181640625, 0.400390625 }

-- Frame art, flash art, flash crop, flash size and spot for each kind.
local DRAGON = { "targetingElite", "targetingFlash", TALL_FLASH, 242, 112, -2, 5 }
local KINDS = {
    rareelite = { "targetingRareElite", "targetingFlash", TALL_FLASH, 242, 112, -2, 5 },
    elite = DRAGON,
    worldboss = DRAGON,
    rare = { "targetingRare", "targetingFlash", SMALL_FLASH, 242, 93, -4, -4 },
    minus = { "targetingMinus", "targetingMinusFlash", FULL, 256, 128, -4, -4 },
}
local PLAIN = { "targetingFrame", "targetingFlash", SMALL_FLASH, 242, 93, -4, -4 }
local MARKED = { elite = true, worldboss = true, rare = true, rareelite = true } -- the cast bars sit lower under these
local LEVEL_X, LEVEL_Y, AURA_X, AURA_Y = 198, -71, 5, 32

local function Parts(frame)
    local container = Look.Path(frame, "TargetFrameContainer")
    local main = Look.Path(frame, "TargetFrameContent", "TargetFrameContentMain")
    local contextual = Look.Path(frame, "TargetFrameContent", "TargetFrameContentContextual")
    if not (container and main and contextual) then return nil end
    return container, main, contextual
end

---------------------------------------------------------------------------
-- Dressing
---------------------------------------------------------------------------

local function Bars(main, record, host, holder)
    UF.Backing(record, host, 119, 25, host, 27, -45)
    local health = UF.OwnBar(record, "health", host, 119, 12, 27, -45)
    local power = UF.OwnBar(record, "power", host, 119, 12, 27, -56)
    local box = main.HealthBarsContainer
    local gameHealth = box and box.HealthBar
    if gameHealth then
        Look.Fade(gameHealth)
        UF.Pin(gameHealth, health)
        UF.MoveText(gameHealth.TextString, holder, health, "CENTER", 0, 0)
        UF.TakeOverlays(gameHealth, health, box.HealthBarMask)
    end
    if box then
        UF.MoveText(box.LeftText, holder, health, "LEFT", 5, 0)
        UF.MoveText(box.RightText, holder, health, "RIGHT", -7, 0)
        UF.MoveText(box.DeadText, holder, health, "CENTER", 0, 0)
        UF.MoveText(box.UnconsciousText, holder, health, "CENTER", 0, 0)
    end
    local gameMana = main.ManaBar
    if gameMana then
        Look.Fade(gameMana)
        UF.Pin(gameMana, power)
        UF.MoveText(gameMana.TextString, holder, power, "CENTER", 0, 0)
        UF.MoveText(gameMana.LeftText, holder, power, "LEFT", 5, 0)
        UF.MoveText(gameMana.RightText, holder, power, "RIGHT", -7, 0)
    end
    return health, power
end

local function Labels(frame, kind, container, main, contextual, host)
    local name = main.Name
    if name then
        name:SetParent(contextual)
        name:SetWidth(100)
        name:SetJustifyH("CENTER")
        Look.Pin(name, "TOPLEFT", host, "TOPLEFT", 36, -30)
    end
    -- The reaction plate. Thick Frames turns it into an underline of the
    -- game's colour, so the Classic art (which Dark Mode greys) isn't put on then.
    if not UF.ThickWant(kind) then
        UF.Dress(main.ReputationColor, "levelBackground", FULL, 119, 19, "TOPRIGHT", frame, "TOPRIGHT", -86, -26)
    end
    local level = main.LevelText
    if level then
        level:SetParent(contextual)
        if GameFontNormalSmall then level:SetFontObject(GameFontNormalSmall) end
        level:SetJustifyH("CENTER")
        Look.Pin(level, "CENTER", host, "TOPLEFT", LEVEL_X, LEVEL_Y)
    end
    Look.Fade(main.LevelBackgroundCircle)
    Look.FadeCircles(main)
    Look.FadeCircles(contextual)
    UF.Dress(contextual.HighLevelTexture, "skull", FULL, 16, 16, "CENTER", host, "TOPLEFT", 197, -71)
    UF.Dress(contextual.LeaderIcon, "leaderIcon", FULL, 16, 16, "TOPRIGHT", frame, "TOPRIGHT", -24, -14)
    local marker = contextual.RaidTargetIcon
    if marker then Look.Pin(marker, "CENTER", container.Portrait or frame, "TOP", 2, -2) end
    UF.Dress(contextual.QuestIcon, "questBadge", FULL, 32, 32, "TOP", frame, "TOP", 32, -16)
    local threat = contextual.NumericalThreat
    if threat then Look.Pin(threat, "BOTTOM", frame, "TOP", -30, -26) end
end

-- kind: "target" or "focus" (the frame's own unit field wins when set).
function UF.DressTarget(frame, kind)
    if not frame then return end
    if Look.InFight() then
        UF.waiting = true
        return
    end
    local container, main, contextual = Parts(frame)
    if not container then
        Look.MissingPiece((frame:GetName() or kind) .. " layout")
        return
    end
    local unit = UF.UnitOf(frame, kind)
    local record = UF.Note(frame)
    UF.dressed[frame] = kind
    local base = UF.Level(frame)
    local host = UF.Host(frame, record)
    UF.SetLevel(host, base + 1)
    UF.SetLevel(container, base + 3)
    UF.SetLevel(contextual, base + 4)
    local holder = UF.Holder(frame, record, UF.Level(contextual) + 3)
    local portrait = container.Portrait
    if portrait then
        portrait:SetSize(64, 64)
        Look.Pin(portrait, "TOPRIGHT", frame, "TOPRIGHT", -22, -16)
    end
    UF.Dress(container.PortraitMask, "portraitMask", nil, 64, 64, "TOPRIGHT", frame, "TOPRIGHT", -22, -16)
    local health, power = Bars(main, record, host, holder)
    Labels(frame, kind, container, main, contextual, host)
    local banner = UF.Banner(record, holder)
    Look.Pin(banner, "TOPRIGHT", frame, "TOPRIGHT", 25, -22)
    if UF.ThickWant(kind) then
        UF.ThickCall("Target", frame, kind, host, health, power, record.backing)
    else
        UF.ThickCall("Off", frame)
    end
    UF.DressToT(frame, kind, unit)
end

---------------------------------------------------------------------------
-- The keeper's steps
---------------------------------------------------------------------------

-- The unit's classification; a hidden one (a fight can hide it) keeps the
-- last seen, so an elite never drops to normal mid-fight.
local function Classification(unit, record)
    local kind = UnitClassification(unit)
    if Look.Secret(kind) then
        kind = record.kind
    elseif kind == nil then
        kind = UF.Exists(unit) and record.kind or nil
    end
    kind = kind or "normal"
    record.kind = kind
    return kind
end

local function KindArt(frame, container, main, contextual, record, kind)
    local art = KINDS[kind] or PLAIN
    UF.Dress(container.FrameTexture, art[1], ART_CROP, 232, 100, "TOPLEFT", frame, "TOPLEFT", 20, -4)
    local flash = container.Flash
    if flash then
        UF.Dress(flash, art[2], art[3], art[4], art[5], "TOPLEFT", frame, "TOPLEFT", art[6], art[7])
        UF.HoldGlow(flash)
        UF.GlowAlpha(flash)
    end
    Look.Fade(container.BossPortraitFrameTexture)
    Look.Fade(contextual.BossIcon)
    local minor = kind == "minus"
    Look.Alpha(record.power, minor and 0 or 1)
    if record.backing then record.backing:SetHeight(minor and 12 or 25) end
    Look.Shown(main.ReputationColor, not minor)
    record.elite = MARKED[kind] or nil
end

-- The target re-coloured on targeting yourself kept the previous name: put
-- the right one back, leaving a label that already fits (a name with its
-- surname) or, with surnames hidden, anything but the name itself.
local function RepairName(label, unit)
    if not label or not UF.Exists(unit) then return end
    local name, text = UnitName(unit), label:GetText()
    if Look.Secret(name) or Look.Secret(text) or type(name) ~= "string" or name == "" then return end
    if UF.Setting("hideSecondaryNames") then
        if text ~= name then label:SetText(name) end
        return
    end
    if type(text) ~= "string" or text == "" or (text ~= name and text:sub(1, #name + 1) ~= name .. " ") then
        label:SetText(name)
    end
end

local function LevelOrSkull(main, contextual, record, unit, thick)
    local skull = Look.SkullLevel(UnitLevel(unit), unit)
    Look.Shown(main.LevelText, not skull)
    Look.Shown(contextual.HighLevelTexture, skull)
    if not thick and main.LevelText and record.host then
        UF.KeepAt(main.LevelText, "CENTER", record.host, "TOPLEFT", LEVEL_X, LEVEL_Y)
    end
end

-- The aura row starts under the frame art (or Thick Frames' plate).
function UF.KeepAuras(frame)
    local container = Look.Path(frame, "TargetFrameContainer")
    local art = container and container.FrameTexture
    local fine, row = Look.Ask(frame, "GetAuraContainer")
    if not art or not fine or not row then return end
    local y = UF.ThickWorn(frame) and UF.ThickNumber("AURA_Y", 20) or AURA_Y
    if UF.FirstPointIs(row, "TOPLEFT", art, "BOTTOMLEFT", AURA_X, y) then return end
    if Look.HeldInFight(row) then
        UF.waiting = true
        return
    end
    Look.Pin(row, "TOPLEFT", art, "BOTTOMLEFT", AURA_X, y)
end

function UF.KeepTarget(frame)
    local kind = frame and UF.dressed[frame]
    if kind ~= "target" and kind ~= "focus" then return end
    local container, main, contextual = Parts(frame)
    local record = UF.Peek(frame)
    if not container or not record then return end
    local unit = UF.UnitOf(frame, kind)
    -- PvP: the banner, the modern pieces faded again.
    Look.Fade(contextual.PrestigePortrait)
    Look.Fade(contextual.PrestigeBadge)
    UF.FadePvpBackground(frame)
    Look.FadeCircles(main)
    Look.FadeCircles(contextual)
    UF.ShowBanner(record.banner, contextual.PvpIcon, unit)
    -- The art follows every new target (and a class-coloured border with it).
    local classification = Classification(unit, record)
    KindArt(frame, container, main, contextual, record, classification)
    UF.KeepPin(Look.Path(main, "HealthBarsContainer", "HealthBar"), record.health)
    RepairName(main.Name, unit)
    local thick = UF.ThickWorn(frame)
    if thick then UF.ThickCall("KeepTarget", frame, unit, classification) end
    LevelOrSkull(main, contextual, record, unit, thick)
    UF.KeepAuras(frame)
    UF.KeepToT(frame)
end

---------------------------------------------------------------------------
-- Turning it off
---------------------------------------------------------------------------

function UF.RestoreTarget(frame)
    if not frame then return end
    UF.dressed[frame] = nil
    local record = UF.Peek(frame)
    if record then
        Look.Shown(record.banner, false)
        if record.host then record.host:Hide() end
    end
    Look.Alpha(Look.Path(frame, "TargetFrameContent", "TargetFrameContentContextual", "PvpIcon"), 1)
    UF.ThickCall("Off", frame)
    local main = Look.Path(frame, "TargetFrameContent", "TargetFrameContentMain")
    Look.Alpha(Look.Path(main, "HealthBarsContainer", "HealthBar"), 1)
    Look.Alpha(main and main.ManaBar, 1)
    UF.RestoreToT(frame)
    ns.needsReload = true
end
