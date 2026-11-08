local _, E = ...

-- /era's rows: one slim line per option. Core/Settings.lua makes them and
-- keeps what each one does; Core/SettingsNav.lua puts them on their pages.
-- A row is EraUI's own frame inside the settings window: a square tick box
-- (dark, with an inner square in your class colour when on), its name and,
-- right after the name, a small plain word or two ("just added",
-- "experimental", "coming soon"). A
-- click anywhere on a tick row flips it. Hovering a row, or reaching it with
-- Tab, shows its description in the window's footer: rows never use the
-- game's tooltip. Every function here takes the row (or the window) as an
-- argument, so no function holds more than a few values from outside.
local Rows = {}
E.SettingsRows = Rows

local WIDTH, WIDE, HEIGHT, NOTE_HEIGHT = 352, 718, 32, 46
Rows.WIDTH, Rows.WIDE, Rows.HEIGHT, Rows.NOTE_HEIGHT = WIDTH, WIDE, HEIGHT, NOTE_HEIGHT
Rows.INDENT, Rows.GAP, Rows.COLUMN, Rows.RESULT_HEIGHT, Rows.MORE_HEIGHT = 22, 4, 366, 40, 56
Rows.GREYED = .45
local WHITE = "Interface\\Buttons\\WHITE8X8"
local BACKDROP = {bgFile = WHITE, edgeFile = WHITE, edgeSize = 1}
Rows.BACKDROP = BACKDROP
local FILL, EDGE = {.071, .082, .102}, {.106, .122, .149}
local HOVER_FILL, HOVER_EDGE = {.098, .114, .141}, {.169, .192, .231}
Rows.FILL, Rows.EDGE, Rows.HOVER_FILL, Rows.HOVER_EDGE = FILL, EDGE, HOVER_FILL, HOVER_EDGE
local TICK_EDGE, TICK_FILL = {.30, .32, .36}, {.059, .063, .075}
Rows.TICK_EDGE, Rows.TICK_FILL = TICK_EDGE, TICK_FILL
local CONNECTOR = {.23, .25, .29}
Rows.CONNECTOR = CONNECTOR
Rows.GOLD = {.93, .75, .32}
Rows.CRUMB = {.44, .48, .53}

-- The small words right after a row's name: plain lower-case text, a size
-- smaller, no box and no border. "just added" is in the game's own gold;
-- "experimental" (not seen working in game yet) a muted warm grey; "coming
-- soon" and "log out to apply" the muted grey of the row's other notes.
local TAGS = {
    NEW = {"just added", {1, .82, 0}},
    TEST = {"experimental", {.66, .61, .53}},
    SOON = {"coming soon", {.58, .62, .68}},
    LOGOUT = {"log out to apply", {.58, .62, .68}},
}
Rows.TAGS = TAGS
local TAG_SIZE, TAG_GAP = 10, 5
Rows.TAG_SIZE, Rows.TAG_GAP = TAG_SIZE, TAG_GAP

-- Your class colour; grey when the class can't be read (a secret value is
-- never used as a key) or has no colour.
local function ClassColour()
    local _, class = UnitClass("player")
    if issecretvalue and issecretvalue(class) then return .7, .7, .7 end
    local colour = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if colour then return colour.r, colour.g, colour.b end
    return .7, .7, .7
end
Rows.ClassColour = ClassColour

local function Text(parent, value, size, muted)
    local text = parent:CreateFontString(nil, "OVERLAY")
    local font, _, flags = GameFontHighlight:GetFont()
    text:SetFont(font, size, flags or "")
    text:SetTextColor(muted and .58 or .94, muted and .62 or .95, muted and .68 or .98)
    text:SetJustifyH("LEFT")
    text:SetText(value or "")
    return text
end
Rows.Text = Text

-- Draws text in a font, falling back to the normal one if it can't load.
local function UseFont(text, font, size)
    local ok = font and font.file and text:SetFont(font.file, size, "OUTLINE")
    if ok == false or not (font and font.file) then text:SetFont(select(1, GameFontHighlight:GetFont()), size, "OUTLINE") end
end
Rows.UseFont = UseFont

-- A row's fill and edge: lighter while hovered, your class colour while it
-- flashes (after search took you to it) or has the keyboard.
function Rows.Paint(row)
    local fill = row.hovered and HOVER_FILL or FILL
    row:SetBackdropColor(fill[1], fill[2], fill[3], 1)
    if row.flashing or row.focused then
        local r, g, b = ClassColour()
        row:SetBackdropBorderColor(r, g, b, 1)
    else
        local edge = row.hovered and HOVER_EDGE or EDGE
        row:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
    end
end

local function Enter(row)
    row.hovered = true
    Rows.Paint(row)
    local frame = row.owner
    if frame and frame.ShowRowHelp then frame:ShowRowHelp(row.target or row) end
end
local function Leave(row)
    row.hovered = false
    Rows.Paint(row)
    local frame = row.owner
    if frame and frame.ShowRowHelp then frame:ShowRowHelp(frame.focusedRow) end
end
Rows.Enter, Rows.Leave = Enter, Leave

-- A control inside a row (a slider, a button) shows the row's description too.
function Rows.Forward(row, child)
    child:HookScript("OnEnter", function() Enter(row) end)
    child:HookScript("OnLeave", function() Leave(row) end)
end

function Rows.Button(parent, label, width, height, strong)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetBackdrop(BACKDROP)
    button.label = Text(button, label, 13)
    button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
    button:SetSize(width or math.max(80, math.floor(button.label:GetStringWidth() + 28.5)), height or 24)
    local r, g, b = ClassColour()
    if strong then
        button:SetBackdropColor(r * .22, g * .22, b * .22, 1)
        button:SetBackdropBorderColor(r, g, b, 1)
    else
        button:SetBackdropColor(.06, .07, .085, 1)
        button:SetBackdropBorderColor(.25, .27, .3, 1)
    end
    return button
end

-- The frame every row starts from. kind says what it holds; frameType is
-- "Button" for rows a click acts on, "Frame" for rows whose controls do.
function Rows.Base(frame, key, kind, label, frameType)
    local row = CreateFrame(frameType or "Button", nil, frame.settingsContent or frame, "BackdropTemplate")
    row:SetSize(WIDTH, HEIGHT)
    row:SetBackdrop(BACKDROP)
    row.owner, row.settingKey, row.rowKind, row.labelText = frame, key, kind, label
    row.baseHeight, row.textLeft = HEIGHT, kind == "tick" and 34 or 12
    row.text = Text(row, label, 13)
    row.text:SetWordWrap(false)
    row.text:SetPoint("LEFT", row, "LEFT", row.textLeft, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    Rows.TagBox(row)
    -- The thin line from a sub-option up to the option it sits under.
    local r, g, b = CONNECTOR[1], CONNECTOR[2], CONNECTOR[3]
    row.connV = row:CreateTexture(nil, "BACKGROUND")
    row.connV:SetColorTexture(r, g, b, 1)
    row.connV:SetWidth(1)
    row.connV:SetPoint("TOP", row, "TOPLEFT", -14, Rows.GAP)
    row.connV:SetPoint("BOTTOM", row, "LEFT", -14, 0)
    row.connH = row:CreateTexture(nil, "BACKGROUND")
    row.connH:SetColorTexture(r, g, b, 1)
    row.connH:SetSize(10, 1)
    row.connH:SetPoint("LEFT", row, "LEFT", -14, 0)
    row.connV:Hide(); row.connH:Hide()
    -- A second, muted line (a handed-over option says what handles it now),
    -- from under the tick box to the row's right end, so the longest note fits.
    row.note = Text(row, "", 11, true)
    row.note:SetWordWrap(false)
    row.note:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 10 - row.textLeft, -3)
    row.note:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.note:Hide()
    if frameType == "Frame" then row:EnableMouse(true) end
    row:SetScript("OnEnter", Enter)
    row:SetScript("OnLeave", Leave)
    Rows.Paint(row)
    if frame.checks and key then frame.checks[key] = row end
    return row
end

-- Tick rows ------------------------------------------------------------------

function Rows.PaintTick(row)
    local on = row.checked and not row.unavailable
    row.tickMark:SetColorTexture(ClassColour())
    row.tickMark:SetShown(on and true or false)
end
local function SetTickChecked(row, value)
    row.checked = value and true or false
    Rows.PaintTick(row)
end
local function GetTickChecked(row)
    return row.checked
end
-- The tick flips before the row's own click handler reads it, so a mouse
-- click anywhere on the row and the keyboard (row:Click()) do the same. A
-- greyed, handed-over or Coming soon row keeps its tick.
local function TickPreClick(row)
    if row.unavailable or row.dependencyDisabled or row.handedOver then return end
    row:SetChecked(not row:GetChecked())
end

-- The square tick box itself: 14 x 14, a grey edge round a dark fill, and an
-- 8 x 8 inner square in your class colour (shown by the caller when on). The
-- class tools' options under a row use it too (Modules/ClassTools.lua).
function Rows.TickBox(owner, x)
    local box = owner:CreateTexture(nil, "ARTWORK")
    box:SetSize(14, 14)
    box:SetPoint("LEFT", owner, "LEFT", x or 10, 0)
    box:SetColorTexture(TICK_EDGE[1], TICK_EDGE[2], TICK_EDGE[3], 1)
    local fill = owner:CreateTexture(nil, "ARTWORK", nil, 1)
    fill:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
    fill:SetColorTexture(TICK_FILL[1], TICK_FILL[2], TICK_FILL[3], 1)
    local mark = owner:CreateTexture(nil, "OVERLAY")
    mark:SetSize(8, 8)
    mark:SetPoint("CENTER", box, "CENTER", 0, 0)
    mark:SetColorTexture(ClassColour())
    mark:Hide()
    return box, fill, mark
end

function Rows.Tick(frame, key, label, summary, unavailable)
    local row = Rows.Base(frame, key, "tick", label, "Button")
    row.summary = summary
    row.searchText = string.lower(label .. " " .. (summary or "") .. " " .. key)
    row.tickBox, row.tickFill, row.tickMark = Rows.TickBox(row, 10)
    row.unavailable = unavailable == true
    row.SetChecked, row.GetChecked = SetTickChecked, GetTickChecked
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("PreClick", TickPreClick)
    if row.unavailable then row.text:SetTextColor(.58, .62, .68) end
    row:SetChecked(false)
    return row
end

-- Greyed: an option waiting on another one (or handed over) fades out and
-- takes no clicks; it still shows its description on hover.
function Rows.SetGreyed(row, greyed)
    row.greyed = greyed and true or false
    row:SetAlpha(greyed and Rows.GREYED or 1)
end

function Rows.SetNote(row, text)
    local shown = text ~= nil and text ~= ""
    row.note:SetText(text or "")
    row.note:SetShown(shown)
    row.text:SetPoint("LEFT", row, "LEFT", row.textLeft, shown and 7 or 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -10, shown and 7 or 0)
    -- The tick box stays on the name's line, clear of the note (the words
    -- after the name go with it).
    if row.tickBox then row.tickBox:SetPoint("LEFT", row, "LEFT", 10, shown and 7 or 0) end
    row:SetHeight(shown and NOTE_HEIGHT or row.baseHeight)
    local frame = row.owner
    if frame and frame.QueueSettingsLayout then frame:QueueSettingsLayout() end
end

-- The holder of a row's words: right after the name's text (or after
-- row.tagAfter, the damage font's button), on the name's line.
function Rows.TagBox(row)
    row.tagBox = CreateFrame("Frame", nil, row)
    row.tagBox:SetSize(1, 14)
    row.tags, row.tagIds, row.tagKey = {}, {}, ""
    Rows.PlaceTags(row)
    return row.tagBox
end
-- A slider row's name line at its widest value ("Travel Distance: 600 px"),
-- so its words and its slider stay put while you drag.
local function WidestName(row)
    local info, text = row.info, row.text
    local now, widest = text:GetText(), 0
    for _, value in ipairs({info.low, info.high}) do
        text:SetText(row.labelText .. ": " .. (info.format and info.format(value) or tostring(value)))
        widest = math.max(widest, math.floor((text:GetStringWidth() or 0) + .5))
    end
    text:SetText(now)
    return widest
end
function Rows.PlaceTags(row)
    local box = row.tagBox
    box:ClearAllPoints()
    if row.tagAfter then
        box:SetPoint("LEFT", row.tagAfter, "RIGHT", 10, 0)
    else
        -- The words drop one so they sit on the name's baseline.
        local width = row.slider and WidestName(row) or math.floor((row.text:GetStringWidth() or 0) + .5)
        box:SetPoint("LEFT", row.text, "LEFT", width + TAG_GAP + 1, -1)
    end
    if row.slider then Rows.PlaceSlider(row) end
end
-- A slider row's slider: in its usual place, or after the row's words
-- ("experimental") when they reach that far, so they never sit on it.
function Rows.PlaceSlider(row)
    local slider, info = row.slider, row.info
    local left = info.wide and 222 or 214
    if #row.tagIds > 0 then
        local words = row.textLeft + WidestName(row) + TAG_GAP + 1 + math.floor(row.tagBox:GetWidth() + .5)
        left = math.max(left, words + 10)
    end
    slider:ClearAllPoints()
    slider:SetPoint("LEFT", row, "LEFT", left, 0)
    if info.wide then
        slider:SetWidth(math.max(60, 522 - left))
    else
        slider:SetPoint("RIGHT", row, "RIGHT", -12, 0)
    end
end
local function Tag(row, index)
    local tag = row.tags[index]
    if tag then return tag end
    tag = Text(row.tagBox, "", TAG_SIZE)
    tag:SetWordWrap(false)
    row.tags[index] = tag
    return tag
end
-- ids in their order from left to right, for example {"NEW", "TEST"}.
function Rows.SetTags(row, ids)
    row.tagKey, row.tagIds = table.concat(ids, ","), ids
    local width, last = 0, nil
    for index, id in ipairs(ids) do
        local info = TAGS[id]
        local tag = Tag(row, index)
        tag.id = id
        tag:SetText(info[1])
        tag:SetTextColor(info[2][1], info[2][2], info[2][3])
        tag:ClearAllPoints()
        if last then tag:SetPoint("LEFT", last, "RIGHT", TAG_GAP, 0)
        else tag:SetPoint("LEFT", row.tagBox, "LEFT", 0, 0) end
        tag:Show()
        width = width + (last and TAG_GAP or 0) + math.floor(tag:GetStringWidth() + .5)
        last = tag
    end
    for index = #ids + 1, #row.tags do row.tags[index]:Hide() end
    row.tagBox:SetWidth(math.max(1, width))
    Rows.PlaceTags(row)
end

-- A sub-option sits 22 in under the option it needs, joined by a thin line.
function Rows.SetIndent(row, depth)
    row.depth = depth or 0
    if not row.connV then return end
    local on = row.depth > 0
    row.connV:SetShown(on)
    row.connH:SetShown(on)
end

-- Search took you here: the row's edge lights up in your class colour.
function Rows.Flash(row)
    row.flashToken = (row.flashToken or 0) + 1
    local token = row.flashToken
    row.flashing = true
    Rows.Paint(row)
    C_Timer.After(1.6, function()
        if row.flashToken == token then
            row.flashing = false
            Rows.Paint(row)
        end
    end)
end

function Rows.SetFocus(row, on)
    row.focused = on and true or false
    Rows.Paint(row)
end

-- Other rows -----------------------------------------------------------------

-- Two or more choices side by side at the row's right end (Classic or Dark
-- Mode). The chosen one is filled in your class colour.
function Rows.SelectChoice(row, index)
    row.selected = index
    Rows.PaintChoices(row.buttons, index)
end
function Rows.PaintChoices(buttons, index)
    local r, g, b = ClassColour()
    for i, button in ipairs(buttons) do
        local on = i == index
        button.selected = on
        if on then
            button:SetBackdropColor(r, g, b, 1)
            button:SetBackdropBorderColor(r, g, b, 1)
            button.label:SetTextColor(.1, .09, 0)
        else
            button:SetBackdropColor(.06, .07, .085, 1)
            button:SetBackdropBorderColor(.18, .2, .24, 1)
            button.label:SetTextColor(.58, .62, .68)
        end
    end
end
function Rows.Choice(frame, key, label, names, onChoose)
    local row = Rows.Base(frame, key, "choice", label, "Frame")
    row.buttons = {}
    local last
    for i = #names, 1, -1 do
        local index = i
        local button = Rows.Button(row, names[i], nil, 22)
        if last then button:SetPoint("RIGHT", last, "LEFT", -6, 0)
        else button:SetPoint("RIGHT", row, "RIGHT", -10, 0) end
        button:SetScript("OnClick", function() onChoose(index) end)
        Rows.Forward(row, button)
        row.buttons[i] = button
        last = button
    end
    row.text:SetPoint("RIGHT", last, "LEFT", -12, 0)
    row.SetChecked = function() end
    return row
end

function Rows.MakeSlider(parent, low, high, step)
    local slider = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    slider:SetHeight(12)
    slider:SetBackdrop(BACKDROP)
    slider:SetBackdropColor(.06, .065, .075, 1)
    slider:SetBackdropBorderColor(.3, .32, .36, 1)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(true)
    slider:SetThumbTexture(WHITE)
    slider:GetThumbTexture():SetSize(10, 20)
    slider:GetThumbTexture():SetVertexColor(ClassColour())
    return slider
end

-- A slider row: "Name: value", then the slider. info: low, high, step, wide,
-- read() (nil: not available here), save(value), format(value), after(value).
function Rows.Slider(frame, key, label, info)
    local row = Rows.Base(frame, key, "slider", label, "Frame")
    local slider = Rows.MakeSlider(row, info.low, info.high, info.step)
    row.slider, row.info = slider, info
    -- Room for the longest name with its highest value ("Cast Ring Opacity
    -- (%): 100"); a wide row's slider is 300 long, a narrow row's takes the
    -- rest of the row. Rows.PlaceSlider moves it right past any words.
    row.text:SetPoint("RIGHT", row, "LEFT", info.wide and 212 or 206, 0)
    Rows.PlaceSlider(row)
    local function Show(value)
        row.text:SetText(label .. ": " .. (info.format and info.format(value) or tostring(value)))
        if info.after then info.after(row, value) end
    end
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.max(info.low, math.min(info.high, math.floor(value + .5)))
        Show(value)
        if not row.syncing and info.save then info.save(value) end
    end)
    row.SetChecked = function()
        local value = info.read()
        slider:SetShown(value ~= nil)
        if value == nil then
            row.text:SetText(label .. ": not available")
            if info.after then info.after(row, nil) end
            return
        end
        value = math.max(info.low, math.min(info.high, value))
        row.syncing = true
        slider:SetValue(value)
        row.syncing = false
        Show(value)
    end
    Rows.Forward(row, slider)
    return row
end

-- A table line (Ability Trail's You and Party): a tick row a whole line
-- wide, its name kept to the first column, then its cells, one a column: a
-- choice (small buttons side by side, the chosen one in your class colour)
-- or a slider with its value after it. Hovering a cell shows that cell's own
-- description in the footer (its key's help and default). cells: {kind,
-- key, label, x, read(), save(value)}, then names, values and width (a
-- choice's buttons) or low, high, step, width and format(value) (a slider).
local function CellEnter(child)
    local row = child.row
    row.hovered = true
    Rows.Paint(row)
    local frame = row.owner
    if frame and frame.ShowRowHelp then frame:ShowRowHelp(child.cell.help) end
end
local function CellLeave(child) Leave(child.row) end
local function Watch(row, child, cell)
    child.row, child.cell = row, cell
    child:HookScript("OnEnter", CellEnter)
    child:HookScript("OnLeave", CellLeave)
end
function Rows.SyncCells(row)
    for _, cell in ipairs(row.cells or {}) do
        local value = cell.read()
        if cell.kind == "choice" then
            local index = 1
            for i, choice in ipairs(cell.values) do if choice == value then index = i end end
            cell.selected = index
            Rows.PaintChoices(cell.buttons, index)
        else
            value = math.max(cell.low, math.min(cell.high, tonumber(value) or cell.low))
            cell.syncing = true
            cell.slider:SetValue(value)
            cell.syncing = false
            cell.value:SetText(cell.format and cell.format(value) or tostring(value))
        end
    end
end
local function ChoiceCell(row, cell)
    cell.buttons = {}
    for i, name in ipairs(cell.names) do
        local button = Rows.Button(row, name, cell.width, 22)
        button:SetPoint("LEFT", row, "LEFT", cell.x + (i - 1) * (cell.width + 4), 0)
        button:SetScript("OnClick", function()
            cell.save(cell.values[i])
            Rows.SyncCells(row)
        end)
        Watch(row, button, cell)
        cell.buttons[i] = button
    end
end
local function SliderCell(row, cell)
    local slider = Rows.MakeSlider(row, cell.low, cell.high, cell.step)
    slider:SetPoint("LEFT", row, "LEFT", cell.x, 0)
    slider:SetWidth(cell.width)
    local value = Text(row, "", 13)
    value:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    value:SetWordWrap(false)
    slider:SetScript("OnValueChanged", function(_, raw)
        local n = math.max(cell.low, math.min(cell.high, math.floor(raw + .5)))
        value:SetText(cell.format and cell.format(n) or tostring(n))
        if not cell.syncing then cell.save(n) end
    end)
    -- The thumb (20 tall) stands past the 12 px slider: the slider takes the
    -- mouse its full height, so grabbing the thumb's edge drags it.
    slider:SetHitRectInsets(0, 0, -5, -5)
    Watch(row, slider, cell)
    cell.slider, cell.value = slider, value
end
function Rows.Cells(row, cells)
    row.cells = cells
    local name = cells[1].x - 8
    row.text:SetPoint("RIGHT", row, "LEFT", name, 0)
    -- The line's own click (its tick) only on its name: a click that misses
    -- a cell (between the buttons, on a value) flips nothing. Kept to the
    -- name as the line is sized (the whole width once laid out).
    local function Fit(self, width)
        width = tonumber(width) or WIDE
        self:SetHitRectInsets(0, math.max(0, width - name), 0, 0)
    end
    Fit(row, WIDE)
    row:HookScript("OnSizeChanged", Fit)
    for _, cell in ipairs(cells) do
        cell.help = {settingKey = cell.key, labelText = cell.label, owner = row.owner, rowKind = "cell"}
        if cell.kind == "choice" then ChoiceCell(row, cell) else SliderCell(row, cell) end
    end
    -- The tick, then its cells, follow what's saved.
    local tick = row.SetChecked
    row.SetChecked = function(self, checked)
        tick(self, checked)
        Rows.SyncCells(self)
    end
end
-- Column titles over a table's first line: on its section heading's line
-- (18 above the line, the heading's height) and in its look, gold small
-- capitals; the heading itself names the first column. titles: {text, x}.
function Rows.Titles(row, titles)
    row.titles = {}
    for i, title in ipairs(titles) do
        local fs = Text(row, title[1]:upper(), 11)
        fs:SetTextColor(Rows.GOLD[1], Rows.GOLD[2], Rows.GOLD[3])
        fs:SetPoint("TOPLEFT", row, "TOPLEFT", title[2], 18)
        row.titles[i] = fs
    end
end

-- A colour row: its swatch at the right; a click opens the colour picker.
function Rows.Colour(frame, key, label, read)
    local row = Rows.Base(frame, key, "colour", label, "Button")
    local edge = row:CreateTexture(nil, "ARTWORK")
    edge:SetSize(18, 18)
    edge:SetPoint("RIGHT", row, "RIGHT", -12, 0)
    edge:SetColorTexture(TICK_EDGE[1], TICK_EDGE[2], TICK_EDGE[3], 1)
    row.swatch = row:CreateTexture(nil, "ARTWORK", nil, 1)
    row.swatch:SetSize(16, 16)
    row.swatch:SetPoint("CENTER", edge, "CENTER", 0, 0)
    row.text:SetPoint("RIGHT", edge, "LEFT", -8, 0)
    row.searchText = string.lower("cursor mouse colour color " .. label)
    row.SetChecked = function() row.swatch:SetColorTexture(read()) end
    row:RegisterForClicks("LeftButtonUp")
    return row
end

-- The damage font: a button showing the chosen font in its own lettering,
-- and the list of fonts it opens (each name in its own font). info: fonts,
-- current() and choose(font).
function Rows.Font(frame, key, label, info)
    local row = Rows.Base(frame, key, "font", label, "Frame")
    row.text:SetPoint("RIGHT", row, "LEFT", 212, 0)
    local button = Rows.Button(row, "", 240, 26)
    button:SetPoint("LEFT", row, "LEFT", 222, 0)
    button.label:Hide()
    local sample = button:CreateFontString(nil, "OVERLAY")
    sample:SetPoint("LEFT", button, "LEFT", 10, 0)
    sample:SetPoint("RIGHT", button, "RIGHT", -26, 0)
    sample:SetJustifyH("LEFT")
    sample:SetWordWrap(false)
    sample:SetTextColor(1, 1, 1)
    local arrow = Text(button, "v", 14, true)
    arrow:SetPoint("RIGHT", button, "RIGHT", -10, 0)
    row.fontButton, row.sample = button, sample
    -- "log out to apply" goes after the button, where there's room.
    row.tagAfter = button
    Rows.PlaceTags(row)
    Rows.Forward(row, button)
    local list = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    list:SetSize(260, #info.fonts * 26 + 12)
    list:SetFrameLevel(frame:GetFrameLevel() + 60)
    list:SetBackdrop(BACKDROP)
    list:SetBackdropColor(.018, .02, .026, .98)
    list:SetBackdropBorderColor(.19, .20, .24, 1)
    list:EnableMouse(true)
    list:Hide()
    row.list, list.rows = list, {}
    for i, font in ipairs(info.fonts) do
        local entry = CreateFrame("Button", nil, list)
        entry:SetSize(240, 24)
        entry:SetPoint("TOPLEFT", list, "TOPLEFT", 10, -6 - (i - 1) * 26)
        entry.mark = entry:CreateTexture(nil, "ARTWORK")
        entry.mark:SetSize(4, 16)
        entry.mark:SetPoint("LEFT", entry, "LEFT", 0, 0)
        entry.label = entry:CreateFontString(nil, "OVERLAY")
        entry.label:SetPoint("LEFT", entry, "LEFT", 12, 0)
        entry.label:SetJustifyH("LEFT")
        entry.label:SetTextColor(.9, .91, .93)
        UseFont(entry.label, font, 16)
        entry.label:SetText(font.name)
        local hover = entry:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, .06)
        entry.font = font
        entry:SetScript("OnClick", function()
            list:Hide()
            info.choose(font)
        end)
        list.rows[i] = entry
    end
    -- Opens under the row, or above it when the row is low in the window.
    button:SetScript("OnClick", function()
        if list:IsShown() then list:Hide(); return end
        local _, rowY = button:GetCenter()
        local _, frameY = frame:GetCenter()
        list:ClearAllPoints()
        if rowY and frameY and rowY < frameY then list:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 4)
        else list:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -4) end
        row:SetChecked()
        list:Show()
    end)
    row:HookScript("OnHide", function() list:Hide() end)
    row.SetChecked = function()
        local current = info.current()
        UseFont(sample, current, 16)
        sample:SetText(current and current.name or "")
        local r, g, b = ClassColour()
        for _, entry in ipairs(list.rows) do
            entry.mark:SetColorTexture(r, g, b, 1)
            entry.mark:SetShown(current ~= nil and entry.font.key == current.key)
        end
    end
    return row
end

-- A row with one button at its right (Presets).
function Rows.ButtonRow(frame, key, label, buttonText, onClick)
    local row = Rows.Base(frame, key, "button", label, "Frame")
    local button = Rows.Button(row, buttonText, nil, 24, true)
    button:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    button:SetScript("OnClick", onClick)
    row.text:SetPoint("RIGHT", button, "LEFT", -12, 0)
    row.button = button
    Rows.Forward(row, button)
    row.SetChecked = function() end
    return row
end

-- A line of words to type (a whole line): its name, the box, and Default at
-- the right, which puts the first words back. Enter, or leaving the box,
-- saves; Escape puts the saved words back. info: read() (the saved words),
-- save(text), reset(), maxLetters.
local function TextSave(box)
    local row = box.row
    if not box.cancelled then row.info.save(box:GetText() or "") end
    box.cancelled = nil
    row:SetChecked()
end
local function TextEscape(box)
    box.cancelled = true
    box:ClearFocus()
end
local function TextEnter(box) box:ClearFocus() end
function Rows.TextBox(frame, key, label, info)
    local row = Rows.Base(frame, key, "text", label, "Frame")
    row.info = info
    row.text:SetPoint("RIGHT", row, "LEFT", 212, 0)
    local reset = Rows.Button(row, "Default", nil, 22)
    reset:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    local box = CreateFrame("EditBox", nil, row, "BackdropTemplate")
    box:SetHeight(22)
    box:SetPoint("LEFT", row, "LEFT", 222, 0)
    box:SetPoint("RIGHT", reset, "LEFT", -8, 0)
    box:SetBackdrop(BACKDROP)
    box:SetBackdropColor(TICK_FILL[1], TICK_FILL[2], TICK_FILL[3], 1)
    box:SetBackdropBorderColor(TICK_EDGE[1], TICK_EDGE[2], TICK_EDGE[3], 1)
    local font, _, flags = GameFontHighlight:GetFont()
    box:SetFont(font, 13, flags or "")
    box:SetTextColor(.94, .95, .98)
    box:SetTextInsets(7, 7, 0, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(info.maxLetters or 120)
    box.row = row
    box:SetScript("OnEnterPressed", TextEnter)
    box:SetScript("OnEscapePressed", TextEscape)
    box:SetScript("OnEditFocusLost", TextSave)
    reset:SetScript("OnClick", function()
        box.cancelled = true
        box:ClearFocus()
        box.cancelled = nil
        info.reset()
        row:SetChecked()
    end)
    Rows.Forward(row, box)
    Rows.Forward(row, reset)
    row.edit, row.resetButton = box, reset
    -- The saved words, unless they're being typed.
    row.SetChecked = function()
        if not box:HasFocus() then box:SetText(info.read() or "") end
    end
    return row
end

-- A whole row that opens something, with ">" at its right end.
function Rows.Link(frame, key, label, onClick)
    local row = Rows.Base(frame, key, "link", label, "Button")
    local r, g, b = ClassColour()
    row.text:SetTextColor(r, g, b)
    row.arrow = Text(row, ">", 16)
    row.arrow:SetTextColor(r, g, b)
    row.arrow:SetPoint("RIGHT", row, "RIGHT", -12, 0)
    row.text:SetPoint("RIGHT", row.arrow, "LEFT", -8, 0)
    row:SetScript("OnClick", onClick)
    row.SetChecked = function() end
    return row
end

-- A heading row with no switch: a class tool's options open under it.
function Rows.Heading(frame, key, label)
    local row = Rows.Base(frame, key, "heading", label, "Frame")
    row.text:SetTextColor(ClassColour())
    row.SetChecked = function() end
    return row
end

-- Another of the author's addons: its icon, name and whether you have it,
-- with Open (installed) or Get it and GitHub (links to copy).
function Rows.More(frame, key, info)
    local row = Rows.Base(frame, key, "more", info.name, "Frame")
    row.baseHeight = Rows.MORE_HEIGHT
    row:SetHeight(Rows.MORE_HEIGHT)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("LEFT", row, "LEFT", 12, 0)
    icon:SetTexture(info.icon)
    row.icon = icon
    row.textLeft = 54
    row.text:SetFont(select(1, GameFontHighlight:GetFont()), 14, "")
    row.text:ClearAllPoints()
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 54, -12)
    row.state = Text(row, "", 11, true)
    row.state:SetWordWrap(false)
    row.state:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 54, 12)
    local open = Rows.Button(row, "Open", 96, 26, true)
    open:SetPoint("RIGHT", row, "RIGHT", -12, 0)
    local github = Rows.Button(row, "GitHub", 80, 26, true)
    github:SetPoint("RIGHT", row, "RIGHT", -12, 0)
    local getIt = Rows.Button(row, "Get it", 96, 26, true)
    getIt:SetPoint("RIGHT", github, "LEFT", -6, 0)
    for _, button in ipairs({open, github, getIt}) do Rows.Forward(row, button) end
    row.open, row.github, row.getIt = open, github, getIt
    row.SetChecked = function() end
    return row
end

-- A search result: the option's name, where it lives ("Tab > Sub-tab") and
-- its labels. A click takes you to the option; it never changes it.
function Rows.Result(frame)
    local row = CreateFrame("Button", nil, frame.settingsContent, "BackdropTemplate")
    row:SetSize(WIDTH, Rows.RESULT_HEIGHT)
    row:SetBackdrop(BACKDROP)
    row.owner, row.rowKind, row.isResult, row.baseHeight = frame, "result", true, Rows.RESULT_HEIGHT
    row.text = Text(row, "", 13)
    row.text:SetWordWrap(false)
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -7)
    row.text:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    Rows.TagBox(row)
    row.crumb = Text(row, "", 11)
    row.crumb:SetTextColor(Rows.CRUMB[1], Rows.CRUMB[2], Rows.CRUMB[3])
    row.crumb:SetWordWrap(false)
    row.crumb:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 12, 7)
    row.crumb:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnEnter", Enter)
    row:SetScript("OnLeave", Leave)
    row:SetScript("OnClick", function(self)
        if self.target and frame.JumpTo then frame:JumpTo(self.target.settingKey) end
    end)
    Rows.Paint(row)
    return row
end
