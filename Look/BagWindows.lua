-- Dressing one of the game's bag windows in the 1.x bag art. The window stays
-- the game's own, with all its behaviour: EraUI sizes it, draws the sheet on
-- it, moves its slots onto the old grid (never resizing, re-parenting or
-- replacing an item button), fades the game's own art (alpha, which survives
-- the game showing its pieces again) and places the portrait, name, close
-- button, money, search box and sort button where the art has room for them.
--
-- A dressing starts from scratch every time, so it can follow the game's own
-- updates (a bag opening, changing size, laying its items out again, moving
-- its search box). It may run in a fight (a bag opened mid-fight must look
-- right); a frame the game guards is then left alone and the window is
-- dressed again when the fight ends.
local _, EraUI = ...
local Look = EraUI.Look
local B = Look.Bags

local KEPT = { "PortraitButton", "MoneyFrame", "CloseButton", "FilterIcon" }

local skinnedCloses = Look.Weak() -- close button: given the 1.x X
local readySlots = Look.Weak()    -- item button: hooked and ringed
local waiting = Look.Weak()       -- window: to dress again after the fight

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
    if B.Free(window, money) then Look.Pin(money, "TOPRIGHT", window, "TOPRIGHT", -6, -215 - 41 * plan.extra) end
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
-- One dressing
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

function B.Dress(window)
    if not B.active or not window or type(window.GetBagSize) ~= "function" then return end
    local size = SlotCount(window)
    if not size or size <= 1 then return end
    local combined = Says(window, "IsCombinedBagContainer")
    local columns = combined and B.Columns(Look.Saved().oneBagColumns) or 4
    local plan = B.Plan(size, columns, combined or Says(window, "IsBackpack"), combined)
    local items = Items(window)
    if B.Free(window, window) then window:SetSize(plan.width, plan.height) end
    B.DrawSheet(window, plan)
    LaySlots(window, plan, items)
    B.DrawStone(window, plan, #items)
    FadeGameArt(window)
    PlacePortrait(window, plan)
    PlaceName(window, plan)
    PlaceClose(window, plan)
    PlaceMoney(window, plan)
    PlaceSearch(window)
end

-- From the game's own updates and the window's showing: dressed again while
-- the area is on.
local function Again(window)
    if B.active then Look.Try(B.Dress, window) end
end

local GAME_UPDATES = { "UpdateFrameSize", "UpdateItemLayout", "UpdateSearchBox", "UpdateMiscellaneousFrames" }
local following = Look.Weak()

-- Once per window: post-hooks on its own update methods (each only when the
-- window carries it itself) and on its showing.
function B.Watch(window)
    if following[window] then return end
    following[window] = true
    for _, method in ipairs(GAME_UPDATES) do Look.HookOwn(window, method, Again) end
    Look.HookScript(window, "OnShow", Again, "bags")
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
