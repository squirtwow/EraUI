-- Opening and closing the classic spellbook, and keeping it in step:
--   * show, hide and toggle, by the rules the secure layer needs in a fight
--     (a book held open by its layer stays; a book the game guards fades);
--   * the key button's release (the micro button's pad clicks it, and so
--     does a key the player sets on Classic Spellbook);
--   * the fight's start and end, and the book's events;
--   * Escape (the game's own list, through the engine's stand-in), the game
--     menu, and the shared window manager (the layer follows the book; in a
--     fight with the layer up the book keeps its place).
-- EraUI changes no key binding: the game's spellbook key opens the game's
-- own spellbook. A key the player sets on Classic Spellbook (the game's Key
-- Bindings, AddOns section: Bindings.xml) clicks the key button.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Spells

local function Faded()
    return (Look.Number(S.book:GetAlpha()) or 1) <= 0
end

local function Open()
    return S.book ~= nil and S.book:IsShown() and not Faded()
end
S.Open = Open

-- Everything made once, out of a fight. Returns the book (nil when it
-- can't be made yet).
function S.Build()
    if S.book then return S.book end
    if Look.InFight() then return nil end
    S.BuildBook()
    S.BuildLayer()
    S.Wire()
    if S.active then S.Link() end
    return S.book
end

---------------------------------------------------------------------------
-- The layer follows the book
---------------------------------------------------------------------------

-- The book's x from the left of the screen (UIParent units).
local function BookX()
    local point, relative, relativePoint, x = S.book:GetPoint(1)
    if point == "TOPLEFT" and relative == UIParent and relativePoint == "TOPLEFT" then return Look.Number(x) end
    local left = Look.Rect(S.book)
    return left
end

local function LayerX()
    local point, _, _, x = S.layer:GetPoint(1)
    return point == "TOPLEFT" and Look.Number(x) or nil
end

-- Out of a fight: the layer to wherever the book is.
function S.FollowBook()
    if not (S.layer and S.book) or Look.InFight() then return end
    local x = BookX()
    if x and x ~= LayerX() then Look.Pin(S.layer, "TOPLEFT", UIParent, "TOPLEFT", x, S.DOWN) end
end

-- After anything places the book: out of a fight the layer follows; in a
-- fight with the layer up the book goes back over it (the layer can't move).
local placing = false
local function Placed()
    if placing or not S.layer then return end
    if not Look.InFight() then return S.FollowBook() end
    if not S.LayerUp() then return end
    local held, x = LayerX(), BookX()
    if held and x and math.abs(held - x) > 0.5 then
        placing = true
        Look.Pin(S.book, "TOPLEFT", UIParent, "TOPLEFT", held, S.DOWN)
        placing = false
    end
end

-- Asked by the window manager: the x the book must keep for now.
local function Hold()
    if Look.InFight() and S.LayerUp() then return LayerX() end
    return nil
end

---------------------------------------------------------------------------
-- Show, hide, toggle
---------------------------------------------------------------------------

-- Out of a fight: the layer up or down (always down while the Training
-- Guide shows, which also keeps every page of the book hidden).
function S.SetLayer(on)
    if not (S.layer and S.book) or Look.InFight() then return end
    if not S.linked then S.Link() end
    local up = on and not S.book.trainingShown
    S.layer:SetAttribute("unit", up and "player" or "none")
    Look.Shown(S.layer, up)
    if S.book.trainingShown then S.ApplyView() end
    S.FollowBook()
end

function S.Show()
    local book = S.Build()
    if not book then return end
    S.closedInFight = false
    book:SetAlpha(1)
    if Look.InFight() and not book:IsShown() and book:IsProtected() then
        S.openAfterFight = true
        return
    end
    book:Show()
    if not Look.InFight() then S.SetLayer(true) end
end

function S.Hide()
    local book = S.book
    if not book then return end
    S.openAfterFight = false
    local fight = Look.InFight()
    if fight and S.LayerUp() and book:IsShown() then return end
    if not fight then S.SetLayer(false) end
    if fight and book:IsProtected() then
        book:SetAlpha(0)
        S.closedInFight = true
    else
        book:SetAlpha(1)
        book:Hide()
    end
end

function S.Toggle()
    if Open() then S.Hide() else S.Show() end
end

local function Follow()
    if S.escapeFollow then S.escapeFollow() end
end

-- The key button released (only while the book is on): open or close as
-- the layer now says. From the Training Guide out of a fight the press
-- closes the book (the guide kept the layer down, so the press raised it).
function S.KeyPressed()
    if not S.active then return end
    local spells = S.DragOn() and PlayerSpellsFrame
    if spells and S.lentOpen then spells:SetAlpha(0) end
    local book = S.Build()
    if not book then return end
    if not S.linked then
        S.Toggle()
    elseif not Look.InFight() and book.trainingShown and Open() then
        S.Hide()
    elseif S.LayerUp() then
        S.Show()
    elseif book:IsShown() then
        S.Hide()
    end
    Follow()
end

---------------------------------------------------------------------------
-- The book's own scripts, its events, Escape, the menu, the manager
---------------------------------------------------------------------------

local function Shown()
    S.Sound("IG_SPELLBOOK_OPEN")
    if not Look.InFight() then S.SetLayer(true) end
    if type(ns.RefreshMicroButtons) == "function" then Look.Try(ns.RefreshMicroButtons) end
    S.Refresh()
    Follow()
end

local function Hidden()
    S.Sound("IG_SPELLBOOK_CLOSE")
    Look.HideTip()
    if Look.InFight() then
        -- Still held open by the layer: the art comes back next frame.
        if S.LayerUp() then
            S.NextFrame(function()
                if Look.InFight() and S.LayerUp() and not S.book:IsShown() then S.book:Show() end
            end)
        end
    else
        S.SetLayer(false)
    end
    if type(ns.RefreshMicroButtons) == "function" then Look.Try(ns.RefreshMicroButtons) end
    Follow()
end

-- Just before the lockdown: a book that isn't open drops its layer.
local function FightStarts()
    if S.book and not Open() then S.SetLayer(false) end
    if S.book and S.book:IsShown() then S.Refresh() end
    Follow()
end

local function FightEnds()
    local book = S.book
    if book then
        if S.closedInFight then
            S.closedInFight = false
            book:SetAlpha(1)
            book:Hide()
            S.SetLayer(false)
        elseif S.openAfterFight then
            S.openAfterFight = false
            S.Show()
        else
            S.SetLayer(book:IsShown())
        end
    end
    if S.active then S.Build() end
    if S.layer and not S.linked and S.active then S.Link() end
    if S.dirty then S.BuildPages() end
    S.FollowBook()
    if book and book:IsShown() then S.Refresh() end
    Follow()
end

-- The rest of the book's events: pages rebuilt and the book redrawn 0.1 s
-- later, once for a burst.
local queued = false
local function Rebuild()
    queued = false
    if S.dirty and not Look.InFight() then S.BuildPages() end
    if S.book and S.book:IsShown() then S.Refresh() end
end

local function Later(keepOnly)
    if not keepOnly then S.dirty = true end
    if queued then return end
    queued = true
    if C_Timer and C_Timer.After then C_Timer.After(0.1, Rebuild) else Rebuild() end
end

local LATER = Look.Words("SPELLS_CHANGED LEARNED_SPELL_IN_TAB LEARNED_SPELL_IN_SKILL_LINE PET_BAR_UPDATE PLAYER_ENTERING_WORLD UNIT_PET")

local function OnEvent(_, event)
    if not S.active then return end
    if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_USABLE" then
        S.Cooldowns()
    elseif event == "PLAYER_REGEN_DISABLED" then
        FightStarts()
    elseif event == "PLAYER_REGEN_ENABLED" then
        FightEnds()
        Later(true)
    else
        Later(false)
    end
end

local function Listener()
    local listener = Look.Build("Frame", S.book, nil, { size = { 1, 1 } })
    for _, event in ipairs(LATER) do
        if event == "UNIT_PET" then Look.Listen(listener, event, "player") else Look.Listen(listener, event) end
    end
    for _, event in ipairs(Look.Words("SPELL_UPDATE_COOLDOWN SPELL_UPDATE_USABLE PLAYER_REGEN_ENABLED PLAYER_REGEN_DISABLED")) do
        Look.Listen(listener, event)
    end
    listener:SetScript("OnEvent", OnEvent)
    -- The listener sits on the book, which may be hidden: events still come.
    S.listener = listener
end

-- Held for Escape: faded out, or held open by the layer (in a fight).
local function Held()
    return Faded() or S.LayerUp()
end

-- Everything that comes with the book, once, as it is made.
function S.Wire()
    local book = S.book
    book:SetScript("OnShow", Shown)
    book:SetScript("OnHide", Hidden)
    Listener()
    Look.Hook(book, "SetPoint", Placed)
    Look.WindowTraits(book, { width = 392, hold = Hold, placed = function() S.FollowBook() end })
    if type(ns.RegisterClassicWindow) == "function" then Look.Try(ns.RegisterClassicWindow, book, true) end
    if type(ns.CloseOnEscape) == "function" then
        local follow = ns.CloseOnEscape(book, S.Hide, Held)
        if type(follow) == "function" then S.escapeFollow = follow end
    end
    if GameMenuFrame then
        Look.HookScript(GameMenuFrame, "OnShow", function()
            if S.active and not Look.InFight() and S.book:IsShown() then S.Hide() end
        end, "spells")
    end
end

-- Asked at apply (when logged in), after a fight and on entering the
-- world: everything made ahead, so it exists before any fight.
function S.Prebuild()
    if not S.active or Look.InFight() then return end
    if type(IsLoggedIn) == "function" and not IsLoggedIn() then return end
    S.Build()
    S.Link()
end
