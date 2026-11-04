-- The spellbook's secure layer (EraUIClassicSpellBookClicks). In a fight the
-- game lets no addon show, hide, move or re-arm a secure button, yet the
-- book must open, close, turn pages, switch tabs and cast. So everything
-- clickable is made out of a fight, and in a fight only secure clicks
-- change what shows: each click sets a "unit" attribute, and the game's
-- unit watch shows exactly the frames whose unit then reads "player".
--   * the layer: up (unit "player") while the book is open;
--   * the chooser: its unit picks one of six containers (each adds its own
--     suffix to the chooser's value, so only one spells "player"); five
--     hold spell lines or the pet's spells, the sixth whatever else is
--     asked for (a search, a line without a container of its own);
--   * each container: page sets stacked page over page, pads over the
--     school tabs, the Spellbook tab and the pet tab;
--   * each page set: twelve secure spell buttons and two page pads.
-- A pad clicks a named helper (a /click macro) that sets one attribute.
-- The key button (EraUIClassicSpellBookBind) is what the micro button's pad
-- clicks, and a key the player sets on Classic Spellbook (Bindings.xml):
-- the key's down click does nothing, its up click acts, so a press toggles
-- once. All of it is made and armed out of a fight only.
local _, EraUI = ...
local Look = EraUI.Look
local S = Look.Spells

-- Each container's piece of "player": the chooser's value and its suffix.
local VALUES = { { "p", "layer" }, { "pl", "ayer" }, { "pla", "yer" }, { "play", "er" }, { "playe", "r" }, { "player" } }
local DYNAMIC = 6
S.boxes = {}

local padInfo = Look.Weak()   -- pad: { helper name, helper, button under it, tip, armed }
local spellOf = Look.Weak()   -- page spell button: { slot, pet, passive }
S.spellOf = spellOf
local steps = 0

local function Secure(kind, parent, name, width, height)
    local button = CreateFrame(kind, name, parent, "SecureActionButtonTemplate")
    button:SetSize(width, height)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("useOnKeyDown", false)
    return button
end

-- Out of sight and out of reach: only clicked by name (/click) or by code.
local function Tucked(name)
    local button = Secure("Button", UIParent, name, 1, 1)
    Look.Pin(button, "TOPLEFT", UIParent, "TOPLEFT", -500, 500)
    button:EnableMouse(false)
    return button
end

local function Watched(frame)
    if type(RegisterUnitWatch) == "function" then RegisterUnitWatch(frame) end
end

-- One refresh of the book on the next frame, however many frames the
-- secure side shows or hides before it.
local booked = false
local function Changed()
    if booked then return end
    booked = true
    S.NextFrame(function()
        booked = false
        if S.book and S.book:IsShown() then S.Refresh() end
    end)
end

---------------------------------------------------------------------------
-- Pads: the button under them is mirrored (pressed, glow, its tooltip)
---------------------------------------------------------------------------

local function PadDown(pad)
    local under = padInfo[pad] and padInfo[pad].under
    if under and under:IsEnabled() then under:SetButtonState("PUSHED") end
end

local function PadUp(pad)
    local under = padInfo[pad] and padInfo[pad].under
    if under then under:SetButtonState("NORMAL") end
end

local function PadEnter(pad)
    local info = padInfo[pad]
    if not info then return end
    if info.under then info.under:LockHighlight() end
    local tip = type(info.tip) == "function" and info.tip()
    if type(tip) == "string" and tip ~= "" then Look.ShowTip(pad, "RIGHT", { { tip, 1, 1, 1 } }) end
end

local function PadLeave(pad)
    local info = padInfo[pad]
    if info and info.under then info.under:UnlockHighlight() end
    Look.HideTip(pad)
end

-- After a released click: out of a fight the button under it runs its own
-- click (so the book follows at once); in a fight a page-turn sound.
local function PadAfter(pad, _, down)
    if down then return end
    local info = padInfo[pad]
    if not info then return end
    if Look.InFight() then
        if info.armed then S.Sound("IG_ABILITY_PAGE_TURN") end
    elseif info.under and info.under:IsEnabled() then
        info.under:Click()
    end
end

local function Mirror(pad, under, tip)
    padInfo[pad] = padInfo[pad] or {}
    padInfo[pad].under, padInfo[pad].tip = under, tip
    pad:SetScript("OnMouseDown", PadDown)
    pad:SetScript("OnMouseUp", PadUp)
    pad:SetScript("OnEnter", PadEnter)
    pad:SetScript("OnLeave", PadLeave)
end

-- A pad that steps a page or a tab: its own named helper does the setting.
local function StepPad(parent, width, height, under, tip)
    local pad = Secure("Button", parent, nil, width, height)
    steps = steps + 1
    local name = "EraUISpellBookStep" .. steps
    padInfo[pad] = { helperName = name, helper = Tucked(name), armed = false }
    Mirror(pad, under, tip)
    pad:SetScript("PostClick", PadAfter)
    return pad
end

-- Armed: a click sets target's unit to value (and, with Combat Spell
-- Dragging, also clicks the game's matching tab). Disarmed: nothing.
function S.Arm(pad, target, value, extra)
    local info = padInfo[pad]
    if not info then return end
    if not target then
        pad:SetAttribute("type", nil)
        pad:SetAttribute("macrotext", nil)
        info.armed = false
        return
    end
    local helper = info.helper
    helper:SetAttribute("type", "attribute")
    helper:SetAttribute("attribute-frame", target)
    helper:SetAttribute("attribute-name", "unit")
    helper:SetAttribute("attribute-value", value)
    local macro = "/click " .. info.helperName
    if extra then macro = macro .. "\n/click " .. extra end
    pad:SetAttribute("type", "macro")
    pad:SetAttribute("macrotext", macro)
    info.armed = true
end

function S.PadArmed(pad)
    return padInfo[pad] ~= nil and padInfo[pad].armed == true
end

---------------------------------------------------------------------------
-- Page spell buttons
---------------------------------------------------------------------------

local function SpellTip(button)
    local held = spellOf[button]
    if not held then return end
    local fetch = C_TooltipInfo and C_TooltipInfo.GetSpellBookItem
    local info = S.Info(held.slot, held.pet)
    local fallback = info and S.Text(info.name) and { { S.Text(info.name), 1, 1, 1 } } or nil
    Look.ShowDataTip(button, "RIGHT", fetch, fallback, held.slot, S.Bank(held.pet))
end

local function SpellDrag(button)
    local held = spellOf[button]
    if not held or held.passive or Look.InFight() then return end
    S.Call("PickupSpellBookItem", held.slot, S.Bank(held.pet))
end

local function SpellLink(button, _, down)
    if down then return end
    local held = spellOf[button]
    if not held or type(IsModifiedClick) ~= "function" or not IsModifiedClick("CHATLINK") then return end
    Look.ChatLink((S.Call("GetSpellBookItemLink", held.slot, S.Bank(held.pet))))
end

local function SpellButton(set, i)
    local button = Secure("Button", set, nil, S.SLOT, S.SLOT)
    local x, y = S.SlotSpot(i)
    Look.Pin(button, "TOPLEFT", set, "TOPLEFT", x, y)
    Look.StateArt(button, "Pushed", "slotPushed")
    local glow = Look.StateArt(button, "Highlight", "slotHighlight")
    if glow then glow:SetBlendMode("ADD") end
    button:RegisterForDrag("LeftButton")
    button:SetAttribute("shift-type1", "")
    button:SetScript("OnEnter", SpellTip)
    button:SetScript("OnLeave", function(self) Look.HideTip(self) end)
    button:SetScript("OnDragStart", SpellDrag)
    button:SetScript("PostClick", SpellLink)
    return button
end

-- The spell a button casts: on the pet's pages the spell first, else the
-- action; none for an empty slot, a passive, a flyout or a hidden id.
local function SpellId(info, pet)
    local first, second = info.actionID, info.spellID
    if pet then first, second = info.spellID, info.actionID end
    if Look.Secret(first) or Look.Secret(second) then return nil end
    return Look.Number(first) or Look.Number(second)
end

local function ArmSpell(button, slot, pet)
    local info = slot and S.Info(slot, pet)
    local passive = info ~= nil and S.Yes(info.isPassive)
    local id = info and not passive and not S.Skipped(info) and SpellId(info, pet)
    spellOf[button] = info and { slot = slot, pet = pet, passive = passive } or nil
    button:SetAttribute("type1", id and "spell" or nil)
    button:SetAttribute("spell", id or nil)
end

---------------------------------------------------------------------------
-- Containers and their page sets
---------------------------------------------------------------------------

local function PageSet(box, p)
    local set = CreateFrame("Frame", nil, box.frame)
    set:SetSize(S.WIDTH, S.HEIGHT)
    set:SetAllPoints(S.layer)
    set:SetFrameLevel((Look.Number(S.layer:GetFrameLevel()) or 1) + 10 + p * 12)
    set:SetAttribute("unit", p == 1 and "player" or "none")
    Watched(set)
    set:SetScript("OnShow", Changed)
    set:SetScript("OnHide", Changed)
    local page = { frame = set, buttons = {} }
    for i = 1, S.PER_PAGE do page.buttons[i] = SpellButton(set, i) end
    page.prev = StepPad(set, 32, 32, S.book.PrevPage)
    Look.Pin(page.prev, "CENTER", set, "BOTTOMLEFT", 50, 105)
    page.next = StepPad(set, 32, 32, S.book.NextPage)
    Look.Pin(page.next, "CENTER", set, "BOTTOMLEFT", 314, 105)
    box.sets[p] = page
    return page
end

local function LineName(i)
    return function()
        local line = S.Lines()[i]
        return line and line.name or nil
    end
end

local function Container(index)
    local frame = CreateFrame("Frame", nil, S.chooser)
    frame:SetSize(S.WIDTH, S.HEIGHT)
    frame:SetAllPoints(S.layer)
    frame:SetAttribute("useparent-unit", true)
    if VALUES[index][2] then frame:SetAttribute("unitsuffix", VALUES[index][2]) end
    Watched(frame)
    frame:SetScript("OnShow", Changed)
    frame:SetScript("OnHide", Changed)
    local box = { frame = frame, value = VALUES[index][1], index = index, sets = {}, tabPads = {}, list = {} }
    for i = 1, 8 do
        local pad = StepPad(frame, 32, 32, S.skillTabs[i], LineName(i))
        Look.Pin(pad, "TOPLEFT", frame, "TOPRIGHT", -32, -65 - (i - 1) * 49)
        box.tabPads[i] = pad
    end
    box.bookPad = StepPad(frame, 100, 30, S.bookTabs[1])
    Look.Pin(box.bookPad, "CENTER", frame, "BOTTOMLEFT", 79, 64)
    box.petPad = StepPad(frame, 100, 30, S.bookTabs[3])
    Look.Pin(box.petPad, "CENTER", frame, "BOTTOMLEFT", 295, 64)
    S.boxes[index] = box
end

-- A container given a list: a page set per page (made as needed, never
-- destroyed), every spell button armed, the page pads armed to step to
-- the next set or back off this one; sets past the list put away.
local function Fill(box, list, pet)
    box.list, box.pet = list, pet
    local pages = S.PageCount(list)
    for p = 1, pages do
        if not box.sets[p] then PageSet(box, p) end
    end
    for p, page in ipairs(box.sets) do
        if p <= pages then
            for i = 1, S.PER_PAGE do ArmSpell(page.buttons[i], list[(p - 1) * S.PER_PAGE + i], pet) end
            S.Arm(page.next, p < pages and box.sets[p + 1].frame or nil, "player")
            S.Arm(page.prev, p > 1 and page.frame or nil, "none")
        else
            page.frame:SetAttribute("unit", "none")
            page.frame:Hide()
        end
    end
end

-- Every container but the pet's: a school tab pad for each line with a
-- container of its own, and the pet pad while the pet has one. The pet's:
-- the Spellbook tab pad back to the first line.
local function ArmTabs(box)
    local onPet = box.use == "pet"
    for i, pad in ipairs(box.tabPads) do
        local target = not onPet and S.lineBox[i]
        S.Arm(pad, target and S.chooser or nil, target and target.value, target and S.ClientTab and S.ClientTab(i))
        Look.Shown(pad, target and true or false)
    end
    local first = onPet and S.lineBox[1]
    S.Arm(box.bookPad, first and S.chooser or nil, first and first.value)
    Look.Shown(box.bookPad, first and true or false)
    local pet = not onPet and S.petBox
    S.Arm(box.petPad, pet and S.chooser or nil, pet and pet.value, pet and S.ClientTab and S.ClientTab("pet"))
    Look.Shown(box.petPad, pet and true or false)
end

---------------------------------------------------------------------------
-- Building the pages, choosing what shows
---------------------------------------------------------------------------

-- Out of a fight only, once the layer is wired; otherwise marked dirty.
function S.BuildPages()
    if Look.InFight() or not S.linked then
        S.dirty = true
        return
    end
    S.dirty = false
    local lines = S.Lines()
    local pets = S.PetSpells()
    local room = pets > 0 and 4 or 5
    S.lineBox, S.petBox = {}, nil
    local next = 1
    for i = 1, math.min(room, #lines) do
        local box = S.boxes[next]
        box.use, box.line = "line", i
        Fill(box, S.ListFor({ pet = false, line = i, search = "" }, S.TopRankOn()), false)
        S.lineBox[i] = box
        next = next + 1
    end
    if pets > 0 then
        local box = S.boxes[next]
        box.use, box.line = "pet", nil
        Fill(box, S.ListFor({ pet = true, line = 1, search = "" }), true)
        S.petBox = box
        next = next + 1
    end
    for i = next, DYNAMIC - 1 do
        S.boxes[i].use = nil
        Fill(S.boxes[i], {}, false)
    end
    local dynamic = S.boxes[DYNAMIC]
    dynamic.use, dynamic.key = "dynamic", nil
    for _, box in ipairs(S.boxes) do
        if box.use then ArmTabs(box) end
    end
    S.ApplyView()
end

-- The dynamic container's key for a view (nil: a container of its own).
local function DynamicKey(view)
    if view.search ~= "" then return (view.pet and "pet:" or "player:") .. view.search:lower() end
    if view.pet then return S.petBox == nil and "pet" or nil end
    if S.lineBox and S.lineBox[view.line] then return nil end
    return "line:" .. tostring(view.line)
end

-- The container showing the current view, or nil when it isn't ready (in a
-- fight the dynamic one can't be refilled).
function S.ViewBox()
    if not S.linked or S.dirty or not S.lineBox then return nil end
    local view = S.view
    local key = DynamicKey(view)
    if not key then return view.pet and S.petBox or S.lineBox[view.line] end
    local dynamic = S.boxes[DYNAMIC]
    if dynamic.key == key then return dynamic end
    if Look.InFight() then return nil end
    dynamic.key = key
    Fill(dynamic, S.ListFor(view, not view.pet and S.TopRankOn()), view.pet)
    ArmTabs(dynamic)
    return dynamic
end

-- Out of a fight: only the current view's container and its pages 1 to
-- the current page are up; nothing at all while the Training Guide shows.
function S.ApplyView()
    if Look.InFight() or not S.linked then return end
    if S.book.trainingShown then
        S.chooser:SetAttribute("unit", "none")
        for _, box in ipairs(S.boxes) do box.frame:Hide() end
        return
    end
    local current = S.ViewBox()
    if not current then return end
    S.chooser:SetAttribute("unit", current.value)
    for _, box in ipairs(S.boxes) do Look.Shown(box.frame, box == current) end
    local last = math.min(S.page, S.PageCount(current.list))
    for p, page in ipairs(current.sets) do
        page.frame:SetAttribute("unit", p <= last and "player" or "none")
        Look.Shown(page.frame, p <= last)
    end
end

-- In a fight the art follows what the secure clicks chose: the container
-- up gives the tab (a line's or the pet's, no search; the dynamic one keeps
-- the view), its highest page set up gives the page. Returns that container.
function S.ReadSecure()
    for _, box in ipairs(S.boxes) do
        if box.use and box.frame:IsShown() then
            if box.use == "line" then
                S.SetView(false, box.line, "")
            elseif box.use == "pet" then
                S.SetView(true, S.view.line, "")
            end
            local top = 0
            for p, page in ipairs(box.sets) do
                if page.frame:IsShown() then top = math.max(top, p) end
            end
            if top > 0 then S.SetPage(top) end
            return box
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- The layer, the key button and wiring them up
---------------------------------------------------------------------------

local function DisplayButtons(layer)
    local buttons = {}
    for i = 1, S.PER_PAGE do
        local button = CreateFrame("CheckButton", "EraUIClassicSpellButton" .. i, layer, "SecureActionButtonTemplate")
        button:SetSize(S.SLOT, S.SLOT)
        local x, y = S.SlotSpot(i)
        Look.Pin(button, "TOPLEFT", layer, "TOPLEFT", x, y)
        Look.StateArt(button, "Pushed", "slotPushed")
        local glow = Look.StateArt(button, "Highlight", "slotHighlight")
        if glow then glow:SetBlendMode("ADD") end
        S.slots[i].button = button
        buttons[i] = button
    end
    S.book.Buttons = buttons
end

-- A pad straight on the layer: its click lowers the layer, then after.
local function LayerPad(width, height, point, x, y, under, after)
    local pad = Secure("Button", S.layer, nil, width, height)
    Look.Pin(pad, "CENTER", S.layer, point, x, y)
    pad:SetAttribute("type", "attribute")
    pad:SetAttribute("attribute-frame", S.layer)
    pad:SetAttribute("attribute-name", "unit")
    pad:SetAttribute("attribute-value", "none")
    Mirror(pad, under)
    pad:SetScript("PostClick", function(_, _, down)
        if not down then after() end
    end)
    return pad
end

-- Everything secure, made once with the book (out of a fight).
function S.BuildLayer()
    local layer = Secure("Button", UIParent, "EraUIClassicSpellBookClicks", S.WIDTH, S.HEIGHT)
    layer:SetFrameStrata("HIGH")
    Look.Pin(layer, "TOPLEFT", UIParent, "TOPLEFT", 0, S.DOWN)
    layer:EnableMouse(false)
    layer:Hide()
    Watched(layer)
    S.layer = layer
    DisplayButtons(layer)
    local chooser = CreateFrame("Frame", nil, layer)
    chooser:SetSize(S.WIDTH, S.HEIGHT)
    chooser:SetAllPoints(layer)
    S.chooser = chooser
    for index = 1, DYNAMIC do Container(index) end
    local key = Tucked("EraUIClassicSpellBookBind")
    key:SetScript("PreClick", function(_, _, down) if not down then S.keyClicking = true end end)
    key:SetScript("PostClick", function(_, _, down)
        S.keyClicking = false
        if not down then S.KeyPressed() end
    end)
    S.key = key
end

-- The key button's click: the layer flipped (and with Combat Spell
-- Dragging the game's own spellbook opened or closed with it).
function S.WireKey()
    local key = S.key
    if S.DragOn() then
        key:SetAttribute("type", "macro")
        key:SetAttribute("clickbutton", nil)
        key:SetAttribute("macrotext", "/click EraUIClassicSpellBookClicks\n/click SpellbookMicroButton")
    else
        key:SetAttribute("type", "click")
        key:SetAttribute("macrotext", nil)
        key:SetAttribute("clickbutton", S.layer)
    end
end

-- Wired once, out of a fight: a click while the unit isn't "player" makes
-- it "player" (open); while it is, the click becomes the "close" button,
-- which makes it "none".
function S.Link()
    if S.linked or not S.layer or Look.InFight() then return end
    local layer = S.layer
    layer:RegisterForClicks("AnyUp", "AnyDown")
    layer:SetAttribute("type", "attribute")
    layer:SetAttribute("attribute-name", "unit")
    layer:SetAttribute("attribute-value", "player")
    layer:SetAttribute("helpbutton", "close")
    layer:SetAttribute("*attribute-value-close", "none")
    layer:SetAttribute("unit", S.book:IsShown() and "player" or "none")
    for _, entry in ipairs(S.slots) do entry.button:EnableMouse(false) end
    S.WireKey()
    LayerPad(24, 24, "TOPRIGHT", -44, -25, S.closeButton, function() S.Hide() end)
    LayerPad(100, 30, "BOTTOMLEFT", 187, 64, S.bookTabs[2], function() S.BookTabClick(S.bookTabs[2]) end)
    S.linked = true
    S.BuildPages()
end

-- The layer's unit reads "player": the book is open for the secure side.
function S.LayerUp()
    return S.layer ~= nil and S.layer:GetAttribute("unit") == "player"
end
