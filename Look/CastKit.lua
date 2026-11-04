-- The cast bars' kit (registry entry "castBars"): which of the game's bars
-- wear the 1.x look, what EraUI remembers about each one, the 1.x cast art,
-- and how a cast's fill is coloured.
--
-- EraUI only dresses the game's cast bars. It post-hooks their own methods
-- and sets art, sizes, anchors and colours on their pieces; it never runs one
-- of their methods, never sets a script on them and never writes a key on
-- them. What it remembers about a bar lives in the weak-keyed tables below.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local Cast = { applied = false }
Look.Cast = Cast

Cast.dressed = Look.Weak()  -- bar: true once its hooks are on (EraUI has dressed it)
Cast.boss = Look.Weak()     -- bar: true for a boss frame's spell bar
Cast.dressing = Look.Weak() -- boss bar: true while it wears EraUI's look
Cast.kinds = Look.Weak()    -- your own bar: the kind of cast it last showed
Cast.parents = Look.Weak()  -- a unit frame with its own SetSmallSize: its spell bar
Cast.soft = Look.Weak()     -- a bar's Flash wearing the rounded look's soft tint

-- The engine's defaults, filled in only where it has none of its own.
do
    local engine = type(ns.DB_DEFAULTS) == "table" and ns.DB_DEFAULTS or nil
    if engine then
        for key, value in pairs({ castBars = true, mirrorTimers = true, textureSource = "builtin" }) do
            if engine[key] == nil then engine[key] = value end
        end
    end
end

-- The 1.x cast art: the client's own file first, then the copy in
-- Media/Classic. Each key is also its Dark Mode key (Core/Appearance.lua
-- tints only the two borders among them).
for _, pair in ipairs(Look.Words([[castBorder:Border castBorderSmall:Border-Small castSmallShield:Small-Shield
    castSpark:Spark castFlash:Flash castFlashSmall:Flash-Small]])) do
    local key, tail = pair:match("^(%w+):(.+)$")
    local file = "UI-CastingBar-" .. tail
    Look.DefineArt(key, "Interface\\CastingBar\\" .. file, file, key)
end

-- The rounded look's shapes (Rounded Cast Bars): the bar's size, how far the
-- shell reaches past it (edge), its corner radius, the name's and time's room
-- from the ends (inset), the name's stop short of the time (room), the font.
Cast.GEOMETRY = {
    CLASSIC = { w = 195, h = 18, edge = 5, corner = 6, inset = 6, room = 40, font = "GameFontHighlight" },
    UNITFRAME = { w = 150, h = 14, edge = 4, corner = 5, inset = 4, room = 32, font = "SystemFont_Shadow_Small" },
}
Cast.GAP = 3 -- between the icon's tile and the bar

-- The game's modern pieces the 1.x look hides (TextBorder: the plate under the name).
Cast.EFFECTS = Look.Words([[Flakes01 Flakes02 Flakes03 BaseGlow WispGlow Sparkles01 Sparkles02 Shine EnergyGlow
    InterruptGlow ChargeGlow ChargeFlash StandardGlow CraftGlow ChannelShadow DropShadow TextBorder]])

---------------------------------------------------------------------------
-- Which bars
---------------------------------------------------------------------------

-- Every bar the look dresses, in order: { bar, isBoss }.
function Cast.Bars()
    local list = {}
    local function Add(bar, isBoss)
        if bar then list[#list + 1] = { bar, isBoss } end
    end
    Add(PlayerCastingBarFrame, false)
    Add(PetCastingBarFrame, false)
    Add(TargetFrame and TargetFrame.spellbar, false)
    Add(FocusFrame and FocusFrame.spellbar, false)
    local holder = BossTargetFrameContainer
    local frames = holder and holder.BossTargetFrames
    if type(frames) == "table" then
        for _, frame in ipairs(frames) do Add(frame.spellbar, true) end
    end
    return list
end

-- Your own bars: yours and your pet's (Cast Bar Colour colours only these).
function Cast.Own(bar)
    return bar ~= nil and (bar == PlayerCastingBarFrame or bar == PetCastingBarFrame)
end

-- A plain flag the game keeps on a frame, read only when it isn't hidden.
function Cast.Flag(value)
    if Look.Secret(value) then return false end
    return value and true or false
end

-- The bar's look as the game set it ("CLASSIC", "UNITFRAME", "OVERLAY").
-- The target's, focus's and bosses' bars never get one on this client: they
-- are the small UNITFRAME bars (they have AdjustPosition).
function Cast.LookOf(bar)
    local named = bar.look
    if type(named) == "string" and not Look.Secret(named) then return named end
    if type(bar.AdjustPosition) == "function" then return "UNITFRAME" end
    return "CLASSIC"
end

-- A full pass, asked for (in a fight the engine runs it when the fight ends).
function Cast.AskPass()
    if type(ns.ApplyAll) == "function" then ns.ApplyAll() end
end

---------------------------------------------------------------------------
-- The kind of cast, from the fill's atlas name alone
---------------------------------------------------------------------------

-- The game's bar type and interrupt flag are hidden for other units, so the
-- only thing read is the atlas name the game just put on the fill. nil when
-- there is none to read (EraUI's own fill is a file, not an atlas).
function Cast.KindOf(bar)
    local fill = bar:GetStatusBarTexture()
    if not fill then return nil end
    local fine, atlas = Look.Ask(fill, "GetAtlas")
    if not fine or Look.Secret(atlas) or type(atlas) ~= "string" then return nil end
    local name = atlas:lower()
    local function Has(word) return name:find(word, 1, true) ~= nil end
    if Has("interrupted") then return "interrupted" end
    if Has("full") then return Has("channel") and "channelDone" or "done" end
    if Has("channel") then return "channel" end
    if Has("uninterrupt") then return "locked" end
    return "cast"
end

---------------------------------------------------------------------------
-- Colours
---------------------------------------------------------------------------

-- The 1.x colours: the game's own named colour when this client has one.
local SHADES = {
    yellow = { "CASTBAR_CLASSIC_YELLOW", 1, 0.7, 0 },
    green = { "CASTBAR_CLASSIC_GREEN", 0, 1, 0 },
    red = { "CASTBAR_CLASSIC_RED", 1, 0, 0 },
    grey = { "CASTBAR_CLASSIC_GRAY", 0.5, 0.5, 0.5 },
}
local SHADE_OF_KIND = { cast = "yellow", channel = "green", channelDone = "green", done = "green",
    interrupted = "red", locked = "grey" }

local function Shade(entry)
    local named = _G[entry[1]]
    if type(named) == "table" and type(named.GetRGB) == "function" then
        local fine, r, g, b = pcall(named.GetRGB, named)
        if fine and Look.Number(r) and Look.Number(g) and Look.Number(b) then return r, g, b end
    end
    return entry[2], entry[3], entry[4]
end

-- The 1.x colour of a kind of cast (an unknown kind counts as a cast).
function Cast.ClassicRGB(kind)
    return Shade(SHADES[SHADE_OF_KIND[kind] or "yellow"])
end

local LIGHT_GREY = { 0.78, 0.80, 0.84 }
local PALADIN_PINK = { 0.96, 0.55, 0.73 }
local CHOICES = { classic = true, grey = true, class = true, custom = true }

-- Cast Bar Colour's choice for your own bars. Match look (anything else):
-- light grey in Dark Mode (as loaded at login), otherwise the 1.x colours.
function Cast.Choice()
    local picked = EraUI:GetSetting("castBarColour")
    if type(picked) == "string" and CHOICES[picked] then return picked end
    return EraUI:GetSetting("darkMode") and "grey" or "classic"
end

local function Unpacked(rgb) return rgb[1], rgb[2], rgb[3] end

-- Your class's colour: another addon's class colours first, Blizzard's after;
-- a paladin is always EraUI's pink. A hidden or unknown class: light grey.
local function ClassRGB()
    local fine, _, class = pcall(UnitClass, "player")
    if not fine or Look.Secret(class) or type(class) ~= "string" then return Unpacked(LIGHT_GREY) end
    if class == "PALADIN" then return Unpacked(PALADIN_PINK) end
    local theirs = type(CUSTOM_CLASS_COLORS) == "table" and CUSTOM_CLASS_COLORS[class] or nil
    local colour = theirs or (type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[class]) or nil
    if type(colour) == "table" and Look.Number(colour.r) and Look.Number(colour.g) and Look.Number(colour.b) then
        return colour.r, colour.g, colour.b
    end
    return Unpacked(LIGHT_GREY)
end

-- The Custom colour: six hex digits (either case), else EraUI's light grey.
local function CustomRGB()
    local hex = EraUI:GetSetting("castBarCustomColour")
    if type(hex) ~= "string" or not hex:find("^%x%x%x%x%x%x$") then hex = "C7CCD6" end
    local function Byte(at) return tonumber(hex:sub(at, at + 1), 16) / 255 end
    return Byte(1), Byte(3), Byte(5)
end

local function ChosenRGB(choice)
    if choice == "class" then return ClassRGB() end
    if choice == "custom" then return CustomRGB() end
    return Unpacked(LIGHT_GREY)
end

-- The colour a bar's fill takes for a kind of cast (nil: unknown). The
-- target's, focus's and bosses' bars always say what is worth interrupting
-- in the 1.x colours. Your own follow Cast Bar Colour, remembering the last
-- kind, so a switch mid-cast keeps an interrupt red and a locked cast grey.
function Cast.FillRGB(bar, kind)
    if not Cast.Own(bar) then return Cast.ClassicRGB(kind) end
    local choice = Cast.Choice()
    if choice == "classic" then
        if kind then Cast.kinds[bar] = kind end
        return Cast.ClassicRGB(kind)
    end
    kind = kind or Cast.kinds[bar] or "cast"
    Cast.kinds[bar] = kind
    if kind == "done" or kind == "interrupted" or kind == "locked" then return Cast.ClassicRGB(kind) end
    return ChosenRGB(choice)
end

-- The bar's fill: EraUI's shaded 1.x fill (Flat Bars' solid square while
-- that's on), coloured for the kind of cast just read.
function Cast.Fill(bar)
    local kind = Cast.KindOf(bar)
    bar:SetStatusBarTexture(Look.BarFill("statusBar"))
    bar:SetStatusBarColor(Cast.FillRGB(bar, kind))
end

-- Only the fill's file, for Look.Refill (the colour is put back by it).
function Cast.PutFill(bar)
    bar:SetStatusBarTexture(Look.BarFill("statusBar"))
end
