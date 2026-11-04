-- The Classic action bar band (Look/Band*.lua and friends), rewritten
-- clean-room on 2026-10-21 from Tools/ClassicSpecs/01-action-bars.md. On
-- Tools/LookMockGame.lua's mock of Forever's UI, whose Edit Mode frames record
-- any use of Edit Mode's own SetPoint, ClearAllPoints or SetScale overrides
-- (EraUI must use the plain ...Base methods) and any move made in a fight:
--   1. the band's shape: width and art slices for the main layouts
--   2. the drop decisions: near the band, which side, a gryphon held or moved
--   3. the micro menu's saved place and its text mirror
--   4. a full pass: every bar's place and size, the gryphons, page arrows,
--      micro menu, bags, XP strips, the cast bar's clearance, bars 6 to 8
--   5. One Bar, Default Bar Size, 10 icons, no page arrows, the menu away
--   6. Edit Mode: Action Bar 1 dragged and snapped home, a gryphon dropped
--      near and far, the menu dropped near and far, its size by the wheel
--   7. the game turning bar 6 on, the position keeper, a fight
--   8. turning the band off
local checks = 0
-- Whole numbers read the same with or without ".0" (Lua 5.3 prints floats so).
local function Whole(text) return (text:gsub("(%d)%.0+(%f[^%d])", "%1")) end
local function Equal(actual, expected, label)
    checks = checks + 1
    local same = actual == expected
        or (type(actual) == "string" and type(expected) == "string" and Whole(actual) == Whole(expected))
    if not same then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
local function Near(actual, expected, label, tolerance)
    checks = checks + 1
    if type(actual) ~= "number" or math.abs(actual - expected) > (tolerance or 0.01) then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end
-- Numbers as text the same in Lua 5.1 and 5.3 (no "1.0").
local function G(...)
    local out = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        out[i] = type(v) == "number" and string.format("%g", v) or tostring(v)
    end
    return table.concat(out, " ")
end
local function Point(frame, i)
    local p = frame.points[i or 1]
    if not p then return "none" end
    local relative = p[2] and (p[2].name or (p[2] == frame.parent and "parent") or "frame") or "nil"
    return string.format("%s %s %s %.1f %.1f", p[1], relative, p[3], p[4], p[5])
end

local Mock = dofile("Tools/LookMockGame.lua")

---------------------------------------------------------------------------
-- 1. The band's shape (pure arithmetic)
---------------------------------------------------------------------------
do
    local game = Mock.New()
    local Look = game.Load()
    local Shape = Look.Shape
    local function Slices(s)
        local out = {}
        for _, slice in ipairs(s.slices) do
            out[#out + 1] = string.format("%d@%d+%d[%d-%d]", slice.piece, slice.x, slice.width, slice.from, slice.to)
        end
        return table.concat(out, " ")
    end
    local all = Shape.Compute({ microOn = true, bagsOn = true, pages = true, icons = 12, microCount = 12 })
    Equal(all.width, 1024, "all on the band: 1024 wide")
    Equal(all.microX, 555, "the first micro button 43 in")
    Equal(all.bagsX, 842, "the bags after the micro region")
    Equal(Slices(all), "1@0+256[0-256] 2@256+256[0-256] 3@512+256[0-256] 4@768+74[0-74] 4@842+182[74-256] 4@1016+8[82-90]",
        "the 1.x pieces, the bag area and the post")
    Equal(Shape.Compute({ microOn = true, bagsOn = true, icons = 12, microCount = 11 }).width, 1022, "eleven buttons: 1022")
    local first = Shape.Compute({ microOn = true, bagsOn = true, bagsFirst = true, icons = 12, microCount = 12 })
    Equal(first.nookX .. " " .. first.bagsX .. " " .. first.microX .. " " .. first.width, "512 548 738 1023",
        "bags first: nook, bags, then the menu")
    Equal(Slices(first), "1@0+256[0-256] 2@256+256[0-256] 3@512+36[0-36] 4@548+182[74-256] 3@730+219[37-256] 4@949+74[0-74] 4@1015+8[82-90]",
        "bags first: the nook and the menu region from piece 3's column 37")
    local one = Shape.Compute({ microOn = false, bagsOn = false, icons = 12 })
    Equal(one.width, 548, "One Bar: the left half and the nook")
    Equal(Slices(one), "1@0+256[0-256] 2@256+256[0-256] 3@512+36[0-36] 4@540+8[82-90]", "One Bar's art")
    local bare = Shape.Compute({ microOn = true, bagsOn = true, pages = false, icons = 12, microCount = 12 })
    Equal(bare.microX .. " " .. bare.microEnd .. " " .. bare.width, "520 805 987", "no page arrows: the menu 8 in, 37 shorter")
    local ten = Shape.Compute({ microOn = true, bagsOn = true, icons = 10, microCount = 12 })
    Equal(ten.base .. " " .. ten.width, "428 940", "10 icons: 84 cut")
    local function Starts(text, prefix) return text:find(prefix, 1, true) == 1 end
    Equal(Starts(Slices(ten), "1@0+172[84-256] 2@172+256[0-256] "), true, "10 icons: piece 1 trimmed on its left")
    local three = Shape.Compute({ microOn = true, bagsOn = true, icons = 3, microCount = 12 })
    Equal(Starts(Slices(three), "2@0+134[122-256] 3@134"), true, "3 icons: only piece 2, trimmed")
    Equal(Shape.Compute({ microOn = false, bagsOn = true, icons = 12 }).width, 730, "the menu away: nook and bags")
    Equal(Shape.Compute({ microOn = true, bagsOn = true, icons = 99, microCount = 12 }).width, 1024, "odd icon counts count as 12")
    local region, fit = Shape.MicroFit(12, 1)
    Equal(region, 330, "twelve buttons fill the 330 cap")
    Near(fit, 280 / 303, "and shrink to fit")
    local small = { Shape.MicroFit(12, 0.5) }
    Equal(small[1], 190, "half size: a smaller region (45 + 140 + 5)")
    Near(small[2], 0.5 * 280 / 303, "half size: the fit times the size")
    Equal(Shape.MicroFit(0, 1), 53, "no buttons: the region's own ends")
end

---------------------------------------------------------------------------
-- 2. Drop decisions (pure)
---------------------------------------------------------------------------
do
    local game = Mock.New()
    local Shape = game.Load().Shape
    Equal(Shape.NearBand(10, 700, 0, 512, 1024, 48), true, "near: bottom within 48, middle over the right half")
    Equal(Shape.NearBand(60, 700, 0, 512, 1024, 48), false, "too high")
    Equal(Shape.NearBand(10, 460, 0, 512, 1024, 48), false, "left of the right half")
    Equal(Shape.NearBand(10, 470, 0, 512, 1024, 48), true, "48 past the right half's start still counts")
    Equal(Shape.NearBand(10, 1120, 0, 512, 1024, 48), true, "96 past the band's end still counts")
    Equal(Shape.NearBand(10, 1130, 0, 512, 1024, 48), false, "beyond that, not")
    Equal(Shape.NearBand(20, 700, 0, 512, 1024, 96), true, "the tolerance scales with the screen (96 at UI scale 2)")
    Equal(Shape.GoesFirst(700, 710, false), false, "not first: stays until clearly left of the line")
    Equal(Shape.GoesFirst(690, 710, false), true, "clearly left: goes first")
    Equal(Shape.GoesFirst(720, 710, true), true, "first: stays until clearly right")
    Equal(Shape.GoesFirst(730, 710, true), false, "clearly right: no longer first")
    Equal(Shape.CapHeld(100, 0, 120, 30, 48), true, "a gryphon within 48 both ways: held")
    Equal(Shape.CapHeld(100, 0, 160, 0, 48), false, "60 off: moved")
    Equal(Shape.CapHomeX(1024, "left") .. " " .. Shape.CapHomeX(1024, "right"), "-32 1056", "gryphon homes overlap the ends by 32")
end

---------------------------------------------------------------------------
-- 3. The micro menu's place and its text mirror
---------------------------------------------------------------------------
do
    local game = Mock.New()
    local Look = game.Load()
    local text = Look.EncodePlace({ "BOTTOMRIGHT", "BOTTOMRIGHT", -6.04, 12.36 })
    Equal(text, "BOTTOMRIGHT,BOTTOMRIGHT,-6.0,12.4", "the place as text, one decimal")
    local back = Look.DecodePlace(text)
    Equal(back[1] .. " " .. back[2], "BOTTOMRIGHT BOTTOMRIGHT", "and back")
    Near(back[3], -6, "x back")
    Near(back[4], 12.4, "y back")
    Equal(Look.DecodePlace("junk"), nil, "junk is no place")
    game.ns.db = { microPosText = "TOP,TOP,10.0,-20.5" }
    local place = Look.MicroPlace()
    Equal(place and place[1], "TOP", "a lost table comes back from its text"); Near(place and place[4], -20.5, "its y too")
    game.ns.db.microPos = { "LEFT", "LEFT", 1, 2 }
    Look.Save()
    Equal(game.ns.db.microPosText, "LEFT,LEFT,1.0,2.0", "a save writes the text from the table")
    Equal(game.saves, 1, "and the mirror")
    game.ns.db.microPos = nil
    game.ns.db.microPosText = ""
    Look.Save()
    Equal(game.ns.db.microPosText, "", "no place: empty text")
end

---------------------------------------------------------------------------
-- 4. A full pass
---------------------------------------------------------------------------
local function Session(options, setup)
    local game = Mock.New(options)
    local Look = game.Load()
    if setup then setup(game) end
    game.Login()
    game.Fire("PLAYER_ENTERING_WORLD")
    return game, Look, game.env
end

do
    local game, Look, env = Session()
    local band = env.EraUIClassicBar
    Equal(band ~= nil and Look.band.active, true, "the band is built and active")
    Equal(#game.overrides, 0, "no Edit Mode override used by EraUI (" .. table.concat(game.overrides, ", ") .. ")")
    Equal(band.width .. "x" .. band.height .. " " .. band.scale, "1022x53 1", "eleven menu buttons: 1022 wide, 53 tall")
    Equal(Point(band), "BOTTOMLEFT UIParent BOTTOM -511.0 0.0", "centred on the screen's bottom")
    Equal(band.strata .. " " .. band.level, "MEDIUM 1", "on its own layer")
    local main = env.MainActionBar
    Equal(Point(main) .. " " .. main.scale, "BOTTOMLEFT UIParent BOTTOM -503.0 4.0 1", "Action Bar 1 at band (8, 4), scale 1")
    Equal(main.BorderArt.alpha, 0, "its own art faded")
    local first, last = main.actionButtons[1].container, main.actionButtons[12].container
    Near(first.scale, 0.8, "36 / 45: classic 36-unit buttons")
    Equal(Point(last):sub(1, 10), "BOTTOMLEFT", "laid from the row's corner")
    Near(last.points[1][4], 11 * 42 * 45 / 36, "a 42-unit pitch, in the holder's own units")
    local l, _, r = last:Rect()
    Near(r - l, 36, "a button 36 wide on screen")
    Near(l, 1 + 8 + 11 * 42, "the twelfth at its slot")
    Equal(Point(env.MultiBarBottomLeft), "BOTTOMLEFT UIParent BOTTOM -503.0 55.0", "bar 2 above bar 1")
    Equal(Point(env.MultiBarBottomRight), "BOTTOMLEFT UIParent BOTTOM 9.0 55.0", "bar 3 over the right half")
    Equal(Point(env.MultiBarRight), "TOPRIGHT UIParent BOTTOMRIGHT -2.0 602.0", "bar 4 in its column")
    Equal(Point(env.MultiBarLeft), "TOPRIGHT UIParent BOTTOMRIGHT -44.0 602.0", "bar 5 beside it")
    Equal(Point(env.StanceBar), "BOTTOMLEFT UIParent BOTTOM -481.0 104.0", "the stance bar starts the small row")
    Near(env.StanceBar.actionButtons[1].container.scale, 30 / 45, "small 30-unit buttons")
    Equal(Point(env.PetActionBar), "BOTTOMLEFT UIParent BOTTOM -143.0 104.0", "the pet bar after the stance bar's 10 slots")
    Near(env.PetActionBar.actionButtons[10].container.scale, 30 / 45, "all ten pet buttons laid (no Num Icons setting)")
    Equal(env.MultiBar5.alpha .. " " .. tostring(env.MultiBar5Button1.mouse), "0 false", "bars 6 to 8 hidden, no clicks")
    local selection = env.MultiBarBottomLeft.Selection
    Equal(#selection.points, 2, "Edit Mode's selection pinned by two corners")
    local sl, sb, sr, st = selection:Rect()
    Near(sr - sl, 498, "over the bar's twelve buttons")
    Near(st - sb, 36, "one row tall")
    sl, _, sr = main.Selection:Rect()
    Near(sr - sl, 498 + 36, "Action Bar 1's box takes in the page arrows")
    -- Gryphons
    local caps = Look.band.caps
    Equal(caps.left.file, "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf", "the dwarf gryphons")
    Equal(caps.left:IsShown() and caps.right:IsShown(), true, "both shown")
    Equal(table.concat(caps.right.coords, ","), "1,0,0,1", "the right one mirrored")
    Equal(Point(env.LeftEndCap), "BOTTOM EraUIClassicBar BOTTOMLEFT -32.0 0.0", "Edit Mode's cap over the left home slot")
    Equal(Point(env.RightEndCap), "BOTTOM EraUIClassicBar BOTTOMLEFT 1054.0 0.0", "and the right")
    Equal(env.LeftEndCap.width .. " " .. env.LeftEndCap.Texture.alpha, "128 0", "128 square, the game's art faded")
    Equal(Point(caps.left), "BOTTOM LeftEndCap BOTTOM 0.0 0.0", "the gryphon rides its cap")
    Equal(caps.left.theme, "endCap", "Dark Mode's key")
    -- Art
    Equal(#Look.band.slices >= 6, true, "the band's art slices")
    Equal(Look.band.slices[1].file .. " " .. Look.band.slices[1].theme, "Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf barBody",
        "the dwarf sheet, darkened as barBody")
    -- Page arrows
    local pages = main.ActionBarPageNumber
    Equal(Point(pages) .. " " .. pages.strata .. " " .. pages.width, "CENTER EraUIClassicBar TOPLEFT 522.0 -32.0 HIGH 32",
        "the page frame in the nook")
    Equal(Point(pages.UpButton) .. " " .. pages.UpButton.width, "CENTER EraUIClassicBar TOPLEFT 522.0 -22.0 32", "the up arrow")
    Equal(Point(pages.DownButton), "CENTER EraUIClassicBar TOPLEFT 522.0 -42.0", "the down arrow")
    Equal(table.concat(pages.UpButton.insets, ","), "6,6,7,7", "a smaller hit area")
    Equal(pages.Text.fontObject .. " " .. Point(pages.Text), "GameFontNormalSmall CENTER EraUIClassicBar TOPLEFT 542.0 -31.5",
        "the page number beside them")
    Equal(pages.UpButton:GetNormalTexture().file, "Interface\\MainMenuBar\\UI-MainMenu-ScrollUpButton-Up", "1.x arrows")
    Equal(pages.UpButton:GetHighlightTexture().blend, "ADD", "an additive glow")
    -- Micro menu
    local list = Look.MicroList()
    local world = env.EraUIClassicWorldMapMicroButton
    local at
    for i, b in ipairs(list) do if b == world then at = i end end
    Equal(list[at - 1], env.QuestLogMicroButton, "the World Map button after the quest button")
    local character = env.CharacterMicroButton
    Equal(character.parent == band and character.width .. "x" .. character.height, "28x38", "on the band, 28 x 38")
    Equal(character:GetNormalTexture().file, "Interface\\Buttons\\UI-MicroButtonCharacter-Up", "the portrait shell")
    Near(character:GetNormalTexture().coords[3], 22 / 64, "the sheet's lower 42 rows")
    Equal(character.Portrait.width .. " " .. Point(character.Portrait), "18 TOP CharacterMicroButton TOP 0.0 -7.0", "the portrait inside")
    Equal(env.GuildMicroButton:GetNormalTexture().file, Look.MEDIA .. "UI-MicroButton-socials-up", "Socials from EraUI's copy")
    Equal(world:GetNormalTexture().file, Look.MEDIA .. "UI-MicroButton-World-up", "the World sheet")
    Equal(Point(character), "BOTTOMLEFT frame BOTTOMLEFT 7.0 2.5", "the first button 7 in, 2.5 up")
    Equal(Point(Look.MicroGroup()), "BOTTOMLEFT EraUIClassicBar BOTTOMLEFT 548.0 0.0", "the menu's group from the nook")
    Near(env.ProfessionMicroButton.points[1][4], 7 + 25, "25 apart")
    Equal(env.StoreMicroButton.alpha .. " " .. Point(env.StoreMicroButton), "0 TOPRIGHT UIParent BOTTOMLEFT -64.0 -64.0",
        "the shop never shows: unseen, parked off the screen (never unplaced: the game's micro menu reads its centre)")
    Equal(env.HousingMicroButton.parent, env.MicroMenu, "a hidden button stays the game's")
    Equal(Point(env.HousingMicroButton) .. " | " .. Point(env.EJMicroButton), "BOTTOMLEFT MicroMenu BOTTOMLEFT 160.0 0.0 | TOPRIGHT"
        .. " UIParent BOTTOMLEFT -64.0 -64.0", "a placed hidden button keeps its place; one never placed is parked off the"
        .. " screen, so the game's micro menu always reads a centre for its edge buttons")
    Equal(env.MicroMenu.BorderArt.alpha, 0, "the menu's own art faded")
    -- Bags
    local pack = env.MainMenuBarBackpackButton
    Equal(pack.parent == band and pack.width, 30, "the backpack on the band, 30 square")
    Equal(Point(env.BagsBar) .. " " .. env.BagsBar.width .. "x" .. env.BagsBar.height,
        "BOTTOMRIGHT UIParent BOTTOM 507.0 1.5 181x39", "the bag bar over the bag area")
    Equal(Point(pack), "BOTTOMRIGHT BagsBar BOTTOMRIGHT 0.0 4.5", "the buttons hang from it")
    local _, pb, pr = pack:Rect()
    Near(pr, 1 + 840 + 178, "the backpack's right edge at band (bag start + 178)")
    Near(pb, 6, "6 up")
    Equal(pack.icon.file .. " " .. pack.FreeSlots.fontObject .. " " .. pack.Count.alpha,
        "Interface\\Buttons\\Button-Backpack-Up NumberFontNormalSmall 0", "the 1.x backpack, its free slots small, the ammo count hidden")
    Equal(Point(env.CharacterBag0Slot), "BOTTOMRIGHT MainMenuBarBackpackButton BOTTOMLEFT -2.0 0.0", "the bags 2 apart")
    Equal(env.CharacterBag1Slot.icon.file .. " " .. env.CharacterBag1Slot.icon.alpha .. " " .. tostring(env.CharacterBag1Slot.icon.desaturated),
        "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag 0.5 true", "an empty bag slot: the faded slot icon")
    local ring = env.KeyRingButton
    Equal(ring.width .. "x" .. ring.height .. " " .. Point(ring), "18x39 RIGHT CharacterBag3Slot LEFT -5.0 0.0", "the key ring, slim")
    Equal(ring:GetNormalTexture().file, "Interface\\Buttons\\UI-Button-KeyRing", "in its 1.x art")
    local reagent = env.CharacterReagentBag0Slot
    Equal(reagent.width .. " " .. Point(reagent) .. " " .. reagent.IconBorder.file,
        "17 CENTER CharacterBag3Slot LEFT -2.0 0.0 Interface\\Minimap\\MiniMap-TrackingBorder", "the reagent bag small and round")
    Equal(env.BagBarExpandToggle.shown, false, "no expand toggle")
    Equal(Look.band.bagFloor == nil or not Look.band.bagFloor.shown, true, "no floating floor on the band")
    -- XP strips
    local xp = env.MainStatusTrackingBarContainer
    Equal(Point(xp) .. " " .. xp.width .. "x" .. xp.height, "TOP EraUIClassicBar TOP 0.0 -1.0 1018x10", "the XP strip along the band's top")
    local gauge = xp.bars[1].StatusBar
    Equal(gauge.barFile, Look.MEDIA .. "UI-StatusBar-Flat.tga", "a flat fill (the bundled .tga)")
    Equal(table.concat(gauge.barColor, ","), "0.58,0,0.55", "purple")
    Equal(xp.BarFrameTexture.alpha, 0, "the game's frame faded")
    Equal(Look.band.maxShown, false, "no max-level cap while XP shows")
    Equal(game.ns.bandPasses >= 1, true, "the pass counted")
    -- Cast bar
    local cast = env.PlayerCastingBarFrame
    game.Native(function() cast:Show() end)
    Look.PlaceCastBar()
    Equal(Point(cast), "BOTTOM UIParent BOTTOM 0.0 160.0", "the cast bar 26 over the pet row (top 134)")
    Equal(#game.overrides, 0, "still no Edit Mode override")
end

---------------------------------------------------------------------------
-- 5. Settings that change the shape
---------------------------------------------------------------------------
do
    local game, Look, env = Session(nil, function(g) g.ns.db.oneBar = true end)
    local band = env.EraUIClassicBar
    Equal(band.width, 548, "One Bar: the band stops after the page arrows")
    Equal(Point(env.MultiBarBottomRight), "BOTTOMLEFT UIParent BOTTOM -266.0 97.0", "bar 3 over bar 2")
    Equal(Point(env.StanceBar), "BOTTOMLEFT UIParent BOTTOM -244.0 146.0", "the small row 42 higher")
    Equal(Point(Look.MicroGroup()), "BOTTOMRIGHT UIParent BOTTOMRIGHT -6.0 0.0", "the menu in the corner")
    Equal(Look.MicroGroup().width, 328 - 36, "in its own tray")
    Equal(Point(env.BagsBar), "BOTTOMRIGHT UIParent BOTTOMRIGHT -10.0 49.0", "the bags on top of it")
    Equal(Look.band.bagFloor and Look.band.bagFloor.shown, true, "on their own floor")
    Equal(Point(Look.band.bagFloor), "BOTTOMRIGHT MainMenuBarBackpackButton BOTTOMRIGHT 4.0 -6.0", "under the backpack")
    Equal(#game.overrides, 0, "One Bar: no Edit Mode override")
end
do
    local game, Look, env = Session(nil, function(g) g.ns.db.defaultBarSize = true end)
    Near(env.EraUIClassicBar.scale, 1.25, "Default Bar Size: the band 45/36 larger")
    Near(env.MainActionBar.actionButtons[1].container.scale, 1, "buttons at the game's 45")
    Equal(Point(env.MainActionBar), "BOTTOMLEFT UIParent BOTTOM -628.8 5.0", "Action Bar 1 scaled with it")
end
do
    local _, _, env = Session(nil, function(g) g.env.MainActionBar.settings[2] = 10 end)
    Equal(env.EraUIClassicBar.width, 1022 - 84, "10 icons: 84 shorter")
    Equal(env.MainActionBar.actionButtons[1].container.shown, true, "the shown buttons laid")
end
do
    local _, _, env = Session(nil, function(g) g.env.MainActionBar.settings[5] = 1 end)
    Equal(env.EraUIClassicBar.width, 512 + 291 + 182, "no page arrows: the menu region 37 shorter")
    Equal(env.MainActionBar.ActionBarPageNumber.shown, false, "the page frame hidden")
end
do
    local _, Look, env = Session(nil, function(g) g.ns.db.microPos = { "CENTER", "CENTER", 100, 50 } end)
    Equal(env.EraUIClassicBar.width, 730, "the menu dropped away: nook and bags")
    Equal(Point(Look.MicroGroup()), "CENTER UIParent CENTER 100.0 50.0", "the menu where it was dropped")
    Equal(Look.band.shape.bagsX, 548, "the bags right after the nook")
end
do
    local _, Look, env = Session(nil, function(g) g.ns.db.bagsFirst = true end)
    Equal(Look.band.shape.bagsX .. " " .. Look.band.shape.microX, "548 738", "bags first")
    Equal(Look.band.shape.width, 1021, "bags first: the menu region last")
    Equal(Point(env.BagsBar), "BOTTOMRIGHT UIParent BOTTOM 215.5 1.5", "the bag bar follows")
end
do
    -- Edit Mode not set up yet at the first pass (every setting reads 0, no
    -- frame is "default"): no reason to call a bar or the bags moved.
    local _, Look, env = Session(nil, function(g)
        for _, name in ipairs({ "MainActionBar", "MultiBarBottomLeft", "BagsBar" }) do
            g.env[name].uninitialized, g.env[name].systemInfo = true, nil
        end
    end)
    Equal(Point(env.MultiBarBottomLeft), "BOTTOMLEFT UIParent BOTTOM -503.0 55.0", "a bar Edit Mode hasn't set up: on the band")
    Equal(Look.band.shape.bagsOn and Look.band.shape.width, 1022, "the bags too, and the full band")
    Near(env.MainActionBar.actionButtons[12].container.scale, 0.8, "all twelve of Action Bar 1's buttons laid")
end
do
    local game, _, env = Session()
    local main, band = env.MainActionBar, env.EraUIClassicBar
    game.ns.db.barDragged = true
    main.default = false
    main.systemInfo.anchorInfo = { point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", offsetX = 100, offsetY = 300 }
    game.Native(function()
        main:ClearAllPoints()
        main:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 100, 300)
    end)
    game.Tick(0.3)
    Equal(Point(band), "BOTTOMLEFT MainActionBar BOTTOMLEFT -8.0 -4.0", "dragged away: the band stays with Action Bar 1")
    main.default = true -- Edit Mode's Reset To Default Position
    game.Tick(0.3)
    Equal(game.ns.db.barDragged, false, "Edit Mode has it at its default again: no longer dragged")
    Equal(Point(band), "BOTTOMLEFT UIParent BOTTOM -511.0 0.0", "and the band home")
end
do
    local _, Look, env = Session({ reputation = true })
    Equal(Look.band.lift, 9, "both strips: the bars above lift 9")
    Equal(Point(env.MultiBarBottomLeft), "BOTTOMLEFT UIParent BOTTOM -503.0 64.0", "bar 2 lifted")
    Equal(Point(env.SecondaryStatusTrackingBarContainer), "BOTTOM EraUIClassicBar TOP 0.0 2.0", "the reputation strip above the band")
    Equal(table.concat(env.SecondaryStatusTrackingBarContainer.bars[1].StatusBar.barColor, ","), "0,0.6,0.1", "reputation green")
end

---------------------------------------------------------------------------
-- 6. Edit Mode
---------------------------------------------------------------------------
do
    local game, Look, env = Session()
    local main, band = env.MainActionBar, env.EraUIClassicBar
    -- Edit Mode moving a frame: its anchor, and its layout record as Edit
    -- Mode writes it when the drag ends.
    local function EditDrag(frame, x, y)
        game.Native(function()
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", x, y)
        end)
        frame.systemInfo.anchorInfo = { point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT",
            offsetX = x, offsetY = y }
        frame.default = false
    end
    game.editing = true
    game.Tick(0.1)
    -- Action Bar 1 dragged far: the band follows, then stays.
    game.mouseDown = true
    main.isDragging = true
    EditDrag(main, 100, 300)
    game.Tick(0.2)
    Equal(Point(band), "BOTTOMLEFT MainActionBar BOTTOMLEFT -8.0 -4.0", "while dragged, the band rides along")
    main.isDragging = false
    game.mouseDown = false
    game.Tick(0.05)
    Equal(game.ns.db.barDragged, true, "let go far from home: dragged")
    Equal(Point(band), "BOTTOMLEFT MainActionBar BOTTOMLEFT -8.0 -4.0", "the band stays with it")
    Equal(#game.overrides, 0, "no Edit Mode override while dragging")
    -- Back near home: snapped home.
    game.mouseDown = true
    main.isDragging = true
    EditDrag(main, 40, 30)
    game.Tick(0.1)
    main.isDragging = false
    game.mouseDown = false
    game.Tick(0.05)
    Equal(game.ns.db.barDragged, false, "let go within 40 of home: snapped home")
    Equal(Point(band), "BOTTOMLEFT UIParent BOTTOM -511.0 0.0", "the band home again")
    -- A gryphon dropped far, then near.
    local cap = env.LeftEndCap
    game.mouseDown = true
    cap.isDragging = true
    EditDrag(cap, 400, 400)
    game.Tick(0.1)
    cap.isDragging = false
    game.mouseDown = false
    game.Tick(0.05)
    Equal(game.ns.db.capMoved and game.ns.db.capMoved.LeftEndCap, true, "a gryphon dropped far: moved")
    Equal(Point(cap), "BOTTOMLEFT UIParent BOTTOMLEFT 400.0 400.0", "it stays where Edit Mode put it")
    game.mouseDown = true
    cap.isDragging = true
    EditDrag(cap, -50, 10)
    game.Tick(0.1)
    cap.isDragging = false
    game.mouseDown = false
    game.Tick(0.05)
    Equal(game.ns.db.capHeldLeft, true, "dropped near its slot: held")
    Equal(game.ns.db.capMoved.LeftEndCap, nil, "no longer moved")
    Equal(Point(cap), "BOTTOM EraUIClassicBar BOTTOMLEFT -32.0 0.0", "back over its home slot")
    -- Edit Mode's Reset To Default Position: the game re-anchors it.
    game.Native(function()
        cap:ClearAllPoints()
        cap:SetPoint("RIGHT", main, "LEFT", 0, 0)
    end)
    cap.default = true
    game.Tick(0.3)
    Equal(game.ns.db.capHeldLeft, false, "Edit Mode's default place clears the flags")
    Equal(Point(cap), "BOTTOM EraUIClassicBar BOTTOMLEFT -32.0 0.0", "and the band takes the cap back")
    -- The micro menu's handle.
    game.Tick(0.3)
    local group = Look.MicroGroup()
    local grip
    for _, child in ipairs(group.children) do if child.level == 1010 then grip = child end end
    Equal(grip ~= nil and grip.shown, true, "the menu's handle shows in Edit Mode")
    grip.scripts.OnDragStart(grip)
    group:ClearAllPoints()
    group:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 200, 400)
    grip.scripts.OnDragStop(grip)
    local place = game.ns.db.microPos
    Equal(place and place[1] .. " " .. place[3] .. " " .. place[4], "BOTTOMLEFT 200 400", "dropped far: its place kept")
    Equal(game.ns.db.microPosText, "BOTTOMLEFT,BOTTOMLEFT,200.0,400.0", "and its text mirror")
    game.Tick(0.1)
    Equal(band.width, 730, "the band without the menu")
    Equal(Point(group), "BOTTOMLEFT UIParent BOTTOMLEFT 200.0 400.0", "the menu where it was dropped")
    Equal(env.EditModeManagerFrame.SaveChangesButton.enabled and env.EditModeManagerFrame.RevertAllChangesButton.enabled, true,
        "Edit Mode's Save and Revert usable for the change")
    grip.scripts.OnMouseWheel(grip, 1)
    Near(game.ns.db.microScale, 1.05, "the wheel sizes it")
    grip.scripts.OnDragStart(grip)
    group:ClearAllPoints()
    group:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 560, 5)
    grip.scripts.OnDragStop(grip)
    Equal(game.ns.db.microPos, nil, "dropped near the band: back on it")
    game.Tick(0.1)
    Equal(band.width, 1022, "the band takes the menu again")
    Equal(Point(group), "BOTTOMLEFT EraUIClassicBar BOTTOMLEFT 548.0 0.0", "the menu in its region")
    Equal(game.ns.db.microScale, nil, "dropped on the band: its own size cleared too")
    grip.scripts.OnMouseWheel(grip, -1)
    Near(game.ns.db.microScale, 0.95, "a notch smaller")
    -- A click opens its dialog.
    grip.scripts.OnMouseDown(grip)
    grip.scripts.OnMouseUp(grip, "LeftButton")
    local dialog
    for _, frame in ipairs(game.frames) do
        if frame.width == 383 and frame.height == 204 then dialog = frame end
    end
    Equal(dialog ~= nil and dialog.shown and dialog.strata, "DIALOG", "the Micro Menu dialog")
    Equal(Point(dialog), "BOTTOM frame TOP 0.0 40.0", "40 above the menu")
    local buttons, closer = {}, nil
    for _, child in ipairs(dialog.children) do
        if child.template == "UIPanelButtonTemplate" then buttons[#buttons + 1] = child end
        if child.template == "UIPanelCloseButton" then closer = child end
    end
    Equal(#buttons .. " " .. tostring(buttons[1].darkened and buttons[2].darkened and closer.darkened), "2 true",
        "two reset buttons and a close button, handed to Dark Windows")
    Equal(tostring(buttons[1].enabled) .. " " .. tostring(buttons[2].enabled), "false true",
        "no place to reset; a size to reset")
    -- Edit Mode's Revert puts back the menu as it was before the session's first change.
    for _, hook in ipairs(env.EditModeManagerFrame.RevertAllChangesButton.scriptHooks.OnClick or {}) do
        hook(env.EditModeManagerFrame.RevertAllChangesButton)
    end
    Equal(game.ns.db.microScale, nil, "Revert: the size as it was")
    -- Leaving Edit Mode.
    game.editing = false
    game.Tick(0.3)
    Equal(grip.shown or dialog.shown, false, "out of Edit Mode: no handle, no dialog")
    Equal(#game.overrides, 0, "Edit Mode moves made no use of Edit Mode's overrides")
end

do
    -- The bag bar dragged off the band in Edit Mode, then dropped back (10.5).
    local game, Look, env = Session()
    local bags, band = env.BagsBar, env.EraUIClassicBar
    local function Drag(x, y)
        game.mouseDown = true
        bags.isDragging = true
        game.Native(function()
            bags:ClearAllPoints()
            bags:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", x, y)
        end)
        bags.systemInfo.anchorInfo = { point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT",
            offsetX = x, offsetY = y }
        bags.default = false
        game.Tick(0.1)
        bags.isDragging = false
        game.mouseDown = false
        game.Tick(0.1)
    end
    game.editing = true
    game.Tick(0.1)
    Drag(100, 400)
    Equal(tostring(game.ns.db.bagsHeld) .. " " .. G(game.ns.db.bagsSnapScale), "false 0", "dropped far: not held")
    Equal(band.width, 512 + 328, "the band without the bags (eleven menu buttons: a 328 region)")
    Equal(Look.band.bagFloor and Look.band.bagFloor.shown, true, "the bags on their own floor")
    Equal(Point(env.MainMenuBarBackpackButton), "BOTTOMRIGHT BagsBar BOTTOMRIGHT 0.0 4.5", "the buttons ride the bag bar")
    Drag(900, 5)
    Equal(tostring(game.ns.db.bagsHeld) .. " " .. G(game.ns.db.bagsSnapScale), "true 1", "dropped near the band: held, its size kept")
    Equal(game.ns.db.bagsFirst, false, "right of the line: after the micro menu")
    Equal(band.width, 1022, "the band takes the bags again")
    Equal(Look.band.bagFloor.shown, false, "no floor on the band")
    Equal(#game.overrides, 0, "the bag drop made no use of Edit Mode's overrides")
end
do
    -- The gryphons: the setting, and Edit Mode's own Hidden for each end cap.
    local game, Look, env = Session()
    local caps = Look.band.caps
    env.LeftEndCap.settings[0] = 1
    game.Tick(0.3)
    Equal(tostring(caps.left.shown) .. " " .. tostring(caps.right.shown), "false true", "an end cap Hidden in Edit Mode: its gryphon gone")
    game.settings.gryphons = false
    game.Tick(0.3)
    Equal(caps.left.shown or caps.right.shown, false, "Gryphons off: both gone")
end

---------------------------------------------------------------------------
-- 7. The game's bars 6 to 8, the position keeper, a fight
---------------------------------------------------------------------------
do
    local game, _, env = Session()
    local saves = game.saves
    game.settingsValues.PROXY_SHOW_ACTIONBAR_6 = true
    env.MultiActionBar_Update()
    Equal(game.ns.db.hideExtraBars, false, "bar 6 turned on in the game's settings: Hide Extra Bars off")
    Equal(env.MultiBar5.alpha .. " " .. tostring(env.MultiBar5Button1.mouse), "1 true", "the bars back, clicks too")
    Equal(game.optionsRefreshed .. " " .. tostring(game.saves > saves), "1 true", "the option list refreshed, saved")
    -- The client moves a bar by itself (a target change): put back.
    local bar2 = env.MultiBarBottomLeft
    game.Native(function()
        bar2:ClearAllPoints()
        bar2:SetPoint("BOTTOM", env.UIParent, "BOTTOM", 0, 200)
    end)
    game.Fire("PLAYER_TARGET_CHANGED")
    Equal(Point(bar2), "BOTTOMLEFT UIParent BOTTOM -503.0 55.0", "a target change: the bar put back at once")
    -- In a fight: the bar waits; unprotected bag buttons are put back.
    game.combat = true
    game.Fire("PLAYER_REGEN_DISABLED")
    game.Native(function()
        bar2:ClearAllPoints()
        bar2:SetPoint("BOTTOM", env.UIParent, "BOTTOM", 0, 200)
        env.MainMenuBarBackpackButton:ClearAllPoints()
        env.MainMenuBarBackpackButton:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
    end)
    game.Fire("PLAYER_FOCUS_CHANGED")
    game.Tick(0.3)
    Equal(Point(bar2), "BOTTOM UIParent BOTTOM 0.0 200.0", "in a fight the bar is left alone")
    Equal(Point(env.MainMenuBarBackpackButton), "BOTTOMRIGHT BagsBar BOTTOMRIGHT 0.0 4.5", "the backpack put back")
    Equal(#game.fightMoves, 0, "no Edit Mode frame moved in a fight (" .. table.concat(game.fightMoves, ", ") .. ")")
    Equal(env.MultiBarBottomLeft.Selection.mouse, false, "the band's selections take no mouse in a fight")
    game.combat = false
    game.Fire("PLAYER_REGEN_ENABLED")
    game.Tick(0.2)
    Equal(Point(bar2), "BOTTOMLEFT UIParent BOTTOM -503.0 55.0", "after the fight: put back")
    Equal(env.MultiBarBottomLeft.Selection.mouse, true, "selections take the mouse again")
    -- A bar the player moved in Edit Mode keeps its place, 36/42 sizing on.
    bar2.systemInfo.anchorInfo = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", offsetX = 0, offsetY = 0 }
    bar2.default = false
    game.Native(function()
        bar2:ClearAllPoints()
        bar2:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
    end)
    game.Tick(0.2)
    Equal(Point(bar2), "CENTER UIParent CENTER 0.0 0.0", "moved in Edit Mode: where Edit Mode put it")
    Equal(Point(game.Look.rows[bar2]), "BOTTOMLEFT MultiBarBottomLeft BOTTOMLEFT 0.0 0.0", "its buttons ride the bar")
    Near(bar2.actionButtons[1].container.scale, 0.8, "still classic 36-unit buttons")
    Equal(#game.overrides, 0, "the keeper made no use of Edit Mode's overrides")
end

---------------------------------------------------------------------------
-- 8. Turning the band off
---------------------------------------------------------------------------
do
    local game, Look, env = Session()
    game.ns.db.classicBar = false
    game.Pass()
    Equal(env.EraUIClassicBar.shown, false, "the band hidden")
    Equal(Look.band.active, false, "and inactive")
    Equal(game.ns.needsReload, true, "a reload clears the rest")
    Near(env.MainActionBar.actionButtons[1].container.scale, 1, "the buttons' own scale back")
    Equal(env.CharacterMicroButton.parent, env.MicroMenu, "the micro buttons back with the menu")
    Equal(env.CharacterMicroButton:GetNormalTexture().atlas, "UI-HUD-MicroMenu-Character-Up", "in the game's art")
    Equal(env.MainMenuBarBackpackButton.parent, env.BagsBar, "the bags back on the bag bar")
    Equal(env.MainMenuBarBackpackButton.FreeSlots.fontObject, "NumberFontNormal", "the free-slot number in the game's font")
    Equal(env.MultiBar5.alpha, 1, "bars 6 to 8 back")
    local pages = env.MainActionBar.ActionBarPageNumber
    Equal(pages.scale .. " " .. pages.UpButton.width .. "x" .. pages.UpButton.height, "1 17x14", "the page arrows at the game's size")
    Equal(pages.UpButton:GetNormalTexture().atlas, "ui-hud-actionbar-pageuparrow-up", "in the game's art")
    Equal(env.EraUIClassicWorldMapMicroButton.shown, false, "the World Map button hidden")
    Equal(env.MainStatusTrackingBarContainer.BarFrameTexture.alpha, 1, "the XP strip's frame back")
    Equal(#game.overrides, 0, "the restore made no use of Edit Mode's overrides")
    game.Pass()
    Equal(game.ns.bandPasses, 1, "while off, a pass lays nothing")
end

print("Classic band checks passed: " .. checks .. " assertions.")
