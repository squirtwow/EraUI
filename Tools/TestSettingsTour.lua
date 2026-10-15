-- The new /era layout's welcome card and six-step walkthrough
-- (Core/SettingsTour.lua) on the real settings window, under the frame mock
-- in Tools/SettingsMock.lua. Who gets the card (layoutWelcome) is decided in
-- Core/Integration.lua and checked in Tools/TestPersistence.lua.
local M = dofile("Tools/SettingsMock.lua")
local equal, Session, Flush, Open, Tab = M.equal, M.Session, M.Flush, M.Open, M.Tab
local S = M.S
local function Has(text, part) return text:find(part, 1, true) ~= nil end
local function Under(frame, ancestor)
 while frame do if frame == ancestor then return true end; frame = frame.parent end
 return false
end
-- Mouse-enabled frames outside the settings window.
local function Outside(f)
 local out = {}
 for _, frame in ipairs(S.frames) do if frame.mouse and not Under(frame, f) then out[frame] = true end end
 return out
end

local STEPS = {
 {"Grouped tabs", "Your tabs now sit under four headings: Look, Gameplay, Social and Extras."},
 {"Sub-tabs", "Busy pages are split into sub-tabs. Everything dark lives together under Appearance > Dark Mode."},
 {"One row per option", "Tick a row to switch it on. Options that need another sit indented under it, greyed until it's on."},
 {"Descriptions", "Hover any row and its full description shows here, along with anything it needs first."},
 {"Search", "Can't find something? Search finds every option and takes you straight to it."},
 {"Nothing lost", "Every setting you had is kept. Take the tour any time from the bottom of the list."},
}
-- Nothing in the walkthrough talks about moved options any more.
for _, step in ipairs(STEPS) do assert(not step[2]:lower():find("moved", 1, true), step[1] .. " says nothing about moving") end

-- The welcome card: once per account, for players who had the old layout.
do
 local E, f = Session("PRIEST")
 local saves = 0
 E.SaveSettings = function() saves = saves + 1 end
 local function Reopen() f:Hide(); f:Show(); Flush() end
 equal(f.welcoming == true, false, "no card unless Integration asked for one (nil)")
 E.settings.layoutWelcome = 0; Reopen()
 equal(f.welcoming == true, false, "a fresh install never gets it (0)")
 E.settings.layoutWelcome = 1; Reopen()
 local w = f.welcome
 equal(f.welcoming == true and w:IsShown(), true, "a returning player sees the welcome card")
 equal(w.title:GetText(), "Settings have a new layout", "its title")
 equal(w.text:GetText(), "Tabs are grouped, busy pages have sub-tabs, and each option is now a single row. All your settings are kept.", "its text")
 equal(w.more:GetText(), "A one-minute walkthrough shows where everything went.", "and the walkthrough line")
 equal(w.later.label:GetText() .. " / " .. w.go.label:GetText(), "Not now / Show me around", "its buttons")
 equal(w.go:GetLeft() > w.later:GetRight(), true, "Show me around on the right")
 equal(string.format("%.2f", w.dim.fill[4]), "0.60", "the window dimmed under it")
 -- The dim layer covers the whole window and takes the mouse and the wheel.
 equal(w:GetLeft() == f:GetLeft() and w:GetRight() == f:GetRight() and w:GetTop() == f:GetTop() and w:GetBottom() == f:GetBottom(), true, "the dim layer covers the window")
 equal(w.mouse and w.wheel and w.scripts.OnMouseWheel ~= nil, true, "it takes the mouse and swallows the wheel")
 equal(w.level > f.level and w.card.level > w.level, true, "above the window, the card above the dim")
 local card = w.card
 local cx, cy = (card:GetLeft() + card:GetRight()) / 2, (card:GetTop() + card:GetBottom()) / 2
 equal(math.abs(cx - (f:GetLeft() + f:GetRight()) / 2) < .01 and math.abs(cy - (f:GetTop() + f:GetBottom()) / 2) < .01 and card:GetWidth() == 380, true, "a 380 wide card in the middle")
 equal(card:GetBottom() <= w.go:GetBottom() and w.text:GetBottom() > w.go:GetTop(), true, "its text clear of its buttons")
 equal(f.keys:HasFocus(), true, "the keyboard goes to the card")
 -- Rows show no description under the card.
 f.checks.trainer:Fire("OnEnter")
 equal(f.footerHelp:IsShown(), false, "no description under the card")
 f.checks.trainer:Fire("OnLeave")
 -- Not now: put away for good, with a note on where the tour is.
 E.settings.layoutNotice = 1
 w.later:Click(); Flush()
 equal(w:IsShown() or f.welcoming, false, "Not now puts it away")
 equal(E.settings.layoutWelcome .. " " .. E.settings.layoutNotice .. " " .. saves, "0 0 1", "and saves that at once (the old note too)")
 equal(f.reloadHint:GetText(), "You can take the tour any time: Take the tour, at the bottom of the list.", "the footer says where the tour is")
 equal(f.keys:HasFocus(), false, "the keyboard goes back")
 f.checks.trainer:Fire("OnEnter"); f.checks.trainer:Fire("OnLeave")
 equal(f.reloadHint:GetText() ~= "You can take the tour any time: Take the tour, at the bottom of the list.", true, "the note goes after the next row's description")
 Reopen()
 equal(f.welcoming == true, false, "gone for good")
 -- Show me around: put away, and the walkthrough starts.
 E.settings.layoutWelcome = 1; Reopen()
 w.go:Click(); Flush()
 equal(E.settings.layoutWelcome == 0 and f.touring and f.tourStep == 1 and not w:IsShown(), true, "Show me around saves it and starts at step 1")
 f.tour.back:Click()
 equal(f.touring, false, "Skip ends the walkthrough")
 -- Closing /era while it shows uses it up.
 E.settings.layoutWelcome = 1; Reopen()
 local before = saves
 f:Hide()
 equal(E.settings.layoutWelcome == 0 and saves == before + 1 and not f.welcoming, true, "closing /era with the card up uses it up, saved")
 f:Show(); Flush()
 equal(f.welcoming == true, false, "so it shows once")
 -- The keyboard: Enter shows you around, Escape is Not now.
 E.settings.layoutWelcome = 1; Reopen()
 f.keys:Fire("OnEnterPressed"); Flush()
 equal(E.settings.layoutWelcome == 0 and f.tourStep, 1, "Enter: Show me around")
 f.keys:Fire("OnEscapePressed")
 E.settings.layoutWelcome = 1; Reopen()
 f.keys:Fire("OnEscapePressed"); Flush()
 equal(E.settings.layoutWelcome == 0 and not f.touring and not f.welcoming and f.reloadHint:GetText(), "You can take the tour any time: Take the tour, at the bottom of the list.", "Escape: Not now")
 -- Never in the setup walkthrough: it waits until after it.
 E.settings.layoutWelcome = 1
 f:SetSetupMode(true); Reopen()
 equal(f.welcoming == true, false, "never in the setup walkthrough")
 f:SetSetupMode(false); Reopen()
 equal(f.welcoming and E.settings.layoutWelcome, 1, "still waiting after it")
 -- Setup started over the card hides it without using it up.
 f:SetSetupMode(true); Flush()
 equal(w:IsShown() or f.welcoming, false, "setup over the card hides it")
 equal(E.settings.layoutWelcome, 1, "without using it up")
 f:SetSetupMode(false); f:Hide(); E.settings.layoutWelcome = 0
end

-- The card never covers a class box or a conjure button, and waits while a
-- class tool opens /era at its controls.
do
 local E, f = Session("MAGE")
 E.settings.layoutWelcome = 1
 f:Hide(); f.selectedCategory = Tab(f, "class"); f:Show(); Flush()
 equal(f.welcoming and f.selectedCategory == Tab(f, "appearance") and f.selectedSub[f.selectedCategory], "style", "from the class tab the card opens on Appearance > Style")
 local conjure = 0
 for _, b in ipairs(S.frames) do if b.secure and b:IsShown() then conjure = conjure + 1 end end
 equal(conjure, 0, "no conjure button over the card")
 equal(E.modules.ClassReminders:OptionsPanel():IsVisible() or f.checks.classTools.inlinePanel:IsVisible(), false, "no class box under it")
 f.welcome.later:Click(); E.settings.layoutWelcome = 1
 f:Hide(); Flush()
 E.modules.MageSupplies:Open(); Flush()
 equal(f:IsShown() and f.selectedCategory == Tab(f, "class") and f.welcoming ~= true, true, "a class tool opening /era at its controls: no card")
 equal(E.settings.layoutWelcome, 1, "it waits for the next /era")
 f:Hide(); f:Show(); Flush()
 equal(f.welcoming, true, "and shows then")
end

-- The walkthrough: six steps, each lighting one part of the window with a
-- card beside it.
do
 local E, f = Session("ROGUE")
 E.settings.layoutWelcome = 0
 local outside = Outside(f)
 Open(f, "quests")
 f.tourButton:Click(); Flush()
 local tour = f.tour
 equal(f.touring and f.tourStep == 1 and tour:IsShown(), true, "Take the tour starts the walkthrough at step 1")
 equal(tour:GetLeft() == f:GetLeft() and tour:GetRight() == f:GetRight() and tour:GetTop() == f:GetTop() and tour:GetBottom() == f:GetBottom(), true, "its layer covers the window")
 equal(tour.mouse and tour.wheel and tour.scripts.OnMouseWheel ~= nil, true, "taking the mouse and the wheel")
 for frame in pairs(Outside(f)) do equal(outside[frame], true, "nothing outside the window takes the mouse") end
 equal(f.keys:HasFocus(), true, "the keyboard goes to the walkthrough")
 local W, H = f:GetWidth(), f:GetHeight()
 local function Rect(region)
  return region:GetLeft() - f:GetLeft(), f:GetTop() - region:GetTop(), region:GetRight() - f:GetLeft(), f:GetTop() - region:GetBottom()
 end
 local targets = {
  function() local _, t = Rect(f.groupHeadings[1]); local l = Rect(f.tabs[1]); local _, _, r, b = Rect(f.tabs[#f.tabs]); return l, t - 5, r, b end,
  function() return Rect(f.subTabStrip) end,
  function() return Rect(f.settingsScroll) end,
  function() return Rect(f.footer) end,
  function() return Rect(f.searchBox) end,
  function() return Rect(f.settingsScroll) end,
 }
 local r, g, b = 1, .96, .41
 for n, want in ipairs(STEPS) do
  equal(f.tourStep, n, "step " .. n)
  equal(tour.step:GetText(), "Step " .. n .. " of 6", "step " .. n .. " says where it is")
  equal(tour.title:GetText(), want[1], "step " .. n .. " title")
  equal(tour.text:GetText(), want[2], "step " .. n .. " text, word for word")
  equal(string.format("%.2f,%.2f,%.2f", tour.title.colour[1], tour.title.colour[2], tour.title.colour[3]), "0.93,0.75,0.32", "step " .. n .. " title in gold")
  equal(not Has(tour.text:GetText(), "\226\128\148"), true, "step " .. n .. " no em dash")
  equal(tour.back.label:GetText(), n == 1 and "Skip" or "Back", "step " .. n .. (n == 1 and " offers Skip" or " offers Back"))
  equal(tour.nextButton.label:GetText(), n == 6 and "Done" or "Next", "step " .. n .. (n == 6 and " ends with Done" or " goes on with Next"))
  if n == 2 then
   equal(f.selectedCategory == Tab(f, "appearance") and f.selectedSub[f.selectedCategory] == "dark" and f.subTabStrip:IsShown(), true, "step 2 opens Appearance > Dark Mode")
  end
  -- The spot: the target and 4 round it, inside the window, outlined in the class colour.
  local l, t, rr, bb = targets[n]()
  local hole = tour.hole
  local x, y = math.max(0, l - 4), math.max(0, t - 4)
  equal(string.format("%.1f %.1f %.1f %.1f", hole.x, hole.y, hole.w, hole.h),
   string.format("%.1f %.1f %.1f %.1f", x, y, math.min(W, rr + 4) - x, math.min(H, bb + 4) - y), "step " .. n .. " lights its part of the window")
  for i = 1, 4 do
   local line = tour.lines[i]
   equal(line:IsShown() and string.format("%.2f,%.2f,%.2f", line.fill[1], line.fill[2], line.fill[3]), "1.00,0.96,0.41", "step " .. n .. " outline " .. i .. " in the class colour")
  end
  local dimmed = 0
  for i = 1, 4 do if tour.dims[i]:IsShown() then dimmed = dimmed + tour.dims[i]:GetWidth() * tour.dims[i]:GetHeight() end end
  equal(math.abs(dimmed + hole.w * hole.h - W * H) < 1, true, "step " .. n .. " everything but the spot dimmed")
  -- The card: 300 wide, inside the window, beside the spot where there's room.
  local card = tour.card
  local cl, ct, cr, cb = Rect(card)
  equal(card:GetWidth() == 300 and cl >= 12 - .01 and ct >= 12 - .01 and cr <= W - 12 + .01 and cb <= H - 12 + .01, true, "step " .. n .. " card inside the window")
  local clear = cr <= hole.x + .01 or cl >= hole.x + hole.w - .01 or cb <= hole.y + .01 or ct >= hole.y + hole.h - .01
  equal(clear, n ~= 3 and n ~= 6, "step " .. n .. (n == 3 and " (the whole page: the card sits over its edge)" or n == 6 and " (the whole page again)" or " card clear of the spot"))
  equal(card.level > tour.level, true, "step " .. n .. " card above the dim layer")
  -- Rows show no description while it runs; the mouse can't reach them.
  f.checks.questLog:Fire("OnEnter")
  equal(f.footerHelp:IsShown(), false, "step " .. n .. " no description from the rows")
  f.checks.questLog:Fire("OnLeave")
  if n == 3 then
   -- Back returns, and the arrow keys move too.
   tour.back:Click(); equal(f.tourStep, 2, "Back returns to step 2")
   tour.nextButton:Click(); equal(f.tourStep, 3, "Next goes on")
   f.keys:Fire("OnArrowPressed", "LEFT"); equal(f.tourStep, 2, "the left arrow goes back")
   f.keys:Fire("OnArrowPressed", "RIGHT"); equal(f.tourStep, 3, "the right arrow goes on")
   f.keys:Fire("OnEnterPressed"); equal(f.tourStep, 4, "Enter goes on")
   f.keys:Fire("OnArrowPressed", "LEFT")
  end
  if n < 6 then tour.nextButton:Click(); Flush() end
 end
 tour.nextButton:Click(); Flush()
 equal(f.touring or tour:IsShown() or f.tourStep ~= nil, false, "Done ends the walkthrough")
 equal(f.keys:HasFocus() or f.footerHelp:IsShown(), false, "and gives the keyboard and the footer back")
 equal(f.signature:IsShown() and f.reloadHint:IsShown(), true, "the footer as before")
 -- Escape ends it; so does closing /era.
 f:StartTour(); Flush()
 f.keys:Fire("OnEscapePressed")
 equal(f.touring or tour:IsShown(), false, "Escape ends it")
 f:StartTour(); Flush()
 f:Hide()
 equal(f.touring or tour:IsShown(), false, "closing /era ends it")
 f:Show(); Flush()
 equal(f.touring, false, "and it doesn't come back")
 -- From the class tab or a search, it starts on Appearance with search cleared.
 Open(f, "class")
 f:StartTour(); Flush()
 equal(f.selectedCategory, Tab(f, "appearance"), "from the class tab it opens Appearance first")
 equal(EraUIRogueTools == nil or not EraUIRogueTools:IsShown(), true, "no rogue tools window over it")
 f.keys:Fire("OnEscapePressed")
 M.Results(f, "poison")
 f:StartTour(); Flush()
 equal(f.searching or f.searchBox:GetText() ~= "", false, "search cleared")
 equal(f.sectionTitle:GetText() .. " " .. f.selectedCategory, "Appearance " .. Tab(f, "appearance"), "and Appearance behind it, not the results")
 for _, result in ipairs(f.results) do equal(result:IsShown(), false, "no result left on show") end
 f.keys:Fire("OnEscapePressed")
 -- Not in setup: Take the tour hides, and setup ends a walkthrough.
 f:StartTour(); Flush()
 f:SetSetupMode(true); Flush()
 equal(f.touring or f.tourButton:IsShown(), false, "setup ends the walkthrough and hides Take the tour")
 f:StartTour(); Flush()
 equal(f.touring, false, "no walkthrough in setup")
 f:SetSetupMode(false); Flush()
 equal(f.tourButton:IsShown(), true, "Take the tour back after setup")
end

-- Take the tour works for a fresh install too (no card for them).
do
 local E, f = Session("WARRIOR")
 equal(E.settings.layoutWelcome == nil and f.welcoming ~= true, true, "a fresh install gets no card")
 f.tourButton:Click(); Flush()
 equal(f.touring and f.tourStep, 1, "but Take the tour works")
 for _ = 1, 6 do f.tour.nextButton:Click(); Flush() end
 equal(f.touring, false, "all the way through")
end

-- In combat: nothing here is secure, so the card and every step work and
-- nothing protected is touched.
do
 local E, f = Session("MAGE")
 S.combat = true
 E.settings.layoutWelcome = 1; f:Hide(); f:Show(); Flush()
 equal(f.welcoming, true, "the card shows in combat")
 f.welcome.go:Click(); Flush()
 for n = 1, 6 do equal(f.tourStep, n, "combat step " .. n); f.tour.nextButton:Click(); Flush() end
 equal(f.touring, false, "the walkthrough runs in combat")
 S.combat = false
end

-- A new player (tourOffer 1, decided in Core/Integration.lua and checked in
-- Tools/TestPersistence.lua) is offered the walkthrough once: the first /era
-- with the first-run welcome or setup behind them, never during setup,
-- never twice. The same card, its own words.
local FRESH = {"Find your way around", "Your options sit in tabs on the left, busy pages have sub-tabs, and each option is a single row.",
 "A one-minute walkthrough shows how it all works."}
do
 local E, f = Session("PRIEST")
 local saves = 0
 E.SaveSettings = function() saves = saves + 1 end
 local function Reopen() f:Hide(); f:Show(); Flush() end
 E.settings.tourOffer = 1
 EraUIClassicCharDB.onboarding = {}
 Reopen()
 equal(f.welcoming == true, false, "not before the first-run welcome or setup is behind them")
 EraUIClassicCharDB.onboarding.welcomeSeen = true; Reopen()
 local w = f.welcome
 equal(f.welcoming == true and w:IsShown(), true, "with the welcome seen (or skipped), the first /era offers it")
 equal(w.title:GetText() .. " | " .. w.text:GetText() .. " | " .. w.more:GetText(), table.concat(FRESH, " | "), "in a new player's words")
 for _, text in ipairs(FRESH) do equal(Has(text, "\226\128\148") or Has(text, "now a single") or Has(text, "kept"), false, "no em dash, nothing about a change: " .. text) end
 equal(w.later.label:GetText() .. " / " .. w.go.label:GetText(), "Not now / Show me around", "the same buttons")
 equal(w.text:GetBottom() > w.go:GetTop() and w.card:GetBottom() <= w.go:GetBottom(), true, "its text clear of its buttons")
 w.later:Click(); Flush()
 equal(E.settings.tourOffer .. " " .. saves .. " " .. f.reloadHint:GetText(), "2 1 " .. E.SettingsTour.LATER_NOTE, "Not now: used up and saved, with the note on where the tour is")
 Reopen()
 equal(f.welcoming == true, false, "never twice")
 -- Show me around: the walkthrough, first and last steps worded as a first look.
 E.settings.tourOffer = 1; Reopen()
 w.go:Click(); Flush()
 equal(E.settings.tourOffer .. " " .. tostring(f.touring) .. " " .. f.tourStep, "2 true 1", "Show me around: used up, the walkthrough at step 1")
 equal(f.tour.text:GetText(), "Your tabs sit under four headings: Look, Gameplay, Social and Extras.", "step 1 as a first look")
 for _ = 2, 6 do f.tour.nextButton:Click(); Flush() end
 equal(f.tour.title:GetText() .. ": " .. f.tour.text:GetText(), "Any time: Take the tour again any time from the bottom of the list, and /era opens this window.",
  "step 6 says where it is, not that nothing was lost")
 f.tour.nextButton:Click(); Flush()
 equal(f.touring, false, "and Done ends it")
 -- Closing /era with the card up uses it up; so does Escape.
 E.settings.tourOffer = 1; Reopen()
 f:Hide()
 equal(E.settings.tourOffer, 2, "closing /era with the card up uses it up")
 E.settings.tourOffer = 1; f:Show(); Flush()
 f.keys:Fire("OnEscapePressed"); Flush()
 equal(E.settings.tourOffer .. " " .. tostring(f.welcoming), "2 false", "Escape: Not now")
 -- Take the tour before the card came: no card after it.
 E.settings.tourOffer = 1; EraUIClassicCharDB.onboarding = {}; Reopen()
 f.tourButton:Click(); Flush()
 equal(E.settings.tourOffer .. " " .. f.tour.text:GetText(), "2 Your tabs sit under four headings: Look, Gameplay, Social and Extras.",
  "Take the tour first: in a new player's words, and the offer is used up")
 f.keys:Fire("OnEscapePressed")
 EraUIClassicCharDB.onboarding.welcomeSeen = true; Reopen()
 equal(f.welcoming == true, false, "so it isn't offered after")
 -- Show me what's new is no tour of the layout: a new player's offer stays.
 E.settings.tourOffer = 1; EraUIClassicCharDB.onboarding = {}; Reopen()
 equal(f.newsButton:IsShown(), true, "Show me what's new on show for a new player")
 f.newsButton:Click(); Flush()
 equal(f.touring == true and f.tourSteps ~= nil, true, "it walks through what's new")
 f.keys:Fire("OnEscapePressed")
 equal(E.settings.tourOffer, 1, "and leaves the offer for later")
 -- Setup finished (not only the welcome seen) counts as behind them too.
 EraUIClassicCharDB.onboarding = {setupComplete = true}; Reopen()
 equal(f.welcoming == true and f.welcome.title:GetText(), FRESH[1], "setup finished: the offer shows")
 f.welcome.later:Click()
 equal(E.settings.tourOffer, 2, "and Not now uses it up")
 -- An account that had EraUI before (0) keeps the layout's words.
 E.settings.tourOffer = 0; f:StartTour(); Flush()
 equal(f.tour.text:GetText(), STEPS[1][2], "an earlier EraUI's account: the layout's words")
 f.keys:Fire("OnEscapePressed")
 -- Never during setup: setup runs, then hands over to settings, and the
 -- offer comes as it does.
 E.settings.tourOffer = 1; EraUIClassicCharDB.onboarding = {welcomeSeen = true}
 f:SetSetupMode(true); Reopen()
 equal(f.welcoming == true, false, "never during setup")
 for _ = 1, 40 do
  if not f.setupMode then break end
  equal(f.welcoming == true, false, "never on a setup page")
  f.setupNext:Click(); Flush()
 end
 equal(f.setupMode == false and f:IsShown(), true, "setup finished into settings")
 equal(f.welcoming == true and f.welcome.title:GetText(), FRESH[1], "the offer comes as setup hands over")
 f.welcome.later:Click()
 -- In combat: nothing secure, so it shows.
 E.settings.tourOffer = 1; S.combat = true; Reopen()
 equal(f.welcoming, true, "the offer shows in combat")
 f.welcome.go:Click(); Flush()
 for _ = 1, 6 do f.tour.nextButton:Click(); Flush() end
 equal(f.touring, false, "and its walkthrough runs through")
 S.combat = false
 -- A returning player's card wins over a stray offer, and only one shows.
 E.settings.tourOffer, E.settings.layoutWelcome = 1, 1; Reopen()
 equal(f.welcome.title:GetText(), "Settings have a new layout", "the layout card first")
 f.welcome.later:Click()
 equal(E.settings.layoutWelcome .. " " .. E.settings.tourOffer, "0 1", "it uses up only itself")
 E.settings.tourOffer = 2
end

-- What's new: What's New's Show me and /era's Show me what's new walk
-- through the release's new options (Core/SettingsNav.lua ADDED), one step
-- per option's own row, in tab order, each on its tab and sub-tab with its
-- row outlined.
local NEWS = {
 {"thickFrames", "appearance", "style", "Thick Frames"},
 {"thickAuraBorders", "appearance", "style", "Thick Aura Borders"},
 {"roundedCastBars", "appearance", "style", "Rounded Cast Bars"},
 {"partyOutline", "appearance", "style", "Raid-style Party Outline"},
 {"darkBagButtons", "appearance", "dark", "Dark Bag Buttons"},
 {"upgradeSpellRanks", "actionBars", "main", "Upgrade Spell Ranks"},
 {"cleanMinimapStyle", "map", "main", "Clean Minimap: Style"},
 {"castBarColour", "casting", "main", "Cast Bar Colour"},
 {"statTracker", "character", "main", "Stat Tracker"},
}
local function Clip(f, region)
 local l, t, r, b = region:GetLeft() - f:GetLeft(), f:GetTop() - region:GetTop(), region:GetRight() - f:GetLeft(), f:GetTop() - region:GetBottom()
 local s = f.settingsScroll
 if region:GetParent() == f.settingsContent then
  l, t = math.max(l, s:GetLeft() - f:GetLeft()), math.max(t, f:GetTop() - s:GetTop())
  r, b = math.min(r, s:GetRight() - f:GetLeft()), math.min(b, f:GetTop() - s:GetBottom())
 end
 return l, t, r, b
end
-- The step on show outlines this region (inside the page's viewport for a row).
local function Outlines(f, region, label)
 local W, H = f:GetWidth(), f:GetHeight()
 local l, t, r, b = Clip(f, region)
 local x, y = math.max(0, l - 4), math.max(0, t - 4)
 local hole = f.tour.hole
 equal(string.format("%.1f %.1f %.1f %.1f", hole.x, hole.y, hole.w, hole.h),
  string.format("%.1f %.1f %.1f %.1f", x, y, math.min(W, r + 4) - x, math.min(H, b + 4) - y), label .. " outlines it")
 equal(b - t >= region:GetHeight() - .01, true, label .. " all of it in view")
 local card = f.tour.card
 local class = card.borderColour -- the card's edge is the class colour
 for i = 1, 4 do
  local line = f.tour.lines[i]
  equal(line:IsShown() and string.format("%.2f,%.2f,%.2f", line.fill[1], line.fill[2], line.fill[3]) == string.format("%.2f,%.2f,%.2f", class[1], class[2], class[3]), true,
   label .. " outline " .. i .. " in the class colour")
 end
 local cl, ct, cr, cb = card:GetLeft() - f:GetLeft(), f:GetTop() - card:GetTop(), card:GetRight() - f:GetLeft(), f:GetTop() - card:GetBottom()
 equal(cl >= 12 - .01 and ct >= 12 - .01 and cr <= W - 12 + .01 and cb <= H - 12 + .01, true, label .. " card inside the window")
 equal(cr <= hole.x + .01 or cl >= hole.x + hole.w - .01 or cb <= hole.y + .01 or ct >= hole.y + hole.h - .01, true, label .. " card clear of it")
 equal(f.tour.text:GetBottom() > f.tour.nextButton:GetTop() - .01 and (not f.tour.note:IsShown() or f.tour.note:GetBottom() > f.tour.nextButton:GetTop() - .01), true,
  label .. " card's words clear of its buttons")
 -- The mock's font strings are one line tall however they wrap, so the
 -- card itself must leave room for every wrapped line, the note's too.
 local t = f.tour
 local words = 14 + 11 + 6 + t.title:GetStringHeight() + 8 + t.text:GetStringHeight()
  + (t.note:IsShown() and 6 + t.note:GetStringHeight() or 0) + 14 + 24 + 14
 equal(card:GetHeight() >= words - .01, true, label .. " card tall enough for every line" .. (t.note:IsShown() and ", its note too" or ""))
end
do
 local E, f = Session("ROGUE")
 local Nav, T = E.SettingsNav, E.SettingsTour
 equal(T.Release(), "1.7.1", "the release What's New shows (the newest notes for a version without its own)")
 -- 1.7.0's nine new options make the longest walkthrough, so this runs as
 -- 1.7.0 (1.7.1's one step is checked in the next block).
 local realRelease = E.ReleaseVersion
 E.ReleaseVersion = function() return "1.7.0" end
 f:Hide(); f:Show(); Flush()
 equal(T.Release(), "1.7.0", "running as 1.7.0")
 -- Exactly the release's options: each option Nav says 1.7.0 added that is
 -- its own row (not under or shown with another new one), in tab order.
 local keys = T.NewsKeys(f)
 local want, fromData = {}, {}
 for i, step in ipairs(NEWS) do want[i] = step[1] end
 for key, version in pairs(Nav.ADDED) do if version == "1.7.0" and Nav.Lead(key) then fromData[#fromData + 1] = key end end
 table.sort(fromData, function(a, b) return f.rowHome[a].place < f.rowHome[b].place end)
 equal(table.concat(keys, ","), table.concat(want, ","), "1.7.0's nine new options, in tab order")
 equal(table.concat(keys, ","), table.concat(fromData, ","), "exactly the rows 1.7.0 added that are an option's own")
 for i = 2, #keys do
  local a, b = f.rowHome[keys[i - 1]], f.rowHome[keys[i]]
  equal(a.tab < b.tab or (a.tab == b.tab and a.place < b.place), true, keys[i - 1] .. " before " .. keys[i])
 end
 equal(#T.NewsKeys(f, "1.6.0") .. " " .. #T.NewsKeys(f, "1.5.5") .. " " .. #T.NewsKeys(f, "9.9.9"), "3 0 0", "another release: its own, or none")
 -- A coming-soon option is never a step.
 equal(f.checks.contextMenus.unavailable, true, "Context Menus is coming soon")
 Nav.ADDED.contextMenus = "9.9.9"
 equal(#T.NewsKeys(f, "9.9.9"), 0, "so a coming-soon option is no step")
 Nav.ADDED.contextMenus = nil
 equal(T.NewsCount(), 9, "What's New's Show me: nine steps")
 -- Show me what's new: at the top right of /era, beside the X.
 local news = f.newsButton
 equal(news:IsShown() and news.label:GetText(), "Show me what's new", "Show me what's new in /era while the release has new options")
 local close = f.closeButton
 equal(news:GetRight() <= close:GetLeft() + .01 and math.abs((news:GetTop() + news:GetBottom()) / 2 - (close:GetTop() + close:GetBottom()) / 2) < .01, true, "just left of the X")
 equal(news:GetBottom() >= f.sectionAbout:GetTop() - .01 or news:GetLeft() >= f.sectionAbout:GetLeft() + 560, true, "clear of the page's description")
 equal(news:GetBottom() > f.subTabStrip:GetTop(), true, "above the sub-tabs")
 equal(news:GetLeft() > f.sectionTitle:GetLeft() + M.Glyphs("Frames & Nameplates", 24), true, "clear of the longest page title")
 f:SetSetupMode(true); Flush()
 equal(news:IsShown(), false, "never in setup")
 equal(T.NewsCount(), 0, "nor What's New's Show me while setup is open")
 f:SetSetupMode(false); Flush()
 equal(news:IsShown(), true, "back after it")
 -- Every option's state as it ships: the steps.
 E.settings.unitFrames, E.settings.castBars, E.settings.darkMode, E.settings.cleanMinimap = true, true, true, true
 f:Hide(); f:Show(); Flush()
 local outside = Outside(f)
 Open(f, "quests")
 news:Click(); Flush()
 local tour = f.tour
 equal(f.touring and f.tourStep == 1 and tour:IsShown(), true, "Show me what's new starts at step 1")
 equal(tour.mouse and tour.wheel and tour.level > f.level and tour.card.level > tour.level, true, "the dim layer takes the mouse and the wheel, the card above it")
 for frame in pairs(Outside(f)) do equal(outside[frame], true, "nothing outside the window takes the mouse") end
 equal(f.keys:HasFocus(), true, "the keyboard goes to the walkthrough")
 for n, step in ipairs(NEWS) do
  local key = step[1]
  local row = f.checks[key]
  local label = "step " .. n .. " (" .. key .. ")"
  equal(f.tourStep, n, label)
  equal(tour.step:GetText(), n .. " of 9 just added in 1.7.0", label .. " says where it is, and the release")
  equal(tour.title:GetText(), step[4], label .. " title: the option's name")
  equal(tour.text:GetText(), row.summary, label .. " text: its one-line summary")
  equal(tour.note:IsShown(), false, label .. " no note: it's on and in view")
  equal(f.selectedCategory .. " " .. f.selectedSub[f.selectedCategory], Tab(f, step[2]) .. " " .. step[3], label .. " on its tab and sub-tab")
  equal(row:IsVisible(), true, label .. " its row on show")
  Outlines(f, row, label)
  equal(tour.back.label:GetText() .. " " .. tour.nextButton.label:GetText(), (n == 1 and "Skip" or "Back") .. " " .. (n == #NEWS and "Done" or "Next"), label .. " buttons")
  equal(not Has(tour.text:GetText() .. tour.title:GetText(), "\226\128\148"), true, label .. " no em dash")
  -- Rows show no description while it runs.
  row:Fire("OnEnter")
  equal(f.footerHelp:IsShown(), false, label .. " no description from the rows")
  row:Fire("OnLeave")
  if n == 3 then
   tour.back:Click(); equal(f.tourStep .. " " .. f.selectedSub[f.selectedCategory], "2 style", "Back returns to step 2")
   f.keys:Fire("OnArrowPressed", "RIGHT"); equal(f.tourStep, 3, "the right arrow goes on")
   f.keys:Fire("OnArrowPressed", "LEFT"); equal(f.tourStep, 2, "the left arrow goes back")
   f.keys:Fire("OnEnterPressed"); equal(f.tourStep, 3, "Enter goes on")
  end
  if n == 5 then
   tour.nextButton:Click(); Flush()
   equal(f.selectedCategory, Tab(f, "actionBars"), "Next takes it to the next option's tab")
   tour.back:Click(); Flush()
   equal(f.selectedCategory .. " " .. f.selectedSub[f.selectedCategory], Tab(f, "appearance") .. " dark", "and Back to the one before's sub-tab")
  end
  if n < #NEWS then tour.nextButton:Click(); Flush() end
 end
 tour.nextButton:Click(); Flush()
 equal(f.touring or tour:IsShown() or f.tourStep ~= nil or f.tourSteps ~= nil, false, "Done ends it")
 equal(f.keys:HasFocus() or f.footerHelp:IsShown(), false, "and gives the keyboard and the footer back")
 equal(f.signature:IsShown() and f.reloadHint:IsShown(), true, "the footer as before")
 -- Then Take the tour is the layout's six again.
 f:StartTour(); Flush()
 equal(tour.step:GetText() .. " " .. tour.title:GetText(), "Step 1 of 6 Grouped tabs", "Take the tour afterwards: the layout's steps")
 f.keys:Fire("OnEscapePressed")
 -- Skip, Escape and closing /era end it.
 news:Click(); Flush(); tour.back:Click()
 equal(f.touring, false, "Skip on step 1 ends it")
 news:Click(); Flush(); f.keys:Fire("OnEscapePressed")
 equal(f.touring or tour:IsShown(), false, "Escape ends it")
 news:Click(); Flush(); f:Hide()
 equal(f.touring or tour:IsShown(), false, "closing /era ends it")
 f:Show(); Flush()
 equal(f.touring, false, "and it doesn't come back")
 -- Greyed options: shown greyed, outlined, with what they wait for.
 E.settings.unitFrames, E.settings.castBars, E.settings.darkMode = nil, nil, nil
 f:Hide(); f:Show(); Flush()
 news:Click(); Flush()
 local notes = {
  thickFrames = "Switch on Unit Frames first (Frames & Nameplates > Unit Frames).",
  roundedCastBars = "Switch on Cast Bars first (Casting).",
  darkBagButtons = "Switch on Dark Mode first (Appearance > Style).",
  castBarColour = "Switch on Cast Bars first.",
 }
 for n, step in ipairs(NEWS) do
  local key, row = step[1], f.checks[step[1]]
  local label = "greyed step " .. n .. " (" .. key .. ")"
  if notes[key] then
   equal(row.dependencyDisabled == true and row.alpha < 1, true, label .. " is greyed")
   equal(tour.note:IsShown() and tour.note:GetText(), notes[key], label .. " says what it waits for")
   Outlines(f, row, label)
  else
   equal(tour.note:IsShown(), false, label .. " waits for nothing: no note")
  end
  tour.nextButton:Click(); Flush()
 end
 equal(f.touring, false, "the greyed run ends too")
 -- Folded: Clean Minimap's Style shows only with Clean Minimap on, so its
 -- step outlines Clean Minimap, saying so.
 E.settings.cleanMinimap = nil
 f:Hide(); f:Show(); Flush()
 news:Click(); Flush()
 for _ = 1, 6 do tour.nextButton:Click(); Flush() end
 equal(f.tourStep .. " " .. tostring(f.checks.cleanMinimapStyle:IsShown()) .. " " .. tour.title:GetText(), "7 false Clean Minimap: Style", "the folded step")
 equal(tour.note:GetText(), "Shows once Clean Minimap is on.", "it says where it shows")
 Outlines(f, f.checks.cleanMinimap, "the folded step")
 f.keys:Fire("OnEscapePressed")
 -- From a search, or with the class tab open, it starts on its own pages.
 M.Results(f, "poison")
 news:Click(); Flush()
 equal(f.searching or f.searchBox:GetText() ~= "", false, "search cleared")
 equal(f.selectedCategory .. " " .. f.selectedSub[f.selectedCategory], Tab(f, "appearance") .. " style", "on the first option's page")
 for _, result in ipairs(f.results) do equal(result:IsShown(), false, "no result left on show") end
 f.keys:Fire("OnEscapePressed")
 Open(f, "class")
 news:Click(); Flush()
 equal(EraUIRogueTools == nil or not EraUIRogueTools:IsShown(), true, "no rogue tools window over it")
 f.keys:Fire("OnEscapePressed")
 -- A release with nothing new for this character: no Show me what's new.
 E.ReleaseVersion = function() return "1.5.5" end
 f:Hide(); f:Show(); Flush()
 equal(news:IsShown() or T.NewsCount() ~= 0, false, "nothing new: no button, no steps")
 equal(T.StartNews(f), false, "and nothing starts")
 equal(f.touring, false, "no walkthrough")
 E.ReleaseVersion = realRelease
 f:Hide(); f:Show(); Flush()
end

-- 1.7.1's walkthrough: Square Minimap alone. Its Square Size slider shows
-- only with it (SHOWN_WITH), so it goes with it: no step of its own.
do
 local E, f = Session("ROGUE")
 local Nav, T = E.SettingsNav, E.SettingsTour
 equal(table.concat(T.NewsKeys(f), ","), "squareMinimap", "1.7.1: one new option, Square Minimap")
 equal(Nav.ADDED.squareMinimapScale .. " " .. tostring(Nav.Lead("squareMinimapScale")), "1.7.1 false", "Square Size came with it, no step of its own")
 equal(T.NewsCount(), 1, "What's New's Show me: one step")
 local row = f.checks.squareMinimap
 E.settings.minimap = true
 f:Hide(); f:Show(); Flush()
 Open(f, "quests")
 equal(f.newsButton:IsShown(), true, "Show me what's new on show")
 f.newsButton:Click(); Flush()
 local tour = f.tour
 equal(f.touring and f.tourStep, 1, "it starts")
 equal(tour.step:GetText(), "1 of 1 just added in 1.7.1", "one step, and the release")
 equal(tour.title:GetText(), "Minimap: Square Minimap", "its name, under Minimap on the same page")
 equal(tour.text:GetText(), row.summary, "its one-line summary")
 equal(tour.note:IsShown(), false, "Minimap on: no note")
 equal(f.selectedCategory .. " " .. f.selectedSub[f.selectedCategory], Tab(f, "map") .. " main", "on Map & Minimap")
 equal(row:IsVisible(), true, "its row on show")
 Outlines(f, row, "Square Minimap's step")
 equal(tour.back.label:GetText() .. " " .. tour.nextButton.label:GetText(), "Skip Done", "one step: Skip and Done")
 tour.nextButton:Click(); Flush()
 equal(f.touring, false, "Done ends it")
 -- Minimap off: greyed, outlined, saying what it waits for.
 E.settings.minimap = false
 f:Hide(); f:Show(); Flush()
 f.newsButton:Click(); Flush()
 equal(row.dependencyDisabled == true and tour.note:IsShown() and tour.note:GetText(), "Switch on Minimap first.", "Minimap off: greyed, the note names Minimap")
 Outlines(f, row, "the greyed step")
 f.keys:Fire("OnEscapePressed")
 E.settings.minimap = true
 f:Hide(); f:Show(); Flush()
end

-- What's New's Show me (Tour.OpenNews): opens /era and starts it; never over
-- the setup walkthrough; a card due on that open waits for the next.
do
 local E, f = Session("PRIEST")
 local T = E.SettingsTour
 f:Hide()
 equal(T.OpenNews(), true, "Show me with /era closed")
 equal(f:IsShown() and f.touring and f.tourStep == 1 and f.tour.step:GetText(), "1 of 1 just added in 1.7.1", "/era opens at the first new option")
 f.keys:Fire("OnEscapePressed")
 equal(T.OpenNews() and f:IsShown() and f.tourStep, 1, "with /era open too")
 f.keys:Fire("OnEscapePressed")
 E.settings.layoutWelcome = 1; f:Hide()
 T.OpenNews(); Flush()
 equal(f.touring == true and f.welcoming == false and not f.welcome:IsShown(), true, "a card due on this open stays out of the way")
 equal(E.settings.layoutWelcome, 1, "without being used up")
 f.keys:Fire("OnEscapePressed"); f:Hide(); f:Show(); Flush()
 equal(f.welcoming, true, "it shows on the next open")
 f.welcome.later:Click()
 f:SetSetupMode(true); Flush()
 equal(T.OpenNews(), false, "never over the setup walkthrough")
 equal(f.setupMode == true and f.touring ~= true, true, "setup carries on")
 f:SetSetupMode(false); Flush()
 f:Hide(); f:SetSetupMode(true); f:Hide(); Flush()
 equal(T.NewsCount(), 1, "setup left closed: What's New's Show me is back")
 equal(T.OpenNews() and f.setupMode == false and f.touring, true, "setup left closed: settings open and it starts")
 f.keys:Fire("OnEscapePressed")
end

-- A new option on the class tab: its step points at the tab itself, as the
-- class page's boxes and conjure buttons never sit under the dim layer.
do
 local E, f = Session("HUNTER")
 local Nav, T = E.SettingsNav, E.SettingsTour
 Nav.ADDED.hunterFeed = "9.9.9"
 equal(table.concat(T.NewsKeys(f, "9.9.9"), ","), "hunterFeed", "a class option counts for its class")
 Open(f, "class")
 T.StartNews(f, "9.9.9"); Flush()
 equal(f.selectedCategory ~= Tab(f, "class") and f.tour.note:GetText(), "On your HUNTER tab.", "its step stays off the class page and says where it is")
 Outlines(f, f.tabs[Tab(f, "class")], "the class step")
 equal(f.tour.step:GetText(), "1 of 1 just added in 9.9.9", "a one-step walkthrough")
 f.tour.nextButton:Click(); Flush()
 equal(f.touring, false, "Done")
 Nav.ADDED.hunterFeed = nil
 -- Handed over to another addon: its row outlined greyed, saying who has it.
 Nav.ADDED.friendlyNameplates = "9.9.9"
 E.NamePlatesHandedOver = function() return true end
 f:RefreshDependencies()
 T.StartNews(f, "9.9.9"); Flush()
 equal(f.checks.friendlyNameplates.handedOver == true and f.tour.note:GetText(), E.SettingsRules.HANDED_OVER.friendlyNameplates, "a handed-over option says who has it")
 Outlines(f, f.checks.friendlyNameplates, "the handed-over step")
 f.keys:Fire("OnEscapePressed")
 Nav.ADDED.friendlyNameplates, E.NamePlatesHandedOver = nil, nil
 f:RefreshDependencies()
 -- An option low on a long page (the Stat Tracker's last tick, with it on):
 -- its step scrolls it into the middle of the page, all of it in view, and
 -- names it with the option it shows with.
 Nav.ADDED.statTrackerDurability = "9.9.9"
 E.settings.statTracker = true
 f:Hide(); f:Show(); Flush()
 T.StartNews(f, "9.9.9"); Flush()
 local row, s = f.checks.statTrackerDurability, f.settingsScroll
 equal(f.tour.title:GetText(), "Stat Tracker: Durability", "a row shown with its switch reads with its name")
 equal(s:GetVerticalScroll() > 0, true, "the page scrolled to it")
 local mid, rowMid = (s:GetTop() + s:GetBottom()) / 2, (row:GetTop() + row:GetBottom()) / 2
 equal(math.abs(mid - rowMid) < 1 or s:GetVerticalScroll() >= f.settingsScrollbar.high - .01, true, "into the middle (or as far as the page goes)")
 Outlines(f, row, "the low row")
 -- Half scrolled away (only code can: the wheel is the dim layer's): the
 -- outline stays inside the page's viewport.
 s:SetVerticalScroll(s:GetVerticalScroll() + s:GetTop() - row:GetTop() + row:GetHeight() / 2)
 local l, t, r, b = f.tourSteps[1].target(f)
 local cl, ct, cr, cb = Clip(f, row)
 equal(f:GetTop() - row:GetTop() < ct and string.format("%.1f %.1f %.1f %.1f", l, t, r, b), string.format("%.1f %.1f %.1f %.1f", cl, ct, cr, cb),
  "half scrolled away: the outline stays inside the page")
 f.keys:Fire("OnEscapePressed")
 Nav.ADDED.statTrackerDurability, E.settings.statTracker = nil, nil
 local mage, g = Session("MAGE")
 mage.SettingsNav.ADDED.hunterFeed = "9.9.9"
 equal(g.checks.hunterFeed ~= nil and g.checks.hunterFeed.classAllowed, false, "a mage has the hunter's row, not for its class")
 equal(#mage.SettingsTour.NewsKeys(g, "9.9.9"), 0, "so another class's option is no step for a mage")
end

-- In combat: What's new's walkthrough touches nothing protected and shows
-- no conjure button (the frame mock throws on a protected change).
do
 local E, f = Session("MAGE")
 local actions = {}
 for _, b in ipairs(S.frames) do if b.secure then actions[#actions + 1] = b end end
 S.combat = true
 for _, b in ipairs(actions) do b.shown = false end
 Open(f, "class")
 f.newsButton:Click(); Flush()
 equal(f.tourStep .. " " .. f.tour.step:GetText(), "1 1 of 1 just added in 1.7.1", "combat: 1.7.1's step")
 f.tour.nextButton:Click(); Flush()
 equal(f.touring, false, "the walkthrough of what's new runs in combat")
 -- And 1.7.0's nine, across every tab they're on.
 Open(f, "class")
 E.SettingsTour.StartNews(f, "1.7.0"); Flush()
 for n = 1, 9 do equal(f.tourStep, n, "combat step " .. n); f.tour.nextButton:Click(); Flush() end
 equal(f.touring, false, "1.7.0's walkthrough runs in combat too")
 f:Hide()
 equal(E.SettingsTour.OpenNews() and f:IsShown() and f.tourStep, 1, "and Show me opens /era in combat")
 f.keys:Fire("OnEscapePressed")
 for _, b in ipairs(actions) do equal(b:IsShown(), false, "combat never shows a conjure button") end
 S.combat = false
end

-- Show me what's new stands out: edge, fill and words in the class colour
-- (as Take the tour's edge and the window's title), and a soft glow round
-- it, EraUI's own flat bands, until this account opens the release's
-- walkthrough (either Show me). Saved per account (newsTourSeen; its backup
-- in Tools/TestPersistence.lua), one release at a time.
local function RGB(c) return string.format("%.2f,%.2f,%.2f", c[1], c[2], c[3]) end
for _, case in ipairs({{"MAGE", {.4, .8, 1}}, {"HUNTER", {.6, .8, .4}}, {"ROGUE", {1, .96, .41}}, {"DRUID", {1, .49, .04}},
 {"PALADIN", {.7, .7, .7}}}) do
 local class, want = case[1], case[2]
 local _, f = Session(class)
 local news = f.newsButton
 local label = class .. (class == "PALADIN" and " (no colour of its own: grey)" or "")
 equal(news:IsShown(), true, label .. ": Show me what's new on show")
 equal(RGB(news.borderColour), RGB(want), label .. ": its edge in the class colour")
 equal(RGB(news.label.colour), RGB(want), label .. ": its words too")
 equal(RGB(news.backdropColour), RGB({want[1] * .22, want[2] * .22, want[3] * .22}), label .. ": on Take the tour's class-tinted fill")
 equal(#news.glow.bands, 12, label .. ": three bands of four round it")
 for i, band in ipairs(news.glow.bands) do equal(RGB(band.fill), RGB(want), label .. ": glow piece " .. i .. " in the class colour") end
end

do
 local E, f = Session("ROGUE")
 local T = E.SettingsTour
 local saves = 0
 E.SaveSettings = function() saves = saves + 1 end
 local function Reopen() f:Hide(); f:Show(); Flush() end
 local news, glow = f.newsButton, f.newsButton.glow
 equal(E.settings.newsTourSeen, nil, "nothing opened yet")
 equal(news:IsShown() and glow:IsShown() and glow:IsVisible(), true, "Show me what's new glows until its walkthrough is opened")
 -- The bands: just outside the button's edge, 2 wide each, fading outwards,
 -- none over the button or over each other, filling the ring 6 round it.
 local L, Tp, Rt, Bt = news:GetLeft(), news:GetTop(), news:GetRight(), news:GetBottom()
 local BANDS = {{0, 2, .5}, {2, 4, .24}, {4, 6, .1}}
 local area, sides = 0, {}
 for i, piece in ipairs(glow.bands) do
  local pl, pt, pr, pb = piece:GetLeft(), piece:GetTop(), piece:GetRight(), piece:GetBottom()
  local side, from, to
  if pb >= Tp - .01 then side, from, to = "top", pb - Tp, pt - Tp
  elseif pt <= Bt + .01 then side, from, to = "bottom", Bt - pt, Bt - pb
  elseif pr <= L + .01 then side, from, to = "left", L - pr, L - pl
  elseif pl >= Rt - .01 then side, from, to = "right", pl - Rt, pr - Rt end
  local label = "glow piece " .. i
  equal(side ~= nil, true, label .. " outside the button, over none of it")
  local band = BANDS[math.floor((i - 1) / 4) + 1]
  equal(string.format("%s %.1f %.1f %.2f", side or "?", from or -1, to or -1, piece.fill[4]),
   string.format("%s %.1f %.1f %.2f", side or "?", band[1], band[2], band[3]), label .. " in its band, fading outwards")
  if side == "top" or side == "bottom" then
   equal(math.abs(pl - (L - band[2])) < .01 and math.abs(pr - (Rt + band[2])) < .01, true, label .. " runs the width, corners too")
  else
   equal(math.abs(pt - (Tp + band[1])) < .01 and math.abs(pb - (Bt - band[1])) < .01, true, label .. " fits between the top and bottom")
  end
  sides[side or "?"] = (sides[side or "?"] or 0) + 1
  area = area + (pr - pl) * (pt - pb)
  for j = i + 1, #glow.bands do
   local o = glow.bands[j]
   local hit = pl < o:GetRight() - .01 and o:GetLeft() < pr - .01 and pb < o:GetTop() - .01 and o:GetBottom() < pt - .01
   equal(hit, false, label .. " and piece " .. j .. " don't overlap")
  end
 end
 equal(sides.top .. sides.bottom .. sides.left .. sides.right, "3333", "every side has its three bands")
 local w, h = Rt - L, Tp - Bt
 equal(math.abs(area - ((w + 12) * (h + 12) - w * h)) < .01, true, "together they fill the ring 6 round the button")
 -- Where it sits: inside the window, clear of the X, the longest page
 -- title, the page's description and the sub-tabs; it takes no mouse.
 local close = f.closeButton
 equal(glow:GetLeft() == L - 6 and glow:GetRight() == Rt + 6 and glow:GetTop() == Tp + 6 and glow:GetBottom() == Bt - 6, true, "its frame is the ring's box")
 equal(glow:GetRight() <= close:GetLeft() + .01, true, "clear of the X")
 equal(glow:GetTop() <= f:GetTop() - 1, true, "inside the window's edge")
 equal(glow:GetLeft() > f.sectionTitle:GetLeft() + M.Glyphs("Frames & Nameplates", 24), true, "clear of the longest page title")
 equal(glow:GetBottom() >= f.sectionAbout:GetTop() - .01 or glow:GetLeft() >= f.sectionAbout:GetLeft() + 560, true, "clear of the page's description")
 equal(glow:GetBottom() > f.subTabStrip:GetTop(), true, "above the sub-tabs")
 local grabs = glow.mouse == true
 for _, piece in ipairs(glow.bands) do grabs = grabs or piece.mouse == true end
 equal(grabs, false, "the glow takes no mouse")
 -- It breathes gently: from full, between .35 and full, one breath about
 -- every 2.4 seconds, never a flash.
 equal(glow:GetAlpha(), 1, "it shows at full")
 local low, high, last, jump = 1, 0, glow:GetAlpha(), 0
 for _ = 1, 96 do
  glow:Fire("OnUpdate", .05)
  local a = glow:GetAlpha()
  low, high, jump = math.min(low, a), math.max(high, a), math.max(jump, math.abs(a - last))
  last = a
 end
 equal(low >= .35 - .001 and high <= 1 + .001 and high - low > .6, true, "it breathes between .35 and full")
 equal(jump < .05, true, "gently: a twentieth of a second never moves it more than .05")
 local before = glow:GetAlpha()
 glow:Fire("OnUpdate", 2 * math.pi / 2.6)
 equal(math.abs(glow:GetAlpha() - before) < .001, true, "one breath every 2.4 seconds")
 glow:Fire("OnUpdate", math.pi / 2.6)
 equal(math.abs(glow:GetAlpha() - before) > .01, true, "half a breath later it's elsewhere")
 Reopen()
 equal(glow:GetAlpha(), 1, "each /era open starts it at full again")
 -- Never in setup, nor without new options; hidden, so it stops.
 f:SetSetupMode(true); Flush()
 equal(news:IsShown() or glow:IsShown(), false, "setup: no button and no glow")
 f:SetSetupMode(false); Flush()
 equal(glow:IsShown() and glow:IsVisible(), true, "back after setup, still glowing")
 local release = E.ReleaseVersion
 E.ReleaseVersion = function() return "1.5.5" end
 Reopen()
 equal(news:IsShown() or glow:IsShown(), false, "nothing new: no button and no glow")
 E.ReleaseVersion = release
 Reopen()
 -- Opening the walkthrough: seen, saved at once, and the glow stops.
 news:Click(); Flush()
 equal(f.touring and f.tourStep, 1, "Show me what's new starts the walkthrough")
 equal(E.settings.newsTourSeen .. " " .. saves, "1.7.1 1", "this release's walkthrough saved as opened, at once")
 equal(glow:IsShown(), false, "the glow stops")
 f.keys:Fire("OnEscapePressed")
 equal(news:IsShown() and not glow:IsShown(), true, "Show me what's new stays, without the glow")
 Reopen()
 equal(news:IsShown() and not glow:IsShown(), true, "and it doesn't come back on the next /era")
 news:Click(); Flush(); f.keys:Fire("OnEscapePressed")
 equal(saves, 1, "opening it again saves nothing more")
 -- Skipped at once still counts as opened.
 E.settings.newsTourSeen = nil; Reopen()
 news:Click(); Flush(); f.tour.back:Click()
 equal(E.settings.newsTourSeen .. " " .. tostring(glow:IsShown()), "1.7.1 false", "Skip on step 1: opened all the same")
 -- One release at a time: an older release seen, this one still glows;
 -- another release's walkthrough leaves it be.
 E.settings.newsTourSeen = "1.7.0"; Reopen()
 equal(glow:IsShown(), true, "1.7.0's walkthrough seen: 1.7.1's still glows")
 E.settings.newsTourSeen = nil
 T.StartNews(f, "1.7.0"); Flush()
 equal(f.touring == true and tostring(E.settings.newsTourSeen) .. " " .. tostring(glow:IsShown()), "nil true", "1.7.0's walkthrough marks nothing: 1.7.1's still glows")
 f.keys:Fire("OnEscapePressed")
 -- What's New's Show me opens it too.
 f:Hide()
 equal(T.OpenNews(), true, "What's New's Show me")
 equal(E.settings.newsTourSeen .. " " .. tostring(glow:IsShown()), "1.7.1 false", "counts as opening it: the glow stops")
 f.keys:Fire("OnEscapePressed")
 T.StartNews(f, "1.7.0"); Flush()
 equal(E.settings.newsTourSeen .. " " .. tostring(glow:IsShown()), "1.7.1 false", "an older release's walkthrough afterwards never brings it back")
 f.keys:Fire("OnEscapePressed")
 -- The next release with new options glows again, until its own opens.
 E.SettingsNav.ADDED.trainer = "1.8.0"
 E.ReleaseVersion = function() return "1.8.0" end
 Reopen()
 equal(news:IsShown() and glow:IsShown(), true, "the next release with new options glows again")
 news:Click(); Flush()
 equal(f.tour.step:GetText() .. " | " .. E.settings.newsTourSeen .. " " .. tostring(glow:IsShown()), "1 of 1 just added in 1.8.0 | 1.8.0 false", "until its own walkthrough opens")
 f.keys:Fire("OnEscapePressed")
 E.SettingsNav.ADDED.trainer, E.ReleaseVersion = nil, release
 -- In a fight: it breathes, opens and stops, touching nothing protected.
 E.settings.newsTourSeen = nil; Reopen()
 S.combat = true
 glow:Fire("OnUpdate", .3)
 news:Click(); Flush()
 equal(E.settings.newsTourSeen .. " " .. tostring(glow:IsShown()), "1.7.1 false", "in a fight: opened, saved, and the glow stops")
 f.keys:Fire("OnEscapePressed")
 S.combat = false
 -- A class that can't be read (a secret value, never used as a key, as the
 -- client refuses it) or no class at all: grey, button and glow alike. A
 -- custom class colour wins, as everywhere in EraUI.
 local SECRET = {}
 local wasSecret, wasClass, wasMeta = issecretvalue, UnitClass, getmetatable(RAID_CLASS_COLORS)
 issecretvalue = function(v) return v == SECRET end
 setmetatable(RAID_CLASS_COLORS, {__index = function(_, k) if k == SECRET then error("a secret class used as a key") end end})
 UnitClass = function() return SECRET, SECRET end
 equal(RGB({E.SettingsRows.ClassColour()}), "0.70,0.70,0.70", "a secret class: grey")
 local probe = M.Frame("Frame", nil, UIParent)
 probe:SetSize(900, 600); probe:SetPoint("CENTER")
 T.Attach(probe)
 local pb = probe.newsButton
 equal(RGB(pb.borderColour) .. " " .. RGB(pb.label.colour) .. " " .. RGB(pb.glow.bands[1].fill), "0.70,0.70,0.70 0.70,0.70,0.70 0.70,0.70,0.70",
  "its button and glow grey, nothing indexed by it")
 equal(pb:IsShown() or pb.glow:IsShown(), false, "a new button and its glow wait to be told to show")
 UnitClass = function() return nil, nil end
 equal(RGB({E.SettingsRows.ClassColour()}), "0.70,0.70,0.70", "no class at all: grey")
 CUSTOM_CLASS_COLORS = {ROGUE = {r = .1, g = .2, b = .3}}
 UnitClass = function() return "Rogue", "ROGUE" end
 equal(RGB({E.SettingsRows.ClassColour()}), "0.10,0.20,0.30", "a custom class colour wins")
 CUSTOM_CLASS_COLORS = nil
 issecretvalue, UnitClass = wasSecret, wasClass
 setmetatable(RAID_CLASS_COLORS, wasMeta)
end
print("Settings welcome and walkthrough checks passed: " .. M.checks .. " assertions.")
