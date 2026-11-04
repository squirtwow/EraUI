-- The group finder's 1.x dressing (Classic look, spec 10 section 10): the
-- Group Browser and Create Listing pages fitted to the social window's
-- width W, with the old red buttons, label-frame drop downs, check box and
-- scroll bars; the play style drop down kept clear of the level ranges
-- tick; the category bars fitted; and EraUI's three round side tabs
-- (Create Listing, Group Browser, Who) in place of the game's own. Every
-- "done once" mark lives in a weak table here, never on the game's frames.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Social
local F = S.finder

local rowsDressed = Look.Weak()  -- a browse result row
local barsPlaced = Look.Weak()   -- the category view whose first bar was placed
local linesFaded = Look.Weak()   -- the listing's divider line

local GAME_TABS = Look.Words("ListingTab BrowsingTab WhoListingTab")
local BAR_GLOWS = Look.Words("SelectedTexture HighlightTexture")

local function Across(frame)
    return Look.Number(frame and frame:GetWidth()) or 0
end

-- The game's red button in the 1.x art, 124 x 22, at a bottom corner.
local function Corner(page, which, side, x)
    local red = page[which]
    if red then
        Look.SkinRedButton(red)
        red:SetSize(124, 22)
        Look.Pin(red, side, page, side, x, 9)
    end
end

-- Each frame a scroll box shows, through whichever walker the client has.
local function EachShown(scroll, fn)
    if type(scroll.ForEachFrame) == "function" then
        pcall(scroll.ForEachFrame, scroll, fn)
        return
    end
    if type(scroll.GetFrames) ~= "function" then return end
    local fine, shownNow = pcall(scroll.GetFrames, scroll)
    if fine and type(shownNow) == "table" then
        for i = 1, #shownNow do fn(shownNow[i]) end
    end
end

---------------------------------------------------------------------------
-- Group Browser
---------------------------------------------------------------------------

function F.DressBrowse(page, wide)
    Look.Fade(page.BackgroundArt)
    Look.Fade(Look.Path(page, "Inset", "CustomBG"))
    local kindDrop, whatDrop = page.CategoryDropdown, page.ActivityDropdown
    -- The two drop downs side by side (only when both are there).
    if kindDrop and whatDrop then
        Look.Pin(kindDrop, "TOPLEFT", page, "TOPLEFT", 41, -52)
        kindDrop:SetWidth(100)
        Look.DressDropdown(kindDrop, 14)
        Look.Pin(whatDrop, "LEFT", kindDrop, "RIGHT", 8, 0)
        whatDrop:SetWidth(wide - 222)
        Look.DressDropdown(whatDrop, 14)
        local again = page.RefreshButton
        if again then
            Look.Pin(again, "LEFT", whatDrop, "RIGHT", 6, 0)
            again:SetSize(28, 28)
        end
    end
    local options = page.OptionsButton
    if options then Look.Pin(options, "TOPRIGHT", page, "TOPRIGHT", -12, -30) end
    Corner(page, "SendMessageButton", "BOTTOMLEFT", 8)
    Corner(page, "GroupInviteButton", "BOTTOMRIGHT", -8)
    Look.SkinScrollBarsUnder(page, 2)
end

-- A result row, once: its name in the normal font, the roles text and the
-- first party icon pulled in for the narrower window.
local function FitResult(result)
    if type(result) ~= "table" or rowsDressed[result] then return end
    local shows = result.DataDisplay
    if shows == nil then return end
    rowsDressed[result] = true
    local named = result.Name
    if named and GameFontNormal then named:SetFontObject(GameFontNormal) end
    local alone, counted = shows.Solo, shows.Enumerate
    if alone and alone.RolesText then Look.Pin(alone.RolesText, "RIGHT", alone, "RIGHT", -78, 0) end
    if counted and counted.Icon1 then Look.Pin(counted.Icon1, "RIGHT", counted, "RIGHT", -16, 0) end
end

function F.DressRows(page)
    local scroll = page and page:IsShown() and page.ScrollBox
    if scroll then
        EachShown(scroll, function(result) pcall(FitResult, result) end)
    end
end

---------------------------------------------------------------------------
-- Create Listing
---------------------------------------------------------------------------

-- The line across the top (build 70009 on: a fixed 454 long for the game's
-- own 458-wide window, turned on its side) sticks out of the narrower one:
-- faded first, and only faded (its frame never hidden, moved or written).
local function FadeLine(page)
    local line = Look.Path(page, "DividerFrame", "Divider")
    if line and not linesFaded[line] then
        linesFaded[line] = true
        line:SetAlpha(0)
    end
end

local function RoleRows(page)
    local together = page.GroupRoleButtons
    if together then
        local poll, picker = together.RolePollButton, together.RoleDropdown
        if poll then Look.SkinRedButton(poll) end
        if picker then Look.DressDropdown(picker, 14) end
        Look.Pin(together, "TOPLEFT", page, "TOPLEFT", 64, -41)
    end
    local single = page.SoloRoleButtons
    if single then
        Look.Pin(single, "TOPLEFT", page, "TOPLEFT", 46, -41)
        local tank, healer, dps = single.Tank, single.Healer, single.DPS
        if healer and tank then Look.Pin(healer, "LEFT", tank, "RIGHT", 10, 0) end
        if dps and healer then Look.Pin(dps, "LEFT", healer, "RIGHT", 10, 0) end
    end
    local newcomers = page.NewPlayerFriendlyButton
    if newcomers then
        Look.Pin(newcomers, "TOPRIGHT", page, "TOPRIGHT", -28, -41)
        if newcomers.CheckButton then Look.SkinCheckBox(newcomers.CheckButton) end
    end
    local section = page.RolesSection
    Look.EachRegion(section, function(region)
        if region.SetTexCoord then
            Look.Fill(region, section)
            Look.Crop(region, 0, 454 / 704, 0, 102 / 144)
        end
    end)
end

function F.DressListing(page, wide)
    FadeLine(page)
    Corner(page, "BackButton", "BOTTOMLEFT", 8)
    Corner(page, "PostButton", "BOTTOMRIGHT", -8)
    RoleRows(page)
    local options = page.OptionsButton
    if options then Look.Pin(options, "TOPRIGHT", page, "TOPRIGHT", -12, -30) end
    local activityView = page.ActivityView
    if not activityView then return end
    local comment = activityView.Comment
    if comment then comment:SetWidth(wide - 40) end
    Look.SkinScrollBarsUnder(activityView, 2)
    local playStyle = activityView.PlayStyleDropdown
    if playStyle then
        Look.DressDropdown(playStyle, 14)
        Look.Pin(playStyle, "TOPLEFT", activityView, "TOPLEFT", 22, -10)
    end
end

-- The play style drop down (build 70170; a listing needs one) shares the top
-- row with the level ranges tick: as wide as the room left of the tick's
-- label allows, between 120 and its own 210. Nothing changes while the view
-- is hidden or any place read is a hidden value.
function F.FitPlayStyle(page)
    local activityView = page and page.ActivityView
    local playStyle = activityView and activityView.PlayStyleDropdown
    if not playStyle or not activityView:IsVisible() then return end
    local tick = activityView.LevelRangesCheckbox
    local words = tick and tick.Text
    local wordsLeft, viewLeft
    if words and tick:IsVisible() and words:IsShown() then
        local at = words:GetLeft()
        if Look.Secret(at) then return end
        wordsLeft = Look.Number(at)
    end
    if wordsLeft then
        local at = activityView:GetLeft()
        if Look.Secret(at) then return end
        viewLeft = Look.Number(at)
    end
    local room
    if wordsLeft and viewLeft then
        room = wordsLeft - viewLeft - 14 - 6
    else
        local span = activityView:GetWidth()
        if Look.Secret(span) or not Look.Number(span) then return end
        room = span - 14 - 6
    end
    local wanted = Look.Clamp(room - 22, 120, 210)
    local current = playStyle:GetWidth()
    if Look.Secret(current) then return end
    current = Look.Number(current)
    if current == nil or math.abs(current - wanted) > 0.5 then playStyle:SetWidth(wanted) end
end

-- The category bars: (W - 20) x 52, their glow and selection (W - 34) x 42,
-- the first one under the view's top (once).
function F.FitCategoryBars(page, wide)
    local holder = page and page.CategoryView
    local bars = holder and holder.CategoryButtons
    if type(bars) ~= "table" or bars[1] == nil then return end
    if not barsPlaced[holder] then
        barsPlaced[holder] = true
        Look.Pin(bars[1], "TOP", holder, "TOP", 0, -8)
    end
    for i = 1, #bars do
        local choice = bars[i]
        if math.abs(Across(choice) - (wide - 20)) > 0.5 then
            choice:SetSize(wide - 20, 52)
            for g = 1, #BAR_GLOWS do
                local glow = choice[BAR_GLOWS[g]]
                if glow then glow:SetSize(wide - 34, 42) end
            end
            local caption = choice.Label
            if caption and GameFontNormal then caption:SetFontObject(GameFontNormal) end
        end
    end
end

---------------------------------------------------------------------------
-- The side tabs
---------------------------------------------------------------------------

-- The finder turned to a tab, through the game's own tab handler (only when
-- it shows and isn't there already; never in a fight).
function ns.TurnGroupFinder(index)
    local finder = LFGParentFrame
    if not finder or not finder:IsShown() or Look.InFight() then return end
    if Look.Number(finder.selectedTab) == index then return end
    S.Call(_G["LFGParentFrameTab" .. index .. "_OnClick"])
end

-- The game's own round tabs: faded and deaf to the mouse (each written only
-- when it isn't so already).
function F.HideGameTabs(finder)
    for i = 1, #GAME_TABS do
        local theirs = finder[GAME_TABS[i]]
        if theirs then
            local fine, alpha = Look.Ask(theirs, "GetAlpha")
            if not fine or Look.Number(alpha) ~= 0 then theirs:SetAlpha(0) end
            local asked, takes = Look.Ask(theirs, "IsMouseEnabled")
            if asked and takes == true and not Look.InFight() then theirs:EnableMouse(false) end
        end
    end
end

-- Each of EraUI's tabs checked only while the finder is on its page (Who
-- never: it leads away).
function F.SyncTabs()
    local finder, mine = LFGParentFrame, F.tabs
    if not (finder and mine) then return end
    local onPage = Look.Number(finder.selectedTab)
    for i = 1, #mine do mine[i]:SetChecked(i ~= 3 and onPage == i) end
end

local function TabClicked(tab, index)
    S.Sound("IG_CHARACTER_INFO_TAB")
    if index == 3 then
        tab:SetChecked(false)
        if Look.InFight() then return end
        Look.HidePanel(LFGParentFrame)
        if type(ns.OpenWhoList) == "function" then ns.OpenWhoList() end
        return
    end
    if Look.InFight() then
        S.NotInFight()
    else
        ns.TurnGroupFinder(index)
    end
    F.SyncTabs()
end

function F.BuildTabs(finder)
    if F.tabs or Look.InFight() or type(ns.NewSideTab) ~= "function" then return end
    local made, above = {}, nil
    for i, spec in ipairs(S.who.SIDE_TABS or {}) do
        local tab = ns.NewSideTab(finder, i, above)
        tab:SetNormalTexture(spec.icon)
        tab.tooltip, tab.tooltipText = spec.tip(), spec.tip()
        if i == 1 then Look.Pin(tab, "TOPLEFT", finder, "TOPRIGHT", -3, -58) end
        tab:SetScript("OnClick", function(self) TabClicked(self, i) end)
        tab:Show()
        made[i] = tab
        above = tab
    end
    F.tabs = made
end
