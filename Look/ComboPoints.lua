-- Combo points round the target portrait (Classic look, "comboPoints"; on with
-- Unit Frames, and forced on while Floating Combo Points is on, which then
-- takes over). The modern displays under the player frame are hidden.
--
-- Forever has its own ComboFrame: five points numbered from 1 that it lays in
-- the 1.x arc itself on every update. EraUI only gives them their alpha back
-- (Floating Combo Points mutes them while it runs). An older ComboFrame,
-- numbered from startComboPointIndex, is laid on EraUI's arc. A client with
-- none at all gets EraUI's own five orbs.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local combo = { active = false, hooked = false }
Look.combo = combo

local ARC = { 50, 32, 14, -4, -22 } -- degrees, top to bottom down the portrait's right side
local REACH = 39

local function Floating()
    return EraUI:GetSetting("floatingComboPoints") and true or false
end

-- The circle the points go round: the target's portrait, or the frame.
local function Ring()
    return Look.Path(TargetFrame, "TargetFrameContainer", "Portrait") or TargetFrame
end

local function Spot(slot)
    local angle = math.rad(ARC[slot])
    return REACH * math.cos(angle), REACH * math.sin(angle)
end

---------------------------------------------------------------------------
-- The game's ComboFrame
---------------------------------------------------------------------------

local function Relay()
    local frame = ComboFrame
    if not frame or not combo.active or Floating() then return end
    local points = frame.ComboPoints
    if type(points) ~= "table" then return end
    if type(frame.LayoutPointsCircle) == "function" then
        -- Forever's: its own arc, every point shown.
        for _, point in ipairs(points) do Look.Alpha(point, 1) end
        return
    end
    if Look.InFight() then return end
    local ring = Ring()
    local first = Look.Number(frame.startComboPointIndex) or 2
    Look.Pin(frame, "CENTER", ring, "CENTER", 0, 0)
    for i, point in ipairs(points) do
        local slot = i - first + 1
        if slot >= 1 and slot <= #ARC then
            local x, y = Spot(slot)
            Look.Pin(point, "CENTER", ring, "CENTER", x, y)
            Look.Alpha(point, 1)
        else
            Look.Pin(point, "CENTER", frame, "CENTER", 0, 0)
            Look.Alpha(point, 0)
        end
    end
end
combo.Relay = Relay

local function HookComboFrame()
    if combo.hooked then return end
    combo.hooked = true
    for _, called in ipairs(Look.Words("ComboFrame_ApplyOverrides ComboFrame_UpdateMax")) do
        if type(_G[called]) == "function" then Look.HookGlobal(called, Relay) end
    end
end

---------------------------------------------------------------------------
-- EraUI's own orbs (a client without ComboFrame)
---------------------------------------------------------------------------

local ORB_PIECES = {
    { "socket", "BACKGROUND", 12, 16, 0, 0, { 0, 0.375, 0, 1 }, 1 },
    { "lit", "ARTWORK", 8, 16, 2, 0, { 0.375, 0.5625, 0, 1 }, 0 },
    { "shine", "OVERLAY", 14, 16, 0, 4, { 0.5625, 1, 0, 1 }, 0 },
}

local function Fade(texture, seconds, from, to)
    if type(UIFrameFade) == "function" then
        UIFrameFade(texture, { mode = to > from and "IN" or "OUT", timeToFade = seconds, startAlpha = from, endAlpha = to })
    else
        texture:SetAlpha(to)
    end
end

-- A point just earned: the orb brightens and its shine flashes.
local function Glint(orb)
    local from = Look.Number(orb.lit:GetAlpha()) or 0
    if type(UIFrameFadeIn) == "function" then UIFrameFadeIn(orb.lit, 0.4, from, 1) else orb.lit:SetAlpha(1) end
    local shine = orb.shine
    if type(UIFrameFade) == "function" then
        UIFrameFade(shine, { mode = "IN", timeToFade = 0.3, startAlpha = 0, endAlpha = 1,
            finishedFunc = function() Fade(shine, 0.4, 1, 0) end })
    else
        shine:SetAlpha(0)
    end
end

local function Unlit(orb)
    orb.lit:SetAlpha(0)
    orb.shine:SetAlpha(0)
end

-- A hidden value (a fight) is "unknown", not zero: the last known one stands,
-- so the orbs don't vanish for a whole fight while the client hides the count.
function combo.Update()
    local own = combo.orbs
    if not own then return end
    local kind = Enum and Enum.PowerType and Enum.PowerType.ComboPoints
    local most, count = Look.Number(UnitPowerMax("player", kind)), Look.Number(UnitPower("player", kind))
    if most then combo.most = most end
    most, count = most or combo.most or 0, count or combo.shown or 0
    local there, hostile = UnitExists("target"), UnitCanAttack("player", "target")
    if Look.Secret(there) then there = true end
    if Look.Secret(hostile) then hostile = true end
    if most <= 0 or count <= 0 or not there or not hostile then
        own.frame:Hide()
        for _, orb in ipairs(own) do Unlit(orb) end
        combo.shown, combo.most = nil, nil
        return
    end
    if not own.frame:IsShown() then
        own.frame:Show()
        if type(UIFrameFadeIn) == "function" then UIFrameFadeIn(own.frame, 0.3, 0, 1) end
    end
    for i, orb in ipairs(own) do
        orb.holder:SetShown(i <= most)
        if i <= count then
            if i > (combo.shown or 0) then Glint(orb) end
        else
            Unlit(orb)
        end
    end
    combo.shown = count
end

local function PinOrbs()
    local own, ring = combo.orbs, Ring()
    Look.Pin(own.frame, "CENTER", ring, "CENTER", 0, 0)
    own.frame:SetFrameLevel((Look.Number(TargetFrame:GetFrameLevel()) or 0) + 5)
    for slot, orb in ipairs(own) do
        local x, y = Spot(slot)
        Look.Pin(orb.holder, "CENTER", ring, "CENTER", x, y)
    end
end

local function BuildOrbs()
    if combo.orbs then return end
    local frame = Look.Build("Frame", TargetFrame, nil, { size = { 64, 64 }, hidden = true })
    local own = { frame = frame }
    for slot = 1, #ARC do
        local holder = Look.Build("Frame", frame, nil, { size = { 12, 12 } })
        local orb = { holder = holder }
        for _, piece in ipairs(ORB_PIECES) do
            local texture = holder:CreateTexture(nil, piece[2])
            Look.Art(texture, "comboPoint")
            texture:SetSize(piece[3], piece[4])
            Look.Pin(texture, "TOPLEFT", holder, "TOPLEFT", piece[5], piece[6])
            texture:SetTexCoord(piece[7][1], piece[7][2], piece[7][3], piece[7][4])
            texture:SetAlpha(piece[8])
            if piece[1] == "shine" then texture:SetBlendMode("ADD") end
            orb[piece[1]] = texture
        end
        own[slot] = orb
    end
    combo.orbs = own
    for _, event in ipairs(Look.Words("PLAYER_TARGET_CHANGED PLAYER_ENTERING_WORLD UPDATE_SHAPESHIFT_FORM")) do
        Look.Listen(frame, event)
    end
    for _, event in ipairs(Look.Words("UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER")) do
        Look.Listen(frame, event, "player")
    end
    frame:SetScript("OnEvent", function()
        if combo.active then combo.Update() end
    end)
end

---------------------------------------------------------------------------
-- The registry entry
---------------------------------------------------------------------------

local function Apply()
    combo.active = true
    if Floating() then
        if type(ns.StartFloatingCombo) == "function" then ns.StartFloatingCombo() end
        return
    end
    if not TargetFrame then
        Look.MissingPiece("TargetFrame")
        return
    end
    Look.Fade(ComboPointPlayerFrame)
    Look.Fade(DruidComboPointBarFrame)
    if ComboFrame then
        HookComboFrame()
        Look.HookScript(ComboFrame, "OnShow", Relay)
        Relay()
        if combo.orbs then combo.orbs.frame:Hide() end
        return
    end
    BuildOrbs()
    PinOrbs()
    combo.Update()
end

local function Restore()
    combo.active = false
    if type(ns.StopFloatingCombo) == "function" then ns.StopFloatingCombo() end
    if combo.orbs then combo.orbs.frame:Hide() end
    Look.Alpha(ComboPointPlayerFrame, 1)
    Look.Alpha(DruidComboPointBarFrame, 1)
    if ComboFrame then ns.needsReload = true end
end

ns.RegisterModule("comboPoints", { apply = Apply, restore = Restore })
