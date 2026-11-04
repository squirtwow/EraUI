-- The professions book (Classic look, registry "professionsBook"): the
-- game's Professions window on its overview page drawn as the old two-page
-- professions book. EraUI draws the pages (on ProfessionsFrame.BookPage) and
-- five rows (on its ProfessionsContentFrame): two primary professions with
-- an emblem, name, rank title and green rank bar, then Cooking, Fishing and
-- First Aid. The game's five cards stay and do the work (their spell buttons
-- cast, unlearn works): EraUI moves them beside its rows, fades their own
-- art and lays a brown plate behind each spell button. Moved only out of a
-- fight. Dark Windows (Dark Mode only) darkens it all with the slider.
-- The watch that runs it is Look/ProfWatch.lua.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Spells

local P = { rows = {}, plates = Look.Weak() }
Look.Prof = P

local ART = {
    sheet = "Interface\\Spellbook\\ProfessionsBook",
    fill = "Interface\\Spellbook\\Professions-Progress-Fill",
    left = "Interface\\Spellbook\\Professions-Book-Left",
    right = "Interface\\Spellbook\\Professions-Book-Right",
    unknown = "Interface\\Icons\\INV_Scroll_04",
    unlearn = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
}
-- Crops on the professions sheet: the round emblem ring and a spell plate.
local RING_CUT = { 0.43359375, 0.72265625, 0.1484375, 0.7265625 }
local PLATE_CUT = { 0.00390625, 0.42578125, 0.1484375, 0.46875 }
local GREEN = { 0, 1, 0 }
-- Each row: height, top, and the lift of its rank line.
local ROWS = { { 100, -62, 0 }, { 100, -168, 15 }, { 52, -282, 0 }, { 52, -352, 0 }, { 52, -422, 0 } }
local CARDS = Look.Words("PrimaryProfession1 PrimaryProfession2 SecondaryProfession1 SecondaryProfession2 SecondaryProfession3")
local MISSING = {
    { "PROFESSIONS_FIRST_PROFESSION", "PROFESSIONS_MISSING_PROFESSION" },
    { "PROFESSIONS_SECOND_PROFESSION", "PROFESSIONS_MISSING_PROFESSION" },
    { "PROFESSIONS_COOKING", "PROFESSIONS_COOKING_MISSING" },
    { "PROFESSIONS_FISHING", "PROFESSIONS_FISHING_MISSING" },
    { "PROFESSIONS_FIRST_AID", "PROFESSIONS_FIRST_AID_MISSING" },
}
local BAR_PIECES = Look.Words("BGLeft BGMiddle BGRight capLeft capRight")
P.CARDS = CARDS

local function BookParts()
    local page = ProfessionsFrame and ProfessionsFrame.BookPage
    return page and page.ProfessionsContentFrame, page
end
P.Content = BookParts

local function Dark(texture, role, force)
    if texture and ns.DarkWindowArt then ns.DarkWindowArt(texture, role, force) end
end

-- A cut of the professions sheet as EraUI's own texture on owner.
local function SheetCut(owner, purpose, layer, sublevel, cut, width, height)
    local piece = Look.OwnTexture(owner, purpose, layer, sublevel)
    piece:SetTexture(ART.sheet)
    Look.Crop(piece, cut[1], cut[2], cut[3], cut[4])
    piece:SetSize(width, height)
    return piece
end

-- A card's spell button n (nil past the ones it has).
local function CardButton(card, n)
    return card and card[("SpellButton%d"):format(n)] or nil
end

---------------------------------------------------------------------------
-- Pages and rows (made once)
---------------------------------------------------------------------------

local function Pages(page)
    local left = Look.OwnTexture(page, "bookLeft", "BACKGROUND", 2)
    left:SetTexture(ART.left)
    Look.Pin(left, "TOPLEFT", page, "TOPLEFT", 7, -25)
    local right = Look.OwnTexture(page, "bookRight", "BACKGROUND", 2)
    right:SetTexture(ART.right)
    Look.Pin(right, "TOPLEFT", left, "TOPRIGHT", 0, 0)
    P.pages = { left, right }
end

-- The rank bar: the game's own professions bar, or a plain one like it.
local function RankBar(row)
    local fine, bar = pcall(CreateFrame, "StatusBar", nil, row, "ProfessionStatusBarTemplate")
    if not (fine and bar) then
        bar = Look.Build("StatusBar", row, nil, { size = { 95, 16 } })
        bar:SetStatusBarTexture(ART.fill)
        local text = Look.OwnLabel(bar, "rank", "TextStatusBarText", "OVERLAY")
        Look.Pin(text, "CENTER", bar, "CENTER", 0, 2)
        bar.rankText = text
    end
    Look.Shown(bar.capped, false)
    bar:SetStatusBarColor(GREEN[1], GREEN[2], GREEN[3])
    return bar
end

local function Label(row, purpose, font, fallback)
    return Look.OwnLabel(row, purpose, _G[font] and font or fallback, "ARTWORK")
end

local function PrimaryRow(row, lift)
    local ring = SheetCut(row, "ring", "ARTWORK", 1, RING_CUT, 72, 72)
    Look.Pin(ring, "TOPLEFT", row, "TOPLEFT", 7, -12)
    local icon = Look.OwnTexture(row, "icon", "ARTWORK", 0)
    Look.Inside(icon, ring, 8, 8, 8, 8)
    Look.RoundIcon(icon, 1)
    local name = Label(row, "name", "QuestTitleFontBlackShadow", "GameFontNormalLarge")
    Look.Pin(name, "TOPLEFT", row, "TOPLEFT", 100, -8)
    name:SetJustifyH("LEFT")
    local title = Label(row, "title", "GameFontHighlightSmall", "GameFontHighlightSmall")
    Look.Pin(title, "TOPLEFT", row, "TOPLEFT", 100, -56 + lift)
    title:SetWidth(182)
    title:SetJustifyH("LEFT")
    local bar = RankBar(row)
    Look.Pin(bar, "TOPLEFT", title, "BOTTOMLEFT", 14, -5)
    local header = Label(row, "header", "QuestTitleFontBlackShadow", "GameFontNormalLarge")
    Look.Pin(header, "TOPLEFT", row, "TOPLEFT", 120, -20)
    header:SetTextColor(0.85, 0.7, 0.6)
    local text = Label(row, "text", "SubSpellFont", "GameFontHighlightSmall")
    Look.Pin(text, "TOPLEFT", header, "BOTTOMLEFT", 0, -1)
    text:SetWidth(305)
    text:SetJustifyH("LEFT")
    text:SetTextColor(0.1, 0.05, 0.05)
    return { frame = row, primary = true, ring = ring, icon = icon, name = name, title = title, bar = bar,
        header = header, text = text }
end

local function SecondaryRow(row)
    local bar = RankBar(row)
    Look.Pin(bar, "BOTTOMLEFT", row, "BOTTOMLEFT", 16, 2)
    local title = Label(row, "title", "GameFontHighlightSmall", "GameFontHighlightSmall")
    title:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", -14, 4)
    title:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 25, 4)
    title:SetJustifyH("LEFT")
    local name = Label(row, "name", "QuestFont_Shadow_Small", "GameFontNormal")
    name:SetPoint("BOTTOMLEFT", title, "TOPLEFT", 0, 2)
    name:SetPoint("BOTTOMRIGHT", title, "TOPRIGHT", 0, 2)
    name:SetJustifyH("LEFT")
    name:SetTextColor(1, 0.82, 0)
    name:SetShadowColor(0, 0, 0)
    local header = Label(row, "header", "QuestFont_Large", "GameFontNormalLarge")
    Look.Pin(header, "TOPLEFT", row, "TOPLEFT", 4, -15)
    header:SetTextColor(0.15, 0.1, 0.1)
    local text = Label(row, "text", "SubSpellFont", "GameFontHighlightSmall")
    Look.Pin(text, "RIGHT", row, "RIGHT", -5, 0)
    text:SetWidth(250)
    text:SetJustifyH("LEFT")
    text:SetTextColor(0.1, 0.05, 0.05)
    return { frame = row, primary = false, bar = bar, title = title, name = name, header = header, text = text }
end

-- Pages and rows, once (hidden until the cards are placed).
function P.Build()
    if P.built then return true end
    local rowsHome, page = BookParts()
    if not rowsHome then return false end
    Pages(page)
    for i, spec in ipairs(ROWS) do
        local row = Look.Build("Frame", rowsHome, nil, { size = { 437, spec[1] } })
        Look.Pin(row, "TOPLEFT", rowsHome, "TOPLEFT", 80, spec[2])
        P.rows[i] = i <= 2 and PrimaryRow(row, spec[3]) or SecondaryRow(row)
        P.rows[i].lift = spec[3]
        row:Hide()
    end
    for _, texture in ipairs(P.pages) do texture:Hide() end
    P.built = true
    return true
end

-- Rows and pages shown once the cards have been placed.
function P.ShowRows(on)
    if not P.built then return end
    for _, row in ipairs(P.rows) do Look.Shown(row.frame, on) end
    for _, texture in ipairs(P.pages) do Look.Shown(texture, on) end
end

---------------------------------------------------------------------------
-- Filling the rows (6.3)
---------------------------------------------------------------------------

-- Apprentice, Journeyman...: the first title whose threshold reaches the
-- profession's top rank, else the last title on the list.
local function TitleForTop(top)
    local titles = _G.PROFESSION_RANKS
    if type(titles) ~= "table" or #titles == 0 then return "" end
    for _, pair in ipairs(titles) do
        if type(pair) == "table" and (Look.Number(pair[1]) or 0) >= top then return pair[2] or "" end
    end
    local last = titles[#titles]
    return type(last) == "table" and last[2] or ""
end
P.RankTitle = TitleForTop

-- The game's order is first, second, First Aid, Fishing, Cooking; the rows
-- take first, second, Cooking, Fishing, First Aid.
local function Slots()
    if type(GetProfessions) ~= "function" then return {} end
    local first, second, aid, fish, cook = GetProfessions()
    return { first, second, cook, fish, aid }
end

local function RankLine(rank, bonus, top)
    if bonus > 0 then return S.Say("TRADESKILL_RANK_WITH_MODIFIER", "%d (+%d)/%d"):format(rank, bonus, top) end
    return S.Say("TRADESKILL_RANK", "%d/%d"):format(rank, top)
end

local function Learned(row, index)
    local name, icon, rank, top, _, _, _, bonus = GetProfessionInfo(index)
    rank, top, bonus = Look.Number(rank) or 0, Look.Number(top) or 0, Look.Number(bonus) or 0
    row.name:SetText(S.Text(name) or "")
    row.title:SetText(TitleForTop(top))
    local bar = row.bar
    bar:SetMinMaxValues(0, math.max(top, 1))
    bar:SetValue(rank)
    if bar.rankText then bar.rankText:SetText(RankLine(rank, bonus, top)) end
    local emblem = row.icon
    if emblem then
        emblem:SetTexture(icon or ART.unknown)
        emblem:SetDesaturated(nil)
    end
end

function P.Fill()
    if not P.built then return end
    local slots = Slots()
    for i, row in ipairs(P.rows) do
        local index = Look.Number(slots[i])
        local known = index ~= nil and type(GetProfessionInfo) == "function"
        for _, piece in ipairs({ row.name, row.title, row.bar }) do Look.Shown(piece, known) end
        Look.Shown(row.header, not known)
        Look.Shown(row.text, not known)
        if known then
            Look.Try(Learned, row, index)
        else
            row.header:SetText(S.Say(MISSING[i][1], ""))
            row.text:SetText(S.Say(MISSING[i][2], ""))
            if row.icon then row.icon:SetTexture(ART.unknown) end
        end
    end
end

---------------------------------------------------------------------------
-- The game's cards, placed and dressed (out of a fight only)
---------------------------------------------------------------------------

-- What of a card EraUI's own row replaces (faded; the card keeps working).
local CARD_FADED = Look.Words("Background ProfessionName specialization missingHeader missingText Rank icon IconBorder")

-- A spell button's brown plate (once), its square frame faded, its mask off.
local function Dress(button)
    if not button or P.plates[button] then return end
    local plate = SheetCut(button, "plate", "BACKGROUND", 0, PLATE_CUT, 108, 41)
    Look.Pin(plate, "LEFT", button, "RIGHT", 1, 0)
    P.plates[button] = plate
    Look.Fade(button.IconTextureOverlay)
    Look.Fade(button.IconBorder) -- only on builds that have it
    local face, mask = button.IconTexture, button.OutlineMask
    if face and mask then Look.Try(face.RemoveMaskTexture, face, mask) end
end

local function Faded(card)
    for _, key in ipairs(CARD_FADED) do Look.Fade(card[key]) end
    local bar = card.StatusBar
    if bar then
        bar:SetAlpha(0)
        bar:EnableMouse(false)
    end
end

local function Unlearn(card, rowsHome, row)
    local unlearn = card.UnlearnButton
    if not unlearn then return end
    Look.Pin(unlearn, "CENTER", rowsHome, "TOPLEFT", 165, ROWS[row][2] + ROWS[row][3] - 76)
    local mark = unlearn.Icon
    if mark then
        mark:SetTexture(ART.unlearn)
        mark:SetSize(16, 16)
        mark:SetAlpha(0.75)
    end
    Look.Fade(unlearn.Overlay)
    if card.GamepadUnlearnButton then Look.Pin(card.GamepadUnlearnButton, "RIGHT", unlearn, "LEFT", -2, 0) end
end

local function PlacePrimary(rowsHome, card, row)
    card:SetSize(170, 100)
    Look.Pin(card, "TOPLEFT", rowsHome, "TOPLEFT", 353, ROWS[row][2] - 5 + ROWS[row][3])
    Faded(card)
    Dress(CardButton(card, 1))
    Dress(CardButton(card, 2))
    Unlearn(card, rowsHome, row)
end

-- Up to four spell buttons, laid right to left from 109 in.
local function PlaceSecondary(rowsHome, card, row)
    card:SetSize(437, 52)
    Look.Pin(card, "TOPLEFT", rowsHome, "TOPLEFT", 80, ROWS[row][2])
    Faded(card)
    local after
    for n = 1, 4 do
        local spell = CardButton(card, n)
        if spell then
            Dress(spell)
            if after then Look.Pin(spell, "TOPRIGHT", after, "TOPLEFT", -109, 0) else Look.Pin(spell, "TOPRIGHT", card, "TOPRIGHT", -109, -6) end
            after = spell
        end
    end
end

-- All five cards (false when the window's page isn't there, or in a fight).
function P.PlaceCards()
    local rowsHome = BookParts()
    if not rowsHome or Look.InFight() then return false end
    for i, key in ipairs(CARDS) do
        local card = rowsHome[key]
        if card and i <= 2 then PlacePrimary(rowsHome, card, i) elseif card then PlaceSecondary(rowsHome, card, i) end
    end
    return true
end

-- With both spell buttons up, a primary card's two buttons sit closer
-- (the game puts them at 60 and 10 above the card's bottom).
local CLOSER = { [60] = 56, [10] = 15 }
local function Closer(spell)
    local point, relative, relativePoint, x, y = spell:GetPoint(1)
    y = Look.Number(y)
    if point ~= "BOTTOMLEFT" or not y then return end
    for from, to in pairs(CLOSER) do
        if math.abs(y - from) <= 0.5 then
            spell:ClearAllPoints()
            spell:SetPoint(point, relative, relativePoint, x, to)
            return
        end
    end
end

function P.PullTogether()
    local rowsHome = BookParts()
    if not rowsHome or Look.InFight() then return end
    for i = 1, 2 do
        local card = rowsHome[CARDS[i]]
        local one, two = CardButton(card, 1), CardButton(card, 2)
        if one and two and one:IsShown() and two:IsShown() then
            Closer(one)
            Closer(two)
        end
    end
end

---------------------------------------------------------------------------
-- Dark Windows (only in Dark Mode)
---------------------------------------------------------------------------

local function Texts(owner, force)
    Look.EachRegion(owner, function(region)
        if region.IsObjectType and region:IsObjectType("FontString") and ns.DarkBlackPageText then
            ns.DarkBlackPageText(region, force)
        end
    end)
end

-- One card: its background and plates, its own "learn" texts, its dark
-- small text (light only on black pages).
function P.DarkCard(card, force)
    if not card then return end
    Dark(card.Background, "page", force)
    if ns.DarkWindowText then
        for _, key in ipairs({ "missingHeader", "missingText" }) do
            if card[key] then ns.DarkWindowText(card[key], force) end
        end
    end
    Texts(card, force)
    for n = 1, 4 do
        local spell = CardButton(card, n)
        if spell then
            Dark(P.plates[spell], "page", force)
            Texts(spell, force)
        end
    end
end

-- The window's frame: the game's nine-slice and the window skin's pieces.
local function DarkFrame(force)
    local window = ProfessionsFrame
    if not window then return end
    Look.EachRegion(window.NineSlice, function(region)
        if region.IsObjectType and region:IsObjectType("Texture") then Dark(region, "frame", force) end
    end)
    if type(ns.WindowPiece) ~= "function" then return end
    for _, piece in ipairs({ "titleStrip", "streaks", "backing" }) do
        local asked, texture = Look.Try(ns.WindowPiece, window, piece)
        if asked and texture then Dark(texture, "frame", force) end
    end
end

function P.DarkPass(force)
    if not EraUI:GetSetting("darkMode") then return end
    for _, texture in ipairs(P.pages or {}) do Dark(texture, "page", force) end
    for _, row in ipairs(P.rows) do
        Dark(row.ring, "trim", force)
        for _, key in ipairs(BAR_PIECES) do Dark(row.bar[key], "trim", force) end
        if ns.DarkWindowText then
            ns.DarkWindowText(row.text, force)
            if not row.primary then ns.DarkWindowText(row.header, force) end
        end
    end
    local rowsHome = BookParts()
    for _, key in ipairs(CARDS) do P.DarkCard(rowsHome and rowsHome[key], force) end
    DarkFrame(force)
end

-- Hooked once, out of a fight, as soon as the window is there in Dark Mode:
-- a pass whenever it opens, and the card the game just filled painted again.
local hookedOnce = false
local function Hook()
    if hookedOnce or Look.InFight() or not EraUI:GetSetting("darkMode") then return hookedOnce end
    local window = ProfessionsFrame
    local page = window and window.BookPage
    if page == nil then return false end
    hookedOnce = true
    -- Both run inside the game's own code (its OnShow, its card loop), so an
    -- error of EraUI's goes to the error handler and never stops the game's.
    Look.HookScript(window, "OnShow", function() Look.Try(P.DarkPass, false) end, "professions")
    Look.Hook(page, "FormatProfession", function(_, card) Look.Try(P.DarkCard, card, true) end)
    return true
end

do
    local waiter = CreateFrame("Frame")
    for _, event in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do Look.Listen(waiter, event) end
    waiter:SetScript("OnEvent", function(_, event)
        local done = Hook() or (event == "PLAYER_ENTERING_WORLD" and not EraUI:GetSetting("darkMode"))
        if done then waiter:UnregisterAllEvents() end
    end)
end
