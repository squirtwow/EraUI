-- The professions book (Look/ProfBook.lua and Look/ProfWatch.lua,
-- clean-room 2026-10-21) on a sealed mock of Forever's Professions window
-- (Tools/SpellMockGame.lua): the rows (rank titles from the game's list, the
-- rank bar and its text, the modifier, the "learn a profession" texts per
-- row), the game's cards placed beside them (sizes, places, what is faded,
-- the brown plates, the unlearn cross, the spell buttons pulled closer), the
-- window's size and panel layout for the book, the crafting page and
-- neither, the side tabs hidden while the book is on, EraUI's book tabs (in
-- a fight the game's red error),
-- the book and crafting pages' titles and portraits, nothing done in a fight,
-- and turning it off. The remembered profession's rules are run in
-- Tools/TestBuild70170.lua.
local Mock = dofile("Tools/SpellMockGame.lua")
local checks = 0
local function Equal(a, b, label)
    checks = checks + 1
    assert(a == b, label .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end

local function Session(options)
    options = options or {}
    local game = Mock.New({ templates = { ProfessionStatusBarTemplate = options.template or false } })
    local env = game.env
    local G = game.GameFrame
    local window = G("Frame", "ProfessionsFrame", env.UIParent)
    local cards = {}
    game.Native(function()
        window.shown = false
        window:SetSize(750, 600)
        window:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 16, -116)
        window.BookPage = G("Frame", nil, window)
        window.CraftingPage = G("Frame", nil, window)
        window.CraftingPage.shown = false
        window.BookPage.ProfessionsContentFrame = G("Frame", nil, window.BookPage)
        window.CloseButton = G("Button", nil, window)
        window.CloseButton.level = 40
        window.TitleContainer = { TitleText = window:CreateFontString() }
        window.PortraitContainer = { portrait = window:CreateTexture() }
        window.ProfessionsOverviewTab = G("Frame", nil, window)
        window.ProfessionsOverviewTab.mouse = true
        window.ProfessionsOverviewTab.Icon = window.ProfessionsOverviewTab:CreateTexture()
        window.ProfessionsOverviewTab.Icon:SetSize(40, 40)
        window.ProfessionsOverviewTab.SelectedTexture = window.ProfessionsOverviewTab:CreateTexture()
        window.rightProfessionTabs = {}
        for i = 1, 2 do
            local tab = G("Frame", nil, window)
            tab.mouse = true
            tab.Icon = tab:CreateTexture()
            tab.SelectedTexture = tab:CreateTexture()
            tab.skillLine = 160 + i
            window.rightProfessionTabs[i] = tab
        end
        local content = window.BookPage.ProfessionsContentFrame
        for i, key in ipairs({ "PrimaryProfession1", "PrimaryProfession2", "SecondaryProfession1", "SecondaryProfession2", "SecondaryProfession3" }) do
            local card = G("Frame", nil, content)
            card:SetSize(664, 142)
            for _, piece in ipairs({ "Background", "ProfessionName", "specialization", "missingHeader", "missingText" }) do
                card[piece] = card:CreateTexture()
            end
            card.StatusBar = G("Frame", nil, card)
            card.StatusBar.mouse = true
            for n = 1, i <= 2 and 2 or 4 do
                local button = G("CheckButton", nil, card)
                button.IconTexture = button:CreateTexture()
                button.OutlineMask = button:CreateMaskTexture()
                button.IconTexture:AddMaskTexture(button.OutlineMask)
                button.IconTextureOverlay = button:CreateTexture()
                -- Forever's 70707 UI adds this frame on its first two cards only.
                if i <= 2 then button.IconBorder = button:CreateTexture() end
                button:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 15, n == 1 and 10 or 60)
                card["SpellButton" .. n] = button
            end
            if i <= 2 then
                card.UnlearnButton = G("Button", nil, card)
                card.UnlearnButton.Icon = card.UnlearnButton:CreateTexture()
                card.UnlearnButton.Overlay = card.UnlearnButton:CreateTexture()
                card.GamepadUnlearnButton = G("Frame", nil, card)
            end
            content[key] = card
            cards[i] = card
        end
    end)
    env.PROFESSION_RANKS = { { 75, "Apprentice" }, { 150, "Journeyman" }, { 225, "Expert" }, { 300, "Artisan" } }
    env.TRADESKILL_RANK, env.TRADESKILL_RANK_WITH_MODIFIER = "%d/%d", "%d (+%d)/%d"
    for _, name in ipairs({ "PROFESSIONS_FIRST_PROFESSION", "PROFESSIONS_SECOND_PROFESSION", "PROFESSIONS_MISSING_PROFESSION",
        "PROFESSIONS_COOKING", "PROFESSIONS_COOKING_MISSING", "PROFESSIONS_FISHING", "PROFESSIONS_FISHING_MISSING",
        "PROFESSIONS_FIRST_AID", "PROFESSIONS_FIRST_AID_MISSING" }) do env[name] = name end
    local known = options.known or { [1] = { "Tailoring", "icon-tailor", 120, 150, 2, 10, 197, 0 },
        [3] = { "First Aid", "icon-aid", 40, 75, 1, 20, 129, 5 }, [5] = { "Cooking", "icon-cook", 1, 75, 1, 30, 185, 0 } }
    -- The game's order: first, second, First Aid, Fishing, Cooking.
    env.GetProfessions = function() return known[1] and 1, known[2] and 2, known[3] and 3, known[4] and 4, known[5] and 5 end
    env.GetProfessionInfo = function(index) local p = known[index]; return table.unpack(p) end
    env.UIErrorsFrame = { AddMessage = function(_, text, r, g, b) game.redError = { text, r, g, b } end }
    env.ERR_NOT_IN_COMBAT = "You can't do that in combat."
    env.ShowUIPanel = function(frame) game.Native(function() frame:Show() end) end
    env.UpdateUIPanelPositions = function() game.panelUpdates = (game.panelUpdates or 0) + 1 end
    game.Load("Look/Base.lua")
    for _, file in ipairs({ "Look/SpellKit.lua", "Look/ProfBook.lua", "Look/ProfWatch.lua" }) do game.Load(file) end
    if options.spellbookOn then
        game.ns.SpellBookActive = function() return true end
        game.ns.SpellBookPetTitle = function() return "Cat" end
        game.ns.ShowSpellBookBank = function(pet) game.shownBank = pet and "pet" or "player" end
    end
    if options.trade then
        game.ns.TradeSkillActive = function() return true end
        game.ns.TradeSkillWindowSize = function() return 362, 444 end
    end
    game.Pass()
    game.Tick(0.2)
    return { game = game, env = env, window = window, cards = cards, P = game.E.Look.Prof }
end

---------------------------------------------------------------------------
-- The rows
---------------------------------------------------------------------------
do
    local s = Session()
    local P, cards = s.P, s.cards
    Equal(P.placed, true, "the cards placed once the window is there")
    local content = s.window.BookPage.ProfessionsContentFrame
    for i, at in ipairs({ { 100, -62 }, { 100, -168 }, { 52, -282 }, { 52, -352 }, { 52, -422 } }) do
        local row = P.rows[i].frame
        Equal(row.parent == content and row.width == 437 and row.height == at[1] and row.points[1][4] == 80
            and row.points[1][5] == at[2] and row:IsShown(), true, "row " .. i .. ": 437 wide, " .. at[1] .. " tall at (80, " .. at[2] .. ")")
    end
    Equal(P.pages[1].file:find("Professions%-Book%-Left") ~= nil and P.pages[1].points[1][4] == 7 and P.pages[1].points[1][5] == -25, true,
        "the left page at the book page's (7, -25)")
    Equal(P.pages[2].points[1][2] == P.pages[1] and P.pages[2].points[1][3] == "TOPRIGHT", true, "the right page beside it")
    local tailor = P.rows[1]
    Equal(tailor.name.text .. " | " .. tailor.title.text, "Tailoring | Journeyman", "a learned profession: its name and rank title from its top rank")
    Equal(tailor.bar.high .. " " .. tailor.bar.value .. " " .. tailor.bar.rankText.text, "150 120 120/150", "the rank bar and its text")
    Equal(tailor.icon.file .. " " .. tostring(tailor.header:IsShown()), "icon-tailor false", "its icon, no learn text")
    Equal(tailor.bar.barColour[1] .. "," .. tailor.bar.barColour[2] .. "," .. tailor.bar.barColour[3], "0,1,0", "the bar green")
    local second = P.rows[2]
    Equal(tostring(second.name:IsShown()) .. " " .. second.header.text .. " " .. second.text.text .. " " .. second.icon.file,
        "false PROFESSIONS_SECOND_PROFESSION PROFESSIONS_MISSING_PROFESSION Interface\\Icons\\INV_Scroll_04",
        "no second profession: the learn texts and the scroll")
    Equal(second.title.points[1][5], -41, "the second row's rank line lifted 15")
    Equal(P.rows[3].name.text .. " " .. P.rows[3].bar.rankText.text, "Cooking 1/75", "row 3 is Cooking (the game's fifth)")
    Equal(P.rows[4].header.text, "PROFESSIONS_FISHING", "row 4 Fishing, not learned")
    Equal(P.rows[5].name.text .. " " .. P.rows[5].bar.rankText.text .. " " .. P.rows[5].title.text, "First Aid 40 (+5)/75 Apprentice",
        "row 5 First Aid, with its modifier")
    Equal(P.RankTitle(300) .. P.RankTitle(375), "ArtisanArtisan", "past the list: its last title")

    -- The cards beside the rows.
    local primary = cards[1]
    Equal(primary.width .. "x" .. primary.height .. " " .. primary.points[1][4] .. "," .. primary.points[1][5], "170x100 353,-67",
        "a primary card: 170 x 100 at (353, row - 5)")
    Equal(cards[2].points[1][5], -168 - 5 + 15, "the second lifted 15")
    for _, piece in ipairs({ "Background", "ProfessionName", "specialization", "missingHeader", "missingText" }) do
        Equal(primary[piece].alpha, 0, "its " .. piece .. " faded")
    end
    Equal(primary.StatusBar.alpha .. " " .. tostring(primary.StatusBar.mouse), "0 false", "its own bar faded, no mouse")
    local button = primary.SpellButton1
    local plate = P.plates[button]
    Equal(plate.width .. "x" .. plate.height .. " " .. plate.points[1][1] .. " " .. plate.points[1][3] .. " " .. plate.points[1][4],
        "108x41 LEFT RIGHT 1", "a brown plate beside each spell button")
    Equal(button.IconTextureOverlay.alpha .. " " .. #button.IconTexture.masks, "0 0", "its square frame faded, its mask off")
    Equal(button.IconBorder.alpha .. " " .. primary.SpellButton2.IconBorder.alpha, "0 0", "the new border faded on both spell buttons")
    Equal(cards[3].SpellButton1.IconBorder, nil, "a button without one is fine")
    Equal(P.plates[cards[3].SpellButton1] ~= nil, true, "and is still dressed")
    local unlearn = primary.UnlearnButton
    Equal(unlearn.points[1][4] .. "," .. unlearn.points[1][5] .. " " .. unlearn.Icon.file, "165,-138 Interface\\Buttons\\UI-GroupLoot-Pass-Up",
        "the unlearn cross under the rank bar")
    Equal(unlearn.Icon.width .. " " .. unlearn.Icon.alpha .. " " .. unlearn.Overlay.alpha, "16 0.75 0", "small, a little faded")
    Equal(primary.GamepadUnlearnButton.points[1][2] == unlearn and primary.GamepadUnlearnButton.points[1][4] == -2, true, "the gamepad one left of it")
    local secondary = cards[3]
    Equal(secondary.width .. "x" .. secondary.height .. " " .. secondary.points[1][4] .. "," .. secondary.points[1][5], "437x52 80,-282",
        "a secondary card over its row")
    Equal(secondary.SpellButton1.points[1][1] .. " " .. secondary.SpellButton1.points[1][4] .. "," .. secondary.SpellButton1.points[1][5],
        "TOPRIGHT -109,-6", "its first spell button 109 in from the right")
    Equal(secondary.SpellButton2.points[1][2] == secondary.SpellButton1 and secondary.SpellButton2.points[1][3] == "TOPLEFT", true,
        "the next to its left")
    Equal(primary.SpellButton1.points[1][5] .. " " .. primary.SpellButton2.points[1][5], "15 56", "with both up, the two sit closer (10 to 15, 60 to 56)")
    Equal(s.game.ns.modules.professionsBook ~= nil, true, "registered as professionsBook")
end

-- The fallback rank bar (no template): a plain 95 x 16 bar with its fill.
do
    local s = Session({ template = false })
    local bar = s.P.rows[1].bar
    Equal(bar.width .. "x" .. bar.height .. " " .. tostring(bar.barFile), "95x16 Interface\\Spellbook\\Professions-Progress-Fill",
        "without the game's template, a plain bar like it")
end

---------------------------------------------------------------------------
-- The window's size, tabs and pages
---------------------------------------------------------------------------
do
    local s = Session({ spellbookOn = true, trade = true })
    local game, window, P = s.game, s.window, s.P
    game.Native(function() window:Show() end)
    game.Tick(0.2)
    Equal(window.width .. "x" .. window.height, "550x525", "the book page up: 550 x 525")
    Equal(window.attrs["UIPanelLayout-width"] .. "x" .. window.attrs["UIPanelLayout-height"], "550x525", "and its panel layout with it")
    Equal(game.panelUpdates, nil, "already the book's size while shut: nothing to place again")
    game.Native(function() window.BookPage:Hide(); window.CraftingPage:Show() end)
    game.Tick(0.2)
    Equal(window.width .. "x" .. window.height, "362x444", "a profession's page with the trade skill window on: its size")
    Equal(game.panelUpdates, 1, "a change while shown: the game asked to place its panels again")
    game.ns.TradeSkillActive = function() return false end
    game.Tick(0.2)
    Equal(window.width .. "x" .. window.height, "750x600", "neither: the window's own size back")
    Equal(window.attrs["UIPanelLayout-width"], nil, "and its own panel layout")
    game.ns.TradeSkillActive = function() return true end
    game.EnterCombat()
    game.Native(function() window.BookPage:Show(); window.CraftingPage:Hide() end)
    game.Tick(0.2)
    Equal(window.width, 750, "never sized in a fight")
    game.LeaveCombat()
    game.Tick(0.2)
    Equal(window.width, 550, "sized when it ends")
    -- The side tabs: hidden while the book is on, nothing to bring them back.
    local tab = window.rightProfessionTabs[1]
    Equal(tab.alpha .. " " .. tostring(tab.mouse), "0 false", "the profession tabs hidden")
    local overview = window.ProfessionsOverviewTab
    Equal(overview.alpha .. " " .. tostring(overview.mouse), "0 false", "the overview tab with them")
    Equal(s.env.EraUIClassicProfessionTabsToggle, nil, "and no arrow to show them")
    -- EraUI's book tabs (the classic spellbook on).
    local tabs = P.bookTabs
    Equal(tabs[1].points[1][3] .. " " .. tabs[1].points[1][4] .. "," .. tabs[1].points[1][5], "BOTTOMLEFT 70,-7", "the Spellbook tab under the window")
    Equal(tabs[1].text .. "|" .. tabs[2].text .. "|" .. tostring(tabs[2].enabled) .. "|" .. tabs[3].text, "Spellbook|Professions|false|Cat",
        "Spellbook, Professions (selected) and the pet's")
    game.EnterCombat()
    tabs[1]:Click("LeftButton")
    Equal(game.redError and game.redError[1] .. game.redError[2], "You can't do that in combat.1", "in a fight: the game's red error")
    Equal(game.shownBank, nil, "and nothing opened")
    game.LeaveCombat()
    tabs[3]:Click("LeftButton")
    Equal(tostring(window:IsShown()) .. " " .. game.shownBank, "false pet", "out of a fight: the window shut, the pet's pages opened")
    -- The pages' titles and portraits.
    game.Native(function() window:Show() end)
    s.env.C_TradeSkillUI = { GetBaseProfessionInfo = function() return { professionName = "Tailoring", professionID = 162 } end,
        GetTradeSkillTexture = function() return "tailoring-portrait" end }
    game.Native(function() window.BookPage:Hide(); window.CraftingPage:Hide() end)
    game.Fire("TRADE_SKILL_SHOW")
    Equal(window.TitleContainer.TitleText.text .. " " .. window.PortraitContainer.portrait.file, "Tailoring tailoring-portrait",
        "a profession opening: its page, title and portrait")
    Equal(tostring(window.rightProfessionTabs[2].SelectedTexture:IsShown()) .. " " .. tostring(window.ProfessionsOverviewTab.SelectedTexture:IsShown()),
        "true false", "its tab selected")
    P.ToBook(window)
    Equal(window.TitleContainer.TitleText.text .. " " .. window.PortraitContainer.portrait.file, "Professions Interface/ICONS/INV_SideTab_Professions_c60",
        "back to the book: its title and portrait")
    -- Off: a reload asked for.
    game.ns.db.professionsBook = false
    game.Pass()
    Equal(game.ns.needsReload, true, "off: the option list asks for a reload")
    game.Tick(0.2)
    Equal(tab.alpha .. " " .. tostring(tab.mouse), "1 true", "the side tabs back: the only way to the game's overview")
    Equal(overview.alpha .. " " .. tostring(overview.mouse), "1 true", "the overview tab with them")
    Equal(#game.errors, 0, "no error reported")
end

-- In a fight the cards can't be placed: placed when it ends.
do
    local game
    local s = Session({ known = { [1] = { "Mining", "icon-mine", 10, 75, 1, 0, 186, 0 } } })
    game = s.game
    local card = s.cards[1]
    game.Native(function() card:ClearAllPoints(); card:SetSize(664, 142) end)
    game.EnterCombat()
    game.Fire("SKILL_LINES_CHANGED")
    game.Tick(0.3)
    Equal(card.width, 664, "nothing placed in a fight")
    game.LeaveCombat()
    game.Tick(0.3)
    Equal(card.width, 170, "placed again once it ends")
end

print("Professions checks passed: " .. checks .. " assertions.")
