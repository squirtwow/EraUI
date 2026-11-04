-- Popups (Look/Popups.lua, module "ClassicPanels", setting "popups") on a
-- small mock of the game's four confirmation pop-ups. Checks:
--   * the module's name and its two entry points;
--   * off at load: nothing made, faded, hooked or skinned, and Refresh does
--     nothing either;
--   * on: each pop-up gets one box of EraUI's own (a BackdropTemplate child
--     filling it, at its frame level, no mouse, the 1.x dialog fill and gold
--     border, white, handed to Dark Mode's DarkBackdrop with no colours of
--     its own), made once however many passes, and carrying none of the
--     keys the pop-up's layout code reads on its children;
--   * the game's own backing (BG on Forever; NineSlice, Bg, Background,
--     Border, TopTileStreaks elsewhere) faded on every pass, and again when
--     the game shows it again;
--   * Forever's buttons (ButtonContainer.Buttons and ExtraButton) handed to
--     Dark Mode's DarkRedButton and never given the classic panel art; an
--     older pop-up's own buttons (its Buttons list, button1-4, Button1-4)
--     given the classic art once each per pass, owner "ClassicPanels", the
--     ExtraButton never;
--   * a missing or forbidden pop-up skipped without touching it; one that
--     errors reported and the others still dressed;
--   * one OnShow post-hook per pop-up, however many passes, shows and events;
--     a pass started inside a pass does nothing;
--   * ADDON_LOADED and PLAYER_ENTERING_WORLD start a pass;
--   * without the Dark Mode helpers nothing breaks;
--   * no key written on any of the game's frames or buttons.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

---------------------------------------------------------------------------
-- The mock game
---------------------------------------------------------------------------

-- Every widget is an empty proxy: its state lives in a hidden table, so any
-- key the file under test writes on one of the game's frames is caught
-- (EraUI's own frames may take keys: the backdrop template sets some).
local function NewGame()
    local game = { made = {}, writes = {}, errors = {}, calls = {}, hooks = 0 }
    local state = setmetatable({}, { __mode = "k" })
    local Methods = {}
    game.state = state

    local function Widget(kind, name, parent, own)
        local proxy = {}
        local s = { kind = kind, name = name, parent = parent, own = own, fields = {}, points = {}, shown = true, alpha = 1,
            level = 1, mouse = true, scripts = {}, hooks = {}, events = {}, children = {} }
        state[proxy] = s
        setmetatable(proxy, {
            __index = function(_, key)
                if s.fields[key] ~= nil then return s.fields[key] end
                return Methods[key]
            end,
            __newindex = function(_, key, value)
                if not s.own then game.writes[#game.writes + 1] = tostring(name or kind) .. "." .. tostring(key) end
                s.fields[key] = value
            end,
        })
        if parent and state[parent] then table.insert(state[parent].children, proxy) end
        return proxy
    end
    game.Widget = Widget
    -- The test's own setup of a game frame's fields (not a write by EraUI).
    function game.Give(frame, key, value) state[frame].fields[key] = value end

    function Methods:GetName() return state[self].name end
    function Methods:GetParent() return state[self].parent end
    function Methods:IsForbidden() return state[self].forbidden == true end
    function Methods:IsObjectType(kind) return state[self].kind == kind end
    function Methods:GetFrameLevel() return state[self].level end
    function Methods:SetFrameLevel(level) state[self].level = level end
    function Methods:ClearAllPoints() state[self].points = {} end
    function Methods:SetPoint(...) table.insert(state[self].points, { ... }) end
    function Methods:SetAllPoints(relative)
        local to = relative or state[self].parent
        state[self].points = { { "TOPLEFT", to, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", to, "BOTTOMRIGHT", 0, 0 } }
    end
    function Methods:SetSize(w, h) state[self].width, state[self].height = w, h end
    function Methods:EnableMouse(on) state[self].mouse = on and true or false end
    function Methods:IsMouseEnabled() return state[self].mouse end
    function Methods:SetBackdrop(info) state[self].backdrop = info end
    function Methods:SetBackdropColor(r, g, b, a) state[self].fill = { r, g, b, a } end
    function Methods:SetBackdropBorderColor(r, g, b, a) state[self].edge = { r, g, b, a } end
    function Methods:SetAlpha(alpha) state[self].alpha = alpha; state[self].alphaSets = (state[self].alphaSets or 0) + 1 end
    function Methods:GetAlpha() return state[self].alpha end
    function Methods:IsShown() return state[self].shown end
    function Methods:Show()
        local s = state[self]
        if s.shown then return end
        s.shown = true
        for _, fn in ipairs(s.hooks.OnShow or {}) do fn(self) end
    end
    function Methods:Hide() state[self].shown = false end
    function Methods:SetShown(on) if on then self:Show() else self:Hide() end end
    function Methods:SetScript(script, fn) state[self].scripts[script] = fn end
    function Methods:HookScript(script, fn)
        local s = state[self]
        s.hooks[script] = s.hooks[script] or {}
        table.insert(s.hooks[script], fn)
        game.hooks = game.hooks + 1
    end
    function Methods:RegisterEvent(event) state[self].events[event] = true end
    function Methods:UnregisterAllEvents() state[self].events = {} end
    function Methods:GetChildren() return table.unpack(state[self].children) end

    local env = setmetatable({}, { __index = _G })
    env._G = env
    game.env = env
    env.UIParent = Widget("Frame", "UIParent", nil, true)
    env.CreateFrame = function(kind, name, parent, template)
        local made = Widget(kind, name, parent, true)
        state[made].template = template
        game.made[#game.made + 1] = made
        if name then env[name] = made end
        return made
    end
    env.hooksecurefunc = function() error("Popups post-hooks no function of the game's") end
    env.geterrorhandler = function() return function(problem) table.insert(game.errors, tostring(problem)) end end
    env.InCombatLockdown = function() return false end
    env.issecretvalue = function() return false end
    return game
end

-- A button with the game's red dialog art.
local function GameButton(game, name)
    local b = game.Widget("Button", name, nil, false)
    return b
end

-- Forever's pop-up: its BG frame, Button1-4 in ButtonContainer, an ExtraButton
-- that also sits in its own Buttons list.
local function ForeverPopup(game, index)
    local name = "StaticPopup" .. index
    local popup = game.Widget("Frame", name, game.env.UIParent, false)
    game.state[popup].level = 7
    game.state[popup].shown = false
    game.env[name] = popup
    local bg = game.Widget("Frame", name .. ".BG", popup, false)
    local holder = game.Widget("Frame", name .. ".ButtonContainer", popup, false)
    local list = {}
    for i = 1, 4 do list[i] = GameButton(game, name .. "Button" .. i) end
    game.Give(holder, "Buttons", list)
    local extra = GameButton(game, name .. "ExtraButton")
    game.Give(popup, "BG", bg)
    game.Give(popup, "ButtonContainer", holder)
    game.Give(popup, "ExtraButton", extra)
    game.Give(popup, "Buttons", { extra })
    return popup
end

-- An older client's pop-up: buttons held directly, the classic pieces.
local function OlderPopup(game, index)
    local name = "StaticPopup" .. index
    local popup = game.Widget("Frame", name, game.env.UIParent, false)
    game.env[name] = popup
    local one, two, three = GameButton(game, name .. "Button1"), GameButton(game, name .. "Button2"), GameButton(game, name .. "Button3")
    local extra = GameButton(game, name .. "ExtraButton")
    game.Give(popup, "Buttons", { one, two, extra })
    game.Give(popup, "button1", one)
    game.Give(popup, "button2", two)
    game.Give(popup, "Button3", three)
    game.Give(popup, "ExtraButton", extra)
    for _, key in ipairs({ "NineSlice", "Bg", "Background", "Border", "TopTileStreaks" }) do
        game.Give(popup, key, game.Widget("Texture", name .. "." .. key, popup, false))
    end
    return popup
end

-- EraUI and its Classic namespace, with the helpers the module calls.
local function NewEraUI(game, settings, withHelpers)
    local E = { modules = {}, settings = settings }
    function E:GetSetting(key) return self.settings[key] end
    function E:RegisterModule(name, module) module.name = name; self.modules[name] = module end
    game.calls.classic, game.calls.darkBox, game.calls.darkButton = {}, {}, {}
    function E:SkinClassicRedButton(button, owner)
        if game.failOn == button then error("a skin that failed") end
        table.insert(game.calls.classic, { button = button, owner = owner })
        return true
    end
    local ns = { db = {} }
    if withHelpers ~= false then
        function ns.DarkBackdrop(...) table.insert(game.calls.darkBox, { n = select("#", ...), ... }) end
        function ns.DarkRedButton(button)
            if game.failOn == button then error("a darkening that failed") end
            table.insert(game.calls.darkButton, button)
            if game.duringPass then game.duringPass() end
        end
    end
    E.Classic = ns
    return E
end

local function Load(game, E)
    for _, path in ipairs({ "Look/Base.lua", "Look/Popups.lua" }) do
        assert(loadfile(path, "t", game.env))("EraUI", E)
    end
    return E.modules.ClassicPanels
end

local function Count(list, wanted)
    local n = 0
    for _, item in ipairs(list) do if item == wanted or (type(item) == "table" and item.button == wanted) then n = n + 1 end end
    return n
end

local function BoxesOf(game, popup)
    local found = {}
    for _, f in ipairs(game.made) do if game.state[f].parent == popup then found[#found + 1] = f end end
    return found
end

---------------------------------------------------------------------------
-- The module's shape
---------------------------------------------------------------------------
do
    local game = NewGame()
    local E = NewEraUI(game, { popups = true })
    local module = Load(game, E)
    Equal(type(module), "table", "registered as ClassicPanels")
    Equal(module.name, "ClassicPanels", "under that exact name")
    Equal(type(module.Initialize) == "function" and type(module.Refresh) == "function", true, "with Initialize and Refresh")
    Equal(#game.made, 0, "loading the file makes nothing")
end

---------------------------------------------------------------------------
-- Off at load
---------------------------------------------------------------------------
do
    local game = NewGame()
    local popup = ForeverPopup(game, 1)
    local older = OlderPopup(game, 2)
    local E = NewEraUI(game, { popups = false })
    local module = Load(game, E)
    module:Initialize()
    module:Refresh()
    popup:Show()
    Equal(#game.made, 0, "off: no box and no event frame")
    Equal(game.hooks, 0, "off: no hook on any pop-up")
    Equal(game.state[popup.BG].alpha, 1, "off: the game's own backing left alone")
    Equal(game.state[older.NineSlice].alphaSets, nil, "off: an older pop-up's pieces left alone")
    Equal(#game.calls.classic + #game.calls.darkBox + #game.calls.darkButton, 0, "off: nothing skinned or darkened")
    Equal(#game.writes, 0, "off: no key written")
end

---------------------------------------------------------------------------
-- On: Forever's pop-ups and an older one
---------------------------------------------------------------------------
do
    local game = NewGame()
    local popup = ForeverPopup(game, 1)
    local older = OlderPopup(game, 2)
    -- A button of some other kind in Forever's own Buttons list: with a
    -- ButtonContainer that list is the game's, never given the classic art.
    local stray = GameButton(game, "StaticPopup1Stray")
    game.Give(popup, "Buttons", { popup.ExtraButton, stray })
    local banned = ForeverPopup(game, 3)
    game.state[banned].forbidden = true
    -- StaticPopup4 doesn't exist on this mock.
    local E = NewEraUI(game, { popups = true })
    local module = Load(game, E)
    -- A forbidden pop-up: anything beyond asking IsForbidden is an error.
    local bannedState = game.state[banned]
    setmetatable(banned, { __index = function(_, key)
        if key == "IsForbidden" then return function() return true end end
        error("touched a forbidden pop-up: " .. tostring(key))
    end, __newindex = function(_, key) error("wrote on a forbidden pop-up: " .. tostring(key)) end })
    module:Initialize()

    -- One event frame of EraUI's own, listening for both events.
    local listeners = {}
    for _, f in ipairs(game.made) do if game.state[f].parent == nil then listeners[#listeners + 1] = f end end
    Equal(#listeners, 1, "one event frame")
    local events = game.state[listeners[1]].events
    Equal(events.ADDON_LOADED and events.PLAYER_ENTERING_WORLD, true, "listening for ADDON_LOADED and PLAYER_ENTERING_WORLD")

    -- The box.
    local boxes = BoxesOf(game, popup)
    Equal(#boxes, 1, "Forever's pop-up: one box")
    local box = game.state[boxes[1]]
    Equal(box.template, "BackdropTemplate", "the box is a BackdropTemplate frame")
    Equal(#box.points == 2 and box.points[1][2] == popup and box.points[2][2] == popup and box.points[1][1] == "TOPLEFT"
        and box.points[2][1] == "BOTTOMRIGHT", true, "filling the pop-up")
    Equal(box.level, 7, "at the pop-up's own frame level")
    Equal(box.mouse, false, "with mouse off")
    Equal(box.shown, true, "shown")
    local art = box.backdrop
    Equal(art.bgFile, "Interface\\DialogFrame\\UI-DialogBox-Background", "the 1.x dialog fill")
    Equal(art.edgeFile, "Interface\\DialogFrame\\UI-DialogBox-Border", "the gold-cornered dialog border")
    Equal(art.tile == true and art.tileSize == 32 and art.edgeSize == 32, true, "tiled at 32, edge 32")
    Equal(art.insets.left == 8 and art.insets.right == 8 and art.insets.top == 8 and art.insets.bottom == 8, true, "insets 8")
    Equal(box.fill[1] == 1 and box.fill[2] == 1 and box.fill[3] == 1 and box.fill[4] == 1, true, "backdrop colour white")
    local handed = 0
    for _, call in ipairs(game.calls.darkBox) do
        if call[1] == boxes[1] then
            handed = handed + 1
            Equal(call.n, 1, "handed to DarkBackdrop with no colours of its own")
        end
    end
    Equal(handed, 1, "the box handed to Dark Mode once, as it is made")
    -- Forever's pop-up is a ResizeLayoutFrame: its Layout reads these keys on
    -- every shown child. A value EraUI wrote there would taint that pass;
    -- left unset, the box is measured like the game's own BG (same rect).
    for _, key in ipairs({ "ignoreInLayout", "includeAsLayoutChildWhenHidden", "includeInLayout", "layoutIndex",
        "IsLayoutFrame", "align", "expand" }) do
        Equal(box.fields[key], nil, "no " .. key .. " on the box")
    end
    Equal(#BoxesOf(game, older), 1, "the older pop-up: one box too")
    Equal(#BoxesOf(game, banned), 0, "a forbidden pop-up gets no box")

    -- The game's own backing faded.
    Equal(game.state[popup.BG].alpha, 0, "Forever's BG faded")
    for _, key in ipairs({ "NineSlice", "Bg", "Background", "Border", "TopTileStreaks" }) do
        Equal(game.state[older[key]].alpha, 0, "the older pop-up's " .. key .. " faded")
    end

    -- Buttons: Forever's darkened, never the classic art.
    for i, button in ipairs(popup.ButtonContainer.Buttons) do
        Equal(Count(game.calls.darkButton, button), 1, "Forever's Button" .. i .. " handed to DarkRedButton")
        Equal(Count(game.calls.classic, button), 0, "Forever's Button" .. i .. " keeps the game's dialog art")
    end
    Equal(Count(game.calls.darkButton, popup.ExtraButton), 1, "Forever's ExtraButton darkened")
    Equal(Count(game.calls.classic, popup.ExtraButton), 0, "Forever's ExtraButton never given the classic art")
    Equal(Count(game.calls.classic, stray), 0, "with a ButtonContainer, the pop-up's own Buttons list is left alone")
    -- The older pop-up's own buttons: classic art once each, owner ClassicPanels.
    for _, key in ipairs({ "button1", "button2", "Button3" }) do
        Equal(Count(game.calls.classic, older[key]), 1, "the older pop-up's " .. key .. ": the classic art, once")
    end
    for _, call in ipairs(game.calls.classic) do Equal(call.owner, "ClassicPanels", "recorded under ClassicPanels") end
    Equal(Count(game.calls.classic, older.ExtraButton), 0, "an older pop-up's ExtraButton never given the classic art")
    Equal(Count(game.calls.darkButton, older.ExtraButton), 1, "but darkened like Forever's")

    -- Passes after the first: fades again, nothing made twice, one hook each.
    local made = #game.made
    game.state[popup.BG].alpha = 1 -- the game shows its backing again
    box.shown = false
    module:Refresh()
    Equal(game.state[popup.BG].alpha, 0, "a pass fades the backing again")
    Equal(box.shown, true, "and shows the box again")
    Equal(#game.made, made, "a pass makes no second box")
    Equal(Count(game.calls.classic, older.button1), 2, "the older pop-up's buttons dressed once per pass")
    popup:Show()
    popup:Hide()
    game.state[popup.BG].alpha = 1
    popup:Show()
    Equal(game.state[popup.BG].alpha, 0, "opening the pop-up dresses it again")
    local listener = game.state[listeners[1]]
    listener.scripts.OnEvent(listeners[1], "ADDON_LOADED", "Blizzard_Something")
    listener.scripts.OnEvent(listeners[1], "PLAYER_ENTERING_WORLD", false, true)
    game.state[popup.BG].alpha = 1
    listener.scripts.OnEvent(listeners[1], "ADDON_LOADED", "Another")
    Equal(game.state[popup.BG].alpha, 0, "an addon loading starts a pass")
    module:Initialize()
    Equal(#game.made, made, "a second Initialize makes no second event frame")
    Equal(#game.state[popup].hooks.OnShow, 1, "one OnShow hook on Forever's pop-up, however many passes")
    Equal(#game.state[older].hooks.OnShow, 1, "one OnShow hook on the older pop-up")
    Equal(game.hooks, 2, "and no other hook anywhere")

    -- A pass started inside a pass does nothing.
    local before, inner = #game.calls.darkButton, 0
    game.duringPass = function()
        inner = inner + 1
        if inner == 1 then module:Refresh() end
    end
    module:Refresh()
    game.duringPass = nil
    Equal(#game.calls.darkButton - before, 6, "a pass inside a pass adds nothing (five of Forever's buttons, one older Extra)")

    -- The first pop-up failing: reported, the next one still dressed, and the
    -- pass after it runs.
    game.failOn = popup.ButtonContainer.Buttons[2]
    game.state[older.Border].alpha = 1
    module:Refresh()
    Equal(#game.errors, 1, "the failure is reported to the error handler")
    Equal(game.state[older.Border].alpha, 0, "the pop-up after it is still dressed")
    game.failOn = nil
    game.state[popup.BG].alpha = 1
    module:Refresh()
    Equal(game.state[popup.BG].alpha, 0, "the next pass still runs")
    Equal(#game.errors, 1, "and nothing else went wrong, the forbidden pop-up included")

    Equal(#game.writes, 0, "no key written on the game's frames: " .. table.concat(game.writes, ", "))
    Equal(bannedState.alphaSets, nil, "the forbidden pop-up untouched")
end

---------------------------------------------------------------------------
-- Without Dark Mode's helpers (tests, or a namespace that lacks them)
---------------------------------------------------------------------------
do
    local game = NewGame()
    local popup = ForeverPopup(game, 1)
    local older = OlderPopup(game, 2)
    local E = NewEraUI(game, { popups = true }, false)
    local module = Load(game, E)
    module:Initialize()
    Equal(#game.errors, 0, "no helpers: no error")
    Equal(#BoxesOf(game, popup), 1, "no helpers: the box still made")
    Equal(game.state[popup.BG].alpha, 0, "no helpers: the backing still faded")
    Equal(Count(game.calls.classic, older.button2), 1, "no helpers: an older pop-up's buttons still get the classic art")
    Equal(#game.writes, 0, "no helpers: no key written")
end

print("Popups checks passed: " .. checks .. " assertions.")
