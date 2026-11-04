local _, EraUI = ...

-- The mini-games' shop (experimental, with the mini-games): coins from levels
-- and stages buy power-ups for Azeroth Blast and mallets for Whack. One panel
-- over the game's play area (the rest dimmed and closed to clicks), two tabs,
-- a row per item: its icon, name, a line on what it does, how many you have
-- and its price. Locked items show greyed with the level that opens them.
--
-- How to use it:
--   MiniGames.Shop.Open(game, done)  game: "blast" or "whack" (nil: the one shown);
--       Blast opens on Power-ups, Whack on Mallets; done() once it closes
--   MiniGames.Shop.Close()  MiniGames.Shop.Shown() -> bool
--   MiniGames.Shop.ITEMS = {{id, name, about, icon (a role), kind = "power"|"booster"|"mallet",
--       game = "blast"|"whack"}}  (the lust booster's name is your faction's)
-- Buying goes through MiniGames.Progress:Buy (its coins, unlocks and save).
local MG = EraUI.MiniGames
if not MG then return end

local Shop = {}
MG.Shop = Shop
Shop.W, Shop.H, Shop.ROW = 340, 420, 46
Shop.LEVEL = 39   -- over a card (MiniGames.Card is at 37), under the effects' sparks
Shop.ROWS = 7
Shop.ITEMS = {
    {id = "mallet", name = "Mallet", about = "Smash one piece or blocker.", icon = "power.mallet", kind = "power", game = "blast"},
    {id = "shuffle", name = "Shuffle", about = "Mix up the pieces.", icon = "power.shuffle", kind = "power", game = "blast"},
    {id = "swap", name = "Free swap", about = "Swap without a match.", icon = "power.swap", kind = "power", game = "blast"},
    {id = "moves", name = "+5 moves", about = "Five more moves.", icon = "power.moves", kind = "power", game = "blast"},
    {id = "charge", name = "Charge", about = "Start a level with a Charge.", icon = "boost.charge", kind = "booster", game = "blast"},
    {id = "sheep", name = "Sheep", about = "Start a level with a Sheep.", icon = "boost.sheep", kind = "booster", game = "blast"},
    {id = "lust", name = "Bloodlust", about = "Start with double points for 3 moves.", icon = "boost.lust", kind = "booster", game = "blast"},
}
local TABS = {{id = "power", label = "Power-ups"}, {id = "mallet", label = "Mallets"}}
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local BACKDROP = {bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 1}
local GOLD = {1, .84, .35}
local shops = {}

local function Name(item)
    if item.id == "lust" then return MG.Faction() == "Alliance" and "Heroism" or "Bloodlust" end
    return item.name
end
-- The rows a tab lists: power-ups and boosters, or Whack's mallets.
local function Items(tab)
    if tab == "power" then return Shop.ITEMS end
    local P = MG.Progress
    local out = {}
    for _, skin in ipairs(P and P.SKINS or {}) do
        out[#out + 1] = {id = "mallet:" .. skin.id, skin = skin.id, name = skin.name, icon = skin.icon, kind = "mallet",
            game = "whack", about = skin.price and "A mallet to buy." or "A mallet for Whack.", opens = skin.opens}
    end
    return out
end

-- Building (once per game) ---------------------------------------------------------------------

local function MakeRow(panel, index)
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(Shop.W - 28, Shop.ROW - 2)
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -(92 + (index - 1) * Shop.ROW))
    row.back = row:CreateTexture(nil, "BACKGROUND")
    row.back:SetSize(Shop.W - 28, Shop.ROW - 2)
    row.back:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.back:SetColorTexture(1, 1, 1, index % 2 == 0 and .03 or .06)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(36, 36)
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.name = MG.Text(row, "", 13)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 48, -6)
    row.about = MG.Text(row, "", 10, true)
    row.about:SetPoint("TOPLEFT", row, "TOPLEFT", 48, -24)
    row.about:SetWidth(170)
    row.about:SetWordWrap(false)
    row.owned = MG.Text(row, "", 12)
    row.owned:SetPoint("RIGHT", row, "RIGHT", -84, 0)
    row.owned:SetJustifyH("RIGHT")
    local coin = MG.ArtValue and MG:ArtValue("coin") or "Interface\\Icons\\INV_Misc_Coin_01"
    row.buy = MG.Button(row, "", 72, 26, coin)
    row.buy:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.buy:SetScript("OnClick", function() Shop.Press(panel, row) end)
    row.use = MG.Button(row, "Use", 72, 26)
    row.use:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.use:SetScript("OnClick", function() Shop.Press(panel, row) end)
    row:Hide()
    return row
end
local function MakeTop(panel)
    panel.stripe = panel:CreateTexture(nil, "BORDER")
    panel.stripe:SetHeight(3)
    panel.stripe:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
    panel.stripe:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
    panel.title = MG.Text(panel, "Shop", 20)
    panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -14)
    panel.coin = panel:CreateTexture(nil, "ARTWORK")
    panel.coin:SetSize(16, 16)
    panel.coin:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -42)
    if MG.Art then MG:Art(panel.coin, "coin") end
    panel.coins = MG.Text(panel, "", 13)
    panel.coins:SetPoint("LEFT", panel.coin, "RIGHT", 5, 0)
    panel.coins:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local close
    if EraUI.CreateCloseX then
        close = EraUI:CreateCloseX(panel, function() Shop.Close() end)
    else
        close = MG.Button(panel, "X", 28, 28)
        close:SetScript("OnClick", function() Shop.Close() end)
    end
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
    panel.close = close
    panel.tabs = {}
    for index, tab in ipairs(TABS) do
        local button = MG.Button(panel, tab.label, 120, 26)
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", 16 + (index - 1) * 128, -62)
        button.tab = tab.id
        button.line = button:CreateTexture(nil, "OVERLAY")
        button.line:SetSize(118, 2)
        button.line:SetPoint("BOTTOM", button, "BOTTOM", 0, 1)
        button.line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        button:SetScript("OnClick", function() MG:Sound("uiClick"); Shop.Tab(panel, tab.id) end)
        panel.tabs[index] = button
    end
end
local function Build(holder)
    local dim = CreateFrame("Frame", nil, holder)
    dim:SetSize(MG.CONTENT_W, MG.CONTENT_H)
    dim:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    dim:SetFrameLevel(holder:GetFrameLevel() + Shop.LEVEL)
    dim:EnableMouse(true)
    dim.shade = dim:CreateTexture(nil, "BACKGROUND")
    dim.shade:SetSize(MG.CONTENT_W, MG.CONTENT_H)
    dim.shade:SetPoint("TOPLEFT", dim, "TOPLEFT", 0, 0)
    dim.shade:SetColorTexture(0, 0, 0, .55)
    local panel = CreateFrame("Frame", nil, dim, "BackdropTemplate")
    panel:SetSize(Shop.W, Shop.H)
    panel:SetPoint("CENTER", dim, "CENTER", 0, 0)
    panel:SetBackdrop(BACKDROP)
    panel:SetBackdropColor(.03, .035, .045, .97)
    panel:EnableMouse(true)
    panel.dim = dim
    panel.paper = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    panel.paper:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
    panel.paper:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -1, 1)
    MakeTop(panel)
    panel.rows = {}
    for index = 1, Shop.ROWS do panel.rows[index] = MakeRow(panel, index) end
    dim:Hide()
    return panel
end

-- Painting ------------------------------------------------------------------------------------

local function PaintRow(row, item)
    local P = MG.Progress
    row.item = item
    if MG.Art then MG:Art(row.icon, item.icon) end
    row.name:SetText(Name(item))
    row.use:Hide()
    row.buy:Hide()
    row.owned:SetText("")
    local open
    if item.kind == "mallet" then
        local owned = P:Unlocked(item.id)
        local price = P.PRICES[item.id]
        open = owned or price ~= nil
        if owned then
            local using = P:Mallet() == item.skin
            row.use.label:SetText(using and "In use" or "Use")
            row.use:SetAlpha(using and .5 or 1)
            row.use:Show()
            row.about:SetText(item.about)
        elseif price then
            row.buy.label:SetText(tostring(price))
            row.buy:Show()
            row.about:SetText(item.about)
        else
            row.about:SetText(("Opens at %s"):format(item.opens or "a milestone"))
        end
    else
        open = P:Unlocked(item.id)
        if open then
            row.owned:SetText(("x%d"):format(P:Count(item.id)))
            row.buy.label:SetText(tostring(P:Price(item.id) or 0))
            row.buy:Show()
            row.about:SetText(item.about)
        else
            row.about:SetText(("Opens at level %d"):format(P.UNLOCK_AT[item.id] or 1))
        end
    end
    row.open = open and true or false
    row:SetAlpha(open and 1 or .45)
    if row.icon.SetDesaturated then pcall(row.icon.SetDesaturated, row.icon, not open) end
    row:Show()
end
local function Paint(panel)
    local P = MG.Progress
    local r, g, b = MG.Colour()
    panel:SetBackdropBorderColor(r, g, b, 1)
    panel.stripe:SetColorTexture(r, g, b, 1)
    if MG.Art then MG:Art(panel.paper, "card", {tint = {.24, .22, .19}, plain = true}) else panel.paper:Hide() end
    panel.paper:SetAlpha(.55)
    panel.coins:SetText(("%d coins"):format(P and P:Coins() or 0))
    for _, button in ipairs(panel.tabs) do button.line:SetShown(button.tab == panel.tab) end
    local items = Items(panel.tab)
    for index, row in ipairs(panel.rows) do
        if items[index] then PaintRow(row, items[index]) else row.item = nil; row:Hide() end
    end
end
function Shop.Tab(panel, tab)
    panel.tab = tab
    Paint(panel)
end
-- A row's button: buy it, or use the mallet.
function Shop.Press(panel, row)
    local P = MG.Progress
    local item = row.item
    if not (P and item) then return end
    if item.kind == "mallet" and P:Unlocked(item.id) then
        if P:SetMallet(item.skin) then
            MG:Sound("uiClick")
            MG:Note(("%s in use."):format(item.name))
        end
        Paint(panel)
        return
    end
    local ok, why, price = P:Buy(item.id)
    if ok then
        MG:Sound("buy")
        MG:Note(("Bought %s for %d coins."):format(Name(item), price or 0))
    elseif why == "coins" then
        MG:Sound("buzz")
        MG:Note(("Not enough coins. You need %d."):format(price or 0))
    else
        MG:Sound("buzz")
    end
    Paint(panel)
    if MG.PaintCoins then MG:PaintCoins() end
end

-- Showing -------------------------------------------------------------------------------------

local function Current(id)
    id = id or MG.current
    return id, id and shops[id]
end
function Shop.Open(game, done)
    local id = game or MG.current
    local owner = id and MG.games[id]
    if not (owner and owner.holder) then return false end
    local panel = shops[id]
    if not panel then
        panel = Build(owner.holder)
        shops[id] = panel
    end
    panel.done = done
    panel.tab = id == "whack" and "mallet" or "power"
    Paint(panel)
    panel.dim:Show()
    MG:Sound("uiClick")
    return true
end
function Shop.Close(game)
    local _, panel = Current(game)
    if not (panel and panel.dim:IsShown()) then return false end
    panel.dim:Hide()
    local done = panel.done
    panel.done = nil
    if type(done) == "function" then done() end
    return true
end
function Shop.Shown(game)
    local _, panel = Current(game)
    return panel ~= nil and panel.dim:IsShown()
end
-- The panel of a game's shop (the tests read it), or nil before it first opened.
function Shop.Frame(game)
    local _, panel = Current(game)
    return panel
end
