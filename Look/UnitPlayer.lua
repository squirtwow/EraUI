-- The player frame in its 1.x dress (Classic look, "unitFrames" with
-- unitFramePlayer): the target frame's stone and gold art mirrored, the round
-- portrait on the left with the level badge under it, EraUI's green and power
-- bars over the game's faded ones, rest "Zzz" and crossed swords in the
-- level's place, the old glows and the 1.x PvP banner. Dressing waits for the
-- end of a fight; the keepers below run in fights too and only touch art,
-- text and anchors of the frame's pieces.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local UF = Look.UF

local FULL = UF.FULL
local ART_CROP = { 1, 0.09375, 0, 0.78125 }        -- the target frame's art, mirrored
local FLASH_CROP = { 0.9453125, 0, 0, 0.181640625 } -- its red glow, mirrored
local STATUS_CROP = { 0, 0.74609375, 0, 0.53125 }
local REST_CROP, FIGHT_CROP = { 0, 0.5, 0, 0.421875 }, { 0.5, 1, 0, 0.484375 }
local NAME_X, NAME_Y, LEVEL_X, LEVEL_Y = 97, -30, 36, -71

-- The player frame and its three parts (container, main, contextual), or nil.
local function Parts()
    local frame = PlayerFrame
    local container = Look.Path(frame, "PlayerFrameContainer")
    local main = Look.Path(frame, "PlayerFrameContent", "PlayerFrameContentMain")
    local contextual = Look.Path(frame, "PlayerFrameContent", "PlayerFrameContentContextual")
    if not (container and main and contextual) then return nil end
    return frame, container, main, contextual
end

-- Only while the player wears the look.
local function Dressed()
    local frame, container, main, contextual = Parts()
    if not frame or UF.dressed[frame] ~= "player" then return nil end
    return frame, container, main, contextual
end

---------------------------------------------------------------------------
-- Art
---------------------------------------------------------------------------

local function Art(frame, container, main, contextual)
    UF.Dress(container.FrameTexture, "targetingFrame", ART_CROP, 232, 100, "TOPLEFT", frame, "TOPLEFT", -19, -4, "BORDER")
    UF.Dress(container.AlternatePowerFrameTexture, "targetingFrame", ART_CROP, 232, 100, "TOPLEFT", frame, "TOPLEFT", -19, -4)
    local flash = container.FrameFlash
    UF.Dress(flash, "targetingFlash", FLASH_CROP, 242, 93, "TOPLEFT", frame, "TOPLEFT", -6, -4, "BACKGROUND")
    UF.HoldGlow(flash)
    UF.GlowAlpha(flash)
    local glow = main.StatusTexture
    if glow then
        glow:SetParent(contextual)
        UF.Dress(glow, "playerStatus", STATUS_CROP, 190, 66, "TOPLEFT", frame, "TOPLEFT", 16, -12)
        glow:SetBlendMode("ADD")
        UF.HoldGlow(glow)
    end
    Look.Fade(contextual.PrestigePortrait)
    Look.Fade(contextual.PrestigeBadge)
    Look.FadeCircles(contextual)
    Look.FadeCircles(main)
    UF.FadePvpBackground(frame)
    Look.Fade(main.LevelBackgroundCircle)
    for _, key in ipairs(Look.Words("PlayerRestLoop AttackIcon PlayerPortraitCornerIcon")) do Look.Fade(contextual[key]) end
end

---------------------------------------------------------------------------
-- Dressing
---------------------------------------------------------------------------

local function Bars(frame, main, record, host, holder)
    UF.Backing(record, host, 119, 41, host, 87, -26)
    local health = UF.OwnBar(record, "health", host, 119, 12, 87, -45)
    local power = UF.OwnBar(record, "power", host, 119, 12, 87, -56)
    local box = main.HealthBarsContainer
    Look.Fade(box)
    local gameHealth = box and box.HealthBar
    if gameHealth then
        UF.Pin(gameHealth, health)
        UF.MoveText(gameHealth.TextString, holder, health, "CENTER", 0, 0)
        UF.MoveText(gameHealth.LeftText, holder, health, "LEFT", 6, 0)
        UF.MoveText(gameHealth.RightText, holder, health, "RIGHT", -4, 0)
        UF.TakeOverlays(gameHealth, health, box.HealthBarMask)
    end
    -- The red bar that shows health just lost.
    local loss = box and box.PlayerFrameHealthBarAnimatedLoss
    if loss then
        loss:SetParent(health)
        Look.Fill(loss, health)
        Look.Refill(loss, UF.PaintFill)
        UF.lossBars[loss] = true
        UF.Unmask(loss:GetStatusBarTexture(), box.HealthBarMask)
    end
    local area = main.ManaBarArea
    Look.Fade(area)
    local gameMana = area and area.ManaBar
    if gameMana then
        UF.Pin(gameMana, power)
        UF.MoveText(gameMana.TextString, holder, power, "CENTER", 0, 0)
        UF.MoveText(gameMana.LeftText, holder, power, "LEFT", 6, 0)
        UF.MoveText(gameMana.RightText, holder, power, "RIGHT", -4, 0)
    end
    return health, power
end

local function Labels(frame, contextual, host)
    local name = PlayerName
    if name then
        name:SetParent(contextual)
        name:SetWidth(100)
        name:SetJustifyH("CENTER")
        Look.Pin(name, "TOPLEFT", host, "TOPLEFT", NAME_X, NAME_Y)
    end
    local level = PlayerLevelText
    if level then
        level:SetParent(contextual)
        level:SetDrawLayer("OVERLAY")
        if GameFontNormalSmall then level:SetFontObject(GameFontNormalSmall) end
        level:SetJustifyH("CENTER")
        Look.Pin(level, "CENTER", host, "TOPLEFT", LEVEL_X, LEVEL_Y)
        level:SetTextColor(1, 0.82, 0)
    end
    UF.Dress(contextual.LeaderIcon, "leaderIcon", FULL, 16, 16, "TOPLEFT", frame, "TOPLEFT", 21, -16)
    local group = contextual.GroupIndicator
    if group then Look.Pin(group, "BOTTOMLEFT", frame, "TOPLEFT", 97, -20) end
end

-- The rest and fight icons, made once on the game's contextual frame and
-- kept in its record.
local function StateIcons(frame, contextual)
    local record = UF.Note(contextual)
    local rest = UF.OwnTexture(record, "rest", contextual, "OVERLAY")
    UF.Dress(rest, "stateIcon", REST_CROP, 31, 31, "TOPLEFT", frame, "TOPLEFT", 20, -54)
    local fight = UF.OwnTexture(record, "fight", contextual, "OVERLAY")
    UF.Dress(fight, "stateIcon", FIGHT_CROP, 32, 31, "TOPLEFT", frame, "TOPLEFT", 21, -53)
    return rest, fight
end

function UF.DressPlayer()
    if Look.InFight() then
        UF.waiting = true
        return
    end
    local frame, container, main, contextual = Parts()
    if not frame then
        Look.MissingPiece("PlayerFrame layout")
        return
    end
    local record = UF.Note(frame)
    UF.dressed[frame] = "player"
    local base = UF.Level(frame)
    local host = UF.Host(frame, record)
    UF.SetLevel(host, base + 1)
    UF.SetLevel(container, base + 3)
    UF.SetLevel(contextual, base + 4)
    local holder = UF.Holder(frame, record, UF.Level(contextual) + 3)
    Art(frame, container, main, contextual)
    local portrait = container.PlayerPortrait
    if portrait then
        portrait:SetSize(64, 64)
        Look.Pin(portrait, "TOPLEFT", frame, "TOPLEFT", 23, -16)
    end
    UF.Dress(container.PlayerPortraitMask, "portraitMask", nil, 64, 64, "TOPLEFT", frame, "TOPLEFT", 23, -16)
    local health, power = Bars(frame, main, record, host, holder)
    Labels(frame, contextual, host)
    local rest, fight = StateIcons(frame, contextual)
    local banner = UF.Banner(record, holder)
    Look.Pin(banner, "TOPLEFT", frame, "TOPLEFT", -1, -22)
    if UF.ThickWant("player") then
        UF.ThickCall("Player", frame, host, health, power, record.backing, rest, fight)
    else
        UF.ThickCall("Off", frame)
    end
end

---------------------------------------------------------------------------
-- Keepers (every keeper pass, fights included)
---------------------------------------------------------------------------

-- The game puts its modern art back for forms and vehicles.
function UF.KeepPlayerArt()
    local frame, container, main, contextual = Dressed()
    if not frame then return end
    for _, piece in ipairs({ container.FrameTexture or false, container.AlternatePowerFrameTexture or false,
        container.FrameFlash or false, main.StatusTexture or false }) do
        if piece and UF.HasAtlas(piece) then
            Art(frame, container, main, contextual)
            return
        end
    end
end

-- Which of rest, fight or the level shows; nil while the game keeps it secret.
local function StateNow(frame)
    local resting, busy = IsResting(), UnitAffectingCombat("player")
    local flagged, hated = frame.inCombat, frame.onHateList
    if Look.Secret(resting) or Look.Secret(busy) or Look.Secret(flagged) or Look.Secret(hated) then return nil end
    local fighting = (flagged and true) or (busy and true) or false
    local rest = resting and not fighting and true or false
    local fight = not resting and (fighting or (hated and true) or false) or false
    return rest, fight
end

function UF.KeepPlayerState()
    local frame, _, _, contextual = Dressed()
    if not frame then return end
    local rest, fight = StateNow(frame)
    if rest == nil then return end
    local icons = UF.Peek(contextual)
    if icons then
        Look.Shown(icons.rest, rest)
        Look.Shown(icons.fight, fight)
    end
    Look.Shown(PlayerLevelText, not rest and not fight)
end

-- 1.x had no role icon there: the level shows in its place.
function UF.KeepPlayerRole()
    local frame, _, _, contextual = Dressed()
    if not frame then return end
    local role = contextual.RoleIcon
    if role and role:IsShown() then role:Hide() end
    local rest, fight = StateNow(frame)
    if rest ~= nil then Look.Shown(PlayerLevelText, not rest and not fight) end
end

function UF.KeepPlayerPvp()
    local frame, _, main, contextual = Dressed()
    if not frame then return end
    Look.Fade(contextual.PrestigePortrait)
    Look.Fade(contextual.PrestigeBadge)
    UF.FadePvpBackground(frame)
    Look.FadeCircles(main)
    local record = UF.Peek(frame)
    local banner = record and record.banner
    if UF.ShowBanner(banner, contextual.PVPIcon, "player") then
        local timer = PlayerPVPTimerText
        if timer then
            if timer:GetParent() ~= record.holder then timer:SetParent(record.holder) end
            UF.KeepAt(timer, "CENTER", banner, "TOPLEFT", 21, 2)
        end
    end
end

-- The level in the old gold, whatever the game's level update set.
function UF.KeepLevelGold()
    local level = PlayerLevelText
    if not level or not UF.active or not UF.FrameOn("unitFramePlayer") then return end
    local r, g, b = level:GetTextColor()
    r, g, b = Look.Number(r), Look.Number(g), Look.Number(b)
    if r and g and b and math.abs(r - 1) < 0.005 and math.abs(g - 0.82) < 0.005 and math.abs(b) < 0.005 then return end
    level:SetTextColor(1, 0.82, 0)
end

function UF.WatchLevel()
    if type(PlayerFrame_UpdateLevel) == "function" then Look.HookGlobal("PlayerFrame_UpdateLevel", UF.KeepLevelGold) end
end

-- The client can blank your own name or show "Unknown"; with surnames hidden
-- the label is your first name only.
local function RepairName()
    local label = PlayerName
    if not label then return end
    local name, text = UnitName("player"), label:GetText()
    if Look.Secret(name) or Look.Secret(text) or type(name) ~= "string" or name == "" then return end
    if UF.Setting("hideSecondaryNames") then
        if text ~= name then label:SetText(name) end
    elseif text == nil or text == "" or text == "Unknown" or text == UNKNOWNOBJECT then
        label:SetText(name)
    end
end

function UF.KeepPlayerSpots()
    local frame, _, main = Dressed()
    if not frame then return end
    local record = UF.Peek(frame)
    if UF.ThickWorn(frame) then
        UF.ThickCall("KeepPlayer", frame)
    elseif record and record.host then
        UF.KeepAt(PlayerName, "TOPLEFT", record.host, "TOPLEFT", NAME_X, NAME_Y)
        UF.KeepAt(PlayerLevelText, "CENTER", record.host, "TOPLEFT", LEVEL_X, LEVEL_Y)
    end
    UF.KeepPin(Look.Path(main, "HealthBarsContainer", "HealthBar"), record and record.health)
    UF.KeepLevelGold()
    RepairName()
end

---------------------------------------------------------------------------
-- Turning it off
---------------------------------------------------------------------------

-- Cheap and safe to repeat. EraUI's own pieces go; the game's art stays until
-- the reload (unitFrames is a reload setting).
function UF.RestorePlayer()
    local frame = PlayerFrame
    if not frame then return end
    local was = UF.dressed[frame] ~= nil
    UF.dressed[frame] = nil
    local main = Look.Path(frame, "PlayerFrameContent", "PlayerFrameContentMain")
    local contextual = Look.Path(frame, "PlayerFrameContent", "PlayerFrameContentContextual")
    local record = UF.Peek(frame)
    if record then
        Look.Shown(record.banner, false)
        if record.host then record.host:Hide() end
    end
    Look.Alpha(contextual and contextual.PVPIcon, 1)
    UF.ThickCall("Off", frame)
    Look.Alpha(main and main.HealthBarsContainer, 1)
    Look.Alpha(main and main.ManaBarArea, 1)
    local icons = UF.Peek(contextual)
    if was and icons then
        Look.Shown(icons.rest, false)
        Look.Shown(icons.fight, false)
        Look.Shown(PlayerLevelText, true)
    end
    ns.needsReload = true
end
