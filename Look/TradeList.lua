-- The trade skill window's recipe list (Classic look, registry
-- "tradeSkill"): the recipes the game's filters let through, grouped under
-- their categories (in the game's order), coloured by difficulty, each
-- with how many can be made from the bags; folding, the All button, the
-- search box (tradeSkillSearch) and the Filter's two switches. The window
-- itself is Look/TradeSkill.lua.
local _, EraUI = ...
local Look = EraUI.Look
local S = Look.Spells

local T = { folded = {}, schematics = {}, warmed = {}, lines = {}, count = 1 }
Look.Trade = T

-- relativeDifficulty: 0 orange, 1 yellow, 2 green, 3 (or none) grey.
T.DIFFICULTY = { [0] = { 1, 0.5, 0.25 }, [1] = { 1, 1, 0 }, [2] = { 0.25, 0.75, 0.25 }, [3] = { 0.5, 0.5, 0.5 } }
T.GOLD = { 1, 0.82, 0 }

local function Api(name, ...)
    local api = C_TradeSkillUI
    local fn = type(api) == "table" and api[name]
    if type(fn) ~= "function" then return nil end
    local fine, first, second, third = pcall(fn, ...)
    if not fine then return nil end
    return first, second, third
end
T.Api = Api

---------------------------------------------------------------------------
-- Reagents and how many can be made
---------------------------------------------------------------------------

-- The recipe's basic reagents: { item, need, slot } each (cached per recipe
-- for the session; the schematic doesn't change).
function T.Reagents(recipe)
    local cached = T.schematics[recipe]
    if cached then return cached.reagents, cached.schematic end
    local schematic = Api("GetRecipeSchematic", recipe, false)
    local reagents = {}
    local basic = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
    local slots = type(schematic) == "table" and schematic.reagentSlotSchematics or {}
    for _, slot in ipairs(slots) do
        local first = type(slot.reagents) == "table" and slot.reagents[1]
        local item = first and Look.Number(first.itemID)
        local need = Look.Number(slot.quantityRequired) or 0
        if (basic == nil or slot.reagentType == basic) and item and need > 0 then
            reagents[#reagents + 1] = { item = item, need = need, slot = slot.dataSlotIndex or slot.slotIndex }
        end
    end
    T.schematics[recipe] = { reagents = reagents, schematic = schematic }
    return reagents, schematic
end

-- Items of a kind in the bags (not the bank).
function T.Have(item)
    local items = C_Item
    if type(items) == "table" and type(items.GetItemCount) == "function" then
        local fine, count = pcall(items.GetItemCount, item, false, false, false)
        if fine then return Look.Number(count) or 0 end
    end
    if type(GetItemCount) == "function" then
        local fine, count = pcall(GetItemCount, item)
        if fine then return Look.Number(count) or 0 end
    end
    return 0
end

function T.Makeable(recipe, info)
    local reagents = T.Reagents(recipe)
    if #reagents == 0 then return Look.Number(info and info.numAvailable) or 0 end
    local most
    for _, reagent in ipairs(reagents) do
        local can = math.floor(T.Have(reagent.item) / reagent.need)
        most = most and math.min(most, can) or can
    end
    return most or 0
end

---------------------------------------------------------------------------
-- Collecting the lines
---------------------------------------------------------------------------

local function Category(id, cache)
    local known = cache[id]
    if known == nil then
        known = Api("GetCategoryInfo", id) or false
        cache[id] = known
    end
    return known or nil
end

-- A group's place: its parent category's order x 1000 + its own.
local function Order(id, cache)
    local info = Category(id, cache)
    if not info then return 0 end
    local parent = Look.Number(info.parentCategoryID) and Category(info.parentCategoryID, cache)
    return (parent and Look.Number(parent.uiOrder) or 0) * 1000 + (Look.Number(info.uiOrder) or 0)
end

local function Groups(needle)
    local groups, byId, cache = {}, {}, {}
    for _, recipe in ipairs(Api("GetFilteredRecipeIDs") or {}) do
        local info = Api("GetRecipeInfo", recipe)
        local name = type(info) == "table" and S.Text(info.name)
        if name and info.learned ~= false and (not needle or name:lower():find(needle, 1, true)) then
            local id = Look.Number(info.categoryID) or 0
            local group = byId[id]
            if not group then
                local category = Category(id, cache)
                group = { id = id, name = category and S.Text(category.name) or S.Say("OTHER", "Other"),
                    order = Order(id, cache), recipes = {} }
                byId[id] = group
                groups[#groups + 1] = group
            end
            group.recipes[#group.recipes + 1] = { id = recipe, name = name, info = info,
                difficulty = Look.Number(info.relativeDifficulty) or 3 }
        end
    end
    table.sort(groups, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.name < b.name
    end)
    for _, group in ipairs(groups) do
        table.sort(group.recipes, function(a, b)
            if a.difficulty ~= b.difficulty then return a.difficulty < b.difficulty end
            return a.name < b.name
        end)
    end
    return groups
end

-- The lines: a header per group, then its recipes unless folded (folding
-- is ignored while searching). The selected recipe stays while listed,
-- else the first listed one is selected.
function T.Collect()
    local needle = T.search and T.search ~= "" and T.search:lower() or nil
    local lines, listed, first = {}, {}, nil
    for _, group in ipairs(Groups(needle)) do
        local folded = not needle and T.folded[group.id] == true
        lines[#lines + 1] = { header = true, group = group, folded = folded }
        for _, recipe in ipairs(group.recipes) do
            listed[recipe.id] = recipe
            first = first or recipe
            if not folded then lines[#lines + 1] = { recipe = recipe } end
        end
    end
    T.lines, T.groups = lines, listed
    if not (T.selected and listed[T.selected]) then T.selected = first and first.id or nil end
    return lines
end

function T.Selected()
    return T.selected and T.groups and T.groups[T.selected] or nil
end

-- Every group folded (and at least one): the All button shows a plus.
function T.AllFolded()
    local any = false
    for _, line in ipairs(T.lines) do
        if line.header then
            if not line.folded then return false end
            any = true
        end
    end
    return any
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------

local rowParts = Look.Weak() -- row: { bar, hover, icon, text }
T.rowParts = rowParts

local function LineClick(row, button)
    local line = row and T.rowLine and T.rowLine[row]
    if not line then return end
    if line.header then
        T.folded[line.group.id] = not line.folded or nil
        T.Collect()
        T.Draw()
        return
    end
    if button == "LeftButton" and type(IsModifiedClick) == "function" and IsModifiedClick("CHATLINK") then
        Look.ChatLink((Api("GetRecipeLink", line.recipe.id)))
        return
    end
    T.selected = line.recipe.id
    T.count = 1
    T.Draw()
end
T.LineClick = LineClick

function T.MakeRow(list)
    local row, parts = Look.SkillRow(list)
    parts.bar:SetAlpha(0.6)
    rowParts[row] = parts
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", LineClick)
    return row
end

-- The lines from the scroll bar's place down, eight of them.
function T.DrawRows()
    local shell = T.shell
    local offset = math.floor((Look.Number(shell.bar:GetValue()) or 0) + 0.5)
    T.rowLine = T.rowLine or Look.Weak()
    for i, row in ipairs(shell.rows) do
        local line, parts = T.lines[offset + i], rowParts[row]
        T.rowLine[row] = line
        Look.Shown(row, line ~= nil)
        if line and line.header then
            parts.icon:SetTexture(line.folded and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
            parts.icon:Show()
            Look.SkillRowText(parts, row, 21)
            parts.text:SetText(line.group.name)
            parts.text:SetTextColor(T.GOLD[1], T.GOLD[2], T.GOLD[3])
            parts.bar:Hide()
        elseif line then
            local recipe = line.recipe
            local made = T.Makeable(recipe.id, recipe.info)
            local colour = T.DIFFICULTY[recipe.difficulty] or T.DIFFICULTY[3]
            parts.icon:Hide()
            Look.SkillRowText(parts, row, 26)
            parts.text:SetText(made > 0 and (recipe.name .. " [" .. made .. "]") or recipe.name)
            local chosen = recipe.id == T.selected
            if chosen then parts.text:SetTextColor(1, 1, 1) else parts.text:SetTextColor(colour[1], colour[2], colour[3]) end
            parts.bar:SetVertexColor(colour[1], colour[2], colour[3])
            Look.Shown(parts.bar, chosen)
        end
    end
    Look.ScrollRange(shell.bar, math.max(0, #T.lines - #shell.rows))
    shell.allIcon:SetTexture(T.AllFolded() and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
end

-- All: fold every group if any is open, else open them all.
function T.AllClick()
    local anyOpen = false
    for _, line in ipairs(T.lines) do
        if line.header and not line.folded then anyOpen = true end
    end
    for _, line in ipairs(T.lines) do
        if line.header then T.folded[line.group.id] = anyOpen or nil end
    end
    T.Collect()
    T.Draw()
end

---------------------------------------------------------------------------
-- The Filter's switches
---------------------------------------------------------------------------

local function Flip(getName, setName)
    local now = Api(getName)
    Api(setName, not (now == true))
end

function T.FilterClick(owner)
    if not T.filterList then
        T.filterList = Look.DropList({
            { label = S.Say("CRAFT_IS_MAKEABLE", "Have Materials"),
                pick = function() Flip("GetOnlyShowMakeableRecipes", "SetOnlyShowMakeableRecipes") end,
                chosen = function() return Api("GetOnlyShowMakeableRecipes") == true end },
            { label = S.Say("TRADESKILL_FILTER_HAS_SKILL_UP", "Has Skill Up"),
                pick = function() Flip("GetOnlyShowSkillUpRecipes", "SetOnlyShowSkillUpRecipes") end,
                chosen = function() return Api("GetOnlyShowSkillUpRecipes") == true end },
        })
        T.filterList.Follow(T.panel)
    end
    T.filterList.Toggle(owner)
end

---------------------------------------------------------------------------
-- The search box (tradeSkillSearch)
---------------------------------------------------------------------------

local function SearchChanged(box)
    local text = box:GetText()
    text = (type(text) == "string" and not Look.Secret(text)) and text:lower() or ""
    Look.Shown(T.searchHint, text == "")
    if text == (T.search or "") then return end
    T.search = text
    T.shell.bar:SetValue(0)
    T.Collect()
    T.Draw()
end

function T.BuildSearch(panel)
    local shell = T.shell
    local box = CreateFrame("EditBox", nil, panel)
    box:SetHeight(16)
    box:SetPoint("LEFT", shell.tab, "RIGHT", 16, -6)
    box:SetPoint("RIGHT", shell.filter, "LEFT", -14, 0)
    box:SetFrameLevel((Look.Number(panel:GetFrameLevel()) or 0) + 13)
    if GameFontHighlightSmall then box:SetFontObject(GameFontHighlightSmall) end
    box:SetAutoFocus(false)
    box:SetMaxLetters(40)
    box:SetTextInsets(2, 14, 0, 0)
    local frame = Look.InsetBox(panel, 16, true)
    frame:SetPoint("TOPLEFT", box, "TOPLEFT", -7, 5)
    frame:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 5, -5)
    frame:SetFrameLevel((Look.Number(panel:GetFrameLevel()) or 0) + 12)
    local shade = Look.OwnTexture(frame, "shade", "BACKGROUND")
    shade:SetColorTexture(0, 0, 0, 0.5)
    Look.Inside(shade, frame, 4, 4, 4, 4)
    local hint = Look.OwnLabel(box, "hint", "GameFontDisableSmall", "ARTWORK")
    Look.Pin(hint, "LEFT", box, "LEFT", 3, 0)
    hint:SetText(S.Say("SEARCH", "Search"))
    box:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    box:SetScript("OnTextChanged", SearchChanged)
    T.searchBox, T.searchFrame, T.searchHint = box, frame, hint
end

function T.SearchShown(on)
    if not T.searchBox then return end
    if not on and (T.searchBox:GetText() or "") ~= "" then T.searchBox:SetText("") end
    Look.Shown(T.searchBox, on)
    Look.Shown(T.searchFrame, on)
end
