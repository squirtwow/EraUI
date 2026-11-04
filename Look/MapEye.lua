-- The queue eye (QueueStatusButton) in its 1.x gold ring on the minimap's
-- lower left (the square's left edge), and the "Default Size" button beside
-- Edit Mode's Revert button in the eye's dialog.
--
-- The eye is an Edit Mode frame (Group Finder) on UIParent, so it doesn't
-- follow the cluster's scale by itself: its spot is converted to its own
-- units. It moves only through its plain ...Base methods, never in a fight,
-- never while Edit Mode says it was moved or while it's being dragged.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Map = Look.Map

-- From the backdrop's top left corner, in map units.
local ROUND_SPOT, SQUARE_SPOT = { 38.5, -116.5 }, { 27, -112 }
local QUEUE_SIZE = 33
-- The eye's own art, smaller, a touch right of and below the button's centre.
local ART_SCALE = 0.64

local rings = Look.Weak() -- the eye: EraUI's frame over it with the gold ring

local function Ratio(backing, queue)
    local outer, own = Look.Number(backing:GetEffectiveScale()), Look.Number(queue:GetEffectiveScale())
    if not outer or not own or outer <= 0 or own <= 0 then return 1 end
    return outer / own
end

function Map.PlaceEye(eye, backdrop)
    if Look.InFight() or Look.InDefaultPosition(eye) == false then return end
    local asked, dragging = Look.Ask(eye, "IsDragging")
    if asked and not Look.Secret(dragging) and dragging then return end
    local screen = UIParent
    if eye:GetParent() ~= screen then eye:SetParent(screen) end
    local spot, k = Map.worn and SQUARE_SPOT or ROUND_SPOT, Ratio(backdrop, eye)
    Look.Place(eye, "CENTER", backdrop, "TOPLEFT", spot[1] * k, spot[2] * k)
end

local function RingOver(queue)
    local holder = rings[queue]
    if holder == nil then
        holder = CreateFrame("Frame", nil, queue)
        holder:SetAllPoints(queue)
        local ring = Look.OwnTexture(holder, "ring", "OVERLAY")
        ring:SetSize(52, 52)
        Look.Pin(ring, "TOPLEFT", queue, "TOPLEFT", 1, -1)
        rings[queue] = holder
    end
    local art = queue.Eye
    local under = (art and Look.Number(art:GetFrameLevel())) or Look.Number(queue:GetFrameLevel()) or 0
    holder:SetFrameLevel(under + 5)
    Look.Art(Look.OwnPiece(holder, "ring"), "mapGoldRing")
end

local function DressQueue(queue)
    queue:SetSize(QUEUE_SIZE, QUEUE_SIZE)
    local art = queue.Eye
    if art and type(art.SetScale) == "function" then
        art:SetScale(ART_SCALE)
        Look.Pin(art, "CENTER", queue, "CENTER", 0.5 / ART_SCALE, (0.5 - ART_SCALE) / ART_SCALE)
    end
    RingOver(queue)
    -- Edit Mode's selection box over the minimap, so it can be grabbed there.
    local box = queue.Selection
    if box and type(box.GetFrameStrata) == "function" and box:GetFrameStrata() ~= "HIGH" then
        box:SetFrameStrata("HIGH")
    end
end

---------------------------------------------------------------------------
-- "Default Size" (Edit Mode's dialog for the eye)
---------------------------------------------------------------------------

local sizeButton

-- The player's own click, out of a fight, inside Edit Mode: Edit Mode's
-- size for the eye back to 100. The shared options code offers a reload
-- once Edit Mode closes (editWrote).
local function BackToDefault()
    local sizes = Enum and Enum.EditModeGroupFinderSetting
    local editor = EditModeSystemSettingsDialog
    if not sizes or sizes.Size == nil or Look.InFight() or not editor then return end
    if type(editor.OnSettingValueChanged) ~= "function" then return end
    if Look.Try(editor.OnSettingValueChanged, editor, sizes.Size, 100) then ns.editWrote = true end
end

local function SizeButton()
    if sizeButton then return sizeButton end
    sizeButton = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
    if ns.DarkNativeButton then ns.DarkNativeButton(sizeButton) end
    sizeButton:SetFrameStrata("DIALOG")
    sizeButton:SetSize(144, 28)
    sizeButton:SetText("Default Size")
    sizeButton:SetScript("OnClick", BackToDefault)
    return sizeButton
end

-- The dialog's Revert button while the dialog is open for the eye (and the
-- look is on), or nil; then the dialog and the eye.
local function RevertForQueue()
    local box, queue = EditModeSystemSettingsDialog, QueueStatusButton
    if not (Map.applied and box and queue and box:IsShown() and box.attachedToSystem == queue) then return nil end
    local row = box.Buttons
    local revert = row and row.RevertChangesButton
    if revert and revert:IsVisible() then return revert, box, queue end
    return nil
end

local function KeepSizeButton()
    local revert, box, queue = RevertForQueue()
    if not revert then
        if sizeButton then sizeButton:Hide() end
        return
    end
    local button = SizeButton()
    local root = Look.Number(UIParent:GetEffectiveScale()) or 1
    local ratio = (Look.Number(box:GetEffectiveScale()) or 0) / (root > 0 and root or 1)
    button:SetScale(ratio > 0 and ratio or 1)
    button:SetFrameLevel((Look.Number(box:GetFrameLevel()) or 0) + 20)
    Look.Pin(button, "LEFT", revert, "RIGHT", 6, 0)
    button:SetSize(144, 28)
    local own = Look.Number(queue:GetScale())
    button:SetEnabled(own ~= nil and math.abs(own - 1) > 0.001)
    button:Show()
end

---------------------------------------------------------------------------
-- The watcher (every 0.1 s, from the first layout that finds the eye)
---------------------------------------------------------------------------

local watcherOn = false
local seen = {} -- what the watcher saw last: Edit Mode's answer, the scale

-- Edit Mode's answer is kept as it comes (true, false, or nil while Edit
-- Mode hasn't set the eye up yet), so the moment Edit Mode sets it up (and
-- puts it on the game's own anchor) counts as a change too. Nothing is
-- looked at in a fight (the eye can't move then): a change made meanwhile
-- is seen once it's over.
local function EveryTenth()
    KeepSizeButton()
    local queue, backing = QueueStatusButton, MinimapBackdrop
    if not Map.applied or not queue or not backing or Look.InFight() then return end
    local answer = Look.InDefaultPosition(queue)
    local scale = Look.Number(queue:GetEffectiveScale())
    if answer == seen.answer and scale == seen.scale then return end
    seen.answer, seen.scale = answer, scale
    Map.PlaceEye(queue, backing)
end

-- Edit Mode puts the eye back on the game's own anchor (UpdateDefaultAnchor)
-- whenever the micro menu, the minimap or a layout changes, even while Edit
-- Mode stays open: the eye goes straight back to its 1.x spot after it.
-- The same rules as every move of the eye (never in a fight, never while
-- Edit Mode says it was moved or it's being dragged).
local STALE = {} -- what the watcher last saw, marked out of date
local function AnchorReset(queue)
    local backing = MinimapBackdrop
    if not Map.applied or not backing or queue ~= QueueStatusButton then return end
    if Look.InFight() then
        -- The watcher puts it back once the fight is over.
        seen.answer = STALE
        return
    end
    Map.PlaceEye(queue, backing)
    seen.answer, seen.scale = Look.InDefaultPosition(queue), Look.Number(queue:GetEffectiveScale())
end

function Map.LayEye(backdrop)
    local queue = QueueStatusButton
    if queue == nil then return end
    if not watcherOn then
        watcherOn = true
        Look.Every(0.1, EveryTenth)
    end
    Look.HookOrMiss(queue, "QueueStatusButton", "UpdateDefaultAnchor", function(button) Look.Try(AnchorReset, button) end)
    DressQueue(queue)
    Map.PlaceEye(queue, backdrop)
end
