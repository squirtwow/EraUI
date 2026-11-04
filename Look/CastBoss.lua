-- Boss cast bars and Forever Enhanced Cooldown Manager's Raid Timers. That
-- addon says through its public table (ForeverEnhancedCooldownManagerAPI)
-- whether it styles the boss frames' cast bars, and calls EraUI back each
-- time that changes. While it does, EraUI hands every boss bar back in
-- Blizzard's own look (read the first time EraUI dressed it) and leaves it
-- alone; when it stops, EraUI dresses them again. No reload either way.
-- No addon, an older one, or any answer but a plain true: EraUI's look.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Cast = Look.Cast

local looks = Look.Weak()   -- boss bar: Blizzard's look as first read (false: unreadable)
local waiting = Look.Weak() -- boss bar: Blizzard's size, waiting for a fight to end
local shared = false
local fightEnd

---------------------------------------------------------------------------
-- The other addon's answer
---------------------------------------------------------------------------

local function Answer(api)
    return api.StylesBossCastBars()
end

-- True only while the other addon's public table answers exactly true.
function Cast.Styled()
    local api = _G.ForeverEnhancedCooldownManagerAPI
    if type(api) ~= "table" then return false end
    local fine, answer = pcall(Answer, api)
    return fine and not Look.Secret(answer) and answer == true
end

function Cast.HandedOver(bar)
    return Cast.boss[bar] == true and Cast.Styled()
end

local function Offer(api)
    local share = api.ShareBossCastBars
    if type(share) ~= "function" then return false end
    return share("EraUI", Cast.TradeBack)
end

-- The handshake: EraUI's callback offered until it is heard once.
function Cast.Share()
    if shared then return end
    local api = _G.ForeverEnhancedCooldownManagerAPI
    if type(api) ~= "table" then return end
    local fine, heard = pcall(Offer, api)
    if fine and not Look.Secret(heard) and heard == true then shared = true end
end

---------------------------------------------------------------------------
-- Reading Blizzard's look (the first time EraUI dresses a boss bar)
---------------------------------------------------------------------------

-- What is kept of each piece.
local KEEP = {
    Border = { art = true, place = true }, BorderShield = { art = true, place = true },
    Background = { art = true, place = true }, Flash = { art = true, place = true, blend = true },
    Spark = { art = true, size = true, blend = true }, Text = { place = true, font = true }, Icon = { place = true },
}
for _, key in ipairs(Cast.EFFECTS) do KEEP[key] = KEEP[key] or { art = true, alpha = true, shown = true } end

-- True when none of the values is hidden.
local function Plain(list, count)
    for i = 1, count do
        if Look.Secret(list[i]) then return false end
    end
    return true
end

local function Gather(...)
    return { ... }, select("#", ...)
end

local function ReadSize(piece, into)
    local w, h = piece:GetSize()
    if Look.Number(w) and Look.Number(h) then into.size = { w, h } end
end

local function ReadPlace(piece, into)
    local points = {}
    for i = 1, Look.Number(piece:GetNumPoints()) or 0 do
        local point, count = Gather(piece:GetPoint(i))
        if not Plain(point, math.max(count, 5)) then
            points = nil
            break
        end
        points[i] = point
    end
    into.points = points
    ReadSize(piece, into)
end

local function ReadArt(piece, into)
    local atlas = piece:GetAtlas()
    if not Look.Secret(atlas) and type(atlas) == "string" and atlas ~= "" then
        into.atlas = atlas
    else
        local file = piece:GetTexture()
        if not Look.Secret(file) and file ~= nil then into.file = file end
        local coords, count = Gather(piece:GetTexCoord())
        if count > 0 and Plain(coords, count) then into.coords = coords end
    end
    local tint, count = Gather(piece:GetVertexColor())
    if count >= 3 and Plain(tint, count) then into.tint = tint end
end

-- One piece's record (an error leaves this piece out, never the others).
local function ReadPiece(piece, keep)
    local saved = {}
    if keep.art then ReadArt(piece, saved) end
    if keep.place then ReadPlace(piece, saved) end
    if keep.size then ReadSize(piece, saved) end
    if keep.blend then
        local mode = piece:GetBlendMode()
        if not Look.Secret(mode) then saved.blend = mode end
    end
    if keep.font then
        local font = piece:GetFontObject()
        if not Look.Secret(font) then saved.font = font end
    end
    if keep.alpha then
        local alpha = piece:GetAlpha()
        if Look.Number(alpha) then saved.alpha = alpha end
    end
    if keep.shown then
        local shown = piece:IsShown()
        if not Look.Secret(shown) then saved.shown = shown and true or false end
    end
    return saved
end

local function ReadLook(bar)
    local record = { pieces = {} }
    ReadSize(bar, record)
    for key, keep in pairs(KEEP) do
        local piece = bar[key]
        if piece then
            local fine, saved = pcall(ReadPiece, piece, keep)
            if fine then record.pieces[key] = saved end
        end
    end
    return record
end

-- Called by the dressing the first time it dresses a boss bar.
function Cast.NoteBossLook(bar)
    if looks[bar] ~= nil then return end
    local fine, record = pcall(ReadLook, bar)
    looks[bar] = fine and record or false
end

---------------------------------------------------------------------------
-- Giving a boss bar back
---------------------------------------------------------------------------

local BLENDS = {
    BLEND = function(t) t:SetBlendMode("BLEND") end,
    ADD = function(t) t:SetBlendMode("ADD") end,
    ALPHAKEY = function(t) t:SetBlendMode("ALPHAKEY") end,
    DISABLE = function(t) t:SetBlendMode("DISABLE") end,
}

local function PutPiece(piece, saved)
    if saved.points then
        piece:ClearAllPoints()
        for _, p in ipairs(saved.points) do piece:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
    end
    if saved.size then piece:SetSize(saved.size[1], saved.size[2]) end
    if saved.atlas then
        piece:SetAtlas(saved.atlas)
    elseif saved.file ~= nil then
        piece:SetTexture(saved.file)
        if saved.coords then piece:SetTexCoord(unpack(saved.coords)) end
    end
    if saved.tint then piece:SetVertexColor(unpack(saved.tint)) end
    local blend = saved.blend and BLENDS[saved.blend]
    if blend then blend(piece) end
    if saved.font ~= nil then piece:SetFontObject(saved.font) end
    if saved.alpha then piece:SetAlpha(saved.alpha) end
    if saved.shown ~= nil then piece:SetShown(saved.shown) end
end

local function Resize(bar, size)
    if size[1] > 0 then bar:SetWidth(size[1]) end
    if size[2] > 0 then bar:SetHeight(size[2]) end
end

-- A fight's end: each waiting size given back, unless EraUI dressed the bar
-- again meanwhile.
local function FightOver()
    for bar, size in pairs(waiting) do
        waiting[bar] = nil
        if not Cast.dressing[bar] then Look.Try(Resize, bar, size) end
    end
end

local function WatchFightEnd()
    if fightEnd then return end
    fightEnd = CreateFrame("Frame")
    Look.Listen(fightEnd, "PLAYER_REGEN_ENABLED")
    fightEnd:SetScript("OnEvent", FightOver)
end

-- Blizzard's look back on a bar EraUI dresses now; then hands off.
function Cast.GiveBack(bar)
    if not Cast.dressing[bar] then return end
    Cast.dressing[bar] = nil
    local record = looks[bar]
    if not record then return end
    if record.size then
        if Look.HeldInFight(bar) then
            waiting[bar] = record.size
            WatchFightEnd()
        else
            waiting[bar] = nil
            Resize(bar, record.size)
        end
    end
    for key, saved in pairs(record.pieces) do
        local piece = bar[key]
        if piece then
            Look.Try(PutPiece, piece, saved)
            -- Off Dark Mode's list as well, or the Darkness slider would grey
            -- the border again while the other addon has the bar.
            if type(ns.UntintTexture) == "function" then ns.UntintTexture(piece) end
        end
    end
end

-- The other addon's callback: each boss bar given back while it styles
-- them, dressed in EraUI's look again when it stops.
local function TradeOne(bar)
    Cast.boss[bar] = true
    if Cast.Styled() then
        Cast.GiveBack(bar)
    elseif Cast.applied then
        Cast.Adopt(bar, true)
    end
end

function Cast.TradeBack()
    for _, entry in ipairs(Cast.Bars()) do
        if entry[2] then Look.Try(TradeOne, entry[1]) end
    end
end
