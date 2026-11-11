-- The spell windows' shared kit (Classic look, area "spells"): what the
-- classic spellbook keeps between its files (Look.Spells), its 1.x art by
-- key, careful readers of the game's spellbook, the rules for what a page
-- lists, and the two tab makers other windows borrow:
--   * ns.NewSideTab: a tab down the right edge (the spellbook's schools; the
--     group finder and social windows use it too);
--   * ns.NewBookTab: a tab along the bottom (Spellbook, Professions, pet).
-- Nothing here touches the game's frames.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local S = {
    slots = {},        -- 1..12: { frame, icon, ring, glow, name, sub, cooldown, shade, button, slot, passive }
    skillTabs = {},    -- the eight school tabs
    bookTabs = {},     -- the three book tabs
    pageOf = {},       -- list key: the page it was left on (this session)
    view = { pet = false, line = 1, search = "" },
    page = 1,
}
Look.Spells = S

S.PER_PAGE = 12
S.WIDTH, S.HEIGHT, S.DOWN = 384, 512, -104
S.SLOT = 37

-- Where slot i sits on the book: two columns of six, 157 apart, rows 51 apart.
function S.SlotSpot(i)
    local column, row = math.floor((i - 1) / 6), (i - 1) % 6
    return 34 + column * 157, -85 - row * 51
end

---------------------------------------------------------------------------
-- Art
---------------------------------------------------------------------------

do
    local BOOK, BUTTONS = "Interface\\Spellbook\\", "Interface\\Buttons\\"
    local define = Look.DefineArt
    for _, corner in ipairs({ "TopLeft", "TopRight", "BotLeft", "BotRight" }) do
        define("sb" .. corner, BOOK .. "UI-SpellbookPanel-" .. corner, "UI-SpellbookPanel-" .. corner)
    end
    define("sbIcon", BOOK .. "Spellbook-Icon", "SpellBook-Icon")
    define("sbSkillTab", BOOK .. "SpellBook-SkillLineTab", "SpellBook-SkillLineTab")
    define("sbEmptySlot", BOOK .. "UI-Spellbook-SpellBackground", "UI-SpellBook-SpellBackground")
    for key, file in pairs({ sbTabUnselected = "UI-SpellBook-Tab-Unselected", sbTab1Selected = "UI-SpellBook-Tab1-Selected",
        sbTab3Selected = "UI-SpellBook-Tab3-Selected", sbTabHighlight = "UI-SpellbookPanel-Tab-Highlight" }) do
        define(key, BOOK .. file, file)
    end
    for _, way in ipairs({ "Prev", "Next" }) do
        for _, look in ipairs({ "Up", "Down", "Disabled" }) do
            local file = "UI-SpellbookIcon-" .. way .. "Page-" .. look
            define("sb" .. way .. look, BUTTONS .. file, file)
        end
    end
    define("mouseHighlight", BUTTONS .. "UI-Common-MouseHilight", "UI-Common-MouseHilight")
    define("skillsBar", nil, "UI-Character-Skills-Bar", nil, true)
    define("skillsBarBorder", nil, "UI-Character-Skills-BarBorder", "skillsBarBorder", true)
end

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

-- A readable true (a secret, or anything else, is not).
function S.Yes(value)
    return not Look.Secret(value) and value == true
end

-- Readable text, or nil.
function S.Text(value)
    if Look.Secret(value) or type(value) ~= "string" then return nil end
    return value
end

function S.Say(globalName, fallback)
    local text = _G[globalName]
    if type(text) == "string" and text ~= "" then return text end
    return fallback
end

function S.Sound(name)
    local kit = SOUNDKIT
    if type(PlaySound) == "function" and type(kit) == "table" and kit[name] then pcall(PlaySound, kit[name]) end
end

-- A font object by its global name, else the fallback's.
function S.Font(name, fallback)
    return _G[name] or _G[fallback] or fallback
end

function S.Note(line)
    if type(ns.Persist) == "function" then pcall(ns.Persist, line) end
end

function S.NextFrame(fn)
    if C_Timer and C_Timer.After then C_Timer.After(0, fn) else fn() end
end

---------------------------------------------------------------------------
-- Reading the game's spellbook (every call protected, secrets as missing)
---------------------------------------------------------------------------

local function Call(name, ...)
    local api = C_SpellBook
    local fn = type(api) == "table" and api[name]
    if type(fn) ~= "function" then return nil end
    local fine, first, second = pcall(fn, ...)
    if not fine then return nil end
    return first, second
end
S.Call = Call

function S.Bank(pet)
    local banks = Enum and Enum.SpellBookSpellBank
    if pet then return banks and banks.Pet or 1 end
    return banks and banks.Player or 0
end

-- The spell lines that get a school tab: not hidden, not another
-- specialisation's, in order, at most eight.
function S.Lines()
    local lines = {}
    local count = Look.Number((Call("GetNumSpellBookSkillLines")))
    local last = (count and count > 0) and count or 30
    for index = 1, last do
        local info = Call("GetSpellBookSkillLineInfo", index)
        if type(info) ~= "table" then break end
        local offSpec = Look.Number(info.offSpecID) or 0
        if not S.Yes(info.shouldHide) and offSpec == 0 then
            lines[#lines + 1] = { index = index, name = S.Text(info.name) or "", icon = info.iconID,
                offset = Look.Number(info.itemIndexOffset) or 0, count = Look.Number(info.numSpellBookItems) or 0 }
            if #lines >= 8 then break end
        end
    end
    return lines
end

-- How many pet spells there are (0 when none or unreadable), and the pet
-- family's token.
function S.PetSpells()
    local count, token = Call("HasPetSpells")
    return Look.Number(count) or 0, S.Text(token)
end

function S.PetTitle()
    local count, token = S.PetSpells()
    if count <= 0 then return nil end
    return (token and S.Text(_G["PET_TYPE_" .. token])) or S.Say("PET", "Pet")
end

function S.Info(slot, pet)
    local info = Call("GetSpellBookItemInfo", slot, S.Bank(pet))
    return type(info) == "table" and info or nil
end

-- A future spell or a flyout (left off the player's pages).
local function Skipped(info)
    local kinds = Enum and Enum.SpellBookItemType
    local kind = info.itemType
    if not kinds or Look.Secret(kind) then return false end
    return kind == kinds.FutureSpell or kind == kinds.Flyout
end
S.Skipped = Skipped

---------------------------------------------------------------------------
-- What a page lists (5.6)
---------------------------------------------------------------------------

local function Matches(info, needle)
    for _, field in ipairs({ "name", "subName" }) do
        local text = S.Text(info[field])
        if text and text:lower():find(needle, 1, true) then return true end
    end
    return false
end

-- Only the highest rank of each spell (on a tie, the later one); a slot
-- without a rank number always stays.
local function TopRanks(slots)
    local ranks, best = {}, {}
    for position, slot in ipairs(slots) do
        local info = S.Info(slot, false)
        local name, sub = info and S.Text(info.name), info and S.Text(info.subName)
        local rank = sub and tonumber(sub:match("%d+"))
        if name and rank then
            ranks[position] = { name, rank }
            local held = best[name]
            if not held or rank >= held[1] then best[name] = { rank, position } end
        end
    end
    local kept = {}
    for position, slot in ipairs(slots) do
        local mine = ranks[position]
        if not mine or best[mine[1]][2] == position then kept[#kept + 1] = slot end
    end
    return kept
end

local function LineSlots(line, needle, into)
    for slot = line.offset + 1, line.offset + line.count do
        local info = S.Info(slot, false)
        if info and not Skipped(info) and (not needle or Matches(info, needle)) then into[#into + 1] = slot end
    end
    return into
end

-- A castable, active spell that opens a crafting window.
local function Crafting(info)
    local kinds = Enum and Enum.SpellBookItemType
    if not kinds or Look.Secret(info.itemType) or info.itemType ~= kinds.Spell then return false end
    if S.Yes(info.isPassive) or Look.Secret(info.isPassive) then return false end
    local id = Look.Number(info.spellID)
    local api = C_TradeSkillUI
    local fn = id and type(api) == "table" and api.CanTradeSkillShowCraftingUI
    if type(fn) ~= "function" then return false end
    local fine, yes = pcall(fn, id)
    return fine and S.Yes(yes)
end

-- From the lines without a tab, only their crafting spells (such as a
-- rogue's Poisons); they join the General page and the search. Forever
-- counts only the lines with a tab and keeps Poisons on a line past them
-- (a rogue: four lines counted, Poisons at slot 39 on line 5), so the
-- slots after the counted lines are read too, till the book ends.
local PAST_LINES = 200 -- at most this many slots after the counted lines
-- The five professions the Professions window shows (the game's first
-- five: two main ones, First Aid, Fishing, Cooking): their slots, and their
-- names and their spells' names, for the copies Forever keeps elsewhere
-- past the counted lines (one per profession, under its own name). They
-- have that window, so they stay off General.
local function Professions()
    local skip, names = {}, {}
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then return skip, names end
    local fine, first, second, aid, fish, cook = pcall(GetProfessions)
    if not fine then return skip, names end
    for _, index in pairs({ first, second, aid, fish, cook }) do
        if Look.Number(index) then
            local ok, name, _, _, _, count, offset = pcall(GetProfessionInfo, index)
            name, count, offset = ok and S.Text(name), ok and Look.Number(count), ok and Look.Number(offset)
            if name then names[name] = true end
            if count and offset then
                for slot = offset + 1, offset + count do
                    skip[slot] = true
                    local item = S.Info(slot, false)
                    local spell = item and S.Text(item.name)
                    if spell then names[spell] = true end
                end
            end
        end
    end
    return skip, names
end
local function CraftingSlots(lines, needle, into)
    local shown = {}
    for _, line in ipairs(lines) do shown[line.index] = true end
    local skip, names = Professions()
    local function Take(slot)
        local item = S.Info(slot, false)
        if not item then return false end
        local name = S.Text(item.name)
        if not skip[slot] and not (name and names[name]) and Crafting(item) and (not needle or Matches(item, needle)) then
            into[#into + 1] = slot
        end
        return true
    end
    local count = Look.Number((Call("GetNumSpellBookSkillLines")))
    local last = (count and count > 0) and count or 30
    local finish = 0
    for index = 1, last do
        local info = Call("GetSpellBookSkillLineInfo", index)
        if type(info) ~= "table" then break end
        local offset, size = Look.Number(info.itemIndexOffset), Look.Number(info.numSpellBookItems)
        if offset and size then
            finish = math.max(finish, offset + size)
            if not shown[index] then
                for slot = offset + 1, offset + size do Take(slot) end
            end
        end
    end
    for slot = finish + 1, finish + PAST_LINES do
        if not Take(slot) then break end
    end
    return into
end

-- The slots a view lists: { pet, line (index into S.Lines()), search }.
-- topRank: the highest-rank rule (the player's pages only).
function S.ListFor(view, topRank)
    local needle = view.search ~= "" and view.search:lower() or nil
    local slots = {}
    if view.pet then
        local count = S.PetSpells()
        for slot = 1, count do
            local info = not needle and true or S.Info(slot, true)
            if info == true or (info and Matches(info, needle)) then slots[#slots + 1] = slot end
        end
        return slots
    end
    local lines = S.Lines()
    if needle then
        for _, line in ipairs(lines) do LineSlots(line, needle, slots) end
        CraftingSlots(lines, needle, slots)
    elseif lines[view.line] then
        LineSlots(lines[view.line], nil, slots)
        if view.line == 1 then CraftingSlots(lines, nil, slots) end
    end
    if topRank then slots = TopRanks(slots) end
    return slots
end

function S.PageCount(list)
    return math.max(1, math.ceil(#list / S.PER_PAGE))
end

-- The key a list's page is remembered under.
function S.PageKey(view)
    if view.search ~= "" then return "search" end
    if view.pet then return "pet" end
    return "line" .. tostring(view.line)
end

function S.TopRankOn()
    return Look.Saved().spellBookTopRank == true
end

---------------------------------------------------------------------------
-- The tab makers (public: other windows use them too)
---------------------------------------------------------------------------

local function SideTabEnter(tab)
    local text = rawget(tab, "tooltip")
    if type(text) == "string" and text ~= "" then Look.ShowTip(tab, "RIGHT", { { text, 1, 1, 1 } }) end
end

local function SideTabLeave(tab)
    Look.HideTip(tab)
end

-- A school tab: 32 x 32 on its 64 x 64 plate, with the old glow and checked
-- art; hidden. Its hover shows the text in its tooltip field. Callers set
-- that field, the icon (its normal texture) and their own click.
function ns.NewSideTab(parent, index, previous)
    local tab = Look.Build("CheckButton", parent, nil, { size = { 32, 32 }, hidden = true })
    local plate = Look.OwnTexture(tab, "plate", "BACKGROUND")
    Look.Art(plate, "sbSkillTab")
    plate:SetSize(64, 64)
    Look.Pin(plate, "TOPLEFT", tab, "TOPLEFT", -3, 11)
    for state, key in pairs({ Highlight = "slotHighlight", Checked = "slotChecked" }) do
        local face = Look.StateArt(tab, state, key)
        if face then face:SetBlendMode("ADD") end
    end
    if previous then
        Look.Pin(tab, "TOPLEFT", previous, "BOTTOMLEFT", 0, -17)
    else
        Look.Pin(tab, "TOPLEFT", parent, "TOPRIGHT", -32, -65)
    end
    tab:SetScript("OnEnter", SideTabEnter)
    tab:SetScript("OnLeave", SideTabLeave)
    return tab
end

-- The spellbook's own book tab click (set later by the book).
function S.BookTabClick(tab)
    if S.OnBookTab then S.OnBookTab(tab) end
end

-- A book tab: 128 x 64, the unselected art, its "selected" look as the
-- disabled art (tab 3 has its own), the old glow; hidden. Placed after the
-- previous tab (20 over its right edge) or centred on the parent's
-- bottom-left (79, 61).
function ns.NewBookTab(parent, index, previous)
    local tab = Look.Build("Button", parent, nil, { size = { 128, 64 }, hidden = true })
    Look.StateArt(tab, "Normal", "sbTabUnselected")
    Look.StateArt(tab, "Disabled", index == 3 and "sbTab3Selected" or "sbTab1Selected")
    local glow = Look.StateArt(tab, "Highlight", "sbTabHighlight")
    if glow then glow:SetBlendMode("ADD") end
    local label = Look.OwnLabel(tab, "label", "GameFontNormalSmall", "ARTWORK")
    label:SetHeight(13)
    Look.Pin(label, "CENTER", tab, "CENTER", 0, 3)
    tab:SetFontString(label)
    if GameFontNormalSmall then tab:SetNormalFontObject(GameFontNormalSmall) end
    if GameFontHighlightSmall then tab:SetDisabledFontObject(GameFontHighlightSmall) end
    if previous then
        Look.Pin(tab, "LEFT", previous, "RIGHT", -20, 0)
    else
        Look.Pin(tab, "CENTER", parent, "BOTTOMLEFT", 79, 61)
    end
    tab:SetScript("OnClick", S.BookTabClick)
    return tab
end
