local _, EraUI = ...
local Module = {}
EraUI:RegisterModule("MinimapTools", Module)
local buttons = setmetatable({}, {__mode = "k"})
local elapsed, lastHover = 0, 0
local libraryCallbacks = setmetatable({}, {__mode = "k"})
local HoverUpdate
function Module:Position()
    if not self.button or InCombatLockdown() then return end
    local position = self.position or EraUI:GetSetting("minimapButtonPosition")
    local x, y = 0.7071, -0.7071
    if type(position) == "table" and type(position.x) == "number" and type(position.y) == "number" then
        local length = math.sqrt(position.x * position.x + position.y * position.y)
        if length > 0 and length < math.huge then x, y = position.x / length, position.y / length end
    end
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x * (Minimap:GetWidth()/2 + 4), y * (Minimap:GetHeight()/2 + 4))
end
function Module:Drag()
    if InCombatLockdown() then self.dragging = false; return end
    local cx, cy = Minimap:GetCenter()
    if not cx or not cy then return end
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local dx, dy = px / scale - cx, py / scale - cy
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 1 then return end
    self.position = {x = dx / length, y = dy / length}
    self:Position()
end
local function IsOver(frame)
    if not frame then return false end
    if type(frame.IsMouseOver) == "function" then return frame:IsMouseOver() end
    if type(MouseIsOver) == "function" then return MouseIsOver(frame) end
    -- If neither API exists, leave buttons visible and usable.
    return true
end
local function Remember(button)
    if button and button.GetAlpha and not buttons[button] then buttons[button] = {} end
end
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
    -- Legacy buttons with unambiguous addon-owned names. Native map controls
    -- (time, mail, tracking and zoom) are deliberately not collected.
    for _, name in ipairs({"DBMMinimapButton", "AtlasButton", "BagnonMinimapButton", "HealBot_MMButton"}) do Remember(_G[name]) end
end
function Module:OnIconCreated(_, button)
    Remember(button)
    self:Refresh()
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
    if InCombatLockdown() then return end
    local clean = EraUI:GetSetting("cleanMinimap")
    local hover = false
    if clean then
        hover = IsOver(_G.Minimap) or IsOver(_G.MinimapCluster)
        for button, state in pairs(buttons) do
            if not state.hidden and button:IsShown() and IsOver(button) then hover = true end
        end
    end
    local now = GetTime()
    if hover then lastHover = now end
    local reveal = self.dragging or not clean or hover or now - lastHover < 0.6
    for button, state in pairs(buttons) do
        if reveal then
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
    Minimap:HookScript("OnSizeChanged", function() self:Position() end)
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
        if InCombatLockdown() then return end
        self.dragging = true
        self:UpdateDriver()
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStop", function()
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
        GameTooltip:AddLine("Left-click: settings\nRight-click: setup walkthrough\nDrag: move around the minimap", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self:Discover()
    local driver = CreateFrame("Frame")
    self.driver = driver
    for _, event in ipairs({"PLAYER_REGEN_ENABLED","UI_SCALE_CHANGED","ADDON_LOADED","PLAYER_ENTERING_WORLD"}) do
        driver:RegisterEvent(event)
    end
    driver:SetScript("OnEvent",function(_,event)
        if event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" then self:Discover() end
        if event ~= "ADDON_LOADED" then self:Position() end
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
