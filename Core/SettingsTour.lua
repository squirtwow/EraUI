local _, E = ...

-- /era's welcome card and walkthroughs. The card shows once per account,
-- the first time /era opens: for players who had the old layout
-- (Core/Integration.lua sets EraUIDB.layoutWelcome to 1) a note on the new
-- layout; for a new player (EraUIDB.tourOffer 1) an offer of the
-- walkthrough once the first-run welcome or setup is behind them. Either
-- way "Not now" or "Show me around". The layout walkthrough is six steps: a
-- dim layer over the window with a class-coloured outline round one part of
-- it and a small card beside it. Take the tour, at the bottom of the tab
-- list, starts it any time. What's New's Show me (Core/Updates.lua) and
-- Show me what's new, at the top of /era, run the same walkthrough over the
-- options the release added, one step each, outlining each option's row on
-- its tab and sub-tab. Show me what's new is in the class colour and glows
-- softly until this account opens that release's walkthrough
-- (EraUIDB.newsTourSeen). While a card or walkthrough shows, the window takes
-- no other clicks (the dim layer is EraUI's own frame, over EraUI's own
-- window). Nothing here is secure or anchored to anything secure, so combat
-- changes nothing.
local Tour = {}
E.SettingsTour = Tour

local WELCOME_TITLE = "Settings have a new layout"
local WELCOME_TEXT = "Tabs are grouped, busy pages have sub-tabs, and each option is now a single row. All your settings are kept."
local WELCOME_MORE = "A one-minute walkthrough shows where everything went."
local LATER_NOTE = "You can take the tour any time: Take the tour, at the bottom of the list."
Tour.WELCOME_TITLE, Tour.WELCOME_TEXT, Tour.WELCOME_MORE, Tour.LATER_NOTE = WELCOME_TITLE, WELCOME_TEXT, WELCOME_MORE, LATER_NOTE
-- A new player's card: the same card and buttons, its own words.
local FRESH_TITLE = "Find your way around"
local FRESH_TEXT = "Your options sit in tabs on the left, busy pages have sub-tabs, and each option is a single row."
local FRESH_MORE = "A one-minute walkthrough shows how it all works."
Tour.FRESH_TITLE, Tour.FRESH_TEXT, Tour.FRESH_MORE = FRESH_TITLE, FRESH_TEXT, FRESH_MORE
local CARD_WIDTH, PAD, GAP, EDGE = 300, 4, 14, 12

local function Rows() return E.SettingsRows end
local function Rules() return E.SettingsRules end
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

-- A new player's walkthrough (tourOffer 1 or 2) words the first and last
-- steps as a first look, not a change (freshTitle, freshText).
local STEPS = {
    {title = "Grouped tabs", text = "Your tabs now sit under four headings: Look, Gameplay, Social and Extras.",
        freshText = "Your tabs sit under four headings: Look, Gameplay, Social and Extras.",
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
        freshTitle = "Any time", freshText = "Take the tour again any time from the bottom of the list, and /era opens this window.",
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

-- A new player's account (tourOffer 1 waiting, 2 offered).
local function FreshAccount()
    return (tonumber(E:GetSavedSetting("tourOffer")) or 0) >= 1
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
    welcome.dim, welcome.card, welcome.title, welcome.text, welcome.more = dim, card, title, text, more
    welcome.go, welcome.later = go, later
    frame.welcome = welcome
    return welcome
end

-- The card shows once per account: either button, or closing /era while it
-- shows, uses it up (the layout card takes the old layout note with it; a
-- new player's offer becomes 2).
local function UseWelcome(frame)
    if frame.welcome then frame.welcome:Hide() end
    frame.welcoming = false
    local changed = false
    if E:GetSavedSetting("layoutWelcome") == 1 or E:GetSavedSetting("layoutNotice") == 1 then
        E:SetSetting("layoutWelcome", 0)
        if E:GetSavedSetting("layoutNotice") == 1 then E:SetSetting("layoutNotice", 0) end
        changed = true
    end
    if frame.welcomeKind == "fresh" and E:GetSavedSetting("tourOffer") == 1 then
        E:SetSetting("tourOffer", 2)
        changed = true
    end
    if changed then E:SaveSettings() end
end
Tour.UseWelcome = UseWelcome

-- kind: "fresh" for a new player's offer, else the new layout's card.
function Tour.ShowWelcome(frame, kind)
    local welcome = BuildWelcome(frame)
    local fresh = kind == "fresh"
    frame.welcomeKind = fresh and "fresh" or "layout"
    welcome.title:SetText(fresh and FRESH_TITLE or WELCOME_TITLE)
    welcome.text:SetText(fresh and FRESH_TEXT or WELCOME_TEXT)
    welcome.more:SetText(fresh and FRESH_MORE or WELCOME_MORE)
    welcome.card:SetHeight(20 + 24 + 10 + Height(welcome.text, 34) + 10 + Height(welcome.more, 17) + 18 + 26 + 18)
    -- No class box or conjure button under the card: the class tab gives way
    -- to Appearance first.
    if frame.selectedCategory == TAB().class then frame:SelectCategory(TAB().appearance, "style") end
    frame.welcoming = true
    if frame.ClearRowFocus then frame:ClearRowFocus() end
    frame:ShowRowHelp(nil)
    welcome:Show()
    frame.keys:SetFocus()
end

-- This character has the first-run welcome or setup behind it (seen,
-- skipped or finished).
local function FirstRunBehind()
    local state = EraUIClassicCharDB and EraUIClassicCharDB.onboarding
    return type(state) == "table" and (state.welcomeSeen == true or state.setupComplete == true)
end

-- On every /era open: the card waits while setup runs, a walkthrough runs,
-- or a class tool opened the window at its controls. A new player's offer
-- also waits until the first-run welcome or setup is behind them.
function Tour.MaybeWelcome(frame)
    if frame.setupMode or frame.touring or frame.navigatingToClass then return end
    if E:GetSavedSetting("layoutWelcome") == 1 then
        Tour.ShowWelcome(frame, "layout")
    elseif E:GetSavedSetting("tourOffer") == 1 and FirstRunBehind() then
        Tour.ShowWelcome(frame, "fresh")
    end
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

-- Hidden without using it up (setup or another walkthrough started over it).
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
    title:SetWidth(CARD_WIDTH - 32)
    title:SetWordWrap(true)
    local text = R.Text(card, "", 13)
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    text:SetWidth(CARD_WIDTH - 32)
    text:SetWordWrap(true)
    -- A muted line under it: what an option waits for, or where it shows.
    local note = R.Text(card, "", 12, true)
    note:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -6)
    note:SetWidth(CARD_WIDTH - 32)
    note:SetWordWrap(true)
    note:Hide()
    local nextButton = R.Button(card, "Next", 80, 24, true)
    nextButton:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -16, 14)
    local back = R.Button(card, "Back", 80, 24)
    back:SetPoint("RIGHT", nextButton, "LEFT", -8, 0)
    nextButton:SetScript("OnClick", function() Tour.Next(frame) end)
    back:SetScript("OnClick", function()
        if frame.tourStep == 1 then Tour.End(frame) else Tour.Back(frame) end
    end)
    tour.card, tour.step, tour.title, tour.text, tour.note = card, step, title, text, note
    tour.nextButton, tour.back = nextButton, back
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

-- The running walkthrough's steps: the layout's six, or a release's new
-- options (frame.tourSteps, with its own step line).
local function StepsOf(frame) return frame.tourSteps or STEPS end

local function ShowStep(frame, n)
    local tour = BuildTour(frame)
    local steps = StepsOf(frame)
    local step = steps[n]
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
    local fresh = frame.tourFresh
    tour.step:SetText(steps.label and steps.label(n, #steps) or ("Step " .. n .. " of " .. #steps))
    tour.title:SetText(fresh and step.freshTitle or step.title)
    tour.text:SetText(fresh and step.freshText or step.text)
    local note = step.note
    if type(note) == "function" then note = note(frame) end
    tour.note:SetText(note or "")
    tour.note:SetShown(note ~= nil and note ~= "")
    tour.back.label:SetText(n == 1 and "Skip" or "Back")
    tour.nextButton.label:SetText(n == #steps and "Done" or "Next")
    tour.card:SetHeight(14 + 11 + 6 + Height(tour.title, 18) + 8 + Height(tour.text, 48)
        + (tour.note:IsShown() and 6 + Height(tour.note, 14) or 0) + 14 + 24 + 14)
    PlaceCard(tour, W, H, x, y, w, h)
end
Tour.ShowStep = ShowStep

-- steps: a release's new options (Tour.StartNews); the layout's six without.
function Tour.Start(frame, steps)
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
    frame.tourSteps = steps
    frame.tourFresh = steps == nil and FreshAccount()
    -- A new player who takes the tour before being offered it isn't offered it after.
    if steps == nil and E:GetSavedSetting("tourOffer") == 1 then
        E:SetSetting("tourOffer", 2)
        E:SaveSettings()
    end
    frame.touring = true
    frame:ShowRowHelp(nil)
    BuildTour(frame):Show()
    ShowStep(frame, 1)
    frame.keys:SetFocus()
end

function Tour.Next(frame)
    if not frame.tourStep then return end
    if frame.tourStep >= #StepsOf(frame) then Tour.End(frame) else ShowStep(frame, frame.tourStep + 1) end
end

function Tour.Back(frame)
    if frame.tourStep and frame.tourStep > 1 then ShowStep(frame, frame.tourStep - 1) end
end

function Tour.End(frame)
    if frame.tour then frame.tour:Hide() end
    local was = frame.touring
    frame.touring, frame.tourStep, frame.tourSteps, frame.tourFresh = false, nil, nil, nil
    frame.newsSpot, frame.newsNote = nil, nil
    if was then
        frame.keys:ClearFocus()
        frame:ShowRowHelp(nil)
    end
end

-- What's new ----------------------------------------------------------------

-- The release whose notes What's New shows (Core/Updates.lua): the running
-- version's, or the newest for a development copy.
local function Release()
    return (E.ReleaseVersion and E.ReleaseVersion()) or E.version
end
Tour.Release = Release

-- This account opened the walkthrough of the release's new options (either
-- Show me), so Show me what's new stops glowing. Saved per account and
-- backed up (EraUIDB.newsTourSeen, Core/Persistence.lua); the next release
-- with new options glows again.
function Tour.NewsSeen(version)
    return E:GetSavedSetting("newsTourSeen") == (version or Release())
end

-- The glow: three bands of EraUI's flat texture just outside the button's
-- edge, in the class colour, fading outwards (from, to: pixels out; alpha).
-- They sit on a frame of their own whose alpha breathes while it shows; a
-- hidden frame runs no OnUpdate, so hiding it stops the glow. It takes no
-- mouse and nothing in it is secure, so a fight changes nothing.
local GLOW_BANDS = {{0, 2, .5}, {2, 4, .24}, {4, 6, .1}}
local GLOW_SIZE, GLOW_LOW, GLOW_SPEED = 6, .35, 2.6

local function Breathe(glow, elapsed)
    glow.pulse = ((glow.pulse or 0) + (elapsed or 0)) % (2 * math.pi / GLOW_SPEED)
    glow:SetAlpha(GLOW_LOW + (1 - GLOW_LOW) * (.5 + .5 * math.sin(glow.pulse * GLOW_SPEED)))
end
-- Each time it shows it starts at full and breathes from there, no jump.
local function Rise(glow)
    glow.pulse = math.pi / 2 / GLOW_SPEED
    Breathe(glow, 0)
end

local function BuildGlow(button)
    local r, g, b = Rows().ClassColour()
    local glow = CreateFrame("Frame", nil, button)
    glow:SetPoint("TOPLEFT", button, "TOPLEFT", -GLOW_SIZE, GLOW_SIZE)
    glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", GLOW_SIZE, -GLOW_SIZE)
    glow.bands = {}
    for _, band in ipairs(GLOW_BANDS) do
        local from, to, alpha = band[1], band[2], band[3]
        local top, bottom, left, right = glow:CreateTexture(nil, "BACKGROUND"), glow:CreateTexture(nil, "BACKGROUND"),
            glow:CreateTexture(nil, "BACKGROUND"), glow:CreateTexture(nil, "BACKGROUND")
        -- Top and bottom run the full width, corners too; the sides fit between.
        top:SetPoint("BOTTOMLEFT", button, "TOPLEFT", -to, from)
        top:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", to, from)
        top:SetHeight(to - from)
        bottom:SetPoint("TOPLEFT", button, "BOTTOMLEFT", -to, -from)
        bottom:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", to, -from)
        bottom:SetHeight(to - from)
        left:SetPoint("TOPRIGHT", button, "TOPLEFT", -from, from)
        left:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", -from, -from)
        left:SetWidth(to - from)
        right:SetPoint("TOPLEFT", button, "TOPRIGHT", from, from)
        right:SetPoint("BOTTOMLEFT", button, "BOTTOMRIGHT", from, -from)
        right:SetWidth(to - from)
        for _, piece in ipairs({top, bottom, left, right}) do
            piece:SetColorTexture(r, g, b, alpha)
            glow.bands[#glow.bands + 1] = piece
        end
    end
    glow:SetScript("OnShow", Rise)
    glow:SetScript("OnUpdate", Breathe)
    glow:Hide()
    return glow
end

-- Glows while Show me what's new is on show and this release's
-- walkthrough hasn't been opened.
local function RefreshGlow(frame)
    local news = frame.newsButton
    if news and news.glow then news.glow:SetShown(news:IsShown() and not Tour.NewsSeen()) end
end

-- A release's new options, one per step: each option's own row
-- (SettingsNav.Lead: the rows under it, or shown with it, go with it) that
-- exists for this character and isn't coming soon, in tab order, then page
-- order. A greyed or folded one still counts: its step says why.
function Tour.NewsKeys(frame, version)
    local Nav, keys = E.SettingsNav, {}
    version = version or Release()
    if not frame.rowHome then return keys end
    for key, added in pairs(Nav.ADDED) do
        local row, home = frame.checks[key], frame.rowHome[key]
        if added == version and row and home and row.classAllowed ~= false and not row.unavailable and Nav.Lead(key) then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, function(a, b) return frame.rowHome[a].place < frame.rowHome[b].place end)
    return keys
end

-- Takes the window to a new option and says what to outline, with a note
-- when it isn't simply there: its row (greyed: what it waits for; handed
-- over: who has it); folded, or shown only with its switch: the switch it
-- shows under; on the class tab: the tab itself, as the class page's boxes
-- and conjure buttons never sit under the dim layer. Changes nothing.
local function Spot(frame, key)
    local home, row, tabs = frame.rowHome[key], frame.checks[key], TAB()
    if home.tab == tabs.class then
        if frame.selectedCategory == tabs.class then frame:SelectCategory(tabs.appearance) end
        return frame.tabs[home.tab], "On your " .. frame.categories[home.tab].name .. " tab."
    end
    frame:SelectCategory(home.tab, home.sub)
    local spot, note = row, nil
    if not row:IsShown() then
        local Owner, owner, depth = E.SettingsNav.Owner, E.SettingsNav.Owner(key), 0
        while owner and depth < 8 and not (frame.checks[owner] and frame.checks[owner]:IsShown()) do
            owner, depth = Owner(owner), depth + 1
        end
        spot = owner and frame.checks[owner]
        if spot then
            note = spot.rowKind == "tick" and ("Shows once " .. (spot.labelText or "it") .. " is on.")
                or ("Shows with one of " .. (spot.labelText or "its") .. "'s choices.")
        else
            note = "Not on show for you right now."
        end
    elseif row.handedOver then
        note = Rules().HANDED_OVER[key] or "Another addon handles this now."
    elseif row.dependencyDisabled then
        note = Rules().WaitingFor(frame, key)
    end
    if spot and spot:GetParent() == frame.settingsContent then frame:ScrollToRow(spot, true) end
    return spot, note
end

-- The outlined spot: the row inside the page's viewport, or the tab.
local function SpotBox(frame)
    local spot = frame.newsSpot
    if not spot then return Box(frame, frame.settingsScroll) end
    local l, t, r, b = Box(frame, spot)
    if l and spot:GetParent() == frame.settingsContent then
        local vl, vt, vr, vb = Box(frame, frame.settingsScroll)
        if vl then l, t, r, b = math.max(l, vl), math.max(t, vt), math.min(r, vr), math.min(b, vb) end
    end
    return l, t, r, b
end

-- The card's title: the row's name; a short one under an older option on
-- the same page reads with that option's ("Clean Minimap: Style").
local function NewsTitle(frame, key)
    local row, owner = frame.checks[key], E.SettingsNav.Owner(key)
    local name = row.labelText or key
    local parent = owner and frame.checks[owner]
    local mine, theirs = frame.rowHome[key], owner and frame.rowHome[owner]
    if parent and theirs and mine.tab == theirs.tab and mine.sub == theirs.sub then
        name = (parent.labelText or owner) .. ": " .. name
    end
    return name
end

-- The card's text: the row's one-line summary.
local function NewsText(frame, key)
    local row = frame.checks[key]
    return row.summary or Rules().settingHelp[key] or ""
end

-- Starts the walkthrough of a release's new options (the notes' release by
-- default). Nothing new for this character, or setup open: nothing starts.
function Tour.StartNews(frame, version)
    version = version or Release()
    local keys = Tour.NewsKeys(frame, version)
    if frame.setupMode or #keys == 0 then return false end
    local steps = {label = function(n, total) return n .. " of " .. total .. " just added in " .. version end}
    for i, key in ipairs(keys) do
        steps[i] = {key = key, title = NewsTitle(frame, key), text = NewsText(frame, key),
            before = function(f) f.newsSpot, f.newsNote = Spot(f, key) end,
            note = function(f) return f.newsNote end, target = SpotBox}
    end
    Tour.Start(frame, steps)
    -- Opened: the release's walkthrough is seen, so the glow stops (saved
    -- at once, backup too). Another release's walkthrough leaves it be.
    if version == Release() and not Tour.NewsSeen(version) then
        E:SetSetting("newsTourSeen", version)
        E:SaveSettings()
    end
    RefreshGlow(frame)
    return true
end

-- How many steps What's New's Show me would have (0: no button). None
-- while the setup walkthrough is open, as Show me never opens over it.
function Tour.NewsCount()
    local frame = E.settingsFrame
    if not frame or (frame.setupMode and frame:IsShown()) then return 0 end
    return #Tour.NewsKeys(frame)
end

-- What's New's Show me (Core/Updates.lua): opens /era, never over the setup
-- walkthrough, and starts the walkthrough of what's new. A card due on this
-- open waits for the next.
function Tour.OpenNews()
    local settings = E.modules and E.modules.Settings
    if not settings then return false end
    if not settings.frame and settings.Initialize then settings:Initialize() end
    local frame = settings.frame
    if not frame or (frame.setupMode and frame:IsShown()) then return false end
    if frame.setupMode then frame:SetSetupMode(false) end
    if not frame:IsShown() then frame:Show() end
    return Tour.StartNews(frame)
end

-- Show me what's new, at the top right of /era beside the X: only while the
-- release has new options for this character, never in setup; glowing
-- until its walkthrough is opened.
function Tour.RefreshNews(frame)
    if not frame.newsButton then return end
    frame.newsButton:SetShown(not frame.setupMode and #Tour.NewsKeys(frame) > 0)
    RefreshGlow(frame)
end

function Tour.Attach(frame)
    frame.StartTour = Tour.Start
    frame.EndTour = Tour.End
    frame.StartNews = Tour.StartNews
    -- In the class colour: edge and fill like Take the tour, and its words.
    local R = Rows()
    local news = R.Button(frame, "Show me what's new", nil, 26, true)
    news.label:SetTextColor(R.ClassColour())
    if frame.closeButton then news:SetPoint("RIGHT", frame.closeButton, "LEFT", -8, 0)
    else news:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -56, -17) end
    news:SetScript("OnClick", function() Tour.StartNews(frame) end)
    news.glow = BuildGlow(news)
    news:Hide()
    frame.newsButton = news
end
