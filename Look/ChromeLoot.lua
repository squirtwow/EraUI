-- The loot window in its 1.x panel: the old 170 x 240 panel art with the bag
-- icon and the skull at its top left, the items on the old name plates, and
-- Prev/Next arrows paging three rows at a time when more than four items
-- wait. The game's own list (its ScrollBox), close button and title stay
-- the game's; its other art is faded, never hidden.
--
-- The window's size is held by post-hooks on its own Resize and
-- UpdateShownState (nothing of the game's is replaced). What EraUI made on
-- it (the panel, icon, skull, plates and pager) is recorded in weak tables.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local C = Look.Chrome
local X = C.extras

local L = {}
C.loot = L

local WIDE, TALL, ROW = 170, 240, 41
local rowPlates = Look.Weak() -- a row frame: its name plate
local ownFrames = Look.Weak() -- EraUI's own frames on the window: true
local viewSet = Look.Weak()   -- a ScrollBox whose view EraUI set up: true

local function Kept(window, region)
    if region == window.ScrollBox or region == window.ClosePanelButton or region == window.CloseButton then return true end
    local title = window.TitleContainer
    return title ~= nil and region == title.TitleText
end

-- Every texture and font string of the window and its children, all the way
-- down, faded, but for what is kept (the list, the X, the title) and EraUI's
-- own pieces and frames.
local function FadeArt(window, frame, depth)
    if depth > 12 then return end
    Look.EachRegion(frame, function(piece)
        local kind = piece.GetObjectType and piece:GetObjectType()
        if (kind == "Texture" or kind == "FontString") and not C.mine[piece] and not Kept(window, piece) then
            Look.Fade(piece)
        end
    end)
    local fine, children = pcall(function() return { frame:GetChildren() } end)
    for _, child in ipairs(fine and children or {}) do
        if not ownFrames[child] and not Kept(window, child) then FadeArt(window, child, depth + 1) end
    end
end

-- The window back to the 1.x size whatever the game just set.
function L.Hold(window)
    if not C.applied or not C.dressed[window] then return end
    local wide, tall = Look.Number(window:GetWidth()), Look.Number(window:GetHeight())
    if wide ~= WIDE or tall ~= TALL then window:SetSize(WIDE, TALL) end
end

local function Own(window, purpose, layer, sublevel, key, size, x, y)
    local made = C.Piece(window, purpose, layer, sublevel)
    Look.Art(made, key)
    Look.Crop(made, 0, 1, 0, 1)
    made:SetSize(size, size)
    Look.Pin(made, "TOPLEFT", window, "TOPLEFT", x, y)
    made:Show()
    return made
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------

local ROW_FADES = Look.Words("NameFrame BorderFrame HighlightNameFrame PushedNameFrame QualityStripe QualityText")

local function DressRow(row)
    for _, key in ipairs(ROW_FADES) do
        local piece = row[key]
        if piece and (Look.Number(piece:GetAlpha()) or 1) > 0 then piece:SetAlpha(0) end
    end
    if rowPlates[row] then return end
    local plate = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    rowPlates[row] = plate
    C.mine[plate] = true
    Look.Art(plate, "namePlate")
    Look.Crop(plate, 0, 1, 0, 1)
    plate:SetSize(130, 62)
    local item = row.Item
    if item then Look.Pin(plate, "LEFT", item, "LEFT", 30, 0) else Look.Pin(plate, "LEFT", row, "LEFT", 35, 0) end
    local text = row.Text
    if text and item then
        Look.Pin(text, "LEFT", item, "RIGHT", 8, 0)
        text:SetSize(93, 38)
        if text.SetJustifyV then text:SetJustifyV("MIDDLE") end
    end
end

-- A row's plate only while it shows an item with a name.
local function PlateShown(row)
    local plate = rowPlates[row]
    if not plate then return end
    local item, text = row.Item, row.Text
    local named = text ~= nil and text.GetText and text:GetText()
    local wanted = (item == nil or item:IsShown()) and type(named) == "string" and not Look.Secret(named) and named ~= ""
    Look.Shown(plate, wanted)
end

local function EachRow(box, visit)
    local fine, frames = pcall(function()
        local list = {}
        if type(box.ForEachFrame) == "function" then
            box:ForEachFrame(function(frame) list[#list + 1] = frame end)
        elseif type(box.GetFrames) == "function" then
            for _, frame in ipairs(box:GetFrames() or {}) do list[#list + 1] = frame end
        end
        return list
    end)
    for _, row in ipairs(fine and frames or {}) do Look.Try(visit, row) end
end

local function Count(box)
    local fine, size = Look.Ask(box, "GetDataProviderSize")
    if fine and Look.Number(size) then return size end
    local rows = 0
    EachRow(box, function() rows = rows + 1 end)
    return rows
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------

local function Scrolled(box)
    local fine, share = Look.Ask(box, "GetScrollPercentage")
    return fine and Look.Number(share) or 0
end

local function Turn(box, way)
    local fine, range = Look.Ask(box, "GetDerivedScrollRange")
    range = fine and Look.Number(range) or 0
    local step = range > 0 and (3 * ROW / range) or 1
    local share = Look.Clamp(Scrolled(box) + way * step, 0, 1)
    Look.Ask(box, "SetScrollPercentage", share)
    if PlaySound and SOUNDKIT and SOUNDKIT.IG_ABILITY_PAGE_TURN then PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN) end
end

local function Arrow(pager, way, x)
    local window = pager:GetParent()
    local arrow = Look.Build("Button", pager, nil, { size = { 32, 32 } })
    ownFrames[arrow] = true
    Look.Pin(arrow, "BOTTOMLEFT", window, "BOTTOMLEFT", x, 6)
    local base = "Interface\\ChatFrame\\UI-ChatIcon-Scroll" .. way .. "-"
    arrow:SetNormalTexture(base .. "Up")
    arrow:SetPushedTexture(base .. "Down")
    arrow:SetDisabledTexture(base .. "Disabled")
    arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    local glow = arrow:GetHighlightTexture()
    if glow then glow:SetBlendMode("ADD") end
    arrow:SetScript("OnClick", function()
        local box = window.ScrollBox
        if not box then return end
        Turn(box, way == "Up" and -1 or 1)
        L.Update(window)
    end)
    return arrow
end

function L.Pager(window)
    if L.pager then return L.pager end
    local pager = Look.Build("Frame", window, nil, { size = { WIDE, 40 } })
    ownFrames[pager] = true
    Look.Pin(pager, "BOTTOMLEFT", window, "BOTTOMLEFT", 0, 0)
    L.up, L.down = Arrow(pager, "Up", 23), Arrow(pager, "Down", 146)
    local prev = Look.OwnLabel(pager, "prev", "GameFontNormal", "ARTWORK")
    Look.Pin(prev, "LEFT", L.up, "RIGHT", 2, 0)
    prev:SetText(PREV or "Prev")
    local nextLabel = Look.OwnLabel(pager, "next", "GameFontNormal", "ARTWORK")
    Look.Pin(nextLabel, "RIGHT", L.down, "LEFT", -2, 0)
    nextLabel:SetText(NEXT or "Next")
    L.pager = pager
    -- Its watch: every 0.5 s while the window shows (the pages or not).
    local watch = Look.Build("Frame", window, nil, { size = { 1, 1 } })
    ownFrames[watch] = true
    watch:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    local waited = 0
    watch:SetScript("OnUpdate", function(_, elapsed)
        waited = waited + (Look.Number(elapsed) or 0)
        if waited < 0.5 then return end
        waited = 0
        Look.Try(L.Update, window)
    end)
    return pager
end

-- Rows dressed, plates shown or not, the pager and the list's foot.
function L.Update(window)
    if not window or not C.applied or not C.dressed[window] then return end
    local box = window.ScrollBox
    if not box then return end
    EachRow(box, DressRow)
    EachRow(box, PlateShown)
    local pager = L.Pager(window)
    local paged = Count(box) > 4
    Look.Shown(pager, paged)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", window, "TOPLEFT", 21, -71)
    box:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 10, paged and 46 or 8)
    if paged then
        local share = Scrolled(box)
        L.up:SetEnabled(share > 0.001)
        L.down:SetEnabled(share < 0.999)
    end
end

-- The list's rows 41 tall with no padding, set once, and the list redrawn.
local function OwnView(box)
    if viewSet[box] then return end
    viewSet[box] = true
    local fine, view = Look.Ask(box, "GetView")
    if not fine or type(view) ~= "table" then return end
    Look.Ask(view, "SetElementExtent", ROW)
    if type(CreateScrollBoxPadding) == "function" then
        local made, padding = pcall(CreateScrollBoxPadding, 0, 0, 0, 0, 0)
        if made then Look.Ask(view, "SetPadding", padding) end
    end
    Look.Ask(box, "FullUpdate", true)
end

---------------------------------------------------------------------------
-- The window's extras
---------------------------------------------------------------------------

local loads
local function Watch(window)
    if loads then return end
    loads = Look.Build("Frame", UIParent, nil, { size = { 1, 1 } })
    loads:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    for _, event in ipairs({ "LOOT_SLOT_CLEARED", "LOOT_SLOT_CHANGED", "LOOT_OPENED" }) do Look.Listen(loads, event) end
    loads:SetScript("OnEvent", function()
        if not window:IsShown() then return end
        local function Later() Look.Try(L.Update, window) end
        if C_Timer and C_Timer.After then C_Timer.After(0, Later) else Later() end
    end)
    Look.Hook(window, "Resize", L.Hold)
    if type(window.UpdateShownState) == "function" then Look.Hook(window, "UpdateShownState", L.Hold) end
    Look.HookScript(window, "OnShow", function()
        L.Hold(window)
        Look.Try(L.Update, window)
    end, "chrome")
end

function X.Loot(window)
    FadeArt(window, window, 0)
    local strip = C.Found(window, "titleStrip")
    if strip then strip:Hide() end
    window:SetSize(WIDE, TALL)
    Own(window, "lootPanel", "BACKGROUND", -2, "lootPanel", 256, 0, 4)
    Own(window, "lootIcon", "BACKGROUND", -1, "lootIcon", 58, 10, -5)
    Own(window, "lootSkull", "ARTWORK", 0, "lootSkull", 58, 10, -5)
    local title = window.TitleContainer and window.TitleContainer.TitleText
    if title then Look.Pin(title, "CENTER", window, "TOPLEFT", 115, -24) end
    local close = window.ClosePanelButton or window.CloseButton
    if close then
        ns.SkinCloseButton(close, true)
        Look.Pin(close, "CENTER", window, "TOPLEFT", 177, -21)
    end
    local box = window.ScrollBox
    if box then
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", window, "TOPLEFT", 21, -71)
        box:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 10, 8)
        OwnView(box)
    end
    Look.Fade(window.ScrollBar)
    L.Pager(window)
    Watch(window)
    L.Update(window)
end
