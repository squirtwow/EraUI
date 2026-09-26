-- EraUI character sheet.
-- The 1.x character sheet on Blizzard's character frame: the 384x512 window
-- in the old art, the portrait and name up top, sixteen slots down the sides
-- with the weapons underneath, the model in the middle with two rotate
-- buttons, the two stat boxes, the five resistances up the right edge, and
-- the tabs along the bottom.
local _, EraUI = ...
local ns = EraUI.Classic

local WIDTH, HEIGHT = 384, 512
local SLOT_GAP = 4
local LEFT_SLOTS = { "CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot", "CharacterBackSlot",
    "CharacterChestSlot", "CharacterShirtSlot", "CharacterTabardSlot", "CharacterWristSlot" }
local RIGHT_SLOTS = { "CharacterHandsSlot", "CharacterWaistSlot", "CharacterLegsSlot", "CharacterFeetSlot",
    "CharacterFinger0Slot", "CharacterFinger1Slot", "CharacterTrinket0Slot", "CharacterTrinket1Slot" }
local WEAPON_SLOTS = { "CharacterMainHandSlot", "CharacterSecondaryHandSlot", "CharacterRangedSlot" }
local STAT_NAMES = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }
local RESISTANCES = {
    { id = 6, coords = { 0, 1, 0.2265625, 0.33984375 } },
    { id = 2, coords = { 0, 1, 0, 0.11328125 } },
    { id = 3, coords = { 0, 1, 0.11328125, 0.2265625 } },
    { id = 4, coords = { 0, 1, 0.33984375, 0.453125 } },
    { id = 5, coords = { 0, 1, 0.453125, 0.56640625 } },
}
local BOX_TOP = { 0, 0.8984375, 0, 0.125 }
local BOX_MID = { 0, 0.8984375, 0.125, 0.1953125 }
local BOX_BOT = { 0, 0.8984375, 0.484375, 0.609375 }
local GREEN, RED, WHITE = "|cff20ff20", "|cffff2020", "|cffffffff"

local active = false
local HideSidePane
local built = false
local sheet = {}

local TAB_LABELS = {
    PaperDollFrame = CHARACTER or "Character", ReputationFrame = REPUTATION or "Reputation",
    TokenFrame = CURRENCY or "Currency", PVPRankFrame = "PvP", SkillsFrame = SKILLS or "Skills",
    StatisticsFrame = "Stats",
}

local function LevelLine()
    local level = UnitLevel("player")
    if issecretvalue and issecretvalue(level) then level = "" end
    local race = UnitRace("player") or ""
    local class = UnitClass("player") or ""
    return string.format("%s %s %s %s", LEVEL or "Level", tostring(level), race, class)
end

local function Number(value)
    if value == nil or (issecretvalue and issecretvalue(value)) then return 0 end
    return value
end

local RING_W, RING_H = 80, 73
local function RingPiece(parent, frame, key, lift)
    local holder = frame.PortraitContainer
    local over = CreateFrame("Frame", nil, parent)
    over:SetSize(RING_W, RING_H)
    over:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    over:SetFrameLevel((holder and holder:GetFrameLevel() or frame:GetFrameLevel()) + lift)
    local tex = over:CreateTexture(nil, "ARTWORK")
    ns.SetTex(tex, key)
    tex:SetAllPoints(over)
    tex:SetTexCoord(0, RING_W / 256, 0, RING_H / 256)
    return over
end
local function RingOver(frame, doll, only)
    local over = RingPiece(frame, frame, only or "charGeneralTopLeft", 1)
    if doll and not only then over.doll = RingPiece(doll, frame, "charTabTopLeft", 2) end
    return over
end

local function Piece(parent, key, w, h, x, y, layer, sub)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    ns.SetTex(tex, key)
    tex:SetSize(w, h)
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return tex
end

local function StatBox(parent, x, y, middleHeight)
    local top = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
    ns.SetTex(top, "charStatBox")
    top:SetSize(115, 16)
    top:SetTexCoord(unpack(BOX_TOP))
    top:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local middle = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
    ns.SetTex(middle, "charStatBox")
    middle:SetSize(115, middleHeight)
    middle:SetTexCoord(unpack(BOX_MID))
    middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    local bottom = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
    ns.SetTex(bottom, "charStatBox")
    bottom:SetSize(115, 16)
    bottom:SetTexCoord(unpack(BOX_BOT))
    bottom:SetPoint("TOPLEFT", middle, "BOTTOMLEFT", 0, 0)
    return bottom
end

local function StatRow(parent, label, anchor, relPoint, x, y)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(104, 13)
    row:SetPoint("TOPLEFT", anchor, relPoint, x, y)
    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.label:SetText(label)
    row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.value:SetJustifyH("RIGHT")
    row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tip, 1, 1, 1)
        if self.tip2 then GameTooltip:AddLine(self.tip2, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function Buffed(base, pos, neg)
    base, pos, neg = Number(base), Number(pos), Number(neg)
    local total = base + pos + neg
    if pos == 0 and neg == 0 then return WHITE .. total .. "|r", nil end
    local color = (pos > 0 and neg == 0) and GREEN or ((neg < 0 and pos == 0) and RED or WHITE)
    local detail = string.format("%d (%d base", total, base)
    if pos > 0 then detail = detail .. string.format(" %s+%d|r", GREEN, pos) end
    if neg < 0 then detail = detail .. string.format(" %s%d|r", RED, neg) end
    return color .. total .. "|r", detail .. ")"
end

function ns.SetClassicStatsShown(shown)
    if not sheet or not sheet.attrs then return end
    sheet.attrs:SetShown(shown and true or false)
end

local function UpdateStats()
    if not built or not active or not PaperDollFrame or not PaperDollFrame:IsShown() then return end
    if ns.UpdateStatPanes then ns.UpdateStatPanes() end
    local _, probe = UnitStat("player", 1)
    if issecretvalue and issecretvalue(probe) then return end
    for i, row in ipairs(sheet.attributes) do
        local _, effective, pos, neg = UnitStat("player", i)
        local text, detail = Buffed(Number(effective) - Number(pos) - Number(neg), pos, neg)
        row.value:SetText(text)
        row.tip = (_G["SPELL_STAT" .. i .. "_NAME"] or STAT_NAMES[i]) .. " " .. Number(effective)
        row.tip2 = detail
    end
    do
        local _, effective, _, pos, neg = UnitArmor("player")
        local text, detail = Buffed(Number(effective) - Number(pos) - Number(neg), pos, neg)
        sheet.armor.value:SetText(text)
        sheet.armor.tip = (ARMOR or "Armor") .. " " .. Number(effective)
        sheet.armor.tip2 = detail
    end
    if UnitAttackBothHands then
        local base, mod = UnitAttackBothHands("player")
        sheet.attack.value:SetText(Buffed(base, mod, 0))
    else
        sheet.attack.value:SetText("--")
    end
    do
        local base, pos, neg = UnitAttackPower("player")
        sheet.attackPower.value:SetText(Buffed(base, pos, neg))
    end
    do
        local minDamage, maxDamage = UnitDamage("player")
        minDamage, maxDamage = Number(minDamage), Number(maxDamage)
        sheet.damage.value:SetText(string.format("%d - %d", math.max(math.floor(minDamage), 1), math.max(math.ceil(maxDamage), 1)))
    end
    local hasRanged = CharacterRangedSlot and CharacterRangedSlot:IsShown() and GetInventoryItemID("player", CharacterRangedSlot:GetID()) ~= nil
    if not hasRanged then
        sheet.rangedAttack.value:SetText("--")
        sheet.rangedPower.value:SetText("--")
        sheet.rangedDamage.value:SetText("--")
    else
        if UnitRangedAttack then
            local base, mod = UnitRangedAttack("player")
            sheet.rangedAttack.value:SetText(Buffed(base, mod, 0))
        else
            sheet.rangedAttack.value:SetText("--")
        end
        local base, pos, neg = UnitRangedAttackPower("player")
        sheet.rangedPower.value:SetText(Buffed(base, pos, neg))
        local _, minDamage, maxDamage = UnitRangedDamage("player")
        minDamage, maxDamage = Number(minDamage), Number(maxDamage)
        if maxDamage > 0 then
            sheet.rangedDamage.value:SetText(string.format("%d - %d", math.max(math.floor(minDamage), 1), math.max(math.ceil(maxDamage), 1)))
        else
            sheet.rangedDamage.value:SetText("--")
        end
    end
    if ns.OnForever() then
        for _, res in ipairs(sheet.resistances) do
            if UnitResistance then
                local _, total = UnitResistance("player", res.id)
                res.value:SetText(Number(total))
            else
                res.value:SetText("0")
            end
        end
    end
end

local MODEL_ZOOM_STEPS = 3
local function FitModelCamera()
    local scene = CharacterModelScene
    local camera = scene and scene.GetActiveCamera and scene:GetActiveCamera()
    if not camera or camera.fcuiFitted then return end
    camera.fcuiFitted = true
    if type(scene.OnMouseWheel) == "function" then
        for _ = 1, MODEL_ZOOM_STEPS do pcall(scene.OnMouseWheel, scene, -1) end
    end
end

local spinner = CreateFrame("Frame")
spinner:Hide()
local function SheetActor(scene)
    local actor
    if scene.GetPlayerActor then actor = scene:GetPlayerActor() end
    if not actor and scene.GetActorByTag then actor = scene:GetActorByTag("player") end
    if not actor and type(scene.tagToActor) == "table" then
        actor = select(2, next(scene.tagToActor))
    end
    if actor and actor.GetYaw and actor.SetYaw then return actor end
end

spinner:SetScript("OnUpdate", function(self, elapsed)
    local scene = CharacterModelScene
    if not scene or not scene:IsVisible() then self:Hide() return end
    local step = self.turn * math.pi * elapsed
    local actor = SheetActor(scene)
    if actor then
        actor:SetYaw((actor:GetYaw() or 0) + step)
        return
    end
    local camera = scene.GetActiveCamera and scene:GetActiveCamera()
    if camera and camera.GetYaw and camera.SetYaw then
        camera:SetYaw((camera:GetYaw() or 0) - step)
        if camera.SnapToTargetInterpolationYaw then camera:SnapToTargetInterpolationYaw() end
    else
        self:Hide()
    end
end)

local function RotateStart(direction)
    spinner.turn = direction == "left" and -1 or 1
    spinner:Show()
end

local function RotateStop()
    spinner:Hide()
end

local function RotateButton(parent, artKey, direction, anchor, relPoint)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(35, 35)
    button:SetPoint("TOPLEFT", anchor, relPoint, 0, 0)
    button:SetNormalTexture((ns.TexPath(artKey .. "Up")))
    button:SetPushedTexture((ns.TexPath(artKey .. "Down")))
    button:SetHighlightTexture((ns.TexPath("roundHighlight")))
    button:GetHighlightTexture():SetBlendMode("ADD")
    button:RegisterForClicks("AnyDown", "AnyUp")
    if CharacterModelScene then button:SetFrameLevel(CharacterModelScene:GetFrameLevel() + 10) end
    button:SetScript("OnMouseDown", function()
        RotateStart(direction)
        PlaySound(SOUNDKIT.IG_INVENTORY_ROTATE_CHARACTER)
    end)
    button:SetScript("OnMouseUp", RotateStop)
    button:SetScript("OnHide", RotateStop)
    return button
end

local function Build()
    built = true
    local frame, doll = CharacterFrame, PaperDollFrame

    sheet.general = {
        Piece(frame, "charGeneralTopLeft", 256, 256, 0, 0, "BACKGROUND", -2),
        Piece(frame, "charGeneralTopRight", 128, 256, 256, 0, "BACKGROUND", -2),
        Piece(frame, "charGeneralBotLeft", 256, 256, 0, -256, "BACKGROUND", -2),
        Piece(frame, "charGeneralBotRight", 128, 256, 256, -256, "BACKGROUND", -2),
    }
    sheet.doll = {
        Piece(doll, "charTabTopLeft", 256, 256, 0, 0, "BACKGROUND", -1),
        Piece(doll, "charTabTopRight", 128, 256, 256, 0, "BACKGROUND", -1),
        Piece(doll, "charTabBotLeft", 256, 256, 0, -256, "BACKGROUND", -1),
        Piece(doll, "charTabBotRight", 128, 256, 256, -256, "BACKGROUND", -1),
    }
    sheet.ringOver = RingOver(frame, doll)

    local attrs = CreateFrame("Frame", nil, doll)
    attrs:SetSize(230, 78)
    attrs:SetPoint("TOPLEFT", doll, "TOPLEFT", 67, -291)
    StatBox(attrs, 0, 0, 53)
    local meleeBottom = StatBox(attrs, 115, 0, 12)
    StatBox(attrs, 115, -46, 11)
    sheet.attrs = attrs
    sheet.attributes = {}
    local prev
    for i = 1, 5 do
        local label = _G["SPELL_STAT" .. i .. "_NAME"] or STAT_NAMES[i]
        local row = StatRow(attrs, label, prev or attrs, prev and "BOTTOMLEFT" or "TOPLEFT", prev and 0 or 6, prev and 0 or -3)
        sheet.attributes[i] = row
        prev = row
    end
    sheet.armor = StatRow(attrs, ARMOR or "Armor", prev, "BOTTOMLEFT", 0, 0)
    sheet.attack = StatRow(attrs, MELEE_ATTACK or "Melee Attack", attrs, "TOPLEFT", 122, -2)
    sheet.attackPower = StatRow(attrs, ATTACK_POWER or "Power", sheet.attack, "BOTTOMLEFT", 5, 1)
    sheet.damage = StatRow(attrs, DAMAGE or "Damage", sheet.attackPower, "BOTTOMLEFT", 0, 1)
    sheet.rangedAttack = StatRow(attrs, RANGED_ATTACK or "Ranged Attack", sheet.damage, "BOTTOMLEFT", -5, -6)
    sheet.rangedPower = StatRow(attrs, ATTACK_POWER or "Power", sheet.rangedAttack, "BOTTOMLEFT", 5, 1)
    sheet.rangedDamage = StatRow(attrs, DAMAGE or "Damage", sheet.rangedPower, "BOTTOMLEFT", 0, 1)
    sheet.attack.tip = MELEE_ATTACK or "Melee Attack"
    sheet.attackPower.tip = MELEE_ATTACK_POWER or "Attack Power"
    sheet.damage.tip = DAMAGE or "Damage"
    sheet.rangedAttack.tip = RANGED_ATTACK or "Ranged Attack"
    sheet.rangedPower.tip = RANGED_ATTACK_POWER or "Ranged Attack Power"
    sheet.rangedDamage.tip = DAMAGE or "Damage"
    meleeBottom:SetPoint("TOPLEFT", attrs, "TOPLEFT", 115, -28)

    local resFrame = CreateFrame("Frame", nil, doll)
    resFrame:SetSize(32, 160)
    resFrame:SetPoint("TOPRIGHT", doll, "TOPLEFT", 297, -77)
    resFrame:SetShown(ns.OnForever())
    sheet.resistances = {}
    prev = nil
    for i, res in ipairs(RESISTANCES) do
        local row = CreateFrame("Frame", nil, resFrame)
        row:SetSize(32, 29)
        row:SetPoint("TOP", prev or resFrame, prev and "BOTTOM" or "TOP", 0, 0)
        local icon = row:CreateTexture(nil, "BACKGROUND")
        ns.SetTex(icon, "charResistIcons")
        icon:SetAllPoints(row)
        icon:SetTexCoord(unpack(res.coords))
        row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.value:SetPoint("BOTTOM", row, "BOTTOM", 0, 3)
        row.id = res.id
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local name = _G["DAMAGE_SCHOOL" .. (self.id + 1)] or _G["RESISTANCE" .. self.id .. "_NAME"] or ("Resistance " .. self.id)
            GameTooltip:SetText(name .. " " .. (RESISTANCE or "Resistance"), 1, 1, 1)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        sheet.resistances[i] = row
        prev = row
    end

    if CharacterModelScene then
        sheet.rotateRight = RotateButton(doll, "rotateLeft", "left", CharacterModelScene, "TOPLEFT")
        sheet.rotateLeft = RotateButton(doll, "rotateRight", "right", sheet.rotateRight, "TOPRIGHT")
    end

    local watcher = CreateFrame("Frame")
    for _, event in ipairs({ "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_DAMAGE", "UNIT_ATTACK_SPEED",
        "UNIT_RESISTANCES", "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "UNIT_LEVEL", "COMBAT_RATING_UPDATE", "UNIT_AURA" }) do
        pcall(watcher.RegisterEvent, watcher, event)
    end
    watcher:SetScript("OnEvent", function(_, event, unit)
        if unit == nil or unit == "player" then UpdateStats() end
        -- The level line and the fade over the client's level text were only
        -- applied when the sheet was laid out, so dinging with the sheet open
        -- left the old level showing.
        if event == "UNIT_LEVEL" or event == "PLAYER_LEVEL_UP" then
            if sheet.level and sheet.level:IsShown() then sheet.level:SetText(LevelLine()) end
            if CharacterLevelText then ns.Fade(CharacterLevelText) end
        end
    end)
    doll:HookScript("OnShow", function() if active then UpdateStats() end end)
end

local function Fade(region)
    if region then ns.Fade(region) end
end

local TAB_MAX_WIDTH = 106
local function TabPieces(tab, active)
    local key = active and "tabActive" or "tabInactive"
    local h = active and 35 or 32
    local bottom = active and 0.546875 or 1
    for _, pair in ipairs({ { tab.left, tab.glowLeft, 0, 0.15625 }, { tab.middle, tab.glowMiddle, 0.15625, 0.84375 }, { tab.right, tab.glowRight, 0.84375, 1 } }) do
        local tex, glow, l, r = pair[1], pair[2], pair[3], pair[4]
        ns.SetTex(tex, key)
        tex:SetTexCoord(l, r, 0, bottom)
        if glow then
            ns.SetTex(glow, key)
            glow:SetTexCoord(l, r, 0, bottom)
        end
    end
    tab.left:SetSize(20, h)
    tab.right:SetSize(20, h)
end

local function ClassicTab(parent, index)
    local tab = CreateFrame("Button", "EraUIClassicCharacterTab" .. index, parent)
    tab:SetHeight(32)
    tab.left = tab:CreateTexture(nil, "BACKGROUND")
    tab.left:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    tab.right = tab:CreateTexture(nil, "BACKGROUND")
    tab.right:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 0, 0)
    tab.middle = tab:CreateTexture(nil, "BACKGROUND")
    tab.middle:SetPoint("TOPLEFT", tab.left, "TOPRIGHT", 0, 0)
    tab.middle:SetPoint("BOTTOMRIGHT", tab.right, "BOTTOMLEFT", 0, 0)
    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.text:SetPoint("CENTER", tab, "CENTER", 0, -3)
    tab.text:SetWordWrap(false)
    tab.text:SetJustifyH("CENTER")
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        local base = tab[key:lower()]
        local glow = tab:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints(base)
        glow:SetBlendMode("ADD")
        glow:SetAlpha(0.35)
        tab["glow" .. key] = glow
    end
    function tab:SetLabel(text)
        self.text:SetWidth(0)
        self.text:SetText(text)
        local width = math.min(TAB_MAX_WIDTH, math.ceil(self.text:GetStringWidth()) + 30)
        self:SetWidth(width)
        self.text:SetWidth(width - 20)
    end
    function tab:SetSelected(selected)
        TabPieces(self, selected)
        self.text:SetFontObject(selected and "GameFontHighlightSmall" or "GameFontNormalSmall")
    end
    TabPieces(tab, false)
    return tab
end

local function OverTab(tab)
    local mode = tab and tab.mode
    if not mode or not mode.SetAllPoints then return end
    local _, relativeTo = mode:GetPoint(1)
    if relativeTo ~= tab or mode:GetNumPoints() ~= 2 then
        mode:ClearAllPoints()
        mode:SetAllPoints(tab)
    end
    if mode:GetFrameLevel() <= tab:GetFrameLevel() then mode:SetFrameLevel(tab:GetFrameLevel() + 2) end
    if mode.SetHitRectInsets then mode:SetHitRectInsets(0, 0, 0, 0) end
    if not mode:IsMouseEnabled() then mode:EnableMouse(true) end
end

local dressed = setmetatable({}, { __mode = "k" })

local ART_RIGHT_EDGE, ART_LEFT_EDGE = 349, 3
function ns.SheetArtEdges() return ART_RIGHT_EDGE, ART_LEFT_EDGE end

function EraUIClassic_CharacterSheetSize()
    local extra = ns.EquipmentPaneExtent and ns.EquipmentPaneExtent() or 0
    return WIDTH, HEIGHT, ART_RIGHT_EDGE + extra, ART_LEFT_EDGE
end

function EraUIClassic_SkinCharacterCopy(frame)
    if not frame then return false end
    if not dressed[frame] then
        dressed[frame] = {
            Piece(frame, "charGeneralTopLeft", 256, 256, 0, 0, "BACKGROUND", -2),
            Piece(frame, "charGeneralTopRight", 128, 256, 256, 0, "BACKGROUND", -2),
            Piece(frame, "charGeneralBotLeft", 256, 256, 0, -256, "BACKGROUND", -2),
            Piece(frame, "charGeneralBotRight", 128, 256, 256, -256, "BACKGROUND", -2),
            Piece(frame, "charTabTopLeft", 256, 256, 0, 0, "BACKGROUND", -1),
            Piece(frame, "charTabTopRight", 128, 256, 256, 0, "BACKGROUND", -1),
            Piece(frame, "charTabBotLeft", 256, 256, 0, -256, "BACKGROUND", -1),
            Piece(frame, "charTabBotRight", 128, 256, 256, -256, "BACKGROUND", -1),
        }
        dressed[frame].ringOver = RingOver(frame, nil, "charTabTopLeft")
    end
    for _, tex in ipairs(dressed[frame]) do tex:SetShown(active) end
    dressed[frame].ringOver:SetShown(active)
    return active
end

local function LayoutNow()
    if not active or not built then return end
    local frame, doll = CharacterFrame, PaperDollFrame
    frame:SetSize(WIDTH, HEIGHT)
    Fade(frame.NineSlice)
    Fade(frame.Bg)
    Fade(frame.TopTileStreaks)
    Fade(frame.Inset)
    Fade(frame.InsetRight)
    for _, key in ipairs({ "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight", "BackgroundOverlay" }) do
        Fade(doll[key])
        if CharacterModelScene then Fade(CharacterModelScene[key]) end
    end
    local controls = CharacterModelScene and CharacterModelScene.ControlFrame
    if controls then
        Fade(controls)
        controls:Hide()
        controls:EnableMouse(false)
        if not controls.fcuiHooked then
            controls.fcuiHooked = true
            controls:HookScript("OnShow", function(self) if active then self:Hide() end end)
        end
    end
    local pane = frame.LeftPaneHost
    if pane then
        pane:ClearAllPoints()
        pane:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -60)
        pane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 82)
        for _, region in ipairs({ pane:GetRegions() }) do
            if region:IsObjectType("Texture") then region:SetAlpha(0) end
        end
    end
    Fade(frame.RightPaneHost)
    if frame.RightPaneToggleButton then
        Fade(frame.RightPaneToggleButton)
        frame.RightPaneToggleButton:EnableMouse(false)
    end
    if frame.ModeTabs then
        Fade(frame.ModeTabs)
        frame.ModeTabs:EnableMouse(false)
    end

    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    if portrait then
        portrait:SetSize(62, 62)
        portrait:ClearAllPoints()
        portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 9, -6)
        if ns.WatchPortrait then ns.WatchPortrait(portrait) end
    end
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    if title then
        title:ClearAllPoints()
        title:SetPoint("CENTER", frame, "TOP", 6, -24)
        title:SetFontObject("GameFontNormal")
    end
    if title then
        if not sheet.level then
            sheet.level = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        end
        sheet.level:ClearAllPoints()
        sheet.level:SetPoint("TOP", title, "BOTTOM", 0, -6)
        sheet.level:SetText(LevelLine())
        sheet.level:Show()
        if CharacterLevelText then Fade(CharacterLevelText) end
    end
    local close = frame.CloseButton
    if close then
        close:ClearAllPoints()
        close:SetPoint("CENTER", frame, "TOPRIGHT", -44, -25)
        if ns.SkinCloseButton then ns.SkinCloseButton(close, true) end
    end

    local function Column(names, x)
        local prev
        for _, name in ipairs(names) do
            local slot = _G[name]
            if slot then
                slot:ClearAllPoints()
                if prev then
                    slot:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -SLOT_GAP)
                else
                    slot:SetPoint("TOPLEFT", doll, "TOPLEFT", x, -74)
                end
                Fade(_G[name .. "Frame"])
                Fade(slot.BorderFrame)
                prev = slot
            end
        end
    end
    Column(LEFT_SLOTS, 21)
    Column(RIGHT_SLOTS, 306)
    local prev
    for _, name in ipairs(WEAPON_SLOTS) do
        local slot = _G[name]
        if slot then
            slot:ClearAllPoints()
            if prev then
                slot:SetPoint("TOPLEFT", prev, "TOPRIGHT", 5, 0)
            else
                slot:SetPoint("TOPLEFT", doll, "BOTTOMLEFT", 122, 127)
            end
            Fade(_G[name .. "Frame"])
            Fade(slot.BorderFrame)
            prev = slot
        end
    end
    local ammo = _G["CharacterAmmoSlot"]
    if ammo then
        Fade(_G["CharacterAmmoSlotFrame"])
        Fade(ammo.BorderFrame)
        local function FadeGearArt(frame)
            for _, region in ipairs({ frame:GetRegions() }) do
                if region:IsObjectType("Texture") then
                    local atlas = region.GetAtlas and region:GetAtlas()
                    if atlas and atlas:lower():find("gearslot", 1, true) then region:SetAlpha(0) end
                end
            end
        end
        FadeGearArt(ammo)
        for _, child in ipairs({ ammo:GetChildren() }) do FadeGearArt(child) end
    end

    if CharacterModelScene then
        CharacterModelScene:ClearAllPoints()
        CharacterModelScene:SetPoint("TOPLEFT", doll, "TOPLEFT", 65, -78)
        CharacterModelScene:SetSize(233, (ns.db and ns.db.statPanes) and 213 or 224)
        FitModelCamera()
    end

    local strip = sheet.general[3]
    local tabPrev
    local function PlaceTab(tab)
        tab:ClearAllPoints()
        if tabPrev then
            tab:SetPoint("LEFT", tabPrev, "RIGHT", -15, 0)
        else
            tab:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 14, 46)
        end
        tabPrev = tab
    end
    if frame.ModeTabs and frame.ModeTabs.Tabs then
        sheet.tabs = sheet.tabs or {}
        for i, mode in ipairs(frame.ModeTabs.Tabs) do
            local tab = sheet.tabs[i]
            if not tab then
                tab = ClassicTab(frame, i)
                tab:EnableMouse(false)
                sheet.tabs[i] = tab
                if mode.HookScript then
                    mode:HookScript("OnEnter", function(self)
                        tab:LockHighlight()
                        if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
                    end)
                    mode:HookScript("OnLeave", function() tab:UnlockHighlight() end)
                end
            end
            tab.mode = mode
            tab.frameName = mode.frameName
            tab:SetLabel(TAB_LABELS[mode.frameName or ""] or mode.frameName or "")
            tab:SetSelected(mode.frameName == frame.activeSubframe)
            tab:SetShown(mode:IsShown())
            if mode:IsShown() then PlaceTab(tab) end
            OverTab(tab)
        end
    else
        for i = 1, 6 do
            local tab = _G["CharacterFrameTab" .. i]
            if tab and tab:IsShown() then
                if ns.SkinBottomTab then ns.SkinBottomTab(tab) end
                PlaceTab(tab)
            end
        end
    end
    UpdateStats()
    if ns.StatPanesHost then ns.StatPanesHost(doll) end
    if ns.UpdateStatPanes then ns.UpdateStatPanes() end
    if frame:IsShown() and EventRegistry and EventRegistry.TriggerEvent then EventRegistry:TriggerEvent("EraUIClassic.CharacterSheetLaid") end
end

local laying = false
local function Layout()
    if laying then return end
    laying = true
    ns.SafeCall(LayoutNow)
    laying = false
end

local PLATE_L = { 0, 1, 0, 0.328125 }
local PLATE_R = { 0, 0.0625, 0.34375, 0.671875 }
local BAR_W, BAR_H = 137, 13

local function FadeAtlas(frame, needle)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then
            local atlas = region.GetAtlas and region:GetAtlas()
            if atlas and atlas:lower():find(needle, 1, true) then region:SetAlpha(0) end
        end
    end
end

local SKILL_BLUE = { 0, 0, 0.5 }
local SKILL_COORDS, REP_COORDS = { 0, 1, 0, 0.5 }, { 0, 1, 0, 1 }
local SKILL_LIST_SCALE = 20 / 33
local REP_LIST_SCALE = 0.76

local function SkinListEntry(row, barKey)
    local content = row.Content
    local bar = content and barKey and content[barKey]
    if not bar then return end
    local skills = barKey == "SkillsBar"
    if content.SetScale then content:SetScale(1 / (skills and SKILL_LIST_SCALE or REP_LIST_SCALE)) end
    if not skills and not row.fcuiRepClick and row.HookScript then
        row.fcuiRepClick = true
        row:HookScript("OnClick", function(self) if ns.ReputationRowClicked then ns.ReputationRowClicked(self) end end)
    end
    FadeAtlas(bar, "stat-bar-bg")
    if content.BackgroundHighlight then
        for _, region in ipairs({ content.BackgroundHighlight:GetRegions() }) do region:SetAlpha(0) end
    end
    if content.AccountWideIcon then content.AccountWideIcon:SetAlpha(0) end
    bar:ClearAllPoints()
    if skills then
        bar:SetPoint("LEFT", row, "LEFT", 20, 0)
        bar:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        bar:SetHeight(15)
    else
        bar:SetSize(BAR_W, BAR_H)
        bar:SetPoint("LEFT", row, "LEFT", 130, 0)
    end
    local fill = bar.Fill
    if fill then
        if bar.Mask and fill.RemoveMaskTexture then pcall(fill.RemoveMaskTexture, fill, bar.Mask) end
        ns.SetTex(fill, "skillsBar")
        fill:SetDrawLayer("BACKGROUND", 0)
        fill:ClearAllPoints()
        if skills then
            fill:SetHeight(15)
            fill:SetPoint("LEFT", bar, "LEFT", 0, 0)
        else
            fill:SetHeight(BAR_H - 2)
            fill:SetPoint("LEFT", bar, "LEFT", 1, 0)
        end
        bar.fcuiInset = skills and 0 or 2
        bar.fcuiCoords = skills and SKILL_COORDS or REP_COORDS
        if not bar.fcuiFill then
            bar.fcuiFill = true
            hooksecurefunc(bar, "SetFillWidth", function(self, width)
                self.Fill:SetWidth(math.max(0, math.min(width, self:GetWidth() - (self.fcuiInset or 0))))
            end)
            hooksecurefunc(bar, "SetFillTextureByColorType", function(self)
                ns.SetTex(self.Fill, "skillsBar")
                self.Fill:SetTexCoord(unpack(self.fcuiCoords))
            end)
            if bar.SetFillPercent then
                hooksecurefunc(bar, "SetFillPercent", function(self) self.Fill:SetTexCoord(unpack(self.fcuiCoords)) end)
            end
            if skills and bar.UpdateBarColor then
                hooksecurefunc(bar, "UpdateBarColor", function(self) self.Fill:SetVertexColor(SKILL_BLUE[1], SKILL_BLUE[2], SKILL_BLUE[3]) end)
            end
            if skills and bar.SetText then
                hooksecurefunc(bar, "SetText", function(self, text)
                    if type(text) == "string" and text:find(" / ", 1, true) then self.Text:SetText((text:gsub(" / ", "/"))) end
                end)
            end
        end
        fill:SetTexCoord(unpack(bar.fcuiCoords))
        if skills then fill:SetVertexColor(SKILL_BLUE[1], SKILL_BLUE[2], SKILL_BLUE[3]) end
        fill:SetWidth(math.max(0, math.min(fill:GetWidth(), bar:GetWidth() - bar.fcuiInset)))
    end
    local name = ns.OwnFontString(bar, "name", "OVERLAY", skills and "GameFontNormalSmall" or "GameFontHighlightSmall")
    name:SetFontObject(skills and "GameFontNormalSmall" or "GameFontHighlightSmall")
    name:SetText(content.Name and content.Name:GetText() or "")
    name:SetWordWrap(false)
    name:SetJustifyH("LEFT")
    name:ClearAllPoints()
    if content.Name then content.Name:SetAlpha(0) end
    if skills then
        name:SetPoint("LEFT", bar, "LEFT", 6, 1)
        name:SetWidth(0)
        local border = ns.OwnTexture(bar, "border", "BORDER", 0)
        ns.SetTex(border, "skillsBarBorder")
        border:SetTexCoord(0, 1, 0, 1)
        border:ClearAllPoints()
        border:SetPoint("LEFT", bar, "LEFT", -5, 0)
        border:SetPoint("RIGHT", bar, "RIGHT", 5, 0)
        border:SetHeight(32)
        border:Show()
        if bar.Text then
            bar.Text:SetFontObject("GameFontHighlightSmall")
            bar.Text:ClearAllPoints()
            bar.Text:SetPoint("LEFT", name, "RIGHT", 10, -1)
            bar.Text:SetWidth(128)
            bar.Text:SetJustifyH("LEFT")
            local text = bar.Text:GetText()
            if type(text) == "string" and text:find(" / ", 1, true) then bar.Text:SetText((text:gsub(" / ", "/"))) end
        end
    else
        name:SetPoint("LEFT", bar, "LEFT", -119, 0)
        name:SetWidth(104)
        if bar.Text then bar.Text:SetFontObject("GameFontHighlightSmall") end
        local left = ns.OwnTexture(bar, "plateLeft", "BORDER", 0)
        ns.SetTex(left, "repPlate")
        left:SetTexCoord(unpack(PLATE_L))
        left:SetSize(256, 21)
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", bar, "TOPLEFT", -126, 4)
        local right = ns.OwnTexture(bar, "plateRight", "BORDER", 0)
        ns.SetTex(right, "repPlate")
        right:SetTexCoord(unpack(PLATE_R))
        right:SetSize(16, 21)
        right:ClearAllPoints()
        right:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
        left:Show()
        right:Show()
        if content.fcui then
            if content.fcui.plateLeft then content.fcui.plateLeft:Hide() end
            if content.fcui.plateRight then content.fcui.plateRight:Hide() end
        end
    end
    local toggle = row.ToggleCollapseButton
    if toggle then
        if toggle:GetParent() == row then toggle:SetScale(1 / (skills and SKILL_LIST_SCALE or REP_LIST_SCALE)) end
        toggle:SetSize(16, 16)
        toggle:ClearAllPoints()
        if skills then
            toggle:SetPoint("RIGHT", bar, "LEFT", -2, 0)
        else
            toggle:SetPoint("RIGHT", bar, "LEFT", -122, 0)
        end
        toggle:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
        toggle:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
        for _, tex in ipairs({ toggle:GetNormalTexture(), toggle:GetPushedTexture() }) do
            if tex then tex:SetTexCoord(0, 1, 0, 1) tex:SetAllPoints(toggle) end
        end
    end
end

local function SkinSkillHeader(row, scale, font)
    FadeAtlas(row, "collapseexpand")
    if row.StateIcon then row.StateIcon:SetAlpha(0) end
    if row.fcui and row.fcui.collapseIcon then row.fcui.collapseIcon:Hide() end
    local holder = row.fcuiHolder
    if not holder then
        holder = CreateFrame("Frame", nil, row)
        holder:SetAllPoints(row)
        row.fcuiHolder = holder
    end
    holder:SetScale(1 / (scale or SKILL_LIST_SCALE))
    local name = ns.OwnFontString(holder, "name", "OVERLAY", font or "GameFontHighlight")
    name:SetFontObject(font or "GameFontHighlight")
    name:SetText(row.Name and row.Name:GetText() or "")
    name:ClearAllPoints()
    name:SetPoint("LEFT", holder, "LEFT", 26, 0)
    if row.Name then row.Name:SetAlpha(0) end
    local icon = ns.OwnTexture(holder, "collapseIcon", "ARTWORK")
    local collapsed = row.IsCollapsed and row:IsCollapsed()
    icon:SetTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
    icon:SetSize(16, 16)
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", holder, "LEFT", 7, 0)
    icon:Show()
end

local function SkinRepHeader(row, barKey)
    if barKey == "SkillsBar" then return SkinSkillHeader(row) end
    if barKey == "ReputationBar" then return SkinSkillHeader(row, REP_LIST_SCALE, "GameFontNormal") end
    FadeAtlas(row, "collapseexpand")
    if row.Name then
        row.Name:SetFontObject(barKey == "SkillsBar" and "GameFontHighlight" or "GameFontNormal")
        row.Name:ClearAllPoints()
        row.Name:SetPoint("LEFT", row, "LEFT", 26, 0)
    end
    if row.StateIcon then row.StateIcon:SetAlpha(0) end
    local icon = ns.OwnTexture(row, "collapseIcon", "ARTWORK")
    local collapsed = row.IsCollapsed and row:IsCollapsed()
    icon:SetTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
    icon:SetSize(16, 16)
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", row, "LEFT", 7, 0)
    icon:Show()
end

local function SkinListRow(row, barKey)
    if not active then return end
    if row.GetElementData and row:GetElementData() == nil then return end
    if row.Content then SkinListEntry(row, barKey) else SkinRepHeader(row, barKey) end
end

local function SkinRepScrollBar(bar)
    if not bar or bar.fcuiSkinned then return end
    bar.fcuiSkinned = true
    bar.fcuiTrackArt = true
    local top = ns.OwnTexture(bar, "trackTop", "BACKGROUND", 0)
    ns.SetTex(top, "charScrollBar")
    top:SetTexCoord(0, 0.484375, 0, 1)
    top:SetSize(31, 256)
    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", bar, "TOPLEFT", -8, 9)
    top:Show()
    local function FitTop()
        local tall = math.max(1, math.min(256, (bar:GetHeight() or 256) + 17 - 108))
        top:SetHeight(tall)
        top:SetTexCoord(0, 0.484375, 0, tall / 256)
    end
    bar:HookScript("OnSizeChanged", FitTop)
    FitTop()
    local bottom = ns.OwnTexture(bar, "trackBottom", "BACKGROUND", 1)
    ns.SetTex(bottom, "charScrollBar")
    bottom:SetTexCoord(0.515625, 1, 0, 0.421875)
    bottom:SetSize(31, 108)
    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -8, -8)
    bottom:Show()
    local track = bar.Track
    if track then
        for _, key in ipairs({ "Begin", "Middle", "End" }) do
            if track[key] then track[key]:SetAlpha(0) end
        end
        if track.Thumb then track.Thumb:SetWidth(16) end
        bar.fcuiKnobReach = 7
        ns.ClassicKnob(bar)
    end
    local function Arrow(button, kind)
        if not button then return end
        if button.Texture then button.Texture:SetAlpha(0) end
        button:SetSize(16, 16)
        local tex = ns.OwnTexture(button, "arrow", "ARTWORK")
        ns.SetTex(tex, "scroll" .. kind .. "ButtonUp")
        tex:SetTexCoord(0.25, 0.75, 0.25, 0.75)
        tex:SetAllPoints(button)
        tex:Show()
        for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
            local getter = button["Get" .. state .. "Texture"]
            local own = getter and getter(button)
            if own then own:SetAlpha(0) end
        end
        for _, region in ipairs({ button:GetRegions() }) do
            if region:IsObjectType("Texture") and region ~= tex then region:SetAlpha(0) end
        end
    end
    Arrow(bar.Back, "Up")
    Arrow(bar.Forward, "Down")
    if bar.Back then
        bar.Back:ClearAllPoints()
        bar.Back:SetPoint("TOP", bar, "TOP", 3, 4)
    end
    if bar.Forward then
        bar.Forward:ClearAllPoints()
        bar.Forward:SetPoint("BOTTOM", bar, "BOTTOM", 3, -4)
    end
end

local listHooked = setmetatable({}, { __mode = "k" })

local function SelectedSkill()
    if not (C_SkillInfo and C_SkillInfo.GetSelectedSkill and C_SkillInfo.GetSkillLineInfo) then return nil end
    local ok, index = pcall(C_SkillInfo.GetSelectedSkill)
    if not ok or not index or index <= 0 then return nil end
    local fine, info = pcall(C_SkillInfo.GetSkillLineInfo, index)
    if not fine or type(info) ~= "table" or info.isHeader then return nil end
    return info
end

StaticPopupDialogs["ERAUI_BASE_UNLEARN_SKILL"] = {
    text = UNLEARN_SKILL_PROMPT or "Unlearn %s?",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(_, skillID)
        if C_SkillInfo and C_SkillInfo.AbandonSkill and skillID then pcall(C_SkillInfo.AbandonSkill, skillID) end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = 1,
}

local DETAIL_H = 124
local FOOT_H = 26
local SCROLL_COLUMN = 22
local function SkinSkillDetail()
    local skills = SkillsFrame
    local detail = skills and skills.SkillDetailFrame
    if not detail or not CharacterFrame then return end
    local onSkills = skills:IsShown() and true or false
    detail:SetParent(CharacterFrame)
    detail:ClearAllPoints()
    detail:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMLEFT", 20, 84)
    detail:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -44, 84)
    detail:SetHeight(DETAIL_H + 2)
    detail:SetFrameLevel(CharacterFrame:GetFrameLevel() + 6)
    detail:SetClipsChildren(true)

    local backing = ns.OwnTexture(detail, "backing", "BACKGROUND")
    backing:SetAllPoints(detail)
    backing:Hide()

    local divider = detail.fcuiDivider
    if not divider and ns.StoneBar then
        divider = ns.StoneBar(CharacterFrame)
        detail.fcuiDivider = divider
    end
    if divider then
        divider:ClearAllPoints()
        divider:SetPoint("BOTTOM", detail, "TOP", 0, 6)
        divider:SetPoint("LEFT", detail, "LEFT", -2, 0)
        divider:SetPoint("RIGHT", detail, "RIGHT", -SCROLL_COLUMN - 2, 0)
        divider:SetShown(onSkills)
        if not divider.fcuiFollows then
            divider.fcuiFollows = true
            detail:HookScript("OnHide", function() divider:Hide() end)
        end
    end

    if detail.Title then detail.Title:SetAlpha(0) end
    if detail.Subtitle then detail.Subtitle:SetAlpha(0) end

    local info = SelectedSkill()
    if detail.RankBar then
        local host = detail.fcuiBarHost
        if not host then
            host = CreateFrame("Frame", nil, detail)
            host.Content = { SkillsBar = detail.RankBar }
            detail.fcuiBarHost = host
        end
        SkinListEntry(host, "SkillsBar")
        local name = detail.RankBar.fcui and detail.RankBar.fcui.name
        if name then name:SetText(info and info.name or "") end
        detail.RankBar:ClearAllPoints()
        detail.RankBar:SetPoint("TOPLEFT", detail, "TOPLEFT", 46, -12)
        detail.RankBar:SetPoint("RIGHT", detail, "RIGHT", -70, 0)
    end

    local box = ns.OwnTexture(detail, "descBox", "BACKGROUND", 1)
    box:SetColorTexture(0, 0, 0, 0)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", detail, "TOPLEFT", 2, -38)
    box:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -SCROLL_COLUMN, FOOT_H + 2)
    box:Hide()
    if detail.Description then
        detail.Description:ClearAllPoints()
        detail.Description:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -4)
        detail.Description:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 4)
        pcall(detail.Description.SetFontObject, detail.Description, "GameFontHighlightSmall")
        local scroll = detail.Description.ScrollBox
        local holder = scroll and scroll.FontStringContainer
        local words = holder and holder.FontString
        if words then
            local width = (CharacterFrame:GetWidth() or 384) - 20 - 44 - 2 - SCROLL_COLUMN - 12
            words:SetWidth(width)
            holder:SetWidth(width)
            local tall = words:GetStringHeight()
            if tall and tall > 0 then holder:SetHeight(tall) end
            if scroll.FullUpdate then pcall(scroll.FullUpdate, scroll, ScrollBoxConstants and ScrollBoxConstants.UpdateImmediately) end
        end
    end
    local column = detail.fcuiColumn
    if not column then
        column = CreateFrame("Frame", nil, CharacterFrame)
        column:SetWidth(31)
        local top = column:CreateTexture(nil, "BACKGROUND", nil, 1)
        ns.SetTex(top, "charScrollBar")
        top:SetPoint("TOPLEFT", column, "TOPLEFT", 0, 0)
        top:SetPoint("TOPRIGHT", column, "TOPRIGHT", 0, 0)
        local bottom = column:CreateTexture(nil, "BACKGROUND", nil, 1)
        ns.SetTex(bottom, "charScrollBar")
        bottom:SetPoint("BOTTOMLEFT", column, "BOTTOMLEFT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", column, "BOTTOMRIGHT", 0, 0)
        column.top, column.bottom = top, bottom
        detail.fcuiColumn = column
        detail:HookScript("OnShow", function() column:Show() end)
        detail:HookScript("OnHide", function() column:Hide() end)
    end
    local tall = DETAIL_H + 2 - FOOT_H + 10
    local half = math.floor(tall / 2)
    column:SetFrameLevel(detail:GetFrameLevel() + 1)
    column:ClearAllPoints()
    local x = -68
    local listBar = skills.ScrollBar
    local barLeft, right = listBar and listBar:GetLeft(), CharacterFrame:GetRight()
    if barLeft and right then x = barLeft - 8 - right end
    column:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMRIGHT", x, 84 + FOOT_H)
    column:SetHeight(tall)
    column.top:SetHeight(half)
    column.top:SetTexCoord(0, 0.484375, 0, half / 256)
    column.bottom:SetHeight(tall - half)
    column.bottom:SetTexCoord(0.515625, 1, (108 - (tall - half)) / 256, 108 / 256)
    column:SetShown(onSkills)
    if detail.DescriptionScrollBar and ns.SkinMinimalScrollBar then
        ns.SkinMinimalScrollBar(detail.DescriptionScrollBar)
        detail.DescriptionScrollBar:ClearAllPoints()
        detail.DescriptionScrollBar:SetPoint("TOP", column, "TOP", 0, -20)
        detail.DescriptionScrollBar:SetPoint("BOTTOM", column, "BOTTOM", 0, 20)
    end

    local foot = detail.fcuiFoot
    if not foot then
        foot = CreateFrame("Frame", nil, detail)
        local stone = foot:CreateTexture(nil, "BACKGROUND", nil, 2)
        stone:SetTexture(ns.TexPath("rockBg"), "REPEAT", "REPEAT")
        stone:SetHorizTile(true)
        stone:SetVertTile(true)
        stone:SetAllPoints(foot)
        stone:SetVertexColor(1.25, 1.2, 1.1)
        local line = foot:CreateTexture(nil, "BORDER")
        line:SetColorTexture(0.52, 0.48, 0.40, 1)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", foot, "TOPLEFT", 0, 0)
        line:SetPoint("TOPRIGHT", foot, "TOPRIGHT", 0, 0)
        local close = ns.PanelButton(foot, CLOSE or "Close", 80)
        close:SetPoint("RIGHT", foot, "RIGHT", -2, 0)
        close:SetScript("OnClick", function()
            if HideUIPanel and CharacterFrame then HideUIPanel(CharacterFrame) end
        end)
        detail.fcuiFoot = foot
    end
    foot:ClearAllPoints()
    foot:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", 0, 0)
    foot:SetHeight(FOOT_H)
    if detail.Content then detail.Content:Hide() end

    local unlearn = detail.fcuiUnlearn
    if not unlearn then
        unlearn = CreateFrame("Button", nil, detail)
        unlearn:SetSize(32, 32)
        unlearn:SetHitRectInsets(9, 9, 9, 9)
        unlearn:SetNormalTexture("Interface\\Buttons\\CancelButton-Up")
        unlearn:SetPushedTexture("Interface\\Buttons\\CancelButton-Down")
        unlearn:SetHighlightTexture("Interface\\Buttons\\CancelButton-Highlight")
        unlearn:GetHighlightTexture():SetBlendMode("ADD")
        unlearn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local line = UNLEARN_SKILL_TOOLTIP
            if type(line) ~= "string" or #line > 40 then line = "Unlearn this profession" end
            GameTooltip:SetText(line, 1, 0.82, 0)
            GameTooltip:Show()
        end)
        unlearn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        unlearn:SetScript("OnClick", function()
            local picked = SelectedSkill()
            if picked and picked.isAbandonable and StaticPopup_Show then
                StaticPopup_Show("ERAUI_BASE_UNLEARN_SKILL", picked.name, nil, picked.skillID)
            end
        end)
        detail.fcuiUnlearn = unlearn
    end
    unlearn:ClearAllPoints()
    if detail.RankBar then
        unlearn:SetPoint("LEFT", detail.RankBar, "RIGHT", 0, 0)
    else
        unlearn:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -8, -10)
    end
    unlearn:SetShown(info ~= nil and info.isAbandonable == true)
    detail:SetShown(onSkills)
end
ns.SkinSkillDetail = SkinSkillDetail

local function SkinListFrame(frame, barKey)
    local box = frame and frame.ScrollBox
    if not box then return end
    if not listHooked[frame] then
        listHooked[frame] = true
        local look = CreateFrame("Frame", nil, frame)
        look:SetScript("OnUpdate", function(self, elapsed)
            self.since = (self.since or 0) + elapsed
            if self.since < 0.05 then return end
            self.since = 0
            if not active or not box.ForEachFrame then return end
            box:ForEachFrame(function(row)
                local data = row.GetElementData and row:GetElementData()
                if data ~= nil and row.fcuiDressedFor ~= data then
                    row.fcuiDressedFor = data
                    SkinListRow(row, barKey)
                end
            end)
        end)
        if box.ForEachFrame and type(frame.Update) == "function" then
            ns.HookMethod(frame, "Update", function()
                if active and box.ForEachFrame then box:ForEachFrame(function(row) SkinListRow(row, barKey) end) end
            end)
        end
    end
    if not active then return end
    box:ClearAllPoints()
    if barKey == "SkillsBar" then
        local k = SKILL_LIST_SCALE
        box:SetScale(k)
        box:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 12 / k, -76 / k)
        box:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -66 / k, (86 + DETAIL_H + 14) / k)
        SkinSkillDetail()
        local detail = frame.SkillDetailFrame
        if detail and not detail.fcuiHooked then
            detail.fcuiHooked = true
            ns.HookMethod(detail, "Refresh", SkinSkillDetail)
            local picked = CreateFrame("Frame", nil, frame)
            picked:SetScript("OnUpdate", function(self, elapsed)
                self.since = (self.since or 0) + elapsed
                if self.since < 0.05 then return end
                self.since = 0
                if not active or not (C_SkillInfo and C_SkillInfo.GetSelectedSkill) then return end
                local ok, index = pcall(C_SkillInfo.GetSelectedSkill)
                if ok and index ~= self.index then
                    self.index = index
                    ns.SafeCall(SkinSkillDetail)
                end
            end)
            frame:HookScript("OnShow", SkinSkillDetail)
            frame:HookScript("OnHide", function() detail:Hide() end)
        end
    elseif barKey == "ReputationBar" then
        local k = REP_LIST_SCALE
        box:SetScale(k)
        box:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 12 / k, -76 / k)
        box:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -66 / k, 86 / k)
    else
        box:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 12, -76)
        box:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -66, 86)
    end
    for _, child in ipairs({ box:GetChildren() }) do
        if child ~= box.ScrollTarget then FadeAtlas(child, "scrollline") end
    end
    if frame.ScrollBar then
        SkinRepScrollBar(frame.ScrollBar)
        frame.ScrollBar:ClearAllPoints()
        frame.ScrollBar:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, -4)
        frame.ScrollBar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 6, 4)
    end
    if box.ForEachFrame then box:ForEachFrame(function(row) SkinListRow(row, barKey) end) end
    if frame.filterDropdown then
        frame.filterDropdown:ClearAllPoints()
        frame.filterDropdown:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -40, -62)
    end
end

local repDetail
local repFactionID

local function RepIndexOf(factionID)
    if not factionID or not C_Reputation or not C_Reputation.GetNumFactions then return nil end
    for index = 1, C_Reputation.GetNumFactions() do
        local data = C_Reputation.GetFactionDataByIndex(index)
        if data and data.factionID == factionID then return index, data end
    end
end

local function RepCheck(parent, label, r, g, b)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    if ns.SkinCheckbox then ns.SkinCheckbox(check) end
    local text = check.Text or check.text
    if not text then
        text = check:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        text:SetPoint("LEFT", check, "RIGHT", 0, 1)
    end
    text:SetFontObject("GameFontNormalSmall")
    text:SetText(label)
    text:SetTextColor(r, g, b)
    check.label = text
    check:SetHitRectInsets(0, -math.min(120, (text:GetStringWidth() or 60)), 0, 0)
    return check
end

local MarkRepRows

local function RefreshRepDetail()
    if not repDetail or not repDetail:IsShown() then return end
    local index, data = RepIndexOf(repFactionID)
    if not index then
        repDetail:Hide()
        return
    end
    repDetail.index = index
    repDetail.name:SetText(data.name or "")
    repDetail.text:SetText(data.description or "")
    local canWar = data.canToggleAtWar and not data.isHeader
    repDetail.war:SetEnabled(canWar and true or false)
    repDetail.war:SetChecked(data.atWarWith and true or false)
    if canWar then repDetail.war.label:SetTextColor(1, 0.1, 0.1) else repDetail.war.label:SetTextColor(0.5, 0.5, 0.5) end
    repDetail.inactive:SetEnabled(data.canSetInactive and true or false)
    repDetail.inactive:SetChecked(C_Reputation.IsFactionActive and not C_Reputation.IsFactionActive(index) or false)
    if data.canSetInactive then repDetail.inactive.label:SetTextColor(1, 0.82, 0) else repDetail.inactive.label:SetTextColor(0.5, 0.5, 0.5) end
    repDetail.watch:SetChecked(data.isWatched and true or false)
end

local function BuildRepDetail()
    if repDetail then return repDetail end
    local box = CreateFrame("Frame", "EraUIClassicReputationDetail", CharacterFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    box:SetSize(212, 203)
    box:SetFrameLevel(CharacterFrame:GetFrameLevel() + 30)
    box:EnableMouse(true)
    box:Hide()
    local function Segment(top, bottom, level)
        local part = CreateFrame("Frame", nil, box, BackdropTemplateMixin and "BackdropTemplate" or nil)
        part:SetPoint("TOPLEFT", box, "TOPLEFT", 0, top)
        part:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", 0, bottom)
        part:SetFrameLevel(box:GetFrameLevel() + level)
        if part.SetBackdrop then
            part:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32, insets = { left = 8, right = 8, top = 8, bottom = 8 },
            })
            part:SetBackdropColor(0, 0, 0, 1)
        end
        return part
    end
    local upper = Segment(0, -146, 0)
    local page = upper:CreateTexture(nil, "BORDER")
    page:SetTexture("Interface\\QuestFrame\\QuestBG")
    page:SetTexCoord(0, 0.58, 0, 0.3)
    page:SetVertexColor(0.55, 0.47, 0.35)
    page:SetPoint("TOPLEFT", upper, "TOPLEFT", 10, -10)
    page:SetPoint("BOTTOMRIGHT", upper, "BOTTOMRIGHT", -10, 10)
    Segment(-134, -203, 1)
    local content = CreateFrame("Frame", nil, box)
    content:SetAllPoints(box)
    content:SetFrameLevel(box:GetFrameLevel() + 5)

    box.name = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    box.name:SetPoint("TOPLEFT", box, "TOPLEFT", 20, -21)
    box.name:SetWidth(150)
    box.name:SetJustifyH("LEFT")
    box.text = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    box.text:SetPoint("TOPLEFT", box.name, "BOTTOMLEFT", 0, -2)
    box.text:SetSize(172, 96)
    box.text:SetJustifyH("LEFT")
    box.text:SetJustifyV("TOP")

    local close = CreateFrame("Button", nil, content)
    close:SetSize(32, 32)
    close:SetPoint("TOPRIGHT", box, "TOPRIGHT", -3, -3)
    if ns.SkinCloseButton then ns.SkinCloseButton(close, true) end
    close:SetScript("OnClick", function() box:Hide() end)

    box.war = RepCheck(content, AT_WAR or "At War", 1, 0.1, 0.1)
    box.war:SetPoint("TOPLEFT", box, "TOPLEFT", 14, -143)
    box.war:SetScript("OnClick", function(self)
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        if box.index and C_Reputation.ToggleFactionAtWar then C_Reputation.ToggleFactionAtWar(box.index) end
        C_Timer.After(1, RefreshRepDetail)
    end)
    box.inactive = RepCheck(content, MOVE_TO_INACTIVE or "Move to Inactive", 1, 0.82, 0)
    box.inactive:SetPoint("LEFT", box.war, "RIGHT", 52, 0)
    box.inactive:SetScript("OnClick", function(self)
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        if box.index and C_Reputation.SetFactionActive then C_Reputation.SetFactionActive(box.index, not self:GetChecked()) end
        C_Timer.After(1, RefreshRepDetail)
    end)
    box.watch = RepCheck(content, SHOW_FACTION_ON_MAINSCREEN or "Show as Experience Bar", 1, 0.82, 0)
    box.watch:SetPoint("TOPLEFT", box.war, "BOTTOMLEFT", 0, 0)
    box.watch:SetScript("OnClick", function(self)
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        if C_Reputation.SetWatchedFactionByIndex then C_Reputation.SetWatchedFactionByIndex(self:GetChecked() and box.index or 0) end
        box.watchHeldAt = GetTime()
        box.watchWanted = self:GetChecked() and true or false
        self:Disable()
        self.label:SetTextColor(0.5, 0.5, 0.5)
        C_Timer.After(1, RefreshRepDetail)
    end)

    box:RegisterEvent("UPDATE_FACTION")
    box:SetScript("OnEvent", function() C_Timer.After(0, RefreshRepDetail) end)
    box:SetScript("OnUpdate", function(self, elapsed)
        if self.watchHeldAt then
            local held = GetTime() - self.watchHeldAt
            local busy = ns.StatusBarsBusy and ns.StatusBarsBusy()
            local there = not ns.StatusBarsShowFaction or (ns.StatusBarsShowFaction() == self.watchWanted)
            if held > 3 or (held > 0.1 and there and not busy) then
                self.watchHeldAt = nil
                self.watch:Enable()
                self.watch.label:SetTextColor(1, 0.82, 0)
                RefreshRepDetail()
            end
        end
        self.since = (self.since or 0) + elapsed
        if self.since < 0.2 then return end
        self.since = 0
        if not (ReputationFrame and ReputationFrame:IsVisible()) then
            self:Hide()
            return
        end
        MarkRepRows()
    end)
    MarkRepRows = function()
        local scrollBox = ReputationFrame and ReputationFrame.ScrollBox
        if scrollBox and scrollBox.ForEachFrame then
            pcall(scrollBox.ForEachFrame, scrollBox, function(row)
                local mark = row.fcuiRepMark
                local chosen = row.elementData and row.elementData.factionID == repFactionID
                local bar = row.Content and row.Content.ReputationBar
                local plate = bar and bar.fcui and bar.fcui.plateLeft
                if chosen and not mark and plate then
                    mark = CreateFrame("Frame", nil, bar)
                    mark:SetAllPoints(bar)
                    mark:SetFrameLevel(bar:GetFrameLevel() + 3)
                    local strip = mark:CreateTexture(nil, "OVERLAY")
                    ns.SetTex(strip, "repHighlight")
                    strip:SetTexCoord(0, 1, 0, 27 / 64)
                    strip:SetSize(256, 27)
                    strip:SetBlendMode("ADD")
                    strip:SetPoint("TOPLEFT", plate, "TOPLEFT", -2, 3)
                    local cap = mark:CreateTexture(nil, "OVERLAY")
                    ns.SetTex(cap, "repHighlight")
                    cap:SetTexCoord(0, 0.0625, 0.4375, 0.9375)
                    cap:SetSize(16, 32)
                    cap:SetBlendMode("ADD")
                    cap:SetPoint("TOPLEFT", strip, "TOPRIGHT", 0, 0)
                    row.fcuiRepMark = mark
                end
                if mark then mark:SetShown((chosen and box:IsShown()) and true or false) end
            end)
        end
    end
    box:SetScript("OnHide", function()
        if box.watchHeldAt then
            box.watchHeldAt = nil
            box.watch:Enable()
            box.watch.label:SetTextColor(1, 0.82, 0)
        end
        local scrollBox = ReputationFrame and ReputationFrame.ScrollBox
        if scrollBox and scrollBox.ForEachFrame then
            pcall(scrollBox.ForEachFrame, scrollBox, function(row) if row.fcuiRepMark then row.fcuiRepMark:Hide() end end)
        end
    end)
    repDetail = box
    return box
end

function ns.ReputationRowClicked(row)
    if not active or not row then return end
    local data = row.elementData
    local factionID = data and data.factionID
    if not factionID or factionID <= 0 then return end
    local box = BuildRepDetail()
    if box:IsShown() and repFactionID == factionID then
        box:Hide()
        return
    end
    repFactionID = factionID
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", ART_RIGHT_EDGE, -48)
    box:Show()
    RefreshRepDetail()
    MarkRepRows()
    C_Timer.After(0, MarkRepRows)
    C_Timer.After(0.1, MarkRepRows)
end

local function SkinReputation()
    local rep = ReputationFrame
    SkinListFrame(rep, "ReputationBar")
    if rep and active then
        local faction = ns.OwnFontString(rep, "factionLabel", "ARTWORK", "GameFontHighlight")
        faction:SetText(FACTION or "Faction")
        faction:ClearAllPoints()
        faction:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 86, -59)
        faction:Show()
        local standing = ns.OwnFontString(rep, "standingLabel", "ARTWORK", "GameFontHighlight")
        standing:SetText(STANDING or "Standing")
        standing:ClearAllPoints()
        standing:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 215, -59)
        standing:Show()
    end
end

local function SkinPvP()
    local pvp = PVPRankFrame
    local main = pvp and pvp.MainInfoFrame
    if not main or not active then return end
    main:ClearAllPoints()
    main:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 6, -70)
    main:SetPoint("BOTTOMRIGHT", CharacterFrame, "TOPRIGHT", -6, -205)
end

local LIST_TABS = { { "SkillsFrame", "SkillsBar" }, { "TokenFrame" }, { "StatisticsFrame" } }
local function SkinListTabs()
    SkinReputation()
    SkinPvP()
    for _, entry in ipairs(LIST_TABS) do
        SkinListFrame(_G[entry[1]], entry[2])
    end
end

local function QuietMouse(frame, depth)
    if frame.IsMouseEnabled and frame:IsMouseEnabled() then
        frame.fcuiMouseWas = true
        pcall(frame.EnableMouse, frame, false)
    end
    if depth < 5 and frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do QuietMouse(child, depth + 1) end
    end
end
local function LoudMouse(frame, depth)
    if frame.fcuiMouseWas then
        frame.fcuiMouseWas = nil
        pcall(frame.EnableMouse, frame, true)
    end
    if depth < 5 and frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do LoudMouse(child, depth + 1) end
    end
end
local function Quiet(frame)
    if not frame or not frame.SetAlpha then return end
    if frame:GetAlpha() > 0 then frame:SetAlpha(0) end
    if not frame.fcuiQuiet or (frame.IsMouseEnabled and frame:IsMouseEnabled()) then
        frame.fcuiQuiet = true
        QuietMouse(frame, 0)
    end
end
local function Loud(frame)
    if not frame or not frame.fcuiQuiet then return end
    frame.fcuiQuiet = nil
    frame:SetAlpha(1)
    LoudMouse(frame, 0)
end

HideSidePane = function(frame)
    Quiet(frame.RightPaneHost)
    for _, pane in ipairs(frame.SidePanes or {}) do
        local keep = SkillsFrame and pane == SkillsFrame.SkillDetailFrame and SkillsFrame:IsShown()
        if keep then Loud(pane) else Quiet(pane) end
    end
    for _, name in ipairs({ "CharacterStatsPane", "CharacterStatsPaneScrollBox", "PaperDollSidebarTabs", "PaperDollLevelInfo" }) do
        Quiet(_G[name])
    end
    if type(GetPaperDollSideBarFrame) == "function" and type(PAPERDOLL_SIDEBARS) == "table" then
        for i = 1, #PAPERDOLL_SIDEBARS do
            local bar = GetPaperDollSideBarFrame(i)
            local keep = bar == (PaperDollFrame and PaperDollFrame.EquipmentManagerPane) and ns.EquipmentPaneOpen and ns.EquipmentPaneOpen()
            if bar then
                if keep then Loud(bar) else Quiet(bar) end
            end
        end
    end
    if frame.ModeTabs then
        frame.ModeTabs:SetAlpha(0)
        if not frame.ModeTabs:IsShown() then frame.ModeTabs:Show() end
    end
    Quiet(frame.RightPaneToggleButton)
    if frame.SetHitRectInsets and frame.GetWidth then
        local spare = math.max(0, math.floor((frame:GetWidth() or 0) - 384))
        if frame.fcuiSpare ~= spare then
            frame.fcuiSpare = spare
            frame:SetHitRectInsets(0, spare, 0, 0)
        end
    end
end

local hooked = false
local function Apply()
    active = true
    if not CharacterFrame or not PaperDollFrame then ns.MissingPiece("CharacterFrame") return end
    if not built then Build() end
    if not hooked then
        hooked = true
        ns.HookMethod(CharacterFrame, "UpdateSize", Layout)
        ns.HookMethod(CharacterFrame, "UpdateTabBounds", Layout)
        if PaperDollFrame then
            PaperDollFrame:HookScript("OnSizeChanged", function() if active then Layout() end end)
        end
        local watcher = CreateFrame("Frame")
        watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        watcher:SetScript("OnEvent", function()
            if active and CharacterFrame and CharacterFrame:IsShown() then Layout() end
        end)
        ns.HookMethod(CharacterFrame, "Expand", function(self)
            if active then HideSidePane(self) end
        end)
        if ReputationFrame then ReputationFrame:HookScript("OnShow", SkinReputation) end
        if PVPRankFrame then PVPRankFrame:HookScript("OnShow", SkinPvP) end
        for _, entry in ipairs(LIST_TABS) do
            local frame = _G[entry[1]]
            if frame then
                local key = entry[2]
                frame:HookScript("OnShow", function(self) SkinListFrame(self, key) end)
            end
        end
        if CharacterFrame.RefreshRightPane then
            ns.HookMethod(CharacterFrame, "RefreshRightPane", function(self)
                if active then HideSidePane(self) end
            end)
            ns.HookMethod(CharacterFrame, "ShowSubFrame", function() if active then C_Timer.After(0, Layout) end end)
        end
        if type(PaperDollFrame_UpdateSidebarTabs) == "function" then
            ns.HookGlobal("PaperDollFrame_UpdateSidebarTabs", function() if active then HideSidePane(CharacterFrame) end end)
        end
        CharacterFrame:HookScript("OnShow", function() if active then Layout() end end)
        local sideWatch = CreateFrame("Frame", nil, CharacterFrame)
        sideWatch:SetScript("OnUpdate", function()
            if not active then return end
            local tabs = PaperDollSidebarTabs
            local host = CharacterFrame.RightPaneHost
            if (tabs and tabs:IsShown() and tabs:GetAlpha() > 0) or (host and host:IsShown() and host:GetAlpha() > 0) then
                HideSidePane(CharacterFrame)
            end
            for _, tab in ipairs(sheet and sheet.tabs or {}) do OverTab(tab) end
        end)
        if CharacterModelScene then
            if CharacterModelScene.TransitionToModelSceneID then
                ns.HookMethod(CharacterModelScene, "TransitionToModelSceneID", function()
                    if active then C_Timer.After(0, FitModelCamera) end
                end)
            end
            CharacterModelScene:HookScript("OnShow", function()
                if active then C_Timer.After(0.1, FitModelCamera) end
            end)
        end
        function ns.CharacterCameraInfo()
            local scene = CharacterModelScene
            local camera = scene and scene.GetActiveCamera and scene:GetActiveCamera()
            if not camera then return "no camera" end
            local ok, distance = pcall(function() return camera:GetZoomDistance() end)
            local okMax, max = pcall(function() return camera:GetMaxZoomDistance() end)
            return string.format("camera %s fitted %s zoom %s max %s", tostring(camera.GetDebugName and camera:GetDebugName() or "?"), tostring(camera.fcuiFitted), ok and tostring(distance) or "n/a", okMax and tostring(max) or "n/a")
        end
    end
    HideSidePane(CharacterFrame)
    if ns.EquipmentPaneApply then ns.EquipmentPaneApply() end
    ns.SetCVar("characterFrameCollapsed", "1")
    SkinListTabs()
    EraUIClassic_CharacterSheetActive = true
    for _, tex in ipairs(sheet.general) do tex:Show() end
    if sheet.ringOver then
        sheet.ringOver:Show()
        if sheet.ringOver.doll then sheet.ringOver.doll:Show() end
    end
    for _, tex in ipairs(sheet.doll) do tex:Show() end
    sheet.attrs:SetShown(not (ns.db and ns.db.statPanes))
    Layout()
end

local function Restore()
    active = false
    EraUIClassic_CharacterSheetActive = false
    if not built then return end
    if sheet.level then sheet.level:Hide() end
    for _, tab in ipairs(sheet.tabs or {}) do tab:Hide() end
    for _, tex in ipairs(sheet.general) do tex:Hide() end
    if sheet.ringOver then
        sheet.ringOver:Hide()
        if sheet.ringOver.doll then sheet.ringOver.doll:Hide() end
    end
    for _, tex in ipairs(sheet.doll) do tex:Hide() end
    sheet.attrs:Hide()
    for _, row in ipairs(sheet.resistances) do row:Hide() end
    if sheet.rotateLeft then sheet.rotateLeft:Hide() end
    if sheet.rotateRight then sheet.rotateRight:Hide() end
    if ns.EquipmentPaneRestore then ns.EquipmentPaneRestore() end
    if PaperDollSidebarTabs then PaperDollSidebarTabs:SetAlpha(1) end
    ns.needsReload = true
end

ns.RegisterModule("characterSheet", { apply = Apply, restore = Restore })
