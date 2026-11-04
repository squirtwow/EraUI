-- The player's cast bar clear of the bars: while it sits in its default
-- place, its bottom goes 26 units above the highest of the band and the bars
-- in the middle of the screen. Placement happens in the same call as the
-- game's own layout (post-hooks and events, no polling), so a cast never
-- shows at the game's height first.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Number = Look.Number
local band = Look.band

local CLEARANCE, REACH, CEILING = 26, 110, 260
local placing = false

local function Visible(frame)
    if not frame or not frame.IsShown or not frame:IsShown() then return false end
    local alpha = Number(frame:GetAlpha())
    return alpha ~= nil and alpha > 0
end

-- A frame's span (left, right, top) in UIParent units, or nil. A bar with
-- action buttons spans its first to its last shown button.
local function Seen(button)
    if button.IsVisible then return button:IsVisible() and true or false end
    return button.IsShown ~= nil and button:IsShown() and true or false
end

local function Span(frame, parentScale)
    local list = frame.actionButtons
    local first, last
    if type(list) == "table" then
        for _, button in ipairs(list) do
            if Seen(button) then
                first = first or button
                last = button
            end
        end
    end
    local top, left, right
    if first then
        top = Number(first:GetTop())
        for _, button in ipairs(list) do
            if Seen(button) then
                local t = Number(button:GetTop())
                if not t then return nil end
                if top and t > top then top = t end
            end
        end
        left, right = Number(first:GetLeft()), Number(last:GetRight())
        frame = first
    else
        top, left, right = Number(frame:GetTop()), Number(frame:GetLeft()), Number(frame:GetRight())
    end
    if not (top and left and right) then return nil end
    local scale = Number(frame:GetEffectiveScale())
    if not scale or scale <= 0 then return nil end
    local f = scale / parentScale
    return left * f, right * f, top * f
end

-- The highest top among the band and the bars near the screen's middle.
local function HighestTop()
    local parentScale = Number(UIParent:GetEffectiveScale())
    local width = Number(UIParent:GetWidth())
    if not parentScale or parentScale <= 0 or not width then return nil end
    local centre = width / 2
    local best
    -- The shaman's totem bar too (pinned over the band's small row,
    -- Look/BandPins.lua): it only reaches the middle with One Bar on.
    local frames = { band.frame or false, MultiBarBottomLeft or false, MultiBarBottomRight or false,
        StanceBar or false, PetActionBar or false, PossessActionBar or false,
        MainStatusTrackingBarContainer or false, SecondaryStatusTrackingBarContainer or false,
        MultiCastActionBarFrame or false }
    for i, frame in ipairs(frames) do
        local counts = frame and Visible(frame)
        if counts and i > 1 then
            counts = not frame.isDragging and not Look.Moved(frame)
        end
        if counts then
            local left, right, top = Span(frame, parentScale)
            if left and right >= centre - REACH and left <= centre + REACH and top < CEILING then
                if not best or top > best then best = top end
            end
        end
    end
    return best
end

local function Allowed(bar)
    if not band.active or not Look.Enabled() then return false end
    if EraUI:GetSetting("advancedCastBar") then return false end
    if not bar:IsShown() or bar.isDragging or bar.isInEditMode then return false end
    if Look.EditModeOpen() then return false end
    local ok, attached = Look.Ask(bar, "IsAttachedToPlayerFrame")
    if ok and attached == true then return false end
    if Look.InFight() and bar.IsProtected and bar:IsProtected() then return false end
    local fine, default = pcall(bar.IsInDefaultPosition, bar)
    return fine and not Look.Secret(default) and default == true
end

function Look.PlaceCastBar()
    local bar = PlayerCastingBarFrame
    if placing or not bar or not Allowed(bar) then return end
    local top = HighestTop()
    if not top then return end
    local barScale, parentScale = Number(bar:GetEffectiveScale()), Number(UIParent:GetEffectiveScale())
    if not barScale or not parentScale or barScale <= 0 or parentScale <= 0 then return end
    local y = (top + CLEARANCE) / (barScale / parentScale)
    local bottom = Number(bar:GetBottom())
    if bottom and math.abs(bottom - y) <= 1 then return end
    placing = true
    Look.ClearPoints(bar)
    Look.AddPoint(bar, "BOTTOM", UIParent, "BOTTOM", 0, y)
    placing = false
end

-- The game's managed layout container the cast bar sits in, looked for
-- again on every show (the game may replace it).
local function HookLayout(bar)
    local container = bar.layoutParent and bar.layoutParent.BottomManagedLayoutContainer
    if not container and bar.GetParent then container = bar:GetParent() end
    if container then Look.Hook(container, "Layout", Look.PlaceCastBar) end
end

local function HookBar()
    local bar = PlayerCastingBarFrame
    if not bar then return end
    Look.HookScript(bar, "OnShow", function(self)
        HookLayout(self)
        Look.PlaceCastBar()
    end)
    Look.Hook(bar, "ApplySystemAnchor", Look.PlaceCastBar)
    Look.Hook(bar, "UpdateSystemSettingBarSize", Look.PlaceCastBar)
    HookLayout(bar)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ADDON_LOADED", "PLAYER_REGEN_ENABLED", "UI_SCALE_CHANGED",
    "DISPLAY_SIZE_CHANGED", "PET_BAR_UPDATE", "UPDATE_SHAPESHIFT_FORMS", "UPDATE_BONUS_ACTIONBAR",
    "UPDATE_OVERRIDE_ACTIONBAR" }) do
    Look.Listen(events, event)
end
events:SetScript("OnEvent", function()
    HookBar()
    Look.PlaceCastBar()
end)
