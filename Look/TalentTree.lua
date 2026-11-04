-- The talent window's tree (Classic look, registry "talents"): one pass
-- that reads the tree afresh and draws the selected tab (texts, tabs, class
-- background, talents in their sockets, branch lines and arrow heads, the
-- foot's buttons), the talents' tooltips in EraUI's own tooltip, and what a
-- click does: a left click stages a rank, a right click takes a staged one
-- back, Apply Changes learns what is staged, the undo button throws it away.
-- Nothing is learned in a fight or while looking at another player's trees.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local T = Look.Talent
local parts = T.parts

local TALENT_FOLDER = "Interface\\TalentFrame\\"
local SOCKET = "Interface\\Buttons\\UI-EmptySlot-White"
local NO_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local STATE_COLOURS = { learned = T.GOLD, open = T.GREEN, locked = T.GREY }

local pool = {}               -- position in the tab: talent button
local shows = Look.Weak()     -- talent button: the talent it shows
local pieces = Look.Weak()    -- talent button: { icon, socket, plate, rank }
local lineArt, headArt = {}, {} -- pooled link textures

---------------------------------------------------------------------------
-- Talent buttons
---------------------------------------------------------------------------

local function TalentTip(button)
    local talent, picture = shows[button], T.model
    if not (talent and picture) then return end
    local tab = picture.tabs[T.tab]
    Look.ShowTip(button, "RIGHT", T.TipRows(picture, talent, tab and tab.name))
end
T.ShowTalentTip = TalentTip

local function Entered(button)
    T.hovered = button
    TalentTip(button)
end

local function Left(button)
    if T.hovered == button then T.hovered = nil end
    Look.HideTip(button)
end

local function Clicked(button, mouse)
    local talent = shows[button]
    if talent and T.Stage(talent, mouse == "RightButton") and Look.TipOwner() == button then TalentTip(button) end
end

-- A texture of the button's own: layer, file, size, and its centre.
local function Face(button, purpose, layer, file, size, x, y, relativePoint)
    local face = Look.OwnTexture(button, purpose, layer)
    face:SetTexture(file)
    face:SetSize(size, size)
    Look.Pin(face, "CENTER", button, relativePoint or "CENTER", x, y)
    return face
end

local function TalentButton(slot)
    if pool[slot] then return pool[slot] end
    local button = Look.Build("Button", parts.child, nil, { size = { 37, 37 } })
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local own = {}
    own.icon = Look.OwnTexture(button, "icon", "BORDER")
    Look.Inside(own.icon, button, 2, 2, 2, 2)
    own.socket = Face(button, "socket", "BACKGROUND", SOCKET, 64, 0, -1)
    own.plate = Face(button, "plate", "OVERLAY", TALENT_FOLDER .. "TalentFrame-RankBorder", 32, -2, 2, "BOTTOMRIGHT")
    own.rank = Look.OwnLabel(button, "rank", "GameFontNormalSmall", "OVERLAY")
    Look.Pin(own.rank, "CENTER", own.plate, "CENTER", 0, 0)
    local glow = Look.OwnTexture(button, "glow", "HIGHLIGHT")
    glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    glow:SetBlendMode("ADD")
    Look.Fill(glow, own.icon)
    button:SetScript("OnClick", Clicked)
    button:SetScript("OnEnter", Entered)
    button:SetScript("OnLeave", Left)
    pieces[button], pool[slot] = own, button
    return button
end

local function ShowTalent(button, talent)
    local own = pieces[button]
    shows[button] = talent
    local x, y = T.Cell(talent)
    Look.Pin(button, "TOPLEFT", parts.child, "TOPLEFT", x, y)
    own.icon:SetTexture(talent.icon or NO_ICON)
    local state = T.State(talent)
    local colour = STATE_COLOURS[state]
    own.icon:SetDesaturated(state == "locked")
    own.socket:SetVertexColor(colour[1], colour[2], colour[3])
    own.rank:SetTextColor(colour[1], colour[2], colour[3])
    own.rank:SetText(T.Whole(talent.ranks))
    local plated = talent.ranks >= 1 or talent.canBuy
    Look.Shown(own.plate, plated)
    Look.Shown(own.rank, plated)
    button:Show()
end

---------------------------------------------------------------------------
-- Branch lines (under the talents) and arrow heads (over them)
---------------------------------------------------------------------------

local function Pooled(store, slot, owner, purpose, layer, file)
    local texture = store[slot]
    if not texture then
        texture = Look.OwnTexture(owner, purpose .. slot, layer)
        texture:SetTexture(file)
        store[slot] = texture
    end
    return texture
end

local function DrawLinks(picture, tab)
    local lines, heads = 0, 0
    for _, link in ipairs(T.Links(picture, tab)) do
        for _, piece in ipairs(T.LinkPieces(link.from, link.to)) do
            local art = T.LINK_ART[piece.kind]
            local texture
            if art.head then
                heads = heads + 1
                texture = Pooled(headArt, heads, parts.heads, "head", "ARTWORK", TALENT_FOLDER .. "UI-TalentArrows")
            else
                lines = lines + 1
                texture = Pooled(lineArt, lines, parts.child, "line", "ARTWORK", TALENT_FOLDER .. "UI-TalentBranches")
            end
            local crop = link.lit and art[1] or art[2]
            Look.Crop(texture, crop[1], crop[2], crop[3], crop[4])
            texture:SetSize(piece.w, piece.h)
            Look.Pin(texture, "TOPLEFT", parts.child, "TOPLEFT", piece.x, piece.y)
            texture:Show()
        end
    end
end

-- Every line and head put away, and every talent button past the first
-- `keep` (the start of each pass). A button the pass fills again is never
-- hidden in between: the game takes the mouse off a button that hides, so
-- the hovered talent would lose its tooltip on every refresh.
local function PutAway(keep)
    for slot, button in ipairs(pool) do
        if slot > keep then
            button:Hide()
            shows[button] = nil
        end
    end
    for _, texture in ipairs(lineArt) do texture:Hide() end
    for _, texture in ipairs(headArt) do texture:Hide() end
end

---------------------------------------------------------------------------
-- The words, tabs, background and foot
---------------------------------------------------------------------------

-- A unit's name (UnitName's first value) or class token (UnitClass's
-- second), or nil when it can't be read or is hidden.
local function UnitWord(unit, read)
    local fine, first, second = pcall(read, unit)
    local value = first
    if read == UnitClass then value = second end
    if fine and not Look.Secret(value) and type(value) == "string" and value ~= "" then return value end
    return nil
end

local function Words(picture, tab)
    local name = T.unit and UnitName and UnitWord(T.unit, UnitName)
    parts.title:SetText(name or T.Say("TALENTS", "Talents"))
    parts.spent:SetText("Points spent in " .. tab.name .. " Talents: |cffffffff" .. T.Whole(tab.spent) .. "|r")
    if picture.inspecting then
        parts.points:SetText("")
    else
        parts.points:SetText(T.Say("TALENT_POINTS", "Talent Points") .. ": |cffffffff" .. T.Whole(picture.unspent) .. "|r")
    end
end

local function TabRow(picture)
    for index, tab in ipairs(parts.tabs or {}) do
        local data = picture and picture.tabs[index]
        if data then
            T.NameTab(tab, data.name)
            T.RaiseTab(tab, index == T.tab)
        end
        Look.Shown(tab, data ~= nil)
    end
end

-- The class's 1.x background for the selected tab, stretched over the whole
-- scroll child (the view crops its right side); none for another class.
local function Backdrop(childHeight)
    local class = UnitClass and UnitWord(T.unit or "player", UnitClass)
    local names = class and T.BACKDROPS[class]
    local name = names and names[T.tab]
    for corner, texture in pairs(parts.back) do
        if name then
            local upper = corner:sub(1, 3) == "Top"
            texture:SetTexture(TALENT_FOLDER .. name .. "-" .. corner)
            texture:SetSize(corner:find("Left") and 256 or 64, childHeight * (upper and 256 or 75) / 331)
            Look.Crop(texture, 0, 1, 0, upper and 1 or 75 / 128)
        end
        Look.Shown(texture, name ~= nil)
    end
end

-- Apply and undo usable exactly while something is staged.
local function Foot(picture)
    local staged = picture.staged == true
    parts.apply:SetEnabled(staged)
    parts.undo:SetEnabled(staged)
    parts.undoMark:SetDesaturated(not staged)
    parts.undoMark:SetAlpha(staged and 1 or 0.5)
end

---------------------------------------------------------------------------
-- The pass
---------------------------------------------------------------------------

function T.Refresh()
    if not (T.window and T.active) then return end
    local picture = T.ReadTree(T.unit ~= nil)
    T.model = picture
    if not picture then
        PutAway(0)
        TabRow(nil)
        return
    end
    if T.tab > #picture.tabs then T.tab = 1 end
    local tab = picture.tabs[T.tab]
    PutAway(#tab.nodes)
    Words(picture, tab)
    TabRow(picture)
    local childHeight = T.ChildHeight(tab.tiers)
    parts.child:SetHeight(childHeight)
    Backdrop(childHeight)
    Look.ScrollRange(parts.bar, childHeight - T.VIEW_H, 20)
    for slot, talent in ipairs(tab.nodes) do ShowTalent(TalentButton(slot), talent) end
    DrawLinks(picture, tab)
    Foot(picture)
    -- The talent still under the mouse keeps a tooltip of what it shows now.
    local hovered = T.hovered
    if hovered and shows[hovered] and Look.TipOwner() == hovered then TalentTip(hovered) end
end

---------------------------------------------------------------------------
-- Tabs and learning
---------------------------------------------------------------------------

function T.SelectTab(index)
    if index == T.tab then return end
    T.tab = index
    T.Sound("IG_CHARACTER_INFO_TAB")
    parts.bar:SetValue(0)
    T.Refresh()
end

-- A left click stages a rank (when one can be bought), a right click takes
-- one back (when it can be). Refused in a fight and while inspecting.
-- True when the click was taken.
function T.Stage(talent, refund)
    local picture, traits = T.model, C_Traits
    if not picture or picture.inspecting or Look.InFight() then return false end
    if type(traits) == "table" then
        if refund and talent.canRefund then
            T.Ask(traits.RefundRank, picture.config, talent.id)
        elseif not refund and talent.canBuy then
            T.Ask(traits.PurchaseRank, picture.config, talent.id)
        end
    end
    T.Refresh()
    return true
end

local function Note(line)
    if type(ns.Persist) == "function" then pcall(ns.Persist, line) end
end

-- Learns what is staged. Forever's own commit first (no saved loadout),
-- else the trait tree's; the game's "too fast" message when it refuses.
function T.ApplyStaged()
    local picture = T.model
    if not picture or picture.inspecting or Look.InFight() then return end
    local talents, traits = C_ClassTalents, C_Traits
    local commit = type(talents) == "table" and talents.CommitConfig
    if type(commit) == "function" then
        local called, result = pcall(commit, nil)
        local said = Look.Secret(result) and "<hidden>" or tostring(result)
        Note("talents: commit called=" .. tostring(called) .. " result=" .. said)
        local tooFast = TALENT_FRAME_CONFIG_OPERATION_TOO_FAST
        if called and not Look.Secret(result) and result == false and UIErrorsFrame and type(tooFast) == "string" then
            UIErrorsFrame:AddMessage(tooFast, T.RED[1], T.RED[2], T.RED[3])
        end
    elseif type(traits) == "table" and type(traits.CommitConfig) == "function" then
        pcall(traits.CommitConfig, picture.config)
    end
    T.Refresh()
end

-- Throws away what is staged.
function T.ResetStaged()
    local picture, traits = T.model, C_Traits
    if picture and not picture.inspecting and type(traits) == "table" then T.Ask(traits.RollbackConfig, picture.config) end
    T.Sound("IG_MAINMENU_OPTION_CHECKBOX_OFF")
    T.Refresh()
end
