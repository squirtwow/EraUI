-- The classic trainer's compact list and details: nine rows of the
-- trainer's services under their categories (green available, red not
-- yet, grey known), each row a secure button routed to the game's own row
-- for that service (so a click selects through the game's own button),
-- folding, the All button and the Filter; the chosen service's icon, name,
-- rank, needs, cost and description; the training points; Train's glow
-- from the cursor's place. Drawn and routed only out of a fight.
local _, EraUI = ...
local Look = EraUI.Look
local S = Look.Spells
local R = Look.Trainer

local rowParts = Look.Weak() -- row: { bar, hover, icon, text }
R.rowParts = rowParts
R.rowLine = Look.Weak()

local function Window()
    return ClassTrainerFrame
end

---------------------------------------------------------------------------
-- Collecting the services
---------------------------------------------------------------------------

local function NodeData(frame)
    local fine, node = Look.Ask(frame, "GetElementData")
    if not fine or type(node) ~= "table" then return nil, nil end
    local data = node.data
    if type(data) ~= "table" and type(node.GetData) == "function" then
        local ok, got = pcall(node.GetData, node)
        data = ok and got or nil
    end
    return (type(data) == "table" and data or node), node
end

-- The game's rows: each service's own (by its index), each category's
-- button and whether the game has it collapsed.
local function GameRows()
    local window = Window()
    local rows, categories = {}, {}
    local list = window and window.ScrollBox
    if list and type(list.ForEachFrame) == "function" then
        list:ForEachFrame(function(frame)
            local data, node = NodeData(frame)
            if not data then return end
            local index = Look.Number(data.skillIndex)
            if index then rows[index] = frame end
            local info = type(data.categoryInfo) == "table" and data.categoryInfo
            if info and type(info.name) == "string" then
                local fine, closed = Look.Ask(node, "IsCollapsed")
                categories[info.name] = { button = frame, closed = fine and closed == true }
            end
        end)
    end
    local step = type(GetTrainerServiceStepIndex) == "function" and Look.Number(GetTrainerServiceStepIndex())
    if step and window and window.skillStepButton then rows[step] = window.skillStepButton end
    return rows, categories
end

-- The lines: a header per category in the order first met (closed when
-- EraUI folded it or the game has it collapsed), then its services.
function R.Collect()
    local rows, categories = GameRows()
    local count = type(GetNumTrainerServices) == "function" and Look.Number(GetNumTrainerServices()) or 0
    local groups, byName, named = {}, {}, 0
    for index = 1, count do
        local name, kind, icon, level, rank, category = GetTrainerServiceInfo(index)
        name = S.Text(name)
        if name then
            named = named + 1
            category = (S.Text(category) ~= "" and S.Text(category)) or S.Say("OTHER", "Other")
            local group = byName[category]
            if not group then
                group = { name = category, services = {} }
                byName[category] = group
                groups[#groups + 1] = group
            end
            group.services[#group.services + 1] = { index = index, name = name, kind = kind, icon = icon,
                level = Look.Number(level) or 0, rank = S.Text(rank) or "", row = rows[index] }
        end
    end
    local lines = {}
    for _, group in ipairs(groups) do
        local game = categories[group.name]
        local closed = R.folded[group.name] == true or (game ~= nil and game.closed)
        lines[#lines + 1] = { header = true, name = group.name, closed = closed, game = game }
        if not closed then
            for _, service in ipairs(group.services) do lines[#lines + 1] = { service = service } end
        end
    end
    R.lines, R.count, R.named = lines, count, named
    return lines
end

-- The service the game has selected (its display index mapped back).
function R.Selected()
    local window = Window()
    local shown = window and window.selectedService
    if shown == nil or Look.Secret(shown) then return nil end
    local map = window.displayIndexToSkillIndex
    local index = type(map) == "table" and map[shown] or shown
    return Look.Number(index)
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------

-- No route left on a row (the game may recycle its rows before the next
-- drawing). Out of a fight only.
function R.Disarm(row)
    row:SetAttribute("type1", nil)
    row:SetAttribute("clickbutton", nil)
end

local function Route(row, target)
    row:SetAttribute("type1", "click")
    row:SetAttribute("clickbutton", target)
end

-- After a released left click (out of a fight): a header folds or opens
-- (one the game had collapsed opens through the game's own button); then a
-- refresh.
local function RowAfter(row, button, down)
    if down or button ~= "LeftButton" or Look.InFight() then return end
    local line = R.rowLine[row]
    if line and line.header then
        if line.game and line.game.closed then
            R.folded[line.name] = nil
        else
            R.folded[line.name] = not line.closed or nil
        end
    end
    R.Queue()
end

function R.MakeRow(list)
    local row, parts = Look.SkillRow(list, "SecureActionButtonTemplate")
    row:RegisterForClicks("AnyUp", "AnyDown")
    row:SetAttribute("useOnKeyDown", false)
    row:SetScript("PostClick", RowAfter)
    rowParts[row] = parts
    return row
end

local function KindColour(kind)
    if kind == "available" then return R.GREEN end
    if kind == "unavailable" then return R.RED end
    return R.GREY
end

local function DrawHeader(row, parts, line)
    parts.icon:SetTexture(line.closed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
    parts.icon:Show()
    Look.SkillRowText(parts, row, 21)
    parts.text:SetText(line.name)
    parts.text:SetTextColor(R.GOLD[1], R.GOLD[2], R.GOLD[3])
    parts.bar:Hide()
    if line.game and line.game.closed then Route(row, line.game.button) end
end

local function DrawService(row, parts, service, selected)
    parts.icon:Hide()
    Look.SkillRowText(parts, row, 33)
    parts.text:SetText(service.rank ~= "" and (service.name .. " (" .. service.rank .. ")") or service.name)
    local colour = KindColour(service.kind)
    local chosen = selected == service.index
    if chosen then parts.text:SetTextColor(1, 1, 1) else parts.text:SetTextColor(colour[1], colour[2], colour[3]) end
    parts.bar:SetVertexColor(colour[1], colour[2], colour[3])
    Look.Shown(parts.bar, chosen)
    if service.row then Route(row, service.row) end
end

function R.DrawRows()
    if Look.InFight() or not R.shell then return end
    local offset = math.floor((Look.Number(R.shell.bar:GetValue()) or 0) + 0.5)
    local selected = R.Selected()
    for i, row in ipairs(R.shell.rows) do
        local line, parts = R.lines[offset + i], rowParts[row]
        R.Disarm(row)
        R.rowLine[row] = line
        Look.Shown(row, line ~= nil)
        if line and line.header then
            DrawHeader(row, parts, line)
        elseif line then
            DrawService(row, parts, line.service, selected)
        end
    end
    local anyOpen, any = false, false
    for _, line in ipairs(R.lines) do
        if line.header then
            any = true
            anyOpen = anyOpen or not line.closed
        end
    end
    R.shell.allIcon:SetTexture((any and not anyOpen) and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
    if #R.lines == 0 then
        R.empty:SetText((R.count or 0) > 0 and "Loading abilities..." or "No abilities match the current filters.")
    end
    Look.Shown(R.empty, #R.lines == 0)
    R.routesValid = true
end

function R.AllClick()
    if Look.InFight() or not R.lines then return end
    local anyOpen = false
    for _, line in ipairs(R.lines) do
        if line.header and not line.closed then anyOpen = true end
    end
    for _, line in ipairs(R.lines) do
        if line.header then R.folded[line.name] = anyOpen or nil end
    end
    R.Queue()
end

local FILTERS = { { "available", "AVAILABLE", "Available" }, { "unavailable", "UNAVAILABLE", "Unavailable" },
    { "used", "USED", "Already Known" } }

function R.FilterClick(owner)
    if Look.InFight() then return end
    if not R.filterList then
        local entries = {}
        for _, filter in ipairs(FILTERS) do
            entries[#entries + 1] = {
                label = S.Say(filter[2], filter[3]),
                pick = function()
                    if Look.InFight() then return end
                    SetTrainerServiceTypeFilter(filter[1], not GetTrainerServiceTypeFilter(filter[1]))
                    R.Queue()
                end,
                chosen = function() return GetTrainerServiceTypeFilter(filter[1]) and true or false end,
            }
        end
        R.filterList = Look.DropList(entries)
        R.filterList.Follow(R.panel)
    end
    R.filterList.Toggle(owner)
end

---------------------------------------------------------------------------
-- The details
---------------------------------------------------------------------------

local function Mark(met, text)
    return (met and "|cffffffff" or "|cffff2020") .. text .. "|r"
end

local function PetTrainer()
    local kind = C_Trainer and type(C_Trainer.GetTrainerType) == "function" and C_Trainer.GetTrainerType()
    return Enum and Enum.TrainerType and kind ~= nil and kind == Enum.TrainerType.Pet
end

local function FreePoints()
    if not (C_PetInfo and type(C_PetInfo.GetPetTrainingPoints) == "function") then return 0 end
    local total, used = C_PetInfo.GetPetTrainingPoints()
    return (Look.Number(total) or 0) - (Look.Number(used) or 0)
end

local function Needs(index, level, pet)
    local parts = {}
    if level > 1 then
        local mine = Look.Number(UnitLevel(pet and "pet" or "player")) or 0
        parts[#parts + 1] = Mark(mine >= level, string.format(S.Say("TRAINER_REQ_LEVEL", "Level %d"), level))
    end
    if type(GetTrainerServiceSkillReq) == "function" then
        local skill, rank, met = GetTrainerServiceSkillReq(index)
        if S.Text(skill) then
            parts[#parts + 1] = Mark(met, string.format(S.Say("TRAINER_REQ_SKILL_RANK", "%s (%d)"), skill, Look.Number(rank) or 0))
        end
    end
    local count = type(GetTrainerServiceNumAbilityReq) == "function" and Look.Number(GetTrainerServiceNumAbilityReq(index)) or 0
    for i = 1, count do
        local ability, met = GetTrainerServiceAbilityReq(index, i)
        if S.Text(ability) then parts[#parts + 1] = Mark(met, ability) end
    end
    if #parts == 0 then return "" end
    return S.Say("REQUIRES_LABEL", "Requires:") .. " " .. table.concat(parts, ", ")
end

local function Cost(index, kind, pet)
    if kind == "used" or type(GetTrainerServiceCost) ~= "function" then return "" end
    local cost = Look.Number((GetTrainerServiceCost(index))) or 0
    if cost <= 0 then return "" end
    local text, affordable
    if pet then
        text = string.format(S.Say("TRAINING_POINTS_ABBREV", "%s TP"), cost)
        affordable = FreePoints() >= cost
    else
        local coins = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString
        text = type(coins) == "function" and coins(cost) or tostring(cost)
        affordable = (Look.Number(GetMoney()) or 0) >= cost
    end
    return S.Say("COSTS_LABEL", "Cost:") .. " " .. Mark(affordable, text)
end

function R.DrawDetail()
    local d = R.detail
    local index = R.Selected()
    local window = Window()
    local train = window and window.TrainButton
    local enabled = train and train:IsEnabled()
    R.trainArt:SetEnabled(not Look.Secret(enabled) and enabled == true)
    if not enabled or Look.Secret(enabled) then R.trainGlow:Hide() end
    local pet = PetTrainer()
    Look.Shown(R.points, pet)
    if pet then R.points:SetText(string.format(S.Say("TRAINING_POINTS", "Training Points: %d"), FreePoints())) end
    local name, kind, icon, level, rank = nil, nil, nil, 0, ""
    if index then name, kind, icon, level, rank = GetTrainerServiceInfo(index) end
    name = S.Text(name)
    Look.Shown(d.icon, name ~= nil)
    if not name then
        for _, key in ipairs({ "name", "rank", "needs", "cost", "about" }) do d[key]:SetText("") end
        return
    end
    d.face:SetTexture(icon)
    d.name:SetText(name)
    rank = S.Text(rank) or ""
    d.rank:SetText(rank ~= "" and ("(" .. rank .. ")") or "")
    d.needs:SetText(Needs(index, Look.Number(level) or 0, pet))
    d.cost:SetText(Cost(index, kind, pet))
    local about = type(GetTrainerServiceDescription) == "function" and GetTrainerServiceDescription(index)
    d.about:SetText(S.Text(about) or "")
end

-- The chosen service's tooltip: the game's own data in EraUI's box.
function R.ServiceTip(owner)
    local index = R.Selected()
    if not index then return end
    local name = S.Text((GetTrainerServiceInfo(index)))
    Look.ShowDataTip(owner, "RIGHT", C_TooltipInfo and C_TooltipInfo.GetTrainerService,
        name and { { name, 1, 1, 1 } } or nil, index)
end

---------------------------------------------------------------------------
-- Train's glow (cosmetic: no frame, no mouse, no forwarding)
---------------------------------------------------------------------------

local function Inside(art)
    if type(GetCursorPosition) ~= "function" then return false end
    local x, y = GetCursorPosition()
    local scale = Look.Number(art:GetEffectiveScale())
    x, y = Look.Number(x), Look.Number(y)
    if not (x and y and scale and scale > 0) then return false end
    local left, bottom, width, height = art:GetRect()
    left, bottom, width, height = Look.Number(left), Look.Number(bottom), Look.Number(width), Look.Number(height)
    if not (left and bottom and width and height) then return false end
    x, y = x / scale, y / scale
    return x >= left and x <= left + width and y >= bottom and y <= bottom + height
end

local function GlowWanted(art)
    local window = Window()
    local train = window and window.TrainButton
    if not (R.active and train and R.panel) or Look.InFight() then return false end
    local enabled = train:IsEnabled()
    if Look.Secret(enabled) or enabled ~= true then return false end
    if not (window:IsShown() and train:IsShown() and R.panel:IsShown()) then return false end
    return Inside(art)
end

local waited = 0
function R.GlowTick(art, elapsed)
    waited = waited + (Look.Number(elapsed) or 0)
    if waited < 0.05 then return end
    waited = 0
    Look.Shown(R.trainGlow, GlowWanted(art))
end

-- Hidden at once when the game's Train is turned off or hidden; looked at
-- again when it comes back on.
function R.WatchTrain()
    local window = Window()
    local train = window and window.TrainButton
    if not train then return end
    local function Off() if R.trainGlow then R.trainGlow:Hide() end end
    Look.HookScript(train, "OnDisable", Off, "trainer")
    Look.HookScript(train, "OnHide", Off, "trainer")
    Look.HookScript(train, "OnEnable", function()
        if R.trainArt then
            waited = 1
            R.GlowTick(R.trainArt, 0)
        end
    end, "trainer")
end
