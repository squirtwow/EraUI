-- Combat Spell Dragging (EraUIClassicDB spellDrag, from /era's "Combat Spell
-- Dragging", off unless chosen; experimental). The game only lets a spell
-- onto the cursor in a fight from its own spellbook buttons, so with this on
-- the key button's click also opens the game's own spellbook (a /click of
-- the spellbook micro button), which EraUI makes invisible and moves off
-- the screen, and its spell buttons are lent: laid invisibly over EraUI's
-- slots, so a drag on a slot is a drag on the game's own button.
--   * only a book the key button opened is lent and quieted; the game's
--     spellbook opened by its own key (or anything else) is left alone, and
--     EraUI's book closes for it (out of a fight);
--   * every lent button is handed back as it was (parent, alpha, strata,
--     scale, anchors) when it isn't needed;
--   * only buttons whose slot fields are the game's own (not written by an
--     addon) are lent, and a button the game guards is never moved in a
--     fight.
local _, EraUI = ...
local Look = EraUI.Look
local S = Look.Spells

local lent = Look.Weak()     -- the game's spell item: { parent, alpha, strata, scale, points, dx, dy }
local muted = Look.Weak()    -- the game's frame whose mouse EraUI turned off
local kept = {}              -- the game's spellbook window as it was (its layout width and first anchor)

function S.DragOn()
    return S.active == true and Look.Saved().spellDrag == true
end

---------------------------------------------------------------------------
-- Handing back
---------------------------------------------------------------------------

local function Movable(item)
    return not (Look.InFight() and item:IsProtected())
end

local function GiveBack(item)
    local was = lent[item]
    if not was or not Movable(item) then return end
    lent[item] = nil
    item:SetParent(was.parent)
    item:SetAlpha(was.alpha)
    item:SetFrameStrata(was.strata)
    item:SetScale(was.scale)
    item:ClearAllPoints()
    for _, point in ipairs(was.points) do item:SetPoint(point[1], point[2], point[3], point[4], point[5]) end
end

function S.HandBack()
    for item in pairs(lent) do GiveBack(item) end
end

-- The mouse given back to every frame EraUI turned it off on (out of a
-- fight), and the window back where the game had it.
function S.GiveMouse()
    if Look.InFight() then return end
    for frame in pairs(muted) do
        muted[frame] = nil
        frame:EnableMouse(true)
    end
    local frame = PlayerSpellsFrame
    if frame and kept.width ~= nil then
        frame:SetAttribute("UIPanelLayout-width", kept.width)
        kept.width = nil
    end
    if frame and kept.point then
        local p = kept.point
        frame:ClearAllPoints()
        frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
        kept.point = nil
    end
end

---------------------------------------------------------------------------
-- Quieting the game's window
---------------------------------------------------------------------------

local function Mute(frame, spared)
    if frame == spared or (frame.IsForbidden and frame:IsForbidden()) then return end
    if frame:IsMouseEnabled() then
        muted[frame] = true
        frame:EnableMouse(false)
    end
    for _, child in ipairs({ frame:GetChildren() }) do Mute(child, spared) end
end

local lastMute = -1
local function Quiet(frame, page)
    frame:SetAlpha(0)
    if Look.InFight() then return end
    local now = type(GetTime) == "function" and GetTime() or 0
    if now - lastMute >= 0.3 then
        lastMute = now
        Look.Try(Mute, frame, page.PagedSpellsFrame)
    end
    local width = frame:GetAttribute("UIPanelLayout-width")
    if width ~= 1 then
        if kept.width == nil then kept.width = width or false end
        frame:SetAttribute("UIPanelLayout-width", 1)
    end
    local point, relative, relativePoint, x = frame:GetPoint(1)
    if not (point == "TOPLEFT" and relative == UIParent and relativePoint == "TOPRIGHT" and x == 4000) then
        if not kept.point and point then kept.point = { frame:GetPoint(1) } end
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPRIGHT", 4000, 0)
    end
end

---------------------------------------------------------------------------
-- Lending
---------------------------------------------------------------------------

local lastLine
local function Note(line)
    if line ~= lastLine then
        lastLine = line
        S.Note("spellbook: " .. line)
    end
end

-- A field the game itself wrote (never one an addon set).
local function GameOwned(item, key)
    return type(issecurevariable) == "function" and issecurevariable(item, key) == true
end

-- The game's built spell items, keyed "bank:slot"; only those whose slot
-- fields are the game's own.
local function Items(page)
    local found, total, marked = {}, 0, 0
    local paged = page.PagedSpellsFrame
    if not paged or type(paged.EnumerateFrames) ~= "function" then return found end
    for _, item in paged:EnumerateFrames() do
        local valid = type(item.HasValidData) == "function" and item:HasValidData()
        if valid and item.Button and item.slotIndex ~= nil then
            total = total + 1
            if GameOwned(item, "slotIndex") and GameOwned(item, "spellBank") then
                found[tostring(item.spellBank) .. ":" .. tostring(item.slotIndex)] = item
            else
                marked = marked + 1
            end
        end
    end
    if total > 0 and next(found) == nil then Note(total .. " spell items, " .. marked .. " marked by an addon: none lent") end
    return found
end

local function Width(frame)
    return (Look.Number(frame:GetWidth()) or 0) * (Look.Number(frame:GetEffectiveScale()) or 1)
end

-- One item laid over a display button: parented to the screen, invisible,
-- above everything, scaled to the same size, its button over the slot.
local function Borrow(item, button)
    if not Movable(item) then return end
    local was = lent[item]
    if not was then
        local points = {}
        for i = 1, item:GetNumPoints() do points[i] = { item:GetPoint(i) } end
        was = { parent = item:GetParent(), alpha = item:GetAlpha(), strata = item:GetFrameStrata(), scale = item:GetScale(),
            points = points, dx = 0, dy = 0 }
        lent[item] = was
        item:SetFrameStrata("FULLSCREEN_DIALOG")
        item:SetParent(UIParent)
        item:SetAlpha(0)
        Look.Pin(item, "TOPLEFT", button, "TOPLEFT", 0, 0)
    end
    local want, have = Width(button), Width(item.Button)
    if have > 0 and math.abs(want - have) > 0.5 then item:SetScale((Look.Number(item:GetScale()) or 1) * want / have) end
    local scale = Look.Number(item:GetEffectiveScale()) or 1
    local gapX = ((Look.Number(button:GetLeft()) or 0) * (Look.Number(button:GetEffectiveScale()) or 1)
        - (Look.Number(item.Button:GetLeft()) or 0) * scale)
    local gapY = ((Look.Number(button:GetTop()) or 0) * (Look.Number(button:GetEffectiveScale()) or 1)
        - (Look.Number(item.Button:GetTop()) or 0) * scale)
    if math.abs(gapX) > 0.2 or math.abs(gapY) > 0.2 then
        was.dx, was.dy = was.dx + gapX / scale, was.dy + gapY / scale
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", button, "TOPLEFT", was.dx, was.dy)
    end
end

local function Lend(page)
    local found = Items(page)
    local bank = S.Bank(S.view.pet)
    local using, count = {}, 0
    for _, entry in ipairs(S.slots) do
        local item = entry.slot and entry.button:IsVisible() and found[tostring(bank) .. ":" .. tostring(entry.slot)]
        if item then
            Borrow(item, entry.button)
            using[item] = true
            count = count + 1
        end
    end
    for item in pairs(lent) do
        if not using[item] then GiveBack(item) end
    end
    local total = 0
    for _ in pairs(found) do total = total + 1 end
    Note("lent " .. count .. " of " .. total .. " spells, bank " .. tostring(bank))
end

---------------------------------------------------------------------------
-- The watch (every 0.05 s while the book is on)
---------------------------------------------------------------------------

local function Step()
    if not S.active then return end
    local frame = PlayerSpellsFrame
    if not frame then return end
    if not S.DragOn() or not S.lentOpen then return S.HandBack() end
    frame:SetAlpha(0)
    local page = frame.SpellBookFrame
    local pageUp = page ~= nil and page:IsShown()
    if frame:IsShown() and not pageUp then
        S.HandBack()
        S.GiveMouse()
        frame:SetAlpha(1)
        return
    end
    if not pageUp then return S.HandBack() end
    Quiet(frame, page)
    if not S.dragSeen and not Look.InFight() then
        S.dragSeen = true
        S.BuildPages()
    end
    if S.book and S.book:IsShown() then
        Lend(page)
    else
        S.HandBack()
        if not Look.InFight() then
            S.lentOpen = false
            Look.HidePanel(frame)
        end
    end
end

-- The game's tab for a line (or "pet") clicked by a named helper of its own,
-- so the game's book shows the same spells as EraUI's. nil when dragging is
-- off or the game's book isn't there.
local tabHelpers = {}
local function GameTab(which)
    local page = PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame
    local categories = page and page.categoryMixins
    local tabs = page and page.CategoryTabSystem
    if type(categories) ~= "table" or not tabs then return nil end
    local line = which ~= "pet" and S.Lines()[which]
    for _, category in ipairs(categories) do
        local fine, bank = Look.Ask(category, "GetSpellBank")
        local match
        if which == "pet" then
            match = fine and bank == S.Bank(true)
        elseif line and fine and bank == S.Bank(false) then
            local asked, holds = Look.Ask(category, "ContainsSkillLine", line.index)
            match = (asked and holds == true) or rawget(category, "skillLineIndex") == line.index
        end
        if match then
            local okId, id = Look.Ask(category, "GetTabID")
            local okTab, tab = Look.Ask(tabs, "GetTabButton", okId and id or nil)
            return okTab and tab or nil
        end
    end
    return nil
end

function S.ClientTab(which)
    if not S.DragOn() or Look.InFight() then return nil end
    local tab = GameTab(which)
    if not tab then return nil end
    local name = "EraUISpellBookGameTab" .. tostring(which)
    local helper = tabHelpers[name]
    if not helper then
        helper = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
        helper:SetSize(1, 1)
        Look.Pin(helper, "TOPLEFT", UIParent, "TOPLEFT", -500, 500)
        helper:EnableMouse(false)
        helper:RegisterForClicks("AnyUp", "AnyDown")
        helper:SetAttribute("useOnKeyDown", false)
        helper:SetAttribute("type", "click")
        tabHelpers[name] = helper
    end
    helper:SetAttribute("clickbutton", tab)
    return name
end

-- The game's spellbook opening: lent only when the key button's own click
-- opened it; anything else (the game's key) is the player's, and EraUI's
-- book makes way for it (out of a fight).
local function GameBookShown(window)
    S.lentOpen = S.keyClicking == true and S.DragOn()
    if S.lentOpen or not S.active then return end
    -- The player's own: seen where the game put it, with its mouse.
    S.HandBack()
    S.GiveMouse()
    window:SetAlpha(1)
    if S.Open and S.Open() and not Look.InFight() then S.Hide() end
end

function S.WatchGameBook()
    local frame = PlayerSpellsFrame
    -- Run inside the game's own opening of its window: an error of EraUI's
    -- goes to the error handler and never stops the game's.
    if frame then Look.HookScript(frame, "OnShow", function(window) Look.Try(GameBookShown, window) end, "spells") end
end

local started = false
function S.StartDragWatch()
    if started then return end
    started = true
    -- The shared ticker runs it protected and reports a failing step once
    -- (never twenty times a second).
    Look.Every(0.05, function() Step() end)
    local loads = CreateFrame("Frame")
    Look.Listen(loads, "ADDON_LOADED")
    loads:SetScript("OnEvent", function(_, _, addon)
        if addon == "Blizzard_PlayerSpells" and S.active then S.WatchGameBook() end
    end)
end

-- Off: every lent button back, the mouse back, the window seen again.
function S.DragRestore()
    S.HandBack()
    S.GiveMouse()
    S.lentOpen = false
    if PlayerSpellsFrame then PlayerSpellsFrame:SetAlpha(1) end
end
