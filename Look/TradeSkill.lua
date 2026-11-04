-- The trade skill window (Classic look, registry "tradeSkillSearch" then
-- "tradeSkill", both from /era's Professions): when a profession opens, the
-- game's Professions window (sized 362 x 444 by the professions watch)
-- shows EraUI's old trade skill window on top: the rank bar, the recipe
-- list (Look/TradeList.lua), the chosen recipe with its needs, cooldown
-- and reagents, and the foot: Create All, a count with arrows, Create and
-- Exit. The game's own crafting page is sent off the screen, once.
-- Public: ns.ShowTradeSkill(up), ns.TradeSkillActive(),
-- ns.TradeSkillWindowSize().
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Spells
local T = Look.Trade

local WIDTH, HEIGHT = 362, 444
local RED = "|cffff2020"
local sentAway = Look.Weak() -- the game's crafting page: true once moved

do
    local engine = type(ns.DB_DEFAULTS) == "table" and ns.DB_DEFAULTS or nil
    if engine then
        if engine.tradeSkill == nil then engine.tradeSkill = true end
        if engine.tradeSkillSearch == nil then engine.tradeSkillSearch = true end
    end
end

---------------------------------------------------------------------------
-- The rank bar
---------------------------------------------------------------------------

local function RankBar(panel)
    local bar = CreateFrame("StatusBar", nil, panel)
    bar:SetHeight(13)
    bar:SetPoint("TOPLEFT", panel, "TOPLEFT", 72, -36)
    bar:SetPoint("RIGHT", panel, "RIGHT", -42, 0)
    bar:SetStatusBarTexture(Look.FirstPath("skillsBar") or "Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.25, 0.25, 0.75)
    local ground = Look.OwnTexture(bar, "ground", "BACKGROUND")
    ground:SetColorTexture(0, 0, 0, 0.6)
    Look.Fill(ground, bar)
    local border = Look.OwnTexture(bar, "border", "OVERLAY")
    Look.Art(border, "skillsBarBorder")
    border:SetPoint("TOPLEFT", bar, "TOPLEFT", -5, 5)
    border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 5, -5)
    local text = Look.OwnLabel(bar, "text", "GameFontHighlightSmall", "OVERLAY")
    Look.Pin(text, "CENTER", bar, "CENTER", 0, 0)
    T.rankBar, T.rankText = bar, text
end

-- The profession on show: name, rank, max and modifier (the child
-- profession, else the base one, else the profession whose skill line the
-- first recipe belongs to).
local function Profession()
    for _, reader in ipairs({ "GetChildProfessionInfo", "GetBaseProfessionInfo" }) do
        local info = T.Api(reader)
        local max = type(info) == "table" and Look.Number(info.maxSkillLevel)
        if max and max > 0 then
            return S.Text(info.professionName), Look.Number(info.skillLevel) or 0, max, Look.Number(info.skillModifier) or 0
        end
    end
    local first
    for _, line in ipairs(T.lines) do
        first = first or line.recipe
    end
    if not first or type(GetProfessions) ~= "function" then return nil end
    local line, _, parent = T.Api("GetTradeSkillLineForRecipe", first.id)
    -- The first eight slots by place: a slot the player hasn't learned is
    -- nil (no first primary profession starts the list with one).
    local slots = { GetProfessions() }
    for place = 1, 8 do
        local index = Look.Number(slots[place])
        local fine, name, _, rank, max, _, _, skill, modifier = false
        if index and type(GetProfessionInfo) == "function" then
            fine, name, _, rank, max, _, _, skill, modifier = pcall(GetProfessionInfo, index)
        end
        if fine and skill and (skill == line or skill == parent) then
            return S.Text(name), Look.Number(rank) or 0, Look.Number(max) or 0, Look.Number(modifier) or 0
        end
    end
    return nil
end

local function DrawRank()
    local name, rank, max, modifier = Profession()
    Look.Shown(T.rankBar, max ~= nil)
    if not max then return end
    T.rankBar:SetMinMaxValues(0, math.max(1, max))
    T.rankBar:SetValue(rank)
    if modifier > 0 then
        T.rankText:SetText(rank .. " (+" .. modifier .. ")/" .. max)
    else
        T.rankText:SetText(rank .. "/" .. max)
    end
    local title = ProfessionsFrame and ProfessionsFrame.TitleContainer and ProfessionsFrame.TitleContainer.TitleText
    local shown = title and title:GetText()
    if title and name and (shown == nil or shown == "") then title:SetText(name) end
end

---------------------------------------------------------------------------
-- The detail
---------------------------------------------------------------------------

local function ResultTip(button)
    local recipe = T.Selected()
    if not recipe then return end
    local fetch = C_TooltipInfo and C_TooltipInfo.GetRecipeResultItem
    if Look.ShowDataTip(button, "RIGHT", fetch, nil, recipe.id, {}) then return end
    Look.ShowDataTip(button, "RIGHT", C_TooltipInfo and C_TooltipInfo.GetSpellByID, { { recipe.name, 1, 1, 1 } }, recipe.id)
end

local function Modified(link)
    if type(IsModifiedClick) == "function" and IsModifiedClick() and type(HandleModifiedItemClick) == "function"
        and type(link) == "string" and not Look.Secret(link) then
        Look.Try(HandleModifiedItemClick, link)
    end
end

local function IconButton(detail)
    local button = Look.Build("Button", detail, nil, { size = { 37, 37 } })
    Look.Pin(button, "TOPLEFT", detail, "TOPLEFT", 20, -18)
    local icon = Look.OwnTexture(button, "icon", "ARTWORK")
    Look.Fill(icon, button)
    local made = Look.OwnLabel(button, "made", "NumberFontNormal", "OVERLAY")
    Look.Pin(made, "BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button:SetScript("OnEnter", ResultTip)
    button:SetScript("OnLeave", function(self) Look.HideTip(self) end)
    button:SetScript("OnClick", function()
        local recipe = T.Selected()
        if recipe then Modified((T.Api("GetRecipeItemLink", recipe.id))) end
    end)
    T.icon, T.iconTexture, T.madeText = button, icon, made
end

local function ItemName(item)
    local items = C_Item
    local name = type(items) == "table" and type(items.GetItemNameByID) == "function" and items.GetItemNameByID(item)
    if not S.Text(name) and type(items) == "table" and type(items.RequestLoadItemDataByID) == "function" then
        pcall(items.RequestLoadItemDataByID, item)
    end
    return S.Text(name) or ""
end

local function ItemIcon(item)
    local items = C_Item
    if type(items) == "table" and type(items.GetItemIconByID) == "function" then return items.GetItemIconByID(item) end
    if type(GetItemIcon) == "function" then return GetItemIcon(item) end
    return nil
end

local reagentOf = Look.Weak() -- reagent button: { item, slot }

local function ReagentTip(button)
    local held, recipe = reagentOf[button], T.Selected()
    if not held then return end
    local fetch = C_TooltipInfo and C_TooltipInfo.GetRecipeReagentItem
    if recipe and held.slot and Look.ShowDataTip(button, "RIGHT", fetch, nil, recipe.id, held.slot) then return end
    Look.ShowDataTip(button, "RIGHT", C_TooltipInfo and C_TooltipInfo.GetItemByID, nil, held.item)
end

local function ReagentClick(button)
    local held = reagentOf[button]
    local items = C_Item
    if held and type(items) == "table" and type(items.GetItemInfo) == "function" then
        local fine, _, link = pcall(items.GetItemInfo, held.item)
        if fine then Modified(link) end
    end
end

-- Each reagent's pieces: { purpose, layer, width, height, point, x, y }
-- against the button (the name against the icon).
local REAGENT_PLATE = { "plate", "BACKGROUND", 128, 64, "LEFT", 30, 0 }
local REAGENT_ICON = { "icon", "ARTWORK", 39, 39, "LEFT", 0, 0 }

local function Sized(button, spec)
    local piece = Look.OwnTexture(button, spec[1], spec[2])
    piece:SetSize(spec[3], spec[4])
    Look.Pin(piece, spec[5], button, spec[5], spec[6], spec[7])
    return piece
end

local function Reagent(detail, k)
    local button = Look.Build("Button", detail, nil, { size = { 148, 41 } })
    local column, line = k % 2, math.floor(k / 2)
    Look.Pin(button, "TOPLEFT", T.reagentLabel, "BOTTOMLEFT", column * 152 - 2, -3 - line * 43)
    Sized(button, REAGENT_PLATE):SetTexture("Interface\\QuestFrame\\UI-QuestItemNameFrame")
    local icon = Sized(button, REAGENT_ICON)
    local count = Look.OwnLabel(button, "count", "NumberFontNormal", "OVERLAY")
    Look.Pin(count, "BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    local name = Look.OwnLabel(button, "name", "GameFontHighlight", "ARTWORK")
    name:SetWidth(98)
    name:SetHeight(36)
    name:SetJustifyH("LEFT")
    Look.Pin(name, "LEFT", icon, "RIGHT", 6, 0)
    button:SetScript("OnEnter", ReagentTip)
    button:SetScript("OnLeave", function(self) Look.HideTip(self) end)
    button:SetScript("OnClick", ReagentClick)
    return { button = button, icon = icon, count = count, name = name }
end

local function Detail(detail)
    IconButton(detail)
    local name = Look.OwnLabel(detail, "name", "GameFontNormal", "ARTWORK")
    name:SetPoint("TOPLEFT", T.icon, "TOPRIGHT", 8, -2)
    name:SetPoint("RIGHT", detail, "RIGHT", -14, 0)
    name:SetJustifyH("LEFT")
    local needs = Look.OwnLabel(detail, "needs", "GameFontHighlightSmall", "ARTWORK")
    needs:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    needs:SetPoint("RIGHT", detail, "RIGHT", -14, 0)
    needs:SetJustifyH("LEFT")
    local cooldown = Look.OwnLabel(detail, "cooldown", "GameFontRedSmall", "ARTWORK")
    Look.Pin(cooldown, "TOPLEFT", needs, "BOTTOMLEFT", 0, -2)
    local label = Look.OwnLabel(detail, "reagents", "GameFontNormalSmall", "ARTWORK")
    Look.Pin(label, "TOPLEFT", detail, "TOPLEFT", 19, -66)
    label:SetText(S.Say("SPELL_REAGENTS", "Reagents:"))
    T.nameText, T.needsText, T.cooldownText, T.reagentLabel = name, needs, cooldown, label
    T.reagents = {}
    for k = 0, 7 do T.reagents[k + 1] = Reagent(detail, k) end
end

local function Needs(recipe)
    local parts = {}
    for _, need in ipairs(T.Api("GetRecipeRequirements", recipe.id) or {}) do
        local name = type(need) == "table" and S.Text(need.name)
        if name then parts[#parts + 1] = (need.met == true and "|cffffffff" or RED) .. name .. "|r" end
    end
    if #parts == 0 then return nil end
    return S.Say("REQUIRES_LABEL", "Requires:") .. " " .. table.concat(parts, ", ")
end

local function DrawReagents(recipe)
    local reagents = T.Reagents(recipe.id)
    Look.Shown(T.reagentLabel, #reagents > 0)
    for i, view in ipairs(T.reagents) do
        local reagent = reagents[i]
        Look.Shown(view.button, reagent ~= nil)
        reagentOf[view.button] = reagent
        if reagent then
            local have = T.Have(reagent.item)
            local shade = have < reagent.need and 0.5 or 1
            view.icon:SetTexture(ItemIcon(reagent.item))
            view.icon:SetVertexColor(shade, shade, shade)
            view.name:SetText(ItemName(reagent.item))
            view.name:SetTextColor(shade, shade, shade)
            view.count:SetText(have .. "/" .. reagent.need)
        end
    end
end

function T.DrawDetail()
    local recipe = T.Selected()
    Look.Shown(T.shell.detail, recipe ~= nil)
    if not recipe then
        T.create:Disable()
        T.createAll:Disable()
        return
    end
    local _, schematic = T.Reagents(recipe.id)
    T.iconTexture:SetTexture(recipe.info.icon or (type(schematic) == "table" and schematic.icon) or nil)
    local most = type(schematic) == "table" and Look.Number(schematic.quantityMax) or 1
    T.madeText:SetText(most > 1 and tostring(most) or "")
    T.nameText:SetText(recipe.name)
    local needs = Needs(recipe)
    T.needsText:SetText(needs or "")
    Look.Shown(T.needsText, needs ~= nil)
    local left = Look.Number((T.Api("GetRecipeCooldown", recipe.id))) or 0
    if left > 0 and type(SecondsToTime) == "function" then
        T.cooldownText:SetText(S.Say("COOLDOWN_REMAINING", "Cooldown remaining:") .. " " .. SecondsToTime(left))
    end
    Look.Shown(T.cooldownText, left > 0)
    DrawReagents(recipe)
    local can = T.Makeable(recipe.id, recipe.info) > 0 and not recipe.info.disabled
    T.create:SetEnabled(can)
    T.createAll:SetEnabled(can)
end

---------------------------------------------------------------------------
-- The foot: making things
---------------------------------------------------------------------------

local function Most()
    local recipe = T.Selected()
    return math.max(1, recipe and T.Makeable(recipe.id, recipe.info) or 0)
end

local function ShowCount(value)
    T.count = value
    T.countBox:SetText(tostring(value))
end

local function Step(by)
    ShowCount(Look.Clamp(T.count + by, 1, Most()))
end

local function Make(all)
    local recipe = T.Selected()
    if not recipe then return end
    local wanted = all and T.Makeable(recipe.id, recipe.info) or (tonumber(T.countBox:GetText()) or 1)
    wanted = Look.Clamp(wanted, 1, Most())
    T.countBox:ClearFocus()
    ShowCount(wanted)
    T.making, T.left = recipe.id, wanted
    T.Api("CraftRecipe", recipe.id, wanted)
end

local function PageArrow(panel, way)
    local arrow = Look.Build("Button", panel, nil, { size = { 20, 20 } })
    local file = "Interface\\Buttons\\UI-SpellbookIcon-" .. way .. "Page-"
    arrow:SetNormalTexture(file .. "Up")
    arrow:SetPushedTexture(file .. "Down")
    arrow:SetDisabledTexture(file .. "Disabled")
    arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    local glow = arrow:GetHighlightTexture()
    if glow then glow:SetBlendMode("ADD") end
    arrow:SetScript("OnClick", function() Step(way == "Next" and 1 or -1) end)
    return arrow
end

local function Foot(panel)
    local createAll = Look.PanelButton(panel, S.Say("CREATE_ALL", "Create All"), 92)
    Look.Pin(createAll, "BOTTOMLEFT", panel, "BOTTOMLEFT", 7, 11)
    createAll:SetScript("OnClick", function() Make(true) end)
    local fewer = PageArrow(panel, "Prev")
    Look.Pin(fewer, "LEFT", createAll, "RIGHT", 5, 0)
    local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    box:SetSize(24, 20)
    Look.Pin(box, "LEFT", fewer, "RIGHT", 5, 0)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(3)
    box:SetText("1")
    box:SetScript("OnEnterPressed", box.ClearFocus)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    local more = PageArrow(panel, "Next")
    Look.Pin(more, "LEFT", box, "RIGHT", 1, 0)
    local frame = Look.InsetBox(panel, 16, true)
    frame:SetPoint("TOPLEFT", fewer, "TOPLEFT", -4, 4)
    frame:SetPoint("BOTTOMRIGHT", more, "BOTTOMRIGHT", 4, -4)
    frame:SetFrameLevel(math.max(0, (Look.Number(fewer:GetFrameLevel()) or 1) - 1))
    local exit = Look.PanelButton(panel, S.Say("EXIT", "Exit"), 86)
    Look.Pin(exit, "BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 11)
    exit:SetScript("OnClick", function() Look.HidePanel(ProfessionsFrame) end)
    local create = Look.PanelButton(panel, S.Say("CREATE_PROFESSION", S.Say("CREATE", "Create")), 93)
    Look.Pin(create, "RIGHT", exit, "LEFT", -2, 0)
    create:SetScript("OnClick", function() Make(false) end)
    T.createAll, T.create, T.countBox, T.exit = createAll, create, box, exit
end

-- Counting down a batch as each one is made; back to 1 when it stops.
local function Casts(_, event, unit, _, spell)
    if not T.making then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit ~= "player" or Look.Secret(spell) or spell ~= T.making then return end
        T.left = T.left - 1
        if T.left <= 0 then
            T.making = nil
            ShowCount(1)
        else
            ShowCount(T.left)
        end
    elseif event == "UPDATE_TRADESKILL_CAST_STOPPED" or (event == "UNIT_SPELLCAST_INTERRUPTED" and unit == "player") then
        T.making = nil
        ShowCount(1)
    end
end

---------------------------------------------------------------------------
-- Refresh, events and warming the reagents
---------------------------------------------------------------------------

function T.Draw()
    if not T.panel then return end
    T.DrawRows()
    T.DrawDetail()
end

-- The reagents' names asked for ahead, ten recipes every 0.02 s.
local queue, warmer = {}, nil
local function Warm()
    for _, line in ipairs(T.lines) do
        local recipe = line.recipe
        if recipe and not T.warmed[recipe.id] then
            T.warmed[recipe.id] = true
            queue[#queue + 1] = recipe.id
        end
    end
    if #queue == 0 or (warmer and warmer:IsShown()) then return end
    if not warmer then
        warmer = CreateFrame("Frame")
        local waited = 0
        warmer:SetScript("OnUpdate", function(self, elapsed)
            waited = waited + (Look.Number(elapsed) or 0)
            if waited < 0.02 then return end
            waited = 0
            for _ = 1, 10 do
                local recipe = table.remove(queue, 1)
                if not recipe then break end
                for _, reagent in ipairs(T.Reagents(recipe)) do ItemName(reagent.item) end
            end
            if #queue == 0 then self:Hide() end
        end)
    end
    warmer:Show()
end

function T.Refresh()
    if not (T.panel and T.panel:IsShown()) then return end
    T.Collect()
    DrawRank()
    T.Draw()
    Warm()
end

local EVENTS = Look.Words([[TRADE_SKILL_SHOW TRADE_SKILL_LIST_UPDATE TRADE_SKILL_DATA_SOURCE_CHANGED
    TRADE_SKILL_DETAILS_UPDATE BAG_UPDATE_DELAYED GET_ITEM_INFO_RECEIVED SKILL_LINES_CHANGED
    UPDATE_TRADESKILL_CAST_STOPPED TRADE_SKILL_ITEM_CRAFTED_RESULT]])

-- One job on the next frame: only item names come in → the detail redrawn;
-- anything else → a full refresh.
local pending, onlyNames = false, true
local function Job()
    pending = false
    if not (T.active and T.panel and T.panel:IsShown()) then return end
    if onlyNames then T.DrawDetail() else T.Refresh() end
end

local function OnEvent(_, event)
    if not T.active then return end
    onlyNames = (not pending or onlyNames) and event == "GET_ITEM_INFO_RECEIVED"
    if pending then return end
    pending = true
    S.NextFrame(Job)
end

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------

local function Build()
    if T.panel then return T.panel end
    local frame = ProfessionsFrame
    if not frame then return nil end
    local panel = Look.Build("Frame", frame, nil, { name = "EraUIClassicTradeSkill", size = { WIDTH, HEIGHT }, hidden = true })
    panel:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    panel:SetFrameLevel((Look.Number(frame:GetFrameLevel()) or 0) + 120)
    T.panel = panel
    RankBar(panel)
    T.shell = Look.SkillShell(panel, { rows = 8, makeRow = T.MakeRow, onScroll = function() T.DrawRows() end })
    T.shell.all:SetScript("OnClick", T.AllClick)
    T.shell.filter:SetScript("OnClick", T.FilterClick)
    T.BuildSearch(panel)
    T.SearchShown(Look.Saved().tradeSkillSearch ~= false)
    Detail(T.shell.detail)
    Foot(panel)
    panel:SetScript("OnShow", T.Refresh)
    local listener = Look.Build("Frame", panel, nil, { size = { 1, 1 } })
    for _, event in ipairs(EVENTS) do Look.Listen(listener, event) end
    listener:SetScript("OnEvent", OnEvent)
    local casts = Look.Build("Frame", panel, nil, { size = { 1, 1 } })
    Look.Listen(casts, "UNIT_SPELLCAST_SUCCEEDED", "player")
    Look.Listen(casts, "UNIT_SPELLCAST_INTERRUPTED", "player")
    Look.Listen(casts, "UPDATE_TRADESKILL_CAST_STOPPED")
    casts:SetScript("OnEvent", Casts)
    return panel
end
T.Build = Build

-- The game's crafting page sent off the screen, once (not while the game
-- guards it in a fight).
local function SendAway(frame)
    local page = frame.CraftingPage
    if not page or sentAway[page] then return sentAway[page] == true end
    if Look.InFight() and page:IsProtected() then return false end
    local width, height = Look.Number(page:GetWidth()) or 0, Look.Number(page:GetHeight()) or 0
    page:ClearAllPoints()
    page:SetSize(math.max(600, width), math.max(500, height))
    page:SetPoint("TOPLEFT", frame, "TOPLEFT", 6000, 0)
    page:SetAlpha(0)
    sentAway[page] = true
    return true
end

-- Asked by the professions watch every 0.1 s: up while a profession's page
-- shows (and only once the game's own page has gone).
ns.ShowTradeSkill = function(up)
    if not T.active then return Look.Shown(T.panel, false) end
    local panel = Build()
    if panel then Look.Shown(panel, up and SendAway(ProfessionsFrame)) end
end

ns.TradeSkillActive = function() return T.active == true end
ns.TradeSkillWindowSize = function() return WIDTH, HEIGHT end

---------------------------------------------------------------------------
-- The registry entries (the search box first; it only touches a built window)
---------------------------------------------------------------------------

local function SearchOn() T.SearchShown(true) end
local function SearchOff() T.SearchShown(false) end
ns.RegisterModule("tradeSkillSearch", { apply = SearchOn, restore = SearchOff })

-- On: the professions watch runs (it asks for the window every 0.1 s).
-- Off: the window put away and a reload asked for (the game's crafting
-- page stays sent away until then).
local function WindowOn()
    T.active = true
    if type(ns.StartProfessionsWatch) == "function" then ns.StartProfessionsWatch() end
end

local function WindowOff()
    T.active = false
    Look.Shown(T.panel, false)
    ns.needsReload = true
end

ns.RegisterModule("tradeSkill", { apply = WindowOn, restore = WindowOff })
