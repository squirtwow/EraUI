local _, E = ...

-- Action Rings' editor (Modules/ActionRings.lua): the box under /era >
-- Action Bars > Action Rings > Your Rings, the page's whole width. Left:
-- your rings, one line each with its key (or "no key"), and New Ring with
-- its list of kinds. Right: the chosen ring's name and Delete; for a
-- ready-made ring, what it fills itself with and Make Editable; the ring as
-- it looks (click a slice to choose it) and the chosen slice with Move
-- Earlier, Move Later, Remove and, for a lower rank of a spell, Keep This
-- Rank; a box to drop a spell, item, mount, pet, toy, macro or set on; and
-- pickers for each kind, a click adding one. Every change is saved at once;
-- a ring changes only out of a fight (in one, when it ends). Drops wait for
-- the fight to end. Names show through EraUI's own tooltip, never the game's.
local Ed = {}
E.RingEditor = Ed

Ed.WIDTH, Ed.HEIGHT = 718, 530
Ed.LEFT, Ed.LEFT_WIDTH, Ed.RIGHT, Ed.RIGHT_WIDTH = 10, 220, 246, 462
Ed.ROW, Ed.ROW_STEP, Ed.LIST_TOP = 26, 28, -34
Ed.PREVIEW, Ed.PREVIEW_ICON, Ed.PREVIEW_RADIUS = 180, 24, 66
Ed.CELL, Ed.CELL_GAP, Ed.COLUMNS, Ed.LINES = 36, 6, 11, 3
Ed.KEY_WIDTH = 96 -- a ring's key in the list at most; the ring's name has the rest
Ed.TOP_HINT = "Bind each ring in Key Bindings > AddOns > EraUI. A change made in a fight waits for it to end."
Ed.LATER = "Saved. Your ring changes when this fight ends."
-- New Ring's list: {kind, its name in the list}; the class ring's name is
-- your class's, World Markers only on a client that has them.
Ed.KINDS = {{"custom", "Empty Ring"}, {"quest", "Quest Items"}, {"raid", "Raid Markers"},
    {"world", "World Markers (experimental)"}, {"mounts", "Mounts"}, {"class", "Class Ring"}}
-- What a ready-made ring fills itself with (the line under its name).
Ed.NOTES = {quest = "Fills itself with quest items you can use and items that start a quest.",
    raid = "Marks your target. Pick a mark again to take it off.",
    world = "Ground markers where you aim, in a group you lead or assist. (experimental)",
    mounts = "Your mounts, favourites first.",
    class = "Your class's spells, at the highest rank you know.",
    rogue = "Your poisons, for each hand."}

local DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local function Rows() return E.SettingsRows end
local function D() return E.RingData end
local function F() return E.RingFill end
local function Module() return E.modules and E.modules.ActionRings end

-- One line (cut with "..." when too long), or up to lines lines.
local function Text(parent, value, size, muted, lines)
    local text = Rows().Text(parent, value, size, muted)
    local wrap = lines ~= nil and lines > 1
    text:SetWordWrap(wrap)
    if wrap then
        if text.SetMaxLines then text:SetMaxLines(lines) end
        text:SetJustifyV("TOP")
        text:SetHeight(lines * (size + 2))
    end
    return text
end
local function Button(parent, label, width, height, strong)
    local button = Rows().Button(parent, label, width, height, strong)
    return button
end
-- A name, and under it (muted) what it is.
local function Tip(owner, text, more)
    local Look = E.Look
    if not (Look and Look.ShowTip and text) then return end
    local rows = {{text, 1, 1, 1}}
    if more then rows[2] = {more, .62, .64, .68} end
    Look.ShowTip(owner, "TOP", rows)
end
local function Untip(owner)
    local Look = E.Look
    if Look and Look.HideTip then Look.HideTip(owner) end
end
local function Place(region, parent, x, y)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
end

---------------------------------------------------------------------------
-- Building the box
---------------------------------------------------------------------------

-- The box under the Your Rings row, made once; moved under the row each time.
function Ed.Attach(frame, row)
    local parent = row:GetParent()
    if not Ed.panel then Ed.Build(parent, row) end
    local panel = Ed.panel
    if panel:GetParent() ~= parent then panel:SetParent(parent) end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -6)
    panel:Show()
    Ed.frame = frame
    Ed.Refresh()
end
function Ed.Hide()
    if Ed.panel then
        Ed.panel.menu:Hide()
        Ed.panel:Hide()
        Untip()
    end
end

function Ed.Build(parent, row)
    local panel = E.ClassTools.SubPanel(parent, row, Ed.WIDTH)
    panel:SetHeight(Ed.HEIGHT)
    panel.items = {}
    Ed.panel = panel
    panel.top = Text(panel, Ed.TOP_HINT, 11, true)
    panel.top:SetWidth(Ed.WIDTH - 20)
    Place(panel.top, panel, Ed.LEFT, -12)
    Ed.BuildList(panel)
    Ed.BuildRing(panel)
    Ed.BuildPreview(panel)
    Ed.BuildDetail(panel)
    Ed.BuildDrop(panel)
    Ed.BuildPicker(panel)
    return panel
end

-- Your rings, and New Ring with its list.
function Ed.BuildList(panel)
    panel.list = {}
    local r, g, b = Rows().ClassColour()
    for slot = 1, D().RINGS do
        local line = CreateFrame("Button", nil, panel, "BackdropTemplate")
        line:SetSize(Ed.LEFT_WIDTH, Ed.ROW)
        line:SetBackdrop(Rows().BACKDROP)
        line.bar = line:CreateTexture(nil, "ARTWORK")
        line.bar:SetPoint("TOPLEFT", line, "TOPLEFT", 1, -1)
        line.bar:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", 1, 1)
        line.bar:SetWidth(3)
        line.bar:SetColorTexture(r, g, b, 1)
        -- The key at the right (as wide as its words, at most KEY_WIDTH), the
        -- ring's name up to it: a long one ends in "...", never under the key.
        line.key = Text(line, "", 11)
        line.key:SetPoint("RIGHT", line, "RIGHT", -8, 0)
        line.key:SetJustifyH("RIGHT")
        line.name = Text(line, "", 12)
        line.name:SetPoint("LEFT", line, "LEFT", 10, 0)
        line.name:SetPoint("RIGHT", line.key, "LEFT", -6, 0)
        line:RegisterForClicks("LeftButtonUp")
        line:SetScript("OnClick", Ed.ListClick)
        line:Hide()
        panel.list[slot] = line
    end
    panel.new = Button(panel, "New Ring", Ed.LEFT_WIDTH, 24, true)
    panel.new:SetScript("OnClick", Ed.NewClick)
    local menu = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    menu:SetSize(Ed.LEFT_WIDTH, #Ed.KINDS * 24 + 8)
    menu:SetBackdrop(Rows().BACKDROP)
    menu:SetBackdropColor(.018, .02, .026, .98)
    menu:SetBackdropBorderColor(.19, .2, .24, 1)
    menu:SetFrameLevel(panel:GetFrameLevel() + 20)
    menu:EnableMouse(true)
    menu.entries = {}
    for i, kind in ipairs(Ed.KINDS) do
        local entry = CreateFrame("Button", nil, menu)
        entry:SetSize(Ed.LEFT_WIDTH - 8, 22)
        entry.label = Text(entry, kind[2], 12)
        entry.label:SetPoint("LEFT", entry, "LEFT", 8, 0)
        local hover = entry:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints(entry)
        hover:SetColorTexture(1, 1, 1, .06)
        entry.ringKind = kind[1]
        entry:SetScript("OnClick", Ed.MenuPick)
        menu.entries[i] = entry
    end
    menu:Hide()
    panel.menu = menu
end

-- The chosen ring's name, Delete, its note and Make Editable.
function Ed.BuildRing(panel)
    local x = Ed.RIGHT
    panel.none = Text(panel, "Make a ring with New Ring, then give it a key in Key Bindings > AddOns > EraUI.", 12, true, 2)
    panel.none:SetWidth(Ed.RIGHT_WIDTH)
    Place(panel.none, panel, x, -40)
    panel.nameLabel = Text(panel, "Name", 13)
    Place(panel.nameLabel, panel, x, -40)
    local box = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
    box:SetSize(200, 24)
    Place(box, panel, x + 50, -34)
    box:SetBackdrop(Rows().BACKDROP)
    box:SetBackdropColor(Rows().TICK_FILL[1], Rows().TICK_FILL[2], Rows().TICK_FILL[3], 1)
    box:SetBackdropBorderColor(Rows().TICK_EDGE[1], Rows().TICK_EDGE[2], Rows().TICK_EDGE[3], 1)
    local font, _, flags = GameFontHighlight:GetFont()
    box:SetFont(font, 13, flags or "")
    box:SetTextColor(.94, .95, .98)
    box:SetTextInsets(7, 7, 0, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(D().NAME_LETTERS)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self.cancelled = true; self:ClearFocus() end)
    -- A name is the ring's it was typed for, whatever is chosen before it's
    -- saved (a click on a button leaves the box typing).
    box:SetScript("OnEditFocusGained", function(self) self.slot = Ed.slot end)
    box:SetScript("OnEditFocusLost", Ed.NameDone)
    panel.nameBox = box
    panel.delete = Button(panel, "Delete", 100, 24)
    Place(panel.delete, panel, x + Ed.RIGHT_WIDTH - 100, -34)
    panel.delete:SetScript("OnClick", Ed.DeleteClick)
    -- Two lines beside Make Editable, above the preview.
    panel.note = Text(panel, "", 11, true, 2)
    panel.note:SetWidth(Ed.RIGHT_WIDTH - 124)
    Place(panel.note, panel, x, -64)
    panel.editable = Button(panel, "Make Editable", 116, 22)
    Place(panel.editable, panel, x + Ed.RIGHT_WIDTH - 116, -64)
    panel.editable:SetScript("OnClick", Ed.EditableClick)
end

-- The preview's icon size and radius for n slices: 24 on a radius of 66; for
-- more slices pushed out (to the box's edge at most), then smaller, until no
-- two icons' outlines (2 each side) touch.
function Ed.PreviewFit(n)
    local view = E.RingView
    local spread, edge = view and view.Spread(n) or 2, Ed.PREVIEW / 2
    for size = Ed.PREVIEW_ICON, 12, -1 do
        local radius = math.max(Ed.PREVIEW_RADIUS, math.ceil((size + 5) / spread))
        if radius + size / 2 + 2 <= edge then return size, radius end
    end
    return 12, edge - 8
end

-- The ring as it looks, small: its round icons on a circle with nothing
-- behind them, each outlined in the ring's rim colour (the chosen one in its
-- accent colour); the ring's name in the middle. A click chooses one.
function Ed.BuildPreview(panel)
    local view = CreateFrame("Frame", nil, panel)
    view:SetSize(Ed.PREVIEW, Ed.PREVIEW)
    Place(view, panel, Ed.RIGHT, -96)
    view.label = Text(view, "", 11, true, 2)
    view.label:SetWidth(2 * (Ed.PREVIEW_RADIUS - Ed.PREVIEW_ICON / 2 - 4))
    view.label:SetJustifyH("CENTER")
    view.label:SetPoint("CENTER", view, "CENTER", 0, 0)
    view.icons = {}
    for k = 1, D().SLICES do
        local icon = CreateFrame("Button", nil, view)
        icon:SetSize(Ed.PREVIEW_ICON, Ed.PREVIEW_ICON)
        -- Round, as the ring's own icons, on a round outline.
        icon.outline = icon:CreateTexture(nil, "BACKGROUND")
        icon.outline:SetTexture(DISC)
        icon.outline:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
        icon.outline:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
        icon.art = icon:CreateTexture(nil, "ARTWORK")
        icon.art:SetAllPoints(icon)
        icon.art:SetTexCoord(.08, .92, .08, .92)
        if E.RingView then E.RingView.Round(icon, icon.art) end
        icon.k = k
        icon:RegisterForClicks("LeftButtonUp")
        icon:SetScript("OnClick", Ed.PreviewClick)
        icon:SetScript("OnEnter", function(self) Tip(self, self.tip) end)
        icon:SetScript("OnLeave", function(self) Untip(self) end)
        icon:Hide()
        view.icons[k] = icon
    end
    panel.preview = view
end

-- The chosen slice: its icon, name and kind, and what can be done with it.
function Ed.BuildDetail(panel)
    local x = Ed.RIGHT + Ed.PREVIEW + 10
    local width = Ed.RIGHT + Ed.RIGHT_WIDTH - x
    panel.slotIcon = panel:CreateTexture(nil, "ARTWORK")
    panel.slotIcon:SetSize(32, 32)
    panel.slotIcon:SetTexCoord(.08, .92, .08, .92)
    Place(panel.slotIcon, panel, x, -96)
    panel.slotName = Text(panel, "", 13)
    panel.slotName:SetWidth(width - 40)
    Place(panel.slotName, panel, x + 40, -98)
    -- Two lines, so "Can't be used now." always shows (Move Earlier sits under it).
    panel.slotKind = Text(panel, "", 11, true, 2)
    panel.slotKind:SetWidth(width - 40)
    Place(panel.slotKind, panel, x + 40, -114)
    panel.pick = Text(panel, "Click a slice in the ring to change it.", 11, true)
    panel.pick:SetWidth(width)
    Place(panel.pick, panel, x, -98)
    local half = math.floor((width - 8) / 2)
    panel.earlier = Button(panel, "Move Earlier", half, 22)
    Place(panel.earlier, panel, x, -142)
    panel.earlier:SetScript("OnClick", function() Ed.Move(-1) end)
    panel.later = Button(panel, "Move Later", half, 22)
    Place(panel.later, panel, x + width - half, -142)
    panel.later:SetScript("OnClick", function() Ed.Move(1) end)
    panel.remove = Button(panel, "Remove", half, 22)
    Place(panel.remove, panel, x, -170)
    panel.remove:SetScript("OnClick", Ed.RemoveClick)
    local keep = E.ClassTools.TickToggle(CreateFrame("Button", nil, panel), "Keep This Rank", width)
    Place(keep, panel, x, -200)
    keep:SetScript("OnClick", Ed.KeepClick)
    panel.keep = keep
end

-- The box to drop something on.
function Ed.BuildDrop(panel)
    local drop = CreateFrame("Button", nil, panel, "BackdropTemplate")
    drop:SetSize(Ed.RIGHT_WIDTH, 40)
    Place(drop, panel, Ed.RIGHT, -286)
    drop:SetBackdrop(Rows().BACKDROP)
    drop:SetBackdropColor(.045, .05, .06, 1)
    drop:SetBackdropBorderColor(.3, .32, .36, 1)
    drop.words = Text(drop, "", 12, true)
    drop.words:SetPoint("CENTER", drop, "CENTER", 0, 0)
    drop:RegisterForClicks("LeftButtonUp")
    drop:SetScript("OnReceiveDrag", Ed.Drop)
    drop:SetScript("OnClick", Ed.Drop)
    panel.drop = drop
end

-- The pickers: a small button for each kind, and a grid of what it has.
function Ed.BuildPicker(panel)
    panel.tabs = {}
    local x = Ed.RIGHT
    local font, _, flags = GameFontHighlight:GetFont()
    for i, picker in ipairs(F().PICKERS) do
        local tab = Button(panel, picker[2], 40, 22)
        tab.label:SetFont(font, 10, flags or "")
        tab:SetWidth(math.floor(tab.label:GetStringWidth() + 12.5))
        Place(tab, panel, x, -334)
        x = x + tab:GetWidth() + 3
        tab.id = picker[1]
        tab:SetScript("OnClick", Ed.TabClick)
        panel.tabs[i] = tab
    end
    local grid = CreateFrame("Frame", nil, panel)
    grid:SetSize(Ed.RIGHT_WIDTH, Ed.LINES * (Ed.CELL + Ed.CELL_GAP))
    Place(grid, panel, Ed.RIGHT, -362)
    grid:EnableMouseWheel(true)
    grid:SetScript("OnMouseWheel", function(_, delta) Ed.Scroll(-delta) end)
    grid.empty = Text(grid, "", 12, true)
    grid.empty:SetWidth(Ed.RIGHT_WIDTH)
    grid.empty:SetJustifyH("CENTER")
    grid.empty:SetPoint("CENTER", grid, "CENTER", 0, 0)
    grid.more = Text(panel, "", 10, true)
    grid.more:SetPoint("TOPRIGHT", grid, "BOTTOMRIGHT", 0, -2)
    grid.more:SetJustifyH("RIGHT")
    grid.cells = {}
    for i = 1, Ed.COLUMNS * Ed.LINES do
        local cell = CreateFrame("Button", nil, grid)
        cell:SetSize(Ed.CELL, Ed.CELL)
        local column, line = (i - 1) % Ed.COLUMNS, math.floor((i - 1) / Ed.COLUMNS)
        Place(cell, grid, column * (Ed.CELL + Ed.CELL_GAP), -line * (Ed.CELL + Ed.CELL_GAP))
        cell.art = cell:CreateTexture(nil, "ARTWORK")
        cell.art:SetAllPoints(cell)
        cell.art:SetTexCoord(.08, .92, .08, .92)
        local hover = cell:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints(cell)
        hover:SetColorTexture(1, 1, 1, .15)
        cell:RegisterForClicks("LeftButtonUp")
        cell:SetScript("OnClick", Ed.CellClick)
        cell:SetScript("OnEnter", function(self) Tip(self, self.slice and self.slice.name, self.slice and D().KindLine(self.slice, true)) end)
        cell:SetScript("OnLeave", function(self) Untip(self) end)
        cell:Hide()
        grid.cells[i] = cell
    end
    panel.grid = grid
    Ed.picker = Ed.picker or F().PICKERS[1][1]
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

-- The ring chosen now (the first one when none is, or it went).
function Ed.Ring()
    if Ed.slot and D().Ring(Ed.slot) then return D().Ring(Ed.slot), Ed.slot end
    Ed.slot, Ed.k = nil, nil
    for slot = 1, D().RINGS do
        if D().Ring(slot) then Ed.slot = slot; return D().Ring(slot), slot end
    end
    return nil, nil
end

-- A ring's slices as they show: your own, or what a ready-made one holds
-- now; each with its name, icon and whether it can be used.
function Ed.Slices(ring)
    local list = ring.kind == "custom" and ring.slices or F().Slices(ring)
    local ctx = {ranks = F().BestRanks().byName}
    local shown = {}
    for k, slice in ipairs(list) do
        local name, icon = D().Display(slice, ctx)
        shown[k] = {slice = slice, name = name, icon = icon, ready = D().Attr(slice, ctx) ~= nil}
    end
    return shown
end

-- A line in the box's hint, kept until the next.
function Ed.Say(text)
    Ed.said = text
    if Ed.panel then Ed.panel.hint:SetText(text or "") end
end

function Ed.Refresh()
    local panel = Ed.panel
    if not panel or not panel:IsShown() then return end
    local ring, slot = Ed.Ring()
    -- Anything else done between Delete's two clicks takes the question back.
    Ed.armed = nil
    Ed.DrawList(panel, slot)
    local shown = ring and Ed.Slices(ring) or {}
    if Ed.k and not shown[Ed.k] then Ed.k = nil end
    Ed.DrawRing(panel, ring)
    Ed.DrawPreview(panel, ring, shown)
    Ed.DrawDetail(panel, ring, shown)
    Ed.DrawPicker(panel, ring)
    panel.hint:SetText(Ed.said or "")
end

function Ed.DrawList(panel, chosen)
    local y = Ed.LIST_TOP
    local r, g, b = Rows().ClassColour()
    for slot, line in ipairs(panel.list) do
        local ring = D().Ring(slot)
        if ring then
            Place(line, panel, Ed.LEFT, y)
            y = y - Ed.ROW_STEP
            line.slot = slot
            line.name:SetText(slot .. "  " .. ring.name)
            local key = E.RingSecure.KeyText(slot)
            line.key:SetText(key or "no key")
            local across = E.RingView and E.RingView.Measure(line.key) or line.key:GetStringWidth()
            line.key:SetWidth(D().Num(across) and math.min(Ed.KEY_WIDTH, across + 2) or Ed.KEY_WIDTH)
            if key then line.key:SetTextColor(Rows().GOLD[1], Rows().GOLD[2], Rows().GOLD[3]) else line.key:SetTextColor(.58, .62, .68) end
            local on = slot == chosen
            line.bar:SetShown(on)
            if on then
                line:SetBackdropColor(r * .18, g * .18, b * .18, 1)
                line:SetBackdropBorderColor(r * .6, g * .6, b * .6, 1)
            else
                line:SetBackdropColor(Rows().FILL[1], Rows().FILL[2], Rows().FILL[3], 1)
                line:SetBackdropBorderColor(Rows().EDGE[1], Rows().EDGE[2], Rows().EDGE[3], 1)
            end
            line:Show()
        else
            line:Hide()
        end
    end
    Place(panel.new, panel, Ed.LEFT, y - 4)
    panel.menu:ClearAllPoints()
    panel.menu:SetPoint("TOPLEFT", panel.new, "BOTTOMLEFT", 0, -2)
end

function Ed.DrawRing(panel, ring)
    local has = ring ~= nil
    panel.none:SetShown(not has)
    for _, part in ipairs({panel.nameLabel, panel.nameBox, panel.delete, panel.preview, panel.drop}) do part:SetShown(has) end
    if not has then
        panel.note:Hide(); panel.editable:Hide()
        return
    end
    if not panel.nameBox:HasFocus() then panel.nameBox:SetText(ring.name or "") end
    panel.delete.label:SetText("Delete")
    local ready = ring.kind ~= "custom"
    local note = Ed.NOTES[ring.kind]
    if ring.kind == "class" and F().ClassToken() == "ROGUE" then note = Ed.NOTES.rogue end
    panel.note:SetText(note or "")
    panel.note:SetShown(ready)
    panel.editable:SetShown(ready)
    panel.drop.words:SetText(ready and "This ring fills itself. Make Editable to add your own."
        or "Drop a spell, item, mount, pet, toy, macro or set here.")
end

function Ed.DrawPreview(panel, ring, shown)
    local view = panel.preview
    local n = #shown
    -- The ring's own colours (Dark Mode or Classic): rims, and the accent
    -- for the chosen slice.
    local palette = E.RingView and E.RingView.Palette()
    local rim, accent = palette and palette.rim or {.04, .04, .05}, palette and palette.accent or {Rows().ClassColour()}
    local size, radius = Ed.PreviewFit(n)
    for k, icon in ipairs(view.icons) do
        local entry = shown[k]
        if entry then
            local angle = math.rad(E.RingSnippet.SliceAngle(k, n))
            icon:SetSize(size, size)
            icon:ClearAllPoints()
            icon:SetPoint("CENTER", view, "CENTER", radius * math.sin(angle), radius * math.cos(angle))
            icon.art:SetTexture(entry.icon)
            icon.art:SetDesaturated(not entry.ready)
            icon.tip = entry.name
            local tint = k == Ed.k and accent or rim
            icon.outline:SetVertexColor(tint[1], tint[2], tint[3], 1)
            icon:Show()
        else
            icon:Hide()
        end
    end
    view.label:SetText(not ring and "" or (n == 0 and "Empty" or (ring.name or "")))
end

function Ed.DrawDetail(panel, ring, shown)
    local entry = ring and Ed.k and shown[Ed.k]
    local own = ring ~= nil and ring.kind == "custom"
    panel.pick:SetShown(ring ~= nil and not entry)
    panel.pick:SetText(#shown == 0 and (own and "Drop something below, or pick it from the lists." or "")
        or "Click a slice in the ring to see it.")
    for _, part in ipairs({panel.slotIcon, panel.slotName, panel.slotKind}) do part:SetShown(entry and true or false) end
    for _, part in ipairs({panel.earlier, panel.later, panel.remove}) do part:SetShown((entry and own) and true or false) end
    panel.keep:Hide()
    if not entry then return end
    local ctx = {ranks = F().BestRanks().byName}
    panel.slotIcon:SetTexture(entry.icon)
    panel.slotIcon:SetDesaturated(not entry.ready)
    panel.slotName:SetText(entry.name)
    panel.slotKind:SetText(D().KindLine(entry.slice, entry.ready, ctx))
    local slice = entry.slice
    if own and slice.kind == "spell" then
        local name = F().SpellName(slice.id)
        local top = name and ctx.ranks[name]
        if top and top.id ~= slice.id then
            panel.keep.SetTick(slice.rank == "exact")
            panel.keep:Show()
        end
    end
end

function Ed.DrawPicker(panel, ring)
    local grid = panel.grid
    for _, tab in ipairs(panel.tabs) do
        if tab.id == Ed.picker then Rows().PaintChoices({tab}, 1) else Rows().PaintChoices({tab}, 0) end
    end
    local list, empty, breaks = {}, "", nil
    for _, picker in ipairs(F().PICKERS) do
        if picker[1] == Ed.picker then
            list, breaks = picker[3]()
            empty = picker[4]
        end
    end
    -- Markers and the like come without a name or icon: the game's own.
    local ctx = {ranks = F().BestRanks().byName}
    for _, slice in ipairs(list) do
        if not (D().Str(slice.name) and slice.icon) then slice.name, slice.icon = D().Display(slice, ctx) end
    end
    Ed.items = list
    local per = Ed.COLUMNS
    -- A picker can start a group on a new row (world markers after the
    -- raid ones): the rest of the row before it stays empty (false).
    local placed = {}
    for i, slice in ipairs(list) do
        if breaks and breaks[i] and #placed % per ~= 0 then
            for _ = 1, per - #placed % per do placed[#placed + 1] = false end
        end
        placed[#placed + 1] = slice
    end
    local lines = math.ceil(#placed / per)
    Ed.offset = math.max(0, math.min(Ed.offset or 0, lines - Ed.LINES))
    for i, cell in ipairs(grid.cells) do
        local slice = placed[Ed.offset * per + i] or nil
        cell.slice = slice
        if slice then
            local icon = slice.icon
            if not (D().Num(icon) or D().Str(icon)) then icon = D().UNKNOWN_ICON end
            cell.art:SetTexture(icon)
            cell:Show()
        else
            cell:Hide()
        end
    end
    grid.empty:SetText(#list == 0 and empty or "")
    grid.more:SetText(lines > Ed.LINES and ("Scroll for more: " .. (Ed.offset + 1) .. " to " .. math.min(lines, Ed.offset + Ed.LINES) .. " of " .. lines .. " rows") or "")
    for _, part in ipairs({grid, grid.more}) do part:SetShown(ring ~= nil) end
    for _, tab in ipairs(panel.tabs) do tab:SetShown(ring ~= nil) end
end

---------------------------------------------------------------------------
-- What the player does
---------------------------------------------------------------------------

-- After any change: saved, its key's name, the ring now or after the fight.
function Ed.Changed(slot)
    local module = Module()
    local said = module and module:Edited(slot or Ed.slot)
    Ed.Say(said == "later" and Ed.LATER or nil)
    Ed.Refresh()
    return said
end

-- A name being typed is saved to its own ring before another is chosen.
function Ed.EndTyping()
    local box = Ed.panel and Ed.panel.nameBox
    if box and box:HasFocus() then box:ClearFocus() end
end

function Ed.ListClick(line)
    Ed.EndTyping()
    Ed.panel.menu:Hide()
    if line.slot ~= Ed.slot then Ed.slot, Ed.k, Ed.armed = line.slot, nil, nil end
    Ed.Say(nil)
    Ed.Refresh()
end

function Ed.NewClick()
    local menu = Ed.panel.menu
    if menu:IsShown() then menu:Hide(); return end
    if D().Count() >= D().RINGS then Ed.Say("You have 10 rings, the most there can be."); return end
    local y = -4
    for _, entry in ipairs(menu.entries) do
        local shown = entry.ringKind ~= "world" or F().WorldMarkersAvailable()
        if entry.ringKind == "class" then entry.label:SetText(D().DefaultName("class")) end
        if shown then
            Place(entry, menu, 4, y)
            y = y - 24
            entry:Show()
        else
            entry:Hide()
        end
    end
    menu:SetHeight(-y + 4)
    menu:Show()
end

function Ed.MenuPick(entry)
    Ed.EndTyping()
    Ed.panel.menu:Hide()
    local slot = D().NewRing(entry.ringKind)
    if not slot then Ed.Say("You have 10 rings, the most there can be."); return end
    Ed.slot, Ed.k, Ed.armed = slot, nil, nil
    Ed.Changed(slot)
end

-- The name typed: Enter or leaving the box saves it to the ring it was typed
-- for, Escape puts it back; empty is the ring's own name again.
function Ed.NameDone(box)
    local cancelled, slot = box.cancelled, box.slot or Ed.slot
    box.cancelled, box.slot = nil, nil
    local ring = D().Ring(slot)
    if ring and not cancelled then
        local before = ring.name
        D().Rename(slot, box:GetText())
        if ring.name ~= before then
            Ed.Changed(slot)
            return
        end
    end
    -- Nothing changed: the box shows the chosen ring's name.
    local shown = D().Ring(Ed.slot)
    box:SetText(shown and shown.name or "")
end

-- Delete: the first click asks ("Delete?"), the second deletes.
function Ed.DeleteClick()
    Ed.EndTyping()
    local slot = Ed.slot
    if not slot or not D().Ring(slot) then return end
    if Ed.armed ~= slot then
        Ed.armed = slot
        Ed.panel.delete.label:SetText("Delete?")
        return
    end
    Ed.armed = nil
    D().DeleteRing(slot)
    Ed.slot, Ed.k = nil, nil
    local module = Module()
    local said = module and module:Deleted(slot)
    Ed.Say(said == "later" and Ed.LATER or nil)
    Ed.Refresh()
end

-- A ready-made ring becomes one of your own, holding what it holds now.
function Ed.EditableClick()
    local ring = D().Ring(Ed.slot)
    if not ring or ring.kind == "custom" then return end
    local slices = {}
    for k, entry in ipairs(Ed.Slices(ring)) do
        local slice = {}
        for key, value in pairs(entry.slice) do slice[key] = value end
        slice.name, slice.icon = entry.name, entry.icon
        slices[k] = slice
    end
    D().MakeEditable(Ed.slot, slices)
    Ed.Changed()
end

function Ed.PreviewClick(icon)
    Ed.k = Ed.k ~= icon.k and icon.k or nil
    Ed.Refresh()
end

function Ed.Move(step)
    local to = Ed.k and D().MoveSlice(Ed.slot, Ed.k, step)
    if not to then return end
    Ed.k = to
    Ed.Changed()
end

function Ed.RemoveClick()
    if not (Ed.k and D().RemoveSlice(Ed.slot, Ed.k)) then return end
    local ring = D().Ring(Ed.slot)
    if ring and Ed.k > #ring.slices then Ed.k = #ring.slices > 0 and #ring.slices or nil end
    Ed.Changed()
end

function Ed.KeepClick()
    local ring = D().Ring(Ed.slot)
    local slice = ring and ring.slices and Ed.k and ring.slices[Ed.k]
    if not slice then return end
    D().SetKeepRank(Ed.slot, Ed.k, slice.rank ~= "exact")
    Ed.Changed()
end

-- Adds a slice after the chosen one (or at the end) of your own ring.
function Ed.Add(slice)
    local ring = D().Ring(Ed.slot)
    if not ring then Ed.Say("Make a ring with New Ring first."); return false end
    if ring.kind ~= "custom" then Ed.Say("This ring fills itself. Make Editable to add your own."); return false end
    local at, why = D().AddSlice(Ed.slot, slice, Ed.k)
    if not at then
        Ed.Say(why == "full" and "Full: a ring holds 16." or "That can't go in a ring.")
        return false
    end
    Ed.k = at
    Ed.Changed()
    return true
end

-- Something dropped on the box (or clicked on it while on the cursor). In
-- a fight it waits: the slice couldn't be used until the fight ends anyway.
function Ed.Drop()
    local kind, a, b, c = D().Call(GetCursorInfo)
    if not kind then return end
    if InCombatLockdown() then Ed.Say("Drop it after this fight."); return end
    local slice, why = D().FromCursor(kind, a, b, c)
    if not slice then Ed.Say(why); return end
    if Ed.Add(slice) then D().Call(ClearCursor) end
end

function Ed.TabClick(tab)
    if Ed.picker == tab.id then return end
    Ed.picker, Ed.offset = tab.id, 0
    Ed.Refresh()
end

function Ed.Scroll(step)
    Ed.offset = (Ed.offset or 0) + step
    Ed.Refresh()
end

function Ed.CellClick(cell)
    if not cell.slice then return end
    local slice = {}
    for key, value in pairs(cell.slice) do slice[key] = value end
    Ed.Add(slice)
end
