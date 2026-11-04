-- The talent window's kit (Classic look, registry "talents"): its state,
-- its 1.x art keys, and the parts that only work things out:
--   * reading Forever's trait tree into a plain picture of the three
--     classic trees (tabs, points, talents);
--   * the old grid (600 tree units to a cell, 63 window units apart);
--   * where each branch line and arrow head of a link goes;
--   * the lines of a talent's tooltip.
--
-- Forever's talents are retail-style trait trees: one tree per class, its
-- node groups being the three classic trees. Every call into the trait and
-- tooltip APIs is protected, and every value read is checked for secrets
-- (a hidden value counts as missing), so a call this client lacks or a
-- value it hides leaves a talent or a line out instead of breaking the
-- window.
local _, EraUI = ...
local Look = EraUI.Look
local Number, Secret = Look.Number, Look.Secret

local T = { active = false, tab = 1, unit = nil, parts = {} }
Look.Talent = T

T.WIDTH, T.HEIGHT = 384, 512
T.VIEW_W, T.VIEW_H = 296, 332      -- the tree view, at (22, -77) in the window
T.PITCH, T.FIRST_X, T.FIRST_Y = 63, 35, 20
T.CELL = 600                       -- tree units between two grid cells
T.TIP_WRAP = 260                   -- where long tooltip lines wrap
T.GOLD, T.GREEN, T.GREY = { 1, 0.82, 0 }, { 0.1, 1, 0.1 }, { 0.5, 0.5, 0.5 }
T.RED, T.WHITE = { 1, 0.1, 0.1 }, { 1, 1, 1 }

---------------------------------------------------------------------------
-- Art (the last name is Dark Mode's key)
---------------------------------------------------------------------------

do
    local paper, talentFolder = "Interface\\PaperDollInfoFrame\\", "Interface\\TalentFrame\\"
    -- Shared with the character window, which may have set them up already.
    local shared = {
        { "charGeneralTopLeft", paper .. "UI-Character-General-TopLeft", "UI-Character-General-TopLeft", "charGeneralTopLeft" },
        { "charGeneralTopRight", paper .. "UI-Character-General-TopRight", "UI-Character-General-TopRight", "charGeneralTopRight" },
        { "tabActive", paper .. "UI-Character-ActiveTab", "UI-Character-ActiveTab", "tabActive" },
        { "tabInactive", paper .. "UI-Character-InActiveTab", "UI-Character-InActiveTab", "tabInactive" },
        { "tabHighlight", paper .. "UI-Character-Tab-RealHighlight", "UI-Character-Tab-RealHighlight" },
        { "skillsBarBorder", nil, "UI-Character-Skills-BarBorder", "skillsBarBorder", true },
    }
    for _, art in ipairs(shared) do
        if not Look.ART[art[1]] then Look.DefineArt(art[1], art[2], art[3], art[4], art[5]) end
    end
    -- The old talent frame's lower half: the client's files only, greyed by
    -- Dark Mode with the rest of the frame.
    Look.DefineArt("talentSheetLeft", talentFolder .. "UI-TalentFrame-BotLeft", nil, "frameSheet")
    Look.DefineArt("talentSheetRight", talentFolder .. "UI-TalentFrame-BotRight", nil, "frameSheet")
end

-- Each class's three 1.x backgrounds, by tab position.
T.BACKDROPS = {}
for class, first, second, third in ([[DRUID Balance FeralCombat Restoration  HUNTER BeastMastery Marksmanship Survival
    MAGE Arcane Fire Frost  PALADIN Holy Protection Combat  PRIEST Discipline Holy Shadow
    ROGUE Assassination Combat Subtlety  SHAMAN ElementalCombat Enhancement Restoration
    WARLOCK Curses Summoning Destruction  WARRIOR Arms Fury Protection]]):gmatch("(%u+) (%a+) (%a+) (%a+)") do
    local prefix = class:sub(1, 1) .. class:sub(2):lower()
    T.BACKDROPS[class] = { prefix .. first, prefix .. second, prefix .. third }
end

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

-- A plain game function, called quietly: its first two results, or nil
-- when it is missing or refuses.
function T.Ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local fine, first, second = pcall(fn, ...)
    if not fine then return nil end
    return first, second
end
local Ask = T.Ask

local function Yes(value)
    return not Secret(value) and value == true
end
T.Yes = Yes

-- Text that may be shown: a string, not hidden, not empty.
local function Readable(value)
    if Secret(value) or type(value) ~= "string" or value == "" then return nil end
    return value
end
T.Text = Readable

-- The game's own words (formatted), or the English stand-in.
function T.Say(globalName, fallback, ...)
    local pattern = _G[globalName]
    if type(pattern) ~= "string" or Secret(pattern) or pattern == "" then pattern = fallback end
    if select("#", ...) == 0 then return pattern end
    local fine, said = pcall(string.format, pattern, ...)
    if fine then return said end
    local spare, plain = pcall(string.format, fallback, ...)
    return spare and plain or fallback
end

function T.Whole(value)
    value = Number(value) or 0
    if value == math.floor(value) then return string.format("%d", value) end
    return tostring(value)
end

function T.Sound(kitName)
    local kit = SOUNDKIT and SOUNDKIT[kitName]
    if PlaySound and kit then PlaySound(kit) end
end

function T.Now()
    return GetTime and Number(GetTime()) or 0
end

-- The edge kind the old trees never drew (only decoration in the new UI).
local function DecorOnly()
    local kinds = Enum and Enum.TraitEdgeType
    return Number(kinds and kinds.VisualOnly) or 0
end

---------------------------------------------------------------------------
-- Reading the tree
---------------------------------------------------------------------------

-- The config shown: the inspected player's, or your active spec's.
function T.ConfigID(inspecting)
    if inspecting then
        local consts = Constants and Constants.TraitConsts
        return Number(consts and consts.INSPECT_TRAIT_CONFIG_ID) or -1
    end
    local specs = C_SpecializationInfo
    local found
    if type(specs) == "table" then
        found = Number(Ask(specs.GetCombatConfigIDForSpecGroup, (Ask(specs.GetActiveSpecGroup))))
    end
    if not found and type(C_ClassTalents) == "table" then found = Number(Ask(C_ClassTalents.GetActiveConfigID)) end
    return found
end

-- The tree's groups as tabs, in their own order (orderIndex, missing 0).
local function ReadTabs(picture, traits)
    local groups = Ask(traits.GetGroupDisplayInfoByTreeID, picture.tree)
    if type(groups) ~= "table" then return end
    for seen, group in ipairs(groups) do
        local id = type(group) == "table" and Number(group.groupID)
        if id then
            picture.tabs[#picture.tabs + 1] = { id = id, name = Readable(group.displayName) or "", rank = Number(group.orderIndex) or 0,
                seen = seen, spent = 0, nodes = {}, tiers = 0 }
        end
    end
    table.sort(picture.tabs, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.seen < b.seen
    end)
    for index, tab in ipairs(picture.tabs) do picture.tabOf[tab.id] = index end
end

-- Points spent in each tab, the tree's unspent points, and staged changes.
local function ReadPoints(picture, traits)
    local ids = {}
    for i, tab in ipairs(picture.tabs) do ids[i] = tab.id end
    local spending = Ask(traits.GetGroupCurrencyInfo, picture.config, ids)
    for _, group in ipairs(type(spending) == "table" and spending or {}) do
        local index = type(group) == "table" and picture.tabOf[Number(group.traitNodeGroupID) or false]
        local purse = index and type(group.currencyInfos) == "table" and group.currencyInfos[1]
        if type(purse) == "table" then picture.tabs[index].spent = Number(purse.spent) or 0 end
    end
    local wallet = Ask(traits.GetTreeCurrencyInfo, picture.config, picture.tree, false)
    local first = type(wallet) == "table" and wallet[1]
    picture.unspent = type(first) == "table" and Number(first.quantity) or 0
    picture.staged = not picture.inspecting and Yes(Ask(traits.ConfigHasStagedChanges, picture.config))
end

-- The spell a node's entry teaches and its icon.
local function Teaches(traits, config, entry)
    local about = entry and Ask(traits.GetEntryInfo, config, entry)
    local definition = type(about) == "table" and Number(about.definitionID)
    local spec = definition and Ask(traits.GetDefinitionInfo, definition)
    if type(spec) ~= "table" then return nil, nil end
    local spell = Number(spec.overriddenSpellID) or Number(spec.spellID)
    local icon = spec.overrideIcon
    if Secret(icon) or not (type(icon) == "string" or (type(icon) == "number" and icon ~= 0)) then icon = nil end
    if not icon and spell then
        icon = Ask(C_Spell and C_Spell.GetSpellTexture, spell)
        if Secret(icon) or (type(icon) ~= "number" and type(icon) ~= "string") then icon = nil end
    end
    return spell, icon
end

-- The first of the node's groups that is a tab, or nil.
local function TabFor(picture, groupIDs)
    if type(groupIDs) ~= "table" then return nil end
    for _, group in ipairs(groupIDs) do
        local index = picture.tabOf[Number(group) or false]
        if index then return index end
    end
    return nil
end

local function ReadTalent(picture, traits, id)
    local about = Ask(traits.GetNodeInfo, picture.config, id)
    if type(about) ~= "table" then return end
    if not Secret(about.isVisible) and about.isVisible == false then return end
    local across = Number(about.posX)
    local index = across and TabFor(picture, about.groupIDs)
    if not index then return end
    local active = about.activeEntry
    local entry = type(active) == "table" and Number(active.entryID) or nil
    if not entry and type(about.entryIDs) == "table" then entry = Number(about.entryIDs[1]) end
    local spell, icon = Teaches(traits, picture.config, entry)
    local talent = {
        id = id, tab = index, x = across, y = Number(about.posY) or 0, entry = entry, spell = spell, icon = icon,
        ranks = Number(about.ranksPurchased) or 0, max = Number(about.maxRanks) or 1,
        canBuy = Yes(about.canPurchaseRank) and picture.unspent > 0, canRefund = Yes(about.canRefundRank),
        edges = type(about.visibleEdges) == "table" and about.visibleEdges or {},
        gates = type(about.conditionIDs) == "table" and about.conditionIDs or {},
    }
    picture.byNode[id] = talent
    picture.all[#picture.all + 1] = talent
    table.insert(picture.tabs[index].nodes, talent)
end

local function Round(value)
    return math.floor(value + 0.5)
end

-- Rows count from the top of the whole tree (so the trees line up),
-- columns from each tree's own left edge.
local function LayGrid(picture)
    local top
    for _, talent in ipairs(picture.all) do top = math.min(top or talent.y, talent.y) end
    for _, tab in ipairs(picture.tabs) do
        local left
        for _, talent in ipairs(tab.nodes) do left = math.min(left or talent.x, talent.x) end
        for _, talent in ipairs(tab.nodes) do
            talent.tier = Round((talent.y - top) / T.CELL)
            talent.column = Round((talent.x - left) / T.CELL)
            tab.tiers = math.max(tab.tiers, talent.tier + 1)
        end
    end
end

-- Everything the window shows, read afresh: nil when there is no tree or it
-- has no tabs.
function T.ReadTree(inspecting)
    local traits = C_Traits
    local config = T.ConfigID(inspecting)
    if not config or type(traits) ~= "table" then return nil end
    local info = Ask(traits.GetConfigInfo, config)
    local trees = type(info) == "table" and info.treeIDs
    local tree = type(trees) == "table" and Number(trees[1])
    if not tree then return nil end
    local picture = { config = config, tree = tree, inspecting = inspecting and true or false, tabs = {}, tabOf = {},
        byNode = {}, all = {}, unspent = 0, staged = false }
    ReadTabs(picture, traits)
    if #picture.tabs == 0 then return nil end
    ReadPoints(picture, traits)
    local nodes = Ask(traits.GetTreeNodes, tree)
    for _, nodeID in ipairs(type(nodes) == "table" and nodes or {}) do
        local id = Number(nodeID)
        if id then ReadTalent(picture, traits, id) end
    end
    LayGrid(picture)
    return picture
end

---------------------------------------------------------------------------
-- The grid and the talents' states
---------------------------------------------------------------------------

-- A talent's top-left in the scroll child.
function T.Cell(talent)
    return T.FIRST_X + T.PITCH * talent.column, -(T.FIRST_Y + T.PITCH * talent.tier)
end

-- The scroll child's height for a tree of this many rows (five fit the view).
function T.ChildHeight(tiers)
    return math.max(T.VIEW_H, 77 + T.PITCH * ((tiers or 1) - 1))
end

function T.Maxed(talent)
    return talent.ranks >= talent.max
end

-- "learned" (gold), "open" (green: can be bought) or "locked" (grey).
function T.State(talent)
    if T.Maxed(talent) or (talent.ranks > 0 and not talent.canBuy) then return "learned" end
    if talent.canBuy then return "open" end
    return "locked"
end

---------------------------------------------------------------------------
-- Links: which are drawn, and where their pieces go
---------------------------------------------------------------------------

-- { from, to, lit } for each link out of the tab's talents; lit once the
-- source is fully ranked.
function T.Links(picture, tab)
    local found, decor = {}, DecorOnly()
    for _, source in ipairs(tab.nodes) do
        for _, edge in ipairs(source.edges) do
            local target = type(edge) == "table" and picture.byNode[Number(edge.targetNode) or false]
            if target and target ~= source and Number(edge.type) ~= decor then
                found[#found + 1] = { from = source, to = target, lit = T.Maxed(source) }
            end
        end
    end
    return found
end

-- The texture regions of each piece: { left, right, top, bottom } lit, then
-- unlit. Heads come from the arrows sheet, the rest from the branches sheet.
T.LINK_ART = {
    down = { { 0, 0.125, 0, 0.484375 }, { 0, 0.125, 0.515625, 1 } },
    across = { { 0.2578125, 0.3828125, 0, 0.5 }, { 0.2578125, 0.3828125, 0.5, 1 } },
    headDown = { { 0, 0.5, 0, 0.5 }, { 0, 0.5, 0.5, 1 }, head = true },
    headRight = { { 1, 0.5, 0, 0.5 }, { 1, 0.5, 0.5, 1 }, head = true },
    headLeft = { { 0.5, 1, 0, 0.5 }, { 0.5, 1, 0.5, 1 }, head = true },
}

-- The pieces of one link, each { kind, x, y, w, h } by its top-left in the
-- scroll child (y counts down). Sideways within a row: a line and a head
-- poking 12 into the target's side. Down to a later row: a line along the
-- source's row to the target's column (when the columns differ), a line
-- down to the target, and a head poking 12 into its top. A link up the
-- tree draws nothing.
function T.LinkPieces(source, target)
    local sx, sy = T.Cell(source)
    local tx, ty = T.Cell(target)
    local pieces = {}
    local function Put(kind, x, y, w, h)
        pieces[#pieces + 1] = { kind = kind, x = x, y = y, w = math.max(1, w), h = math.max(1, h) }
    end
    local row = sy - 2.5
    if target.tier == source.tier then
        if target.column > source.column then
            Put("across", sx + 35, row, tx + 2 - (sx + 35), 32)
            Put("headRight", tx - 20, ty - 2.5, 32, 32)
        elseif target.column < source.column then
            Put("across", tx + 35, row, sx + 2 - (tx + 35), 32)
            Put("headLeft", tx + 25, ty - 2.5, 32, 32)
        end
        return pieces
    end
    if target.tier < source.tier then return pieces end
    local shaft = tx + 2.5
    if target.column == source.column then
        Put("down", shaft, sy - 35, 32, sy - 35 - (ty - 2))
    else
        if target.column > source.column then
            Put("across", sx + 35, row, tx + 34.5 - (sx + 35), 32)
        else
            Put("across", shaft, row, sx + 2 - shaft, 32)
        end
        Put("down", shaft, sy - 18.5, 32, sy - 18.5 - (ty + 2))
    end
    Put("headDown", shaft, ty + 20, 32, 32)
    return pieces
end

---------------------------------------------------------------------------
-- A talent's tooltip lines (for EraUI's own tooltip, Look.ShowTip)
---------------------------------------------------------------------------

local function Paint(colour, fallback)
    if type(colour) == "table" then
        local r, g, b = Number(colour.r), Number(colour.g), Number(colour.b)
        if r and g and b then return r, g, b end
    end
    return fallback[1], fallback[2], fallback[3]
end

-- The lines of a tooltip-data record (C_TooltipInfo), added to rows: a
-- hidden or empty left text is skipped; a right text makes a two-column
-- line; other lines wrap unless the record says not to.
function T.DataRows(record, rows)
    if type(record) ~= "table" or type(record.lines) ~= "table" then return end
    for _, line in ipairs(record.lines) do
        local left = type(line) == "table" and Readable(line.leftText)
        if left then
            local r, g, b = Paint(line.leftColor, T.GOLD)
            local row = { left, r, g, b }
            local right = Readable(line.rightText)
            if right then
                local rr, rg, rb = Paint(line.rightColor, T.WHITE)
                row.right = { right, rr, rg, rb }
            elseif Secret(line.wrapText) or line.wrapText ~= false then
                row[5] = T.TIP_WRAP
            end
            rows[#rows + 1] = row
        end
    end
end

local function SpellName(spell)
    local spells = C_Spell
    return spell and type(spells) == "table" and Readable((Ask(spells.GetSpellName, spell))) or nil
end

local function Warn(rows, text)
    rows[#rows + 1] = { text, T.RED[1], T.RED[2], T.RED[3], T.TIP_WRAP }
end

-- Unmet point gates ("Requires 10 points in Arms Talents", the selected
-- tab's name).
local function GateRows(picture, talent, tabName, rows)
    local traits = C_Traits
    for _, gate in ipairs(talent.gates) do
        local id = Number(gate)
        local about = id and type(traits) == "table" and Ask(traits.GetConditionInfo, picture.config, id)
        local need = type(about) == "table" and Yes(about.isGate) and not Yes(about.isMet) and Number(about.spentAmountRequired)
        if need then Warn(rows, T.Say("TOOLTIP_TALENT_TIER_POINTS", "Requires %d points in %s Talents", need, tabName or "")) end
    end
end

-- Talents anywhere in the tree that lead here and aren't fully ranked yet,
-- each with its own max rank.
local function NeedRows(picture, talent, rows)
    local decor = DecorOnly()
    for _, other in ipairs(picture.all) do
        if not T.Maxed(other) then
            for _, edge in ipairs(other.edges) do
                if type(edge) == "table" and Number(edge.targetNode) == talent.id and Number(edge.type) ~= decor then
                    local plain = other.max == 1 and "Requires %d point in %s" or "Requires %d points in %s"
                    Warn(rows, T.Say("TOOLTIP_TALENT_PREREQ", plain, other.max, SpellName(other.spell) or "?"))
                    break
                end
            end
        end
    end
end

local function RankRows(talent, rank, rows)
    local fetch = C_TooltipInfo and C_TooltipInfo.GetTraitEntry
    if talent.entry then T.DataRows((Ask(fetch, talent.entry, rank)), rows) end
end

function T.TipRows(picture, talent, tabName)
    local rows = {}
    local rankLine = { T.Say("TOOLTIP_TALENT_RANK", "Rank %d/%d", talent.ranks, talent.max), 1, 1, 1 }
    local name = SpellName(talent.spell)
    if name and C_TooltipInfo and type(C_TooltipInfo.GetTraitEntry) == "function" then
        rows[1] = { name, 1, 1, 1 }
        rows[2] = rankLine
        GateRows(picture, talent, tabName, rows)
        NeedRows(picture, talent, rows)
        RankRows(talent, math.max(1, talent.ranks), rows)
        if talent.ranks >= 1 and talent.ranks < talent.max then
            rows[#rows + 1] = { " ", 1, 1, 1 }
            rows[#rows + 1] = { T.Say("TOOLTIP_TALENT_NEXT_RANK", "Next rank:"), 1, 1, 1 }
            RankRows(talent, talent.ranks + 1, rows)
        end
    else
        if talent.spell and C_TooltipInfo then T.DataRows((Ask(C_TooltipInfo.GetSpellByID, talent.spell)), rows) end
        rows[#rows + 1] = { " ", 1, 1, 1 }
        rows[#rows + 1] = rankLine
    end
    if talent.canBuy and not picture.inspecting then
        rows[#rows + 1] = { T.Say("TOOLTIP_TALENT_LEARN", "Click to learn"), T.GREEN[1], T.GREEN[2], T.GREEN[3] }
    end
    return rows
end
