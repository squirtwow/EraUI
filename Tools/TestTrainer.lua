-- Compact trainer layout and native-control ownership regression. The secure
-- execution model is deliberately narrow; only the actual client proves taint.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
unpack = table.unpack or unpack
function wipe(t) for key in pairs(t) do t[key] = nil end end
local secure, combat = false, false
local frames, states, hooks, timers, drivers = {}, {}, {}, {}, {}
local methods = {}
local function Native(fn, ...)
    local previous = secure
    secure = true
    fn(...)
    secure = previous
end
local function Post(name, ...)
    local previous = secure
    secure = false
    for _, fn in ipairs(hooks[name] or {}) do fn(...) end
    secure = previous
end
local function Frame(kind, name, parent, template, native)
    local state = { kind = kind, name = name, parent = parent, template = template, native = native,
        scripts = {}, scriptHooks = {}, events = {}, attrs = {}, refs = {}, points = {}, shown = true,
        alpha = 1, scale = 1, width = 302, height = 330, level = 5, enabled = true, value = 0 }
    local f = setmetatable({}, {
        __index = function(_, key) return methods[key] or state[key] end,
        __newindex = function(_, key, value)
            assert(not native or secure, "addon wrote native field: " .. key)
            state[key] = value
        end,
    })
    states[f] = state
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
function CreateFrame(...) return Frame(...) end
function methods:SetScript(key, fn)
    assert(not self.native, "addon replaced a native script")
    self.scripts[key] = fn
end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:HookScript(key, fn)
    self.scriptHooks[key] = self.scriptHooks[key] or {}
    table.insert(self.scriptHooks[key], fn)
end
function methods:UnregisterAllEvents() wipe(self.events) end
function methods:SetAttribute(key, value) assert(not combat or secure, "protected attribute in combat"); self.attrs[key] = value end
function methods:GetAttribute(key) return self.attrs[key] end
function methods:SetFrameRef(key, value) self.refs[key] = value end
function methods:GetFrameRef(key) return self.refs[key] end
function methods:Execute(body)
    assert(not combat, "insecure Execute in combat")
    Native(assert(load(body, "restricted snippet", "t", { self = self })))
end
function methods:SetHeight(value)
    if self.viewport then assert(secure, "virtualized list resized in addon context") end
    states[self].height = value
    if self.viewport and self.resize then self.resize() end
end
function methods:SetScale(value)
    if self.viewport then assert(secure, "virtualized list rescaled in addon context") end
    states[self].scale = value
end
function methods:SetSize(w, h) states[self].width, states[self].height = w, h end
function methods:SetWidth(value) states[self].width = value end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetScale() return self.scale end
function methods:GetAlpha() return self.alpha end
function methods:SetAlpha(value)
    if self.native and value == 0 then assert(EraUIClassicTrainer:IsShown(), "native controls hidden before Classic layout appears") end
    states[self].alpha = value
end
function methods:GetFrameLevel() return self.level end
function methods:SetFrameLevel(value) states[self].level = value end
function methods:GetNumPoints() return #self.points end
function methods:GetPoint(i) return unpack(self.points[i]) end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:ClearAllPoints() wipe(self.points) end
function methods:SetAllPoints(target) self:ClearAllPoints(); self:SetPoint("TOPLEFT", target, "TOPLEFT"); self:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT") end
local function ScriptHooks(frame, key)
    local previous = secure
    secure = false
    for _, fn in ipairs(frame.scriptHooks[key] or {}) do fn(frame) end
    secure = previous
end
function methods:Show()
    local wasShown = self.shown
    states[self].shown = true
    if not wasShown then ScriptHooks(self, "OnShow") end
end
function methods:Hide()
    local wasShown = self.shown
    states[self].shown = false
    if wasShown then ScriptHooks(self, "OnHide") end
end
function methods:SetShown(value) states[self].shown = value end
function methods:IsShown() return self.shown end
function methods:IsEnabled() return self.enabled end
function methods:SetEnabled(value)
    assert(not self.native or secure, "addon changed native eligibility")
    states[self].enabled = value
end
function methods:EnableMouse(value) states[self].mouse = value end
function methods:SetText(text) states[self].text = text end
function methods:SetFormattedText(format, ...) self:SetText(string.format(format, ...)) end
function methods:SetTexture(value) states[self].texture = value end
function methods:SetTextColor(...) states[self].color = { ... } end
function methods:CreateTexture() return Frame("Texture", nil, self) end
function methods:CreateFontString() return Frame("FontString", nil, self) end
function methods:GetElementData() return self.elementData end
function methods:ForEachFrame(fn) for _, row in ipairs(self.visible or {}) do fn(row) end end
function methods:GetValue() return self.value end
function methods:SetValue(value) states[self].value = math.max(0, math.min(value, self.maximum or 0)); if self.changed then self.changed() end end
function methods:SetRange(value) states[self].maximum = value; self:SetValue(self.value) end
for _, name in ipairs({ "SetJustifyH", "SetJustifyV", "SetWordWrap", "SetBlendMode", "SetVertexColor", "RegisterForClicks", "SetHorizTile", "SetVertTile" }) do methods[name] = function() end end
function hooksecurefunc(name, fn) hooks[name] = hooks[name] or {}; hooks[name][#hooks[name] + 1] = fn end
function InCombatLockdown() return combat end
local function Drive(frame)
    Native(assert(load(frame:GetAttribute("_onstate-combat"), "combat driver", "t", { self = frame, newstate = combat and "1" or "0" })))
end
function RegisterStateDriver(frame, key, value)
    assert(key == "combat", "must not hide the whole Classic layout during combat")
    drivers[frame] = value
    Drive(frame)
end
function UnregisterStateDriver(frame) drivers[frame] = nil end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function Flush()
    local passes = 0
    while #timers > 0 do
        passes = passes + 1
        assert(passes < 10, "refresh timer loop")
        local batch = timers; timers = {}
        for _, fn in ipairs(batch) do fn() end
    end
end
local function Event(name, ...)
    for _, frame in ipairs(frames) do if frame.events[name] then frame.scripts.OnEvent(frame, name, ...) end end
end
local trainerType, points, petLevel, money = 1, 3, 11, 100
Enum = { TrainerType = { Pet = 1, General = 2, Tradeskills = 3 } }
C_Trainer = { GetTrainerType = function() return trainerType end }
C_PetInfo = { GetPetTrainingPoints = function() return points, 0 end }
C_CurrencyInfo = { GetCoinTextureString = function(cost) return cost .. " copper" end }
function UnitLevel(unit) return unit == "pet" and petLevel or 60 end
function GetMoney() return money end
local catalog, filters = {}, { available = true, unavailable = true, used = true }
for i = 1, 14 do catalog[i] = { name = "Ability " .. i, cost = i == 1 and 5 or 1, level = i == 1 and 12 or 1, kind = "available", category = "Pet" } end
function GetNumTrainerServices() return #catalog end
function GetTrainerServiceInfo(index)
    local row = catalog[index]
    if row then return row.name, row.kind, "icon-" .. index, row.level, "Rank 1", row.category end
end
function GetTrainerServiceCost(index) return catalog[index].cost, catalog[index].profession end
function GetTrainerServiceStepIndex() return trainerType == Enum.TrainerType.Tradeskills and #catalog or nil end
function GetTrainerServiceSkillReq() return nil end
function GetTrainerServiceNumAbilityReq() return 0 end
function GetTrainerServiceDescription(index) return "Description " .. index end
function GetTrainerGreetingText() return "Learn an ability." end
function GetTrainerServiceTypeFilter(kind) return filters[kind] end
function SetTrainerServiceTypeFilter(kind, value) filters[kind] = value; Event("TRAINER_UPDATE") end
function BuyTrainerService() error("addon purchase call") end
function SelectTrainerService() error("addon selection call") end
function HideUIPanel(frame) frame:Hide() end
local module
local ns = {
    TexPath = function() return "classic-rock", "fallback-rock" end,
    ThemeTexture = function() end,
    RegisterModule = function(_, value) module = value end,
    PanelButton = function(parent) return Frame("Button", nil, parent) end,
    SkillInsetBox = function(parent) return Frame("Frame", nil, parent) end,
    DropList = function(items)
        return { items = items, Follow = function() end, Toggle = function() end }
    end,
    OldSkillShell = function(panel, opts)
        for _, key in ipairs({ "list", "listBox", "detailBox", "footBox", "detail", "filter", "collapseAll" }) do panel[key] = Frame("Frame", nil, panel) end
        panel.collapseAll.icon = Frame("Texture", nil, panel.collapseAll)
        panel.bar = Frame("Frame", nil, panel)
        panel.bar.changed = opts.onScroll
        panel.rows = {}
        for i = 1, opts.rows do panel.rows[i] = opts.createRow(panel.list, i) end
    end,
}
assert(loadfile("Classic/Trainer.lua"))("EraUI", { Classic = ns })
module.apply()
Equal(#frames, 1, "waits for load-on-demand UI")

local pool, purchases, confirmations = {}, {}, 0
ClassTrainerFrame = Frame("Frame", "ClassTrainerFrame", nil, nil, true)
Native(function()
    for _, key in ipairs({ "ScrollBox", "ScrollBar", "TrainButton", "money", "trainingPoints", "skillStepButton", "FilterDropdown", "FilterInputHint", "BG", "Inset", "bottomInset" }) do
        ClassTrainerFrame[key] = Frame("Frame", nil, ClassTrainerFrame, nil, true)
    end
    ClassTrainerFrame.ScrollBox.viewport = true
    ClassTrainerFrame.selectedService = 21
    ClassTrainerFrame.displayIndexToSkillIndex = {}
end)
ClassTrainerFrameMoneyBg = Frame("Texture", nil, ClassTrainerFrame)
local function Initialize(button, index)
    assert(secure, "native initializer invoked insecurely")
    button.displayIndex = GetTrainerServiceStepIndex() == index and 0 or index + 20
    button.elementData = { data = { skillIndex = index } }
    ClassTrainerFrame.displayIndexToSkillIndex[button.displayIndex] = index
    local row = catalog[index]
    if ClassTrainerFrame.selectedService == button.displayIndex then
        ClassTrainerFrame.showDialog = row.profession
        ClassTrainerFrame.TrainButton:SetEnabled(row.kind == "available" and row.cost <= (trainerType == 1 and points or money) and row.level <= (trainerType == 1 and petLevel or 60))
    end
    Post("ClassTrainerFrame_InitServiceButton", button)
end
local function NativeRows()
    assert(secure, "native layout invoked insecurely")
    local visible = {}
    for i = 1, math.min(#catalog, math.floor(ClassTrainerFrame.ScrollBox:GetHeight() / 47)) do
        if not pool[i] then
            pool[i] = Frame("Button", nil, ClassTrainerFrame.ScrollBox, nil, true)
            pool[i].scripts.OnClick = function(self)
                assert(secure, "native selection is insecure")
                ClassTrainerFrame.selectedService = self.displayIndex
                Initialize(self, self.elementData.data.skillIndex)
                Post("ClassTrainer_SetSelection")
            end
        end
        Initialize(pool[i], i)
        visible[#visible + 1] = pool[i]
    end
    ClassTrainerFrame.ScrollBox.visible = visible
    if GetTrainerServiceStepIndex() then
        Initialize(ClassTrainerFrame.skillStepButton, #catalog)
        ClassTrainerFrame.skillStepButton.scripts.OnClick = pool[#catalog].scripts.OnClick
    end
end
Native(function() ClassTrainerFrame.ScrollBox.resize = NativeRows end)
function ClassTrainerFrame_InitServiceButton() error("must not call native initializer from addon") end
ClassTrainerFrame.TrainButton.scripts.OnClick = function()
    assert(secure, "native purchase is insecure")
    if not ClassTrainerFrame.TrainButton:IsEnabled() then return end
    if ClassTrainerFrame.showDialog then confirmations = confirmations + 1
    else purchases[#purchases + 1] = ClassTrainerFrame.displayIndexToSkillIndex[ClassTrainerFrame.selectedService] end
end
local function Click(frame)
    if frame == ClassTrainerFrame.TrainButton and EraUIClassicTrainer.trainBlocker:IsShown() then return end
    local target = frame:GetAttribute("type1") == "click" and frame:GetAttribute("clickbutton") or frame
    if target and target.scripts.OnClick then Native(target.scripts.OnClick, target, "LeftButton") end
    if frame.scripts.PostClick then frame.scripts.PostClick(frame, "LeftButton", false) end
end
Native(NativeRows)
Event("ADDON_LOADED", "Blizzard_TrainerUI")
Flush()
local panel = EraUIClassicTrainer
local bridge
for _, frame in ipairs(frames) do if frame.refs.panel == panel then bridge = frame end end
Equal(#panel.rows, 9, "original compact list restored")
Equal(panel.rows[1].line.header, true, "category header retained")
Equal(panel.rows[2]:GetAttribute("clickbutton"), pool[1], "first service securely routes to native row")
Equal(#ClassTrainerFrame.ScrollBox.visible, 14, "offscreen services materialized")
Equal(ClassTrainerFrame.ScrollBox.alpha, 0, "large native cards hidden")
Equal(panel.detail.name.text, "Ability 1", "separate detail panel populated")
Equal(panel.detail.icon.texture, "icon-1", "selected ability icon restored")
Equal(panel.detail.requires.text:find("|cffff2020Level 12", 1, true) ~= nil, true, "requirement uses pet level")
Equal(panel.detail.cost.text:find("5 TP", 1, true) ~= nil, true, "pet costs use points")
Equal(panel.detail.cost.text:find("|cffff2020", 1, true) ~= nil, true, "unaffordable points are red")
Equal(panel.points.text, "Training Points: 3", "available pet points in footer")
Equal(panel.train.enabled, false, "artwork mirrors native disabled state")
Equal(panel.train.mouse, false, "native Train button receives clicks")
Equal(panel.train.scripts.OnClick, nil, "no addon purchase handler")
Equal(ClassTrainerFrame.TrainButton.points[1][2], panel.train, "real Train button covers original location")
Equal(drivers[bridge], "[combat] 1; 0", "late-loaded bridge has combat input driver")
Equal(drivers[panel], nil, "Classic layout has no combat hide rule")
Equal(panel.empty.shown, false, "populated list hides empty-state message")
ClassTrainerFrame:Hide()
panel:Hide()
Native(function() ClassTrainerFrame:Show() end)
Equal(panel.shown, true, "native OnShow restores Classic layout before timer/paint")
Flush()

Click(panel.rows[3])
Equal(panel.rows[3]:GetAttribute("clickbutton"), nil, "native refresh immediately invalidates old routes")
Flush()
Equal(panel.detail.name.text, "Ability 2", "native selection updates detail")
Equal(panel.train.enabled, true, "eligible native service enables artwork")
Click(ClassTrainerFrame.TrainButton)
Equal(purchases[1], 2, "real Train button buys selected service")
points = 17
Event("UNIT_PET_TRAINING_POINTS")
Flush()
Equal(panel.points.text, "Training Points: 17", "pet-point events update the footer")
catalog[2].kind = "used"
Native(NativeRows)
Flush()
Equal(panel.detail.cost.text, "", "learned ability does not display a purchase cost")
Equal(panel.train.enabled, false, "learned ability retains native disabled state")
catalog[2].kind = "available"
Native(NativeRows)
Flush()
panel.bar:SetValue(6)
Click(panel.rows[9])
Flush()
Equal(panel.detail.name.text, "Ability 14", "last compact page selects offscreen native service")
Click(ClassTrainerFrame.TrainButton)
Equal(purchases[2], 14, "offscreen ability buys correct index")

-- Native index 0/step mapping, restricted eligibility and confirmation stay native.
trainerType = Enum.TrainerType.Tradeskills
catalog[14].profession = true
Native(NativeRows)
Flush()
Click(panel.rows[9])
Flush()
Click(ClassTrainerFrame.TrainButton)
Equal(ClassTrainerFrame.selectedService, 0, "profession step keeps native display index zero")
Equal(confirmations, 1, "profession confirmation preserved")
Equal(#purchases, 2, "no direct purchase bypasses confirmation")
Equal(panel.points.shown, false, "coin trainer does not show pet points")
Equal(panel.detail.cost.text:find("copper", 1, true) ~= nil, true, "coin trainer uses money")

-- Recycled IDs are unbound until the compact text and targets are rebuilt.
catalog[14].name = "Replacement ability"
Native(NativeRows)
Equal(panel.rows[9]:GetAttribute("clickbutton"), nil, "recycling invalidates route before repaint")
Flush()
Equal(panel.rows[9].text.text, "Replacement ability (Rank 1)", "recycled row label matches target")
panel.bar:SetValue(0)
Click(panel.rows[1])
Flush()
Equal(panel.rows[2].shown, false, "category collapse hides abilities")
Equal(panel.empty.shown, false, "folded categories are not mislabeled as no matches")
Click(panel.rows[1])
Flush()
Equal(panel.rows[2].shown, true, "category expansion rebinds abilities")
-- Reopen an already-collapsed native category through its real button.
local categoryClosed = true
local category = Frame("Button", nil, ClassTrainerFrame.ScrollBox, nil, true)
Native(function()
    category.elementData = { data = { categoryInfo = { name = "Pet" } }, IsCollapsed = function() return categoryClosed end }
    category.scripts.OnClick = function()
        assert(secure, "native category invoked insecurely")
        categoryClosed = not categoryClosed
        Post("ClassTrainerFrame_InitCategoryButton")
    end
    table.insert(ClassTrainerFrame.ScrollBox.visible, 1, category)
end)
Event("TRAINER_UPDATE")
Flush()
Equal(panel.rows[2].shown, false, "native collapsed category hides compact abilities")
Equal(panel.rows[1]:GetAttribute("clickbutton"), category, "native collapsed category securely routed")
Click(panel.rows[1])
Flush()
Equal(categoryClosed, false, "native category opens through secure click")
Equal(panel.rows[2].shown, true, "native category opening updates compact list")
panel.collapseAll.scripts.OnClick()
Equal(panel.rows[2].shown, false, "All collapses custom sections")
panel.collapseAll.scripts.OnClick()
Equal(panel.rows[2].shown, true, "All expands custom sections")
panel.filter.scripts.OnClick(panel.filter)
panel.filterList.items[3][2]()
Flush()
Equal(filters.used, false, "filter retains original control")

combat = true
Drive(bridge)
local oldSelection = ClassTrainerFrame.selectedService
Click(panel.rows[2])
Click(ClassTrainerFrame.TrainButton)
Event("TRAINER_UPDATE")
Flush()
Equal(panel.shown, true, "Classic layout stays visible in combat")
Equal(panel.trainBlocker.shown, true, "native Train button blocked during combat")
Equal(panel.trainBlocker.level > ClassTrainerFrame.TrainButton.level, true, "input shield is above native purchase button")
Equal(panel.rows[2]:GetAttribute("type1"), nil, "combat securely disarms row action")
Equal(ClassTrainerFrame.selectedService, oldSelection, "combat row click does not change selection")
Equal(#purchases, 2, "combat input shield prevents purchase")
Equal(confirmations, 1, "combat input shield prevents confirmation click")
combat = false
Drive(bridge)
Event("PLAYER_REGEN_ENABLED")
Flush()
Equal(panel.trainBlocker.shown, false, "training input restored out of combat")
Equal(panel.rows[2]:GetAttribute("clickbutton"), pool[1], "routes refreshed after combat")
local fullCatalog = catalog
catalog = {}
trainerType = Enum.TrainerType.Pet
Native(function() ClassTrainerFrame.selectedService = nil; ClassTrainerFrame.TrainButton:SetEnabled(false); NativeRows() end)
Event("TRAINER_UPDATE")
Flush()
Equal(panel.empty.shown, true, "empty filtered catalog has explanatory message")
Equal(panel.empty.text, "No abilities match the current filters.", "empty message avoids claiming no abilities exist")
Equal(filters.used, false, "empty list does not change user's known-ability filter")
catalog = { { cost = 1, level = 1, kind = "available" } }
Native(NativeRows)
Event("TRAINER_UPDATE")
Flush()
Equal(panel.empty.text, "Loading abilities...", "pending ability names use loading message")
catalog = fullCatalog
Native(NativeRows)
Event("TRAINER_UPDATE")
Flush()
Equal(panel.empty.shown, false, "new abilities remove empty-state message")
module.apply()
Flush()
Equal(#hooks.ClassTrainerFrame_InitServiceButton, 1, "reapply does not stack hooks")
module.restore()
Equal(panel.shown, false, "restore hides custom layout")
Equal(ClassTrainerFrame.ScrollBox.height, 330, "restore resets native viewport")
Equal(ClassTrainerFrame.ScrollBox.scale, 1, "restore resets native scale")
Equal(ClassTrainerFrame.ScrollBox.alpha, 1, "restore reveals native list")
Equal(ClassTrainerFrame.TrainButton.alpha, 1, "restore reveals native Train button")
Equal(ClassTrainerFrame.TrainButton.level, 5, "restore resets native layering")
Equal(panel.rows[2]:GetAttribute("clickbutton"), nil, "restore removes secure routes")
Equal(drivers[bridge], nil, "restore removes combat driver")
module.apply()
Flush()
Equal(panel.shown, true, "reenabling restores compact panel")
Equal(panel.rows[2]:GetAttribute("clickbutton"), pool[1], "reenabling restores click route")
module.restore()
Equal(ClassTrainerFrame.ScrollBox.height, 330, "second restore retains original geometry")
for _, frame in ipairs(frames) do Equal(frame.scripts.OnUpdate, nil, "no polling timers") end
print("Trainer: " .. checks .. " assertions passed")
