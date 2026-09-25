-- EraUI professions book.
-- The professions overview as the old professions book: two parchment pages,
-- each primary profession with its round emblem, its name, its rank and the
-- small green bar, its two spells on their plates down the right; the
-- secondary professions as three short rows under them.
local _, EraUI = ...
local ns = EraUI.Classic

local active = false
local built = false

local SHEET = "Interface\\Spellbook\\ProfessionsBook"
local PAGE_LEFT = "Interface\\Spellbook\\Professions-Book-Left"
local PAGE_RIGHT = "Interface\\Spellbook\\Professions-Book-Right"
local BOOK_W, BOOK_H = 550, 525
local SECOND_LIFT = { 0, 15 }

local ROW_X, ROW_W = 80, 437
local PRIMARY_H, SECONDARY_H = 100, 52
local PRIMARY_Y = { -62, -168 }
local SECONDARY_Y = { -282, -352, -422 }
local SPELL_X = 288
local CLIENT_BUTTON_X = 15

local rows = {}
local sizeWas

local function Page()
    return ProfessionsFrame and ProfessionsFrame.BookPage
end

local function Content()
    local page = Page()
    return page and page.ProfessionsContentFrame
end

local function Font(fontString, name, fallback)
    local object = _G[name] or _G[fallback]
    if object then fontString:SetFontObject(object) end
end

local function NewBar(parent)
    local ok, bar = pcall(CreateFrame, "StatusBar", nil, parent, "ProfessionStatusBarTemplate")
    if not ok or not bar then
        bar = CreateFrame("StatusBar", nil, parent)
        bar:SetSize(95, 16)
        bar:SetStatusBarTexture("Interface\\Spellbook\\Professions-Progress-Fill")
        bar.rankText = bar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        bar.rankText:SetPoint("CENTER", 0, 2)
    end
    if bar.capped then bar.capped:Hide() end
    bar:SetStatusBarColor(0, 1, 0)
    return bar
end

local function NewRow(content, primary, y, lift)
    local row = CreateFrame("Frame", nil, content)
    row:SetSize(ROW_W, primary and PRIMARY_H or SECONDARY_H)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", ROW_X, y)
    row.primary = primary

    row.name = row:CreateFontString(nil, "ARTWORK")
    row.rank = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.rank:SetJustifyH("LEFT")
    row.bar = NewBar(row)
    row.missingHeader = row:CreateFontString(nil, "ARTWORK")
    row.missingText = row:CreateFontString(nil, "ARTWORK")
    Font(row.missingText, "SubSpellFont", "GameFontHighlightSmall")
    row.missingText:SetJustifyH("LEFT")
    row.missingText:SetTextColor(0.1, 0.05, 0.05)

    if primary then
        local ring = row:CreateTexture(nil, "ARTWORK", nil, 1)
        ring:SetTexture(SHEET)
        ring:SetTexCoord(0.43359375, 0.72265625, 0.14843750, 0.72656250)
        ring:SetSize(72, 72)
        ring:SetPoint("TOPLEFT", row, "TOPLEFT", 7, -12)
        row.ring = ring
        local icon = row:CreateTexture(nil, "ARTWORK", nil, 0)
        icon:SetPoint("TOPLEFT", ring, "TOPLEFT", 8, -8)
        icon:SetPoint("BOTTOMRIGHT", ring, "BOTTOMRIGHT", -8, 8)
        row.icon = icon

        Font(row.name, "QuestTitleFontBlackShadow", "GameFontNormalLarge")
        row.name:SetJustifyH("LEFT")
        row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 100, -8)
        row.rank:SetPoint("TOPLEFT", row, "TOPLEFT", 100, -56 + (lift or 0))
        row.rank:SetWidth(182)
        row.bar:SetPoint("TOPLEFT", row.rank, "BOTTOMLEFT", 14, -5)

        Font(row.missingHeader, "QuestTitleFontBlackShadow", "GameFontNormalLarge")
        row.missingHeader:SetTextColor(0.85, 0.7, 0.6)
        row.missingHeader:SetPoint("TOPLEFT", row, "TOPLEFT", 120, -20)
        row.missingText:SetWidth(305)
        row.missingText:SetPoint("TOPLEFT", row.missingHeader, "BOTTOMLEFT", 0, -1)
    else
        row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 16, 2)
        row.rank:SetPoint("BOTTOMLEFT", row.bar, "TOPLEFT", -14, 4)
        row.rank:SetPoint("BOTTOMRIGHT", row.bar, "TOPRIGHT", 25, 4)
        Font(row.name, "QuestFont_Shadow_Small", "GameFontNormal")
        row.name:SetJustifyH("LEFT")
        row.name:SetTextColor(1, 0.82, 0)
        row.name:SetShadowColor(0, 0, 0)
        row.name:SetPoint("BOTTOMLEFT", row.rank, "TOPLEFT", 0, 2)
        row.name:SetPoint("BOTTOMRIGHT", row.rank, "TOPRIGHT", 0, 2)

        Font(row.missingHeader, "QuestFont_Large", "GameFontNormalLarge")
        row.missingHeader:SetTextColor(0.15, 0.1, 0.1)
        row.missingHeader:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -15)
        row.missingText:SetWidth(250)
        row.missingText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    end
    return row
end

local function RankTitle(maxRank)
    local ranks = PROFESSION_RANKS
    if type(ranks) ~= "table" or not maxRank then return "" end
    local title = ""
    for _, entry in ipairs(ranks) do
        title = entry[2] or title
        if maxRank <= (entry[1] or 0) then break end
    end
    return title or ""
end

local MISSING = {
    { header = "PROFESSIONS_FIRST_PROFESSION", text = "PROFESSIONS_MISSING_PROFESSION" },
    { header = "PROFESSIONS_SECOND_PROFESSION", text = "PROFESSIONS_MISSING_PROFESSION" },
    { header = "PROFESSIONS_COOKING", text = "PROFESSIONS_COOKING_MISSING" },
    { header = "PROFESSIONS_FISHING", text = "PROFESSIONS_FISHING_MISSING" },
    { header = "PROFESSIONS_FIRST_AID", text = "PROFESSIONS_FIRST_AID_MISSING" },
}

local function FillRow(row, index, slot)
    local name, texture, rank, maxRank, rankModifier, _
    if index and GetProfessionInfo then
        name, texture, rank, maxRank, _, _, _, rankModifier = GetProfessionInfo(index)
    end
    local known = name ~= nil
    row.name:SetShown(known)
    row.rank:SetShown(known)
    row.bar:SetShown(known)
    row.missingHeader:SetShown(not known)
    row.missingText:SetShown(not known)
    if row.icon then
        if known and texture then
            row.icon:SetTexture(texture)
            row.icon:SetDesaturated(false)
        else
            row.icon:SetTexture("Interface\\Icons\\INV_Scroll_04")
        end
        if ns.RoundIcon then ns.RoundIcon(row.icon, 1) end
    end
    if not known then
        local words = MISSING[slot] or MISSING[1]
        row.missingHeader:SetText(_G[words.header] or "")
        row.missingText:SetText(_G[words.text] or "")
        return
    end
    row.name:SetText(name)
    row.rank:SetText(RankTitle(maxRank))
    rank, maxRank = rank or 0, maxRank or 0
    row.bar:SetMinMaxValues(0, math.max(1, maxRank))
    row.bar:SetValue(rank)
    if row.bar.rankText then
        if rankModifier and rankModifier > 0 then
            row.bar.rankText:SetFormattedText(TRADESKILL_RANK_WITH_MODIFIER or "%d (+%d)/%d", rank, rankModifier, maxRank)
        else
            row.bar.rankText:SetFormattedText(TRADESKILL_RANK or "%d/%d", rank, maxRank)
        end
    end
end

local function FillRows()
    if not built or not GetProfessions then return end
    local prof1, prof2, faid, fish, cook = GetProfessions()
    FillRow(rows[1], prof1, 1)
    FillRow(rows[2], prof2, 2)
    FillRow(rows[3], cook, 3)
    FillRow(rows[4], fish, 4)
    FillRow(rows[5], faid, 5)
end

local function FadeCard(card)
    for _, key in ipairs({ "Background", "ProfessionName", "specialization", "missingHeader", "missingText", "Rank", "icon", "IconBorder" }) do
        local region = card[key]
        if region and region.SetAlpha then region:SetAlpha(0) end
    end
    local bar = card.StatusBar
    if bar then
        bar:SetAlpha(0)
        if bar.EnableMouse then bar:EnableMouse(false) end
    end
end

local function DressSpellButton(button)
    if not button or button.fcuiPlate then return end
    local plate = button:CreateTexture(nil, "BACKGROUND")
    plate:SetTexture(SHEET)
    plate:SetTexCoord(0.00390625, 0.42578125, 0.14843750, 0.46875000)
    plate:SetSize(108, 41)
    plate:SetPoint("LEFT", button, "RIGHT", 1, 0)
    button.fcuiPlate = plate
    if button.IconTextureOverlay then button.IconTextureOverlay:SetAlpha(0) end
    if button.IconTexture and button.OutlineMask and button.IconTexture.RemoveMaskTexture then
        pcall(button.IconTexture.RemoveMaskTexture, button.IconTexture, button.OutlineMask)
    end
end

local function DressUnlearn(card, content, y)
    local button = card.UnlearnButton
    if not button then return end
    button:ClearAllPoints()
    button:SetPoint("CENTER", content, "TOPLEFT", ROW_X + 100 - 15, y - 76)
    if button.Icon then
        button.Icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        button.Icon:SetSize(16, 16)
        button.Icon:SetAlpha(0.75)
    end
    if button.Overlay then button.Overlay:SetAlpha(0) end
    local pad = card.GamepadUnlearnButton
    if pad then
        pad:ClearAllPoints()
        pad:SetPoint("RIGHT", button, "LEFT", -2, 0)
    end
end

local function PlaceCards()
    local content = Content()
    if not content or InCombatLockdown() then return false end
    for i = 1, 2 do
        local card = content["PrimaryProfession" .. i]
        if card then
            local y = PRIMARY_Y[i]
            card:ClearAllPoints()
            card:SetSize(170, PRIMARY_H)
            local lift = SECOND_LIFT[i] or 0
            card:SetPoint("TOPLEFT", content, "TOPLEFT", ROW_X + SPELL_X - CLIENT_BUTTON_X, y - 5 + lift)
            FadeCard(card)
            DressSpellButton(card.SpellButton1)
            DressSpellButton(card.SpellButton2)
            DressUnlearn(card, content, y + lift)
        end
    end
    for i = 1, 3 do
        local card = content["SecondaryProfession" .. i]
        if card then
            card:ClearAllPoints()
            card:SetSize(ROW_W, SECONDARY_H)
            card:SetPoint("TOPLEFT", content, "TOPLEFT", ROW_X, SECONDARY_Y[i])
            FadeCard(card)
            local previous
            for n = 1, 4 do
                local button = card["SpellButton" .. n]
                if button then
                    DressSpellButton(button)
                    button:ClearAllPoints()
                    if previous then
                        button:SetPoint("TOPRIGHT", previous, "TOPLEFT", -109, 0)
                    else
                        button:SetPoint("TOPRIGHT", card, "TOPRIGHT", -109, -6)
                    end
                    previous = button
                end
            end
        end
    end
    return true
end

local function Build()
    local page, content = Page(), Content()
    if built or not page or not content then return built end
    local left = page:CreateTexture(nil, "BACKGROUND", nil, 2)
    left:SetTexture(PAGE_LEFT)
    left:SetPoint("TOPLEFT", page, "TOPLEFT", 7, -25)
    local right = page:CreateTexture(nil, "BACKGROUND", nil, 2)
    right:SetTexture(PAGE_RIGHT)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    rows.art = { left, right }
    for i = 1, 2 do rows[i] = NewRow(content, true, PRIMARY_Y[i], SECOND_LIFT[i]) end
    for i = 1, 3 do rows[2 + i] = NewRow(content, false, SECONDARY_Y[i]) end
    built = true
    return true
end

local SPELL_LOW, SPELL_HIGH = 15, 56
local function TightenSpells()
    local content = Content()
    if not content or InCombatLockdown() then return end
    for i = 1, 2 do
        local card = content["PrimaryProfession" .. i]
        local first, second = card and card.SpellButton1, card and card.SpellButton2
        if first and second and first:IsShown() and second:IsShown() then
            for _, button in ipairs({ first, second }) do
                local point, rel, relPoint, x, y = button:GetPoint(1)
                if point == "BOTTOMLEFT" and y then
                    local want
                    if math.abs(y - 60) < 0.5 then want = SPELL_HIGH elseif math.abs(y - 10) < 0.5 then want = SPELL_LOW end
                    if want then button:SetPoint(point, rel, relPoint, x, want) end
                end
            end
        end
    end
end

local function ShowOurs(on)
    if not built then return end
    for _, tex in ipairs(rows.art or {}) do tex:SetShown(on) end
    for i = 1, 5 do
        if rows[i] then rows[i]:SetShown(on) end
    end
end

local function TellManager(frame, width, height)
    if not sizeWas.attrs then
        sizeWas.attrs = { frame:GetAttribute("UIPanelLayout-width"), frame:GetAttribute("UIPanelLayout-height") }
    end
    local wantWidth, wantHeight = width or sizeWas.attrs[1], height or sizeWas.attrs[2]
    if frame:GetAttribute("UIPanelLayout-width") == wantWidth and frame:GetAttribute("UIPanelLayout-height") == wantHeight then return end
    frame:SetAttribute("UIPanelLayout-width", wantWidth)
    frame:SetAttribute("UIPanelLayout-height", wantHeight)
    if frame:IsShown() and UpdateUIPanelPositions then pcall(UpdateUIPanelPositions, frame) end
end

local function FitWindow(width, height)
    local frame = ProfessionsFrame
    if not frame or InCombatLockdown() then return false end
    if width then
        if not sizeWas then sizeWas = { frame:GetWidth(), frame:GetHeight() } end
        if math.abs(frame:GetWidth() - width) > 0.5 or math.abs(frame:GetHeight() - height) > 0.5 then
            frame:SetSize(width, height)
        end
        TellManager(frame, width, height)
    elseif sizeWas then
        if math.abs(frame:GetHeight() - sizeWas[2]) > 0.5 then frame:SetHeight(sizeWas[2]) end
        if frame:GetWidth() < sizeWas[1] - 0.5 then frame:SetWidth(sizeWas[1]) end
        TellManager(frame, nil, nil)
    end
    return true
end

local function FillTabIcons()
    local frame = ProfessionsFrame
    if not frame then return end
    local function Fill(tab)
        local icon = tab and tab.Icon
        if not icon then return end
        local extent = tab.interiorExtent or 50
        if math.abs((icon:GetWidth() or 0) - extent) > 0.5 then
            icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
            icon:SetSize(extent, extent)
        end
    end
    Fill(frame.ProfessionsOverviewTab)
    for _, tab in ipairs(frame.rightProfessionTabs or {}) do Fill(tab) end
end

local tabToggle
local function TabsOpen() return ns.db and ns.db.professionTabs and true or false end

local function SyncTabs()
    local frame = ProfessionsFrame
    if not frame then return end
    local open = TabsOpen()
    local function Set(tab)
        if not tab then return end
        local alpha = open and 1 or 0
        if math.abs((tab:GetAlpha() or 1) - alpha) > 0.01 then tab:SetAlpha(alpha) end
        if tab:IsMouseEnabled() ~= open then tab:EnableMouse(open) end
    end
    Set(frame.ProfessionsOverviewTab)
    for _, tab in ipairs(frame.rightProfessionTabs or {}) do Set(tab) end
    if tabToggle then
        local close = frame.CloseButton
        local level = math.min(10000, (close and close:GetFrameLevel() or (frame:GetFrameLevel() + 600)) + 1)
        if tabToggle:GetFrameLevel() ~= level then tabToggle:SetFrameLevel(level) end
    end
    if tabToggle and tabToggle.open ~= open then
        tabToggle.open = open
        local name = open and "PrevPage" or "NextPage"
        tabToggle:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "-Up")
        tabToggle:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "-Down")
    end
end

local function TabToggle()
    local frame = ProfessionsFrame
    if tabToggle or not frame then return end
    tabToggle = CreateFrame("Button", "EraUIClassicProfessionTabsToggle", frame)
    tabToggle:SetSize(24, 24)
    tabToggle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -15, -28)
    tabToggle:SetFrameLevel(frame:GetFrameLevel() + 40)
    tabToggle:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    tabToggle:SetScript("OnClick", function()
        ns.db.professionTabs = not TabsOpen()
        if ns.MirrorSave then ns.MirrorSave() end
        SyncTabs()
    end)
    tabToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(TRADE_SKILLS or "Professions")
        GameTooltip:Show()
    end)
    tabToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function BackToBook()
    local frame, page = ProfessionsFrame, Page()
    if not frame or not page or InCombatLockdown() then return false end
    page:Show()
    if frame.CraftingPage then frame.CraftingPage:Hide() end
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    if title and TRADE_SKILLS then title:SetText(TRADE_SKILLS) end
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    if portrait then portrait:SetTexture("Interface/ICONS/INV_SideTab_Professions_c60") end
    for _, tab in ipairs(frame.rightProfessionTabs or {}) do
        if tab.SelectedTexture then tab.SelectedTexture:Hide() end
    end
    local overview = frame.ProfessionsOverviewTab
    if overview and overview.SelectedTexture then overview.SelectedTexture:Show() end
    return true
end

local function NotInAFight()
    if UIErrorsFrame and ERR_NOT_IN_COMBAT then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1) end
end

local bookTabs
local function BookTabs()
    local frame, page = ProfessionsFrame, Page()
    if not frame or not page or not ns.NewBookTab then return end
    local on = ns.SpellBookActive and ns.SpellBookActive() and true or false
    if not bookTabs then
        if not on then return end
        bookTabs = {}
        for i = 1, 3 do bookTabs[i] = ns.NewBookTab(page, i, bookTabs[i - 1]) end
        bookTabs[1]:ClearAllPoints()
        bookTabs[1]:SetPoint("CENTER", frame, "BOTTOMLEFT", 70, -7)
        bookTabs[1]:SetText(SPELLBOOK or "Spellbook")
        bookTabs[2]:SetText(TRADE_SKILLS or "Professions")
        bookTabs[2]:SetEnabled(false)
        for i, tab in ipairs(bookTabs) do
            tab:SetScript("OnClick", function()
                if i == 2 then return end
                if InCombatLockdown() then NotInAFight() return end
                PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
                HideUIPanel(frame)
                ns.ShowSpellBookBank(i == 3)
            end)
        end
    end
    local pet = on and ns.SpellBookPetTitle and ns.SpellBookPetTitle() or nil
    if pet and bookTabs[3]:GetText() ~= pet then bookTabs[3]:SetText(pet) end
    bookTabs[1]:SetShown(on)
    bookTabs[2]:SetShown(on)
    bookTabs[3]:SetShown(on and pet ~= nil)
end

local function ToCraft()
    local frame, page = ProfessionsFrame, Page()
    local crafting = frame and frame.CraftingPage
    if not frame or not page or not crafting or InCombatLockdown() then return false end
    if not page:IsShown() and crafting:IsShown() then return true end
    page:Hide()
    crafting:Show()
    local info = C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    local id = info and info.professionID
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    if title and info and info.professionName and info.professionName ~= "" then title:SetText(info.professionName) end
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    if portrait and id and C_TradeSkillUI.GetTradeSkillTexture then
        local icon = C_TradeSkillUI.GetTradeSkillTexture(id)
        if icon then portrait:SetTexture(icon) end
    end
    local overview = frame.ProfessionsOverviewTab
    if overview and overview.SelectedTexture then overview.SelectedTexture:Hide() end
    for _, tab in ipairs(frame.rightProfessionTabs or {}) do
        if tab.SelectedTexture then tab.SelectedTexture:SetShown(id ~= nil and tab.skillLine == id) end
    end
    return true
end

local tabsQuieted = false
local function QuietTabs()
    local frame = ProfessionsFrame
    if tabsQuieted or not frame or not (EventRegistry and EventRegistry.UnregisterCallback) then return end
    local tabs = {}
    for _, tab in ipairs(frame.rightProfessionTabs or {}) do tabs[#tabs + 1] = tab end
    if frame.ProfessionsOverviewTab then tabs[#tabs + 1] = frame.ProfessionsOverviewTab end
    if #tabs == 0 then return end
    tabsQuieted = true
    for _, tab in ipairs(tabs) do
        pcall(EventRegistry.UnregisterCallback, EventRegistry, "ProfessionsFrame.Show", tab)
    end
    ns.Persist("professions: " .. #tabs .. " tabs taken off the show list")
end

function ns.OpenProfessionsBook()
    if InCombatLockdown() then NotInAFight() return false end
    if not ProfessionsFrame and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_ProfessionsBook")
        pcall(C_AddOns.LoadAddOn, "Blizzard_Professions")
    end
    local frame = ProfessionsFrame
    if not frame then return false end
    if active then QuietTabs() end
    BackToBook()
    if not frame:IsShown() then ShowUIPanel(frame) end
    return true
end

local watch
local function StartWatch()
    if watch then return end
    watch = CreateFrame("Frame")
    watch:RegisterEvent("SKILL_LINES_CHANGED")
    watch:RegisterEvent("SPELLS_CHANGED")
    watch:RegisterEvent("PLAYER_REGEN_ENABLED")
    watch:RegisterEvent("TRADE_SKILL_SHOW")
    watch:RegisterEvent("ADDON_LOADED")
    watch:SetScript("OnEvent", function(self, event)
        if event == "ADDON_LOADED" then
            if active and ProfessionsFrame then QuietTabs() end
            return
        end
        if event == "TRADE_SKILL_SHOW" then
            local frame = ProfessionsFrame
            local now = GetTime()
            if not tabsQuieted and frame and frame:IsShown() and active and self.bookWhenShut
                and now - (self.shutAt or 0) < 0.5 then
                self.restoreBook = true
            else
                self.ownCastAt = now
                self.wantCraft = now
                if active and frame and ToCraft() then
                    local tick = self:GetScript("OnUpdate")
                    if tick then
                        self.since = 1
                        tick(self, 0)
                    end
                end
            end
        end
        self.dirty = true
    end)
    local placed = false
    watch:SetScript("OnUpdate", function(self, elapsed)
        local shut = ProfessionsFrame and not ProfessionsFrame:IsShown()
        if shut then
            local book = Page()
            self.shutAt = GetTime()
            local castNow = (GetTime() - (self.ownCastAt or 0)) < 3
            self.bookWhenShut = (book and book:IsShown() or (not self.everShown and not castNow)) and true or false
            local ownCast = (GetTime() - (self.ownCastAt or 0)) < 3
            if active and book and not book:IsShown() and not InCombatLockdown() and not ownCast then
                if BackToBook() then
                    self.bookWhenShut = true
                    ns.Persist("professions: shut window turned to the book")
                end
            end
        elseif ProfessionsFrame then
            self.everShown = true
            self.ownCastAt = nil
        end
        if self.wasShut and not shut then self.since = 1 end
        self.wasShut = shut and true or false
        if self.restoreBook and BackToBook() then self.restoreBook = false end
        if self.wantCraft then
            if GetTime() - self.wantCraft > 3 then
                self.wantCraft = nil
            elseif active and ProfessionsFrame and not self.restoreBook and ToCraft() then
                if ProfessionsFrame:IsShown() then self.wantCraft = nil end
            end
        end
        self.since = (self.since or 0) + elapsed
        if self.since < 0.1 then return end
        self.since = 0
        if not ProfessionsFrame and not self.loadTried and not InCombatLockdown()
            and (active or (ns.TradeSkillActive and ns.TradeSkillActive())) then
            if C_AddOns and C_AddOns.LoadAddOn then
                self.loadTried = true
                local okBook, book = pcall(C_AddOns.LoadAddOn, "Blizzard_ProfessionsBook")
                local okMain, main = pcall(C_AddOns.LoadAddOn, "Blizzard_Professions")
                ns.Persist(string.format("professions: early load book %s/%s main %s/%s frame %s", tostring(okBook),
                    tostring(book), tostring(okMain), tostring(main), tostring(ProfessionsFrame ~= nil)))
            end
        end
        local frame = ProfessionsFrame
        local page = Page()
        if not frame or not page then return end
        if active then
            QuietTabs()
            FillTabIcons()
        end
        TabToggle()
        SyncTabs()
        BookTabs()
        local bookUp = active and page:IsVisible() and true or false
        local crafting = frame.CraftingPage
        local tradeOn = ns.TradeSkillActive and ns.TradeSkillActive()
        local craftUp = not bookUp and tradeOn and crafting and crafting:IsVisible() and true or false
        if bookUp then
            FitWindow(BOOK_W, BOOK_H)
        elseif craftUp then
            FitWindow(ns.TradeSkillWindowSize())
        elseif frame:IsVisible() then
            FitWindow(nil)
        elseif self.bookWhenShut then
            if active then FitWindow(BOOK_W, BOOK_H) end
        elseif tradeOn then
            FitWindow(ns.TradeSkillWindowSize())
        end
        if ns.ShowTradeSkill then ns.ShowTradeSkill(craftUp) end
        if active then
            if not built then Build() end
            if built and (self.dirty or not placed) then
                local was = placed
                placed = PlaceCards() or placed
                if placed ~= was then ns.Persist("professions: cards placed, combat " .. tostring(InCombatLockdown())) end
                FillRows()
                self.dirty = false
            end
            self.placedNow = placed
            ShowOurs(placed)
            if placed then TightenSpells() end
        end
    end)
end
ns.StartProfessionsWatch = StartWatch

local function Apply()
    active = true
    StartWatch()
    local tick = watch and watch:GetScript("OnUpdate")
    if tick then
        for _ = 1, 3 do
            watch.since = 1
            tick(watch, 0)
        end
        watch.since = 1
        ns.Persist(string.format("professions: first pass, fight %s, window %s", tostring(InCombatLockdown()), tostring(ProfessionsFrame ~= nil)))
    end
end

local function Restore()
    if not active then return end
    active = false
    ns.needsReload = true
end

ns.RegisterModule("professionsBook", { apply = Apply, restore = Restore })
