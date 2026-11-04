-- EraUI Raid-style Party Outline.
-- Appearance > Style > Frame Style (experimental, off unless ticked). The
-- game's own raid-style party frames (Edit Mode: Use Raid-Style Party
-- Frames) get one thick near-black outline round the whole group, with soft
-- corners and the fine line Thick Frames draws just inside its plates (muted
-- bronze in Classic, the Darkness grey in Dark Mode), and a flat fill on
-- each frame's health and power bars (Flat Bars' solid square; the game's
-- colours stay). Names, sizes, spacing and class colours stay the game's.
--
-- How: while Edit Mode's Display Border is on, the game keeps a border frame
-- round its party members (CompactPartyFrame.borderFrame, which Forever's
-- CompactRaidGroup.lua pins to the first member's top left and the last
-- shown member's bottom right, 2 out at the top and sides, 3 below). EraUI's
-- outline is a frame of its own made on that border and pinned to it by two
-- corners, so it shows exactly while the game's border shows (raid-style
-- party frames in use, in a party, Display Border on) and follows every
-- change of size or member, in a fight too, with no code of EraUI's running.
-- It sits a level under the members, and the border's own fill is faded so
-- the outline takes its place. The bars' fill is the only other change on
-- the game's frames: a cosmetic setter, each bar's own art (the game's
-- atlas) noted first and given back when it's switched off. The game gives
-- the bars their art once, in its XML, so nothing needs hooking to keep it.
-- State lives in weak tables beside the game's frames, never a key on them,
-- and no Edit Mode method is ever called. Worn and taken off out of a fight
-- only: a switch in a fight waits for its end (EraUI's own pass, booked).
-- While Forever Enhanced Raid Frames draws your party (its own party block,
-- FERFParty, is made only while its party frames are on, and it then parks
-- the game's), EraUI draws nothing here and gives the bars back.
local _, EraUI = ...
local ns = EraUI.Classic

local function IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) end

-- The outline's near black (Thick Frames' plate) and the line's muted bronze
-- in Classic. Its edge is Thick Frames' on its big frames (the approved
-- mockup's Thick border of 6 at the unit frames' size): the members sit an
-- edge in from the outline's outside, and the fine line, one unit wide and
-- square, runs 2 to 1 units outside them. Its corner is its own: 6, so the
-- line's square corner (3 in) keeps clear of the round one (a rounder 8
-- brings the round corner almost onto it).
local SHELL = { .05, .05, .06 }
local BRONZE = { .55, .46, .27 }
local EDGE, CORNER = 5, 6
-- The game's own border round the members (CompactRaidGroup.lua
-- SetupBorderFrameAnchor): 2 out at the top and sides, 3 below.
local GAME_SIDE, GAME_FOOT = 2, 3
-- The outline's corners: quarters of the round portrait mask the game ships.
local CORNERS = {
    { "TOPLEFT", 0, .5, 0, .5 }, { "TOPRIGHT", .5, 1, 0, .5 },
    { "BOTTOMLEFT", 0, .5, .5, 1 }, { "BOTTOMRIGHT", .5, 1, .5, 1 },
}
-- The bars of each of the game's party frames that take the flat fill.
local BARS = { "healthBar", "powerBar" }

-- The outline, made the first time it's worn: { frame, body, line, on, r, g, b }.
local outline
-- Each bar given the flat fill -> its own art (the game's atlas, or a file),
-- or false when that couldn't be read (that bar is left as it is).
local flat = setmetatable({}, { __mode = "k" })
-- The game border's own fill, faded under the outline -> its own alpha.
local faded = setmetatable({}, { __mode = "k" })
local watching = false

local function Wanted()
    return EraUI:GetSetting("enabled") and EraUI:GetSetting("partyOutline") == true or false
end

-- Forever Enhanced Raid Frames draws your party: its party block (a secure
-- group header named FERFParty) is made at login only while its own party
-- frames are on. Only read, by its name.
function ns.PartyOutlineStepsAside()
    return type(_G.FERFParty) == "table"
end

local function Group()
    local group = _G.CompactPartyFrame
    if type(group) == "table" then return group end
end

-- Every bar of the game's party frames, members and pets alike. The game
-- makes all of them with its party frame, so someone who joins in a fight
-- already has the flat fill.
local function EachBar(group, fn)
    for _, list in ipairs({ group.memberUnitFrames, group.petUnitFrames }) do
        if type(list) == "table" then
            for _, unitFrame in ipairs(list) do
                for _, key in ipairs(BARS) do
                    local bar = unitFrame[key]
                    if type(bar) == "table" and bar.SetStatusBarTexture then fn(bar) end
                end
            end
        end
    end
end

-- The flat fill ----------------------------------------------------------------

-- A bar's own art, read before its first flat fill: its atlas, else its
-- file. Secret or unreadable: false, and the bar keeps its art.
local function OwnArt(bar)
    local tex = bar:GetStatusBarTexture()
    if not tex then return false end
    local atlas = tex.GetAtlas and tex:GetAtlas()
    if not IsSecret(atlas) and type(atlas) == "string" and atlas ~= "" then return atlas end
    local file = tex:GetTexture()
    if not IsSecret(file) and (type(file) == "string" or type(file) == "number") then return file end
    return false
end

local function Solid(bar)
    bar:SetStatusBarTexture((ns.TexPath("statusBarSolid")))
end

-- In the colour it already has (Classic/Skin.lua ns.Refill reads it first).
local function Flatten(bar)
    if flat[bar] == nil then flat[bar] = OwnArt(bar) end
    if flat[bar] then ns.Refill(bar, Solid) end
end

local function GiveBack(bar)
    local own = flat[bar]
    flat[bar] = nil
    if own then ns.Refill(bar, function(b) b:SetStatusBarTexture(own) end) end
end

-- The outline ------------------------------------------------------------------

-- One of its pieces pinned by two of the outline's corners.
local function Span(piece, frame, from, x1, y1, to, x2, y2)
    piece:ClearAllPoints()
    piece:SetPoint("TOPLEFT", frame, from, x1, y1)
    piece:SetPoint("BOTTOMRIGHT", frame, to, x2, y2)
end

-- EraUI's own frame on the game's border, pinned to it by two corners an
-- edge out from the members, so its size and place are the game's at every
-- moment. Its pieces are pinned to it the same way: four rounded corners,
-- the middle at full height and the two ends between the corners (as
-- Rounded Cast Bars' shell), then the fine line's four strips.
local function Build(border)
    local frame = CreateFrame("Frame", nil, border)
    frame:SetPoint("TOPLEFT", border, "TOPLEFT", GAME_SIDE - EDGE, EDGE - GAME_SIDE)
    frame:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", EDGE - GAME_SIDE, GAME_FOOT - EDGE)
    local o = { frame = frame, body = {}, line = {} }
    for i = 1, 7 do
        local piece = frame:CreateTexture(nil, "BACKGROUND")
        local corner = CORNERS[i]
        if corner then
            ns.SetTex(piece, "portraitMask")
            piece:SetTexCoord(corner[2], corner[3], corner[4], corner[5])
            piece:SetVertexColor(SHELL[1], SHELL[2], SHELL[3], 1)
            piece:SetSize(CORNER, CORNER)
            piece:SetPoint(corner[1], frame, corner[1], 0, 0)
        else
            piece:SetColorTexture(SHELL[1], SHELL[2], SHELL[3], 1)
        end
        o.body[i] = piece
    end
    Span(o.body[5], frame, "TOPLEFT", CORNER, 0, "BOTTOMRIGHT", -CORNER, 0)
    Span(o.body[6], frame, "TOPLEFT", 0, -CORNER, "BOTTOMLEFT", CORNER, CORNER)
    Span(o.body[7], frame, "TOPRIGHT", -CORNER, -CORNER, "BOTTOMRIGHT", 0, CORNER)
    local inset = EDGE - 2
    for i = 1, 4 do o.line[i] = frame:CreateTexture(nil, "BORDER") end
    Span(o.line[1], frame, "TOPLEFT", inset, -inset, "TOPRIGHT", -inset, -inset - 1)
    Span(o.line[2], frame, "BOTTOMLEFT", inset, inset + 1, "BOTTOMRIGHT", -inset, inset)
    Span(o.line[3], frame, "TOPLEFT", inset, -inset - 1, "BOTTOMLEFT", inset + 1, inset + 1)
    Span(o.line[4], frame, "TOPRIGHT", -inset - 1, -inset - 1, "BOTTOMRIGHT", -inset, inset + 1)
    outline = o
    return o
end

-- A level under the members, so they draw over it (the game puts them all
-- on one level, over its border's). The level is checked as a plain number.
local function Lower(o, group)
    local members = group.memberUnitFrames
    local member = type(members) == "table" and members[1]
    if not member then return end
    local level = member:GetFrameLevel()
    if IsSecret(level) or type(level) ~= "number" then return end
    level = math.max(0, level - 1)
    if o.frame:GetFrameLevel() ~= level then o.frame:SetFrameLevel(level) end
end

-- The line: the Darkness grey in Dark Mode, else muted bronze; set only when
-- it changes.
local function LineColour()
    if EraUI:GetSetting("darkMode") then
        if ns.DarkGrey then return ns.DarkGrey() end
        return .42, .44, .48
    end
    return BRONZE[1], BRONZE[2], BRONZE[3]
end

local function Tone(o)
    local r, g, b = LineColour()
    if o.r == r and o.g == g and o.b == b then return end
    o.r, o.g, o.b = r, g, b
    for _, strip in ipairs(o.line) do strip:SetColorTexture(r, g, b, 1) end
end

-- The game border's own fill faded while the outline is worn (its alpha
-- noted first), so only the outline shows round the members.
local function Fade(region)
    if type(region) ~= "table" then return end
    if faded[region] == nil then
        local alpha = region:GetAlpha()
        faded[region] = (not IsSecret(alpha) and type(alpha) == "number") and alpha or 1
    end
    region:SetAlpha(0)
end

-- Wearing and taking off ---------------------------------------------------------

local function Wear(group)
    local border = group.borderFrame
    if type(border) == "table" then
        local o = outline or Build(border)
        Lower(o, group)
        Tone(o)
        Fade(border.Background)
        o.on = true
        o.frame:Show()
    end
    EachBar(group, Flatten)
end

-- Off: the outline hidden, the border's fill and each bar's art back.
local function TakeOff()
    if outline and outline.on then
        outline.on = false
        outline.frame:Hide()
    end
    for region, alpha in pairs(faded) do
        faded[region] = nil
        region:SetAlpha(alpha)
    end
    for bar in pairs(flat) do GiveBack(bar) end
end

local function Worn()
    return (outline ~= nil and outline.on == true) or next(flat) ~= nil
end

-- The game makes its party frame with its raid frames, before EraUI runs;
-- should it ever come later, the look goes on once it's made (a post-hook,
-- set only while the look is wanted).
local function Watch()
    if watching or type(CompactPartyFrame_Generate) ~= "function" then return end
    watching = true
    hooksecurefunc("CompactPartyFrame_Generate", function()
        if Wanted() then C_Timer.After(0, ns.RefreshPartyOutline) end
    end)
end

-- EraUI's passes (out of a fight: login, entering the world, Edit Mode
-- closed, after a fight) and the /era tick: the look on or off. In a fight
-- nothing changes and the pass after it is booked: returns false then.
function ns.RefreshPartyOutline()
    local want = Wanted() and not ns.PartyOutlineStepsAside()
    if InCombatLockdown() then
        if want == Worn() then return true end
        if ns.ApplyAll then ns.ApplyAll() end
        return false
    end
    local group = Group()
    if want and group then Wear(group) else TakeOff() end
    if want and not group then Watch() end
    return true
end

-- The Darkness slider (Core/Appearance.lua RefreshDarkness): the line takes
-- the new grey at once (EraUI's own textures, so in a fight too).
function ns.RefreshPartyOutlineLine()
    if outline and outline.on then Tone(outline) end
end

ns.RegisterModule("partyOutline", {
    apply = function() ns.RefreshPartyOutline() end,
    restore = function() if not InCombatLockdown() then TakeOff() end end,
})
