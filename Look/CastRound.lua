-- Rounded Cast Bars (roundedCastBars, off by default): your bar, your pet's,
-- the target's and the focus's become thick near-black bars with soft
-- corners, the spell's icon in a tile of its own at the left, the name at
-- the left and the time left at the right. Boss bars keep the 1.x look.
--
-- The shell is EraUI's own: a frame under the bar (the near-black body, the
-- fine line, the icon) and one over it (the time), pinned to the bar by its
-- corners. Nothing is made until a bar first wears it. The bar itself is only
-- sized, never moved, and nothing about its place or size is read: under the
-- target's aura row the game refuses an addon's layout scripts.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Cast = Look.Cast

local shells = Look.Weak() -- bar: its shell (frames, pieces, what it wears)
local owners = Look.Weak() -- the shell's top frame: its bar
local tints = Look.Weak()  -- bar: the class colour Class-coloured Cast Border gave its line
local NEAR_BLACK = { 0.05, 0.05, 0.06, 1 }
local QUARTERS = { { 0, 0.5, 0, 0.5 }, { 0.5, 1, 0, 0.5 }, { 0, 0.5, 0.5, 1 }, { 0.5, 1, 0.5, 1 } }
local TRIM = 0.07
local TICK = 0.05

local function Accents()
    local modules = EraUI.modules
    return type(modules) == "table" and modules.ClassAccents or nil
end

---------------------------------------------------------------------------
-- Whether a bar wears it
---------------------------------------------------------------------------

function Cast.RoundShown(bar)
    local shell = bar and shells[bar]
    return shell ~= nil and shell.worn == true
end

local function Wanted(bar, look)
    return Cast.applied and EraUI:GetSetting("roundedCastBars") == true and Cast.dressed[bar] == true
        and not Cast.boss[bar] and Cast.GEOMETRY[look] ~= nil
end

-- What the bar will wear after this dressing, and whether it is held: a bar
-- the game guards in a fight keeps what it wears until the fight is over.
function Cast.RoundOutcome(bar, look)
    local now, want = Cast.RoundShown(bar), Wanted(bar, look)
    if want ~= now and Cast.GEOMETRY[look] and Look.HeldInFight(bar) then return now, true end
    return want, false
end

---------------------------------------------------------------------------
-- The shell
---------------------------------------------------------------------------

local function Strip(piece, bar, from, x1, y1, to, x2, y2)
    piece:ClearAllPoints()
    piece:SetPoint("TOPLEFT", bar, from, x1, y1)
    piece:SetPoint("BOTTOMRIGHT", bar, to, x2, y2)
end

-- Every piece pinned to the bar for a shape (again only when the shape changes).
local function Pin(shell, bar, shape)
    local h, edge, corner, gap = shape.h, shape.edge, shape.corner, Cast.GAP
    local reach, tile = gap + h + edge, gap + h
    local body, line = shell.body, shell.line
    local corners = { { "TOPLEFT", -reach, edge }, { "TOPRIGHT", edge, edge }, { "BOTTOMLEFT", -reach, -edge },
        { "BOTTOMRIGHT", edge, -edge } }
    for i, spot in ipairs(corners) do
        local piece = body[i]
        piece:ClearAllPoints()
        piece:SetSize(corner, corner)
        piece:SetPoint(spot[1], bar, spot[1], spot[2], spot[3])
    end
    Strip(body[5], bar, "TOPLEFT", corner - reach, edge, "BOTTOMRIGHT", edge - corner, -edge)
    Strip(body[6], bar, "TOPLEFT", -reach, edge - corner, "BOTTOMLEFT", corner - reach, corner - edge)
    Strip(body[7], bar, "TOPRIGHT", edge - corner, edge - corner, "BOTTOMRIGHT", edge, corner - edge)
    Strip(line[1], bar, "TOPLEFT", -tile - 2, 2, "TOPRIGHT", 2, 1)
    Strip(line[2], bar, "BOTTOMLEFT", -tile - 2, -1, "BOTTOMRIGHT", 2, -2)
    Strip(line[3], bar, "TOPLEFT", -tile - 2, 1, "BOTTOMLEFT", -tile - 1, -1)
    Strip(line[4], bar, "TOPRIGHT", 1, 1, "BOTTOMRIGHT", 2, -1)
    shell.icon:ClearAllPoints()
    shell.icon:SetSize(h, h)
    shell.icon:SetPoint("RIGHT", bar, "LEFT", -gap, 0)
    shell.time:ClearAllPoints()
    shell.time:SetPoint("RIGHT", bar, "RIGHT", -shape.inset, 0)
    shell.time:SetFontObject(shape.font)
end

-- The time left on the bar: its own value and range when they can be read,
-- else the game's own duration for the unit (passed on, never worked on).
-- Returns false when there is nothing to show.
local function Remaining(duration) return duration:GetRemainingDuration() end

local function TimeLeft(bar)
    local own = bar.CastTimeText
    if own then
        local asked, shown = Look.Ask(own, "IsShown")
        if asked and not Look.Secret(shown) and shown == true then return false end
    end
    local channel = Cast.Flag(bar.channeling)
    if not (channel or Cast.Flag(bar.casting)) then return false end
    local gotValue, value = Look.Ask(bar, "GetValue")
    local gotRange, _, most = Look.Ask(bar, "GetMinMaxValues")
    value, most = gotValue and Look.Number(value), gotRange and Look.Number(most)
    if value and most then
        if channel then return true, math.max(0, value) end
        return true, math.max(0, most - value)
    end
    local unit = bar.unit
    if Look.Secret(unit) or type(unit) ~= "string" then return false end
    local ask = channel and UnitChannelDuration or UnitCastingDuration
    if type(ask) ~= "function" then return false end
    local fine, duration = pcall(ask, unit)
    if not fine or Look.Secret(duration) or duration == nil then return false end
    local read, left = pcall(Remaining, duration)
    if not read then return false end
    if Look.Secret(left) or Look.Number(left) then return true, left end
    return false
end

local function ShowTime(shell, bar)
    local some, left = TimeLeft(bar)
    if some then
        shell.time:SetFormattedText("%.1f", left)
        shell.empty = false
    elseif not shell.empty then
        shell.time:SetText("")
        shell.empty = true
    end
end

-- The top frame's own clock: a few times a second while the bar shows. An
-- error is reported once, never every frame.
local function OnTick(top, elapsed)
    local bar = owners[top]
    local shell = bar and shells[bar]
    if not shell then return end
    shell.waited = shell.waited + (elapsed or 0)
    if shell.waited < TICK then return end
    shell.waited = 0
    local fine, problem = pcall(ShowTime, shell, bar)
    if not fine and not shell.told then
        shell.told = true
        Look.Try(error, problem, 0)
    end
end

local function Build(bar)
    local shell = { worn = false, waited = 0, empty = true, body = {}, line = {} }
    local under = CreateFrame("Frame", nil, bar)
    Look.Fill(under, bar)
    under:Hide()
    for i = 1, 7 do
        local piece = under:CreateTexture(nil, "BACKGROUND")
        if i <= 4 then
            Look.Art(piece, "portraitMask")
            piece:SetTexCoord(unpack(QUARTERS[i]))
            piece:SetVertexColor(unpack(NEAR_BLACK))
        else
            piece:SetColorTexture(unpack(NEAR_BLACK))
        end
        shell.body[i] = piece
    end
    for i = 1, 4 do shell.line[i] = under:CreateTexture(nil, "BORDER") end
    shell.icon = under:CreateTexture(nil, "ARTWORK")
    shell.icon:SetTexCoord(TRIM, 1 - TRIM, TRIM, 1 - TRIM)
    local over = CreateFrame("Frame", nil, bar)
    Look.Fill(over, bar)
    over:Hide()
    shell.time = over:CreateFontString(nil, "OVERLAY", Cast.GEOMETRY.CLASSIC.font)
    shell.time:SetJustifyH("RIGHT")
    owners[over] = bar
    over:SetScript("OnUpdate", OnTick)
    shell.under, shell.over = under, over
    shells[bar] = shell
    return shell
end

---------------------------------------------------------------------------
-- The fine line's colour
---------------------------------------------------------------------------

-- The look's line: the Darkness grey in Dark Mode, muted bronze otherwise.
function ns.RoundedCastLine()
    if EraUI:GetSetting("darkMode") then
        if type(ns.DarkGrey) == "function" then return ns.DarkGrey() end
        return 0.42, 0.44, 0.48
    end
    return 0.55, 0.46, 0.27
end

local function PaintLine(bar, shell)
    local r, g, b
    local tint = tints[bar]
    if tint then r, g, b = tint[1], tint[2], tint[3] else r, g, b = ns.RoundedCastLine() end
    local last = shell.lineRGB
    if last and last[1] == r and last[2] == g and last[3] == b then return end
    shell.lineRGB = { r, g, b }
    for _, piece in ipairs(shell.line) do piece:SetColorTexture(r, g, b, 1) end
end

---------------------------------------------------------------------------
-- Wearing it and taking it off
---------------------------------------------------------------------------

-- The name at the bar's left, stopping short of the time.
local function NameLeft(shell, bar, shape)
    local name = bar.Text
    if not name then return end
    if shell.justify == nil then
        local asked, side = Look.Ask(name, "GetJustifyH")
        shell.justify = (asked and not Look.Secret(side) and type(side) == "string") and side or "CENTER"
    end
    name:ClearAllPoints()
    name:SetPoint("LEFT", bar, "LEFT", shape.inset, 0)
    name:SetPoint("RIGHT", bar, "RIGHT", -shape.room, 0)
    name:SetJustifyH("LEFT")
end

local function Untrim(shell, icon)
    if shell.trimmed and icon then icon:SetTexCoord(0, 1, 0, 1) end
    shell.trimmed = false
end

-- The spell's icon in its tile: the small bars show the game's own icon
-- (moved in); the big bar hides it, so EraUI's own shows the same spell.
local function TileIcon(shell, bar, look, shape)
    local theirs = bar.Icon
    if look == "UNITFRAME" then
        if theirs then
            theirs:SetSize(shape.h, shape.h)
            Look.Pin(theirs, "RIGHT", bar, "LEFT", -Cast.GAP, 0)
            theirs:SetTexCoord(TRIM, 1 - TRIM, TRIM, 1 - TRIM)
            shell.trimmed = true
        end
        shell.icon:Hide()
        return
    end
    if theirs then
        local asked, art = Look.Ask(theirs, "GetTexture")
        if asked then shell.icon:SetTexture(art) end
        Untrim(shell, theirs)
    end
    shell.icon:Show()
end

-- The game's shield round the tile, in its own proportions (29 x 33 round a
-- 20 x 20 icon), held by two points so its own size is left alone.
local function ShieldRound(bar, shape)
    local shield = bar.BorderShield
    if not shield then return end
    shield:SetAtlas("ui-castingbar-shield")
    local x = -(Cast.GAP + shape.h / 2)
    local halfWide, halfTall = shape.h * 1.45 / 2, shape.h * 1.65 / 2
    shield:ClearAllPoints()
    shield:SetPoint("TOPLEFT", bar, "LEFT", x - halfWide, 1 + halfTall)
    shield:SetPoint("BOTTOMRIGHT", bar, "LEFT", x + halfWide, 1 - halfTall)
end

-- Where the game put its own cast time (Edit Mode's Show Cast Time), or nil
-- when any part of it can't be read.
local function Remember(text)
    local count = Look.Number(text:GetNumPoints()) or 0
    local points = {}
    for i = 1, count do
        local anchor = { text:GetPoint(i) }
        for part = 1, 5 do
            if Look.Secret(anchor[part]) then return nil end
        end
        points[i] = anchor
    end
    local font = text:GetFontObject()
    if font == nil or Look.Secret(font) then return nil end
    return { points = points, font = font }
end

local function CastTimeInside(shell, bar, shape)
    local theirs = bar.CastTimeText
    if not theirs then return end
    if not shell.castTime then
        local read, saved = pcall(Remember, theirs)
        shell.castTime = read and saved or nil
    end
    if not shell.castTime then return end
    Look.Pin(theirs, "RIGHT", bar, "RIGHT", -shape.inset, 0)
    theirs:SetFontObject(shape.font)
end

local function CastTimeBack(shell, bar)
    local theirs, saved = bar.CastTimeText, shell.castTime
    if not theirs or not saved then return end
    theirs:ClearAllPoints()
    for _, p in ipairs(saved.points) do theirs:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
    theirs:SetFontObject(saved.font)
end

-- On, after the 1.x dressing has run (it already sized the spark and flash).
function Cast.Wear(bar, look)
    local shape = Cast.GEOMETRY[look]
    local shell = shells[bar] or Build(bar)
    if shell.shape ~= look then
        Pin(shell, bar, shape)
        shell.shape = look
    end
    local level = Look.Number(bar:GetFrameLevel())
    if level then
        local below = math.max(0, level - 1)
        if Look.Number(shell.under:GetFrameLevel()) ~= below then shell.under:SetFrameLevel(below) end
    end
    if not Look.HeldInFight(bar) then bar:SetSize(shape.w, shape.h) end
    if bar.Border then bar.Border:SetAlpha(0) end
    NameLeft(shell, bar, shape)
    TileIcon(shell, bar, look, shape)
    ShieldRound(bar, shape)
    CastTimeInside(shell, bar, shape)
    shell.worn = true
    shell.under:Show()
    shell.over:Show()
    PaintLine(bar, shell)
    local accents = Accents()
    if accents and type(accents.HideCastOutline) == "function" then accents:HideCastOutline(bar) end
end

-- Off again; the 1.x dressing puts back the rest on its own.
function Cast.TakeOff(bar)
    local shell = shells[bar]
    if not shell or not shell.worn then return end
    shell.worn = false
    shell.under:Hide()
    shell.over:Hide()
    shell.time:SetText("")
    shell.empty = true
    if bar.Border then bar.Border:SetAlpha(1) end
    if bar.Text then bar.Text:SetJustifyH(shell.justify or "CENTER") end
    Untrim(shell, bar.Icon)
    CastTimeBack(shell, bar)
    local accents = Accents()
    if accents and type(accents.Refresh) == "function" then accents:Refresh() end
end

-- Step 8 of a dressing: on or off, a pass booked for a bar held in a fight.
function Cast.RoundStep(bar, look, outcome, held)
    if held then Cast.AskPass() end
    if outcome then Cast.Wear(bar, look) else Cast.TakeOff(bar) end
end

-- The rounded look's flash: an even white glow over the bar.
function Cast.SoftFlash(bar, flash)
    Look.Art(flash, "statusBarSolid")
    flash:SetTexCoord(0, 1, 0, 1)
    flash:SetBlendMode("ADD")
    Look.Fill(flash, bar)
    flash:SetVertexColor(1, 1, 1, 0.4)
    Cast.soft[flash] = true
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

-- True while the bar wears the shell (Modules/ClassAccents.lua).
function ns.RoundedCastShown(bar)
    return Cast.RoundShown(bar)
end

-- A class colour for the bar's line (nil r: none), at once where worn.
function ns.TintRoundedCast(bar, r, g, b)
    if not bar then return end
    if Look.Number(r) and Look.Number(g) and Look.Number(b) then tints[bar] = { r, g, b } else tints[bar] = nil end
    local shell = shells[bar]
    if shell and shell.worn then PaintLine(bar, shell) end
end

-- The Darkness slider: every worn line, then the Advanced Cast Bar's.
function ns.RefreshRoundedCastLines()
    for bar, shell in pairs(shells) do
        if shell.worn then PaintLine(bar, shell) end
    end
    local modules = EraUI.modules
    local advanced = type(modules) == "table" and modules.AdvancedCastBar or nil
    if advanced and type(advanced.RefreshLine) == "function" then advanced:RefreshLine() end
end
