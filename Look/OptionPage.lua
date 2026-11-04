-- The old Classic options page, built one way for both of its homes: the
-- floating window (EraUIClassicOptions; /era replaces the way in, so players
-- don't reach it) and the page in the game's Settings, AddOns tab
-- (EraUIClassicOptionsCanvas). A search box, two columns of check boxes in
-- a scrolling list with the 1.x scroll bar, Toggle all, Reset toggles (asks
-- first) and Reload UI, and the reload note.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local O = Look.Options

local ROW = O.ROW

-- Reset toggles' hover (Squirt's own words, kept as they are).
O.RESET_HOVER = "Asks first, then puts every checkbox back to its default. Nothing to do with edit mode layouts."
O.TOGGLE_HOVER = "Turns every part of the classic look on, or off when all of them are on. It leaves alone the extras that start off (One bar, One bag, Default interface bar size), the minimap button and the welcome note."
O.RELOAD_NOTE = "Reload the interface to clear the old art from the parts you turned off."
local CLEAR_ICON = "Interface\\FriendsFrame\\ClearBroadcastIcon"

local function Default(key)
    local known = ns.DB_DEFAULTS
    if type(known) ~= "table" then return nil end
    return known[key]
end

local function AsksReload(key)
    local keys = ns.RELOAD_KEYS
    return type(keys) == "table" and keys[key] == true
end

local function OptionList()
    return type(ns.TOGGLES) == "table" and ns.TOGGLES or {}
end

local function RunPass()
    if type(ns.ApplyAll) == "function" then ns.ApplyAll() end
end

local function ReloadQuestion()
    if StaticPopup_Show then StaticPopup_Show("ERAUICLASSIC_RELOAD") end
end

---------------------------------------------------------------------------
-- Search and placement
---------------------------------------------------------------------------

local function Wanted(page)
    local typed = page.search and page.search:GetText()
    local raw = type(typed) == "string" and typed or ""
    return (raw:lower():gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Matches(line, wanted)
    if wanted == "" then return true end
    local name, about = (line.label or ""):lower(), (line.description or ""):lower()
    return name:find(wanted, 1, true) ~= nil or about:find(wanted, 1, true) ~= nil
end

-- The groups the search shows, in list order: each top-level row with a
-- match in its group (itself or a child), then all its children.
local function Groups(page, wanted)
    local lit, heads, order = {}, {}, {}
    for _, each in ipairs(page.rows) do
        if Matches(each, wanted) then lit[each.parent or each.key] = true end
    end
    for _, each in ipairs(page.rows) do
        if each.parent == nil and lit[each.key] then
            heads[each.key] = { each }
            order[#order + 1] = heads[each.key]
        end
    end
    for _, each in ipairs(page.rows) do
        local under = each.parent and heads[each.parent]
        if under then under[#under + 1] = each end
    end
    return order
end

function O.Place(page)
    local groups = Groups(page, Wanted(page))
    local count = 0
    for _, group in ipairs(groups) do count = count + #group end
    local half = math.max(1, math.ceil(count / 2))
    -- Two columns: a new one starts when this one has rows, the group
    -- would take it past half, and it isn't the last column already.
    local placed, column, depth, deepest = {}, 0, 0, 0
    for _, group in ipairs(groups) do
        if depth > 0 and depth + #group > half and column < 1 then column, depth = column + 1, 0 end
        for _, each in ipairs(group) do
            local across = column * page.columnWidth + (each.parent and 22 or 0)
            Look.Pin(each.frame, "TOPLEFT", page.child, "TOPLEFT", across, -depth * ROW)
            each.frame:Show()
            placed[each] = true
            depth = depth + 1
        end
        deepest = math.max(deepest, depth)
    end
    for _, each in ipairs(page.rows) do
        if not placed[each] then each.frame:Hide() end
    end
    local tall = math.max(1, deepest * ROW)
    page.child:SetHeight(tall)
    Look.ScrollRange(page.bar, math.max(0, tall - page.visible * ROW), ROW)
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------

local function RefreshRow(line, saved, handed)
    local usable = line.parent == nil or saved[line.parent] ~= false
    line.note = nil
    if handed and O.PLATE_KEYS[line.key] then usable, line.note = false, O.PLATE_NOTE end
    line.enabled = usable
    if line.kind == "stepper" then
        O.SyncStepper(line)
    else
        line.frame:SetChecked(saved[line.key] ~= false)
        line.frame:SetEnabled(usable)
    end
    line.text:SetFontObject(usable and GameFontHighlight or GameFontDisable)
end

-- The page read again: each row's tick, whether it can be used, and the
-- reload note. (O.Refresh: after a click, a pass or a reset; the page's
-- own showing reads it directly.)
local function ReadPage(frame)
    local page, saved = frame and O.pages[frame], ns.db
    if page == nil or saved == nil then return end
    if type(ns.ReadGameDamageNumbers) == "function" then Look.Try(ns.ReadGameDamageNumbers) end
    local handed = type(ns.PlatesHandedOver) == "function" and ns.PlatesHandedOver() == true
    for _, each in ipairs(page.rows) do RefreshRow(each, saved, handed) end
    page.note:SetText(ns.needsReload and O.RELOAD_NOTE or "")
end
O.Refresh = ReadPage

---------------------------------------------------------------------------
-- Toggle all, Reset toggles
---------------------------------------------------------------------------

-- The parts of the classic look Toggle all switches.
local function Switched(key)
    if key:find("^eraui_") or key == "minimapButton" or key == "welcomeNote" then return false end
    return Default(key) ~= false
end

function O.ToggleAll(frame)
    local saved = ns.db
    if saved == nil then return end
    local keys, someOff = {}, false
    for _, option in ipairs(OptionList()) do
        if Switched(option[1]) then
            keys[#keys + 1] = option[1]
            if saved[option[1]] == false then someOff = true end
        end
    end
    local reloadDue = false
    for _, key in ipairs(keys) do
        if not someOff and saved[key] ~= false and AsksReload(key) then reloadDue = true end
        saved[key] = someOff
    end
    RunPass()
    O.Refresh(frame)
    if reloadDue then ReloadQuestion() end
end

-- Only the prompt's Reset runs this: each option back to its default, in
-- the list's order (the Quality of Life rows told through ToggleChanged),
-- the bars fitted back if Default interface bar size went off, a pass, the
-- page read again, and the reload question when a reload key went off.
function O.ResetToggles(frame)
    local saved = ns.db
    if saved == nil then return end
    local reloadDue, wasBig = false, saved.defaultBarSize == true
    for _, option in ipairs(OptionList()) do
        local key = option[1]
        local wanted = Default(key)
        if wanted == false and saved[key] ~= false and AsksReload(key) then reloadDue = true end
        saved[key] = wanted
        if key:find("^eraui_") and type(ns.ToggleChanged) == "function" then ns.ToggleChanged(key) end
    end
    if wasBig and saved.defaultBarSize ~= true and type(ns.FitBarsToSize) == "function" then ns.FitBarsToSize(false) end
    RunPass()
    O.Refresh(frame)
    if reloadDue then ReloadQuestion() end
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

local function SearchBox(page, width, top)
    local holder = page.frame
    local field = CreateFrame("EditBox", nil, holder, "InputBoxTemplate")
    field:SetSize(width - 60, 20)
    field:SetPoint("TOP", holder, "TOP", 4, top)
    field:SetAutoFocus(false)
    if ChatFontNormal then field:SetFontObject(ChatFontNormal) end
    field:SetMaxLetters(40)
    local placeholder = Look.OwnLabel(field, "placeholder", "GameFontDisable", "ARTWORK")
    Look.Pin(placeholder, "LEFT", field, "LEFT", 2, 0)
    placeholder:SetText("Search toggles")
    local eraser = Look.Build("Button", field, nil, { size = { 17, 17 } })
    Look.Pin(eraser, "RIGHT", field, "RIGHT", -3, 0)
    eraser:SetNormalTexture(CLEAR_ICON)
    local face = eraser:GetNormalTexture()
    if face then face:SetAlpha(0.6) end
    eraser:SetHighlightTexture(CLEAR_ICON)
    local glow = eraser:GetHighlightTexture()
    if glow then glow:SetBlendMode("ADD") end
    eraser:Hide()
    local function Typed()
        local now = field:GetText() or ""
        Look.Shown(placeholder, now == "")
        Look.Shown(eraser, now ~= "")
        O.Place(page)
    end
    local function Emptied()
        field:SetText("")
        field:ClearFocus()
        Typed()
    end
    field:SetScript("OnTextChanged", Typed)
    field:SetScript("OnEscapePressed", Emptied)
    field:SetScript("OnEnterPressed", function() field:ClearFocus() end)
    eraser:SetScript("OnClick", Emptied)
    page.search, page.hint, page.clear = field, placeholder, eraser
end

local function List(page, width, top)
    local holder = page.frame
    local across, tall = width - 70, page.visible * ROW
    local viewport = CreateFrame("ScrollFrame", nil, holder)
    viewport:SetPoint("TOPLEFT", holder, "TOPLEFT", 22, top)
    viewport:SetPoint("BOTTOMRIGHT", holder, "TOPLEFT", 22 + across, top - tall)
    viewport:SetSize(across, tall)
    if viewport.SetClipsChildren then viewport:SetClipsChildren(true) end
    local sheet = Look.Build("Frame", viewport, nil, { size = { across, 1 } })
    sheet:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)
    viewport:SetScrollChild(sheet)
    page.scroll, page.child, page.columnWidth = viewport, sheet, across / 2
    page.bar = Look.ClassicScrollBar(holder, viewport, function(value) viewport:SetVerticalScroll(value) end)
    local function Wheel(_, notches)
        local bar = page.bar
        bar:SetValue((Look.Number(bar:GetValue()) or 0) - (Look.Number(notches) or 0) * ROW)
    end
    viewport:EnableMouseWheel(true)
    viewport:SetScript("OnMouseWheel", Wheel)
end

-- The three buttons and the note.
local function Buttons(page)
    local holder, field = page.frame, page.search
    local all = ns.PanelButton(holder, "Toggle all", 100)
    all:SetPoint("TOPRIGHT", field, "BOTTOM", -3, -6)
    all:SetScript("OnClick", function() O.ToggleAll(holder) end)
    O.GiveTip(all, function() return { { "Toggle all", 1, 1, 1 }, { O.TOGGLE_HOVER, 1, 0.82, 0, 280 } } end)
    local defaults = ns.PanelButton(holder, "Reset toggles", 100)
    defaults:SetPoint("TOPLEFT", field, "BOTTOM", 3, -6)
    page.ask = { title = "Reset toggles", question = "Reset every checkbox on this page to its default?",
        combat = "Finish combat before resetting the toggles.", run = function() O.ResetToggles(holder) end }
    defaults:SetScript("OnClick", function()
        if EraUI.AskReset then EraUI:AskReset(page.ask) end
    end)
    O.GiveTip(defaults, function() return { { "Reset toggles", 1, 1, 1 }, { O.RESET_HOVER, 1, 0.82, 0, 280 } } end)
    local again = ns.PanelButton(holder, "Reload UI", 130)
    again:SetPoint("BOTTOM", holder, "BOTTOM", 0, 22)
    again:SetScript("OnClick", function()
        if type(ns.ReloadForLayout) == "function" then ns.ReloadForLayout() end
    end)
    local warning = Look.OwnLabel(holder, "reloadNote", "GameFontNormal", "OVERLAY")
    Look.Pin(warning, "BOTTOM", holder, "BOTTOM", 0, 78)
    warning:SetTextColor(1, 0.35, 0.25)
    warning:SetText("")
    page.note, page.toggle, page.reset, page.reload = warning, all, defaults, again
    -- Closing the page (or the window) closes its own Reset question.
    Look.HookScript(holder, "OnHide", function()
        if EraUI.CloseResetPrompt then EraUI:CloseResetPrompt(page.ask) end
    end, "options")
end

-- One page on frame: shape = { width, visible (rows), searchTop, listTop }.
function O.Build(frame, shape)
    local page = { frame = frame, rows = {}, byKey = {}, visible = shape.visible, width = shape.width }
    O.pages[frame] = page
    SearchBox(page, shape.width, shape.searchTop)
    List(page, shape.width, shape.listTop)
    Buttons(page)
    O.MakeRows(page)
    Look.HookScript(frame, "OnShow", function() ReadPage(frame) end, "options")
    O.Place(page)
    ReadPage(frame)
    return page
end
