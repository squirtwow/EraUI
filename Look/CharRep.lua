-- The 1.x reputation detail box (Classic look, "characterSheet"): clicking a
-- faction on the Reputation tab opens a small parchment box just right of
-- the window with the faction's name and description and the At War, Move
-- to Inactive and Show as Experience Bar boxes. Clicking the same faction
-- again closes it. The chosen faction's row wears the old highlight strip.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local C = Look.Char

local RED, PARCHMENT = { 1, 0.1, 0.1 }, { 0.55, 0.47, 0.35 }
local box, chosen        -- the box (made on the first click) and the chosen faction's ID
local checks = {}        -- atWar, inactive, watch: { button, label }
local texts = {}         -- name, description: the box's two texts
local hold               -- the watch box held after a click: { since, wanted }
local marks = Look.Weak() -- reputation bar: EraUI's mark frame on it

local function HideBox()
    if box then box:Hide() end
end

local function Now() return (GetTime and Look.Number(GetTime())) or 0 end

local function After(delay, fn)
    if C_Timer and C_Timer.After then C_Timer.After(delay, fn) else fn() end
end

---------------------------------------------------------------------------
-- Finding the chosen faction
---------------------------------------------------------------------------

local function FactionData(index)
    local fine, data = pcall(C_Reputation.GetFactionDataByIndex, index)
    if fine and type(data) == "table" then return data end
end

-- The chosen faction's current place in the list and its data, or nil
-- (the list's order changes as headers fold and factions go inactive).
local function ChosenIndex()
    if not chosen or not C_Reputation then return nil end
    local fine, total = pcall(C_Reputation.GetNumFactions)
    total = fine and Look.Number(total) or 0
    for place = 1, total do
        local data = FactionData(place)
        if data and not Look.Secret(data.factionID) and data.factionID == chosen then return place, data end
    end
end

local function RowFaction(row)
    local data = C.RowData(row)
    local id = data and data.factionID
    if Look.Secret(id) then return nil end
    return Look.Number(id)
end

---------------------------------------------------------------------------
-- The marks on the chosen row
---------------------------------------------------------------------------

-- One additive piece of the 1.x highlight sheet on the mark.
local function Glow(mark, purpose, size, cut)
    local piece = Look.OwnTexture(mark, purpose, "OVERLAY")
    Look.Art(piece, "repHighlight")
    piece:SetSize(size[1], size[2])
    Look.Crop(piece, cut[1], cut[2], cut[3], cut[4])
    piece:SetBlendMode("ADD")
    return piece
end

-- The chosen row's mark: the highlight strip over the bar's plate, with its
-- end cap, on a frame of EraUI's three above the bar.
local function Mark(bar)
    if marks[bar] then return marks[bar] end
    local mark = Look.Build("Frame", bar, nil, { size = { 1, 1 }, level = (Look.Number(bar:GetFrameLevel()) or 1) + 3 })
    Look.Fill(mark, bar)
    local strip = Glow(mark, "strip", { 256, 27 }, { 0, 1, 0, 27 / 64 })
    local plate = Look.OwnPiece(bar, "plate")
    Look.Pin(strip, "TOPLEFT", plate or bar, "TOPLEFT", plate and -2 or -128, plate and 3 or 7)
    Look.Pin(Glow(mark, "cap", { 16, 32 }, { 0, 0.0625, 0.4375, 0.9375 }), "TOPLEFT", strip, "TOPRIGHT", 0, 0)
    marks[bar] = mark
    return mark
end

local function HideMarks()
    for _, mark in pairs(marks) do mark:Hide() end
end

function C.MarkChosenRow()
    local list = ReputationFrame
    if not (box and box:IsShown() and list) then return HideMarks() end
    C.EachRow(list.ScrollBox, function(row)
        local bar = row.Content and row.Content.ReputationBar
        if not bar then return end
        local mine = RowFaction(row) == chosen
        if mine then Mark(bar):Show() elseif marks[bar] then marks[bar]:Hide() end
    end)
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------

local function Paint(which, enabled, colour)
    local check = checks[which]
    check.button:SetEnabled(enabled and true or false)
    local tint = enabled and colour or C.GREY
    check.label:SetTextColor(tint[1], tint[2], tint[3])
end

function C.RefreshRepBox()
    local index, data = ChosenIndex()
    if not index then return HideBox() end
    texts.name:SetText(data.name or "")
    texts.description:SetText(data.description or "")
    local atWar = data.canToggleAtWar == true and data.isHeader ~= true
    checks.atWar.button:SetChecked(data.atWarWith == true)
    Paint("atWar", atWar, RED)
    local fine, active = pcall(C_Reputation.IsFactionActive, index)
    checks.inactive.button:SetChecked(fine and active == false)
    Paint("inactive", data.canSetInactive == true, C.GOLD)
    checks.watch.button:SetChecked(data.isWatched == true)
    if not hold then Paint("watch", true, C.GOLD) end
end

local function RefreshSoon(delay)
    After(delay, function() if box and box:IsShown() then C.RefreshRepBox() end end)
end

---------------------------------------------------------------------------
-- Clicks
---------------------------------------------------------------------------

-- A box ticked or unticked: its sound, and where the chosen faction is now.
local function Ticked(button)
    if PlaySound and SOUNDKIT then
        local sound = button:GetChecked() and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF"
        PlaySound(SOUNDKIT[sound])
    end
    return ChosenIndex()
end

local function AtWarClicked(button)
    local index = Ticked(button)
    if index then Look.Try(C_Reputation.ToggleFactionAtWar, index) end
    RefreshSoon(1)
end

local function InactiveClicked(button)
    local index = Ticked(button)
    if index then Look.Try(C_Reputation.SetFactionActive, index, not button:GetChecked()) end
    RefreshSoon(1)
end

-- The watch box waits for the XP strips to follow before it can be clicked
-- again: 3 s at most, or as soon as 0.1 s has passed and they agree.
local function ReleaseWatch()
    if not hold then return end
    hold = nil
    Paint("watch", true, C.GOLD)
    C.RefreshRepBox()
end

local function StripsAgree(wanted)
    local shows = type(ns.StatusBarsShowFaction) ~= "function" or ns.StatusBarsShowFaction() == wanted
    local busy = type(ns.StatusBarsBusy) == "function" and ns.StatusBarsBusy() == true
    return shows and not busy
end

local function WatchClicked(button)
    local index = Ticked(button)
    local wanted = button:GetChecked() and true or false
    if index then Look.Try(C_Reputation.SetWatchedFactionByIndex, wanted and index or 0) end
    hold = { since = Now(), wanted = wanted }
    Paint("watch", false, C.GOLD)
    RefreshSoon(1)
end

local function HoldTick()
    if not hold then return end
    local waited = Now() - hold.since
    if waited > 3 or (waited > 0.1 and StripsAgree(hold.wanted)) then ReleaseWatch() end
end

---------------------------------------------------------------------------
-- The box
---------------------------------------------------------------------------

local function DialogBox(owner, level)
    local frame = Look.Build("Frame", owner, "BackdropTemplate", { size = { 212, 146 }, level = level })
    frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 } })
    frame:SetBackdropColor(0, 0, 0, 1)
    if ns.DarkBackdrop then ns.DarkBackdrop(frame, { 0, 0, 0, 1 }) end
    return frame
end

local function CheckBox(content, which, words, colour, onClick)
    local button = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    button:SetSize(24, 24)
    Look.SkinCheckBox(button)
    local label = button.Text
    if not label then
        label = Look.OwnLabel(button, "label", "GameFontNormalSmall", "ARTWORK")
        Look.Pin(label, "LEFT", button, "RIGHT", 0, 1)
    end
    label:SetFontObject(GameFontNormalSmall)
    label:SetText(words)
    label:SetTextColor(colour[1], colour[2], colour[3])
    local wide = Look.Number(label:GetStringWidth())
    button:SetHitRectInsets(0, -(wide and math.min(120, wide) or 60), 0, 0)
    button:SetScript("OnClick", onClick)
    checks[which] = { button = button, label = label }
    return button
end

-- The box's two texts: the faction's name, and its description under it.
local function MakeTexts(content)
    texts.name = Look.OwnLabel(content, "name", "GameFontNormal")
    texts.description = Look.OwnLabel(content, "description", "GameFontHighlightSmall")
    texts.name:SetWidth(150)
    texts.description:SetSize(172, 96)
    texts.description:SetJustifyV("TOP")
    for _, text in pairs(texts) do text:SetJustifyH("LEFT") end
    Look.Pin(texts.name, "TOPLEFT", box, "TOPLEFT", 20, -21)
    Look.Pin(texts.description, "TOPLEFT", texts.name, "BOTTOMLEFT", 0, -2)
end

local function BoxHidden()
    ReleaseWatch()
    HideMarks()
end

local function MakeBox()
    local sheet = CharacterFrame
    box = Look.Build("Frame", sheet, nil, { name = "EraUIClassicReputationDetail", size = { 212, 203 },
        level = (Look.Number(sheet:GetFrameLevel()) or 1) + 30, mouse = true, hidden = true })
    local level = Look.Number(box:GetFrameLevel()) or 1
    -- Two dialog boxes, the lower one over the upper's foot by 12.
    local upper = DialogBox(box, level)
    upper:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    upper:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", 0, -146)
    local lower = DialogBox(box, level + 1)
    Look.Inside(lower, box, 0, 134, 0, 0)
    local parchment = Look.OwnTexture(upper, "parchment", "BORDER")
    parchment:SetTexture("Interface\\QuestFrame\\QuestBG")
    Look.Crop(parchment, 0, 0.58, 0, 0.3)
    Look.Tint(parchment, PARCHMENT)
    Look.Inside(parchment, upper, 10, 10, 10, 10)
    local content = Look.Build("Frame", box, nil, { size = { 212, 203 }, level = level + 5 })
    Look.Fill(content, box)
    MakeTexts(content)
    local close = Look.Build("Button", content, nil, { size = { 32, 32 } })
    Look.Pin(close, "TOPRIGHT", box, "TOPRIGHT", -3, -3)
    Look.SkinCloseButton(close)
    close:SetScript("OnClick", HideBox)
    local atWar = CheckBox(content, "atWar", C.Text("AT_WAR", "At War"), RED, AtWarClicked)
    Look.Pin(atWar, "TOPLEFT", box, "TOPLEFT", 14, -143)
    local inactive = CheckBox(content, "inactive", C.Text("MOVE_TO_INACTIVE", "Move to Inactive"), C.GOLD, InactiveClicked)
    Look.Pin(inactive, "LEFT", atWar, "RIGHT", 52, 0)
    local watch = CheckBox(content, "watch", C.Text("SHOW_FACTION_ON_MAINSCREEN", "Show as Experience Bar"), C.GOLD, WatchClicked)
    Look.Pin(watch, "TOPLEFT", atWar, "BOTTOMLEFT", 0, 0)
    box:SetScript("OnHide", BoxHidden)
    local waited = 0
    box:SetScript("OnUpdate", function(_, elapsed)
        HoldTick()
        waited = waited + (elapsed or 0)
        if waited < 0.2 then return end
        waited = 0
        if not (ReputationFrame and ReputationFrame:IsVisible()) then return box:Hide() end
        Look.Try(C.MarkChosenRow)
    end)
    Look.Listen(box, "UPDATE_FACTION")
    box:SetScript("OnEvent", function() RefreshSoon(0) end)
end

-- A click on a faction's row (the game's own click has run first).
function C.RepRowClicked(row)
    if not C.active then return end
    local id = RowFaction(row)
    if not id or id <= 0 then return end
    if not box then MakeBox() end
    if box:IsShown() and id == chosen then
        box:Hide()
        return
    end
    chosen = id
    Look.Pin(box, "TOPLEFT", CharacterFrame, "TOPLEFT", C.ART_RIGHT, -48)
    box:Show()
    C.RefreshRepBox()
    Look.Try(C.MarkChosenRow)
    After(0, function() Look.Try(C.MarkChosenRow) end)
    After(0.1, function() Look.Try(C.MarkChosenRow) end)
end

C.HideRepBox = HideBox
C.DialogBox = DialogBox -- the currency box's too (Look/CharCurrency.lua)

-- What the tests read.
function C.RepBox()
    return box, checks, chosen, texts
end
