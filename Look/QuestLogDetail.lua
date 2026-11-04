-- The classic quest log's detail pane: the selected quest on the
-- parchment, drawn from the top down on the pane's page, every line
-- hanging from the one above it:
--   title (and "- (Failed)"), the objectives text, the time left, each
--   objective (finished ones greyed with "(Complete)"), the money it asks
--   for (red while you are short), "Description" and the description, then
--   the rewards: the choices, the items (with the money beside their label)
--   in a two-column grid of 1.x reward plates, and the experience.
-- Dark brown ink on the parchment, near white with Dark Mode (which greys
-- the parchment). Lines and plates are pooled: put away at the start of
-- every drawing and reused in order. A reward's hover shows the game's own
-- item tooltip data in EraUI's tooltip; EraUI writes nothing into the
-- game's tooltip.
local _, EraUI = ...
local Look = EraUI.Look
local Q = Look.Quest
local parts = Q.parts

local lines, plates = {}, {}
local plateFor = Look.Weak()   -- plate: { kind, index, questID, name, colour }
local pen = { lines = 0, plates = 0 }
local PLATE_SCALE = 141 / 147

---------------------------------------------------------------------------
-- Ink, fonts and the pools
---------------------------------------------------------------------------

local function Inks()
    if EraUI:GetSetting("darkMode") == true then
        return { 0.88, 0.87, 0.83 }, { 0.88, 0.87, 0.83 }
    end
    return { 0.18, 0.12, 0.06 }, { 0.2, 0.2, 0.2 }
end

local function Fonts()
    return {
        title = Q.Font("QuestTitleFont", "QuestFont_Large", "GameFontNormalLarge"),
        body = Q.Font("QuestFont", "QuestFontNormalSmall", "GameFontNormal"),
        small = Q.Font("QuestFontNormalSmall", "GameFontNormalSmall"),
    }
end

-- The next pooled line on the page, in this font and colour, `wide` across.
local function Line(font, colour, wide)
    pen.lines = pen.lines + 1
    local line = lines[pen.lines]
    if not line then
        line = parts.page:CreateFontString(nil, "ARTWORK")
        line:SetJustifyH("LEFT")
        lines[pen.lines] = line
    end
    line:SetFontObject(font)
    line:SetWidth(wide or 285)
    line:SetTextColor(colour[1], colour[2], colour[3])
    line:ClearAllPoints()
    line:Show()
    return line
end

-- Hung `gap` below the last thing placed (the first line from the page's
-- top-left, 5 in).
local function Hang(region, gap)
    if pen.last then
        region:SetPoint("TOPLEFT", pen.last, "BOTTOMLEFT", 0, -gap)
    else
        region:SetPoint("TOPLEFT", parts.page, "TOPLEFT", 5, -5)
    end
    pen.last = region
end

local function Say(font, colour, text, gap, wide)
    local line = Line(font, colour, wide)
    line:SetText(text)
    Hang(line, gap)
    return line
end

---------------------------------------------------------------------------
-- Reward plates
---------------------------------------------------------------------------

local function PlateEnter(plate)
    local info = plateFor[plate]
    if not info then return end
    local tips = C_TooltipInfo
    local fetch = type(tips) == "table" and tips.GetQuestLogItem or nil
    local colour = info.colour or { 1, 1, 1 }
    Look.ShowDataTip(plate, "RIGHT", fetch, { { info.name, colour[1], colour[2], colour[3] } },
        info.kind, info.index, info.questID)
end

local function PlateClick(plate)
    local info = plateFor[plate]
    if not info or not Q.Modified("CHATLINK") or type(GetQuestLogItemLink) ~= "function" then return end
    local fine, link = pcall(GetQuestLogItemLink, info.kind, info.index, info.questID)
    if fine then Look.ChatLink(link) end
end

local function NewPlate()
    local plate = Look.Build("Button", parts.page, nil, { size = { 147, 41 } })
    plate:SetScale(PLATE_SCALE)
    local icon = Look.OwnTexture(plate, "icon", "BACKGROUND")
    icon:SetSize(39, 39)
    Look.Pin(icon, "TOPLEFT", plate, "TOPLEFT", 0, 0)
    local frame = Look.OwnTexture(plate, "frame", "BACKGROUND", 1)
    Look.Art(frame, "questRewardPlate")
    Look.Crop(frame, 0, 1, 0, 1)
    frame:SetSize(128, 64)
    Look.Pin(frame, "LEFT", icon, "RIGHT", -10, 0)
    local count = Look.OwnLabel(plate, "count", "NumberFontNormal", "OVERLAY")
    Look.Pin(count, "BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    local name = Look.OwnLabel(plate, "name", "GameFontHighlight", "ARTWORK")
    name:SetSize(90, 36)
    name:SetJustifyH("LEFT")
    name:SetTextColor(1, 1, 1)
    if name.SetMaxLines then name:SetMaxLines(3) end
    Look.Pin(name, "LEFT", frame, "LEFT", 15, 0)
    plate:SetScript("OnEnter", PlateEnter)
    plate:SetScript("OnLeave", function(self) Look.HideTip(self) end)
    plate:SetScript("OnClick", PlateClick)
    return plate
end

-- Quality colours for the fallback tooltip line.
local function QualityColour(quality)
    local colours = ITEM_QUALITY_COLORS
    local entry = Look.Number(quality) and type(colours) == "table" and colours[quality] or nil
    if type(entry) == "table" and Look.Number(entry.r) then return { entry.r, entry.g, entry.b } end
    return { 1, 1, 1 }
end

-- One reward plate: odd ones start a row 4 below the last thing placed,
-- even ones stand 3 right of the odd one (both gaps in the page's units).
local function Plate(kind, index, questID)
    local reader = kind == "choice" and GetQuestLogChoiceInfo or GetQuestLogRewardInfo
    local name, texture, count, quality, itemID
    if type(reader) == "function" then
        local fine, a, b, c, d, _, f = pcall(reader, index, questID)
        if fine then name, texture, count, quality, itemID = a, b, c, d, f end
    end
    name = Q.Words(name) or ("item " .. tostring(Look.Number(itemID) or "?"))
    pen.plates = pen.plates + 1
    local plate = plates[pen.plates] or NewPlate()
    plates[pen.plates] = plate
    plateFor[plate] = { kind = kind, index = index, questID = questID, name = name, colour = QualityColour(quality) }
    Look.OwnPiece(plate, "icon"):SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    local amount = Look.Number(count) or 0
    local shown = Look.OwnLabel(plate, "count")
    shown:SetText(amount > 1 and tostring(amount) or "")
    shown:SetShown(amount > 1)
    Look.OwnLabel(plate, "name"):SetText(name)
    plate:ClearAllPoints()
    if pen.left and pen.inRow == 1 then
        plate:SetPoint("TOPLEFT", pen.left, "TOPRIGHT", 3 / PLATE_SCALE, 0)
        pen.inRow = 2
    else
        if pen.last then
            plate:SetPoint("TOPLEFT", pen.last, "BOTTOMLEFT", 0, -4 / PLATE_SCALE)
        else
            plate:SetPoint("TOPLEFT", parts.page, "TOPLEFT", 5 / PLATE_SCALE, -5 / PLATE_SCALE)
        end
        pen.last, pen.left, pen.inRow = plate, plate, 1
    end
    plate:Show()
end

local function Plates(kind, total, questID)
    pen.left, pen.inRow = nil, 0
    for index = 1, total do Plate(kind, index, questID) end
    pen.left, pen.inRow = nil, 0
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function Number(fn, ...)
    if type(fn) ~= "function" then return 0 end
    local fine, value = pcall(fn, ...)
    return fine and Look.Number(value) or 0
end

local function Objectives(fonts, ink, done, logIndex)
    local total = Number(GetNumQuestLeaderBoards, logIndex)
    for i = 1, total do
        local fine, text, kind, finished = false, nil, nil, nil
        if type(GetQuestLogLeaderBoard) == "function" then fine, text, kind, finished = pcall(GetQuestLogLeaderBoard, i, logIndex) end
        if fine then
            local words = Q.Words(text) or Q.Words(kind) or ""
            local over = not Look.Secret(finished) and finished == true
            if over then words = words .. " (" .. Q.Say("COMPLETE", "Complete") .. ")" end
            Say(fonts.small, over and done or ink, words, i == 1 and 10 or 2)
        end
    end
    return total
end

local function Rewards(fonts, ink, questID)
    local choices = Number(GetNumQuestLogChoices, questID, true)
    local items = Number(GetNumQuestLogRewards, questID)
    local money = Number(GetQuestLogRewardMoney, questID)
    local xp = Number(GetQuestLogRewardXP, questID)
    if choices + items + money + xp <= 0 then return end
    Say(fonts.title, ink, Q.Say("QUEST_REWARDS", "Rewards"), 10)
    if choices > 0 then
        Say(fonts.small, ink, Q.Say("REWARD_CHOICES", "Choose one of the following rewards:"), 5)
        Plates("choice", choices, questID)
    end
    if items > 0 or money > 0 then
        local label = choices > 0 and Q.Say("REWARD_ITEMS", "You will also receive:")
            or Q.Say("REWARD_ITEMS_ONLY", "You will receive:")
        local line = Say(fonts.small, ink, label, 5)
        if money > 0 then
            local coins = Line(fonts.small, ink, 0)
            coins:SetText(Q.Coins(money))
            coins:SetPoint("TOPLEFT", line, "TOPLEFT", (Look.Number(line:GetStringWidth()) or 0) + 15, 0)
        end
        Plates("reward", items, questID)
    end
    if xp > 0 then
        local amount = type(BreakUpLargeNumbers) == "function" and BreakUpLargeNumbers(xp) or tostring(xp)
        Say(fonts.small, ink, Q.Say("REWARD_XP", "Experience") .. ": " .. amount, 4)
    end
end

local function Draw(entry)
    local fonts = Fonts()
    local ink, done = Inks()
    local questID, logIndex = entry.quest, entry.index
    local failed = Q.Yes(C_QuestLog and C_QuestLog.IsFailed, questID)
    local title = Q.Words(entry.info.title) or ""
    if failed then title = title .. " - (" .. Q.Say("FAILED", "Failed") .. ")" end
    Say(fonts.title, ink, title)
    local description, objectives
    if type(GetQuestLogQuestText) == "function" then
        local fine, first, second = pcall(GetQuestLogQuestText, logIndex)
        if fine then description, objectives = Q.Words(first), Q.Words(second) end
    end
    if objectives then Say(fonts.body, ink, objectives, 5, 275) end
    local left
    if type(GetQuestLogTimeLeft) == "function" then
        local fine, seconds = pcall(GetQuestLogTimeLeft)
        left = fine and Look.Number(seconds) or nil
    end
    if left then
        Q.timed = true
        local clock = type(SecondsToTime) == "function" and SecondsToTime(left) or (tostring(left) .. " sec")
        Say(fonts.small, ink, Q.Say("TIME_REMAINING", "Time Remaining:") .. " " .. clock, 10)
    end
    local counted = Objectives(fonts, ink, done, logIndex)
    local asked = Number(C_QuestLog and C_QuestLog.GetRequiredMoney, questID)
    if asked > 0 then
        local short = asked > Number(GetMoney)
        local colour = short and { 1, 0.1, 0.1 } or done
        Say(fonts.small, colour, Q.Say("REQUIRED_MONEY", "Required Money:") .. " " .. Q.Coins(asked), counted > 0 and 4 or 10)
    end
    if description then
        Say(fonts.title, ink, Q.Say("QUEST_DESCRIPTION", "Description"), 10)
        Say(fonts.body, ink, description, 5, 275)
    end
    Rewards(fonts, ink, questID)
end

-- An edge in screen units (a plate keeps its own, smaller scale).
local function OnScreen(region, edge)
    local at = Look.Number(region[edge](region))
    local scale = Look.Number(region:GetEffectiveScale())
    if not at or not scale then return nil end
    return at * scale
end

-- The page's height from what was drawn (at least the pane's), and the
-- detail bar's range from it; edges not laid out yet: the pane's height.
local function Measure()
    local page, pane = parts.page, parts.detail
    local paneTall = Look.Number(pane:GetHeight()) or 0
    local top = OnScreen(page, "GetTop")
    local bottom = pen.last and OnScreen(pen.last, "GetBottom")
    local scale = Look.Number(page:GetEffectiveScale())
    local tall = paneTall
    if top and bottom and scale and scale > 0 then
        tall = math.max(paneTall, (top - bottom) / scale + 12)
    elseif not pen.waiting and C_Timer and C_Timer.After then
        -- Measured once more on the next frame, once the game has laid it out.
        pen.waiting = true
        C_Timer.After(0, function()
            pen.waiting = false
            if parts.page:IsVisible() then Measure() end
        end)
    end
    page:SetHeight(tall)
    Look.ScrollRange(parts.detailBar, tall - paneTall, 20)
end

-- Every pooled line and plate put away, then the selected quest drawn.
function Q.DrawDetail()
    for _, line in ipairs(lines) do line:Hide() end
    for _, plate in ipairs(plates) do plate:Hide() end
    pen.lines, pen.plates, pen.last, pen.left, pen.inRow = 0, 0, nil, nil, 0
    Q.timed = false
    local entry = Q.selected and Q.EntryFor(Q.selected)
    if not entry then
        Q.drawn = nil
        parts.page:SetHeight(1)
        Look.ScrollRange(parts.detailBar, 0, 20)
        return
    end
    Q.SelectInGame(entry.quest)
    if Q.drawn ~= entry.quest then
        Q.drawn = entry.quest
        parts.detailBar:SetValue(0)
    end
    Look.Try(Draw, entry)
    Measure()
end

function Q.MakeDetail(page)
    page:SetHeight(1)
end
