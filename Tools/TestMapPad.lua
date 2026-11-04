-- The secure click pad (Look/BandMicro.lua, ns.MapPad) on Tools/LookMockGame.lua:
-- one pad per button, a secure button that clicks the minimap's zone text
-- button (or the target given), made only out of a fight (asked in one, made
-- when it ends), laid exactly over its button every 0.2 s out of a fight, and
-- hidden while the button is, while Edit Mode is open or while "when" says no.
-- A pad with an "after" runs it once the click is let go, and stands down at
-- a fight's start. The real button shows pressed while the pad is held, and
-- the World Map button stays pressed while the map is open. Its tooltip is
-- EraUI's own, never the game's GameTooltip. It works with the band off.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local Mock = dofile("Tools/LookMockGame.lua")
local game = Mock.New()
local Look = game.Load()
local env, ns = game.env, game.ns
-- No login: the band is off; the pads still work.

-- The pads made so far, oldest first.
local function Pads()
    local found = {}
    for _, frame in ipairs(game.frames) do
        if frame.template == "SecureActionButtonTemplate" then found[#found + 1] = frame end
    end
    return found
end

-- A button of another window, out of a fight.
local spell = game.New("Button", "SpellbookLikeButton", env.UIParent)
spell:SetSize(28, 38)
spell.points = { { "BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 300, 20 } }
spell.level = 7
local afterRuns = 0
ns.MapPad(spell, "HIGH", function() afterRuns = afterRuns + 1 end)
ns.MapPad(spell, "HIGH", function() afterRuns = afterRuns + 100 end)
Equal(#Pads(), 1, "one pad per button, a second ask does nothing")
local pad = Pads()[1]
Equal(pad.attributes.type .. " " .. tostring(pad.attributes.useOnKeyDown), "click false", "a secure click, on the key's release")
Equal(pad.attributes.clickbutton, env.MinimapCluster.ZoneTextButton, "clicking the minimap's zone button by default")
Equal(pad.strata .. " " .. tostring(pad.shown), "HIGH false", "its layer as asked, hidden at first")
game.Tick(0.2)
Equal(pad.shown, true, "shown over its button")
local l, b, r, t = pad:Rect()
local bl, bb, br, bt = spell:Rect()
Equal(string.format("%g %g %g %g", l, b, r, t), string.format("%g %g %g %g", bl, bb, br, bt), "exactly over it")
Equal(pad.level, 12, "5 levels above it")
-- Clicks
pad.scripts.OnMouseDown(pad)
Equal(spell.state, "PUSHED", "held: the button shows pressed")
pad.scripts.OnMouseUp(pad)
Equal(spell.state, "NORMAL", "let go: normal again")
pad.scripts.PostClick(pad, "LeftButton", true)
Equal(afterRuns, 0, "after: not on the press")
pad.scripts.PostClick(pad, "LeftButton", false)
Equal(afterRuns, 1, "after: on the release")
-- Its tooltip
spell.tooltipText = "Spellbook (P)"
pad.scripts.OnEnter(pad)
Equal(spell.highlightLocked, true, "the button's highlight locked while over the pad")
local tipShown
for _, frame in ipairs(game.frames) do
    if frame.strata == "TOOLTIP" and frame.shown then tipShown = frame end
end
Equal(tipShown ~= nil and tipShown.rows[1].text, "Spellbook (P)", "EraUI's own tooltip with the button's text")
pad.scripts.OnLeave(pad)
Equal(tostring(spell.highlightLocked) .. " " .. tostring(tipShown.shown), "false false", "unlocked, the tip gone")
Equal(env.GameTooltip, nil, "the game's tooltip never touched")
-- Hidden while...
spell.shown = false
game.Tick(0.2)
Equal(pad.shown, false, "its button hidden: hidden")
spell.shown = true
game.editing = true
game.Tick(0.2)
Equal(pad.shown, false, "Edit Mode open: hidden")
game.editing = false
game.Tick(0.2)
Equal(pad.shown, true, "back when Edit Mode closes")
spell.points = {}
game.Tick(0.2)
Equal(pad.shown, false, "its button has no place: hidden")
spell.points = { { "BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 300, 20 } }
-- A fight: nothing laid; a pad with an "after" stands down at its start.
game.Tick(0.2)
game.combat = true
game.Fire("PLAYER_REGEN_DISABLED")
Equal(pad.shown, false, "a pad that opens EraUI's own window stands down in a fight")
spell.points = { { "BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 500, 20 } }
game.Tick(0.4)
Equal(pad.shown, false, "nothing laid in a fight")
-- Asked in a fight: made when it ends.
local quest = game.New("Button", "QuestLikeButton", env.UIParent)
quest:SetSize(28, 38)
quest.points = { { "BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 340, 20 } }
local allowed = false
ns.MapPad(quest, nil, nil, nil, function() return allowed end)
Equal(#Pads(), 1, "asked in a fight: not made yet")
game.combat = false
game.Fire("PLAYER_REGEN_ENABLED")
Equal(#Pads(), 2, "made when the fight ends")
local questPad = Pads()[2]
Equal(questPad.strata, "MEDIUM", "MEDIUM by default")
game.Tick(0.2)
Equal(questPad.shown, false, "'when' says no: hidden")
allowed = true
game.Tick(0.2)
Equal(questPad.shown and pad.shown, true, "'when' says yes: shown; the first pad back after the fight")
local px = pad:Rect()
Equal(string.format("%g", px), "500", "and laid over its button's new place")
-- The World Map button: a pad with no "after" and no target keeps it pressed while the map is open.
local world = Look.WorldMapButton()
local worldPad = Pads()[3]
Equal(worldPad ~= nil and worldPad.attributes.clickbutton, env.MinimapCluster.ZoneTextButton, "the World Map button's own pad")
worldPad.scripts.OnMouseDown(worldPad)
env.WorldMapFrame:Show()
worldPad.scripts.OnMouseUp(worldPad)
Equal(world.state, "PUSHED", "the map opened: the button stays pressed")
env.WorldMapFrame:Hide()
Equal(world.state, "NORMAL", "the map closed: normal")
worldPad.scripts.OnEnter(worldPad)
Equal(tipShown.shown and tipShown.rows[1].text, "World Map", "its own tip: World Map")
worldPad.scripts.OnLeave(worldPad)
Equal(tipShown.shown, false, "the pad's leave takes the map's tip away")
worldPad.scripts.OnEnter(worldPad)
game.bindings.TOGGLEWORLDMAP = "M"
world.scripts.OnEnter(world)
Equal(tipShown.rows[1].text, "World Map (M)", "with its key")
world.scripts.OnLeave(world)
Equal(tipShown.shown, false, "hidden on leave")
world.scripts.OnClick(world)
Equal(game.mapToggles, 1, "a click opens the map")
Equal(Look.band.active, false, "all with the band off")

print("Map pad checks passed: " .. checks .. " assertions.")
