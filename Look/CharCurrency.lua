-- The 1.x currency detail box (Classic look, "characterSheet"): clicking a
-- currency on the Currency tab opens a parchment box just right of the
-- window, where the reputation box opens, holding the game's own detail for
-- that currency: its name and count, description and caps, and the Unused
-- and Show on Backpack boxes. Clicking the same currency again, the box's X,
-- another tab, closing the window or the currency leaving the list closes it.
--
-- The detail is the game's side pane (TokenFrame's DetailFrame), which the
-- side-pane pass keeps muted (Look/CharTabs.lua). While the box is open the
-- pane is let back in, laid inside the box and worn in 1.x art (check boxes,
-- thin scroll bar, red button). Its boxes and their clicks are the game's
-- own, so ticking Show on Backpack watches the currency as the game does.
-- EraUI only reads which currency the game has chosen; it never chooses.
--
-- The game's pane stays in its own HIGH strata, so the box gives way to
-- EraUI's own windows (the spellbook, the talents, the quest log), which
-- open right of the window over the box's spot: it closes as one opens
-- there and doesn't open while one stands there. Otherwise the pane would
-- float over the window and take its clicks.
local _, EraUI = ...
local Look = EraUI.Look
local C = Look.Char

local BOX_W, BOX_H, BOX_DOWN = 236, 350, 48 -- the box's size, and how far below the window's top it starts
local FOOT = 110 -- the lower dialog box: the game's 90-tall foot (the ticks) and its border
local INSET = { 16, 28, 14, 10 } -- the game's pane in the box: left, top (under the X), right, bottom
local PARCHMENT = { 0.55, 0.47, 0.35 }
local box, shownFor -- the box (made on the first click) and the currency it is open for (its name, else its place)
local anchors       -- the game's own anchors on its pane, kept the first time it is moved
local dressed = Look.Weak() -- the game's pane: true once its pieces are in 1.x art

local function Pane()
    return TokenFrame and TokenFrame.DetailFrame
end

-- The currency the game has chosen: its place in the list and its name
-- (nil when secret), or nil.
local function Chosen()
    local list = TokenFrame
    local index = list and Look.Number(list.selectedID)
    if not index or index <= 0 then return nil end
    local name = list.selectedToken
    if Look.Secret(name) or type(name) ~= "string" then name = nil end
    return index, name
end

local function HideBox()
    if box then box:Hide() end
end

function C.CurrencyOpen()
    return box ~= nil and box:IsShown()
end

---------------------------------------------------------------------------
-- The game's pane in the box
---------------------------------------------------------------------------

local function Remember(pane)
    if anchors then return end
    anchors = {}
    for i = 1, pane:GetNumPoints() do anchors[i] = { pane:GetPoint(i) } end
end

-- Once: the modern divider faded, the Unused and Show on Backpack boxes in
-- the old check art, the description's thin scroll bar, the transfer button
-- in the old red.
local function Dress(pane)
    if dressed[pane] then return end
    dressed[pane] = true
    Look.Fade(pane.Divider)
    Look.SkinCheckBox(pane.InactiveCheckbox)
    Look.SkinCheckBox(pane.BackpackCheckbox)
    if pane.DescriptionScrollBar then Look.ThinScrollBar(pane.DescriptionScrollBar) end
    if pane.CurrencyTransferToggleButton then Look.SkinRedButton(pane.CurrencyTransferToggleButton) end
end

-- The pane inside the box, in sight and within reach. (The game shows it
-- itself as it opens its right pane for the click; shown here only if not.)
local function Hold(pane)
    if not C.Free(pane) then return end
    Remember(pane)
    local _, onto = pane:GetPoint(1)
    if onto ~= box or pane:GetNumPoints() ~= 2 then Look.Inside(pane, box, INSET[1], INSET[2], INSET[3], INSET[4]) end
    if not pane:IsShown() then pane:Show() end
    C.Unmute(pane)
end

---------------------------------------------------------------------------
-- The box
---------------------------------------------------------------------------

-- Closed: the game's pane muted again (the side-pane pass only runs when the
-- game lays its panes out, and a click or a tab change doesn't).
local function BoxHidden()
    shownFor = nil
    local pane = Pane()
    if C.active and pane then C.Mute(pane) end
end

-- After the game's own refresh of its pane: no currency chosen any more
-- (a header folded it away, the filter changed), the box goes.
local function AfterRefresh()
    if not C.active then return end
    if box and box:IsShown() and not Chosen() then HideBox() end
end

-- True when one of EraUI's own windows (Look/Windows.lua) shows over the
-- box's spot, worked out from the window so it is known before the box
-- shows. (A shown one the client can't place yet counts as over it.)
local function Covered()
    local windows = Look.Windows and Look.Windows.windows
    if type(windows) ~= "table" or not box then return false end
    local left, _, _, top = Look.Rect(CharacterFrame)
    local own, root = Look.Number(box:GetEffectiveScale()), UIParent and Look.Number(UIParent:GetEffectiveScale())
    if not (left and top and own and root) or own <= 0 or root <= 0 then return false end
    local f = own / root
    left, top = left + C.ART_RIGHT * f, top - BOX_DOWN * f
    local right, bottom = left + BOX_W * f, top - BOX_H * f
    for _, window in ipairs(windows) do
        if window:IsShown() then
            local l, b, r, t = Look.Rect(window)
            if not l or (l < right and r > left and b < top and t > bottom) then return true end
        end
    end
    return false
end

-- After the window manager's pass (one of its windows opened, closed or
-- moved): the box gives way at once.
local function AfterPlace()
    if box and box:IsShown() and Covered() then HideBox() end
end

local function HookWindows()
    local manager = Look.Windows
    if type(manager) == "table" and type(manager.Place) == "function" then
        Look.Hook(manager, "Place", function() Look.Try(AfterPlace) end, "currencyBox")
    end
end

-- Every 0.2 s while it shows: the box goes once there is nothing to show,
-- or one of EraUI's windows stands over it (the backup to AfterPlace).
local waited = 0
local function Watch(_, elapsed)
    waited = waited + (elapsed or 0)
    if waited < 0.2 then return end
    waited = 0
    local pane = Pane()
    if not (C.active and pane and pane:IsShown() and Chosen()) or Covered() then HideBox() end
end

local function MakeBox(list, pane)
    local sheet = CharacterFrame
    box = Look.Build("Frame", list, nil, { name = "EraUIClassicCurrencyDetail", size = { BOX_W, BOX_H },
        level = (Look.Number(sheet:GetFrameLevel()) or 1) + 30, mouse = true, hidden = true })
    local level = Look.Number(box:GetFrameLevel()) or 1
    -- Two dialog boxes, as the reputation box has: the upper one parchment,
    -- the lower one (the ticks) over its foot by 12.
    local upper = C.DialogBox(box, level)
    upper:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    upper:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, FOOT - 12)
    local lower = C.DialogBox(box, level + 1)
    Look.Inside(lower, box, 0, BOX_H - FOOT, 0, 0)
    local page = Look.OwnTexture(upper, "parchment", "BORDER")
    page:SetTexture("Interface\\QuestFrame\\QuestBG")
    Look.Crop(page, 0, 0.6, 0, 0.55)
    Look.Tint(page, PARCHMENT)
    Look.Inside(page, upper, 10, 10, 10, 10)
    local close = Look.Build("Button", box, nil, { size = { 32, 32 }, level = level + 2 })
    Look.Pin(close, "TOPRIGHT", box, "TOPRIGHT", -3, -3)
    Look.SkinCloseButton(close)
    close:SetScript("OnClick", HideBox)
    box:SetScript("OnHide", BoxHidden)
    box:SetScript("OnUpdate", Watch)
    -- (The box is the Currency tab's own frame, so it is out of sight with
    -- the tab; these close it, so it never comes back by itself.)
    Look.HookScript(list, "OnHide", HideBox, "currencyBox")
    Look.HookScript(sheet, "OnHide", HideBox, "currencyBox")
    Look.Hook(pane, "Refresh", function() Look.Try(AfterRefresh) end, "currencyBox")
    HookWindows()
end

-- Shift-clicks (a chat link, watching from the list) leave the box alone.
local function Modified()
    if type(IsModifiedClick) ~= "function" then return false end
    for _, action in ipairs({ "CHATLINK", "TOKENWATCHTOGGLE" }) do
        local fine, held = pcall(IsModifiedClick, action)
        if fine and held == true then return true end
    end
    return false
end

-- A click on a currency's row (the game's own click has run first). A plain
-- click always makes that currency the game's chosen one, so the box opens
-- for the chosen currency, or closes when it is already open for it. (The
-- row itself isn't read: the game's click refills the list, so the row may
-- hold another currency by now.)
function C.CurrencyRowClicked()
    local list, pane = TokenFrame, Pane()
    if not (C.active and list and pane) or Modified() then return end
    local index, name = Chosen()
    if not index then return end
    if not box then MakeBox(list, pane) end
    HookWindows() -- (once; here too in case the window manager came late)
    local which = name or index
    if box:IsShown() and which == shownFor then return HideBox() end
    -- One of EraUI's windows over the spot: no box while it stands there.
    if Covered() then return HideBox() end
    shownFor = which
    Look.Pin(box, "TOPLEFT", CharacterFrame, "TOPLEFT", C.ART_RIGHT, -BOX_DOWN)
    box:Show()
    Dress(pane)
    Hold(pane)
end

-- The window turned off: the box closed, the game's pane back in its own
-- place (it stays muted until the reload, as the rest of the side pane).
function C.RestoreCurrencyBox()
    HideBox()
    local pane = Pane()
    if not (pane and anchors and C.Free(pane)) then return end
    pane:ClearAllPoints()
    for _, point in ipairs(anchors) do pane:SetPoint(point[1], point[2], point[3], point[4], point[5]) end
    anchors = nil
end

-- What the tests read.
function C.CurrencyBox()
    return box, shownFor
end
