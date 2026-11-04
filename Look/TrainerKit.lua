-- The classic trainer (Classic look, registry "trainer"): the old compact
-- layout over the game's trainer window (class, pet and profession
-- trainers). This file builds it and lays the game's own pieces under it:
--   * EraUIClassicTrainer, the panel: the greeting over a stone strip, the
--     skill shell (Look/SkillShell.lua) with nine rows, the details, and the
--     foot: the money box, Train and Exit;
--   * a restricted-code bridge for the two things addon code must not do
--     itself: showing the panel and resizing the game's virtual list (so a
--     row of the game's exists for every service);
--   * the game's pieces faded, its money moved into EraUI's box, its own
--     Train button laid invisibly over EraUI's Train art. Every selection
--     and every purchase is the game's own button, clicked securely; EraUI
--     never selects, buys or runs the game's row set-up itself, and nothing
--     of EraUI's that takes the mouse ever sits over the game's Train.
-- Each game piece is remembered as it was the first time it is changed
-- (a weak table) and given back when the trainer look is turned off.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Spells

local R = { folded = {}, memory = Look.Weak(), log = {}, routed = Look.Weak() }
Look.Trainer = R
R.ROWS = 9
R.GREEN, R.RED, R.GREY, R.GOLD = { 0.1, 1, 0.1 }, { 1, 0.1, 0.1 }, { 0.5, 0.5, 0.5 }, { 1, 0.82, 0 }

local function Window()
    return ClassTrainerFrame
end
R.Window = Window

---------------------------------------------------------------------------
-- The game's pieces: remembered once, faded or placed, given back
---------------------------------------------------------------------------

-- The first time a game frame is changed: its alpha, and (with placing)
-- its level, scale, size and anchors.
local function Remember(frame, placing)
    local held = R.memory[frame]
    if held and (held.level or not placing) then return end
    held = held or { alpha = frame:GetAlpha() }
    if placing then
        local points = {}
        for i = 1, frame:GetNumPoints() do points[i] = { frame:GetPoint(i) } end
        held.level, held.scale, held.points = frame:GetFrameLevel(), frame:GetScale(), points
        held.width, held.height = frame:GetWidth(), frame:GetHeight()
    end
    R.memory[frame] = held
end

local function Fade(frame)
    if not frame or type(frame.SetAlpha) ~= "function" then return end
    Remember(frame, false)
    if frame:GetAlpha() ~= 0 then frame:SetAlpha(0) end
end

-- The window skin's marble floor on the trainer window: asked of the skin,
-- else found among the window's own textures by its art.
local function SkinFloor(window)
    if type(ns.WindowPiece) == "function" then
        local fine, floor = Look.Try(ns.WindowPiece, window, "insetFloor")
        if fine and floor then return floor end
    end
    local found
    Look.EachRegion(window, function(region)
        if found or not (region.IsObjectType and region:IsObjectType("Texture")) then return end
        local fine, path = Look.Ask(region, "GetTextureFilePath")
        if not fine or type(path) ~= "string" then fine, path = Look.Ask(region, "GetTexture") end
        if fine and type(path) == "string" and not Look.Secret(path) and path:lower():find("background%-marble") then found = region end
    end)
    return found
end

local FADED = Look.Words("FilterDropdown FilterInputHint trainingPoints skillStepButton bottomInset BG Inset ScrollBox ScrollBar")

-- Out of a fight, each refresh: the game's own shell faded, its Train over
-- EraUI's art, its money in EraUI's box.
function R.Layout()
    local window, panel = Window(), R.panel
    if not (window and panel) or Look.InFight() or not panel:IsShown() then return end
    for _, key in ipairs(FADED) do Fade(window[key]) end
    Fade(ClassTrainerStatusBar)
    Fade(ClassTrainerFrameMoneyBg)
    Fade(SkinFloor(window))
    local train = window.TrainButton
    if train then
        Remember(train, true)
        if train:GetAlpha() ~= 0 then train:SetAlpha(0) end
        train:ClearAllPoints()
        train:SetAllPoints(R.trainArt)
        train:SetFrameLevel((Look.Number(panel:GetFrameLevel()) or 0) + 30)
    end
    local money = window.money
    if money then
        Remember(money, true)
        money:SetFrameLevel((Look.Number(panel:GetFrameLevel()) or 0) + 8)
        if ClassTrainerFrameMoneyBg then
            money:ClearAllPoints()
            money:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 18, 13)
        end
    end
    R.Viewport()
end

-- Every service given a real (invisible) game row: the game's list made
-- tiny and tall enough, from restricted code.
function R.Viewport()
    local window = Window()
    if not (R.bridge and window and window.ScrollBox) or Look.InFight() then return end
    local count = Look.Number(GetNumTrainerServices and GetNumTrainerServices()) or 0
    Remember(window.ScrollBox, true)
    R.bridge:SetAttribute("want-height", math.max(330, (count * 2 + 1) * 47))
    R.bridge:SetAttribute("want-scale", 0.01)
    R.bridge:Execute([[
        local list = self:GetFrameRef("list")
        local height, scale = self:GetAttribute("want-height"), self:GetAttribute("want-scale")
        if list:GetScale() ~= scale then list:SetScale(scale) end
        if list:GetHeight() ~= height then list:SetHeight(height) end
    ]])
end

-- Off: the list's own height and scale back (restricted code), then every
-- remembered piece as it was; the memory cleared for a later look.
function R.GiveBack()
    local window = Window()
    local list = window and window.ScrollBox
    local held = list and R.memory[list]
    if held and R.bridge and not Look.InFight() then
        R.bridge:SetAttribute("want-height", held.height or 330)
        R.bridge:SetAttribute("want-scale", held.scale or 1)
        R.bridge:Execute([[
            local list = self:GetFrameRef("list")
            list:SetScale(self:GetAttribute("want-scale"))
            list:SetHeight(self:GetAttribute("want-height"))
        ]])
    end
    for frame, was in pairs(R.memory) do
        frame:SetAlpha(was.alpha)
        if was.level then
            frame:SetFrameLevel(was.level)
            frame:ClearAllPoints()
            for _, point in ipairs(was.points) do frame:SetPoint(point[1], point[2], point[3], point[4], point[5]) end
            if frame ~= list then
                frame:SetScale(was.scale)
                frame:SetSize(was.width, was.height)
            end
        end
    end
    R.memory = Look.Weak()
end

---------------------------------------------------------------------------
-- The greeting
---------------------------------------------------------------------------

local function Greeting(panel)
    local stone = Look.Build("Frame", panel, nil, { size = { 100, 33 } })
    stone:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -50)
    stone:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -50)
    stone:SetHeight(33)
    stone:SetFrameLevel((Look.Number(panel:GetFrameLevel()) or 0) + 1)
    local rock = Look.OwnTexture(stone, "rock", "ARTWORK")
    Look.TileArt(rock, "rockBg")
    Look.Fill(rock, stone)
    local box = Look.Build("Frame", panel, nil, { size = { 100, 31 } })
    box:SetPoint("TOPLEFT", panel, "TOPLEFT", 72, -21)
    box:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -14, -52)
    box:SetFrameLevel((Look.Number(stone:GetFrameLevel()) or 0) + 1)
    local text = box:CreateFontString(nil, "ARTWORK")
    text:SetFontObject("GameFontHighlight")
    text:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    text:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(true)
    text:SetMaxLines(2)
    R.stone, R.greetingBox, R.greeting = stone, box, text
end

-- The trainer's words: in the window's font, or the small one when they
-- need more than two lines (the game ends anything longer with "...").
function R.DrawGreeting()
    local said = type(GetTrainerGreetingText) == "function" and GetTrainerGreetingText() or ""
    said = (type(said) == "string" and not Look.Secret(said)) and said or ""
    local text = R.greeting
    text:SetFontObject("GameFontHighlight")
    text:SetText(said)
    if said ~= "" and text:IsTruncated() then
        text:SetFontObject("GameFontHighlightSmall")
        text:SetText(said)
    end
end

---------------------------------------------------------------------------
-- The foot: money, Train and Exit
---------------------------------------------------------------------------

-- The art's own highlight, copied as a texture of the art: the glow shown
-- by the cursor's place alone (the art takes no mouse).
local function Glow(art)
    local own = art:GetHighlightTexture()
    local glow = Look.OwnTexture(art, "glow", "OVERLAY")
    glow:SetTexture(own and own:GetTexture() or "Interface\\Buttons\\UI-Panel-Button-Highlight")
    if own then glow:SetTexCoord(own:GetTexCoord()) end
    glow:SetBlendMode("ADD")
    Look.Fill(glow, art)
    glow:Hide()
    if ns.DarkWindowArt then ns.DarkWindowArt(glow, "glow") end
    return glow
end

local function Boxed(panel, button)
    local box = Look.InsetBox(panel, 16, true)
    box:SetPoint("TOPLEFT", button, "TOPLEFT", -4, 3)
    box:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 4, -7)
    box:SetFrameLevel(math.max(0, (Look.Number(button:GetFrameLevel()) or 1) - 1))
    return box
end

local function Foot(panel)
    local exit = Look.PanelButton(panel, S.Say("EXIT", "Exit"), 84)
    Look.Pin(exit, "BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 11)
    exit:SetScript("OnClick", function()
        if not Look.InFight() then Look.HidePanel(Window()) end
    end)
    local art = Look.PanelButton(panel, S.Say("TRAIN", "Train"), 84)
    Look.Pin(art, "RIGHT", exit, "LEFT", -3, 0)
    art:EnableMouse(false)
    R.trainArt, R.exit = art, exit
    R.trainGlow = Glow(art)
    local money = Look.InsetBox(panel, 16, true)
    money:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 1, 4)
    money:SetPoint("TOPRIGHT", art, "TOPLEFT", 1, 3)
    R.moneyBox = money
    R.trainBox, R.exitBox = Boxed(panel, art), Boxed(panel, exit)
    local points = Look.OwnLabel(money, "points", "GameFontNormalSmall", "ARTWORK")
    points:SetPoint("LEFT", money, "LEFT", 14, 0)
    points:SetPoint("RIGHT", money, "RIGHT", -8, 0)
    points:SetJustifyH("LEFT")
    R.points = points
    local oval = Look.OwnTexture(panel, "oval", "ARTWORK")
    oval:SetTexture("Interface\\MoneyFrame\\UI-MoneyFrame-Border")
    oval:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 4, -3)
    oval:SetPoint("TOPRIGHT", art, "TOPLEFT", -5, -2)
    if ns.DarkWindowArt then ns.DarkWindowArt(oval, "frame") end
    R.oval = oval
end

---------------------------------------------------------------------------
-- The details
---------------------------------------------------------------------------

local function Details(detail)
    local icon = Look.Build("Button", detail, nil, { size = { 37, 37 } })
    Look.Pin(icon, "TOPLEFT", detail, "TOPLEFT", 20, -18)
    local face = Look.OwnTexture(icon, "face", "ARTWORK")
    Look.Fill(face, icon)
    icon:SetScript("OnEnter", function(self) R.ServiceTip(self) end)
    icon:SetScript("OnLeave", function(self) Look.HideTip(self) end)
    local name = Look.OwnLabel(detail, "name", "GameFontNormal", "ARTWORK")
    Look.Pin(name, "TOPLEFT", icon, "TOPRIGHT", 8, -2)
    name:SetJustifyH("LEFT")
    local rank = Look.OwnLabel(detail, "rank", "GameFontHighlightSmall", "ARTWORK")
    Look.Pin(rank, "LEFT", name, "RIGHT", 4, 0)
    local needs = Look.OwnLabel(detail, "needs", "GameFontHighlightSmall", "ARTWORK")
    needs:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    needs:SetPoint("RIGHT", detail, "RIGHT", -14, 0)
    needs:SetJustifyH("LEFT")
    needs:SetWordWrap(true)
    local cost = Look.OwnLabel(detail, "cost", "GameFontNormalSmall", "ARTWORK")
    Look.Pin(cost, "TOPLEFT", detail, "TOPLEFT", 21, -62)
    local about = Look.OwnLabel(detail, "about", "GameFontHighlightSmall", "ARTWORK")
    about:SetPoint("TOPLEFT", cost, "BOTTOMLEFT", 0, -6)
    about:SetPoint("RIGHT", detail, "RIGHT", -16, 0)
    about:SetJustifyH("LEFT")
    about:SetJustifyV("TOP")
    R.detail = { icon = icon, face = face, name = name, rank = rank, needs = needs, cost = cost, about = about }
end

---------------------------------------------------------------------------
-- Building it (the first refresh with the window there)
---------------------------------------------------------------------------

local function Bridge(panel)
    local bridge = CreateFrame("Frame", nil, nil, "SecureHandlerStateTemplate")
    bridge:SetSize(1, 1)
    bridge:SetFrameRef("list", Window().ScrollBox)
    bridge:SetFrameRef("panel", panel)
    for i, row in ipairs(R.shell.rows) do bridge:SetFrameRef("row" .. i, row) end
    R.bridge = bridge
end

function R.Build()
    if R.panel then return R.panel end
    local window = Window()
    if not window or Look.InFight() then return nil end
    local panel = CreateFrame("Frame", "EraUIClassicTrainer", window, "SecureHandlerStateTemplate")
    panel:SetSize(338, 424)
    panel:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, 0)
    panel:SetFrameLevel((Look.Number(window:GetFrameLevel()) or 0) + 120)
    panel:EnableMouse(true)
    panel:Hide()
    R.panel = panel
    Greeting(panel)
    R.shell = Look.SkillShell(panel, { rows = R.ROWS, makeRow = R.MakeRow, idle = true,
        onScroll = function() if R.lines then R.DrawRows() end end })
    local shell = R.shell
    shell.detailBox:ClearAllPoints()
    shell.detailBox:SetPoint("TOPLEFT", shell.listBox, "BOTTOMLEFT", 0, 12)
    shell.detailBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 25)
    shell.footBox:ClearAllPoints()
    shell.footBox:SetPoint("TOPLEFT", shell.detailBox, "BOTTOMLEFT", 0, 11)
    shell.footBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 1, 2)
    shell.footBox:SetFrameLevel((Look.Number(shell.detailBox:GetFrameLevel()) or 0) + 1)
    for _, piece in ipairs({ "TopEdge", "TopLeftCorner", "TopRightCorner" }) do Look.Fade(shell.footBox[piece]) end
    local empty = Look.OwnLabel(shell.list, "empty", "GameFontHighlightSmall", "OVERLAY")
    empty:SetPoint("TOPLEFT", shell.list, "TOPLEFT", 8, -16)
    empty:SetPoint("RIGHT", shell.list, "RIGHT", -8, 0)
    empty:SetWordWrap(true)
    empty:Hide()
    R.empty = empty
    Details(shell.detail)
    Foot(panel)
    shell.all:SetScript("OnClick", function() R.AllClick() end)
    shell.filter:SetScript("OnClick", function(self) R.FilterClick(self) end)
    R.trainArt:SetScript("OnUpdate", function(self, elapsed) R.GlowTick(self, elapsed) end)
    Bridge(panel)
    return panel
end

-- Shown through the bridge (restricted code), only when hidden.
function R.ShowPanel()
    if not (R.bridge and R.panel) or Look.InFight() or R.panel:IsShown() then return end
    R.bridge:Execute([[
        local panel = self:GetFrameRef("panel")
        if not panel:IsShown() then panel:Show() end
    ]])
end
