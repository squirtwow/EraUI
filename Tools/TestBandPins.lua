-- Edit Mode layout pins (Look/BandPins.lua) on Tools/LookMockGame.lua: the
-- band's places written into the active Edit Mode layout only as the session
-- ends (ns.sessionEnding), only in a layout that may be written, never in a
-- fight; what counts as EraUI's own pin; the anchors handed to the shared
-- options code; handing the bars back with Action Bars off; the "adopt" job.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
local function G(v) return type(v) == "number" and string.format("%g", v) or tostring(v) end

local Mock = dofile("Tools/LookMockGame.lua")
local game = Mock.New()
local Look = game.Load()
local env, ns = game.env, game.ns
game.Login()
game.Fire("PLAYER_ENTERING_WORLD")

-- Not while the session goes on.
local totem = env.MultiCastActionBarFrame
local totemAt = table.concat({ totem.points[1][1], totem.points[1][3], G(totem.points[1][4]), G(totem.points[1][5]) }, " ")
Equal(ns.PinBandBars(), false, "no session end: nothing pinned")
Equal(game.anchorWrites, nil, "no Edit Mode record written")
Equal(table.concat({ totem.points[1][1], totem.points[1][3], G(totem.points[1][4]), G(totem.points[1][5]) }, " "), totemAt,
    "the totem bar left where Blizzard has it mid-session")
-- The lists.
local unpinned = {}
for _, frame in ipairs(ns.BandBarsToUnpinned()) do unpinned[#unpinned + 1] = frame:GetName() end
Equal(table.concat(unpinned, " "), "MainActionBar MultiBarBottomLeft MultiBarBottomRight MultiBarRight MultiBarLeft StanceBar "
    .. "PetActionBar MainStatusTrackingBarContainer", "the shown band frames Edit Mode has at default")
-- The anchors for the "EraUI" layout.
local anchors = ns.BandPinAnchors()
local first = anchors[1]
Equal(first.name .. " " .. G(first.system) .. " " .. G(first.systemIndex), "MainActionBar 0 1", "name, system and index")
local a = first.anchorInfo
Equal(a.point .. " " .. a.relativeTo .. " " .. a.relativePoint .. " " .. G(a.offsetX) .. " " .. G(a.offsetY),
    "BOTTOMLEFT UIParent BOTTOM -503 4", "bottom-left to UIParent's BOTTOM where the band has it")
-- The shaman's totem bar's spot (2026-10-17 audit A5): bottom-left at the
-- small row's start (30), just above it (104 + 30, 4 clear, 9 more for the
-- two-strip lift), so never on a row. Hidden or not: it shows from level
-- 20, and a shared layout serves every character.
local spotX, spotY = Look.BandPoint(30, 147)
local _, rowTop = Look.BandPoint(30, 104 + 30 + 9)
Equal(spotY > rowTop, true, "the totem bar's spot is above the small row, even with both strips")
local last = anchors[#anchors]
Equal(last.name .. " " .. G(last.system) .. " " .. last.anchorInfo.point .. " " .. last.anchorInfo.relativeTo .. " "
    .. last.anchorInfo.relativePoint .. " " .. G(last.anchorInfo.offsetX) .. " " .. G(last.anchorInfo.offsetY),
    "MultiCastActionBarFrame 17 BOTTOMLEFT UIParent BOTTOM " .. G(spotX) .. " " .. G(spotY),
    "the EraUI layout gets the totem bar's spot too, hidden as it is")
-- In a fight, or a preset layout: nothing.
ns.sessionEnding = true
game.combat = true
Equal(ns.PinBandBars(), false, "in a fight: nothing")
game.combat = false
game.writable = false
Equal(ns.PinBandBars(), false, "a preset layout: nothing")
game.writable = true
-- The session ends: pinned.
Equal(ns.PinBandBars(), true, "pinned as the session ends")
Equal(game.anchorWrites, 9, "each shown band frame's record written, and the totem bar's")
local tp = totem.points[1]
Equal(tp[1] .. " " .. tp[2].name .. " " .. tp[3] .. " " .. G(tp[4]) .. " " .. G(tp[5]), "BOTTOMLEFT UIParent BOTTOM " .. G(spotX) .. " " .. G(spotY),
    "the totem bar on its spot")
Equal(totem.default, false, "no longer at Edit Mode's default, so Blizzard never stacks it over the rows")
Equal(Look.PinnedByEraUI(totem) and not Look.Moved(totem), true, "EraUI's own pin")
local kept = ns.db.barPins.EraUI.MultiCastActionBarFrame
Equal(kept[1] .. " " .. kept[2] .. " " .. G(kept[3]) .. " " .. G(kept[4]), "BOTTOMLEFT BOTTOM " .. G(spotX) .. " " .. G(spotY), "its pin kept for this layout")
Equal(game.layoutSaves, 1, "the layouts saved once")
Equal(ns.db.pinShape, true, "pins are shaped from now on")
local pin = ns.db.barPins.EraUI.MultiBarBottomLeft
Equal(pin[1] .. " " .. pin[2] .. " " .. G(pin[3]) .. " " .. G(pin[4]), "BOTTOMLEFT BOTTOM -503 55", "the pin kept for this layout")
local xp = env.MainStatusTrackingBarContainer
Equal(xp.points[1][1] .. " " .. xp.points[1][2].name .. " " .. xp.points[1][3], "BOTTOMLEFT UIParent BOTTOM",
    "a frame anchored elsewhere re-anchored to UIParent's BOTTOM first")
Equal(#game.overrides .. " " .. #game.fightMoves, "0 0", "through the plain Base methods")
-- Pinned frames are EraUI's: not "moved", so the band still lays them.
Equal(env.MultiBarBottomLeft.default, false, "Edit Mode no longer calls it default")
Equal(Look.PinnedByEraUI(env.MultiBarBottomLeft), true, "but it is EraUI's own pin")
Equal(Look.Moved(env.MultiBarBottomLeft), false, "so not moved")
game.Pass()
Equal(env.MultiBarBottomLeft.points[1][1] .. " " .. G(env.MultiBarBottomLeft.points[1][5]), "BOTTOMLEFT 55", "the band keeps it")
-- The totem bar: never laid by the band, so a pass leaves its pin alone.
Equal(totem.points[1][1] .. " " .. G(totem.points[1][4]) .. " " .. G(totem.points[1][5]), "BOTTOMLEFT " .. G(spotX) .. " " .. G(spotY),
    "a band pass leaves the totem bar on its pin")
-- Its own scale: offsets in its own units, the layout's at scale 1.
totem.scale = 0.5
ns.PinBandBars()
Equal(G(totem.points[1][4]) .. " " .. G(totem.systemInfo.anchorInfo.offsetX), G(spotX / 0.5) .. " " .. G(spotX), "a scaled totem bar lands on the same spot")
totem.scale = 1
-- One Bar stacks the rows 42 higher: the totem bar goes with them.
ns.db.oneBar = true
game.Pass()
local oneX, oneY = Look.BandPoint(30, 147 + 42)
ns.PinBandBars()
Equal(G(totem.points[1][4]) .. " " .. G(totem.points[1][5]), G(oneX) .. " " .. G(oneY), "One Bar: above the higher small row")
ns.db.oneBar = false
game.Pass()
ns.PinBandBars()
-- Moved by the player in Edit Mode: theirs, never pinned again.
local mine = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", offsetX = 100, offsetY = 0 }
totem.systemInfo.anchorInfo = mine
totem.points[1] = { "CENTER", env.UIParent, "CENTER", 100, 0 }
Equal(Look.Moved(totem), true, "moved by the player")
ns.PinBandBars()
Equal(totem.points[1][1] .. " " .. G(totem.points[1][4]) .. " " .. tostring(totem.systemInfo.anchorInfo == mine), "CENTER 100 true",
    "a moved totem bar stays where the player put it")
local hasTotem = false
for _, record in ipairs(ns.BandPinAnchors()) do hasTotem = hasTotem or record.name == "MultiCastActionBarFrame" end
Equal(hasTotem, false, "nor is it in the EraUI layout's anchors")
-- Back at its default (Edit Mode's Reset): EraUI's pin again at the next session end.
totem.default = true
ns.PinBandBars()
Equal(Look.PinnedByEraUI(totem) and totem.points[1][1] == "BOTTOMLEFT", true, "pinned again once it was back at its default")
Equal(#game.overrides .. " " .. #game.fightMoves, "0 0", "the totem bar only ever moved through its plain Base methods")
-- A pin moved by the player is the player's own (same points, other spot).
env.MultiBarRight.systemInfo.anchorInfo = { point = "RIGHT", relativeTo = "UIParent", relativePoint = "RIGHT", offsetX = -300, offsetY = 0 }
env.MultiBarRight.default = false
Equal(Look.PinnedByEraUI(env.MultiBarRight), false, "a point-to-same-point anchor that isn't the saved pin: the player's")
Equal(Look.Moved(env.MultiBarRight), true, "moved")
-- The anchor matching the saved pin within 0.5 counts as EraUI's.
env.MultiBarRight.systemInfo.anchorInfo = { point = "TOPRIGHT", relativeTo = "UIParent", relativePoint = "TOPRIGHT", offsetX = 0, offsetY = 0 }
ns.db.barPins.EraUI.MultiBarRight = { "TOPRIGHT", "TOPRIGHT", 0.3, -0.2 }
Equal(Look.PinnedByEraUI(env.MultiBarRight), true, "the saved pin, within 0.5")
-- Before pins were shaped, an old BOTTOM to BOTTOM anchor was EraUI's too.
env.MultiBarRight.systemInfo.anchorInfo = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 3, offsetY = 9 }
Equal(Look.PinnedByEraUI(env.MultiBarRight), false, "shaped: an old BOTTOM pin is no longer assumed")
ns.db.pinShape = false
Equal(Look.PinnedByEraUI(env.MultiBarRight), true, "before shaping: BOTTOM to BOTTOM was EraUI's")
ns.db.pinShape = true
-- The adopt job.
game.classicLayout = false
Equal(ns.AdoptBandBars(), 0, "not the EraUI layout: nothing adopted")
game.classicLayout = true
ns.db.barDragged = true
ns.sessionEnding = false
local resetsBefore = game.resets or 0
Equal(ns.AdoptBandBars(), 0, "not while the session goes on")
Equal((game.resets or 0) - resetsBefore, 0, "no Edit Mode reset mid-session")
ns.sessionEnding = true
Equal(ns.AdoptBandBars() > 0, true, "the EraUI layout: frames back to default")
Equal(ns.db.barDragged, false, "Action Bar 1 no longer dragged")
Equal(totem.default, false, "the band adopts its bars, not the totem bar: its pin stays")
-- Action Bars off: handed back once.
ns.db.classicBar = false
game.Pass()
for _, frame in ipairs({ env.MultiBarBottomLeft, env.MultiBarLeft, env.BagsBar }) do frame.default = false end
env.MultiBarBottomLeft.systemInfo.anchorInfo = { point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = -503, offsetY = 55 }
env.MultiBarLeft.systemInfo.anchorInfo = { point = "LEFT", relativeTo = "UIParent", relativePoint = "LEFT", offsetX = 20, offsetY = 0 }
env.BagsBar.systemInfo.anchorInfo = { point = "TOPLEFT", relativeTo = "UIParent", relativePoint = "TOPLEFT", offsetX = 20, offsetY = -20 }
game.classicLayout = false
local resets = game.resets or 0
ns.sessionEnding = false
Equal(ns.UnpinBandBars(), false, "not while the session goes on")
ns.sessionEnding = true
Equal(ns.UnpinBandBars(), true, "handed back as the session ends")
Equal((game.resets or 0) - resets, 2, "only EraUI's own pins go back to default (not the player's own places)")
Equal(env.MultiBarBottomLeft.default and totem.default and not env.MultiBarLeft.default and not env.BagsBar.default, true,
    "which ones: bar 2 and the totem bar")
Equal(ns.db.barPins.EraUI, nil, "this layout's pins forgotten")
Equal(tostring(ns.db.bandHandedBack) .. " " .. tostring(ns.db.barDragged), "true false", "handed back, not dragged")
game.classicLayout = true
Equal(ns.UnpinBandBars(), true, "in the EraUI layout every moved frame goes back")
Equal(env.MultiBarLeft.default and env.BagsBar.default, true, "the player's moves too, in EraUI's own layout")
-- The debug line.
Equal(ns.ClassicBarInfo():match("^art shown=false left=") ~= nil, true, "the debug line")

print("Band pin checks passed: " .. checks .. " assertions.")
