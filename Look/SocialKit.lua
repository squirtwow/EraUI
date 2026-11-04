-- The social area's kit (Classic look, spec 10: the social window's Who and
-- Guild pages, the friends key's way back to the classic window and the
-- group finder's dressing). What the area's files share, on Look.Social:
--   * the Classic settings the area reads, with their defaults (only where
--     the engine has none of its own);
--   * the 1.x art the two lists draw, by key;
--   * small readers: the game's words with a fallback, readable text and
--     counts, the class colours, "is this me?";
--   * the pieces both lists are made of: the stone header band, the column
--     header, the faint section box, the list rows with their gold glow,
--     and the black right-click menu.
-- Nothing here touches the game's frames.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local S = { who = { parts = {} }, guild = { parts = {} }, notes = {}, finder = {} }
Look.Social = S

do
    local engine = type(ns.DB_DEFAULTS) == "table" and ns.DB_DEFAULTS or nil
    local wanted = { whoList = true, guildRoster = true, whoTabs = false, whoColumn = "zone" }
    if engine then
        for key, value in pairs(wanted) do
            if engine[key] == nil then engine[key] = value end
        end
    end
end

---------------------------------------------------------------------------
-- Art (none of it Dark Mode's: the headers, the pill and the glows keep
-- their colours)
---------------------------------------------------------------------------

do
    local define, BUTTONS = Look.DefineArt, "Interface\\Buttons\\"
    define("socialRowGlow", "Interface\\QuestFrame\\UI-QuestLogTitleHighlight", "UI-QuestLogTitleHighlight")
    define("socialColumnTabs", "Interface\\FriendsFrame\\WhoFrame-ColumnTabs")
    define("socialFilterBorder", "Interface\\ClassTrainerFrame\\UI-ClassTrainer-FilterBorder")
    -- Shared with the spellbook's kit (the same files), set here too for
    -- when this area is loaded on its own.
    local shared = {
        sbNextUp = "UI-SpellbookIcon-NextPage-Up", sbNextDown = "UI-SpellbookIcon-NextPage-Down",
        sbPrevUp = "UI-SpellbookIcon-PrevPage-Up", sbPrevDown = "UI-SpellbookIcon-PrevPage-Down",
        mouseHighlight = "UI-Common-MouseHilight",
    }
    for key, file in pairs(shared) do
        if not Look.ART[key] then define(key, BUTTONS .. file, file) end
    end
    if not Look.ART.sbSkillTab then
        define("sbSkillTab", "Interface\\Spellbook\\SpellBook-SkillLineTab", "SpellBook-SkillLineTab")
    end
end

S.GOLD = { 1, 0.82, 0 }
S.GREY = { 0.5, 0.5, 0.5 }
S.WHITE = { 1, 1, 1 }

---------------------------------------------------------------------------
-- Small readers
---------------------------------------------------------------------------

-- The game's word for something, or the fallback while it has none.
function S.Say(globalName, fallback)
    local word = _G[globalName]
    if type(word) == "string" and word ~= "" then return word end
    return fallback
end

-- Text that can be read, or the fallback.
function S.Text(value, fallback)
    if type(value) == "string" and not Look.Secret(value) then return value end
    return fallback
end

-- A count that can be used, or 0.
function S.Count(value)
    return Look.Number(value) or 0
end

function S.Now()
    return type(GetTime) == "function" and (Look.Number(GetTime()) or 0) or 0
end

-- A quiet call of an API the client may lack: ok, then its results.
function S.Call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

-- True only for a readable true.
function S.Yes(fn, ...)
    local fine, answer = S.Call(fn, ...)
    return fine and not Look.Secret(answer) and answer == true
end

function S.Lower(text)
    return type(text) == "string" and text:lower() or ""
end

function S.Sound(kitName)
    local kit = SOUNDKIT and SOUNDKIT[kitName]
    if kit and type(PlaySound) == "function" then pcall(PlaySound, kit) end
end

function S.RedLine(text)
    local errors = UIErrorsFrame
    if errors and errors.AddMessage then errors:AddMessage(text, 1, 0.1, 0.1) end
end

function S.NotInFight()
    S.RedLine(S.Say("ERR_NOT_IN_COMBAT", "You can't do that while in combat"))
end

function S.NextFrame(fn)
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0, fn) else fn() end
end

-- A class's colour from its file name, white when unknown.
function S.ClassColour(classFile)
    local colours = RAID_CLASS_COLORS
    local colour = type(classFile) == "string" and type(colours) == "table" and colours[classFile] or nil
    if type(colour) == "table" and Look.Number(colour.r) then return colour.r, colour.g, colour.b end
    return 1, 1, 1
end

-- Whether a name (and GUID) is you: Forever's names are "First Surname".
function S.Mine(name, guid)
    if type(EraUI.IsPlayer) ~= "function" then return false end
    local fine, answer = pcall(EraUI.IsPlayer, EraUI, name, guid)
    return fine and answer == true
end

function S.Colour(text, rgb)
    text:SetTextColor(rgb[1], rgb[2], rgb[3])
end

---------------------------------------------------------------------------
-- The pieces both lists are made of
---------------------------------------------------------------------------

-- A frame with a faint warm wash (the old section box); the caller sizes it.
function S.SectionBox(parent)
    local box = Look.Build("Frame", parent, nil, { size = { 100, 40 } })
    local wash = Look.OwnTexture(box, "wash", "BACKGROUND")
    wash:SetColorTexture(1, 0.96, 0.88, 0.03)
    Look.Fill(wash, box)
    return box
end

-- The stone band behind a list's column headers: 22 tall, its top 1 above
-- the page's, reaching 3 past the page on each side (the window's edge
-- less 5).
function S.HeaderBand(page)
    local band = Look.Build("Frame", page, nil, { size = { 100, 22 } })
    band:SetPoint("TOPLEFT", page, "TOPLEFT", -3, 1)
    band:SetPoint("TOPRIGHT", page, "TOPRIGHT", 3, 1)
    local stone = Look.StoneFill(band, "BACKGROUND")
    Look.Fill(stone, band)
    return band
end

-- A column header (column: { key, label, width }): the old tab art in three
-- pieces, the label 8 in, a faint gold glow. Its left at the previous
-- header's right (or the row's left).
local TAB_FILE_ROWS = 0.625
function S.ColumnHeader(parent, column, previous, onClick)
    local header = Look.Build("Button", parent, nil, { size = { column.width, 20 } })
    if previous then
        Look.Pin(header, "LEFT", previous, "RIGHT", 0, 0)
    else
        Look.Pin(header, "LEFT", parent, "LEFT", 0, 0)
    end
    local left = Look.OwnTexture(header, "tabLeft", "BACKGROUND")
    local right = Look.OwnTexture(header, "tabRight", "BACKGROUND")
    local middle = Look.OwnTexture(header, "tabMiddle", "BACKGROUND")
    for piece, crop in pairs({ [left] = { 0, 0.078125 }, [right] = { 0.90625, 0.96875 }, [middle] = { 0.078125, 0.90625 } }) do
        Look.Art(piece, "socialColumnTabs")
        Look.Crop(piece, crop[1], crop[2], 0, TAB_FILE_ROWS)
    end
    left:SetSize(5, 20)
    Look.Pin(left, "TOPLEFT", header, "TOPLEFT", 0, 0)
    right:SetSize(4, 20)
    Look.Pin(right, "TOPRIGHT", header, "TOPRIGHT", 0, 0)
    middle:ClearAllPoints()
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    local label = Look.OwnLabel(header, "label", "GameFontHighlightSmall", "ARTWORK")
    Look.Pin(label, "LEFT", header, "LEFT", 8, 0)
    header:SetFontString(label)
    label:SetText(column.label)
    local glow = Look.OwnTexture(header, "glow", "HIGHLIGHT")
    glow:SetColorTexture(1, 0.82, 0, 0.12)
    Look.Inside(glow, header, 4, 2, 4, 2)
    header:SetScript("OnClick", onClick)
    return header
end

-- The gold title glow on a list row (its selected mark and its hover).
local function RowGlow(texture)
    Look.Art(texture, "socialRowGlow")
    texture:SetBlendMode("ADD")
    texture:SetVertexColor(1, 0.82, 0, 1)
    Look.Crop(texture, 0, 0.97, 0, 1)
end
S.RowGlow = RowGlow

-- A list row: 16 tall, the i-th down the area, its width; left and right
-- clicks; four small texts, left-justified, never wrapped. What a row holds
-- is kept here (rowParts), never on the row.
S.rowParts = Look.Weak() -- row: { mark, texts }

function S.LayRow(row, columns)
    local parts = S.rowParts[row]
    for c, column in ipairs(columns) do
        local text = parts.texts[c]
        Look.Pin(text, "LEFT", row, "LEFT", column.x, 0)
        text:SetWidth(column.width)
    end
end

function S.ListRow(area, i, columns)
    local row = Look.Build("Button", area, nil, { size = { 100, 16 } })
    local down = -(i - 1) * 16
    row:SetPoint("TOPLEFT", area, "TOPLEFT", 0, down)
    row:SetPoint("TOPRIGHT", area, "TOPRIGHT", 0, down)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local mark = Look.OwnTexture(row, "chosen", "BACKGROUND")
    RowGlow(mark)
    Look.Fill(mark, row)
    mark:Hide()
    local hover = Look.OwnTexture(row, "hover", "HIGHLIGHT")
    RowGlow(hover)
    Look.Fill(hover, row)
    local texts = {}
    for c = 1, 4 do
        local text = Look.OwnLabel(row, "text" .. c, "GameFontHighlightSmall", "ARTWORK")
        text:SetJustifyH("LEFT")
        if text.SetWordWrap then text:SetWordWrap(false) end
        texts[c] = text
    end
    S.rowParts[row] = { mark = mark, texts = texts }
    S.LayRow(row, columns)
    return row
end

-- How many rows fit the area (16 each, at least one).
function S.RowsShown(area)
    local tall = Look.Number(area:GetHeight()) or 0
    return math.max(1, math.floor(tall / 16))
end

-- The mouse wheel on a list area: one row a notch (up: towards the top).
function S.Wheel(area, bar)
    area:EnableMouseWheel(true)
    area:SetScript("OnMouseWheel", function(_, delta)
        local value = Look.Number(bar:GetValue()) or 0
        bar:SetValue(value - (Look.Number(delta) or 0))
    end)
end

---------------------------------------------------------------------------
-- The right-click menu: a black panel with a silver line round it, a gold
-- title, one 15-tall item per allowed entry and Cancel last, at the cursor.
-- entries: { { text, action(entry), allowed(entry) or nil }, ... }.
-- Returns { frame, items, entry, Open(entry, title), Close(), Follow(frame),
-- IsShown() }.
---------------------------------------------------------------------------

local function Edge(panel, side)
    local line = Look.OwnTexture(panel, "edge" .. side, "BORDER")
    line:SetColorTexture(0.62, 0.62, 0.6, 1)
    if side == "TOP" or side == "BOTTOM" then
        line:SetHeight(1)
        line:SetPoint(side .. "LEFT", panel, side .. "LEFT")
        line:SetPoint(side .. "RIGHT", panel, side .. "RIGHT")
    else
        line:SetWidth(1)
        line:SetPoint("TOP" .. side, panel, "TOP" .. side)
        line:SetPoint("BOTTOM" .. side, panel, "BOTTOM" .. side)
    end
end

local function SameEntry(a, b)
    if a == nil or b == nil then return false end
    if a == b then return true end
    return type(a) == "table" and type(b) == "table" and a.name ~= nil and a.name == b.name
end

local menusMade = 0

local function MenuItem(menu, frame, item)
    local button = Look.Build("Button", frame, nil, { size = { 128, 15 } })
    Look.Pin(button, "TOPLEFT", frame, "TOPLEFT", 6, -18) -- re-stacked as the menu opens
    local label = Look.OwnLabel(button, "label", "GameFontHighlightSmall", "ARTWORK")
    Look.Pin(label, "LEFT", button, "LEFT", 4, 0)
    label:SetText(item.text)
    local glow = Look.OwnTexture(button, "glow", "HIGHLIGHT")
    glow:SetColorTexture(1, 0.82, 0, 0.16)
    Look.Fill(glow, button)
    button:SetScript("OnClick", function()
        local entry = menu.entry
        frame:Hide()
        if item.action then Look.Try(item.action, entry) end
    end)
    return button
end

local function Allowed(item, entry)
    if not item.allowed then return true end
    local fine, answer = pcall(item.allowed, entry)
    return fine and answer and true or false
end

function S.RowMenu(entries)
    menusMade = menusMade + 1
    local menu = { items = {}, buttons = {}, owner = "socialMenu" .. menusMade }
    local frame = Look.Build("Frame", UIParent, nil, { size = { 140, 24 }, strata = "DIALOG", mouse = true,
        clamped = true, hidden = true })
    Look.Pin(frame, "TOPLEFT", UIParent, "TOPLEFT", 0, 0) -- moved to the cursor as it opens
    menu.frame = frame
    local fill = Look.OwnTexture(frame, "fill", "BACKGROUND")
    fill:SetColorTexture(0, 0, 0, 0.94)
    Look.Fill(fill, frame)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do Edge(frame, side) end
    local title = Look.OwnLabel(frame, "title", "GameFontNormalSmall", "OVERLAY")
    S.Colour(title, S.GOLD)
    Look.Pin(title, "TOP", frame, "TOP", 0, -4)
    for _, entry in ipairs(entries) do
        menu.items[#menu.items + 1] = { text = entry[1], action = entry[2], allowed = entry[3] }
    end
    menu.items[#menu.items + 1] = { text = S.Say("CANCEL", "Cancel") }
    for i, item in ipairs(menu.items) do menu.buttons[i] = MenuItem(menu, frame, item) end
    frame:SetScript("OnHide", function() menu.entry = nil end)
    Look.Listen(frame, "GLOBAL_MOUSE_DOWN")
    frame:SetScript("OnEvent", function()
        if not frame:IsShown() or frame:IsMouseOver() then return end
        menu.dropped, menu.droppedAt = menu.entry, S.Now()
        frame:Hide()
    end)

    function menu.Close() frame:Hide() end
    function menu.IsShown() return frame:IsShown() end
    local followed = Look.Weak()
    function menu.Follow(other)
        if not other or followed[other] then return end
        followed[other] = true
        Look.HookScript(other, "OnHide", function() frame:Hide() end, menu.owner)
    end
    function menu.Open(entry, heading)
        if frame:IsShown() and SameEntry(menu.entry, entry) then
            frame:Hide()
            return
        end
        if SameEntry(menu.dropped, entry) and S.Now() - (menu.droppedAt or -10) < 0.4 then return end
        menu.entry = entry
        title:SetText(heading or "")
        local shown = 0
        for i, item in ipairs(menu.items) do
            local button = menu.buttons[i]
            if Allowed(item, entry) then
                local down = -18 - shown * 15
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, down)
                button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, down)
                button:Show()
                shown = shown + 1
            else
                button:Hide()
            end
        end
        frame:SetHeight(24 + 15 * shown)
        local x, y = 0, 0
        if type(GetCursorPosition) == "function" then x, y = GetCursorPosition() end
        local scale = Look.Number(UIParent:GetEffectiveScale()) or 1
        if scale <= 0 then scale = 1 end
        Look.Pin(frame, "TOPLEFT", UIParent, "BOTTOMLEFT", (Look.Number(x) or 0) / scale, (Look.Number(y) or 0) / scale)
        frame:Show()
        if frame.Raise then frame:Raise() end
    end
    return menu
end
