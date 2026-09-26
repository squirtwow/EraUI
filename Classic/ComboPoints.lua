-- EraUI combo points.
-- Combo points where 1.x kept them: five small orbs curving down the right
-- side of the target's portrait, lit one by one with the old glint on each
-- new one. Where the client still has its own ComboFrame it is re-laid to the
-- 1.13 shape instead of drawing a second set; only a client without it gets
-- orbs of our own.
local _, EraUI = ...
local ns = EraUI.Classic

local POINTS = 5
local RADIUS = 39
local ANGLES = { 50, 32, 14, -4, -22 }
local function OrbCentre(index)
    local a = math.rad(ANGLES[index])
    return RADIUS * math.cos(a), RADIUS * math.sin(a)
end
local SHEET = "comboPoint"

local active = false
local frame
local lastPoints = 0
local lastMax = 0

local function Ring()
    return ns.Path(TargetFrame, "TargetFrameContainer", "Portrait") or TargetFrame
end

local function PinOrb(orb, index)
    local x, y = OrbCentre(index)
    orb:ClearAllPoints()
    orb:SetPoint("CENTER", Ring(), "CENTER", x, y)
end

local function LayoutBlizzard()
    local cf = ComboFrame
    if not cf or not active or EraUI:GetSetting("floatingComboPoints") then return end
    if InCombatLockdown() then return end
    cf:ClearAllPoints()
    cf:SetPoint("CENTER", Ring(), "CENTER", 0, 0)
    local first = cf.startComboPointIndex or 2
    for i, point in ipairs(cf.ComboPoints or {}) do
        local slot = i - first + 1
        if slot >= 1 and slot <= POINTS then
            PinOrb(point, slot)
            point:SetAlpha(1)
        else
            point:ClearAllPoints()
            point:SetPoint("CENTER", cf, "CENTER", 0, 0)
            point:SetAlpha(0)
        end
    end
end

local blizzardHooked = false
local function HookBlizzard()
    if blizzardHooked or not ComboFrame then return end
    blizzardHooked = true
    if ComboFrame_ApplyOverrides then hooksecurefunc("ComboFrame_ApplyOverrides", LayoutBlizzard) end
    if ComboFrame_UpdateMax then hooksecurefunc("ComboFrame_UpdateMax", LayoutBlizzard) end
    ComboFrame:HookScript("OnShow", LayoutBlizzard)
end

local function Orb(parent, index)
    local orb = CreateFrame("Frame", nil, parent)
    orb:SetSize(12, 12)
    orb.index = index
    local base = orb:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(base, SHEET)
    base:SetSize(12, 16)
    base:SetPoint("TOPLEFT", orb, "TOPLEFT", 0, 0)
    base:SetTexCoord(0, 0.375, 0, 1)
    local lit = orb:CreateTexture(nil, "ARTWORK")
    ns.SetTex(lit, SHEET)
    lit:SetSize(8, 16)
    lit:SetPoint("TOPLEFT", orb, "TOPLEFT", 2, 0)
    lit:SetTexCoord(0.375, 0.5625, 0, 1)
    lit:SetAlpha(0)
    local shine = orb:CreateTexture(nil, "OVERLAY")
    ns.SetTex(shine, SHEET)
    shine:SetSize(14, 16)
    shine:SetPoint("TOPLEFT", orb, "TOPLEFT", 0, 4)
    shine:SetTexCoord(0.5625, 1, 0, 1)
    shine:SetBlendMode("ADD")
    shine:SetAlpha(0)
    orb.lit, orb.shine = lit, shine
    return orb
end

local function Glint(orb)
    UIFrameFadeIn(orb.lit, 0.4, orb.lit:GetAlpha(), 1)
    UIFrameFade(orb.shine, {
        mode = "IN", timeToFade = 0.3, startAlpha = 0, endAlpha = 1,
        finishedFunc = function() UIFrameFadeOut(orb.shine, 0.4, 1, 0) end,
    })
end

local function Number(value)
    if value == nil or (issecretvalue and issecretvalue(value)) then return nil end
    return value
end

local function Update()
    if not frame or not active then return end
    local max = Number(UnitPowerMax("player", Enum.PowerType.ComboPoints))
    local points = Number(UnitPower("player", Enum.PowerType.ComboPoints))
    if max then lastMax = max end
    -- A secret read is "unknown", not zero: keep the last known count so the
    -- orbs do not vanish for the whole fight while the client hides the value.
    local shownMax = max or lastMax
    local shownPoints = points or lastPoints
    if shownMax <= 0 or shownPoints <= 0 or not UnitExists("target") or not UnitCanAttack("player", "target") then
        frame:Hide()
        for i = 1, POINTS do
            frame.orbs[i].lit:SetAlpha(0)
            frame.orbs[i].shine:SetAlpha(0)
        end
        lastPoints = 0
        lastMax = 0
        return
    end
    if not frame:IsShown() then
        frame:Show()
        UIFrameFadeIn(frame, 0.3, 0, 1)
    end
    for i = 1, POINTS do
        local orb = frame.orbs[i]
        orb:SetShown(i <= shownMax)
        if i <= shownPoints then
            if i > lastPoints then Glint(orb) end
        else
            orb.lit:SetAlpha(0)
            orb.shine:SetAlpha(0)
        end
    end
    lastPoints = shownPoints
end

local function Build()
    frame = CreateFrame("Frame", nil, TargetFrame)
    frame:SetSize(64, 64)
    frame:SetPoint("CENTER", Ring(), "CENTER", 0, 0)
    frame:SetFrameLevel(TargetFrame:GetFrameLevel() + 5)
    frame.orbs = {}
    for i = 1, POINTS do
        frame.orbs[i] = Orb(frame, i)
        PinOrb(frame.orbs[i], i)
    end
    frame:Hide()
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    frame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    frame:SetScript("OnEvent", Update)
end

local function RetailFrames()
    return { ComboPointPlayerFrame, DruidComboPointBarFrame }
end

local function Apply()
    active = true
    if EraUI:GetSetting("floatingComboPoints") then ns.StartFloatingCombo(); return end
    if not TargetFrame then ns.MissingPiece("TargetFrame") return end
    for _, retail in pairs(RetailFrames()) do ns.Fade(retail) end
    if ComboFrame then
        HookBlizzard()
        LayoutBlizzard()
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() else for i, orb in ipairs(frame.orbs) do PinOrb(orb, i) end end
    Update()
end

local function Restore()
    active = false
    if ns.StopFloatingCombo then ns.StopFloatingCombo() end
    if frame then frame:Hide() end
    for _, retail in pairs(RetailFrames()) do ns.Unfade(retail) end
    if ComboFrame then ns.needsReload = true end
end

ns.RegisterModule("comboPoints", { apply = Apply, restore = Restore })
