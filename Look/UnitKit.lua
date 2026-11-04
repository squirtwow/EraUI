-- The unit frames' kit (Classic look, "unitFrames"): what the player, target,
-- focus, target-of-target, pet and party files share.
--
-- EraUI only dresses the game's unit frames: it moves, sizes and colours their
-- art and text, lays its own status bars over the game's (faded) ones and
-- never replaces a frame, a script or a click. Everything EraUI keeps about a
-- game frame lives in a weak-keyed record here (UF.Note), never on the frame:
-- a key written there would carry EraUI's taint into the game's own code.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local UF = { active = false, waiting = false }
Look.UF = UF

local records = Look.Weak()   -- a game frame or region: EraUI's record for it
UF.dressed = Look.Weak()      -- game frame: "player", "target", "focus" or "party"
UF.ownBars = Look.Weak()      -- EraUI's own status bars (Flat Bars refills them)
UF.overlayFills = Look.Weak() -- the game's heal and absorb fills, now on EraUI's bars
UF.lossBars = Look.Weak()     -- the player's red health-loss bar
UF.petBars = Look.Weak()      -- the pet's own bars: "health" or "power"

UF.FULL = { 0, 1, 0, 1 }

function UF.Note(owner)
    local record = records[owner]
    if not record then
        record = {}
        records[owner] = record
    end
    return record
end

function UF.Peek(owner)
    return owner and records[owner] or nil
end

-- What other files may read (the cast bars: "haveElite"; the debug report:
-- "host"; the tests). Read only; nil for anything unknown.
local READABLE = {
    host = "host", holder = "holder", barHost = "barHost", artHolder = "artHolder", totArt = "art",
    health = "health", power = "power", totHealth = "health", totPower = "power", barBg = "backing",
    rest = "rest", fight = "fight", banner = "banner", haveElite = "elite", lastClassification = "kind",
}
function ns.UnitFrameOwn(frame, key)
    local record, field = frame and records[frame], READABLE[key]
    if not record or not field then return nil end
    return record[field]
end

---------------------------------------------------------------------------
-- Settings and Thick Frames
---------------------------------------------------------------------------

function UF.Setting(key)
    return EraUI:GetSetting(key)
end

-- A per-frame Classic key (unitFramePlayer...): only an explicit false is off.
function UF.FrameOn(key)
    local saved = ns.db
    return not (type(saved) == "table" and saved[key] == false)
end

-- Thick Frames (a file of its own, loaded before this one; absent in some tests).
function UF.Thick()
    local thick = ns.Thick
    return type(thick) == "table" and thick or nil
end

function UF.ThickCall(name, ...)
    local thick = UF.Thick()
    local fn = thick and thick[name]
    if type(fn) == "function" then return fn(...) end
end

function UF.ThickWant(kind)
    return UF.ThickCall("Want", kind) and true or false
end

function UF.ThickWorn(frame)
    if not frame then return false end
    return UF.ThickCall("Worn", frame) and true or false
end

function UF.ThickNumber(name, fallback)
    local thick = UF.Thick()
    return thick and Look.Number(thick[name]) or fallback
end

---------------------------------------------------------------------------
-- EraUI's own frames and bars
---------------------------------------------------------------------------

-- A frame of EraUI's covering a game frame: mouse off, every point on it.
function UF.Cover(owner)
    local made = CreateFrame("Frame", nil, owner)
    made:EnableMouse(false)
    made:SetAllPoints(owner)
    return made
end

function UF.SetLevel(frame, level)
    if frame and level and Look.Number(frame:GetFrameLevel()) ~= level then frame:SetFrameLevel(level) end
end

function UF.Level(frame)
    return frame and Look.Number(frame:GetFrameLevel()) or 0
end

-- The bars' host and the text holder (the game's bar texts move onto EraUI's
-- bars, parented to the holder so they draw over the frame's art).
function UF.Host(owner, record)
    record.host = record.host or UF.Cover(owner)
    record.host:Show()
    return record.host
end

function UF.Holder(owner, record, level)
    record.holder = record.holder or UF.Cover(owner)
    UF.SetLevel(record.holder, level)
    record.holder:Show()
    return record.holder
end

-- An EraUI texture kept in a record (made once).
function UF.OwnTexture(record, field, owner, layer, sublevel)
    local texture = record[field]
    if not texture then
        texture = owner:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
        record[field] = texture
    end
    return texture
end

-- The black backing behind a frame's bars.
function UF.Backing(record, owner, width, height, relative, x, y, sublevel)
    local backing = UF.OwnTexture(record, "backing", owner, "BACKGROUND", sublevel)
    backing:SetColorTexture(0, 0, 0, 0.5)
    backing:SetSize(width, height)
    Look.Pin(backing, "TOPLEFT", relative, "TOPLEFT", x, y)
    backing:Show()
    return backing
end

function UF.PaintOwn(bar)
    bar:SetStatusBarTexture(Look.BarFill("statusBar"))
    local fill = bar:GetStatusBarTexture()
    if fill then fill:SetTexCoord(0, 1, 0, 1) end
end

function UF.PaintFill(bar)
    bar:SetStatusBarTexture(Look.BarFill("statusBar"))
end

-- One of EraUI's own bars, made once into the record, then sized, filled,
-- placed and shown on every pass. start: its first colour.
function UF.OwnBar(record, field, host, width, height, x, y, start)
    local bar = record[field]
    if not bar then
        bar = CreateFrame("StatusBar", nil, host)
        bar:EnableMouse(false)
        if start then bar:SetStatusBarColor(start[1], start[2], start[3]) end
        UF.ownBars[bar] = true
        record[field] = bar
    end
    bar:SetSize(width, height)
    Look.Refill(bar, UF.PaintOwn)
    Look.Pin(bar, "TOPLEFT", host, "TOPLEFT", x, y)
    bar:Show()
    return bar
end

-- Values go straight to the bar, secret or not; only a readable maximum is
-- ever compared (a secret is asked about first, never tested against nil).
local function Missing(value)
    return not Look.Secret(value) and value == nil
end

local function Feed(bar, value, most)
    if Missing(value) or Missing(most) then return false end
    local top = Look.Number(most)
    if top and top <= 0 then
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
    else
        bar:SetMinMaxValues(0, most)
        bar:SetValue(value)
    end
    return true
end

function UF.FillHealth(bar, unit)
    if bar and Feed(bar, UnitHealth(unit), UnitHealthMax(unit)) then bar:SetStatusBarColor(Look.HealthColor(unit)) end
end

function UF.FillPower(bar, unit)
    if bar and Feed(bar, UnitPower(unit), UnitPowerMax(unit)) then bar:SetStatusBarColor(Look.PowerColor(unit)) end
end

function UF.Empty(bar)
    if not bar then return end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
end

-- Does the unit exist? A hidden answer counts as yes (its values are fed as they are).
function UF.Exists(unit)
    if type(unit) ~= "string" then return false end
    local there = UnitExists(unit)
    return Look.Secret(there) or there and true or false
end

---------------------------------------------------------------------------
-- The game's pieces
---------------------------------------------------------------------------

-- A piece of 1.x art on a texture: art, crop, size, one anchor, layer. The
-- keepers re-dress art on every pass (fights too), so the anchor is compared
-- first and only moved when the game moved it (the target's aura row hangs
-- on its frame art).
function UF.Dress(texture, key, crop, width, height, point, relative, relativePoint, x, y, layer, sublevel)
    if not texture then return end
    Look.Art(texture, key)
    if crop then texture:SetTexCoord(crop[1], crop[2], crop[3], crop[4]) end
    if width then texture:SetSize(width, height) end
    if point then UF.KeepAt(texture, point, relative, relativePoint, x, y) end
    if layer then texture:SetDrawLayer(layer, sublevel) end
end

-- A game text moved onto one of EraUI's bars.
function UF.MoveText(text, holder, bar, point, x, y)
    if not text or not bar then return end
    text:SetParent(holder)
    text:SetDrawLayer("OVERLAY")
    Look.Pin(text, point, bar, point, x, y)
end

-- Reads one anchor; nil when any part of it is kept secret.
local function ReadPoint(region, index)
    local point, relative, relativePoint, x, y = region:GetPoint(index)
    if Look.Secret(point) or Look.Secret(relative) or Look.Secret(relativePoint) or Look.Secret(x) or Look.Secret(y) then
        return nil
    end
    return point, relative, relativePoint, Look.Number(x), Look.Number(y)
end

local function Matches(region, index, point, relative, relativePoint, x, y)
    local p, r, rp, px, py = ReadPoint(region, index)
    return p == point and r == relative and rp == relativePoint and px ~= nil and py ~= nil
        and math.abs(px - x) <= 0.5 and math.abs(py - y) <= 0.5
end

-- True when a region's first anchor is this one (within half a unit).
function UF.FirstPointIs(region, point, relative, relativePoint, x, y)
    return Matches(region, 1, point, relative, relativePoint, x, y)
end

-- True when it has exactly this one anchor.
function UF.OnlyPointIs(region, point, relative, relativePoint, x, y)
    local count = region:GetNumPoints()
    if Look.Secret(count) or count ~= 1 then return false end
    return Matches(region, 1, point, relative, relativePoint, x, y)
end

-- Compare first, move only what moved.
function UF.KeepAt(region, point, relative, relativePoint, x, y)
    if region and relative and not UF.OnlyPointIs(region, point, relative, relativePoint, x, y) then
        Look.Pin(region, point, relative, relativePoint, x, y)
    end
end

-- The game's bar laid exactly under EraUI's, so the heal and absorb pieces
-- it draws start at the end of EraUI's fill.
function UF.Pin(gameBar, ours)
    gameBar:ClearAllPoints()
    gameBar:SetPoint("TOPLEFT", ours, "TOPLEFT", 0, 0)
    gameBar:SetPoint("BOTTOMRIGHT", ours, "BOTTOMRIGHT", 0, 0)
end

-- Since build 70425 the game puts its bar back in its own spot on target,
-- focus and classification changes and the player's form or vehicle art: the
-- keepers pin it again, in a fight too unless the game guards it then. A bar
-- already lying there is only read; secret anchors count as moved.
local function LiesUnder(gameBar, ours)
    local count = gameBar:GetNumPoints()
    if Look.Secret(count) or count ~= 2 then return false end
    local corners = {}
    for i = 1, 2 do
        local point, relative, relativePoint, x, y = ReadPoint(gameBar, i)
        if (point ~= "TOPLEFT" and point ~= "BOTTOMRIGHT") or relative ~= ours or relativePoint ~= point
            or not x or not y or math.abs(x) > 0.01 or math.abs(y) > 0.01 or corners[point] then
            return false
        end
        corners[point] = true
    end
    return true
end

function UF.KeepPin(gameBar, ours)
    if not gameBar or not ours or LiesUnder(gameBar, ours) then return end
    if Look.HeldInFight(gameBar) then
        UF.waiting = true
        return
    end
    UF.Pin(gameBar, ours)
end

-- The heal prediction and absorb pieces of the game's health bar, onto EraUI's.
local OVERLAYS = Look.Words("MyHealPredictionBar OtherHealPredictionBar HealAbsorbBar TotalAbsorbBar")

local function Unmask(texture, mask)
    if texture and mask then Look.Ask(texture, "RemoveMaskTexture", mask) end
end
UF.Unmask = Unmask

function UF.TakeOverlays(gameBar, ours, mask)
    local fill = Look.BarFill("statusBar")
    for _, key in ipairs(OVERLAYS) do
        local piece = gameBar[key]
        if piece then
            piece:SetParent(ours)
            Look.Fill(piece, ours)
            local inside = piece.Fill
            if inside then
                Unmask(inside, mask)
                inside:SetTexture(fill)
                UF.overlayFills[inside] = true
            end
        end
    end
    local over = gameBar.OverAbsorbGlow
    if over then
        over:SetParent(ours)
        Unmask(over, mask)
        over:ClearAllPoints()
        over:SetPoint("TOPLEFT", ours, "TOPRIGHT", -7, 0)
        over:SetPoint("BOTTOMLEFT", ours, "BOTTOMRIGHT", -7, 0)
    end
    local under = gameBar.OverHealAbsorbGlow
    if under then
        under:SetParent(ours)
        Unmask(under, mask)
        under:ClearAllPoints()
        under:SetPoint("TOPRIGHT", ours, "TOPLEFT", 7, 0)
        under:SetPoint("BOTTOMRIGHT", ours, "BOTTOMLEFT", 7, 0)
    end
end

---------------------------------------------------------------------------
-- PvP: the 1.x banner instead of the modern icon
---------------------------------------------------------------------------

local BANNERS = {
    FFA = "Interface\\TargetingFrame\\UI-PVP-FFA",
    Horde = "Interface\\TargetingFrame\\UI-PVP-Horde",
    Alliance = "Interface\\TargetingFrame\\UI-PVP-Alliance",
}

-- known (false when the game won't say), then the answer.
local function Asked(fn, unit)
    if type(fn) ~= "function" then return true, nil end
    local fine, answer = pcall(fn, unit)
    if not fine or Look.Secret(answer) then return false end
    return true, answer
end

-- known, then the banner's file (nil: no banner).
function UF.BannerFile(unit)
    local known, open = Asked(UnitIsPVPFreeForAll, unit)
    if not known then return false end
    if open then return true, BANNERS.FFA end
    local flaggedKnown, flagged = Asked(UnitIsPVP, unit)
    if not flaggedKnown then return false end
    if not flagged then return true, nil end
    local sideKnown, side = Asked(UnitFactionGroup, unit)
    if not sideKnown then return false end
    return true, (side == "Horde" or side == "Alliance") and BANNERS[side] or nil
end

function UF.Banner(record, holder)
    local banner = record.banner
    if not banner then
        banner = holder:CreateTexture(nil, "OVERLAY")
        banner:SetSize(64, 64)
        banner:SetTexCoord(0, 1, 0, 1)
        record.banner = banner
    end
    return banner
end

-- The banner for the unit's flag, the game's own icon faded under it; when
-- the game won't say, the game's own icon shows. True while the banner shows.
function UF.ShowBanner(banner, gameIcon, unit)
    if not banner then return false end
    local known, file = UF.BannerFile(unit)
    if not known then
        Look.Shown(banner, false)
        Look.Alpha(gameIcon, 1)
        return false
    end
    Look.Fade(gameIcon)
    if file then banner:SetTexture(file) end
    Look.Shown(banner, file ~= nil)
    return file ~= nil
end

-- The modern PvP background on the player's or target's content.
local PVP_HOMES = Look.Words("PlayerFrameContentMain PlayerFrameContentContextual TargetFrameContentMain TargetFrameContentContextual")
function UF.FadePvpBackground(frame)
    local content = frame and (frame.PlayerFrameContent or frame.TargetFrameContent)
    if type(content) ~= "table" then return end
    for _, key in ipairs(PVP_HOMES) do
        local part = content[key]
        if part then
            Look.Fade(part.PvpBackgroundCircle)
            Look.Fade(part.PvpBackgroundIcon)
        end
    end
end

---------------------------------------------------------------------------
-- Hide Aggro Highlight: the threat flash and status glows held at 0
---------------------------------------------------------------------------

local holding = false -- EraUI's own SetAlpha inside the hook
local function HoldDown(texture)
    if holding or not UF.active or not UF.Setting("disableAggroHighlight") then return end
    holding = true
    texture:SetAlpha(0)
    holding = false
end

-- Once per texture: after the game's own SetAlpha or Show, back to 0 while
-- the look is on and the option too. With the option on, 0 at once.
function UF.HoldGlow(texture)
    if not texture then return end
    Look.Hook(texture, "SetAlpha", HoldDown)
    Look.Hook(texture, "Show", HoldDown)
    if UF.Setting("disableAggroHighlight") then
        holding = true
        texture:SetAlpha(0)
        holding = false
    end
end

-- The player's and the target's flash: 0 with the option on, else 1.
function UF.GlowAlpha(texture)
    if not texture then return end
    if UF.Setting("disableAggroHighlight") then return end
    holding = true
    texture:SetAlpha(1)
    holding = false
end

---------------------------------------------------------------------------
-- Small reads
---------------------------------------------------------------------------

-- A texture the game has put a modern atlas on (a readable, non-empty name).
function UF.HasAtlas(texture)
    if not texture then return false end
    local fine, atlas = Look.Ask(texture, "GetAtlas")
    return fine and not Look.Secret(atlas) and type(atlas) == "string" and atlas ~= ""
end

-- "fine", "undone" (the game put its own art back) or "unknown" (secret):
-- a 128 x 64 1.x art piece with one anchor, TOPLEFT on its owner at (x, y).
function UF.ArtState(texture, owner, x, y)
    local fine, atlas = Look.Ask(texture, "GetAtlas")
    if fine then
        if Look.Secret(atlas) then return "unknown" end
        if type(atlas) == "string" and atlas ~= "" then return "undone" end
    end
    local width, height = texture:GetSize()
    if Look.Secret(width) or Look.Secret(height) then return "unknown" end
    width, height = Look.Number(width), Look.Number(height)
    if width and height and (math.abs(width - 128) > 0.5 or math.abs(height - 64) > 0.5) then return "undone" end
    local point, relative, relativePoint, px, py = texture:GetPoint(1)
    if Look.Secret(point) or Look.Secret(relative) or Look.Secret(relativePoint) or Look.Secret(px) or Look.Secret(py) then
        return "unknown"
    end
    if point ~= "TOPLEFT" or relative ~= owner or relativePoint ~= "TOPLEFT" or not Look.Number(px) or not Look.Number(py)
        or math.abs(px - x) > 0.5 or math.abs(py - y) > 0.5 then
        return "undone"
    end
    return "fine"
end

-- The unit a dressed frame shows.
function UF.UnitOf(frame, kind)
    if kind == "player" then return "player" end
    local unit = frame and frame.unit
    if type(unit) == "string" then return unit end
    if kind == "party" then
        local record = UF.Peek(frame)
        return record and record.unit or "party1"
    end
    return kind
end
