-- Bags and the bank (Look/BagKit.lua, BankDress.lua, BagSheet.lua, BagWindows.lua,
-- BagModule.lua; clean-room 2026-10-21) on a sealed mock of the game's bag
-- windows and bank: every key written on one of the game's frames or buttons
-- is caught (post-hooks excepted), and an item button is never looked into.
-- Checks (spec 11, "worth adding"):
--   * load: the One Bag column limits exist once the kit loads; "oneBag" then
--     "bags" registered; the area's defaults only where missing;
--   * an ordinary bag of 2 to 36 slots: its top, middle bands and lip, its
--     height, width 192, the art 256 wide hung from the window's top-right
--     (64 past its left edge); bands no longer wanted hidden;
--   * slots on the old grid from the bottom-right (42 across, 41 up), the top
--     row filled from its right; plain stone over leftover cells (none on a
--     two-slot top);
--   * the backpack at 16 and 20 slots (sheet, money strip, close, money,
--     rows); the One Bag window's columns (rounded, kept within 4 to 16), its
--     width, its column copies and its reversed fill with stone at the
--     bottom-right; SetOneBagColumns; the One Bag reader;
--   * empty slots' icons, the game's art faded, the kept pieces untouched,
--     item buttons and what hangs on them never touched, the portrait, name,
--     close button, money, search box and sort button;
--   * hooks once per window and button; nothing while off; sizes 0, 1 and a
--     secret left alone; the reload note only after the art went on;
--   * Dark Mode's keys on the sheets and stone only;
--   * a guarded window or slot never moved in a fight, dressed at its end;
--   * the bank: hooks once, the floor, the rings by width, the holes, the bag
--     slots (red unbought, white empty, a bag kept, no padlock), the heading
--     made once, the gold labels, the portrait only when empty, the red
--     buttons (and a refused file leaving the game's own art), missing
--     methods reported, the hooks still while Bags & Bank is off.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
local function Near(actual, expected, label)
    checks = checks + 1
    if type(actual) ~= "number" or math.abs(actual - expected) > 0.001 then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })

---------------------------------------------------------------------------
-- The mock game
---------------------------------------------------------------------------

local function NewGame(setup)
    setup = setup or {}
    local game = { writes = {}, violations = {}, errors = {}, themed = {}, hookCount = {}, listeners = {}, missing = {},
        darkClose = {}, darkRed = {}, portraits = {}, combat = false, refuse = {}, cvars = { combinedBags = "0" },
        settings = { enabled = true, bagsBank = true } }
    local S = setmetatable({}, { __mode = "k" })
    local given = setmetatable({}, { __mode = "k" })
    game.S = S
    local Methods = {}
    local gameMeta = { __index = Methods, __newindex = function(t, key, value)
        game.writes[#game.writes + 1] = tostring(S[t] and S[t].name or S[t].kind) .. "." .. tostring(key)
        rawset(t, key, value)
    end }
    local ownMeta = { __index = Methods }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    game.env = env

    local REGION = { Texture = true, FontString = true, MaskTexture = true }
    local function Widget(kind, name, parent, own)
        local w = setmetatable({}, own and ownMeta or gameMeta)
        S[w] = { kind = kind, name = name, parent = parent, own = own, points = {}, alpha = 1, alphaSets = 0, shown = true,
            level = 1, regions = {}, children = {}, hooks = {}, scripts = {}, faces = {}, fonts = {} }
        given[w] = {}
        if parent then
            local list = REGION[kind] and S[parent].regions or S[parent].children
            list[#list + 1] = w
        end
        if name then env[name] = w end
        game.all = game.all or {}
        game.all[#game.all + 1] = w
        return w
    end
    game.Widget = Widget
    -- The game's (or the test's) own field on one of its frames.
    function game.Give(w, key, value)
        given[w][key] = value
        rawset(w, key, value)
    end

    local function Flag(self, what)
        game.violations[#game.violations + 1] = tostring(S[self].name or S[self].kind) .. ":" .. what
    end
    -- An item button may be placed, never looked into, faded, hidden, sized or
    -- re-parented; what hangs on it is never touched at all.
    local function Sealed(self, what, placing)
        local seal = S[self].sealed
        if seal == "inside" or (seal == "button" and not placing) then Flag(self, what) end
    end
    local function Moving(self, what)
        Sealed(self, what, what == "SetPoint" or what == "ClearAllPoints")
        if game.combat and S[self].protected then Flag(self, what .. " in a fight") end
    end

    function Methods:GetName() return S[self].name end
    function Methods:GetParent() return S[self].parent end
    function Methods:SetParent(parent)
        Sealed(self, "SetParent")
        local s = S[self]
        if s.parent then
            for i, child in ipairs(S[s.parent].children) do
                if child == self then table.remove(S[s.parent].children, i) break end
            end
        end
        s.parent = parent
        if parent then table.insert(S[parent].children, self) end
    end
    function Methods:GetObjectType() return S[self].kind end
    function Methods:IsObjectType(kind) return S[self].kind == kind end
    function Methods:GetRegions() Sealed(self, "GetRegions") return table.unpack(S[self].regions) end
    function Methods:GetChildren() Sealed(self, "GetChildren") return table.unpack(S[self].children) end
    function Methods:SetSize(w, h) Moving(self, "SetSize") S[self].width, S[self].height = w, h end
    function Methods:SetWidth(w) Moving(self, "SetWidth") S[self].width = w end
    function Methods:SetHeight(h) Moving(self, "SetHeight") S[self].height = h end
    function Methods:GetWidth() return S[self].width or 0 end
    function Methods:GetHeight() return S[self].height or 0 end
    function Methods:ClearAllPoints() Moving(self, "ClearAllPoints") S[self].points = {} end
    function Methods:SetPoint(point, relative, relativePoint, x, y)
        Moving(self, "SetPoint")
        table.insert(S[self].points, { point, relative, relativePoint or point, x or 0, y or 0 })
    end
    function Methods:SetAllPoints(relative)
        Moving(self, "SetAllPoints")
        local to = relative or S[self].parent
        S[self].points = { { "TOPLEFT", to, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", to, "BOTTOMRIGHT", 0, 0 } }
    end
    function Methods:GetPoint(i)
        local p = S[self].points[i or 1]
        if p then return table.unpack(p) end
    end
    function Methods:SetAlpha(alpha)
        Sealed(self, "SetAlpha")
        S[self].alpha, S[self].alphaSets = alpha, S[self].alphaSets + 1
    end
    function Methods:GetAlpha() return S[self].alpha end
    function Methods:Show()
        Sealed(self, "Show")
        local s = S[self]
        if s.shown then return end
        s.shown = true
        if s.scripts.OnShow then s.scripts.OnShow(self) end
        for _, fn in ipairs(s.hooks.OnShow or {}) do fn(self) end
    end
    function Methods:Hide() Sealed(self, "Hide") S[self].shown = false end
    function Methods:SetShown(on) if on then self:Show() else self:Hide() end end
    function Methods:IsShown() return S[self].shown end
    function Methods:IsVisible()
        local s = S[self]
        return s.shown and (not s.parent or s.parent:IsVisible())
    end
    function Methods:GetFrameLevel() return S[self].level end
    function Methods:SetFrameLevel(level) Moving(self, "SetFrameLevel") S[self].level = level end
    function Methods:IsProtected() return S[self].protected == true end
    function Methods:HookScript(script, fn)
        local s = S[self]
        s.hooks[script] = s.hooks[script] or {}
        table.insert(s.hooks[script], fn)
        local key = tostring(s.name or s.kind) .. ":" .. script
        game.hookCount[key] = (game.hookCount[key] or 0) + 1
    end
    function Methods:SetScript(script, fn)
        if not S[self].own then Flag(self, "SetScript " .. script) end
        S[self].scripts[script] = fn
    end
    function Methods:GetScript(script) return S[self].scripts[script] end
    function Methods:RegisterEvent(event)
        game.listeners[event] = game.listeners[event] or {}
        table.insert(game.listeners[event], self)
    end
    function Methods:EnableMouse() end
    function Methods:CreateTexture(name, layer, _, sublevel)
        local made = Widget("Texture", name, self, true)
        S[made].layer, S[made].sublevel = layer, sublevel
        return made
    end
    function Methods:CreateFontString(name, layer, font)
        local made = Widget("FontString", name, self, true)
        S[made].layer, S[made].font = layer, font
        return made
    end
    -- Textures
    function Methods:SetTexture(file, wrapH, wrapV)
        Sealed(self, "SetTexture")
        if game.refuse[file] then return false end
        local s = S[self]
        s.file, s.wrap, s.atlas, s.colour = file, { wrapH, wrapV }, nil, nil
        return true
    end
    function Methods:GetTexture() return S[self].file end
    function Methods:SetAtlas(atlas) S[self].atlas, S[self].file = atlas, "atlas:" .. atlas end
    function Methods:GetAtlas() return S[self].atlas end
    function Methods:SetTexCoord(...) S[self].coords = { ... } end
    function Methods:SetDrawLayer(layer, sublevel) S[self].layer, S[self].sublevel = layer, sublevel end
    function Methods:SetVertexColor(r, g, b) S[self].vertex = { r, g, b } end
    function Methods:SetColorTexture(r, g, b, a) S[self].colour, S[self].file = { r, g, b, a }, nil end
    function Methods:SetHorizTile(on) S[self].horizTile = on end
    function Methods:SetVertTile(on) S[self].vertTile = on end
    function Methods:SetBlendMode(mode) S[self].blend = mode end
    -- Font strings
    function Methods:SetFontObject(font) S[self].font = font end
    function Methods:SetText(text) S[self].text = text end
    function Methods:GetText() return S[self].text end
    function Methods:SetJustifyH(way) S[self].justify = way end
    function Methods:SetTextColor(r, g, b) S[self].textColour = { r, g, b } end
    -- Buttons
    for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
        Methods["Set" .. state .. "Texture"] = function(self, file)
            local s = S[self]
            if not s.faces[state] then s.faces[state] = Widget("Texture", nil, self, true) end
            return s.faces[state]:SetTexture(file)
        end
        Methods["Get" .. state .. "Texture"] = function(self) return S[self].faces[state] end
    end
    function Methods:SetNormalFontObject(font) S[self].fonts.normal = font end
    function Methods:SetHighlightFontObject(font) S[self].fonts.highlight = font end
    function Methods:SetDisabledFontObject(font) S[self].fonts.disabled = font end

    -- The game's globals
    env.UIParent = Widget("Frame", "UIParent", nil, true)
    env.CreateFrame = function(kind, name, parent) return Widget(kind, name, parent, true) end
    env.hooksecurefunc = function(a, b, c)
        if type(a) == "string" then
            local original = env[a]
            env[a] = function(...) original(...) c(...) end
            return
        end
        local original = a[b]
        local wrapped = function(...)
            local results = table.pack(original(...))
            c(...)
            return table.unpack(results, 1, results.n)
        end
        rawset(a, b, wrapped)
        if given[a] then given[a][b] = wrapped end
        local key = tostring(S[a] and (S[a].name or S[a].kind) or "?") .. ":" .. b
        game.hookCount[key] = (game.hookCount[key] or 0) + 1
    end
    env.issecretvalue = function(value) return value == SECRET end
    env.InCombatLockdown = function() return game.combat end
    env.geterrorhandler = function() return function(problem) table.insert(game.errors, tostring(problem)) end end
    env.C_CVar = { GetCVar = function(name)
        if game.cvarFails then error("no such CVar") end
        return game.cvars[name]
    end }
    env.C_Timer = { After = function(_, fn) fn() end }
    env.UnitExists = function(unit) return unit == "npc" and game.npc == true end
    env.SetPortraitTexture = function(texture, unit)
        table.insert(game.portraits, unit)
        S[texture].file = "portrait:" .. unit
    end
    env.ITEMSLOTTEXT, env.BANK_BAG_PURCHASE, env.BANK_BAG = "Item Slots", "Purchasable Bag Slot", "Bag"
    for _, font in ipairs({ "GameFontNormal", "GameFontHighlight", "GameFontDisable", "GameFontNormalLarge" }) do
        env[font] = { fontName = font }
    end
    env.CreateFont = function(name)
        local font = { fontName = name }
        function font:CopyFontObject(other) self.copied = other end
        function font:SetFontObject(other) self.copied = other end
        function font:SetTextColor(r, g, b) self.colour = { r, g, b } end
        env[name] = font
        return font
    end

    -- EraUI, its Classic namespace and the engine pieces the area calls.
    local E = { settings = game.settings }
    function E:GetSetting(key) return self.settings[key] end
    local ns = { db = setup.db or { textureSource = "builtin", panels = true, bags = true }, registry = {},
        DB_DEFAULTS = { oneBagColumns = 8, textureSource = "builtin" } }
    function ns.RegisterModule(key, entry) entry.key = key table.insert(ns.registry, entry) end
    function ns.ThemeTexture(texture, key) game.themed[texture] = key end
    function ns.DarkCloseButton(button) game.darkClose[button] = (game.darkClose[button] or 0) + 1 end
    function ns.DarkRedButton(button) game.darkRed[button] = (game.darkRed[button] or 0) + 1 end
    function ns.MissingPiece(name) game.missing[name] = true end
    E.Classic = ns
    game.E, game.ns = E, ns

    function game.Load()
        local function Run(path) assert(loadfile(path, "t", env))("EraUI", E) end
        Run("Look/Base.lua")
        Run("Look/BagKit.lua")
        game.limitsAtKit = { ns.ONE_BAG_COLUMNS_MIN, ns.ONE_BAG_COLUMNS_MAX }
        for _, path in ipairs({ "Look/BankDress.lua", "Look/BagSheet.lua", "Look/BagWindows.lua", "Look/BagModule.lua" }) do
            Run(path)
        end
        return E.Look
    end
    function game.Pass()
        for _, entry in ipairs(ns.registry) do
            if ns.db[entry.key] ~= false then entry.apply() else entry.restore() end
        end
    end
    function game.Fire(event)
        for _, listener in ipairs(game.listeners[event] or {}) do
            local run = S[listener].scripts.OnEvent
            if run then run(listener, event) end
        end
    end
    -- Keys on the game's frames that neither the game nor a post-hook put there.
    function game.Strays()
        local found = {}
        for _, w in ipairs(game.all) do
            if not S[w].own then
                for key, value in pairs(w) do
                    if given[w][key] ~= value then found[#found + 1] = tostring(S[w].name or S[w].kind) .. "." .. tostring(key) end
                end
            end
        end
        for _, write in ipairs(game.writes) do found[#found + 1] = write end
        return found
    end
    return game
end

---------------------------------------------------------------------------
-- The game's bag windows
---------------------------------------------------------------------------

local function GameTexture(game, parent, atlas)
    local texture = game.Widget("Texture", nil, parent)
    game.S[texture].atlas = atlas
    return texture
end

local function MakeItem(game, window, n)
    local S = game.S
    local button = game.Widget("Button", S[window].name .. "Item" .. n, window)
    S[button].sealed, S[button].width = "button", 37
    local icon = GameTexture(game, button)
    local normal = GameTexture(game, button, "bags-item-slot64")
    S[button].faces.Normal = normal
    game.Give(button, "icon", icon)
    -- The game's cooldown and Bag Item Levels' marks hang on the button.
    for _ = 1, 2 do
        local inside = game.Widget("Frame", nil, button)
        S[inside].sealed = "inside"
    end
    game.Give(button, "GetBagID", function() return 0 end)
    game.Give(button, "GetSlotAndBagID", function() return n, 0 end)
    game.Give(button, "SetItemButtonTexture", function(_, file) S[icon].file = file end)
    return button
end

-- kind: "bag", "backpack" or "combined".
local function MakeWindow(game, name, kind)
    local S, Give, Widget = game.S, game.Give, game.Widget
    local env = game.env
    local window = Widget("Frame", name, env.UIParent)
    S[window].shown, S[window].level, S[window].width, S[window].height = false, 5, 178, 100
    local parts = {}
    parts.own = GameTexture(game, window, "Background1Slot")
    local holder = Widget("Frame", nil, window)
    S[holder].level = 400
    Give(window, "PortraitContainer", holder)
    parts.face = GameTexture(game, holder)
    S[parts.face].file = "game portrait"
    parts.ring = GameTexture(game, holder, "modern-ring")
    parts.mask = Widget("MaskTexture", nil, holder)
    Give(holder, "portrait", parts.face)
    Give(holder, "CircleMask", parts.mask)
    local title = Widget("Frame", nil, window)
    Give(window, "TitleContainer", title)
    parts.title = Widget("FontString", nil, title)
    Give(title, "TitleText", parts.title)
    local close = Widget("Button", name .. "CloseButton", window)
    Give(window, "CloseButton", close)
    for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do S[close].faces[state] = GameTexture(game, close) end
    local portraitButton = Widget("Button", nil, window)
    Give(window, "PortraitButton", portraitButton)
    Give(portraitButton, "GetBagID", function() return 0 end)
    parts.portraitButton = GameTexture(game, portraitButton)
    local filter = Widget("Frame", nil, window)
    Give(window, "FilterIcon", filter)
    parts.filter = GameTexture(game, filter)
    local nine = Widget("Frame", nil, window)
    Give(window, "NineSlice", nine)
    parts.nine = GameTexture(game, nine)
    local bg = Widget("Frame", nil, window)
    Give(window, "Bg", bg)
    parts.bg = GameTexture(game, bg)
    if kind ~= "bag" then
        local money = Widget("Frame", nil, window)
        Give(window, "MoneyFrame", money)
        parts.coin = GameTexture(game, money)
        local border = Widget("Frame", nil, money)
        Give(money, "Border", border)
        parts.border = GameTexture(game, border)
    end
    Give(window, "Items", {})
    Give(window, "GetBagSize", function(self) return rawget(self, "size") or 0 end)
    Give(window, "IsBackpack", function() return kind == "backpack" end)
    Give(window, "IsCombinedBagContainer", function() return kind == "combined" end)
    Give(window, "EnumerateValidItems", function(self)
        local items, size, i = rawget(self, "Items"), self:GetBagSize(), 0
        return function()
            i = i + 1
            if type(size) == "number" and i <= size then return i, items[i] end
        end
    end)
    -- The game's own updates (straight into its state, as the game's code).
    Give(window, "UpdateFrameSize", function(self) S[self].width, S[self].height = 178, 100 end)
    Give(window, "UpdateItemLayout", function(self)
        for _, button in self:EnumerateValidItems() do S[button].points = { { "BOTTOMRIGHT", self, "BOTTOMRIGHT", -7, 9 } } end
    end)
    Give(window, "UpdateSearchBox", function(self)
        if kind == "bag" then return end
        for _, piece in ipairs({ env.BagItemSearchBox, env.BagItemAutoSortButton }) do
            local old = S[piece].parent
            if old ~= self then
                for i, child in ipairs(S[old].children) do
                    if child == piece then table.remove(S[old].children, i) break end
                end
                S[piece].parent = self
                table.insert(S[self].children, piece)
            end
            S[piece].points = { { "TOPLEFT", self, "TOPLEFT", 42, -37 } }
        end
    end)
    Give(window, "UpdateMiscellaneousFrames", function() S[parts.face].file = "game portrait" end)
    return window, parts
end

-- The game opening a window of `size` slots (ContainerFrame_GenerateFrame's order).
local function Open(game, window, size)
    local S = game.S
    game.Give(window, "size", size)
    local items = rawget(window, "Items")
    for i = #items + 1, (type(size) == "number" and size or 0) do items[i] = MakeItem(game, window, i) end
    S[window].shown = false
    window:Show()
    window:UpdateMiscellaneousFrames()
    window:UpdateFrameSize()
    window:UpdateItemLayout()
    window:UpdateSearchBox()
end

-- The sheet's bands on a window: from the right end hung at the window's
-- top-right, each band's copies and left part hung leftwards off it, and the
-- next band's right end under it.
local function Bands(game, window)
    local S = game.S
    local mine = {}
    for _, region in ipairs(S[window].regions) do
        local s = S[region]
        if s.own and s.shown and s.layer == "BACKGROUND" and s.sublevel == -1 then mine[#mine + 1] = region end
    end
    local function HungFrom(target, targetPoint)
        for _, piece in ipairs(mine) do
            local p = S[piece].points[1]
            if p and p[1] == "TOPRIGHT" and p[2] == target and p[3] == targetPoint and p[4] == 0 and p[5] == 0 then return piece end
        end
    end
    local bands, counted = {}, 0
    local right = HungFrom(window, "TOPRIGHT")
    while right do
        local chain, piece = {}, HungFrom(right, "TOPLEFT")
        while piece do
            chain[#chain + 1] = piece
            piece = HungFrom(piece, "TOPLEFT")
        end
        local band = { right = right, left = chain[#chain], copies = #chain - 1, tall = S[right].height,
            key = game.themed[right], coords = S[right].coords, width = S[right].width }
        for _, p in ipairs(chain) do
            band.width = band.width + S[p].width
            assert(S[p].height == band.tall, "every piece of a band as tall as it")
            assert(game.themed[p] == band.key, "every piece of a band from the same sheet")
            assert(S[p].coords[3] == band.coords[3] and S[p].coords[4] == band.coords[4], "the same sheet rows")
        end
        counted = counted + 1 + #chain
        bands[#bands + 1] = band
        right = HungFrom(right, "BOTTOMRIGHT")
    end
    assert(counted == #mine, "no stray band pieces shown (" .. counted .. " of " .. #mine .. ")")
    return bands
end

local function Stone(game, window)
    for _, region in ipairs(game.S[window].regions) do
        local s = game.S[region]
        if s.own and s.layer == "BACKGROUND" and s.sublevel == 0 then return region, s end
    end
end

local function Point(game, frame, i)
    local p = game.S[frame].points[i or 1]
    if not p then return "none" end
    return string.format("%s %s %s %g %g", p[1], tostring(game.S[p[2]] and game.S[p[2]].name or p[2]), p[3], p[4], p[5])
end

---------------------------------------------------------------------------
-- Load, registry and defaults
---------------------------------------------------------------------------

local game = NewGame()
local env, S, ns = game.env, game.S, game.ns
env.ContainerFrameContainer = game.Widget("Frame", "ContainerFrameContainer", env.UIParent)
env.BagItemSearchBox = game.Widget("EditBox", "BagItemSearchBox", env.UIParent)
env.BagItemAutoSortButton = game.Widget("Button", "BagItemAutoSortButton", env.UIParent)
local pack, packParts = MakeWindow(game, "ContainerFrame1", "backpack")
local bag, bagParts = MakeWindow(game, "ContainerFrame2", "bag")
local other = MakeWindow(game, "ContainerFrame3", "bag")
local small = MakeWindow(game, "ContainerFrame4", "bag")
local one, oneParts = MakeWindow(game, "ContainerFrameCombinedBags", "combined")
game.Give(env.ContainerFrameContainer, "ContainerFrames", { pack, bag, other, small })

local Look = game.Load()
local B = Look.Bags
Equal(game.limitsAtKit[1] .. " " .. game.limitsAtKit[2], "4 16", "the One Bag limits exist as soon as the kit loads")
Equal(#ns.registry .. " " .. ns.registry[1].key .. " " .. ns.registry[2].key, "2 oneBag bags", "oneBag, then bags")
Equal(ns.registry[1].apply == ns.registry[1].restore, true, "the One Bag reader runs either way")
Equal(tostring(ns.DB_DEFAULTS.bags) .. " " .. tostring(ns.DB_DEFAULTS.oneBag) .. " " .. ns.DB_DEFAULTS.oneBagColumns, "true false 8",
    "the area's defaults")
Equal(type(ns.SetOneBagColumns) .. " " .. type(ns.SkinBank), "function function", "the public functions")

game.Pass()
Equal(B.active, true, "on")
Equal(#game.errors, 0, "no errors at the first pass")

---------------------------------------------------------------------------
-- Ordinary bags
---------------------------------------------------------------------------

local ORDINARY = {
    { 2, 72, {}, 82 }, { 4, 86, {}, 96 }, { 5, 94, { 32 }, 136 }, { 6, 72, { 32 }, 114 }, { 7, 94, { 32 }, 136 },
    { 8, 94, { 32 }, 136 }, { 10, 72, { 73 }, 155 }, { 12, 94, { 73 }, 177 }, { 14, 72, { 114 }, 196 },
    { 16, 94, { 114 }, 218 }, { 18, 72, { 155 }, 237 }, { 20, 94, { 155 }, 259 }, { 24, 94, { 196 }, 300 },
    { 28, 94, { 237 }, 341 }, { 32, 94, { 237, 41 }, 382 }, { 36, 94, { 237, 82 }, 423 },
}
-- Each top's sheet rows (spec 5.4 and 13): the two-slot top 1:1, the one-row
-- and usual tops 84 and 92 sheet rows drawn 86 and 94 high.
local TOP_ROWS = { [72] = 97, [86] = 2, [94] = 2 }
local TOP_ENDS = { [72] = 169, [86] = 86, [94] = 94 }
for _, row in ipairs(ORDINARY) do
    local size, top, middles, height = row[1], row[2], row[3], row[4]
    local label = size .. " slots"
    Open(game, bag, size)
    Equal(S[bag].width .. " x " .. S[bag].height, "192 x " .. height, label .. ": the window")
    local bands = Bands(game, bag)
    Equal(#bands, #middles + 2, label .. ": top, middles and lip")
    Equal(bands[1].tall, top, label .. ": the top")
    Near(bands[1].coords[3], TOP_ROWS[top] / 512, label .. ": the top's sheet rows")
    Near(bands[1].coords[4], TOP_ENDS[top] / 512, label .. ": the top's last sheet row")
    for i, tall in ipairs(middles) do
        Equal(bands[i + 1].tall, tall, label .. ": middle " .. i)
        Near(bands[i + 1].coords[3], (i == 1 and 181 or 213) / 512, label .. ": middle " .. i .. "'s first sheet row")
        Near(bands[i + 1].coords[4] - bands[i + 1].coords[3], tall / 512, label .. ": drawn 1:1")
    end
    local lip = bands[#bands]
    Equal(lip.tall, 10, label .. ": the lip")
    Near(lip.coords[3], 169 / 512, label .. ": the lip's rows")
    Near(lip.coords[4], 179 / 512, label .. ": to row 179")
    for _, band in ipairs(bands) do
        Equal(band.width .. " " .. band.copies .. " " .. band.key, "256 1 bagComponents", label .. ": art 256 wide, one column, Dark Mode's key")
    end
    Near(bands[1].coords[1], 204 / 256, label .. ": the right end's sheet columns")
    Near(S[bands[1].left].coords[2], 162 / 256, label .. ": the left part's")
    local stone, s = Stone(game, bag)
    local missing = math.ceil(size / 4) * 4 - size
    local wantStone = missing > 0 and size % 4 ~= 2
    Equal(stone ~= nil and s.shown, wantStone, label .. ": stone over leftover cells")
end
-- Shrinking: bands no longer wanted are hidden (Bands() checks no stray piece shows).
Open(game, bag, 4)
Equal(#Bands(game, bag) .. " " .. S[bag].height, "2 96", "36 then 4 slots: the old bands hidden")

-- Slots on the old grid.
Open(game, bag, 16)
local items = rawget(bag, "Items")
Equal(Point(game, items[1]), "BOTTOMRIGHT ContainerFrame2 BOTTOMRIGHT -12 9", "the first slot at the bottom-right")
Equal(Point(game, items[2]), "BOTTOMRIGHT ContainerFrame2 BOTTOMRIGHT -54 9", "42 across")
Equal(Point(game, items[5]), "BOTTOMRIGHT ContainerFrame2 BOTTOMRIGHT -12 50", "41 up")
Equal(Point(game, items[16]), "BOTTOMRIGHT ContainerFrame2 BOTTOMRIGHT -138 132", "the last at the top-left")
Equal(#S[items[1]].points, 1, "one anchor each")
Open(game, bag, 7)
Equal(Point(game, items[5]) .. " | " .. Point(game, items[7]), "BOTTOMRIGHT ContainerFrame2 BOTTOMRIGHT -12 50 | "
    .. "BOTTOMRIGHT ContainerFrame2 BOTTOMRIGHT -96 50", "the top row filled from its right")
local stone, stoneState = Stone(game, bag)
Equal(stoneState.width .. " x " .. stoneState.height, "39 x 37", "7 slots: one cell of stone")
Equal(Point(game, stone), "BOTTOMRIGHT ContainerFrame2 BOTTOMRIGHT -137 49", "left of the last filled top-row cell, one right and down")
Equal(game.themed[stone] .. " " .. stoneState.layer .. " " .. stoneState.sublevel, "bagComponents BACKGROUND 0", "over the sheet, greyed with it")
Near(stoneState.coords[1] * 256, 110, "plain stone's columns")
Near(stoneState.coords[4] * 512, 160, "and rows")
Open(game, bag, 5)
Equal(stoneState.width .. " " .. Point(game, stone), "123 BOTTOMRIGHT ContainerFrame2 BOTTOMRIGHT -53 49", "5 slots: three cells of stone")

-- Empty slots, the ring, the portrait, the name, the close button.
local item = items[1]
Equal(S[item.icon].alpha, 0, "an empty slot's icon hidden (the sheet's cell shows)")
game.Give(item, "hasItem", 1)
item:SetItemButtonTexture(133)
Equal(S[item.icon].alpha, 1, "an item: shown")
game.Give(item, "hasItem", nil)
item:SetItemButtonTexture(nil)
Equal(S[item.icon].alpha, 0, "taken out: hidden again")
-- Forever's 70707 UI: an empty slot in the combined bag draws a greyed bag icon.
do
    local bagIcon = GameTexture(game, item)
    game.Give(item, "EmptyBagIcon", bagIcon)
    item:SetItemButtonTexture(nil)
    Equal(S[bagIcon].alpha, 0, "the combined bag's greyed icon faded too")
    game.Give(item, "EmptyBagIcon", nil)
    item:SetItemButtonTexture(nil)
    Equal(S[item.icon].alpha, 0, "a slot without one is fine")
end
local ring = S[item].faces.Normal
Equal(S[ring].file .. " " .. S[ring].width .. " " .. Point(game, ring), "Interface\\Buttons\\UI-Quickslot2 64 CENTER ContainerFrame2Item1 CENTER 0 -1",
    "the 1.x ring, 64 square, one below the middle")
Equal(table.concat(S[ring].coords, " ") .. " " .. tostring(game.themed[ring]), "0 1 0 1 nil", "the whole file, never greyed")
Equal(S[packParts.face] and S[bagParts.face].file, "game portrait", "a bag keeps the game's portrait")
local holder = bag.PortraitContainer
Equal(S[holder].width .. " " .. Point(game, holder) .. " " .. S[holder].level, "40 TOPLEFT ContainerFrame2 TOPLEFT 4 -4 5",
    "the portrait's holder in the art's round hole, at the window's level")
Equal(S[bagParts.face].layer .. " " .. S[bagParts.face].sublevel, "BACKGROUND -8", "the portrait under the ring")
Equal(S[bagParts.title].font.fontName .. " " .. Point(game, bagParts.title) .. " " .. S[bagParts.title].width .. " " .. S[bagParts.title].justify,
    "GameFontHighlight TOPLEFT ContainerFrame2 TOPLEFT 47 -10 112 CENTER", "the name on the name plate")
local close = bag.CloseButton
Equal(S[close].width .. " " .. Point(game, close) .. " " .. (game.darkClose[close] or 0), "32 TOPRIGHT ContainerFrame2 TOPRIGHT -2 0 1",
    "the small red X, handed to Dark Windows once")
Equal(S[S[close].faces.Normal].file, "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", "in the 1.x art")

-- The game's art faded; the kept pieces, the portrait and the slots untouched.
Equal(S[bagParts.own].alpha .. S[bagParts.nine].alpha .. S[bagParts.bg].alpha .. S[bagParts.ring].alpha, "0000",
    "the window's own art, its nine-slice, its backing and the modern ring faded")
Equal(S[bagParts.face].alphaSets + S[bagParts.mask].alphaSets + S[bagParts.portraitButton].alphaSets + S[bagParts.filter].alphaSets
    + S[bagParts.title].alphaSets, 0, "the portrait, its mask, the portrait button, the filter icon and the name untouched")
for state, face in pairs(S[close].faces) do Equal(S[face].alpha, 1, "the close button's " .. state .. " kept") end
Equal(table.concat(game.violations, ", "), "", "item buttons never looked into, what hangs on them never touched")

---------------------------------------------------------------------------
-- The backpack
---------------------------------------------------------------------------

Open(game, pack, 16)
local packBands = Bands(game, pack)
Equal(S[pack].width .. " x " .. S[pack].height .. " " .. #packBands, "192 x 240 1", "16 slots: the backpack sheet alone")
Equal(packBands[1].tall .. " " .. packBands[1].key .. " " .. packBands[1].coords[3] .. " " .. packBands[1].coords[4], "255 backpackBg 0 1",
    "the whole sheet, 255 tall, greyed by Dark Mode")
Equal(Point(game, pack.CloseButton) .. " | " .. Point(game, pack.MoneyFrame), "TOPRIGHT ContainerFrame1 TOPRIGHT 1 -2 | "
    .. "TOPRIGHT ContainerFrame1 TOPRIGHT -6 -215", "the close button and the gold on its strip")
Equal(S[packParts.border].alpha .. " " .. S[packParts.coin].alphaSets, "0 0", "the money's border faded, the money itself untouched")
local packItems = rawget(pack, "Items")
Equal(Point(game, packItems[1]) .. " | " .. Point(game, packItems[16]), "BOTTOMRIGHT ContainerFrame1 TOPRIGHT -12 -211 | "
    .. "BOTTOMRIGHT ContainerFrame1 TOPRIGHT -138 -88", "the backpack's rows from its top")
Equal(S[packParts.face].file .. " " .. table.concat(S[packParts.face].coords, " ") .. " " .. tostring(game.themed[packParts.face]),
    "Interface\\Buttons\\Button-Backpack-Up 0 1 0 1 nil", "the 1.x backpack icon in the ring, never greyed")
Equal(Point(game, env.BagItemSearchBox) .. " " .. S[env.BagItemSearchBox].width .. " " .. S[env.BagItemSearchBox].level,
    "TOPLEFT ContainerFrame1 TOPLEFT 52 -31 104 15", "the search box on the backpack, ten over the window")
Equal(Point(game, env.BagItemAutoSortButton) .. " " .. S[env.BagItemAutoSortButton].level, "TOPRIGHT ContainerFrame1 TOPRIGHT -10 -28 15",
    "the sort button too")
Open(game, pack, 20)
packBands = Bands(game, pack)
Equal(S[pack].height .. " " .. #packBands, "281 3", "20 slots: top, one row, money strip")
Equal(packBands[1].tall .. " " .. packBands[2].tall .. " " .. packBands[3].tall, "210 41 45", "210, 41 and 45 tall")
Near(packBands[1].coords[4], 210 / 255, "the top to 210/255 of the sheet")
Equal(packBands[2].key, "bagComponents", "the extra row from the bag sheet")
Near(packBands[2].coords[3], 215 / 512, "from its row 215")
Near(packBands[3].coords[3], 210 / 255, "the strip from 210/255")
Equal(Point(game, pack.MoneyFrame) .. " | " .. Point(game, packItems[1]), "TOPRIGHT ContainerFrame1 TOPRIGHT -6 -256 | "
    .. "BOTTOMRIGHT ContainerFrame1 TOPRIGHT -12 -252", "the money and the bottom row one row lower")

---------------------------------------------------------------------------
-- One Bag
---------------------------------------------------------------------------

for _, case in ipairs({ { 3, 4 }, { 8.4, 8 }, { 8.6, 9 }, { 99, 16 }, { nil, 4 }, { "x", 4 } }) do
    ns.db.oneBagColumns = case[1]
    Open(game, one, 40)
    local columns = case[2]
    local bands = Bands(game, one)
    Equal(S[one].width .. " " .. bands[1].copies .. " " .. bands[1].width, (192 + 42 * (columns - 4)) .. " " .. (columns - 3) .. " "
        .. (256 + 42 * (columns - 4)), "One Bag at " .. tostring(case[1]) .. ": " .. columns .. " across")
end
ns.db.oneBagColumns = 8
Open(game, one, 70)
local oneBands = Bands(game, one)
Equal(S[one].width .. " x " .. S[one].height .. " " .. #oneBands .. " " .. oneBands[2].tall .. " " .. oneBands[1].width,
    "360 x 445 3 205 424", "70 slots at 8 across: nine rows, one middle of five")
local oneItems = rawget(one, "Items")
Equal(Point(game, oneItems[70]), "BOTTOMRIGHT ContainerFrameCombinedBags TOPRIGHT -306 -88", "the last item top-left")
Equal(Point(game, oneItems[69]), "BOTTOMRIGHT ContainerFrameCombinedBags TOPRIGHT -264 -88", "the one before it to its right")
Equal(Point(game, oneItems[1]), "BOTTOMRIGHT ContainerFrameCombinedBags TOPRIGHT -96 -416", "the first item ends the bottom row, from its left")
local oneStone, oneStoneState = Stone(game, one)
Equal(oneStoneState.width .. " " .. Point(game, oneStone), "81 BOTTOMRIGHT ContainerFrameCombinedBags TOPRIGHT -11 -417",
    "stone over the two empty cells at the bottom-right")
Equal(S[oneParts.face].file, "Interface\\Buttons\\Button-Backpack-Up", "the backpack icon")
Equal(Point(game, env.BagItemSearchBox) .. " " .. S[env.BagItemSearchBox].level .. " " .. S[env.BagItemAutoSortButton].level,
    "TOPLEFT ContainerFrameCombinedBags TOPLEFT 52 -31 15 15", "search box and sort button lifted over the One Bag window")
Equal(S[oneParts.title].width, 112 + 168, "the name plate as wide as the art")

-- SetOneBagColumns
Equal(ns.SetOneBagColumns(3), 4, "3 columns: 4")
Equal(ns.db.oneBagColumns .. " " .. S[one].width, "4 192", "saved, and the open window follows at once")
Equal(ns.SetOneBagColumns(7.6) .. " " .. S[one].width, "8 360", "rounded")
Equal(ns.SetOneBagColumns("lots"), 4, "not a number: 4")
Equal(ns.SetOneBagColumns(99), 16, "kept within 16")
one:Hide()
ns.SetOneBagColumns(5)
Equal(S[one].width, 696, "a closed window isn't touched")
Open(game, one, 70)
Equal(S[one].width, 234, "and follows when it next opens")
local saved = ns.db
ns.db = nil
Equal(ns.SetOneBagColumns(9.2), 9, "no database: the number, nothing else")
ns.db = saved
-- The search box elsewhere: left where it is.
local box = env.BagItemSearchBox
env.BagItemSearchBox:SetParent(env.UIParent)
S[box].points = { { "CENTER", env.UIParent, "CENTER", 1, 2 } }
ns.SetOneBagColumns(8)
Equal(Point(game, box), "CENTER UIParent CENTER 1 2", "a search box on another window isn't moved")

-- The One Bag reader.
game.cvars.combinedBags = "1"
game.Pass()
Equal(ns.db.oneBag, true, "Combine Bags on: oneBag on")
game.cvars.combinedBags = "0"
game.Pass()
Equal(ns.db.oneBag, false, "off: off (read through the entry's restore while off)")
game.cvars.combinedBags = "1"
game.Pass()
Equal(ns.db.oneBag, true, "on again, read by the restore")
game.cvarFails = true
game.cvars.combinedBags = "0"
game.Pass()
Equal(ns.db.oneBag, true, "a failing read leaves it alone")
game.cvarFails = false
local cvars = env.C_CVar
env.C_CVar = nil
game.Pass()
Equal(ns.db.oneBag, true, "no C_CVar: left alone")
env.C_CVar = cvars
game.Pass()
Equal(ns.db.oneBag, false, "read again")

---------------------------------------------------------------------------
-- Hooks once, nothing while off, small and secret sizes
---------------------------------------------------------------------------

for _ = 1, 3 do game.Pass() end
Open(game, bag, 16)
for _, method in ipairs({ "UpdateFrameSize", "UpdateItemLayout", "UpdateSearchBox", "UpdateMiscellaneousFrames", "OnShow" }) do
    Equal(game.hookCount["ContainerFrame2:" .. method], 1, "ContainerFrame2's " .. method .. " hooked once")
end
Equal(game.hookCount["ContainerFrame2Item1:SetItemButtonTexture"], 1, "an item button hooked once")
Equal(game.hookCount["ContainerFrame2Item16:SetItemButtonTexture"], 1, "every item button once")

Open(game, small, 1)
Equal(S[small].width .. " " .. #Bands(game, small), "178 0", "one slot: the game's look")
Open(game, small, SECRET)
Equal(S[small].width .. " " .. #Bands(game, small), "178 0", "a secret size: left alone")
Equal(#game.errors, 0, "no errors")

-- A guarded window or slot in a fight: left alone, dressed when the fight ends.
game.combat = true
S[other].protected = true
Open(game, other, 12)
Equal(S[other].width, 178, "a guarded window isn't resized in a fight")
local otherItems = rawget(other, "Items")
Equal(Point(game, otherItems[1]), "BOTTOMRIGHT ContainerFrame3 BOTTOMRIGHT -12 9", "its plain slots still placed")
S[other].protected = false
S[otherItems[2]].protected = true
game.combat = false
game.Fire("PLAYER_REGEN_ENABLED")
Equal(S[other].width .. " x " .. S[other].height, "192 x 177", "dressed when the fight ends")
game.combat = true
Open(game, other, 12)
Equal(Point(game, otherItems[2]), "BOTTOMRIGHT ContainerFrame3 BOTTOMRIGHT -7 9", "a guarded slot left where the game put it")
game.combat = false
game.Fire("PLAYER_REGEN_ENABLED")
Equal(Point(game, otherItems[2]), "BOTTOMRIGHT ContainerFrame3 BOTTOMRIGHT -54 9", "placed after the fight")
S[otherItems[2]].protected = false
Equal(table.concat(game.violations, ", "), "", "nothing guarded moved in a fight")

-- Off: the hooks stand still, the reload note asked for.
Equal(ns.needsReload, nil, "no reload note while on")
ns.db.bags = false
game.Pass()
Equal(tostring(B.active) .. " " .. tostring(ns.needsReload), "false true", "off after the art went on: the reload note")
Open(game, other, 16)
Equal(S[other].width .. " " .. S[other].height, "178 100", "off: a window opening keeps the game's look")
Equal(S[one].shown, true, "(the One Bag window still open)")
local oneWidth = S[one].width
Equal(ns.SetOneBagColumns(12) .. " " .. ns.db.oneBagColumns .. " " .. S[one].width, "12 12 " .. oneWidth,
    "off: the columns saved, the open One Bag window left alone")
ns.SetOneBagColumns(8)
ns.db.bags = true
game.Pass()
Equal(S[one].width, 360, "on again: the open One Bag window dressed at the saved columns")

---------------------------------------------------------------------------
-- Dark Mode's keys
---------------------------------------------------------------------------

local keys = {}
for texture, key in pairs(game.themed) do keys[key] = (keys[key] or 0) + 1 end
local names = {}
for key in pairs(keys) do names[#names + 1] = key end
table.sort(names)
Equal(table.concat(names, " "), "backpackBg bagComponents", "only the sheets and the stone go to Dark Mode")

---------------------------------------------------------------------------
-- The bank
---------------------------------------------------------------------------

local function RedButton(name, parent)
    local button = game.Widget("Button", name, parent)
    for _, slice in ipairs({ "Left", "Right", "Middle" }) do game.Give(button, slice, GameTexture(game, button)) end
    for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do S[button].faces[state] = GameTexture(game, button) end
    return button
end

local function Pool(make)
    local pool = { active = {}, free = {} }
    function pool:Acquire()
        local button = table.remove(self.free) or make()
        self.active[button] = true
        S[button].shown = true
        return button
    end
    function pool:ReleaseAll()
        for button in pairs(self.active) do
            self.free[#self.free + 1] = button
            S[button].shown = false
        end
        self.active = {}
    end
    function pool:EnumerateActive() return pairs(self.active) end
    return pool
end

local bank = game.Widget("Frame", "BankFrame", env.UIParent)
S[bank].shown = false
local bankBack = GameTexture(game, bank, "bank-frame-background")
game.Give(bank, "Background", bankBack)
local divider = GameTexture(game, bank, "bank-divider")
local otherArt = GameTexture(game, bank, "bank-something")
local bagText, bagCost = game.Widget("FontString", nil, bank), game.Widget("FontString", nil, bank)
game.Give(bank, "BagText", bagText)
game.Give(bank, "BagCost", bagCost)
local bankHolder = game.Widget("Frame", nil, bank)
game.Give(bank, "PortraitContainer", bankHolder)
local bankFace = GameTexture(game, bankHolder)
game.Give(bankHolder, "portrait", bankFace)
local panel = game.Widget("Frame", "BankPanel", bank)
game.Give(bank, "BankPanel", panel)
local panelNine = game.Widget("Frame", nil, panel)
game.Give(panel, "NineSlice", panelNine)
local nineEdge = GameTexture(game, panelNine)
local shadows = game.Widget("Frame", nil, panel)
game.Give(panel, "EdgeShadows", shadows)
local purchase = RedButton("BankFramePurchaseButton", panel)
game.Give(panel, "PurchaseButton", purchase)
local money = game.Widget("Frame", nil, panel)
game.Give(panel, "MoneyFrame", money)
local withdraw, deposit = RedButton("Withdraw", money), RedButton("Deposit", money)
game.Give(money, "WithdrawButton", withdraw)
game.Give(money, "DepositButton", deposit)

local slotWidths, made = { 37, 28, 0 }, 0
local itemPool = Pool(function()
    made = made + 1
    local button = game.Widget("Button", "BankSlot" .. made, panel)
    S[button].width = slotWidths[made] or 37
    local normal = GameTexture(game, button, "bank-frame-item-slotframe")
    S[button].faces.Normal = normal
    local back = GameTexture(game, button, "bags-item-slot64")
    game.Give(button, "Background", back)
    game.Give(button, "Refresh", function() S[normal].atlas, S[normal].file = "bank-frame-item-slotframe", "atlas" end)
    game.Give(button, "UpdateBackgroundForBankType", function() S[back].colour, S[back].file = nil, "atlas" end)
    return button
end)
game.Give(panel, "itemButtonPool", itemPool)
game.Give(panel, "GenerateItemSlotsForSelectedTab", function(self)
    itemPool:ReleaseAll()
    for _ = 1, 3 do itemPool:Acquire() end
end)
game.Give(panel, "RefreshBankPanel", function()
    for button in itemPool:EnumerateActive() do button:Refresh() end
end)

local bagStates, bagsMade = { "bag", "empty", "unbought" }, 0
local bagPool = Pool(function()
    bagsMade = bagsMade + 1
    local button = game.Widget("Button", "BankBag" .. bagsMade, bank)
    S[button].width = 37
    S[button].faces.Normal = GameTexture(game, button, "bank-frame-bag-slotframe")
    game.Give(button, "Background", GameTexture(game, button, "bank-frame-bag-slot-bg"))
    local lock = GameTexture(game, button, "bankslot-icon-lock")
    game.Give(button, "DisabledOverlay", lock)
    local icon = GameTexture(game, button)
    game.Give(button, "icon", icon)
    game.Give(button, "SetItemButtonTexture", function(_, file) S[icon].file = file end)
    return button
end)
game.Give(bank, "itemButtonBagPool", bagPool)
game.Give(bank, "RefreshBagButtons", function(self)
    bagPool:ReleaseAll()
    for i = 1, 3 do
        local button = bagPool:Acquire()
        local state = bagStates[i]
        game.Give(button, "tooltipText", state == "unbought" and env.BANK_BAG_PURCHASE or env.BANK_BAG)
        S[button.DisabledOverlay].shown = state == "unbought"
        button:SetItemButtonTexture(state == "bag" and 133 or nil)
    end
end)
S[bank].scripts.OnShow = function(self)
    self:RefreshBagButtons()
    panel:GenerateItemSlotsForSelectedTab()
end

-- The chrome's call at login (the bank closed), and again: hooks once.
ns.SkinBank(bank)
ns.SkinBank(bank)
for _, hook in ipairs({ "BankPanel:GenerateItemSlotsForSelectedTab", "BankPanel:RefreshBankPanel", "BankFrame:RefreshBagButtons",
    "BankFrame:OnShow" }) do
    Equal(game.hookCount[hook], 1, hook .. " hooked once")
end
Equal(S[bankBack].alpha .. S[divider].alpha .. S[otherArt].alpha .. S[nineEdge].alpha, "0010",
    "the modern backdrop, the divider and the panel's nine-slice faded; other art kept")
Equal(S[shadows].shown, false, "the edge shadows hidden")
local floor
for _, region in ipairs(S[bank].regions) do
    if S[region].own and S[region].layer == "BACKGROUND" then floor = region end
end
local fs = S[floor]
Equal(fs.file .. " " .. fs.wrap[1] .. " " .. fs.wrap[2] .. " " .. tostring(fs.horizTile) .. " " .. tostring(fs.vertTile),
    "Interface\\AddOns\\EraUI\\Media\\Classic\\UI-BankFrame-Floor REPEAT REPEAT true true", "the gravel floor, tiled both ways")
Equal(fs.sublevel .. " " .. Point(game, floor, 1) .. " | " .. Point(game, floor, 2) .. " " .. tostring(game.themed[floor]),
    "1 TOPLEFT BankFrame TOPLEFT 4 -20 | BOTTOMRIGHT BankFrame BOTTOMRIGHT -4 4 nil", "over the chrome's backing, never greyed")
local headings = 0
for _, region in ipairs(S[bank].regions) do
    if S[region].own and S[region].kind == "FontString" then
        headings = headings + 1
        Equal(S[region].text .. " " .. S[region].font.fontName .. " " .. Point(game, region), "Item Slots EraUILookGold TOP BankPanel TOP 0 -46",
            "the gold Item Slots heading")
    end
end
Equal(headings, 1, "one heading, however often the bank is dressed")
Equal(S[bagText].font.fontName .. " " .. S[bagCost].font.fontName, "EraUILookGold EraUILookGold", "Bag Slots and its cost in gold")
local gold = env.EraUILookGold
Equal(gold.copied.fontName .. " " .. table.concat(gold.colour, " "), "GameFontNormal 1 0.82 0", "the gold font: the normal one in the old gold")
Equal(table.concat(game.portraits, " "), "player", "an empty portrait at login: the player's face")
for _, button in ipairs({ purchase, withdraw, deposit }) do
    local face = S[button].faces.Normal
    Equal(S[face].file .. " " .. table.concat(S[face].coords, " "), "Interface\\Buttons\\UI-Panel-Button-Up 0 0.625 0 0.6875",
        S[button].name .. ": the 1.x red art")
    Equal(S[button.Left].alpha .. " " .. game.darkRed[button] .. " " .. S[button].fonts.disabled.fontName, "0 1 GameFontDisable",
        S[button].name .. ": the game's slices faded, handed to Dark Windows once")
end

-- Opening the bank: slots and bag slots dressed.
S[bankFace].file = nil
game.npc = true
bank:Show()
local slots = {}
for button in itemPool:EnumerateActive() do slots[#slots + 1] = button end
table.sort(slots, function(a, b) return S[a].name < S[b].name end)
for i, size in ipairs({ 64, 28 * 64 / 37, 64 }) do
    local slot = slots[i]
    local face = S[slot].faces.Normal
    Near(S[face].width, size, S[slot].name .. ": the ring sized by the slot (" .. S[slot].width .. " wide)")
    Equal(S[face].file .. " " .. Point(game, face) .. " " .. tostring(game.themed[face]),
        "Interface\\Buttons\\UI-Quickslot2 CENTER " .. S[slot].name .. " CENTER 0 -1 nil", S[slot].name .. ": centred one below, never greyed")
    local hole = S[slot.Background]
    Equal(table.concat(hole.colour, " ") .. " " .. Point(game, slot.Background, 1) .. " | " .. Point(game, slot.Background, 2),
        "0.06 0.06 0.06 1 TOPLEFT " .. S[slot].name .. " TOPLEFT 1 -1 | BOTTOMRIGHT " .. S[slot].name .. " BOTTOMRIGHT -1 1",
        S[slot].name .. ": a near-black hole one in from the edges")
end
panel:RefreshBankPanel()
Equal(S[S[slots[1]].faces.Normal].file, "Interface\\Buttons\\UI-Quickslot2", "the game's refresh puts its frame back; the ring follows")
Equal(game.hookCount["BankSlot1:Refresh"] .. " " .. game.hookCount["BankSlot1:UpdateBackgroundForBankType"], "1 1", "each slot hooked once")
Equal(table.concat(game.portraits, " "), "player npc", "an empty ring at opening: the banker's face")

local bags = {}
for button in bagPool:EnumerateActive() do bags[#bags + 1] = button end
table.sort(bags, function(a, b) return S[a].name < S[b].name end)
local EMPTY_BAG = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
local function BagLook(button)
    local icon = S[button.icon]
    return tostring(icon.file) .. " " .. table.concat(icon.vertex or {}, " ") .. " " .. tostring(S[button.DisabledOverlay].shown)
end
Equal(BagLook(bags[1]), "133 1 1 1 false", "a bag kept, white")
Equal(BagLook(bags[2]), EMPTY_BAG .. " 1 1 1 false", "a bought empty slot: the old bag icon, white")
Equal(BagLook(bags[3]), EMPTY_BAG .. " 1 0.1 0.1 false", "a slot not bought: red, no padlock")
Equal(S[S[bags[3]].faces.Normal].file, "Interface\\Buttons\\UI-Quickslot2", "bag slots wear the ring too")
bags[1]:SetItemButtonTexture(nil)
Equal(BagLook(bags[1]), EMPTY_BAG .. " 1 1 1 false", "a bag taken out: the old bag icon")
ns.db.textureSource = "bundled"
bank:RefreshBagButtons()
Equal(S[bags[2].icon].file, "Interface\\AddOns\\EraUI\\Media\\Classic\\UI-PaperDoll-Slot-Bag", "the bundled copy with that art source")
ns.db.textureSource = "builtin"
Equal(game.themed[bags[2].icon], nil, "never greyed")

-- Still while Bags & Bank is off (as loaded at login).
game.settings.bagsBank = false
panel:RefreshBankPanel()
Equal(S[S[slots[1]].faces.Normal].file, "atlas", "off: the hooks stand still")
game.settings.bagsBank = true

-- A refused red art file: the game's own button left whole.
local refused = RedButton("Refused", env.UIParent)
game.refuse["Interface\\Buttons\\UI-Panel-Button-Up"] = true
Equal(Look.SkinRedButton(refused), false, "the client refuses the art")
Equal(S[refused.Left].alpha .. " " .. tostring(game.darkRed[refused]), "1 nil", "its slices kept, nothing handed on")
game.refuse["Interface\\Buttons\\UI-Panel-Button-Up"] = nil

-- A bank without its panel's methods: named in the debug report.
local bare = game.Widget("Frame", "BareBank", env.UIParent)
game.Give(bare, "BankPanel", game.Widget("Frame", "BarePanel", bare))
ns.SkinBank(bare)
Equal(tostring(game.missing["BankPanel:RefreshBankPanel"]) .. " " .. tostring(game.missing["BankFrame:RefreshBagButtons"]), "true true",
    "missing bank methods reported")

---------------------------------------------------------------------------
-- Nothing written on the game's frames
---------------------------------------------------------------------------

Equal(table.concat(game.Strays(), ", "), "", "no key written on a bag window, item button, BankFrame, BankPanel or bank button")
Equal(table.concat(game.violations, ", "), "", "no item button looked into, nothing guarded moved")
Equal(table.concat(game.errors, " | "), "", "no errors")

---------------------------------------------------------------------------
-- Off from login: no reload note
---------------------------------------------------------------------------

local quiet = NewGame({ db = { bags = false, panels = true, textureSource = "builtin" } })
quiet.Load()
quiet.Pass()
quiet.Pass()
Equal(quiet.ns.needsReload, nil, "Bags & Bank off from login: no reload note")
Equal(quiet.E.Look.Bags.active, false, "and nothing active")

print("TestBags: " .. checks .. " checks passed")
