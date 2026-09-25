-- EraUI group finder.
-- The group finder in the social window's clothes. This client keeps Create
-- Listing, Group Browser and its who list in one window of its own, larger
-- than the old windows and drawn in the new style. While the classic Who tab
-- is the way in, that window is cut to the social window's size and wears the
-- old controls.
local _, EraUI = ...
local ns = EraUI.Classic

local ADDON_NAME = "Blizzard_GroupFinder_VanillaStyle"
local active = false
local dressed = false
local sideTabs = {}

local function Size()
    local social = FriendsFrame
    local width, height = social and social:GetWidth() or 0, social and social:GetHeight() or 0
    if width < 300 then width, height = 360, 424 end
    return math.floor(width + 0.5), math.floor(height + 0.5)
end

local function Red(button, width, height)
    if not button then return end
    if ns.SkinRedButton then ns.SkinRedButton(button) end
    if width then button:SetSize(width, height or 22) end
end

local function Hide(region)
    if region and region.SetAlpha then region:SetAlpha(0) end
end

local function QuietClientTabs(parent)
    for _, key in ipairs({ "ListingTab", "BrowsingTab", "WhoListingTab" }) do
        local tab = parent[key]
        if tab then
            if tab:GetAlpha() > 0 then tab:SetAlpha(0) end
            if tab:IsMouseEnabled() then tab:EnableMouse(false) end
        end
    end
end

local function TurnTo(index)
    local parent = _G["LFGParentFrame"]
    local turn = _G["LFGParentFrameTab" .. index .. "_OnClick"]
    if parent and parent:IsShown() and type(turn) == "function" and parent.selectedTab ~= index then turn() end
end

local function BuildSideTabs(parent)
    if #sideTabs > 0 or not ns.NewSideTab then return end
    local entries = {
        { index = 1, icon = "Interface/Icons/INV_Helmet_08", text = _G.LFG_LIST_TAB_1 or "Create Listing" },
        { index = 2, icon = "Interface/Icons/Achievement_General_StayClassy", text = _G.LFG_LIST_TAB_2 or "Group Browser" },
        { who = true, icon = "Interface/Icons/INV_OwlDragonMount", text = _G.LFG_LIST_TAB_3 or WHO or "Who" },
    }
    for i, entry in ipairs(entries) do
        local side = ns.NewSideTab(parent, i, sideTabs[i - 1])
        if i == 1 then
            side:ClearAllPoints()
            side:SetPoint("TOPLEFT", parent, "TOPRIGHT", -3, -58)
        end
        side:SetNormalTexture(entry.icon)
        side.tooltip = entry.text
        side.index = entry.index
        side:SetScript("OnClick", function(self)
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            if entry.who then
                self:SetChecked(false)
                if ns.OpenWhoList and not InCombatLockdown() then
                    ns.HidePanel(parent)
                    ns.OpenWhoList()
                end
                return
            end
            TurnTo(entry.index)
        end)
        side:Show()
        sideTabs[i] = side
    end
end

local function SyncSideTabs(parent)
    for _, side in ipairs(sideTabs) do
        side:SetChecked(side.index ~= nil and side.index == parent.selectedTab)
    end
end

local function DressBrowse(page, width)
    Hide(page.BackgroundArt)
    if page.Inset then Hide(page.Inset.CustomBG) end
    local category, activity, refresh = page.CategoryDropdown, page.ActivityDropdown, page.RefreshButton
    if category and activity then
        category:ClearAllPoints()
        category:SetPoint("TOPLEFT", page, "TOPLEFT", 41, -52)
        category:SetWidth(100)
        activity:ClearAllPoints()
        activity:SetPoint("LEFT", category, "RIGHT", 8, 0)
        activity:SetWidth(width - 66 - 100 - 8 - 6 - 30 - 12)
        if refresh then
            refresh:ClearAllPoints()
            refresh:SetPoint("LEFT", activity, "RIGHT", 6, 0)
            refresh:SetSize(28, 28)
        end
        if ns.DressDropdown then
            ns.DressDropdown(category, 14)
            ns.DressDropdown(activity, 14)
        end
    end
    if page.OptionsButton then
        page.OptionsButton:ClearAllPoints()
        page.OptionsButton:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -30)
    end
    Red(page.SendMessageButton, 124)
    Red(page.GroupInviteButton, 124)
    if page.SendMessageButton then
        page.SendMessageButton:ClearAllPoints()
        page.SendMessageButton:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 9)
    end
    if page.GroupInviteButton then
        page.GroupInviteButton:ClearAllPoints()
        page.GroupInviteButton:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 9)
    end
    if ns.SkinScrollBarsUnder then ns.SkinScrollBarsUnder(page, 2) end
end

local function DressListing(page, width)
    Red(page.BackButton, 124)
    Red(page.PostButton, 124)
    if page.BackButton then
        page.BackButton:ClearAllPoints()
        page.BackButton:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 9)
    end
    if page.PostButton then
        page.PostButton:ClearAllPoints()
        page.PostButton:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 9)
    end
    local group = page.GroupRoleButtons
    if group then
        Red(group.RolePollButton)
        if group.RoleDropdown and ns.DressDropdown then ns.DressDropdown(group.RoleDropdown, 14) end
    end
    local solo = page.SoloRoleButtons
    if solo then
        solo:ClearAllPoints()
        solo:SetPoint("TOPLEFT", page, "TOPLEFT", 46, -41)
        if solo.Tank and solo.Healer and solo.DPS then
            solo.Healer:ClearAllPoints()
            solo.Healer:SetPoint("LEFT", solo.Tank, "RIGHT", 10, 0)
            solo.DPS:ClearAllPoints()
            solo.DPS:SetPoint("LEFT", solo.Healer, "RIGHT", 10, 0)
        end
    end
    if group then
        group:ClearAllPoints()
        group:SetPoint("TOPLEFT", page, "TOPLEFT", 64, -41)
    end
    local friendly = page.NewPlayerFriendlyButton
    if friendly then
        friendly:ClearAllPoints()
        friendly:SetPoint("TOPRIGHT", page, "TOPRIGHT", -28, -41)
        if friendly.CheckButton and ns.SkinCheckbox then ns.SkinCheckbox(friendly.CheckButton) end
    end
    local band = page.RolesSection
    if band then
        for _, region in ipairs({ band:GetRegions() }) do
            if region.IsObjectType and region:IsObjectType("Texture") then
                region:ClearAllPoints()
                region:SetAllPoints(band)
                region:SetTexCoord(0, 454 / 704, 0, 102 / 144)
            end
        end
    end
    if page.OptionsButton then
        page.OptionsButton:ClearAllPoints()
        page.OptionsButton:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -30)
    end
    local view = page.ActivityView
    if view then
        if view.Comment then view.Comment:SetWidth(width - 40) end
        if ns.SkinScrollBarsUnder then ns.SkinScrollBarsUnder(view, 2) end
    end
end

local function FitCategories(page, width)
    local view = page.CategoryView
    local bars = view and view.CategoryButtons
    if type(bars) ~= "table" then return end
    local wide = width - 20
    local first = bars[1]
    if first and not first.fcuiRaised then
        first.fcuiRaised = true
        first:ClearAllPoints()
        first:SetPoint("TOP", view, "TOP", 0, -8)
    end
    for _, bar in ipairs(bars) do
        if math.abs(bar:GetWidth() - wide) > 0.5 then
            bar:SetSize(wide, 52)
            for _, key in ipairs({ "SelectedTexture", "HighlightTexture" }) do
                if bar[key] then bar[key]:SetSize(wide - 14, 42) end
            end
            if bar.Label and bar.Label.SetFontObject then bar.Label:SetFontObject("GameFontNormal") end
        end
    end
end

local function DressRow(row)
    if row.fcuiRow then return end
    local display = row.DataDisplay
    if not display then return end
    row.fcuiRow = true
    if row.Name and row.Name.SetFontObject then row.Name:SetFontObject("GameFontNormal") end
    local solo = display.Solo
    if solo and solo.RolesText then
        solo.RolesText:ClearAllPoints()
        solo.RolesText:SetPoint("RIGHT", solo, "RIGHT", -78, 0)
    end
    local all = display.Enumerate
    if all and all.Icon1 then
        all.Icon1:ClearAllPoints()
        all.Icon1:SetPoint("RIGHT", all, "RIGHT", -16, 0)
    end
end

local function DressRows(page)
    local box = page and page.ScrollBox
    if not (box and box.ForEachFrame and page:IsShown()) then return end
    pcall(box.ForEachFrame, box, DressRow)
end

local watcher
local function Fit()
    local parent = _G["LFGParentFrame"]
    if not active or not parent then return end
    local width, height = Size()
    if not InCombatLockdown() then
        if math.abs(parent:GetWidth() - width) > 0.5 or math.abs(parent:GetHeight() - height) > 0.5 then
            parent:SetSize(width, height)
        end
        if parent:GetAttribute("UIPanelLayout-defined") and parent:GetAttribute("UIPanelLayout-width") ~= width then
            parent:SetAttribute("UIPanelLayout-width", width)
            if parent:IsShown() and UpdateUIPanelPositions then pcall(UpdateUIPanelPositions, parent) end
        end
    end
    if not dressed then
        dressed = true
        if _G["LFGBrowseFrame"] then ns.SafeCall(DressBrowse, _G["LFGBrowseFrame"], width) end
        if _G["LFGListingFrame"] then ns.SafeCall(DressListing, _G["LFGListingFrame"], width) end
        BuildSideTabs(parent)
    end
    QuietClientTabs(parent)
    SyncSideTabs(parent)
    if _G["LFGListingFrame"] then FitCategories(_G["LFGListingFrame"], width) end
    DressRows(_G["LFGBrowseFrame"])
end

local function Watch()
    if watcher then return end
    watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:SetScript("OnEvent", function(_, _, name)
        if name == ADDON_NAME then ns.SafeCall(Fit) end
    end)
    watcher:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 0.1 then return end
        self.since = 0
        local parent = _G["LFGParentFrame"]
        if active and parent and parent:IsShown() then ns.SafeCall(Fit) end
    end)
end

function ns.WarmGroupFinder()
    if not active or InCombatLockdown() then return end
    if C_AddOns and C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded(ADDON_NAME) then
        pcall(C_AddOns.LoadAddOn, ADDON_NAME)
    end
    ns.SafeCall(Fit)
end

local function Apply()
    active = true
    Watch()
    ns.SafeCall(Fit)
end

local function Restore()
    active = false
    ns.needsReload = true
end

ns.RegisterModule("groupFinder", { apply = Apply, restore = Restore })
