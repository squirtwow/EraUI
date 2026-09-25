-- EraUI nameplates.
-- The 1.x plate, drawn from the old sheet at its own size: a 128x16 rounded
-- border with the level in the slot at its right end, a 102x8 health bar in
-- the shaded fill, and the name above. A cast bar in the same border sits
-- under it. Blizzard's nameplate unit frame keeps all its logic; the pieces
-- are re-laid after its own anchoring passes. Forbidden plates are left alone.
local _, EraUI = ...
local ns = EraUI.Classic

local BORDER_W, BORDER_H = 128, 16
local INSET_L, INSET_R, INSET_T, INSET_B = 5, 21, 4, 4
local BAR_W, BAR_H = BORDER_W - INSET_L - INSET_R, BORDER_H - INSET_T - INSET_B
local BORDER_GAP = 2
local NAME_GAP = 2
local AURA_GAP = 4
local LEVEL_X = -11.5
local ICON_SIZE = 14
local CVAR = "nameplateStyle"

local SIZE_CVAR = "nameplateSize"
local SIZE_SCALES = { 0.8, 1.0, 1.25, 1.4, 1.6 }
local function PlateScale()
    local value = C_CVar and C_CVar.GetCVar and tonumber(C_CVar.GetCVar(SIZE_CVAR))
    return SIZE_SCALES[value or 2] or 1
end

local active = false
local skinned = setmetatable({}, { __mode = "k" })

local function Forbidden(frame)
    return not frame or (frame.IsForbidden and frame:IsForbidden())
end

local function Border(bar)
    local border = ns.OwnTexture(bar, "border", "OVERLAY", 2)
    ns.SetTex(border, "nameplateBorder")
    border:SetTexCoord(0, 1, 0.5, 1)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", bar, "TOPLEFT", -INSET_L, INSET_T)
    border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", INSET_R, -INSET_B)
    border:Show()
    return border
end

local CAST_EXTRA = INSET_R - INSET_L
local function CastBorder(bar)
    if bar.fcui and bar.fcui.border then bar.fcui.border:Hide() end
    local left = ns.OwnTexture(bar, "borderL", "OVERLAY", 2)
    local right = ns.OwnTexture(bar, "borderR", "OVERLAY", 2)
    for _, tex in ipairs({ left, right }) do
        ns.SetTex(tex, "nameplateBorder")
        tex:ClearAllPoints()
        tex:SetSize(BORDER_W / 2, BORDER_H)
        tex:Show()
    end
    left:SetTexCoord(0, 0.5, 0.5, 1)
    right:SetTexCoord(0.5, 0, 0.5, 1)
    left:SetPoint("TOPLEFT", bar, "TOPLEFT", -INSET_L, INSET_T)
    right:SetPoint("TOPRIGHT", bar, "TOPRIGHT", INSET_L, INSET_T)
    return left
end

local function ShadedFill(bar)
    local tex = bar.barTexture or (bar.GetStatusBarTexture and bar:GetStatusBarTexture())
    if not tex then return end
    tex:SetAtlas(nil)
    ns.SetTex(tex, "barFill")
    tex:SetTexCoord(0, 1, 0, 1)
end

local function UpdateLevel(unitFrame)
    local own = unitFrame.fcui
    local level, skull = own and own.level, own and own.skull
    if not level or not unitFrame.unit then return end
    local lvl = UnitLevel(unitFrame.unit)
    if lvl == nil or (issecretvalue and issecretvalue(lvl)) then
        level:SetText("")
        skull:Hide()
        return
    end
    if ns.SkullLevel(lvl, unitFrame.unit) then
        level:SetText("")
        skull:Show()
        return
    end
    skull:Hide()
    level:SetText(lvl)
    local color
    local foe = UnitCanAttack("player", unitFrame.unit)
    if issecretvalue and issecretvalue(foe) then foe = false end
    if foe then
        local rate = C_PlayerInfo and C_PlayerInfo.GetContentDifficultyCreatureForPlayer
        if rate and GetDifficultyColor then
            local ok, difficulty = pcall(rate, unitFrame.unit)
            if ok and difficulty then color = GetDifficultyColor(difficulty) end
        end
        if not color and GetCreatureDifficultyColor then color = GetCreatureDifficultyColor(lvl) end
    end
    if color then level:SetTextColor(color.r, color.g, color.b) else level:SetTextColor(1, 0.82, 0) end
end

local function ClassColor(unitFrame)
    if not active then return end
    local health = ns.Path(unitFrame, "HealthBarsContainer", "healthBar")
    local unit = unitFrame.unit or (unitFrame.displayedUnit)
    if not health or not unit then return end
    local isPlayer = UnitIsPlayer and UnitIsPlayer(unit)
    if issecretvalue and issecretvalue(isPlayer) then return end
    if not isPlayer then return end
    if ns.db.classColorPlates then
        local _, class = UnitClass(unit)
        if not class or (issecretvalue and issecretvalue(class)) then return end
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if color then health:SetStatusBarColor(color.r, color.g, color.b) end
        return
    end
    local friendly = UnitIsFriend and UnitIsFriend("player", unit)
    if issecretvalue and issecretvalue(friendly) then return end
    if friendly then
        local flagged = UnitIsPVP and UnitIsPVP(unit)
        if issecretvalue and issecretvalue(flagged) then flagged = false end
        if flagged then health:SetStatusBarColor(0, 1, 0) else health:SetStatusBarColor(0, 0, 1) end
    end
end
ns.NamePlateClassColor = ClassColor

local function Layout(unitFrame)
    if not active or Forbidden(unitFrame) then return end
    if ns.PlateAllowed and not ns.PlateAllowed(unitFrame) then return end
    local container = unitFrame.HealthBarsContainer
    local health = container and container.healthBar
    local castContainer = unitFrame.CastBarsContainer
    if not health or not castContainer then return end
    unitFrame.fcui = unitFrame.fcui or {}
    local own = unitFrame.fcui

    local scale = PlateScale()
    castContainer:SetScale(scale)
    container:SetScale(scale)
    castContainer:ClearAllPoints()
    castContainer:SetSize(BAR_W, BAR_H)
    castContainer:SetPoint("BOTTOM", unitFrame, "BOTTOM", 0, INSET_B)
    container:ClearAllPoints()
    container:SetSize(BAR_W, BAR_H)
    container:SetPoint("BOTTOM", castContainer, "TOP", 0, INSET_T + BORDER_GAP + INSET_B)
    health:ClearAllPoints()
    health:SetAllPoints(container)

    ShadedFill(health)
    ClassColor(unitFrame)
    local border = Border(health)
    for _, key in ipairs({ "bgTexture", "selectedBorder", "deselectedOverlay", "Text", "LeftText", "RightText" }) do
        if health[key] then health[key]:SetAlpha(0) end
    end
    if unitFrame.LevelFrame then ns.Fade(unitFrame.LevelFrame) end
    if unitFrame.PlayerLevelDiffFrame then ns.Fade(unitFrame.PlayerLevelDiffFrame) end
    if unitFrame.ClassificationFrame then ns.Fade(unitFrame.ClassificationFrame) end

    local level = own.level
    if not level then
        level = health:CreateFontString(nil, "OVERLAY", "SystemFont_NamePlateLevel")
        level:SetDrawLayer("OVERLAY", 3)
        level:SetShadowColor(0, 0, 0, 1)
        level:SetShadowOffset(1, -1)
        own.level = level
        local skull = health:CreateTexture(nil, "OVERLAY", nil, 3)
        skull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
        skull:SetSize(12, 12)
        skull:Hide()
        own.skull = skull
    end
    level:ClearAllPoints()
    level:SetPoint("CENTER", border, "RIGHT", LEVEL_X, 0)
    own.skull:ClearAllPoints()
    own.skull:SetPoint("CENTER", border, "RIGHT", LEVEL_X, 0)
    UpdateLevel(unitFrame)

    local name = unitFrame.name
    if name then
        name:ClearAllPoints()
        name:SetPoint("BOTTOM", border, "TOP", 0, NAME_GAP)
        name:SetWidth(0)
        name:SetJustifyH("CENTER")
        name:SetShadowColor(0, 0, 0, 1)
        name:SetShadowOffset(1, -1)
        local debuffs = ns.Path(unitFrame, "AurasFrame", "DebuffListFrame")
        if debuffs then
            debuffs:ClearAllPoints()
            debuffs:SetPoint("LEFT", border, "LEFT", 0, 0)
            debuffs:SetPoint("BOTTOM", name, "TOP", 0, AURA_GAP)
        end
    end

    local cast = castContainer.castBar
    if cast then
        cast:ClearAllPoints()
        cast:SetPoint("TOPLEFT", castContainer, "TOPLEFT", 0, 0)
        cast:SetPoint("BOTTOMRIGHT", castContainer, "BOTTOMRIGHT", CAST_EXTRA, 0)
        ShadedFill(cast)
        if cast.channeling then
            cast:SetStatusBarColor(0, 1, 0)
        else
            cast:SetStatusBarColor(1, 0.7, 0)
        end
        local castBorder = CastBorder(cast)
        if cast.Background then cast.Background:SetAlpha(0) end
        if cast.Border then cast.Border:SetAlpha(0) end
        if cast.Icon then
            cast.Icon:ClearAllPoints()
            cast.Icon:SetSize(ICON_SIZE, ICON_SIZE)
            cast.Icon:SetPoint("RIGHT", castBorder, "LEFT", -1, 0)
        end
        if cast.Text then
            cast.Text:ClearAllPoints()
            cast.Text:SetPoint("CENTER", cast, "CENTER", 0, 0)
            cast.Text:SetJustifyH("CENTER")
        end
        if cast.CastTargetNameText then cast.CastTargetNameText:SetAlpha(0) end
    end
end

local function SkinPlate(unitFrame)
    if not active or Forbidden(unitFrame) then return end
    if ns.PlateAllowed and not ns.PlateAllowed(unitFrame) then return end
    skinned[unitFrame] = true
    Layout(unitFrame)
end

local function PlateFor(unitToken)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unitToken)
    return ok and plate and plate.UnitFrame or nil
end

local function OnPlateAdded(unitToken)
    if not active then return end
    local unitFrame = PlateFor(unitToken)
    if unitFrame then SkinPlate(unitFrame) end
end

local function EachPlate(fn)
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" then return end
    for _, plate in ipairs(plates) do
        local unitFrame = plate and plate.UnitFrame
        if unitFrame and not Forbidden(unitFrame) then fn(unitFrame) end
    end
end

local SWEEP, RELAY = 0.2, 1
local driver

local function RestoreStyleChoice()
    local saved = ns.db.savedNamePlateStyle
    if saved == nil then return end
    ns.db.savedNamePlateStyle = nil
    ns.SetCVar(CVAR, saved)
end

local function Apply()
    active = true
    RestoreStyleChoice()
    if not NamePlateDriverFrame then ns.MissingPiece("NamePlateDriverFrame") return end
    if not driver then
        driver = CreateFrame("Frame")
        for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "UNIT_LEVEL", "PLAYER_TARGET_CHANGED",
            "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "CVAR_UPDATE",
            "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
            "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED" }) do
            pcall(driver.RegisterEvent, driver, event)
        end
        driver:SetScript("OnEvent", function(_, event, unit)
            if not active then return end
            if event == "NAME_PLATE_UNIT_ADDED" then
                OnPlateAdded(unit)
            elseif event == "UNIT_LEVEL" then
                local unitFrame = unit and PlateFor(unit)
                if unitFrame and not Forbidden(unitFrame) then UpdateLevel(unitFrame) end
            elseif event:find("SPELLCAST", 1, true) then
                local unitFrame = unit and PlateFor(unit)
                if unitFrame then SkinPlate(unitFrame) end
            else
                EachPlate(SkinPlate)
            end
        end)
        driver:SetScript("OnUpdate", function(self, elapsed)
            if not active then return end
            self.since = (self.since or 0) + elapsed
            if self.since < SWEEP then return end
            self.since = 0
            self.held = (self.held or 0) + SWEEP
            local place = self.held >= RELAY
            if place then self.held = 0 end
            EachPlate(function(unitFrame)
                if place or not skinned[unitFrame] then
                    SkinPlate(unitFrame)
                else
                    ClassColor(unitFrame)
                end
            end)
        end)
    end
    EachPlate(SkinPlate)
end

local function Restore()
    active = false
    RestoreStyleChoice()
    for unitFrame in pairs(skinned) do
        if unitFrame.fcui then
            for _, region in pairs(unitFrame.fcui) do region:Hide() end
        end
        if unitFrame.HealthBarsContainer then unitFrame.HealthBarsContainer:SetScale(1) end
        if unitFrame.CastBarsContainer then unitFrame.CastBarsContainer:SetScale(1) end
        local health = ns.Path(unitFrame, "HealthBarsContainer", "healthBar")
        local cast = ns.Path(unitFrame, "CastBarsContainer", "castBar")
        for _, bar in pairs({ health, cast }) do
            if bar.fcui then
                for _, tex in pairs(bar.fcui) do tex:Hide() end
            end
        end
    end
    ns.needsReload = true
end

ns.RegisterModule("namePlates", { apply = Apply, restore = Restore })

local function ColorApply()
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            if plate.UnitFrame then ClassColor(plate.UnitFrame) end
        end
    end
end

local function ColorRestore()
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unitFrame = plate.UnitFrame
        if unitFrame and type(unitFrame.UpdateHealthColor) == "function" then
            pcall(unitFrame.UpdateHealthColor, unitFrame)
        end
    end
end

ns.RegisterModule("classColorPlates", { apply = ColorApply, restore = ColorRestore })

local SIMPLIFIED_CVAR = "nameplateSimplifiedTypes"

local function FullPlatesApply()
    if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return end
    local current = C_CVar.GetCVar(SIMPLIFIED_CVAR)
    local value = tonumber(current)
    if not value or value == 0 then return end
    if ns.db.savedSimplifiedTypes == nil then ns.db.savedSimplifiedTypes = current end
    ns.SetCVar(SIMPLIFIED_CVAR, 0)
end

local function FullPlatesRestore()
    local saved = ns.db.savedSimplifiedTypes
    ns.db.savedSimplifiedTypes = nil
    if tonumber(saved) then ns.SetCVar(SIMPLIFIED_CVAR, saved) end
end

ns.RegisterModule("fullPlates", { apply = FullPlatesApply, restore = FullPlatesRestore })
