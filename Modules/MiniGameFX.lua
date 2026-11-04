local _, EraUI = ...

-- The mini-games' effects kit (experimental, with the mini-games; how to
-- call it is written with the game contract at the top of
-- Modules/MiniGames.lua): sparks bursting out, words floating up, a banner
-- word, a shake of the play area, a glow pulsing on a region, a pop of one of
-- the game's own frames, a tween, and the header's score counting up.
-- Every piece is pooled (made once, reused, never past its cap) and drawn on
-- the window's effects layer (shell.fx, over the game's frames). The window's
-- own every-frame update moves them (MiniGames:Animate), only while one runs,
-- with nothing made per frame. A call while the window is hidden does
-- nothing (a pop or a tween goes straight to its end); hiding the window or
-- switching games clears them all (MiniGames:ClearFX).
local MG = EraUI.MiniGames
if not MG then return end

-- The kit's textures: each in this client's ManifestInterfaceData, or by file
-- ID a file fetched from build 1.60.1.70707 itself.
MG.ART = {
    white = "Interface\\Buttons\\WHITE8X8",
    spark = "Interface\\Cooldown\\star4",                         -- a 4-point star (ADD)
    starburst = "Interface\\Cooldown\\starburst",                 -- a spiky ring (ADD)
    ring = "Interface\\Cooldown\\ping4",                          -- a shockwave ring (ADD)
    glow = "Interface\\Glues\\Models\\UI_Draenei\\GenericGlow64", -- a soft round glow (ADD)
    square = "Interface\\Buttons\\UI-ActionButton-Border",        -- a square glow (ADD)
    castSpark = "Interface\\CastingBar\\UI-CastingBar-Spark",
    mallet = "Interface\\Icons\\INV_Hammer_15", malletIron = "Interface\\Icons\\INV_Hammer_16",
    circleMask = "Interface\\Masks\\CircleMask", portraitMask = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
    bursts = 166970,        -- spells/starbursts: white, blue, red and yellow (MiniGames.QUARTER)
    sparkleGold = 240909,   -- spells/glowstar_gold
    sparkleYellow = 166246, -- spells/glowstar_yellow
    flare = 166976,         -- spells/starflashyellow (ADD)
    star = 166955,          -- spells/star: a cartoon gold star
    dust = 165971,          -- spells/dust1_a
    smoke = 937000,         -- spells/smoke_puffy_mask: four puffs (MiniGames.QUARTER)
    smokeToon = 166911,     -- spells/smoketoon01
    streak = 929276,        -- spells/streak1 (128 x 32)
    glowRing = 986749,      -- spells/glowring (ADD)
    shockwave = 166862,     -- spells/shockwave2white
}
-- A 2 x 2 sheet's quarters as texture coords, by colour (ART.bursts) or 1 to 4.
MG.QUARTER = {white = {0, .5, 0, .5}, blue = {.5, 1, 0, .5}, red = {0, .5, .5, 1}, yellow = {.5, 1, .5, 1}}
MG.QUARTER[1], MG.QUARTER[2], MG.QUARTER[3], MG.QUARTER[4] = MG.QUARTER.white, MG.QUARTER.blue, MG.QUARTER.red, MG.QUARTER.yellow

local FX = {
    -- The most of each kind at once: past it, a new one is skipped.
    CAP = {spark = 160, float = 16, pulse = 24, pop = 32, tween = 48},
    made = {spark = 0, float = 0, pulse = 0},
    free = {spark = {}, float = {}, pulse = {}, job = {}},
    sparks = {}, floats = {}, pulses = {}, pops = {}, tweens = {},
    shake = {on = false, t = 0, life = 0, strength = 0},
}
MG.FX = FX

local TURN = math.pi * 2
local EMPTY = {}
local POP_IN = .14     -- seconds a floating word takes to settle to its size
local BANNER_IN = .18  -- seconds the banner takes to scale in
local BANNER_OUT = .3  -- the share of its time the banner takes to fade
local FLOAT_GOLD, BANNER_GOLD = {1, .9, .45}, {1, .82, .25}

local function Num(value, default)
    if type(value) == "number" and value == value and value > -math.huge and value < math.huge then return value end
    return default
end
local function Font()
    local font = GameFontHighlight and (GameFontHighlight:GetFont())
    return font or "Fonts\\FRIZQT__.TTF"
end
-- The effects' layer, while the window shows (and isn't being cleared).
local function Layer()
    local shell = MG.window
    if FX.clearing or not (shell and shell.fx and shell:IsVisible()) then return nil end
    return shell.fx
end
-- A game's callback: an error is said once in chat and closes the window.
local function Call(fn, a, b)
    local ok, err = pcall(fn, a, b)
    if not ok then
        MG.Report(err)
        MG.fxFailed = true
    end
end
local function HasAtlas(name)
    local info = type(C_Texture) == "table" and C_Texture.GetAtlasInfo
    if type(name) ~= "string" or type(info) ~= "function" then return false end
    local ok, found = pcall(info, name)
    return ok and found ~= nil
end
-- A region's width or height, else the fallback.
local function Size(region, method, fallback)
    local fn = region and region[method]
    if type(fn) ~= "function" then return fallback end
    local ok, value = pcall(fn, region)
    value = ok and Num(value, nil)
    if value and value > 0 then return value end
    return fallback
end

-- Pools -------------------------------------------------------------------------------

local function Take(kind, make)
    local free = FX.free[kind]
    local item = free[#free]
    if item then
        free[#free] = nil
        return item
    end
    if FX.made[kind] >= FX.CAP[kind] then return nil end
    FX.made[kind] = FX.made[kind] + 1
    return make(MG.window.fx)
end
-- Takes list[index] out (the last one moves into its place) and back to its pool.
local function Drop(list, index, kind)
    local item = list[index]
    list[index] = list[#list]
    list[#list] = nil
    item:Hide()
    item.at = nil
    local free = FX.free[kind]
    free[#free + 1] = item
end
local function TakeJob()
    local free = FX.free.job
    local job = free[#free]
    if job then free[#free] = nil else job = {} end
    return job
end
local function DropJob(list, index)
    local job = list[index]
    list[index] = list[#list]
    list[#list] = nil
    job.frame, job.step, job.done, job.data = nil, nil, nil, nil
    local free = FX.free.job
    free[#free + 1] = job
    return job
end

-- A pooled texture dressed for an effect: the atlas, else the texture (and
-- its coords), tinted, blended. Returns whether its art loaded.
local function Dress(texture, opts, fallback)
    local shown = false
    if opts.atlas and HasAtlas(opts.atlas) and type(texture.SetAtlas) == "function" then
        shown = pcall(texture.SetAtlas, texture, opts.atlas)
    end
    if not shown then
        shown = texture:SetTexture(opts.texture or fallback) ~= false
        local c = opts.coords
        if type(c) == "table" then texture:SetTexCoord(c[1] or 0, c[2] or 1, c[3] or 0, c[4] or 1)
        else texture:SetTexCoord(0, 1, 0, 1) end
    end
    local colour = type(opts.colour) == "table" and opts.colour or nil
    if colour then texture:SetVertexColor(colour[1] or 1, colour[2] or 1, colour[3] or 1, 1)
    else texture:SetVertexColor(1, 1, 1, 1) end
    -- Light added ("ADD"), or laid on plainly ("BLEND"); never another mode.
    if opts.blend == "BLEND" then texture:SetBlendMode("BLEND") else texture:SetBlendMode("ADD") end
    if texture.SetRotation then texture:SetRotation(0) end
    return shown
end

-- Sparks ------------------------------------------------------------------------------

local function MakeSpark(layer)
    local spark = layer:CreateTexture(nil, "OVERLAY", nil, 2)
    spark:Hide()
    return spark
end
-- One frame of a spark: out fast, then slower, falling with gravity, fading
-- and shrinking at the end. Returns true once it's over.
local function MoveSpark(spark, dt)
    spark.t = spark.t + dt
    local t = spark.t
    local share = t / spark.life
    if share >= 1 then return true end
    local go = 1 - (1 - share) * (1 - share)
    spark:SetPoint("CENTER", spark.at, "CENTER", spark.x0 + spark.dx * go, spark.y0 + spark.dy * go - spark.fall * t * t)
    spark:SetAlpha(share < .55 and spark.fxAlpha or spark.fxAlpha * (1 - share) / .45)
    local size = spark.size * (1 - spark.shrink * share)
    spark:SetSize(size, size)
    if spark.spin ~= 0 and spark.SetRotation then spark:SetRotation(spark.spin * t) end
    return false
end
local function Launch(spark, opts, anchor, angle, life, speed, size)
    local reach = speed * life * (.55 + .45 * MG.Jitter())
    spark.dx, spark.dy = math.cos(angle) * reach, math.sin(angle) * reach
    spark.x0, spark.y0 = Num(opts.x, 0), Num(opts.y, 0)
    spark.t, spark.life = 0, life * (.8 + .4 * MG.Jitter())
    spark.size = size * (.75 + .5 * MG.Jitter())
    spark.fall = Num(opts.gravity, 0) * .5
    spark.spin = Num(opts.spin, 0) * TURN * (MG.Jitter() < .5 and -1 or 1)
    spark.shrink = math.max(0, math.min(1, Num(opts.shrink, .5)))
    spark.fxAlpha = math.max(0, math.min(1, Num(opts.alpha, 1)))
    spark.at = anchor
    MoveSpark(spark, 0)
    spark:Show()
end
-- Sparks flying out from at (see Modules/MiniGames.lua). Returns how many.
function MG:Burst(at, opts)
    local layer = Layer()
    if not layer then return 0 end
    opts = type(opts) == "table" and opts or EMPTY
    local count = math.min(40, math.max(0, math.floor(Num(opts.count, 8))))
    local life = math.max(.05, Num(opts.life, .55))
    local speed, size = Num(opts.speed, 120), math.max(1, Num(opts.size, 14))
    local spread = Num(opts.spread, TURN)
    local angle = Num(opts.angle, MG.Jitter() * TURN)
    local made = 0
    for k = 1, count do
        local spark = Take("spark", MakeSpark)
        if not spark then break end
        Dress(spark, opts, MG.ART.spark)
        local a = angle + spread * ((k - .5 + (MG.Jitter() - .5) * .6) / count - .5)
        Launch(spark, opts, at or layer, a, life, speed, size)
        FX.sparks[#FX.sparks + 1] = spark
        made = made + 1
    end
    if made > 0 then MG.fxBusy = true end
    return made
end

-- Floating words ----------------------------------------------------------------------

local function MakeFloat(layer)
    local float = CreateFrame("Frame", nil, layer)
    float:SetSize(180, 40)
    float:SetPoint("CENTER", layer, "CENTER", 0, 0)
    float:SetFrameLevel(layer:GetFrameLevel() + 2)
    float.text = float:CreateFontString(nil, "OVERLAY")
    float.text:SetFont(Font(), 16, "OUTLINE")
    float.text:SetPoint("CENTER", float, "CENTER", 0, 0)
    float.text:SetJustifyH("CENTER")
    float:Hide()
    return float
end
-- One frame of a word: it pops in, rises (quick, then slower) and fades.
local function MoveFloat(float, dt)
    float.t = float.t + dt
    local share = float.t / float.life
    if share >= 1 then return true end
    local scale = float.t < POP_IN and float.pop + (1 - float.pop) * float.t / POP_IN or 1
    if scale ~= float.fxScale then
        float.fxScale = scale
        float:SetScale(scale)
    end
    local go = 1 - (1 - share) * (1 - share)
    -- Its place in its own (scaled) units, so it stays put as it settles.
    float:SetPoint("CENTER", float.at, "CENTER", float.x0 / scale, (float.y0 + float.rise * go) / scale)
    float:SetAlpha(share < .6 and 1 or (1 - share) / .4)
    return false
end
-- Words rising from at and fading (see Modules/MiniGames.lua).
function MG:FloatText(at, text, opts)
    local layer = Layer()
    if not layer or text == nil then return false end
    opts = type(opts) == "table" and opts or EMPTY
    local float = Take("float", MakeFloat)
    if not float then return false end
    float.text:SetFont(Font(), math.max(6, Num(opts.size, 16)), "OUTLINE")
    float.text:SetText(tostring(text))
    local colour = type(opts.colour) == "table" and opts.colour or FLOAT_GOLD
    float.text:SetTextColor(colour[1] or 1, colour[2] or 1, colour[3] or 1, 1)
    float.t, float.life = 0, math.max(.1, Num(opts.life, .8))
    float.rise, float.pop = Num(opts.rise, 32), math.max(.1, Num(opts.pop, 1.5))
    float.x0, float.y0, float.at, float.fxScale = Num(opts.x, 0), Num(opts.y, 0), at or layer, nil
    MoveFloat(float, 0)
    float:Show()
    FX.floats[#FX.floats + 1] = float
    MG.fxBusy = true
    return true
end

-- The banner ----------------------------------------------------------------------------

-- A dark band soft at both ends, a glow and the word, over everything.
local function MakeBanner(layer)
    local banner = CreateFrame("Frame", nil, layer)
    banner:SetSize(MG.CONTENT_W, 100)
    banner:SetPoint("CENTER", layer, "CENTER", 0, 0)
    banner:SetFrameLevel(layer:GetFrameLevel() + 8)
    banner.fxLayer = layer
    local half = MG.CONTENT_W / 2
    banner.left = banner:CreateTexture(nil, "BACKGROUND")
    banner.left:SetSize(half, 54)
    banner.left:SetPoint("RIGHT", banner, "CENTER", 0, 0)
    MG.Gradient(banner.left, "HORIZONTAL", 0, 0, 0, 0, 0, 0, 0, .6)
    banner.right = banner:CreateTexture(nil, "BACKGROUND")
    banner.right:SetSize(half, 54)
    banner.right:SetPoint("LEFT", banner, "CENTER", 0, 0)
    MG.Gradient(banner.right, "HORIZONTAL", 0, 0, 0, .6, 0, 0, 0, 0)
    banner.glow = banner:CreateTexture(nil, "BORDER")
    banner.glow:SetSize(MG.CONTENT_W - 30, 96)
    banner.glow:SetPoint("CENTER", banner, "CENTER", 0, 0)
    if banner.glow:SetTexture(MG.ART.glow) == false then banner.glow:Hide() end
    banner.glow:SetBlendMode("ADD")
    banner.text = banner:CreateFontString(nil, "OVERLAY")
    banner.text:SetFont(Font(), 30, "OUTLINE")
    banner.text:SetPoint("CENTER", banner, "CENTER", 0, 4)
    banner.text:SetJustifyH("CENTER")
    banner.sub = banner:CreateFontString(nil, "OVERLAY")
    banner.sub:SetFont(Font(), 13, "OUTLINE")
    banner.sub:SetPoint("TOP", banner.text, "BOTTOM", 0, -3)
    banner.sub:SetJustifyH("CENTER")
    banner:Hide()
    return banner
end
-- One frame of the banner: scales in from big, holds, fades.
local function MoveBanner(banner, dt)
    banner.t = banner.t + dt
    local t, share = banner.t, banner.t / banner.life
    if share >= 1 then return true end
    local scale = 1
    if t < BANNER_IN then
        local q = 1 - t / BANNER_IN
        scale = banner.from + (1 - banner.from) * (1 - q * q)
    end
    if scale ~= banner.fxScale then
        banner.fxScale = scale
        banner:SetScale(scale)
        banner:SetPoint("CENTER", banner.fxLayer, "CENTER", 0, banner.y / scale)
    end
    local alpha = 1
    if t < BANNER_IN then alpha = t / BANNER_IN
    elseif share > 1 - BANNER_OUT then alpha = (1 - share) / BANNER_OUT end
    banner:SetAlpha(alpha)
    return false
end
-- A big word in the middle of the play area (see Modules/MiniGames.lua).
-- One at a time: a new one takes the place of the last.
function MG:Banner(text, opts)
    local layer = Layer()
    if not layer or text == nil then return false end
    opts = type(opts) == "table" and opts or EMPTY
    local banner = FX.banner or MakeBanner(layer)
    FX.banner = banner
    local colour = type(opts.colour) == "table" and opts.colour or BANNER_GOLD
    banner.text:SetFont(Font(), math.max(8, Num(opts.size, 30)), "OUTLINE")
    banner.text:SetText(tostring(text))
    banner.text:SetTextColor(colour[1] or 1, colour[2] or 1, colour[3] or 1, 1)
    banner.sub:SetText(opts.sub ~= nil and tostring(opts.sub) or "")
    banner.sub:SetTextColor(.94, .95, .98, 1)
    local glow = type(opts.glow) == "table" and opts.glow or colour
    banner.glow:SetVertexColor(glow[1] or 1, glow[2] or 1, glow[3] or 1, .55)
    banner.t, banner.life, banner.fxScale = 0, math.max(.4, Num(opts.life, 1.4)), nil
    banner.from, banner.y = math.max(.1, Num(opts.from, 1.8)), Num(opts.y, 0)
    MoveBanner(banner, 0)
    banner:Show()
    FX.bannerOn = true
    MG.fxBusy = true
    return true
end

-- Shake, pulse, pop and tween -------------------------------------------------------------

local function Rest()
    local shell = MG.window
    if shell and shell.content then shell.content:SetPoint("TOPLEFT", shell, "TOPLEFT", MG.CONTENT_X, -MG.CONTENT_Y) end
end
-- The play area (the game's frames and the effects) shakes, less and less.
-- A shake while one runs: the stronger of the two, from the start.
function MG:Shake(strength, life)
    if not Layer() then return false end
    local shake = FX.shake
    local left = shake.on and shake.strength * (1 - shake.t / shake.life) or 0
    shake.strength = math.max(left, math.max(0, Num(strength, 4)))
    shake.t, shake.life, shake.on = 0, math.max(.05, Num(life, .3)), true
    MG.fxBusy = true
    return true
end
local function MoveShake(dt)
    local shake, shell = FX.shake, MG.window
    shake.t = shake.t + dt
    if shake.t >= shake.life then
        shake.on = false
        Rest()
        return
    end
    local size = shake.strength * (1 - shake.t / shake.life)
    local dx, dy = math.sin(shake.t * 97) * size, math.cos(shake.t * 73) * size * .7
    shell.content:SetPoint("TOPLEFT", shell, "TOPLEFT", MG.CONTENT_X + dx, -MG.CONTENT_Y + dy)
end

local function MakePulse(layer)
    local pulse = layer:CreateTexture(nil, "ARTWORK")
    pulse:Hide()
    return pulse
end
-- One frame of a pulse: quick up, slow down, growing a little.
local function MovePulse(pulse, dt)
    pulse.t = pulse.t + dt
    local share = pulse.t / pulse.life
    if share >= 1 then return true end
    pulse:SetAlpha(pulse.peak * (share < .2 and share / .2 or (1 - share) / .8))
    local k = 1 + (pulse.grow - 1) * share
    pulse:SetSize(pulse.fxW * k, pulse.fxH * k)
    return false
end
-- A glow flashing on a region (see Modules/MiniGames.lua).
function MG:Pulse(at, opts)
    local layer = Layer()
    if not layer then return false end
    opts = type(opts) == "table" and opts or EMPTY
    local pulse = Take("pulse", MakePulse)
    if not pulse then return false end
    Dress(pulse, opts, MG.ART.glow)
    local anchor = at or layer
    local scale = Num(opts.scale, 1.3)
    pulse.fxW = Num(opts.w, nil) or Size(anchor, "GetWidth", 40) * scale
    pulse.fxH = Num(opts.h, nil) or Size(anchor, "GetHeight", 40) * scale
    pulse.grow, pulse.peak = Num(opts.grow, 1.15), math.max(0, math.min(1, Num(opts.alpha, .7)))
    pulse.t, pulse.life, pulse.at = 0, math.max(.05, Num(opts.life, .35)), anchor
    pulse:SetPoint("CENTER", anchor, "CENTER", Num(opts.x, 0), Num(opts.y, 0))
    MovePulse(pulse, 0)
    pulse:Show()
    FX.pulses[#FX.pulses + 1] = pulse
    MG.fxBusy = true
    return true
end

local function Read(frame, method)
    local fn = frame[method]
    if type(fn) ~= "function" then return 1 end
    local ok, value = pcall(fn, frame)
    value = ok and Num(value, nil)
    return value and value > 0 and value or 1
end
-- One frame of a pop: up to its peak, then to its end size (fading out on
-- the way when that is under 1).
local function MovePop(job, dt)
    job.t = job.t + dt
    local share = job.t / job.life
    if share >= 1 then return true end
    local up, scale = .35, 1
    if share < up then
        local q = 1 - share / up
        scale = 1 + (job.peak - 1) * (1 - q * q)
    else
        local q = (share - up) / (1 - up)
        scale = job.peak + (job.to - job.peak) * q * q
        if job.to < 1 then job.frame:SetAlpha(job.alpha * (1 - q)) end
    end
    job.frame:SetScale(math.max(.01, scale * job.scale))
    return false
end
-- The pop at list[index] over: its frame back to its own size and alpha, then done.
local function EndPop(index, cleared)
    local job = FX.pops[index]
    local frame, done = job.frame, job.done
    frame:SetScale(job.scale)
    frame:SetAlpha(job.alpha)
    DropJob(FX.pops, index)
    if type(done) == "function" then Call(done, frame, cleared) end
end
-- One of the game's frames scales up, then back or away (see Modules/MiniGames.lua).
function MG:Pop(frame, opts)
    if type(frame) ~= "table" or type(frame.SetScale) ~= "function" then return false end
    opts = type(opts) == "table" and opts or EMPTY
    if not Layer() then
        if type(opts.done) == "function" then Call(opts.done, frame, true) end
        return false
    end
    -- One pop at a time on a frame: a new one starts it again.
    local job
    for index, other in ipairs(FX.pops) do
        if other.frame == frame then
            job = other
            local done = other.done
            other.done = nil
            if type(done) == "function" then Call(done, frame, true) end
            break
        end
    end
    if not job then
        if #FX.pops >= FX.CAP.pop then
            if type(opts.done) == "function" then Call(opts.done, frame, true) end
            return false
        end
        job = TakeJob()
        job.frame, job.scale, job.alpha = frame, Read(frame, "GetScale"), Read(frame, "GetAlpha")
        FX.pops[#FX.pops + 1] = job
    end
    job.t, job.life = 0, math.max(.05, Num(opts.life, .25))
    job.peak, job.to = math.max(.01, Num(opts.peak, 1.3)), math.max(0, Num(opts.to, 1))
    job.done = opts.done
    MG.fxBusy = true
    return true
end

-- The tween at list[index] over: done(data, cleared).
local function EndTween(index, cleared)
    local job = FX.tweens[index]
    local done, data = job.done, job.data
    DropJob(FX.tweens, index)
    if type(done) == "function" then Call(done, data, cleared) end
end
-- step(share, data) every frame for life seconds, then done(data, cleared).
-- The window hidden (or too many running): step(1) and done at once.
function MG:Tween(life, step, done, data)
    if type(step) ~= "function" then step = nil end
    if type(done) ~= "function" then done = nil end
    if not (step or done) then return false end
    if not Layer() or #FX.tweens >= FX.CAP.tween then
        if step then Call(step, 1, data) end
        if done then Call(done, data, true) end
        return false
    end
    local job = TakeJob()
    job.t, job.life, job.step, job.done, job.data = 0, math.max(.01, Num(life, .3)), step, done, data
    FX.tweens[#FX.tweens + 1] = job
    MG.fxBusy = true
    return true
end

-- The header's score, counting up to its goal: quick at first, then slower.
local function MoveScore(dt)
    local shell = MG.window
    local goal, shown = shell.scoreGoal or 0, shell.scoreShown or 0
    if goal == shown then return false end
    if goal < shown then
        MG:ShowScore(goal)
        return false
    end
    local step = math.max(1, math.ceil((goal - shown) * math.min(1, dt * 10)))
    MG:ShowScore(math.min(goal, shown + step))
    return shell.scoreShown ~= goal
end

-- The update ------------------------------------------------------------------------------

local function Each(list, move, kind, dt)
    local index = 1
    while index <= #list do
        if move(list[index], dt) then Drop(list, index, kind) else index = index + 1 end
    end
end
local function EachJob(list, dt, finish)
    local index = 1
    while index <= #list do
        local job = list[index]
        local over
        if finish == EndPop then
            over = MovePop(job, dt)
        else
            job.t = job.t + dt
            over = job.t >= job.life
            if job.step then Call(job.step, over and 1 or job.t / job.life, job.data) end
        end
        -- A callback may have cleared everything.
        if list[index] == job then
            if over then finish(index, false) else index = index + 1 end
        end
    end
end
-- Every running effect moved on by elapsed seconds (the window's own update
-- calls it, only while one runs). Then whether any still runs, counted
-- after every callback (one may have started another effect).
function MG:Animate(elapsed)
    local dt = math.max(0, math.min(1, Num(elapsed, 0)))
    Each(FX.sparks, MoveSpark, "spark", dt)
    Each(FX.floats, MoveFloat, "float", dt)
    Each(FX.pulses, MovePulse, "pulse", dt)
    EachJob(FX.pops, dt, EndPop)
    EachJob(FX.tweens, dt, EndTween)
    if FX.bannerOn and MoveBanner(FX.banner, dt) then
        FX.bannerOn = false
        FX.banner:Hide()
    end
    if FX.shake.on then MoveShake(dt) end
    local counting = self.window ~= nil and MoveScore(dt)
    local busy = #FX.sparks > 0 or #FX.floats > 0 or #FX.pulses > 0 or #FX.pops > 0 or #FX.tweens > 0
        or FX.bannerOn or FX.shake.on or counting
    self.fxBusy = busy and true or false
    return self.fxBusy
end

-- Every effect stopped at once: sparks, words, pulses and the banner gone,
-- the play area still, pops back to size and tweens ended (cleared = true),
-- the header's score at its goal.
function MG:ClearFX()
    if FX.clearing then return end
    FX.clearing = true
    for index = #FX.sparks, 1, -1 do Drop(FX.sparks, index, "spark") end
    for index = #FX.floats, 1, -1 do Drop(FX.floats, index, "float") end
    for index = #FX.pulses, 1, -1 do Drop(FX.pulses, index, "pulse") end
    while #FX.pops > 0 do EndPop(#FX.pops, true) end
    while #FX.tweens > 0 do EndTween(#FX.tweens, true) end
    if FX.banner then FX.banner:Hide() end
    FX.bannerOn = false
    if FX.shake.on then
        FX.shake.on = false
        Rest()
    end
    local shell = self.window
    if shell and shell.scoreGoal then self:ShowScore(shell.scoreGoal) end
    FX.clearing = false
    self.fxBusy, self.fxFailed = false, nil
end
