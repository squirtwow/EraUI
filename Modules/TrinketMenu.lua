local _, E = ...

-- The quick menu that opens on a right-click of a Trinket Bar slot
-- (Modules/TrinketBar.lua): the bar's own options where the bar is, so you
-- can change it without opening /era. Six ticks, Icon Size, Unlock to move,
-- Trinket sets (your saved sets, in /era) and All settings, which opens /era
-- at Action Bars > Trinkets.
--
-- It is EraUI's own plain frame on UIParent, never a child of a slot, so
-- making it, showing it, filling it and hiding it are ordinary code. A
-- screen-wide button under it closes it on a click anywhere else, and its
-- name is in the game's own Escape list, so Escape closes it too; both end
-- in the frame's OnHide, which is the one place it tidies up. The bar
-- refuses to open it in a fight, the way it refuses the drag.
--
-- Changing a row here is the same change /era makes: the setting is saved,
-- the bar is told at once, and the matching row in the options window
-- follows if that window is open, so the two never disagree.
local Me = {}
E.TrinketMenu = Me

Me.WINDOW_NAME = "EraUITrinketMenu"

local WIDTH, PAD, ROW_H, TITLE_H = 184, 7, 19, 18
local LABEL_H, SLIDER_H, SLIDER_GAP = 15, 12, 4
local SIZE_MIN, SIZE_MAX, SIZE_STEP, SIZE_DEFAULT = 24, 56, 2, 36

local function K() return E.TrinketKit end
local function Bar() return E.modules and E.modules.TrinketBar end

-- The ticks, in the order /era has them, with the default each one starts at.
local TICKS = {
    { key = "trinketBarBoth", label = "Show Both Slots", default = true },
    { key = "trinketBarRings", label = "Show Your Rings", default = false },
    { key = "trinketBarGlow", label = "Ready Glow", default = true },
    { key = "trinketBarTime", label = "Time Left on Icon", default = true },
    { key = "trinketBarTwoRows", label = "Two Rows", default = false },
    { key = "trinketBarColumn", label = "Up and Down", default = false },
}

local frame, catcher, box, title, slider, sizeLabel
local ticks, actions = {}, {}
local syncing = false

local function On(tick)
    local value = E:GetSetting(tick.key)
    if value == nil then return tick.default end
    return value == true
end

local function Size() return K().Setting("trinketBarSize", SIZE_MIN, SIZE_MAX, SIZE_DEFAULT) end

---------------------------------------------------------------------------
-- Saving a change
---------------------------------------------------------------------------

-- The same row in /era, while that window is open: it re-reads what was
-- just saved, so the menu and the options window always show the same thing.
-- Through pcall: the options window is not the menu's business, and a row
-- that has gone or changed its ways must not spoil a click on the bar.
local function Window(key)
    local window = E.settingsFrame
    local row = window and window.checks and window.checks[key]
    if not (row and row.SetChecked) then return end
    if row.rowKind == "tick" then pcall(row.SetChecked, row, E:GetSetting(key) == true)
    else pcall(row.SetChecked, row) end
end

-- A change made here: saved, the bar told at once, the menu and /era redrawn.
local function Save(key, value)
    E:SetSetting(key, value)
    if E.SaveSettings then E:SaveSettings() end
    local bar = Bar()
    if bar then bar:Refresh() end
    Window(key)
    Me.Refresh()
end

---------------------------------------------------------------------------
-- The rows
---------------------------------------------------------------------------

local function Shade(row)
    local kit = K()
    row.shade = row:CreateTexture(nil, "HIGHLIGHT")
    row.shade:SetTexture(kit.FILL)
    row.shade:SetVertexColor(1, .82, .3, .14)
    row.shade:SetAllPoints(row)
end

local function TickClick(row)
    Save(row.tick.key, not On(row.tick))
end

local function TickRow(index, tick, y)
    local kit = K()
    local row = CreateFrame("Button", nil, frame)
    row.tick = tick
    row:SetSize(WIDTH - PAD * 2, ROW_H)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    Shade(row)
    row.box, row.fill, row.mark = kit.TickBox(row)
    row.box:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.label = kit.Text(row, 11, "ARTWORK")
    row.label:SetPoint("LEFT", row.box, "RIGHT", 6, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.label:SetWordWrap(false)
    row.label:SetText(tick.label)
    row:SetScript("OnClick", TickClick)
    ticks[index] = row
    return row
end

local function ActionRow(index, label, y, click)
    local kit = K()
    local row = CreateFrame("Button", nil, frame)
    row:SetSize(WIDTH - PAD * 2, ROW_H)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    Shade(row)
    row.label = kit.Text(row, 11, "ARTWORK")
    row.label:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.label:SetWordWrap(false)
    row.label:SetText(label)
    row:SetScript("OnClick", click)
    actions[index] = row
    return row
end

-- Unlock to move: the menu goes first, so it is not sitting over the bar
-- you are about to drag. The bar's gold box and its hint say the rest.
local function Unlock()
    local bar = Bar()
    Me.Close()
    if bar then bar:SetUnlocked(true) end
end

-- /era, open at one of the Trinket Bar's own rows: All settings at the
-- switch, Trinket sets at the Your Sets heading with your saved sets under it
-- (Modules/TrinketSetList.lua). Showing the window and jumping to a row
-- change nothing the game protects.
local function Jump(key)
    Me.Close()
    local settings = E.modules and E.modules.Settings
    if not (settings and settings.ShowSettings) then return end
    settings:ShowSettings()
    local window = E.settingsFrame
    if window and window.JumpTo then window:JumpTo(key) end
end
local function TrinketSets() Jump("trinketBarSets") end
local function AllSettings() Jump("trinketBar") end

---------------------------------------------------------------------------
-- The frame
---------------------------------------------------------------------------

-- Made once, sized as it is made: Forever may never draw a frame laid out
-- under one without a size.
local function Build()
    if frame then return end
    local kit = K()
    -- Under the menu, across the whole screen: a click anywhere else closes
    -- it. FULLSCREEN sits under the menu's own FULLSCREEN_DIALOG, so the
    -- menu's own rows are clicked, not this.
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN")
    catcher:EnableMouse(true)
    catcher:RegisterForClicks("AnyUp")
    catcher:SetScript("OnClick", function() Me.Close() end)
    catcher:Hide()
    frame = CreateFrame("Frame", Me.WINDOW_NAME, UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    local y = PAD
    frame:SetSize(WIDTH, PAD * 2 + TITLE_H + #TICKS * ROW_H + LABEL_H + SLIDER_H + SLIDER_GAP + ROW_H * 3)
    box = kit.Box(frame)
    title = kit.Text(frame, 12)
    title:SetText("Trinket Bar")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    y = y + TITLE_H
    for index, tick in ipairs(TICKS) do
        TickRow(index, tick, y)
        y = y + ROW_H
    end
    sizeLabel = kit.Text(frame, 11)
    sizeLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 2, -y)
    y = y + LABEL_H
    slider = kit.Slider(frame, SIZE_MIN, SIZE_MAX, SIZE_STEP)
    slider:SetWidth(WIDTH - PAD * 2 - 4)
    slider:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 2, -y)
    slider:SetScript("OnValueChanged", function(_, value)
        if syncing then return end
        value = tonumber(value)
        if not value or value ~= value or math.abs(value) == math.huge then return end
        value = math.max(SIZE_MIN, math.min(SIZE_MAX, math.floor(value / SIZE_STEP + .5) * SIZE_STEP))
        if value == Size() then return end
        Save("trinketBarSize", value)
    end)
    y = y + SLIDER_H + SLIDER_GAP
    ActionRow(1, "Unlock to move", y, Unlock)
    y = y + ROW_H
    ActionRow(2, "Trinket sets", y, TrinketSets)
    y = y + ROW_H
    ActionRow(3, "All settings", y, AllSettings)
    -- Escape, through the game's own list: it hides the named frame, and
    -- OnHide below does the tidying up for every way of closing.
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, Me.WINDOW_NAME) end
    frame:SetScript("OnHide", function()
        Me.anchor = nil
        if catcher then catcher:Hide() end
    end)
    Me.frame = frame
end

function Me.Paint()
    if not frame then return end
    local kit = K()
    local look = kit.Look()
    kit.Paint(box)
    title:SetTextColor(look.word[1], look.word[2], look.word[3])
    sizeLabel:SetTextColor(look.word[1], look.word[2], look.word[3])
    for _, row in ipairs(ticks) do row.label:SetTextColor(look.word[1], look.word[2], look.word[3]) end
    for _, row in ipairs(actions) do row.label:SetTextColor(kit.GOLD[1], kit.GOLD[2], kit.GOLD[3]) end
end

-- Every row as the options now have it.
function Me.Refresh()
    if not frame then return end
    for _, row in ipairs(ticks) do row.mark:SetShown(On(row.tick)) end
    local size = Size()
    sizeLabel:SetText("Icon Size: " .. size .. " px")
    syncing = true
    slider:SetValue(size)
    syncing = false
end

---------------------------------------------------------------------------
-- Opening and closing
---------------------------------------------------------------------------

-- Under the slot, or over it when there is no room below (a bar near the
-- bottom of the screen). An unreadable spot leaves it under.
local function Place(anchor)
    local kit = K()
    local bottom, height = anchor:GetBottom(), frame:GetHeight()
    local above = kit.Num(bottom) and kit.Num(height) and bottom < height + 10
    frame:ClearAllPoints()
    if above then frame:SetPoint("BOTTOM", anchor, "TOP", 0, 6)
    else frame:SetPoint("TOP", anchor, "BOTTOM", 0, -6) end
end

function Me.Shown() return frame ~= nil and frame:IsShown() end

function Me.Open(anchor)
    if not (K() and anchor) then return false end
    Build()
    Me.anchor = anchor
    Me.Paint()
    Me.Refresh()
    Place(anchor)
    catcher:Show()
    frame:Show()
    return true
end

function Me.Close()
    if frame then frame:Hide() end
end

function Me.Toggle(anchor)
    if Me.Shown() and Me.anchor == anchor then Me.Close(); return false end
    return Me.Open(anchor)
end
