-- The Classic character window (Look/Char*.lua, registry "characterSheet",
-- clean-room 2026-10-21) on Tools/CharMockGame.lua, a mock of Forever's
-- CharacterFrame whose own objects are sealed: a key EraUI wrote on any of
-- them fails the run.
-- Checked: the 384 x 512 window after the game's UpdateSize, its faded art,
-- the 1.x art and rings, portrait, title and level line (a secret level, a
-- ding), the red X; the slot columns and weapon row; the model, its camera fit
-- and rotate buttons; the 1.x stat boxes by the bonus rule and the
-- resistances (Forever only); the bottom tabs over the game's own; the side
-- pane muted and unmuted, the hit inset and the CVar; the list skins, the
-- skill detail pane, the reputation box, the currency box (the game's own
-- detail and Show on Backpack tick in a 1.x box) and the equipment pane; turning the
-- window off and on; a fight; EraUIClassic_CharacterSheetSize and
-- EraUIClassic_SkinCharacterCopy. No GameTooltip, no error.
-- Run: fengari Tools/TestCharacterSheet.lua
local Mock = dofile("Tools/CharMockGame.lua")
local SECRET, Strip = Mock.SECRET, Mock.Strip
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
local function Near(actual, expected, label)
    checks = checks + 1
    if type(actual) ~= "number" or math.abs(actual - expected) > 1e-6 then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end
local function True(value, label) Equal(value and true or false, true, label) end

local function Session(opts)
    opts = opts or {}
    local game = Mock.New(opts)
    local C = game.Load()
    local tips = {}
    local realTip = game.Look.ShowTip
    game.Look.ShowTip = function(owner, side, rows)
        tips[#tips + 1] = rows
        return realTip(owner, side, rows)
    end
    local s = { game = game, C = C, env = game.env, sheet = game.env.CharacterFrame, paper = game.env.PaperDollFrame, tips = tips }
    -- Where a region sits from the window's top-left (x right, y up).
    function s.Spot(obj, corner)
        local sheet = s.sheet
        if corner == "BOTTOMLEFT" then return obj:GetLeft() - sheet:GetLeft(), obj:GetBottom() - sheet:GetTop() end
        return obj:GetLeft() - sheet:GetLeft(), obj:GetTop() - sheet:GetTop()
    end
    function s.Clean(label)
        Equal(#game.errors, 0, label .. ": nothing reached the error handler (" .. tostring(game.errors[1]) .. ")")
        Equal(game.gameTips, 0, label .. ": the game's tooltip was never asked for")
    end
    function s.State(obj) return game.State(obj) end
    return s
end

---------------------------------------------------------------------------
-- The window, its art, portrait, title and close button
---------------------------------------------------------------------------
do
    local s = Session()
    local game, env, sheet, paper, C = s.game, s.env, s.sheet, s.paper, s.C
    Equal(C.built, false, "nothing is built before the first pass")
    game.Pass()
    game.Open("PaperDollFrame")
    Equal(env.EraUIClassic_CharacterSheetActive, true, "the public flag is on")
    Near(sheet:GetWidth(), 384, "the window is 384 wide after the game's UpdateSize")
    Near(sheet:GetHeight(), 512, "and 512 tall")
    for _, key in ipairs({ "NineSlice", "Bg", "TopTileStreaks", "Inset", "InsetRight" }) do Equal(sheet[key]:GetAlpha(), 0, key .. " faded") end
    for _, key in ipairs({ "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight", "BackgroundOverlay" }) do
        Equal(env.CharacterModelScene[key]:GetAlpha(), 0, "the model's " .. key .. " faded")
    end
    Equal(env.CharacterModelScene.GearEnchantAnimation:GetAlpha(), 0, "the enchant swirl faded (not in 1.x)")
    Equal(paper.BackgroundTopLeft:GetAlpha(), 0, "the paper doll's own backdrop faded")
    Equal(paper.TopBackgroundStripHost:GetAlpha(), 0, "Forever's grey level-line strip faded (it ran across the 1.x art)")
    Equal(select(1, sheet.LeftPaneHost:GetRegions()):GetAlpha(), 0, "the left pane's art faded")
    Equal(sheet.RightPaneHost:GetAlpha(), 0, "the right pane faded")
    Equal(sheet.RightPaneToggleButton:GetAlpha(), 0, "the expand arrow faded")
    Equal(sheet.RightPaneToggleButton:IsMouseEnabled(), false, "and click-through")
    Equal(sheet.ModeTabs:GetAlpha(), 0, "the side tabs invisible")
    Equal(sheet.ModeTabs:IsMouseEnabled(), false, "their holder click-through")
    local x, y = s.Spot(sheet.LeftPaneHost)
    Near(x, 6, "the left pane from (6, -60)")
    Near(y, -60, "the left pane from (6, -60), y")
    Near(sheet.LeftPaneHost:GetRight() - sheet:GetLeft(), 378, "to (-6, 82): right")
    -- The 1.x art: general on the window, the Character tab's on the paper doll.
    local files = {}
    for set, owner in pairs({ general = sheet, tab = paper }) do
        for i, texture in ipairs(C.sheetArt[set]) do
            Equal(texture:GetParent(), owner, set .. " art piece " .. i .. " drawn on its frame")
            local layer, sub = texture:GetDrawLayer()
            Equal(layer, "BACKGROUND", set .. " piece " .. i .. " in the background")
            Equal(sub, set == "general" and -2 or -1, set .. " piece " .. i .. " sub-level")
            Near(texture:GetWidth(), i % 2 == 1 and 256 or 128, set .. " piece " .. i .. " width")
            Near(texture:GetHeight(), 256, set .. " piece " .. i .. " height")
            files[#files + 1] = texture:GetTexture()
        end
    end
    True(table.concat(files, " "):find("UI%-Character%-General%-TopLeft"), "the general art's files")
    True(table.concat(files, " "):find("UI%-Character%-CharacterTab%-L1"), "the Character tab art's files")
    local x4, y4 = s.Spot(C.sheetArt.general[4])
    Near(x4, 256, "the bottom-right piece at x 256")
    Near(y4, -256, "and y -256")
    Equal(s.State(C.sheetArt.general[1]).theme, "charGeneralTopLeft", "the art goes through Dark Mode's theme under its key")
    -- The rings over the portrait.
    local holder = sheet.PortraitContainer
    Equal(C.rings.general:GetFrameLevel(), holder:GetFrameLevel() + 1, "the general ring above the portrait")
    Equal(C.rings.tab:GetFrameLevel(), holder:GetFrameLevel() + 2, "the Character tab ring above that")
    Equal(C.rings.tab:GetParent(), paper, "the tab ring shows only with the paper doll")
    local face = select(1, C.rings.general:GetRegions())
    Equal(table.concat(s.State(face).coords, ","), "0," .. 80 / 256 .. ",0," .. 73 / 256, "the ring is the art's top-left 80 x 73")
    Near(C.rings.general:GetWidth(), 80, "ring width")
    -- Portrait: 62 x 62 at (9, -6), an icon cropped 10%.
    local portrait = holder.portrait
    Near(portrait:GetWidth(), 62, "portrait size")
    local px, py = s.Spot(portrait)
    Near(px, 9, "portrait x")
    Near(py, -6, "portrait y")
    Equal(table.concat(s.State(portrait).coords, ","), "0.1,0.9,0.1,0.9", "an icon portrait loses its border")
    portrait:SetTexture("portrait-face")
    portrait:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    game.Tick(0.1)
    Equal(table.concat(s.State(portrait).coords, ","), "0,1,0,1", "EraUI's crop comes off a face")
    -- Title and level line.
    local title = sheet.TitleContainer.TitleText
    Equal(title:GetText(), "Squirt Gutterson", "the title's text is the game's")
    Equal(s.State(title).font, env.GameFontNormal, "the title re-fonted")
    Equal(C.levelLine:GetText(), "Level 12 Human Rogue", "the level line")
    Equal(select(2, C.levelLine:GetPoint(1)), title, "under the title")
    -- The name in the art's top band, clear of the line under it (at 24
    -- down it sat on that line); the level line where it was.
    local _, onto, at, x, y = title:GetPoint(1)
    Equal(table.concat({ tostring(onto == sheet), at, x, y }, " "), "true TOP 6 -19", "the name up in the top band")
    local _, _, _, lx, ly = C.levelLine:GetPoint(1)
    Equal(lx .. " " .. ly, "0 -11", "the level line still 43 down")
    Equal(env.CharacterLevelText:GetAlpha(), 0, "the game's level text faded")
    game.level = 13
    env.CharacterLevelText:SetAlpha(1)
    game.Fire("UNIT_LEVEL", "player")
    Equal(C.levelLine:GetText(), "Level 13 Human Rogue", "a ding shows at once")
    Equal(env.CharacterLevelText:GetAlpha(), 0, "the game's level text faded again")
    game.level = SECRET
    game.Fire("UNIT_LEVEL", "target")
    Equal(C.levelLine:GetText(), "Level  Human Rogue", "a secret level is written empty (any unit's UNIT_LEVEL)")
    game.level = 13
    -- The red X.
    local close = sheet.CloseButton
    local cx, cy = close:GetCenter()
    Near(cx - sheet:GetLeft(), 384 - 44, "the X centred at (-44, -25) from the top right")
    Near(cy - sheet:GetTop(), -25, "the X's y")
    Near(close:GetWidth(), 32, "the X is 32 x 32")
    True(close:GetNormalTexture():GetTexture():find("UI%-Panel%-MinimizeButton%-Up"), "in the 1.x art")
    Equal(close:GetHighlightTexture():GetBlendMode(), "ADD", "its glow additive")
    local darkened = false
    for _, entry in ipairs(game.darkened) do if entry[1] == "DarkCloseButton" and entry[2] == close then darkened = true end end
    True(darkened, "the X handed to Dark Windows")
    s.Clean("window")
end

---------------------------------------------------------------------------
-- Slots, model, camera, rotate buttons
---------------------------------------------------------------------------
do
    local s = Session()
    local game, env, sheet, paper, C = s.game, s.env, s.sheet, s.paper, s.C
    game.Pass()
    game.Open("PaperDollFrame")
    local function Column(names, x, label)
        for i, short in ipairs(names) do
            local slot = env["Character" .. short .. "Slot"]
            local sx, sy = s.Spot(slot)
            Near(sx, x, label .. " " .. short .. " x")
            Near(sy, -74 - (i - 1) * 41, label .. " " .. short .. " y (4 below the last)")
            Equal(env["Character" .. short .. "SlotFrame"]:GetAlpha(), 0, short .. "'s gear-slot art faded")
            Equal(slot.BorderFrame:GetAlpha(), 0, short .. "'s border faded")
            Equal(slot:GetAlpha(), 1, short .. " itself is never faded")
            Equal(slot:GetParent(), env.PaperDollItemsFrame, short .. " is never re-parented")
            Equal(slot:GetScale(), 1, short .. " is never rescaled")
        end
    end
    Column({ "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" }, 21, "left")
    Column({ "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" }, 306, "right")
    local mx, my = s.Spot(env.CharacterMainHandSlot)
    Near(mx, 122, "main hand x")
    Near(my, -512 + 127, "main hand's top-left at the bottom (122, 127)")
    Near(s.Spot(env.CharacterSecondaryHandSlot), 122 + 37 + 5, "off hand 5 right of the main hand")
    Near(s.Spot(env.CharacterRangedSlot), 122 + 2 * (37 + 5), "ranged 5 right of the off hand")
    Equal(select(1, env.CharacterAmmoSlot:GetRegions()):GetAlpha(), 0, "the ammo slot's gear-slot atlas faded")
    Equal(select(1, select(2, env.CharacterAmmoSlot:GetChildren()):GetRegions()):GetAlpha(), 0, "and its child's")
    -- The model.
    local scene = env.CharacterModelScene
    local sx, sy = s.Spot(scene)
    Near(sx, 65, "model x")
    Near(sy, -78, "model y")
    Near(scene:GetWidth(), 233, "model width")
    Near(scene:GetHeight(), 224, "model height without the stat panes")
    Equal(scene.ControlFrame:IsShown(), false, "the model's controls hidden")
    Equal(scene.ControlFrame:IsMouseEnabled(), false, "and click-through")
    scene.ControlFrame:Show()
    Equal(scene.ControlFrame:IsShown(), false, "hidden again when the game shows them")
    Equal(game.camera.zoom, 3, "the camera wheeled out three notches")
    sheet:UpdateSize()
    Equal(game.camera.zoom, 3, "once per camera")
    scene:TransitionToModelSceneID(7)
    Equal(game.camera.zoom, 0, "a new camera comes with a new scene")
    game.Tick(0.05)
    Equal(game.camera.zoom, 3, "fitted a frame later")
    -- Rotate buttons.
    local left, right = C.rotate[1], C.rotate[2]
    Near(left:GetWidth(), 35, "rotate buttons are 35 x 35")
    Equal(select(2, left:GetPoint(1)), scene, "the first at the model's top-left")
    Equal(select(2, right:GetPoint(1)), left, "the second beside it")
    Equal(left:GetFrameLevel(), scene:GetFrameLevel() + 10, "above the model")
    True(left:GetNormalTexture():GetTexture():find("RotationLeft%-Button%-Up"), "the left art")
    Equal(left:GetHighlightTexture():GetBlendMode(), "ADD", "a round additive glow")
    game.Run(left, "OnMouseDown")
    Equal(game.sounds[#game.sounds], "rotate", "the rotate sound")
    game.Tick(0.5, 0.25)
    Near(game.actor.yaw, -math.pi * 0.5, "the left button turns the actor half a turn a second, yaw down")
    game.Run(left, "OnMouseUp")
    game.Tick(0.5, 0.25)
    Near(game.actor.yaw, -math.pi * 0.5, "mouse up stops it")
    game.Run(right, "OnMouseDown")
    game.Tick(0.25, 0.25)
    Near(game.actor.yaw, -math.pi * 0.25, "the right button turns it back")
    right:Hide()
    game.Tick(0.25, 0.25)
    Near(game.actor.yaw, -math.pi * 0.25, "hiding the button stops it")
    right:Show()
    game.noActor = true
    game.Run(right, "OnMouseDown")
    game.Tick(0.25, 0.25)
    Near(game.camera.yaw, -math.pi * 0.25, "with no actor the camera turns the other way")
    True((game.camera.snaps or 0) > 0, "and snaps to its target")
    scene:Hide()
    game.Tick(0.25, 0.25)
    Near(game.camera.yaw, -math.pi * 0.25, "the scene hidden: turning stops at once")
    s.Clean("slots and model")
end

---------------------------------------------------------------------------
-- The 1.x stat boxes and the resistances
---------------------------------------------------------------------------
do
    local s = Session()
    local game, env, C = s.game, s.env, s.C
    game.stats[1] = { 15, 20, 5, 0 }
    game.stats[2] = { 25, 22, 0, -3 }
    game.stats[3] = { 22, 24, 5, -3 }
    game.armor = { 50, 60, 60, 10, 0 }
    game.attackPower = { 40, 6, 0 }
    game.Pass()
    game.Open("PaperDollFrame")
    local rows = C.statRows
    Equal(rows.stat1.value:GetText(), "|cff20ff2020|r", "Strength with a bonus: green")
    Equal(Strip(rows.stat1.line), "20 (15 base +5)", "and its detail")
    Equal(rows.stat1.title, "Strength 20", "Strength's tooltip title")
    Equal(rows.stat2.value:GetText(), "|cffff202022|r", "Agility with a penalty: red")
    Equal(Strip(rows.stat2.line), "22 (25 base -3)", "and its detail")
    Equal(rows.stat3.value:GetText(), "|cffffffff24|r", "both: white")
    Equal(Strip(rows.stat3.line), "24 (22 base +5 -3)", "both in the detail")
    Equal(rows.stat4.line, nil, "no bonus, no penalty: no detail")
    Equal(rows.armor.title, "Armor 60", "Armor's title")
    Equal(rows.armor.value:GetText(), "|cff20ff2060|r", "Armor's bonus")
    Equal(rows.meleePower.value:GetText(), "|cff20ff2046|r", "Attack Power by the bonus rule")
    Equal(rows.meleePower.title, "Attack Power", "its fixed title")
    Equal(rows.meleeDamage.value:GetText(), "3 - 7", "damage: min down, max up")
    Equal(rows.rangedDamage.value:GetText(), "4 - 9", "ranged damage")
    Equal(rows.rangedPower.title, "Ranged Attack Power", "the ranged power title")
    game.damage = { 0.2, 0.4 }
    game.rangedDamage = { 2, 1, 0 }
    game.Fire("UNIT_DAMAGE", "player")
    Equal(rows.meleeDamage.value:GetText(), "1 - 1", "damage at least 1")
    Equal(rows.rangedDamage.value:GetText(), "--", "no ranged damage: --")
    -- The hover: EraUI's own tooltip, the title then the wrapped line.
    game.Run(rows.stat1.frame, "OnEnter")
    local tip = s.tips[#s.tips]
    Equal(tip[1][1], "Strength 20", "the hover's title")
    Equal(Strip(tip[2][1]), "20 (15 base +5)", "then the line")
    Equal(tip[2][5], 220, "the line wraps")
    -- Secret stats keep the old numbers.
    game.stats[1] = { 15, SECRET, 5, 0 }
    game.armor = { 1, 1, 1, 0, 0 }
    game.Fire("UNIT_STATS", "player")
    Equal(rows.armor.value:GetText(), "|cff20ff2060|r", "secret stats: the boxes keep their old numbers")
    game.stats[1] = { 15, 20, 5, 0 }
    -- Box art and places.
    local box = C.statBox
    local bx, by = s.Spot(box)
    Near(bx, 67, "the boxes at (67, -291)")
    Near(by, -291, "the boxes' y")
    local strips = { box:GetRegions() }
    Equal(#strips, 9, "three boxes of three strips")
    True(strips[1]:GetTexture():find("UI%-Character%-StatBackground"), "the 1.x stat background")
    Equal(select(2, strips[1]:GetDrawLayer()), 1, "background sub-level 1")
    local mx, my = s.Spot(rows.melee.frame)
    Near(mx - bx, 122, "Melee Attack at the box's (122, -2)")
    Near(my - by, -2, "Melee Attack's y")
    -- Resistances (Forever only).
    local column = C.resistColumn
    Equal(column:IsShown(), true, "the resistances show on Forever")
    Near(column:GetRight() - s.sheet:GetLeft(), 297, "their right edge at the model's (297)")
    Equal(C.resistRows[1].number:GetText(), "3", "Arcane first")
    Equal(C.resistRows[4].number:GetText(), "10", "Frost fourth")
    game.resists[6] = SECRET
    game.Fire("UNIT_RESISTANCES", "player")
    Equal(C.resistRows[1].number:GetText(), "0", "a secret resistance shows 0")
    game.Run(C.resistRows[1].frame, "OnEnter")
    Equal(s.tips[#s.tips][1][1], "Arcane Resistance", "the resistance hover")
    s.Clean("stat boxes")
end
do
    local s = Session({ interface = 11507 })
    s.game.Pass()
    s.game.Open("PaperDollFrame")
    Equal(s.C.resistColumn:IsShown(), false, "no resistance column off Forever")
    s.Clean("not Forever")
end

---------------------------------------------------------------------------
-- The bottom tabs
---------------------------------------------------------------------------
do
    local s = Session({ statisticsTab = false })
    local game, env, sheet, C = s.game, s.env, s.sheet, s.C
    game.Pass()
    game.Open("PaperDollFrame")
    local labels = {}
    for i, tab in ipairs(C.tabs) do labels[i] = tab:IsShown() and game.State(select(1, tab:GetRegions())) and tab end
    local modes = sheet.ModeTabs.Tabs
    local want = { "Character", "Reputation", "Skills", "PvP", "Currency" }
    local last
    for i = 1, 5 do
        local tab, mode = C.tabs[i], modes[i]
        Equal(tab:GetName(), "EraUIClassicCharacterTab" .. i, "tab " .. i .. "'s name")
        local label = game.Look.OwnPiece and nil
        local text
        for _, region in ipairs({ tab:GetRegions() }) do if region:GetObjectType() == "FontString" then text = region end end
        Equal(text:GetText(), want[i], "tab " .. i .. "'s label")
        Near(tab:GetWidth(), math.min(106, #want[i] * 6 + 30), "tab " .. i .. "'s width")
        Equal(tab:IsMouseEnabled(), false, "EraUI's tab never takes the mouse")
        Equal(tab:IsShown(), true, "a shown mode tab's tab shows")
        if last then
            Equal(select(2, tab:GetPoint(1)), last, "tab " .. i .. " follows the last")
            Near(tab:GetLeft() - last:GetRight(), -15, "tabs overlap by 15")
        else
            local x, y = s.Spot(tab, "BOTTOMLEFT")
            Near(x, 14, "the first tab at (14, 46) of the art's foot")
            Near(y, -512 + 46, "the first tab's bottom")
        end
        last = tab
        -- The game's tab laid over it.
        Equal(mode:GetNumPoints(), 2, "mode tab " .. i .. " on all points of EraUI's")
        Equal(select(2, mode:GetPoint(1)), tab, "mode tab " .. i .. " anchored to EraUI's tab")
        True(mode:GetFrameLevel() >= tab:GetFrameLevel() + 2, "mode tab " .. i .. " above it")
        Equal(table.concat(game.State(mode).insets, ","), "0,0,0,0", "mode tab " .. i .. " has no hit insets")
        Equal(mode:IsMouseEnabled(), true, "mode tab " .. i .. " takes the click")
    end
    Equal(C.tabs[6]:IsShown(), false, "a hidden mode tab's tab stays hidden")
    -- Selected tab look.
    local function Look(tab)
        local art, font
        for _, region in ipairs({ tab:GetRegions() }) do
            if region:GetObjectType() == "FontString" then font = game.State(region).font
            elseif select(1, region:GetDrawLayer()) == "BACKGROUND" then art = art or region end
        end
        return art, font
    end
    local art, font = Look(C.tabs[1])
    True(art:GetTexture():find("UI%-Character%-ActiveTab"), "the selected tab wears the active art")
    Near(art:GetHeight(), 35, "35 tall")
    Equal(font, env.GameFontHighlightSmall, "and the white font")
    art, font = Look(C.tabs[2])
    True(art:GetTexture():find("UI%-Character%-InActiveTab"), "the others the inactive art")
    Equal(font, env.GameFontNormalSmall, "and the gold font")
    sheet:ShowSubFrame("SkillsFrame")
    game.Tick(0.05)
    art = Look(C.tabs[3])
    True(art:GetTexture():find("UI%-Character%-ActiveTab"), "a tab switch moves the selection")
    -- Hover follows the game's tab; its own tooltip is the game's.
    game.Run(modes[2], "OnEnter")
    Equal(game.State(C.tabs[2]).locked, true, "hovering the game's tab lights EraUI's")
    Equal(game.tabTips, 1, "the game's own tab tooltip is left to the game")
    game.Run(modes[2], "OnLeave")
    Equal(game.State(C.tabs[2]).locked, false, "and leaving puts it out")
    -- The game moves its tab: put back on the next frame.
    modes[2]:ClearAllPoints()
    modes[2]:SetPoint("TOPLEFT", sheet.ModeTabs, "TOPLEFT")
    game.Tick(0.05)
    Equal(select(2, modes[2]:GetPoint(1)), C.tabs[2], "the game's tab laid back over EraUI's every frame")
    s.Clean("tabs")
end

---------------------------------------------------------------------------
-- The side pane, the hit rect and the CVar
---------------------------------------------------------------------------
do
    local s = Session()
    local game, env, sheet, C = s.game, s.env, s.sheet, s.C
    game.cvars.characterFrameCollapsed = "0"
    game.Pass()
    game.Open("PaperDollFrame")
    Equal(game.cvars.characterFrameCollapsed, "1", "the window loads collapsed")
    Equal(game.ns.db.cvarWas.characterFrameCollapsed, "0", "the old value kept for the hand-back")
    local writes = game.cvarWrites
    game.Pass()
    Equal(game.cvars.characterFrameCollapsed, "1", "still collapsed")
    for _, frame in ipairs({ sheet.RightPaneHost, env.CharacterStatsPane, env.CharacterStatsPaneScrollBox, env.PaperDollSidebarTabs,
        env.PaperDollLevelInfo, env.PaperDollFrame.TitleManagerPane, env.CharacterStatsPanePetScrollBox, env.ReputationFrame.ReputationDetailFrame }) do
        Equal(frame:GetAlpha(), 0, "a side-pane piece muted")
    end
    local tabs = env.PaperDollSidebarTabs
    Equal(tabs:IsMouseEnabled(), false, "muted frames lose the mouse")
    local inner = tabs:GetChildren()
    Equal(inner:IsMouseEnabled(), false, "and their children")
    Equal(inner:GetChildren():IsMouseEnabled(), false, "and theirs")
    Equal(env.SkillsFrame.SkillDetailFrame:GetAlpha(), 0, "the Skills detail is muted off the Skills tab")
    sheet:ShowSubFrame("SkillsFrame")
    sheet:Expand()
    Equal(env.SkillsFrame.SkillDetailFrame:GetAlpha(), 1, "the Skills detail kept while Skills shows")
    Equal(env.SkillsFrame.SkillDetailFrame:IsMouseEnabled(), true, "with the mouse given back")
    -- The game shows its sidebar again: muted again on the next frame.
    sheet:ShowSubFrame("PaperDollFrame")
    tabs:SetAlpha(1)
    tabs:EnableMouse(true)
    game.Tick(0.05)
    Equal(tabs:GetAlpha(), 0, "muted again once the game shows it")
    Equal(tabs:IsMouseEnabled(), false, "its mouse off again")
    env.PaperDollFrame_UpdateSidebarTabs()
    Equal(tabs:GetAlpha(), 0, "after the game's sidebar update too")
    -- The hit rect follows a window wider than the 1.x one.
    sheet:SetSize(450, 512)
    C.HideSidePane()
    Equal(table.concat(game.State(sheet).insets, ","), "0,66,0,0", "the invisible part takes no clicks")
    local insetWrites = game.State(sheet).insetWrites
    C.HideSidePane()
    Equal(game.State(sheet).insetWrites, insetWrites, "set only when the inset changes")
    -- No CVar write in a fight.
    game.combat = true
    game.cvars.characterFrameCollapsed = "0"
    C.WriteCollapsed()
    Equal(game.cvars.characterFrameCollapsed, "0", "never in a fight")
    game.combat = false
    True(writes > 0, "written through the engine's guarded writer")
    s.Clean("side pane")
end

---------------------------------------------------------------------------
-- The lists: Skills, Reputation, Currency, Statistics, PvP
---------------------------------------------------------------------------
do
    local s = Session()
    local game, env, sheet, C = s.game, s.env, s.sheet, s.C
    game.Fill("skills", { { name = "Professions", header = true, collapsed = false }, { name = "First Aid", rank = 121, maxRank = 150 } }, true)
    game.Fill("reputation", { { name = "Alliance", header = true, collapsed = true }, { name = "Stormwind", share = 0.5, factionID = 72 } }, true)
    game.Fill("currency", { { name = "Miscellaneous", header = true, collapsed = false } }, true)
    game.Pass()
    game.Open("SkillsFrame")
    local box = env.SkillsFrame.ScrollBox
    Near(box:GetScale(), 20 / 33, "the Skills box shrunk so its rows are 20 tall")
    local l, b, r, t = box:Rect()
    local sl, _, sr, st = sheet:Rect()
    Near(l - sl, 12, "the Skills box from (12, -76)")
    Near(t - st, -76, "its top")
    Near(r - sr, -66, "to (-66, 224): right")
    Near(b - (st - 512), 224, "and bottom")
    Near(env.ReputationFrame.ScrollBox:GetScale(), 0.76, "the Reputation box at 0.76")
    Near(env.TokenFrame.ScrollBox:GetScale(), 1, "Currency unscaled")
    local rows = game.Rows("skills")
    Near(rows[2].Content:GetScale(), 33 / 20, "an entry's content drawn at normal size")
    local bar = rows[2].Content.SkillsBar
    Equal(bar.Text:GetText(), "121/150", "the rank reads 121/150")
    Equal(game.State(bar.Text).font, env.GameFontHighlightSmall, "in white")
    Equal(rows[2].Content.Name:GetAlpha(), 0, "the game's name faded")
    local border
    for _, region in ipairs({ bar:GetRegions() }) do
        if region:GetTexture() and region:GetTexture():find("Skills%-BarBorder") then border = region end
    end
    True(border, "the skill bar's 1.x border")
    Near(border:GetHeight(), 32, "32 tall")
    Equal(select(1, bar:GetRegions()):GetAlpha(), 0, "the modern bar background faded")
    -- The header's cover: name and minus (expanded).
    local header = rows[1]
    Equal(header.Name:GetAlpha(), 0, "the header's own name faded")
    Equal(header.StateIcon:GetAlpha(), 0, "its state icon faded")
    Equal(select(1, header:GetRegions()):GetAlpha(), 0, "its collapse-expand art faded")
    local cover = header:GetChildren()
    Near(cover:GetScale(), 33 / 20, "a cover drawn at normal size")
    local icon, name
    for _, region in ipairs({ cover:GetRegions() }) do
        if region:GetObjectType() == "FontString" then name = region else icon = region end
    end
    Equal(name:GetText(), "Professions", "the header's name")
    True(icon:GetTexture():find("UI%-MinusButton%-Up"), "an expanded header shows minus")
    -- Reputation: collapsed header shows plus; the entry's bar and plate.
    env.CharacterFrame:ShowSubFrame("ReputationFrame")
    local repRows = game.Rows("reputation")
    local repCover = repRows[1]:GetChildren()
    for _, region in ipairs({ repCover:GetRegions() }) do
        if region:GetObjectType() == "Texture" then True(region:GetTexture():find("UI%-PlusButton%-Up"), "a collapsed header shows plus") end
    end
    local repBar = repRows[2].Content.ReputationBar
    Near(repBar:GetWidth(), 137, "the 1.x reputation bar")
    Near(repBar:GetHeight(), 13, "13 tall")
    local plate = 0
    for _, region in ipairs({ repBar:GetRegions() }) do
        if region:GetTexture() and region:GetTexture():find("ReputationBar$") then plate = plate + 1 end
    end
    Equal(plate, 2, "the plate and its right cap")
    local labels = 0
    for _, region in ipairs({ env.ReputationFrame:GetRegions() }) do
        if region:GetObjectType() == "FontString" and (region:GetText() == "Faction" or region:GetText() == "Standing") and region:IsShown() then labels = labels + 1 end
    end
    Equal(labels, 2, "the Faction and Standing labels")
    local fx = env.ReputationFrame.filterDropdown:GetRight() - sheet:GetLeft()
    Near(fx, 384 - 40, "the filter at (-40, -62) from the top right")
    -- Currency header: the game's name moved and re-fonted.
    local coin = game.Rows("currency")[1]
    Equal(game.State(coin.Name).font, env.GameFontNormal, "a currency header's name in gold")
    Near(coin.Name:GetLeft() - coin:GetLeft(), 26, "26 in")
    -- The scroll column on the lists' bars.
    local scroll = env.SkillsFrame.ScrollBar
    local top, bottom
    for _, region in ipairs({ scroll:GetRegions() }) do
        if region:GetTexture() and region:GetTexture():find("UI%-Character%-ScrollBar") then
            if select(2, region:GetDrawLayer()) == 0 then top = region else bottom = region end
        end
    end
    True(top and bottom, "the scroll column's two pieces")
    Near(bottom:GetHeight(), 108, "the bottom piece 108 tall")
    Near(top:GetHeight(), math.max(1, math.min(256, scroll:GetHeight() + 17 - 108)), "the top piece fits the bar")
    Equal(scroll.Track.Begin:GetAlpha(), 0, "the modern track faded")
    Near(scroll.Track.Thumb:GetWidth(), 16, "the thumb 16 wide")
    Equal(scroll.Back.Texture:GetAlpha(), 0, "the arrow's own art faded")
    local _, relative, _, ax, ay = scroll.Back:GetPoint(1)
    Equal(relative, scroll, "the up arrow on the bar")
    Equal(ax .. "," .. ay, "3,4", "at its top (3, 4)")
    -- PvP.
    env.CharacterFrame:ShowSubFrame("PVPRankFrame")
    local info = env.PVPRankFrame.MainInfoFrame
    Near(info:GetLeft() - sheet:GetLeft(), 6, "the PvP panel from (6, -70)")
    Near(info:GetBottom() - sheet:GetTop(), -205, "to the window's top right (-6, -205)")
    s.Clean("lists")
end

---------------------------------------------------------------------------
-- The skill detail pane
---------------------------------------------------------------------------
do
    local s = Session()
    local game, env, sheet, C = s.game, s.env, s.sheet, s.C
    game.skillList = { { name = "Professions", isHeader = true }, { name = "First Aid", rank = 121, maxRank = 150, skillID = 129, isAbandonable = true },
        { name = "Daggers", rank = 10, maxRank = 60, skillID = 173, isAbandonable = false } }
    game.selected = 2
    game.Pass()
    game.Open("PaperDollFrame")
    local pane = env.SkillsFrame.SkillDetailFrame
    env.CharacterFrame:ShowSubFrame("SkillsFrame")
    -- A tab click runs no side-pane pass (the game only expands for the
    -- paper doll): the pane, muted on the other tabs, comes back by itself.
    Equal(pane:GetAlpha(), 1, "the pane visible after a plain tab click")
    Equal(pane:IsMouseEnabled(), true, "and within reach")
    Equal(pane:GetParent(), sheet, "the pane brought into the window")
    local x, y = s.Spot(pane, "BOTTOMLEFT")
    Near(x, 20, "the pane from (20, 84)")
    Near(y, -512 + 84, "its bottom")
    Near(pane:GetWidth(), 384 - 20 - 44, "to (-44, 84)")
    Near(pane:GetHeight(), 126, "126 tall")
    Equal(pane:GetFrameLevel(), sheet:GetFrameLevel() + 6, "6 above the window")
    Equal(pane:IsShown(), true, "shown on Skills")
    Equal(pane.Title:GetAlpha(), 0, "its title faded")
    Equal(pane.Content:IsShown(), false, "its rows hidden")
    local divider = C.SkillPart("divider")
    Equal(divider:IsShown(), true, "the stone divider on Skills")
    Near(divider:GetBottom() - pane:GetTop(), 6, "6 above the pane")
    local column = C.SkillPart("column")
    Equal(column:IsShown(), true, "the description's scroll column on Skills")
    Near(column:GetHeight(), 110, "110 tall")
    local rank = pane.RankBar
    local rankName
    for _, region in ipairs({ rank:GetRegions() }) do if region:GetObjectType() == "FontString" and region ~= rank.Text then rankName = region end end
    Equal(rankName:GetText(), "First Aid", "the rank bar names the chosen skill")
    local unlearn = C.SkillPart("unlearn")
    Equal(unlearn:IsShown(), true, "the unlearn X for a skill that can be abandoned")
    Equal(select(2, unlearn:GetPoint(1)), rank, "beside the rank bar")
    game.Run(unlearn, "OnEnter")
    Equal(s.tips[#s.tips][1][1], "Unlearn this skill", "the unlearn hover")
    game.Run(unlearn, "OnClick")
    local popup = game.popups[#game.popups]
    Equal(popup[1], "ERAUI_BASE_UNLEARN_SKILL", "the unlearn pop-up")
    Equal(popup[2], "First Aid", "naming the skill")
    Equal(popup[4], 129, "carrying its ID")
    env.StaticPopupDialogs.ERAUI_BASE_UNLEARN_SKILL.OnAccept(nil, popup[4])
    Equal(game.abandoned, 129, "accepting abandons that skill")
    Equal(env.StaticPopupDialogs.ERAUI_BASE_UNLEARN_SKILL.hideOnEscape, 1, "Escape hides the pop-up")
    -- The selection poll re-dresses.
    game.selected = 3
    game.Tick(0.1)
    Equal(rankName:GetText(), "Daggers", "a new choice re-dresses the pane")
    Equal(unlearn:IsShown(), false, "no unlearn X for a skill that can't be abandoned")
    -- The description fits the pane.
    Near(game.State(pane.Description.ScrollBox.FontStringContainer.FontString).w, 284, "the description 284 wide")
    True((game.fullUpdates or 0) > 0, "its scroll box updated")
    -- A plain tab click away, the game keeping its side panes hidden: the
    -- divider and the column (both on the window) go with the pane.
    env.CharacterFrame:ShowSubFrame("ReputationFrame")
    Equal(pane:IsShown(), false, "the pane hides with Skills")
    Equal(divider:IsShown(), false, "its divider with it")
    Equal(column:IsShown(), false, "and its column")
    env.CharacterFrame:ShowSubFrame("SkillsFrame")
    Equal(column:IsShown(), true, "back on Skills: the column again")
    Equal(divider:IsShown(), true, "and the divider")
    Equal(pane:GetAlpha(), 1, "and the pane in sight")
    -- Close in the foot closes the window.
    local close = C.SkillPart("close")
    Equal(close:GetText(), "Close", "the foot's Close")
    Near(close:GetWidth(), 80, "80 wide")
    game.Run(close, "OnClick")
    Equal(game.closed, sheet, "Close closes the window")
    -- Off the Skills tab.
    game.Open("ReputationFrame")
    -- (The game's RefreshRightPane shows its side panes again while the
    -- window isn't collapsed yet; muted, the pane stays out of sight.)
    True(not pane:IsShown() or pane:GetAlpha() == 0, "the pane out of sight off Skills")
    Equal(pane:IsMouseEnabled(), false, "and out of reach")
    Equal(divider:IsShown(), false, "with its divider")
    Equal(column:IsShown(), false, "and its column")
    s.Clean("skill detail")
end

---------------------------------------------------------------------------
-- The reputation detail box
---------------------------------------------------------------------------
do
    local s = Session()
    local game, env, sheet, C = s.game, s.env, s.sheet, s.C
    game.factions = { { name = "Alliance", isHeader = true, factionID = 469 },
        { name = "Stormwind", description = "The capital.", factionID = 72, canToggleAtWar = true, atWarWith = false, canSetInactive = true, isWatched = false },
        { name = "Ironforge", description = "Dwarves.", factionID = 47, canToggleAtWar = false, canSetInactive = false, isWatched = true, active = false } }
    game.Fill("reputation", { { name = "Stormwind", share = 0.5, factionID = 72 }, { name = "Ironforge", share = 0.3, factionID = 47 } }, true)
    game.Pass()
    game.Open("ReputationFrame")
    local rows = game.Rows("reputation")
    rows[1]:Click()
    local box, checks_, chosen, texts = C.RepBox()
    Equal(box:GetName(), "EraUIClassicReputationDetail", "the box's name")
    Equal(box:IsShown(), true, "a click opens the box")
    Equal(chosen, 72, "for that faction")
    local x, y = s.Spot(box)
    Near(x, 349, "just right of the art (349, -48)")
    Near(y, -48, "its y")
    Equal(box:GetFrameLevel(), sheet:GetFrameLevel() + 30, "30 above the window")
    Equal(texts.name:GetText(), "Stormwind", "the faction's name")
    Equal(texts.description:GetText(), "The capital.", "its description")
    Equal(box:IsMouseEnabled(), true, "the box takes the mouse")
    Equal(checks_.atWar.button:IsEnabled(), true, "At War can be toggled")
    Equal(table.concat({ checks_.atWar.label:GetTextColor() }, ",", 1, 3), "1,0.1,0.1", "in red")
    Equal(checks_.inactive.button:GetChecked(), false, "an active faction")
    Equal(checks_.watch.button:GetChecked(), false, "not watched")
    local dark = 0
    for _, entry in ipairs(game.darkened) do if entry[1] == "DarkBackdrop" and entry[2]:GetParent() == box then dark = dark + 1 end end
    Equal(dark, 2, "both dialog boxes handed to Dark Windows")
    game.Tick(0.3)
    local mark
    for _, child in ipairs({ rows[1].Content.ReputationBar:GetChildren() }) do
        if not game.IsGame(child) then mark = child end
    end
    True(mark and mark:IsShown(), "the chosen row wears the mark")
    Equal(mark:GetFrameLevel(), rows[1].Content.ReputationBar:GetFrameLevel() + 3, "3 above the bar")
    local strip = select(1, mark:GetRegions())
    Equal(strip:GetBlendMode(), "ADD", "an additive strip")
    True(strip:GetTexture():find("ReputationBar%-Highlight"), "the 1.x highlight")
    for _, child in ipairs({ rows[2].Content.ReputationBar:GetChildren() }) do
        if not game.IsGame(child) then Equal(child:IsShown(), false, "no mark on another row") end
    end
    -- Clicks.
    checks_.atWar.button:Click()
    Equal(game.repCalls[#game.repCalls], "war 2", "At War toggles that faction")
    Equal(game.sounds[#game.sounds], "on", "with the tick sound")
    checks_.inactive.button:Click()
    Equal(game.repCalls[#game.repCalls], "active 2 false", "Move to Inactive")
    checks_.watch.button:Click()
    Equal(game.repCalls[#game.repCalls], "watch 2", "Show as Experience Bar")
    Equal(checks_.watch.button:IsEnabled(), false, "held while the strips follow")
    game.stripsShowFaction = false
    game.Tick(0.5)
    Equal(checks_.watch.button:IsEnabled(), false, "still held while the strips disagree")
    game.stripsShowFaction = true
    game.Tick(0.2)
    Equal(checks_.watch.button:IsEnabled(), true, "released once the strips agree")
    checks_.watch.button:Click()
    Equal(game.repCalls[#game.repCalls], "watch 0", "unticked: no watched faction")
    game.Tick(3.2)
    Equal(checks_.watch.button:IsEnabled(), true, "released after 3 s at most")
    -- Another faction, then the same one again.
    game.factions[3].isWatched = true
    rows[2]:Click()
    Equal(texts.name:GetText(), "Ironforge", "another faction")
    Equal(checks_.atWar.button:IsEnabled(), false, "At War off for it")
    Equal(table.concat({ checks_.atWar.label:GetTextColor() }, ",", 1, 3), "0.5,0.5,0.5", "greyed")
    Equal(checks_.inactive.button:GetChecked(), true, "an inactive faction")
    Equal(checks_.watch.button:GetChecked(), true, "watched")
    rows[2]:Click()
    Equal(box:IsShown(), false, "the same faction again closes it")
    rows[1]:Click()
    game.Tick(0.3)
    env.CharacterFrame:ShowSubFrame("SkillsFrame")
    game.Tick(0.3)
    Equal(box:IsShown(), false, "the box hides when the tab hides")
    Equal(mark:IsShown(), false, "and every mark with it")
    s.Clean("reputation box")
end

---------------------------------------------------------------------------
-- The currency detail box: the game's own detail (name, count, the Unused
-- and Show on Backpack ticks) in a 1.x box beside the window. Found 14 Nov:
-- the side-pane pass kept that detail muted, so a click showed nothing.
---------------------------------------------------------------------------
do
    local s = Session()
    local game, env, sheet, C = s.game, s.env, s.sheet, s.C
    local honor = { name = "Honor Points", currencyID = 1901, quantity = 102, discovered = true, isShowInBackpack = false, isTypeUnused = false }
    game.currencies = { { name = "Miscellaneous", isHeader = true }, honor,
        { name = "Arena Points", currencyID = 1900, quantity = 7, discovered = true, isShowInBackpack = true } }
    game.Fill("currency", { { name = "Miscellaneous", header = true, collapsed = false },
        { name = "Honor Points", currencyIndex = 2, quantity = 102 },
        { name = "Arena Points", currencyIndex = 3, quantity = 7, isShowInBackpack = true } }, true)
    game.State(sheet).collapsed = true -- the game's right pane starts closed (EraUI's CVar)
    game.Pass()
    game.Open("TokenFrame")
    local coins, pane = env.TokenFrame, env.TokenFrame.DetailFrame
    local backpack, unused, transfer = pane.BackpackCheckbox, pane.InactiveCheckbox, pane.CurrencyTransferToggleButton
    local rows = game.Rows("currency")
    Equal(coins.selectedID, 2, "the game chooses the first currency as the tab shows")
    Equal(C.CurrencyBox(), nil, "no box before a click")
    True(not pane:IsShown() or pane:GetAlpha() == 0, "the game's detail out of sight before a click")
    -- A plain click: the game chooses the currency and opens its right pane;
    -- EraUI's box opens with the game's detail in it. The game's click
    -- refills the list, so the clicked row may hold another currency after.
    game.reuseRows = true
    rows[2]:Click()
    Equal(rows[2].elementData.name, "Arena Points", "the clicked row holds another currency after the refill")
    coins:Update()
    game.reuseRows = nil
    Equal(rows[2].elementData.name, "Honor Points", "(the next refill puts them back)")
    Equal(game.paneOpens, 1, "the game opened its right pane for the click")
    local box = C.CurrencyBox()
    True(box, "a plain click makes the box")
    Equal(box:GetName(), "EraUIClassicCurrencyDetail", "the box's name")
    Equal(box:IsShown(), true, "and opens it")
    Equal(C.CurrencyOpen(), true, "the box reports open")
    Equal(select(2, C.CurrencyBox()), "Honor Points", "for the clicked currency")
    Equal(box:GetParent(), coins, "the Currency tab's own frame")
    Equal(box:GetFrameLevel(), sheet:GetFrameLevel() + 30, "30 above the window")
    Equal(box:IsMouseEnabled(), true, "the box takes the mouse")
    -- Beside the window: just right of the art, never over it.
    local x, y = s.Spot(box)
    Near(x, C.ART_RIGHT, "just right of the art (349, -48)")
    Near(y, -48, "its y")
    True(box:GetLeft() >= sheet:GetLeft() + C.ART_RIGHT - 1e-6, "the box never over the window's art")
    Near(box:GetWidth(), 236, "236 wide")
    Near(box:GetHeight(), 350, "350 tall")
    -- The game's own detail laid in it: in sight and within reach.
    Equal(select(2, pane:GetPoint(1)), box, "the game's detail laid in the box")
    Equal(pane:GetNumPoints(), 2, "by two corners")
    Near(pane:GetLeft() - box:GetLeft(), 16, "16 in from the left")
    Near(box:GetRight() - pane:GetRight(), 14, "14 in from the right")
    Near(box:GetTop() - pane:GetTop(), 28, "28 down, under the X")
    Near(pane:GetBottom() - box:GetBottom(), 10, "10 up from the foot")
    Equal(pane:GetParent(), coins, "never re-parented")
    Equal(pane:GetFrameStrata(), "HIGH", "its strata left alone")
    Equal(pane:GetAlpha(), 1, "the detail in sight")
    Equal(pane:IsMouseEnabled(), true, "and within reach")
    Equal(pane:IsVisible(), true, "and shown")
    Equal(pane.Title:GetText(), "Honor Points", "the game's detail names the chosen currency")
    Equal(backpack.Label:GetText(), "Show on Backpack", "the Show on Backpack box")
    Equal(backpack:IsVisible(), true, "shows")
    Equal(backpack:IsMouseEnabled(), true, "and takes the click")
    Equal(backpack:GetChecked(), false, "not watched yet")
    Equal(unused:IsVisible(), true, "the Unused box shows too")
    Equal(unused:IsMouseEnabled(), true, "and takes the click")
    -- The box: two dialog boxes, the upper one parchment, the ticks in the
    -- lower one.
    local dialogs, close = {}, nil
    for _, child in ipairs({ box:GetChildren() }) do
        if s.State(child).backdrop then dialogs[#dialogs + 1] = child end
        if child:GetObjectType() == "Button" then close = child end
    end
    Equal(#dialogs, 2, "two dialog boxes")
    local upper, lower = dialogs[1], dialogs[2]
    True(select(1, upper:GetRegions()):GetTexture():find("QuestBG"), "the upper one parchment")
    Near(lower:GetHeight(), 110, "the lower one 110 tall")
    Near(lower:GetTop() - upper:GetBottom(), 12, "over the upper one's foot by 12")
    True(unused:GetTop() <= lower:GetTop() - 8, "the ticks below the lower box's top edge")
    True(backpack:GetBottom() >= lower:GetBottom() + 8, "and above its foot")
    True(close and close:GetFrameLevel() > lower:GetFrameLevel(), "the X over the boxes")
    Near(box:GetRight() - close:GetRight(), 3, "the X in the top right")
    -- 1.x art, and every piece handed to Dark Mode.
    local dark, cross, red = 0, false, false
    for _, entry in ipairs(game.darkened) do
        if entry[1] == "DarkBackdrop" and entry[2]:GetParent() == box then dark = dark + 1 end
        if entry[1] == "DarkCloseButton" and entry[2] == close then cross = true end
        if entry[1] == "DarkRedButton" and entry[2] == transfer then red = true end
    end
    Equal(dark, 2, "both dialog boxes handed to Dark Windows")
    True(cross, "the X handed to Dark Windows")
    True(red, "the transfer button's 1.x red handed to Dark Windows")
    True(backpack:GetNormalTexture():GetTexture():find("UI%-CheckBox%-Up"), "the tick in the 1.x check art")
    True(backpack:GetCheckedTexture():GetTexture():find("UI%-CheckBox%-Check"), "its check mark too")
    True(unused:GetNormalTexture():GetTexture():find("UI%-CheckBox%-Up"), "the Unused tick as well")
    Equal(pane.Divider:GetAlpha(), 0, "the modern divider faded")
    Equal(transfer.Left:GetAlpha(), 0, "the transfer button's modern slices faded")
    Equal(transfer:IsShown(), false, "the transfer button left to the game (hidden here)")
    -- Ticking: the game's own clicks.
    backpack:Click()
    Equal(game.coinCalls[#game.coinCalls], "backpack 2 true", "ticking Show on Backpack watches the chosen currency")
    Equal(honor.isShowInBackpack, true, "watched")
    Equal(backpack:GetChecked(), true, "the tick stays")
    Equal(game.sounds[#game.sounds], "on", "with the game's tick sound")
    Equal(box:IsShown(), true, "the box stays open")
    backpack:Click()
    Equal(game.coinCalls[#game.coinCalls], "backpack 2 false", "unticked: no longer watched")
    game.watchFull = true
    backpack:Click()
    Equal(backpack:GetChecked(), false, "too many watched: the game takes the tick back")
    game.watchFull = nil
    unused:Click()
    Equal(game.coinCalls[#game.coinCalls], "unused 2 true", "Unused ticked through the game's own click")
    unused:Click()
    Equal(game.coinCalls[#game.coinCalls], "unused 2 false", "and unticked")
    -- The side-pane pass and its watch leave the open box's detail alone.
    C.HideSidePane()
    Equal(pane:GetAlpha(), 1, "the side-pane pass leaves the open box's detail in sight")
    Equal(sheet.RightPaneHost:GetAlpha(), 0, "the right pane itself still muted")
    sheet.RightPaneHost:SetAlpha(1)
    game.Tick(0.05)
    Equal(sheet.RightPaneHost:GetAlpha(), 0, "the watch mutes the right pane again")
    Equal(pane:GetAlpha(), 1, "but never the open box's detail")
    Equal(backpack:IsMouseEnabled(), true, "its ticks still within reach")
    sheet:RefreshRightPane()
    Equal(pane:GetAlpha(), 1, "nor the game's own pass")
    for _, other in ipairs({ env.ReputationFrame.ReputationDetailFrame, env.SkillsFrame.SkillDetailFrame }) do
        Equal(other:GetAlpha(), 0, "the other tabs' detail panes stay muted")
    end
    -- Another currency, then the same one again.
    rows[3]:Click()
    Equal(box:IsShown(), true, "another currency: the box stays")
    Equal(pane.Title:GetText(), "Arena Points", "and the game's detail follows")
    Equal(select(2, C.CurrencyBox()), "Arena Points", "open for it")
    Equal(backpack:GetChecked(), true, "a watched currency shows ticked")
    Equal(game.paneOpens, 1, "the game's right pane opened once")
    rows[3]:Click()
    Equal(box:IsShown(), false, "the same currency again closes it")
    Equal(C.CurrencyOpen(), false, "the box reports closed")
    Equal(pane:GetAlpha(), 0, "the game's detail muted again")
    Equal(backpack:IsMouseEnabled(), false, "its ticks out of reach")
    -- Shift-clicks are the game's (watch from the list, a chat link).
    game.modified = "TOKENWATCHTOGGLE"
    rows[2]:Click()
    Equal(game.coinCalls[#game.coinCalls], "backpack 2 true", "Shift-click still watches from the list")
    Equal(box:IsShown(), false, "and opens no box")
    game.modified = nil
    rows[2]:Click()
    Equal(box:IsShown(), true, "a plain click opens it again")
    Equal(pane:GetAlpha(), 1, "the detail back in sight")
    for _, held in ipairs({ "TOKENWATCHTOGGLE", "CHATLINK" }) do
        game.modified = held
        rows[2]:Click()
        Equal(box:IsShown(), true, held .. " on the open currency leaves the box open")
    end
    game.modified = nil
    -- The X.
    game.Run(close, "OnClick")
    Equal(box:IsShown(), false, "the X closes it")
    Equal(pane:GetAlpha(), 0, "the detail muted with it")
    -- The chosen currency leaves the list (a header folded): closed at once
    -- after the game's own refresh; nothing chosen at all: within 0.2 s.
    rows[2]:Click()
    table.remove(game.currencies, 2)
    pane:ClearSelectionIfMissing()
    Equal(box:IsShown(), false, "the chosen currency folded away: the box goes")
    table.insert(game.currencies, 2, honor)
    rows[2]:Click()
    Equal(box:IsShown(), true, "open again")
    game.Own(coins, "selectedID", nil)
    game.Tick(0.3)
    Equal(box:IsShown(), false, "nothing chosen: the box goes")
    -- Another tab, closing the window.
    rows[2]:Click()
    Equal(box:IsShown(), true, "open again")
    sheet:ShowSubFrame("ReputationFrame")
    Equal(box:IsShown(), false, "another tab closes it")
    Equal(pane:GetAlpha(), 0, "the game's detail muted on the other tabs")
    Equal(pane:IsMouseEnabled(), false, "and out of reach")
    sheet:RefreshRightPane()
    Equal(pane:GetAlpha(), 0, "still muted after the game's own pass")
    Equal(sheet.RightPaneHost:GetAlpha(), 0, "and the right pane with it")
    sheet:ShowSubFrame("TokenFrame")
    Equal(box:IsShown(), false, "back on Currency: closed until a click")
    Equal(pane:GetAlpha(), 0, "the detail still out of sight")
    rows[3]:Click()
    Equal(box:IsShown(), true, "a click opens it")
    env.HideUIPanel(sheet)
    Equal(box:IsShown(), false, "closing the window closes it")
    game.Open("TokenFrame")
    Equal(box:IsShown(), false, "opening the window again: still closed")
    -- In a fight the detail isn't guarded, so the box still opens.
    game.combat = true
    rows[3]:Click()
    Equal(box:IsShown(), true, "a click in a fight opens it")
    Equal(pane:GetAlpha(), 1, "with the detail in sight")
    game.combat = false
    -- EraUI's own windows (the spellbook, the talents, the quest log) open
    -- right of the window, over the box's spot. They are toplevel, so they
    -- would cover the box, but the game's detail in it is HIGH and would
    -- float over them and take their clicks: the box gives way.
    assert(loadfile("Look/Windows.lua", "t", env))("EraUI", game.E)
    local Look = game.Look
    local book = Look.Build("Frame", env.UIParent, nil, { size = { 352, 512 }, mouse = true, hidden = true })
    game.ns.RegisterClassicWindow(book, true)
    rows[2]:Click()
    Equal(box:IsShown(), true, "open for another currency")
    book:Show()
    Near(book:GetLeft() - sheet:GetLeft(), 352, "the window manager puts the book beside the window, over the box's spot")
    Equal(box:IsShown(), false, "one of EraUI's windows opening over the spot closes the box at once")
    Equal(pane:GetAlpha(), 0, "the game's detail muted with it")
    Equal(pane:IsMouseEnabled(), false, "so it takes none of the book's clicks")
    Equal(backpack:IsMouseEnabled(), false, "nor do its ticks")
    Equal(unused:IsMouseEnabled(), false, "nor the Unused tick")
    rows[3]:Click()
    Equal(box:IsShown(), false, "no box while the book stands over its spot")
    Equal(pane:GetAlpha(), 0, "the detail still out of sight")
    game.Tick(0.3)
    Equal(box:IsShown(), false, "nor after a while")
    book:Hide()
    rows[3]:Click()
    Equal(box:IsShown(), true, "the book closed: a click opens the box again")
    Equal(pane:GetAlpha(), 1, "with the detail in sight")
    -- A window kept clear of the spot leaves the box alone; one moved over
    -- it outside the manager's pass closes it within 0.2 s.
    Look.WindowTraits(book, { hold = function() return 700 end })
    Look.Pin(book, "TOPLEFT", env.UIParent, "TOPLEFT", 700, -104)
    book:Show()
    Equal(box:IsShown(), true, "a window clear of the spot leaves the box open")
    game.Tick(0.3)
    Equal(box:IsShown(), true, "and so does the box's watch")
    Look.Pin(book, "TOPLEFT", env.UIParent, "TOPLEFT", 500, -104)
    game.Tick(0.3)
    Equal(box:IsShown(), false, "moved over the spot: the box goes within 0.2 s")
    Equal(pane:IsMouseEnabled(), false, "and the detail out of reach")
    book:Hide()
    -- Character Window off: closed, the game's detail back in its own place.
    game.ns.db.characterSheet = false
    game.Pass()
    Equal(box:IsShown(), false, "Character Window off: the box closed")
    Equal(select(2, pane:GetPoint(1)), sheet.RightPaneHost, "the game's detail back on its own anchors")
    Equal(pane:GetNumPoints(), 2, "both of them")
    rows[2]:Click()
    Equal(box:IsShown(), false, "no box while off")
    s.Clean("currency box")
end

---------------------------------------------------------------------------
-- The equipment pane
---------------------------------------------------------------------------
do
    local s = Session()
    local game, env, sheet, paper, C = s.game, s.env, s.sheet, s.paper, s.C
    game.Pass()
    game.Open("PaperDollFrame")
    local arrow, dialog, list = env.EraUIClassicEquipmentToggle, env.EraUIClassicEquipmentPane, paper.EquipmentManagerPane
    local anchor = { list:GetPoint(1) }
    Equal(dialog:IsShown(), false, "closed at first")
    True(arrow:GetNormalTexture():GetTexture():find("NextPage%-Up"), "the arrow points out")
    local w, h, right = env.EraUIClassic_CharacterSheetSize()
    Equal(w .. "," .. h .. "," .. right, "384,512,349", "the size while closed")
    local signals = game.signals
    game.Run(arrow, "OnClick")
    Equal(dialog:IsShown(), true, "the arrow opens the dialog")
    Equal(game.sounds[#game.sounds], "open", "with the open sound")
    Equal(game.signals, signals + 1, "and the laid-out signal")
    True(arrow:GetNormalTexture():GetTexture():find("PrevPage%-Up"), "the arrow points back")
    local x, y = s.Spot(dialog)
    Near(x, 343, "docked at (343, -8)")
    Near(y, -8, "its y")
    Equal(select(2, list:GetPoint(1)), dialog, "the game's set list in the dialog")
    Near(list:GetLeft() - dialog:GetLeft(), 14, "14 in")
    Equal(select(1, list:GetRegions()):GetAlpha(), 0, "its own art faded")
    Equal(list:IsShown(), true, "and shown")
    Equal(list:GetAlpha(), 1, "never muted while open")
    Equal(dialog:GetFrameLevel(), math.max(paper:GetFrameLevel(), list:GetFrameLevel() - 1), "the dialog just under the list")
    w, h, right = env.EraUIClassic_CharacterSheetSize()
    Equal(right, 349 + 246, "the size counts the open dialog (246 past the art)")
    local plate, darkPlate
    for _, region in ipairs({ dialog:GetRegions() }) do if region:GetTexture() and region:GetTexture():find("Header") then plate = region end end
    for _, entry in ipairs(game.darkened) do if entry[1] == "DarkWindowArt" and entry[2] == plate and entry[3] == "frame" then darkPlate = true end end
    True(darkPlate, "the header plate handed to Dark Windows")
    game.Run(arrow, "OnEnter")
    Equal(s.tips[#s.tips][1][1], "Equipment Manager", "the arrow's hover")
    local shut = dialog:GetChildren()
    game.Run(shut, "OnClick")
    Equal(dialog:IsShown(), false, "its X closes it")
    Equal(list:IsShown(), false, "the game's list hidden with it")
    Equal(game.sounds[#game.sounds], "close", "with the close sound")
    game.Run(arrow, "OnClick")
    dialog:Hide()
    Equal(select(3, env.EraUIClassic_CharacterSheetSize()), 349, "no extent while the dialog isn't shown")
    -- Turned off: given back.
    game.ns.db.characterSheet = false
    game.Pass()
    Equal(arrow:IsShown(), false, "the arrow hidden")
    Equal(select(2, list:GetPoint(1)), anchor[2], "the set list's own place given back")
    Equal(select(1, list:GetRegions()):GetAlpha(), 1, "and its art")
    s.Clean("equipment")
end

---------------------------------------------------------------------------
-- Off, on again, a fight, the copy, the rules
---------------------------------------------------------------------------
do
    local s = Session()
    local game, env, sheet, C = s.game, s.env, s.sheet, s.C
    game.ns.db.characterSheet = false
    game.Pass()
    Equal(C.built, false, "off at login: nothing built")
    Equal(game.ns.needsReload, nil, "nothing to reload for")
    game.ns.db.characterSheet = true
    game.Pass()
    game.Open("ReputationFrame")
    game.ns.db.characterSheet = false
    game.Pass()
    Equal(env.EraUIClassic_CharacterSheetActive, false, "the public flag off")
    Equal(game.ns.needsReload, true, "the option list asks for a reload")
    Equal(C.levelLine:IsShown(), false, "the level line hidden")
    Equal(C.tabs[1]:IsShown(), false, "EraUI's tabs hidden")
    Equal(C.sheetArt.general[1]:IsShown(), false, "the art hidden")
    Equal(C.rings.general:IsShown(), false, "the rings hidden")
    Equal(C.statBox:IsShown(), false, "the boxes hidden")
    Equal(C.resistColumn:IsShown(), false, "the resistances hidden")
    Equal(C.rotate[1]:IsShown(), false, "the rotate buttons hidden")
    Equal(env.PaperDollSidebarTabs:GetAlpha(), 1, "the sidebar tabs' alpha back")
    Equal(env.CharacterModelScene.GearEnchantAnimation:GetAlpha(), 1, "the enchant swirl back")
    for _, region in ipairs({ env.ReputationFrame:GetRegions() }) do
        if region:GetObjectType() == "FontString" then Equal(region:IsShown(), false, "the reputation labels hidden") end
    end
    game.Pass()
    Equal(game.ns.needsReload, true, "restore is safe to repeat")
    game.ns.db.characterSheet = true
    game.Pass()
    Equal(C.rotate[1]:IsShown(), true, "on again: the rotate buttons back")
    Equal(C.resistColumn:IsShown(), true, "and the resistances")
    Equal(C.statBox:IsShown(), true, "and the boxes")
    -- The game's objects are sealed: this very write is what the mock refuses.
    local fine = pcall(function() env.CharacterHeadSlot.eraMark = true end)
    Equal(fine, false, "a key written on a game frame fails the run")
    s.Clean("off and on")
end
do
    local s = Session()
    local game, env, sheet, C = s.game, s.env, s.sheet, s.C
    game.Pass()
    game.Open("PaperDollFrame")
    local slot = env.CharacterHeadSlot
    game.State(slot).protected = true
    game.State(env.CharacterModelScene).protected = true
    slot:ClearAllPoints()
    slot:SetPoint("TOPLEFT", env.PaperDollItemsFrame, "TOPLEFT", 0, 0)
    game.combat = true
    sheet:UpdateSize()
    Equal(select(4, slot:GetPoint(1)), 0, "a guarded slot isn't moved in a fight")
    Near(sheet:GetWidth(), 384, "the window itself is still sized")
    game.combat = false
    game.Fire("PLAYER_REGEN_ENABLED")
    Near(s.Spot(slot), 21, "the layout catches up at the fight's end")
    s.Clean("fight")
end
do
    local s = Session()
    local game, env, C = s.game, s.env, s.C
    Equal(env.EraUIClassic_SkinCharacterCopy(nil), false, "no frame: false")
    local copy = env.CreateFrame("Frame", nil, env.UIParent)
    Equal(env.EraUIClassic_SkinCharacterCopy(copy), false, "the copy reports the sheet off")
    local pieces = 0
    for _, region in ipairs({ copy:GetRegions() }) do if region:GetObjectType() == "Texture" then pieces = pieces + 1 end end
    Equal(pieces, 8, "both art sets on the copy")
    Equal(select(1, copy:GetRegions()):IsShown(), false, "hidden while the sheet is off")
    game.Pass()
    Equal(env.EraUIClassic_SkinCharacterCopy(copy), true, "the copy reports the sheet on")
    Equal(select(1, copy:GetRegions()):IsShown(), true, "shown while it's on")
    Equal(env.EraUIClassic_SkinCharacterCopy(copy), true, "once only")
    pieces = 0
    for _, region in ipairs({ copy:GetRegions() }) do if region:GetObjectType() == "Texture" then pieces = pieces + 1 end end
    Equal(pieces, 8, "nothing added the second time")
    s.Clean("copy")
end

-- (No GameTooltip, MouseIsOver or key binding in any Look file: Tools/TestRules.mjs.)
print("Character sheet checks passed: " .. checks .. " assertions.")
