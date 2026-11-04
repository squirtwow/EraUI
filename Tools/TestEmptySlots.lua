-- Empty action slots (Look/EmptySlots.lua, Hide Empty Action Slots) on
-- Tools/LookMockGame.lua:
--   * side bars: an empty button's alpha is 0, 1 with an action, and 1 while
--     the game's grid shows (a spell in hand, ACTIONBAR_SHOWGRID) or its
--     "showgrid" attribute holds the event (2) or spellbook (4) reason; the
--     Always Show Buttons reason (1) alone does not count;
--   * Action Bar 1: an empty slot shows EraUI's socket and ring (the 1.x art,
--     sized by the button) while the button's own art doesn't show, and its
--     key while the button's own hotkey doesn't (not with Hide Keybind Text,
--     not while the grid shows), in the hotkey's font and colour;
--   * off: EraUI's sockets and labels hidden, the faded side buttons back.
-- Nothing is written on the game's buttons: EraUI's frames lie over them.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local Mock = dofile("Tools/LookMockGame.lua")
local game = Mock.New()
local Look = game.Load()
local env, ns = game.env, game.ns

-- Which buttons hold an action: their own HasAction, as the game's buttons have.
local holds = {}
for _, frame in ipairs(game.frames) do
    if frame.kind == "CheckButton" then
        local button = frame
        rawset(button, "HasAction", function() return holds[button] == true end)
    end
end
local side1, side2 = env.MultiBarBottomLeftButton1, env.MultiBarBottomLeftButton2
holds[side1] = true
holds[env.ActionButton1] = true
game.bindings.ACTIONBUTTON1, game.bindings.ACTIONBUTTON3 = "1", "3"
env.ActionButton3.HotKey.text = ""
env.ActionButton3.HotKey:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
env.ActionButton3.HotKey:SetTextColor(0.6, 0.6, 0.6)

-- Off (the default): nothing.
game.ns.db.emptySlots = false
game.Login()
game.Tick(0.4)
Equal(side2.alpha, 1, "off: empty side buttons as the game shows them")

-- On.
game.ns.db.emptySlots = true
game.Pass()
Equal(side1.alpha .. " " .. side2.alpha, "1 0", "on: an empty side button hidden, one with an action shown")
game.Fire("ACTIONBAR_SHOWGRID")
game.Tick(0.05)
Equal(side2.alpha, 1, "a spell in hand: shown")
game.Fire("ACTIONBAR_HIDEGRID")
game.Tick(0.05)
Equal(side2.alpha, 0, "put down: hidden again")
for reasons, want in pairs({ [1] = 0, [2] = 1, [4] = 1, [5] = 1, [3] = 1, [0] = 0 }) do
    side2.attributes.showgrid = reasons
    game.Tick(1)
    Equal(side2.alpha, want, "showgrid " .. reasons)
end
side2.attributes.showgrid = nil
game.Tick(1)

-- Action Bar 1's empty third slot.
local function Covers(slotButton)
    local under, over
    for _, frame in ipairs(game.frames) do
        if frame.kind == "Frame" and frame.points[1] and frame.points[1][2] == slotButton and frame.parent == env.UIParent then
            if not under then under = frame else over = frame end
        end
    end
    return under, over
end
local button3 = env.ActionButton3
local under, over = Covers(button3)
Equal(under ~= nil and over ~= nil, true, "EraUI's two frames over the slot")
local socket, ring = under.regions[1], under.regions[2]
Equal(socket.file .. " " .. socket.alpha .. " " .. socket.layer .. " " .. socket.sublevel, "Interface\\Buttons\\UI-Quickslot 0.4 BACKGROUND -1",
    "the stone socket")
Equal(ring.file .. " " .. ring.alpha, "Interface\\Buttons\\UI-Quickslot2 0.5", "the ring")
Equal(string.format("%g", ring.coords[1] * 64) .. " " .. string.format("%g", ring.coords[2] * 64), "12 51", "cropped to its pixels 12 to 51")
Equal(string.format("%g %g", socket.width, ring.width), "82.5 50", "sized by the button (45 / 36)")
Equal(socket.theme .. " " .. ring.theme, "slotEmpty slotNormal", "Dark Mode's keys")
Equal(under.shown, false, "the button's own art shows: no socket")
button3:GetNormalTexture():SetAlpha(0)
game.Tick(1)
Equal(under.shown, true, "its own art gone: the socket shows")
Equal(under.level < button3.level and over.level > button3.level, true, "the socket under the button, the key over it")
local label = over.regions[1]
Equal(over.shown and label.text, "3", "the key bound to the slot")
Equal(label.font[1] .. " " .. label.font[2] .. " " .. string.format("%g", label.textColor[1]), "Fonts\\FRIZQT__.TTF 11 0.6",
    "in the hotkey's font and colour")
local _, over1 = Covers(env.ActionButton1)
Equal(over1 == nil or not over1.shown, true, "a slot with an action: nothing of EraUI's")
button3.HotKey.text = "3"
game.Tick(1)
Equal(over.shown, false, "the game's own hotkey shows: no label")
button3.HotKey.text = RANGE_INDICATOR or "●"
env.RANGE_INDICATOR = button3.HotKey.text
game.Tick(1)
Equal(over.shown, true, "the range dot isn't a key: label")
button3.HotKey.text = ""
game.settings.hideKeybindText = true
game.Tick(1)
Equal(over.shown, false, "Hide Keybind Text: no label")
game.settings.hideKeybindText = false
game.Fire("ACTIONBAR_SHOWGRID")
game.Tick(0.05)
Equal(under.shown or over.shown, false, "a spell in hand: the socket and label give way to the grid")
game.Fire("ACTIONBAR_HIDEGRID")
game.Tick(0.05)
Equal(under.shown and over.shown, true, "back after")
-- The game hides an empty button itself; its slot (holder) still shows.
button3:Hide()
game.Tick(1)
Equal(under.shown and over.shown, true, "the game's empty button hidden: the socket and key stand in")
button3:Show()
-- No slot at all: the whole bar away (a vehicle, a pet battle), or a slot
-- past Edit Mode's icon count. Nothing of EraUI's is left behind.
env.MainActionBar:Hide()
game.Tick(1)
Equal(under.shown or over.shown, false, "the bar hidden: no socket or key left on screen")
env.MainActionBar:Show()
game.Tick(1)
Equal(under.shown and over.shown, true, "the bar back: so are they")
button3.container:Hide()
game.Tick(1)
Equal(under.shown or over.shown, false, "a slot Edit Mode doesn't show: nothing")
button3.container:Show()
env.MainActionBar:SetAlpha(0.5)
game.Tick(1)
Equal(under.alpha .. " " .. over.alpha, "0.5 0.5", "they fade with the bar")
env.MainActionBar:SetAlpha(1)
game.Tick(1)
holds[button3] = true
game.Fire("ACTIONBAR_SLOT_CHANGED")
game.Tick(0.05)
Equal(under.shown or over.shown, false, "a spell placed: nothing of EraUI's")
holds[button3] = nil
game.Fire("ACTIONBAR_SLOT_CHANGED")
game.Tick(0.05)

-- Audit A15: one pass at a time. A burst of slot changes (a rank swap, a
-- page change) makes one pass on the next frame, none before it; with
-- nothing announced, one look a second (never five); the game's own grid
-- calls (its spellbooks) book a pass too.
local passes = 0
local plainHolds = rawget(env.ActionButton1, "HasAction")
rawset(env.ActionButton1, "HasAction", function(...) passes = passes + 1; return plainHolds(...) end)
for _ = 1, 180 do game.Fire("ACTIONBAR_SLOT_CHANGED") end
Equal(passes, 0, "A15: 180 slot changes: no pass yet")
game.Tick(0.05)
Equal(passes, 1, "A15: one pass on the next frame")
game.Tick(0.9)
Equal(passes, 1, "A15: nothing announced: no pass for most of a second")
game.Tick(0.15)
Equal(passes, 2, "A15: then the slow look, once a second")
side2.attributes.showgrid = 4
game.Tick(1)
Equal(side2.alpha, 1, "A15: a grid set with no event is still caught by the slow look")
side2.attributes.showgrid = nil
game.Tick(1)
for _, event in ipairs({ "CVAR_UPDATE", "EDIT_MODE_LAYOUTS_UPDATED" }) do
    passes = 0
    game.Fire(event)
    game.Tick(0.05)
    Equal(passes, 1, "A15: " .. event .. " books a pass")
end
local gridCalls = 0
env.MultiActionBar_ShowAllGrids = function() gridCalls = gridCalls + 1 end
env.MultiActionBar_HideAllGrids = function() gridCalls = gridCalls + 1 end
game.Pass()
game.Pass()
game.Tick(1)
passes = 0
env.MultiActionBar_ShowAllGrids(4)
game.Tick(0.05)
env.MultiActionBar_HideAllGrids(4)
game.Tick(0.05)
Equal(gridCalls .. " " .. passes, "2 2", "A15: the game's own grid calls run as before, each booking a pass (hooked once)")
rawset(env.ActionButton1, "HasAction", plainHolds)

-- Off again.
game.ns.db.emptySlots = false
game.Pass()
Equal(under.shown or over.shown, false, "off: EraUI's frames hidden")
Equal(side2.alpha, 1, "off: the faded side button back")
side2:SetAlpha(0.3)
game.Pass()
Equal(side2.alpha, 0.3, "off: the game's own alpha left alone afterwards")

print("Empty slot checks passed: " .. checks .. " assertions.")
