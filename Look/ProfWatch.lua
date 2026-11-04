-- The professions watch: one watcher, started by the professions book or
-- the trade skill window, never stopped. It keeps the game's Professions
-- window in the classic shape:
--   * its size: the book's 550 x 525 on the overview page, the trade skill
--     window's on a profession's page (out of a fight only);
--   * its tabs: the overview and profession tabs down its right side hidden
--     while the book is on, EraUI's Spellbook / Professions / pet tabs along
--     its bottom while the classic spellbook is on;
--   * the remembered profession: the game recasts the last profession when
--     its window opens; EraUI casts nothing, so the shut window forgets it
--     (once per closing, out of a fight) and turns to the book, and the
--     micro button opens the book as in 1.5.0;
--   * the cards placed and the rows filled (Look/ProfBook.lua).
-- Registry "professionsBook" (from /era's Professions, a reload setting);
-- public ns.OpenProfessionsBook and ns.StartProfessionsWatch.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Spells
local P = Look.Prof

local SHAPE = { book = { 550, 525 } }
local OPENING = 3 -- seconds a profession has to show after TRADE_SKILL_SHOW
local kept = {}   -- the window's own size and panel layout, read the first time EraUI changed them
local OVERVIEW_ICON = "Interface/ICONS/INV_SideTab_Professions_c60"

do
    local engine = type(ns.DB_DEFAULTS) == "table" and ns.DB_DEFAULTS or nil
    if engine and engine.professionsBook == nil then engine.professionsBook = true end
end

local function Clock()
    return type(GetTime) == "function" and (Look.Number(GetTime()) or 0) or 0
end

local function ProfWindow()
    return _G.ProfessionsFrame
end

local function TradeOn()
    return type(ns.TradeSkillActive) == "function" and ns.TradeSkillActive() == true
end

local function TradeShape()
    if type(ns.TradeSkillWindowSize) == "function" then return ns.TradeSkillWindowSize() end
    return 362, 444
end

-- The game's red "not in a fight" line.
local function Refused()
    local errors = _G.UIErrorsFrame
    if errors and _G.ERR_NOT_IN_COMBAT then errors:AddMessage(_G.ERR_NOT_IN_COMBAT, 1, 0.1, 0.1) end
end

local function TitleOf(window)
    local holder = window.TitleContainer
    return holder and holder.TitleText or nil
end

local function PortraitOf(window)
    local holder = window.PortraitContainer
    return holder and holder.portrait or nil
end

-- Both of the window's addons loaded (protected); what each answered.
local function LoadBoth()
    local load = (C_AddOns and C_AddOns.LoadAddOn) or _G.LoadAddOn
    if type(load) ~= "function" then return "no loader" end
    local said = {}
    for _, name in ipairs({ "Blizzard_ProfessionsBook", "Blizzard_Professions" }) do
        local fine, loaded = pcall(load, name)
        said[#said + 1] = name .. "=" .. tostring(fine and loaded)
    end
    return table.concat(said, ", ")
end

---------------------------------------------------------------------------
-- The two pages, and forgetting the remembered profession
---------------------------------------------------------------------------

local function Remembered(window)
    return type(window.RecastSelectedProfession) == "function" and window.selectedSkillLine ~= nil
end

-- True when nothing is remembered any more.
local function Forget(window)
    if not Remembered(window) then return true end
    if Look.InFight() or type(window.SelectBookPage) ~= "function" then return false end
    Look.Try(window.SelectBookPage, window)
    return not Remembered(window)
end

local function Selected(tab, on)
    if tab and tab.SelectedTexture then Look.Shown(tab.SelectedTexture, on) end
end

-- Back to the book's page (out of a fight).
function P.ToBook(window)
    if Look.InFight() or not window.BookPage then return end
    window.BookPage:Show()
    Look.Shown(window.CraftingPage, false)
    local title, portrait = TitleOf(window), PortraitOf(window)
    if title then title:SetText(S.Say("TRADE_SKILLS", "Professions")) end
    if portrait then portrait:SetTexture(OVERVIEW_ICON) end
    for _, tab in ipairs(window.rightProfessionTabs or {}) do Selected(tab, false) end
    Selected(window.ProfessionsOverviewTab, true)
end

-- To a profession's crafting page (out of a fight; true when it worked).
local function ToCrafting(window)
    local book, craft = window.BookPage, window.CraftingPage
    if Look.InFight() or not (book and craft) then return false end
    if craft:IsShown() and not book:IsShown() then return true end
    book:Hide()
    craft:Show()
    local fine, base = Look.Ask(C_TradeSkillUI, "GetBaseProfessionInfo")
    base = fine and type(base) == "table" and base or {}
    local named, skill = S.Text(base.professionName), Look.Number(base.professionID)
    local title, portrait = TitleOf(window), PortraitOf(window)
    if title and named and named ~= "" then title:SetText(named) end
    if portrait and skill then
        local asked, texture = Look.Ask(C_TradeSkillUI, "GetTradeSkillTexture", skill)
        if asked and texture then portrait:SetTexture(texture) end
    end
    Selected(window.ProfessionsOverviewTab, false)
    for _, tab in ipairs(window.rightProfessionTabs or {}) do Selected(tab, skill ~= nil and tab.skillLine == skill) end
    return true
end

-- The spellbook's Professions tab: the window on its book page. Nothing is
-- cast from EraUI's code: a remembered profession is forgotten first, and
-- if that can't be done the window stays shut. An open window is only
-- turned to the book.
local function OpenBook()
    if Look.InFight() then
        Refused()
        return false
    end
    if not ProfWindow() then Look.Try(LoadBoth) end
    local window = ProfWindow()
    if not window then return false end
    local wasOpen = window:IsShown()
    if not wasOpen and not Forget(window) then return false end
    P.ToBook(window)
    if wasOpen then return true end
    if type(ShowUIPanel) == "function" then Look.Try(ShowUIPanel, window) else window:Show() end
    return true
end
ns.OpenProfessionsBook = OpenBook

---------------------------------------------------------------------------
-- The window's size (out of a fight only)
---------------------------------------------------------------------------

-- The panel layout's width and height (nil: the window's own, none set).
local function Layout(window, width, height)
    if window:GetAttribute("UIPanelLayout-width") ~= width then window:SetAttribute("UIPanelLayout-width", width) end
    if window:GetAttribute("UIPanelLayout-height") ~= height then window:SetAttribute("UIPanelLayout-height", height) end
end

local function SizeTo(window, width, height)
    if Look.InFight() or not width then return end
    local nowW, nowH = Look.Number(window:GetWidth()) or 0, Look.Number(window:GetHeight()) or 0
    if not kept.width then
        kept.width, kept.height = nowW, nowH
        kept.layoutW, kept.layoutH = window:GetAttribute("UIPanelLayout-width"), window:GetAttribute("UIPanelLayout-height")
    end
    local changed = math.abs(nowW - width) > 0.5 or math.abs(nowH - height) > 0.5
    if changed then window:SetSize(width, height) end
    if width == kept.width and height == kept.height then
        Layout(window, kept.layoutW, kept.layoutH)
    else
        Layout(window, width, height)
    end
    if changed and window:IsShown() and type(UpdateUIPanelPositions) == "function" then
        Look.Try(UpdateUIPanelPositions, window)
    end
end

local function Size(window)
    if Look.InFight() then return end
    local bookUp = P.bookOn and window.BookPage:IsVisible()
    local craft = window.CraftingPage
    local craftUp = not window.BookPage:IsVisible() and TradeOn() and craft ~= nil and craft:IsVisible()
    if not window:IsShown() then
        if P.bookOn and P.bookNext then SizeTo(window, SHAPE.book[1], SHAPE.book[2])
        elseif TradeOn() then SizeTo(window, TradeShape()) end
        return
    end
    if bookUp then
        SizeTo(window, SHAPE.book[1], SHAPE.book[2])
    elseif craftUp then
        SizeTo(window, TradeShape())
    elseif kept.width then
        SizeTo(window, math.max(kept.width, Look.Number(window:GetWidth()) or 0), kept.height)
    end
end

---------------------------------------------------------------------------
-- The tabs
---------------------------------------------------------------------------

-- Down its right side: the overview tab, then one for each profession.
local function EveryTab(window)
    local every = { window.ProfessionsOverviewTab }
    for _, side in ipairs(window.rightProfessionTabs or {}) do every[#every + 1] = side end
    return every
end

-- Hidden while the book is on (closing the window turns back to it). With
-- the book off they are the only way back to the game's own overview.
local function SideTabs(window)
    local wanted = P.bookOn ~= true
    local alpha = wanted and 1 or 0
    for _, side in ipairs(EveryTab(window)) do
        if (Look.Number(side:GetAlpha()) or 1) ~= alpha then side:SetAlpha(alpha) end
        local guarded = Look.InFight() and side:IsProtected()
        if side:IsMouseEnabled() ~= wanted and not guarded then side:EnableMouse(wanted) end
    end
end

local function BookTabClick(tab)
    if tab == P.bookTabs[2] then return end
    if Look.InFight() then return Refused() end
    S.Sound("IG_ABILITY_PAGE_TURN")
    Look.HidePanel(ProfWindow())
    if type(ns.ShowSpellBookBank) == "function" then ns.ShowSpellBookBank(tab == P.bookTabs[3]) end
end

local function MakeBookTabs(window)
    P.bookTabs = {}
    local before
    for i = 1, 3 do
        local tab = ns.NewBookTab(window.BookPage, i, before)
        tab:SetScript("OnClick", BookTabClick)
        P.bookTabs[i] = tab
        before = tab
    end
    Look.Pin(P.bookTabs[1], "CENTER", window, "BOTTOMLEFT", 70, -7)
    P.bookTabs[1]:SetText(S.Say("SPELLBOOK", "Spellbook"))
    P.bookTabs[2]:SetText(S.Say("TRADE_SKILLS", "Professions"))
    P.bookTabs[2]:SetEnabled(false)
end

local function BookTabs(window)
    local spellsOn = type(ns.SpellBookActive) == "function" and ns.SpellBookActive() == true
    if spellsOn and not P.bookTabs then MakeBookTabs(window) end
    local tabs = P.bookTabs
    if not tabs then return end
    local petTitle = spellsOn and type(ns.SpellBookPetTitle) == "function" and ns.SpellBookPetTitle() or nil
    Look.Shown(tabs[1], spellsOn)
    Look.Shown(tabs[2], spellsOn)
    Look.Shown(tabs[3], spellsOn and petTitle ~= nil)
    if petTitle then tabs[3]:SetText(petTitle) end
end

---------------------------------------------------------------------------
-- The watch
---------------------------------------------------------------------------

local function CraftPageUp(window)
    local craft = window.CraftingPage
    return not window.BookPage:IsVisible() and craft ~= nil and craft:IsVisible()
end

local function Rows()
    if not P.bookOn or not P.Build() then return end
    if (P.dirty or not P.placed) and P.PlaceCards() then
        if not P.placed then S.Note("professions: cards placed") end
        P.placed = true
        P.Fill()
        P.DarkPass(false)
        P.dirty = false
    end
    P.ShowRows(P.placed == true)
    if P.placed then P.PullTogether() end
end

-- The 0.1 s step.
local function Tenth()
    local window = ProfWindow()
    if not window and not P.loadTried and not Look.InFight() and (P.bookOn or TradeOn()) then
        P.loadTried = true
        S.Note("professions: loaded " .. tostring((select(2, Look.Try(LoadBoth)))))
        window = ProfWindow()
    end
    if not (window and window.BookPage) then return end
    SideTabs(window)
    BookTabs(window)
    Size(window)
    if type(ns.ShowTradeSkill) == "function" then Look.Try(ns.ShowTradeSkill, CraftPageUp(window)) end
    Rows()
end
P.Step = Tenth

-- The shut window: forgets once per closing and turns to the book, out of
-- a fight and not while a profession is opening.
local function Shut(window, opening)
    P.wasShown = false
    local onBook = window.BookPage ~= nil and window.BookPage:IsShown()
    P.bookNext = onBook or (not P.everShown and not opening)
    local remember = Remembered(window) and not P.forgotThisClosing
    if P.bookOn and not Look.InFight() and not opening and (remember or not onBook) then
        local forgot = false
        if remember then
            P.forgotThisClosing = true
            forgot = Forget(window)
        end
        P.ToBook(window)
        P.bookNext = true
        S.Note("professions: shut window turned to the book" .. (forgot and ", last profession forgotten" or ""))
    end
    if opening and P.bookOn then ToCrafting(window) end
end

-- Every frame: the shut window; a window that just opened is shaped at
-- once; the 0.1 s step.
local waited = 0
local function EveryFrame(_, elapsed)
    local window = ProfWindow()
    if window and window:IsShown() then
        local justOpened = not P.wasShown
        P.wasShown, P.everShown, P.openingAt, P.forgotThisClosing = true, true, nil, false
        if justOpened then
            waited = 0
            Look.Try(Tenth)
        end
    elseif window then
        Shut(window, P.openingAt ~= nil and Clock() - P.openingAt < OPENING)
    end
    waited = waited + (Look.Number(elapsed) or 0)
    if waited >= 0.1 then
        waited = 0
        Look.Try(Tenth)
    end
end

local function OnEvent(_, event)
    P.dirty = true
    if event ~= "TRADE_SKILL_SHOW" then return end
    P.openingAt = Clock()
    local window = ProfWindow()
    if P.bookOn and window and ToCrafting(window) then Look.Try(Tenth) end
end

local function StartWatch()
    if P.watch then return end
    local watch = CreateFrame("Frame")
    for _, event in ipairs(Look.Words("SKILL_LINES_CHANGED SPELLS_CHANGED PLAYER_REGEN_ENABLED TRADE_SKILL_SHOW")) do
        Look.Listen(watch, event)
    end
    watch:SetScript("OnEvent", OnEvent)
    watch:SetScript("OnUpdate", EveryFrame)
    P.watch = watch
end
ns.StartProfessionsWatch = StartWatch

---------------------------------------------------------------------------
-- The registry entry
---------------------------------------------------------------------------

ns.RegisterModule("professionsBook", {
    apply = function()
        P.bookOn = true
        StartWatch()
        for _ = 1, 3 do Look.Try(Tenth) end
        S.Note("professions: book applied")
    end,
    restore = function()
        P.bookOn = false
        ns.needsReload = true
    end,
})
