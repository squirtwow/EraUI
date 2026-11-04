-- Dressing one of the game's windows in the 1.x chrome: the metal border on
-- its nine-slice, the round portrait, the title, the grey stone with its
-- band of streaks, the marble floor in its inset, the stone title strip,
-- the red X (and the bigger/smaller pair), the tabs on its foot, the 1.x
-- scroll bars, the window's own extras, then Dark Windows.
--
-- options (all optional): noRing, noStone, noFloor, lift (bottom corners, 10),
-- tabLift (else lift), stoneRight and stoneBottom (insets of the stone),
-- topTabs (the macro window's), extras (function(window, options)).
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local C = Look.Chrome

C.applied = false

-- A window may be dressed while the chrome is on, its /era switch allows it
-- (Core/Integration.lua's question; everything when nothing answers) and it
-- has a nine-slice to wear the metal on.
function C.Allowed(window)
    if not C.applied or not window then return false end
    local fine, forbidden = Look.Ask(window, "IsForbidden")
    if fine and forbidden == true then return false end
    if type(ns.WindowAllowed) == "function" then
        local fine, allowed = pcall(ns.WindowAllowed, window)
        if not fine or not allowed then return false end
    end
    return window.NineSlice ~= nil
end

-- What a window's own background shows: the parchment ones stay.
local function Parchment(region)
    local fine, atlas = Look.Ask(region, "GetAtlas")
    if fine and type(atlas) == "string" and not Look.Secret(atlas) and atlas:lower():find("parchment", 1, true) then
        return true
    end
    local asked, file = Look.Ask(region, "GetTextureFilePath")
    if not asked or type(file) ~= "string" then asked, file = Look.Ask(region, "GetTexture") end
    return asked and type(file) == "string" and not Look.Secret(file) and file:lower():find("parchment", 1, true) ~= nil
end

local function Portrait(window)
    local holder = window.PortraitContainer
    local face = (holder and holder.portrait) or C.Part(window, "portrait", "Portrait")
    if not face then return end
    face:SetSize(61, 61)
    Look.Pin(face, "TOPLEFT", window, "TOPLEFT", -6, 8)
    Look.WatchPortrait(face)
end

local function Title(window, ring)
    local title = window.TitleContainer
    if not title then return end
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", window, "TOPLEFT", ring and 58 or 6, 0)
    title:SetPoint("TOPRIGHT", window, "TOPRIGHT", -58, 0)
end

-- The marble floor over a plain inset (its own art faded), else none.
local function Floor(window, options)
    local inset = not options.noFloor and C.Part(window, "Inset")
    local plain = inset and type(inset.GetObjectType) == "function" and inset:GetObjectType() == "Frame"
    if not plain then
        local floor = C.Found(window, "insetFloor")
        if floor then floor:Hide() end
        return
    end
    Look.EachRegion(inset.NineSlice, function(piece)
        if C.IsTexture(piece) then Look.Fade(piece) end
    end)
    Look.Fade(inset.Bg)
    local floor = C.Piece(window, "insetFloor", "BACKGROUND", -1)
    Look.PlainArt(floor, "marbleBg", true, true)
    Look.Crop(floor, 0, 1, 0, 1)
    Look.Fill(floor, inset)
    floor:Show()
end

local function Stone(window, options)
    if options.noStone then
        for _, piece in ipairs({ "backing", "streaks", "insetFloor" }) do
            local made = C.Found(window, piece)
            if made then made:Hide() end
        end
        return
    end
    local stone = C.Piece(window, "backing", "BACKGROUND", -2)
    Look.PlainArt(stone, "rockBg", true, true)
    Look.Crop(stone, 0, 1, 0, 1)
    stone:ClearAllPoints()
    stone:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    stone:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -(options.stoneRight or 0), options.stoneBottom or 0)
    stone:Show()
    local own = C.Part(window, "Bg")
    if C.IsTexture(own) then Look.Alpha(own, Parchment(own) and 1 or 0) end
    Look.Fade(window.TopTileStreaks)
    local streaks = C.Piece(window, "streaks", "BACKGROUND", -1)
    Look.PlainArt(streaks, "frameSheet", true, false)
    Look.Crop(streaks, 0, 1, 0.671875, 0.9609375)
    streaks:SetHeight(37)
    streaks:ClearAllPoints()
    streaks:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -21)
    streaks:SetPoint("TOPRIGHT", window, "TOPRIGHT", -2, -21)
    streaks:Show()
    Floor(window, options)
end

-- The thin stone strip under the title, on every dressed window.
local function TitleStrip(window, ring)
    local strip = C.Piece(window, "titleStrip", "BACKGROUND", 0)
    Look.PlainArt(strip, "frameSheet", true, false)
    Look.Crop(strip, 0, 1, 0.2890625, 0.421875)
    strip:SetHeight(17)
    strip:ClearAllPoints()
    strip:SetPoint("TOPLEFT", window, "TOPLEFT", ring and 2 or 6, -3)
    strip:SetPoint("TOPRIGHT", window, "TOPRIGHT", -25, -3)
    strip:Show()
end

local function Buttons(window)
    local close = C.Part(window, "CloseButton")
    if close then ns.SkinCloseButton(close) end
    local pair = window.MaximizeMinimizeButton
    if pair then
        ns.SkinMaxMinButtons(pair)
        pair:SetSize(32, 32)
        if close then Look.Pin(pair, "RIGHT", close, "LEFT", 8.5, 0) end
    end
end

local function Tabs(window, options)
    local lift = options.tabLift or options.lift or 10
    local system = window.TabSystem
    if system and system.GetChildren then
        local fine, children = pcall(function() return { system:GetChildren() } end)
        for _, tab in ipairs(fine and children or {}) do ns.SkinBottomTab(tab, nil, lift) end
    end
    local called = C.Name(window)
    if not called then return end
    for i = 1, 10 do
        local tab = _G[called .. "Tab" .. i]
        if tab then
            if options.topTabs then C.SkinTopTab(tab, nil, lift) else ns.SkinBottomTab(tab, nil, lift) end
        end
    end
end

-- Dark Windows: the edges, stone, streaks and title strip painted again
-- (each dressing set their files again), the inset floor never.
function C.Darken(window)
    if type(ns.DarkWindowArt) ~= "function" then return end
    local slice = window.NineSlice
    for _, key in ipairs(C.EDGE_KEYS) do
        local edge = slice and slice[key]
        if edge then ns.DarkWindowArt(edge, "frame", true) end
    end
    for _, piece in ipairs({ "backing", "streaks", "titleStrip" }) do
        local made = C.Found(window, piece)
        if made then ns.DarkWindowArt(made, "frame", true) end
    end
end

-- One window, in order. True when it was dressed.
function C.Dress(window, options)
    options = options or {}
    if not C.Allowed(window) then return false end
    local ring = not options.noRing
    C.Border(window.NineSlice, ring, options.lift or 10)
    if ring then Look.Try(Portrait, window) end
    Look.Try(Title, window, ring)
    Look.Try(Stone, window, options)
    Look.Try(TitleStrip, window, ring)
    Look.Try(Buttons, window)
    Look.Try(Tabs, window, options)
    Look.Try(Look.SkinScrollBarsUnder, window, 5)
    -- Marked before its extras, which may look at it (the loot window's).
    C.dressed[window] = options
    if type(options.extras) == "function" then Look.Try(options.extras, window, options) end
    C.Darken(window)
    return true
end

-- Public: dress a window now (tests, and the windows other code hands in).
function ns.SkinWindow(window, options)
    return C.Dress(window, options)
end
