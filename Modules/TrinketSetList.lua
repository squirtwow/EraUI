local _, E = ...

-- The sets panel under /era > Action Bars > Trinkets > Your Sets: the trinket
-- sets you have saved (Modules/TrinketSets.lua), one line each with its name
-- to type over, what it holds, the key it answers to, and Load, Save Over and
-- Delete. Save What I'm Wearing at the top of the panel makes a new one of the
-- trinkets you have on now. There is no limit on how many sets you keep: the
-- panel grows with the list and /era's own page scrolls.
--
-- The key button steps along the ten Trinket Set keys in the game's Key
-- Bindings menu (Modules/TrinketKeys.lua): a left-click takes the next one, a
-- right-click the one before, and both go round through no key at all. Two
-- sets never hold the same key, so taking one says which set lost it. The key
-- itself is yours to set in that menu; EraUI never sets one.
--
-- It is /era's own kind of box (Modules/ClassTools.lua SubPanel), so the
-- options window lays it out and Dark Mode looks after it, and it is built
-- once and shown under the row whenever that page is open. Nothing here reads
-- the game: the sets are Modules/TrinketSets.lua's, and the slots, the names
-- and the icons are Modules/TrinketKit.lua's. An item's name shows in EraUI's
-- own small box, never the game's tooltip, which Forever taints as soon as an
-- addon drives it.
--
-- The game never lets gear change in a fight. Load in one keeps the set and
-- puts it on the moment the fight ends, and says so; everything else here
-- only writes to the saved table, which a fight never stops.
local SL = {}
E.TrinketSetList = SL

SL.WIDTH, SL.PAD = 718, 10
SL.ROW, SL.ROW_STEP, SL.LIST_TOP = 26, 30, 86
SL.NAME, SL.CELL, SL.CELL_GAP, SL.BUTTON = 200, 22, 4, 78
SL.KEY = 100 -- the key button, between the cells and Load
SL.BOTTOM = 30 -- room under the list for the panel's own line
SL.TOP_HINT = "Save the trinkets you have on now, then put them back on with one click, or with a key of "
    .. "your own: click a set's key button and press the key you want. "
    .. "A set loaded in a fight goes on the moment the fight ends."
SL.NONE = "No sets yet. Save What I'm Wearing makes one of what you have on."
SL.NO_KEY = "No key"

local function K() return E.TrinketKit end
local function Sets() return E.TrinketSets end
local function Keys() return E.TrinketKeys end
local function Rows() return E.SettingsRows end

---------------------------------------------------------------------------
-- The parts of the panel
---------------------------------------------------------------------------

-- One line of words, or up to lines lines.
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

local function Tip(owner, title, more)
    K().Tip(owner, title, more)
end
local function Untip(owner)
    K().Untip(owner)
end

-- What the panel says after the last thing you did, under the list.
function SL.Say(text)
    SL.said = text
    if SL.panel then SL.panel.hint:SetText(text or "") end
end

-- A name box being typed in is finished with first, so a click on Load or
-- Delete keeps the name you typed.
function SL.EndTyping()
    local panel = SL.panel
    if panel and panel.typing and panel.typing:HasFocus() then panel.typing:ClearFocus() end
end

---------------------------------------------------------------------------
-- One line of the list
---------------------------------------------------------------------------

-- The name as typed, kept on the set it was typed for: whatever is chosen or
-- deleted before it is saved, it goes to the right set, and a set deleted
-- while you type simply takes the name with it.
local function NameDone(box)
    local panel = SL.panel
    if panel then panel.typing = nil end
    local cancelled, set = box.cancelled, box.set
    box.cancelled, box.set = nil, nil
    if set and not cancelled then
        local before = set.name
        local name = Sets().Rename(set, box:GetText())
        if name and name ~= before then
            SL.Say("Renamed " .. name .. ".")
            SL.Refresh()
            return
        end
    end
    SL.Refresh()
end

local function NameGained(box)
    local panel = SL.panel
    if panel then panel.typing = box end
    box.set = box.line and box.line.set
end

local function LoadClick(button)
    local line = button.line
    SL.EndTyping()
    local sets = Sets()
    local index = line.set and sets.IndexOf(line.set)
    if not index then SL.Refresh(); return end
    local name = line.set.name
    local how, gone = sets.Wear(index)
    if how == "later" then SL.Say(K().LATER)
    elseif how == "now" then SL.Say(gone or ("Put on " .. name .. "."))
    else SL.Say(nil) end
    SL.Refresh()
end

local function OverClick(button)
    local line = button.line
    SL.EndTyping()
    local sets = Sets()
    local index = line.set and sets.IndexOf(line.set)
    if not index then SL.Refresh(); return end
    sets.Over(index)
    SL.Say("Saved what you have on into " .. line.set.name .. ".")
    SL.Refresh()
end

-- A key slot's plain name, as the game's Key Bindings menu shows it.
local function Label(slot)
    local keys = Keys()
    return ((keys and keys.PLAIN) or "Trinket Set ") .. slot
end

-- What the key button says: no key, or the key slot and the key you have set
-- on it ("Key 3: F7").
local function KeyText(set, line)
    if line and SL.Listening(line) then return "Press a key" end
    local slot = set and set.key
    if not slot then return SL.NO_KEY end
    local keys = Keys()
    local key = keys and keys.KeyText and keys.KeyText(slot)
    -- The key itself, not the slot it happens to sit in. The slot stopped
    -- being the player's business the moment they could bind the key here,
    -- and "Key 1: CTRL-F" ran off the end of the button (27 Nov 2026). The
    -- slot still shows in the game's own menu for anyone who wants it.
    return key or ("Key " .. slot)
end

-- Binding a key to a set, here rather than in the game's own menu. A
-- left-click waits for a key and sets it; a right-click takes it away.
-- Squirt asked for this on 27 Nov 2026: pointing a set at one of ten slots
-- here and then hunting that slot down in Key Bindings is two jobs for what
-- is plainly one ("say i have it set to ctrl 1, i press ctrl 1 and those
-- trinkets will be equipped"). A slot still carries the binding, so the
-- game's own menu goes on showing and changing it; a free one is just picked
-- for you. The only place EraUI writes a binding besides the classic talents
-- offer, under the same rules: never in a fight, and a key the game refuses
-- changes nothing.
local listening -- the SET whose button is waiting for a key, never the line: a
-- refresh recycles the lines, and a stale one loses its set

-- The first of the ten slots no other set holds, or the set's own.
local function FreeSlot(sets, set)
    if set.key then return set.key end
    local keys = Keys()
    for slot = 1, (keys and keys.KEYS) or 10 do
        if not sets.Keyed(slot) then return slot end
    end
end

-- A keypress as the game writes it, with its modifiers. A modifier pressed on
-- its own is not a key to bind.
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    UNKNOWN = true }
local function Chord(key)
    if type(key) ~= "string" or MODIFIERS[key] then return nil end
    local chord = ""
    if IsAltKeyDown() then chord = chord .. "ALT-" end
    if IsControlKeyDown() then chord = chord .. "CTRL-" end
    if IsShiftKeyDown() then chord = chord .. "SHIFT-" end
    return chord .. key
end

function SL.StopListening()
    if not listening then return end
    listening = nil
    if SL.catcher then
        SL.catcher:EnableKeyboard(false)
        SL.catcher:Hide()
    end
    SL.Refresh()
end

function SL.Listening(line) return listening ~= nil and line ~= nil and listening == line.set end

local function Took(set, key)
    local sets, keys = Sets(), Keys()
    if not (set and sets.IndexOf(set) and keys) then return SL.StopListening() end
    local slot = FreeSlot(sets, set)
    if not slot then
        SL.Say("All ten key slots are taken. Take a key off another set first.")
        return SL.StopListening()
    end
    local ok, lost = sets.Key(set, slot)
    if not ok then return SL.StopListening() end
    local took = false
    pcall(function() took = SetBinding(key, "CLICK " .. keys.NAME .. slot .. ":LeftButton") and true or false end)
    if not took then
        SL.Say("The game would not take " .. key .. ".")
        return SL.StopListening()
    end
    pcall(SaveBindings, GetCurrentBindingSet())
    SL.Say(set.name .. " is on " .. key .. ".")
    if lost then SL.Say(Label(slot) .. " taken from " .. lost.name .. ".") end
    SL.StopListening()
end

local function Catcher()
    if SL.catcher then return SL.catcher end
    local catcher = CreateFrame("Frame", nil, UIParent)
    catcher:Hide()
    if catcher.SetPropagateKeyboardInput then catcher:SetPropagateKeyboardInput(false) end
    catcher:SetScript("OnKeyDown", function(_, key)
        if not listening then return end
        if key == "ESCAPE" then
            SL.Say("Left as it was.")
            return SL.StopListening()
        end
        local chord = Chord(key)
        if chord then Took(listening, chord) end
    end)
    SL.catcher = catcher
    return catcher
end

local function KeyClick(button, mouse)
    local line = button.line
    SL.EndTyping()
    local sets = Sets()
    if not (line.set and sets.IndexOf(line.set)) then SL.Refresh(); return end
    -- A right-click takes the key off, which is the way back out.
    if mouse == "RightButton" then
        SL.StopListening()
        local keys, slot = Keys(), line.set.key
        if slot and keys then
            local had = GetBindingKey("CLICK " .. keys.NAME .. slot .. ":LeftButton")
            if had then
                pcall(SetBinding, had)
                pcall(SaveBindings, GetCurrentBindingSet())
            end
        end
        if sets.Key(line.set, nil) then SL.Say(line.set.name .. " answers to no key now.") end
        SL.Refresh()
        return
    end
    if InCombatLockdown() then
        SL.Say("You can't change a key in a fight.")
        return
    end
    if listening == line.set then return SL.StopListening() end
    listening = line.set
    local catcher = Catcher()
    catcher:Show()
    catcher:EnableKeyboard(true)
    SL.Refresh()
end

-- Delete asks first: the button says Delete?, and anything else you do in the
-- panel takes the question back.
local function DeleteClick(button)
    local line = button.line
    SL.EndTyping()
    local sets = Sets()
    local index = line.set and sets.IndexOf(line.set)
    if not index then SL.Refresh(); return end
    if SL.armed ~= line.set then
        -- One line asks at a time: whichever line held the question goes back
        -- to Delete first (Refresh puts every button's word back), so a line
        -- can never be left saying Delete? when a click on it would only ask
        -- again.
        SL.Refresh()
        SL.armed = line.set
        button.label:SetText("Delete?")
        return
    end
    local name = line.set.name
    SL.armed = nil
    sets.Delete(index)
    SL.Say(name .. " deleted.")
    SL.Refresh()
end

-- One line, made the first time the list is that long: the name to type over,
-- a cell for each slot the bar shows, and the three buttons.
local function Line(index)
    local panel = SL.panel
    local line = panel.lines[index]
    if line then return line end
    line = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    line:SetSize(SL.WIDTH - SL.PAD * 2, SL.ROW)
    line:SetBackdrop(Rows().BACKDROP)
    line:SetBackdropColor(.06, .07, .085, 1)
    line:SetBackdropBorderColor(.19, .2, .24, 1)
    local box = CreateFrame("EditBox", nil, line, "BackdropTemplate")
    box:SetSize(SL.NAME, 22)
    box:SetPoint("LEFT", line, "LEFT", 4, 0)
    box:SetBackdrop(Rows().BACKDROP)
    box:SetBackdropColor(Rows().TICK_FILL[1], Rows().TICK_FILL[2], Rows().TICK_FILL[3], 1)
    box:SetBackdropBorderColor(Rows().TICK_EDGE[1], Rows().TICK_EDGE[2], Rows().TICK_EDGE[3], 1)
    local font, _, flags = GameFontHighlight:GetFont()
    box:SetFont(font, 12, flags or "")
    box:SetTextColor(.94, .95, .98)
    box:SetTextInsets(6, 6, 0, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(Sets().NAME_LETTERS)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self.cancelled = true; self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", NameGained)
    box:SetScript("OnEditFocusLost", NameDone)
    box.line = line
    line.nameBox = box
    -- A cell for each slot, in the bar's own order: the item the set holds
    -- for it, or the empty slot's own art, faded.
    line.cells = {}
    for at, info in ipairs(K().SLOTS) do
        local cell = CreateFrame("Frame", nil, line)
        cell:SetSize(SL.CELL, SL.CELL)
        cell:SetPoint("LEFT", box, "RIGHT", 8 + (at - 1) * (SL.CELL + SL.CELL_GAP), 0)
        cell:EnableMouse(true)
        cell.info = info
        cell.art = cell:CreateTexture(nil, "ARTWORK")
        cell.art:SetAllPoints(cell)
        cell:SetScript("OnEnter", function(self)
            Tip(self, self.itemName or self.info.label, self.itemName and self.info.label or "No item saved for this slot.")
        end)
        cell:SetScript("OnLeave", Untip)
        line.cells[at] = cell
    end
    line.delete = Rows().Button(line, "Delete", SL.BUTTON + 10, 22)
    line.delete:SetPoint("RIGHT", line, "RIGHT", -4, 0)
    line.delete:SetScript("OnClick", DeleteClick)
    line.over = Rows().Button(line, "Save Over", SL.BUTTON + 10, 22)
    line.over:SetPoint("RIGHT", line.delete, "LEFT", -6, 0)
    line.over:SetScript("OnClick", OverClick)
    line.load = Rows().Button(line, "Load", SL.BUTTON, 22, true)
    line.load:SetPoint("RIGHT", line.over, "LEFT", -6, 0)
    line.load:SetScript("OnClick", LoadClick)
    -- The key this set answers to, left of Load: a long key name is cut
    -- rather than let out over the cells beside it.
    line.key = Rows().Button(line, SL.NO_KEY, SL.KEY, 22)
    line.key:SetPoint("RIGHT", line.load, "LEFT", -6, 0)
    line.key:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    line.key:SetScript("OnClick", KeyClick)
    line.key.label:ClearAllPoints()
    line.key.label:SetPoint("LEFT", line.key, "LEFT", 5, 0)
    line.key.label:SetPoint("RIGHT", line.key, "RIGHT", -5, 0)
    line.key.label:SetJustifyH("CENTER")
    line.key.label:SetWordWrap(false)
    line.key:SetScript("OnEnter", function(self)
        local set = self.line and self.line.set
        local slot = set and set.key
        local keys = Keys()
        local key = slot and keys and keys.KeyText and keys.KeyText(slot)
        Tip(self, SL.Listening(self.line) and "Press a key" or (key and ("On " .. key)) or SL.NO_KEY, {
            SL.Listening(self.line) and "Press the key you want, Ctrl and Shift included. Escape leaves it as it was."
                or key and "Press that key and this set goes on, wherever the trinkets are sitting."
                or "This set loads when you click Load, until you put a key on it.",
            SL.Listening(self.line) and "A key already used elsewhere is taken for this."
                or "Left-click, then press a key. Right-click takes the key off.",
        })
    end)
    line.key:SetScript("OnLeave", Untip)
    for _, button in ipairs({line.key, line.load, line.over, line.delete}) do button.line = line end
    line:Hide()
    panel.lines[index] = line
    return line
end

---------------------------------------------------------------------------
-- Building the panel
---------------------------------------------------------------------------

local function SaveClick()
    SL.EndTyping()
    local sets = Sets()
    local index = sets.New()
    local set = sets.Set(index)
    SL.armed = nil
    SL.Say("Saved " .. (set and set.name or "a set") .. ".")
    SL.Refresh()
end

function SL.Build(parent, row)
    local panel = E.ClassTools.SubPanel(parent, row, SL.WIDTH)
    panel:SetHeight(SL.LIST_TOP + SL.ROW_STEP + SL.BOTTOM)
    panel.lines = {}
    SL.panel = panel
    panel.top = Text(panel, SL.TOP_HINT, 11, true, 2)
    panel.top:SetWidth(SL.WIDTH - SL.PAD * 2)
    panel.top:SetPoint("TOPLEFT", panel, "TOPLEFT", SL.PAD, -12)
    panel.save = Rows().Button(panel, "Save What I'm Wearing", 210, 24, true)
    panel.save:SetPoint("TOPLEFT", panel, "TOPLEFT", SL.PAD, -50)
    panel.save:SetScript("OnClick", SaveClick)
    panel.none = Text(panel, SL.NONE, 12, true)
    panel.none:SetPoint("TOPLEFT", panel, "TOPLEFT", SL.PAD, -SL.LIST_TOP - 4)
    return panel
end

-- The panel under the Your Sets row, built once and moved under it each time
-- that page opens.
function SL.Attach(frame, row)
    if not (Sets() and K() and E.ClassTools) then return end
    local parent = row:GetParent()
    if not SL.panel then SL.Build(parent, row) end
    local panel = SL.panel
    if panel:GetParent() ~= parent then panel:SetParent(parent) end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -6)
    panel:Show()
    SL.frame = frame
    SL.Refresh()
end

-- Put away with its row (the page changed, a search, or the bar switched
-- off). What it said is about the last thing you did while it was open, so it
-- goes with it: opening the page again would otherwise report a set deleted
-- or loaded minutes ago as though it had just happened.
function SL.Hide()
    if not SL.panel then return end
    SL.EndTyping()
    Untip()
    SL.armed = nil
    SL.Say(nil)
    SL.panel:Hide()
end

---------------------------------------------------------------------------
-- Drawing it
---------------------------------------------------------------------------

-- Every line as the sets now stand, and the panel as tall as it takes: /era
-- is told of the new size, so its own page scrolls and no set is ever out of
-- reach however many you keep.
function SL.Refresh()
    local panel = SL.panel
    if not (panel and panel:IsShown()) then return end
    local kit, sets = K(), Sets()
    local shown = kit.Shown()
    local list = sets.Sets()
    local y = SL.LIST_TOP
    -- Anything else done in the panel takes Delete's question back.
    SL.armed = nil
    for index = 1, math.max(#list, #panel.lines) do
        local set = list[index]
        local line = set and Line(index) or panel.lines[index]
        if line and set then
            line.set = set
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", panel, "TOPLEFT", SL.PAD, -y)
            y = y + SL.ROW_STEP
            if not line.nameBox:HasFocus() then line.nameBox:SetText(set.name) end
            for at, cell in ipairs(line.cells) do
                local info = shown[at]
                if info then
                    cell.info = info
                    local id = set.items[info.slot]
                    local name, icon
                    if id then name, icon = kit.ById(id) end
                    cell.itemName = id and (name or "Item") or nil
                    cell.art:SetTexture(icon or kit.EmptyArt(info))
                    cell.art:SetDesaturated(id == nil)
                    cell.art:SetAlpha(id and 1 or .4)
                    cell:Show()
                else
                    cell.itemName = nil
                    cell:Hide()
                end
            end
            line.key.label:SetText(KeyText(set, line))
            line.delete.label:SetText("Delete")
            line:Show()
        elseif line then
            line.set = nil
            -- A line that goes takes its own hover box with it, if that box
            -- is the one on screen.
            for _, cell in ipairs(line.cells) do Untip(cell) end
            Untip(line.key)
            line:Hide()
        end
    end
    panel.none:SetShown(#list == 0)
    panel:SetHeight(SL.LIST_TOP + math.max(1, #list) * SL.ROW_STEP + SL.BOTTOM)
    panel.hint:SetText(SL.said or "")
end
