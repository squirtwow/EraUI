-- No cast animation on buttons (Classic/CastAnim.lua) against a mock of the
-- game's action buttons, modelled on Forever's Blizzard_ActionBar
-- (Shared/ActionButton.lua): a cast or channel starting clears the button's
-- cooldown swipe and plays the cast animation over the icon; when it ends
-- (UNIT_SPELLCAST_SUCCEEDED, UNIT_SPELLCAST_CHANNEL_STOP) the animation
-- finishes with a 0.5 s burst, and as it hides it sets the swipe again. Since
-- build 70425 that swipe is Forever's lighter 0.64
-- (Camelot/ActionButtonOverrides.lua GetCooldownFrameAlpha), so with the
-- option on EraUI strips once more 0.6 s after the end, and again at 1 s for
-- a slow frame or a hitch that lands the burst's end after the first: the
-- swipe stays solid after a channel, a cast and an interrupted cast. Off, the
-- game's own swipe and animation are left as the game sets them. No key on
-- the buttons.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

-- Time and timers -----------------------------------------------------------------
local now, timers = 0, {}
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end }
-- Runs every timer due by now + dt, in order (one a timer books runs too
-- when it falls due in that span); a delay of 0 is the next frame.
local function Advance(dt)
    local target = now + dt
    while true do
        local best
        for i, t in ipairs(timers) do
            if t.at <= target and (not best or t.at < timers[best].at) then best = i end
        end
        if not best then break end
        local t = table.remove(timers, best)
        now = math.max(now, t.at)
        t.fn()
    end
    now = target
end
local function Late()
    local n = 0
    for _, t in ipairs(timers) do if not t.game and t.at - now >= 0.5 then n = n + 1 end end
    return n
end

-- The game's buttons ---------------------------------------------------------------
local writes = {}
local function Sealed(state)
    return setmetatable(state, { __newindex = function(_, key) writes[#writes + 1] = tostring(key) end })
end
local GAME_SWIPE = 0.64
local buttons = {}
for i = 1, 3 do
    local cooldown = Sealed({ swipe = 1 })
    rawset(cooldown, "SetSwipeColor", function(self, _, _, _, a) rawset(self, "swipe", a) end)
    local anim = Sealed({ alpha = 1, shown = false })
    rawset(anim, "SetAlpha", function(self, a) rawset(self, "alpha", a) end)
    buttons[i] = Sealed({})
    rawset(buttons[i], "cooldown", cooldown)
    rawset(buttons[i], "SpellCastAnimFrame", anim)
end
local casting = buttons[1] -- the button whose spell is cast
local burst = 0.5 -- when the end burst hides (later in a hitch)
-- The game's own handlers on the button (they run before EraUI's driver).
local function AnimHide(button)
    local anim = button.SpellCastAnimFrame
    if not anim.shown then return end
    rawset(anim, "shown", false)
    button.cooldown:SetSwipeColor(0, 0, 0, GAME_SWIPE) -- ActionButtonCastingAnimFrameMixin:OnHide
end
local function Game(event)
    local anim = casting.SpellCastAnimFrame
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        casting.cooldown:SetSwipeColor(0, 0, 0, 0) -- PlaySpellCastAnim
        rawset(anim, "shown", true)
        rawset(anim, "playing", true)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if anim.playing then -- FinishAnimAndPlayBurst: hidden when the 0.5 s burst ends
            rawset(anim, "playing", false)
            timers[#timers + 1] = { at = now + burst, fn = function() AnimHide(casting) end, game = true }
        end
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if anim.playing then -- a forced stop: hidden at once
            rawset(anim, "playing", false)
            AnimHide(casting)
        end
    end
end

-- EraUI -----------------------------------------------------------------------------
local driver
CreateFrame = function()
    local f = { scripts = {}, events = {} }
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:RegisterUnitEvent(event) self.events[event] = true end
    function f:RegisterEvent(event) self.events[event] = true end
    driver = f
    return f
end
local ns, modules = {}, {}
ns.RegisterModule = function(key, mod) modules[key] = mod end
ns.ForEachActionButton = function(fn) for _, b in ipairs(buttons) do fn(b) end end
assert(loadfile("Classic/CastAnim.lua"))("EraUI", { Classic = ns })
local module = modules.castAnim
local function Fire(event)
    Game(event)
    if driver and driver.events[event] then driver.scripts.OnEvent(driver, event, "player") end
end
local function Swipe() return casting.cooldown.swipe end

-- 1. On: a channel ends ----------------------------------------------------------------
module.apply()
equal(Swipe() .. " " .. casting.SpellCastAnimFrame.alpha, "1 0", "on: the swipe solid, the cast animation taken to nothing")
Fire("UNIT_SPELLCAST_CHANNEL_START")
Advance(0)
equal(Swipe() .. " " .. Late(), "1 0", "a channel starts: the swipe put back to solid, nothing booked for later")
Advance(3)
Fire("UNIT_SPELLCAST_CHANNEL_STOP")
Advance(0)
equal(Swipe() .. " " .. Late(), "1 2", "the channel ends: solid at once, two more strips booked for after the burst")
Advance(0.52)
equal(Swipe(), GAME_SWIPE, "the game's burst hides at 0.5 s and lightens the swipe (build 70425)")
Advance(0.1)
equal(Swipe() .. " " .. #timers, "1 1", "0.6 s after the end: solid again, the slow-frame strip still booked")
Advance(0.4)
equal(Swipe() .. " " .. #timers, "1 0", "1 s after the end: still solid, nothing left booked")
Advance(5)
equal(Swipe(), 1, "and it stays solid")

-- 2. A cast: succeeded, then stopped, in the same frame ----------------------------------
Fire("UNIT_SPELLCAST_START")
Advance(1.5)
Fire("UNIT_SPELLCAST_SUCCEEDED")
Fire("UNIT_SPELLCAST_STOP")
Advance(0)
equal(Swipe() .. " " .. Late(), "1 4", "a cast succeeds and stops: solid, two late strips for each end event")
Advance(0.55)
equal(Swipe(), GAME_SWIPE, "the burst lightens it")
Advance(0.1)
equal(Swipe(), 1, "then solid again")
Advance(0.5)
equal(Swipe() .. " " .. #timers, "1 0", "and after the slow-frame strips, nothing left booked")

-- 3. The stop a moment after the success -----------------------------------------------------
Fire("UNIT_SPELLCAST_START")
Advance(1.5)
Fire("UNIT_SPELLCAST_SUCCEEDED")
Advance(0.2)
Fire("UNIT_SPELLCAST_STOP")
Advance(0.35)
equal(Swipe(), GAME_SWIPE, "the burst of the first end lightens it")
Advance(0.1)
equal(Swipe(), 1, "the late strip of the first end puts it back")
Advance(1)
equal(Swipe() .. " " .. #timers, "1 0", "the second one's strip leaves it solid")

-- 4. A hitch: the burst's end lands after the first late strip -----------------------------
burst = 0.65
Fire("UNIT_SPELLCAST_CHANNEL_START")
Advance(2)
Fire("UNIT_SPELLCAST_CHANNEL_STOP")
Advance(0.7)
equal(Swipe(), GAME_SWIPE, "a hitch: the burst hides after the first late strip and lightens the swipe")
Advance(0.4)
equal(Swipe() .. " " .. #timers, "1 0", "the slow-frame strip at 1 s puts it back")
burst = 0.5

-- 5. An interrupted cast: hidden at once, the next-frame strip covers it --------------------
Fire("UNIT_SPELLCAST_START")
Advance(0.4)
Fire("UNIT_SPELLCAST_INTERRUPTED")
equal(Swipe(), 1, "interrupted: solid at once (the game hid it before EraUI's strip)")
Advance(0)
equal(Late(), 0, "an interrupt books no late strip (nothing hides later)")
Advance(1)
equal(Swipe(), 1, "still solid")

-- 6. Off: the game's own swipe and animation ------------------------------------------------
Fire("UNIT_SPELLCAST_CHANNEL_START")
Advance(2)
Fire("UNIT_SPELLCAST_CHANNEL_STOP")
Advance(0)
module.restore()
equal(casting.SpellCastAnimFrame.alpha, 1, "switched off: the cast animation shows again")
Advance(1)
equal(Swipe(), GAME_SWIPE, "switched off before the late strip: it leaves the game's swipe alone")
Fire("UNIT_SPELLCAST_CHANNEL_START")
Advance(2)
Fire("UNIT_SPELLCAST_CHANNEL_STOP")
Advance(1)
equal(Swipe() .. " " .. casting.SpellCastAnimFrame.alpha, GAME_SWIPE .. " 1", "off: the game's own swipe and animation")
module.apply()
equal(Swipe(), 1, "on again: solid")

equal(table.concat(writes, ","), "", "no key written on the game's buttons, their cooldowns or animations")
print("Cast animation checks passed: " .. checks .. " assertions.")
