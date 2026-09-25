-- EraUI unit frames.
-- The 1.x unit frames on Blizzard's 12.x frames. Blizzard's health and power
-- bars are faded out and our own bars, fed by unit events, are drawn in the
-- old spots; Blizzard's text, prediction and absorb regions are moved onto
-- ours so nothing is lost. Everything secure (clicks, menus, auras) is
-- untouched.
local _, EraUI = ...
local ns = EraUI.Classic

local UI_STATUSBAR = "statusBar"
local FRAME_W, FRAME_H = 232, 100
local BAR_W, BAR_H = 119, 12
local PLAYER_BAR_X, TARGET_BAR_X = 87, 27
local HEALTH_Y, POWER_Y = -45, -56
local PLAYER_NAME_Y = -26
local PORTRAIT = 64

local active = false
local KEYS = { player = "unitFramePlayer", target = "unitFrameTarget", focus = "unitFrameFocus", pet = "unitFramePet", party = "unitFrameParty" }
local function On(kind) return ns.db == nil or ns.db[KEYS[kind]] ~= false end

local combatPending = false
local function Busy()
    if not InCombatLockdown() then return false end
    combatPending = true
    return true
end
local RestorePlayer, RestoreTargetLike, RestoreParty
local driver

local frames = {}
local SkinParty, SkinPartySoon

local keepers = {}
local KeepAuraRow
local KeepPlayerAnchors, PlayerArt
local function Keeper(key, fn)
    keepers[key] = fn
    fn()
end

local function KeepFrames()
    if not active then return end
    for _, fn in pairs(keepers) do ns.SafeCall(fn) end
end

local keptBars = setmetatable({}, { __mode = "k" })

local function RecolorKept(bar)
    local kind = keptBars[bar]
    if not kind or not active then return end
    bar:SetStatusBarTexture((ns.TexPath(UI_STATUSBAR)))
    if kind == "health" then
        bar:SetStatusBarColor(0, 1, 0)
    else
        local unit = bar.unit or (bar:GetParent() and bar:GetParent().unit)
        if unit then bar:SetStatusBarColor(ns.PowerColor(unit)) end
    end
end

local function KeepBar(bar, kind)
    if not bar then return end
    keptBars[bar] = kind
    RecolorKept(bar)
end

local function TextHolder(frame, above)
    frame.fcui = frame.fcui or {}
    local holder = frame.fcui.texts
    if not holder then
        holder = CreateFrame("Frame", nil, frame)
        holder:SetAllPoints(frame)
        holder:EnableMouse(false)
        frame.fcui.texts = holder
    end
    local level = (above or frame):GetFrameLevel() + 3
    if holder:GetFrameLevel() ~= level then holder:SetFrameLevel(level) end
    holder:Show()
    return holder
end

local function AttachTexts(bar, texts, offsets, textParent)
    for i, fs in ipairs(texts) do
        if fs then
            fs:SetParent(textParent or bar)
            fs:SetDrawLayer("OVERLAY")
            fs:ClearAllPoints()
            local o = offsets[i]
            fs:SetPoint(o[1], bar, o[1], o[2], o[3])
        end
    end
end

local function AttachOverlays(source, bar, mask)
    for _, key in ipairs({ "MyHealPredictionBar", "OtherHealPredictionBar", "HealAbsorbBar", "TotalAbsorbBar" }) do
        local piece = source[key]
        if piece then
            piece:SetParent(bar)
            piece:ClearAllPoints()
            piece:SetAllPoints(bar)
            if mask and piece.Fill and piece.Fill.RemoveMaskTexture then pcall(piece.Fill.RemoveMaskTexture, piece.Fill, mask) end
            if piece.Fill then piece.Fill:SetTexture((ns.TexPath(UI_STATUSBAR))) end
        end
    end
    for _, key in ipairs({ "OverAbsorbGlow", "OverHealAbsorbGlow" }) do
        local glow = source[key]
        if glow then
            glow:SetParent(bar)
            if mask and glow.RemoveMaskTexture then pcall(glow.RemoveMaskTexture, glow, mask) end
            glow:ClearAllPoints()
            if key == "OverAbsorbGlow" then
                glow:SetPoint("TOPLEFT", bar, "TOPRIGHT", -7, 0)
                glow:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", -7, 0)
            else
                glow:SetPoint("TOPRIGHT", bar, "TOPLEFT", 7, 0)
                glow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", 7, 0)
            end
        end
    end
end

local function FadePvpCircle(frame)
    for _, key in ipairs({ "PlayerFrameContentMain", "PlayerFrameContentContextual", "TargetFrameContentMain", "TargetFrameContentContextual" }) do
        local content = frame.PlayerFrameContent or frame.TargetFrameContent
        local part = content and content[key]
        if part then
            ns.Fade(part.PvpBackgroundCircle)
            ns.Fade(part.PvpBackgroundIcon)
        end
    end
end

local function Update(entry, what)
    if not entry or not UnitExists(entry.unit) then return end
    if entry.frame and what == nil then FadePvpCircle(entry.frame) end
    if what ~= "power" and entry.health then ns.SetHealth(entry.health, entry.unit) end
    if what ~= "health" and entry.power then ns.SetPower(entry.power, entry.unit) end
end

local function UpdateAll()
    for _, entry in pairs(frames) do Update(entry) end
end

local function RepaintKept(unit)
    if unit ~= "pet" then return end
    RecolorKept(PetFrameHealthBar)
    RecolorKept(PetFrameManaBar)
end

local function OnEvent(_, event, unit)
    if not active then return end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        RepaintKept(unit)
        for _, entry in pairs(frames) do
            if entry.unit == unit then Update(entry, "health") end
        end
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" or event == "UNIT_POWER_FREQUENT" then
        RepaintKept(unit)
        for _, entry in pairs(frames) do
            if entry.unit == unit then Update(entry, "power") end
        end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PARTY_MEMBER_ENABLE" or event == "PARTY_MEMBER_DISABLE"
        or event == "PLAYER_LEVEL_UP" or event == "PLAYER_LEVEL_CHANGED" then
        SkinPartySoon()
        C_Timer.After(1, SkinParty)
        KeepFrames()
        UpdateAll()
    elseif event == "PLAYER_ENTERING_WORLD" then
        SkinPartySoon()
        UpdateAll()
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED"
        or event == "PLAYER_UPDATE_RESTING" or event == "PLAYER_REGEN_DISABLED"
        or event == "PLAYER_FLAGS_CHANGED" or event == "UNIT_CLASSIFICATION_CHANGED"
        or event == "UNIT_FACTION" or event == "UNIT_LEVEL" then
        KeepFrames()
        UpdateAll()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if combatPending then
            combatPending = false
            if ns.QueueApply then ns.QueueApply() end
        end
        KeepFrames()
        UpdateAll()
    else
        KeepFrames()
        UpdateAll()
    end
end

local AURA_X, AURA_Y = 5, 32
KeepAuraRow = function(frame)
    local auras = frame.GetAuraContainer and frame:GetAuraContainer()
    local art = frame.TargetFrameContainer and frame.TargetFrameContainer.FrameTexture
    if not auras or not art then return end
    local point, relativeTo, relativePoint, x, y = auras:GetPoint(1)
    local hidden = issecretvalue and (issecretvalue(point) or issecretvalue(x) or issecretvalue(y) or issecretvalue(relativePoint))
    if not hidden and point == "TOPLEFT" and relativeTo == art and relativePoint == "BOTTOMLEFT"
        and math.abs((x or 0) - AURA_X) < 0.5 and math.abs((y or 0) - AURA_Y) < 0.5 then
        return
    end
    ns.SetPointOnce(auras, "TOPLEFT", art, "BOTTOMLEFT", AURA_X, AURA_Y)
end

PlayerArt = function()
    local frame = PlayerFrame
    local container = frame and frame.PlayerFrameContainer
    if not container then return end
    local art = container.FrameTexture
    if art then
        ns.SetTex(art, "targetingFrame")
        art:SetTexCoord(1, 0.09375, 0, 0.78125)
        art:SetSize(FRAME_W, FRAME_H)
        ns.SetPointOnce(art, "TOPLEFT", frame, "TOPLEFT", -19, -4)
        art:SetDrawLayer("BORDER")
    end
    if container.AlternatePowerFrameTexture then
        local alt = container.AlternatePowerFrameTexture
        ns.SetTex(alt, "targetingFrame")
        alt:SetTexCoord(1, 0.09375, 0, 0.78125)
        alt:SetSize(FRAME_W, FRAME_H)
        ns.SetPointOnce(alt, "TOPLEFT", frame, "TOPLEFT", -19, -4)
    end
    if container.FrameFlash then
        local flash = container.FrameFlash
        ns.SetTex(flash, "targetingFlash")
        flash:SetAlpha(EraUI:GetSetting("disableAggroHighlight") and 0 or 1)
        flash:SetTexCoord(0.9453125, 0, 0, 0.181640625)
        flash:SetSize(242, 93)
        ns.SetPointOnce(flash, "TOPLEFT", frame, "TOPLEFT", -6, -4)
        flash:SetDrawLayer("BACKGROUND")
    end
    local main = ns.Path(frame, "PlayerFrameContent", "PlayerFrameContentMain")
    local status = main and main.StatusTexture
    if status then
        ns.SetTex(status, "playerStatus")
        status:SetTexCoord(0, 0.74609375, 0, 0.53125)
        status:SetSize(190, 66)
        ns.SetPointOnce(status, "TOPLEFT", frame, "TOPLEFT", 16, -12)
        status:SetBlendMode("ADD")
    end
    local contextual = ns.Path(frame, "PlayerFrameContent", "PlayerFrameContentContextual")
    if contextual then
        ns.Fade(contextual.PrestigePortrait)
        ns.Fade(contextual.PrestigeBadge)
        ns.FadeCircles(contextual)
    end
    if main then ns.FadeCircles(main) end
    FadePvpCircle(frame)
end

local function PlayerArtTaken()
    local container = PlayerFrame and PlayerFrame.PlayerFrameContainer
    if not container then return false end
    for _, key in ipairs({ "FrameTexture", "AlternatePowerFrameTexture", "FrameFlash" }) do
        local region = container[key]
        if region and region.GetAtlas and region:GetAtlas() then return true end
    end
    local main = ns.Path(PlayerFrame, "PlayerFrameContent", "PlayerFrameContentMain")
    local status = main and main.StatusTexture
    if status and status.GetAtlas and status:GetAtlas() then return true end
    return false
end

local function KeepPlayerArt()
    if not active or not On("player") then return end
    if PlayerArtTaken() then PlayerArt() end
end

local PVP_ART = {
    Horde = "Interface\\TargetingFrame\\UI-PVP-Horde",
    Alliance = "Interface\\TargetingFrame\\UI-PVP-Alliance",
    FFA = "Interface\\TargetingFrame\\UI-PVP-FFA",
}

local function PvpArt(unit)
    local ok, art = pcall(function()
        if UnitIsPVPFreeForAll and UnitIsPVPFreeForAll(unit) then return PVP_ART.FFA end
        if UnitIsPVP(unit) then return PVP_ART[UnitFactionGroup(unit) or ""] end
        return nil
    end)
    if not ok then return false end
    return art
end

local function OwnPvpIcon(frame, holder, unit, clientIcon, point, x, y)
    if not holder then return nil end
    local icon = ns.OwnTexture(holder, "pvpIcon", "OVERLAY")
    local art = PvpArt(unit)
    if art == false then
        icon:Hide()
        ns.Unfade(clientIcon)
        return nil
    end
    ns.Fade(clientIcon)
    if not art then
        icon:Hide()
        return nil
    end
    icon:SetTexture(art)
    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetSize(64, 64)
    ns.SetPointOnce(icon, point, frame, point, x, y)
    icon:Show()
    return icon
end

local function HideOwnPvp(frame)
    local holder = frame and frame.fcui and frame.fcui.texts
    local icon = holder and holder.fcui and holder.fcui.pvpIcon
    if icon then icon:Hide() end
end

local function SkinPlayer()
    if Busy() then return end
    local frame = PlayerFrame
    local container = frame and frame.PlayerFrameContainer
    local main = ns.Path(frame, "PlayerFrameContent", "PlayerFrameContentMain")
    local contextual = ns.Path(frame, "PlayerFrameContent", "PlayerFrameContentContextual")
    if not container or not main or not contextual then ns.MissingPiece("PlayerFrame layout") return end
    local healthContainer, manaArea = main.HealthBarsContainer, main.ManaBarArea
    local blizzHealth = healthContainer and healthContainer.HealthBar
    local blizzMana = manaArea and manaArea.ManaBar

    PlayerArt()
    if container.PlayerPortrait then
        container.PlayerPortrait:SetSize(PORTRAIT, PORTRAIT)
        ns.SetPointOnce(container.PlayerPortrait, "TOPLEFT", frame, "TOPLEFT", 23, -16)
    end
    if container.PlayerPortraitMask then
        container.PlayerPortraitMask:SetSize(PORTRAIT, PORTRAIT)
        ns.SetTex(container.PlayerPortraitMask, "portraitMask")
        ns.SetPointOnce(container.PlayerPortraitMask, "TOPLEFT", frame, "TOPLEFT", 23, -16)
    end

    local host = frame.fcui and frame.fcui.host
    if not host then
        host = CreateFrame("Frame", nil, frame)
        host:EnableMouse(false)
        frame.fcui = frame.fcui or {}
        frame.fcui.host = host
    end
    host:SetAllPoints(frame)
    host:Show()
    local base = frame:GetFrameLevel()
    if host:GetFrameLevel() ~= base + 1 then host:SetFrameLevel(base + 1) end
    if container:GetFrameLevel() ~= base + 3 then container:SetFrameLevel(base + 3) end
    if contextual:GetFrameLevel() ~= base + 4 then contextual:SetFrameLevel(base + 4) end
    local bg = ns.OwnTexture(host, "barBg", "BACKGROUND")
    bg:SetColorTexture(0, 0, 0, 0.5)
    bg:SetSize(BAR_W, 41)
    ns.SetPointOnce(bg, "TOPLEFT", host, "TOPLEFT", PLAYER_BAR_X, PLAYER_NAME_Y)

    local health = ns.CreateBar(host, "health", BAR_W, BAR_H)
    ns.SetPointOnce(health, "TOPLEFT", host, "TOPLEFT", PLAYER_BAR_X, HEALTH_Y)
    health:SetStatusBarColor(ns.HealthColor("player"))
    local power = ns.CreateBar(host, "power", BAR_W, BAR_H)
    ns.SetPointOnce(power, "TOPLEFT", host, "TOPLEFT", PLAYER_BAR_X, POWER_Y)
    if blizzHealth then ns.SetPointOnce(blizzHealth, "TOPLEFT", health, "TOPLEFT", 0, 0); blizzHealth:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0) end
    if blizzMana then ns.SetPointOnce(blizzMana, "TOPLEFT", power, "TOPLEFT", 0, 0); blizzMana:SetPoint("BOTTOMRIGHT", power, "BOTTOMRIGHT", 0, 0) end

    if healthContainer then
        ns.Fade(healthContainer)
        if blizzHealth then
            AttachTexts(health, { blizzHealth.TextString, blizzHealth.LeftText, blizzHealth.RightText },
                { { "CENTER", 0, 0 }, { "LEFT", 6, 0 }, { "RIGHT", -4, 0 } }, TextHolder(frame, contextual))
            AttachOverlays(blizzHealth, health, healthContainer.HealthBarMask)
        end
        local loss = healthContainer.PlayerFrameHealthBarAnimatedLoss
        if loss then
            loss:SetParent(health)
            loss:ClearAllPoints()
            loss:SetAllPoints(health)
            loss:SetStatusBarTexture((ns.TexPath(UI_STATUSBAR)))
            local tex = loss:GetStatusBarTexture()
            if tex and healthContainer.HealthBarMask and tex.RemoveMaskTexture then pcall(tex.RemoveMaskTexture, tex, healthContainer.HealthBarMask) end
        end
    end
    if manaArea then
        ns.Fade(manaArea)
        if blizzMana then
            AttachTexts(power, { blizzMana.TextString, blizzMana.LeftText, blizzMana.RightText },
                { { "CENTER", 0, 0 }, { "LEFT", 6, 0 }, { "RIGHT", -4, 0 } }, TextHolder(frame, contextual))
        end
    end

    if PlayerName then
        PlayerName:SetParent(contextual)
        PlayerName:SetWidth(100)
        PlayerName:SetJustifyH("CENTER")
        ns.SetPointOnce(PlayerName, "TOPLEFT", host, "TOPLEFT", 97, -30)
    end
    if PlayerLevelText then
        PlayerLevelText:SetParent(contextual)
        PlayerLevelText:SetDrawLayer("OVERLAY")
        PlayerLevelText:SetFontObject("GameFontNormalSmall")
        PlayerLevelText:SetJustifyH("CENTER")
        ns.SetPointOnce(PlayerLevelText, "CENTER", host, "TOPLEFT", 36, -71)
        PlayerLevelText:SetTextColor(1, 0.82, 0)
    end
    ns.Fade(main.LevelBackgroundCircle)
    ns.FadeCircles(main)
    ns.FadeCircles(contextual)
    local levelBg = ns.OwnTexture(host, "levelBg", "BORDER")
    ns.SetTex(levelBg, "levelBackground")
    levelBg:SetSize(BAR_W, 19)
    ns.SetPointOnce(levelBg, "TOPLEFT", host, "TOPLEFT", PLAYER_BAR_X, PLAYER_NAME_Y)
    levelBg:SetVertexColor(0, 0, 0)
    levelBg:Hide()

    if main.StatusTexture then
        local status = main.StatusTexture
        status:SetParent(contextual)
        ns.SetTex(status, "playerStatus")
        status:SetTexCoord(0, 0.74609375, 0, 0.53125)
        status:SetSize(190, 66)
        ns.SetPointOnce(status, "TOPLEFT", frame, "TOPLEFT", 16, -12)
        status:SetBlendMode("ADD")
    end
    local rest = ns.OwnTexture(contextual, "rest", "OVERLAY")
    ns.SetTex(rest, "stateIcon")
    rest:SetTexCoord(0, 0.5, 0, 0.421875)
    rest:SetSize(31, 31)
    ns.SetPointOnce(rest, "TOPLEFT", frame, "TOPLEFT", 20, -54)
    local attack = ns.OwnTexture(contextual, "attack", "OVERLAY")
    ns.SetTex(attack, "stateIcon")
    attack:SetTexCoord(0.5, 1, 0, 0.484375)
    attack:SetSize(32, 31)
    ns.SetPointOnce(attack, "TOPLEFT", frame, "TOPLEFT", 21, -53)
    if contextual.PlayerRestLoop then ns.Fade(contextual.PlayerRestLoop) end
    if contextual.AttackIcon then ns.Fade(contextual.AttackIcon) end
    if contextual.PlayerPortraitCornerIcon then ns.Fade(contextual.PlayerPortraitCornerIcon) end
    local function UpdateStatus()
        if not active then return end
        local resting = IsResting()
        local inCombat = frame.inCombat or (UnitAffectingCombat and UnitAffectingCombat("player"))
        local showRest = resting and not inCombat
        local showAttack = (not resting and (inCombat or frame.onHateList)) and true or false
        rest:SetShown(showRest)
        attack:SetShown(showAttack)
        if PlayerLevelText then PlayerLevelText:SetShown(not showRest and not showAttack) end
    end
    Keeper("player.status", UpdateStatus)

    local function LevelNotRole()
        if not active then return end
        if contextual.RoleIcon then contextual.RoleIcon:Hide() end
        if PlayerLevelText then PlayerLevelText:SetShown(not rest:IsShown() and not attack:IsShown()) end
    end
    Keeper("player.role", LevelNotRole)

    if contextual.LeaderIcon then
        ns.SetTex(contextual.LeaderIcon, "leaderIcon")
        contextual.LeaderIcon:SetTexCoord(0, 1, 0, 1)
        contextual.LeaderIcon:SetSize(16, 16)
        ns.SetPointOnce(contextual.LeaderIcon, "TOPLEFT", frame, "TOPLEFT", 21, -16)
    end
    local function PlayerPvp()
        if not active then return end
        ns.Fade(contextual.PrestigePortrait)
        ns.Fade(contextual.PrestigeBadge)
        FadePvpCircle(frame)
        ns.FadeCircles(main)
        local holder = frame.fcui and frame.fcui.texts
        local icon = OwnPvpIcon(frame, holder, "player", contextual.PVPIcon, "TOPLEFT", -1, -22)
        if icon and PlayerPVPTimerText then
            if holder and PlayerPVPTimerText:GetParent() ~= holder then PlayerPVPTimerText:SetParent(holder) end
            ns.SetPointOnce(PlayerPVPTimerText, "CENTER", icon, "TOPLEFT", 21, 2)
        end
    end
    Keeper("player.pvp", PlayerPvp)
    if contextual.GroupIndicator then
        ns.SetPointOnce(contextual.GroupIndicator, "BOTTOMLEFT", frame, "TOPLEFT", 97, -20)
    end

    frames.player = { unit = "player", frame = frame, health = health, power = power }
    Keeper("player.anchors", KeepPlayerAnchors)
    Update(frames.player)
end

KeepPlayerAnchors = function()
    if not active or not On("player") then return end
    local host = PlayerFrame and PlayerFrame.fcui and PlayerFrame.fcui.host
    if not host then return end
    if PlayerName then ns.SetPointOnce(PlayerName, "TOPLEFT", host, "TOPLEFT", 97, -30) end
    if PlayerLevelText then ns.SetPointOnce(PlayerLevelText, "CENTER", host, "TOPLEFT", 36, -71) end
end

local CLASSIFICATION_ART = {
    rareelite = { key = "targetingRareElite", flashCoords = { 0, 0.9453125, 0.181640625, 0.400390625 }, flashSize = { 242, 112 }, flashPoint = { -2, 5 } },
    elite = { key = "targetingElite", flashCoords = { 0, 0.9453125, 0.181640625, 0.400390625 }, flashSize = { 242, 112 }, flashPoint = { -2, 5 } },
    worldboss = { key = "targetingElite", flashCoords = { 0, 0.9453125, 0.181640625, 0.400390625 }, flashSize = { 242, 112 }, flashPoint = { -2, 5 } },
    rare = { key = "targetingRare", flashCoords = { 0, 0.9453125, 0, 0.181640625 }, flashSize = { 242, 93 }, flashPoint = { -4, -4 } },
    minus = { key = "targetingMinus", flashCoords = { 0, 1, 0, 1 }, flashSize = { 256, 128 }, flashPoint = { -4, -4 }, flashKey = "targetingMinusFlash" },
    normal = { key = "targetingFrame", flashCoords = { 0, 0.9453125, 0, 0.181640625 }, flashSize = { 242, 93 }, flashPoint = { -4, -4 } },
}

local function ApplyClassification(frame)
    local entry = frames[frame]
    if not entry or not active then return end
    local container = frame.TargetFrameContainer
    local classification = UnitClassification(entry.unit)
    if (issecretvalue and issecretvalue(classification)) or classification == nil then classification = "normal" end
    local art = CLASSIFICATION_ART[classification] or CLASSIFICATION_ART.normal
    if container.FrameTexture then
        ns.SetTex(container.FrameTexture, art.key)
        container.FrameTexture:SetTexCoord(0.09375, 1, 0, 0.78125)
        container.FrameTexture:SetSize(FRAME_W, FRAME_H)
        ns.SetPointOnce(container.FrameTexture, "TOPLEFT", frame, "TOPLEFT", 20, -4)
    end
    if container.Flash then
        ns.SetTex(container.Flash, art.flashKey or "targetingFlash")
        container.Flash:SetAlpha(EraUI:GetSetting("disableAggroHighlight") and 0 or 1)
        container.Flash:SetTexCoord(unpack(art.flashCoords))
        container.Flash:SetSize(unpack(art.flashSize))
        ns.SetPointOnce(container.Flash, "TOPLEFT", frame, "TOPLEFT", art.flashPoint[1], art.flashPoint[2])
    end
    if container.BossPortraitFrameTexture then ns.Fade(container.BossPortraitFrameTexture) end
    local contextual = ns.Path(frame, "TargetFrameContent", "TargetFrameContentContextual")
    if contextual and contextual.BossIcon then ns.Fade(contextual.BossIcon) end
    local main = ns.Path(frame, "TargetFrameContent", "TargetFrameContentMain")
    local minus = classification == "minus"
    if entry.power then entry.power:SetAlpha(minus and 0 or 1) end
    if entry.bg then
        entry.bg:SetSize(BAR_W, minus and 12 or 25)
    end
    if main and main.ReputationColor then main.ReputationColor:SetShown(not minus) end
    frame.haveElite = (classification == "elite" or classification == "worldboss" or classification == "rare" or classification == "rareelite") or nil
end

local TOT_X, TOT_Y = 20 + 232 - 35 - 93, -4 - 100 - 10 + 45
local function PlaceTot(frame)
    local tot = frame and frame.totFrame
    if not tot or InCombatLockdown() then return end
    if frame.smallSize and math.abs(tot:GetScale() - 1) > 0.01 then tot:SetScale(1) end
    local scale = tot:GetScale()
    if not scale or scale <= 0 then scale = 1 end
    local wantX, wantY = TOT_X / scale, TOT_Y / scale
    local point, relativeTo, relativePoint, x, y = tot:GetPoint(1)
    if tot:GetNumPoints() == 1 and point == "TOPLEFT" and relativeTo == frame and relativePoint == "TOPLEFT"
        and math.abs((x or 0) - wantX) < 0.5 and math.abs((y or 0) - wantY) < 0.5 then
        return
    end
    tot:ClearAllPoints()
    tot:SetPoint("TOPLEFT", frame, "TOPLEFT", wantX, wantY)
end

local function FillTot(tot, fallbackUnit)
    local own = tot.fcui
    if not own or not own.totHealth then return end
    local unit = tot.unit or fallbackUnit
    if not unit or not UnitExists(unit) then return end
    ns.SetHealth(own.totHealth, unit)
    ns.SetPower(own.totPower, unit)
end

local function SkinTarget(frame, unit)
    if Busy() then return end
    if not frame then return end
    local container = frame.TargetFrameContainer
    local main = ns.Path(frame, "TargetFrameContent", "TargetFrameContentMain")
    local contextual = ns.Path(frame, "TargetFrameContent", "TargetFrameContentContextual")
    if not container or not main or not contextual then ns.MissingPiece(frame:GetName() .. " layout") return end
    local healthContainer = main.HealthBarsContainer
    local blizzHealth = healthContainer and healthContainer.HealthBar
    local blizzMana = main.ManaBar

    if container.Portrait then
        container.Portrait:SetSize(PORTRAIT, PORTRAIT)
        ns.SetPointOnce(container.Portrait, "TOPRIGHT", frame, "TOPRIGHT", -22, -16)
    end
    if container.PortraitMask then
        container.PortraitMask:SetSize(PORTRAIT, PORTRAIT)
        ns.SetTex(container.PortraitMask, "portraitMask")
        ns.SetPointOnce(container.PortraitMask, "TOPRIGHT", frame, "TOPRIGHT", -22, -16)
    end

    local host = frame.fcui and frame.fcui.host
    if not host then
        host = CreateFrame("Frame", nil, frame)
        host:EnableMouse(false)
        frame.fcui = frame.fcui or {}
        frame.fcui.host = host
    end
    host:SetAllPoints(frame)
    host:Show()
    local base = frame:GetFrameLevel()
    if host:GetFrameLevel() ~= base + 1 then host:SetFrameLevel(base + 1) end
    if container:GetFrameLevel() ~= base + 3 then container:SetFrameLevel(base + 3) end
    if contextual:GetFrameLevel() ~= base + 4 then contextual:SetFrameLevel(base + 4) end
    local bg = ns.OwnTexture(host, "barBg", "BACKGROUND")
    bg:SetColorTexture(0, 0, 0, 0.5)
    bg:SetSize(BAR_W, 25)
    ns.SetPointOnce(bg, "TOPLEFT", host, "TOPLEFT", TARGET_BAR_X, HEALTH_Y)

    local health = ns.CreateBar(host, "health", BAR_W, BAR_H)
    ns.SetPointOnce(health, "TOPLEFT", host, "TOPLEFT", TARGET_BAR_X, HEALTH_Y)
    health:SetStatusBarColor(ns.HealthColor(unit))
    local power = ns.CreateBar(host, "power", BAR_W, BAR_H)
    ns.SetPointOnce(power, "TOPLEFT", host, "TOPLEFT", TARGET_BAR_X, POWER_Y)
    if blizzHealth then ns.SetPointOnce(blizzHealth, "TOPLEFT", health, "TOPLEFT", 0, 0); blizzHealth:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0) end
    if blizzMana then ns.SetPointOnce(blizzMana, "TOPLEFT", power, "TOPLEFT", 0, 0); blizzMana:SetPoint("BOTTOMRIGHT", power, "BOTTOMRIGHT", 0, 0) end

    if blizzHealth then
        ns.Fade(blizzHealth)
        AttachTexts(health, { blizzHealth.TextString, healthContainer.LeftText, healthContainer.RightText, healthContainer.DeadText, healthContainer.UnconsciousText },
            { { "CENTER", 0, 0 }, { "LEFT", 5, 0 }, { "RIGHT", -7, 0 }, { "CENTER", 0, 0 }, { "CENTER", 0, 0 } }, TextHolder(frame, contextual))
        AttachOverlays(blizzHealth, health, healthContainer.HealthBarMask)
    end
    if blizzMana then
        ns.Fade(blizzMana)
        AttachTexts(power, { blizzMana.TextString, blizzMana.LeftText, blizzMana.RightText },
            { { "CENTER", 0, 0 }, { "LEFT", 5, 0 }, { "RIGHT", -7, 0 } }, TextHolder(frame, contextual))
    end

    if main.Name then
        main.Name:SetParent(contextual)
        main.Name:SetWidth(100)
        main.Name:SetJustifyH("CENTER")
        ns.SetPointOnce(main.Name, "TOPLEFT", host, "TOPLEFT", 36, -30)
    end
    if main.ReputationColor then
        ns.SetTex(main.ReputationColor, "levelBackground")
        main.ReputationColor:SetTexCoord(0, 1, 0, 1)
        main.ReputationColor:SetSize(BAR_W, 19)
        ns.SetPointOnce(main.ReputationColor, "TOPRIGHT", frame, "TOPRIGHT", -86, -26)
    end
    if main.LevelText then
        main.LevelText:SetParent(contextual)
        main.LevelText:SetFontObject("GameFontNormalSmall")
        main.LevelText:SetJustifyH("CENTER")
        ns.SetPointOnce(main.LevelText, "CENTER", host, "TOPLEFT", 198, -71)
    end
    ns.Fade(main.LevelBackgroundCircle)
    ns.FadeCircles(main)
    ns.FadeCircles(contextual)
    if contextual.HighLevelTexture then
        ns.SetTex(contextual.HighLevelTexture, "skull")
        contextual.HighLevelTexture:SetTexCoord(0, 1, 0, 1)
        contextual.HighLevelTexture:SetSize(16, 16)
        ns.SetPointOnce(contextual.HighLevelTexture, "CENTER", host, "TOPLEFT", 197, -71)
    end
    if contextual.LeaderIcon then
        ns.SetTex(contextual.LeaderIcon, "leaderIcon")
        contextual.LeaderIcon:SetTexCoord(0, 1, 0, 1)
        contextual.LeaderIcon:SetSize(16, 16)
        ns.SetPointOnce(contextual.LeaderIcon, "TOPRIGHT", frame, "TOPRIGHT", -24, -14)
    end
    if contextual.RaidTargetIcon and container.Portrait then
        ns.SetPointOnce(contextual.RaidTargetIcon, "CENTER", container.Portrait, "TOP", 2, -2)
    end
    if contextual.QuestIcon then
        ns.SetTex(contextual.QuestIcon, "questBadge")
        contextual.QuestIcon:SetTexCoord(0, 1, 0, 1)
        contextual.QuestIcon:SetSize(32, 32)
        ns.SetPointOnce(contextual.QuestIcon, "TOP", frame, "TOP", 32, -16)
    end
    if contextual.NumericalThreat then
        ns.SetPointOnce(contextual.NumericalThreat, "BOTTOM", frame, "TOP", -30, -26)
    end
    local function TargetPvp(self)
        if not active then return end
        ns.Fade(contextual.PrestigePortrait)
        ns.Fade(contextual.PrestigeBadge)
        FadePvpCircle(frame)
        ns.FadeCircles(contextual)
        ns.FadeCircles(main)
        OwnPvpIcon(frame, frame.fcui and frame.fcui.texts, (self and self.unit) or unit, contextual.PvpIcon, "TOPRIGHT", 25, -22)
    end
    frames[frame] = { unit = unit, frame = frame, health = health, power = power, bg = bg }
    Update(frames[frame])

    Keeper(unit .. ".frame", function()
        if not active or not frames[frame] then return end
        TargetPvp(frame)
        ApplyClassification(frame)
        local main = ns.Path(frame, "TargetFrameContent", "TargetFrameContentMain")
        local contextual = ns.Path(frame, "TargetFrameContent", "TargetFrameContentContextual")
        local host = frame.fcui and frame.fcui.host
        -- The client re-colours the target name when you target yourself but
        -- never re-writes the text, so the previous target's name lingers in
        -- your class colour. Re-assert the name on every target change.
        local currentUnit = frame.unit or unit
        if main and main.Name and UnitExists(currentUnit) then
            local name = UnitName(currentUnit)
            if name and not (issecretvalue and issecretvalue(name)) and main.Name:GetText() ~= name then
                main.Name:SetText(name)
            end
        end
        if main and main.LevelText and host then
            ns.SetPointOnce(main.LevelText, "CENTER", host, "TOPLEFT", 198, -71)
            local skull = ns.SkullLevel(UnitLevel(frame.unit or unit), frame.unit or unit)
            main.LevelText:SetShown(not skull)
            if contextual and contextual.HighLevelTexture then
                contextual.HighLevelTexture:SetShown(skull)
            end
        end
        KeepAuraRow(frame)
        local tot = frame.totFrame
        if tot and tot:IsShown() then
            ns.Fade(tot.FrameTexture)
            ns.Fade(tot.HealthBar)
            ns.Fade(tot.ManaBar)
        end
        PlaceTot(frame)
    end)

    local tot = frame.totFrame
    PlaceTot(frame)
    if tot then
        tot.fcui = tot.fcui or {}
        local holder = tot.fcui.artHolder
        if not holder then
            holder = CreateFrame("Frame", nil, tot)
            holder:EnableMouse(false)
            holder:SetAllPoints(tot)
            tot.fcui.artHolder = holder
        end
        local top = math.max(tot.HealthBar and tot.HealthBar:GetFrameLevel() or 0,
            tot.ManaBar and tot.ManaBar:GetFrameLevel() or 0, tot:GetFrameLevel()) + 1
        if holder:GetFrameLevel() ~= top then holder:SetFrameLevel(top) end
        holder:Show()
        local totArt = ns.OwnTexture(holder, "art", "ARTWORK")
        ns.SetTex(totArt, "targetOfTarget")
        totArt:SetTexCoord(0.015625, 0.7265625, 0, 0.703125)
        totArt:SetSize(93, 45)
        ns.SetPointOnce(totArt, "TOPLEFT", tot, "TOPLEFT", 0, 0)
        totArt:Show()
        ns.Fade(tot.FrameTexture)
        if tot.Portrait then
            tot.Portrait:SetSize(35, 35)
            ns.SetPointOnce(tot.Portrait, "TOPLEFT", tot, "TOPLEFT", 5, -5)
        end
        if tot.Name then
            tot.Name:SetParent(holder)
            tot.Name:SetWidth(100)
            ns.SetPointOnce(tot.Name, "BOTTOMLEFT", totArt, "BOTTOMLEFT", 42, 3)
        end
        local totBg = ns.OwnTexture(tot, "barBg", "BACKGROUND")
        totBg:SetColorTexture(0, 0, 0, 0.5)
        totBg:SetSize(46, 15)
        ns.SetPointOnce(totBg, "TOPLEFT", tot, "TOPLEFT", 45, -15)
        ns.Fade(tot.HealthBar)
        ns.Fade(tot.ManaBar)
        local barHost = tot.fcui.barHost
        if not barHost then
            barHost = CreateFrame("Frame", nil, tot)
            barHost:EnableMouse(false)
            barHost:SetAllPoints(tot)
            tot.fcui.barHost = barHost
        end
        barHost:Show()
        local totHealth = ns.CreateBar(barHost, "health", 46, 7)
        ns.SetPointOnce(totHealth, "TOPLEFT", tot, "TOPLEFT", 45, -15)
        local totPower = ns.CreateBar(barHost, "power", 46, 7)
        ns.SetPointOnce(totPower, "TOPLEFT", tot, "TOPLEFT", 45, -23)
        tot.fcui.totHealth, tot.fcui.totPower = totHealth, totPower
        local over = math.max(totHealth:GetFrameLevel(), totPower:GetFrameLevel(), holder:GetFrameLevel() - 2) + 2
        if holder:GetFrameLevel() ~= over then holder:SetFrameLevel(over) end
        local fallbackUnit = (frame.unit or unit) .. "target"
        local since = 0
        holder:SetScript("OnUpdate", function(_, elapsed)
            since = since + elapsed
            if since < 0.1 then return end
            since = 0
            if active then FillTot(tot, fallbackUnit) end
        end)
        holder:SetScript("OnShow", function()
            since = 0
            if active then FillTot(tot, fallbackUnit) end
        end)
        holder:RegisterEvent("PLAYER_TARGET_CHANGED")
        holder:RegisterEvent("PLAYER_FOCUS_CHANGED")
        holder:RegisterUnitEvent("UNIT_TARGET", frame.unit or unit)
        holder:SetScript("OnEvent", function()
            since = 0
            if active then FillTot(tot, fallbackUnit) end
        end)
        totHealth:SetStatusBarColor(0, 1, 0)
        totPower:SetStatusBarColor(0, 0, 1)
        FillTot(tot, fallbackUnit)
        local totName = tot:GetName()
        if totName then
            local spots = { { -23, -8 }, { -10, -8 }, { -23, -21 }, { -10, -21 } }
            for i = 1, 4 do
                local debuff = _G[totName .. "Debuff" .. i]
                if debuff then ns.SetPointOnce(debuff, "TOPLEFT", tot, "TOPRIGHT", spots[i][1], spots[i][2]) end
            end
        end
    end
end

local function SkinPet()
    if Busy() then return end
    local frame = PetFrame
    if not frame then return end
    frame:SetSize(128, 53)
    if PetPortrait then ns.SetPointOnce(PetPortrait, "TOPLEFT", frame, "TOPLEFT", 7, -6) end
    if PetName then
        PetName:SetWidth(0)
        ns.SetPointOnce(PetName, "BOTTOMLEFT", frame, "BOTTOMLEFT", 53, 33)
    end
    if PetFrameTexture then
        ns.SetTex(PetFrameTexture, "smallTargetingFrame")
        PetFrameTexture:SetTexCoord(0, 1, 0, 1)
        PetFrameTexture:SetSize(128, 64)
        ns.SetPointOnce(PetFrameTexture, "TOPLEFT", frame, "TOPLEFT", 0, -2)
    end
    if PetFrameFlash then
        ns.SetTex(PetFrameFlash, "partyFlash")
        PetFrameFlash:SetTexCoord(0, 1, 1, 0)
        PetFrameFlash:SetSize(128, 64)
        ns.SetPointOnce(PetFrameFlash, "TOPLEFT", frame, "TOPLEFT", -4, 11)
        PetFrameFlash:SetDrawLayer("BACKGROUND")
    end
    local bars = { { PetFrameHealthBar, -22, PetFrameHealthBarMask, { PetFrameHealthBarText, PetFrameHealthBarTextLeft, PetFrameHealthBarTextRight } },
        { PetFrameManaBar, -29, PetFrameManaBarMask, { PetFrameManaBarText, PetFrameManaBarTextLeft, PetFrameManaBarTextRight } } }
    for _, b in ipairs(bars) do
        local bar, y, mask, texts = b[1], b[2], b[3], b[4]
        if bar then
            bar:SetStatusBarTexture((ns.TexPath(UI_STATUSBAR)))
            bar:SetSize(69, 8)
            ns.SetPointOnce(bar, "TOPLEFT", frame, "TOPLEFT", 47, y)
            if mask then ns.Fade(mask) end
            AttachTexts(bar, texts, { { "CENTER", 0, 0 }, { "LEFT", 3, 0 }, { "RIGHT", -3, 0 } }, TextHolder(frame))
        end
    end
    KeepBar(PetFrameHealthBar, "health")
    KeepBar(PetFrameManaBar, "power")
    if PetAttackModeTexture then
        ns.SetTex(PetAttackModeTexture, "petAttackStatus")
        PetAttackModeTexture:SetTexCoord(0.703125, 1, 0, 1)
        PetAttackModeTexture:SetSize(76, 64)
        ns.SetPointOnce(PetAttackModeTexture, "TOPLEFT", frame, "TOPLEFT", 6, -9)
    end
    if PetHitIndicator then ns.SetPointOnce(PetHitIndicator, "CENTER", frame, "TOPLEFT", 28, -27) end
end

local function SkinPartyMember(frame)
    if Busy() then return end
    if frame.Texture then
        ns.SetTex(frame.Texture, "partyFrame")
        frame.Texture:SetTexCoord(0, 1, 0, 1)
        frame.Texture:SetSize(128, 64)
        ns.SetPointOnce(frame.Texture, "TOPLEFT", frame, "TOPLEFT", 0, -10)
        frame.Texture:SetDrawLayer("ARTWORK", 7)
    end
    if frame.Portrait then ns.SetPointOnce(frame.Portrait, "TOPLEFT", frame, "TOPLEFT", 7, -14) end
    if frame.Name then
        frame.Name:SetWidth(0)
        ns.SetPointOnce(frame.Name, "TOPLEFT", frame, "TOPLEFT", 49, -7)
    end
    local bg = ns.OwnTexture(frame, "barBg", "BACKGROUND", -7)
    bg:SetColorTexture(0, 0, 0, 0.5)
    bg:SetSize(72, 20)
    ns.SetPointOnce(bg, "TOPLEFT", frame, "TOPLEFT", 45, -19)
    local host = frame.fcui and frame.fcui.host
    if not host then
        host = CreateFrame("Frame", nil, frame)
        host:EnableMouse(false)
        frame.fcui = frame.fcui or {}
        frame.fcui.host = host
    end
    host:SetAllPoints(frame)
    host:Show()
    local under = math.max(0, frame:GetFrameLevel() - 1)
    if host:GetFrameLevel() ~= under then host:SetFrameLevel(under) end
    local health = ns.CreateBar(host, "health", 70, 10)
    ns.SetPointOnce(health, "TOPLEFT", host, "TOPLEFT", 45, -19)
    health:SetStatusBarColor(0, 1, 0)
    local power = ns.CreateBar(host, "power", 74, 7)
    ns.SetPointOnce(power, "TOPLEFT", host, "TOPLEFT", 41, -30)
    local container = frame.HealthBarContainer
    local blizzHealth = ns.Path(frame, "HealthBarContainer", "HealthBar")
    if container then
        ns.Fade(container)
        if blizzHealth then
            ns.SetPointOnce(blizzHealth, "TOPLEFT", health, "TOPLEFT", 0, 0)
            blizzHealth:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
            AttachTexts(health, { container.CenterText, container.LeftText, container.RightText },
                { { "CENTER", 0, 0 }, { "LEFT", 3, 0 }, { "RIGHT", -3, 0 } }, TextHolder(frame))
            AttachOverlays(blizzHealth, health, container.HealthBarMask)
        end
    end
    local mana = frame.ManaBar
    if mana then
        ns.Fade(mana)
        ns.SetPointOnce(mana, "TOPLEFT", power, "TOPLEFT", 0, 0)
        mana:SetPoint("BOTTOMRIGHT", power, "BOTTOMRIGHT", 0, 0)
        AttachTexts(power, { mana.CenterText, mana.LeftText, mana.RightText },
            { { "CENTER", 2, 0 }, { "LEFT", 7, 0 }, { "RIGHT", -3, 0 } }, TextHolder(frame))
    end
    frames[frame] = { unit = frame.unit or "party1", frame = frame, health = health, power = power }
    Update(frames[frame])
    local overlay = frame.PartyMemberOverlay
    if overlay then
        if overlay.LeaderIcon then
            ns.SetTex(overlay.LeaderIcon, "leaderIcon")
            overlay.LeaderIcon:SetTexCoord(0, 1, 0, 1)
            overlay.LeaderIcon:SetSize(16, 16)
            ns.SetPointOnce(overlay.LeaderIcon, "TOPLEFT", frame, "TOPLEFT", 0, -8)
        end
        if overlay.RoleIcon then ns.SetPointOnce(overlay.RoleIcon, "TOPLEFT", frame, "TOPLEFT", 7, -41) end
        if overlay.PVPIcon then ns.SetPointOnce(overlay.PVPIcon, "TOPLEFT", frame, "TOPLEFT", -9, -23) end
    end
    if frame.Flash then
        ns.SetTex(frame.Flash, "partyFlash")
        frame.Flash:SetTexCoord(0, 1, 0, 1)
        frame.Flash:SetSize(128, 64)
        ns.SetPointOnce(frame.Flash, "TOPLEFT", frame, "TOPLEFT", -3, -6)
        frame.Flash:SetDrawLayer("BACKGROUND", 0)
    end
    if frame.Name then ns.SetPointOnce(frame.Name, "TOPLEFT", frame, "TOPLEFT", 49, -7) end
end

SkinParty = function()
    local pool = PartyFrame and PartyFrame.PartyMemberFramePool
    if not pool then return end
    if Busy() then return end
    for frame in pool:EnumerateActive() do SkinPartyMember(frame) end
end

local function PartyArtUndone(frame)
    local tex = frame.Texture
    if not tex then return false end
    local atlas = tex.GetAtlas and tex:GetAtlas()
    if atlas and not (issecretvalue and issecretvalue(atlas)) then return true end
    local w, h = tex:GetSize()
    local point, relativeTo, _, x, y = tex:GetPoint(1)
    if issecretvalue and (issecretvalue(w) or issecretvalue(h) or issecretvalue(point) or issecretvalue(x) or issecretvalue(y)) then
        return nil
    end
    if math.abs((w or 0) - 128) > 0.5 or math.abs((h or 0) - 64) > 0.5 then return true end
    return point ~= "TOPLEFT" or relativeTo ~= frame or math.abs(x or 0) > 0.5 or math.abs((y or 0) + 10) > 0.5
end

local function KeepParty()
    if not active or not On("party") then return end
    local pool = PartyFrame and PartyFrame.PartyMemberFramePool
    if not pool then return end
    for frame in pool:EnumerateActive() do
        local undone = frames[frame] and PartyArtUndone(frame)
        if undone or undone == nil and frames[frame] then
            local tex = frame.Texture
            ns.SetTex(tex, "partyFrame")
            tex:SetTexCoord(0, 1, 0, 1)
            tex:SetSize(128, 64)
            ns.SetPointOnce(tex, "TOPLEFT", frame, "TOPLEFT", 0, -10)
            if frame.Portrait then ns.SetPointOnce(frame.Portrait, "TOPLEFT", frame, "TOPLEFT", 7, -14) end
            if frame.Name then ns.SetPointOnce(frame.Name, "TOPLEFT", frame, "TOPLEFT", 49, -7) end
            if frame.Flash then
                ns.SetTex(frame.Flash, "partyFlash")
                frame.Flash:SetTexCoord(0, 1, 0, 1)
                frame.Flash:SetSize(128, 64)
                ns.SetPointOnce(frame.Flash, "TOPLEFT", frame, "TOPLEFT", -3, -6)
            end
            if undone and not Busy() then SkinPartyMember(frame) end
        end
    end
end

SkinPartySoon = function()
    if not active or not On("party") then return end
    SkinParty()
    C_Timer.After(0, SkinParty)
    C_Timer.After(0.3, SkinParty)
end

local managerState

local ARROW_BAND = 0.36
local function ClientTabArt(button, on)
    for _, key in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        local get = button[key]
        local tex = get and get(button)
        if tex then tex:SetAlpha(on and 1 or 0) end
    end
end

local function MirrorTab(button)
    if button.fcuiTab then
        ClientTabArt(button, false)
        button.fcuiTab.back:Show()
        button.fcuiTab.arrow:Show()
        return
    end
    if not C_Texture or not C_Texture.GetAtlasInfo then return end
    local info = C_Texture.GetAtlasInfo("gm-btnforward-normal")
    if not info or not info.file then return end
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetTexture(info.file)
    back:SetTexCoord(r, l, t, b)
    back:SetAllPoints(button)
    local arrow = button:CreateTexture(nil, "ARTWORK")
    arrow:SetTexture(info.file)
    arrow:SetTexCoord(l + (r - l) * (0.5 - ARROW_BAND / 2), l + (r - l) * (0.5 + ARROW_BAND / 2), t, b)
    arrow:SetPoint("TOP", button, "TOP", 0, 0)
    arrow:SetPoint("BOTTOM", button, "BOTTOM", 0, 0)
    arrow:SetWidth(math.max(1, (button:GetWidth() or 16) * ARROW_BAND))
    local glow = button:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints(button)
    glow:SetColorTexture(1, 1, 1, 0.12)
    button.fcuiTab = { back = back, arrow = arrow, glow = glow }
    ClientTabArt(button, false)
    button:HookScript("OnEnter", function(self) if self.fcuiTab and self.fcuiTab.back:IsShown() then ClientTabArt(self, false) end end)
    button:HookScript("OnLeave", function(self) if self.fcuiTab and self.fcuiTab.back:IsShown() then ClientTabArt(self, false) end end)
end

local function PlainTab(button)
    if not button.fcuiTab then return end
    button.fcuiTab.back:Hide()
    button.fcuiTab.arrow:Hide()
    ClientTabArt(button, true)
end

local function LayoutRaidManager()
    local manager = CompactRaidFrameManager
    if not manager then return end
    local arrow = manager.toggleButtonForward
    if active then
        if manager.Background then manager.Background:SetAlpha(manager.collapsed and 0 or 1) end
        if arrow then
            arrow:ClearAllPoints()
            arrow:SetPoint("TOPRIGHT", manager, "TOPRIGHT", -7, 0)
            MirrorTab(arrow)
        end
    else
        if manager.Background then manager.Background:SetAlpha(1) end
        if arrow then
            arrow:ClearAllPoints()
            arrow:SetPoint("RIGHT", manager, "RIGHT", -7, 0)
            PlainTab(arrow)
        end
    end
end

local function WatchRaidManager()
    local manager = CompactRaidFrameManager
    if not manager then return end
    local state = manager.collapsed and true or false
    if state == managerState then return end
    managerState = state
    LayoutRaidManager()
end

local function SkinRaidManager()
    if not CompactRaidFrameManager then return end
    managerState = nil
    WatchRaidManager()
end

local function HideHost(frame)
    if frame and frame.fcui and frame.fcui.host then frame.fcui.host:Hide() end
end

RestorePlayer = function()
    if not PlayerFrame then return end
    frames.player = nil
    HideOwnPvp(PlayerFrame)
    ns.Unfade(ns.Path(PlayerFrame, "PlayerFrameContent", "PlayerFrameContentContextual", "PVPIcon"))
    HideHost(PlayerFrame)
    local pmain = ns.Path(PlayerFrame, "PlayerFrameContent", "PlayerFrameContentMain")
    if pmain then
        ns.Unfade(pmain.HealthBarsContainer)
        ns.Unfade(pmain.ManaBarArea)
    end
    ns.needsReload = true
end

RestoreTargetLike = function(frame)
    if not frame then return end
    frames[frame] = nil
    HideOwnPvp(frame)
    ns.Unfade(ns.Path(frame, "TargetFrameContent", "TargetFrameContentContextual", "PvpIcon"))
    HideHost(frame)
    local main = ns.Path(frame, "TargetFrameContent", "TargetFrameContentMain")
    if main then
        ns.Unfade(ns.Path(main, "HealthBarsContainer", "HealthBar"))
        ns.Unfade(main.ManaBar)
    end
    local tot = frame.totFrame
    if tot and tot.fcui then
        if tot.fcui.artHolder then tot.fcui.artHolder:Hide() end
        if tot.fcui.barHost then tot.fcui.barHost:Hide() end
        ns.Unfade(tot.FrameTexture)
        ns.Unfade(tot.HealthBar)
        ns.Unfade(tot.ManaBar)
    end
    ns.needsReload = true
end

RestoreParty = function()
    local pool = PartyFrame and PartyFrame.PartyMemberFramePool
    if not pool then return end
    for frame in pool:EnumerateActive() do
        frames[frame] = nil
        HideHost(frame)
        ns.Unfade(frame.HealthBarContainer)
        ns.Unfade(frame.ManaBar)
    end
    ns.needsReload = true
end

local function SnapToPixels(frame)
    if not frame or InCombatLockdown() or not frame.GetPoint then return end
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    if not point or not x then return end
    local scale = frame:GetScale()
    if not scale or scale <= 0 then scale = 1 end
    local sx, sy = x * scale, y * scale
    local nx, ny = math.floor(sx + 0.5), math.floor(sy + 0.5)
    if math.abs(sx - nx) < 0.01 and math.abs(sy - ny) < 0.01 then return end
    frame:SetPoint(point, rel, relPoint, nx / scale, ny / scale)
end

local function Apply()
    active = true
    Keeper("player.art", KeepPlayerArt)
    Keeper("party", KeepParty)
    if not driver then
        driver = CreateFrame("Frame")
        driver:SetScript("OnEvent", OnEvent)
        for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
            "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_ENTERING_WORLD", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE",
            "GROUP_ROSTER_UPDATE", "PARTY_MEMBER_ENABLE", "PARTY_MEMBER_DISABLE", "PLAYER_REGEN_ENABLED", "UNIT_PET",
            "PLAYER_UPDATE_RESTING", "PLAYER_REGEN_DISABLED", "PLAYER_FLAGS_CHANGED", "UNIT_CLASSIFICATION_CHANGED",
            "UNIT_FACTION", "UNIT_LEVEL", "PLAYER_LEVEL_UP", "PLAYER_LEVEL_CHANGED" }) do
            pcall(driver.RegisterEvent, driver, event)
        end
        driver:SetScript("OnUpdate", function(self, elapsed)
            if not active then return end
            if frames.player then Update(frames.player, "power") end
            if TargetFrame and frames[TargetFrame] and TargetFrame:IsShown() then KeepAuraRow(TargetFrame) end
            if FocusFrame and frames[FocusFrame] and FocusFrame:IsShown() then KeepAuraRow(FocusFrame) end
            self.since = (self.since or 0) + elapsed
            if self.since < 0.25 then return end
            self.since = 0
            WatchRaidManager()
            RepaintKept("pet")
            KeepFrames()
        end)
    end
    if On("player") then SkinPlayer() else RestorePlayer() end
    if On("target") then SkinTarget(TargetFrame, "target") else RestoreTargetLike(TargetFrame) end
    if On("focus") then
        if EraUI:GetSetting("matchFocusSize") and FocusFrame and TargetFrame and not Busy() then
            if FocusFrame.smallSize and FocusFrame.SetSmallSize then FocusFrame:SetSmallSize(false) end
            local scale = TargetFrame:GetScale()
            if FocusFrame:GetScale() ~= scale then FocusFrame:SetScale(scale) end
        end
        SkinTarget(FocusFrame, "focus")
    else RestoreTargetLike(FocusFrame) end
    if On("pet") then SkinPet() end
    if On("party") then SkinParty() else RestoreParty() end
    SkinRaidManager()
    for _, name in ipairs({ "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame" }) do
        SnapToPixels(_G[name])
    end
end

local function Restore()
    active = false
    LayoutRaidManager()
    RestorePlayer()
    RestoreTargetLike(TargetFrame)
    RestoreTargetLike(FocusFrame)
    RestoreParty()
    ns.needsReload = true
end

ns.RegisterModule("unitFrames", { apply = Apply, restore = Restore })

local arrowHidden = false
local arrowWatch
local function SetBuffArrow(hidden)
    local button = BuffFrame and BuffFrame.CollapseAndExpandButton
    if not button then return end
    local alpha = 1
    if hidden and not (button.IsMouseOver and button:IsMouseOver(6, -6, -6, 6)) then alpha = 0 end
    if math.abs((button:GetAlpha() or 1) - alpha) > 0.01 then button:SetAlpha(alpha) end
    if not button:IsMouseEnabled() then button:EnableMouse(true) end
end

ns.RegisterModule("hideBuffArrow", {
    apply = function()
        arrowHidden = true
        SetBuffArrow(true)
        if not arrowWatch then
            arrowWatch = CreateFrame("Frame")
            arrowWatch:SetScript("OnUpdate", function(self, elapsed)
                self.since = (self.since or 0) + elapsed
                if self.since < 0.05 then return end
                self.since = 0
                if arrowHidden then SetBuffArrow(true) end
            end)
        end
    end,
    restore = function()
        arrowHidden = false
        SetBuffArrow(false)
    end,
})
