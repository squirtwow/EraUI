-- The classic spellbook's art and controls (EraUIClassicSpellBook): the
-- parchment in four pieces, EraUI's own black cover for Black Pages, the
-- round book icon, title, page number and arrows, the red X, the twelve
-- slots, the school tabs and the Training Guide tab, the three book tabs,
-- the search box and the "Show all spell ranks" tick. Built once, out of a
-- fight, the first time the book is wanted. The secure layer the clicks go
-- through is Look/SpellLayer.lua; what each piece shows, Look/SpellDraw.lua.
-- The fields set on the book are the ones the Training Guide
-- (Modules/TrainingGuide.lua) uses: Search, Ranks, PageText, PrevPage,
-- NextPage, Buttons, SkillTabs, TrainTab, Title, BookTabs.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Spells

---------------------------------------------------------------------------
-- The parchment, cover, icon, title and page line
---------------------------------------------------------------------------

local PIECES = { { "sbTopLeft", 256, "TOPLEFT" }, { "sbTopRight", 128, "TOPRIGHT" },
    { "sbBotLeft", 256, "BOTTOMLEFT" }, { "sbBotRight", 128, "BOTTOMRIGHT" } }

local function Dark(texture, role)
    if ns.DarkWindowArt then ns.DarkWindowArt(texture, role) end
end

local function Parchment(book)
    for _, piece in ipairs(PIECES) do
        local sheet = Look.OwnTexture(book, piece[1], "BACKGROUND", 0)
        Look.Art(sheet, piece[1])
        sheet:SetSize(piece[2], 256)
        Look.Pin(sheet, piece[3], book, piece[3], 0, 0)
        Dark(sheet, "trim")
    end
    -- Black Pages' near black over the parchment alone (22 to 343 across,
    -- 75 to 430 down); made hidden with no colour.
    local cover = Look.OwnTexture(book, "cover", "BACKGROUND", 1)
    cover:SetSize(322, 356)
    Look.Pin(cover, "TOPLEFT", book, "TOPLEFT", 22, -75)
    cover:Hide()
    Dark(cover, "cover")
    S.cover = cover
    local icon = Look.OwnTexture(book, "icon", "ARTWORK")
    Look.Art(icon, "sbIcon")
    icon:SetSize(58, 58)
    Look.Pin(icon, "TOPLEFT", book, "TOPLEFT", 10, -8)
    Look.RoundIcon(icon, 2)
    local title = Look.OwnLabel(book, "title", "GameFontNormal", "ARTWORK")
    Look.Pin(title, "CENTER", book, "CENTER", 6, 230)
    title:SetText(S.Say("SPELLBOOK", "Spellbook"))
    book.Title = title
    local pageText = Look.OwnLabel(book, "pageText", "GameFontBlack", "ARTWORK")
    pageText:SetWidth(102)
    pageText:SetJustifyH("RIGHT")
    Look.Pin(pageText, "CENTER", book, "BOTTOMLEFT", 182, 105)
    if ns.DarkWindowText then ns.DarkWindowText(pageText) end
    book.PageText = pageText
end

local function Arrow(book, way, x)
    local arrow = Look.Build("Button", book, nil, { size = { 32, 32 } })
    Look.Pin(arrow, "CENTER", book, "BOTTOMLEFT", x, 105)
    for state, look in pairs({ Normal = "Up", Pushed = "Down", Disabled = "Disabled" }) do
        Look.StateArt(arrow, state, "sb" .. way .. look)
    end
    local glow = Look.StateArt(arrow, "Highlight", "mouseHighlight")
    if glow then glow:SetBlendMode("ADD") end
    arrow:SetScript("OnClick", function() S.TurnPage(way == "Next" and 1 or -1) end)
    return arrow
end

local function Close(book)
    local shut = Look.Build("Button", book, nil, { size = { 32, 32 } })
    Look.Pin(shut, "CENTER", book, "TOPRIGHT", -44, -25)
    Look.SkinCloseButton(shut)
    shut:SetScript("OnClick", function() S.Hide() end)
    S.closeButton = shut
end

---------------------------------------------------------------------------
-- The twelve slots (the art; the secure buttons are on the layer)
---------------------------------------------------------------------------

local function Slot(book, i)
    local frame = Look.Build("Frame", book, nil, { size = { S.SLOT, S.SLOT } })
    local x, y = S.SlotSpot(i)
    Look.Pin(frame, "TOPLEFT", book, "TOPLEFT", x, y)
    local socket = Look.OwnTexture(frame, "socket", "BACKGROUND")
    Look.Art(socket, "sbEmptySlot")
    socket:SetSize(64, 64)
    Look.Pin(socket, "TOPLEFT", frame, "TOPLEFT", -3, 3)
    Dark(socket, "page")
    local icon = Look.OwnTexture(frame, "icon", "BORDER")
    Look.Fill(icon, frame)
    icon:Hide()
    local ring = Look.OwnTexture(frame, "ring", "ARTWORK")
    Look.Art(ring, "slotNormal")
    ring:SetSize(64, 64)
    Look.Pin(ring, "CENTER", frame, "CENTER", 0, 0)
    local glow = Look.OwnTexture(frame, "checked", "OVERLAY")
    Look.Art(glow, "slotChecked")
    glow:SetBlendMode("ADD")
    Look.Fill(glow, frame)
    glow:Hide()
    local name = Look.OwnLabel(frame, "name", "GameFontNormal", "ARTWORK")
    name:SetWidth(103)
    name:SetJustifyH("LEFT")
    if name.SetMaxLines then name:SetMaxLines(3) end
    local sub = Look.OwnLabel(frame, "sub", _G.SubSpellFont and "SubSpellFont" or "GameFontHighlightSmall", "ARTWORK")
    sub:SetSize(79, 18)
    sub:SetJustifyH("LEFT")
    Look.Pin(sub, "TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    if ns.DarkWindowText then ns.DarkWindowText(sub) end
    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    Look.Fill(cooldown, frame)
    S.slots[i] = { frame = frame, icon = icon, ring = ring, glow = glow, name = name, sub = sub, cooldown = cooldown }
end

-- The name beside its slot: 3 up with a rank under it, 1 up without.
function S.PlaceName(entry, withSub)
    Look.Pin(entry.name, "LEFT", entry.frame, "RIGHT", 5, withSub and 3 or 1)
end

-- The dim shade over a slot that can't be clicked now (made on first use).
function S.Shade(entry, on)
    if not on and not entry.shade then return end
    if not entry.shade then
        entry.shade = Look.OwnTexture(entry.frame, "shade", "OVERLAY", 7)
        entry.shade:SetColorTexture(0, 0, 0, 0.55)
        Look.Fill(entry.shade, entry.frame)
    end
    Look.Shown(entry.shade, on)
end

---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------

local GUIDE_ICON = "Interface\\Icons\\INV_Misc_Book_09"

local function SchoolTabs(book)
    local previous
    for i = 1, 8 do
        local tab = ns.NewSideTab(book, i, previous)
        tab:SetScript("OnClick", function(self) S.SchoolTabClick(self, i) end)
        S.skillTabs[i] = tab
        previous = tab
    end
    local guide = ns.NewSideTab(book, 9, nil)
    guide:SetNormalTexture(GUIDE_ICON)
    guide.tooltip = "Training Guide"
    guide:SetScript("OnClick", function(self) S.GuideTabClick(self) end)
    book.SkillTabs, book.TrainTab = S.skillTabs, guide
end

local function BookTabs(book)
    local previous
    for i = 1, 3 do
        local tab = ns.NewBookTab(book, i, previous)
        S.bookTabs[i] = tab
        previous = tab
    end
    S.bookTabs[1]:SetText(S.Say("SPELLBOOK", "Spellbook"))
    S.bookTabs[2]:SetText(S.Say("TRADE_SKILLS", "Professions"))
    book.BookTabs = S.bookTabs
end

---------------------------------------------------------------------------
-- The search box and the ranks tick
---------------------------------------------------------------------------

local function SearchChanged(box)
    local text = box:GetText()
    text = (type(text) == "string" and not Look.Secret(text)) and text or ""
    Look.Shown(S.searchHint, text == "")
    Look.Shown(S.searchClear, text ~= "")
    if text ~= S.view.search then
        S.view.search = text
        if S.book:IsShown() then S.Refresh() end
    end
end

local function Search(book)
    local box = CreateFrame("EditBox", nil, book, "InputBoxTemplate")
    box:SetSize(130, 20)
    Look.Pin(box, "TOPRIGHT", book, "TOPRIGHT", -42, -47)
    box:SetAutoFocus(false)
    box:SetMaxLetters(40)
    local hint = Look.OwnLabel(box, "hint", "GameFontDisable", "ARTWORK")
    Look.Pin(hint, "LEFT", box, "LEFT", 2, 0)
    hint:SetText(S.Say("SEARCH", "Search"))
    local clear = Look.Build("Button", box, nil, { size = { 17, 17 } })
    Look.Pin(clear, "RIGHT", box, "RIGHT", -3, 0)
    local mark = "Interface\\FriendsFrame\\ClearBroadcastIcon"
    clear:SetNormalTexture(mark)
    clear:GetNormalTexture():SetAlpha(0.6)
    clear:SetHighlightTexture(mark)
    clear:GetHighlightTexture():SetBlendMode("ADD")
    clear:Hide()
    clear:SetScript("OnClick", function()
        box:SetText("")
        box:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    box:SetScript("OnTextChanged", SearchChanged)
    S.searchHint, S.searchClear = hint, clear
    book.Search = box
end

local function RanksClick(tick)
    local db = ns.db
    if db then db.spellBookTopRank = not tick:GetChecked() end
    S.Sound(tick:GetChecked() and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
    if type(ns.ToggleChanged) == "function" then
        Look.Try(ns.ToggleChanged, "spellBookTopRank")
    else
        S.Refresh()
    end
end

local function Ranks(book)
    local tick = Look.Build("CheckButton", book, nil, { size = { 22, 22 } })
    Look.Pin(tick, "TOPLEFT", book, "TOPLEFT", 76, -46)
    local box = "Interface\\Buttons\\UI-CheckBox-"
    tick:SetNormalTexture(box .. "Up")
    tick:SetPushedTexture(box .. "Down")
    tick:SetHighlightTexture(box .. "Highlight")
    tick:GetHighlightTexture():SetBlendMode("ADD")
    tick:SetCheckedTexture(box .. "Check")
    tick:SetHitRectInsets(0, -110, 0, 0)
    local label = Look.OwnLabel(tick, "label", "GameFontNormalSmall", "ARTWORK")
    Look.Pin(label, "LEFT", tick, "RIGHT", 0, 1)
    label:SetText(S.Say("SHOW_ALL_SPELL_RANKS", "Show all spell ranks"))
    tick:SetScript("OnClick", RanksClick)
    book.Ranks = tick
end

---------------------------------------------------------------------------
-- The book
---------------------------------------------------------------------------

-- Everything drawn on the book; the frame itself, hidden, at the top left.
function S.BuildBook()
    local book = Look.Build("Frame", UIParent, nil, { name = "EraUIClassicSpellBook", size = { S.WIDTH, S.HEIGHT },
        strata = "MEDIUM", mouse = true, wheel = true, hidden = true })
    book:SetToplevel(true)
    Look.Pin(book, "TOPLEFT", UIParent, "TOPLEFT", 0, S.DOWN)
    S.book = book
    Parchment(book)
    book.PrevPage, book.NextPage = Arrow(book, "Prev", 50), Arrow(book, "Next", 314)
    Close(book)
    for i = 1, S.PER_PAGE do Slot(book, i) end
    SchoolTabs(book)
    BookTabs(book)
    Search(book)
    Ranks(book)
    book:SetScript("OnMouseWheel", function(_, delta)
        if Look.InFight() then return end
        S.TurnPage((Look.Number(delta) or 0) > 0 and -1 or 1)
    end)
    -- The Training Guide's way in (Modules/TrainingGuide.lua).
    book.SetLayer = function(_, on) S.SetLayer(on) end
    book.Refresh = function() S.Refresh() end
    return book
end
