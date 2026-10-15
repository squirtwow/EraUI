-- EraUI cast bars.
-- The 1.x cast bars: 195x13 with the old border sheet, UI-StatusBar fills in
-- the old yellow/green/gray/red, a static spark and none of the modern flakes,
-- wisps and glow lines. Nothing here writes a field on a cast bar; secure
-- hooks put the classic art back after each change so Blizzard's own update
-- loop keeps running untouched.
-- The boss frames' cast bars can be styled by Forever Enhanced Cooldown
-- Manager instead (its Raid Timers page); see "Boss cast bars" below. The
-- player's and pet's fill can take another colour: "Cast Bar Colour" below.
local _, EraUI = ...
local ns = EraUI.Classic

local FX = { "Flakes01", "Flakes02", "Flakes03", "BaseGlow", "WispGlow", "Sparkles01", "Sparkles02", "Shine",
    "EnergyGlow", "InterruptGlow", "ChargeGlow", "ChargeFlash", "StandardGlow", "CraftGlow", "ChannelShadow", "DropShadow", "TextBorder" }
local FINISH_ANIMS = { "StandardFinish", "ChannelFinish", "CraftingFinish" }

-- The fill's art, through Classic/Textures.lua ns.BarFill: the Classic shaded
-- UI-StatusBar, or the solid square with Flat Bars on.
local FILL_KEY = "statusBar"
local COLORS = {
    yellow = CASTBAR_CLASSIC_YELLOW or CreateColor(1, 0.7, 0),
    green = CASTBAR_CLASSIC_GREEN or CreateColor(0, 1, 0),
    gray = CASTBAR_CLASSIC_GRAY or CreateColor(0.5, 0.5, 0.5),
    red = CASTBAR_CLASSIC_RED or CreateColor(1, 0, 0),
}

local active = false
local skinned = {}
local playerChannel
local function KeepPlayerChannel(bar)
    if not active or not playerChannel or EraUI:GetSetting("advancedCastBar")then return end
    bar:SetMinMaxValues(0,playerChannel.total)
    bar:SetValue(EraUI.CastTiming.Value(playerChannel,GetTime()))
    if bar.Spark then
        bar.Spark:ClearAllPoints()
        bar.Spark:SetPoint("CENTER",bar:GetStatusBarTexture(),"RIGHT",0,0)
    end
end
local function ReadPlayerChannel(bar,fresh)
    if not active or EraUI:GetSetting("advancedCastBar")then playerChannel=nil;return end
    local name,_,_,startMS,endMS,_,_,spellID,empowered=UnitChannelInfo("player")
    if (issecretvalue and issecretvalue(empowered))or empowered then playerChannel=nil;return end
    playerChannel=EraUI.CastTiming.Snapshot(playerChannel,true,name,startMS,endMS,spellID,fresh)
    KeepPlayerChannel(bar)
end

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

-- Boss cast bars ---------------------------------------------------------------
-- Forever Enhanced Cooldown Manager (Squirt's other addon) can style the boss
-- frames' cast bars too, from its Raid Timers page. It says whether it does
-- through its public API (ForeverEnhancedCooldownManagerAPI), never its
-- insides, and calls back each time that answer changes: before its look goes
-- on, and after Blizzard's is back. While it styles them, EraUI leaves those
-- bars alone, after putting back exactly what it changed on them; when it
-- hands them back, EraUI's look goes on again. The answer is asked on every
-- boss bar update, so both ways work at once, without a reload. Without that
-- addon, with one too old to have the API, or when its answer can't be read,
-- the boss bars are EraUI's as before.
local bossBars = {} -- the boss frames' cast bars
local before = {} -- each one's look before EraUI first dressed it (false if it couldn't be read)
local dressed = {} -- the boss bars in EraUI's look now
local shared = false -- told the other addon that EraUI steps back

-- Whether Forever Enhanced Cooldown Manager styles the boss cast bars now.
local function OtherStylesBoss()
    local api = _G.ForeverEnhancedCooldownManagerAPI
    if type(api) ~= "table" then return false end
    local ask = api.StylesBossCastBars
    if type(ask) ~= "function" then return false end
    local answer = ask()
    return not IsSecret(answer) and answer == true
end

-- A boss bar left to the other addon; anything unreadable leaves it EraUI's.
local function Yielded(bar)
    if not bossBars[bar] then return false end
    local ok, yes = pcall(OtherStylesBoss)
    return ok and yes == true
end

-- What EraUI changes on a boss bar, piece by piece: its art (atlas or texture,
-- coords and tint), its place (anchors and size), size alone, blend, font,
-- alpha and whether it shows.
local BOSS_PIECES = {
    Border = { art = true, place = true },
    BorderShield = { art = true, place = true },
    Flash = { art = true, place = true, blend = true },
    Spark = { art = true, size = true, blend = true },
    Background = { art = true, place = true },
    Text = { place = true, font = true },
    Icon = { place = true },
}

-- Values that can be put back as they were: nil if any of them is secret.
local function Plain(...)
    local values = { n = select("#", ...), ... }
    for i = 1, values.n do
        if IsSecret(values[i]) then return nil end
    end
    return values
end

local function Note(region, what)
    local was = {}
    if what.place then
        local points = {}
        for i = 1, region:GetNumPoints() do
            local point = Plain(region:GetPoint(i))
            if not point then
                points = nil
                break
            end
            points[i] = point
        end
        was.points = points
    end
    if what.place or what.size then was.size = Plain(region:GetSize()) end
    if what.art then
        local atlas = region:GetAtlas()
        if atlas and not IsSecret(atlas) then
            was.atlas = atlas
        else
            local texture = region:GetTexture()
            if texture and not IsSecret(texture) then was.texture = texture end
            was.coords = Plain(region:GetTexCoord())
        end
        was.tint = Plain(region:GetVertexColor())
    end
    if what.blend then was.blend = Plain(region:GetBlendMode()) end
    if what.font then was.font = Plain(region:GetFontObject()) end
    if what.alpha then was.alpha = Plain(region:GetAlpha()) end
    if what.shown then was.shown = Plain(region:IsShown()) end
    return was
end

-- Each piece on its own, so one that can't be read leaves the rest.
local function NoteBar(bar)
    local was = { size = Plain(bar:GetSize()), pieces = {} }
    local function Piece(key, what)
        local ok, piece = pcall(Note, bar[key], what)
        if ok then was.pieces[key] = piece end
    end
    for key, what in pairs(BOSS_PIECES) do
        if bar[key] then Piece(key, what) end
    end
    for _, key in ipairs(FX) do
        if bar[key] and not BOSS_PIECES[key] then Piece(key, { art = true, alpha = true, shown = true }) end
    end
    return was
end

local function Resize(object, size)
    if not size then return end
    local w, h = size[1], size[2]
    if type(w) == "number" and w > 0 then object:SetWidth(w) end
    if type(h) == "number" and h > 0 then object:SetHeight(h) end
end

local function PutBack(region, was)
    if was.points then
        region:ClearAllPoints()
        for _, point in ipairs(was.points) do region:SetPoint(unpack(point, 1, point.n)) end
    end
    Resize(region, was.size)
    if was.atlas then
        region:SetAtlas(was.atlas)
    else
        if was.texture then region:SetTexture(was.texture) end
        if was.coords then region:SetTexCoord(unpack(was.coords, 1, was.coords.n)) end
    end
    if was.tint then region:SetVertexColor(unpack(was.tint, 1, was.tint.n)) end
    -- Each mode by name (EraUI never sets MOD; Tools/TestBlendModes.mjs).
    local blend = was.blend and was.blend[1]
    if blend == "BLEND" then
        region:SetBlendMode("BLEND")
    elseif blend == "ADD" then
        region:SetBlendMode("ADD")
    elseif blend == "ALPHAKEY" then
        region:SetBlendMode("ALPHAKEY")
    elseif blend == "DISABLE" then
        region:SetBlendMode("DISABLE")
    end
    if was.font and was.font[1] then region:SetFontObject(was.font[1]) end
    if was.alpha then region:SetAlpha(was.alpha[1]) end
    if was.shown then region:SetShown(was.shown[1]) end
end

-- A boss bar's own size can't change while it's protected in a fight: it goes
-- back when the fight ends, unless EraUI has dressed the bar again by then.
local sizeAfterFight = {} -- handed-over boss bars waiting for Blizzard's size
local fightWatch

local function SizesAfterFight()
    for bar, size in pairs(sizeAfterFight) do
        sizeAfterFight[bar] = nil
        if not dressed[bar] then pcall(Resize, bar, size) end
    end
end

local function SizeBack(bar, size)
    if InCombatLockdown() and bar.IsProtected and bar:IsProtected() then
        sizeAfterFight[bar] = size
        if not fightWatch then
            fightWatch = CreateFrame("Frame")
            fightWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
            fightWatch:SetScript("OnEvent", SizesAfterFight)
        end
        return
    end
    sizeAfterFight[bar] = nil
    Resize(bar, size)
end

-- Blizzard's look back on a boss bar EraUI has dressed: what EraUI changed,
-- as it was, and nothing else.
local function GiveBack(bar)
    if not dressed[bar] then return end
    dressed[bar] = nil
    local was = before[bar]
    if not was then return end
    SizeBack(bar, was.size)
    for key, piece in pairs(was.pieces) do
        if bar[key] then pcall(PutBack, bar[key], piece) end
    end
end

-- 12.x never calls SetLook on the target, focus and boss spell bars, so their
-- look is unset; those are the small bars (they have AdjustPosition).
local function LookOf(bar)
    if bar.look then return bar.look end
    return bar.AdjustPosition and "UNITFRAME" or "CLASSIC"
end

-- Rounded Cast Bars -------------------------------------------------------------
-- Appearance > Style > Frame Style (off unless ticked; needs Cast Bars).
-- The player's, pet's, target's and focus's bars in EraUI's look get a thick
-- near-black shell with soft corners round the bar and the spell's icon,
-- which sits in a square tile of its own at the shell's left. The spell's
-- name goes to the left of the bar and the time left to its
-- right; a fine line runs just inside the shell: muted bronze in Classic,
-- the Darkness grey in Dark Mode, or the player's class colour with
-- Class-coloured Cast Border (Modules/ClassAccents.lua sets it). The Classic
-- border art is faded while it shows; the fill stays EraUI's (solid with
-- Flat Bars). All of it is EraUI's own: two frames per bar (the shell under
-- the bar, the time over it), made the first time the option shows, then
-- only shown, hidden and toned; state in weak tables; post-hooks only; no
-- key written on the game's bars. Off, nothing is made and every bar looks
-- as it does today. Boss bars are left out (Forever Enhanced Cooldown
-- Manager's Raid Timers can take those).
--
-- Per look, the bar's own size and the shell round it. CLASSIC: the player's
-- bar on its own (and the pet's), 195 wide as today, 18 tall. UNITFRAME: the
-- target's and focus's (and the player's and pet's while Edit Mode locks the
-- cast bar to the player frame), 150 wide, 14 tall. The icon's tile is as
-- tall as the bar. edge: the shell past the bar and the tile; corner: its
-- radius; inset: the name's and the time's room from the bar's ends; room:
-- how far in from the right the name stops, for the time; font: the name's
-- (Shape), which the time takes too.
local ROUND = {
    CLASSIC = { w = 195, h = 18, edge = 5, corner = 6, inset = 6, room = 40, font = "GameFontHighlight" },
    UNITFRAME = { w = 150, h = 14, edge = 4, corner = 5, inset = 4, room = 32, font = "SystemFont_Shadow_Small" },
}
local GAP = 3 -- between the icon's tile and the bar
local SHELL = { .05, .05, .06 } -- near black, as Thick Aura Borders' edge
local BRONZE = { .55, .46, .27 } -- the line in Classic (Thick Aura Borders' bronze)
local FLASH = .4 -- the solid flash's strength as a cast completes
-- A cast that can't be interrupted: the game's own shield round the tile, in
-- the proportions its own bars draw it round their icon (29x33 round 20x20).
local SHIELD_ATLAS, SHIELD_W, SHIELD_H = "ui-castingbar-shield", 1.45, 1.65
-- The shell's corners: quarters of the round portrait mask the game ships.
local CORNERS = {
    { "TOPLEFT", 0, .5, 0, .5 }, { "TOPRIGHT", .5, 1, 0, .5 },
    { "BOTTOMLEFT", 0, .5, .5, 1 }, { "BOTTOMRIGHT", .5, 1, .5, 1 },
}
-- bar: {shell, face, body, line, icon, time, on, geometry, r, g, b, justify,
-- trimmed, timeWas, timed, since}
local rounds = setmetatable({}, { __mode = "k" })
local classTint = setmetatable({}, { __mode = "k" }) -- bar: {r, g, b}, Class-coloured Cast Border's
local flashTinted = setmetatable({}, { __mode = "k" }) -- bars whose flash wears the soft tint

local function RoundedOn()
    return active and EraUI:GetSetting("roundedCastBars") == true
end

local function RoundGeometry(bar)
    return ROUND[LookOf(bar) == "UNITFRAME" and "UNITFRAME" or "CLASSIC"]
end

-- Whether a bar wears the rounded look now: the option on and a bar in
-- EraUI's look, never a boss bar. A protected bar in a fight keeps what it
-- wears until the pass after the fight; held then says so.
local function Rounding(bar)
    local state = rounds[bar]
    local on = state ~= nil and state.on == true
    local want = RoundedOn() and skinned[bar] == true and not bossBars[bar]
    if want ~= on and ns.HeldInFight and ns.HeldInFight(bar) then return on, true end
    return want, false
end

local function Shape(bar)
    local look = LookOf(bar)
    if look == "UNITFRAME" then
        bar:SetSize(150, 10)
        if bar.Border then
            ns.SetTex(bar.Border, "castBorderSmall")
            bar.Border:SetTexCoord(0, 1, 0, 1)
            bar.Border:ClearAllPoints()
            bar.Border:SetHeight(56)
            bar.Border:SetPoint("TOPLEFT", bar, "TOPLEFT", -23, 23)
            bar.Border:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 23, 23)
        end
        if bar.BorderShield then
            bar.BorderShield:ClearAllPoints()
            bar.BorderShield:SetHeight(56)
            bar.BorderShield:SetPoint("TOPLEFT", bar, "TOPLEFT", -28, 23)
            bar.BorderShield:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 18, 23)
        end
        if bar.Text then
            bar.Text:ClearAllPoints()
            bar.Text:SetHeight(16)
            bar.Text:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 4)
            bar.Text:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 4)
            bar.Text:SetFontObject("SystemFont_Shadow_Small")
        end
        if bar.Icon then
            bar.Icon:SetSize(18, 18)
            bar.Icon:ClearAllPoints()
            bar.Icon:SetPoint("RIGHT", bar, "LEFT", -3.5, 1)
        end
    elseif look == "CLASSIC" then
        bar:SetSize(195, 13)
        if bar.Border then
            ns.SetTex(bar.Border, "castBorder")
            bar.Border:SetTexCoord(0, 1, 0, 1)
            bar.Border:ClearAllPoints()
            bar.Border:SetSize(256, 64)
            bar.Border:SetPoint("TOP", bar, "TOP", 0, 28)
        end
        if bar.BorderShield then
            bar.BorderShield:ClearAllPoints()
            bar.BorderShield:SetSize(256, 64)
            bar.BorderShield:SetPoint("TOP", bar, "TOP", 0, 28)
        end
        if bar.Text then
            bar.Text:ClearAllPoints()
            bar.Text:SetSize(185, 16)
            bar.Text:SetPoint("TOP", bar, "TOP", 0, 5)
            bar.Text:SetFontObject("GameFontHighlight")
        end
    end
end

local function HideFx(bar)
    for _, key in ipairs(FX) do
        local region = bar[key]
        if region then
            if region.SetAtlas then region:SetAtlas(nil) end
            region:SetAlpha(0)
            region:Hide()
        end
    end
end

local function DressSpark(bar)
    if not bar.Spark then return end
    ns.SetTex(bar.Spark, "castSpark")
    bar.Spark:SetTexCoord(0, 1, 0, 1)
    -- Rounded Cast Bars: as tall as the shell, so its glow stays inside it.
    local size = 32
    if Rounding(bar) then
        local g = RoundGeometry(bar)
        size = g.h + 2 * g.edge
    end
    bar.Spark:SetSize(size, size)
    bar.Spark:SetBlendMode("ADD")
end

local function DressFlash(bar)
    if not bar.Flash then return end
    if Rounding(bar) then
        -- Rounded Cast Bars: a soft, even flash over the bar itself, as the
        -- Classic glow is drawn for the Classic border.
        ns.SetTex(bar.Flash, "statusBarSolid")
        bar.Flash:SetTexCoord(0, 1, 0, 1)
        bar.Flash:SetBlendMode("ADD")
        bar.Flash:ClearAllPoints()
        bar.Flash:SetAllPoints(bar)
        bar.Flash:SetVertexColor(1, 1, 1, FLASH)
        flashTinted[bar] = true
        return
    end
    local small = LookOf(bar) == "UNITFRAME"
    ns.SetTex(bar.Flash, small and "castFlashSmall" or "castFlash")
    bar.Flash:SetTexCoord(0, 1, 0, 1)
    bar.Flash:SetBlendMode("ADD")
    bar.Flash:ClearAllPoints()
    if small then
        bar.Flash:SetHeight(56)
        bar.Flash:SetPoint("TOPLEFT", bar, "TOPLEFT", -23, 23)
        bar.Flash:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 23, 23)
    else
        bar.Flash:SetSize(256, 64)
        bar.Flash:SetPoint("TOP", bar, "TOP", 0, 28)
    end
    -- Back from Rounded Cast Bars: the flash at its own full strength.
    if flashTinted[bar] then
        flashTinted[bar] = nil
        bar.Flash:SetVertexColor(1, 1, 1, 1)
    end
end

local function DressShield(bar)
    if not bar.BorderShield then return end
    ns.SetTex(bar.BorderShield, LookOf(bar) == "UNITFRAME" and "castSmallShield" or "castBorder")
    bar.BorderShield:SetTexCoord(0, 1, 0, 1)
end

-- The kind of cast from the modern atlas name, so the bar type (a secret
-- value for other units) is never read: interrupted, done (a finished
-- cast's full bar), channelDone (a channel's), channel, locked (can't be
-- interrupted) or cast. nil when there's no readable name (EraUI's own fill,
-- or a secret).
local function FillKind(atlas)
    if type(atlas) ~= "string" or IsSecret(atlas) then return nil end
    atlas = atlas:lower()
    if atlas:find("interrupted", 1, true) then return "interrupted" end
    if atlas:find("full", 1, true) then return atlas:find("channel", 1, true) and "channelDone" or "done" end
    if atlas:find("channel", 1, true) then return "channel" end
    if atlas:find("uninterrupt", 1, true) then return "locked" end
    return "cast"
end
-- The Classic colour of each kind (an unreadable name is a cast): yellow
-- while casting, green while channelling and as a cast finishes, red when
-- interrupted, grey when it can't be.
local KIND_COLOR = { interrupted = COLORS.red, done = COLORS.green, channelDone = COLORS.green, channel = COLORS.green,
    locked = COLORS.gray, cast = COLORS.yellow }

-- Cast Bar Colour (Casting) -------------------------------------------------
-- The fill of the player's and pet's bars while they cast or channel:
-- castBarColour "auto" (Match look, the default) is the Classic colours in
-- the Classic look, exactly as before, and the light grey in Dark Mode (read
-- as loaded, so it follows Dark Mode's own reload); "classic" the Classic
-- colours; "grey" the light grey; "class" the player's class colour (on the
-- pet's bar too); "custom" castBarCustomColour, a hex colour picked in /era.
-- With a colour of its own a channel takes it too, and so does a channel's
-- end; interrupted casts stay red, casts that can't be interrupted grey, and
-- a finished cast still flashes green. The target's, focus's and bosses'
-- bars keep the Classic colours: they say what's worth interrupting. The
-- kind of cast comes from the fill's atlas name only (FillKind); EraUI's own
-- fill has none, so each own bar's last kind is kept in a weak table.
local LIGHT_GREY = { .78, .80, .84 }
local CUSTOM_DEFAULT = "C7CCD6" -- Core/Init.lua's castBarCustomColour: the light grey
local CHOSEN = { classic = true, grey = true, class = true, custom = true }
local kinds = setmetatable({}, { __mode = "k" }) -- own bar: the kind of cast it shows

local function OwnBar(bar)
    return bar ~= nil and (bar == PlayerCastingBarFrame or bar == PetCastingBarFrame)
end

-- The colour chosen, with Match look (or anything unknown) read as the look's.
local function ColourChoice()
    local choice = EraUI:GetSetting("castBarColour")
    if CHOSEN[choice] then return choice end
    return EraUI:GetSetting("darkMode") and "grey" or "classic"
end

local function HexRGB(hex)
    if type(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x$") then hex = CUSTOM_DEFAULT end
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

-- The player's class colour (a paladin's pink as everywhere in EraUI), or
-- the light grey when it can't be read.
local function ClassRGB()
    local _, class = UnitClass("player")
    if type(class) ~= "string" or IsSecret(class) then return LIGHT_GREY[1], LIGHT_GREY[2], LIGHT_GREY[3] end
    if class == "PALADIN" then return .96, .55, .73 end
    local colour = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if colour then return colour.r, colour.g, colour.b end
    return LIGHT_GREY[1], LIGHT_GREY[2], LIGHT_GREY[3]
end

local function ChosenRGB(choice)
    if choice == "class" then return ClassRGB() end
    if choice == "custom" then return HexRGB(EraUI:GetSetting("castBarCustomColour")) end
    return LIGHT_GREY[1], LIGHT_GREY[2], LIGHT_GREY[3]
end

-- A bar's fill colour for a kind of cast (nil: its atlas couldn't be read).
-- In the Classic colours an unreadable one is a cast, as it always was; with
-- a colour of its own, an own bar keeps the kind it last showed. Only a
-- readable kind is remembered, so a bar shown again in the Classic colours
-- (no atlas left to read) doesn't forget it: a switch to a colour mid-cast
-- keeps a cast that can't be interrupted grey.
local function FillRGB(bar, kind)
    if not OwnBar(bar) then return KIND_COLOR[kind or "cast"]:GetRGB() end
    local choice = ColourChoice()
    if choice == "classic" then
        if kind then kinds[bar] = kind end
        return KIND_COLOR[kind or "cast"]:GetRGB()
    end
    kind = kind or kinds[bar] or "cast"
    kinds[bar] = kind
    if kind == "cast" or kind == "channel" or kind == "channelDone" then return ChosenRGB(choice) end
    return KIND_COLOR[kind]:GetRGB()
end

local function Fill(bar)
    if not active or Yielded(bar) then return end
    local tex = bar:GetStatusBarTexture()
    local atlas = tex and tex.GetAtlas and tex:GetAtlas()
    local kind = FillKind(atlas)
    bar:SetStatusBarTexture(ns.BarFill(FILL_KEY))
    bar:SetStatusBarColor(FillRGB(bar, kind))
end

local function CastFill(bar)
    bar:SetStatusBarTexture(ns.BarFill(FILL_KEY))
end

-- Rounded Cast Bars: the shell ------------------------------------------------
-- The line's colour for the look: the Darkness grey in Dark Mode (with the
-- slider), else muted bronze. Modules/AdvancedCastBar.lua draws the same line.
function ns.RoundedCastLine()
    if EraUI:GetSetting("darkMode") then
        if ns.DarkGrey then return ns.DarkGrey() end
        return .42, .44, .48
    end
    return BRONZE[1], BRONZE[2], BRONZE[3]
end

-- A bar's line in Class-coloured Cast Border's colour, or the look's own;
-- set only when it changes.
local function Tone(bar, state)
    local r, g, b
    local tint = classTint[bar]
    if tint then r, g, b = tint[1], tint[2], tint[3] else r, g, b = ns.RoundedCastLine() end
    if state.r == r and state.g == g and state.b == b then return end
    state.r, state.g, state.b = r, g, b
    for _, strip in ipairs(state.line) do strip:SetColorTexture(r, g, b, 1) end
end

-- One region pinned by two of the bar's corners.
local function Span(region, bar, from, x1, y1, to, x2, y2)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", bar, from, x1, y1)
    region:SetPoint("BOTTOMRIGHT", bar, to, x2, y2)
end

-- Every piece pinned to the bar by its corners, from the look's own sizes:
-- nothing about the bar's place or size is read (under the target's aura row
-- the game keeps its layout from addons, and no OnSizeChanged is needed).
-- Pinned again only when the look changes.
local function PinShell(state, bar, g)
    local left, out, c = GAP + g.h + g.edge, g.edge, g.corner
    local x = { TOPLEFT = -left, TOPRIGHT = out, BOTTOMLEFT = -left, BOTTOMRIGHT = out }
    local y = { TOPLEFT = out, TOPRIGHT = out, BOTTOMLEFT = -out, BOTTOMRIGHT = -out }
    for i, corner in ipairs(CORNERS) do
        local piece = state.body[i]
        piece:ClearAllPoints()
        piece:SetSize(c, c)
        piece:SetPoint(corner[1], bar, corner[1], x[corner[1]], y[corner[1]])
    end
    -- The middle at full height, then the left and right between the corners.
    Span(state.body[5], bar, "TOPLEFT", -left + c, out, "BOTTOMRIGHT", out - c, -out)
    Span(state.body[6], bar, "TOPLEFT", -left, out - c, "BOTTOMLEFT", -left + c, -out + c)
    Span(state.body[7], bar, "TOPRIGHT", out - c, out - c, "BOTTOMRIGHT", out, -out + c)
    -- The fine line: one unit wide, 2 to 1 units past the tile and the bar.
    local tile = GAP + g.h
    Span(state.line[1], bar, "TOPLEFT", -tile - 2, 2, "TOPRIGHT", 2, 1)
    Span(state.line[2], bar, "BOTTOMLEFT", -tile - 2, -1, "BOTTOMRIGHT", 2, -2)
    Span(state.line[3], bar, "TOPLEFT", -tile - 2, 1, "BOTTOMLEFT", -tile - 1, -1)
    Span(state.line[4], bar, "TOPRIGHT", 1, 1, "BOTTOMRIGHT", 2, -1)
    -- EraUI's own icon in the tile, and the time at the bar's right.
    state.icon:ClearAllPoints()
    state.icon:SetSize(g.h, g.h)
    state.icon:SetPoint("RIGHT", bar, "LEFT", -GAP, 0)
    state.time:ClearAllPoints()
    state.time:SetPoint("RIGHT", bar, "RIGHT", -g.inset, 0)
    state.time:SetFontObject(g.font)
end

local function Left(duration) return duration:GetRemainingDuration() end

-- The time left, from the bar's own numbers when they can be read, else from
-- the game's own duration for the cast (formatted by the font string, never
-- worked on here). Returns false when there's nothing to show.
local function Remaining(bar)
    local channel = bar.channeling
    if not (bar.casting or channel) then return false end
    local ok, value = pcall(bar.GetValue, bar)
    local okRange, _, high = pcall(bar.GetMinMaxValues, bar)
    if ok and okRange and not IsSecret(value) and not IsSecret(high) and type(value) == "number" and type(high) == "number" then
        if channel then return true, math.max(0, value) end
        return true, math.max(0, high - value)
    end
    local unit = bar.unit
    local getter = channel and UnitChannelDuration or UnitCastingDuration
    if not getter or IsSecret(unit) or type(unit) ~= "string" then return false end
    local okDuration, duration = pcall(getter, unit)
    if not okDuration or IsSecret(duration) or duration == nil then return false end
    local okLeft, left = pcall(Left, duration)
    if not okLeft then return false end
    return true, left
end

-- The time, a few times a second while the bar shows. The player's bar shows
-- the game's own cast time instead while Edit Mode's Show Cast Time is on.
local function Clock(bar, state, elapsed)
    state.since = (state.since or 0) + (type(elapsed) == "number" and elapsed or 0)
    if state.since < .05 then return end
    state.since = 0
    local own, gameShows = bar.CastTimeText, false
    if own then
        local shown = own:IsShown()
        gameShows = not IsSecret(shown) and shown == true
    end
    local ok, left
    if not gameShows then ok, left = Remaining(bar) end
    if not ok then
        if state.timed ~= false then state.timed = false; state.time:SetText("") end
        return
    end
    state.timed = true
    state.time:SetFormattedText("%.1f", left)
end

-- The shell, made the first time a bar shows it: a frame one level under the
-- bar (its body, the line and EraUI's own icon) and one over it (the time).
local function Build(bar)
    local shell = CreateFrame("Frame", nil, bar)
    local state = { shell = shell, body = {}, line = {} }
    for i = 1, 7 do
        local piece = shell:CreateTexture(nil, "BACKGROUND")
        if i <= #CORNERS then
            ns.SetTex(piece, "portraitMask")
            piece:SetTexCoord(CORNERS[i][2], CORNERS[i][3], CORNERS[i][4], CORNERS[i][5])
            piece:SetVertexColor(SHELL[1], SHELL[2], SHELL[3], 1)
        else
            piece:SetColorTexture(SHELL[1], SHELL[2], SHELL[3], 1)
        end
        state.body[i] = piece
    end
    for i = 1, 4 do state.line[i] = shell:CreateTexture(nil, "BORDER") end
    state.icon = shell:CreateTexture(nil, "ARTWORK")
    state.icon:SetTexCoord(.07, .93, .07, .93)
    local face = CreateFrame("Frame", nil, bar)
    face:SetAllPoints(bar)
    state.face = face
    state.time = face:CreateFontString(nil, "OVERLAY")
    state.time:SetJustifyH("RIGHT")
    face:SetScript("OnUpdate", function(_, elapsed) Clock(bar, state, elapsed) end)
    rounds[bar] = state
    return state
end

-- The shell one level under the bar, so the bar's fill draws over it. The
-- level is checked as a plain number first, and against the shell's own
-- level each time (the game can re-level the bar's children: Edit Mode's
-- lock moves the player's bar to the player frame, and that bar is raised
-- when it shows), so the shell never ends up over the fill.
local function Lower(state, bar)
    local level = bar:GetFrameLevel()
    if IsSecret(level) or type(level) ~= "number" then return end
    level = math.max(0, level - 1)
    if state.shell:GetFrameLevel() ~= level then state.shell:SetFrameLevel(level) end
end

-- EraUI's own icon shows the spell the game put on the bar's own icon (which
-- the game hides in this look). Passed on as it is, secret or not.
local function CopyIcon(bar, state)
    if not bar.Icon then return end
    local ok, texture = pcall(bar.Icon.GetTexture, bar.Icon)
    if ok then state.icon:SetTexture(texture) end
end

-- The rounded look on a bar, after Shape and the rest have dressed it in
-- EraUI's Classic look (so on every pass: the game's own calls reset parts).
local function Wear(bar)
    local g = RoundGeometry(bar)
    local state = rounds[bar] or Build(bar)
    if state.geometry ~= g then
        state.geometry = g
        PinShell(state, bar, g)
    end
    Lower(state, bar)
    if not (ns.HeldInFight and ns.HeldInFight(bar)) then bar:SetSize(g.w, g.h) end
    if bar.Border then bar.Border:SetAlpha(0) end
    -- The name at the bar's left, clear of the time.
    local text = bar.Text
    if text then
        if state.justify == nil then
            local justify = text:GetJustifyH()
            state.justify = (not IsSecret(justify) and type(justify) == "string") and justify or "CENTER"
        end
        text:ClearAllPoints()
        text:SetPoint("LEFT", bar, "LEFT", g.inset, 0)
        text:SetPoint("RIGHT", bar, "RIGHT", -g.room, 0)
        text:SetJustifyH("LEFT")
    end
    -- The icon: in this look EraUI already places the game's own (Shape), so
    -- it moves into the tile; the Classic look's is hidden by the game, so
    -- EraUI's own shows its spell there.
    local moved = LookOf(bar) == "UNITFRAME" and bar.Icon ~= nil
    if moved then
        bar.Icon:SetSize(g.h, g.h)
        bar.Icon:ClearAllPoints()
        bar.Icon:SetPoint("RIGHT", bar, "LEFT", -GAP, 0)
        bar.Icon:SetTexCoord(.07, .93, .07, .93)
        state.trimmed = true
    elseif state.trimmed then
        state.trimmed = nil
        bar.Icon:SetTexCoord(0, 1, 0, 1)
    end
    state.icon:SetShown(not moved)
    if not moved then CopyIcon(bar, state) end
    -- The game shows and hides it; held by two points, so no size of its own
    -- is changed (Shape's own places it again when the look goes off).
    if bar.BorderShield then
        local shield, x, w, h = bar.BorderShield, -(GAP + g.h / 2), g.h * SHIELD_W / 2, g.h * SHIELD_H / 2
        shield:SetAtlas(SHIELD_ATLAS)
        shield:ClearAllPoints()
        shield:SetPoint("TOPLEFT", bar, "LEFT", x - w, 1 + h)
        shield:SetPoint("BOTTOMRIGHT", bar, "LEFT", x + w, 1 - h)
    end
    -- The player's bar has the game's own cast time (Edit Mode's Show Cast
    -- Time): inside the bar at the right too, where it was noted first.
    local own = bar.CastTimeText
    if own then
        if state.timeWas == nil then
            local points = {}
            for i = 1, own:GetNumPoints() do
                points[i] = Plain(own:GetPoint(i))
                if not points[i] then points = nil break end
            end
            local font = Plain(own:GetFontObject())
            state.timeWas = points and { points = points, font = font and font[1] } or false
        end
        -- One that can't be read stays where the game put it.
        if state.timeWas then
            own:ClearAllPoints()
            own:SetPoint("RIGHT", bar, "RIGHT", -g.inset, 0)
            own:SetFontObject(g.font)
        end
    end
    state.on = true
    state.shell:Show()
    state.face:Show()
    Tone(bar, state)
    -- Class-coloured Cast Border's copy of the Classic border never shows on
    -- the shell, whichever of the two ran first.
    local accents = EraUI.modules and EraUI.modules.ClassAccents
    if accents and accents.HideCastOutline then accents:HideCastOutline(bar) end
end

-- The rounded look off a bar: what Shape and the rest don't put back
-- themselves (they have just dressed it in EraUI's Classic look again).
local function TakeOff(bar)
    local state = rounds[bar]
    if not state or not state.on then return end
    state.on = false
    state.shell:Hide()
    state.face:Hide()
    state.timed = false
    state.time:SetText("")
    if bar.Border then bar.Border:SetAlpha(1) end
    if bar.Text and state.justify then bar.Text:SetJustifyH(state.justify) end
    if state.trimmed and bar.Icon then
        state.trimmed = nil
        bar.Icon:SetTexCoord(0, 1, 0, 1)
    end
    local own, was = bar.CastTimeText, state.timeWas
    if own and was then
        own:ClearAllPoints()
        for _, point in ipairs(was.points) do own:SetPoint(unpack(point, 1, point.n)) end
        if was.font then own:SetFontObject(was.font) end
    end
    -- Class-coloured Cast Border's copy comes back on the Classic look.
    local accents = EraUI.modules and EraUI.modules.ClassAccents
    if accents and accents.Refresh then accents:Refresh() end
end

-- One bar's rounded look, on or off, at the end of each dressing. A
-- protected bar in a fight keeps its look; a pass is booked for the end of
-- the fight (Classic/Core.lua ns.ApplyAll).
local function Round(bar)
    local want, held = Rounding(bar)
    if held and ns.ApplyAll then ns.ApplyAll() end
    if want then Wear(bar) else TakeOff(bar) end
end

local Position
Position = function(bar)
    if not active or bar.boss then return end
    if InCombatLockdown() and bar.IsProtected and bar:IsProtected() then return end
    local parent = bar:GetParent()
    if not parent or not parent.GetAuraContainer then return end
    if parent.smallSize then
        if bar:GetScale() ~= 1 then bar:SetScale(1) end
    end
    local container = parent:GetAuraContainer()
    local ok, _, relativeTo = pcall(bar.GetPoint, bar, 1)
    local underAuras = ok and container ~= nil and relativeTo == container
    if ns.OnSpellBarPlaced then ns.OnSpellBarPlaced(bar, underAuras, parent) end
    bar:ClearAllPoints()
    if underAuras then
        bar:SetPoint("TOPLEFT", container, "BOTTOMLEFT", 22, -16)
        return
    end
    local y = 3
    -- A thick frame (Classic/ThickFrames.lua) has no elite art below it, but
    -- its level's pill and target of target sit lower.
    local thickY = ns.ThickCastY and ns.ThickCastY(parent)
    if thickY then
        y = thickY
    elseif parent.haveToT then
        y = -25
    elseif ns.UnitFrameOwn and ns.UnitFrameOwn(parent, "haveElite") then
        -- The elite art flag EraUI's unit frames keep for the frame
        -- (Classic/UnitFrames.lua), never a key on the game's frame.
        y = -9
    end
    bar:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 43, y)
end

local function StopFinishAnims(bar)
    for _, key in ipairs(FINISH_ANIMS) do
        local anim = bar[key]
        if anim and anim.Stop then anim:Stop() end
    end
    HideFx(bar)
end

local function Dress(bar)
    if not active then return end
    if bossBars[bar] then
        if Yielded(bar) then return end
        -- Blizzard's look, read the first time, to put back when the bar is handed over.
        if before[bar] == nil then
            local ok, was = pcall(NoteBar, bar)
            before[bar] = ok and was or false
        end
        dressed[bar] = true
    end
    Shape(bar)
    if bar.Background then
        bar.Background:SetAtlas(nil)
        bar.Background:SetColorTexture(0, 0, 0, 0.5)
        bar.Background:ClearAllPoints()
        bar.Background:SetAllPoints(bar)
    end
    DressSpark(bar)
    DressFlash(bar)
    DressShield(bar)
    HideFx(bar)
    Round(bar)
    Fill(bar)
    if bar.AdjustPosition then Position(bar) end
end

-- The look again without the fill (so each bar keeps its colour): Rounded
-- Cast Bars switched in /era.
local function Restyle(bar)
    Shape(bar)
    DressSpark(bar)
    DressFlash(bar)
    DressShield(bar)
    Round(bar)
end

local function Skin(bar, boss)
    if not bar then return end
    if boss then bossBars[bar] = true end
    if not skinned[bar] then
        skinned[bar] = true
        if bar==PlayerCastingBarFrame then
            ns.HookMethod(bar,"HandleCastStart",function(b,event)
                playerChannel=nil
                if event=="UNIT_SPELLCAST_CHANNEL_START"then ReadPlayerChannel(b,true)end
            end)
            ns.HookMethod(bar,"HandleChannelUpdateDelayed",function(b)ReadPlayerChannel(b,false)end)
            ns.HookMethod(bar,"FinishSpell",function()playerChannel=nil end)
            ns.HookMethod(bar,"HandleCastStop",function()playerChannel=nil end)
            ns.HookMethod(bar,"HandleInterruptOrSpellFailed",function()playerChannel=nil end)
            bar:HookScript("OnHide",function()playerChannel=nil end)
            bar:HookScript("OnUpdate",KeepPlayerChannel)
        end
        ns.HookMethod(bar, "SetLook", Dress)
        ns.HookMethod(bar, "UpdateShownState", Dress)
        if bar.AdjustPosition then
            ns.HookMethod(bar, "AdjustPosition", Position)
            local parent = bar:GetParent()
            if parent and parent.SetSmallSize then
                ns.HookMethod(parent, "SetSmallSize", function() Position(bar) end)
            end
        end
        ns.HookMethod(bar, "UpdateBarFillTexture", Fill)
        ns.HookMethod(bar, "ShowSpark", function(b)
            if not active or Yielded(b) then return end
            DressSpark(b)
            HideFx(b)
        end)
        ns.HookMethod(bar, "PlayFadeAnim", function(b)
            if active and not Yielded(b) then DressFlash(b) end
        end)
        ns.HookMethod(bar, "PlayFinishAnim", function(b)
            if active and not Yielded(b) then StopFinishAnims(b) end
        end)
        ns.HookMethod(bar, "PlayInterruptAnims", function(b)
            if active and not Yielded(b) then HideFx(b) end
        end)
    end
    Dress(bar)
end

-- Called by Forever Enhanced Cooldown Manager each time it takes the boss bars
-- or hands them back: Blizzard's look back on each bar it now styles (before
-- its own goes on), EraUI's look on each bar it has handed back.
local function Handover()
    for bar in pairs(bossBars) do
        if Yielded(bar) then pcall(GiveBack, bar) else pcall(Dress, bar) end
    end
end

-- Flat Bars switched in /era (Classic/Skin.lua ns.RefreshFlatBars): the new
-- fill on every bar in EraUI's look now, in the colour it has (Fill would
-- read the colour from the game's own fill, which EraUI's has replaced).
-- Boss bars the other addon styles are left alone. Returns false when a
-- protected bar waits for the end of a fight.
function ns.RefreshCastFills()
    if not active then return true end
    local done = true
    for bar in pairs(skinned) do
        if not bossBars[bar] or (dressed[bar] and not Yielded(bar)) then
            if ns.HeldInFight(bar) then done = false else ns.Refill(bar, CastFill) end
        end
    end
    return done
end

-- Cast Bar Colour chosen in /era (Core/Settings.lua): the player's and pet's
-- bars take it at once, mid-cast too, for the kind of cast each shows now.
-- Only their colour changes (a cosmetic setter, as each cast's own fill sets
-- in a fight too); the other bars are left alone.
function ns.RefreshCastColours()
    if not active then return end
    for bar in pairs(skinned) do
        if OwnBar(bar) then bar:SetStatusBarColor(FillRGB(bar, kinds[bar])) end
    end
end

-- Rounded Cast Bars switched in /era: every bar in EraUI's look takes its
-- new look at once (a bar that never wore the rounded one is left alone when
-- it's switched off), keeping its fill and colour. A protected bar in a fight
-- waits for the pass after it. Returns false when one waits.
function ns.RefreshRoundedCasts()
    if not active then return true end
    local done = true
    for bar in pairs(skinned) do
        if not bossBars[bar] then
            local want, held = Rounding(bar)
            local state = rounds[bar]
            if held then
                done = false
            elseif want or (state and state.on) then
                Restyle(bar)
            end
        end
    end
    if not done and ns.ApplyAll then ns.ApplyAll() end
    return done
end

-- Modules/ClassAccents.lua: whether a cast bar wears the rounded shell now
-- (its class colour then goes on the shell's line, not on a copy of the
-- faded border), and that colour (none: the look's own line again).
function ns.RoundedCastShown(bar)
    local state = rounds[bar]
    return state ~= nil and state.on == true
end
function ns.TintRoundedCast(bar, r, g, b)
    if not bar then return end
    classTint[bar] = r and { r, g, b } or nil
    local state = rounds[bar]
    if state and state.on then Tone(bar, state) end
end

-- The Darkness slider (Core/Appearance.lua RefreshDarkness): each line in
-- Dark Mode's grey takes the new shade at once, the Advanced Cast Bar's too.
function ns.RefreshRoundedCastLines()
    for bar, state in pairs(rounds) do
        if state.on then Tone(bar, state) end
    end
    local advanced = EraUI.modules and EraUI.modules.AdvancedCastBar
    if advanced and advanced.RefreshLine then advanced:RefreshLine() end
end

-- Tells Forever Enhanced Cooldown Manager, once, that EraUI steps back from the
-- boss bars while it styles them (until then it leaves them to EraUI's Cast
-- Bars). Said at login, even when a fight holds EraUI's first pass back (a
-- /reload in one), and tried again on each pass until it's there to hear it.
local function Share()
    if shared then return end
    local ok, done = pcall(function()
        local api = _G.ForeverEnhancedCooldownManagerAPI
        if type(api) ~= "table" then return false end
        local share = api.ShareBossCastBars
        if type(share) ~= "function" then return false end
        return share("EraUI", Handover)
    end)
    shared = ok and done == true
end

local function Apply()
    active = true
    Share()
    Skin(PlayerCastingBarFrame)
    Skin(PetCastingBarFrame)
    if TargetFrame then Skin(TargetFrame.spellbar) end
    if FocusFrame then Skin(FocusFrame.spellbar) end
    local bosses = BossTargetFrameContainer and BossTargetFrameContainer.BossTargetFrames
    if bosses then
        for _, boss in pairs(bosses) do Skin(boss.spellbar, true) end
    end
end

local function Restore()
    active = false
    for bar in pairs(skinned) do
        -- A boss bar EraUI isn't dressing (the other addon's) is left alone.
        if not bossBars[bar] or (dressed[bar] and not Yielded(bar)) then
            TakeOff(bar)
            if bar.Border then bar.Border:SetAtlas("ui-castingbar-frame") end
            if bar.Spark then bar.Spark:SetAtlas("ui-castingbar-pip") end
            if bar.Flash then bar.Flash:SetAtlas("ui-castingbar-full-glow-standard") end
            if bar.Background then bar.Background:SetAtlas("ui-castingbar-background") end
            for _, key in ipairs(FX) do
                if bar[key] then bar[key]:SetAlpha(1) end
            end
        end
    end
    ns.needsReload = true
end

-- init runs at login with Cast Bars on, before the first pass, fight or not.
ns.RegisterModule("castBars", { init = Share, apply = Apply, restore = Restore })
