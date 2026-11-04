-- The classic spellbook's registry entries and the names other files call:
--   * "spellBook" (from /era's Classic Spellbook, a reload setting): the
--     book, made at login out of a fight; its micro button's secure pad
--     (the micro button opens EraUI's book, in a fight too); the game menu;
--     Combat Spell Dragging's watch. EraUI changes no key binding: the
--     game's spellbook key opens the game's own spellbook; a key the player
--     sets on Classic Spellbook (Bindings.xml) opens EraUI's.
--   * "spellBookTopRank": the pages listed again when "Show all spell
--     ranks" changes (the setting or the game's own switch).
--   * "spellBookSearch": the book's search box shown, or emptied and hidden.
-- A pass runs every apply again; every restore is cheap and safe to repeat.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Spells

-- The Classic settings this area reads, with their defaults (only where
-- the engine has none of its own).
do
    local engine = type(ns.DB_DEFAULTS) == "table" and ns.DB_DEFAULTS or nil
    if engine then
        for key, value in pairs({ spellBook = true, spellBookSearch = true, spellBookTopRank = false }) do
            if engine[key] == nil then engine[key] = value end
        end
    end
end

local function QuickBinding()
    local check = KeybindFrames_InQuickKeybindMode
    if type(check) ~= "function" then return false end
    local fine, binding = pcall(check)
    return fine and not Look.Secret(binding) and binding == true
end

-- The micro button's pad shows while the book is on, and steps aside while
-- the player binds keys with the game's quick keybind mode.
local function PadWanted()
    return S.active == true and S.key ~= nil and not QuickBinding()
end

local function BookOpen()
    return S.Open ~= nil and S.Open() and true or false
end

-- The pad over the spellbook micro button (clicks the key button), and the
-- pressed look of the book's micro buttons following the book (once).
local pressedFollows = false
local MICRO = Look.Words("SpellbookMicroButton PlayerSpellsMicroButton")
local function MicroButtons()
    local micro = _G.SpellbookMicroButton
    if micro and S.key and type(ns.MapPad) == "function" then ns.MapPad(micro, nil, nil, S.key, PadWanted) end
    if pressedFollows or type(ns.MicroButtonFollows) ~= "function" then return end
    pressedFollows = true
    for _, called in ipairs(MICRO) do
        if _G[called] then ns.MicroButtonFollows(_G[called], BookOpen) end
    end
end

---------------------------------------------------------------------------
-- spellBook
---------------------------------------------------------------------------

local function AtLogin()
    S.active = true
    S.Prebuild()
end

local function SpellBookOn()
    S.active = true
    local db = ns.db
    if db and db.spellBookPos ~= nil then db.spellBookPos = nil end -- legacy, read by nothing
    S.Prebuild()
    MicroButtons()
    S.StartDragWatch()
    S.WatchGameBook()
end

local function SpellBookOff()
    if S.book and S.book:IsShown() then S.Hide() end
    S.active = false
    S.DragRestore()
end

ns.RegisterModule("spellBook", { init = AtLogin, apply = SpellBookOn, restore = SpellBookOff })

-- Entering the world and every fight's end: made ahead while the book is on.
do
    local ahead = CreateFrame("Frame")
    Look.Listen(ahead, "PLAYER_ENTERING_WORLD")
    Look.Listen(ahead, "PLAYER_REGEN_ENABLED")
    ahead:SetScript("OnEvent", function() S.Prebuild() end)
end

---------------------------------------------------------------------------
-- spellBookTopRank and spellBookSearch
---------------------------------------------------------------------------

-- Listed again only when the rule really changed (the setting or the
-- game's switch it follows), then at once.
local function ListAgain()
    local topOnly = S.TopRankOn()
    if S.listedTopRank == topOnly then return end
    S.listedTopRank = topOnly
    S.dirty = true
    if not Look.InFight() then S.BuildPages() end
    if S.book and S.book:IsShown() then S.Refresh() end
end

ns.RegisterModule("spellBookTopRank", { apply = ListAgain, restore = ListAgain })

local function SearchBox()
    return S.book and S.book.Search or nil
end

ns.RegisterModule("spellBookSearch", {
    apply = function()
        local box = SearchBox()
        if box and not S.book.trainingShown then Look.Shown(box, true) end
    end,
    restore = function()
        local box = SearchBox()
        if box == nil then return end
        if (box:GetText() or "") ~= "" then box:SetText("") end
        Look.Shown(box, false)
    end,
})

---------------------------------------------------------------------------
-- What other files call
---------------------------------------------------------------------------

ns.SpellBookActive = function() return S.active == true end
ns.SpellBookPetTitle = function() return S.PetTitle() end
ns.HideSpellBook = function() S.Hide() end

-- The book on the player's (or the pet's) pages; false while it is off.
ns.ShowSpellBookBank = function(isPet)
    if not S.active then return false end
    S.SetView(isPet and true or false, S.view.line, S.view.search)
    S.Show()
    S.Refresh()
    return true
end

-- Opens or closes the book (false while it is off).
ns.ToggleSpellBook = function()
    if not S.active then return false end
    S.Toggle()
    return true
end

-- For the debug report: the game's own spellbook keys (they open the
-- game's book; EraUI binds none) and the book's state.
ns.SpellBookBindInfo = function()
    local found = {}
    for _, command in ipairs({ "TOGGLESPELLBOOK", "TOGGLEPLAYERSPELLS" }) do
        local keys = type(GetBindingKey) == "function" and { GetBindingKey(command) } or {}
        for _, key in ipairs(keys) do
            if type(key) == "string" and not Look.Secret(key) then found[#found + 1] = command .. "=" .. key end
        end
    end
    local made = S.book ~= nil
    return ("keys <%s> (the game's own spellbook); book built %s; book protected %s"):format(table.concat(found, ", "),
        tostring(made), tostring(made and S.book:IsProtected() == true))
end
