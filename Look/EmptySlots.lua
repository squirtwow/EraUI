-- Empty action slots ("emptySlots", from Hide Empty Action Slots). On:
--   * the side bars hide their empty buttons, until a spell is dragged or the
--     spellbook is open (the game's grid);
--   * Action Bar 1's empty slots keep a stone socket and ring, and the key
--     bound to them, the way 1.x showed an empty bar.
-- The sockets and labels sit on EraUI's own frames laid over the buttons;
-- nothing is added to or written on the game's buttons. Only alpha is set on
-- the game's side-bar buttons.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Number = Look.Number

local SIDE_BARS = Look.Words("MultiBarBottomLeft MultiBarBottomRight MultiBarRight MultiBarLeft")
-- The game's "show grid" reasons that show an empty side-bar button (a spell
-- in hand, the spellbook open); its own Always Show Buttons reason (1) doesn't.
local SHOWING_REASONS = { 2, 4 }

local wanted, dragging = false, false
local hidByUs = Look.Weak() -- side-bar button: EraUI set its alpha to 0
local overlays = {}         -- slot number: { under, over, socket, ring, keyText }

local function HasBit(value, flag)
    value = Number(value)
    return value ~= nil and math.floor(value / flag) % 2 == 1
end

local function Holds(actionButton)
    if type(actionButton.HasAction) == "function" then
        local fine, has = pcall(actionButton.HasAction, actionButton)
        if fine then return has and true or false end
    end
    local slotNumber = actionButton.action
    if HasAction and slotNumber ~= nil then
        local fine, has = pcall(HasAction, slotNumber)
        if fine then return has and true or false end
    end
    return true
end

-- Shown while a spell is dragged (the grid) or the spellbook is open.
local function GridWants(actionButton)
    if dragging then return true end
    local fine, reasons = pcall(actionButton.GetAttribute, actionButton, "showgrid")
    if not fine then return false end
    for _, reason in ipairs(SHOWING_REASONS) do
        if HasBit(reasons, reason) then return true end
    end
    return false
end

local function SideButton(actionButton)
    local alpha = (Holds(actionButton) or GridWants(actionButton)) and 1 or 0
    if (Number(actionButton:GetAlpha()) or 1) ~= alpha then actionButton:SetAlpha(alpha) end
    if alpha == 0 then hidByUs[actionButton] = true end
end

---------------------------------------------------------------------------
-- Action Bar 1's empty slots
---------------------------------------------------------------------------

local function Overlay(slotNumber)
    if overlays[slotNumber] then return overlays[slotNumber] end
    local made = {}
    made.under = Look.Build("Frame", UIParent, nil, { size = { 36, 36 } })
    made.over = Look.Build("Frame", UIParent, nil, { size = { 36, 36 } })
    made.socket = made.under:CreateTexture(nil, "BACKGROUND", nil, -1)
    made.ring = made.under:CreateTexture(nil, "ARTWORK")
    for _, face in ipairs({ made.socket, made.ring }) do Look.Pin(face, "CENTER", made.under, "CENTER") end
    Look.Art(made.socket, "slotEmpty")
    Look.Alpha(made.socket, 0.4)
    Look.Art(made.ring, "slotNormal")
    Look.Crop(made.ring, 12 / 64, 51 / 64, 12 / 64, 51 / 64)
    Look.Alpha(made.ring, 0.5)
    made.keyText = Look.Label(made.over, "NumberFontNormalSmall", "OVERLAY")
    Look.Pin(made.keyText, "TOPRIGHT", made.over, "TOPRIGHT", -3, -2)
    made.keyText:SetJustifyH("RIGHT")
    made.keyText:SetShadowColor(0, 0, 0, 1)
    made.keyText:SetShadowOffset(1, -1)
    overlays[slotNumber] = made
    return made
end

local function Visible(region)
    return region ~= nil and region:IsShown() and (Number(region:GetAlpha()) or 0) > 0
end

local function OwnRingShows(actionButton)
    if not actionButton:IsVisible() then return false end
    local seen = Number(actionButton.GetEffectiveAlpha and actionButton:GetEffectiveAlpha())
    return not (seen and seen <= 0) and Visible(actionButton:GetNormalTexture())
end

local function OwnKeyShows(actionButton)
    local hotkey = actionButton.HotKey
    if not hotkey or not actionButton:IsVisible() or not Visible(hotkey) then return false end
    local shown = hotkey:GetText()
    return type(shown) == "string" and shown ~= "" and shown ~= RANGE_INDICATOR
end

local function KeyFor(slotNumber)
    local key = GetBindingKey and GetBindingKey("ACTIONBUTTON" .. slotNumber)
    if not key then return nil end
    return GetBindingText and GetBindingText(key, "KEY_", true) or key
end

-- EraUI's two frames over the button, at its scale and its holder's fade,
-- socket just under its own art and the key label over it.
local function Cover(made, actionButton, holder)
    local own, root = Number(actionButton:GetEffectiveScale()), Number(UIParent:GetEffectiveScale())
    local ratio = (own and root and root > 0) and own / root or 1
    local wide = Number(actionButton:GetWidth()) or 36
    local tall = Number(actionButton:GetHeight()) or wide
    local layer = Number(actionButton:GetFrameLevel()) or 2
    local faded = Number(holder.GetEffectiveAlpha and holder:GetEffectiveAlpha()) or 1
    for _, cover in ipairs({ made.under, made.over }) do
        cover:SetScale(ratio)
        cover:SetAlpha(faded)
        cover:SetFrameStrata(actionButton:GetFrameStrata())
        Look.Pin(cover, "CENTER", actionButton, "CENTER")
        cover:SetSize(wide, tall)
    end
    made.under:SetFrameLevel(math.max(0, layer - 1))
    made.over:SetFrameLevel(layer + 3)
    made.socket:SetSize(66 * wide / 36, 66 * wide / 36)
    made.ring:SetSize(40 * wide / 36, 40 * wide / 36)
end

local function CopyHotKeyLook(made, hotkey)
    local font, size, flags = hotkey:GetFont()
    if font then made.keyText:SetFont(font, size, flags) end
    made.keyText:SetTextColor(hotkey:GetTextColor())
end

local function MainSlot(slotNumber)
    local actionButton = _G["ActionButton" .. slotNumber]
    if not actionButton then return end
    local made = Overlay(slotNumber)
    -- The game hides an empty button but keeps its holder (the slot) shown;
    -- a hidden holder is no slot at all (past Edit Mode's icon count, or the
    -- whole bar away for a vehicle or a pet battle).
    local holder = actionButton.container or actionButton:GetParent()
    if Holds(actionButton) or not (holder and holder:IsVisible()) then
        made.under:Hide()
        made.over:Hide()
        return
    end
    Cover(made, actionButton, holder)
    made.under:SetShown(not dragging and not OwnRingShows(actionButton))
    local key = KeyFor(slotNumber)
    local labelShown = key ~= nil and not dragging and not EraUI:GetSetting("hideKeybindText")
        and not OwnKeyShows(actionButton)
    if labelShown then
        if actionButton.HotKey then CopyHotKeyLook(made, actionButton.HotKey) end
        made.keyText:SetText(key)
    end
    made.over:SetShown(labelShown)
end

local function Refresh()
    if not wanted then return end
    for _, barName in ipairs(SIDE_BARS) do
        local owner = _G[barName]
        if owner then
            for _, actionButton in ipairs(Look.BarButtons(owner)) do SideButton(actionButton) end
        end
    end
    for slotNumber = 1, 12 do MainSlot(slotNumber) end
end

-- One pass at a time. Events and the game's grid calls book one for the
-- next frame, however many come at once (a rank swap or a page change
-- changes many slots). Otherwise one look a second catches what nothing
-- announces: the game's Always Show Buttons, a grid set some other way.
local due = false
local function Book()
    if wanted then due = true end
end
local function Pass()
    due = false
    Refresh()
end
Look.Every(function() return due and 0 or 1 end, Pass)

local slotEvents = CreateFrame("Frame")
for _, event in ipairs(Look.Words([[UPDATE_BINDINGS ACTIONBAR_SHOWGRID ACTIONBAR_HIDEGRID ACTIONBAR_SLOT_CHANGED
    PLAYER_ENTERING_WORLD UPDATE_BONUS_ACTIONBAR ACTIONBAR_PAGE_CHANGED CVAR_UPDATE EDIT_MODE_LAYOUTS_UPDATED]])) do
    Look.Listen(slotEvents, event)
end
slotEvents:SetScript("OnEvent", function(_, event)
    if event == "ACTIONBAR_SHOWGRID" or event == "ACTIONBAR_HIDEGRID" then dragging = event == "ACTIONBAR_SHOWGRID" end
    Book()
end)

-- The game's spellbooks show the side bars' grid with no event: its own
-- calls are post-hooked (each once, and only where the client has them).
local function HookGrids()
    for _, name in ipairs({ "MultiActionBar_ShowAllGrids", "MultiActionBar_HideAllGrids" }) do
        if type(_G[name]) == "function" then Look.HookGlobal(name, Book, "emptySlots") end
    end
end

-- Off: EraUI's sockets and labels hidden, and the side-bar buttons it faded
-- shown again.
local function Stop()
    wanted = false
    for _, made in pairs(overlays) do
        made.under:Hide()
        made.over:Hide()
    end
    for actionButton in pairs(hidByUs) do
        Look.Alpha(actionButton, 1)
        hidByUs[actionButton] = nil
    end
end

local function Start()
    wanted = true
    HookGrids()
    Refresh()
end

Look.EmptySlotsRefresh = Refresh
ns.RegisterModule("emptySlots", { apply = Start, restore = Stop })
