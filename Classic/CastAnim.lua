-- EraUI cast animation suppression.
-- The 12.x client plays an animation across an action button's icon while its
-- spell is casting, and lightens the cooldown swipe under it so it shows
-- through. 1.x had neither. The animation frame is taken to nothing and the
-- swipe put back to solid, driven from the cast events rather than a hook on
-- the client's own play of it.
local _, EraUI = ...
local ns = EraUI.Classic

local active = false
local driver

local function Strip(button)
    if not button then return end
    local anim = button.SpellCastAnimFrame
    if anim then anim:SetAlpha(active and 0 or 1) end
    local cooldown = active and button.cooldown
    if cooldown and cooldown.SetSwipeColor then cooldown:SetSwipeColor(0, 0, 0, 1) end
end

local function StripAll()
    if ns.ForEachActionButton then ns.ForEachActionButton(Strip) end
end

local EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED" }

local function Apply()
    active = true
    if not driver then
        driver = CreateFrame("Frame")
        driver:SetScript("OnEvent", function()
            if not active then return end
            StripAll()
            C_Timer.After(0, StripAll)
        end)
        for _, event in ipairs(EVENTS) do
            pcall(driver.RegisterUnitEvent, driver, event, "player")
        end
        driver:RegisterEvent("PLAYER_ENTERING_WORLD")
        driver:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    end
    StripAll()
end

local function Restore()
    active = false
    StripAll()
end

ns.RegisterModule("castAnim", { apply = Apply, restore = Restore })
