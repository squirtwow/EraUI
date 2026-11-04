-- The game menu (Escape) as the old dialog box: its header plate with "Main
-- Menu" in gold, and compact red buttons 144 wide. Built the first time the
-- menu opens while the look is on; the buttons are dressed each time the
-- game makes them again, never in a fight. Restore asks for a reload (the
-- art stays until then).
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local M = { applied = false, built = false }
Look.Menu = M

local dressedButtons = Look.Weak() -- a menu button: true once in the 1.x art
local LIFT = 18

local function Menu()
    return GameMenuFrame
end

local function Each(visit)
    local menu = Menu()
    local pool = menu and menu.buttonPool
    if type(pool) ~= "table" or type(pool.EnumerateActive) ~= "function" then return end
    local list = {}
    pcall(function()
        for button in pool:EnumerateActive() do list[#list + 1] = button end
    end)
    for _, button in ipairs(list) do Look.Try(visit, button) end
end

-- Once per button: the game's three slices faded, the red panel art 21
-- tall in its 23 (a 2 gap between buttons), the glow additive, Dark Windows.
local function Once(button)
    for _, piece in ipairs({ button.Left, button.Right, button.Center }) do Look.Fade(piece) end
    local took = false
    for _, state in ipairs({ { "Normal", "Up" }, { "Pushed", "Down" }, { "Disabled", "Disabled" }, { "Highlight", "Highlight" } }) do
        local give, read = button["Set" .. state[1] .. "Texture"], button["Get" .. state[1] .. "Texture"]
        if type(give) == "function" and type(read) == "function" then
            if state[1] ~= "Normal" and not took then break end
            give(button, "Interface\\Buttons\\UI-Panel-Button-" .. state[2])
            local face = read(button)
            if face then
                if state[1] == "Normal" then took = face:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up") ~= false end
                Look.Crop(face, 0, 0.625, 0, 0.6875)
                face:ClearAllPoints()
                face:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -1)
                face:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 1)
                if state[1] == "Highlight" then face:SetBlendMode("ADD") end
            end
        end
    end
    if took and ns.DarkRedButton then ns.DarkRedButton(button) end
    if button.SetNormalFontObject and GameFontHighlight then button:SetNormalFontObject(GameFontHighlight) end
    if button.SetHighlightFontObject and GameFontHighlight then button:SetHighlightFontObject(GameFontHighlight) end
    if button.SetDisabledFontObject and GameFontDisable then button:SetDisabledFontObject(GameFontDisable) end
    local label = button.GetFontString and button:GetFontString()
    if label then Look.Pin(label, "CENTER", button, "CENTER", 0, -1) end
end

local function DressButton(button)
    if not dressedButtons[button] then
        dressedButtons[button] = true
        Once(button)
    end
    button:SetSize(144, 23)
end

-- The menu's own layout, then each button 18 up and the menu 18 shorter.
local function Compact()
    local menu = Menu()
    if type(menu.Layout) == "function" then Look.Try(menu.Layout, menu) end
    Each(function(button)
        local point, relative, relativePoint, x, y = button:GetPoint(1)
        x, y = Look.Number(x), Look.Number(y)
        if type(point) == "string" and x and y then button:SetPoint(point, relative, relativePoint, x, y + LIFT) end
    end)
    local tall = Look.Number(menu:GetHeight())
    if tall and tall > 54 then menu:SetHeight(tall - LIFT) end
end

function M.DressButtons()
    if not M.applied or not M.built or Look.InFight() or not Menu() then return end
    Each(DressButton)
    Compact()
end

-- The box, the header plate and the title, once a session.
local function Build()
    local menu = Menu()
    if M.built or not menu then return end
    M.built = true
    local border = menu.Border
    Look.EachRegion(border, function(piece) Look.Fade(piece) end)
    local fine, children = pcall(function() return border and { border:GetChildren() } or {} end)
    for _, child in ipairs(fine and children or {}) do Look.EachRegion(child, function(piece) Look.Fade(piece) end) end
    M.box = Look.DialogBox(menu)
    local header = menu.Header
    if header then
        for _, key in ipairs({ "LeftBG", "RightBG", "CenterBG" }) do Look.Fade(header[key]) end
        M.plate = Look.HeaderPlate(header, "BACKGROUND", menu)
        local text = header.Text
        if text then
            text:SetFontObject(Look.GoldFont())
            text:SetText(MAIN_MENU or "Main Menu")
        end
    end
    Look.Hook(menu, "InitButtons", M.DressButtons)
end

local function Opened()
    if not M.applied or Look.InFight() then return end
    Build()
    M.DressButtons()
end

local function MenuOn()
    M.applied = true
    local menu = Menu()
    if not menu then return end
    Look.HookScript(menu, "OnShow", Opened, "gameMenu")
    if menu:IsShown() then Opened() end
end

-- Every pass while off: the reload note only when the look went on.
local function MenuOff()
    if M.built then ns.needsReload = true end
    M.applied = false
end

ns.RegisterModule("gameMenu", { apply = MenuOn, restore = MenuOff })
