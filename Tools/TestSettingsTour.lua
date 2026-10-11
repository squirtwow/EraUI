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
print("Settings welcome and walkthrough checks passed: " .. M.checks .. " assertions.")
