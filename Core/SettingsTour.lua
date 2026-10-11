local _, E = ...

-- The new /era layout's welcome card and walkthrough. Players who had the
-- old layout (Core/Integration.lua sets EraUIDB.layoutWelcome to 1 once per
-- account) see a card the first time they open /era after the update: "Not
-- now" or "Show me around". The walkthrough is six steps: a dim layer over
-- the window with a class-coloured outline round one part of it and a small
-- card beside it. While either shows, the window takes no other clicks (the
-- dim layer is EraUI's own frame, over EraUI's own window). Take the tour, at
-- the bottom of the tab list, starts the walkthrough any time. Nothing here
-- is secure or anchored to anything secure, so combat changes nothing.
local Tour = {}
E.SettingsTour = Tour

local WELCOME_TITLE = "Settings have a new layout"
local WELCOME_TEXT = "Tabs are grouped, busy pages have sub-tabs, and each option is now a single row. All your settings are kept."
local WELCOME_MORE = "A one-minute walkthrough shows where everything went."
local LATER_NOTE = "You can take the tour any time: Take the tour, at the bottom of the list."
Tour.WELCOME_TITLE, Tour.WELCOME_TEXT, Tour.WELCOME_MORE, Tour.LATER_NOTE = WELCOME_TITLE, WELCOME_TEXT, WELCOME_MORE, LATER_NOTE
local CARD_WIDTH, PAD, GAP, EDGE = 300, 4, 14, 12

local function Rows() return E.SettingsRows end
local function TAB() return E.SettingsNav.TAB end

-- A region's box in window coordinates: left and top from the window's top
-- left corner, y growing downwards.
local function Box(frame, region)
    local left, top, right, bottom = region:GetLeft(), region:GetTop(), region:GetRight(), region:GetBottom()
    local fl, ft = frame:GetLeft(), frame:GetTop()
    if not (left and top and right and bottom and fl and ft) then return end
    local ratio = region:GetEffectiveScale() / frame:GetEffectiveScale()
    return left * ratio - fl, ft - top * ratio, right * ratio - fl, ft - bottom * ratio
end
Tour.Box = Box

local function TabList(frame)
    local l, t = Box(frame, frame.groupHeadings[1])
    local tabs = frame.tabs
    local _, _, r, b = Box(frame, tabs[#tabs])
    local tl = Box(frame, tabs[1])
    if not (l and tl) then return end
    return math.min(l, tl), t - 5, r, b
end

local STEPS = {
    {title = "Grouped tabs", text = "Your tabs now sit under four headings: Look, Gameplay, Social and Extras.",
        target = TabList},
    {title = "Sub-tabs", text = "Busy pages are split into sub-tabs. Everything dark lives together under Appearance > Dark Mode.",
        before = function(frame) frame:SelectCategory(TAB().appearance, "dark") end,
        target = function(frame) return Box(frame, frame.subTabStrip) end},
    {title = "One row per option", text = "Tick a row to switch it on. Options that need another sit indented under it, greyed until it's on.",
        target = function(frame) return Box(frame, frame.settingsScroll) end},
    {title = "Descriptions", text = "Hover any row and its full description shows here, along with anything it needs first.",
        target = function(frame) return Box(frame, frame.footer) end},
    {title = "Search", text = "Can't find something? Search finds every option and takes you straight to it.",
        target = function(frame) return Box(frame, frame.searchBox) end},
    {title = "Nothing lost", text = "Every setting you had is kept. Take the tour any time from the bottom of the list.",
        target = function(frame) return Box(frame, frame.settingsScroll) end},
}
Tour.STEPS = STEPS

-- A layer over the whole window that takes the mouse and the wheel.
local function Blocker(frame, level)
    local layer = CreateFrame("Frame", nil, frame)
    layer:SetAllPoints(frame)
    layer:SetFrameLevel(frame:GetFrameLevel() + level)
    layer:EnableMouse(true)
    layer:EnableMouseWheel(true)
    layer:SetScript("OnMouseWheel", function() end)
    layer:Hide()
    return layer
end

local function Card(parent, width, level)
    local R = Rows()
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetWidth(width)
    card:SetFrameLevel(parent:GetFrameLevel() + level)
    card:SetBackdrop(R.BACKDROP)
    card:SetBackdropColor(.08, .09, .125, 1)
    card:SetBackdropBorderColor(R.ClassColour())
    card:EnableMouse(true)
    return card
end

local function Gold(text)
    local gold = Rows().GOLD
    text:SetTextColor(gold[1], gold[2], gold[3])
    return text
end

local function Height(text, fallback)
    local h = text.GetStringHeight and text:GetStringHeight()
    return (h and h > 0) and h or fallback
end

-- Welcome card ------------------------------------------------------------

local function BuildWelcome(frame)
    if frame.welcome then return frame.welcome end
    local R = Rows()
    local welcome = Blocker(frame, 100)
    local dim = welcome:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints(welcome)
    dim:SetColorTexture(.012, .016, .024, .6)
    local card = Card(welcome, 380, 20)
    card:SetPoint("CENTER", welcome, "CENTER", 0, 0)
    local title = Gold(R.Text(card, WELCOME_TITLE, 20))
    title:SetPoint("TOPLEFT", card, "TOPLEFT", 20, -20)
    local text = R.Text(card, WELCOME_TEXT, 13)
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    text:SetWidth(340)
    text:SetWordWrap(true)
    local more = R.Text(card, WELCOME_MORE, 13, true)
    more:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -10)
    more:SetWidth(340)
    more:SetWordWrap(true)
    local go = R.Button(card, "Show me around", nil, 26, true)
    go:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -20, 18)
    local later = R.Button(card, "Not now", nil, 26)
    later:SetPoint("RIGHT", go, "LEFT", -8, 0)
    go:SetScript("OnClick", function() Tour.Go(frame) end)
    later:SetScript("OnClick", function() Tour.Later(frame) end)
    card:SetHeight(20 + 24 + 10 + Height(text, 34) + 10 + Height(more, 17) + 18 + 26 + 18)
    welcome.dim, welcome.card, welcome.title, welcome.text, welcome.more = dim, card, title, text, more
    welcome.go, welcome.later = go, later
    frame.welcome = welcome
    return welcome
end

-- The card shows once per account: either button, or closing /era while it
-- shows, uses it up (and the old layout note with it).
local function UseWelcome(frame)
    if frame.welcome then frame.welcome:Hide() end
    frame.welcoming = false
    if E:GetSavedSetting("layoutWelcome") == 1 or E:GetSavedSetting("layoutNotice") == 1 then
        E:SetSetting("layoutWelcome", 0)
        if E:GetSavedSetting("layoutNotice") == 1 then E:SetSetting("layoutNotice", 0) end
        E:SaveSettings()
    end
end
Tour.UseWelcome = UseWelcome

function Tour.ShowWelcome(frame)
    local welcome = BuildWelcome(frame)
    -- No class box or conjure button under the card: the class tab gives way
    -- to Appearance first.
    if frame.selectedCategory == TAB().class then frame:SelectCategory(TAB().appearance, "style") end
    frame.welcoming = true
    if frame.ClearRowFocus then frame:ClearRowFocus() end
    frame:ShowRowHelp(nil)
    welcome:Show()
    frame.keys:SetFocus()
end

-- On every /era open: the card waits while setup runs, a walkthrough runs,
-- or a class tool opened the window at its controls.
function Tour.MaybeWelcome(frame)
    if frame.setupMode or frame.touring or frame.navigatingToClass then return end
    if E:GetSavedSetting("layoutWelcome") ~= 1 then return end
    Tour.ShowWelcome(frame)
end

function Tour.Later(frame)
    UseWelcome(frame)
    frame.keys:ClearFocus()
    frame.footerMessage = LATER_NOTE
    frame:ShowRowHelp(nil)
end

function Tour.Go(frame)
    UseWelcome(frame)
    Tour.Start(frame)
end

-- Hidden without using it up (setup started over it).
function Tour.HideWelcome(frame)
    if frame.welcome then frame.welcome:Hide() end
    frame.welcoming = false
end

-- Walkthrough -------------------------------------------------------------

local function BuildTour(frame)
    if frame.tour then return frame.tour end
    local R = Rows()
    local tour = Blocker(frame, 100)
    tour.dims, tour.lines = {}, {}
    for i = 1, 4 do
        local dim = tour:CreateTexture(nil, "BACKGROUND")
        dim:SetColorTexture(.012, .016, .024, .72)
        tour.dims[i] = dim
        local line = tour:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(R.ClassColour())
        tour.lines[i] = line
    end
    local card = Card(tour, CARD_WIDTH, 10)
    local step = R.Text(card, "", 11, true)
    step:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -14)
    local title = Gold(R.Text(card, "", 18))
    title:SetPoint("TOPLEFT", step, "BOTTOMLEFT", 0, -6)
    local text = R.Text(card, "", 13)
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    text:SetWidth(CARD_WIDTH - 32)
    text:SetWordWrap(true)
    local nextButton = R.Button(card, "Next", 80, 24, true)
    nextButton:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -16, 14)
    local back = R.Button(card, "Back", 80, 24)
    back:SetPoint("RIGHT", nextButton, "LEFT", -8, 0)
    nextButton:SetScript("OnClick", function() Tour.Next(frame) end)
    back:SetScript("OnClick", function()
        if frame.tourStep == 1 then Tour.End(frame) else Tour.Back(frame) end
    end)
    tour.card, tour.step, tour.title, tour.text, tour.nextButton, tour.back = card, step, title, text, nextButton, back
    frame.tour = tour
    return tour
end

local function Place(texture, parent, x, y, w, h)
    if w <= 0 or h <= 0 then texture:Hide(); return end
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    texture:SetSize(w, h)
    texture:Show()
end

-- Beside the spot if it fits (right, then left), else below or above it,
-- always inside the window; with no room anywhere (the whole page is the
-- spot), on the side with the most room.
local function PlaceCard(tour, W, H, x, y, w, h)
    local card = tour.card
    local ch = card:GetHeight()
    local cx, cy
    if x + w + GAP + CARD_WIDTH <= W - EDGE then cx, cy = x + w + GAP, y
    elseif x - GAP - CARD_WIDTH >= EDGE then cx, cy = x - GAP - CARD_WIDTH, y
    elseif y + h + GAP + ch <= H - EDGE then cx, cy = x, y + h + GAP
    elseif y - GAP - ch >= EDGE then cx, cy = x, y - GAP - ch
    elseif x >= W - x - w then cx, cy = EDGE, y
    else cx, cy = W - EDGE - CARD_WIDTH, y end
    cx = math.max(EDGE, math.min(W - EDGE - CARD_WIDTH, cx))
    cy = math.max(EDGE, math.min(H - EDGE - ch, cy))
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", tour, "TOPLEFT", cx, -cy)
    tour.cardX, tour.cardY = cx, cy
end

local function ShowStep(frame, n)
    local tour = BuildTour(frame)
    local step = STEPS[n]
    frame.tourStep = n
    if step.before then step.before(frame) end
    if frame.LayoutSettings then frame:LayoutSettings() end
    local W, H = frame:GetWidth(), frame:GetHeight()
    local left, top, right, bottom = step.target(frame)
    left, top, right, bottom = left or 0, top or 0, right or W, bottom or H
    local x, y = math.max(0, left - PAD), math.max(0, top - PAD)
    local w, h = math.min(W, right + PAD) - x, math.min(H, bottom + PAD) - y
    tour.hole = {x = x, y = y, w = w, h = h}
    Place(tour.dims[1], tour, 0, 0, W, y)
    Place(tour.dims[2], tour, 0, y + h, W, H - y - h)
    Place(tour.dims[3], tour, 0, y, x, h)
    Place(tour.dims[4], tour, x + w, y, W - x - w, h)
    Place(tour.lines[1], tour, x, y, w, 2)
    Place(tour.lines[2], tour, x, y + h - 2, w, 2)
    Place(tour.lines[3], tour, x, y, 2, h)
    Place(tour.lines[4], tour, x + w - 2, y, 2, h)
    tour.step:SetText("Step " .. n .. " of " .. #STEPS)
    tour.title:SetText(step.title)
    tour.text:SetText(step.text)
    tour.back.label:SetText(n == 1 and "Skip" or "Back")
    tour.nextButton.label:SetText(n == #STEPS and "Done" or "Next")
    tour.card:SetHeight(14 + 11 + 6 + 18 + 8 + Height(tour.text, 48) + 14 + 24 + 14)
    PlaceCard(tour, W, H, x, y, w, h)
end
Tour.ShowStep = ShowStep

function Tour.Start(frame)
    if frame.setupMode then return end
    Tour.HideWelcome(frame)
    local searched = frame.searching
    if frame.ResetSearch then frame:ResetSearch() end
    if E.Presets and E.Presets.Hide then E.Presets:Hide() end
    local font = frame.checks and frame.checks.damageFont
    if font and font.list then font.list:Hide() end
    if frame.ClearRowFocus then frame:ClearRowFocus() end
    -- No class box or conjure button under the dim layer, and a page (not
    -- search results) behind it.
    if frame.selectedCategory == TAB().class or searched then frame:SelectCategory(TAB().appearance) end
    frame.touring = true
    frame:ShowRowHelp(nil)
    BuildTour(frame):Show()
    ShowStep(frame, 1)
    frame.keys:SetFocus()
end

function Tour.Next(frame)
    if not frame.tourStep then return end
    if frame.tourStep >= #STEPS then Tour.End(frame) else ShowStep(frame, frame.tourStep + 1) end
end

function Tour.Back(frame)
    if frame.tourStep and frame.tourStep > 1 then ShowStep(frame, frame.tourStep - 1) end
end

function Tour.End(frame)
    if frame.tour then frame.tour:Hide() end
    local was = frame.touring
    frame.touring, frame.tourStep = false, nil
    if was then
        frame.keys:ClearFocus()
        frame:ShowRowHelp(nil)
    end
end

function Tour.Attach(frame)
    frame.StartTour = Tour.Start
    frame.EndTour = Tour.End
end
