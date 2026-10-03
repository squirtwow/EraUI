-- The spellbook key (P) with the real Classic/SpellBook.lua and
-- Modules/TrainingGuide.lua. P is an override binding to a secure button whose
-- click flips the secure click layer's "unit" (a macro with Combat Spell
-- Dragging, a plain click without it); a unit watch shows the layer. The mock
-- runs those secure steps as the game does: the action fires on the key's
-- release, attribute changes and unit watches may touch protected frames in
-- combat, and any addon edit to a protected frame in combat fails the test.
local checks = 0
local function Equal(a, b, label)
    checks = checks + 1
    assert(a == b, label .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end

local function Session(drag)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    local combat, restricted = false, false
    local frames, watched, timers, bindings, listeners = {}, {}, {}, {}, {}
    local methods = {}
    local function Frame(kind, parent, template)
        local f = setmetatable({ kind = kind, parent = parent, children = {}, scripts = {}, hooks = {}, attrs = {},
            shown = true, alpha = 1, level = 1, width = 10, height = 10, checked = false, enabled = true },
            { __index = methods })
        f.secure = template ~= nil and template:find("Secure", 1, true) ~= nil
        if parent then parent.children[#parent.children + 1] = f end
        if f.secure then
            f.protected = true
            local p = parent
            while p and p ~= env.UIParent do p.protected = true; p = p.parent end
        end
        frames[#frames + 1] = f
        return f
    end
    -- Layout, visibility, mouse and attributes of a protected frame can't be
    -- changed by addon code during combat; the game's secure code can.
    local function Lock(f)
        assert(not (combat and f.protected and not restricted), "addon edit to a protected frame during combat")
    end
    for _, name in ipairs({ "SetSize", "SetWidth", "SetHeight", "SetAllPoints", "ClearAllPoints", "SetFrameStrata",
        "SetFrameLevel", "SetScale", "SetID", "RegisterForDrag", "EnableMouseWheel", "SetToplevel", "SetHitRectInsets" }) do
        methods[name] = function(self) Lock(self) end
    end
    for _, name in ipairs({ "SetBlendMode", "SetColorTexture", "SetTextColor", "SetJustifyH", "SetMaxLines",
        "SetDesaturated", "SetVertexColor", "SetTexture", "SetNormalTexture", "SetPushedTexture", "SetHighlightTexture",
        "SetCheckedTexture", "SetFontString", "SetDisabledFontObject", "SetButtonState", "LockHighlight",
        "UnlockHighlight", "SetAutoFocus", "SetMaxLetters", "ClearFocus", "SetScrollChild", "SetWordWrap", "Clear",
        "SetCooldown", "UnregisterEvent", "SetFormattedText" }) do
        methods[name] = function() end
    end
    function methods:SetPoint(_, target)
        Lock(self)
        if self.protected and type(target) == "table" and target ~= env.UIParent then target.protected = true end
    end
    function methods:GetPoint() return "TOPLEFT", env.UIParent, "TOPLEFT", 0, 0 end
    function methods:GetNumPoints() return 1 end
    function methods:EnableMouse(v) Lock(self); self.mouse = v and true or false end
    function methods:IsMouseEnabled() return self.mouse ~= false end
    function methods:RegisterForClicks(...) Lock(self); self.clicks = { ... } end
    function methods:SetAttribute(key, value) Lock(self); self.attrs[key] = value end
    function methods:GetAttribute(key) return self.attrs[key] end
    function methods:IsProtected() return self.protected == true end
    function methods:SetParent(parent) Lock(self); self.parent = parent end
    function methods:GetParent() return self.parent end
    function methods:GetFrameLevel() return self.level end
    function methods:GetFrameStrata() return "MEDIUM" end
    function methods:GetWidth() return self.width end
    function methods:GetHeight() return self.height end
    function methods:GetLeft() return 0 end
    function methods:GetTop() return 0 end
    function methods:GetScale() return 1 end
    function methods:GetEffectiveScale() return 1 end
    function methods:SetAlpha(a) self.alpha = a end
    function methods:GetAlpha() return self.alpha end
    function methods:SetText(text) self.text = text end
    function methods:GetText() return self.text end
    function methods:HasFocus() return false end
    function methods:SetVerticalScroll(v) self.scroll = v end
    function methods:GetVerticalScroll() return self.scroll or 0 end
    function methods:SetChecked(v) self.checked = v and true or false end
    function methods:GetChecked() return self.checked end
    function methods:SetEnabled(v) self.enabled = v and true or false end
    function methods:IsEnabled() return self.enabled end
    function methods:GetID() return self.id or 0 end
    methods.SetID = function(self, id) Lock(self); self.id = id end
    function methods:CreateTexture() return Frame("Texture", self) end
    function methods:CreateFontString() return Frame("FontString", self) end
    function methods:Texture(key)
        self.textures = self.textures or {}
        self.textures[key] = self.textures[key] or Frame("Texture", self)
        return self.textures[key]
    end
    function methods:GetHighlightTexture() return self:Texture("Highlight") end
    function methods:GetNormalTexture() return self:Texture("Normal") end
    function methods:GetCheckedTexture() return self:Texture("Checked") end
    function methods:SetScript(event, fn) self.scripts[event] = fn end
    function methods:GetScript(event) return self.scripts[event] end
    function methods:HookScript(event, fn)
        self.hooks[event] = self.hooks[event] or {}
        table.insert(self.hooks[event], fn)
    end
    -- Handlers are addon code, even when the game's secure code set them off.
    function methods:Fire(event, ...)
        local was = restricted
        restricted = false
        if self.scripts[event] then self.scripts[event](self, ...) end
        for _, fn in ipairs(self.hooks[event] or {}) do fn(self, ...) end
        restricted = was
    end
    function methods:SetShown(v)
        Lock(self)
        v = v and true or false
        if self.shown == v then return end
        self.shown = v
        self:Fire(v and "OnShow" or "OnHide")
    end
    function methods:Show() self:SetShown(true) end
    function methods:Hide() self:SetShown(false) end
    function methods:IsShown() return self.shown end
    function methods:IsVisible()
        local f = self
        while f do
            if not f.shown then return false end
            f = f.parent
        end
        return true
    end
    function methods:RegisterEvent(event)
        self.events = self.events or {}
        if not self.events[event] then
            self.events[event] = true
            listeners[#listeners + 1] = { frame = self, event = event }
        end
    end

    -- The game's secure button, as far as these buttons use it.
    local function Suffix(button)
        if button == "LeftButton" then return "1" end
        if button == "RightButton" then return "2" end
        return "-" .. button
    end
    local function Attr(f, name, suffix)
        local a = f.attrs
        local v = a[name .. suffix]
        if v == nil then v = a["*" .. name .. suffix] end
        if v == nil then v = a[name .. "*"] end
        if v == nil then v = a["*" .. name .. "*"] end
        if v == nil then v = a[name] end
        return v
    end
    local casts = {}
    local function SecureAction(f, button, down)
        if (down and true or false) ~= (f.attrs.useOnKeyDown and true or false) then return end
        local unit = Attr(f, "unit", Suffix(button))
        if unit == "player" then
            local help = Attr(f, "helpbutton", Suffix(button))
            if help then button = help end
        end
        local suffix = Suffix(button)
        local kind = Attr(f, "type", suffix)
        if kind == "attribute" then
            local target = Attr(f, "attribute-frame", suffix) or f
            local name = Attr(f, "attribute-name", suffix)
            if name then target.attrs[name] = Attr(f, "attribute-value", suffix) end
        elseif kind == "click" then
            local other = Attr(f, "clickbutton", suffix)
            if other then other:Click("LeftButton", down) end
        elseif kind == "macro" then
            for line in (Attr(f, "macrotext", suffix) or ""):gmatch("[^\n]+") do
                local name = line:match("^/click%s+(%S+)")
                if name and env[name] then env[name]:Click("LeftButton", false) end
            end
        elseif kind == "spell" then
            casts[#casts + 1] = Attr(f, "spell", suffix)
        end
    end
    function methods:Click(button, down)
        button = button or "LeftButton"
        if self.secure then
            local was = restricted
            restricted = true
            SecureAction(self, button, down)
            restricted = was
        else
            if not self.enabled then return end
            if self.kind == "CheckButton" then self.checked = not self.checked end
            if self.scripts.OnClick then self.scripts.OnClick(self, button, down) end
        end
        if self.scripts.PostClick then self.scripts.PostClick(self, button, down) end
    end

    -- A unit watch shows its frame while the unit exists; only "player" does.
    local function Unit(f)
        local node, unit = f, f.attrs.unit
        while unit == nil and node.attrs["useparent-unit"] and node.parent do
            node = node.parent
            unit = node.attrs.unit
        end
        if unit and f.attrs.unitsuffix then unit = unit .. f.attrs.unitsuffix end
        return unit
    end
    local function Watch()
        restricted = true
        for _, f in ipairs(watched) do f:SetShown(Unit(f) == "player") end
        restricted = false
    end
    local function Tick()
        for _ = 1, 20 do
            Watch()
            if #timers == 0 then return end
            local due = timers
            timers = {}
            for _, fn in ipairs(due) do fn() end
        end
        error("timers never settled")
    end
    local function FireEvent(event)
        for _, l in ipairs(listeners) do
            if l.event == event and l.frame.scripts.OnEvent then l.frame.scripts.OnEvent(l.frame, event) end
        end
    end

    env.UIParent = Frame("Frame")
    env.CreateFrame = function(kind, name, parent, template)
        assert(not (combat and template and template:find("Secure", 1, true)), "secure frame created during combat")
        local f = Frame(kind, parent, template)
        if name then env[name] = f end
        return f
    end
    env.RegisterUnitWatch = function(f) watched[#watched + 1] = f end
    env.InCombatLockdown = function() return combat end
    env.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
    env.GetBindingKey = function(binding) if binding == "TOGGLESPELLBOOK" then return "P" end end
    env.SetOverrideBindingClick = function(owner, _, key, name, button)
        assert(not combat, "binding changed during combat")
        bindings[key] = { owner = owner, name = name, button = button or "LeftButton" }
    end
    env.ClearOverrideBindings = function(owner)
        for key, b in pairs(bindings) do if b.owner == owner then bindings[key] = nil end end
    end
    env.IsLoggedIn = function() return true end
    env.GetTime = function() return 0 end
    env.IsModifiedClick = function() return false end
    env.PlaySound = function() end
    env.SOUNDKIT = setmetatable({}, { __index = function() return 0 end })
    env.GameTooltip = { SetOwner = function() end, SetText = function() end, Show = function() end,
        Hide = function() end, SetSpellBookItem = function() end, AddLine = function() end }
    env.GameTooltip_Hide = function() end
    env.GameFontHighlightSmall = {}
    env.NORMAL_FONT_COLOR = { GetRGB = function() return 1, .82, 0 end }
    env.PASSIVE_SPELL_FONT_COLOR = env.NORMAL_FONT_COLOR
    env.SPELLBOOK, env.PAGE_NUMBER, env.SEARCH, env.TRADE_SKILLS, env.PET = "Spellbook", "Page %d", "Search",
        "Professions", "Pet"
    env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    env.unpack = table.unpack
    env.UnitClass = function() return "Hunter", "HUNTER" end
    env.UnitRace = function() return "Orc", "Orc", 2 end
    env.UnitFactionGroup = function() return "Horde" end
    env.UnitLevel = function() return 20 end
    env.UnitName = function() return "Squirt" end
    env.Enum = { SpellBookSpellBank = { Player = 0, Pet = 1 },
        SpellBookItemType = { Spell = 1, FutureSpell = 2, Flyout = 3 }, TrainerType = { General = 0 } }
    -- Two class lines of eight spells: page one of line one fills a layer.
    local lines = { { name = "General", offset = 0, count = 8 }, { name = "Marksmanship", offset = 8, count = 8 } }
    local function Item(i)
        if i < 1 or i > 16 then return nil end
        return { name = "Spell " .. i, subName = "Rank 1", iconID = i, spellID = 1000 + i, actionID = 1000 + i,
            itemType = 1, isPassive = false }
    end
    env.C_SpellBook = {
        GetNumSpellBookSkillLines = function() return #lines end,
        GetSpellBookSkillLineInfo = function(i)
            local l = lines[i]
            return l and { name = l.name, iconID = i, itemIndexOffset = l.offset, numSpellBookItems = l.count,
                shouldHide = false, offSpecID = 0 }
        end,
        GetSpellBookItemType = function() return 1 end,
        GetSpellBookItemInfo = function(i) return Item(i) end,
        GetSpellBookItemName = function(i) local it = Item(i); return it and it.name, it and it.subName end,
        GetSpellBookItemCooldown = function() return { startTime = 0, duration = 0, isEnabled = true, modRate = 1 } end,
        HasPetSpells = function() return nil end,
        PickupSpellBookItem = function() end,
    }
    -- With Combat Spell Dragging the key also clicks the game's own spellbook
    -- button, which opens and closes the game's book lending its buttons.
    local client = { open = false, clicks = 0 }
    env.SpellbookMicroButton = Frame("Button", env.UIParent)
    env.SpellbookMicroButton:SetScript("OnClick", function()
        client.clicks = client.clicks + 1
        client.open = not client.open
    end)

    local settings = { enabled = true, trainingGuide = true }
    local options = {}
    local ns = { db = {}, modules = {} }
    if not drag then ns.db.spellDrag = false end -- unset means on, as in a fresh install
    function ns.RegisterModule(key, mod) mod.key = key; ns.modules[#ns.modules + 1] = mod end
    function ns.SetTex(tex, key) tex.art = key end
    function ns.SetButtonTex(btn, kind) btn:Texture(kind) end
    function ns.RegisterClassicWindow() end
    function ns.SkinCloseButton() end
    function ns.RefreshMicroButtons() end
    function ns.Persist() end
    function ns.SafeCall(fn, ...) fn(...); return true end
    function ns.HidePanel(frame) frame:Hide() end
    local E = { Classic = ns, modules = {} }
    function E:RegisterModule(name, mod) self.modules[name] = mod end
    function E:GetSetting(key) return settings[key] end
    function E:SaveSettings() end
    E.ClassTools = {
        Options = function() return options end,
        Known = function() return false end,
        Skin = function() end,
        Text = function(parent, text) local fs = Frame("FontString", parent); fs.text = text; return fs end,
        Spell = function() return nil end,
    }
    assert(loadfile("Modules/TrainingGuide.lua", "t", env))("EraUI", E)
    assert(loadfile("Classic/SpellBook.lua", "t", env))("EraUI", E)
    E.modules.TrainingGuide:Initialize()
    for _, mod in ipairs(ns.modules) do if mod.key == "spellBook" then mod.init(); mod.apply() end end
    Tick()

    local s = { env = env, client = client, casts = casts, settings = settings, frames = frames }
    function s.Book() return env.EraUIClassicSpellBook end
    function s.Layer() return env.EraUIClassicSpellBookClicks end
    function s.Guide() return env.EraUITrainingGuide end
    function s.Open() local b = s.Book(); return b:IsShown() and b:GetAlpha() > 0 end
    -- The page holder: the one plain frame on the click layer.
    function s.Holder()
        for _, child in ipairs(s.Layer().children) do
            if child.kind == "Frame" and not child.secure then return child end
        end
    end
    -- Secure buttons a mouse click would reach on the spell pages: the spells,
    -- page arrows and tab pads under the holder.
    function s.LivePages()
        local n = 0
        local function Walk(f)
            for _, child in ipairs(f.children) do
                if child.secure and child.mouse ~= false and (child.attrs.type or child.attrs.type1)
                    and child:IsVisible() then n = n + 1 end
                Walk(child)
            end
        end
        Walk(s.Holder())
        return n
    end
    function s.LiveSpells()
        local n = 0
        for _, f in ipairs(frames) do
            if f.secure and f.attrs.type1 == "spell" and f.mouse ~= false and f:IsVisible() then n = n + 1 end
        end
        return n
    end
    function s.Press(key)
        local b = bindings[key]
        assert(b, "nothing bound to " .. key)
        env[b.name]:Click(b.button, true)
        env[b.name]:Click(b.button, false)
        Tick()
    end
    function s.Click(frame)
        frame:Click("LeftButton", false)
        Tick()
    end
    function s.EnterCombat()
        FireEvent("PLAYER_REGEN_DISABLED") -- lockdown starts just after this event
        combat = true
        Tick()
    end
    function s.LeaveCombat()
        combat = false
        FireEvent("PLAYER_REGEN_ENABLED")
        Tick()
    end
    s.Tick = Tick
    return s
end

for _, drag in ipairs({ true, false }) do
    local how = drag and " (spell dragging)" or " (no spell dragging)"
    local s = Session(drag)
    local book, layer = s.Book(), s.Layer()
    Equal(book ~= nil and layer ~= nil, true, "book and click layer built at login" .. how)
    Equal(s.env.EraUIClassicSpellBookBind.attrs.type, drag and "macro" or "click", "key button wired" .. how)
    Equal(layer.attrs.type ~= nil and layer.attrs.unit, "none", "click layer linked and down while closed" .. how)
    Equal(s.Open(), false, "book starts closed" .. how)

    -- The normal spell pages: P opens, P closes, P opens.
    s.Press("P")
    Equal(s.Open(), true, "P opens the book" .. how)
    Equal(layer.attrs.unit .. " " .. tostring(layer:IsShown()), "player true", "open book raises the click layer" .. how)
    Equal(s.LiveSpells() > 0, true, "spells on the page can be clicked" .. how)
    s.Press("P")
    Equal(s.Open(), false, "P closes the book" .. how)
    Equal(layer.attrs.unit .. " " .. tostring(layer:IsShown()), "none false", "closed book lowers the click layer" .. how)
    s.Press("P")
    Equal(s.Open(), true, "P opens the book again" .. how)

    -- The Training Guide tab.
    s.Click(book.TrainTab)
    Equal(book.trainingShown, true, "Training Guide tab selected" .. how)
    Equal(s.Guide():IsShown(), true, "guide shown in the book" .. how)
    Equal(layer.attrs.unit .. " " .. tostring(layer:IsShown()), "none false", "guide keeps the click layer down" .. how)
    Equal(s.LiveSpells(), 0, "no spell can be clicked through the guide" .. how)
    s.Press("P")
    Equal(s.Open(), false, "P closes the book from the Training Guide" .. how)
    Equal(layer.attrs.unit .. " " .. tostring(layer:IsShown()), "none false", "and leaves the click layer down" .. how)
    s.Press("P")
    Equal(s.Open(), true, "P opens the book again" .. how)
    Equal(book.trainingShown and s.Guide():IsVisible(), true, "still on the Training Guide" .. how)
    Equal(layer.attrs.unit .. " " .. tostring(layer:IsShown()), "none false", "reopened guide keeps the layer down" .. how)
    Equal(s.LiveSpells(), 0, "nothing clickable through the reopened guide" .. how)
    s.Press("P")
    Equal(s.Open(), false, "P closes it again" .. how)
    if drag then
        Equal(s.client.open, false, "the game's own book closes with it, so dragging stays in step")
    end
    s.Press("P")
    Equal(s.Open(), true, "and opens it again" .. how)
    if drag then Equal(s.client.open, true, "the game's own book opens with it") end

    -- Back to the spells from a class tab: normal behaviour returns.
    s.Click(book.SkillTabs[1])
    Equal(book.trainingShown, false, "class tab leaves the guide" .. how)
    Equal(s.Guide():IsShown(), false, "guide hidden" .. how)
    Equal(layer.attrs.unit .. " " .. tostring(layer:IsShown()), "player true", "click layer back up" .. how)
    Equal(s.LiveSpells() > 0, true, "spells clickable again" .. how)
    s.Press("P")
    Equal(s.Open(), false, "P closes the spell pages" .. how)
    s.Press("P")
    Equal(s.Open(), true, "P opens the spell pages" .. how)
    Equal(s.LiveSpells() > 0, true, "spells clickable after reopening" .. how)

    -- Combat on the spell pages: the existing rules, unchanged.
    s.EnterCombat()
    s.Press("P")
    Equal(s.Open(), false, "P closes the spell pages in combat" .. how)
    Equal(layer.attrs.unit, "none", "click layer down in combat" .. how)
    Equal(s.LiveSpells(), 0, "nothing clickable on the closed book in combat" .. how)
    s.Press("P")
    Equal(s.Open(), true, "P opens the spell pages in combat" .. how)
    Equal(s.LiveSpells() > 0, true, "spells clickable in combat" .. how)
    s.LeaveCombat()
    Equal(s.Open(), true, "book stays open after combat" .. how)
    Equal(layer.attrs.unit .. " " .. tostring(layer:IsShown()), "player true", "layer up after combat" .. how)

    -- Combat with the Training Guide already open (it can't be opened in
    -- combat). Closing follows the existing combat rules: the first press
    -- raises the secure layer (addon code can't lower it in combat), the next
    -- closes. Nothing may become clickable through the guide meanwhile.
    s.Click(book.TrainTab)
    Equal(book.trainingShown, true, "guide open before the fight" .. how)
    s.EnterCombat()
    Equal(s.LivePages(), 0, "no spell page clickable through the guide as the fight starts" .. how)
    s.Click(book.SkillTabs[1])
    Equal(book.trainingShown, true, "class tab can't leave the guide in combat" .. how)
    s.Press("P")
    Equal(layer.attrs.unit, "player", "first press in combat raises the layer, as before" .. how)
    Equal(s.Open(), true, "and the book stays open, as before" .. how)
    Equal(s.Guide():IsVisible(), true, "guide still shown" .. how)
    Equal(s.LivePages(), 0, "no spell, page arrow or tab pad clickable through the guide in combat" .. how)
    Equal(s.LiveSpells(), 0, "no spell clickable through the guide in combat" .. how)
    s.Press("P")
    Equal(s.Open(), false, "second press closes the book in combat" .. how)
    Equal(layer.attrs.unit, "none", "layer down" .. how)
    s.Press("P")
    Equal(s.Open(), true, "P reopens it in combat, on the guide" .. how)
    Equal(book.trainingShown and s.Guide():IsVisible(), true, "reopened on the guide" .. how)
    Equal(s.LivePages(), 0, "still nothing clickable through the guide" .. how)
    s.Press("P")
    Equal(s.Open(), false, "closed again in combat" .. how)
    s.LeaveCombat()
    Equal(s.Open(), false, "book stays closed after combat" .. how)
    Equal(layer.attrs.unit .. " " .. tostring(layer:IsShown()), "none false", "layer down after combat" .. how)
    s.Press("P")
    Equal(s.Open(), true, "P opens it after combat, on the guide" .. how)
    Equal(book.trainingShown, true, "guide kept" .. how)
    Equal(layer.attrs.unit .. " " .. tostring(layer:IsShown()), "none false", "layer down on the guide" .. how)
    s.Press("P")
    Equal(s.Open(), false, "and P closes it" .. how)

    -- A fight that starts with the book closed on the guide: P opens it in
    -- combat with the layer up, still with nothing clickable through the guide.
    s.EnterCombat()
    s.Press("P")
    Equal(s.Open(), true, "P opens the closed guide in combat" .. how)
    Equal(s.LivePages(), 0, "nothing clickable through the guide opened in combat" .. how)
    s.Press("P")
    Equal(s.Open(), false, "P closes it in combat" .. how)
    s.LeaveCombat()

    -- The guide left out of combat: the spell pages work again.
    s.Press("P")
    s.Click(book.SkillTabs[2])
    Equal(book.trainingShown, false, "guide left after the fight" .. how)
    Equal(s.LivePages() > 0 and s.LiveSpells() > 0, true, "spell pages clickable again" .. how)
    s.EnterCombat()
    Equal(s.LiveSpells() > 0, true, "and in the next fight" .. how)
    s.LeaveCombat()
    s.Press("P")
    Equal(s.Open(), false, "P closes the spell pages at the end" .. how)
end

-- Shift-click a spell to link it in chat. Forever's chat code is ChatFrameUtil;
-- ChatEdit_InsertLink is only a deprecated copy the game loads while its
-- fallbacks are on (Blizzard_DeprecatedChatInfo), so a link must not need it.
do
    local s = Session(false)
    local env = s.env
    s.Press("P")
    local spell
    for _, f in ipairs(s.frames) do
        if f.secure and f.slot and f.scripts.PostClick and f:IsVisible() then spell = f; break end
    end
    Equal(spell ~= nil, true, "a spell on the open page")
    local link = "|cff71d5ff|Hspell:" .. (1000 + spell.slot) .. "|h[Spell " .. spell.slot .. "]|h|r"
    env.C_SpellBook.GetSpellBookItemLink = function(slot) return "|cff71d5ff|Hspell:" .. (1000 + slot) .. "|h[Spell " .. slot .. "]|h|r" end
    local shift = true
    env.IsModifiedClick = function(action) return shift and action == "CHATLINK" end
    -- new: ChatFrameUtil.InsertLink (Forever), old: ChatEdit_InsertLink.
    local function ShiftClick(new, old, label)
        local got = {}
        env.ChatFrameUtil = new and { InsertLink = function(text) got[#got + 1] = "new " .. text; return true end } or nil
        env.ChatEdit_InsertLink = old and function(text) got[#got + 1] = "old " .. text end or nil
        local ok, err = pcall(s.Click, spell)
        Equal(ok, true, label .. ": shift-clicking a spell is not an error (" .. tostring(err) .. ")")
        return table.concat(got, ", ")
    end
    Equal(ShiftClick(true, false, "Forever"), "new " .. link, "Forever: the spell's link goes to chat through ChatFrameUtil")
    Equal(ShiftClick(false, true, "old client"), "old " .. link, "old client: through ChatEdit_InsertLink")
    Equal(ShiftClick(true, true, "both"), "new " .. link, "both: ChatFrameUtil only")
    Equal(ShiftClick(false, false, "neither"), "", "neither: no link, no error")
    shift = false
    Equal(ShiftClick(true, true, "plain click"), "", "a plain click links nothing")
    env.ChatFrameUtil, env.ChatEdit_InsertLink = nil, nil
end

print("Spellbook key checks passed: " .. checks .. " assertions.")
