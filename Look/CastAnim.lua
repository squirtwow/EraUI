-- No cast animation on action buttons ("castAnim"): Forever plays an
-- animation over a button's icon while its spell casts and lightens the
-- cooldown swipe under it; 1.x had neither. While on, each button's
-- animation frame is kept invisible and its swipe solid black. This follows
-- the player's cast events (no hook on the game's own animation, no key on
-- its buttons): at once, on the next frame, and for an ending cast again at
-- 0.6 s and 1 s, after the game's 0.5 s end burst puts back its lighter
-- swipe (build 70425), the second strip for a burst that ends late.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local wanted, hidSome = false, false
local LATE_AFTER = { 0.6, 1 }
local ENDINGS = {}
for _, event in ipairs(Look.Words("UNIT_SPELLCAST_STOP UNIT_SPELLCAST_CHANNEL_STOP UNIT_SPELLCAST_SUCCEEDED")) do
    ENDINGS[event] = true
end

local function Calm(actionButton)
    Look.Alpha(actionButton.SpellCastAnimFrame, 0)
    local swipe = actionButton.cooldown
    if swipe and swipe.SetSwipeColor then swipe:SetSwipeColor(0, 0, 0, 1) end
end

local function CalmEvery()
    if not wanted or type(ns.ForEachActionButton) ~= "function" then return end
    hidSome = true
    ns.ForEachActionButton(Calm)
end

local listener = CreateFrame("Frame")
for _, event in ipairs(Look.Words([[UNIT_SPELLCAST_START UNIT_SPELLCAST_STOP UNIT_SPELLCAST_CHANNEL_START
    UNIT_SPELLCAST_CHANNEL_STOP UNIT_SPELLCAST_SUCCEEDED UNIT_SPELLCAST_INTERRUPTED]])) do
    Look.Listen(listener, event, "player")
end
Look.Listen(listener, "PLAYER_ENTERING_WORLD")
Look.Listen(listener, "ACTIONBAR_SLOT_CHANGED")
-- One next-frame strip however many events ask in a frame, and an ending's
-- late strips booked once per frame (a cast's success and stop come
-- together), at the same 0.6 s and 1 s.
local nextBooked, lateBookedAt = false, nil
local function NextFrame()
    nextBooked = false
    CalmEvery()
end
local function BookNext()
    if nextBooked then return end
    nextBooked = true
    C_Timer.After(0, NextFrame)
end
listener:SetScript("OnEvent", function(_, event)
    if not wanted then return end
    -- Slot changes (a rank swap or a page change brings many) and loading
    -- screens: the next frame's strip only.
    if event == "ACTIONBAR_SLOT_CHANGED" or event == "PLAYER_ENTERING_WORLD" then return BookNext() end
    CalmEvery()
    BookNext()
    if not ENDINGS[event] then return end
    local now = type(GetTime) == "function" and GetTime() or nil
    if now ~= nil and now == lateBookedAt then return end
    lateBookedAt = now
    for _, delay in ipairs(LATE_AFTER) do C_Timer.After(delay, CalmEvery) end
end)

local function Shows(actionButton)
    Look.Alpha(actionButton.SpellCastAnimFrame, 1)
end

ns.RegisterModule("castAnim", {
    apply = function()
        wanted = true
        CalmEvery()
    end,
    -- Off: the animations show again; the swipe is left as the game sets it.
    restore = function()
        wanted = false
        if not hidSome or type(ns.ForEachActionButton) ~= "function" then return end
        hidSome = false
        ns.ForEachActionButton(Shows)
    end,
})
