-- Crowd-control icons on unit portraits. The client blocks addon aura reads
-- in combat, which is when crowd control happens, so addon code never reads
-- a debuff here:
--  * Target, focus and party use Blizzard's CustomAuraContainer. EraUI only
--    supplies an icon texture and a Cooldown; Blizzard's secure code fills in
--    the icon, sweep, countdown and visibility from the hidden aura data.
--  * The player portrait uses C_LossOfControl, which the client exposes for
--    the player, highest-priority effect first.
-- Native portraits, aura tables and secure unit-frame controls stay Blizzard's.
local _, E = ...
local M = {}; E:RegisterModule("PortraitDebuffs", M)

-- Original Classic crowd-control lists, every rank. On hostile target/focus
-- the client allows matching by spell ID, so one slot per category is stacked
-- with stuns on top; the topmost shown slot is the highest priority without
-- EraUI ever seeing which one is shown. Friendly units only allow the
-- client's own crowd-control category, shown by the bottom "any" slot.
local CATEGORIES = {
    -- Stuns: rogue, druid, paladin, warrior, priest/mage procs, pets and racials.
    { key = "stun", ids = {1833,408,8643,5211,6798,8983,9005,9823,9827,853,5588,5589,10308,
        7922,20253,20614,20615,12809,12798,15269,12355,24394,20549,22703,835} },
    -- Fear, horror, charm and incapacitation.
    { key = "fear", ids = {5782,6213,6215,5484,17928,6789,17925,17926,8122,8124,10888,10890,
        5246,20511,1513,14326,14327,6358,118,12824,12825,12826,28270,28271,28272,
        710,18647,6770,2070,11297,1776,1777,8629,11285,11286,2094,19503,
        19386,24132,24133,2637,18657,18658,3355,14308,14309,20066} },
    -- Silence debuff IDs, not the interrupt cast IDs.
    { key = "silence", ids = {15487,18469,18425,18498,19244,24259} },
    -- Roots: Entangling Roots/Nature's Grasp, Frost Nova/Frostbite and hunter procs.
    { key = "root", ids = {339,1062,5195,5196,9852,9853,19975,19974,19973,19972,19971,19970,
        122,865,6131,10230,12494,19229,19185,13138} },
}
local ANY_CC = "HARMFUL|CROWD_CONTROL"
local states = setmetatable({}, { __mode = "k" }) -- owner frame -> display
local driver, fonts

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end
local function Enabled()
    return E:GetSetting("enabled") and E:GetSetting("unitFrames") and E:GetSetting("portraitDebuffs")
end

local function Fonts()
    if fonts then return fonts end
    local function Font(name, size)
        local font = CreateFont(name)
        font:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
        font:SetTextColor(1, .85, .1)
        return font
    end
    fonts = { large = Font("EraUIPortraitCCLarge", 18), small = Font("EraUIPortraitCCSmall", 12) }
    return fonts
end

-- The dark circular sweep shared by both display kinds.
local function StyleCooldown(cooldown)
    cooldown:SetAllPoints()
    cooldown:EnableMouse(false)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    -- TexPath also returns a fallback path; only the texture may be passed,
    -- because the client reads a second argument as the swipe colour.
    cooldown:SetSwipeTexture((E.Classic.TexPath("portraitMask")))
    cooldown:SetSwipeColor(0, 0, 0, .65)
    cooldown:SetUseCircularEdge(true)
    cooldown.noCooldownCount = true -- Our countdown only, not third-party text.
end

-- A slightly inset area leaves the original portrait rim unobscured.
local function Inset(frame, portrait)
    frame:SetPoint("TOPLEFT", portrait, "TOPLEFT", 1, -1)
    frame:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", -1, 1)
end

-- Player, target and focus portraits carry a level badge on their lower
-- edge. There the icon is cut to the portrait circle joined with the badge
-- circle, so a shown icon covers the whole badge. Party portraits have none.
local BADGE_BOX = 88 -- Unit-frame units; matches Tools/GeneratePortraitCCMasks.mjs.
local function ShapeIcon(icon, parent, badge)
    if not badge then
        icon:SetAllPoints()
        E.Classic.RoundIcon(icon)
        return
    end
    icon:SetPoint("CENTER", parent, "CENTER", 0, 0)
    icon:SetSize(BADGE_BOX, BADGE_BOX)
    icon:SetTexCoord(.06, .94, .06, .94)
    local mask = parent:CreateMaskTexture()
    mask:SetTexture("Interface\\AddOns\\EraUI\\Media\\PortraitCCMask" .. badge .. ".tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
end

-- Target, focus and party ---------------------------------------------------------

local function CreateContainer(owner, portrait, unit, withCategories, small, badge)
    local container = CreateFrame("AuraContainer", nil, portrait:GetParent(), "CustomAuraContainerTemplate")
    container:EnableMouse(false)
    container:SetFrameLevel(owner:GetFrameLevel() + 5)
    Inset(container, portrait)
    container:SetEditModePreviewEnabled(false)
    container:SetUnit(unit)
    local font = small and Fonts().small or Fonts().large
    -- Runs once per slot, before the client restricts the slot in combat.
    -- Everything supplied must be a descendant of the slot button.
    local function Slot(rank)
        return function(button)
            button:SetAllPoints(container)
            button:EnableMouse(false)
            -- Two levels per rank: each slot's sweep and countdown (one level
            -- up) stay below the next higher-priority slot's icon.
            button:SetFrameLevel(container:GetFrameLevel() + rank * 2)
            local icon = button:CreateTexture(nil, "ARTWORK")
            ShapeIcon(icon, button, badge)
            button:SetIcon(icon)
            local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
            StyleCooldown(cooldown)
            cooldown:SetHideCountdownNumbers(false)
            if cooldown.SetCountdownFont then cooldown:SetCountdownFont(font:GetName()) end
            button:SetDurationCooldown(cooldown)
        end
    end
    local slots = #CATEGORIES + 1
    container:AddAuraSlot("any", ANY_CC, { initializeFrame = Slot(1) })
    if withCategories then
        for index, category in ipairs(CATEGORIES) do
            local ids = {}
            for _, id in ipairs(category.ids) do ids[id] = true end
            container:AddAuraSlot(category.key, "HARMFUL", {
                initializeFrame = Slot(slots - index + 1),
                candidateFilters = { includeSpellIDs = ids },
            })
        end
    end
    return { kind = "container", owner = owner, container = container, unit = unit }
end

-- Player -------------------------------------------------------------------------

local function CreatePlayer(owner, portrait)
    local overlay = CreateFrame("Frame", nil, portrait:GetParent())
    overlay:Hide()
    overlay:EnableMouse(false)
    overlay:SetFrameLevel(owner:GetFrameLevel() + 5)
    Inset(overlay, portrait)
    local icon = overlay:CreateTexture(nil, "ARTWORK")
    ShapeIcon(icon, overlay, "Left")
    local cooldown = CreateFrame("Cooldown", nil, overlay, "CooldownFrameTemplate")
    StyleCooldown(cooldown)
    cooldown:SetHideCountdownNumbers(true)
    local label = CreateFrame("Frame", nil, cooldown)
    label:SetAllPoints()
    label:EnableMouse(false)
    label:SetFrameLevel(cooldown:GetFrameLevel() + 1)
    local time = label:CreateFontString(nil, "OVERLAY")
    time:SetPoint("CENTER")
    time:SetFontObject(Fonts().large)
    local state = { kind = "player", owner = owner, overlay = overlay, icon = icon, cooldown = cooldown, time = time }
    overlay:SetScript("OnUpdate", function(_, elapsed)
        state.elapsed = (state.elapsed or 0) + elapsed
        if state.elapsed < .1 then return end
        state.elapsed = 0
        if not state.expiry then return end
        local remaining = state.expiry - GetTime()
        if remaining <= 0 then M:UpdatePlayer(); return end
        local seconds = math.ceil(remaining)
        local text = seconds >= 60 and (math.ceil(seconds / 60) .. "m") or tostring(seconds)
        if state.text ~= text then state.time:SetText(text); state.text = text end
    end)
    return state
end

local function Number(value)
    return Public(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Loss-of-control entries are public for the player; index 1 is the client's
-- highest-priority active effect.
function M:UpdatePlayer()
    local state = PlayerFrame and states[PlayerFrame]
    if not state or state.kind ~= "player" then return end
    local data
    if Enabled() and C_LossOfControl and C_LossOfControl.GetActiveLossOfControlData then
        local ok, result = pcall(C_LossOfControl.GetActiveLossOfControlData, 1)
        if ok and Public(result) and type(result) == "table" then data = result end
    end
    local icon = data and data.iconTexture
    if not data or not Public(icon) or not icon then
        state.expiry, state.text = nil, nil
        state.overlay:Hide()
        return
    end
    state.icon:SetTexture(icon)
    local start, duration = data.startTime, data.duration
    if Number(start) and Number(duration) and duration > 0 then
        state.cooldown:SetCooldown(start, duration)
        state.expiry = start + duration
    else
        -- Effects without a known end show the icon without a countdown.
        state.cooldown:Clear()
        state.expiry = nil
        state.time:SetText("")
    end
    state.text = nil
    state.overlay:Show()
end

-- Setup ---------------------------------------------------------------------------

-- Only when the setting actually changes, and containers never in combat:
-- group and zone events refresh often, and a no-op call is still a call.
local function Show(state, shown)
    if state.kind == "failed" or state.applied == shown then return end
    if state.kind == "container" then
        if InCombatLockdown() then M.pending = true; return end
        state.container:SetEnabled(shown)
        state.container:SetShown(shown)
    elseif not shown then
        state.expiry, state.text = nil, nil
        state.overlay:Hide()
    end
    state.applied = shown
end

local function Visit(owner, portrait, unit, kind)
    if not owner or not portrait or not unit then return end
    local state = states[owner]
    if not state then
        -- Blizzard's secure aura container is what makes in-combat display
        -- possible; without it there is no permitted path.
        if kind ~= "player" and not CustomAuraContainerSlotDefaultOptions then return end
        -- Displays are created out of combat; the containers then update
        -- themselves, in combat too.
        if InCombatLockdown() then M.pending = true; return end
        local ok, result
        if kind == "player" then ok, result = pcall(CreatePlayer, owner, portrait)
        else
            local hostile = kind == "hostile"
            ok, result = pcall(CreateContainer, owner, portrait, unit, hostile, kind == "party", hostile and "Right" or nil)
        end
        -- A failed build is reported once per session and not retried on every event.
        state = ok and result or { kind = "failed", error = tostring(result) }
        if not ok then
            if not M.lastError then E:Print("Portrait crowd-control could not start: " .. state.error) end
            M.lastError = state.error
        end
        states[owner] = state
    elseif state.kind == "container" and state.unit ~= unit then
        state.unit = unit
        state.container:SetUnit(unit)
    end
    return state
end

function M:Refresh()
    local enabled = Enabled() and true or false
    if enabled then
        local player = PlayerFrame and PlayerFrame.PlayerFrameContainer
        Visit(PlayerFrame, player and player.PlayerPortrait, "player", "player")
        for _, owner in ipairs({ TargetFrame, FocusFrame }) do
            local container = owner and owner.TargetFrameContainer
            Visit(owner, container and container.Portrait, owner == TargetFrame and "target" or "focus", "hostile")
        end
        local pool = PartyFrame and PartyFrame.PartyMemberFramePool
        if pool then
            for owner in pool:EnumerateActive() do
                local unit = owner.unit
                if Public(unit) and type(unit) == "string" then Visit(owner, owner.Portrait, unit, "party") end
            end
        end
    end
    for _, state in pairs(states) do Show(state, enabled) end
    if enabled then self:UpdatePlayer() end
end

local function RefreshUnit(owner)
    local state = owner and states[owner]
    if state and state.kind == "container" and Enabled() then state.container:UpdateAllAuras() end
end

function M:Initialize()
    driver = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
        "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE" }) do
        pcall(driver.RegisterEvent, driver, event)
    end
    driver:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_TARGET_CHANGED" then RefreshUnit(TargetFrame)
        elseif event == "PLAYER_FOCUS_CHANGED" then RefreshUnit(FocusFrame)
        elseif event == "LOSS_OF_CONTROL_ADDED" or event == "LOSS_OF_CONTROL_UPDATE" then M:UpdatePlayer()
        elseif event == "PLAYER_REGEN_ENABLED" then
            if M.pending then M.pending = false; M:Refresh() end
        else M:Refresh() end
    end)
    self:Refresh()
end
