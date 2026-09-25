-- EraUI spellbook.
-- The 1.x spellbook: the four-piece parchment book, twelve spells a page in
-- two columns with the name and rank beside each icon, school tabs down the
-- right edge, page arrows at the bottom and the Spellbook and pet tabs along
-- the bottom edge. Data comes from C_SpellBook and the buttons are secure so
-- clicks cast.
local _, EraUI = ...
local ns = EraUI.Classic

local SPELLS_PER_PAGE = 12
local MAX_SKILL_TABS = 8
local BOOK_W, BOOK_H = 384, 512
local BUTTON_SIZE, COLUMN_X, ROW_GAP = 37, 157, 14
local FIRST_X, FIRST_Y = 34, -85

local BANK_PLAYER = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
local BANK_PET = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet or 1
local ITEM_FUTURE = Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell
local ITEM_FLYOUT = Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

local active = false
local book
local state = {
    bank = BANK_PLAYER,
    line = 1,
    pages = {},
    slots = {},
    search = "",
}

local function CurrentPageKey()
    if state.search ~= "" then return "search" end
    return state.bank == BANK_PET and "pet" or state.line
end

local function CurrentPage()
    return state.pages[CurrentPageKey()] or 1
end

local function SetPage(page)
    state.pages[CurrentPageKey()] = page
end

local function PetSpellCount()
    local ok, count, token = pcall(C_SpellBook.HasPetSpells)
    if not ok or not count or IsSecret(count) then return 0 end
    return count, token
end

local function SpellMatches(index, bank, query)
    local ok, name, sub = pcall(C_SpellBook.GetSpellBookItemName, index, bank)
    if not ok or type(name) ~= "string" or IsSecret(name) then return false end
    if name:lower():find(query, 1, true) then return true end
    return type(sub) == "string" and not IsSecret(sub) and sub:lower():find(query, 1, true) ~= nil
end

local function CollectAllSlots()
    local slots = state.slots
    wipe(slots)
    local query = state.search:lower()
    if query ~= "" then
        if state.bank == BANK_PET then
            local count = PetSpellCount()
            for i = 1, count do
                if SpellMatches(i, BANK_PET, query) then slots[#slots + 1] = i end
            end
            return
        end
        local n = C_SpellBook.GetNumSpellBookSkillLines() or 0
        for line = 1, n do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if info and not info.shouldHide and (info.offSpecID or 0) == 0 then
                local first = (info.itemIndexOffset or 0) + 1
                local last = (info.itemIndexOffset or 0) + (info.numSpellBookItems or 0)
                for i = first, last do
                    local kind = C_SpellBook.GetSpellBookItemType(i, BANK_PLAYER)
                    if kind ~= ITEM_FUTURE and kind ~= ITEM_FLYOUT and SpellMatches(i, BANK_PLAYER, query) then
                        slots[#slots + 1] = i
                    end
                end
            end
        end
        return
    end
    if state.bank == BANK_PET then
        local count = PetSpellCount()
        for i = 1, count do slots[#slots + 1] = i end
        return
    end
    local info = C_SpellBook.GetSpellBookSkillLineInfo(state.line)
    if not info then return end
    local first = (info.itemIndexOffset or 0) + 1
    local last = (info.itemIndexOffset or 0) + (info.numSpellBookItems or 0)
    for i = first, last do
        local itemType = C_SpellBook.GetSpellBookItemType(i, BANK_PLAYER)
        if itemType ~= ITEM_FUTURE and itemType ~= ITEM_FLYOUT then slots[#slots + 1] = i end
    end
end

local function CollectSlots()
    CollectAllSlots()
    if not (ns.db and ns.db.spellBookTopRank == true) or state.bank == BANK_PET then return end
    local slots = state.slots
    local best, rankOf = {}, {}
    for _, index in ipairs(slots) do
        local ok, name, sub = pcall(C_SpellBook.GetSpellBookItemName, index, BANK_PLAYER)
        if ok and type(name) == "string" and not IsSecret(name) and type(sub) == "string" and not IsSecret(sub) then
            local rank = tonumber(sub:match("%d+"))
            if rank then
                rankOf[index] = rank
                local held = best[name]
                if not held or rank >= rankOf[held] then best[name] = index end
            end
        end
    end
    local kept = {}
    for _, index in ipairs(slots) do
        local ok, name = pcall(C_SpellBook.GetSpellBookItemName, index, BANK_PLAYER)
        if not rankOf[index] or not ok or best[name] == index then kept[#kept + 1] = index end
    end
    wipe(slots)
    for i, index in ipairs(kept) do slots[i] = index end
end

local function PageCount()
    return math.max(1, math.ceil(#state.slots / SPELLS_PER_PAGE))
end

local function SlotsFor(bank, line, search)
    local keepBank, keepLine, keepSearch = state.bank, state.line, state.search
    state.bank, state.line, state.search = bank, line, search
    CollectSlots()
    local out = {}
    for i, index in ipairs(state.slots) do out[i] = index end
    state.bank, state.line, state.search = keepBank, keepLine, keepSearch
    return out
end

local SUB_FONT = _G.SubSpellFont and "SubSpellFont" or "GameFontHighlightSmall"

local function CastID(info, bank)
    if (bank or state.bank) == BANK_PET then return info.spellID or info.actionID end
    return info.actionID or info.spellID
end

local function ArmSpell(btn, slot, bank)
    local info = slot and C_SpellBook.GetSpellBookItemInfo(slot, bank)
    btn.slot = info and slot or nil
    btn.bank = bank
    btn.isPassive = info and info.isPassive or nil
    local id = info and not info.isPassive and info.itemType ~= ITEM_FLYOUT and CastID(info, bank) or nil
    if id and not IsSecret(id) then
        btn:SetAttribute("type1", "spell")
        btn:SetAttribute("spell", id)
    else
        btn:SetAttribute("type1", nil)
        btn:SetAttribute("spell", nil)
    end
end

local function UpdateCooldown(btn)
    local cd = btn.cooldown
    if not btn.slot then cd:Clear(); return end
    if C_SpellBook.GetSpellBookItemCooldownDuration and cd.SetCooldownFromDurationObject then
        local ok, duration = pcall(C_SpellBook.GetSpellBookItemCooldownDuration, btn.slot, state.bank)
        if ok and duration ~= nil then
            if pcall(cd.SetCooldownFromDurationObject, cd, duration, true) then return end
        end
    end
    local ok, info = pcall(C_SpellBook.GetSpellBookItemCooldown, btn.slot, state.bank)
    if not ok or not info then cd:Clear(); return end
    local enabled = info.isEnabled
    if not IsSecret(enabled) and enabled == false then cd:Clear(); return end
    if IsSecret(info.startTime) or IsSecret(info.duration) or IsSecret(info.modRate) then
        cd:Clear()
        return
    end
    cd:SetCooldown(info.startTime, info.duration, info.modRate)
end

local function UpdateUsable(btn)
    local icon = btn.Icon
    if not btn.slot or btn.isPassive or not C_SpellBook.IsSpellBookItemUsable or not InCombatLockdown() then
        icon:SetVertexColor(1, 1, 1)
        return
    end
    local ok, usable, noPower = pcall(C_SpellBook.IsSpellBookItemUsable, btn.slot, state.bank)
    if not ok or IsSecret(usable) or IsSecret(noPower) or usable then
        icon:SetVertexColor(1, 1, 1)
    elseif noPower then
        icon:SetVertexColor(0.5, 0.5, 1)
    else
        icon:SetVertexColor(0.4, 0.4, 0.4)
    end
end

local function DimButton(btn, on)
    local shade = btn.shade
    if not on then
        if shade then shade:Hide() end
        return
    end
    if not shade then
        shade = btn.slotFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        shade:SetAllPoints(btn.slotFrame)
        shade:SetColorTexture(0, 0, 0, 0.55)
        btn.shade = shade
    end
    shade:Show()
end

local viewLive = true
local Button_OnEnter

local function UpdateButton(btn)
    local page = CurrentPage()
    local slot = state.slots[(page - 1) * SPELLS_PER_PAGE + btn:GetID()]
    local info = slot and C_SpellBook.GetSpellBookItemInfo(slot, state.bank)
    btn.slot = slot
    if not info then
        btn.slot = nil
        btn.isPassive = nil
        btn.Icon:Hide()
        btn.SpellName:Hide()
        btn.SpellSubName:Hide()
        btn.cooldown:Clear()
        btn.checkedTex:Hide()
        btn.normal:SetVertexColor(1, 1, 1)
        DimButton(btn, false)
        return
    end
    btn.isPassive = info.isPassive
    btn.Icon:SetTexture(info.iconID)
    btn.Icon:SetDesaturated(info.isOffSpec and true or false)
    btn.Icon:Show()
    btn.SpellName:SetText(info.name)
    local sub = info.subName or ""
    if sub == "" and info.isPassive then sub = SPELL_PASSIVE end
    btn.SpellSubName:SetText(sub)
    btn.SpellName:ClearAllPoints()
    btn.SpellName:SetPoint("LEFT", btn, "RIGHT", 5, sub == "" and 1 or 3)
    btn.SpellName:Show()
    btn.SpellSubName:Show()
    if info.isPassive then
        btn.normal:SetVertexColor(0, 0, 0)
        btn.SpellName:SetTextColor(PASSIVE_SPELL_FONT_COLOR:GetRGB())
    else
        btn.normal:SetVertexColor(1, 1, 1)
        btn.SpellName:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
    end
    btn.checkedTex:Hide()
    DimButton(btn, not viewLive and not info.isPassive)
    UpdateUsable(btn)
    UpdateCooldown(btn)
end

Button_OnEnter = function(self)
    if not self.slot then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetSpellBookItem(self.slot, state.bank)
    GameTooltip:Show()
end

local function Button_OnDragStart(self)
    if not self.slot or self.isPassive or InCombatLockdown() then return end
    C_SpellBook.PickupSpellBookItem(self.slot, self.bank or state.bank)
end

local function Button_PostClick(self)
    if not self.slot then return end
    if IsModifiedClick("CHATLINK") then
        local ok, link = pcall(C_SpellBook.GetSpellBookItemLink, self.slot, state.bank)
        if ok and link and not IsSecret(link) then ChatEdit_InsertLink(link) end
    end
end

local function CreateSpellButton(parent, id, clicks)
    local slot = CreateFrame("Frame", nil, parent)
    slot:SetID(id)
    slot:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    local column = id > 6 and 1 or 0
    local row = (id - 1) % 6
    slot:SetPoint("TOPLEFT", parent, "TOPLEFT", FIRST_X + column * COLUMN_X, FIRST_Y - row * (BUTTON_SIZE + ROW_GAP))

    local empty = slot:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(empty, "sbEmptySlot")
    empty:SetSize(64, 64)
    empty:SetPoint("TOPLEFT", slot, "TOPLEFT", -3, 3)

    local icon = slot:CreateTexture(nil, "BORDER")
    icon:SetAllPoints(slot)
    icon:Hide()

    local normal = slot:CreateTexture(nil, "ARTWORK")
    ns.SetTex(normal, "slotNormal")
    normal:SetSize(64, 64)
    normal:SetPoint("CENTER", slot, "CENTER", 0, 0)

    local checked = slot:CreateTexture(nil, "OVERLAY")
    ns.SetTex(checked, "checked")
    checked:SetAllPoints(slot)
    checked:SetBlendMode("ADD")
    checked:Hide()

    local name = slot:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    name:SetWidth(103)
    name:SetJustifyH("LEFT")
    name:SetMaxLines(3)
    name:SetPoint("LEFT", slot, "RIGHT", 5, 3)

    local sub = slot:CreateFontString(nil, "ARTWORK", SUB_FONT)
    sub:SetSize(79, 18)
    sub:SetJustifyH("LEFT")
    sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)

    local cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
    cooldown:SetAllPoints(slot)

    local btn = CreateFrame("CheckButton", "EraUIClassicSpellButton" .. id, clicks, "SecureActionButtonTemplate")
    btn:SetID(id)
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    btn:SetPoint("TOPLEFT", clicks, "TOPLEFT", FIRST_X + column * COLUMN_X, FIRST_Y - row * (BUTTON_SIZE + ROW_GAP))
    btn.slotFrame = slot
    btn.EmptySlot = empty
    btn.Icon = icon
    btn.SpellName = name
    btn.SpellSubName = sub
    btn.cooldown = cooldown
    btn.normal = normal
    btn.checkedTex = checked

    ns.SetButtonTex(btn, "Pushed", "slotPushed")
    ns.SetButtonTex(btn, "Highlight", "highlight")
    btn:GetHighlightTexture():SetBlendMode("ADD")

    return btn
end

local function CreatePageButton12(layer, id)
    local btn = CreateFrame("Button", nil, layer, "SecureActionButtonTemplate")
    local column = id > 6 and 1 or 0
    local row = (id - 1) % 6
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    btn:SetPoint("TOPLEFT", layer, "TOPLEFT", FIRST_X + column * COLUMN_X, FIRST_Y - row * (BUTTON_SIZE + ROW_GAP))
    ns.SetButtonTex(btn, "Pushed", "slotPushed")
    ns.SetButtonTex(btn, "Highlight", "highlight")
    btn:GetHighlightTexture():SetBlendMode("ADD")
    btn:RegisterForClicks("AnyDown", "AnyUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetAttribute("useOnKeyDown", false)
    btn:SetAttribute("shift-type1", "")
    btn:SetScript("OnEnter", Button_OnEnter)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    btn:SetScript("OnDragStart", Button_OnDragStart)
    btn:SetScript("PostClick", Button_PostClick)
    return btn
end

local function SkillTab_OnClick(self)
    if InCombatLockdown() then
        self:SetChecked(state.line == self.line)
        return
    end
    state.bank = BANK_PLAYER
    state.line = self.line
    PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
    book:Refresh()
end

local function SkillTab_OnEnter(self)
    if not self.tooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tooltip)
    GameTooltip:Show()
end

local function CreateSkillTab(parent, i, prev)
    local tab = CreateFrame("CheckButton", nil, parent)
    tab:SetSize(32, 32)
    if prev then
        tab:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -17)
    else
        tab:SetPoint("TOPLEFT", parent, "TOPRIGHT", -32, -65)
    end
    local plate = tab:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(plate, "sbSkillTab")
    plate:SetSize(64, 64)
    plate:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)
    tab:SetNormalTexture("")
    ns.SetButtonTex(tab, "Highlight", "highlight")
    tab:GetHighlightTexture():SetBlendMode("ADD")
    ns.SetButtonTex(tab, "Checked", "checked")
    tab:GetCheckedTexture():SetBlendMode("ADD")
    tab:SetID(i)
    tab:SetScript("OnClick", SkillTab_OnClick)
    tab:SetScript("OnEnter", SkillTab_OnEnter)
    tab:SetScript("OnLeave", GameTooltip_Hide)
    tab:Hide()
    return tab
end

local function BookTab_OnClick(self)
    if self.professions then
        if ns.OpenProfessionsBook and ns.OpenProfessionsBook() then
            PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
            if ns.HideSpellBook then ns.HideSpellBook() end
        end
        return
    end
    if InCombatLockdown() then return end
    state.bank = self.bank
    PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
    book:Refresh()
end

local function CreateBookTab(parent, i, prev)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(128, 64)
    if prev then
        tab:SetPoint("LEFT", prev, "RIGHT", -20, 0)
    else
        tab:SetPoint("CENTER", parent, "BOTTOMLEFT", 79, 61)
    end
    tab.Text = tab:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    tab.Text:SetHeight(13)
    tab.Text:SetPoint("CENTER", tab, "CENTER", 0, 3)
    tab:SetFontString(tab.Text)
    tab:SetDisabledFontObject(GameFontHighlightSmall)
    ns.SetButtonTex(tab, "Normal", "sbTabUnselected")
    ns.SetButtonTex(tab, "Disabled", i == 3 and "sbTab3Selected" or "sbTab1Selected")
    ns.SetButtonTex(tab, "Highlight", "sbTabHighlight")
    tab:GetHighlightTexture():SetBlendMode("ADD")
    tab:SetScript("OnClick", BookTab_OnClick)
    tab:Hide()
    return tab
end

local function Page_OnClick(self)
    if InCombatLockdown() then return end
    local page = CurrentPage() + self.step
    if page < 1 or page > PageCount() then return end
    SetPage(page)
    PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
    book:Refresh()
end

local function CreatePageButton(parent, key, step, x)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(32, 32)
    btn:SetPoint("CENTER", parent, "BOTTOMLEFT", x, 105)
    ns.SetButtonTex(btn, "Normal", key .. "Up")
    ns.SetButtonTex(btn, "Pushed", key .. "Down")
    ns.SetButtonTex(btn, "Disabled", key .. "Disabled")
    ns.SetButtonTex(btn, "Highlight", "mouseHighlight")
    btn:GetHighlightTexture():SetBlendMode("ADD")
    btn.step = step
    btn:SetScript("OnClick", Page_OnClick)
    return btn
end

local function Book_OnMouseWheel(_, delta)
    Page_OnClick({ step = delta > 0 and -1 or 1 })
end

local function CreateBook()
    local f = CreateFrame("Frame", "EraUIClassicSpellBook", UIParent)
    f:SetSize(BOOK_W, BOOK_H)
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
    f:Hide()
    f.fcuiSlotWidth = 392
    ns.RegisterClassicWindow(f, true)
    ns.db.spellBookPos = nil
    if ns.CloseOnEscape then ns.CloseOnEscape(f, function() ns.HideSpellBook() end) end
    if GameMenuFrame then
        GameMenuFrame:HookScript("OnShow", function()
            if InCombatLockdown() then return end
            if f:IsShown() then
                if InCombatLockdown() and f.LayerUp and f:LayerUp() then return end
                f:Hide()
            end
        end)
    end

    for _, piece in ipairs({
        { "sbTopLeft", 256, 256, "TOPLEFT" },
        { "sbTopRight", 128, 256, "TOPRIGHT" },
        { "sbBotLeft", 256, 256, "BOTTOMLEFT" },
        { "sbBotRight", 128, 256, "BOTTOMRIGHT" },
    }) do
        local tex = f:CreateTexture(nil, "BACKGROUND")
        ns.SetTex(tex, piece[1])
        tex:SetSize(piece[2], piece[3])
        tex:SetPoint(piece[4], f, piece[4], 0, 0)
    end

    local icon = f:CreateTexture(nil, "ARTWORK")
    ns.SetTex(icon, "sbIcon")
    icon:SetSize(58, 58)
    icon:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    if ns.RoundIcon then ns.RoundIcon(icon, 2) end

    f.Title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.Title:SetPoint("CENTER", f, "CENTER", 6, 230)
    f.Title:SetText(SPELLBOOK)

    f.PageText = f:CreateFontString(nil, "ARTWORK", "GameFontBlack")
    f.PageText:SetWidth(102)
    f.PageText:SetJustifyH("RIGHT")
    f.PageText:SetPoint("CENTER", f, "BOTTOMLEFT", 182, 105)

    f.PrevPage = CreatePageButton(f, "sbPrev", -1, 50)
    f.NextPage = CreatePageButton(f, "sbNext", 1, 314)

    f.Close = CreateFrame("Button", nil, f)
    f.Close:SetSize(32, 32)
    f.Close:SetPoint("CENTER", f, "TOPRIGHT", -44, -25)
    ns.SkinCloseButton(f.Close, true)
    f.Close:SetScript("OnClick", function() ns.HidePanel(f) end)

    local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    search:SetSize(130, 20)
    search:SetPoint("TOPRIGHT", f, "TOPRIGHT", -42, -47)
    search:SetAutoFocus(false)
    search:SetMaxLetters(40)
    local hint = search:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    hint:SetPoint("LEFT", search, "LEFT", 2, 0)
    hint:SetText(SEARCH or "Search")
    local clear = CreateFrame("Button", nil, search)
    clear:SetSize(17, 17)
    clear:SetPoint("RIGHT", search, "RIGHT", -3, 0)
    clear:SetNormalTexture("Interface\\FriendsFrame\\ClearBroadcastIcon")
    clear:SetHighlightTexture("Interface\\FriendsFrame\\ClearBroadcastIcon", "ADD")
    clear:GetNormalTexture():SetAlpha(0.6)
    clear:SetScript("OnClick", function() search:SetText("") search:ClearFocus() end)
    clear:Hide()
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        hint:SetShown(text == "")
        clear:SetShown(text ~= "")
        if text ~= state.search then
            state.search = text
            if f:IsShown() then f:Refresh() end
        end
    end)
    search:SetShown(ns.db.spellBookSearch ~= false)
    f.Search = search

    local ranks = CreateFrame("CheckButton", nil, f)
    ranks:SetSize(22, 22)
    ranks:SetPoint("TOPLEFT", f, "TOPLEFT", 76, -46)
    ranks:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    ranks:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    ranks:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    ranks:GetHighlightTexture():SetBlendMode("ADD")
    ranks:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    ranks:SetHitRectInsets(0, -110, 0, 0)
    local ranksText = ranks:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    ranksText:SetPoint("LEFT", ranks, "RIGHT", 0, 1)
    ranksText:SetText(_G.SHOW_ALL_SPELL_RANKS or "Show all spell ranks")
    ranks:SetScript("OnClick", function(self)
        ns.db.spellBookTopRank = not self:GetChecked()
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        if ns.ToggleChanged then ns.ToggleChanged("spellBookTopRank") else f:Refresh() end
    end)
    f.Ranks = ranks

    local clicks = CreateFrame("Button", "EraUIClassicSpellBookClicks", UIParent, "SecureActionButtonTemplate")
    clicks:EnableMouse(false)
    clicks:SetSize(BOOK_W, BOOK_H)
    clicks:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
    clicks:SetFrameStrata("HIGH")
    clicks:Hide()
    f.Clicks = clicks

    local function FollowBook()
        if InCombatLockdown() and clicks:IsProtected() then return end
        clicks:ClearAllPoints()
        clicks:SetPoint("TOPLEFT", UIParent, "TOPLEFT", f.fcuiSlotX or 0, -104)
    end
    f.OnClassicPlaced = function() FollowBook() end
    f.LayerUp = function()
        return clicks:GetAttribute("unit") == "player"
    end
    f.fcuiHoldX = function(self)
        if InCombatLockdown() and self:LayerUp() then return self.fcuiSlotX or 0 end
    end
    f.SetLayer = function(_, on)
        if InCombatLockdown() then return end
        on = on and true or false
        if clicks.fcuiLinked then clicks:SetAttribute("unit", on and "player" or "none") end
        clicks:SetShown(on)
    end

    local function LayerPad(over, width, height, point, x, y, after)
        local pad = CreateFrame("Button", nil, clicks, "SecureActionButtonTemplate")
        pad:SetSize(width, height)
        pad:SetPoint("CENTER", clicks, point, x, y)
        pad:RegisterForClicks("AnyUp", "AnyDown")
        pad:SetAttribute("useOnKeyDown", false)
        pad:SetAttribute("type", "attribute")
        pad:SetAttribute("attribute-frame", clicks)
        pad:SetAttribute("attribute-name", "unit")
        pad:SetAttribute("attribute-value", "none")
        pad:SetScript("PostClick", function(_, _, down)
            if not down then after() end
        end)
        pad:SetScript("OnMouseDown", function() over:SetButtonState("PUSHED") end)
        pad:SetScript("OnMouseUp", function() over:SetButtonState("NORMAL") end)
        pad:SetScript("OnEnter", function() over:LockHighlight() end)
        pad:SetScript("OnLeave", function() over:UnlockHighlight() end)
        return pad
    end

    local function LinkLayer()
        if clicks.fcuiLinked or InCombatLockdown() then return end
        local toggle = _G["EraUIClassicSpellBookBind"]
        if not toggle then return end
        clicks.fcuiLinked = true
        for _, btn in ipairs(f.Buttons or {}) do btn:EnableMouse(false) end
        clicks:RegisterForClicks("AnyUp", "AnyDown")
        clicks:SetAttribute("useOnKeyDown", false)
        clicks:SetAttribute("type", "attribute")
        clicks:SetAttribute("attribute-name", "unit")
        clicks:SetAttribute("attribute-value", "player")
        clicks:SetAttribute("helpbutton", "close")
        clicks:SetAttribute("attribute-value-close", "none")
        clicks:SetAttribute("unit", f:IsShown() and "player" or "none")
        RegisterUnitWatch(clicks)
        if ns.db and ns.db.spellDrag ~= false then
            toggle:SetAttribute("type", "macro")
            toggle:SetAttribute("macrotext",
                "/click EraUIClassicSpellBookClicks\n/click SpellbookMicroButton")
        else
            toggle:SetAttribute("type", "click")
            toggle:SetAttribute("clickbutton", clicks)
        end
        LayerPad(f.Close, 24, 24, "TOPRIGHT", -44, -25, function()
            if ns.HideSpellBook then ns.HideSpellBook() end
        end)
        local profTab = f.BookTabs and f.BookTabs[2]
        if profTab then
            LayerPad(profTab, 100, 30, "BOTTOMLEFT", 187, 64, function()
                local click = profTab:GetScript("OnClick")
                if click then click(profTab) end
            end)
        end
    end
    f.LinkLayer = LinkLayer

    local follow = CreateFrame("Frame")
    follow:RegisterEvent("PLAYER_REGEN_ENABLED")
    follow:SetScript("OnEvent", function()
        LinkLayer()
        if f.Pages and f.Pages.dirty and f.BuildPages then f.BuildPages() end
        FollowBook()
        if f:IsShown() then f:Refresh() end
    end)

    f:HookScript("OnShow", function(self) self:SetLayer(true) end)
    f:HookScript("OnHide", function(self)
        if not InCombatLockdown() then
            self:SetLayer(false)
        elseif self:LayerUp() then
            C_Timer.After(0, function()
                if InCombatLockdown() and self:LayerUp() and not self:IsShown() then self:Show() end
            end)
        end
    end)

    f.Buttons = {}
    for id = 1, SPELLS_PER_PAGE do
        f.Buttons[id] = CreateSpellButton(f, id, clicks)
    end

    f.SkillTabs = {}
    for i = 1, MAX_SKILL_TABS do
        f.SkillTabs[i] = CreateSkillTab(f, i, f.SkillTabs[i - 1])
    end

    f.TrainTab = CreateSkillTab(f, MAX_SKILL_TABS + 1, nil)
    f.TrainTab:SetNormalTexture("Interface\\Icons\\INV_Misc_Book_09")
    f.TrainTab.tooltip = "What can I train?"
    f.TrainTab:SetScript("OnClick", function(self)
        self:SetChecked(false)
        local open = SlashCmdList and SlashCmdList.WHATSTRAINING
        if type(open) ~= "function" then return end
        PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
        pcall(open, "")
        local window = _G["WhatsTrainingFloatingFrame"]
        if window and window:IsShown() and not window.fcuiDocked then
            window.fcuiDocked = true
            window:ClearAllPoints()
            window:SetPoint("TOPLEFT", f, "TOPRIGHT", -28, -12)
        end
    end)

    f.BookTabs = {}
    for i = 1, 3 do
        f.BookTabs[i] = CreateBookTab(f, i, f.BookTabs[i - 1])
    end
    LinkLayer()

    local SELECTORS = { { "p", "layer" }, { "pl", "ayer" }, { "pla", "yer" }, { "play", "er" }, { "playe", "r" }, { "player" } }
    local DYNAMIC = #SELECTORS
    local holder = CreateFrame("Frame", nil, clicks)
    holder:SetAllPoints(clicks)
    local containers, lineContainer = {}, {}
    local petContainer
    local pages = { dirty = true, built = false }
    f.Pages = pages

    local refreshQueued = false
    local function QueueRefresh()
        if refreshQueued then return end
        refreshQueued = true
        C_Timer.After(0, function()
            refreshQueued = false
            if f:IsShown() then f:Refresh() end
        end)
    end

    local function ClientCategoryTab(line, bank)
        local window = _G["PlayerSpellsFrame"]
        local client = window and window.SpellBookFrame
        local tabs = client and client.CategoryTabSystem
        if not tabs or not client.categoryMixins then return nil end
        for _, category in ipairs(client.categoryMixins) do
            local okBank, holdsBank = pcall(category.GetSpellBank, category)
            if okBank and holdsBank == bank then
                local okID, id = pcall(category.GetTabID, category)
                local match = bank ~= Enum.SpellBookSpellBank.Player
                if not match and line then
                    local okLine, holds = pcall(category.ContainsSkillLine, category, line)
                    match = (okLine and holds) or category.skillLineIndex == line
                end
                if okID and id and match then
                    local okTab, tab = pcall(tabs.GetTabButton, tabs, id)
                    if okTab and tab then return tab end
                end
            end
        end
        return nil
    end

    local linePads = {}
    local function LinePad(key, tab)
        local name = "EraUIClassicBookLine" .. key
        local pad = linePads[key]
        if not pad then
            pad = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
            pad:SetSize(1, 1)
            pad:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
            pad:EnableMouse(false)
            pad:RegisterForClicks("AnyUp", "AnyDown")
            pad:SetAttribute("useOnKeyDown", false)
            pad:SetAttribute("type", "click")
            linePads[key] = pad
        end
        if pad.tab ~= tab then
            pad:SetAttribute("clickbutton", tab)
            pad.tab = tab
        end
        return name
    end

    local padCount = 0
    local function NewPad(parent, over, width, height, enter)
        local pad = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
        padCount = padCount + 1
        pad.twinName = "EraUIClassicBookAct" .. padCount
        pad.twin = CreateFrame("Button", pad.twinName, UIParent, "SecureActionButtonTemplate")
        pad.twin:SetSize(1, 1)
        pad.twin:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
        pad.twin:EnableMouse(false)
        pad.twin:RegisterForClicks("AnyUp", "AnyDown")
        pad.twin:SetAttribute("useOnKeyDown", false)
        pad.twin:SetAttribute("attribute-name", "unit")
        pad:SetSize(width, height)
        pad:RegisterForClicks("AnyUp", "AnyDown")
        pad:SetAttribute("useOnKeyDown", false)
        pad:SetAttribute("attribute-name", "unit")
        pad:SetScript("OnMouseDown", function() if over:IsEnabled() then over:SetButtonState("PUSHED") end end)
        pad:SetScript("OnMouseUp", function() if over:IsEnabled() then over:SetButtonState("NORMAL") end end)
        pad:SetScript("OnEnter", function()
            over:LockHighlight()
            if enter then enter(over) end
        end)
        pad:SetScript("OnLeave", function()
            over:UnlockHighlight()
            GameTooltip:Hide()
        end)
        pad:SetScript("PostClick", function(self, _, down)
            if down then return end
            if InCombatLockdown() then
                if self.live then PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN) end
                return
            end
            local click = over:GetScript("OnClick")
            if click and over:IsEnabled() then click(over) end
        end)
        return pad
    end
    local function ArmPad(pad, frame, value, alsoName)
        pad.live = frame ~= nil
        pad.twin:SetAttribute("type", frame and "attribute" or nil)
        pad.twin:SetAttribute("attribute-frame", frame)
        pad.twin:SetAttribute("attribute-value", value)
        if frame then
            local text = "/click " .. pad.twinName
            if alsoName then text = text .. "\n/click " .. alsoName end
            pad:SetAttribute("type", "macro")
            pad:SetAttribute("macrotext", text)
        else
            pad:SetAttribute("type", nil)
            pad:SetAttribute("macrotext", nil)
        end
    end

    local function NewLayer(c, page)
        local layer = CreateFrame("Frame", nil, c.frame)
        layer:SetAllPoints(clicks)
        layer:SetFrameLevel(clicks:GetFrameLevel() + 10 + page * 12)
        layer.buttons = {}
        for id = 1, SPELLS_PER_PAGE do layer.buttons[id] = CreatePageButton12(layer, id) end
        layer.prev = NewPad(layer, f.PrevPage, 32, 32)
        layer.prev:SetPoint("CENTER", layer, "BOTTOMLEFT", 50, 105)
        layer.next = NewPad(layer, f.NextPage, 32, 32)
        layer.next:SetPoint("CENTER", layer, "BOTTOMLEFT", 314, 105)
        layer:SetAttribute("unit", page == 1 and "player" or "none")
        RegisterUnitWatch(layer)
        layer:HookScript("OnShow", QueueRefresh)
        layer:HookScript("OnHide", QueueRefresh)
        c.layers[page] = layer
        return layer
    end

    local function NewContainer(index)
        local c = { index = index, selector = SELECTORS[index][1], layers = {}, skillPads = {} }
        c.frame = CreateFrame("Frame", nil, holder)
        c.frame:SetAllPoints(clicks)
        c.frame:SetAttribute("useparent-unit", true)
        if SELECTORS[index][2] then c.frame:SetAttribute("unitsuffix", SELECTORS[index][2]) end
        RegisterUnitWatch(c.frame)
        c.frame:HookScript("OnShow", QueueRefresh)
        c.frame:HookScript("OnHide", QueueRefresh)
        for i = 1, MAX_SKILL_TABS do
            local pad = NewPad(c.frame, f.SkillTabs[i], 32, 32, SkillTab_OnEnter)
            pad:SetPoint("TOPLEFT", c.frame, "TOPRIGHT", -32, -65 - (i - 1) * 49)
            c.skillPads[i] = pad
        end
        c.bookPad = NewPad(c.frame, f.BookTabs[1], 100, 30)
        c.bookPad:SetPoint("CENTER", c.frame, "BOTTOMLEFT", 79, 64)
        c.petPad = NewPad(c.frame, f.BookTabs[3], 100, 30)
        c.petPad:SetPoint("CENTER", c.frame, "BOTTOMLEFT", 295, 64)
        containers[index] = c
        return c
    end

    local function Fill(c, slots, bank)
        c.slots, c.bank = slots, bank
        c.pages = math.max(1, math.ceil(#slots / SPELLS_PER_PAGE))
        for page = 1, c.pages do
            local layer = c.layers[page] or NewLayer(c, page)
            for id = 1, SPELLS_PER_PAGE do
                ArmSpell(layer.buttons[id], slots[(page - 1) * SPELLS_PER_PAGE + id], bank)
            end
        end
        for page, layer in ipairs(c.layers) do
            ArmPad(layer.prev, page > 1 and page <= c.pages and layer or nil, "none")
            ArmPad(layer.next, page < c.pages and c.layers[page + 1] or nil, "player")
            if page > c.pages then
                layer:SetAttribute("unit", "none")
                layer:Hide()
            end
        end
    end

    local function ArmTabs(c, lines)
        local player = c.kind ~= "pet"
        local lend = ns.db and ns.db.spellDrag ~= false
        local function TabName(line, bank, key)
            if not lend then return nil end
            local tab = ClientCategoryTab(line, bank)
            return tab and LinePad(key, tab) or nil
        end
        for i = 1, MAX_SKILL_TABS do
            local target = player and lines[i] and lineContainer[lines[i]]
            local pad = c.skillPads[i]
            local also = target and lines[i] and TabName(lines[i], Enum.SpellBookSpellBank.Player, "L" .. lines[i]) or nil
            ArmPad(pad, target and holder or nil, target and target.selector or nil, also)
            pad:SetShown(target and true or false)
        end
        local first = lines[1] and lineContainer[lines[1]]
        ArmPad(c.bookPad, not player and first and holder or nil, first and first.selector or nil,
            (not player and first and lines[1]) and TabName(lines[1], Enum.SpellBookSpellBank.Player, "L" .. lines[1]) or nil)
        c.bookPad:SetShown(not player and first ~= nil)
        ArmPad(c.petPad, player and petContainer and holder or nil, petContainer and petContainer.selector or nil,
            (player and petContainer) and TabName(nil, Enum.SpellBookSpellBank.Pet, "Pet") or nil)
        c.petPad:SetShown(player and petContainer ~= nil)
    end

    function f.BuildPages()
        if InCombatLockdown() or not clicks.fcuiLinked then
            pages.dirty = true
            return
        end
        pages.dirty = false
        local lines = {}
        local n = C_SpellBook.GetNumSpellBookSkillLines() or 0
        for i = 1, n do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(i)
            if info and not info.shouldHide and (info.offSpecID or 0) == 0 and #lines < MAX_SKILL_TABS then lines[#lines + 1] = i end
        end
        local hasPet = PetSpellCount() > 0
        local room = DYNAMIC - 1 - (hasPet and 1 or 0)
        wipe(lineContainer)
        petContainer = nil
        local index = 0
        for i, line in ipairs(lines) do
            if i <= room then
                index = index + 1
                local c = containers[index] or NewContainer(index)
                c.kind, c.line, c.content = "line", line, nil
                Fill(c, SlotsFor(BANK_PLAYER, line, ""), BANK_PLAYER)
                lineContainer[line] = c
            end
        end
        if hasPet then
            index = index + 1
            local c = containers[index] or NewContainer(index)
            c.kind, c.line, c.content = "pet", nil, nil
            Fill(c, SlotsFor(BANK_PET, state.line, ""), BANK_PET)
            petContainer = c
        end
        for i = index + 1, DYNAMIC - 1 do
            if containers[i] then containers[i].kind = nil end
        end
        local dyn = containers[DYNAMIC] or NewContainer(DYNAMIC)
        dyn.kind, dyn.content = "dyn", nil
        pages.lines = lines
        for _, c in pairs(containers) do
            if c.kind then ArmTabs(c, lines) end
        end
        pages.built = true
        if f.ApplyPages then f.ApplyPages() end
    end

    local function ContainerFor()
        if not pages.built then return nil end
        if state.search ~= "" then return containers[DYNAMIC], "search:" .. tostring(state.bank) .. ":" .. state.search:lower() end
        if state.bank == BANK_PET then return petContainer end
        if lineContainer[state.line] then return lineContainer[state.line] end
        return containers[DYNAMIC], "line:" .. tostring(state.line)
    end

    local function ReadPages()
        if not pages.built then return end
        local current
        for _, c in pairs(containers) do
            if c.kind and c.frame:IsShown() then current = c end
        end
        if not current then return end
        if current.kind == "line" then
            state.bank, state.line, state.search = BANK_PLAYER, current.line, ""
        elseif current.kind == "pet" then
            state.bank, state.search = BANK_PET, ""
        end
        local page = 1
        for i = 1, current.pages or 1 do
            if current.layers[i] and current.layers[i]:IsShown() then page = i end
        end
        SetPage(page)
    end

    local function ApplyPages()
        local c, content = ContainerFor()
        if not c then return nil end
        if c.kind == "dyn" and c.content ~= content then
            c.content = content
            c.line = state.line
            Fill(c, SlotsFor(state.bank, state.line, state.search), state.bank)
            ArmTabs(c, pages.lines or {})
        end
        holder:SetAttribute("unit", c.selector)
        for _, other in pairs(containers) do other.frame:SetShown(other == c) end
        local page = math.min(CurrentPage(), c.pages)
        for i, layer in ipairs(c.layers) do
            local up = i <= page
            layer:SetAttribute("unit", up and "player" or "none")
            layer:SetShown(up)
        end
        return c
    end
    f.ReadPages, f.ApplyPages, f.ContainerFor = ReadPages, ApplyPages, ContainerFor

    f:BuildPages()

    f:SetScript("OnMouseWheel", Book_OnMouseWheel)
    f:HookScript("OnShow", function(self)
        PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
        self:Refresh()
        ns.RefreshMicroButtons()
    end)
    f:HookScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
        ns.RefreshMicroButtons()
    end)
    if ns.MicroButtonFollows then
        for _, name in ipairs({ "SpellbookMicroButton", "PlayerSpellsMicroButton" }) do
            ns.MicroButtonFollows(_G[name], function() return f:IsShown() end)
        end
    end
    for _, event in ipairs({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE", "SPELL_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED", "PET_BAR_UPDATE", "PLAYER_ENTERING_WORLD" }) do
        pcall(f.RegisterEvent, f, event)
    end
    pcall(f.RegisterUnitEvent, f, "UNIT_PET", "player")
    pcall(f.RegisterEvent, f, "PLAYER_REGEN_DISABLED")
    pcall(f.RegisterEvent, f, "SPELL_UPDATE_USABLE")
    local rebuildQueued = false
    f:SetScript("OnEvent", function(self, event)
        if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_USABLE" then
            if self:IsShown() then
                for _, btn in ipairs(self.Buttons) do
                    UpdateCooldown(btn)
                    UpdateUsable(btn)
                end
            end
            return
        end
        if event == "PLAYER_REGEN_DISABLED" then
            if self:IsShown() then self:Refresh() end
            return
        end
        if event ~= "PLAYER_REGEN_ENABLED" or self.Pages.dirty then self.Pages.dirty = true end
        if rebuildQueued then return end
        rebuildQueued = true
        C_Timer.After(0.1, function()
            rebuildQueued = false
            if self.Pages.dirty and not InCombatLockdown() then self:BuildPages() end
            if self:IsShown() then self:Refresh() end
        end)
    end)

    function f:UpdateSkillTabs()
        local shown = 0
        local selectedVisible = false
        local firstLine
        if state.bank == BANK_PLAYER then
            local n = C_SpellBook.GetNumSpellBookSkillLines() or 0
            for i = 1, n do
                local info = C_SpellBook.GetSpellBookSkillLineInfo(i)
                local offSpec = info and (info.offSpecID or 0) ~= 0
                if info and not info.shouldHide and not offSpec and shown < MAX_SKILL_TABS then
                    shown = shown + 1
                    local tab = self.SkillTabs[shown]
                    tab.line = i
                    tab.tooltip = info.name
                    tab:SetNormalTexture(info.iconID or "")
                    tab:SetChecked(state.line == i)
                    tab:Show()
                    firstLine = firstLine or i
                    if state.line == i then selectedVisible = true end
                end
            end
        end
        for i = shown + 1, MAX_SKILL_TABS do self.SkillTabs[i]:Hide() end
        local train = self.TrainTab
        if train then
            local there = state.bank == BANK_PLAYER and SlashCmdList and type(SlashCmdList.WHATSTRAINING) == "function"
            train:SetShown(there and true or false)
            if there then
                train:ClearAllPoints()
                if shown > 0 then
                    train:SetPoint("TOPLEFT", self.SkillTabs[shown], "BOTTOMLEFT", 0, -17)
                else
                    train:SetPoint("TOPLEFT", self, "TOPRIGHT", -32, -65)
                end
            end
        end
        if state.bank == BANK_PLAYER and not selectedVisible and firstLine then
            state.line = firstLine
            for i = 1, shown do self.SkillTabs[i]:SetChecked(self.SkillTabs[i].line == firstLine) end
        end
    end

    function f:UpdateBookTabs()
        local petCount, token = PetSpellCount()
        local tab1, profTab, tab2 = self.BookTabs[1], self.BookTabs[2], self.BookTabs[3]
        tab1.bank = BANK_PLAYER
        tab1:SetText(SPELLBOOK)
        tab1:Show()
        profTab.professions = true
        profTab:SetText(TRADE_SKILLS or "Professions")
        profTab:Show()
        local petTitle
        if petCount > 0 then
            petTitle = (token and _G["PET_TYPE_" .. token]) or PET
            tab2.bank = BANK_PET
            tab2:SetText(petTitle)
            tab2:Show()
        else
            tab2:Hide()
            if state.bank == BANK_PET then state.bank = BANK_PLAYER end
        end
        tab1:SetEnabled(state.bank ~= BANK_PLAYER)
        tab2:SetEnabled(state.bank ~= BANK_PET)
        self.Title:SetText(state.bank == BANK_PET and petTitle or SPELLBOOK)
    end

    function f:UpdatePages()
        local pages = PageCount()
        local page = math.min(CurrentPage(), pages)
        SetPage(page)
        self.PageText:SetFormattedText(PAGE_NUMBER, page)
        self.PrevPage:SetEnabled(page > 1)
        self.NextPage:SetEnabled(page < pages)
    end

    function f:Refresh()
        if not active then return end
        if self.Ranks then
            self.Ranks:SetChecked(not (ns.db and ns.db.spellBookTopRank == true))
            self.Ranks:SetShown(state.bank ~= BANK_PET)
        end
        local fight = InCombatLockdown()
        if fight then
            self.ReadPages()
        elseif self.Pages.dirty then
            self:BuildPages()
        end
        if self.Search then
            pcall(self.Search.SetEnabled, self.Search, not fight)
            if fight and self.Search:HasFocus() then self.Search:ClearFocus() end
        end
        self:UpdateBookTabs()
        self:UpdateSkillTabs()
        local c, content = self.ContainerFor()
        local usable = c and (not fight or (c.slots and (c.kind ~= "dyn" or c.content == content)))
        if usable then
            if not fight then
                self:UpdatePagesFor(c, content)
                c = self.ApplyPages() or c
            end
            wipe(state.slots)
            for i, index in ipairs(c.slots) do state.slots[i] = index end
            viewLive = true
        else
            CollectSlots()
            viewLive = not fight
        end
        self:UpdatePages()
        for _, btn in ipairs(self.Buttons) do UpdateButton(btn) end
    end

    function f.UpdatePagesFor(_, c, content)
        local slots = c.slots
        if c.kind == "dyn" and c.content ~= content then slots = SlotsFor(state.bank, state.line, state.search) end
        local most = math.max(1, math.ceil(#slots / SPELLS_PER_PAGE))
        if CurrentPage() > most then SetPage(most) end
    end

    return f
end

local wanted = false
local closedInFight = false

local function ShowClicks(on)
    if not book then return end
    book:SetLayer(on and book:IsShown())
end

local function Show()
    if not book then book = CreateBook() end
    closedInFight = false
    book:SetAlpha(1)
    if InCombatLockdown() and not book:IsShown() and book:IsProtected() then
        wanted = true
        return
    end
    book:Show()
    ShowClicks(true)
    wanted = false
end

local function Hide()
    wanted = false
    if not book then return end
    if InCombatLockdown() and book:LayerUp() and book:IsShown() then return end
    ShowClicks(false)
    if InCombatLockdown() and book:IsProtected() then
        closedInFight = true
        book:SetAlpha(0)
        return
    end
    closedInFight = false
    book:SetAlpha(1)
    book:Hide()
end

local ghost = { at = {}, points = {} }
local GHOST_X = 4000

local function Note(line)
    if ghost.said == line then return end
    ghost.said = line
    ns.Persist("spelldrag: " .. line)
end

local function DragOn()
    return active and ns.db and ns.db.spellDrag ~= false
end
ns.SpellBookLendsButtons = DragOn

local function GhostWindow() return _G["PlayerSpellsFrame"] end

local function GhostBook()
    local window = GhostWindow()
    return window and window.SpellBookFrame
end

local function Deafen(window)
    if InCombatLockdown() then return end
    local skip = window.SpellBookFrame and window.SpellBookFrame.PagedSpellsFrame
    local hushed = ghost.hushed
    if not hushed then
        hushed = {}
        ghost.hushed = hushed
    end
    local function Walk(frame)
        if frame == skip then return end
        if frame.IsMouseEnabled and frame:IsMouseEnabled() then
            hushed[#hushed + 1] = frame
            frame:EnableMouse(false)
        end
        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do Walk(child) end
        end
    end
    Walk(window)
end

local function Unhush()
    if InCombatLockdown() then return end
    for _, frame in ipairs(ghost.hushed or {}) do
        if frame.EnableMouse then pcall(frame.EnableMouse, frame, true) end
    end
    ghost.hushed = nil
end

local function QuietGhost(window)
    if window:GetAlpha() ~= 0 then window:SetAlpha(0) end
    if InCombatLockdown() then return end
    local now = GetTime()
    if now - (ghost.hushAt or 0) > 0.3 then
        ghost.hushAt = now
        Deafen(window)
    end
    pcall(window.SetAttribute, window, "UIPanelLayout-width", 1)
    local point, _, _, x = window:GetPoint(1)
    if window:GetNumPoints() ~= 1 or point ~= "TOPLEFT" or x ~= GHOST_X then
        window:ClearAllPoints()
        window:SetPoint("TOPLEFT", UIParent, "TOPRIGHT", GHOST_X, 0)
    end
end

local function GhostItems()
    local client = GhostBook()
    local paged = client and client:IsShown() and client.PagedSpellsFrame
    if not paged or not paged.EnumerateFrames then return nil end
    local map, any, total, marked = {}, false, 0, 0
    for _, item in paged:EnumerateFrames() do
        if item.HasValidData and item:HasValidData() and item.Button and item.slotIndex then
            total = total + 1
            if issecurevariable(item, "slotIndex") and issecurevariable(item, "spellBank") then
                map[item.slotIndex .. ":" .. tostring(item.spellBank)] = item
                any = true
            else
                marked = marked + 1
            end
        end
    end
    if not any then Note("the client book holds " .. total .. " buttons, " .. marked .. " of them marked by an addon") end
    return any and map or nil
end

local function Unpark(item)
    local kept = ghost.points[item]
    if not kept then return end
    ghost.points[item] = nil
    ghost.at[item] = nil
    if kept.parent then item:SetParent(kept.parent) end
    item:SetAlpha(kept.alpha or 1)
    item:SetFrameStrata(kept.strata)
    item:SetScale(kept.scale)
    item:ClearAllPoints()
    if kept.point then item:SetPoint(kept.point, kept.rel, kept.relPoint, kept.x, kept.y) end
end

local function UnparkAll()
    for item in pairs(ghost.points) do Unpark(item) end
end

local function ParkGhost()
    if not book or not book:IsShown() or not DragOn() then return UnparkAll() end
    local map = GhostItems()
    if not map then return UnparkAll() end
    local taken, laid, none = {}, 0, 0
    for _, btn in ipairs(book.Buttons or {}) do
        local item = btn.slot and btn:IsVisible() and map[btn.slot .. ":" .. tostring(state.bank)]
        if btn.slot and btn:IsVisible() then
            if item then laid = laid + 1 else none = none + 1 end
        end
        if item then
            taken[item] = true
            local face = item.Button
            if not ghost.points[item] then
                local point, rel, relPoint, x, y = item:GetPoint(1)
                ghost.points[item] = { point = point, rel = rel, relPoint = relPoint, x = x, y = y,
                    parent = item:GetParent(), alpha = item:GetAlpha(),
                    scale = item:GetScale() or 1, strata = item:GetFrameStrata() }
                item:SetParent(UIParent)
                item:SetAlpha(0)
                item:SetFrameStrata("FULLSCREEN_DIALOG")
            end
            local want = (btn:GetWidth() or 0) * btn:GetEffectiveScale()
            local have = (face:GetWidth() or 0) * face:GetEffectiveScale()
            if want > 0 and have > 0 and math.abs(want - have) > 0.5 then
                item:SetScale((item:GetScale() or 1) * want / have)
            end
            local at = ghost.at[item]
            if not at or at.btn ~= btn then
                ghost.at[item] = { btn = btn, x = 0, y = 0 }
                item:ClearAllPoints()
                item:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
            else
                local scale = item:GetEffectiveScale()
                if scale and scale > 0 and face:GetLeft() and btn:GetLeft() then
                    local dx = (btn:GetLeft() * btn:GetEffectiveScale() - face:GetLeft() * face:GetEffectiveScale()) / scale
                    local dy = (btn:GetTop() * btn:GetEffectiveScale() - face:GetTop() * face:GetEffectiveScale()) / scale
                    if math.abs(dx) > 0.2 or math.abs(dy) > 0.2 then
                        at.x, at.y = at.x + dx, at.y + dy
                        item:ClearAllPoints()
                        item:SetPoint("TOPLEFT", btn, "TOPLEFT", at.x, at.y)
                    end
                end
            end
        end
    end
    for item in pairs(ghost.points) do
        if not taken[item] then Unpark(item) end
    end
    Note("lent " .. laid .. " of " .. (laid + none) .. " spells, bank " .. tostring(state.bank))
end

local function FollowGhost()
    local window = GhostWindow()
    if not window then return end
    local client = GhostBook()
    local live = client ~= nil and client:IsShown()
    if not DragOn() then
        UnparkAll()
        return
    end
    if window:GetAlpha() ~= 0 then window:SetAlpha(0) end
    if not window:IsShown() then Note("the client never opened its window") end
    if window:IsShown() and not live then
        UnparkAll()
        Unhush()
        if window:GetAlpha() == 0 then window:SetAlpha(1) end
        return
    end
    if not live then
        UnparkAll()
        return
    end
    QuietGhost(window)
    if not ghost.wired and book and book.BuildPages and not InCombatLockdown() then
        ghost.wired = true
        ns.SafeCall(book.BuildPages)
    end
    if book and book:IsShown() then
        ParkGhost()
    else
        UnparkAll()
        if not InCombatLockdown() and HideUIPanel then
            pcall(HideUIPanel, window)
        end
    end
end

local dragWatch
local function StartDragWatch()
    if dragWatch then return end
    dragWatch = CreateFrame("Frame")
    dragWatch:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 0.05 then return end
        self.since = 0
        if not active then return end
        ns.SafeCall(FollowGhost)
    end)
end

local waiting = CreateFrame("Frame")
waiting:RegisterEvent("PLAYER_REGEN_ENABLED")
waiting:RegisterEvent("PLAYER_REGEN_DISABLED")
waiting:SetScript("OnEvent", function(_, event)
    if not active then return end
    if event == "PLAYER_REGEN_DISABLED" then
        local open = book and book:IsShown() and book:GetAlpha() > 0
        if book and not open then book:SetLayer(false) end
        return
    end
    if closedInFight and book then
        closedInFight = false
        book:SetAlpha(1)
        book:Hide()
        ShowClicks(false)
        return
    end
    if wanted then
        Show()
    elseif book then
        ShowClicks(book:IsShown())
    end
end)

local function Toggle()
    if book and book:IsShown() and not closedInFight then
        Hide()
    else
        Show()
    end
end

local originals = {}

local function Step(fn)
    if InCombatLockdown() and C_Timer and C_Timer.After then
        C_Timer.After(0, fn)
    else
        fn()
    end
end

local wrapped = {}
local function Wrap(key, replacement)
    if not PlayerSpellsUtil or type(PlayerSpellsUtil[key]) ~= "function" or originals[key] then return end
    local orig = PlayerSpellsUtil[key]
    originals[key] = orig
    wrapped[key] = function(...)
        local handled = replacement(...)
        if handled then return end
        return orig(...)
    end
end

local tookOver = false
local function TakeOver(on)
    if not PlayerSpellsUtil then return end
    if on == tookOver then return end
    tookOver = on
    for key, orig in pairs(originals) do
        PlayerSpellsUtil[key] = on and wrapped[key] or orig
    end
end

local microClick
local tookButton = false
local function TakeButton(on)
    local button = _G["SpellbookMicroButton"]
    if not button or not button.GetScript then return end
    if on == tookButton then return end
    tookButton = on
    if on and ns.db and ns.db.spellDrag ~= false then
        if microClick then button:SetScript("OnClick", microClick) end
    elseif on then
        if microClick == nil then microClick = button:GetScript("OnClick") or false end
        button:SetScript("OnClick", function()
            if KeybindFrames_InQuickKeybindMode and KeybindFrames_InQuickKeybindMode() then return end
            Step(Toggle)
        end)
    elseif microClick then
        button:SetScript("OnClick", microClick)
    end
end

local BIND_NAME = "EraUIClassicSpellBookBind"
local bindButton

local boundKeys = {}
local function UpdateBinding()
    if not bindButton or InCombatLockdown() then return end
    ClearOverrideBindings(bindButton)
    wipe(boundKeys)
    if not active then return end
    for _, binding in ipairs({ "TOGGLESPELLBOOK", "TOGGLEPLAYERSPELLS" }) do
        local key, second = GetBindingKey(binding)
        for _, k in ipairs({ key, second }) do
            if k then
                SetOverrideBindingClick(bindButton, true, k, BIND_NAME, "LeftButton")
                boundKeys[#boundKeys + 1] = binding .. "=" .. k
            end
        end
    end
end

function ns.SpellBookBindInfo()
    return string.format("keys %s; book built %s; book protected %s",
        (#boundKeys > 0 and table.concat(boundKeys, ", ") or "none"),
        tostring(book ~= nil),
        tostring(book and book.IsProtected and book:IsProtected()))
end

local function Prebuild()
    if book or not active or InCombatLockdown() then return end
    book = CreateBook()
end

local function Init()
    bindButton = CreateFrame("Button", BIND_NAME, UIParent, "SecureActionButtonTemplate")
    bindButton:RegisterForClicks("AnyDown", "AnyUp")
    bindButton:SetAttribute("useOnKeyDown", false)
    bindButton:SetScript("PostClick", function(_, _, down)
        if not active or down then return end
        if ns.db and ns.db.spellDrag ~= false then
            local window = _G["PlayerSpellsFrame"]
            if window and window:GetAlpha() ~= 0 then window:SetAlpha(0) end
        end
        local layer = book and book.Clicks
        if layer and layer.fcuiLinked then
            if book:LayerUp() then
                Show()
            elseif book:IsShown() then
                Hide()
            end
        else
            Toggle()
        end
    end)
    bindButton:RegisterEvent("UPDATE_BINDINGS")
    bindButton:RegisterEvent("PLAYER_REGEN_ENABLED")
    bindButton:RegisterEvent("PLAYER_ENTERING_WORLD")
    bindButton:SetScript("OnEvent", function(_, event)
        UpdateBinding()
        if event ~= "UPDATE_BINDINGS" then ns.SafeCall(Prebuild) end
    end)
    Wrap("ToggleSpellBookFrame", function() Step(Toggle); return true end)
    Wrap("OpenToSpellBookTab", function() Step(Show); return true end)
    Wrap("OpenToSpellBookTabAtSpell", function() Step(Show); return true end)
    Wrap("OpenToSpellBookTabAtCategory", function() Step(Show); return true end)
end

local function Apply()
    active = true
    TakeOver(true)
    TakeButton(true)
    UpdateBinding()
    if ns.MapPad and bindButton then
        ns.MapPad(_G["SpellbookMicroButton"], nil, nil, bindButton, function() return active end)
    end
    StartDragWatch()
    if IsLoggedIn and IsLoggedIn() then ns.SafeCall(Prebuild) end
end

local function Restore()
    active = false
    TakeOver(false)
    TakeButton(false)
    UpdateBinding()
    if book and book:IsShown() then Hide() end
    ns.SafeCall(UnparkAll)
    ns.SafeCall(Unhush)
    local window = GhostWindow()
    if window then window:SetAlpha(1) end
end

ns.NewBookTab = CreateBookTab
ns.NewSideTab = CreateSkillTab
function ns.SpellBookActive() return active end
function ns.SpellBookBank() return state.bank end
function ns.HideSpellBook() Hide() end
function ns.SpellBookPetTitle()
    local petCount, token = PetSpellCount()
    if petCount > 0 then return (token and _G["PET_TYPE_" .. token]) or PET end
end
function ns.ShowSpellBookBank(pet)
    if not active then return false end
    state.bank = pet and BANK_PET or BANK_PLAYER
    Show()
    if book and book:IsShown() then book:Refresh() end
    return true
end

function ns.ToggleSpellBook()
    if not active then return false end
    Toggle()
    return true
end

ns.RegisterModule("spellBook", { init = Init, apply = Apply, restore = Restore })

local function RelistBook()
    if not book then return end
    book.Pages.dirty = true
    if not InCombatLockdown() then book:BuildPages() end
    if book:IsShown() and book.Refresh then book:Refresh() end
end
ns.RegisterModule("spellBookTopRank", { apply = RelistBook, restore = RelistBook })

ns.RegisterModule("spellBookSearch", {
    apply = function() if book and book.Search then book.Search:Show() end end,
    restore = function()
        if book and book.Search then
            book.Search:SetText("")
            book.Search:Hide()
        end
    end,
})
