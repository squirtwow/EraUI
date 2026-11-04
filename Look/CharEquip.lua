-- The equipment pane (Classic look, "characterSheet"): a small page arrow
-- near the window's top right opens the game's own Equipment Manager in a
-- dialog docked to the right of the 1.x window, the way Wrath did it. The
-- set buttons, saving and equipping are all the game's.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local C = Look.Char

local PANE_W, PANE_H = 262, 440
local INSIDE = 8 -- the dialog border's own width, each side
local eq = { open = false, placed = false }

local function SetList()
    return PaperDollFrame and PaperDollFrame.EquipmentManagerPane
end

function C.EquipmentOpen()
    return eq.open
end

-- How far the open dialog reaches past the art's right edge (0 while it
-- isn't up).
function C.EquipmentExtent()
    if C.active and eq.open and eq.dialog and eq.dialog:IsShown() then return PANE_W - 2 * INSIDE end
    return 0
end

local function PaintArrow()
    local arrow = eq.arrow
    if not arrow then return end
    local way = eq.open and "PrevPage" or "NextPage"
    arrow:SetNormalTexture(C.BUTTONS .. "UI-SpellbookIcon-" .. way .. "-Up")
    arrow:SetPushedTexture(C.BUTTONS .. "UI-SpellbookIcon-" .. way .. "-Down")
end

local function Remember(list)
    if eq.anchors then return end
    eq.anchors = {}
    for i = 1, list:GetNumPoints() do eq.anchors[i] = { list:GetPoint(i) } end
end

-- The dialog up or down with the window's state, the game's set list in it
-- while it is up.
function C.SyncEquipment()
    local dialog, list = eq.dialog, SetList()
    if not dialog then return end
    if C.active and eq.open then
        dialog:Show()
        if list and C.Free(list) then
            Remember(list)
            list:ClearAllPoints()
            list:SetPoint("TOPLEFT", dialog, "TOPLEFT", 14, -40)
            list:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -12, 12)
            eq.placed = true
            Look.EachRegion(list, function(piece)
                if piece.IsObjectType and piece:IsObjectType("Texture") then Look.Fade(piece) end
            end)
            local level = math.max(Look.Number(PaperDollFrame:GetFrameLevel()) or 1, (Look.Number(list:GetFrameLevel()) or 1) - 1)
            dialog:SetFrameLevel(level)
            if not list:IsShown() then list:Show() end
        end
    else
        dialog:Hide()
        if list and list:IsShown() and (C.active or eq.placed) and C.Free(list) then list:Hide() end
    end
    PaintArrow()
end

function C.SetEquipmentOpen(open)
    eq.open = open and true or false
    C.SyncEquipment()
    -- The side-pane hiding keeps the game's set list unmuted only while the
    -- dialog is open: run it now, so the list shows the moment it opens.
    if C.HideSidePane then Look.Try(C.HideSidePane) end
    if PlaySound and SOUNDKIT then
        PlaySound(eq.open and SOUNDKIT.IG_CHARACTER_INFO_OPEN or SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    end
    C.Signal()
end

local function MakeDialog(paper)
    local dialog = CreateFrame("Frame", "EraUIClassicEquipmentPane", paper, "BackdropTemplate")
    dialog:SetSize(PANE_W, PANE_H)
    dialog:EnableMouse(true)
    dialog:Hide()
    dialog:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    if ns.DarkBackdrop then ns.DarkBackdrop(dialog) end
    Look.Pin(dialog, "TOPLEFT", CharacterFrame, "TOPLEFT", C.ART_RIGHT - INSIDE + 2, -8)
    local plate = Look.OwnTexture(dialog, "plate", "ARTWORK")
    plate:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    if ns.DarkWindowArt then ns.DarkWindowArt(plate, "frame") end
    plate:SetSize(300, 64)
    Look.Pin(plate, "TOP", dialog, "TOP", 0, 12)
    local title = Look.OwnLabel(dialog, "title", "GameFontNormal", "OVERLAY")
    title:SetText(C.Text("EQUIPMENT_MANAGER", "Equipment Manager"))
    Look.Pin(title, "TOP", plate, "TOP", 0, -14)
    local shut = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    Look.Pin(shut, "TOPRIGHT", dialog, "TOPRIGHT", -6, -6)
    Look.SkinCloseButton(shut)
    shut:SetScript("OnClick", function() C.SetEquipmentOpen(false) end)
    return dialog
end

local function MakeArrow(paper)
    local arrow = CreateFrame("Button", "EraUIClassicEquipmentToggle", paper)
    arrow:SetSize(24, 24)
    Look.Pin(arrow, "TOPRIGHT", CharacterFrame, "TOPRIGHT", -40, -50)
    arrow:SetHighlightTexture(C.BUTTONS .. "UI-Common-MouseHilight")
    local glow = arrow:GetHighlightTexture()
    if glow then glow:SetBlendMode("ADD") end
    arrow:SetScript("OnClick", function() C.SetEquipmentOpen(not eq.open) end)
    arrow:SetScript("OnEnter", function()
        Look.ShowTip(arrow, "RIGHT", { { C.Text("EQUIPMENT_MANAGER", "Equipment Manager"), 1, 1, 1 } })
    end)
    arrow:SetScript("OnLeave", function() Look.HideTip(arrow) end)
    return arrow
end

-- On every sheet apply: made the first time, then brought up to date.
function C.ApplyEquipment(paper)
    if not eq.dialog then
        eq.dialog = MakeDialog(paper)
        eq.arrow = MakeArrow(paper)
    end
    eq.arrow:Show()
    C.SyncEquipment()
end

-- The window turned off: the dialog and arrow down, the game's set list
-- given back its own place and art.
function C.RestoreEquipment()
    if not eq.dialog then return end
    eq.dialog:Hide()
    eq.arrow:Hide()
    local list = SetList()
    if not list then return end
    if eq.placed and list:IsShown() and C.Free(list) then list:Hide() end
    if eq.anchors and C.Free(list) then
        list:ClearAllPoints()
        for _, point in ipairs(eq.anchors) do list:SetPoint(point[1], point[2], point[3], point[4], point[5]) end
    end
    eq.placed = false
    Look.EachRegion(list, function(piece)
        if piece.IsObjectType and piece:IsObjectType("Texture") then piece:SetAlpha(1) end
    end)
end
