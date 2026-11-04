-- Two small pieces of the unit frames' look:
--   * the raid manager's fold tab (CompactRaidFrameManager), moved to the
--     manager's top right with EraUI's own mirrored "forward" art, its
--     background hidden while folded (part of "unitFrames");
--   * the buff frame's fold arrow, invisible until the mouse comes within 6
--     units of it, still there to click (its own entry, "hideBuffArrow").
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local UF = Look.UF

---------------------------------------------------------------------------
-- The raid manager's tab
---------------------------------------------------------------------------

local tabArt = Look.Weak() -- the tab button: { mirrored, middle, hover }
local touched = Look.Weak() -- managers EraUI has dressed (only those are given back)
local FACES = Look.Words("Normal Pushed Disabled Highlight")

-- The tab button's own four state faces at one alpha.
local function FacesTo(tab, alpha)
    for index = 1, #FACES do
        local asked, face = Look.Ask(tab, "Get" .. FACES[index] .. "Texture")
        if asked then Look.Alpha(face, alpha) end
    end
end

-- The game lights its own faces on hover: off again while EraUI's art shows.
local function AfterHover(tab)
    local art = tabArt[tab]
    if art and art[1]:IsShown() then FacesTo(tab, 0) end
end

-- One texture of EraUI's on the tab, from the atlas's file and coordinates.
local function Piece(tab, layer, file, left, right, top, bottom)
    local made = tab:CreateTexture(nil, layer)
    made:SetTexture(file)
    made:SetTexCoord(left, right, top, bottom)
    return made
end

-- Made once from the atlas gm-btnforward-normal: the whole tab mirrored
-- left to right, the middle 36% of it (not mirrored) over that, and a faint
-- white hover.
local function TabArt(tab)
    if tabArt[tab] then return tabArt[tab] end
    local reader = C_Texture and C_Texture.GetAtlasInfo
    local ok, info = false, nil
    if type(reader) == "function" then ok, info = pcall(reader, "gm-btnforward-normal") end
    local file = ok and type(info) == "table" and (info.file or info.filename)
    if not file then return nil end
    local l, r = Look.Number(info.leftTexCoord) or 0, Look.Number(info.rightTexCoord) or 1
    local t, b = Look.Number(info.topTexCoord) or 0, Look.Number(info.bottomTexCoord) or 1
    local mirrored = Piece(tab, "BACKGROUND", file, r, l, t, b)
    Look.Fill(mirrored, tab)
    local third = (r - l) * 0.32
    local middle = Piece(tab, "ARTWORK", file, l + third, r - third, t, b)
    middle:SetPoint("TOP", tab, "TOP")
    middle:SetPoint("BOTTOM", tab, "BOTTOM")
    middle:SetWidth(math.max(1, (Look.Number(tab:GetWidth()) or 0) * 0.36))
    local hover = tab:CreateTexture(nil, "HIGHLIGHT")
    Look.Fill(hover, tab)
    hover:SetColorTexture(1, 1, 1, 0.12)
    tabArt[tab] = { mirrored, middle, hover }
    Look.HookScript(tab, "OnEnter", AfterHover)
    Look.HookScript(tab, "OnLeave", AfterHover)
    return tabArt[tab]
end

local function RaidManager()
    local found = CompactRaidFrameManager
    return type(found) == "table" and found or nil
end

-- Acts only when the manager folds or opens (a pass forgets what it saw).
-- The background follows at once; the manager is secure, so its tab is
-- moved out of a fight only (the pass after it).
function UF.RaidTab()
    local holder = UF.active and RaidManager()
    if not holder then return end
    local folded = holder.collapsed and true or false
    if UF.raidSeen == folded then return end
    touched[holder] = true
    Look.Alpha(holder.Background, folded and 0 or 1)
    if Look.InFight() then
        UF.waiting = true
        return
    end
    UF.raidSeen = folded
    local tab = holder.toggleButtonForward
    if not tab then return end
    Look.Pin(tab, "TOPRIGHT", holder, "TOPRIGHT", -7, 0)
    local art = TabArt(tab)
    if art then
        for _, piece in ipairs(art) do piece:Show() end
        FacesTo(tab, 0)
    end
end

-- Runs on every pass while the look is off, so a manager EraUI never
-- dressed (the look off since login) is left entirely to the game.
function UF.RaidTabBack()
    UF.raidSeen = nil
    local holder = RaidManager()
    if not holder or not touched[holder] or Look.InFight() then return end
    touched[holder] = nil
    Look.Alpha(holder.Background, 1)
    local tab = holder.toggleButtonForward
    if not tab then return end
    Look.Pin(tab, "RIGHT", holder, "RIGHT", -7, 0)
    for _, piece in ipairs(tabArt[tab] or {}) do piece:Hide() end
    FacesTo(tab, 1)
end

---------------------------------------------------------------------------
-- The buff arrow ("hideBuffArrow")
---------------------------------------------------------------------------

local arrow = { on = false, watching = false }
Look.buffArrow = arrow

local function FoldArrow()
    return Look.Path(BuffFrame, "CollapseAndExpandButton")
end

-- Every 0.05 s: shown only while the mouse is over it or within 6 units of
-- an edge, and kept clickable.
function arrow.Check()
    local fold = arrow.on and FoldArrow()
    if not fold then return end
    local wanted = fold:IsMouseOver(6, -6, -6, 6) == true and 1 or 0
    local current = Look.Number(fold:GetAlpha())
    if not current or math.abs(current - wanted) > 0.01 then fold:SetAlpha(wanted) end
    local asked, clickable = Look.Ask(fold, "IsMouseEnabled")
    if asked and clickable == false then fold:EnableMouse(true) end
end

local function ArrowOn()
    arrow.on = true
    if not arrow.watching then
        arrow.watching = true
        Look.Every(0.05, arrow.Check)
    end
    arrow.Check()
end

-- The watch keeps running; it does nothing while off.
local function ArrowOff()
    arrow.on = false
    local fold = FoldArrow()
    if not fold then return end
    Look.Alpha(fold, 1)
    fold:EnableMouse(true)
end

ns.RegisterModule("hideBuffArrow", { apply = ArrowOn, restore = ArrowOff })
