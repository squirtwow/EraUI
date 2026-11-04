-- What the classic spellbook shows on each refresh: the view (player or pet
-- tab, the school line, the search) and its page, the tabs, the page line
-- and the twelve slots (icon, name and rank, the ring's colour, the dim
-- shade, the usable tint and the cooldown). Out of a fight a refresh also
-- lines the secure layer up with the page drawn (Look/SpellLayer.lua); in a
-- fight it draws what the secure clicks chose.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Spells

---------------------------------------------------------------------------
-- The view and its page (each list remembers its page this session)
---------------------------------------------------------------------------

function S.SetView(pet, line, search)
    S.pageOf[S.PageKey(S.view)] = S.page
    S.view.pet, S.view.line, S.view.search = pet and true or false, line or 1, search or ""
    S.page = S.pageOf[S.PageKey(S.view)] or 1
    local box = S.book and S.book.Search
    if box and S.view.search == "" and (box:GetText() or "") ~= "" then box:SetText("") end
end

function S.SetPage(page)
    S.page = page
    S.pageOf[S.PageKey(S.view)] = page
end

-- A page forward (1) or back (-1), out of a fight, while there is one.
function S.TurnPage(step)
    if Look.InFight() then return end
    local target = S.page + step
    if target < 1 or target > S.PageCount(S.drawn or {}) then return end
    S.SetPage(target)
    S.Sound("IG_ABILITY_PAGE_TURN")
    S.Refresh()
end

local function Guide()
    local modules = EraUI.modules
    local guide = type(modules) == "table" and modules.TrainingGuide
    if type(guide) ~= "table" or type(guide.Enabled) ~= "function" then return nil end
    local fine, on = pcall(guide.Enabled, guide)
    return (fine and on) and guide or nil
end
S.Guide = Guide

local function CloseGuide()
    local book = S.book
    if not (book and book.trainingShown) then return end
    local modules = EraUI.modules
    local guide = type(modules) == "table" and modules.TrainingGuide
    if guide and type(guide.Close) == "function" then Look.Try(guide.Close, guide) end
end

---------------------------------------------------------------------------
-- Tabs and their clicks
---------------------------------------------------------------------------

-- A school tab: in a fight only its look is put back (the secure pad over
-- it did the switching); out of a fight the line it stands for.
function S.SchoolTabClick(tab, i)
    if Look.InFight() then
        tab:SetChecked(not S.view.pet and S.view.line == i and not S.book.trainingShown)
        return
    end
    CloseGuide()
    S.SetView(false, i, S.view.search)
    S.Sound("IG_ABILITY_PAGE_TURN")
    S.Refresh()
end

function S.GuideTabClick(tab)
    if Look.InFight() then
        tab:SetChecked(S.book.trainingShown and true or false)
        return
    end
    tab:SetChecked(false)
    local guide = Guide()
    if not guide then return end
    S.Sound("IG_ABILITY_PAGE_TURN")
    if type(guide.BindBook) == "function" then Look.Try(guide.BindBook, guide, S.book) end
    if type(guide.Toggle) == "function" then Look.Try(guide.Toggle, guide, S.book) end
end

-- The book tabs (also the default click of ns.NewBookTab): Professions
-- opens the professions book (and closes this one when it opened); the
-- Spellbook and pet tabs switch the book's pages, out of a fight.
function S.OnBookTab(tab)
    if tab == S.bookTabs[2] then
        local opened = type(ns.OpenProfessionsBook) == "function" and ns.OpenProfessionsBook()
        if opened then
            S.Sound("IG_ABILITY_PAGE_TURN")
            S.Hide()
        end
        return
    end
    if Look.InFight() then return end
    CloseGuide()
    S.SetView(tab == S.bookTabs[3], S.view.line, S.view.search)
    S.Sound("IG_ABILITY_PAGE_TURN")
    S.Refresh()
end

local function DrawBookTabs()
    local tabs, view = S.bookTabs, S.view
    local petTitle = S.PetTitle()
    if view.pet and not petTitle then S.SetView(false, view.line, view.search) end
    for i = 1, 3 do Look.Shown(tabs[i], i < 3 or petTitle ~= nil) end
    if petTitle then tabs[3]:SetText(petTitle) end
    tabs[1]:SetEnabled(view.pet or S.book.trainingShown)
    tabs[2]:SetEnabled(true)
    tabs[3]:SetEnabled(not view.pet)
end

local function DrawSchoolTabs()
    local view, book = S.view, S.book
    local lines = view.pet and {} or S.Lines()
    if not view.pet and lines[1] and not lines[view.line] then S.SetView(false, 1, view.search) end
    local last
    for i, tab in ipairs(S.skillTabs) do
        local line = lines[i]
        if line then
            tab:SetNormalTexture(line.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            tab.tooltip = line.name
            tab:SetChecked(view.line == i and not book.trainingShown)
            last = tab
        end
        Look.Shown(tab, line ~= nil)
    end
    local guide = book.TrainTab
    if last then
        Look.Pin(guide, "TOPLEFT", last, "BOTTOMLEFT", 0, -17)
    else
        Look.Pin(guide, "TOPLEFT", book, "TOPRIGHT", -32, -65)
    end
    Look.Shown(guide, not view.pet and Guide() ~= nil)
end

---------------------------------------------------------------------------
-- A slot
---------------------------------------------------------------------------

local function Colour(colour, r, g, b)
    if type(colour) == "table" and type(colour.GetRGB) == "function" then return colour:GetRGB() end
    return r, g, b
end

local function Ring(entry)
    if entry.passive then
        entry.ring:SetVertexColor(0, 0, 0)
    elseif ns.DarkWindowsOn and ns.DarkWindowsOn() and ns.DarkGrey then
        entry.ring:SetVertexColor(ns.DarkGrey())
    else
        entry.ring:SetVertexColor(1, 1, 1)
    end
end

-- In a fight, a spell that can't be cast now is greyed (no power:
-- blue-grey); out of a fight, and whenever the game won't say, white.
function S.Tint(entry)
    local r, g, b = 1, 1, 1
    local usable = C_SpellBook and C_SpellBook.IsSpellBookItemUsable
    if Look.InFight() and entry.slot and not entry.passive and type(usable) == "function" then
        local fine, can, noPower = pcall(usable, entry.slot, S.Bank(entry.pet))
        if fine and not Look.Secret(can) and not Look.Secret(noPower) and not can then
            if noPower then r, g, b = 0.5, 0.5, 1 else r, g, b = 0.4, 0.4, 0.4 end
        end
    end
    entry.icon:SetVertexColor(r, g, b)
end

local function ClearCooldown(cooldown)
    if type(cooldown.Clear) == "function" then cooldown:Clear() else cooldown:SetCooldown(0, 0) end
end

-- The swipe: the game's secret-safe duration object when it has one, else
-- start and duration (cleared when off, unreadable or missing).
function S.Cooldown(entry)
    local cooldown = entry.cooldown
    if not entry.slot then return ClearCooldown(cooldown) end
    local bank = S.Bank(entry.pet)
    local byDuration = C_SpellBook and C_SpellBook.GetSpellBookItemCooldownDuration
    if type(byDuration) == "function" and type(cooldown.SetCooldownFromDurationObject) == "function" then
        local fine, duration = pcall(byDuration, entry.slot, bank)
        if fine and duration ~= nil and pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration, true) then return end
    end
    local info = S.Call("GetSpellBookItemCooldown", entry.slot, bank)
    if type(info) ~= "table" or (not Look.Secret(info.isEnabled) and info.isEnabled == false) then
        return ClearCooldown(cooldown)
    end
    local start, length, rate = Look.Number(info.startTime), Look.Number(info.duration), Look.Number(info.modRate)
    if not (start and length) or Look.Secret(info.modRate) then return ClearCooldown(cooldown) end
    cooldown:SetCooldown(start, length, rate or 1)
end

function S.Cooldowns()
    if not (S.book and S.book:IsShown()) then return end
    for _, entry in ipairs(S.slots) do
        S.Cooldown(entry)
        S.Tint(entry)
    end
end

local function Empty(entry)
    entry.slot, entry.passive = nil, nil
    entry.icon:Hide()
    entry.name:Hide()
    entry.sub:Hide()
    entry.glow:Hide()
    ClearCooldown(entry.cooldown)
    S.Shade(entry, false)
    Ring(entry)
end

local function DrawSlot(entry, slot, pet, live)
    local info = slot and S.Info(slot, pet)
    entry.pet = pet
    if not info then return Empty(entry) end
    local passive = S.Yes(info.isPassive)
    entry.slot, entry.passive = slot, passive
    entry.icon:SetTexture(info.iconID)
    entry.icon:SetDesaturated(S.Yes(info.isOffSpec))
    entry.icon:Show()
    local sub = S.Text(info.subName) or ""
    if sub == "" and passive then sub = S.Say("SPELL_PASSIVE", "Passive") end
    entry.name:SetText(S.Text(info.name) or "")
    entry.name:SetTextColor(Colour(passive and PASSIVE_SPELL_FONT_COLOR or NORMAL_FONT_COLOR, 1, 0.82, 0))
    entry.name:Show()
    entry.sub:SetText(sub)
    entry.sub:Show()
    S.PlaceName(entry, sub ~= "")
    Ring(entry)
    S.Shade(entry, not live and not passive)
    S.Tint(entry)
    S.Cooldown(entry)
end

---------------------------------------------------------------------------
-- The refresh
---------------------------------------------------------------------------

local function DrawPage(list, live)
    local book = S.book
    local pages = S.PageCount(list)
    local page = Look.Clamp(S.page, 1, pages)
    book.PageText:SetText(string.format(S.Say("PAGE_NUMBER", "Page %d"), page))
    book.PrevPage:SetEnabled(page > 1)
    book.NextPage:SetEnabled(page < pages)
    local first = (page - 1) * S.PER_PAGE
    for i, entry in ipairs(S.slots) do DrawSlot(entry, list[first + i], S.view.pet, live) end
end

-- The list to draw and whether the page is live (its spells clickable).
local function Chosen(fight)
    if fight then
        local box = S.ViewBox()
        if box then return box.list, true end
        return S.ListFor(S.view, not S.view.pet and S.TopRankOn()), false
    end
    if S.dirty then S.BuildPages() end
    local box = S.ViewBox()
    if box then
        S.SetPage(Look.Clamp(S.page, 1, S.PageCount(box.list)))
        S.ApplyView()
        return box.list, true
    end
    return S.ListFor(S.view, not S.view.pet and S.TopRankOn()), true
end

function S.Refresh()
    local book = S.book
    if not (S.active and book) then return end
    if book.trainingShown then
        local guide = Guide()
        if guide and type(guide.Refresh) == "function" then Look.Try(guide.Refresh, guide) end
        return
    end
    local fight = Look.InFight()
    -- In a fight a secure pad may have switched the tab or turned the page:
    -- read that first, so the tabs and the ranks tick drawn below follow it
    -- (the pad's click queues only this one refresh).
    if fight then S.ReadSecure() end
    book.Ranks:SetChecked(not S.TopRankOn())
    Look.Shown(book.Ranks, not S.view.pet)
    if book.Search.SetEnabled then book.Search:SetEnabled(not fight) end
    if fight then book.Search:ClearFocus() end
    DrawBookTabs()
    DrawSchoolTabs()
    local list, live = Chosen(fight)
    book.Title:SetText(S.view.pet and (S.PetTitle() or S.Say("PET", "Pet")) or S.Say("SPELLBOOK", "Spellbook"))
    S.drawn = list
    DrawPage(list, live)
end
