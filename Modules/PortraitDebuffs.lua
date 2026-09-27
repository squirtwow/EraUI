-- Cosmetic overlays only. Native portraits, aura tables and secure unit-frame
-- controls stay owned by Blizzard. The spell list is an original Classic CC list.
local _, E = ...
local M = {}; E:RegisterModule("PortraitDebuffs", M)
local states = {}
local units = { player=true, target=true, focus=true, party1=true, party2=true, party3=true, party4=true }
local priorities = {}
local function Add(priority, ids)
    for _, id in ipairs(ids) do priorities[id] = priority end
end
-- Stuns: rogue, druid, paladin, warrior, priest/mage procs, pets and racials.
Add(4, {1833,408,8643,5211,6798,8983,9005,9823,9827,853,5588,5589,10308,
    7922,20253,20614,20615,12809,12798,15269,12355,24394,20549,22703,835})
-- Fear, horror, charm and incapacitation, including every Classic spell rank.
Add(3, {5782,6213,6215,5484,17928,6789,17925,17926,8122,8124,10888,10890,
    5246,20511,1513,14326,14327,6358,118,12824,12825,12826,28270,28271,28272,
    710,18647,6770,2070,11297,1776,1777,8629,11285,11286,2094,19503,
    19386,24132,24133,2637,18657,18658,3355,14308,14309,20066})
-- Silence debuff IDs, not the interrupt cast IDs.
Add(2, {15487,18469,18425,18498,19244,24259})
-- Roots: Entangling Roots/Nature's Grasp, Frost Nova/Frostbite and hunter procs.
Add(1, {339,1062,5195,5196,9852,9853,19975,19974,19973,19972,19971,19970,
    122,865,6131,10230,12494,19229,19185,13138})

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end
local function Number(value)
    return Public(value) and type(value)=="number" and value==value and value>-math.huge and value<math.huge
end
local function Enabled()
    return E:GetSetting("enabled") and E:GetSetting("unitFrames") and E:GetSetting("portraitDebuffs")
end
local function Unit(state)
    local unit = state.fixedUnit or state.owner.unit
    if Public(unit) and type(unit)=="string" and units[unit] then return unit end
end
local function Clear(state)
    state.aura, state.unit = nil, nil
    state.overlay:Hide()
end
local function SelectAura(unit)
    local api = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not api then return end
    -- Avoid making restricted aura queries in the first place when this client
    -- exposes its secret-aura policy. Older clients still use the guarded read.
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, restricted = pcall(C_Secrets.ShouldAurasBeSecret)
        if not ok or not Public(restricted) or restricted then return end
    end
    local now, best, score = GetTime(), nil, 0
    for index=1,255 do
        local ok, aura = pcall(api, unit, index, "HARMFUL")
        if not ok or not Public(aura) then return end
        if not aura then return best end
        if type(aura)~="table" or not Public(aura.spellId) then return end
        local priority = priorities[aura.spellId]
        if priority then
            local duration, expiry, icon = aura.duration, aura.expirationTime, aura.icon
            if not Number(duration) or not Number(expiry) or not Public(icon) then return end
            if duration>0 and expiry>now and (type(icon)=="number" or type(icon)=="string") then
                if priority>score or priority==score and (expiry>best.expiry or expiry==best.expiry and aura.spellId<best.id) then
                    -- Copy only the public display fields. Never annotate native aura data.
                    best = {id=aura.spellId, icon=icon, duration=duration, expiry=expiry}
                    score = priority
                end
            end
        end
    end
    -- An incomplete scan cannot establish the highest-priority effect.
end
local Update
local function Countdown(state)
    if not state.aura then return end
    local remaining = math.max(0, math.ceil(state.aura.expiry-GetTime()))
    local text = remaining>=60 and (math.ceil(remaining/60).."m") or tostring(remaining)
    if state.text~=text then state.overlay.time:SetText(text); state.text=text end
end
local function Create(owner, portrait, fixedUnit)
    if InCombatLockdown() then return end
    local overlay = CreateFrame("Frame", nil, portrait:GetParent())
    overlay:Hide(); overlay:EnableMouse(false)
    overlay:SetFrameLevel(owner:GetFrameLevel()+5)
    -- A slight inset leaves the original portrait rim unobscured.
    overlay:SetPoint("TOPLEFT", portrait, "TOPLEFT", 1, -1)
    overlay:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", -1, 1)
    local icon = overlay:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(); E.Classic.RoundIcon(icon)
    local cooldown = CreateFrame("Cooldown", nil, overlay, "CooldownFrameTemplate")
    cooldown:SetAllPoints(); cooldown:EnableMouse(false)
    cooldown:SetDrawEdge(false); cooldown:SetDrawBling(false)
    cooldown:SetSwipeTexture(E.Classic.TexPath("portraitMask"))
    cooldown:SetSwipeColor(0, 0, 0, .65)
    cooldown:SetUseCircularEdge(true); cooldown:SetHideCountdownNumbers(true)
    -- Our one countdown scales to party portraits, independently of global
    -- action-button countdown settings or third-party cooldown text.
    cooldown.noCooldownCount = true
    local label = CreateFrame("Frame", nil, cooldown)
    label:SetAllPoints(); label:EnableMouse(false)
    label:SetFrameLevel(cooldown:GetFrameLevel()+1)
    local time = label:CreateFontString(nil, "OVERLAY")
    time:SetPoint("CENTER"); time:SetTextColor(1, .85, .1)
    time:SetFont(STANDARD_TEXT_FONT, 22, "OUTLINE")
    overlay.icon, overlay.cooldown, overlay.time = icon, cooldown, time
    local state = {owner=owner, portrait=portrait, fixedUnit=fixedUnit, overlay=overlay}
    states[owner] = state
    overlay:SetScript("OnSizeChanged", function(_, width)
        if Number(width) and width>0 then time:SetFont(STANDARD_TEXT_FONT, math.max(12, math.min(32, width*.47)), "OUTLINE") end
    end)
    overlay:SetScript("OnUpdate", function(_, elapsed)
        state.elapsed = (state.elapsed or 0)+elapsed
        if state.elapsed<.1 then return end
        state.elapsed = 0
        if not Enabled() or Unit(state)~=state.unit then Clear(state); return end
        if state.aura and state.aura.expiry<=GetTime() then Update(state) else Countdown(state) end
    end)
    owner:HookScript("OnShow", function() M:Refresh() end)
    owner:HookScript("OnHide", function() Clear(state) end)
    return state
end
Update = function(state)
    local unit = Unit(state)
    if not Enabled() or not unit or not state.owner:IsShown() or not state.portrait:IsShown() then Clear(state); return end
    local exists = UnitExists(unit)
    if not Public(exists) or not exists then Clear(state); return end
    local aura = SelectAura(unit)
    if not aura then Clear(state); return end
    local old = state.aura
    state.unit, state.aura = unit, aura
    if not old or old.id~=aura.id or old.icon~=aura.icon or old.duration~=aura.duration or old.expiry~=aura.expiry then
        state.overlay.icon:SetTexture(aura.icon)
        state.overlay.cooldown:SetCooldown(aura.expiry-aura.duration, aura.duration)
    end
    Countdown(state); state.overlay:Show()
end
function M:Refresh()
    if not Enabled() then for _, state in pairs(states) do Clear(state) end; return end
    local seen = {}
    local function Visit(owner, portrait, unit)
        if not owner or not portrait then return end
        local state = states[owner] or Create(owner, portrait, unit)
        if state then seen[owner]=true; Update(state) end
    end
    local player = PlayerFrame and PlayerFrame.PlayerFrameContainer
    Visit(PlayerFrame, player and player.PlayerPortrait, "player")
    Visit(TargetFrame, TargetFrame and TargetFrame.TargetFrameContainer and TargetFrame.TargetFrameContainer.Portrait, "target")
    Visit(FocusFrame, FocusFrame and FocusFrame.TargetFrameContainer and FocusFrame.TargetFrameContainer.Portrait, "focus")
    local pool = PartyFrame and PartyFrame.PartyMemberFramePool
    if pool then for owner in pool:EnumerateActive() do Visit(owner, owner.Portrait) end end
    for owner, state in pairs(states) do if not seen[owner] then Clear(state) end end
end
function M:Initialize()
    local driver = CreateFrame("Frame")
    for _, event in ipairs({"UNIT_AURA", "UNIT_PORTRAIT_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED",
        "PLAYER_FOCUS_CHANGED", "GROUP_ROSTER_UPDATE", "ADDON_LOADED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do
        driver:RegisterEvent(event)
    end
    driver:SetScript("OnEvent", function(_, event, unit)
        if event=="UNIT_AURA" or event=="UNIT_PORTRAIT_UPDATE" then
            if not Public(unit) or type(unit)~="string" then return end
            for _, state in pairs(states) do
                local current = Unit(state)
                if current~=state.unit then Clear(state) end
                local same = current and (current==unit or UnitIsUnit(current, unit))
                if Public(same) and same then Update(state) end
            end
        else self:Refresh() end
    end)
    self:Refresh()
end
