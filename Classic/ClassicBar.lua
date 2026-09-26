-- EraUI main action bar.
-- The 1.x main menu bar: a 1024x53 stone band centered at the bottom with a
-- gryphon on each end. Blizzard's action buttons, page arrows, micro buttons,
-- bag buttons and experience bars are re-anchored onto it in their 2004 spots.
-- Edit mode keeps working for everything else; while it is open the band hands
-- everything back.
local _, EraUI = ...
local ns = EraUI.Classic

local ART_W, ART_H = 1024, 53
local BAND_H, STRIP_H = 43, 10
local CAP_SIZE = 128
local BUTTON_SIZE, BUTTON_PITCH = 36, 42
local ROW_X, ROW_Y = 8, 4
local UPPER_ROW_Y = 55
local PET_ROW_Y = 104
local TWO_BAR_LIFT = 9
local STANCE_X, PET_X = 30, 36
local SMALL_PITCH, SMALL_BUTTON = 33, 30
local SIDE_BAR_X, SIDE_BAR_Y, SIDE_BAR_GAP = -2, 98, 6
local PAGE_X, PAGE_UP_Y, PAGE_DOWN_Y = 522, -22, -42
local PAGE_ROOM = 36
local CORNER_X = -6
local MICRO_X, MICRO_Y, MICRO_W, MICRO_H, MICRO_STEP = 555, 2.5, 28, 38, -3
local MICRO_SKIP = { StoreMicroButton = true }
local hiddenMicro = {}
local BAG_SIZE, BAG_OVERLAP, BACKPACK_GAP, BAGS_X, BAGS_Y = 30, -2, -2, -4, 6
local KEYRING_W, KEYRING_H, KEYRING_GAP = 18, 39, -5
local MICRO_END_GAP = 5
local REAGENT_SIZE = 17

local OWNED_SYSTEMS = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "StanceBar", "PetActionBar", "PossessActionBar", "MicroMenuContainer", "BagsBar",
    "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }

local MICRO_BUTTONS = { "CharacterMicroButton", "ProfessionMicroButton", "SpellbookMicroButton", "TalentMicroButton",
    "PlayerSpellsMicroButton", "AchievementMicroButton", "QuestLogMicroButton", "LegacyMicroButton", "GuildMicroButton",
    "LFDMicroButton", "CollectionsMicroButton", "EJMicroButton", "HousingMicroButton", "HelpMicroButton",
    "StoreMicroButton", "MainMenuMicroButton" }
local BAG_BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot" }
local EXTRA_BARS = { "MultiBar5", "MultiBar6", "MultiBar7" }

local PIECES = {
    { x = 0, key = "barBody", band = { 0.83203125, 1.0 }, strip = { 0.79296875, 0.83203125 } },
    { x = 256, key = "barBody", band = { 0.58203125, 0.75 }, strip = { 0.54296875, 0.58203125 } },
    { x = 512, key = "barKeyring", band = { 0.6640625, 1.0 }, strip = { 0.29296875, 0.33203125 }, stripKey = "barBody" },
    { x = 768, key = "barKeyring", band = { 0.1640625, 0.5 }, strip = { 0.04296875, 0.08203125 }, stripKey = "barBody" },
}
local REP_ROWS = { { 0, 0.171875 }, { 0.1875, 0.359375 }, { 0.375, 0.546875 }, { 0.5625, 0.734375 } }

local art
local active = false
local applying = false
local pending = false
local restoreQueued = false
local Snapshot
local saved = {}

local function Remember(frame)
    if not saved[frame] then
        saved[frame] = { scale = frame:GetScale(), parent = frame:GetParent(), w = frame:GetWidth(), h = frame:GetHeight() }
    end
end

local function BarSetting(bar, key)
    if not bar or not bar.GetSettingValue or not Enum or not Enum.EditModeActionBarSetting then return nil end
    local setting = Enum.EditModeActionBarSetting[key]
    if setting == nil then return nil end
    local ok, value = pcall(bar.GetSettingValue, bar, setting)
    if ok and type(value) == "number" then return value end
    return nil
end

local function BarVertical(bar)
    local value = BarSetting(bar, "Orientation")
    if value == nil then return nil end
    local vertical = Enum and Enum.ActionBarOrientation and Enum.ActionBarOrientation.Vertical or 1
    return value == vertical
end

local function BarRows(bar)
    return math.max(1, math.floor(BarSetting(bar, "NumRows") or 1))
end

local function IconScale(bar)
    local scale
    do
        local value = BarSetting(bar, "IconSize")
        if value and value > 0 then scale = value / 100 end
    end
    if not scale then scale = (bar and bar.GetScale and bar:GetScale()) or 1 end
    local own = (ns.db and ns.db.defaultBarSize == true) and (45 / 36) or 1
    if own <= 0 then own = 1 end
    if scale <= 0 then scale = 1 end
    return scale * own
end

local function BandScale(bar) return IconScale(bar or ns.GetMainBar()) end
ns.BandScale = BandScale

local function BandNow()
    local scale = art and art.GetScale and art:GetScale() or 1
    if not scale or scale <= 0 then scale = 1 end
    return scale
end

local function MatchScale(frame, scale)
    if not frame or not frame.SetScale or not frame.GetScale then return end
    if math.abs((frame:GetScale() or 1) - scale) < 0.005 then return end
    Remember(frame)
    frame:SetScale(scale)
end

local function OneBar() return ns.db and ns.db.oneBar == true end

local MICRO_LEAD, MICRO_REGION_MAX, BAG_PART = 45, 330, 182
local POST_U, POST_W = 82, 8
local MICRO_GROUP_X = 548
local shape = { micro = true, bags = true, region = MICRO_REGION_MAX, scale = 1 }

local function MicroOut() return ns.db and ns.db.microPos ~= nil end

function ns.MicroTouched()
    if ns.microDirty or not ns.db then return end
    local pos = ns.db.microPos
    ns.microBefore = {
        pos = type(pos) == "table" and { point = pos.point, relPoint = pos.relPoint, x = pos.x, y = pos.y } or nil,
        scale = ns.db.microScale,
        bagsFirst = ns.db.bagsFirst,
    }
    ns.microDirty = true
end
local function MicroUserScale()
    local value = tonumber(ns.db and ns.db.microScale) or 1
    return math.max(0.5, math.min(2, value))
end

local dragPreview = {}

local function OnBandMicro() return shape.micro and not OneBar() end
local function OnBandBags() return shape.bags and not OneBar() end

local MICRO_SECOND_LEAD = 8
local MICRO_ROW_IN = 7

local function BandPlan(microOn, bagsOn, bagsFirst, region)
    local plan = { bagsFirst = (bagsFirst and microOn and bagsOn) and true or false }
    plan.cut = shape.cut or 0
    local x = ART_W / 2 - plan.cut
    plan.base = x
    plan.microFirst = (microOn and not plan.bagsFirst) and true or false
    plan.noPages = shape.noPages and true or false
    if plan.microFirst and plan.noPages then
        plan.microStart, plan.microRow = x, x + MICRO_SECOND_LEAD
        x = x + region - MICRO_LEAD + MICRO_SECOND_LEAD
        plan.microEnd = x
        if bagsOn then plan.bagsStart = x x = x + BAG_PART end
    elseif plan.microFirst then
        plan.microStart, plan.microRow = x, x + (MICRO_X - ART_W / 2)
        x = x + region
        plan.microEnd = x
        if bagsOn then plan.bagsStart = x x = x + BAG_PART end
    else
        if not plan.noPages then x = x + PAGE_ROOM end
        if bagsOn then plan.bagsStart = x x = x + BAG_PART end
        if microOn then
            plan.microStart, plan.microRow = x, x + MICRO_SECOND_LEAD
            x = x + region - MICRO_LEAD + MICRO_SECOND_LEAD
            plan.microEnd = x
        end
    end
    plan.width = x
    return plan
end

local function CurrentPlan()
    if not shape.plan then shape.plan = BandPlan(OnBandMicro(), OnBandBags(), ns.db and ns.db.bagsFirst, shape.region) end
    return shape.plan
end

local function ArtWidth() return CurrentPlan().width end

local function Segments()
    local plan = CurrentPlan()
    local cut = plan.cut
    local list = {}
    if cut < 256 then
        list[1] = { 0, 256 - cut, 1, cut / 256, 1 }
        list[2] = { 256 - cut, 256, 2, 0, 1 }
    else
        list[1] = { 0, 512 - cut, 2, (cut - 256) / 256, 1 }
    end
    local half = plan.base
    local headless = plan.microFirst and plan.noPages
    if plan.microFirst and not headless then
        local region = plan.microEnd - plan.microStart
        local third = math.min(region, 256)
        list[#list + 1] = { half, third, 3, 0, third / 256 }
        if region > 256 then list[#list + 1] = { half + 256, region - 256, 4, 0, (region - 256) / 256 } end
    elseif not plan.microFirst and not plan.noPages then
        list[#list + 1] = { half, PAGE_ROOM, 3, 0, PAGE_ROOM / 256 }
    end
    if plan.bagsStart then
        list[#list + 1] = { plan.bagsStart, BAG_PART, 4, (256 - BAG_PART) / 256, 1 }
    end
    if plan.microStart and (not plan.microFirst or headless) then
        local width = plan.microEnd - plan.microStart
        local u0 = MICRO_LEAD - MICRO_SECOND_LEAD
        local first = math.min(width, 256 - u0)
        list[#list + 1] = { plan.microStart, first, 3, u0 / 256, (u0 + first) / 256 }
        if width > first then
            list[#list + 1] = { plan.microStart + first, width - first, 4, 0, (width - first) / 256 }
        end
    end
    list[#list + 1] = { plan.width - POST_W, POST_W, 4, POST_U / 256, (POST_U + POST_W) / 256 }
    return list
end

local function BuildArt()
    art = CreateFrame("Frame", "EraUIClassicBar", UIParent)
    art:SetSize(ART_W, ART_H)
    art:SetFrameStrata("MEDIUM")
    art:SetFrameLevel(1)
    art.pieces = {}
    for i = 1, 8 do
        art.pieces[i] = art:CreateTexture(nil, "BACKGROUND")
    end
    art.leftCap = art:CreateTexture(nil, "OVERLAY", nil, 5)
    art.leftCap:SetSize(CAP_SIZE, CAP_SIZE)
    art.leftCap:SetPoint("BOTTOM", art, "BOTTOM", -544, 0)
    art.rightCap = art:CreateTexture(nil, "OVERLAY", nil, 5)
    art.rightCap:SetSize(CAP_SIZE, CAP_SIZE)
    art.rightCap:SetPoint("BOTTOM", art, "BOTTOM", 544, 0)
    art.maxLevel = {}
    for i = 1, 4 do
        local tex = art:CreateTexture(nil, "BACKGROUND")
        tex:SetSize(256, 7)
        tex:SetPoint("BOTTOM", art, "TOP", -384 + (i - 1) * 256, -11)
        art.maxLevel[i] = tex
    end
    art.rows = {}
    art.sideAnchor = CreateFrame("Frame", nil, UIParent)
    art.sideAnchor:SetSize(1, 1)
    art.sideAnchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    for _, index in ipairs({ 7, 8 }) do
        local row = CreateFrame("Frame", nil, art.sideAnchor)
        row:SetSize(1, 1)
        art.rows[index] = row
    end
end

local function PaintArt()
    local segments = Segments()
    -- The band is EraUI's own art; ignore the client's Hide Bar Art, which
    -- this client re-enables by itself while spells are dragged.
    local bare = false
    for i, tex in ipairs(art.pieces) do
        local seg = (not bare) and segments[i] or nil
        if seg then
            local piece = PIECES[seg[3]]
            ns.SetTex(tex, piece.key)
            tex:SetTexCoord(seg[4], seg[5], piece.band[1], piece.band[2])
            tex:SetSize(seg[2], BAND_H)
            tex:ClearAllPoints()
            tex:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", seg[1], 0)
            tex:Show()
        else
            tex:Hide()
        end
    end
    ns.SetTex(art.leftCap, "endCap")
    art.leftCap:SetTexCoord(0, 1, 0, 1)
    ns.SetTex(art.rightCap, "endCap")
    art.rightCap:SetTexCoord(1, 0, 0, 1)
    for i, tex in ipairs(art.maxLevel) do
        ns.SetTex(tex, "maxLevel")
        tex:SetTexCoord(0, 1, (i - 1) * 0.25, (i - 1) * 0.25 + 0.21875)
    end
end

local CAP_KEYS = { "LeftEndCap", "RightEndCap" }

local function CapFrame(bar, key)
    local caps = bar and bar.EndCaps
    return caps and caps[key] or nil
end

local function CapHeldKey(key) return key == "LeftEndCap" and "capHeldLeft" or "capHeldRight" end

local function CapMoved(key)
    if ns.db and ns.db[CapHeldKey(key)] == true then return false end
    if ns.db and ns.db.capMoved and ns.db.capMoved[key] == true then return true end
    local bar = ns.GetMainBar and ns.GetMainBar()
    local cap = bar and bar.EndCaps and bar.EndCaps[key]
    if not cap or type(cap.IsInDefaultPosition) ~= "function" then return false end
    if cap.IsInitialized then
        local okInit, ready = pcall(cap.IsInitialized, cap)
        if not okInit or not ready then return false end
    end
    local ok, isDefault = pcall(cap.IsInDefaultPosition, cap)
    return ok and isDefault == false
end

local function CapHidden(cap)
    local setting = Enum and Enum.EditModeMainActionBarEndCapSetting and Enum.EditModeMainActionBarEndCapSetting.Hidden
    if not cap or setting == nil or not cap.GetSettingValueBool then return false end
    local ok, hidden = pcall(cap.GetSettingValueBool, cap, setting)
    return ok and hidden and true or false
end

local function CapSlot(key, w) return (key == "LeftEndCap" and -1 or 1) * (w / 2 + 32) end

local function PlaceCaps(bar, w, hideArt)
    local container = bar and bar.EndCaps
    if container and not container:IsShown() then container:Show() end
    for _, key in ipairs(CAP_KEYS) do
        local tex = key == "LeftEndCap" and art.leftCap or art.rightCap
        local cap = CapFrame(bar, key)
        tex:ClearAllPoints()
        if cap and cap.GetPoint then
            for _, region in ipairs({ cap:GetRegions() }) do
                if region:IsObjectType("Texture") and region:GetAlpha() > 0 then region:SetAlpha(0) end
            end
            if type(cap.IsInDefaultPosition) == "function" and (CapMoved(key) or ns.db[CapHeldKey(key)]) then
                local ok, isDefault = pcall(cap.IsInDefaultPosition, cap)
                if ok and isDefault then
                    if ns.db.capMoved then ns.db.capMoved[key] = nil end
                    ns.db[CapHeldKey(key)] = false
                end
            end
            if not CapMoved(key) and not cap.isDragging then
                ns.OverlayOnBand(cap, "BOTTOM", "BOTTOM", CapSlot(key, w), 0, CAP_SIZE, CAP_SIZE)
            end
            tex:SetPoint("BOTTOM", cap, "BOTTOM", 0, 0)
            tex:SetShown(not hideArt and not CapHidden(cap) and EraUI:GetSetting("gryphons"))
        else
            tex:SetPoint("BOTTOM", art, "BOTTOM", CapSlot(key, w), 0)
            tex:SetShown(not hideArt and EraUI:GetSetting("gryphons"))
        end
    end
end

local function ApplyArtShape(bar)
    local hide = false -- the band is EraUI's own art; Hide Bar Art is ignored
    local w = ArtWidth()
    art:SetSize(w, ART_H)
    art.artHidden = hide
    PlaceCaps(bar, w, hide)
    for i, tex in ipairs(art.maxLevel) do
        local seen = math.max(0, math.min(256, w - (i - 1) * 256))
        tex:ClearAllPoints()
        tex:SetPoint("BOTTOMLEFT", art, "TOPLEFT", (i - 1) * 256, -11)
        tex:SetWidth(math.max(seen, 1))
        tex:SetTexCoord(0, seen / 256, (i - 1) * 0.25, (i - 1) * 0.25 + 0.21875)
        tex.fcuiInBand = seen > 0
    end
end

local rowOf = {}

local function Row(index, parent)
    local row = art.rows[index]
    if not row then
        row = CreateFrame("Frame", nil, art)
        row:SetSize(1, 1)
        art.rows[index] = row
    end
    parent = parent or art
    if row:GetParent() ~= parent then row:SetParent(parent) end
    return row
end

local function LayoutButtons(bar, rowIndex, point, relTo, relPoint, x, y, vertical, pitch, target, origin, rows)
    if not bar or not bar.actionButtons then return end
    local first = bar.actionButtons[1]
    local size = first and first:GetWidth() or 45
    if not size or size == 0 then size = 45 end
    local scale = (target or BUTTON_SIZE) / size
    local step = (pitch or BUTTON_PITCH) / scale
    local icon = IconScale(bar)
    MatchScale(bar, 1)
    local band = (art and art:GetScale()) or 1
    if band <= 0 then band = 1 end
    origin = origin or band
    if origin <= 0 then origin = 1 end
    local onBand = relTo == nil or relTo == art
    local row = Row(rowIndex, onBand and art or UIParent)
    row:SetScale(onBand and (origin / band) or origin)
    row:ClearAllPoints()
    row:SetPoint(point, relTo, relPoint, x, y)
    local hung = rowOf[bar]
    if not hung then
        hung = {}
        rowOf[bar] = hung
    end
    hung.row, hung.onBar, hung.vertical = row, relTo == bar, vertical and true or false
    local slots = BarSetting(bar, "NumIcons")
    rows = math.max(1, rows or 1)
    local shown = (slots and slots > 0) and math.min(slots, #bar.actionButtons) or #bar.actionButtons
    local per = math.max(1, math.ceil(shown / rows))
    local count = 0
    for i, button in ipairs(bar.actionButtons) do
        local container = button.container
        if container then
            count = i
            Remember(container)
            container:SetScale(scale * icon)
            container:ClearAllPoints()
            local along, across = (i - 1) % per, math.floor((i - 1) / per)
            if vertical then
                container:SetPoint("TOPLEFT", row, "TOPLEFT", across * step, -along * step)
            else
                container:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", along * step, across * step)
            end
        end
    end
    if slots and slots > 0 then count = math.min(count, slots) end
    if count > 0 then
        local slot = math.floor((target or BUTTON_SIZE) * icon + 0.5)
        local lines = math.ceil(count / per)
        local along = math.floor((math.min(count, per) - 1) * (step * scale * icon) + slot + 0.5)
        local thick = math.floor((lines - 1) * (step * scale * icon) + slot + 0.5)
        local wide, tall = along, thick
        if vertical then wide, tall = thick, along end
        if math.abs((bar:GetWidth() or 0) - wide) > 0.5 or math.abs((bar:GetHeight() or 0) - tall) > 0.5 then
            Remember(bar)
            bar:SetSize(wide, tall)
        end
        local selection = bar.Selection
        if selection and selection.SetPoint and not InCombatLockdown() then
            local box = hung.box
            if not box then
                box = CreateFrame("Frame", nil, UIParent)
                hung.box = box
            end
            local corner = vertical and "TOPLEFT" or "BOTTOMLEFT"
            local boxW = wide
            if bar == ns.GetMainBar() and not vertical and not ns.barMoved
                and BarSetting(bar, "HideBarScrolling") ~= 1 then
                boxW = boxW + PAGE_ROOM * band
            end
            box:ClearAllPoints()
            box:SetPoint(corner, row, corner, 0, 0)
            box:SetSize(boxW, tall)
            if not hung.boxed then
                hung.boxed = true
                selection:ClearAllPoints()
                selection:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
                selection:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
            end
        end
    end
end

local function HoldBandBoxes(fight)
    local main = ns.GetMainBar and ns.GetMainBar()
    for bar, hung in pairs(rowOf) do
        local selection = bar.Selection
        if selection and selection.EnableMouse and not (selection.IsProtected and selection:IsProtected() and InCombatLockdown()) then
            local onBand
            if bar == main then onBand = not ns.barMoved else onBand = not hung.onBar end
            local want = not (fight and onBand)
            if selection:IsMouseEnabled() ~= want then selection:EnableMouse(want) end
        end
    end
end

local function RestoreSelections()
    for bar, hung in pairs(rowOf) do
        if hung.boxed and bar.Selection then
            hung.boxed = nil
            bar.Selection:ClearAllPoints()
            bar.Selection:SetAllPoints(bar)
            if not bar.Selection:IsMouseEnabled() then bar.Selection:EnableMouse(true) end
        end
    end
end

local function RestoreButtons(bar)
    if not bar or not bar.actionButtons then return end
    for _, button in ipairs(bar.actionButtons) do
        local container = button.container
        if container and saved[container] then
            container:SetScale(saved[container].scale)
            if saved[container].parent and container:GetParent() ~= saved[container].parent then
                container:SetParent(saved[container].parent)
            end
            saved[container] = nil
        end
    end
    bar.oldGridSettings = nil
    if bar.UpdateGridLayout then bar:UpdateGridLayout() end
end

local function ButtonLevel()
    local bar = ns.GetMainBar()
    return math.max(art:GetFrameLevel() + 20, (bar and bar:GetFrameLevel() or 0) + 10)
end

local function Anchor(frame, point, relPoint, x, y, scale)
    if not frame then return end
    Remember(frame)
    frame:ClearAllPoints()
    frame:SetPoint(point, art, relPoint, x, y)
    if scale then frame:SetScale(scale) end
end

local function LayoutPageArrows(bar)
    local pn = bar.ActionBarPageNumber
    if not pn then return end
    local pageX = CurrentPlan().base + (PAGE_X - ART_W / 2)
    pn:ClearAllPoints()
    pn:SetPoint("CENTER", art, "TOPLEFT", pageX, (PAGE_UP_Y + PAGE_DOWN_Y) / 2)
    pn:SetSize(32, 76)
    pn:SetScale(BandNow())
    pn:SetFrameStrata("HIGH")
    pn:SetShown(BarSetting(bar, "HideBarScrolling") ~= 1)
    for _, entry in ipairs({ { pn.UpButton, PAGE_UP_Y }, { pn.DownButton, PAGE_DOWN_Y } }) do
        local button, y = entry[1], entry[2]
        if button then
            button:SetSize(32, 32)
            button:SetHitRectInsets(6, 6, 7, 7)
            button:ClearAllPoints()
            button:SetPoint("CENTER", art, "TOPLEFT", pageX, y)
        end
    end
    if pn.Text then
        pn.Text:SetFontObject("GameFontNormalSmall")
        pn.Text:ClearAllPoints()
        pn.Text:SetPoint("CENTER", art, "TOPLEFT", pageX + 20, (PAGE_UP_Y + PAGE_DOWN_Y) / 2 + 0.5)
    end
end

function ns.OverlayOnBand(frame, point, bandPoint, x, y, w, h, relativeTo)
    if not frame or not art then return end
    local fs = frame:GetEffectiveScale() / art:GetEffectiveScale()
    if not fs or fs <= 0 then fs = 1 end
    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo or art, bandPoint, x / fs, y / fs)
    frame:SetSize(w / fs, h / fs)
end

local function LayoutBags()
    local backpack = MainMenuBarBackpackButton
    if not backpack then return end
    local piece = BagsBar
    local out = piece and not shape.bags
    local lift = (KEYRING_H - BAG_SIZE) / 2
    local home, homePoint, homeY = art, "BOTTOMRIGHT", BAGS_Y
    local homeX
    local buttonScale = 1
    local rowW = BAG_SIZE + (BAG_SIZE - BACKPACK_GAP) + 3 * (BAG_SIZE - BAG_OVERLAP)
    if KeyRingButton or CharacterReagentBag0Slot then rowW = rowW + KEYRING_W - KEYRING_GAP end
    local band = (art:GetScale() or 1)
    if band <= 0 then band = 1 end
    if piece and (out or OneBar()) then
        buttonScale = (piece:GetScale() or 1) / band
    elseif piece then
        buttonScale = piece:GetScale() or 1
        local snap = ns.db and ns.db.bagsSnapScale or 0
        if snap > 0 and math.abs(buttonScale - snap) < 0.001 then buttonScale = 1 end
    end
    if out then
        home, homeX, homeY = piece, 0, lift
    else
        local relativeTo
        if OneBar() then
            local under = MicroOut() and 0 or BAND_H * MicroUserScale() / band
            relativeTo, homeX, homeY = art.sideAnchor, CORNER_X - 4 * buttonScale, under + 6 * buttonScale
        else
            local plan = CurrentPlan()
            homePoint, homeX = "BOTTOMLEFT", (plan.bagsStart or (plan.width - BAG_PART)) + BAG_PART + BAGS_X
        end
        if piece then
            if not piece.isDragging then
                ns.OverlayOnBand(piece, "BOTTOMRIGHT", homePoint, homeX, homeY - lift * buttonScale, rowW * buttonScale, KEYRING_H * buttonScale, relativeTo)
            end
            home, homePoint, homeX, homeY = piece, "BOTTOMRIGHT", 0, lift
        elseif relativeTo then
            home = relativeTo
        end
    end
    local level = ButtonLevel()
    local prev
    for _, name in ipairs(BAG_BUTTONS) do
        local button = _G[name]
        if button then
            Remember(button)
            if button:GetParent() ~= art then button:SetParent(art) end
            button:SetScale(buttonScale)
            button:SetSize(BAG_SIZE, BAG_SIZE)
            button:SetFrameLevel(level)
            button:ClearAllPoints()
            if not prev then
                button:SetPoint("BOTTOMRIGHT", home, homePoint, homeX / buttonScale, homeY / buttonScale)
            elseif prev == backpack then
                button:SetPoint("RIGHT", prev, "LEFT", BACKPACK_GAP, 0)
            else
                button:SetPoint("RIGHT", prev, "LEFT", BAG_OVERLAP, 0)
            end
            ns.SkinBagButton(button, BAG_SIZE, name == "MainMenuBarBackpackButton")
            button:Show()
            prev = button
        end
    end
    local lastBag = prev
    local slim = KeyRingButton or CharacterReagentBag0Slot
    if slim then
        Remember(slim)
        if slim:GetParent() ~= art then slim:SetParent(art) end
        slim:SetScale(buttonScale)
        slim:SetSize(KEYRING_W, KEYRING_H)
        slim:SetFrameLevel(level)
        slim:ClearAllPoints()
        slim:SetPoint("RIGHT", prev, "LEFT", KEYRING_GAP, 0)
        ns.SkinKeyRing(slim)
        prev = slim
    end
    if KeyRingButton and CharacterReagentBag0Slot then
        local reagent = CharacterReagentBag0Slot
        Remember(reagent)
        if reagent:GetParent() ~= art then reagent:SetParent(art) end
        reagent:SetScale(buttonScale)
        reagent:SetSize(REAGENT_SIZE, REAGENT_SIZE)
        reagent:SetFrameLevel(level + 2)
        reagent:ClearAllPoints()
        reagent:SetPoint("CENTER", lastBag, "LEFT", -2, 0)
        ns.SkinBagButton(reagent, REAGENT_SIZE, false, false, true)
    end
    art.slimSlot = prev
    if piece and out then piece:SetSize(rowW, KEYRING_H) end
    local floor = art.bagFloor
    local floating = (out or OneBar()) and true or false
    if floating then
        if not floor then
            floor = CreateFrame("Frame", nil, art)
            floor:SetSize(BAG_PART, BAND_H)
            floor.tex = floor:CreateTexture(nil, "BACKGROUND")
            floor.tex:SetAllPoints(floor)
            floor.post = floor:CreateTexture(nil, "BORDER")
            art.bagFloor = floor
        end
        local postSheet = PIECES[4]
        ns.SetTex(floor.post, postSheet.key)
        floor.post:SetTexCoord((POST_U + POST_W) / 256, POST_U / 256, postSheet.band[1], postSheet.band[2])
        floor.post:SetSize(POST_W, BAND_H)
        floor.post:ClearAllPoints()
        floor.post:SetPoint("BOTTOMRIGHT", floor, "BOTTOMLEFT", 1, 0)
        floor.post:Show()
        local sheet = PIECES[4]
        ns.SetTex(floor.tex, sheet.key)
        floor.tex:SetTexCoord((256 - BAG_PART) / 256, 1, sheet.band[1], sheet.band[2])
        floor:SetScale(buttonScale)
        floor:SetFrameLevel(math.max(0, level - 1))
        floor:ClearAllPoints()
        floor:SetPoint("BOTTOMRIGHT", backpack, "BOTTOMRIGHT", -BAGS_X, -BAGS_Y)
        floor:Show()
    elseif floor then
        floor:Hide()
    end
    if BagBarExpandToggle then BagBarExpandToggle:Hide() end
    if BagsBar then
        for _, region in ipairs({ BagsBar:GetRegions() }) do
            if region:IsObjectType("Texture") then region:SetAlpha(0) end
        end
        for _, child in ipairs({ BagsBar:GetChildren() }) do
            if not child.GetBagID and not child.GetID then
                for _, region in ipairs({ child:GetRegions() }) do
                    if region:IsObjectType("Texture") then region:SetAlpha(0) end
                end
            end
        end
    end
end

local microButtons

local mapPads = {}
local MapPad

MapPad = function(button, strata, after, target, when)
    local zone = target or (MinimapCluster and MinimapCluster.ZoneTextButton)
    if not button or mapPads[button] or not zone then return end
    if InCombatLockdown() then
        local wait = CreateFrame("Frame")
        wait:RegisterEvent("PLAYER_REGEN_ENABLED")
        wait:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            MapPad(button, strata, after, target, when)
        end)
        return
    end
    local mapPad = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    mapPads[button] = mapPad
    mapPad:SetAttribute("type", "click")
    mapPad:SetAttribute("clickbutton", zone)
    mapPad:SetAttribute("useOnKeyDown", false)
    mapPad:RegisterForClicks("AnyUp", "AnyDown")
    mapPad:SetFrameStrata(strata or "MEDIUM")
    mapPad:Hide()
    mapPad:SetScript("OnMouseDown", function() button:SetButtonState("PUSHED") end)
    mapPad:SetScript("OnMouseUp", function()
        if after or target or not (WorldMapFrame and WorldMapFrame:IsShown()) then button:SetButtonState("NORMAL") end
    end)
    if after then
        mapPad:SetScript("PostClick", function(_, _, down)
            if not down then after() end
        end)
    end
    mapPad:SetScript("OnEnter", function()
        button:LockHighlight()
        local enter = button:GetScript("OnEnter")
        if enter then enter(button) end
    end)
    mapPad:SetScript("OnLeave", function()
        button:UnlockHighlight()
        GameTooltip:Hide()
    end)
    local watch = CreateFrame("Frame")
    if after then
        watch:RegisterEvent("PLAYER_REGEN_DISABLED")
        watch:SetScript("OnEvent", function()
            if mapPad:IsShown() then mapPad:Hide() end
        end)
    end
    watch:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 0.2 then return end
        self.since = 0
        if InCombatLockdown() then return end
        local mgr = EditModeManagerFrame
        local editing = mgr and mgr.IsEditModeActive and mgr:IsEditModeActive()
        local left, bottom = button:GetLeft(), button:GetBottom()
        if not button:IsVisible() or editing or not left or not bottom or (when and not when()) then
            if mapPad:IsShown() then mapPad:Hide() end
            return
        end
        local ratio = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local x, y, w, h = left * ratio, bottom * ratio, button:GetWidth() * ratio, button:GetHeight() * ratio
        if not mapPad:IsShown() or math.abs((mapPad.x or -1) - x) > 0.5 or math.abs((mapPad.y or -1) - y) > 0.5
            or math.abs((mapPad.w or -1) - w) > 0.5 then
            mapPad.x, mapPad.y, mapPad.w = x, y, w
            mapPad:ClearAllPoints()
            mapPad:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
            mapPad:SetSize(w, h)
            mapPad:SetFrameLevel(button:GetFrameLevel() + 5)
            mapPad:Show()
        end
    end)
end
ns.MapPad = MapPad

local function WorldMapMicroButton()
    if ns.WorldMapMicroButton then return ns.WorldMapMicroButton end
    local button = CreateFrame("Button", "EraUIClassicWorldMapMicroButton", art or UIParent)
    button:SetSize(MICRO_W, MICRO_H)
    button:SetNormalTexture((ns.TexPath("microWorldUp")))
    button:SetPushedTexture((ns.TexPath("microWorldDown")))
    button:SetHighlightTexture((ns.TexPath("microHighlight")))
    button:SetScript("OnClick", function()
        if ToggleWorldMap then ToggleWorldMap() end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local key = GetBindingKey("TOGGLEWORLDMAP")
        GameTooltip:SetText((WORLDMAP_BUTTON or "World Map") .. (key and (" (" .. key .. ")") or ""), 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function() button:SetButtonState("PUSHED", true) end)
        WorldMapFrame:HookScript("OnHide", function() button:SetButtonState("NORMAL") end)
    end
    ns.WorldMapMicroButton = button
    MapPad(button)
    return button
end

local function MicroButtonList()
    if microButtons then return microButtons end
    local found = {}
    if MicroMenu then
        for _, child in ipairs({ MicroMenu:GetChildren() }) do
            if child.layoutIndex and child.PostAddButtonCallback then found[#found + 1] = child end
        end
        table.sort(found, function(a, b) return a.layoutIndex < b.layoutIndex end)
    end
    if #found == 0 then
        for _, name in ipairs(MICRO_BUTTONS) do
            if _G[name] then found[#found + 1] = _G[name] end
        end
    end
    local map = WorldMapMicroButton()
    if map then
        local at = #found + 1
        for i, button in ipairs(found) do
            if button == QuestLogMicroButton then at = i + 1 break end
        end
        table.insert(found, at, map)
    end
    microButtons = found
    return found
end

local function MicroNeed(count)
    return count * (MICRO_W + MICRO_STEP) - MICRO_STEP
end

local function MicroPlan(count, userScale)
    local need = MicroNeed(count)
    if need <= 0 then return 1, MICRO_LEAD + MICRO_END_GAP end
    local room = MICRO_REGION_MAX - MICRO_LEAD - MICRO_END_GAP
    local scale = math.min(1, room / need) * (userScale or 1)
    local region = math.ceil(MICRO_LEAD + need * scale + MICRO_END_GAP)
    return scale, math.min(MICRO_REGION_MAX, region)
end

local SELECTION_LAYOUT = {
    TopRightCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = 8 },
    TopLeftCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = 8 },
    BottomLeftCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = -8 },
    BottomRightCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = -8 },
    TopEdge = { atlas = "_%s-NineSlice-EdgeTop" },
    BottomEdge = { atlas = "_%s-NineSlice-EdgeBottom" },
    LeftEdge = { atlas = "!%s-NineSlice-EdgeLeft" },
    RightEdge = { atlas = "!%s-NineSlice-EdgeRight" },
    Center = { atlas = "%s-NineSlice-Center", x = -8, y = 8, x1 = 8, y1 = -8 },
}

local SNAP_PX = 48

local function NearBandSlot(frame, bandX, bandY, corner, fullW)
    if not frame or not art then return false end
    local artScale, scale = art:GetEffectiveScale(), frame:GetEffectiveScale()
    local left, bottom = art:GetLeft(), art:GetBottom()
    if not artScale or not scale or not left or not bottom then return false end
    if fullW and not ns.barMoved then left = left + (art:GetWidth() or fullW) / 2 - fullW / 2 end
    local wantX, wantY = (left + bandX) * artScale, (bottom + bandY) * artScale
    local hasX = corner == "BOTTOMRIGHT" and frame:GetRight() or frame:GetLeft()
    local hasY = frame:GetBottom()
    if not hasX or not hasY then return false end
    local reach = SNAP_PX * UIParent:GetEffectiveScale()
    local dx, dy = math.abs(hasX * scale - wantX), math.abs(hasY * scale - wantY)
    return dx < reach and dy < reach, dx + dy
end

local function DropPlace(which, frame, current)
    if OneBar() or not frame or not art then return nil end
    local artScale, scale = art:GetEffectiveScale(), frame:GetEffectiveScale()
    local aL, aR, aB = art:GetLeft(), art:GetRight(), art:GetBottom()
    local fL, fR, fB = frame:GetLeft(), frame:GetRight(), frame:GetBottom()
    if not (artScale and scale and aL and aR and aB and fL and fR and fB) then return nil end
    local unit = UIParent:GetEffectiveScale()
    local reach = SNAP_PX * unit
    local middle = (fL + fR) / 2 * scale
    if math.abs(fB * scale - aB * artScale) > reach then
        return nil
    end
    local barEnd = (aL + CurrentPlan().base) * artScale
    if middle < barEnd - reach or middle > aR * artScale + 2 * reach then
        return nil
    end
    local otherOn
    if which == "micro" then otherOn = shape.bagsReal ~= false else otherOn = shape.microReal ~= false end
    if not otherOn then return false end
    local both = BandPlan(true, true, false, shape.region)
    local left = aL
    if not ns.barMoved then left = (aL + aR) / 2 - both.width / 2 end
    local line = (left + (both.base + both.width) / 2) * artScale
    local rel = middle - line
    if which == "bags" then rel = -rel end
    local margin = 16 * unit
    local answer
    if current == true then answer = rel > -margin
    elseif current == false then answer = rel > margin
    else answer = rel > 0 end
    return answer
end

local function MicroDialog()
    local dialog = art.microDialog
    if dialog then return dialog end
    dialog = CreateFrame("Frame", "EraUIClassicMicroDialog", UIParent)
    dialog:SetSize(383, 204)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(200)
    dialog:SetMovable(true)
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:Hide()
    art.microDialog = dialog

    local okBorder, border = pcall(CreateFrame, "Frame", nil, dialog, "DialogBorderTranslucentTemplate")
    if okBorder and border then
        border:SetAllPoints(dialog)
    else
        local ground = dialog:CreateTexture(nil, "BACKGROUND")
        ground:SetAllPoints(dialog)
        ground:SetColorTexture(0, 0, 0, 0.85)
    end

    local title = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    title:SetPoint("TOP", dialog, "TOP", 0, -15)
    title:SetText("Micro Menu")

    local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() dialog:Hide() end)

    local label = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    label:SetSize(100, 32)
    label:SetJustifyH("LEFT")
    label:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -48)
    label:SetText(HUD_EDIT_MODE_SETTING_MICRO_MENU_SIZE or "Size")

    local okSlider, slider = pcall(CreateFrame, "Frame", nil, dialog, "MinimalSliderWithSteppersTemplate")
    if okSlider and slider and slider.Init then
        slider:SetSize(200, 32)
        slider:SetPoint("LEFT", label, "RIGHT", 5, 0)
        dialog.slider = slider
        local function Percent(value) return string.format("%d%%", value) end
        local formatters
        if CreateMinimalSliderFormatter and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
            formatters = { [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, Percent) }
        end
        dialog.InitSlider = function()
            dialog.filling = true
            slider:Init(math.floor(MicroUserScale() * 100 + 0.5), 50, 200, 30, formatters)
            dialog.filling = false
        end
        if slider.RegisterCallback and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Event then
            slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
                if dialog.filling or type(value) ~= "number" then return end
                ns.MicroTouched()
                ns.db.microScale = math.max(0.5, math.min(2, value / 100))
                if ns.MirrorSave then ns.MirrorSave() end
                ns.QueueApply()
            end, dialog)
        end
    end

    local reset = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    reset:SetSize(330, 28)
    reset:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 22)
    reset:SetText(HUD_EDIT_MODE_RESET_POSITION or "Reset To Default Position")
    reset:SetScript("OnClick", function()
        ns.MicroTouched()
        ns.db.microPos, ns.db.microScale = nil, nil
        if ns.MirrorSave then ns.MirrorSave() end
        dialog:Refresh()
        ns.QueueApply()
    end)
    dialog.reset = reset

    local resize = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    resize:SetSize(330, 28)
    resize:SetPoint("BOTTOM", reset, "TOP", 0, 6)
    resize:SetText("Reset To Default Size")
    resize:SetScript("OnClick", function()
        ns.MicroTouched()
        ns.db.microScale = nil
        if ns.MirrorSave then ns.MirrorSave() end
        dialog:Refresh()
        ns.QueueApply()
    end)
    dialog.resize = resize

    function dialog:Refresh()
        if self.InitSlider then self.InitSlider() end
        self.reset:SetEnabled(ns.db.microPos ~= nil)
        self.resize:SetEnabled(math.abs(MicroUserScale() - 1) > 0.001)
    end
    dialog:SetScript("OnShow", function(self) self:Refresh() end)
    dialog:SetScript("OnHide", function()
        local handle = art.microHome and art.microHome.handle
        if handle and handle.Dress then handle.Dress("editmode-actionbar-highlight") end
    end)
    return dialog
end

local function MicroHome()
    local home = art.microHome
    if home then return home end
    home = CreateFrame("Frame", "EraUIClassicMicroGroup", art)
    home:SetClampedToScreen(true)
    home:SetMovable(true)
    art.microHome = home
    home.floor = { home:CreateTexture(nil, "BACKGROUND"), home:CreateTexture(nil, "BACKGROUND") }
    home.posts = { home:CreateTexture(nil, "BORDER"), home:CreateTexture(nil, "BORDER") }

    local handle = CreateFrame("Frame", nil, home)
    handle:SetAllPoints(home)
    handle:SetFrameStrata("MEDIUM")
    handle:SetFrameLevel(1010)
    handle:EnableMouse(true)
    handle:EnableMouseWheel(true)
    handle:RegisterForDrag("LeftButton")
    handle:Hide()

    local function Dress(kit)
        if handle.kit == kit then return end
        handle.kit = kit
        if NineSliceUtil and NineSliceUtil.ApplyLayout then
            pcall(NineSliceUtil.ApplyLayout, handle, SELECTION_LAYOUT, kit)
        end
    end
    handle.Dress = Dress
    Dress("editmode-actionbar-highlight")
    local label = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    label:SetPoint("CENTER", handle, "CENTER", 0, 0)
    label:SetText("Micro Menu")
    handle:SetScript("OnDragStart", function(self)
        if InCombatLockdown() and home:IsProtected() then return end
        Dress("editmode-actionbar-selected")
        home.moving, home.dragged = true, true
        home:StartMoving()
        self:SetScript("OnUpdate", function()
            if OneBar() then return end
            local place = DropPlace("micro", home, dragPreview.bagsFirst)
            local near = place ~= nil
            if dragPreview.micro ~= near or (near and dragPreview.bagsFirst ~= place) then
                dragPreview.micro = near
                if near then dragPreview.bagsFirst = place else dragPreview.bagsFirst = nil end
                ns.QueueApply()
            end
        end)
    end)
    handle:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        home:StopMovingOrSizing()
        home.moving = false
        C_Timer.After(0, function() home.dragged = false end)
        local place = DropPlace("micro", home, dragPreview.bagsFirst)
        dragPreview.micro, dragPreview.bagsFirst = nil, nil
        Dress("editmode-actionbar-highlight")
        if place ~= nil then
            ns.MicroTouched()
            ns.db.microPos, ns.db.microScale = nil, nil
            ns.db.bagsFirst = place
            if ns.MirrorSave then ns.MirrorSave() end
        else
            local point, _, relPoint, x, y = home:GetPoint(1)
            ns.MicroTouched()
            ns.db.microPos = { point = point, relPoint = relPoint, x = x, y = y }
            if ns.MirrorSave then ns.MirrorSave() end
        end
        if art.microDialog and art.microDialog:IsShown() then art.microDialog:Refresh() end
        ns.QueueApply()
        if ns.MicroDroppedInFight then ns.MicroDroppedInFight() end
    end)
    handle:SetScript("OnMouseWheel", function(_, delta)
        ns.MicroTouched()
        ns.db.microScale = math.max(0.5, math.min(2, MicroUserScale() + 0.05 * delta))
        if ns.MirrorSave then ns.MirrorSave() end
        if art.microDialog and art.microDialog:IsShown() then art.microDialog:Refresh() end
        ns.QueueApply()
    end)
    handle:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            ns.MicroTouched()
            ns.db.microPos, ns.db.microScale = nil, nil
            if ns.MirrorSave then ns.MirrorSave() end
            if art.microDialog and art.microDialog:IsShown() then art.microDialog:Refresh() end
            ns.QueueApply()
            return
        end
        if home.moving or home.dragged then return end
        local dialog = MicroDialog()
        Dress("editmode-actionbar-selected")
        dialog:ClearAllPoints()
        dialog:SetPoint("BOTTOM", home, "TOP", 0, 40)
        dialog:Show()
    end)
    handle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Micro Menu", 1, 1, 1)
        GameTooltip:AddLine("Drag to move. Let go near the bar to put it back.", 1, 0.82, 0)
        GameTooltip:AddLine("Click for its size and reset. The mouse wheel sizes it too.", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    home.handle = handle
    return home
end

local microBusy = false
local function LayoutMicroButtons()
    if microBusy then return end
    microBusy = true
    local wanted = {}
    for _, button in ipairs(MicroButtonList()) do
        Remember(button)
        if button:GetParent() ~= art then button:SetParent(art) end
        if MICRO_SKIP[button:GetName() or ""] then
            button:ClearAllPoints()
            button:SetAlpha(0)
        elseif button:IsShown() or hiddenMicro[button] then
            wanted[#wanted + 1] = button
        end
    end
    if #wanted == 0 then microBusy = false return end
    local out = (not shape.micro) or OneBar()
    local group = out and MicroUserScale() or 1
    local scale, region = MicroPlan(#wanted, out and 1 or MicroUserScale())
    local baseScale = MicroPlan(#wanted, 1)
    local bandScale = (art:GetScale() or 1)
    if bandScale <= 0 then bandScale = 1 end
    local homeScale = out and (group / bandScale) or 1
    local buttonScale = scale * homeScale
    local level = ButtonLevel()

    local home = MicroHome()
    local plan = CurrentPlan()
    local groupX = (not out and plan.microRow) and (plan.microRow - MICRO_ROW_IN) or MICRO_GROUP_X
    local groupW = (not out and plan.microEnd) and (plan.microEnd - groupX) or ((ART_W / 2 + region) - MICRO_GROUP_X)
    home:SetSize(groupW, BAND_H)
    home:SetScale(homeScale)
    home:SetFrameLevel(math.max(0, level - 1))
    if not home.moving then
        home:ClearAllPoints()
        local pos = ns.db.microPos
        if pos then
            home:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x or 0, pos.y or 0)
        elseif OneBar() then
            home:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", CORNER_X, 0)
        else
            home:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", groupX, 0)
        end
    end
    home:Show()
    local third = math.min(region, 256)
    local runs = {
        { 3, (MICRO_GROUP_X - 512) / 256, third / 256, third - (MICRO_GROUP_X - 512), 0 },
        { 4, 0, math.max(0, region - 256) / 256, math.max(0, region - 256), third - (MICRO_GROUP_X - 512) },
    }
    for i, tex in ipairs(home.floor) do
        local run = runs[i]
        if out and run[4] > 0 then
            local sheet = PIECES[run[1]]
            ns.SetTex(tex, sheet.key)
            tex:SetTexCoord(run[2], run[3], sheet.band[1], sheet.band[2])
            tex:SetSize(run[4], BAND_H)
            tex:ClearAllPoints()
            tex:SetPoint("BOTTOMLEFT", home, "BOTTOMLEFT", run[5], 0)
            tex:Show()
        else
            tex:Hide()
        end
    end

    for i, post in ipairs(home.posts) do
        if out then
            local sheet = PIECES[4]
            ns.SetTex(post, sheet.key)
            post:SetSize(POST_W, BAND_H)
            post:ClearAllPoints()
            if i == 1 then
                post:SetTexCoord((POST_U + POST_W) / 256, POST_U / 256, sheet.band[1], sheet.band[2])
                post:SetPoint("BOTTOMLEFT", home, "BOTTOMLEFT", 0, 0)
            else
                post:SetTexCoord(POST_U / 256, (POST_U + POST_W) / 256, sheet.band[1], sheet.band[2])
                post:SetPoint("BOTTOMRIGHT", home, "BOTTOMRIGHT", 0, 0)
            end
            post:Show()
        else
            post:Hide()
        end
    end

    local prev
    for _, button in ipairs(wanted) do
        Remember(button)
        if button:GetParent() ~= art then button:SetParent(art) end
        button:SetSize(MICRO_W, MICRO_H)
        button:SetScale(buttonScale)
        button:SetFrameLevel(level)
        if hiddenMicro[button] then
            hiddenMicro[button] = nil
            button:Show()
        end
        button:ClearAllPoints()
        if prev then
            button:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", MICRO_STEP, 0)
        else
            local rowY = MICRO_Y
            if not out then rowY = MICRO_Y + MICRO_H * (baseScale - scale) / 2 end
            button:SetPoint("BOTTOMLEFT", home, "BOTTOMLEFT", MICRO_ROW_IN / scale, rowY / scale)
        end
        ns.SkinMicroButton(button)
        prev = button
    end
    if art.perfMeter then art.perfMeter:Hide() end
    if MicroMenu then
        if MicroMenu.BorderArt then MicroMenu.BorderArt:SetAlpha(0) end
        if MicroMenu.BackgroundArt then MicroMenu.BackgroundArt:SetAlpha(0) end
    end
    microBusy = false
end

function ns.RelayoutBags()
    LayoutBags()
    LayoutMicroButtons()
end

local function ActiveLayoutName()
    local mgr = EditModeManagerFrame
    local info = mgr and mgr.GetActiveLayoutInfo and mgr:GetActiveLayoutInfo()
    return info and info.layoutName or nil
end

local function PinnedByUs(frame, info)
    local pins = ns.db and ns.db.barPins
    local layout = pins and pins[ActiveLayoutName() or ""]
    local name = frame.GetName and frame:GetName()
    local pin = layout and name and layout[name]
    if not info then return false end
    local relativeTo = info.relativeTo
    if type(relativeTo) == "table" then relativeTo = relativeTo.GetName and relativeTo:GetName() end
    if relativeTo == "UIParent" and info.point and info.relativePoint and info.point ~= info.relativePoint then return true end
    if not ns.db.pinShape and relativeTo == "UIParent" and info.point == "BOTTOM" and info.relativePoint == "BOTTOM" then return true end
    if not pin then return false end
    return info.point == pin.point and info.relativePoint == pin.relativePoint and relativeTo == "UIParent"
        and math.abs((info.offsetX or 0) - (pin.offsetX or 0)) < 0.5
        and math.abs((info.offsetY or 0) - (pin.offsetY or 0)) < 0.5
end

local function SystemMoved(frame)
    if not frame or type(frame.IsInDefaultPosition) ~= "function" then return false end
    if not (frame.IsInitialized and frame:IsInitialized()) then return false end
    local ok, isDefault = pcall(frame.IsInDefaultPosition, frame)
    if not ok or isDefault then return false end
    local info = frame.systemInfo and frame.systemInfo.anchorInfo
    if PinnedByUs(frame, info) then return false end
    local mgr = EditModePresetLayoutManager
    local okDefault, preset = pcall(function() return mgr and mgr:GetDefaultSystemAnchorInfo(frame.system, frame.systemIndex) end)
    if not okDefault or not info or not preset then return true end
    local same = info.point == preset.point and info.relativeTo == preset.relativeTo and info.relativePoint == preset.relativePoint
        and math.abs((info.offsetX or 0) - (preset.offsetX or 0)) < 0.5 and math.abs((info.offsetY or 0) - (preset.offsetY or 0)) < 0.5
    return not same
end
ns.SystemMoved = SystemMoved

local function BandRow(bar, rowIndex, x, y, pitch, target)
    if not bar then return false end
    local vertical, rows = BarVertical(bar) == true, BarRows(bar)
    if SystemMoved(bar) or vertical or rows > 1 then
        local own = IconScale(bar)
        if vertical then
            LayoutButtons(bar, rowIndex, "TOPLEFT", bar, "TOPLEFT", 0, 0, true, pitch, target, own, rows)
        else
            LayoutButtons(bar, rowIndex, "BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0, false, pitch, target, own, rows)
        end
        return false
    end
    local band = BandNow()
    Anchor(bar, "BOTTOMLEFT", "BOTTOMLEFT", x * band, y * band, 1)
    LayoutButtons(bar, rowIndex, "BOTTOMLEFT", art, "BOTTOMLEFT", x, y, false, pitch, target)
    return true
end

local function LayoutPetRow(lift)
    local x = STANCE_X
    local y = PET_ROW_Y + (lift or 0)
    for _, bar in ipairs({ StanceBar, PossessActionBar }) do
        if bar then
            local pinned = BandRow(bar, bar == StanceBar and 4 or 5, x, y, SMALL_PITCH, SMALL_BUTTON)
            if pinned and bar:IsShown() and bar.actionButtons then
                x = x + #bar.actionButtons * SMALL_PITCH + 8
            end
        end
    end
    if PetActionBar then
        BandRow(PetActionBar, 6, math.max(PET_X, x), y, SMALL_PITCH, SMALL_BUTTON)
    end
end

local SIDE_COL_H = 12 * BUTTON_PITCH

local function SideColumn(bar, rowIndex, x)
    if not bar then return false end
    local vertical, rows = BarVertical(bar) ~= false, BarRows(bar)
    if SystemMoved(bar) or not vertical or rows > 1 then
        local own = IconScale(bar)
        if vertical then
            LayoutButtons(bar, rowIndex, "TOPLEFT", bar, "TOPLEFT", 0, 0, true, nil, nil, own, rows)
        else
            LayoutButtons(bar, rowIndex, "BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0, false, nil, nil, own, rows)
        end
        return false
    end
    Remember(bar)
    bar:SetScale(1)
    bar:ClearAllPoints()
    local icon = IconScale(bar)
    bar:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", x * icon, (SIDE_BAR_Y + SIDE_COL_H) * icon)
    LayoutButtons(bar, rowIndex, "TOPLEFT", UIParent, "BOTTOMRIGHT", x - BUTTON_SIZE, SIDE_BAR_Y + SIDE_COL_H, true, nil, nil, icon)
    return true
end

local function LayoutSideBars()
    local right, left = MultiBarRight, MultiBarLeft
    local rightPinned = SideColumn(right, 7, SIDE_BAR_X)
    local leftX = SIDE_BAR_X
    if rightPinned and right:IsShown() then
        local ratio = IconScale(right) / IconScale(left)
        leftX = (SIDE_BAR_X - BUTTON_SIZE) * ratio - SIDE_BAR_GAP
    end
    SideColumn(left, 8, leftX)
end

local EXTRA_SETTINGS = { "PROXY_SHOW_ACTIONBAR_6", "PROXY_SHOW_ACTIONBAR_7", "PROXY_SHOW_ACTIONBAR_8" }

local function ExtraBarsEnabledInSettings()
    if not Settings or not Settings.GetValue then return false end
    for _, var in ipairs(EXTRA_SETTINGS) do
        local ok, value = pcall(Settings.GetValue, var)
        if ok and value then return true end
    end
    return false
end

local LayoutExtraBars

local function FollowSettings()
    if not active or not ns.db or not ns.db.hideExtraBars then return end
    if ExtraBarsEnabledInSettings() then
        ns.db.hideExtraBars = false
        LayoutExtraBars(false)
        if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
    end
end

LayoutExtraBars = function(hide)
    for _, name in ipairs(EXTRA_BARS) do
        local bar = _G[name]
        if bar then
            bar:SetAlpha(hide and 0 or 1)
            if not InCombatLockdown() then
                for _, button in ipairs(bar.actionButtons or {}) do
                    button:EnableMouse(not hide)
                end
            end
        end
    end
end

local function EnsureStrips(statusBar)
    if statusBar.fcuiStrips then return statusBar.fcuiStrips end
    local strips = {}
    for i = 1, 5 do
        strips[i] = statusBar:CreateTexture(nil, "ARTWORK", nil, 1)
    end
    statusBar.fcuiStrips = strips
    return strips
end

local BAR_COLORS = {
    { "Rested", 0, 0.39, 0.88 }, { "Experience", 0.58, 0, 0.55 },
    { "Faction-Red", 0.8, 0.13, 0.13 }, { "Faction-Orange", 1, 0.5, 0 }, { "Faction-Yellow", 1, 1, 0 },
    { "Faction-Green", 0, 0.6, 0.1 }, { "Faction-Blue", 0, 0.6, 1 },
    { "Honor", 1, 0.24, 0 }, { "Artifact", 0.9, 0.8, 0.6 }, { "Azerite", 1, 0.8, 0.2 },
}

local function RecolorStatus(status, atlas)
    if not active then return end
    if atlas then
        status.fcuiAtlas = atlas
    else
        local tex = status:GetStatusBarTexture()
        status.fcuiAtlas = status.fcuiAtlas or (tex and tex.GetAtlas and tex:GetAtlas())
        atlas = status.fcuiAtlas
    end
    status:SetStatusBarTexture((ns.TexPath("statusBarFlat")))
    local r, g, b = 0.58, 0, 0.55
    if status.fcuiXP then
        local rested = false
        local run = status.fcuiRun
        if run and run:IsShown() and (run:GetWidth() or 0) > 0 then rested = true end
        if not rested and GetXPExhaustion then
            local amount = GetXPExhaustion()
            if amount and not (issecretvalue and issecretvalue(amount)) and amount > 0 then rested = true end
        end
        if not rested and status.fcuiRested then rested = true end
        if not rested and atlas and atlas:find("Rested", 1, true) then rested = true end
        if not rested and GetRestState then
            local state = GetRestState()
            if not (issecretvalue and issecretvalue(state)) and state == 1 then rested = true end
        end
        if rested then r, g, b = 0, 0.39, 0.88 end
        if run then
            run:SetColorTexture(0, 0.39, 0.88, 0.15)
            run:SetVertexColor(1, 1, 1, 1)
            run:SetAlpha(1)
            run:SetDrawLayer("BACKGROUND", 0)
        end
    elseif status.fcuiBar and status.fcuiBar.factionID and C_Reputation and C_Reputation.GetWatchedFactionData then
        local ok, data = pcall(C_Reputation.GetWatchedFactionData)
        local reaction = ok and data and data.reaction
        if type(reaction) == "number" and not (issecretvalue and issecretvalue(reaction)) then
            if reaction <= 2 then r, g, b = 0.8, 0.3, 0.22
            elseif reaction == 3 then r, g, b = 0.75, 0.27, 0
            elseif reaction == 4 then r, g, b = 0.9, 0.7, 0
            else r, g, b = 0, 0.6, 0.1 end
        else
            r, g, b = 0, 0.6, 0.1
        end
    elseif atlas then
        for _, entry in ipairs(BAR_COLORS) do
            if atlas:find(entry[1], 1, true) then r, g, b = entry[2], entry[3], entry[4] break end
        end
    end
    status:SetStatusBarColor(r, g, b)
end

local function HookRestedState(bar, status)
    if not bar.UpdateStatusBarTextures then return end
    ns.HookMethod(bar, "UpdateStatusBarTextures", function(self, isRested)
        local sb = self.StatusBar or status
        if not sb then return end
        sb.fcuiRested = isRested and true or false
        RecolorStatus(sb)
    end)
end

local STATUS_INSET = 2

local function LayoutStatusBar(container, isTop)
    if not container then return end
    Anchor(container, isTop and "BOTTOM" or "TOP", "TOP", 0, isTop and 2 or -1, BandNow())
    local h = isTop and 7 or STRIP_H
    local w = ArtWidth() - STATUS_INSET * 2
    container:SetSize(w, h)
    if container.BarFrameTexture then container.BarFrameTexture:SetAlpha(0) end
    if not container.fcuiNoFade then
        container.fcuiNoFade = true
        for _, key in ipairs({ "FadeInAnimation", "FadeOutAnimation" }) do
            local group = container[key]
            if group and group.GetAnimations then
                for _, anim in ipairs({ group:GetAnimations() }) do
                    if anim.SetDuration then anim:SetDuration(0.02) end
                    if anim.SetStartDelay then anim:SetStartDelay(0) end
                end
            end
        end
    end
    local function FadeDividers(self)
        if not active or not self.HorizontalDividersPool then return end
        for divider in self.HorizontalDividersPool:EnumerateActive() do divider:SetAlpha(0) end
    end
    FadeDividers(container)
    ns.HookMethod(container, "UpdateDividers", FadeDividers)
    for _, bar in pairs(container.bars or {}) do
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        bar:SetSize(w, h)
        local status = bar.StatusBar
        if status then
            status:ClearAllPoints()
            status:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
            status:SetSize(w, h)
            status.fcuiXP = bar.ExhaustionTick ~= nil
            status.fcuiBar = bar
            ns.HookMethod(status, "SetBarTexture", RecolorStatus)
            HookRestedState(bar, status)
            RecolorStatus(status)
            if status.Background then status.Background:SetAlpha(0) end
            local run = bar.ExhaustionLevelFillBar
            status.fcuiRun = run
            local tick = bar.ExhaustionTick
            if tick and tick.UpdateTickPosition then
                ns.HookMethod(tick, "UpdateTickPosition", function() RecolorStatus(status) end)
            end
            if run then
                if run.SetParent then run:SetParent(status) end
                run:SetDrawLayer("BACKGROUND", 0)
                run:SetVertexColor(1, 1, 1, 1)
                run:SetColorTexture(0, 0.39, 0.88, 0.15)
                run:ClearAllPoints()
                run:SetPoint("BOTTOMLEFT", status, "BOTTOMLEFT", 0, 0)
                run:SetHeight(h)
            end
            tick = bar.ExhaustionTick
            if tick and not tick.fcuiSkinned then
                tick.fcuiSkinned = true
                tick:SetSize(32, 32)
                if tick.Normal then
                    ns.SetTex(tick.Normal, "exhaustionTick")
                    tick.Normal:SetTexCoord(0, 1, 0, 1)
                    tick.Normal:ClearAllPoints()
                    tick.Normal:SetAllPoints(tick)
                end
                if tick.Highlight then
                    ns.SetTex(tick.Highlight, "exhaustionTickHighlight")
                    tick.Highlight:SetTexCoord(0, 1, 0, 1)
                    tick.Highlight:ClearAllPoints()
                    tick.Highlight:SetAllPoints(tick)
                end
            end
            local strips = EnsureStrips(status)
            local segment = 1024 / 20
            local count = math.max(1, math.floor(w / segment + 0.5))
            local stretch = (w / count) / segment
            local sheetTo = math.min(1024, w / stretch)
            for i, tex in ipairs(strips) do
                local piece = PIECES[i]
                local from = (i - 1) * 256
                local to = math.min(sheetTo, i * 256)
                if piece and to > from then
                    local u1 = (to - from) / 256
                    if isTop then
                        ns.SetTex(tex, "repBar")
                        tex:SetTexCoord(0, u1, REP_ROWS[i][1], REP_ROWS[i][2])
                        tex:SetSize((to - from) * stretch, 11)
                    else
                        ns.SetTex(tex, piece.stripKey or piece.key)
                        tex:SetTexCoord(0, u1, piece.strip[1], piece.strip[2])
                        tex:SetSize((to - from) * stretch, STRIP_H)
                    end
                    tex:ClearAllPoints()
                    tex:SetPoint("TOPLEFT", status, "TOPLEFT", from * stretch, isTop and 2 or 0)
                    tex:Show()
                else
                    tex:Hide()
                end
            end
        end
    end
end

local function HasVisibleBar(container)
    if not container then return false end
    for _, bar in pairs(container.bars or {}) do
        if bar:IsShown() then return true end
    end
    return false
end

local function RecolorExpBars()
    if not active then return end
    for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        for _, bar in pairs(container and container.bars or {}) do
            if bar.ExhaustionTick and bar.StatusBar then
                bar.StatusBar.fcuiRested = nil
                RecolorStatus(bar.StatusBar)
            end
        end
    end
end

local function ShowsExperience(container)
    for _, bar in pairs(container and container.bars or {}) do
        if bar:IsShown() and bar.ExhaustionTick then return true end
    end
    return false
end

local function LayoutStatusBars()
    local main, second = MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer
    local swap = HasVisibleBar(main) and HasVisibleBar(second) and ShowsExperience(second) and not ShowsExperience(main)
    LayoutStatusBar(main, swap)
    LayoutStatusBar(second, not swap)
    local anyShown = (main and main:IsShown()) or (second and second:IsShown())
    for _, tex in ipairs(art.maxLevel) do tex:SetShown(not anyShown and tex.fcuiInBand == true and not art.artHidden) end
end

local barsWatch = CreateFrame("Frame")
local function BarsState()
    local main, second = MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer
    local mainUp, secondUp = HasVisibleBar(main), HasVisibleBar(second)
    local swap = mainUp and secondUp and ShowsExperience(second) and not ShowsExperience(main)
    return (mainUp and "1" or "0") .. (secondUp and "1" or "0") .. (swap and "s" or "-"), mainUp and secondUp
end

local function Playing(container)
    for _, key in ipairs({ "FadeInAnimation", "FadeOutAnimation", "MaxLevelFadeOutAnimation" }) do
        local group = container[key]
        if group and group.IsPlaying and group:IsPlaying() then return true end
    end
    return false
end
barsWatch:SetScript("OnUpdate", function(self, elapsed)
    self.since = (self.since or 0) + elapsed
    if self.since < 0.05 then return end
    self.since = 0
    if not (active and art) then return end
    local busy = false
    for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        if container then
            if Playing(container) then
                busy = true
            elseif HasVisibleBar(container) and (container:GetAlpha() or 1) < 1 then
                container:SetAlpha(1)
            end
        end
    end
    if busy or InCombatLockdown() then return end
    local state, two = BarsState()
    if state ~= self.state then
        self.state = state
        pcall(LayoutStatusBars)
        if two ~= self.two then
            self.two = two
            if ns.QueueApply then ns.QueueApply() end
        end
    end
end)

local CAST_GAP = 26
local castWatch = CreateFrame("Frame")
castWatch:SetScript("OnUpdate", function(self, elapsed)
    -- Walking every bar system and its buttons is far too heavy for a frame
    -- tick; ten times a second is smooth for a position that changes rarely.
    self.since = (self.since or 0) + elapsed
    if self.since < 0.1 then return end
    self.since = 0
    local bar = _G["PlayerCastingBarFrame"]
    if not (active and art and bar and bar:IsShown()) then return end
    if bar.isDragging then return end
    if bar.IsInDefaultPosition then
        local ok, default = pcall(bar.IsInDefaultPosition, bar)
        if ok and default == false then return end
    end
    local screen = UIParent:GetEffectiveScale()
    local centre = UIParent:GetWidth() / 2
    local top = 0
    for _, frame in ipairs({ art, MultiBarBottomLeft, MultiBarBottomRight, StanceBar, PetActionBar, PossessActionBar,
        MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        local onBand = frame == art or (frame and not frame.isDragging and not SystemMoved(frame))
        if onBand and frame:IsShown() and (frame:GetAlpha() or 1) > 0 and frame:GetTop() and frame:GetLeft() then
            local from, to = frame, frame
            local buttons = frame.actionButtons
            if buttons and buttons[1] and buttons[1]:GetLeft() then
                from, to = buttons[1], buttons[1]
                for i = #buttons, 2, -1 do
                    if buttons[i]:IsShown() and buttons[i]:GetRight() then to = buttons[i] break end
                end
            end
            local k = from:GetEffectiveScale() / screen
            local left, right = math.min(from:GetLeft(), to:GetLeft()) * k, math.max(from:GetRight(), to:GetRight()) * k
            local up = math.max(from:GetTop(), to:GetTop()) * k
            if left < centre + 110 and right > centre - 110 and up < 260 and up > top then top = up end
        end
    end
    if top <= 0 then return end
    local mine = bar:GetEffectiveScale() / screen
    local want = (top + CAST_GAP) / mine
    local bottom = bar:GetBottom()
    if bottom and math.abs(bottom - want) > 1 then
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, want)
    end
end)

function ns.StatusBarsBusy()
    if not (active and art) then return false end
    for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        if container and Playing(container) then return true end
    end
    return (BarsState()) ~= barsWatch.state
end

function ns.StatusBarsShowFaction()
    for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        for _, bar in pairs(container and container.bars or {}) do
            if bar:IsShown() and not bar.ExhaustionTick and bar.factionID then return true end
        end
    end
    return false
end

local function BarMoved(bar)
    if not ns.db.barDragged then return false end
    return SystemMoved(bar)
end

local function AfterLayout()
    if ns.OnBarLaid then ns.OnBarLaid() end
end
ns.MicroButtonList = MicroButtonList

local bagsDropped = false
local bagsInHand = false
local bagsWereOut

local function ReadShape()
    shape.micro = not MicroOut()
    local bagsMoved = BagsBar and SystemMoved(BagsBar)
    if not bagsMoved and ns.db.bagsHeld then ns.db.bagsHeld = false end
    shape.bags = (not bagsMoved) or ns.db.bagsHeld == true
    local count = 0
    for _, button in ipairs(MicroButtonList()) do
        if not MICRO_SKIP[button:GetName() or ""] and (button:IsShown() or hiddenMicro[button]) then count = count + 1 end
    end
    shape.scale, shape.region = MicroPlan(count, MicroUserScale())
    shape.region = math.max(MICRO_LEAD + MICRO_END_GAP, math.min(MICRO_REGION_MAX, shape.region))
    shape.bagsReal, shape.microReal = shape.bags, shape.micro
    shape.noPages = BarSetting(ns.GetMainBar(), "HideBarScrolling") == 1
    local icons = BarSetting(ns.GetMainBar(), "NumIcons")
    if not icons or icons < 1 or icons > 12 then icons = 12 end
    shape.cut = (12 - math.floor(icons + 0.5)) * BUTTON_PITCH
    if bagsDropped then
        bagsDropped = false
        local showing = dragPreview.bagsFirst
        dragPreview.bags, dragPreview.bagsFirst = nil, nil
        if bagsInHand and BagsBar and not InCombatLockdown() then
            local place = DropPlace("bags", BagsBar, showing)
            if place ~= nil then
                ns.db.bagsHeld = true
                ns.db.bagsSnapScale = BagsBar:GetScale() or 1
                shape.bags, shape.bagsReal = true, true
                ns.MicroTouched()
                ns.db.bagsFirst = place
            else
                ns.db.bagsHeld = false
                ns.db.bagsSnapScale = 0
                shape.bags = not SystemMoved(BagsBar)
                shape.bagsReal = shape.bags
            end
            if ns.MirrorSave then ns.MirrorSave() end
        end
        bagsInHand = false
    end
    if shape.bagsReal and bagsWereOut and BagsBar and math.abs((BagsBar:GetScale() or 1) - 1) > 0.001 then
        ns.db.bagsSnapScale = BagsBar:GetScale() or 1
        if ns.MirrorSave then ns.MirrorSave() end
    end
    bagsWereOut = not shape.bagsReal
    local bagsFirst = ns.db and ns.db.bagsFirst
    if dragPreview.micro ~= nil then shape.micro = dragPreview.micro end
    if dragPreview.bags ~= nil then shape.bags = dragPreview.bags end
    if dragPreview.bagsFirst ~= nil then bagsFirst = dragPreview.bagsFirst end
    shape.plan = BandPlan(OnBandMicro(), OnBandBags(), bagsFirst, shape.region)
end

local function Layout()
    local bar = ns.GetMainBar()
    if not bar then return end
    ReadShape()
    art:SetScale(BandScale(bar))
    art:ClearAllPoints()
    local moved = BarMoved(bar)
    ns.barMoved = moved
    if not moved then
        local band = BandNow()
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM",
            ((ns.db.barOffsetX or 0) - ArtWidth() / 2 + ROW_X) * band, ((ns.db.barOffsetY or 0) + ROW_Y) * band)
    end
    if moved or bar.isDragging then
        art:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -ROW_X, -ROW_Y)
    else
        art:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", (ns.db.barOffsetX or 0) - ArtWidth() / 2, ns.db.barOffsetY or 0)
    end
    art:Show()
    PaintArt()
    ApplyArtShape(bar)
    if bar.BorderArt then bar.BorderArt:SetAlpha(0) end
    if bar.HorizontalDividersPool then bar.HorizontalDividersPool:ReleaseAll() end
    if bar.VerticalDividersPool then bar.VerticalDividersPool:ReleaseAll() end
    LayoutButtons(bar, 1, "BOTTOMLEFT", art, "BOTTOMLEFT", ROW_X, ROW_Y)
    LayoutPageArrows(bar)

    local lower, upper = MultiBarBottomLeft, MultiBarBottomRight
    local twoBars = HasVisibleBar(MainStatusTrackingBarContainer) and HasVisibleBar(SecondaryStatusTrackingBarContainer)
    local barLift = twoBars and TWO_BAR_LIFT or 0
    BandRow(lower, 2, ROW_X, UPPER_ROW_Y + barLift)
    if OneBar() then
        BandRow(upper, 3, ROW_X, UPPER_ROW_Y + BUTTON_PITCH + barLift)
    else
        BandRow(upper, 3, CurrentPlan().base + 8, UPPER_ROW_Y + barLift)
    end
    LayoutPetRow((OneBar() and BUTTON_PITCH or 0) + barLift)
    LayoutSideBars()
    LayoutExtraBars(ns.db.hideExtraBars)
    ns.HookGlobal("MultiActionBar_Update", FollowSettings)
    LayoutBags()
    LayoutMicroButtons()
    LayoutStatusBars()
    AfterLayout()
end

local function Apply()
    if not art then BuildArt() end
    active = true
    ns.db.bandHandedBack = nil
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    applying = true
    ns.bandPasses = (ns.bandPasses or 0) + 1
    local ok, err = pcall(Layout)
    applying = false
    Snapshot()
    if not ok then geterrorhandler()(err) end
end

function ns.ClassicBarActive() return active end

local function Restore()
    if not active then return end
    if InCombatLockdown() then
        restoreQueued = true
        return
    end
    active = false
    restoreQueued = false
    RestoreSelections()
    if art then
        art:Hide()
        if art.perfBar then art.perfBar:Hide() end
        if art.perfMeter then art.perfMeter:Hide() end
        if art.bagFloor then art.bagFloor:Hide() end
    end
    LayoutExtraBars(false)
    local bar = ns.GetMainBar()
    for _, button in ipairs(MicroButtonList()) do
        ns.UnskinMicroButton(button)
        if hiddenMicro[button] then
            hiddenMicro[button] = nil
            button:Show()
        end
    end
    for _, name in ipairs(BAG_BUTTONS) do
        if _G[name] then ns.UnskinBagButton(_G[name]) end
    end
    if CharacterReagentBag0Slot then
        ns.UnskinBagButton(CharacterReagentBag0Slot)
        ns.UnskinKeyRing(CharacterReagentBag0Slot)
    end
    if KeyRingButton then ns.UnskinKeyRing(KeyRingButton) end
    for _, name in ipairs(MICRO_BUTTONS) do
        local button = _G[name]
        if button and button.GetCenter and not button:GetCenter() then
            button:ClearAllPoints()
            button:SetPoint("CENTER", MicroMenu or UIParent, "CENTER", 0, 0)
        end
    end
    for frame, state in pairs(saved) do
        frame:SetScale(state.scale)
        if frame:GetParent() == art and state.parent then
            pcall(frame.SetParent, frame, state.parent)
            frame:SetSize(state.w, state.h)
        end
    end
    wipe(saved)
    for _, name in ipairs({ "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "StanceBar", "PetActionBar", "PossessActionBar" }) do
        RestoreButtons(_G[name])
    end
    if ns.WorldMapMicroButton then ns.WorldMapMicroButton:Hide() end
    if bar then
        if bar.BorderArt then bar.BorderArt:SetAlpha(1) end
        for _, key in ipairs(CAP_KEYS) do
            local cap = CapFrame(bar, key)
            if cap then
                for _, region in ipairs({ cap:GetRegions() }) do
                    if region:IsObjectType("Texture") then region:SetAlpha(1) end
                end
            end
        end
        if bar.UpdateEndCaps then bar:UpdateEndCaps(bar.hideBarArt) end
        if bar.UpdateDividers then bar:UpdateDividers() end
    end
    if StoreMicroButton then StoreMicroButton:SetAlpha(1) end
    if MicroMenu then
        if MicroMenu.BorderArt then MicroMenu.BorderArt:SetAlpha(1) end
        if MicroMenu.BackgroundArt then MicroMenu.BackgroundArt:SetAlpha(1) end
        if MicroMenu.Layout then pcall(MicroMenu.Layout, MicroMenu) end
    end
    if BagsBar then
        if BagsBar.BorderArt then BagsBar.BorderArt:SetAlpha(1) end
        if BagsBar.Layout then pcall(BagsBar.Layout, BagsBar) end
    end
    if BagBarExpandToggle then BagBarExpandToggle:Show() end
    for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        if container then
            container:SetAlpha(1)
            if container.BarFrameTexture then container.BarFrameTexture:SetAlpha(1) end
            if container.HorizontalDividersPool then
                for divider in container.HorizontalDividersPool:EnumerateActive() do divider:SetAlpha(1) end
            end
            for _, b in pairs(container.bars or {}) do
                if b.StatusBar and b.StatusBar.fcuiStrips then
                    for _, tex in ipairs(b.StatusBar.fcuiStrips) do tex:Hide() end
                end
            end
        end
    end
    for _, name in ipairs(OWNED_SYSTEMS) do
        local frame = _G[name]
        if frame and frame.ApplySystemAnchor then pcall(frame.ApplySystemAnchor, frame) end
    end
    if EditModeManagerFrame and EditModeManagerFrame.UpdateBottomActionBarPositions then
        pcall(EditModeManagerFrame.UpdateBottomActionBarPositions, EditModeManagerFrame)
    end
    if StatusTrackingBarManager and StatusTrackingBarManager.UpdateBarsShown then
        pcall(StatusTrackingBarManager.UpdateBarsShown, StatusTrackingBarManager)
    end
    local pn = bar and bar.ActionBarPageNumber
    if pn then
        pn:SetFrameStrata(bar:GetFrameStrata())
        pn:SetScale(1)
        pn:ClearAllPoints()
        pn:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", -4, 9)
        for _, entry in ipairs({ { pn.UpButton, 10 }, { pn.DownButton, -10 } }) do
            local button, y = entry[1], entry[2]
            if button then
                button:SetSize(17, 14)
                button:SetHitRectInsets(0, 0, 0, 0)
                button:ClearAllPoints()
                button:SetPoint("CENTER", pn, "CENTER", 0, y)
            end
        end
        if pn.Text then
            pn.Text:SetFontObject("GameFontNormal")
            pn.Text:ClearAllPoints()
            pn.Text:SetPoint("CENTER", pn, "CENTER", -1, 0)
        end
        if pn.Layout then pcall(pn.Layout, pn) end
    end
    if bar and bar.ActionBarPageNumber and bar.UpdateSystemSettingHideBarScrolling then
        pcall(bar.UpdateSystemSettingHideBarScrolling, bar)
    end
    local presets = EditModePresetLayoutManager
    for _, name in ipairs(OWNED_SYSTEMS) do
        local frame = _G[name]
        if frame and frame.system and presets and presets.GetDefaultSystemAnchorInfo
            and type(frame.IsInDefaultPosition) == "function" then
            local okDefault, isDefault = pcall(frame.IsInDefaultPosition, frame)
            local ok, info = pcall(presets.GetDefaultSystemAnchorInfo, presets, frame.system, frame.systemIndex)
            local relativeTo = ok and info and (type(info.relativeTo) == "string" and _G[info.relativeTo] or info.relativeTo)
            if okDefault and not isDefault and relativeTo and info.point then
                local scale = frame:GetScale()
                if not scale or scale <= 0 then scale = 1 end
                frame:ClearAllPoints()
                frame:SetPoint(info.point, relativeTo, info.relativePoint or info.point, (info.offsetX or 0) / scale, (info.offsetY or 0) / scale)
            end
        end
    end
    ns.needsReload = true
end

local dragging = false
local editWatch
ns.EditModeDragging = function() return dragging end

local watchList, baseline = {}, {}
local shiftSeen = false
local MarkStatus
local function WatchList()
    if #watchList > 0 then return watchList end
    local names = { "BottomManagedFrameContainer", "RightManagedFrameContainer", "MicroMenu", "BagsBar" }
    for _, name in ipairs(OWNED_SYSTEMS) do names[#names + 1] = name end
    names[#names + 1] = BAG_BUTTONS[1]
    for _, name in ipairs(names) do
        local frame = _G[name]
        if frame and frame.GetPoint then watchList[#watchList + 1] = frame end
    end
    local micro = MicroButtonList()[1]
    if micro then watchList[#watchList + 1] = micro end
    for _, key in ipairs(CAP_KEYS) do
        local cap = CapFrame(ns.GetMainBar(), key)
        if cap and cap.GetPoint then watchList[#watchList + 1] = cap end
    end
    return watchList
end

local function Census()
    local micro, bags = 0, 0
    for _, button in ipairs(MicroButtonList()) do
        if button:IsShown() then micro = micro + 1 end
    end
    for _, name in ipairs(BAG_BUTTONS) do
        local button = _G[name]
        if button and button:IsShown() then bags = bags + 1 end
    end
    return micro, bags
end

local function Record(frame, into)
    into = into or {}
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    into.point, into.rel, into.relPoint = point, rel, relPoint
    into.x, into.y = x or 0, y or 0
    into.w, into.h = frame:GetWidth() or 0, frame:GetHeight() or 0
    into.scale = frame:GetScale() or 1
    into.shown = frame:IsShown() and true or false
    return into
end

local function Differs(frame, b)
    if not b then return true end
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    if point ~= b.point or rel ~= b.rel or relPoint ~= b.relPoint then return true end
    if math.abs((x or 0) - b.x) > 0.05 or math.abs((y or 0) - b.y) > 0.05 then return true end
    if math.abs((frame:GetWidth() or 0) - b.w) > 0.05 then return true end
    if math.abs((frame:GetHeight() or 0) - b.h) > 0.05 then return true end
    if math.abs((frame:GetScale() or 1) - (b.scale or 1)) > 0.001 then return true end
    return (frame:IsShown() and true or false) ~= b.shown
end

local rowList
local rowBase = {}
local function RowFrames()
    if rowList then return rowList end
    local list = {}
    for _, name in ipairs(BAG_BUTTONS) do
        if _G[name] then list[#list + 1] = _G[name] end
    end
    for _, extra in ipairs({ KeyRingButton, CharacterReagentBag0Slot }) do
        if extra then list[#list + 1] = extra end
    end
    local micro = MicroButtonList()
    for _, button in ipairs(micro) do list[#list + 1] = button end
    if #micro > 0 then rowList = list end
    return list
end

local function MarkRows()
    for _, frame in ipairs(RowFrames()) do rowBase[frame] = Record(frame, rowBase[frame]) end
end

local function RowsMoved()
    for _, frame in ipairs(RowFrames()) do
        if rowBase[frame] and Differs(frame, rowBase[frame]) then return true end
    end
    return false
end

local function RowsFree()
    for _, frame in ipairs(RowFrames()) do
        if frame.IsProtected and frame:IsProtected() then return false end
    end
    return true
end

local function RowsBack()
    applying = true
    local ok, err = pcall(function()
        LayoutBags()
        LayoutMicroButtons()
    end)
    applying = false
    MarkRows()
    if not ok and ns.Debug then ns.Debug("rows: " .. tostring(err)) end
end

Snapshot = function()
    for _, frame in ipairs(WatchList()) do baseline[frame] = Record(frame, baseline[frame]) end
    MarkRows()
    baseline.micro, baseline.bags = Census()
    if MarkStatus then MarkStatus() end
end

function ns.MicroDroppedInFight()
    if not InCombatLockdown() or not RowsFree() then return end
    shape.micro = not MicroOut()
    applying = true
    pcall(LayoutMicroButtons)
    applying = false
    MarkRows()
end

local function Moved(list)
    for _, frame in ipairs(list or WatchList()) do
        if Differs(frame, baseline[frame]) then return true end
    end
    if not list then
        local micro, bags = Census()
        if micro ~= baseline.micro or bags ~= baseline.bags then return true end
    end
    return false
end

local statusList
local function StatusFrames()
    if statusList then return statusList end
    statusList = {}
    for _, frame in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        if frame and frame.GetPoint then statusList[#statusList + 1] = frame end
    end
    return statusList
end

local statusMark = {}
local function BarSums(container)
    local count, width, height = 0, 0, 0
    for _, bar in pairs(container.bars or {}) do
        count = count + 1
        width = width + (bar:GetWidth() or 0)
        height = height + (bar:GetHeight() or 0)
        local status = bar.StatusBar
        if status then
            width = width + (status:GetWidth() or 0)
            height = height + (status:GetHeight() or 0)
        end
    end
    return count, width, height
end

MarkStatus = function()
    for _, frame in ipairs(StatusFrames()) do
        local mark = Record(frame, statusMark[frame])
        mark.count, mark.width, mark.height = BarSums(frame)
        statusMark[frame] = mark
    end
end

local function StatusMoved()
    for _, frame in ipairs(StatusFrames()) do
        local mark = statusMark[frame]
        if Differs(frame, mark) then return true end
        local count, width, height = BarSums(frame)
        if count ~= mark.count or math.abs(width - mark.width) > 0.05 or math.abs(height - mark.height) > 0.05 then
            return true
        end
    end
    return false
end

local function StatusBack()
    if not active or applying then return end
    ns.stripPasses = (ns.stripPasses or 0) + 1
    applying = true
    pcall(LayoutStatusBars)
    applying = false
    MarkStatus()
end

local BAND_SYSTEMS = { "MicroMenuContainer", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }
local function HideSelections()
    for _, name in ipairs(BAND_SYSTEMS) do
        local system = _G[name]
        local selection = system and system.Selection
        if selection and selection:IsShown() then selection:Hide() end
    end
end

local function KeepBarShape()
    local bar = ns.GetMainBar()
    if not bar then return end
    for _, key in ipairs(CAP_KEYS) do
        local cap = CapFrame(bar, key)
        if cap then
            for _, region in ipairs({ cap:GetRegions() }) do
                if region:IsObjectType("Texture") and region:GetAlpha() > 0 then region:SetAlpha(0) end
            end
            local tex = key == "LeftEndCap" and art and art.leftCap or art and art.rightCap
            if tex then tex:SetShown(not CapHidden(cap) and EraUI:GetSetting("gryphons")) end
        end
    end
    if art and (bar.hideBarArt == true) ~= (art.artHidden == true) then ApplyArtShape(bar) end
end

local function ReadBarPlacement()
    local bar = ns.GetMainBar()
    if not bar then return end
    local info = bar.systemInfo
    if ns.db.barDragged then
        if info and info.isInDefaultPosition then
            ns.db.barDragged = false
            ns.QueueApply()
        end
        return
    end
    if baseline[bar] and Differs(bar, baseline[bar]) then ns.db.barDragged = true end
end

local HOME_REACH = 40
local function SnapBarHome()
    local bar = ns.GetMainBar()
    if not bar or not art or not ns.db.barDragged or InCombatLockdown() then return end
    local left, bottom = bar:GetLeft(), bar:GetBottom()
    local screen = UIParent:GetWidth()
    if not left or not bottom or not screen then return end
    local band = BandNow()
    local wantLeft = screen / 2 + ((ns.db.barOffsetX or 0) - ArtWidth() / 2 + ROW_X) * band
    local wantBottom = ((ns.db.barOffsetY or 0) + ROW_Y) * band
    if math.abs(left - wantLeft) > HOME_REACH or math.abs(bottom - wantBottom) > HOME_REACH then return end
    ns.db.barDragged = false
    if ns.MirrorSave then ns.MirrorSave() end
end

local WATCH_EDIT, WATCH_IDLE = 0.05, 0.2
local handHeld = false
local handIdle = 0
local capInHand
local burst, burstAt, hold = 0, 0, 0
local function StartWatch()
    if editWatch then return end
    local scaledWindows = false
    local function RightColumnsWidth()
        if ns.db and ns.db.bagsBesideBars == false then return 0 end
        local screenRight = UIParent:GetRight()
        if not screenRight then return 0 end
        local leftmost
        for _, bar in ipairs({ MultiBarRight, MultiBarLeft }) do
            if bar and bar:IsVisible() and (bar:GetAlpha() or 1) > 0 then
                local s = bar:GetEffectiveScale() / UIParent:GetEffectiveScale()
                local l, r, w, h = bar:GetLeft(), bar:GetRight(), bar:GetWidth(), bar:GetHeight()
                if l and r and w and h and h > w * 2 and (screenRight - r * s) < 100 then
                    if not leftmost or l * s < leftmost then leftmost = l * s end
                end
            end
        end
        return leftmost and math.max(0, screenRight - leftmost) or 0
    end
    local besideSet = false
    local function AnchorOpenBags()
        local manager = ContainerFrameSettingsManager
        local backpack = MainMenuBarBackpackButton
        if not manager or not manager.GetBagsShown or not backpack or not backpack:IsVisible() then return end
        local ok, shown = pcall(manager.GetBagsShown, manager)
        local first = ok and type(shown) == "table" and shown[1]
        if not first or not first.GetPoint then return end
        local _, relativeTo = first:GetPoint(1)
        if not (ns.db and ns.db.bagsAboveRow == true) then
            if relativeTo == backpack and type(UpdateContainerFrameAnchors) == "function" then
                pcall(UpdateContainerFrameAnchors)
            end
            local point, rel, relPoint, x, y = first:GetPoint(1)
            if point == "BOTTOMRIGHT" and relPoint == "BOTTOMRIGHT" and rel and rel == first:GetParent() then
                local width = RightColumnsWidth()
                if width > 0 then
                    local scale = first:GetScale() or 1
                    if scale <= 0 then scale = 1 end
                    local target = -(width + 10) / scale
                    if math.abs((x or 0) - target) > 0.5 then
                        first:SetPoint(point, rel, relPoint, target, y or 0)
                    end
                    besideSet = true
                elseif besideSet then
                    besideSet = false
                    if type(UpdateContainerFrameAnchors) == "function" then pcall(UpdateContainerFrameAnchors) end
                end
            end
        elseif relativeTo ~= backpack then
            first:ClearAllPoints()
            first:SetPoint("BOTTOMRIGHT", backpack, "TOPRIGHT", 0, 10)
        end
        local piece = BagsBar
        local follow = ns.db and ns.db.bagWindowsFollow and piece and ((shape.bagsReal == false) or OneBar())
        if not follow and not scaledWindows then return end
        local base = 1
        if type(GetContainerScale) == "function" then
            local okScale, value = pcall(GetContainerScale)
            if okScale and type(value) == "number" and value > 0 then base = value end
        end
        local want = follow and base * (piece:GetScale() or 1) or base
        for _, frame in ipairs(shown) do
            if math.abs((frame:GetScale() or 1) - want) > 0.001 then frame:SetScale(want) end
        end
        scaledWindows = follow and true or false
    end

    local function BagsExtra()
        local extra = art.bagsExtra
        if extra then return extra end
        extra = CreateFrame("Frame", "EraUIClassicBagsExtra", UIParent)
        extra:SetFrameStrata("DIALOG")
        extra:SetFrameLevel(200)
        extra:SetHeight(184)
        extra:Hide()
        art.bagsExtra = extra
        local okBorder, border = pcall(CreateFrame, "Frame", nil, extra, "DialogBorderTranslucentTemplate")
        if okBorder and border then
            border:SetAllPoints(extra)
        else
            local ground = extra:CreateTexture(nil, "BACKGROUND")
            ground:SetAllPoints(extra)
            ground:SetColorTexture(0, 0, 0, 0.85)
        end
        local check = CreateFrame("CheckButton", nil, extra, "UICheckButtonTemplate")
        check:SetSize(30, 30)
        check:SetPoint("TOPLEFT", extra, "TOPLEFT", 22, -14)
        check:SetScript("OnClick", function(self)
            ns.db.bagWindowsFollow = self:GetChecked() and true or false
        end)
        extra.check = check
        local text = extra:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
        text:SetPoint("LEFT", check, "RIGHT", 6, 0)
        text:SetText("Opened bags take this size too")
        local above = CreateFrame("CheckButton", nil, extra, "UICheckButtonTemplate")
        above:SetSize(30, 30)
        above:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 0, -2)
        above:SetScript("OnClick", function(self)
            ns.db.bagsAboveRow = self:GetChecked() and true or false
            if ns.ToggleChanged then ns.ToggleChanged("bagsAboveRow") end
        end)
        extra.above = above
        local aboveText = extra:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
        aboveText:SetPoint("LEFT", above, "RIGHT", 6, 0)
        aboveText:SetText("Opened bags above the bag buttons")
        local one = CreateFrame("CheckButton", nil, extra, "UICheckButtonTemplate")
        one:SetSize(30, 30)
        one:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -2)
        one:SetScript("OnClick", function(self)
            ns.db.oneBag = self:GetChecked() and true or false
            if ns.ToggleChanged then ns.ToggleChanged("oneBag") end
            if extra.InitColumns then extra.InitColumns() end
        end)
        extra.one = one
        local oneText = extra:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
        oneText:SetPoint("LEFT", one, "RIGHT", 6, 0)
        oneText:SetText("One bag: all bags open as one window")
        local colsLabel = extra:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
        colsLabel:SetPoint("TOPLEFT", one, "BOTTOMLEFT", 6, -10)
        colsLabel:SetText("One bag columns")
        extra.colsLabel = colsLabel
        local okSlider, slider = pcall(CreateFrame, "Frame", nil, extra, "MinimalSliderWithSteppersTemplate")
        if okSlider and slider and slider.Init then
            slider:SetSize(180, 32)
            slider:SetPoint("LEFT", colsLabel, "RIGHT", 10, 0)
            extra.slider = slider
            local low, high = ns.ONE_BAG_COLUMNS_MIN or 4, ns.ONE_BAG_COLUMNS_MAX or 16
            local formatters
            if CreateMinimalSliderFormatter and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
                formatters = { [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
                    MinimalSliderWithSteppersMixin.Label.Right, function(value) return tostring(math.floor(value + 0.5)) end) }
            end
            extra.InitColumns = function()
                extra.filling = true
                slider:Init(tonumber(ns.db.oneBagColumns) or low, low, high, high - low, formatters)
                extra.filling = false
                local on = ns.db.oneBag == true
                slider:SetAlpha(on and 1 or 0.4)
                if slider.SetEnabled then pcall(slider.SetEnabled, slider, on) end
                colsLabel:SetFontObject(on and "GameFontHighlightMedium" or "GameFontDisableMed3")
            end
            if slider.RegisterCallback and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Event then
                slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
                    if extra.filling or type(value) ~= "number" or not ns.SetOneBagColumns then return end
                    ns.SetOneBagColumns(value)
                end, extra)
            end
        end
        local saved = extra:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        saved:SetPoint("BOTTOMLEFT", extra, "BOTTOMLEFT", 26, 14)
        saved:SetText("These apply and save the moment you change them. No Save needed.")
        local resize = CreateFrame("Button", nil, extra, "UIPanelButtonTemplate")
        resize:SetHeight(28)
        resize:SetText("Reset To Default Size")
        resize:SetFrameLevel(210)
        resize:SetScript("OnClick", function()
            local setting = Enum and Enum.EditModeBagsSetting and Enum.EditModeBagsSetting.Size
            local manager = EditModeManagerFrame
            if setting == nil or not manager or not manager.OnSystemSettingChange or not BagsBar then return end
            pcall(manager.OnSystemSettingChange, manager, BagsBar, setting, 100)
            ns.editWrote = true
            local dialog = EditModeSystemSettingsDialog
            if dialog and dialog.UpdateDialog then pcall(dialog.UpdateDialog, dialog, BagsBar) end
        end)
        extra.resize = resize
        return extra
    end

    local function FollowBagsDialog(editing)
        local dialog = EditModeSystemSettingsDialog
        local up = editing and dialog and dialog:IsShown() and dialog.attachedToSystem == BagsBar
        local extra = art and art.bagsExtra
        if not up then
            if extra and extra:IsShown() then extra:Hide() end
            return
        end
        extra = BagsExtra()
        extra:ClearAllPoints()
        extra:SetPoint("TOPLEFT", dialog, "BOTTOMLEFT", 0, 6)
        extra:SetPoint("TOPRIGHT", dialog, "BOTTOMRIGHT", 0, 6)
        extra.check:SetChecked(ns.db.bagWindowsFollow and true or false)
        if extra.one then extra.one:SetChecked(ns.db.oneBag == true) end
        if extra.above then extra.above:SetChecked(ns.db.bagsAboveRow == true) end
        if extra.InitColumns then extra.InitColumns() end
        local revert = dialog.Buttons and dialog.Buttons.RevertChangesButton
        if revert and extra.resize then
            extra.resize:ClearAllPoints()
            extra.resize:SetPoint("LEFT", revert, "RIGHT", 6, 0)
            extra.resize:SetPoint("RIGHT", dialog.Buttons, "RIGHT", 0, 0)
            extra.resize:Show()
        elseif extra.resize then
            extra.resize:Hide()
        end
        extra:Show()
    end

    editWatch = CreateFrame("Frame")
    editWatch:SetScript("OnUpdate", function(self, elapsed)
        -- Bag anchoring and the status-bar check are event-driven work; they
        -- were running on every frame before the main throttle below.
        self.pulse = (self.pulse or 0) + elapsed
        if self.pulse >= 0.1 then
            self.pulse = 0
            if active then AnchorOpenBags() end
            if active and not applying and StatusMoved() then StatusBack() end
        end
        local mgr = EditModeManagerFrame
        local editing = mgr and mgr.IsEditModeActive and mgr:IsEditModeActive() and true or false
        local held = active and editing and IsMouseButtonDown and IsMouseButtonDown("LeftButton") and true or false
        if active and held ~= dragging then
            dragging = held
            if not held then
                if editing then
                    ReadBarPlacement()
                    SnapBarHome()
                    bagsDropped = true
                    if capInHand then
                        local key, bar = capInHand, ns.GetMainBar()
                        local cap = CapFrame(bar, key)
                        ns.db.capMoved = ns.db.capMoved or {}
                        local slotX = ArtWidth() / 2 + CapSlot(key, ArtWidth()) - CAP_SIZE / 2
                        if cap and NearBandSlot(cap, slotX, 0, "BOTTOMLEFT") then
                            ns.db[CapHeldKey(key)] = true
                            ns.db.capMoved[key] = nil
                        else
                            ns.db[CapHeldKey(key)] = false
                            ns.db.capMoved[key] = true
                        end
                        if ns.MirrorSave then ns.MirrorSave() end
                    end
                end
                capInHand = nil
                handHeld = false
                if not InCombatLockdown() then ns.SafeCall(Apply) end
                ns.QueueApply()
            end
        end
        self.since = (self.since or 0) + elapsed
        if self.since < (editing and WATCH_EDIT or WATCH_IDLE) then return end
        self.since = 0
        if not active then return end
        local mainBar = ns.GetMainBar()
        if editing and mainBar and (mainBar.hideBarArt == true) ~= (art.artHidden == true) then ns.QueueApply() end
        if editing and (BarSetting(ns.GetMainBar(), "HideBarScrolling") == 1) ~= (shape.noPages and true or false) then
            ns.QueueApply()
        end
        if editing then HideSelections() end
        if editing and ns.microDirty and mgr then
            for _, key in ipairs({ "SaveChangesButton", "RevertAllChangesButton" }) do
                local button = mgr[key]
                if button then
                    if not button:IsEnabled() then
                        local raw = getmetatable(button)
                        raw = raw and raw.__index
                        if type(raw) == "table" and raw.Enable then raw.Enable(button) else button:Enable() end
                    end
                    if not button.fcuiMicroHooked then
                        button.fcuiMicroHooked = true
                        button:HookScript("OnClick", function()
                            if not ns.microDirty then return end
                            local before = ns.microBefore
                            ns.microDirty, ns.microBefore = false, nil
                            if key == "RevertAllChangesButton" and before and ns.db then
                                ns.db.microPos, ns.db.microScale, ns.db.bagsFirst = before.pos, before.scale, before.bagsFirst
                                if ns.MirrorSave then ns.MirrorSave() end
                                ns.QueueApply()
                            end
                        end)
                    end
                end
            end
        elseif not editing and ns.microDirty then
            ns.microDirty, ns.microBefore = false, nil
        end
        if editing then
            local mark = ""
            for _, name in ipairs({ "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "StanceBar", "PetActionBar" }) do
                local bar = _G[name]
                if bar then mark = mark .. tostring(BarVertical(bar)) .. BarRows(bar) .. tostring(BarSetting(bar, "NumIcons")) .. ";" end
            end
            if self.barMark and self.barMark ~= mark then ns.QueueApply() end
            self.barMark = mark
        else
            self.barMark = nil
        end
        local bagsPiece = BagsBar
        if bagsPiece and bagsPiece.isDragging then bagsInHand = true end
        if bagsPiece and bagsPiece.isDragging and not OneBar() then
            local place = DropPlace("bags", bagsPiece, dragPreview.bagsFirst)
            local near = place ~= nil
            if dragPreview.bags ~= near or (near and dragPreview.bagsFirst ~= place) then
                dragPreview.bags = near
                if near then dragPreview.bagsFirst = place else dragPreview.bagsFirst = nil end
                ns.QueueApply()
            end
        elseif dragPreview.bags ~= nil then
            dragPreview.bags, dragPreview.bagsFirst = nil, nil
        end
        for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
            local pool = container and container.HorizontalDividersPool
            if pool and pool.EnumerateActive then
                for divider in pool:EnumerateActive() do
                    if divider:GetAlpha() > 0 then divider:SetAlpha(0) end
                end
            end
        end
        local handle = art and art.microHome and art.microHome.handle
        if handle and handle:IsShown() ~= editing then
            if editing then handle:SetFrameLevel(1010) end
            handle:SetShown(editing)
        end
        if not editing and art and art.microDialog and art.microDialog:IsShown() then art.microDialog:Hide() end
        if art then FollowBagsDialog(editing) end
        if not dragging and not InCombatLockdown() then KeepBarShape() end
    end)

    local function PieceInHand()
        for _, name in ipairs(OWNED_SYSTEMS) do
            local frame = _G[name]
            if frame and frame.isDragging then return true end
        end
        local bar = ns.GetMainBar()
        for _, key in ipairs(CAP_KEYS) do
            local cap = CapFrame(bar, key)
            if cap and cap.isDragging then
                capInHand = key
                return true
            end
        end
        local home = art and art.microHome
        return (home and home.moving) and true or false
    end

    local function PlaceNow()
        if not active or applying then return end
        if PieceInHand() then
            local bar = ns.GetMainBar()
            if bar and bar.isDragging and art and not handHeld then
                art:ClearAllPoints()
                art:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -ROW_X, -ROW_Y)
            end
            for other, hung in pairs(rowOf) do
                if other ~= bar and other.isDragging and not hung.onBar and not InCombatLockdown() then
                    hung.onBar = true
                    hung.row:ClearAllPoints()
                    if hung.vertical then
                        hung.row:SetPoint("TOPLEFT", other, "TOPLEFT", 0, 0)
                    else
                        hung.row:SetPoint("BOTTOMLEFT", other, "BOTTOMLEFT", 0, 0)
                    end
                end
            end
            handHeld = true
            return
        end
        if handHeld then
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                handIdle = (handIdle or 0) + 1
                if handIdle > 30 then handHeld, handIdle = false, 0 end
            end
            if handHeld then return end
        end
        handIdle = 0
        local rows = RowsMoved()
        local fight = InCombatLockdown()
        if fight then
            local manager = EditModeManagerFrame
            if manager and manager.IsEditModeActive and manager:IsEditModeActive() then
                ns.fightEdited = true
                shiftSeen = false
            end
            if not shiftSeen and not ns.fightEdited then
                for _, frame in ipairs(ns.BandBarsToUnpinned()) do
                    if baseline[frame] and Differs(frame, baseline[frame]) then
                        shiftSeen = true
                        local b = baseline[frame]
                        local point, rel, relPoint, x, y = frame:GetPoint(1)
                        ns.Persist(string.format("bars: %s off its place %.2f s into the fight: was %s>%s.%s %.0f,%.0f scale %.2f shown %s; now %s>%s.%s %.0f,%.0f scale %.2f shown %s",
                            tostring(frame:GetName()), GetTime() - (ns.fightBeganAt or GetTime()),
                            tostring(b.point), tostring(b.rel and b.rel.GetName and b.rel:GetName()), tostring(b.relPoint), b.x or 0, b.y or 0, b.scale or 1, tostring(b.shown),
                            tostring(point), tostring(rel and rel.GetName and rel:GetName()), tostring(relPoint), x or 0, y or 0, frame:GetScale() or 1, tostring(frame:IsShown())))
                        break
                    end
                end
            end
            if not (rows and RowsFree()) then return end
        elseif ns.fightEdited then
            ns.fightEdited = nil
            shiftSeen = false
        elseif shiftSeen then
            shiftSeen = false
            ns.Persist("bars: moved by the client during a fight; put back, nobody asked")
        elseif not rows and not Moved() then
            return
        end
        local mgr = EditModeManagerFrame
        local byHand = mgr and mgr.IsEditModeActive and mgr:IsEditModeActive()
            and IsMouseButtonDown and IsMouseButtonDown("LeftButton")
        if not byHand then
            local now = GetTime()
            if now < hold then return end
            if now - burstAt < 1 then burst = burst + 1 else burst = 0 end
            burstAt = now
            if burst > 8 then
                burst, hold = 0, now + 0.6
                return
            end
        end
        if fight then RowsBack() else ns.SafeCall(Apply) end
    end
    local placer = CreateFrame("Frame")
    -- The placement pass inspects every bar piece and is expensive. Events and
    -- explicit calls still place immediately; the idle poll only needs to be
    -- fast enough to chase the client within a tenth of a second.
    placer:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 0.1 then return end
        self.since = 0
        PlaceNow()
    end)
    placer:RegisterEvent("PLAYER_TARGET_CHANGED")
    placer:RegisterEvent("PLAYER_FOCUS_CHANGED")
    for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PET_BAR_UPDATE", "UPDATE_SHAPESHIFT_FORMS",
        "UPDATE_BONUS_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR", "UPDATE_OVERRIDE_ACTIONBAR" }) do
        pcall(placer.RegisterEvent, placer, event)
    end
    pcall(placer.RegisterUnitEvent, placer, "UNIT_PET", "player")
    local lastWord = CreateFrame("Frame")
    lastWord:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 1 then return end
        self.since = 0
        if InCombatLockdown() then return end
        placer:UnregisterEvent("PLAYER_REGEN_DISABLED")
        placer:RegisterEvent("PLAYER_REGEN_DISABLED")
    end)
    placer:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            local ok, moved = pcall(Moved)
            ns.fightBeganAt = GetTime()
            ns.Persist("bars: fight beginning; moved by the client " .. tostring(ok and moved) .. ", locked " .. tostring(InCombatLockdown()))
            PlaceNow()
            local okAfter, movedAfter = pcall(Moved)
            ns.Persist("bars: after our pass, still moved " .. tostring(okAfter and movedAfter) .. ", locked " .. tostring(InCombatLockdown()) .. ", passes " .. tostring(ns.bandPasses))
            pcall(HoldBandBoxes, true)
            return
        end
        if event == "PLAYER_REGEN_ENABLED" then pcall(HoldBandBoxes, false) end
        PlaceNow()
    end)
end

local function Init()
    local bar = ns.GetMainBar()
    if not bar then return end
    StartWatch()
    if HelpOpenWebTicketButton and MainMenuMicroButton and MicroMenu then
        ns.HookMethod(MicroMenu, "UpdateHelpTicketButtonAnchor", function()
            if active then
                HelpOpenWebTicketButton:ClearAllPoints()
                HelpOpenWebTicketButton:SetPoint("CENTER", MainMenuMicroButton, "TOPRIGHT", -3, -5)
            end
        end)
    end

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:RegisterEvent("UPDATE_EXHAUSTION")
    watcher:RegisterEvent("PLAYER_UPDATE_RESTING")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("PLAYER_XP_UPDATE")
    watcher:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            RecolorExpBars()
            for _, wait in ipairs({ 0.5, 1.5, 3 }) do
                C_Timer.After(wait, function() if active then ns.QueueApply() end end)
            end
            return
        end
        if event ~= "PLAYER_REGEN_ENABLED" then
            RecolorExpBars()
            return
        end
        if restoreQueued then
            Restore()
        elseif pending and active then
            ns.QueueApply()
        end
    end)
    if ns.OnEditMode then
        ns.OnEditMode(function()
            dragging = false
            if active then ns.QueueApply() end
        end)
    end
end

local PIN_NAMES = { "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
    "MultiBarLeft", "StanceBar", "PetActionBar", "PossessActionBar", "MainStatusTrackingBarContainer",
    "SecondaryStatusTrackingBarContainer" }

function ns.BandBarsToUnpinned()
    local list = {}
    if not active or not art then return list end
    for _, name in ipairs(PIN_NAMES) do
        local frame = _G[name]
        if frame and frame.system and frame:IsShown() and type(frame.IsInDefaultPosition) == "function" then
            local ok, isDefault = pcall(frame.IsInDefaultPosition, frame)
            if ok and isDefault then list[#list + 1] = frame end
        end
    end
    return list
end

function ns.BandBarsToPin()
    local list = {}
    if not active or not art then return list end
    for _, name in ipairs(PIN_NAMES) do
        local frame = _G[name]
        if frame and frame.system and frame:IsShown() and type(frame.IsInDefaultPosition) == "function" then
            local ok, isDefault = pcall(frame.IsInDefaultPosition, frame)
            local info = frame.systemInfo and frame.systemInfo.anchorInfo
            if ok and (isDefault or PinnedByUs(frame, info)) then list[#list + 1] = frame end
        end
    end
    return list
end

local function AnchorToScreen(frame)
    local point, relativeTo, relativePoint = frame:GetPoint(1)
    if relativeTo == UIParent and point ~= relativePoint then return true end
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    if not left or not bottom then return false end
    local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if not ratio or ratio <= 0 then return false end
    local half = UIParent:GetWidth() / 2 / ratio
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", left - half, bottom)
    return true
end

local ResetEndCaps
function ns.PinBandBars()
    if not ns.sessionEnding then return false end
    if not active or not art or InCombatLockdown() then return false end
    if not (ns.LayoutWritable and ns.LayoutWritable()) then return false end
    local mgr = EditModeManagerFrame
    if not mgr or not mgr.UpdateSystemAnchorInfo or not mgr.SaveLayouts then return false end
    local layoutName = ActiveLayoutName()
    if not layoutName then return false end
    local changed = false
    applying = true
    for _, frame in ipairs(ns.BandBarsToPin()) do
        if AnchorToScreen(frame) then
            local ok, did = pcall(mgr.UpdateSystemAnchorInfo, mgr, frame)
            local held = mgr.GetActiveLayoutSystemInfo and mgr:GetActiveLayoutSystemInfo(frame.system, frame.systemIndex)
            local info = (held and held.anchorInfo) or (frame.systemInfo and frame.systemInfo.anchorInfo)
            if ok and did and info then
                ns.db.barPins = ns.db.barPins or {}
                ns.db.barPins[layoutName] = ns.db.barPins[layoutName] or {}
                ns.db.barPins[layoutName][frame:GetName()] = {
                    point = info.point, relativePoint = info.relativePoint,
                    offsetX = info.offsetX, offsetY = info.offsetY,
                }
                changed = true
            end
        end
    end
    applying = false
    if ResetEndCaps() then changed = true end
    if changed then pcall(mgr.SaveLayouts, mgr) end
    ns.db.pinShape = true
    return changed
end

function ns.BandPinAnchors()
    local out = {}
    for _, frame in ipairs(ns.BandBarsToPin()) do
        local left, bottom = frame:GetLeft(), frame:GetBottom()
        local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local scale = frame:GetScale()
        if left and bottom and ratio and ratio > 0 and scale and scale > 0 then
            local half = UIParent:GetWidth() / 2 / ratio
            out[#out + 1] = {
                name = frame:GetName(), system = frame.system, systemIndex = frame.systemIndex,
                anchorInfo = {
                    point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOM",
                    offsetX = (left - half) * scale, offsetY = bottom * scale,
                },
            }
        end
    end
    return out
end

ResetEndCaps = function()
    local bar = ns.GetMainBar()
    local caps = bar and bar.EndCaps
    if not caps then return false end
    local changed = false
    for _, key in ipairs({ "LeftEndCap", "RightEndCap" }) do
        local cap = caps[key]
        if cap and not (active and CapMoved(key)) and cap.system and type(cap.IsInDefaultPosition) == "function" and type(cap.ResetToDefaultPosition) == "function" then
            local ok, isDefault = pcall(cap.IsInDefaultPosition, cap)
            if ok and not isDefault and pcall(cap.ResetToDefaultPosition, cap) then changed = true end
        end
    end
    return changed
end

local HAND_BACK = { "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
    "MultiBarLeft", "StanceBar", "PetActionBar", "PossessActionBar", "MainStatusTrackingBarContainer",
    "SecondaryStatusTrackingBarContainer", "BagsBar", "MicroMenuContainer" }

function ns.UnpinBandBars()
    if not ns.sessionEnding then return false end
    if InCombatLockdown() then return false end
    if not (ns.LayoutWritable and ns.LayoutWritable()) then return false end
    local mgr = EditModeManagerFrame
    if not mgr or not mgr.SaveLayouts then return false end
    local layoutName = ActiveLayoutName()
    local ours = ns.ClassicLayoutActive and ns.ClassicLayoutActive()
    local changed = false
    for _, name in ipairs(HAND_BACK) do
        local frame = _G[name]
        if frame and frame.system and type(frame.IsInDefaultPosition) == "function" and type(frame.ResetToDefaultPosition) == "function" then
            local ok, isDefault = pcall(frame.IsInDefaultPosition, frame)
            local info = frame.systemInfo and frame.systemInfo.anchorInfo
            if ok and not isDefault and (ours or PinnedByUs(frame, info)) and pcall(frame.ResetToDefaultPosition, frame) then changed = true end
        end
    end
    if ResetEndCaps() then changed = true end
    if layoutName and ns.db.barPins then ns.db.barPins[layoutName] = nil end
    ns.db.barDragged = false
    ns.db.bandHandedBack = true
    if changed then
        if mgr.UpdateActionBarPositions then pcall(mgr.UpdateActionBarPositions, mgr) end
        pcall(mgr.SaveLayouts, mgr)
    end
    return changed
end

function ns.AdoptBandBars()
    if not ns.sessionEnding then return false end
    if InCombatLockdown() or not active then return false end
    if not (ns.ClassicLayoutActive and ns.ClassicLayoutActive()) then return false end
    local count = 0
    for _, name in ipairs(PIN_NAMES) do
        local frame = _G[name]
        if frame and frame.system and type(frame.IsInDefaultPosition) == "function" and type(frame.ResetToDefaultPosition) == "function" then
            local ok, isDefault = pcall(frame.IsInDefaultPosition, frame)
            if ok and not isDefault and pcall(frame.ResetToDefaultPosition, frame) then count = count + 1 end
        end
    end
    ns.db.barDragged = false
    ns.ApplyAll()
    return count
end

function ns.ClassicBarInfo()
    if not art then return "not built" end
    return string.format("art shown=%s left=%.0f bottom=%.0f scale=%.2f pending=%s", tostring(art:IsShown()), art:GetLeft() or 0, art:GetBottom() or 0, art:GetScale(), tostring(pending))
end

ns.RegisterModule("classicBar", { init = Init, apply = Apply, restore = Restore })
