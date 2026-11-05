-- The window chrome ("panels", Look/Chrome*.lua, clean-room 2026-10-21) on a
-- sealed mock of Forever's windows (Tools/WindowMockGame.lua: any key EraUI
-- writes on one of the game's objects fails). What 12-windows-settings.md
-- section 5 asks: which windows, the gate (the chrome on, each window's /era
-- switch, a nine-slice), the metal border (corners through the art lookup,
-- bottom corners lifted once, the plain top left tucked in), the edges, the
-- portrait, the title, the stone and its streaks, the marble floor in a
-- plain inset, the title strip, the red X and the size pair, the tabs (lift
-- once and again after a move, width from text and padding, the game's own
-- resize), the 1.x scroll bars, each window's extras (world map, merchant,
-- friends, quest and gossip, rewards, trade, item text, guild control, the
-- bank's hand-over, the group finder's listing, inspect, macros,
-- collections), the loot window (its size held, panel, rows, pages), Dark
-- Windows' hand-overs, the ADDON_LOADED dressing and restore.
-- Run from the addon folder: fengari Tools/TestWindowChrome.lua
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function Near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

local Mock = dofile("Tools/WindowMockGame.lua")
local FILES = { "Look/Base.lua", "Look/ChromeKit.lua", "Look/ChromeWindow.lua", "Look/ChromeExtras.lua",
    "Look/ChromeLoot.lua", "Look/ChromeModule.lua" }
local MEDIA = "Interface\\AddOns\\EraUI\\Media\\Classic\\"

local game, st, env, ns, Look
-- The game's named frames and functions, as globals here too.
setmetatable(_G, { __index = function(_, key) return env and rawget(env, key) end })

local function Anchor(region, index)
    local point, relative, relativePoint, x, y = region:GetPoint(index or 1)
    return point, relative, relativePoint, x, y
end
local function At(region, point)
    local s = st[region]
    return s.points[point]
end
local function Spot(region, point)
    local anchor = At(region, point)
    if not anchor then return "none" end
    return string.format("%s %s %s,%s", anchor[3], tostring(anchor[2] and anchor[2]:GetName() or "?"), tostring(anchor[4]),
        tostring(anchor[5]))
end
local function Coords(region) return table.concat(st[region].coords, ",") end

-- The game's windows, as the game makes them.
local function World()
    local Window = game.Window
    Window("TaxiFrame", { inset = true, tabs = 2 })
    Window("CalendarFrame")
    Window("AddonList", { width = 600, height = 550 })
    Window("FriendsFrame", { width = 385, tabs = 3, inset = true })
    Window("MailFrame")
    Window("ProfessionsFrame", { inset = true })
    Window("NoSliceFrame", { noNineSlice = true })
    -- The merchant: its foot pieces, buttons and label slots.
    local merchant = Window("MerchantFrame", { inset = true })
    local foot = game.New("Texture", "MerchantFrameBottomLeftBorder", merchant, "BORDER")
    foot:SetAtlas("merchant-bottom")
    game.New("Texture", nil, merchant, "ARTWORK"):SetAtlas("merchant-other")
    game.New("Button", "MerchantSellAllJunkButton", merchant):SetPoint("BOTTOMLEFT", merchant, "BOTTOMLEFT", 10, 10)
    local buyback = game.New("Button", "MerchantBuyBackItem", merchant)
    game.New("Texture", "MerchantBuyBackItemNameFrame", buyback, "BACKGROUND")
    for i = 1, 12 do
        local item = game.New("Frame", "MerchantItem" .. i, merchant)
        game.New("Texture", "MerchantItem" .. i .. "NameFrame", item, "BACKGROUND")
    end
    local extra = game.New("Frame", "MerchantExtraCurrencyInset", merchant)
    game.New("Texture", nil, extra, "BACKGROUND")
    env.MerchantFrame_UpdateRepairButtons = function()
        MerchantSellAllJunkButton:ClearAllPoints()
        MerchantSellAllJunkButton:SetPoint("BOTTOMLEFT", merchant, "BOTTOMLEFT", 99, 99)
    end
    -- The game's two merchant pages: the only places that show and hide the foot.
    env.MerchantFrame_UpdateMerchantInfo = function() foot:Show() end
    env.MerchantFrame_UpdateBuybackInfo = function() foot:Hide() end
    -- Quest and gossip NPC windows, with parchment backgrounds.
    local quest = Window("QuestFrame", { height = 496, bg = "Interface\\QuestFrame\\QuestBG-Parchment" })
    local scroll = game.New("ScrollFrame", "QuestDetailScrollFrame", quest)
    st[scroll].width, st[scroll].height = 300, 403
    local page = game.New("Frame", nil, scroll)
    st[page].width, st[page].height = 300, 600
    scroll:SetScrollChild(page)
    local panel = game.New("Frame", "QuestFrameDetailPanel", quest)
    st[panel].width, st[panel].height = 330, 450
    local panelBg = game.New("Texture", nil, panel, "BACKGROUND")
    panelBg:SetPoint("TOPLEFT", quest, "TOPLEFT", 9, -60)
    game.Own(panel, "Bg", panelBg)
    local rewards = game.New("Frame", "QuestInfoRewardsFrame", quest)
    local function RewardButton(name)
        local button = game.New("Button", name, rewards)
        st[button].width, st[button].height = 147, 41
        game.Own(button, "NameFrame", game.New("Texture", nil, button, "BACKGROUND"))
        game.Own(button, "IconBorder", game.New("Texture", nil, button, "ARTWORK"))
        return button
    end
    game.Own(rewards, "RewardButtons", { RewardButton(nil) })
    RewardButton("QuestInfoItem1")
    env.QuestInfo_Display = function() end
    env.QuestInfo_ShowRewards = function() end
    local gossip = Window("GossipFrame", { height = 520 })
    local greeting = game.New("Frame", nil, gossip)
    st[greeting].width, st[greeting].height = 330, 450
    game.Own(gossip, "GreetingPanel", greeting)
    local ground = game.New("Texture", nil, gossip, "BACKGROUND")
    ground:SetPoint("TOPLEFT", gossip, "TOPLEFT", 0, 0)
    game.Own(gossip, "Background", ground)
    -- Trade, item text.
    local trade = Window("TradeFrame")
    local overlay = game.New("Frame", nil, trade)
    game.Own(trade, "RecipientOverlay", overlay)
    game.Own(overlay, "portrait", game.New("Texture", nil, overlay, "ARTWORK"))
    game.Own(overlay, "portraitFrame", game.New("Texture", nil, overlay, "OVERLAY"))
    local book = Window("ItemTextFrame")
    local bookScroll = game.New("ScrollFrame", "ItemTextScrollFrame", book)
    st[bookScroll].width, st[bookScroll].height = 300, 300
    game.ThinBar(bookScroll)
    -- The world map's border with its size pair.
    local map = game.New("Frame", "WorldMapFrame", env.UIParent)
    st[map].width, st[map].height = 700, 500
    map:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
    local border = Window(nil, {})
    border:SetParent(map)
    game.Own(map, "BorderFrame", border)
    local pair = game.New("Frame", nil, border)
    game.Own(border, "MaximizeMinimizeFrame", pair)
    game.Own(pair, "MaximizeButton", game.New("Button", nil, pair))
    game.Own(pair, "MinimizeButton", game.New("Button", nil, pair))
    game.Own(map, "Minimize", function() game.mapSize = "small" end)
    game.Own(map, "Maximize", function() game.mapSize = "big" end)
    -- The bank (handed to the bags area's own dressing), the group finder's listing.
    Window("BankFrame")
    local listing = Window("LFGListingFrame")
    game.New("Button", "LFGParentFrameCloseButton", listing)
    env.PanelTemplates_TabResize = function(tab, padding)
        tab:SetWidth(30 + (padding or 0))
    end
end

local function Session(settings, mockOptions)
    game = Mock.New(mockOptions)
    st, env, ns = game.st, game.env, game.ns
    for key, value in pairs(settings or {}) do game.settings[key] = value end
    game.Building(World)
    ns.db = { panels = true }
    game.allowed = {}
    -- Core/Integration.lua's question: each window's /era switch by name.
    ns.WindowAllowed = function(window) return game.allowed[window:GetName() or "unnamed"] ~= false end
    game.banked = {}
    ns.SkinBank = function(bank) game.banked[#game.banked + 1] = { bank, game.darkForced } end
    Look = game.Load(FILES)
    return game
end

local function NoErrors(label)
    Equal(table.concat(game.errors, " || "), "", label .. ": no error handed to the game's error handler")
end

---------------------------------------------------------------------------
-- Registry
---------------------------------------------------------------------------
Session()
local entry = game.Module("panels")
Equal(entry ~= nil and type(entry.apply) == "function" and type(entry.restore) == "function", true, "one registry entry, panels")
Equal(#ns.modules, 1, "and no other")
Equal(Look.ART.frameMetal.client, "Interface\\FrameGeneral\\UIFrameMetal", "the metal corners from the game's file")
Equal(Look.ART.frameMetal.theme, "frameMetal", "Dark Mode's key for them")
Equal(ns.WindowPiece(TaxiFrame, "backing"), nil, "nothing dressed before the first pass")

---------------------------------------------------------------------------
-- A portrait window, in its defaults
---------------------------------------------------------------------------
game.Pass()
local slice = TaxiFrame.NineSlice
local ring = { 135 / 512, 267 / 512, 135 / 512, 267 / 512 }
local function Cut(texture, want)
    local c = st[texture].coords
    for i = 1, 4 do if not Near(c[i], want[i]) then return false end end
    return true
end
Equal(st[slice.TopLeftCorner].file, "Interface\\FrameGeneral\\UIFrameMetal", "the corners wear the metal sheet")
Equal(Cut(slice.TopLeftCorner, ring), true, "the top left is the ring (the portrait's hole)")
Equal(Cut(slice.TopRightCorner, { 1 / 512, 133 / 512, 135 / 512, 267 / 512 }), true, "the top right's piece")
Equal(Cut(slice.BottomLeftCorner, { 1 / 512, 133 / 512, 1 / 512, 133 / 512 }), true, "the bottom left's")
Equal(Cut(slice.BottomRightCorner, { 135 / 512, 267 / 512, 1 / 512, 133 / 512 }), true, "the bottom right's")
Equal(st[slice.TopLeftCorner].width .. "x" .. st[slice.TopLeftCorner].height, "132x132", "each 132 square")
Equal(select(5, Anchor(slice.BottomLeftCorner)), 7, "a bottom corner lifted 10 (from -3)")
Equal(select(5, Anchor(slice.BottomRightCorner)), 7, "both of them")
Equal(select(4, Anchor(slice.TopLeftCorner)), -13, "the ring's top left stays where the game put it")
local top = slice.TopEdge
Equal(st[top].file, "Interface\\FrameGeneral\\UIFrameMetalHorizontal", "the top edge from the horizontal sheet")
Equal(Cut(top, { 0, 1, 135 / 512, 183 / 512 }), true, "its 48-row band")
Equal(st[top].width .. "x" .. st[top].height .. " " .. table.concat(st[top].wrap, "/") .. " " .. tostring(st[top].htile),
    "128x48 REPEAT/CLAMP true", "128 x 48, repeating across")
Equal(st[slice.BottomEdge].height, 132, "the bottom edge 132 tall")
local left = slice.LeftEdge
Equal(st[left].file .. " " .. st[left].width .. " " .. table.concat(st[left].wrap, "/") .. " " .. tostring(st[left].vtile),
    "Interface\\FrameGeneral\\UIFrameMetalVertical 132 CLAMP/REPEAT true", "the side edges from the vertical sheet, repeating down")
Equal(Cut(slice.RightEdge, { 135 / 512, 267 / 512, 0, 1 }), true, "the right edge's column")
local face = TaxiFrame.PortraitContainer.portrait
Equal(st[face].width .. "x" .. st[face].height .. " " .. Spot(face, "TOPLEFT"), "61x61 TOPLEFT TaxiFrame -6,8", "the portrait 61 square in the ring")
local title = TaxiFrame.TitleContainer
Equal(Spot(title, "TOPLEFT") .. " / " .. Spot(title, "TOPRIGHT"), "TOPLEFT TaxiFrame 58,0 / TOPRIGHT TaxiFrame -58,0", "the title between the ring and the X")
local stone = ns.WindowPiece(TaxiFrame, "backing")
Equal(st[stone].file, MEDIA .. "UI-Background-Rock", "the stone: EraUI's own rock")
Equal(st[stone].layer .. " " .. st[stone].sublevel .. " " .. table.concat(st[stone].wrap, "/"), "BACKGROUND -2 REPEAT/REPEAT",
    "under everything, repeating both ways")
Equal(Spot(stone, "TOPLEFT") .. " / " .. Spot(stone, "BOTTOMRIGHT"), "TOPLEFT TaxiFrame 0,0 / BOTTOMRIGHT TaxiFrame 0,0", "over the whole window")
Equal(game.themed[stone], nil, "set straight from its file (Dark Mode doesn't tint it)")
Equal(st[TaxiFrame.Bg].alpha, 0, "the window's own rock faded")
Equal(st[TaxiFrame.TopTileStreaks].alpha, 0, "its streaks faded")
local streaks = ns.WindowPiece(TaxiFrame, "streaks")
Equal(st[streaks].file .. " " .. Coords(streaks) .. " " .. st[streaks].height, MEDIA .. "_UI-Frame 0,1,0.671875,0.9609375 37",
    "the band of streaks from the frame sheet, 37 tall")
Equal(Spot(streaks, "TOPLEFT") .. " / " .. Spot(streaks, "TOPRIGHT"), "TOPLEFT TaxiFrame 0,-21 / TOPRIGHT TaxiFrame -2,-21", "under the title")
local floor = ns.WindowPiece(TaxiFrame, "insetFloor")
Equal(st[floor].file .. " " .. st[floor].layer .. st[floor].sublevel, MEDIA .. "UI-Background-Marble BACKGROUND-1", "the marble floor")
Equal(Spot(floor, "TOPLEFT") .. " / " .. Spot(floor, "BOTTOMRIGHT"), "TOPLEFT TaxiFrameInset 0,0 / BOTTOMRIGHT TaxiFrameInset 0,0", "filling the inset")
Equal(st[TaxiFrame.Inset.NineSlice.TopEdge].alpha .. st[TaxiFrame.Inset.Bg].alpha, "00", "the inset's own art faded")
local strip = ns.WindowPiece(TaxiFrame, "titleStrip")
Equal(st[strip].file .. " " .. Coords(strip) .. " " .. st[strip].height .. " " .. st[strip].layer .. st[strip].sublevel,
    MEDIA .. "_UI-Frame 0,1,0.2890625,0.421875 17 BACKGROUND0", "the stone title strip, 17 tall")
Equal(Spot(strip, "TOPLEFT") .. " / " .. Spot(strip, "TOPRIGHT"), "TOPLEFT TaxiFrame 2,-3 / TOPRIGHT TaxiFrame -25,-3", "across the top")
local close = TaxiFrameCloseButton
Equal(st[close].width .. "x" .. st[close].height, "32x32", "the X 32 square")
Equal(st[close:GetNormalTexture()].file, "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", "in the 1.x red X")
Equal(st[close:GetHighlightTexture()].blend, "ADD", "its glow additive")
local cx = At(close, "TOPRIGHT")
Equal(cx[2] == slice.TopRightCorner and cx[4] == 0.6 and cx[5] == -11, true, "at the metal's top right corner")
Equal(game.dark[close], "cross", "handed to Dark Windows")
-- Tabs: the first hangs on the window, so it's lifted; the second hangs on the first.
local tab1, tab2 = TaxiFrameTab1, TaxiFrameTab2
Equal(st[tab1.LeftActive].file, "Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab", "the tab's active art")
Equal(Coords(tab1.LeftActive) .. " " .. st[tab1.LeftActive].width .. "x" .. st[tab1.LeftActive].height, "0,0.15625,0,0.546875 20x35",
    "its active left piece")
Equal(Spot(tab1.Left, "TOPLEFT") .. " " .. st[tab1.Left].height, "TOPLEFT TaxiFrameTab1 0,-4 32", "its inactive left piece 4 lower")
Equal(st[tab1.Left].htile, false, "no tiling")
Equal(st[tab1.LeftHighlight].alpha, 0, "the modern highlight faded")
Equal(select(5, Anchor(tab1)), 12, "the first tab lifted 10")
Equal(select(5, Anchor(tab2)), 0, "the next one (hung on the first) not")
Equal(st[tab1].width .. " " .. st[tab1.Middle].width .. " " .. st[tab1.MiddleActive].width, "80 40 40",
    "its width from its text (30) plus 50, the middles 40 less")
local glow = tab1:GetHighlightTexture()
Equal(st[glow].file .. " " .. st[glow].blend .. " " .. Spot(glow, "TOPLEFT"), "Interface\\PaperDollInfoFrame\\UI-Character-Tab-RealHighlight ADD TOPLEFT TaxiFrameTab1 3,5",
    "its glow")
-- Dark Windows: the four edges, stone, streaks and title strip, painted with force.
for _, piece in ipairs({ slice.TopEdge, slice.BottomEdge, slice.LeftEdge, slice.RightEdge, stone, streaks, strip }) do
    Equal(game.dark[piece], "frame", "handed to Dark Windows as frame art")
end
Equal(game.dark[floor], nil, "the floor isn't")
-- Dressed again (the world map is on a resize): nothing lifted twice, painted again.
local forced = game.darkForced
ns.SkinWindow(TaxiFrame, {})
Equal(select(5, Anchor(slice.BottomLeftCorner)) .. " " .. select(5, Anchor(tab1)), "7 12", "dressed again: lifted once only")
Equal(game.darkForced - forced, 7, "dressed again: its seven pieces painted again, once each")
-- Something else moves a tab: lifted again from there.
tab1:SetPoint("TOPLEFT", TaxiFrame, "BOTTOMLEFT", 11, -2)
ns.FitBottomTab(tab1)
Equal(select(5, Anchor(tab1)), 8, "a tab moved by the game: lifted again")
ns.FitBottomTab(tab1)
Equal(select(5, Anchor(tab1)), 8, "and only once")
-- A custom padding is kept for the tab; the game's own resize refits.
ns.FitBottomTab(tab2, 38)
Equal(st[tab2].width, 30 + 38, "a padding of 38 (the social windows')")
PanelTemplates_TabResize(tab2, 0)
Equal(st[tab2].width, 68, "the game's own resize: fitted again at once, keeping that padding")
local other = game.New("Button", nil, env.UIParent)
game.TabPieces(other, "Other")
PanelTemplates_TabResize(other, 5)
Equal(st[other].width, 35, "a tab EraUI never dressed: the game's own size")
NoErrors("the defaults")

---------------------------------------------------------------------------
-- No ring, lifts, the gate, a window without a nine-slice
---------------------------------------------------------------------------
-- No ring: only the top left is the plain piece (a top left shape); the
-- other three are the ring window's, so they meet the same edges. The plain
-- piece on all four drew stray metal lines inside the AddOn List (2026-10-22).
local PLAIN = { 269 / 512, 401 / 512, 1 / 512, 133 / 512 }
local RING_REST = { TopRightCorner = { 1 / 512, 133 / 512, 135 / 512, 267 / 512 },
    BottomLeftCorner = { 1 / 512, 133 / 512, 1 / 512, 133 / 512 }, BottomRightCorner = { 135 / 512, 267 / 512, 1 / 512, 133 / 512 } }
local function NoRingCorners(nine, label)
    Equal(Cut(nine.TopLeftCorner, PLAIN), true, label .. ": the plain top left")
    for key, want in pairs(RING_REST) do
        Equal(Cut(nine[key], want), true, label .. ": " .. key .. " the ring window's piece")
        Equal(Cut(nine[key], PLAIN), false, label .. ": " .. key .. " not the plain top left piece")
        Equal(Cut(nine[key], st[TaxiFrame.NineSlice[key]].coords), true, label .. ": " .. key .. " the same as the portrait window's")
        Equal(st[nine[key]].width .. "x" .. st[nine[key]].height, "132x132", label .. ": " .. key .. " 132 square")
    end
end
local cal = CalendarFrame.NineSlice
NoRingCorners(cal, "calendar")
Equal(select(4, Anchor(cal.TopLeftCorner)), -8, "the plain top left tucked in to -8")
Equal(select(4, Anchor(cal.TopRightCorner)) .. " " .. select(4, Anchor(cal.BottomRightCorner)), "4 4", "the right corners not tucked")
Equal(select(5, Anchor(cal.BottomLeftCorner)) .. " " .. select(5, Anchor(cal.BottomRightCorner)), "7 7", "its bottom corners lifted 10")
local addons = AddonList.NineSlice
NoRingCorners(addons, "the AddOn List")
Equal(select(4, Anchor(addons.TopLeftCorner)), -8, "the AddOn List: its plain top left tucked in")
Equal(select(4, Anchor(addons.BottomLeftCorner)), -13, "the AddOn List: its bottom left keeps the game's x (only the plain top left is tucked)")
ns.SkinWindow(AddonList, { noRing = true })
NoRingCorners(addons, "the AddOn List dressed again")
Equal(select(4, Anchor(addons.TopLeftCorner)) .. " " .. select(5, Anchor(addons.BottomRightCorner)), "-8 7", "dressed again: tucked and lifted once")
Equal(Cut(slice.TopLeftCorner, ring), true, "a portrait window's top left still the ring")
Equal(st[CalendarFrame.PortraitContainer.portrait].width, 62, "no ring: the portrait left alone")
Equal(Spot(CalendarFrame.TitleContainer, "TOPLEFT"), "TOPLEFT CalendarFrame 6,0", "the title from 6 in")
Equal(Spot(ns.WindowPiece(CalendarFrame, "titleStrip"), "TOPLEFT"), "TOPLEFT CalendarFrame 6,-3", "the title strip too")
Equal(select(5, Anchor(FriendsFrame.NineSlice.BottomLeftCorner)), 2, "friends: lifted 5")
Equal(select(5, Anchor(FriendsFrameTab1)), 5, "and its tab 3")
Equal(st[FriendsFrame].width, 360, "friends: 385 wide becomes 360")
Equal(table.concat(st[ns.WindowPiece(FriendsFrame, "insetFloor")].colour, ","), "0.9,0.9,0.9,1", "its floor in the pane shade")
Equal(ns.WindowPiece(NoSliceFrame, "titleStrip"), nil, "a window with no nine-slice isn't dressed")
Equal(ns.WindowPiece(MailFrame, "titleStrip") ~= nil, true, "mail is")
Equal(ns.WindowPiece(MailFrame, "insetFloor"), nil, "a window with no inset: no floor")
Equal(ns.WindowPiece(ProfessionsFrame, "titleStrip") ~= nil, true, "the professions window is dressed")
Equal(ns.WindowPiece(ProfessionsFrame, "insetFloor"), nil, "with no floor: the inset of that name is the search pop-up's")
Equal(st[ProfessionsFrameInset.Bg].alpha ~= 0, true, "and that inset's art left alone")
-- The gate: refused, tried again on the next pass once allowed.
Session()
game.allowed.MerchantFrame = false
game.Pass()
Equal(ns.WindowPiece(MerchantFrame, "titleStrip"), nil, "Merchant's /era switch off: the merchant stays modern")
Equal(ns.WindowPiece(TaxiFrame, "titleStrip") ~= nil, true, "the others dressed")
game.allowed.MerchantFrame = true
game.Pass()
Equal(ns.WindowPiece(MerchantFrame, "titleStrip") ~= nil, true, "switched on: dressed on the next pass")
-- Chrome off from login: nothing at all, and no reload asked for.
Session()
ns.db.panels = false
game.Pass()
Equal(ns.WindowPiece(TaxiFrame, "titleStrip"), nil, "the chrome off: nothing dressed")
Equal(ns.needsReload, nil, "and nothing to clear, so no reload asked for")
Equal(ns.SkinWindow(TaxiFrame, {}), false, "nor dressed by hand while off")
NoErrors("the gate")

---------------------------------------------------------------------------
-- Windows that load later, and restore
---------------------------------------------------------------------------
Session()
game.Pass()
local inspect = game.Building(function()
    local window = game.Window("InspectFrame")
    local tabs = game.New("Frame", "InspectUITabs", window)
    game.Own(window, "ModeTabs", tabs)
    local guildTab = game.New("Frame", nil, tabs)
    game.Own(tabs, "GuildTab", guildTab)
    game.Own(tabs, "Tabs", { game.New("Frame", nil, tabs), guildTab })
    for _, side in ipairs(tabs.Tabs) do side:EnableMouse(true) end
    game.New("Button", "InspectFrameTab1", window)
    game.New("Button", "InspectFrameTab2", window)
    local head = game.New("Button", "InspectHeadSlot", window)
    game.Own(head, "BorderFrame", game.New("Texture", nil, head, "OVERLAY"))
    env.INSPECTPAPERDOLLFRAME_SLOTS = { "InspectHeadSlot" }
    return window
end)
game.Seal()
game.combat = true
game.Fire("ADDON_LOADED", "Blizzard_InspectUI")
game.combat = false
Equal(ns.WindowPiece(inspect, "titleStrip") ~= nil, true, "a window loading later (in a fight too) is dressed as it loads")
Equal(Spot(ns.WindowPiece(inspect, "backing"), "BOTTOMRIGHT"), "BOTTOMRIGHT InspectFrame 0,4", "inspect: the stone 4 short of the foot")
Equal(st[InspectHeadSlot.BorderFrame].alpha, 0, "its slots' modern borders faded")
inspect:Show()
game.Tick(0.05)
Equal(st[inspect.ModeTabs].alpha .. " " .. tostring(st[inspect.ModeTabs.Tabs[1]].mouse), "0 false", "its side tabs out of sight and reach")
Equal(st[InspectFrameTab1].shown, true, "the bottom tabs shown while the guild side tab is")
inspect.ModeTabs.GuildTab:Hide()
game.Tick(0.05)
Equal(tostring(st[InspectFrameTab1].shown) .. tostring(st[InspectFrameTab2].shown), "falsefalse", "and hidden when it isn't")
-- Restore: the title strips hidden, a reload asked for; nothing else undone.
ns.db.panels = false
game.Pass()
Equal(st[ns.WindowPiece(TaxiFrame, "titleStrip")].shown, false, "the chrome off: the title strips hidden")
Equal(st[ns.WindowPiece(TaxiFrame, "backing")].shown, true, "the rest stays until the reload")
Equal(ns.needsReload, true, "a reload asked for")
local late = game.Building(function() return game.Window("MacroFrame") end)
game.Seal()
game.Fire("ADDON_LOADED", "Blizzard_MacroUI")
Equal(ns.WindowPiece(late, "titleStrip"), nil, "off: a window loading now isn't dressed")
NoErrors("later windows and restore")

---------------------------------------------------------------------------
-- The world map's border and its size buttons
---------------------------------------------------------------------------
Session()
game.Pass()
local border = WorldMapFrame.BorderFrame
local pair = border.MaximizeMinimizeFrame
Equal(st[border.PortraitContainer.portrait].alpha, 0, "the map's border: no portrait")
Equal(ns.WindowPiece(border, "backing"), nil, "no stone")
Equal(Cut(border.NineSlice.TopLeftCorner, { 269 / 512, 401 / 512, 1 / 512, 133 / 512 }), true, "the plain metal")
NoRingCorners(border.NineSlice, "the map's border")
Equal(select(5, Anchor(border.NineSlice.BottomLeftCorner)), 2, "lifted 5")
local bigger, smaller = pair.MaximizeButton, pair.MinimizeButton
Equal(st[bigger:GetNormalTexture()].file .. " " .. st[smaller:GetPushedTexture()].file,
    "Interface\\Buttons\\UI-Panel-BiggerButton-Up Interface\\Buttons\\UI-Panel-SmallerButton-Down", "the 1.x bigger and smaller buttons")
Equal(st[bigger:GetHighlightTexture()].file, "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "with the X's glow")
Equal(table.concat(st[bigger].hitInsets, ","), "5,5,5,5", "their hit area 5 in")
Equal(game.dark[bigger] .. game.dark[smaller], "crosscross", "both handed to Dark Windows")
Equal(st[pair].width .. " " .. Spot(pair, "RIGHT"), "32 LEFT ? 8,0", "the pair 32 square, left of the X")
forced = game.darkForced
WorldMapFrame:Minimize()
Equal(game.mapSize, "small", "the game's own Minimize ran")
Equal(game.darkForced, forced, "the border isn't dressed again in the same call")
game.NextFrame()
Equal(game.darkForced > forced, true, "the frame after, the border is dressed again (its art painted again)")
ns.db.panels = false
game.Pass()
forced = game.darkForced
WorldMapFrame:Maximize()
game.NextFrame()
Equal(game.darkForced, forced, "with the chrome off, a resize dresses nothing")
Equal(game.hookCounts[WorldMapFrame].Minimize .. game.hookCounts[WorldMapFrame].Maximize, "11", "each hooked once")
-- A copy of the public pair skin on any frame holding the two buttons.
local holder = game.New("Frame", nil, env.UIParent)
game.Own(holder, "MaximizeButton", game.New("Button", nil, holder))
game.Own(holder, "MinimizeButton", game.New("Button", nil, holder))
ns.SkinMaxMinButtons(holder)
Equal(st[holder.MinimizeButton:GetNormalTexture()].file, "Interface\\Buttons\\UI-Panel-SmallerButton-Up", "ns.SkinMaxMinButtons on any pair")
NoErrors("the world map")

---------------------------------------------------------------------------
-- The merchant
---------------------------------------------------------------------------
Session()
game.Pass()
local foot = MerchantFrameBottomLeftBorder
Equal(st[foot].file, MEDIA .. "UI-Merchant-BottomBorder", "the merchant's foot: the old art on the game's own piece")
Equal(Coords(foot) .. " " .. st[foot].width .. "x" .. st[foot].height .. " " .. st[foot].layer .. st[foot].sublevel .. " " .. st[foot].alpha,
    "0,1,0,0.4765625 256x61 OVERLAY0 1", "its left part")
Equal(Spot(foot, "BOTTOMLEFT"), "BOTTOMLEFT MerchantFrame 1,26", "on the merchant's foot")
local footRight = Look.OwnPiece(MerchantFrame, "chrome.merchantFootRight")
Equal(Coords(footRight) .. " " .. st[footRight].width .. "x" .. st[footRight].height .. " " .. Spot(footRight, "LEFT"),
    "0,0.296875,0.4765625,0.953125 76x61 RIGHT MerchantFrameBottomLeftBorder 0,0", "its right part beside it")
MerchantFrame:Show()
foot:Hide()
Equal(st[footRight].shown, false, "the right part hides with the left")
foot:Show()
Equal(st[footRight].shown, true, "and shows with it")
Equal(#(st[foot].hooks.OnShow or {}) .. #(st[foot].hooks.OnHide or {}), "11", "the left part's show and hide hooked once each")
Equal(game.hookCounts[env] and game.hookCounts[env].MerchantFrame_UpdateBuybackInfo, nil,
    "with the texture's own scripts, the game's pages aren't hooked")
local junk = At(MerchantSellAllJunkButton, "BOTTOMLEFT")
Equal(junk[4] .. "," .. junk[5], "176,33", "Sell All Junk on the old foot")
Equal(Spot(MerchantBuyBackItem, "TOPLEFT"), "BOTTOMLEFT MerchantItem10 44,-53", "Buyback under the tenth item")
MerchantFrame_UpdateRepairButtons()
junk = At(MerchantSellAllJunkButton, "BOTTOMLEFT")
Equal(junk[4] .. "," .. junk[5], "176,33", "the game placing its buttons again: put back at once")
Equal(st[MerchantItem7NameFrame].file .. " " .. st[MerchantBuyBackItemNameFrame].file,
    MEDIA .. "UI-Merchant-LabelSlots " .. MEDIA .. "UI-Merchant-LabelSlots", "the old label slots behind each name")
local merchantArt = game.FindAll(function(s, obj) return s.parent == MerchantFrame and s.kind == "Texture" and s.atlas == "merchant-other" end)
Equal(st[merchantArt[1]].alpha, 0, "the merchant's own art faded")
Equal(st[ns.WindowPiece(MerchantFrame, "titleStrip")].alpha, 1, "but not EraUI's own pieces")
Equal(st[MerchantFrameInset.NineSlice.TopEdge].alpha, 0, "its inset's art faded, all the way down")
local extraArt = st[MerchantExtraCurrencyInset].regions[1]
Equal(st[extraArt].alpha, 0, "and the extra currency box's")
NoErrors("the merchant")

---------------------------------------------------------------------------
-- Quest and gossip NPC windows
---------------------------------------------------------------------------
Equal(st[QuestFrame].height, 427, "the quest window 69 shorter (496)")
Equal(st[QuestDetailScrollFrame].height, 334, "its scroll frame too")
Equal(st[QuestDetailScrollFrame:GetScrollChild()].height, 334, "a page taller than its scroll frame cut to it")
Equal(st[QuestDetailScrollFrame].rectUpdates, 1, "and the scroll frame told")
Equal(st[QuestFrameDetailPanel].height, 381, "a panel taller than 400 69 shorter")
local panelBg = QuestFrameDetailPanel.Bg
Equal(Spot(panelBg, "BOTTOMLEFT"), "BOTTOMLEFT QuestFrame 9,27", "its background ending at the new foot")
Equal(st[QuestFrame.Bg].alpha, 1, "the quest window's parchment kept")
Equal(Spot(ns.WindowPiece(QuestFrame, "backing"), "BOTTOMRIGHT"), "BOTTOMRIGHT QuestFrame -5,0", "the stone 5 short of the right edge")
ns.SkinWindow(QuestFrame, { lift = 5, stoneRight = 5, extras = Look.Chrome.extras.Quest })
Equal(st[QuestFrame].height, 427, "dressed again: shortened once only")
local plate = game.Find(function(s) return s.parent == QuestInfoItem1 and s.kind == "Texture" and s.file == MEDIA .. "UI-QuestItemNameFrame" end)
Equal(plate ~= nil, true, "a reward on the old item name plate")
Equal(st[plate].layer .. st[plate].sublevel, "BACKGROUND1", "behind the name")
Equal(Near(st[plate].width, 107 / (106 / 128)) and Near(st[plate].height, 39 / (42 / 64)), true, "drawn to read 107 x 39")
Equal(Near(At(plate, "LEFT")[4], 38 - st[plate].width * 11 / 128), true, "from 38 in")
Equal(st[QuestInfoItem1.NameFrame].alpha .. st[QuestInfoItem1.IconBorder].alpha, "00", "its modern frame faded")
Equal(game.Find(function(s) return s.parent == QuestInfoRewardsFrame.RewardButtons[1] and s.file == MEDIA .. "UI-QuestItemNameFrame" end) ~= nil,
    true, "the rewards frame's own buttons too")
local second = game.Building(function()
    local button = game.New("Button", "QuestInfoItem2", QuestInfoRewardsFrame)
    game.Own(button, "NameFrame", game.New("Texture", nil, button, "BACKGROUND"))
    return button
end)
game.Seal()
QuestInfo_Display()
Equal(st[second.NameFrame].alpha, 0, "a reward the game adds: dressed after its QuestInfo_Display")
Equal(st[GossipFrame].height, 451, "gossip: 69 shorter")
Equal(st[GossipFrame.GreetingPanel].height, 381, "its greeting panel too")
Equal(Spot(GossipFrame.Background, "BOTTOMLEFT"), "BOTTOMLEFT GossipFrame 0,27", "its background ends at the new foot")
-- A window under 470 tall is left its height.
local short = game.Building(function() return game.Window("ShortQuest", { height = 420 }) end)
game.Seal()
ns.SkinWindow(short, { extras = Look.Chrome.extras.Quest })
Equal(st[short].height, 420, "a quest window under 470: its height kept")
NoErrors("NPC windows")

---------------------------------------------------------------------------
-- Trade, item text, the bank, the group finder's listing
---------------------------------------------------------------------------
local recipient = TradeFrame.RecipientOverlay
Equal(st[recipient.portraitFrame].file .. " " .. tostring(Cut(recipient.portraitFrame, ring)), "Interface\\FrameGeneral\\UIFrameMetal true",
    "trade: the recipient's ring in the metal")
Equal(Spot(recipient.portraitFrame, "TOPLEFT") .. " " .. st[recipient.portrait].width, "TOPLEFT ? -7,8 61", "round its 61 portrait")
local bar = ItemTextScrollFrame.ScrollBar
Equal(st[bar.Track.Begin].alpha, 0, "item text: the 1.x scroll bar")
local columnFloor = Look.OwnPiece(bar, "chrome.columnFloor")
Equal(columnFloor ~= nil and table.concat(st[columnFloor].solid, ","), "0.04,0.04,0.04,1", "with a near-black floor in its column")
ItemTextFrame:Show()
game.Tick(0.05)
Equal(st[bar].alpha, 0, "nothing to scroll: the bar out of sight")
st[bar].scrollable = true
game.Tick(0.05)
Equal(st[bar].alpha, 1, "something to scroll: shown")
Equal(game.banked[1] and game.banked[1][1], BankFrame, "the bank handed to the bags area's dressing")
Equal(ns.WindowPiece(BankFrame, "insetFloor"), nil, "the bank has no inset: no floor of the chrome's")
local listingClose = LFGParentFrameCloseButton
Equal(st[listingClose:GetNormalTexture()].file, "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", "the group finder's X")
local lx = At(listingClose, "TOPRIGHT")
Equal(lx[2] == LFGListingFrame.NineSlice.TopRightCorner and st[listingClose].level, true and (st[LFGListingFrame].level + 20),
    "at the metal's corner, 20 levels over the window")
NoErrors("trade, item text, bank, listing")

---------------------------------------------------------------------------
-- The merchant's foot on a client whose textures take no show or hide
-- script: no error, and the right part follows the game's two pages.
---------------------------------------------------------------------------
Session(nil, { regionShowScripts = false })
game.Pass()
local bareFoot = MerchantFrameBottomLeftBorder
local bareRight = Look.OwnPiece(MerchantFrame, "chrome.merchantFootRight")
Equal(bareRight ~= nil and st[bareRight].file, MEDIA .. "UI-Merchant-BottomBorder", "no texture scripts: the foot dressed all the same")
Equal(#(st[bareFoot].hooks.OnShow or {}), 0, "no script hooked on a texture that can't take one")
MerchantFrame:Show()
MerchantFrame_UpdateBuybackInfo()
Equal(tostring(st[bareFoot].shown) .. " " .. tostring(st[bareRight].shown), "false false", "the buyback page: the right part hides with the left")
MerchantFrame_UpdateMerchantInfo()
Equal(tostring(st[bareFoot].shown) .. " " .. tostring(st[bareRight].shown), "true true", "the merchant page: both shown")
Equal(game.hookCounts[env].MerchantFrame_UpdateMerchantInfo .. game.hookCounts[env].MerchantFrame_UpdateBuybackInfo, "11",
    "each page hooked once")
ns.SkinWindow(MerchantFrame, { lift = 5, extras = Look.Chrome.extras.Merchant })
Equal(game.hookCounts[env].MerchantFrame_UpdateBuybackInfo, 1, "dressed again: still hooked once")
NoErrors("the merchant's foot without texture scripts")

---------------------------------------------------------------------------
-- The bank's turn: after the chrome, before Dark Windows
---------------------------------------------------------------------------
Session()
local before = game.darkForced
game.Pass()
local bankAt = game.banked[1][2]
Equal(bankAt >= before, true, "setup: the bank's turn came")
local bankPieces = 0
for piece, role in pairs(game.dark) do
    if role == "frame" and st[piece].parent and (st[piece].parent == BankFrame or st[piece].parent == BankFrame.NineSlice) then
        bankPieces = bankPieces + 1
    end
end
Equal(bankPieces, 7, "the bank's frame art handed to Dark Windows")
NoErrors("the bank")

---------------------------------------------------------------------------
-- Macros, guild control, collections
---------------------------------------------------------------------------
Session()
game.Pass()
local macro = game.Building(function()
    local window = game.Window("MacroFrame", { inset = true, tabs = 2 })
    local selector = game.New("Frame", "MacroSelector", window)
    game.ThinBar(selector)
    local back = game.New("Frame", "MacroFrameTextBackground", window)
    local backSlice = game.New("Frame", nil, back)
    game.Own(back, "NineSlice", backSlice)
    game.Pieces(backSlice, "TopEdge Center")
    return window
end)
game.Seal()
game.Fire("ADDON_LOADED", "Blizzard_MacroUI")
Equal(Spot(MacroFrameTab1, "BOTTOMLEFT"), "TOPLEFT MacroFrameInset 50,-2", "macros: the first tab on the inset's top")
Equal(Spot(MacroFrameTab2, "BOTTOMLEFT"), "BOTTOMRIGHT MacroFrameTab1 2,0", "the second beside it")
Equal(Coords(MacroFrameTab1.LeftActive), "0,0.15625,0.546875,0", "the tabs' art flipped onto their top edge")
Equal(Spot(MacroFrameTab1.LeftActive, "BOTTOMLEFT"), "BOTTOMLEFT MacroFrameTab1 0,0", "standing on the tab's foot")
Equal(Spot(MacroFrameTab1.MiddleActive, "BOTTOMLEFT"), "BOTTOMRIGHT ? 0,0", "the middle between its sides")
Equal(st[MacroFrameTab1].width, 30 + 36, "a top tab's padding 36")
Equal(Spot(MacroSelector, "TOPLEFT"), "TOPLEFT MacroFrame 7,-63", "the icon picker placed")
local textBack = MacroFrameTextBackground.NineSlice
Equal(tostring(st[textBack.TopEdge].desaturated) .. " " .. table.concat(st[textBack.TopEdge].colour, ","), "true 0.85,0.85,0.85,1",
    "the text box's border drained and dimmed")
Equal(st[textBack.Center].desaturated, nil, "its middle kept")
local feet = game.FindAll(function(s) return s.parent == macro and not s.game and s.backdrop end)
Equal(#feet, 1, "one iron box along the foot")
Equal(Spot(feet[1], "TOPLEFT") .. " / " .. Spot(feet[1], "BOTTOMRIGHT"), "BOTTOMLEFT MacroFrame -1,34 / BOTTOMRIGHT MacroFrame 1,0", "from the foot up 34")
ns.SkinWindow(macro, { topTabs = true, lift = 2, extras = Look.Chrome.extras.Macro })
Equal(#game.FindAll(function(s) return s.parent == macro and not s.game and s.backdrop end), 1, "made once")
local control = game.Building(function()
    local window = game.Window("GuildControlUI")
    local check = game.New("CheckButton", nil, window)
    game.Own(check, "HoverBackground", game.New("Texture", nil, check, "BACKGROUND"))
    local red = game.New("Button", nil, window)
    game.Pieces(red, "Left Middle Right")
    local drop = game.New("Frame", nil, window)
    game.Own(drop, "Button", game.New("Button", nil, drop))
    game.Own(drop, "Text", game.New("FontString", nil, drop, "ARTWORK"))
    game.Own(drop, "Arrow", game.New("Texture", nil, drop, "ARTWORK"))
    game.Own(drop, "Background", game.New("Texture", nil, drop, "BACKGROUND"))
    game.New("FontString", nil, window, "ARTWORK")
    return { window = window, check = check, red = red, drop = drop }
end)
game.Seal()
game.Fire("ADDON_LOADED", "Blizzard_GuildControlUI")
Equal(st[control.check:GetNormalTexture()].file, "Interface\\Buttons\\UI-CheckBox-Up", "guild control: the 1.x check box")
Equal(st[control.red:GetNormalTexture()].file .. " " .. st[control.red.Left].alpha, "Interface\\Buttons\\UI-Panel-Button-Up 0", "the red button")
Equal(st[control.drop.Background].alpha, 0, "the drop down in the old label frame")
local goldText = game.Find(function(s) return s.parent == control.window and s.kind == "FontString" and s.game end)
Equal(st[goldText].font ~= nil and st[st[goldText].font].name, "EraUILookGold", "its own text in the gold font")
Equal(Cut(control.window.NineSlice.TopLeftCorner, { 269 / 512, 401 / 512, 1 / 512, 133 / 512 }), true, "no ring")
NoRingCorners(control.window.NineSlice, "guild control")
local journal = game.Building(function() return game.Window("CollectionsJournal", { inset = true }) end)
game.Seal()
game.Fire("ADDON_LOADED", "Blizzard_Collections")
Equal(table.concat(st[ns.WindowPiece(journal, "insetFloor")].colour, ","), "0.45,0.42,0.38,1", "collections: its floor tinted")
NoErrors("macros, guild control, collections")

---------------------------------------------------------------------------
-- The loot window
---------------------------------------------------------------------------
local function LootWorld(items)
    return game.Building(function()
        local loot = game.Window("LootFrame", { noPortrait = true, width = 220, height = 290 })
        game.Own(loot, "ClosePanelButton", game.New("Button", nil, loot))
        local box = game.New("Frame", nil, loot)
        game.Own(loot, "ScrollBox", box)
        local view = { extent = 46 }
        function view.SetElementExtent(_, extent) view.extent = extent end
        -- As Blizzard's ScrollBoxLinearBaseViewMixin: five numbers, not a padding table.
        function view.SetPadding(_, top, bottom, left, right, spacing)
            view.padding = { top, bottom, left, right, spacing }
        end
        game.lootView = view
        game.lootRows = {}
        for i = 1, items do
            local row = game.New("Frame", nil, box)
            game.Pieces(row, "NameFrame BorderFrame HighlightNameFrame PushedNameFrame QualityStripe", "Texture", "ARTWORK")
            game.Own(row, "QualityText", game.New("FontString", nil, row, "ARTWORK"))
            local item = game.New("Button", nil, row)
            game.Own(row, "Item", item)
            local text = game.New("FontString", nil, row, "ARTWORK")
            st[text].text = i == 3 and "" or ("Item " .. i)
            game.Own(row, "Text", text)
            game.lootRows[i] = row
        end
        game.lootShare = 0
        game.Own(box, "GetView", function() return view end)
        game.Own(box, "FullUpdate", function(_, now) game.fullUpdate = now end)
        game.Own(box, "GetDataProviderSize", function() return #game.lootRows end)
        game.Own(box, "ForEachFrame", function(_, fn) for _, row in ipairs(game.lootRows) do fn(row) end end)
        game.Own(box, "GetScrollPercentage", function() return game.lootShare end)
        game.Own(box, "SetScrollPercentage", function(_, share) game.lootShare = share end)
        game.Own(box, "GetDerivedScrollRange", function() return math.max(0, (#game.lootRows - 4) * 41) end)
        game.ThinBar(loot)
        game.Own(loot, "Resize", function(self) self:SetHeight(290); self:SetWidth(220) end)
        game.Own(loot, "UpdateShownState", function(self) self:SetHeight(290) end)
        return loot
    end)
end
Session()
local loot = LootWorld(6)
game.Seal()
game.Pass()
Equal(st[loot].width .. "x" .. st[loot].height, "170x240", "loot: the 1.x 170 x 240")
loot:Resize()
Equal(st[loot].width .. "x" .. st[loot].height, "170x240", "the game resizing it: held at 170 x 240")
loot:UpdateShownState()
Equal(st[loot].height, 240, "Edit Mode showing it: held too")
Equal(rawget(loot, "GetPanelMaxHeight"), nil, "none of the window's own methods replaced")
local panelArt = Look.OwnPiece(loot, "chrome.lootPanel")
Equal(st[panelArt].file .. " " .. st[panelArt].width .. " " .. st[panelArt].layer .. st[panelArt].sublevel .. " " .. Spot(panelArt, "TOPLEFT"),
    MEDIA .. "UI-LootPanel 256 BACKGROUND-2 TOPLEFT LootFrame 0,4", "the old loot panel")
local icon, skull = Look.OwnPiece(loot, "chrome.lootIcon"), Look.OwnPiece(loot, "chrome.lootSkull")
Equal(st[icon].file .. " " .. st[icon].width .. " " .. Spot(icon, "TOPLEFT"), MEDIA .. "LootPanel-Icon 58 TOPLEFT LootFrame 10,-5", "the bag icon")
Equal(st[skull].file .. " " .. st[skull].layer, "Interface\\TargetingFrame\\TargetDead ARTWORK", "the skull over it")
Equal(Spot(loot.TitleContainer.TitleText, "CENTER"), "TOPLEFT LootFrame 115,-24", "the title where 1.x had it")
Equal(Spot(loot.ClosePanelButton, "CENTER"), "TOPLEFT LootFrame 177,-21", "the X too")
Equal(st[loot.ClosePanelButton:GetNormalTexture()].file, "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", "the 1.x X")
Equal(st[loot.NineSlice.TopLeftCorner].alpha .. st[loot.Bg].alpha, "00", "the game's frame art faded")
Equal(st[ns.WindowPiece(loot, "titleStrip")].shown, false, "no stone title strip")
Equal(ns.WindowPiece(loot, "backing"), nil, "no stone")
Equal(st[loot.TitleContainer.TitleText].alpha .. st[loot.ScrollBox].alpha, "11", "its title and list kept")
Equal(Spot(loot.ScrollBox, "TOPLEFT") .. " / " .. Spot(loot.ScrollBox, "BOTTOMRIGHT"), "TOPLEFT LootFrame 21,-71 / BOTTOMRIGHT LootFrame 10,46",
    "the list placed, three rows tall with the pages showing")
local paddingTypes = {}
for i = 1, 5 do paddingTypes[i] = type(game.lootView.padding[i]) .. "=" .. tostring(type(game.lootView.padding[i]) == "number" and game.lootView.padding[i]) end
Equal(game.lootView.extent .. " " .. table.concat(paddingTypes, ",") .. " " .. tostring(game.fullUpdate),
    "41 number=0,number=0,number=0,number=0,number=0 true", "rows 41 tall, no padding (five plain numbers), redrawn at once")
local row1 = game.lootRows[1]
local rowPlate = game.Find(function(s) return s.parent == row1 and s.file == MEDIA .. "UI-QuestItemNameFrame" end)
Equal(st[rowPlate].width .. "x" .. st[rowPlate].height .. " " .. Spot(rowPlate, "LEFT"), "130x62 LEFT ? 30,0", "each row on the old name plate")
Equal(st[row1.NameFrame].alpha .. st[row1.QualityStripe].alpha .. st[row1.QualityText].alpha, "000", "the row's modern pieces faded")
Equal(Spot(row1.Text, "LEFT") .. " " .. st[row1.Text].width .. "x" .. st[row1.Text].height, "RIGHT ? 8,0 93x38", "its name beside the icon")
local emptyPlate = game.Find(function(s) return s.parent == game.lootRows[3] and s.file == MEDIA .. "UI-QuestItemNameFrame" end)
Equal(st[emptyPlate].shown, false, "a row with no name: no plate")
local pager = Look.Chrome.loot.pager
Equal(st[pager].shown and st[pager].width .. "x" .. st[pager].height, "170x40", "more than four items: the pages show")
local up, down = Look.Chrome.loot.up, Look.Chrome.loot.down
Equal(Spot(up, "BOTTOMLEFT") .. " / " .. Spot(down, "BOTTOMLEFT"), "BOTTOMLEFT LootFrame 23,6 / BOTTOMLEFT LootFrame 146,6", "Prev and Next arrows")
Equal(st[up:GetNormalTexture()].file, "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up", "the old chat arrows")
Equal(tostring(st[up].enabled) .. tostring(st[down].enabled), "falsetrue", "at the top: only Next")
down:Click()
Equal(game.lootShare, 1, "Next: three rows of 41 (more than the 82 to scroll: the end)")
Equal(tostring(st[up].enabled) .. tostring(st[down].enabled), "truefalse", "at the end: only Prev")
up:Click()
Equal(game.lootShare, 0, "Prev: back")
-- Fewer items: no pages, the list down to the foot.
table.remove(game.lootRows)
table.remove(game.lootRows)
loot:Show()
game.Fire("LOOT_SLOT_CLEARED")
game.NextFrame()
Equal(st[pager].shown, false, "four items: no pages")
Equal(select(5, loot.ScrollBox:GetPoint("BOTTOMRIGHT")), 8, "the list down to the foot")
-- The watcher redresses rows the game adds.
local newRow = game.Building(function()
    local row = game.New("Frame", nil, loot.ScrollBox)
    game.Pieces(row, "NameFrame BorderFrame", "Texture", "ARTWORK")
    game.Own(row, "Text", game.New("FontString", nil, row, "ARTWORK"))
    return row
end)
game.Seal()
game.lootRows[#game.lootRows + 1] = newRow
game.Tick(0.4)
Equal(st[newRow.NameFrame].alpha, 1, "setup: not before the watch's half second")
game.Tick(0.2)
Equal(st[newRow.NameFrame].alpha, 0, "a row the game adds: dressed by the pages' 0.5 s watch")
NoErrors("the loot window")

print("Window chrome checks passed: " .. checks .. " assertions.")
