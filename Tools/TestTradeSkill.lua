-- The trade skill window (Look/SkillShell.lua, TradeList.lua and
-- TradeSkill.lua, clean-room 2026-10-21) on a sealed mock of Forever's
-- Professions window and its trade skill API (Tools/SpellMockGame.lua): the
-- game's crafting page sent away once; the rank bar; the recipes grouped
-- under their categories in the game's order, sorted by difficulty, coloured
-- by it, with "[n]" made from the bags' reagents; folding, All, the search
-- (which ignores folding) and the Filter's two switches; the chosen recipe's
-- needs, cooldown and reagents; Create, Create All and the count (kept
-- between 1 and what can be made), counting down as each one is made; the
-- events (item names only redraw the details); the search box's entry; the
-- result and reagent tooltips in EraUI's own box; off.
local Mock = dofile("Tools/SpellMockGame.lua")
local checks = 0
local function Equal(a, b, label)
    checks = checks + 1
    assert(a == b, label .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end

local game = Mock.New()
local env = game.env
local G = game.GameFrame
local window = G("Frame", "ProfessionsFrame", env.UIParent)
game.Native(function()
    window:SetSize(362, 444)
    window:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 16, -116)
    window.CraftingPage = G("Frame", nil, window)
    window.CraftingPage:SetSize(700, 400)
    window.CraftingPage:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -20)
    window.TitleContainer = { TitleText = window:CreateFontString() }
end)

-- Recipes: id = { name, category, difficulty, reagents { item, need }, learned }
local recipes = {
    [101] = { "Linen Bandage", 10, 2, { { 1251, 1 } } },
    [102] = { "Heavy Linen Bandage", 10, 0, { { 1251, 2 } } },
    [103] = { "Wool Bandage", 10, 0, { { 2592, 1 } } },
    [201] = { "Anti-Venom", 20, 1, {} },
    [301] = { "Unlearned", 20, 3, {}, false },
}
local categories = { [10] = { name = "Bandages", uiOrder = 2, parentCategoryID = 1 }, [20] = { name = "Antidotes", uiOrder = 1, parentCategoryID = 1 },
    [1] = { name = "First Aid", uiOrder = 5 } }
local bags = { [1251] = 5, [2592] = 0 }
local crafted, onlyMakeable, onlySkillUp = {}, false, false
local loadsAsked = {}
env.Enum = { CraftingReagentType = { Basic = 0, Modifying = 1 } }
env.C_TradeSkillUI = {
    GetFilteredRecipeIDs = function() return { 101, 102, 103, 201, 301 } end,
    GetRecipeInfo = function(id)
        local r = recipes[id]
        return { recipeID = id, name = r[1], categoryID = r[2], relativeDifficulty = r[3], learned = r[5] ~= false,
            icon = "icon-" .. id, numAvailable = id == 201 and 4 or 0 }
    end,
    GetCategoryInfo = function(id) return categories[id] end,
    GetRecipeSchematic = function(id)
        local slots = {}
        for i, reagent in ipairs(recipes[id][4]) do
            slots[i] = { reagentType = 0, quantityRequired = reagent[2], reagents = { { itemID = reagent[1] } }, dataSlotIndex = i }
        end
        slots[#slots + 1] = { reagentType = 1, quantityRequired = 1, reagents = { { itemID = 9999 } } }
        return { reagentSlotSchematics = slots, quantityMax = id == 101 and 2 or 1, icon = "schematic-" .. id }
    end,
    GetChildProfessionInfo = function() return { professionName = "First Aid", skillLevel = 40, maxSkillLevel = 75, skillModifier = 5 } end,
    GetRecipeRequirements = function(id) if id == 101 then return { { name = "Anvil", met = true }, { name = "Forge", met = false } } end return {} end,
    GetRecipeCooldown = function(id) return id == 102 and 3600 or 0 end,
    GetRecipeLink = function(id) return "|Hrecipe:" .. id .. "|h" end,
    GetRecipeItemLink = function(id) return "|Hitem:" .. id .. "|h" end,
    CraftRecipe = function(id, count) crafted[#crafted + 1] = { id, count } end,
    GetOnlyShowMakeableRecipes = function() return onlyMakeable end,
    SetOnlyShowMakeableRecipes = function(on) onlyMakeable = on end,
    GetOnlyShowSkillUpRecipes = function() return onlySkillUp end,
    SetOnlyShowSkillUpRecipes = function(on) onlySkillUp = on end,
}
env.C_Item = {
    GetItemCount = function(item, bank, uses, reagentBank)
        assert(bank == false and uses == false and reagentBank == false, "bag counts only")
        return bags[item] or 0
    end,
    GetItemNameByID = function(item) if item == 2592 then return nil end return "Item " .. item end,
    RequestLoadItemDataByID = function(item) loadsAsked[item] = (loadsAsked[item] or 0) + 1 end,
    GetItemIconByID = function(item) return "item-icon-" .. item end,
    GetItemInfo = function(item) return "Item " .. item, "|Hitem:" .. item .. "|h" end,
}
env.SecondsToTime = function(seconds) return seconds .. " sec" end
env.HandleModifiedItemClick = function(link) game.handled = link end
env.HideUIPanel = function(frame) game.Native(function() frame:Hide() end) end

game.Load("Look/Base.lua")
for _, file in ipairs({ "Look/SpellKit.lua", "Look/SkillShell.lua", "Look/TradeList.lua", "Look/TradeSkill.lua" }) do game.Load(file) end
local T = game.E.Look.Trade
local ns = game.ns
local order = {}
for _, module in ipairs(ns.modules) do order[#order + 1] = module.key end
Equal(table.concat(order, ","), "tradeSkillSearch,tradeSkill", "the search box's entry first, then the window's")
Equal(select(1, ns.TradeSkillWindowSize()) .. "x" .. select(2, ns.TradeSkillWindowSize()), "362x444", "the trade skill window's size")
Equal(ns.TradeSkillActive(), false, "off until applied")
game.Pass()
Equal(ns.TradeSkillActive(), true, "on once applied")
game.Native(function() window:Show() end)
ns.ShowTradeSkill(true)
game.Settle()
local panel = env.EraUIClassicTradeSkill
Equal(panel ~= nil and panel:IsShown() and panel.parent == window, true, "the window shown over the Professions window")
Equal(panel.level, window.level + 120, "120 levels above it")
local page = window.CraftingPage
Equal(page.points[1][4] .. " " .. page.width .. "x" .. page.height .. " " .. page.alpha, "6000 700x500 0", "the game's crafting page sent away, at least 600 x 500, unseen")
ns.ShowTradeSkill(false)
Equal(panel:IsShown(), false, "hidden when the crafting page isn't up")
ns.ShowTradeSkill(true)
game.Settle()

-- The rank bar and the title.
Equal(T.rankText.text .. " " .. T.rankBar.high .. " " .. T.rankBar.value, "40 (+5)/75 75 40", "the rank bar: rank (+modifier)/max")
Equal(window.TitleContainer.TitleText.text, "First Aid", "the window's empty title takes the profession's name")
local barPoints = T.rankBar.points
Equal(barPoints[1][4] .. "," .. barPoints[1][5] .. " " .. barPoints[2][1] .. " " .. barPoints[2][4], "72,-36 RIGHT -42", "from (72, -36) to 42 in from the right")

-- The list: categories in the game's order, recipes by difficulty.
local function Lines()
    local out = {}
    for _, line in ipairs(T.lines) do
        out[#out + 1] = line.header and ("[" .. line.group.name .. "]") or line.recipe.name
    end
    return table.concat(out, ", ")
end
Equal(Lines(), "[Antidotes], Anti-Venom, [Bandages], Heavy Linen Bandage, Wool Bandage, Linen Bandage",
    "categories by their order, recipes by difficulty then name, the unlearned left out")
local rows = T.shell.rows
local function Row(i) return T.rowParts[rows[i]].text end
Equal(Row(2).text, "Anti-Venom [4]", "a recipe with no reagents counts what the game says")
Equal(Row(4).text, "Heavy Linen Bandage [2]", "two each from five in the bags: 2")
Equal(Row(5).text, "Wool Bandage", "none in the bags: no count")
Equal(Row(6).text, "Linen Bandage [5]", "and five")
local c = Row(4).textColour
Equal(c[1] .. "," .. c[2] .. "," .. c[3], "1,0.5,0.25", "orange (0)")
c = Row(2).textColour
Equal(c[1] .. "," .. c[2] .. "," .. c[3], "1,1,1", "the chosen recipe (the first listed) in white")
Equal(T.rowParts[rows[2]].bar:IsShown() and T.rowParts[rows[2]].bar.colour[2], 1, "its bar tinted yellow (1)")
c = Row(6).textColour
Equal(c[1] .. "," .. c[2] .. "," .. c[3], "0.25,0.75,0.25", "green (2)")
c = Row(1).textColour
Equal(c[1] .. "," .. c[2] .. "," .. c[3] .. " " .. Row(1).points[1][4], "1,0.82,0 21", "a header in gold, 21 in")
Equal(Row(2).points[1][4], 26, "a recipe 26 in")
Equal(T.rowParts[rows[1]].icon.file:find("MinusButton") ~= nil, true, "an open header shows a minus")

-- Folding, All and the search.
rows[3]:Click("LeftButton")
Equal(Lines(), "[Antidotes], Anti-Venom, [Bandages]", "a header folds its group")
Equal(T.rowParts[rows[3]].icon.file:find("PlusButton") ~= nil, true, "and shows a plus")
T.searchBox:SetText("wool")
T.searchBox:Fire("OnTextChanged")
Equal(Lines(), "[Bandages], Wool Bandage", "the search finds inside a folded group")
T.searchBox:SetText("")
T.searchBox:Fire("OnTextChanged")
Equal(Lines(), "[Antidotes], Anti-Venom, [Bandages]", "and folding comes back with it cleared")
T.shell.all:Click("LeftButton")
Equal(Lines(), "[Antidotes], [Bandages]", "All folds every group while any is open")
Equal(T.shell.allIcon.file:find("PlusButton") ~= nil, true, "the All button shows a plus with every group folded")
T.shell.all:Click("LeftButton")
Equal(#T.lines, 6, "and opens them all again")
Equal(T.shell.bar.high, 0, "six lines: nothing to scroll")
T.searchBox:Fire("OnEscapePressed")
Equal(T.searchBox.text .. tostring(T.searchBox.focus), "false", "Escape empties the search and drops focus")
-- The Filter's two switches (the game's own).
T.shell.filter:Click("LeftButton")
local list = T.filterList.frame
Equal(list:IsShown(), true, "the Filter's list")
list.children[1]:Click("LeftButton")
Equal(onlyMakeable, true, "Have Materials flips the game's switch")
T.shell.filter:Click("LeftButton")
list.children[2]:Click("LeftButton")
Equal(onlySkillUp, true, "Has Skill Up too")

-- The details.
rows[6]:Click("LeftButton")
Equal(T.selected, 101, "a click chooses a recipe")
Equal(T.nameText.text .. " " .. T.iconTexture.file .. " " .. T.madeText.text, "Linen Bandage icon-101 2", "its name, icon and how many one makes")
Equal(T.needsText.text, "Requires: |cffffffffAnvil|r, |cffff2020Forge|r", "its needs: met white, unmet red")
Equal(T.cooldownText:IsShown(), false, "no cooldown")
Equal(T.reagents[1].button:IsShown() and T.reagents[1].count.text .. " " .. T.reagents[1].name.text, "5/1 Item 1251", "a reagent: have/need and its name")
Equal(T.reagents[2].button:IsShown(), false, "only the basic reagents (a modifying one left out)")
Equal(T.create.enabled and T.createAll.enabled, true, "Create and Create All on: some can be made")
rows[5]:Click("LeftButton")
Equal(T.reagents[1].icon.colour[1] .. " " .. T.reagents[1].name.textColour[1], "0.5 0.5", "a reagent short: greyed")
Equal(T.reagents[1].name.text, "", "a name not loaded yet")
Equal((loadsAsked[2592] or 0) > 0, true, "is asked for")
Equal(T.create.enabled or T.createAll.enabled, false, "none can be made: both off")
rows[4]:Click("LeftButton")
Equal(T.cooldownText:IsShown() and T.cooldownText.text, "Cooldown remaining: 3600 sec", "a cooldown")
-- Shift-click links, the icon's modified click hands the game the item link.
game.modified = "CHATLINK"
env.ChatFrameUtil = { InsertLink = function(link) game.linked = link; return true end }
rows[6]:Click("LeftButton")
Equal(game.linked .. " " .. T.selected, "|Hrecipe:101|h 102", "a shift-click links the recipe and chooses nothing")
game.modified = nil
env.IsModifiedClick = function() return true end
T.icon:Click("LeftButton")
Equal(game.handled, "|Hitem:102|h", "a modified click on the icon hands the game the item's link")
env.IsModifiedClick = function(action) return game.modified == action end

-- Making things.
rows[6]:Click("LeftButton")
T.countBox:SetText("9")
T.create:Click("LeftButton")
Equal(crafted[1][1] .. "x" .. crafted[1][2] .. " " .. T.countBox.text, "101x5 5", "Create: the count kept to what can be made (5), shown in the box")
T.createAll:Click("LeftButton")
Equal(crafted[2][2], 5, "Create All: all that can be made")
game.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 101)
Equal(T.countBox.text, "4", "the count goes down as each one is made")
game.Fire("UNIT_SPELLCAST_SUCCEEDED", "target", "cast", 101)
game.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 555)
Equal(T.countBox.text, "4", "not for another unit or spell")
game.Fire("UPDATE_TRADESKILL_CAST_STOPPED")
Equal(T.countBox.text, "1", "stopped: back to 1")
local more, fewer
for _, f in ipairs(game.frames) do
    if f.parent == panel and f.kind == "Button" and f.normalFace and f.normalFace.file then
        if f.normalFace.file:find("NextPage") then more = f elseif f.normalFace.file:find("PrevPage") then fewer = f end
    end
end
fewer:Click("LeftButton")
Equal(T.countBox.text, "1", "never below 1")
for _ = 1, 8 do more:Click("LeftButton") end
Equal(T.countBox.text, "5", "never above what can be made")

-- Events: item names coming in redraw only the details.
game.Settle() -- the cast stopping above booked its own refresh
local collected = 0
local collect = T.Collect
T.Collect = function(...) collected = collected + 1; return collect(...) end
game.Fire("GET_ITEM_INFO_RECEIVED")
game.Settle()
Equal(collected, 0, "item names only: the details redrawn, nothing collected")
game.Fire("BAG_UPDATE_DELAYED")
game.Fire("GET_ITEM_INFO_RECEIVED")
game.Settle()
Equal(collected, 1, "anything else: one full refresh for the burst")
T.Collect = collect

-- Tooltips: the game's own data in EraUI's box.
env.C_TooltipInfo = {
    GetRecipeResultItem = function(id) return { lines = { { leftText = "Result " .. id } } } end,
    GetRecipeReagentItem = function(id, slot) return { lines = { { leftText = "Reagent " .. id .. ":" .. slot } } } end,
}
T.icon:Fire("OnEnter")
Equal(game.E.Look.TipOwner(), T.icon, "the result's tooltip in EraUI's box")
T.icon:Fire("OnLeave")
T.reagents[1].button:Fire("OnEnter")
Equal(game.E.Look.TipOwner(), T.reagents[1].button, "a reagent's too")
T.reagents[1].button:Fire("OnLeave")

-- The rank bar when neither profession reader knows the top rank: the
-- known profession whose skill line the first recipe belongs to, found
-- among the first eight slots even with no first primary profession
-- (GetProfessions starts with nil then).
env.C_TradeSkillUI.GetChildProfessionInfo = function() return { professionName = "First Aid", maxSkillLevel = 0 } end
env.C_TradeSkillUI.GetTradeSkillLineForRecipe = function() return 129, "First Aid", nil end
env.GetProfessions = function() return nil, nil, 5, nil, nil end
env.GetProfessionInfo = function(index)
    if index == 5 then return "First Aid", "icon", 30, 150, 2, 0, 129, 0 end
end
T.Refresh()
Equal(T.rankBar:IsShown() and T.rankText.text, "30/150", "no top rank from the readers: the profession of the first recipe's line")
env.C_TradeSkillUI.GetChildProfessionInfo = function() return { professionName = "First Aid", skillLevel = 40, maxSkillLevel = 75, skillModifier = 5 } end

-- The search box's entry, and off.
ns.db.tradeSkillSearch = false
T.searchBox:SetText("x")
game.Pass()
Equal(tostring(T.searchBox:IsShown()) .. tostring(T.searchFrame:IsShown()) .. "|" .. T.searchBox.text, "falsefalse|", "search off: emptied and hidden with its box")
ns.db.tradeSkillSearch = nil
game.Pass()
Equal(T.searchBox:IsShown(), true, "on again")
ns.db.tradeSkill = false
game.Pass()
Equal(tostring(panel:IsShown()) .. " " .. tostring(ns.needsReload), "false true", "off: hidden, a reload asked for")
ns.ShowTradeSkill(true)
Equal(panel:IsShown(), false, "and kept hidden")
Equal(#game.errors, 0, "no error reported")
print("Trade skill checks passed: " .. checks .. " assertions.")
