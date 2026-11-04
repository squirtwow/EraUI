-- The classic button style (Look/ButtonStyle.lua, registry entry "buttons"),
-- rewritten clean-room on 2026-10-21 from Tools/ClassicSpecs/01-action-bars.md
-- section 13. On Tools/LookMockGame.lua, whose action buttons carry the pieces
-- of Forever's ActionButtonTemplate (icon and round mask, SlotBackground,
-- SlotArt, Flash, Border, the state faces) and its UpdateButtonArt:
--   1. which buttons: the nine bars' own lists, else their buttons by name,
--      each once; never the stance, pet or possess buttons
--   2. the 1.x art and every size, from the button's width (45 if unreadable)
--   3. square icons: the round mask off once, back when the setting goes off
--   4. the repaint watch: only a button the game redrew is dressed again
--   5. Action Bar 1 left as the game's own bar keeps its slot frame
--   6. taking it off gives the game's art back, once; never-on touches nothing
--   7. one erroring button never stops the others
--   8. the engine order, the cast animation following the same buttons
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
-- Values as text the same in Lua 5.1 and 5.3 (no "1.0").
local function G(...)
    local out = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        out[i] = type(v) == "number" and string.format("%g", v) or tostring(v)
    end
    return table.concat(out, " ")
end
local function Point(region, owner)
    local p = region.points[1]
    if not p then return "none" end
    return G(p[1], p[2] == owner and "button" or tostring(p[2] and p[2].name), p[3], p[4], p[5]) .. " (" .. #region.points .. ")"
end
local function Crop(region)
    local c = region.coords
    if not c then return "none" end
    return G(c[1] * 64, c[2] * 64, c[3] * 64, c[4] * 64)
end

local Mock = dofile("Tools/LookMockGame.lua")
local game = Mock.New()
local Look = game.Load()
local env, ns = game.env, game.ns
local QS = "Interface\\Buttons\\"

local Style
for _, module in ipairs(ns.modules) do
    if module.key == "buttons" then Style = module end
end
Equal(Style ~= nil and type(Style.apply) == "function" and type(Style.restore) == "function", true,
    "a registry entry \"buttons\" with apply and restore")

---------------------------------------------------------------------------
-- 8a. The engine order: the band lays out first, the cast animation and the
-- page arrows after.
---------------------------------------------------------------------------
do
    local keys = {}
    for _, module in ipairs(ns.modules) do keys[#keys + 1] = module.key end
    Equal(table.concat(keys, " "), "classicBar buttons castAnim classicBar emptySlots", "registry order")
end

---------------------------------------------------------------------------
-- 1. Which buttons
---------------------------------------------------------------------------
local function Visited()
    local seen, count, twice = {}, 0, false
    ns.ForEachActionButton(function(button)
        if seen[button] then twice = true end
        seen[button] = true
        count = count + 1
    end)
    return seen, count, twice
end
do
    local seen, count, twice = Visited()
    Equal(G(count, twice), "96 false", "eight bars of twelve here (no MainMenuBar on Forever), each button once")
    Equal(seen[env.ActionButton1] and seen[env.ActionButton12] and seen[env.MultiBarBottomLeftButton1]
        and seen[env.MultiBarLeftButton12] and seen[env.MultiBar7Button12] and true, true, "Action Bar 1 to bar 8")
    Equal(seen[env.StanceButton1] or seen[env.PetActionButton1] or seen[env.PossessButton1] or false, false,
        "never the stance, pet or possess buttons")
    -- A bar without its own list: its buttons by their global names.
    local list = env.MultiBar6.actionButtons
    env.MultiBar6.actionButtons = nil
    seen, count = Visited()
    Equal(G(count, seen[env.MultiBar6Button7] == true), "96 true", "no list of its own: MultiBar6Button1 to 12 by name")
    env.MultiBar6.actionButtons = list
    -- Action Bar 1 under its older name too: still each button once.
    env.MainMenuBar = env.MainActionBar
    seen, count, twice = Visited()
    Equal(G(count, twice), "96 false", "MainMenuBar naming the same bar: no button twice")
    env.MainMenuBar = { actionButtons = env.MainActionBar.actionButtons }
    seen, count, twice = Visited()
    Equal(G(count, twice), "96 false", "a second bar listing the same buttons: still each button once")
    env.MainMenuBar = nil
    -- A bar the client lacks is skipped.
    local seventh = env.MultiBar7
    env.MultiBar7 = nil
    seen, count = Visited()
    Equal(count, 84, "a missing bar is skipped")
    env.MultiBar7 = seventh
end

---------------------------------------------------------------------------
-- 2. The 1.x art, at login (buttons on by default)
---------------------------------------------------------------------------
game.Login()
local b1 = env.ActionButton1
do
    Equal(b1.SlotArt.alpha, 0, "the modern slot frame faded")
    local ring = b1:GetNormalTexture()
    Equal(G(ring.file, Crop(ring)), QS .. "UI-Quickslot2 12 51 12 51", "the ring: UI-Quickslot2, its pixels 12 to 51")
    Equal(G(ring.width, ring.height, ring.layer, ring.alpha, ring.theme), "50 50 OVERLAY 0.5 slotNormal",
        "the ring: 40 x 45/36 square, OVERLAY, half alpha, Dark Mode's key")
    Equal(Point(ring, b1), "CENTER button CENTER 0 0 (1)", "the ring: centred")
    local socket = b1.SlotBackground
    Equal(G(socket.file, Crop(socket)), QS .. "UI-Quickslot 0 64 0 64", "the socket: UI-Quickslot, full")
    Equal(G(socket.width, socket.layer, socket.sublevel, socket.alpha, socket.shown, socket.theme),
        "82.5 BACKGROUND -1 0.4 true slotEmpty", "the socket: 66 x 45/36, BACKGROUND -1, alpha 0.4, shown, Dark Mode's key")
    Equal(Point(socket, b1), "CENTER button CENTER 0 0 (1)", "the socket: centred (no longer filling the button)")
    local pressed = b1:GetPushedTexture()
    Equal(G(pressed.file, Crop(pressed), pressed.width, pressed.height, pressed.layer, Point(pressed, b1)),
        QS .. "UI-Quickslot-Depress 0 64 0 64 45 45 OVERLAY CENTER button CENTER 0 0 (1)", "pressed: the button's size")
    local glow = b1:GetHighlightTexture()
    Equal(G(glow.file, glow.width, glow.blend, glow.theme, Point(glow, b1)),
        QS .. "ButtonHilight-Square 45 ADD nil CENTER button CENTER 0 0 (1)", "mouse-over: additive, keeps its colour")
    local checked = b1:GetCheckedTexture()
    Equal(G(checked.file, checked.width, checked.blend, Point(checked, b1)),
        QS .. "CheckButtonHilight 45 ADD CENTER button CENTER 0 0 (1)", "checked: additive")
    local flash = b1.Flash
    Equal(G(flash.file, flash.width, flash.height, Point(flash, b1)), QS .. "UI-QuickslotRed 45 45 CENTER button CENTER 0 0 (1)",
        "the red attack flash")
    local border = b1.Border
    Equal(G(border.file, border.width, border.blend, Point(border, b1)),
        QS .. "UI-ActionButton-Border 77.5 ADD CENTER button CENTER 0 0 (1)", "the equipped border: 62 x 45/36, additive")
    Equal(G(flash.shown, border.shown), "false false", "the flash and border are left for the game to show")
    Equal(#b1.icon.masks, 0, "square icons (on by default): the round mask off")
    -- The side bars too.
    Equal(G(env.MultiBar7Button12.SlotArt.alpha, env.MultiBar7Button12:GetNormalTexture().file), "0 " .. QS .. "UI-Quickslot2",
        "bar 8's last button dressed too")
    Equal(env.StanceButton1:GetNormalTexture().file, "normal", "a stance button keeps the game's art")
    Equal(#env.StanceButton1.icon.masks, 1, "and its round mask")
    -- Dressing is textures only: the game's own Lua (UpdateButtonArt) runs
    -- from EraUI's code only when the style comes off.
    Equal(game.buttonArtUpdates, 0, "dressing never runs the game's own UpdateButtonArt")
end

-- Sizes follow the button's width: a 36-wide button, then unreadable ones.
do
    local side = env.MultiBarRightButton1
    side:SetSize(36, 36)
    Style.apply()
    Equal(G(side:GetNormalTexture().width, side.SlotBackground.width, side.Border.width, side:GetPushedTexture().width,
        side:GetHighlightTexture().width, side.Flash.width), "40 66 62 36 36 36", "a 36-wide button: the 1.x sizes")
    game.secret = {}
    side.width = game.secret
    Style.apply()
    Equal(G(side:GetNormalTexture().width, side.SlotBackground.width, side.Border.width, side:GetPushedTexture().width),
        "50 82.5 77.5 45", "a width the game keeps secret: sized as 45")
    side.width = 0
    Style.apply()
    Equal(G(side:GetNormalTexture().width, side:GetPushedTexture().width), "50 45", "a zero width: sized as 45")
    game.secret = nil
    side:SetSize(45, 45)
    Style.apply()
end

-- Bundled art first (textureSource), still through Dark Mode's key.
do
    ns.db.textureSource = "bundled"
    Style.apply()
    Equal(G(b1:GetNormalTexture().file, b1:GetNormalTexture().theme), "Interface\\AddOns\\EraUI\\Media\\Classic\\UI-Quickslot2 slotNormal",
        "bundled first: EraUI's copy")
    ns.db.textureSource = nil
    Style.apply()
    Equal(b1:GetNormalTexture().file, QS .. "UI-Quickslot2", "back to the game's own file")
end

---------------------------------------------------------------------------
-- 3. Square icons
---------------------------------------------------------------------------
do
    Equal(game.maskChanges, 96, "each round mask taken off once at login")
    game.Pass()
    Style.apply()
    Equal(game.maskChanges, 96, "and never again on later passes")
    ns.db.squareIcons = false
    game.Pass()
    Equal(G(#b1.icon.masks, b1.icon.masks[1] == b1.IconMask, game.maskChanges), "1 true 192", "off: each mask put back once")
    game.Pass()
    Equal(game.maskChanges, 192, "off: nothing more")
    ns.db.squareIcons = true
    game.Pass()
    Equal(G(#b1.icon.masks, game.maskChanges), "0 288", "on again: off once more")
end

---------------------------------------------------------------------------
-- 4. The repaint watch
---------------------------------------------------------------------------
do
    local b2, b3 = env.ActionButton2, env.ActionButton3
    -- A mark on each ring shows whether the style dressed the button again.
    local function Mark() b2:GetNormalTexture().alpha, b3:GetNormalTexture().alpha = 0.7, 0.7 end
    local function Dressed(button) return button:GetNormalTexture().alpha == 0.5 end
    Mark()
    game.Tick(0.4)
    Equal(G(Dressed(b2), Dressed(b3)), "false false", "nothing redrawn: nothing dressed again")
    b2.SlotArt:SetAlpha(1)
    game.Tick(0.25)
    Equal(G(b2.SlotArt.alpha, Dressed(b2), Dressed(b3)), "0 true false", "the slot frame back: that button dressed again, alone")
    Mark()
    b2.SlotArt:SetAlpha(0.05)
    game.Tick(0.25)
    Equal(G(b2.SlotArt.alpha, Dressed(b2)), "0 true", "the slot frame barely back (above 0.01): dressed again")
    Mark()
    b2.SlotBackground:SetAlpha(1)
    game.Tick(0.25)
    Equal(G(b2.SlotBackground.alpha, Dressed(b2)), "0.4 true", "the socket's alpha changed: dressed again")
    Mark()
    b2.SlotBackground:SetAlpha(0.4000000059604645)
    game.Tick(0.4)
    Equal(Dressed(b2), false, "0.4 as the game stores it (single precision) is still EraUI's")
    b2.SlotBackground:SetAlpha(0.4)
    -- The socket hidden: with the band on it is left so (as before); with
    -- the band off the button is dressed again.
    b2.SlotBackground:Hide()
    game.Tick(0.4)
    Equal(G(b2.SlotBackground.shown, Dressed(b2)), "false false", "socket hidden, band on: left as it is")
    Look.band.active = false
    game.Tick(0.25)
    Equal(G(b2.SlotBackground.shown, Dressed(b2)), "true true", "socket hidden, band off: dressed again")
    Look.band.active = true
    -- In a fight: textures only, nothing of Edit Mode's moved.
    Mark()
    game.combat = true
    b2.SlotArt:SetAlpha(1)
    game.Tick(0.25)
    game.combat = false
    Equal(G(Dressed(b2), #game.fightMoves, #game.overrides), "true 0 0", "in a fight: the textures only, no frame moved")
    Equal(game.buttonArtUpdates, 0, "the watch, in a fight too, never runs the game's own UpdateButtonArt")
    b2:GetNormalTexture().alpha = 0.5
    b3:GetNormalTexture().alpha = 0.5
end

---------------------------------------------------------------------------
-- 5. Action Bar 1 as the game's own bar (classicBar exactly false)
---------------------------------------------------------------------------
do
    ns.db.classicBar = false
    Style.apply()
    local side = env.MultiBarBottomLeftButton1
    Equal(G(b1.SlotArt.alpha, side.SlotArt.alpha), "1 0", "Action Bar 1 keeps the game's slot frame; other bars don't")
    b1:GetNormalTexture().alpha = 0.7
    game.Tick(0.4)
    Equal(G(b1.SlotArt.alpha, b1:GetNormalTexture().alpha), "1 0.7", "kept at 1: the watch leaves it be")
    b1.SlotArt:SetAlpha(0.5)
    game.Tick(0.25)
    Equal(G(b1.SlotArt.alpha, b1:GetNormalTexture().alpha), "1 0.5", "faded below 0.99: dressed again, kept at 1")
    b1.SlotArt:Hide()
    Style.apply()
    Equal(b1.SlotArt.alpha, 0, "its slot frame hidden by the game: faded like the rest")
    b1.SlotArt:Show()
    local called = side.name
    side.name = nil
    local fine = pcall(Style.apply)
    Equal(G(fine, side.SlotArt.alpha), "true 0", "a button with no name: faded, no error")
    side.name = called
    ns.db.classicBar = nil
    Style.apply()
    Equal(b1.SlotArt.alpha, 0, "the band back on: faded")
end

---------------------------------------------------------------------------
-- 6. Taking it off
---------------------------------------------------------------------------
do
    game.buttonArtUpdates = 0
    ns.db.buttons = false
    game.Pass()
    Equal(game.buttonArtUpdates, 96, "the game's own UpdateButtonArt, once per dressed button")
    Equal(b1.SlotArt.alpha, 1, "the slot frame back")
    local socket = b1.SlotBackground
    Equal(G(socket.alpha, socket.layer, socket.sublevel, Crop(socket), socket.atlas),
        "1 BACKGROUND 0 0 64 0 64 UI-HUD-ActionBar-IconFrame-Background", "the socket: the game's art, alpha 1, BACKGROUND 0")
    Equal(G(socket.points[1][1], socket.points[2][1], socket.points[1][2] == b1), "TOPLEFT BOTTOMRIGHT true",
        "the socket fills the button again")
    Equal(G(socket.shown, b1.SlotArt.shown), "false true", "and the game's own update shows what its bar art wants")
    Equal(G(#b1.icon.masks, b1.icon.masks[1] == b1.IconMask), "1 true", "the round mask back")
    local ring, pressed = b1:GetNormalTexture(), b1:GetPushedTexture()
    Equal(G(ring.atlas, Crop(ring), ring.alpha, ring.width, ring.height, Point(ring, b1)),
        "UI-HUD-ActionBar-IconFrame 0 64 0 64 1 46 45 TOPLEFT button TOPLEFT 0 0 (1)", "the frame: the game's, full, at the top left")
    Equal(G(pressed.atlas, Crop(pressed), Point(pressed, b1)),
        "UI-HUD-ActionBar-IconFrame-Down 0 64 0 64 TOPLEFT button TOPLEFT 0 0 (1)", "pressed: the game's")
    for _, glow in ipairs({ b1:GetHighlightTexture(), b1:GetCheckedTexture() }) do
        Equal(G(glow.atlas, glow.width, glow.height, Point(glow, b1)),
            "UI-HUD-ActionBar-IconFrame-Mouseover 46 45 TOPLEFT button TOPLEFT 0 0 (1)", "the glows: the game's, 46 x 45")
    end
    Equal(G(b1.Flash.atlas, b1.Flash.atlasSized, Point(b1.Flash, b1)),
        "UI-HUD-ActionBar-IconFrame-Flash true TOPLEFT button TOPLEFT 0 0 (1)", "the flash: the game's, at its own size")
    Equal(G(b1.Border.atlas, b1.Border.atlasSized, b1.Border.blend, Point(b1.Border, b1)),
        "UI-HUD-ActionBar-IconFrame-Border true BLEND TOPLEFT button TOPLEFT 0 0 (1)", "the border: the game's, BLEND")
    -- Restore runs on every pass while off: only once.
    game.Pass()
    game.Pass()
    Equal(game.buttonArtUpdates, 96, "later passes while off: nothing more")
    b1.SlotArt:SetAlpha(0.8)
    game.Tick(0.4)
    Equal(b1.SlotArt.alpha, 0.8, "off: the watch dresses nothing")
    -- On again.
    ns.db.buttons = nil
    game.Pass()
    Equal(G(b1.SlotArt.alpha, b1:GetNormalTexture().file, #b1.icon.masks), "0 " .. QS .. "UI-Quickslot2 0", "on again: dressed")
end

-- Off from the start: nothing touched at all.
do
    local fresh = Mock.New()
    fresh.Load()
    fresh.ns.db.buttons = false
    fresh.Login()
    fresh.Tick(0.4)
    local first = fresh.env.ActionButton1
    Equal(G(fresh.buttonArtUpdates, first:GetNormalTexture().file, first.SlotArt.alpha, #first.icon.masks, first.SlotBackground.atlas),
        "0 normal 1 1 UI-HUD-ActionBar-IconFrame-Background", "never on: the game's buttons untouched")
end

---------------------------------------------------------------------------
-- 7. One erroring button never stops the others
---------------------------------------------------------------------------
do
    local bad, good = env.MultiBarLeftButton1, env.MultiBarLeftButton2
    rawset(bad, "GetWidth", function() error("boom") end)
    good:GetNormalTexture().alpha = 0.7
    local fine, problem = pcall(Style.apply)
    Equal(G(fine, tostring(problem):find("boom", 1, true) ~= nil), "false true", "the error is passed on to the engine")
    Equal(good:GetNormalTexture().alpha, 0.5, "the buttons after it are still dressed")
    rawset(bad, "GetWidth", nil)
    Style.apply()
end

---------------------------------------------------------------------------
-- 8b. The cast animation follows the same buttons
---------------------------------------------------------------------------
do
    Equal(G(b1.SpellCastAnimFrame.alpha, env.MultiBar5Button3.SpellCastAnimFrame.alpha, env.StanceButton1.SpellCastAnimFrame.alpha),
        "0 0 1", "No cast animation: every styled button, never a stance button")
end

print("Button style checks passed: " .. checks .. " assertions.")
