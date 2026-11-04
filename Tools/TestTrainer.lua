-- The classic trainer (Look/Trainer*.lua on Look/SkillShell.lua, clean-room
-- 2026-10-21) over a mock of the game's trainer window (Tools/SpellMockGame.lua
-- plus the trainer's virtual list, its rows and Train). The game's own
-- buttons do every selection and purchase; EraUI only routes secure clicks
-- to them. The mock fails on: a key written on any of the game's frames, a
-- game script replaced, the game's Train turned on or off by EraUI, the
-- game's row set-up, selection or purchase called by EraUI, the virtual list
-- resized or rescaled outside restricted code, Execute or a protected
-- attribute in a fight, any state driver (Squirt's call, 2026-10-21: the old
-- combat shield is gone), and a game piece faded before the classic layout
-- shows. Also: the greeting's room above the list (never cut, two lines,
-- the small font or the game's "..." when longer), the money box's border
-- handed to Dark Windows, and that nothing taking the mouse ever sits over
-- the game's Train, in a fight too.
local Mock = dofile("Tools/SpellMockGame.lua")
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local game = Mock.New()
local env = game.env
local G = game.GameFrame
local catalog, filters = {}, { available = true, unavailable = true, used = true }
for i = 1, 14 do catalog[i] = { name = "Ability " .. i, cost = i == 1 and 5 or 1, level = i == 1 and 12 or 1, kind = "available", category = "Pet" } end
local trainerType, points, petLevel, money = 1, 3, 11, 100
local greetingText = "Learn an ability."
local purchases, confirmations, cursor = {}, 0, { -100, -100 }
local darkRoles = {}

env.Enum = { TrainerType = { Pet = 1, General = 2, Tradeskills = 3 } }
env.C_Trainer = { GetTrainerType = function() return trainerType end }
env.C_PetInfo = { GetPetTrainingPoints = function() return points, 0 end }
env.C_CurrencyInfo = { GetCoinTextureString = function(cost) return cost .. " copper" end }
env.UnitLevel = function(unit) return unit == "pet" and petLevel or 60 end
env.GetMoney = function() return money end
env.GetCursorPosition = function() return cursor[1], cursor[2] end
env.GetNumTrainerServices = function() return #catalog end
env.GetTrainerServiceInfo = function(index)
    local row = catalog[index]
    if row then return row.name, row.kind, "icon-" .. index, row.level, "Rank 1", row.category end
end
env.GetTrainerServiceCost = function(index) return catalog[index].cost, catalog[index].profession end
env.GetTrainerServiceStepIndex = function() return trainerType == env.Enum.TrainerType.Tradeskills and #catalog or nil end
env.GetTrainerServiceSkillReq = function() return nil end
env.GetTrainerServiceNumAbilityReq = function() return 0 end
env.GetTrainerServiceDescription = function(index) return "Description " .. index end
env.GetTrainerGreetingText = function() return greetingText end
env.GetTrainerServiceTypeFilter = function(kind) return filters[kind] end
env.SetTrainerServiceTypeFilter = function(kind, value) filters[kind] = value; game.Fire("TRAINER_UPDATE") end
env.BuyTrainerService = function() error("addon purchase call") end
env.SelectTrainerService = function() error("addon selection call") end
env.HideUIPanel = function(frame) game.Native(function() frame:Hide() end) end
for _, name in ipairs({ "ClassTrainerFrame_InitCategoryButton", "ClassTrainerFrame_Update", "ClassTrainer_SetSelection",
    "ClassTrainerFrame_UpdateTrainingPoints", "ClassTrainerFrame_InitServiceButton" }) do
    env[name] = function() assert(game.native, "EraUI ran the game's " .. name) end
end
-- Text: the greeting's font, line limit and the game's truncation (about 40
-- characters of the window's font a line across the greeting, 52 small).
local PER_LINE = { GameFontHighlight = 40, GameFontHighlightSmall = 52 }

game.Load("Look/Base.lua")
game.ns.DarkWindowArt = function(texture, role) darkRoles[texture] = role end
for _, file in ipairs({ "Look/SpellKit.lua", "Look/SkillShell.lua", "Look/TrainerKit.lua", "Look/TrainerList.lua", "Look/TrainerModule.lua" }) do
    game.Load(file)
end
local R = game.E.Look.Trainer
local module = game.ns.modules.trainer
module.apply()
Equal(R.panel, nil, "nothing built before the trainer's UI loads")

-- The game's trainer window, as Blizzard_TrainerUI builds it.
local window = G("Frame", "ClassTrainerFrame", env.UIParent)
local pool = {}
game.Native(function()
    window:SetSize(338, 424)
    window:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 16, -116)
    for _, key in ipairs({ "ScrollBox", "ScrollBar", "money", "trainingPoints", "FilterDropdown", "FilterInputHint", "BG",
        "Inset", "bottomInset" }) do
        window[key] = G("Frame", nil, window)
        window[key]:SetSize(100, 20)
        window[key]:SetPoint("TOPLEFT", window, "TOPLEFT", 10, -10)
    end
    window.TrainButton = G("Button", "ClassTrainerTrainButton", window)
    window.TrainButton:SetSize(80, 22)
    window.TrainButton:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, 0)
    window.skillStepButton = G("Button", nil, window)
    window.ScrollBox:SetSize(302, 330)
    window.selectedService = 21
    window.displayIndexToSkillIndex = {}
end)
local list, train = window.ScrollBox, window.TrainButton
env.ClassTrainerFrameMoneyBg = G("Texture", "ClassTrainerFrameMoneyBg", window)
env.ClassTrainerStatusBar = G("StatusBar", "ClassTrainerStatusBar", window)
-- Traps on the game's pieces.
game.Native(function()
    for _, name in ipairs({ "SetHeight", "SetScale" }) do
        local own = list[name]
        list[name] = function(self, ...)
            assert(game.restricted, "the virtual list " .. name .. " outside restricted code")
            own(self, ...)
            if name == "SetHeight" and list.rebuild then list.rebuild() end
        end
    end
    train.SetEnabled = function(self, on)
        assert(game.native, "EraUI changed the game's Train button's enabled state")
        rawset(self, "enabled", on and true or false)
        self:Fire(on and "OnEnable" or "OnDisable")
    end
end)
local fadedBeforeLayout = false
for _, piece in ipairs({ list, window.ScrollBar, window.BG, window.Inset, train, env.ClassTrainerFrameMoneyBg }) do
    game.Native(function()
        piece.SetAlpha = function(self, a)
            if a == 0 and not (env.EraUIClassicTrainer and env.EraUIClassicTrainer:IsShown()) then fadedBeforeLayout = true end
            rawset(self, "alpha", a)
        end
    end)
end

local function Initialize(button, index)
    button.displayIndex = env.GetTrainerServiceStepIndex() == index and 0 or index + 20
    button.elementData = { data = { skillIndex = index } }
    window.displayIndexToSkillIndex[button.displayIndex] = index
    local row = catalog[index]
    if window.selectedService == button.displayIndex then
        window.showDialog = row.profession
        local affordable = row.cost <= (trainerType == 1 and points or money)
        local reached = row.level <= (trainerType == 1 and petLevel or 60)
        train:SetEnabled(row.kind == "available" and affordable and reached)
    end
    env.ClassTrainerFrame_InitServiceButton(button)
end
local function NativeRows()
    game.Native(function()
        local shown = {}
        for i = 1, math.min(#catalog, math.floor(list:GetHeight() / 47)) do
            if not pool[i] then
                pool[i] = G("Button", nil, list)
                pool[i]:SetScript("OnClick", function(self)
                    game.Native(function()
                        window.selectedService = self.displayIndex
                        Initialize(self, self.elementData.data.skillIndex)
                        env.ClassTrainer_SetSelection()
                    end)
                end)
                pool[i].GetElementData = function(self) return self.elementData end
            end
            Initialize(pool[i], i)
            shown[#shown + 1] = pool[i]
        end
        list.shown = shown
        if env.GetTrainerServiceStepIndex() then
            Initialize(window.skillStepButton, #catalog)
            window.skillStepButton:SetScript("OnClick", pool[#catalog].scripts.OnClick)
            function window.skillStepButton:GetElementData() return self.elementData end
        end
    end)
end
game.Native(function()
    list.rebuild = NativeRows
    function list:ForEachFrame(fn) for _, row in ipairs(self.shown or {}) do fn(row) end end
    train:SetScript("OnClick", function()
        game.Native(function()
            if not train:IsEnabled() then return end
            if window.showDialog then confirmations = confirmations + 1
            else purchases[#purchases + 1] = window.displayIndexToSkillIndex[window.selectedService] end
        end)
    end)
end)
-- Clicking where Train is: whatever takes the mouse highest over that spot.
local function Overlaps(a, b)
    local al, ab, ar, at = a:Rect()
    local bl, bb, br, bt = b:Rect()
    if not (al and bl) then return false end
    return al < br and bl < ar and ab < bt and bb < at
end
local function Strata(f) return ({ BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 })[f.strata] or 3 end
local function OverTrain()
    local over = {}
    for _, f in ipairs(game.frames) do
        if f ~= train and f.mouse and f:IsVisible() and f.kind ~= "Texture" and f.kind ~= "FontString" and Overlaps(f, train)
            and (Strata(f) > Strata(train) or (Strata(f) == Strata(train) and f.level > train.level)) then over[#over + 1] = f end
    end
    return over
end
local function ClickAtTrain()
    if #OverTrain() > 0 then return end
    train:Click("LeftButton", false)
end
local function Flush() game.Settle() end

NativeRows()
game.Fire("ADDON_LOADED", "Blizzard_TrainerUI")
game.Native(function() window:Hide(); window:Show() end)
Flush()
local panel = env.EraUIClassicTrainer
local shell, rows = R.shell, R.shell.rows
Equal(fadedBeforeLayout, false, "no game piece faded before the classic layout showed")
Equal(#rows, 9, "the compact list: nine rows")
Equal(R.rowLine[rows[1]].header, true, "a category header first")
Equal(rows[2].attrs.clickbutton, pool[1], "the first service routes to the game's first row")
Equal(#list.shown, 14, "every service has a game row (the list made tall)")
Equal(list.scale, 0.01, "and tiny")
Equal(list.alpha, 0, "the game's large list faded")
Equal(R.detail.name.text, "Ability 1", "the separate detail panel filled")
Equal(R.detail.face.file, "icon-1", "with the chosen ability's icon")
Equal(R.detail.needs.text:find("|cffff2020Level 12", 1, true) ~= nil, true, "a level the pet hasn't reached in red")
Equal(R.detail.cost.text:find("5 TP", 1, true) ~= nil and R.detail.cost.text:find("|cffff2020", 1, true) ~= nil, true,
    "pet costs in training points, red when short")
Equal(R.points.text, "Training Points: 3", "the pet's free points in the footer")
Equal(R.trainArt.enabled, false, "the Train art off like the game's")
Equal(R.trainArt.mouse, false, "the Train art takes no mouse")
Equal(R.trainArt.scripts.OnClick, nil, "and has no click of its own")
Equal(train.points[1][2], R.trainArt, "the game's Train laid over EraUI's art")
Equal(train.alpha .. " " .. tostring(train.level > panel.level), "0 true", "invisible, above the panel")
Equal(env.ClassTrainerFrameMoneyBg.alpha, 0, "the money backing faded")
Equal(window.money.points[1][2] == panel and window.money.points[1][4] == 18, true, "the money moved into EraUI's box")
Equal(env.ClassTrainerFrameMoneyBg.points[1], nil, "the money backing's own anchors never touched")
Equal(R.empty:IsShown(), false, "a full list hides the empty message")

-- The greeting: its own room between the title strip and the list.
local box, greeting = R.greetingBox, R.greeting
Equal(R.stone.points[1][4] .. "," .. R.stone.points[1][5] .. " " .. R.stone.parent.name, "4,-50 EraUIClassicTrainer",
    "the stone under it from (4, -50)")
Equal(box.parent == panel and box.kind == "Frame" and box.level > R.stone.level, true, "a plain frame on the layout, above the stone")
local top, bottom = box.points[1], box.points[2]
Equal(top[1] .. " " .. top[3] .. " " .. top[4] .. " " .. top[5], "TOPLEFT TOPLEFT 72 -21", "it starts right of the portrait, below the title strip")
Equal(bottom[1] .. " " .. bottom[3] .. " " .. bottom[4] .. " " .. bottom[5], "BOTTOMRIGHT TOPRIGHT -14 -52",
    "and ends above the list's tab (from -53) and Filter (from -57)")
Equal(greeting.parent == box and greeting.maxLines == 2 and greeting.wrap == true, true, "two wrapped lines at most")
Equal(box.mouse, false, "the greeting takes no mouse")
local function Greet(text)
    greetingText = text
    game.Fire("TRAINER_UPDATE")
    Flush()
end
local function Truncated() return math.ceil(#(greeting.text or "") / PER_LINE[greeting.font]) > 2 end
greeting.IsTruncated = Truncated
Greet("Enchanting is the art of improving existing items through magic.")
Equal(greeting.font, "GameFontHighlight", "two lines' worth keeps the window's font")
Greet(string.rep("A longer greeting, ", 5))
Equal(greeting.font, "GameFontHighlightSmall", "three lines' worth takes the small font")
Greet("")
Equal(greeting.text .. "|" .. greeting.font, "|GameFontHighlight", "no greeting: nothing, the window's font")
Greet(nil)
Equal(greeting.text, "", "a trainer without a greeting shows nothing")
Greet("Learn an ability.")
Equal(greeting.font, "GameFontHighlight", "the next trainer starts in the window's font again")
-- Dark Windows: the money oval is frame art, Train's glow a glow.
Equal(R.oval.file, "Interface\\MoneyFrame\\UI-MoneyFrame-Border", "the money box's oval")
Equal(darkRoles[R.oval] .. " " .. darkRoles[R.trainGlow], "frame glow", "handed to Dark Windows as frame and glow")
Equal(R.trainGlow.file, R.trainArt:GetHighlightTexture().file, "Train's glow is a copy of the art's own highlight")
-- Nothing takes the mouse over Train.
Equal(train:Rect() ~= nil and Overlaps(panel, train) and panel.mouse == true and panel.level < train.level, true,
    "setup: the geometry resolves (the panel, which takes the mouse, lies under Train)")
Equal(#OverTrain(), 0, "nothing of EraUI's over the game's Train")

-- The window shown again: laid out at once, before any timer.
game.Native(function() window:Hide() end)
panel:Hide()
game.Native(function() window:Show() end)
Equal(panel:IsShown(), true, "the game's OnShow brings the layout back before any timer")
Flush()

-- Selecting through the game's own rows.
rows[3]:Click("LeftButton", false)
Equal(rows[3].attrs.clickbutton, nil, "the game updating its rows unroutes EraUI's at once")
Flush()
Equal(R.detail.name.text, "Ability 2", "the game's selection fills the details")
Equal(R.trainArt.enabled, true, "an affordable ability: the art on like the game's Train")
cursor[1], cursor[2] = 0, 0
local l, b, w, h = R.trainArt:GetRect()
cursor[1], cursor[2] = l + 10, b + 10
R.GlowTick(R.trainArt, 0.06)
Equal(R.trainGlow:IsShown(), true, "the cursor over Train lights its glow (no frame, no mouse)")
cursor[1] = l - 10
R.GlowTick(R.trainArt, 0.06)
Equal(R.trainGlow:IsShown(), false, "and leaving puts it out")
game.Native(function() panel.scale = 0.5 end)
cursor[1], cursor[2] = (l + w * 0.75) * 1, b + 2
R.GlowTick(R.trainArt, 0.06)
Equal(R.trainGlow:IsShown(), false, "the art's effective scale is used")
game.Native(function() panel.scale = 1 end)
cursor[1], cursor[2] = l + 10, b + 10
R.GlowTick(R.trainArt, 0.06)
ClickAtTrain()
Equal(purchases[1], 2, "clicking Train buys the chosen ability through the game's own button")
points = 17
game.Fire("UNIT_PET_TRAINING_POINTS")
Flush()
Equal(R.points.text, "Training Points: 17", "pet point events update the footer")
catalog[2].kind = "used"
NativeRows()
Equal(R.trainGlow:IsShown(), false, "the game turning Train off clears the glow before the refresh")
Flush()
Equal(R.detail.cost.text, "", "a known ability shows no cost")
Equal(R.trainArt.enabled, false, "and Train stays off")
catalog[2].kind = "available"
NativeRows()
Flush()
shell.bar:SetValue(6)
rows[9]:Click("LeftButton", false)
Flush()
Equal(R.detail.name.text, "Ability 14", "the last compact page selects a game row off the first page")
ClickAtTrain()
Equal(purchases[2], 14, "and Train buys that one")

-- A profession trainer: the step service and the game's confirmation.
trainerType = env.Enum.TrainerType.Tradeskills
catalog[14].profession = true
NativeRows()
Flush()
rows[9]:Click("LeftButton", false)
Flush()
ClickAtTrain()
Equal(window.selectedService, 0, "the profession step keeps the game's display index 0")
Equal(confirmations, 1, "the game's confirmation still asks")
Equal(#purchases, 2, "no purchase bypasses it")
Equal(R.points:IsShown(), false, "no pet points on a coin trainer")
Equal(R.detail.cost.text:find("copper", 1, true) ~= nil, true, "coin costs")

-- Recycled rows, folding, the game's collapsed category, All, Filter.
catalog[14].name = "Replacement ability"
NativeRows()
Equal(rows[9].attrs.clickbutton, nil, "recycled game rows unroute EraUI's before the repaint")
Flush()
Equal(rows[9].attrs.clickbutton ~= nil and R.rowParts[rows[9]].text.text, "Replacement ability (Rank 1)", "the row's text matches its target")
shell.bar:SetValue(0)
rows[1]:Click("LeftButton", false)
Flush()
Equal(rows[2]:IsShown(), false, "folding a category hides its abilities")
Equal(R.empty:IsShown(), false, "a folded list isn't called empty")
rows[1]:Click("LeftButton", false)
Flush()
Equal(rows[2]:IsShown() and rows[2].attrs.clickbutton ~= nil, true, "opening it routes them again")
local closed = true
local category = G("Button", nil, list)
game.Native(function()
    category.elementData = { data = { categoryInfo = { name = "Pet" } }, IsCollapsed = function() return closed end }
    function category:GetElementData() return self.elementData end
    category:SetScript("OnClick", function()
        game.Native(function()
            closed = not closed
            env.ClassTrainerFrame_InitCategoryButton()
        end)
    end)
    table.insert(list.shown, 1, category)
end)
game.Fire("TRAINER_UPDATE")
Flush()
Equal(rows[2]:IsShown(), false, "the game's collapsed category hides the abilities")
Equal(rows[1].attrs.clickbutton, category, "and is routed to the game's own category button")
rows[1]:Click("LeftButton", false)
Flush()
Equal(closed, false, "it opens through the game's own button")
Equal(rows[2]:IsShown(), true, "and the list follows")
shell.all:Click("LeftButton", false)
Flush()
Equal(rows[2]:IsShown(), false, "All folds every category")
shell.all:Click("LeftButton", false)
Flush()
Equal(rows[2]:IsShown(), true, "and opens them again")
shell.filter:Click("LeftButton", false)
Equal(R.filterList.frame:IsShown(), true, "the Filter opens its list")
local known = R.filterList.frame.children[3]
known:Click("LeftButton", false)
Flush()
Equal(filters.used, false, "Already Known flips the game's own filter")

-- A fight: nothing refreshed or re-routed, the layout stays, nothing over Train.
game.EnterCombat()
Equal(R.trainGlow:IsShown(), false, "no glow in a fight")
local before = rows[2].attrs.clickbutton
game.Fire("TRAINER_UPDATE")
Flush()
Equal(panel:IsShown(), true, "the classic layout stays up in a fight")
Equal(rows[2].attrs.clickbutton, before, "the rows keep their routes in a fight (nothing re-armed)")
Equal(#OverTrain(), 0, "nothing of EraUI's takes the mouse over Train in a fight (no shield)")
game.LeaveCombat()
Flush()
Equal(rows[2].attrs.clickbutton, pool[1], "routes refreshed after the fight")

-- Empty lists.
local full = catalog
catalog = {}
trainerType = env.Enum.TrainerType.Pet
game.Native(function() window.selectedService = nil end)
NativeRows()
game.Fire("TRAINER_UPDATE")
Flush()
Equal(R.empty:IsShown() and R.empty.text, "No abilities match the current filters.", "an empty filtered list says so")
Equal(filters.used, false, "and leaves the player's filter alone")
catalog = { { cost = 1, level = 1, kind = "available" } }
NativeRows()
game.Fire("TRAINER_UPDATE")
Flush()
Equal(R.empty.text, "Loading abilities...", "services with no names yet: loading")
catalog = full
NativeRows()
game.Fire("TRAINER_UPDATE")
Flush()
Equal(R.empty:IsShown(), false, "named services remove the message")

-- On again adds no second hook; off gives the game's trainer back.
local hooks = game.hooks
module.apply()
Flush()
Equal(game.hooks, hooks, "applying again adds no second hook")
module.restore()
Equal(panel:IsShown(), false, "off: the classic layout hidden")
Equal(list.height .. " " .. list.scale, "330 1", "the game's list back to its own height and scale")
Equal(list.alpha .. " " .. train.alpha, "1 1", "the game's list and Train seen again")
Equal(train.points[1][2], window, "Train back on its own anchor")
Equal(rows[2].attrs.clickbutton, nil, "no route left")
module.apply()
Flush()
Equal(panel:IsShown() and rows[2].attrs.clickbutton == pool[1], true, "on again: the layout and its routes")
module.restore()
Equal(list.height, 330, "a second restore keeps the game's own height")
local polled = 0
for _, f in ipairs(game.frames) do
    if f.scripts.OnUpdate and f ~= R.trainArt and f.parent ~= nil and f ~= R.filterList.frame then polled = polled + 1 end
end
Equal(polled, 0, "only Train's art looks at anything on a timer (no trainer data polling)")
Equal(#game.errors, 0, "no error reported")
print("Trainer: " .. checks .. " assertions passed")
