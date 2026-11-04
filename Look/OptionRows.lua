-- The rows of the old Classic options page (Look/OptionPage.lua builds the
-- page): a 1.x check box per option, and the One bag columns stepper under
-- One bag. Their hover shows the row's name, the reason it is greyed (the
-- nameplate hand-over's note) and its description in EraUI's own tooltip
-- box (the game's tooltip is never written to).
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local O = {}
Look.Options = O

O.ROW = 24
O.pages = Look.Weak() -- the window or settings canvas: its page record
O.tips = Look.Weak()  -- a row or button: a function giving its tooltip lines

-- The note a nameplate row shows while Forever Enhanced Nameplates handles
-- the plates.
O.PLATE_NOTE = "Forever Enhanced Nameplates is on and handles nameplates, so EraUI leaves them alone."
O.PLATE_KEYS = { namePlates = true, fullPlates = true, classColorPlates = true }

-- The lines a frame's hover shows (tests read them through here).
function O.TipRows(frame)
    local make = frame and O.tips[frame]
    if type(make) ~= "function" then return nil end
    local fine, rows = pcall(make)
    return fine and rows or nil
end

local function Hover(frame)
    local rows = O.TipRows(frame)
    if rows and #rows > 0 then Look.ShowTip(frame, "RIGHT", rows) end
end

local function Leave(frame)
    Look.HideTip(frame)
end

-- A frame of EraUI's own with a tooltip: name (white), a reason (gold) when
-- there is one, the description.
function O.GiveTip(frame, lines)
    O.tips[frame] = lines
    frame:SetScript("OnEnter", Hover)
    frame:SetScript("OnLeave", Leave)
end

local function RowTip(row)
    return function()
        local rows = { { row.label, 1, 1, 1 } }
        if row.note then rows[#rows + 1] = { row.note, 1, 0.82, 0, 280 } end
        if row.description and row.description ~= "" then rows[#rows + 1] = { row.description, 1, 0.82, 0, 280 } end
        return rows
    end
end

---------------------------------------------------------------------------
-- Check box rows
---------------------------------------------------------------------------

local CHECK_ART = { { "Normal", "Up" }, { "Pushed", "Down" }, { "Highlight", "Highlight" }, { "Checked", "Check" },
    { "DisabledChecked", "Check-Disabled" } }

-- A 1.x check box (24 x 24) with its label at its right. A click sets the
-- key to the box's state, tells the engine (ToggleChanged) and refreshes
-- the page.
function O.CheckRow(page, entry, child, labelWidth)
    local box = Look.Build("CheckButton", page.child, nil, { size = { 24, 24 } })
    box:SetPoint("TOPLEFT", page.child, "TOPLEFT", 0, 0)
    for _, art in ipairs(CHECK_ART) do
        local give = box["Set" .. art[1] .. "Texture"]
        if type(give) == "function" then give(box, "Interface\\Buttons\\UI-CheckBox-" .. art[2]) end
    end
    local glow = box.GetHighlightTexture and box:GetHighlightTexture()
    if glow then glow:SetBlendMode("ADD") end
    local label = Look.OwnLabel(box, "label", "GameFontHighlight", "ARTWORK")
    Look.Pin(label, "LEFT", box, "RIGHT", 2, 1)
    label:SetWidth(labelWidth)
    label:SetJustifyH("LEFT")
    if label.SetWordWrap then label:SetWordWrap(false) end
    label:SetText(entry[2])
    local row = { key = entry[1], label = entry[2], description = entry[3], parent = entry[4], child = child,
        frame = box, text = label, kind = "check" }
    box:SetScript("OnClick", function(self)
        local saved = ns.db
        if not saved then return end
        saved[row.key] = self:GetChecked() and true or false
        if type(ns.ToggleChanged) == "function" then ns.ToggleChanged(row.key) end
        O.Refresh(page.frame)
    end)
    O.GiveTip(box, RowTip(row))
    return row
end

---------------------------------------------------------------------------
-- The One bag columns stepper
---------------------------------------------------------------------------

local function Limits()
    local low, high = Look.Number(ns.ONE_BAG_COLUMNS_MIN), Look.Number(ns.ONE_BAG_COLUMNS_MAX)
    return low or 4, high or 16
end

function O.StepperValue()
    local low = Limits()
    local saved = ns.db
    return saved and Look.Number(saved.oneBagColumns) or low
end

local function StepButton(holder, way)
    local button = Look.Build("Button", holder, nil, { size = { 16, 16 } })
    local base = "Interface\\Buttons\\UI-" .. way .. "Button-"
    button:SetNormalTexture(base .. "Up")
    button:SetPushedTexture(base .. "Down")
    button:SetDisabledTexture(base .. "Disabled")
    button:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
    local glow = button.GetHighlightTexture and button:GetHighlightTexture()
    if glow then glow:SetBlendMode("ADD") end
    return button
end

-- The stepper's enabled state and number follow the saved value.
function O.SyncStepper(stepper)
    local low, high = Limits()
    local value = O.StepperValue()
    stepper.value:SetText(tostring(value))
    stepper.minus:SetEnabled(stepper.enabled ~= false and value > low)
    stepper.plus:SetEnabled(stepper.enabled ~= false and value < high)
end

function O.StepperRow(page, labelWidth)
    local holder = Look.Build("Frame", page.child, nil, { size = { 24, 24 } })
    holder:SetPoint("TOPLEFT", page.child, "TOPLEFT", 0, 0)
    local minus, plus = StepButton(holder, "Minus"), StepButton(holder, "Plus")
    local number = Look.OwnLabel(holder, "value", "GameFontHighlight", "ARTWORK")
    local caption = Look.OwnLabel(holder, "label", "GameFontHighlight", "ARTWORK")
    local stepper = { key = "oneBagColumns", label = "One bag columns", parent = "oneBag", child = true, frame = holder,
        kind = "stepper", minus = minus, plus = plus, value = number, text = caption,
        description = "How many slots across the One bag window is. The old bags were four across; more makes the window wider and shorter." }
    Look.Pin(minus, "LEFT", holder, "LEFT", 4, 0)
    number:SetWidth(20)
    number:SetJustifyH("CENTER")
    Look.Pin(number, "LEFT", minus, "RIGHT", 2, 0)
    Look.Pin(plus, "LEFT", holder, "LEFT", 42, 0)
    Look.Pin(caption, "LEFT", plus, "RIGHT", 4, 1)
    caption:SetWidth(labelWidth)
    caption:SetJustifyH("LEFT")
    caption:SetText(stepper.label)
    local function Step(way)
        local low, high = Limits()
        local wanted = Look.Clamp(O.StepperValue() + way, low, high)
        if type(ns.SetOneBagColumns) == "function" then ns.SetOneBagColumns(wanted) end
        O.SyncStepper(stepper)
    end
    minus:SetScript("OnClick", function() Step(-1) end)
    plus:SetScript("OnClick", function() Step(1) end)
    for _, frame in ipairs({ holder, minus, plus }) do O.GiveTip(frame, RowTip(stepper)) end
    O.SyncStepper(stepper)
    return stepper
end

-- The rows of a page, in the option list's order (the stepper right after
-- One bag, while the bags code offers it).
function O.MakeRows(page)
    local column = page.columnWidth
    for _, entry in ipairs(type(ns.TOGGLES) == "table" and ns.TOGGLES or {}) do
        local child = entry[4] ~= nil
        local row = O.CheckRow(page, entry, child, column - 30 - (child and 22 or 0))
        page.rows[#page.rows + 1] = row
        page.byKey[row.key] = row
        if row.key == "oneBag" and type(ns.SetOneBagColumns) == "function" then
            local stepper = O.StepperRow(page, column - 70 - 22)
            page.rows[#page.rows + 1] = stepper
            page.byKey[stepper.key] = stepper
        end
    end
end
