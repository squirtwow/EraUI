local _, EraUI = ...
local Module = {}
EraUI:RegisterModule("MinimapTools", Module)
local buttons = setmetatable({}, {__mode = "k"})
local elapsed, lastHover = 0, 0
local libraryCallbacks = setmetatable({}, {__mode = "k"})
local HoverUpdate
local unpack = unpack or table.unpack
-- Clean Minimap's Drawer style (below) keeps addon buttons in EraUI's own
-- panel. held: each button in it, with what to give back exactly (its
-- parent, points, strata and frame level). Kept in EraUI's own tables:
-- nothing is ever written on another addon's frames.
local held = {}
-- Minimap children that look like addon buttons, found for the drawer.
local found = setmetatable({}, {__mode = "k"})
local Drawer = {order = {}, shown = {}, slots = {}}
Module.drawer = Drawer

-- Square Minimap is worn (Classic/Minimap.lua): the buttons go round the
-- square's edge instead of the ring.
local function Square()
    local classic = EraUI.Classic
    return type(classic) == "table" and type(classic.SquareMinimapOn) == "function" and classic.SquareMinimapOn() == true
end
-- A spot on the minimap's edge from a saved direction ({x, y}, any length),
-- or the default direction (x, y): on the ring 4 out from the map, or on
-- the square 4 out (the corner for a diagonal).
local function RingPoint(position, x, y)
    if type(position) == "table" and type(position.x) == "number" and type(position.y) == "number" then
        local length = math.sqrt(position.x * position.x + position.y * position.y)
        if length > 0 and length < math.huge then x, y = position.x / length, position.y / length end
    end
    local w, h = Minimap:GetWidth()/2 + 4, Minimap:GetHeight()/2 + 4
    if Square() then
        local far = math.max(math.abs(x), math.abs(y))
        if far > 0 then return x / far * w, y / far * h end
    end
    return x * w, y * h
end
-- The direction from the minimap's centre to the cursor, or nil.
local function CursorDirection()
    local cx, cy = Minimap:GetCenter()
    if not cx or not cy then return end
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local dx, dy = px / scale - cx, py / scale - cy
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 1 then return end
    return {x = dx / length, y = dy / length}
end
function Module:Position()
    -- In the drawer it sits in its slot there instead.
    if not self.button or InCombatLockdown() or held[self.button] then return end
    local x, y = RingPoint(self.position or EraUI:GetSetting("minimapButtonPosition"), 0.7071, -0.7071)
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
function Module:Drag()
    if InCombatLockdown() then self.dragging = false; return end
    local position = CursorDirection()
    if not position then return end
    self.position = position
    self:Position()
end
local function IsOver(frame)
    if not frame then return false end
    if type(frame.IsMouseOver) == "function" then return frame:IsMouseOver() end
    if type(MouseIsOver) == "function" then return MouseIsOver(frame) end
    -- If neither API exists, leave buttons visible and usable.
    return true
end
-- Another addon's button mid-drag (FECM's flags isMoving, LibDBIcon's
-- isMouseDown). They follow the cursor round the ring, so the cursor can be off
-- the button: never fade one while it's being dragged. Only reads their flags.
local function Dragged(button)
    if button.isMoving or button.isMouseDown then return true end
    return type(button.IsDragging) == "function" and button:IsDragging() == true
end
local function Remember(button)
    if button and button.GetAlpha and not buttons[button] then buttons[button] = {} end
end
-- Clean Minimap with its Drawer style chosen (and EraUI on).
local function DrawerOn()
    return EraUI:GetSetting("enabled") ~= false and EraUI:GetSetting("cleanMinimap") == true
        and EraUI:GetSetting("cleanMinimapStyle") == "drawer"
end
Module.DrawerOn = DrawerOn
function Module:Discover()
    Remember(self.button)
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if lib and lib.GetButtonList and lib.GetMinimapButton then
        for _, name in ipairs(lib:GetButtonList()) do Remember(lib:GetMinimapButton(name)) end
        if lib.RegisterCallback and not libraryCallbacks[lib] then
            lib.RegisterCallback(self, "LibDBIcon_IconCreated", "OnIconCreated")
            libraryCallbacks[lib] = true
        elseif not lib.RegisterCallback and type(lib.Register) == "function" and libraryCallbacks[lib] ~= lib.Register then
            hooksecurefunc(lib,"Register",function(_,name)
                Remember(lib:GetMinimapButton(name))
                self:Refresh()
            end)
            libraryCallbacks[lib] = lib.Register
        end
        self.discoveryNote = libraryCallbacks[lib] and "LibDBIcon registration-based discovery active"
            or "LibDBIcon has no supported creation callback; discovery is event-based only"
    end
    -- Legacy buttons with unambiguous addon-owned names, and the buttons of
    -- Squirt's other addons (the cooldown manager, cooldown pulse, cursor,
    -- nameplates, raid frames, privacy and clam opener), which draw their
    -- own rather than use the library. Native map controls (time, mail,
    -- tracking and zoom) are deliberately not collected.
    for _, name in ipairs({"DBMMinimapButton", "AtlasButton", "BagnonMinimapButton", "HealBot_MMButton", "FECMMinimapButton",
        "FECPMinimapButton", "FECursorMinimapButton", "FENMinimapButton", "FERFMinimapButton", "ClamOpenerMinimapButton",
        "ForeverEnhancedPrivacyMinimapButton"}) do
        Remember(_G[name])
    end
    -- The drawer also takes other addons' buttons on the minimap.
    if DrawerOn() then self:ScanChildren() end
end
function Module:OnIconCreated(_, button)
    Remember(button)
    self:Refresh()
end
-- Buttons an addon makes after it loads (at log in, or a moment later) join
-- the drawer: one more look a second after an addon loads.
function Module:SoonDiscover()
    if self.discoverSoon or not DrawerOn() or not (C_Timer and C_Timer.After) then return end
    self.discoverSoon = true
    C_Timer.After(1, function()
        self.discoverSoon = false
        self:Discover()
        self:Refresh()
    end)
end

function Module:UpdateDriver()
    if not self.driver then return end
    -- The existing hover grace period is retained. This only checks already
    -- registered buttons while Clean minimap is enabled; it never scans frames.
    local running = self.dragging or EraUI:GetSetting("cleanMinimap")
    if self.hoverRunning ~= not not running then
        self.hoverRunning = not not running
        self.driver:SetScript("OnUpdate",running and HoverUpdate or nil)
    end
end

function Module:Refresh()
    self:UpdateDriver()
    self:PaintDrawerButton()
    if InCombatLockdown() then return end
    -- The drawer first: a button it takes keeps its own look there.
    self:UpdateDrawer()
    local clean = EraUI:GetSetting("cleanMinimap")
    local hover = false
    if clean then
        hover = IsOver(_G.Minimap) or IsOver(_G.MinimapCluster)
        for button, state in pairs(buttons) do
            if not held[button] and (Dragged(button) or (not state.hidden and button:IsShown() and IsOver(button))) then hover = true end
        end
    end
    local now = GetTime()
    if hover then lastHover = now end
    local reveal = self.dragging or not clean or hover or now - lastHover < 0.6
    for button, state in pairs(buttons) do
        if reveal or held[button] then
            if state.hidden then
                button:SetAlpha(state.alpha)
                button:EnableMouse(state.mouse)
                state.hidden = nil
            end
        elseif button:IsShown() then
            if not state.hidden then
                state.alpha, state.mouse = button:GetAlpha(), button:IsMouseEnabled()
                state.hidden = true
            end
            button:SetAlpha(0)
            button:EnableMouse(false)
        end
    end
end

-- Drawer -----------------------------------------------------------------------
-- Clean Minimap's second style: one EraUI button on the minimap's edge opens
-- a panel beside the minimap with every addon's minimap button in a grid.
-- The buttons are lent to the panel (reparented) out of combat only, and
-- given back exactly when the style, Clean Minimap or EraUI is turned off.
-- Their scripts are never touched: Arrange lays EraUI's own handles over the
-- grid to drag them into a new order, so an addon's own drag (round the
-- minimap) can't fire in the drawer while you arrange. Dragged outside
-- Arrange, an addon's button does its own thing until let go, then goes
-- back to its slot. Protected and forbidden frames, and the game's own
-- minimap buttons, are never touched.

local DRAWER, DRAWER_BUTTON = "EraUIMinimapDrawer", "EraUIMinimapDrawerButton"
-- From the panel's top to the grid, its sides and bottom, between slots,
-- the narrowest panel (room for its heading and Arrange), and how far it
-- sits from the minimap's edge (clear of the ring and its buttons).
local TOP, SIDE, BOTTOM, GAP, MIN_WIDTH, RING = 32, 12, 12, 4, 176, 30
-- The game's own minimap pieces, by name (Forever's Blizzard_Minimap,
-- TimeManager, Calendar and queue status code, and the older clients'
-- names), then its unnamed ones through MinimapCluster and Minimap.
local GAME = {}
for name in ("MinimapCluster Minimap MinimapBackdrop MinimapZoneTextButton MinimapZoneText MinimapCompassTexture"
    .. " MinimapCompassTextureUnderlay MinimapNorthTag MinimapBorder MinimapBorderTop MinimapZoomIn MinimapZoomOut"
    .. " MiniMapTracking MiniMapTrackingButton MiniMapTrackingFrame MiniMapTrackingDropDown MiniMapMailFrame MiniMapMailIcon"
    .. " MiniMapCraftingOrderIcon MiniMapWorldMapButton MinimapToggleButton MiniMapBattlefieldFrame MiniMapLFGFrame"
    .. " LFGMinimapFrame LFDMinimapFrame MiniMapInstanceDifficulty GuildInstanceDifficulty MiniMapChallengeMode"
    .. " MiniMapVoiceChatFrame MiniMapRecordingButton MiniMapMeetingStoneFrame GameTimeFrame TimeManagerClockButton"
    .. " QueueStatusButton QueueStatusMinimapButton ExpansionLandingPageMinimapButton GarrisonLandingPageMinimapButton"
    .. " AddonCompartmentFrame HybridMinimap FeedbackUIButton"):gmatch("%S+") do GAME[name] = true end
local CLUSTER_PARTS = {"Tracking", "IndicatorFrame", "InstanceDifficulty", "DielFrame", "MinimapContainer", "BorderTop",
    "ZoneTextButton", "GamepadButtons", "GamepadHudBackground"}
local MAP_PARTS = {"ZoomIn", "ZoomOut", "ZoomHitArea"}
-- Map markers sit on the minimap too (some at its edge): never buttons.
local PIN_WORDS = {"pin", "node", "waypoint", "arrow", "blip"}

local function Forbidden(frame)
    return type(frame) ~= "table" or (frame.IsForbidden ~= nil and frame:IsForbidden() == true)
end
local function GameFrame(frame)
    local name = frame:GetName()
    if type(name) == "string" and (GAME[name] or name:find("^Blizzard")) then return true end
    local map, cluster = _G.Minimap, _G.MinimapCluster
    if frame == map or frame == cluster or frame == _G.MinimapBackdrop then return true end
    for _, key in ipairs(MAP_PARTS) do if map and frame == map[key] then return true end end
    for _, key in ipairs(CLUSTER_PARTS) do if cluster and frame == cluster[key] then return true end end
    local container = cluster and cluster.MinimapContainer
    return container ~= nil and frame == container.PlayerCoords
end
-- An addon's button the drawer may hold: named, on the minimap (or held
-- already), not protected or forbidden, not the game's and not EraUI's own
-- (its settings button is the one exception: it goes in too).
local function Eligible(frame)
    if Forbidden(frame) or not frame.GetParent or not frame.GetName then return false end
    if frame.IsProtected and frame:IsProtected() then return false end
    local name = frame:GetName()
    if type(name) ~= "string" or name == "" or GameFrame(frame) then return false end
    if frame ~= Module.button and name:find("^EraUI") then return false end
    if held[frame] then return true end
    local parent = frame:GetParent()
    return parent ~= nil and (parent == _G.Minimap or parent == _G.MinimapBackdrop or parent == _G.MinimapCluster)
end
local function Script(frame, kind)
    if not frame.GetScript or (frame.HasScript and not frame:HasScript(kind)) then return nil end
    local ok, handler = pcall(frame.GetScript, frame, kind)
    return ok and handler or nil
end
-- A child of the minimap that looks like an addon's button: named as one,
-- clickable, button-sized and on the edge where minimap buttons sit.
local function LooksLikeButton(frame)
    if Forbidden(frame) or not frame.GetName then return false end
    local name = frame:GetName()
    if type(name) ~= "string" then return false end
    local lower = name:lower()
    if not (lower:find("minimap", 1, true) or lower:find("button", 1, true)) then return false end
    for _, word in ipairs(PIN_WORDS) do if lower:find(word, 1, true) then return false end end
    if not (Script(frame, "OnClick") or Script(frame, "OnMouseUp") or Script(frame, "OnMouseDown")) then return false end
    local width, height = frame:GetWidth(), frame:GetHeight()
    if not (width and height) or width < 12 or height < 12 or width > 64 or height > 64 then return false end
    local x, y = frame:GetCenter()
    local mx, my = Minimap:GetCenter()
    if not (x and y and mx and my) then return false end
    local ratio = frame:GetEffectiveScale() / Minimap:GetEffectiveScale()
    local dx, dy = x * ratio - mx, y * ratio - my
    return math.sqrt(dx * dx + dy * dy) >= Minimap:GetWidth() / 2 * .75
end
function Module:ScanChildren()
    for _, holder in ipairs({_G.Minimap, _G.MinimapBackdrop}) do
        if holder and holder.GetChildren then
            for _, child in ipairs({holder:GetChildren()}) do
                if not found[child] and not buttons[child] and LooksLikeButton(child) and Eligible(child) then found[child] = true end
            end
        end
    end
end

-- The order, by button name: the saved one first, then buttons new to the
-- drawer (EraUI's own first, then by name), so a new addon's button lands
-- at the end; a saved name with no button now is skipped.
local function SavedOrder()
    local saved, rank = EraUI:GetSetting("minimapDrawerOrder"), {}
    if type(saved) == "table" then
        for i, name in ipairs(saved) do if type(name) == "string" and not rank[name] then rank[name] = i end end
    end
    return saved, rank
end
local function SortDrawer()
    local list = {}
    for button in pairs(held) do list[#list + 1] = button end
    local _, rank = SavedOrder()
    local own = Module.button
    table.sort(list, function(a, b)
        local an, bn = a:GetName(), b:GetName()
        local ra, rb = rank[an], rank[bn]
        if ra and rb then return ra < rb end
        if ra or rb then return ra ~= nil end
        if (a == own) ~= (b == own) then return a == own end
        return an:lower() < bn:lower()
    end)
    Drawer.order = list
end
-- Saves the order as it is now; names not here now (an addon turned off)
-- keep their turn after these.
local function SaveOrder()
    local names, seen = {}, {}
    for _, button in ipairs(Drawer.order) do
        local name = button:GetName()
        if not seen[name] then names[#names + 1] = name; seen[name] = true end
    end
    local saved = SavedOrder()
    if type(saved) == "table" then
        for _, name in ipairs(saved) do
            if type(name) == "string" and not seen[name] and #names < 100 then names[#names + 1] = name; seen[name] = true end
        end
    end
    EraUI:SetSetting("minimapDrawerOrder", names)
    if EraUI.SaveSettings then EraUI:SaveSettings() end
end

local function Pack(...) return {n = select("#", ...), ...} end
-- A held button its addon has placed since EraUI last did (round the
-- minimap: the library places its buttons as you log in, which can be
-- after they were lent, and re-places them later): that is where it goes
-- back. Points on the drawer are EraUI's own.
local function Adopt(button)
    local state, count = held[button], button:GetNumPoints()
    if not state or count == 0 then return end
    local points = {}
    for i = 1, count do
        points[i] = Pack(button:GetPoint(i))
        if points[i][2] == Drawer.panel then return end
    end
    state.points = points
end
-- Sets a button's strata and frame level, writing only what differs. One
-- its addon fixed in place (as the library's are) is let go of for the
-- change and fixed again, as the game's own code does.
local function SetStrataLevel(button, strata, level)
    if button:GetFrameStrata() == strata and button:GetFrameLevel() == level then return end
    local fixedStrata = button.HasFixedFrameStrata ~= nil and button:HasFixedFrameStrata() == true
    local fixedLevel = button.HasFixedFrameLevel ~= nil and button:HasFixedFrameLevel() == true
    if fixedStrata then button:SetFixedFrameStrata(false) end
    if fixedLevel then button:SetFixedFrameLevel(false) end
    if button:GetFrameStrata() ~= strata then button:SetFrameStrata(strata) end
    if button:GetFrameLevel() ~= level then button:SetFrameLevel(level) end
    if fixedStrata then button:SetFixedFrameStrata(true) end
    if fixedLevel then button:SetFixedFrameLevel(true) end
end
-- Lends a button to the drawer, out of combat, noting what to give back.
local function Capture(button)
    local state = {parent = button:GetParent(), strata = button:GetFrameStrata(), level = button:GetFrameLevel(), points = {}}
    for i = 1, button:GetNumPoints() do state.points[i] = Pack(button:GetPoint(i)) end
    -- Shown as its addon left it: Hide until hover's fade comes off first.
    local hover = buttons[button]
    if hover and hover.hidden then
        button:SetAlpha(hover.alpha)
        button:EnableMouse(hover.mouse)
        hover.hidden = nil
    end
    held[button] = state
    local panel = Drawer.panel
    button:SetParent(panel)
    SetStrataLevel(button, panel:GetFrameStrata(), panel:GetFrameLevel() + 5)
    Drawer.dirty = true
end
-- Gives a button back exactly as it was lent (or where its addon placed it
-- since), unless its addon has taken it back already. Its shown state,
-- scale and scripts were never changed.
local function GiveBack(button)
    local state = held[button]
    if state and button:GetParent() == Drawer.panel then Adopt(button) end
    held[button] = nil
    Drawer.dirty = true
    if not state or button:GetParent() ~= Drawer.panel then return end
    button:SetParent(state.parent)
    SetStrataLevel(button, state.strata, state.level)
    button:ClearAllPoints()
    for _, point in ipairs(state.points) do button:SetPoint(unpack(point, 1, point.n)) end
end
function Module:GiveBackAll()
    if InCombatLockdown() then return end
    for button in pairs(held) do GiveBack(button) end
    if Drawer.panel then Drawer.panel:Hide() end
    Drawer.order, Drawer.shown = {}, {}
    if self.button then self:Position() end
end
function Module:Holds(button)
    return held[button] ~= nil
end

-- Lends new buttons, forgets ones their addon took back, gives them all back
-- when the drawer is off. Out of combat only (Refresh runs it again when the
-- fight ends).
function Module:UpdateDrawer()
    if not self.driver or InCombatLockdown() then return end
    if not DrawerOn() then
        if next(held) or (Drawer.panel and Drawer.panel:IsShown()) then self:GiveBackAll() end
        if Drawer.button then Drawer.button:Hide() end
        return
    end
    if not Drawer.panel and not self:BuildDrawer() then return end
    if not Drawer.button:IsShown() then
        Drawer.button:Show()
        self:PlaceDrawerButton()
    end
    -- An addon that took its button back keeps it; it can come back later.
    for button in pairs(held) do
        if button:GetParent() ~= Drawer.panel then held[button] = nil; Drawer.dirty = true end
    end
    for button in pairs(buttons) do if not held[button] and Eligible(button) then Capture(button) end end
    for button in pairs(found) do if not held[button] and Eligible(button) then Capture(button) end end
    if Drawer.dirty then
        Drawer.dirty = false
        SortDrawer()
        self:LayoutDrawer()
    end
end

local function Columns()
    local n = tonumber(EraUI:GetSetting("minimapDrawerColumns")) or 5
    return math.max(3, math.min(8, math.floor(n + .5)))
end
-- One slot: the biggest button's size, kept between 24 and 40.
local function SlotSize(list)
    local size = 0
    for _, button in ipairs(list) do
        local scale = button:GetScale() or 1
        size = math.max(size, (button:GetWidth() or 0) * scale, (button:GetHeight() or 0) * scale)
    end
    if size <= 0 then size = 32 end
    return math.max(24, math.min(40, size))
end
-- Slot i's centre, from the panel's top left.
local function SlotCentre(i)
    local column, row = (i - 1) % Drawer.columns, math.floor((i - 1) / Drawer.columns)
    return Drawer.left + column * (Drawer.size + GAP) + Drawer.size / 2, TOP + row * (Drawer.size + GAP) + Drawer.size / 2
end
-- Puts a button in its slot, writing only what differs. Mid its own drag
-- it's left alone until let go (and a button that has turned protected
-- since is never touched).
local function Place(button, x, y)
    if Dragged(button) or (button.IsProtected and button:IsProtected()) then return end
    local panel = Drawer.panel
    local scale = button:GetScale() or 1
    if scale <= 0 then scale = 1 end
    x, y = x / scale, y / scale
    local point, relative, relativePoint, px, py = button:GetPoint(1)
    if button:GetNumPoints() ~= 1 or point ~= "CENTER" or relative ~= panel or relativePoint ~= "TOPLEFT"
        or math.abs((px or 0) - x) > .01 or math.abs((py or 0) - y) > .01 then
        Adopt(button)
        button:ClearAllPoints()
        button:SetPoint("CENTER", panel, "TOPLEFT", x, y)
    end
    SetStrataLevel(button, panel:GetFrameStrata(), panel:GetFrameLevel() + 5)
end
-- Arrange's handle over a slot: EraUI's own, above the button it covers.
local function Handle(i)
    local slot = Drawer.slots[i]
    if slot then return slot end
    local panel = Drawer.panel
    slot = CreateFrame("Button", nil, panel)
    slot:SetFrameLevel(panel:GetFrameLevel() + 12)
    slot:EnableMouse(true)
    slot:RegisterForDrag("LeftButton")
    slot.fill = slot:CreateTexture(nil, "BACKGROUND")
    slot.fill:SetAllPoints(slot)
    slot.edges = {}
    for e, side in ipairs({{"TOPLEFT", "TOPRIGHT"}, {"BOTTOMLEFT", "BOTTOMRIGHT"}, {"TOPLEFT", "BOTTOMLEFT"}, {"TOPRIGHT", "BOTTOMRIGHT"}}) do
        local edge = slot:CreateTexture(nil, "BORDER")
        edge:SetColorTexture(1, .82, 0, .7)
        edge:SetPoint(side[1], slot, side[1], 0, 0)
        edge:SetPoint(side[2], slot, side[2], 0, 0)
        if e <= 2 then edge:SetHeight(1) else edge:SetWidth(1) end
        slot.edges[e] = edge
    end
    slot:SetScript("OnDragStart", function(self)
        Drawer.dragButton = self.button
        Module:LayoutDrawer()
    end)
    slot:SetScript("OnDragStop", function() Module:EndArrangeDrag() end)
    slot:Hide()
    Drawer.slots[i] = slot
    return slot
end
function Module:LayoutDrawer()
    local panel = Drawer.panel
    if not panel then return end
    local list = {}
    for _, button in ipairs(Drawer.order) do
        if held[button] and button:IsShown() then list[#list + 1] = button end
    end
    Drawer.shown = list
    local columns, size = Columns(), SlotSize(list)
    local across = math.max(1, math.min(columns, #list))
    local rows = math.max(1, math.ceil(#list / columns))
    local gridWidth = across * size + (across - 1) * GAP
    local width, height = math.max(MIN_WIDTH, gridWidth + SIDE * 2), TOP + rows * size + (rows - 1) * GAP + BOTTOM
    if math.abs(panel:GetWidth() - width) > .01 or math.abs(panel:GetHeight() - height) > .01 then panel:SetSize(width, height) end
    Drawer.size, Drawer.columns, Drawer.left = size, columns, (width - gridWidth) / 2
    Drawer.empty:SetShown(#list == 0)
    for i, button in ipairs(list) do
        local x, y = SlotCentre(i)
        Place(button, x, -y)
        local slot = Handle(i)
        if slot.x ~= x or slot.y ~= y or slot.size ~= size then
            slot.x, slot.y, slot.size = x, y, size
            slot:SetSize(size, size)
            slot:ClearAllPoints()
            slot:SetPoint("CENTER", panel, "TOPLEFT", x, -y)
        end
        slot.button = button
        local lifted = button == Drawer.dragButton
        slot.fill:SetColorTexture(1, .82, 0, lifted and .35 or .1)
        slot:SetShown(Drawer.arranging == true)
    end
    for i = #list + 1, #Drawer.slots do
        Drawer.slots[i].button = nil
        Drawer.slots[i]:Hide()
    end
end
-- The slot under the cursor while arranging, or nil.
local function CursorSlot()
    local panel, count = Drawer.panel, #Drawer.shown
    local left, top = panel:GetLeft(), panel:GetTop()
    if count == 0 or not left or not top then return end
    local x, y = GetCursorPosition()
    local scale = panel:GetEffectiveScale()
    x, y = x / scale - left - Drawer.left, top - y / scale - TOP
    local step = Drawer.size + GAP
    local column = math.max(0, math.min(Drawer.columns - 1, math.floor((x + GAP / 2) / step)))
    local row = math.max(0, math.floor((y + GAP / 2) / step))
    return math.max(1, math.min(count, row * Drawer.columns + column + 1))
end
-- Moves the lifted button to slot index, the others making room.
local function DragTo(index)
    local button, shown, order = Drawer.dragButton, Drawer.shown, Drawer.order
    if not index or not button then return end
    local from, target = nil, shown[index]
    for i, other in ipairs(shown) do if other == button then from = i end end
    if not from or from == index or not target then return end
    for i, other in ipairs(order) do if other == button then table.remove(order, i); break end end
    local at = #order + 1
    for i, other in ipairs(order) do if other == target then at = index > from and i + 1 or i; break end end
    table.insert(order, at, button)
    Module:LayoutDrawer()
end
function Module:EndArrangeDrag()
    if not Drawer.dragButton then return end
    Drawer.dragButton = nil
    SaveOrder()
    self:LayoutDrawer()
end
function Module:PaintArrange()
    if not Drawer.title then return end
    Drawer.title:SetText(Drawer.arranging and "Drag to reorder" or "Addon buttons")
    Drawer.arrangeLabel:SetText(Drawer.arranging and "Done" or "Arrange")
end
function Module:SetArranging(on)
    Drawer.arranging = on and true or false
    if not on then self:EndArrangeDrag() end
    self:PaintArrange()
    self:LayoutDrawer()
end

-- Right next to the drawer button, wherever it was dragged (the user: "button
-- pop out is too far even if i moved the minimap icon it always pops out
-- there"): out from the minimap's side the button sits on, so it never
-- covers the map, and flipped where the screen runs out; at the minimap's
-- own scale. Without the button: beside the minimap, as before.
local BESIDE = 4 -- between the button and the drawer
local function PlacePanel()
    local panel, map, button = Drawer.panel, _G.Minimap, Drawer.button
    local ui = UIParent:GetEffectiveScale()
    local ratio = map:GetEffectiveScale() / ui
    if ratio > 0 then panel:SetScale(ratio) end
    panel:SetClampedToScreen(true)
    panel:ClearAllPoints()
    local mx, my = map:GetCenter()
    local bx, by = nil, nil
    if button and button:IsShown() then bx, by = button:GetCenter() end
    if not (bx and by and mx and my) then
        local right = not mx or mx * ratio < UIParent:GetWidth() / 2
        local edge = (not my or my * ratio > UIParent:GetHeight() / 2) and "TOP" or "BOTTOM"
        if right then panel:SetPoint(edge .. "LEFT", map, edge .. "RIGHT", RING, 0)
        else panel:SetPoint(edge .. "RIGHT", map, edge .. "LEFT", -RING, 0) end
        return
    end
    -- Everything in UIParent's units.
    local bscale = button:GetEffectiveScale() / ui
    bx, by, mx, my = bx * bscale, by * bscale, mx * ratio, my * ratio
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    local pw, ph = (panel:GetWidth() or 0) * ratio, (panel:GetHeight() or 0) * ratio
    local half = (button:GetWidth() or 0) * bscale / 2
    local dx, dy = bx - mx, by - my
    if math.abs(dx) >= math.abs(dy) then
        -- On the ring's left or right: open sideways, out from the map.
        local right = dx > 0
        if right and bx + half + pw > w then right = false
        elseif not right and bx - half - pw < 0 then right = true end
        local v = by > h / 2 and "TOP" or "BOTTOM"
        if right then panel:SetPoint(v .. "LEFT", button, v .. "RIGHT", BESIDE, 0)
        else panel:SetPoint(v .. "RIGHT", button, v .. "LEFT", -BESIDE, 0) end
    else
        -- On the ring's top or bottom: open up or down, out from the map.
        local up = dy > 0
        if up and by + half + ph > h then up = false
        elseif not up and by - half - ph < 0 then up = true end
        local side = bx > w / 2 and "RIGHT" or "LEFT"
        if up then panel:SetPoint("BOTTOM" .. side, button, "TOP" .. side, 0, BESIDE)
        else panel:SetPoint("TOP" .. side, button, "BOTTOM" .. side, 0, -BESIDE) end
    end
end
function Module:ToggleDrawer()
    local panel = Drawer.panel
    if not panel then return end
    if panel:IsShown() then panel:Hide(); return end
    -- A button an addon has made since the last look joins as it opens.
    if not InCombatLockdown() then
        self:Discover()
        self:UpdateDrawer()
    end
    -- Laid out first, so the drawer's size is known when it's placed.
    self:LayoutDrawer()
    PlacePanel()
    -- The order you see is kept from now on, so a button new later lands
    -- at the end (not in among them by name).
    local _, rank = SavedOrder()
    for _, button in ipairs(Drawer.order) do
        if not rank[button:GetName()] then SaveOrder(); break end
    end
    panel:Show()
end

-- The drawer button's hover box: EraUI's own, never the game's tooltip, but
-- drawn like EraUI's tooltips (the user: "this should be like other era ui
-- tooltips right?"): the same dark fill, EraUI's bevelled border (its grey
-- following the Darkness slider in Dark Mode, as the tooltips' does), the
-- tooltip fonts, a white title and white lines, to the left of the button
-- like the E button's tooltip.
local TIP_BORDER = "Interface\\AddOns\\EraUI\\Media\\TooltipBorder.tga"
local function TipShade()
    local grey = EraUI.Classic and EraUI.Classic.DarkGrey
    if not (grey and EraUI:GetSetting("darkMode")) then return 1 end
    return math.min(1, (grey()) / .42)
end
local function ShowHint(owner)
    local hint = Drawer.hint
    if not hint then
        hint = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        hint:SetFrameStrata("TOOLTIP")
        hint:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = TIP_BORDER,
            edgeSize = 16, insets = {left = 3, right = 3, top = 3, bottom = 3}})
        hint:SetBackdropColor(.016, .016, .02, .9)
        hint:EnableMouse(false)
        hint.title = hint:CreateFontString(nil, "OVERLAY", "GameTooltipHeaderText")
        hint.title:SetPoint("TOPLEFT", hint, "TOPLEFT", 10, -10)
        hint.title:SetTextColor(1, 1, 1)
        hint.title:SetText("Addon buttons")
        hint.body = hint:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        hint.body:SetPoint("TOPLEFT", hint.title, "BOTTOMLEFT", 0, -2)
        hint.body:SetJustifyH("LEFT")
        hint.body:SetTextColor(1, 1, 1)
        hint.body:SetText("Click: open or close\nDrag: move")
        Drawer.hint = hint
    end
    local shade = TipShade()
    hint:SetBackdropBorderColor(shade, shade, shade, 1)
    local width = math.max(hint.title:GetStringWidth() or 0, hint.body:GetStringWidth() or 0)
    hint:SetSize(math.floor(width + 21), math.floor((hint.title:GetStringHeight() or 14) + (hint.body:GetStringHeight() or 24) + 22))
    hint:ClearAllPoints()
    hint:SetPoint("BOTTOMRIGHT", owner, "TOPLEFT", 0, 0)
    hint:SetClampedToScreen(true)
    hint:Show()
end
local function HideHint()
    if Drawer.hint then Drawer.hint:Hide() end
end

-- The drawer button sits on the minimap's edge, bottom left until moved.
function Module:PlaceDrawerButton()
    local button = Drawer.button
    if not button then return end
    local x, y = RingPoint(Drawer.position or EraUI:GetSetting("minimapDrawerButtonPosition"), -0.7071, -0.7071)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
local function FollowCursor()
    local position = CursorDirection()
    if not position then return end
    Drawer.position = position
    Module:PlaceDrawerButton()
end
local DOTS = { classic = { 1, 0.82, 0.25 }, dark = { 0.80, 0.82, 0.86 } }
local DISC = { classic = { 0.08, 0.065, 0.035 }, dark = { 0.05, 0.05, 0.06 } }
function Module:PaintDrawerButton()
    if not Drawer.dots then return end
    local look = EraUI:GetSetting("darkMode") and "dark" or "classic"
    if Drawer.look == look then return end
    Drawer.look = look
    local dot, disc = DOTS[look], DISC[look]
    for _, texture in ipairs(Drawer.dots) do texture:SetColorTexture(dot[1], dot[2], dot[3], 1) end
    if Drawer.back then Drawer.back:SetVertexColor(disc[1], disc[2], disc[3]) end
end

function Module:BuildDrawerButton()
    local ns = EraUI.Classic
    local button = CreateFrame("Button", DRAWER_BUTTON, Minimap)
    button:SetSize(32, 32)
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    back:SetSize(20, 20)
    back:SetPoint("CENTER")
    Drawer.back = back
    -- A little grid of dots: more buttons inside. Gold in the Classic look,
    -- light grey on a neutral dark disc in Dark Mode (the user: "with dark
    -- mode, the squares on the icon draw thing, should be different colo,
    -- looks weird now with the yellow dots").
    Drawer.dots = {}
    for row = 0, 2 do
        for column = 0, 2 do
            local dot = button:CreateTexture(nil, "ARTWORK")
            dot:SetSize(3, 3)
            dot:SetPoint("CENTER", button, "CENTER", (column - 1) * 5, (1 - row) * 5)
            Drawer.dots[#Drawer.dots + 1] = dot
        end
    end
    self:PaintDrawerButton()
    -- The gold ring of EraUI's minimap buttons; Dark Mode's grey, following
    -- the Darkness slider, when Dark Mode is on.
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    if not (ns and ns.SetTex and ns.TEX and ns.TEX.trackingBorder and ns.SetTex(border, "trackingBorder")) then
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    end
    Drawer.ring = border
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", function()
        if Drawer.moving or GetTime() < (Drawer.suppressClickUntil or 0) then return end
        HideHint()
        self:ToggleDrawer()
    end)
    button:SetScript("OnDragStart", function(frame)
        Drawer.moving = true
        HideHint()
        frame:SetScript("OnUpdate", FollowCursor)
    end)
    button:SetScript("OnDragStop", function(frame)
        frame:SetScript("OnUpdate", nil)
        Drawer.moving = false
        Drawer.suppressClickUntil = GetTime() + 0.2
        if Drawer.position then
            EraUI:SetSetting("minimapDrawerButtonPosition", {x = Drawer.position.x, y = Drawer.position.y})
        end
        self:PlaceDrawerButton()
    end)
    button:SetScript("OnEnter", function(frame) if not Drawer.moving then ShowHint(frame) end end)
    button:SetScript("OnLeave", HideHint)
    button:Hide()
    return button
end

-- A menu of the game's that a button in the drawer opened (a right-click
-- menu, say) closes itself as soon as its button is out of sight, so a
-- click on one of its entries must leave the drawer open or the click
-- would never land. Only reads the game's menu manager.
local function MenuFromDrawer()
    local menus = _G.Menu
    local manager = type(menus) == "table" and type(menus.GetManager) == "function" and menus.GetManager()
    if not manager or type(manager.GetOpenMenu) ~= "function" then return false end
    local open = manager:GetOpenMenu()
    local owner = open and type(open.GetOwnerRegion) == "function" and open:GetOwnerRegion() or nil
    for _ = 1, 30 do
        if not owner or Forbidden(owner) then return false end
        if owner == Drawer.panel then return true end
        owner = type(owner.GetParent) == "function" and owner:GetParent() or nil
    end
    return false
end

function Module:BuildDrawer()
    if Drawer.panel then return true end
    if not (_G.Minimap and UIParent) then return false end
    local ns = EraUI.Classic
    local panel = CreateFrame("Frame", DRAWER, UIParent, "BackdropTemplate")
    panel:SetFrameStrata("HIGH")
    panel:SetClampedToScreen(true)
    -- Clicks inside stay inside (never through to the world).
    panel:EnableMouse(true)
    panel:Hide()
    panel:SetSize(MIN_WIDTH, TOP + 32 + BOTTOM)
    -- The classic dialog box; Dark Windows darkens it in Dark Mode.
    panel:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
        insets = {left = 6, right = 6, top = 6, bottom = 6}})
    panel:SetBackdropColor(1, 1, 1, 1)
    panel:SetBackdropBorderColor(1, 1, 1, 1)
    if ns and ns.DarkBackdrop then ns.DarkBackdrop(panel) end
    Drawer.panel = panel
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -12)
    Drawer.title = title
    local arrange = CreateFrame("Button", nil, panel)
    arrange:SetSize(60, 18)
    arrange:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -9, -8)
    arrange:SetFrameLevel(panel:GetFrameLevel() + 14)
    local label = arrange:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", arrange, "CENTER", 0, 0)
    local glow = arrange:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints(arrange)
    glow:SetColorTexture(1, 0.82, 0, 0.16)
    arrange:SetScript("OnClick", function() self:SetArranging(not Drawer.arranging) end)
    Drawer.arrange, Drawer.arrangeLabel = arrange, label
    local empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    empty:SetPoint("TOP", panel, "TOP", 0, -TOP - 9)
    empty:SetText("No addon buttons yet.")
    empty:Hide()
    Drawer.empty = empty
    self:PaintArrange()
    -- While open it keeps every button in its slot: an addon re-placing its
    -- button round the minimap, or showing or hiding it, is put right at once.
    local since = 0
    panel:SetScript("OnUpdate", function(_, dt)
        since = since + (dt or 0)
        if Drawer.dragButton then DragTo(CursorSlot())
        elseif since < 0.05 then return end
        since = 0
        self:LayoutDrawer()
    end)
    -- Closes with a click anywhere else (the game's mouse-down event while
    -- it's open, or a catcher over the screen without it), Escape (the
    -- game's own list of windows Escape closes; no key is bound) or the
    -- drawer button again.
    local mouseDown = pcall(panel.RegisterEvent, panel, "GLOBAL_MOUSE_DOWN")
    if mouseDown then panel:UnregisterEvent("GLOBAL_MOUSE_DOWN") end
    panel:SetScript("OnShow", function(frame)
        if mouseDown then frame:RegisterEvent("GLOBAL_MOUSE_DOWN") end
    end)
    panel:SetScript("OnHide", function(frame)
        if mouseDown then frame:UnregisterEvent("GLOBAL_MOUSE_DOWN") end
        HideHint()
        if Drawer.arranging then self:SetArranging(false) end
    end)
    if mouseDown then
        panel:SetScript("OnEvent", function(frame)
            if not frame:IsShown() or frame:IsMouseOver() or (Drawer.button and Drawer.button:IsMouseOver()) then return end
            if MenuFromDrawer() then return end
            frame:Hide()
        end)
    else
        local catcher = CreateFrame("Frame", nil, panel)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameLevel(math.max(0, panel:GetFrameLevel() - 1))
        catcher:EnableMouse(true)
        catcher:SetScript("OnMouseDown", function() panel:Hide() end)
        Drawer.catcher = catcher
    end
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, DRAWER) end
    Drawer.button = self:BuildDrawerButton()
    return true
end

function Module:UpdateCoordinates()
    local enabled = EraUI:GetSetting("coordinates") == true
    local container = MinimapCluster and MinimapCluster.MinimapContainer
    local native = container and container.PlayerCoords
    if native then
        -- Forever supplies its own updater. Keep one display and retain its scripts.
        if self.coordinatesFrame then self.coordinatesFrame:Hide() end
        if self.nativeCoordinates ~= native then
            self.nativeCoordinates = native
            native:HookScript("OnShow", function(frame)
                if not EraUI:GetSetting("coordinates") then frame:Hide() end
            end)
        end
        native:SetShown(enabled)
    elseif self.coordinatesFrame then
        self.coordinatesFrame:SetShown(enabled)
    end
end
local function ReadCoordinates(text)
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then text:SetText("");return end
    local map = C_Map.GetBestMapForUnit("player")
    if (issecretvalue and issecretvalue(map)) or not map then text:SetText("");return end
    local position = C_Map.GetPlayerMapPosition(map,"player")
    if not position then text:SetText("");return end
    local x,y = position:GetXY()
    if (issecretvalue and (issecretvalue(x) or issecretvalue(y))) or type(x)~="number" or type(y)~="number" then
        text:SetText("");return
    end
    text:SetFormattedText("%.1f, %.1f",x*100,y*100)
end
function Module:Initialize()
    if not _G.Minimap then return end
    local coordinates = CreateFrame("Frame", nil, Minimap)
    self.coordinatesFrame = coordinates
    coordinates:SetSize(120,16)
    coordinates:SetPoint("TOP",Minimap,"BOTTOM",0,-6)
    coordinates:EnableMouse(false)
    local text = coordinates:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    text:SetAllPoints(coordinates)
    local since=0
    coordinates:SetScript("OnShow",function() since=0;ReadCoordinates(text) end)
    -- Only updates our own visible label; no frame discovery or UI scanning.
    coordinates:SetScript("OnUpdate",function(_,dt)
        since=since+dt
        if since>=0.25 then since=0;ReadCoordinates(text) end
    end)
    self:UpdateCoordinates()
    local button = CreateFrame("Button", "EraUIMinimapButton", Minimap)
    self.button = button
    button:SetSize(32, 32)
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    self:Position()
    Minimap:HookScript("OnSizeChanged", function()
        self:Position()
        self:PlaceDrawerButton()
    end)
    button:SetNormalTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    local icon = button:GetNormalTexture()
    icon:ClearAllPoints(); icon:SetPoint("CENTER"); icon:SetSize(20, 20)
    icon:SetVertexColor(0.08, 0.065, 0.035)
    local letter = button:CreateFontString(nil, "OVERLAY")
    letter:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    letter:SetPoint("CENTER", 0, 1)
    letter:SetText("E")
    letter:SetTextColor(1, 0.82, 0.25)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54); border:SetPoint("TOPLEFT")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function()
        -- In the drawer it keeps its slot (Arrange moves it there).
        if InCombatLockdown() or held[button] then return end
        self.dragging = true
        self:UpdateDriver()
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStop", function()
        if held[button] then return end
        self.dragging = false
        self.suppressClickUntil = GetTime() + 0.2
        if self.position then EraUI:SetSetting("minimapButtonPosition", {x=self.position.x, y=self.position.y}) end
        self:Refresh()
    end)
    button:SetScript("OnClick", function(_, click)
        if self.dragging or GetTime() < (self.suppressClickUntil or 0) then return end
        if click == "RightButton" then
            if EraUI.Classic then EraUI.Classic.ShowWelcome() end
        else
            if EraUI.Classic then EraUI.Classic.OpenOptions() end
        end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("EraUI")
        GameTooltip:AddLine("Left-click: settings\nRight-click: setup walkthrough"
            .. (held[self] and "" or "\nDrag: move around the minimap"), 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self:Discover()
    local driver = CreateFrame("Frame")
    self.driver = driver
    for _, event in ipairs({"PLAYER_REGEN_ENABLED","UI_SCALE_CHANGED","ADDON_LOADED","PLAYER_ENTERING_WORLD","PLAYER_LOGOUT"}) do
        driver:RegisterEvent(event)
    end
    driver:SetScript("OnEvent",function(_,event)
        -- Logging out: every button goes back where its addon put it.
        if event == "PLAYER_LOGOUT" then self:GiveBackAll(); return end
        if event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" then
            self:Discover()
            self:SoonDiscover()
        end
        if event ~= "ADDON_LOADED" then
            self:Position()
            self:PlaceDrawerButton()
        end
        self:Refresh()
    end)
    self:Refresh()
end

HoverUpdate = function(_,dt)
    if Module.dragging then Module:Drag() end
    elapsed = elapsed+dt
    if elapsed < 0.1 then return end
    elapsed = 0
    Module:Refresh()
end
