-- The classic quest log's list and the refresh that keeps the window
-- current (registry "questLog"):
--   * the entries, read fresh from the game's log on every refresh: every
--     header (the game's own headers are kept open so every quest can be
--     read; EraUI keeps its own folding, for this session only), and every
--     quest that isn't under a folded header, hidden, a task or a bounty;
--   * 21 list lines made with the window (six shown in single pane, all in
--     double), scrolled by the 1.x bar or the mouse wheel a line a notch;
--   * the selection: kept while it is listed, else the game's, else the
--     first quest;
--   * the count box, the All tab, the radios and the foot's buttons follow;
--   * a quest with a voice (Squirt's voice-over addon, when it is loaded,
--     Look/QuestKit.lua) gets a small seal at its line's right end: a click
--     plays the quest's text, again pauses it. Its tag moves left of the
--     seal and the title gives it room. EraUI's own button on each line,
--     set with the line on every refresh and scroll.
local _, EraUI = ...
local Look = EraUI.Look
local Q = Look.Quest
local parts = Q.parts

local shows = Look.Weak()     -- list line: the item it shows
local inkOf = Look.Weak()     -- list line: { r, g, b } of its words
local sealOf = Look.Weak()    -- list line: its voice seal
local voiceOf = Look.Weak()   -- voice seal: the quest it plays
local SEAL = 14               -- the voice seal, a little under a line's height

---------------------------------------------------------------------------
-- Items: the log's headers and quests as the list shows them
---------------------------------------------------------------------------

-- Where EraUI keeps a header's folding: its sort key, else its title,
-- else its place in the log.
local function FoldKey(info, place)
    local key = info.headerSortKey
    if key == nil or Look.Secret(key) then key = Q.Words(info.title) end
    return key or info.questLogIndex or place
end

local function OpenInGame(place)
    if type(ExpandQuestHeader) == "function" then pcall(ExpandQuestHeader, place) end
end

local function Listable(info)
    return info.isHidden ~= true and info.isTask ~= true and info.isBounty ~= true
end

function Q.Collect()
    local found, underFold = {}, false
    local place = 1
    while place <= Q.EntryCount() do
        local info = Q.Info(place)
        if info and info.isHeader == true then
            if info.isCollapsed == true then OpenInGame(Look.Number(info.questLogIndex) or place) end
            local key = FoldKey(info, place)
            underFold = Q.folded[key] == true
            found[#found + 1] = { header = true, key = key, title = Q.Words(info.title) or "", folded = underFold }
        elseif info and not underFold and Listable(info) and Look.Number(info.questID) then
            found[#found + 1] = { quest = info.questID, info = info, index = Look.Number(info.questLogIndex) or place }
        end
        place = place + 1
    end
    return found
end

-- True only with at least one header, every one of them folded.
function Q.AllFolded(list)
    local headerCount = 0
    for _, item in ipairs(list or Q.entries) do
        if item.header then
            if not item.folded then return false end
            headerCount = headerCount + 1
        end
    end
    return headerCount > 0
end

-- Every listed header folded, or EraUI's folding forgotten (the caller
-- refreshes).
function Q.FoldAll(fold)
    if not fold then
        for key in pairs(Q.folded) do Q.folded[key] = nil end
        return
    end
    for _, item in ipairs(Q.Collect()) do
        if item.header then Q.folded[item.key] = true end
    end
end

function Q.EntryFor(questID)
    for place, item in ipairs(Q.entries) do
        if item.quest == questID then return item, place end
    end
    return nil
end

---------------------------------------------------------------------------
-- List lines
---------------------------------------------------------------------------

local function Words(slot) return Look.OwnLabel(slot, "title") end

local function TintWords(slot, r, g, b)
    inkOf[slot] = { r, g, b }
    Words(slot):SetTextColor(r, g, b)
end

local function ShowHeader(slot, item)
    local icon = Look.OwnPiece(slot, "icon")
    icon:SetTexture(item.folded and Q.FILES.plus or Q.FILES.minus)
    icon:Show()
    Words(slot):SetWidth(0)
    Words(slot):SetText(item.title)
    Look.OwnLabel(slot, "tag"):Hide()
    Look.OwnPiece(slot, "check"):Hide()
    voiceOf[sealOf[slot]] = nil
    sealOf[slot]:Hide()
    -- The plus glow over the icon (a quest's glow fills its line).
    slot:SetHighlightTexture(Q.FILES.plusGlow)
    local hilite = slot:GetHighlightTexture()
    Look.Fill(hilite, icon)
    hilite:SetBlendMode("ADD")
    hilite:SetVertexColor(1, 1, 1)
    slot:UnlockHighlight()
    TintWords(slot, Q.HeaderColor())
end

-- "  [2] Title": two spaces, then how many of the party are on it.
local function QuestLine(item)
    local title = Q.Words(item.info.title) or ""
    local onIt = #item.party
    if onIt > 0 then return "  [" .. onIt .. "] " .. title end
    return "  " .. title
end

-- The line's voice seal: shown with the voice addon's picture for a quest
-- with a voice, else put away. True when it shows.
local function ShowSeal(slot, questID)
    local seal, art = sealOf[slot], Q.VoiceSeal(questID)
    voiceOf[seal] = art and questID or nil
    if art then
        Look.OwnPiece(seal, "face"):SetTexture(art)
        Look.OwnPiece(seal, "glow"):SetTexture(art)
    end
    seal:SetShown(art ~= nil)
    if not art and Look.TipOwner() == seal then Look.HideTip(seal) end
    return art ~= nil
end

local function ShowQuest(slot, item)
    Look.OwnPiece(slot, "icon"):Hide()
    item.party = Q.PartyOn(item.quest)
    item.tag = Q.Tag(item.info)
    local words, tagged = Words(slot), Look.OwnLabel(slot, "tag")
    tagged:SetText(item.tag and ("(" .. item.tag .. ")") or "")
    tagged:SetShown(item.tag ~= nil)
    words:SetWidth(0)
    words:SetText(QuestLine(item))
    local voiced, watched = ShowSeal(slot, item.quest), Q.Watched(item.quest)
    Look.Pin(tagged, "RIGHT", voiced and sealOf[slot] or slot, voiced and "LEFT" or "RIGHT", -2, 0)
    local room = 275
    if item.tag then room = room - ((Look.Number(tagged:GetStringWidth()) or 0) + 15) end
    -- Room for the seal, and for the check mark after the title before it.
    if voiced then room = room - (SEAL + 4) - (watched and 20 or 0) end
    local across = math.min(Look.Number(words:GetStringWidth()) or 0, room)
    words:SetWidth(across)
    local mark = Look.OwnPiece(slot, "check")
    Look.Pin(mark, "LEFT", slot, "LEFT", 20 + across + 4, 0)
    mark:SetShown(watched)
    local r, g, b = Q.LevelColor(Look.Number(item.info.difficultyLevel) or Look.Number(item.info.level) or 0)
    local hilite = Look.StateArt(slot, "Highlight", "questLogHighlight")
    if hilite then
        Look.Crop(hilite, 0, 1, 0, 1)
        Look.Fill(hilite, slot)
        hilite:SetBlendMode("ADD")
    end
    TintWords(slot, r, g, b)
    -- The selected quest: its glow in its colour, held on, its tag white.
    local chosen = item.quest == Q.selected
    if hilite then
        if chosen then hilite:SetVertexColor(r, g, b) else hilite:SetVertexColor(1, 1, 1) end
    end
    if chosen then slot:LockHighlight() else slot:UnlockHighlight() end
    if chosen then tagged:SetTextColor(1, 1, 1) else tagged:SetTextColor(r, g, b) end
end

-- The hover: the words white; a quest's tooltip (title, tag, the party).
local function HoverIn(slot)
    local item = shows[slot]
    if item == nil then return end
    Words(slot):SetTextColor(1, 1, 1)
    if item.header then
        -- A refresh can turn a hovered quest line into a header: no tooltip.
        Look.HideTip(slot)
        return
    end
    local tip = { { Q.Words(item.info.title) or "", 1, 1, 1 } }
    if item.tag then tip[#tip + 1] = { item.tag, 0.8, 0.8, 0.8 } end
    local party = item.party or {}
    if #party > 0 then
        tip[#tip + 1] = { " ", 1, 1, 1 }
        tip[#tip + 1] = { Q.Say("PARTY_QUEST_STATUS_ON", "Party members that are on this quest:"), 1, 0.82, 0 }
        for _, name in ipairs(party) do tip[#tip + 1] = { name, 1, 1, 1 } end
    end
    Look.ShowTip(slot, "RIGHT", tip)
end

local function HoverOut(slot)
    local ink = inkOf[slot]
    if ink then Words(slot):SetTextColor(ink[1], ink[2], ink[3]) end
    Look.HideTip(slot)
end

-- A header folds or opens; a quest is linked in chat (with the chat-link
-- modifier), watched or not (Shift), and chosen.
local function Clicked(slot)
    local item = shows[slot]
    if item == nil then return end
    if item.header then
        local opening = Q.folded[item.key] == true
        Q.folded[item.key] = (not opening) or nil
        Q.Sound(opening and "IG_QUEST_LIST_OPEN" or "IG_QUEST_LIST_CLOSE")
        Q.Refresh()
        return
    end
    local questID = item.quest
    if Q.Modified("CHATLINK") and type(GetQuestLink) == "function" then
        local fine, link = pcall(GetQuestLink, questID)
        if fine and Look.ChatLink(link) then return end
    end
    if IsShiftKeyDown and IsShiftKeyDown() then Q.FlipWatch(questID) end
    Q.selected = questID
    Q.SelectInGame(questID)
    Q.Sound("IG_QUEST_LIST_SELECT")
    Q.Refresh()
end

local LINE_SCRIPTS = { OnClick = Clicked, OnEnter = HoverIn, OnLeave = HoverOut }

-- A voice seal's click plays its quest (again: pauses, again: carries on);
-- the line under it isn't clicked, so the selection stays.
local function SealClicked(seal)
    local questID = voiceOf[seal]
    if questID then Q.PlayVoice(questID) end
end

local function SealIn(seal)
    if voiceOf[seal] then Look.ShowTip(seal, "RIGHT", { { "Play this quest's voice", 1, 1, 1 } }) end
end

local function SealOut(seal)
    Look.HideTip(seal)
end

local SEAL_SCRIPTS = { OnClick = SealClicked, OnEnter = SealIn, OnLeave = SealOut }

-- The line's voice seal: EraUI's own small button at its right end (a
-- child of the line, so above its words and glow), put away until a quest
-- with a voice shows there.
local function NewSeal(slot)
    local seal = Look.Build("Button", slot, nil, { size = { SEAL, SEAL }, hidden = true })
    Look.Pin(seal, "RIGHT", slot, "RIGHT", -2, 0)
    Look.Fill(Look.OwnTexture(seal, "face", "ARTWORK"), seal)
    local glow = Look.OwnTexture(seal, "glow", "HIGHLIGHT")
    Look.Fill(glow, seal)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.4)
    for script, run in pairs(SEAL_SCRIPTS) do seal:SetScript(script, run) end
    sealOf[slot] = seal
end

-- One list line: 15 tall, the icon (headers), the words from 20 in, the
-- tag at the right, the check mark and the hover glow.
local function NewLine(list, above)
    local slot = Look.Build("Button", list, nil, { size = { 300, 15 } })
    if above then
        Look.Pin(slot, "TOPLEFT", above, "BOTTOMLEFT", 0, -0.6)
    else
        Look.Pin(slot, "TOPLEFT", list, "TOPLEFT", 0, 0)
    end
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local icon = Look.OwnTexture(slot, "icon", "ARTWORK")
    icon:SetSize(16, 16)
    Look.Pin(icon, "LEFT", slot, "LEFT", 3, 0)
    local words = Look.OwnLabel(slot, "title", "GameFontNormal", "ARTWORK")
    words:SetJustifyH("LEFT")
    words:SetWordWrap(false)
    Look.Pin(words, "LEFT", slot, "LEFT", 20, 0)
    local tagged = Look.OwnLabel(slot, "tag", "GameFontNormal", "ARTWORK")
    tagged:SetJustifyH("RIGHT")
    Look.Pin(tagged, "RIGHT", slot, "RIGHT", -2, 0)
    local mark = Look.OwnTexture(slot, "check", "OVERLAY")
    mark:SetTexture(Q.FILES.check)
    mark:SetSize(16, 16)
    slot:SetHighlightTexture(Q.FILES.plusGlow)
    for script, run in pairs(LINE_SCRIPTS) do slot:SetScript(script, run) end
    NewSeal(slot)
    slot:Hide()
    return slot
end

function Q.MakeRows(list)
    for i = 1, 21 do Q.rows[i] = NewLine(list, Q.rows[i - 1]) end
end

-- The lines from the list bar's place; past the end, or past the lines
-- the layout shows, a line is put away.
local refilling = false
function Q.FillRows()
    if refilling then return end
    refilling = true
    local list, visible, bar = Q.entries, Q.rowsShown or 6, parts.listBar
    Look.ScrollRange(bar, #list - visible, 1)
    local first = Look.Clamp(Q.ListOffset(), 0, math.max(0, #list - visible))
    for i, slot in ipairs(Q.rows) do
        local item = (i <= visible) and list[first + i] or nil
        shows[slot] = item
        if item == nil then
            slot:Hide()
        else
            if item.header then ShowHeader(slot, item) else ShowQuest(slot, item) end
            slot:Show()
            if Look.TipOwner() == slot then HoverIn(slot) end
        end
    end
    refilling = false
end

function Q.ListMoved()
    if Q.window and Q.window:IsShown() then Q.FillRows() end
end

-- The first list line's place in the items now.
function Q.ListOffset()
    return math.floor((Look.Number(parts.listBar:GetValue()) or 0) + 0.5)
end

---------------------------------------------------------------------------
-- The selection, and the refresh
---------------------------------------------------------------------------

local function Lists(list, questID)
    if not questID then return false end
    for _, item in ipairs(list) do
        if item.quest == questID then return true end
    end
    return false
end

local function Choose(list)
    if Lists(list, Q.selected) then return Q.selected end
    local gameOwn = Q.GameSelection()
    if Lists(list, gameOwn) then return gameOwn end
    for _, item in ipairs(list) do
        if item.quest then return item.quest end
    end
    return nil
end

local function FootButtons()
    local chosen = Q.selected
    local some = chosen ~= nil
    parts.abandon:SetEnabled(some)
    parts.track:SetEnabled(some)
    parts.share:SetEnabled(some and Q.InGroup() and Q.Yes(C_QuestLog and C_QuestLog.IsPushableQuest, chosen))
    parts.trackRadio:SetChecked(some and Q.Watched(chosen))
    parts.trackRadio:SetEnabled(some)
    parts.dualRadio:SetChecked(Q.double == true)
end

-- The voice addon's seals changed (its voices loaded, its seals or colours
-- switched): an open log redraws its lines.
local function VoicesChanged()
    if Q.window and Q.window:IsShown() then Q.FillRows() end
end

function Q.Refresh()
    local window = Q.window
    if not (window and window:IsShown()) then return end
    Q.ListenForVoices(VoicesChanged)
    local list = Q.Collect()
    Q.entries = list
    Q.selected = Choose(list)
    local nothing = #list == 0
    Q.FillRows()
    parts.allIcon:SetTexture(Q.AllFolded(list) and Q.FILES.plus or Q.FILES.minus)
    Q.FillCount()
    FootButtons()
    Q.DrawDetail()
    -- Last, as setting a bar's range shows it.
    Look.Shown(parts.empty, nothing)
    for _, piece in ipairs({ parts.detail, parts.listBar, parts.detailBar }) do Look.Shown(piece, not nothing) end
    Look.Shown(parts.allHolder, not nothing and not Q.double)
end
