-- The game menu ("gameMenu", Look/GameMenu.lua) and the game's Settings
-- window ("settingsPanel", Look/SettingsSkin.lua), clean-room 2026-10-21, on
-- a sealed mock of Forever (Tools/WindowMockGame.lua: any key EraUI writes
-- on one of the game's objects fails). What 12-windows-settings.md sections
-- 6 and 7 ask: the look is built the first time the window opens while on;
-- the menu's old border faded, the dialog box and header plate (Dark
-- Windows' hand-overs), "Main Menu" in gold, the compact red buttons (144 x
-- 23, 18 up, the menu 18 shorter), never dressed in a fight, dressed again
-- when the game makes its buttons again; the Settings window's art faded,
-- its box and plate, the title, the X, the 1.x tabs, red buttons, the two
-- bordered insets, the thin scroll bars, the category rows (gold labels
-- kept gold, the old highlight bar kept on), the settings rows dressed when
-- their data changes (reused rows), each control in the old art; restore
-- asks for a reload only once the look went on.
-- Run from the addon folder: fengari Tools/TestWindowsSettings.lua
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local Mock = dofile("Tools/WindowMockGame.lua")
local FILES = { "Look/Base.lua", "Look/ChromeKit.lua", "Look/GameMenu.lua", "Look/SettingsSkin.lua" }
local game, st, env, ns, Look
setmetatable(_G, { __index = function(_, key) return env and rawget(env, key) end })

local function Spot(region, point)
    local anchor = st[region].points[point]
    if not anchor then return "none" end
    return string.format("%s %s %s,%s", anchor[3], tostring(anchor[2] and (anchor[2]:GetName() or "?") or "nil"),
        tostring(anchor[4]), tostring(anchor[5]))
end

---------------------------------------------------------------------------
-- The game menu: a vertical layout of pooled red buttons
---------------------------------------------------------------------------
local function MakeGameMenu()
    local menu = game.New("Frame", "GameMenuFrame", env.UIParent)
    st[menu].width, st[menu].height, st[menu].shown, st[menu].level = 260, 1, false, 5
    menu:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
    local border = game.New("Frame", nil, menu)
    game.Own(menu, "Border", border)
    game.New("Texture", nil, border, "BORDER")
    local corner = game.New("Frame", nil, border)
    game.New("Texture", nil, corner, "BORDER")
    local header = game.New("Frame", nil, menu)
    game.Own(menu, "Header", header)
    game.Pieces(header, "LeftBG RightBG CenterBG")
    game.Own(header, "Text", game.New("FontString", nil, header, "OVERLAY"))
    local buttons = {}
    local function Button(text)
        local button = game.New("Button", nil, menu)
        game.Pieces(button, "Left Right Center")
        st[button].width, st[button].height = 200, 36
        local label = button:GetFontString()
        st[label].text = text
        return button
    end
    game.Own(menu, "buttonPool", { EnumerateActive = function()
        local i = 0
        return function()
            i = i + 1
            return buttons[i]
        end
    end })
    -- The game: its buttons made again on each opening, then laid out.
    game.Own(menu, "InitButtons", function()
        game.inits = (game.inits or 0) + 1
        if #buttons == 0 then
            for _, text in ipairs({ "Options", "Macros", "Log Out" }) do buttons[#buttons + 1] = Button(text) end
        end
    end)
    game.Own(menu, "Layout", function(self)
        for i, button in ipairs(buttons) do
            button:ClearAllPoints()
            button:SetPoint("TOP", self, "TOP", 0, -(48 + (i - 1) * 36))
        end
        self:SetHeight(48 + #buttons * 36 + 34)
    end)
    menu:SetScript("OnShow", function(self)
        self:InitButtons()
        self:Layout()
    end)
    game.menuButtons = buttons
    return menu
end

---------------------------------------------------------------------------
-- The Settings window
---------------------------------------------------------------------------
local function Minimal(name, panel)
    local tab = game.New("Button", nil, panel)
    game.Pieces(tab, "Left Middle Right")
    game.Own(tab, "Text", game.New("FontString", nil, tab, "ARTWORK"))
    st[tab].width, st[tab].height = 80, 37
    game.Own(tab, "SetSelected", function(self, on) st[self].selected = on end)
    game.Own(tab, "IsSelected", function(self) return st[self].selected == true end)
    game.Own(panel, name, tab)
    return tab
end
local function RedButton(holder, key)
    local button = game.New("Button", nil, holder)
    game.Pieces(button, "Left Middle Right")
    if key then game.Own(holder, key, button) end
    return button
end
local function ScrollBox(holder)
    local box = game.New("Frame", nil, holder)
    game.Own(holder, "ScrollBox", box)
    local rows = {}
    game.Own(box, "ForEachFrame", function(_, fn) for _, row in ipairs(rows) do fn(row) end end)
    return box, rows
end
local function MakeSettingsPanel()
    local panel = game.New("Frame", "SettingsPanel", env.UIParent)
    st[panel].width, st[panel].height, st[panel].shown, st[panel].level = 920, 724, false, 8
    panel:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
    local slice = game.New("Frame", nil, panel)
    game.Own(panel, "NineSlice", slice)
    game.New("Texture", nil, slice, "BORDER")
    game.Own(slice, "Text", game.New("FontString", nil, slice, "OVERLAY"))
    local bg = game.New("Frame", nil, panel)
    game.Own(panel, "Bg", bg)
    game.New("Texture", nil, bg, "BACKGROUND")
    game.New("Texture", nil, game.New("Frame", nil, bg), "BACKGROUND")
    game.New("Texture", nil, panel, "OVERLAY"):SetAtlas("Options_InnerFrame")
    game.Own(panel, "ClosePanelButton", game.New("Button", nil, panel))
    Minimal("GameTab", panel)
    Minimal("AddOnsTab", panel)
    RedButton(panel, "CloseButton")
    RedButton(panel, "ApplyButton")
    local categories = game.New("Frame", nil, panel)
    game.Own(panel, "CategoryList", categories)
    local _, categoryRows = ScrollBox(categories)
    game.ThinBar(categories)
    local container = game.New("Frame", nil, panel)
    game.Own(panel, "Container", container)
    local list = game.New("Frame", nil, container)
    game.Own(container, "SettingsList", list)
    local header = game.New("Frame", nil, list)
    game.Own(list, "Header", header)
    game.New("Texture", nil, header, "BACKGROUND")
    RedButton(header, "DefaultsButton")
    game.Own(header, "Title", game.New("FontString", nil, header, "OVERLAY"))
    local _, settingRows = ScrollBox(list)
    game.ThinBar(list)
    game.categoryRows, game.settingRows = categoryRows, settingRows
    return panel
end
-- A category list row: a header (its background and label) or a category
-- (its label and the bar under the chosen one).
local function CategoryRow(header)
    local list = env.SettingsPanel.CategoryList.ScrollBox
    local row = game.New(header and "Frame" or "Button", nil, list)
    if header then game.Own(row, "Background", game.New("Texture", nil, row, "BACKGROUND")) end
    game.Own(row, "Label", game.New("FontString", nil, row, "ARTWORK"))
    if not header then
        local bar = game.New("Texture", nil, row, "ARTWORK")
        bar:SetAtlas("Options_List_Active")
        game.Own(row, "Texture", bar)
    end
    table.insert(game.categoryRows, row)
    return row
end
-- A settings list row the game reuses as the page scrolls.
local function SettingRow(kind)
    local list = env.SettingsPanel.Container.SettingsList.ScrollBox
    local row = game.New("Frame", nil, list)
    game.Own(row, "GetElementData", function(self) return st[self].data end)
    if kind ~= "title" then game.Own(row, "Text", game.New("FontString", nil, row, "ARTWORK")) end
    if kind == "check" then
        local check = game.New("CheckButton", nil, row)
        game.Own(check, "HoverBackground", game.New("Texture", nil, check, "BACKGROUND"))
        game.Own(row, "Checkbox", check)
    elseif kind == "slider" then
        local holder = game.New("Frame", nil, row)
        local slider = game.New("Slider", nil, holder)
        game.Pieces(slider, "Left Right Middle")
        game.Own(holder, "Slider", slider)
        for _, key in ipairs({ "Back", "Forward" }) do
            local stepper = game.New("Button", nil, holder)
            game.New("Texture", nil, stepper, "BACKGROUND")
            stepper:SetNormalTexture("bronze")
            st[stepper].alpha = 0.5
            game.Own(holder, key, stepper)
        end
        game.Own(row, "SliderWithSteppers", holder)
    elseif kind == "dropdown" then
        local control = game.New("Frame", nil, row)
        game.Own(row, "Control", control)
        local drop = game.New("Button", nil, control)
        game.Own(drop, "Background", game.New("Texture", nil, drop, "BACKGROUND"))
        game.Own(drop, "Arrow", game.New("Texture", nil, drop, "ARTWORK"))
        game.Own(drop, "Text", game.New("FontString", nil, drop, "ARTWORK"))
        drop:SetHighlightTexture("modern-glow")
        game.Own(control, "Dropdown", drop)
        for _, key in ipairs({ "IncrementButton", "DecrementButton" }) do
            local arrow = game.New("Button", nil, control)
            game.New("Texture", nil, arrow, "ARTWORK")
            game.Own(control, key, arrow)
        end
    elseif kind == "expand" or kind == "button" then
        local button = RedButton(row, "Button")
        if kind == "expand" then
            button.Left:SetAtlas("Options_ListExpand_Right")
            game.Own(button, "Text", game.New("FontString", nil, button, "ARTWORK"))
            button:SetHighlightTexture("modern-glow")
        end
    elseif kind == "title" then
        game.Own(row, "Title", game.New("FontString", nil, row, "ARTWORK"))
    end
    table.insert(game.settingRows, row)
    return row
end

local function Session(settings)
    game = Mock.New()
    st, env, ns = game.st, game.env, game.ns
    for key, value in pairs(settings or {}) do game.settings[key] = value end
    game.Building(function()
        MakeGameMenu()
        MakeSettingsPanel()
    end)
    ns.db = { gameMenu = true, settingsPanel = true }
    Look = game.Load(FILES)
    return game
end
local function NoErrors(label)
    Equal(table.concat(game.errors, " || "), "", label .. ": no error handed to the game's error handler")
end

---------------------------------------------------------------------------
-- The game menu
---------------------------------------------------------------------------
Session()
local keys = {}
for _, module in ipairs(ns.modules) do keys[#keys + 1] = module.key end
Equal(table.concat(keys, " "), "gameMenu settingsPanel", "two registry entries, in order")
game.Pass()
local menu = GameMenuFrame
Equal(Look.Menu.built, false, "the menu closed: nothing built yet")
Equal(#(st[menu].hooks.OnShow or {}), 1, "its opening post-hooked once")
game.Pass()
Equal(#(st[menu].hooks.OnShow or {}), 1, "and only once")
menu:Show()
Equal(Look.Menu.built, true, "built the first time it opens")
local border = menu.Border
Equal(st[st[border].regions[1]].alpha .. st[st[st[border].children[1]].regions[1]].alpha, "00", "its modern border faded, children too")
local box = Look.Menu.box
Equal(st[box].template .. " " .. tostring(st[box].parent == menu) .. " " .. st[box].level, "BackdropTemplate true 5", "a dialog box of EraUI's, at the menu's level")
Equal(Spot(box, "TOPLEFT") .. " / " .. Spot(box, "BOTTOMRIGHT"), "TOPLEFT GameMenuFrame 0,0 / BOTTOMRIGHT GameMenuFrame 0,0", "on all its points")
local backdrop = st[box].backdrop
Equal(backdrop.bgFile .. " " .. backdrop.edgeFile .. " " .. backdrop.tileSize .. " " .. backdrop.edgeSize,
    "Interface\\DialogFrame\\UI-DialogBox-Background Interface\\DialogFrame\\UI-DialogBox-Border 32 32", "the old dialog art")
Equal(backdrop.insets.left .. backdrop.insets.right .. backdrop.insets.top .. backdrop.insets.bottom, "11121211", "its insets")
Equal(game.dark[box], "box", "handed to Dark Windows")
local header = menu.Header
Equal(st[header.LeftBG].alpha .. st[header.RightBG].alpha .. st[header.CenterBG].alpha, "000", "the modern header faded")
local plate = Look.Menu.plate
Equal(st[plate].file .. " " .. st[plate].width .. "x" .. st[plate].height .. " " .. st[plate].layer,
    "Interface\\DialogFrame\\UI-DialogBox-Header 256x64 BACKGROUND", "the old header plate")
Equal(Spot(plate, "TOP"), "TOP GameMenuFrame 0,12", "on the menu's top")
Equal(game.dark[plate], "frame", "handed to Dark Windows")
Equal(st[header.Text].text .. " " .. st[st[header.Text].font].name, "Main Menu EraUILookGold", "Main Menu in gold")
local first = game.menuButtons[1]
Equal(st[first.Left].alpha .. st[first.Right].alpha .. st[first.Center].alpha, "000", "a button's three slices faded")
local normal = first:GetNormalTexture()
Equal(st[normal].file .. " " .. table.concat(st[normal].coords, ","), "Interface\\Buttons\\UI-Panel-Button-Up 0,0.625,0,0.6875", "the red panel art")
Equal(Spot(normal, "TOPLEFT") .. " / " .. Spot(normal, "BOTTOMRIGHT"), "TOPLEFT ? 0,-1 / BOTTOMRIGHT ? 0,1", "21 tall in its 23")
Equal(st[first:GetHighlightTexture()].blend, "ADD", "its glow additive")
Equal(game.dark[first], "button", "handed to Dark Windows")
Equal(st[st[first].normalFont].name .. " " .. st[st[first].disabledFont].name, "GameFontHighlight GameFontDisable", "its fonts")
Equal(Spot(first:GetFontString(), "CENTER"), "CENTER ? 0,-1", "its label one down")
Equal(st[first].width .. "x" .. st[first].height, "144x23", "144 x 23")
Equal(select(5, first:GetPoint(1)), -30, "each button 18 up (48 down in the game's layout)")
Equal(st[menu].height, 190 - 18, "the menu 18 shorter")
-- Opened again: the game makes and lays out its buttons again; dressed again.
menu:Hide()
menu:Show()
Equal(select(5, game.menuButtons[3]:GetPoint(1)), -(48 + 72) + 18, "opened again: still compact")
Equal(st[menu].height, 172, "and 18 shorter, once")
-- The game making its buttons again on its own (its InitButtons, hooked once).
local added = game.Building(function()
    local button = game.New("Button", nil, menu)
    game.Pieces(button, "Left Right Center")
    return button
end)
game.Seal()
table.insert(game.menuButtons, added)
menu:InitButtons()
Equal(st[added].width .. " " .. st[added:GetNormalTexture()].file, "144 Interface\\Buttons\\UI-Panel-Button-Up", "a button made again: dressed at once")
Equal(game.hookCounts[menu].InitButtons, 1, "InitButtons post-hooked once")
-- In a fight nothing is dressed.
local fresh = game.Building(function()
    local button = game.New("Button", nil, menu)
    game.Pieces(button, "Left Right Center")
    return button
end)
game.Seal()
table.insert(game.menuButtons, fresh)
game.combat = true
menu:Hide()
menu:Show()
Equal(fresh:GetNormalTexture(), nil, "in a fight: a new button left as the game made it")
Equal(st[fresh].width, nil, "and its size")
game.combat = false
menu:Hide()
menu:Show()
Equal(st[fresh].width .. " " .. st[fresh:GetNormalTexture()].file, "144 Interface\\Buttons\\UI-Panel-Button-Up", "out of the fight, the next opening dresses it")
-- Restore: a reload asked for, nothing undone.
ns.db.gameMenu = false
game.Pass()
Equal(ns.needsReload, true, "off: a reload asked for")
menu:Hide()
local later = game.Building(function()
    local button = game.New("Button", nil, menu)
    game.Pieces(button, "Left Right Center")
    return button
end)
game.Seal()
table.insert(game.menuButtons, later)
menu:Show()
Equal(later:GetNormalTexture(), nil, "off: a new button left alone")
NoErrors("the game menu")
-- Off from login: nothing built, no reload asked for.
Session()
ns.db.gameMenu = false
game.Pass()
GameMenuFrame:Show()
Equal(tostring(Look.Menu.built) .. " " .. tostring(ns.needsReload), "false nil", "off from login: nothing built and nothing to clear")
-- The menu open when the look goes on: built at once.
Session()
GameMenuFrame:Show()
game.Pass()
Equal(Look.Menu.built, true, "the menu open at the pass: built at once")
NoErrors("the game menu, other starts")

---------------------------------------------------------------------------
-- The Settings window
---------------------------------------------------------------------------
Session()
local panel = env.SettingsPanel
local headerRow, chosenRow = CategoryRow(true), CategoryRow(false)
local check = SettingRow("check")
local slider = SettingRow("slider")
local drop = SettingRow("dropdown")
local expand = SettingRow("expand")
local red = SettingRow("button")
local titled = SettingRow("title")
for i, row in ipairs({ check, slider, drop, expand, red, titled }) do st[row].data = { i } end
game.Seal()
game.Pass()
Equal(Look.SettingsSkin.built, false, "the Settings window closed: nothing built")
panel:Show()
Equal(Look.SettingsSkin.built, true, "built as it opens")
Equal(st[st[panel.NineSlice].regions[1]].alpha, 0, "its modern frame faded")
Equal(st[st[panel.Bg].regions[1]].alpha .. st[st[st[panel.Bg].children[1]].regions[1]].alpha, "00", "its background and the background's children")
local inner = game.Find(function(s) return s.parent == panel and s.atlas == "Options_InnerFrame" end)
Equal(st[inner].alpha, 0, "its own inner frame art")
local sBox = Look.SettingsSkin.box
Equal(st[sBox].backdrop.edgeFile .. " " .. st[sBox].level .. " " .. game.dark[sBox], "Interface\\DialogFrame\\UI-DialogBox-Border 8 box",
    "the old dialog box, at its level, handed to Dark Windows")
local sPlate = Look.SettingsSkin.plate
Equal(st[sPlate].layer .. " " .. Spot(sPlate, "TOP") .. " " .. game.dark[sPlate], "ARTWORK TOP SettingsPanel 0,12 frame", "the header plate")
Equal(Spot(panel.NineSlice.Text, "TOP") .. " " .. st[st[panel.NineSlice.Text].font].name, "TOP ? 0,-14 EraUILookGold", "the title on the plate, in gold")
local x = panel.ClosePanelButton
Equal(st[x:GetNormalTexture()].file .. " " .. Spot(x, "TOPRIGHT"), "Interface\\Buttons\\UI-Panel-MinimizeButton-Up TOPRIGHT SettingsPanel -4,-4", "the 1.x X")
local gameTab = panel.GameTab
Equal(st[gameTab.Left].alpha, 0, "the tabs' modern pieces faded")
local tabLeft = Look.OwnPiece(gameTab, "optionsTabLeft")
Equal(st[tabLeft].file .. " " .. st[tabLeft].width .. "x" .. st[tabLeft].height, "Interface\\AddOns\\EraUI\\Media\\Classic\\UI-OptionsFrame-InActiveTab 20x32",
    "the old options tab art")
gameTab:SetSelected(true)
Equal(st[tabLeft].file, "Interface\\AddOns\\EraUI\\Media\\Classic\\UI-OptionsFrame-ActiveTab", "chosen: the active art at once")
Equal(st[st[gameTab.Text].font].name, "GameFontHighlightSmall", "its text white")
Equal(st[panel.CloseButton:GetNormalTexture()].file .. " " .. st[panel.ApplyButton.Left].alpha, "Interface\\Buttons\\UI-Panel-Button-Up 0",
    "Close and Apply as red panel buttons")
local insets = game.FindAll(function(s) return s.parent == panel and not s.game and s.backdrop and s.backdrop.edgeFile == "Interface\\Tooltips\\UI-Tooltip-Border" end)
Equal(#insets, 2, "two thin bordered insets")
local categoryInset = insets[1]
Equal(Spot(categoryInset, "TOPLEFT") .. " / " .. Spot(categoryInset, "BOTTOMRIGHT"), "TOPLEFT ? 0,8 / BOTTOMRIGHT ? 8,-8", "round the category list")
Equal(table.concat(st[categoryInset].backdropColour, ",") .. " " .. table.concat(st[categoryInset].borderColour, ","), "0.34,0.32,0.3,0.55 0.6,0.6,0.6,1",
    "in the old shades")
Equal(game.dark[categoryInset], nil, "not handed to Dark Windows (not the dialog border)")
Equal(Spot(gameTab, "BOTTOMLEFT"), "TOPLEFT ? 10,-2", "the Game tab on the inset")
Equal(Spot(insets[2], "TOPLEFT") .. " / " .. Spot(insets[2], "BOTTOMRIGHT"), "TOPLEFT ? -8,8 / BOTTOMRIGHT ? 8,-8", "round the page")
Equal(st[panel.CategoryList.ScrollBar.Track.Begin].alpha .. st[panel.Container.SettingsList.ScrollBar.Track.Begin].alpha, "00", "both scroll bars in the 1.x art")
local listHeader = panel.Container.SettingsList.Header
Equal(st[st[listHeader].regions[1]].alpha .. " " .. st[listHeader.DefaultsButton:GetNormalTexture()].file .. " " .. st[st[listHeader.Title].font].name,
    "0 Interface\\Buttons\\UI-Panel-Button-Up GameFontHighlightLarge", "the page's header: faded, Defaults red, the title large")
-- The category rows.
Equal(st[headerRow.Background].alpha .. " " .. st[st[headerRow.Label].font].name, "0 GameFontHighlight", "a header row: no background, white label")
Equal(table.concat(st[chosenRow.Label].textColour, ","), "1,0.82,0", "a category's label gold")
chosenRow.Label:SetFontObject(GameFontHighlight)
Equal(table.concat(st[chosenRow.Label].textColour, ","), "1,0.82,0", "kept gold after the game sets its font again")
local bar = chosenRow.Texture
Equal(st[bar].file .. " " .. table.concat(st[bar].colour, ",") .. " " .. st[bar].blend,
    "Interface\\QuestFrame\\UI-QuestLogTitleHighlight 1,1,0,1 ADD", "the chosen category's bar in the old highlight")
bar:SetAtlas("Options_List_Hover")
Equal(st[bar].file, "Interface\\QuestFrame\\UI-QuestLogTitleHighlight", "kept after the game sets its atlas again")
-- The settings rows.
Equal(table.concat(st[check.Text].textColour, ","), "1,0.82,0", "a setting's name gold")
Equal(st[check.Checkbox:GetNormalTexture()].file .. " " .. st[check.Checkbox.HoverBackground].alpha, "Interface\\Buttons\\UI-CheckBox-Up 0", "the 1.x check box")
local sliderFrame = slider.SliderWithSteppers
Equal(st[sliderFrame.Slider.Left].alpha, 0, "the slider's modern track faded")
local track = game.Find(function(s) return s.parent == sliderFrame.Slider and not s.game and s.backdrop end)
Equal(st[track].backdrop.bgFile .. " " .. st[track].height, "Interface\\Buttons\\UI-SliderBar-Background 17", "the old slider track")
Equal(st[sliderFrame.Slider:GetThumbTexture()].file, "Interface\\Buttons\\UI-SliderBar-Button-Horizontal", "the round thumb")
Equal(tostring(st[sliderFrame.Back:GetNormalTexture()].desaturated) .. " " .. st[sliderFrame.Back].alpha, "true 1", "its steppers drained of colour, kept")
local dropdown = drop.Control.Dropdown
Equal(st[dropdown.Background].alpha .. st[dropdown.Arrow].alpha .. st[dropdown:GetHighlightTexture()].alpha, "000", "the drop down's modern art faded")
Equal(Look.OwnPiece(dropdown, "dropLeft") ~= nil and st[dropdown.Text].justify, "LEFT", "the old label frame round it")
local inc = drop.Control.IncrementButton
Equal(st[inc:GetNormalTexture()].file .. " " .. st[inc:GetNormalTexture()].width, "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up 26", "the spellbook's page arrows")
Equal(st[drop.Control.DecrementButton:GetNormalTexture()].file, "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up", "back and forward")
local header2 = expand.Button
Equal(st[header2.Left].alpha .. st[header2:GetHighlightTexture()].alpha, "00", "an expand header's art faded")
Equal(st[st[header2.Text].font].name .. " " .. Spot(header2.Text, "TOPLEFT"), "EraUILookGold TOPLEFT ? 8,0", "its text gold across it")
Equal(st[Look.OwnPiece(header2, "settingsGlow")].file, "Interface\\QuestFrame\\UI-QuestLogTitleHighlight", "the old highlight on hover")
Equal(st[red.Button:GetNormalTexture()].file, "Interface\\Buttons\\UI-Panel-Button-Up", "a plain button red")
Equal(st[st[titled.Title].font].name, "GameFontHighlightLarge", "a title row large")
-- A row reused for another setting (the page scrolled) is dressed again;
-- the same row with the same data isn't.
st[check.Text].textColour = nil
panel:Show()
game.Tick(0.1)
Equal(st[check.Text].textColour, nil, "the same data: not dressed again")
st[check].data = { "another" }
game.Tick(0.1)
Equal(table.concat(st[check.Text].textColour, ","), "1,0.82,0", "new data: dressed again by the watch")
local late = game.Building(function() return SettingRow("check") end)
game.Seal()
st[late].data = { "late" }
game.Tick(0.1)
Equal(st[late.Checkbox:GetNormalTexture()].file, "Interface\\Buttons\\UI-CheckBox-Up", "a row the game adds: dressed by the watch")
local lateCategory = game.Building(function() return CategoryRow(false) end)
game.Seal()
game.Tick(0.1)
Equal(table.concat(st[lateCategory.Label].textColour, ","), "1,0.82,0", "a category row the game adds too")
-- Restore: a reload asked for; the gold and the bar left to the game.
ns.db.settingsPanel = false
game.Pass()
Equal(ns.needsReload, true, "off: a reload asked for")
chosenRow.Label:SetFontObject(GameFontHighlight)
Equal(table.concat(st[chosenRow.Label].textColour, ","), "1,1,1", "off: the game's own label colour stays")
Equal(game.hookCounts[chosenRow.Label].SetFontObject, 1, "hooked once")
NoErrors("the Settings window")
-- Off from login: nothing built, no reload asked for.
Session()
ns.db.settingsPanel = false
game.Pass()
env.SettingsPanel:Show()
Equal(tostring(Look.SettingsSkin.built) .. " " .. tostring(ns.needsReload), "false nil", "off from login: nothing built and nothing to clear")
NoErrors("the Settings window off")

print("Windows and settings checks passed: " .. checks .. " assertions.")
