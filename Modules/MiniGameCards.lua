local _, EraUI = ...

-- The mini-games' cards (experimental, with the mini-games): one card at a
-- time over a game's play area, the rest dimmed and closed to clicks. A
-- level's intro (its goals, moves and boosters), a win (stars filling, coins
-- counting up, what opened), a loss (how close you got, +5 moves) and the
-- how-it-works cards, each shown once. EraUI's dark look with a faint
-- parchment, your class colour along the top.
--
-- How to use it:
--   MiniGames.Card.Show(spec) -> card  over the game shown now (spec.game: another's)
--     spec = {title, sub, icon (a role or a texture), lines = {{icon, text, done, progress}},
--       big (22, gold: "20 moves"), best ("Best 1,240"), stars (0..3: fill one by one, a
--       sound each), coins (count up to "+N coins"), toggles = {{id, icon, count, price,
--       on, locked}}, onToggle(id) -> on, count (a toggle clicked; its new look),
--       buttons = {{label, width, primary, sub, onClick(card)}}, width (300), height
--       (at least what it holds), kind ("how" for a how-it-works card), quiet (no
--       coin sound: the window hid while it came)}
--   MiniGames.Card.Hide()  the card of the game shown (nil: that one)
--   MiniGames.Card.Shown() -> whether the game shown has a card up
--   MiniGames.Card.HowItWorks(ids, done) -> whether one shows: each card id (one id or a
--       list) not seen yet, one after another ("Got it"), each marked seen
--       (MiniGames.Progress:See); then done(). All seen: done() at once.
-- Each game has its own card in its holder, so switching games hides it and
-- switching back shows it again.
local MG = EraUI.MiniGames
if not MG then return end

local Card = {}
MG.Card = Card
Card.W, Card.H, Card.HOW_H = 300, 260, 200
Card.LEVEL = 37        -- the dim layer over the game's holder (the card just over it, under the effects)
Card.LINES, Card.TOGGLES, Card.BUTTONS = 4, 4, 3
Card.STAR, Card.STAR_TIME = 48, .35
Card.GOLD = {1, .84, .35}
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local BACKDROP = {bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 1}
local cards = {}

local function GameOf(id)
    id = id or MG.current
    local game = id and MG.games[id]
    return game, id
end
-- A role (MiniGames:Art) or a texture value (a path or file ID).
local function Picture(texture, icon)
    if icon == nil then
        texture:Hide()
        return false
    end
    if type(icon) == "string" and not icon:find("\\", 1, true) and MG.Art then return MG:Art(texture, icon) ~= nil end
    local ok = texture:SetTexture(icon) ~= false
    texture:SetTexCoord(.08, .92, .08, .92)
    texture:SetVertexColor(1, 1, 1, 1)
    texture:SetShown(ok)
    return ok
end

-- Building (once per game) ------------------------------------------------------------------

local function MakeLine(card)
    local line = CreateFrame("Frame", nil, card)
    line:SetSize(Card.W - 40, 26)
    line.icon = line:CreateTexture(nil, "ARTWORK")
    line.icon:SetSize(24, 24)
    line.icon:SetPoint("LEFT", line, "LEFT", 0, 0)
    line.check = line:CreateTexture(nil, "OVERLAY")
    line.check:SetSize(14, 14)
    line.check:SetPoint("BOTTOMRIGHT", line.icon, "BOTTOMRIGHT", 4, -3)
    line.text = MG.Text(line, "", 13)
    line.text:SetPoint("LEFT", line, "LEFT", 30, 0)
    line.text:SetWidth(Card.W - 120)
    line.progress = MG.Text(line, "", 13)
    line.progress:SetPoint("RIGHT", line, "RIGHT", 0, 0)
    line.progress:SetJustifyH("RIGHT")
    line:Hide()
    return line
end
local function MakeToggle(card, index)
    local toggle = CreateFrame("Button", nil, card)
    toggle:SetSize(40, 40)
    toggle.icon = toggle:CreateTexture(nil, "ARTWORK")
    toggle.icon:SetSize(36, 36)
    toggle.icon:SetPoint("CENTER", toggle, "CENTER", 0, 0)
    toggle.ring = toggle:CreateTexture(nil, "OVERLAY")
    toggle.ring:SetSize(52, 52)
    toggle.ring:SetPoint("CENTER", toggle, "CENTER", 0, 0)
    if toggle.ring:SetTexture(MG.ART.square) == false then toggle.ring:SetColorTexture(1, .84, .35, .5) end
    toggle.ring:SetBlendMode("ADD")
    toggle.ring:SetVertexColor(Card.GOLD[1], Card.GOLD[2], Card.GOLD[3], 1)
    toggle.badge = toggle:CreateTexture(nil, "OVERLAY", nil, 1)
    toggle.badge:SetSize(16, 16)
    toggle.badge:SetPoint("BOTTOMRIGHT", toggle, "BOTTOMRIGHT", 4, -4)
    toggle.badge:SetColorTexture(.05, .04, .03, .9)
    toggle.count = MG.Text(toggle, "", 11, false, true)
    toggle.count:SetPoint("CENTER", toggle.badge, "CENTER", 0, 0)
    toggle.count:SetJustifyH("CENTER")
    toggle.price = MG.Text(toggle, "", 10, false, true)
    toggle.price:SetPoint("TOP", toggle, "BOTTOM", 0, -2)
    toggle.price:SetJustifyH("CENTER")
    toggle.price:SetTextColor(Card.GOLD[1], Card.GOLD[2], Card.GOLD[3])
    toggle.index = index
    toggle:SetScript("OnClick", function(self) Card.Toggle(card, self) end)
    toggle:Hide()
    return toggle
end
local function MakeButton(card)
    local button = MG.Button(card, "", 110, 28)
    button.sub = MG.Text(button, "", 9, true)
    button.sub:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
    button.sub:SetJustifyH("CENTER")
    button.glow = button:CreateTexture(nil, "BACKGROUND")
    button.glow:SetSize(150, 50)
    button.glow:SetPoint("CENTER", button, "CENTER", 0, 0)
    if button.glow:SetTexture(MG.ART.glow) == false then button.glow:SetColorTexture(1, .84, .35, .15) end
    button.glow:SetBlendMode("ADD")
    button.glow:SetVertexColor(Card.GOLD[1], Card.GOLD[2], Card.GOLD[3], .35)
    button:SetScript("OnClick", function(self)
        MG:Sound("uiClick")
        if type(self.onClick) == "function" then self.onClick(card, self) end
    end)
    button:Hide()
    return button
end
local function MakeHeader(card)
    card.paper = card:CreateTexture(nil, "BACKGROUND", nil, 1)
    card.paper:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
    card.paper:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -1, 1)
    card.stripe = card:CreateTexture(nil, "BORDER")
    card.stripe:SetHeight(3)
    card.stripe:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
    card.stripe:SetPoint("TOPRIGHT", card, "TOPRIGHT", -1, -1)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(36, 36)
    card.icon:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -14)
    card.title = MG.Text(card, "", 20)
    card.title:SetJustifyH("CENTER")
    card.sub = MG.Text(card, "", 12, true)
    card.sub:SetJustifyH("CENTER")
    card.big = MG.Text(card, "", 22, false, true)
    card.big:SetJustifyH("CENTER")
    card.big:SetTextColor(Card.GOLD[1], Card.GOLD[2], Card.GOLD[3])
    card.best = MG.Text(card, "", 12, true)
    card.best:SetJustifyH("CENTER")
    card.coins = MG.Text(card, "", 15, false, true)
    card.coins:SetJustifyH("CENTER")
    card.coins:SetTextColor(Card.GOLD[1], Card.GOLD[2], Card.GOLD[3])
end
local function Build(holder)
    local dim = CreateFrame("Frame", nil, holder)
    dim:SetSize(MG.CONTENT_W, MG.CONTENT_H)
    dim:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    dim:SetFrameLevel(holder:GetFrameLevel() + Card.LEVEL)
    dim:EnableMouse(true)
    dim.shade = dim:CreateTexture(nil, "BACKGROUND")
    dim.shade:SetSize(MG.CONTENT_W, MG.CONTENT_H)
    dim.shade:SetPoint("TOPLEFT", dim, "TOPLEFT", 0, 0)
    dim.shade:SetColorTexture(0, 0, 0, .5)
    local card = CreateFrame("Frame", nil, dim, "BackdropTemplate")
    card:SetSize(Card.W, Card.H)
    card:SetPoint("CENTER", dim, "CENTER", 0, 0)
    card:SetBackdrop(BACKDROP)
    card:SetBackdropColor(.03, .035, .045, .97)
    card:EnableMouse(true)
    card.dim = dim
    MakeHeader(card)
    card.starArt = {}
    for s = 1, 3 do
        local star = card:CreateTexture(nil, "ARTWORK")
        star:SetSize(Card.STAR, Card.STAR)
        card.starArt[s] = star
    end
    card.lines, card.toggles, card.buttons = {}, {}, {}
    for i = 1, Card.LINES do card.lines[i] = MakeLine(card) end
    for i = 1, Card.TOGGLES do card.toggles[i] = MakeToggle(card, i) end
    for i = 1, Card.BUTTONS do card.buttons[i] = MakeButton(card) end
    dim:Hide()
    return card
end

-- Painting --------------------------------------------------------------------------------------

local function Place(region, card, y, x)
    region:ClearAllPoints()
    region:SetPoint("TOP", card, "TOP", x or 0, -y)
end
local function PaintToggle(toggle, info)
    Picture(toggle.icon, info.icon)
    local count = tonumber(info.count) or 0
    toggle.ring:SetShown(info.on and true or false)
    toggle.badge:SetShown(count > 0)
    toggle.count:SetText(count > 0 and tostring(count) or "")
    toggle.price:SetText(count <= 0 and info.price and tostring(info.price) or "")
    toggle:SetAlpha(info.locked and .4 or 1)
    if toggle.icon.SetDesaturated then pcall(toggle.icon.SetDesaturated, toggle.icon, info.locked and true or false) end
end
function Card.Toggle(card, toggle)
    local spec = card.spec
    local info = spec and spec.toggles and spec.toggles[toggle.index]
    if not info or info.locked then
        MG:Sound("buzz")
        return
    end
    MG:Sound("uiClick")
    if type(spec.onToggle) == "function" then
        local on, count = spec.onToggle(info.id)
        if on ~= nil then info.on = on and true or false end
        if count ~= nil then info.count = count end
    else
        info.on = not info.on
    end
    PaintToggle(toggle, info)
end
local function PaintLines(card, spec, y)
    local how = spec.kind == "how"
    for i, line in ipairs(card.lines) do
        local info = spec.lines and spec.lines[i]
        if info then
            local rows = how and 34 or 26
            line:SetSize(Card.W - 40, rows)
            Place(line, card, y)
            local hasIcon = Picture(line.icon, info.icon)
            line.text:ClearAllPoints()
            line.text:SetPoint("LEFT", line, "LEFT", hasIcon and 30 or 0, 0)
            line.text:SetWidth(Card.W - 40 - (hasIcon and 30 or 0) - (info.progress and 50 or 0))
            line.text:SetWordWrap(how)
            line.text:SetText(info.text or "")
            if how then line.text:SetTextColor(.82, .85, .9) else line.text:SetTextColor(.94, .95, .98) end
            line.progress:SetText(info.progress or "")
            if info.done then
                if MG.Art then MG:Art(line.check, "check") else line.check:Show() end
                line.progress:SetTextColor(.4, 1, .5)
            else
                line.check:Hide()
                line.progress:SetTextColor(.94, .95, .98)
            end
            line:Show()
            y = y + rows + 2
        else
            line:Hide()
        end
    end
    return y
end
local function PaintToggles(card, spec, y)
    local list = spec.toggles or {}
    local count = math.min(#list, Card.TOGGLES)
    local width = count * 40 + math.max(0, count - 1) * 14
    for i, toggle in ipairs(card.toggles) do
        local info = list[i]
        if info and i <= count then
            toggle:ClearAllPoints()
            toggle:SetPoint("TOPLEFT", card, "TOP", -width / 2 + (i - 1) * 54, -y)
            PaintToggle(toggle, info)
            toggle:Show()
        else
            toggle:Hide()
        end
    end
    return count > 0 and y + 56 or y
end
local function PaintButtons(card, spec, height)
    local list = spec.buttons or {}
    local count = math.min(#list, Card.BUTTONS)
    local total = 0
    for i = 1, count do total = total + (tonumber(list[i].width) or 110) end
    total = total + math.max(0, count - 1) * 8
    local x = -total / 2
    for i, button in ipairs(card.buttons) do
        local info = list[i]
        if info and i <= count then
            local width = tonumber(info.width) or 110
            button:SetSize(width, 28)
            button.sheen:SetSize(width - 2, 14)
            button.shade:SetSize(width - 2, 13)
            button:ClearAllPoints()
            button:SetPoint("BOTTOMLEFT", card, "BOTTOM", x, 12)
            button.label:SetText(info.label or "")
            local sub = info.sub
            button.sub:SetText(sub or "")
            button.labelAt = {"CENTER", button, "CENTER", 0, sub and 4 or 0}
            button.label:ClearAllPoints()
            button.label:SetPoint("CENTER", button, "CENTER", 0, sub and 4 or 0)
            button.glow:SetShown(info.primary and true or false)
            button.onClick = info.onClick
            button:Show()
            x = x + width + 8
        else
            button.onClick = nil
            button:Hide()
        end
    end
    return height
end
-- The stars fill one after another, a sound each.
local function FillStars(card, stars, y)
    local shown = math.max(0, math.min(3, math.floor(tonumber(stars) or 0)))
    for s, star in ipairs(card.starArt) do
        star:ClearAllPoints()
        star:SetPoint("TOP", card, "TOP", (s - 2) * (Card.STAR + 8), -y)
        MG:Art(star, "starEmpty")
        star:Show()
    end
    card.filling = (card.filling or 0) + 1
    local run = card.filling
    local function Fill(s)
        if s > shown or card.filling ~= run then return end
        MG:Tween(Card.STAR_TIME, nil, function(_, cleared)
            if card.filling ~= run then return end
            MG:Art(card.starArt[s], "star")
            if not cleared then
                MG:Sound("star", s)
                MG:Pop(card.starArt[s], {peak = 1.35})
            end
            Fill(s + 1)
        end)
    end
    Fill(1)
end
local function CountCoins(card, coins, quiet)
    local total = math.max(0, math.floor(tonumber(coins) or 0))
    card.coins:SetText("+0 coins")
    if total > 0 and not quiet then MG:Sound("coins") end
    MG:Tween(.6, function(share) card.coins:SetText(("+%d coins"):format(math.floor(total * share + .5))) end,
        function() card.coins:SetText(("+%d coins"):format(total)) end)
end

local function Paint(card, spec)
    card.spec = spec
    local r, g, b = MG.Colour()
    card:SetBackdropBorderColor(r, g, b, 1)
    card.stripe:SetColorTexture(r, g, b, 1)
    if MG.Art then MG:Art(card.paper, "card", {tint = {.24, .22, .19}, plain = true}) else card.paper:Hide() end
    card.paper:SetAlpha(.55)
    local width = tonumber(spec.width) or Card.W
    local hasIcon = Picture(card.icon, spec.icon)
    local y = 16
    Place(card.title, card, y)
    card.title:SetWidth(width - (hasIcon and 110 or 30))
    card.title:SetText(spec.title or "")
    y = y + 26
    card.sub:SetShown(spec.sub ~= nil)
    if spec.sub then
        Place(card.sub, card, y)
        card.sub:SetWidth(width - 30)
        card.sub:SetText(spec.sub)
        y = y + 18
    end
    y = y + 6
    if spec.stars ~= nil then
        FillStars(card, spec.stars, y)
        y = y + Card.STAR + 8
    else
        card.filling = (card.filling or 0) + 1
        for _, star in ipairs(card.starArt) do star:Hide() end
    end
    y = PaintLines(card, spec, y)
    for _, part in ipairs({"big", "best", "coins"}) do
        local value = spec[part]
        local region = card[part]
        if value ~= nil then
            Place(region, card, y + (part == "big" and 4 or 0))
            region:SetWidth(width - 30)
            if part == "coins" then CountCoins(card, value, spec.quiet) else region:SetText(tostring(value)) end
            region:Show()
            y = y + (part == "big" and 32 or 20)
        else
            region:Hide()
        end
    end
    y = PaintToggles(card, spec, y + 4)
    local default = spec.kind == "how" and Card.HOW_H or Card.H
    local height = math.max(tonumber(spec.height) or default, y + 12 + 28 + 12)
    card:SetSize(width, height)
    PaintButtons(card, spec, height)
end

-- Showing ---------------------------------------------------------------------------------------

function Card.Show(spec)
    if type(spec) ~= "table" then return nil end
    local game, id = GameOf(spec.game)
    if not (game and game.holder) then return nil end
    local card = cards[id]
    if not card then
        card = Build(game.holder)
        cards[id] = card
    end
    Paint(card, spec)
    card.dim:Show()
    card:Show()
    MG:Pop(card, {peak = 1.04, life = .18})
    return card
end
function Card.Hide(id)
    local _, which = GameOf(id)
    local card = which and cards[which]
    if not card then return false end
    card.filling = (card.filling or 0) + 1
    local was = card.dim:IsShown()
    card.dim:Hide()
    card.spec = nil
    return was
end
function Card.Shown(id)
    local _, which = GameOf(id)
    local card = which and cards[which]
    return card ~= nil and card.dim:IsShown()
end
-- The frame of a game's card (the tests read it), or nil before its first.
function Card.Frame(id)
    local _, which = GameOf(id)
    return which and cards[which]
end
function Card.HowItWorks(ids, done)
    local P = MG.Progress
    if type(ids) == "string" then ids = {ids} end
    local queue = {}
    for _, id in ipairs(type(ids) == "table" and ids or {}) do
        if P and P.CARDS[id] and not P:Seen(id) then queue[#queue + 1] = id end
    end
    local index = 0
    local Next
    Next = function()
        index = index + 1
        local id = queue[index]
        if not id then
            if type(done) == "function" then done() end
            return
        end
        local info = P:Card(id)
        local lines = {}
        for i, text in ipairs(info.lines) do lines[i] = {text = text} end
        local card = Card.Show({kind = "how", title = info.title, icon = info.icon, lines = lines, width = Card.W, height = Card.HOW_H,
            buttons = {{label = "Got it", width = 110, primary = true, onClick = function()
                P:See(id)
                Card.Hide()
                Next()
            end}}})
        if not card then
            -- No game to show it on: it counts as seen, the rest follow.
            P:See(id)
            Next()
        end
    end
    Next()
    return #queue > 0
end
