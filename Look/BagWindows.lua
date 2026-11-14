-- Dressing one of the game's bag windows in the 1.x bag art. The window stays
-- the game's own, with all its behaviour: EraUI sizes it, draws the sheet on
-- it, moves its slots onto the old grid (never resizing, re-parenting or
-- replacing an item button), fades the game's own art (alpha, which survives
-- the game showing its pieces again) and places the portrait, name, close
-- button, money, search box and sort button where the art has room for them,
-- and the watched currencies beside the gold.
--
-- A dressing starts from scratch every time, so it can follow the game's own
-- updates (a bag opening, changing size, laying its items out again, moving
-- its search box, laying out its currencies, its gold changing width). It
-- may run in a fight (a bag opened mid-fight must look right); a frame the
-- game guards is then left alone and the window is dressed again when the
-- fight ends.
local _, EraUI = ...
local Look = EraUI.Look
local B = Look.Bags

local KEPT = { "PortraitButton", "MoneyFrame", "CloseButton", "FilterIcon" }

local skinnedCloses = Look.Weak() -- close button: given the 1.x X
local readySlots = Look.Weak()    -- item button: hooked and ringed
local waiting = Look.Weak()       -- window: to dress again after the fight
local following = Look.Weak()     -- window: its updates hooked

---------------------------------------------------------------------------
-- After a fight
---------------------------------------------------------------------------

local fightWatch

local function FightOver()
    local again = {}
    for window in pairs(waiting) do again[#again + 1] = window end
    for _, window in ipairs(again) do
        waiting[window] = nil
        if B.active and window:IsShown() then Look.Try(B.Dress, window) end
    end
end

-- True when `frame` may be moved or sized now; a guarded frame in a fight
-- isn't, and its window waits for the fight's end.
function B.Free(window, frame)
    if not Look.InFight() then return true end
    local fine, guarded = Look.Ask(frame, "IsProtected")
    if not fine or (not Look.Secret(guarded) and not guarded) then return true end
    waiting[window] = true
    if not fightWatch then
        fightWatch = Look.Build("Frame", nil, nil, { size = { 1, 1 } })
        Look.Listen(fightWatch, "PLAYER_REGEN_ENABLED")
        fightWatch:SetScript("OnEvent", FightOver)
    end
    return false
end

---------------------------------------------------------------------------
-- The slots
---------------------------------------------------------------------------

-- An empty slot shows the sheet's dark cell: the game draws its modern
-- empty-slot art through the icon, so the icon shows only with an item, and
-- its greyed bag icon (Combine Bags, only on builds that have it) never.
function B.EmptyLook(button)
    Look.Fade(button.EmptyBagIcon)
    local picture, filled = button.icon, button.hasItem
    if not picture or Look.Secret(filled) then return end
    picture:SetAlpha(filled and 1 or 0)
end

local function IconChanged(button)
    if B.active then B.EmptyLook(button) end
end

local function FirstLook(button)
    if readySlots[button] then return end
    readySlots[button] = true
    if type(button.SetItemButtonTexture) == "function" then Look.Hook(button, "SetItemButtonTexture", IconChanged) end
    B.Ring(button, 64)
end

local function Items(window)
    local list = {}
    local fine = pcall(function()
        for _, button in window:EnumerateValidItems() do list[#list + 1] = button end
    end)
    return fine and list or {}
end

local function LaySlots(window, plan, items)
    local count = #items
    for i, button in ipairs(items) do
        FirstLook(button)
        if B.Free(window, button) then
            local point, x, y = B.Spot(plan, B.Cell(plan, i, count))
            Look.Pin(button, "BOTTOMRIGHT", window, point, x, y)
        end
        B.EmptyLook(button)
    end
end

---------------------------------------------------------------------------
-- The game's own art, faded
---------------------------------------------------------------------------

local function IsSlot(child)
    return type(child.GetBagID) == "function" or type(child.GetSlotAndBagID) == "function"
end

local function FadeTextures(owner, spare)
    Look.EachRegion(owner, function(piece)
        if piece ~= spare and not B.mine[piece] and B.IsTexture(piece) then Look.Fade(piece) end
    end)
end

-- The window's own textures, and those of its direct children but the ones
-- kept whole, the item buttons (never looked into: Bag Item Levels hangs its
-- marks there) and the portrait itself.
local function FadeGameArt(window)
    FadeTextures(window)
    local kept = {}
    for _, key in ipairs(KEPT) do
        if window[key] then kept[window[key]] = true end
    end
    if BagItemSearchBox then kept[BagItemSearchBox] = true end
    if BagItemAutoSortButton then kept[BagItemAutoSortButton] = true end
    local face = Look.Path(window, "PortraitContainer", "portrait")
    for _, child in ipairs({ window:GetChildren() }) do
        if not kept[child] and not IsSlot(child) then FadeTextures(child, face) end
    end
    local bg = window.Bg
    if bg and B.IsTexture(bg) then Look.Fade(bg) end
end

---------------------------------------------------------------------------
-- Portrait, name, close button, money, search box and sort button
---------------------------------------------------------------------------

local function PlacePortrait(window, plan)
    local holder = window.PortraitContainer
    if not holder then return end
    if B.Free(window, holder) then
        holder:SetSize(40, 40)
        Look.Pin(holder, "TOPLEFT", window, "TOPLEFT", 4, -4)
        local level = Look.Number(window:GetFrameLevel())
        if level then holder:SetFrameLevel(level) end
    end
    local face = holder.portrait
    if not face then return end
    Look.Fill(face, holder)
    face:SetDrawLayer("BACKGROUND", -8)
    if plan.backpack then
        Look.Art(face, "backpack")
        Look.Crop(face, 0, 1, 0, 1)
    end
end

-- The bag's name, white, centred on the art's name plate.
local function PlaceName(window, plan)
    local plate = Look.Path(window, "TitleContainer", "TitleText")
    if not plate then return end
    if GameFontHighlight then plate:SetFontObject(GameFontHighlight) end
    Look.Pin(plate, "TOPLEFT", window, "TOPLEFT", 47, -10)
    plate:SetWidth(112 + plan.wider)
    plate:SetJustifyH("CENTER")
end

local function PlaceClose(window, plan)
    local close = window.CloseButton
    if not close or not B.Free(window, close) then return end
    if not skinnedCloses[close] then
        skinnedCloses[close] = true
        Look.SkinCloseButton(close)
    end
    if plan.backpack then Look.Pin(close, "TOPRIGHT", window, "TOPRIGHT", 1, -2)
    else Look.Pin(close, "TOPRIGHT", window, "TOPRIGHT", -2, 0) end
end

local function PlaceMoney(window, plan)
    local money = window.MoneyFrame
    if not plan.backpack or not money then return end
    if B.Free(window, money) then Look.Pin(money, "TOPRIGHT", window, "TOPRIGHT", -B.MONEY_RIGHT, -B.MoneyTop(plan)) end
    FadeTextures(money.Border)
end

-- The game hands the search box and the sort button to whichever window
-- holds the backpack, at their own low level: the One Bag window's art
-- covered them. Lifted ten over the window they show again.
local function PlaceSearch(window)
    local level = Look.Number(window:GetFrameLevel()) or 1
    local search, sorter = BagItemSearchBox, BagItemAutoSortButton
    if search and search:GetParent() == window and B.Free(window, search) then
        Look.Pin(search, "TOPLEFT", window, "TOPLEFT", 52, -31)
        search:SetSize(104, 16)
        search:SetFrameLevel(level + 10)
    end
    if sorter and sorter:GetParent() == window and B.Free(window, sorter) then
        Look.Pin(sorter, "TOPRIGHT", window, "TOPRIGHT", -10, -28)
        sorter:SetFrameLevel(level + 10)
    end
end

---------------------------------------------------------------------------
-- Asking a window
---------------------------------------------------------------------------

local function Says(window, method)
    local fine, answer = Look.Ask(window, method)
    return fine and not Look.Secret(answer) and answer == true
end

-- How many slots the window holds: nil when it can't be read (a secret),
-- 0 when it doesn't say.
local function SlotCount(window)
    local fine, size = Look.Ask(window, "GetBagSize")
    if fine and Look.Secret(size) then return nil end
    return fine and Look.Number(size) or 0
end

---------------------------------------------------------------------------
-- Watched currencies, on the gold's strip
---------------------------------------------------------------------------

-- The game's watched-currency row (BackpackTokenFrame, one per UI), while
-- this backpack-style window holds it and shows it. The game pins the row to
-- the window's bottom edge, 8 in from each side, and lets as many
-- currencies be watched as 50-wide slots fit in its width (before the bags
-- are first opened: in its own window's width, 430 for the One Bag window).
-- The row keeps the game's anchors, its right one moved out past the 1.x
-- window's right when that window is narrower than the game's own (the One
-- Bag window under ten columns), so the game allows at least as many as on
-- its own window. The row draws nothing of its own: its box is faded and
-- its buttons are moved onto the art.
local TOKEN_SLOT = 50  -- the game's slot for one currency, when its width can't be read
local MONEY_MOST = 168 -- the widest the game lets the bag's gold grow
local ROW_IN = 8       -- the game's row, in from the window's sides and bottom

local function Tracker(window, plan)
    local tracker = BackpackTokenFrame
    if not plan.backpack or type(tracker) ~= "table" then return nil end
    local fine, parent = Look.Ask(tracker, "GetParent")
    if not fine or parent ~= window or not Says(tracker, "IsShown") then return nil end
    return tracker
end

-- The row's buttons in the game's watched order: its own list of them (the
-- ones in use, re-made by every Update), else its shown children by ID.
local function Watched(tracker)
    local found = {}
    local listed = tracker.Tokens
    if type(listed) == "table" then
        for i, button in pairs(listed) do
            if type(i) == "number" and type(button) == "table" then found[#found + 1] = { i, button } end
        end
    else
        for _, child in ipairs({ tracker:GetChildren() }) do
            local fine, id = Look.Ask(child, "GetID")
            id = fine and Look.Number(id)
            if id and child.Count and child.Icon and Says(child, "IsShown") then found[#found + 1] = { id, child } end
        end
    end
    table.sort(found, function(a, b) return a[1] < b[1] end)
    local buttons = {}
    for k, pair in ipairs(found) do buttons[k] = pair[2] end
    return buttons
end

-- The gold's text (its coins share one font), for the currencies' look.
local function GoldText(money)
    for _, coin in ipairs({ "GoldButton", "SilverButton", "CopperButton" }) do
        local text = Look.Path(money, coin, "Text")
        if text then return text end
    end
end

-- How wide the gold is: the game sizes it to its coins (0 when it isn't
-- shown; the widest it may be when its width can't be read).
local function GoldWidth(money)
    if not money or not Says(money, "IsShown") then return 0 end
    local fine, across = Look.Ask(money, "GetWidth")
    return fine and Look.Number(across) or MONEY_MOST
end

-- One currency in the gold's font and colour: its icon at the button's
-- right, its amount right against the icon, both on the button's middle,
-- the amount as tall as its font (the game's is 10 high, for a smaller
-- font). Returns how wide the two are.
local function StyleToken(button, gold)
    local count, icon = button.Count, button.Icon
    if not count or not icon then return nil end
    if gold then
        local fine, font = Look.Ask(gold, "GetFontObject")
        if fine and type(font) == "table" then count:SetFontObject(font) end
        local read, r, g, b = pcall(gold.GetTextColor, gold)
        if read and Look.Number(r) and Look.Number(g) and Look.Number(b) then count:SetTextColor(r, g, b) end
    end
    local read, _, tall = pcall(count.GetFont, count)
    tall = read and Look.Number(tall)
    if tall then count:SetHeight(math.ceil(tall) + 2) end
    Look.Pin(icon, "RIGHT", button, "RIGHT", 0, 0)
    Look.Pin(count, "RIGHT", icon, "LEFT", 0, 0)
    local fine, across = Look.Ask(count, "GetStringWidth")
    across = fine and Look.Number(across)
    if not across then return TOKEN_SLOT end
    local _, side = Look.Ask(icon, "GetWidth")
    return math.ceil(across) + (Look.Number(side) or 12)
end

-- The row as wide as the game's own window would make it, when the 1.x
-- window is narrower (its width is how many currencies the game lets be
-- watched); else just where the game pins it. Never sized or re-parented.
local function RowWidth(window, plan, tracker)
    if not B.Free(window, tracker) then return end
    local _, own = Look.Ask(window, "CalculateWidth")
    local past = math.max(0, (Look.Number(own) or 0) - plan.width)
    tracker:ClearAllPoints()
    tracker:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", ROW_IN, ROW_IN)
    tracker:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", past - ROW_IN, ROW_IN)
end

-- After the row's own Update (a currency watched or unwatched, an amount
-- changed: CURRENCY_DISPLAY_UPDATE runs it, Shift-click runs it), whose grid
-- put its buttons back in a row from its right: the window dressed again.
local function TrackerUpdated(tracker)
    if not B.active then return end
    local fine, window = Look.Ask(tracker, "GetParent")
    if fine and following[window] and Says(window, "IsShown") then Look.Try(B.Dress, window) end
end

-- The currencies this window shows, styled and measured, and where they go
-- (B.TokenSpots, with how many strips under the gold's they need); nothing
-- when it shows none.
local function Currencies(window, plan)
    local tracker = Tracker(window, plan)
    if not tracker then return nil, nil, nil, 0 end
    Look.HookOwn(tracker, "Update", TrackerUpdated)
    RowWidth(window, plan, tracker)
    FadeTextures(tracker.Border)
    local money = window.MoneyFrame
    local gold = money and GoldText(money)
    local tokens, widths = Watched(tracker), {}
    for i, button in ipairs(tokens) do widths[i] = StyleToken(button, gold) or TOKEN_SLOT end
    local spots, strips = B.TokenSpots(plan, widths, GoldWidth(money))
    return tokens, widths, spots, strips
end

-- Each currency as wide as its amount and icon (so none covers another's
-- mouse-over), its middle on the gold's (or a strip under it); one wider
-- than a whole strip hidden until the game shows it again.
local function PlaceTokens(window, plan, tokens, widths, spots)
    if not tokens then return end
    local _, tall = Look.Ask(window.MoneyFrame, "GetHeight")
    local middle = -B.MoneyTop(plan) - (Look.Number(tall) or 13) / 2
    for i, button in ipairs(tokens) do
        local spot = spots[i]
        if B.Free(window, button) then
            if spot then
                button:SetWidth(widths[i])
                Look.Pin(button, "LEFT", window, "TOPLEFT", spot[1], middle - (spot[2] - 1) * B.STRIP_TALL)
            end
            Look.Shown(button, spot and true or false)
        end
    end
end

---------------------------------------------------------------------------
-- One dressing, and when
---------------------------------------------------------------------------

-- The gold is placed first: its width is read (single-pinned, the width the
-- game gave it) to fit the currencies beside it, and strips under it change
-- the plan.
function B.Dress(window)
    if not B.active or not window or type(window.GetBagSize) ~= "function" then return end
    local size = SlotCount(window)
    if not size or size <= 1 then return end
    local combined = Says(window, "IsCombinedBagContainer")
    local columns = combined and B.Columns(Look.Saved().oneBagColumns) or 4
    local backpack = combined or Says(window, "IsBackpack")
    local plan = B.Plan(size, columns, backpack, combined)
    local items = Items(window)
    PlaceMoney(window, plan)
    local tokens, widths, spots, strips = Currencies(window, plan)
    if strips > 0 then plan = B.Plan(size, columns, backpack, combined, strips) end
    if B.Free(window, window) then window:SetSize(plan.width, plan.height) end
    B.DrawSheet(window, plan)
    LaySlots(window, plan, items)
    B.DrawStone(window, plan, #items)
    FadeGameArt(window)
    PlacePortrait(window, plan)
    PlaceName(window, plan)
    PlaceClose(window, plan)
    PlaceTokens(window, plan, tokens, widths, spots)
    PlaceSearch(window)
end

-- From the game's own updates and the window's showing: dressed again while
-- the area is on.
local function Again(window)
    if B.active then Look.Try(B.Dress, window) end
end

-- UpdateCurrencyFrames: the game showing or hiding the currency row, and
-- pinning the gold back above it.
local GAME_UPDATES = { "UpdateFrameSize", "UpdateItemLayout", "UpdateSearchBox", "UpdateMiscellaneousFrames",
    "UpdateCurrencyFrames" }

-- Once per window: post-hooks on its own update methods (each only when the
-- window carries it itself) and on its showing; on a backpack-style window,
-- its gold changing width (more digits) too, so the currencies stay clear.
function B.Watch(window)
    if following[window] then return end
    following[window] = true
    for _, method in ipairs(GAME_UPDATES) do Look.HookOwn(window, method, Again) end
    Look.HookScript(window, "OnShow", Again, "bags")
    local money = window.MoneyFrame
    if money and (Says(window, "IsBackpack") or Says(window, "IsCombinedBagContainer")) then
        Look.HookScript(money, "OnSizeChanged", function()
            if Says(window, "IsShown") then Again(window) end
        end, "bags")
    end
end

-- Every bag window the game has: its container's list, the numbered ones
-- (the same frames again) and the One Bag window, each once.
function B.Windows()
    local found, seen = {}, {}
    local function Add(window)
        if type(window) == "table" and not seen[window] then
            seen[window] = true
            found[#found + 1] = window
        end
    end
    local holder = ContainerFrameContainer
    if holder and type(holder.ContainerFrames) == "table" then
        for _, window in ipairs(holder.ContainerFrames) do Add(window) end
    end
    for i = 1, 13 do Add(_G["ContainerFrame" .. i]) end
    Add(ContainerFrameCombinedBags)
    return found
end
