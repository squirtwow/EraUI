local _, EraUI = ...

-- Azeroth Blast's HUD (experimental, with the mini-games): the strip over the
-- board (moves left, up to three goal chips or the boss chip, the Bloodlust /
-- Heroism meter; Free play's own words and its Look button), the power-up
-- bar under it, and the edge glow round the board while Bloodlust or Heroism
-- runs. Methods on the game table of Modules/MiniGameBlastView.lua; a helper
-- with no update, timer or animation of its own (the game's Update moves it).
--
-- HUD CONTRACT (for the game file): game:MakeHud(play), :PaintHud(force),
-- :ShowMoves(n, pop), :StepHud(step) (a beat's goal counts and boss hit),
-- :PaintMeter(force), :LightEdge(on), :MoveEdge(dt), :ShineHud(dt),
-- :PaintPower(), :GoalSpot(id) -> x, y (in the play area), :BossStrikes(step),
-- :BossDown(done). The power-up bar calls game:UsePower(id) (the game file's).
-- The edge glow is flat colour added in bands 3 to 16 px outside the board
-- (never a gradient, never a pixel over the board), with four sparks running
-- round it; the board's rim keeps its metal.
local MG = EraUI.MiniGames
local VIEW = MG and MG.BlastView
if not VIEW then return end

local Blast = MG.Blast
local game, V, PAINT = VIEW.game, VIEW.V, VIEW.PAINT
local Disc, Round, Lit = VIEW.Disc, VIEW.Round, VIEW.Lit
local ART = MG.ART or {}
local EMPTY = {}
local HUD = {
    gold = {1, .84, .35}, green = {.4, 1, .5}, red = {1, .35, .3}, white = {.94, .95, .98}, muted = {.58, .62, .68},
    back = {0, 0, 0, .5}, edgeLine = {1, 1, 1, .08},
    track = {.08, .02, .02}, fill = {.85, .12, .1}, sheen = {1, 1, 1, .18},
    POWERS = {"mallet", "shuffle", "swap", "moves"},
    hit = {colour = {1, .35, .3}, size = 18, rise = 30, life = .9},
    flash = {colour = {1, 1, 1}, alpha = .9, life = .15, scale = 1.15},
    down = {count = 30, colour = {1, .84, .35}, size = 18, speed = 170, life = .9},
    pop = {peak = 1.25, life = .22},
    MOVES_LOW = 3,
}
VIEW.HUD = HUD
MG:TuneDefaults("blastBoss", {zoom = 1})

-- Building ---------------------------------------------------------------------------------------

local function Box(hud, spot)
    local box = CreateFrame("Frame", nil, hud)
    box:SetSize(spot.w, spot.h)
    box:SetPoint("TOPLEFT", hud, "TOPLEFT", spot.x, -spot.y)
    box.back = box:CreateTexture(nil, "BACKGROUND")
    box.back:SetSize(spot.w, spot.h)
    box.back:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    box.back:SetColorTexture(HUD.back[1], HUD.back[2], HUD.back[3], HUD.back[4])
    box.line = box:CreateTexture(nil, "BORDER")
    box.line:SetSize(spot.w, 1)
    box.line:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    box.line:SetColorTexture(HUD.edgeLine[1], HUD.edgeLine[2], HUD.edgeLine[3], HUD.edgeLine[4])
    return box
end
local function Label(parent, size, y, muted, outline)
    local text = MG.Text(parent, "", size, muted, outline)
    text:SetPoint("CENTER", parent, "TOP", 0, -y)
    text:SetJustifyH("CENTER")
    return text
end
local function MakeMoves(self, hud)
    local box = Box(hud, V.MOVES)
    box.label = Label(box, 11, 12, true)
    box.label:SetText("Moves")
    -- The number in a frame of its own, so it can pop.
    local pop = CreateFrame("Frame", nil, box)
    pop:SetSize(V.MOVES.w, 30)
    pop:SetPoint("CENTER", box, "TOP", 0, -36)
    box.pop = pop
    box.number = MG.Text(pop, "", 26, false, true)
    box.number:SetPoint("CENTER", pop, "CENTER", 0, 0)
    box.number:SetJustifyH("CENTER")
    self.hud.moves = box
end
local function MakeChip(self, hud, k)
    local G = V.GOALS
    local chip = Box(hud, {x = G.x + (k - 1) * (G.w + G.gap), y = G.y, w = G.w, h = G.h})
    local face = CreateFrame("Frame", nil, chip)
    face:SetSize(30, 30)
    face:SetPoint("CENTER", chip, "TOP", 0, -22)
    chip.face = face
    chip.rim = face:CreateTexture(nil, "BORDER")
    chip.rim:SetSize(32, 32)
    chip.rim:SetPoint("CENTER", face, "CENTER", 0, 0)
    chip.plate = face:CreateTexture(nil, "BORDER", nil, 1)
    chip.plate:SetSize(30, 30)
    chip.plate:SetPoint("CENTER", face, "CENTER", 0, 0)
    chip.icon = face:CreateTexture(nil, "ARTWORK")
    chip.icon:SetSize(30, 30)
    chip.icon:SetPoint("CENTER", face, "CENTER", 0, 0)
    chip.portrait = face:CreateTexture(nil, "ARTWORK", nil, 1)
    chip.portrait:SetSize(24, 24)
    chip.portrait:SetPoint("CENTER", face, "CENTER", 0, 0)
    Round(face, chip.portrait)
    chip.check = face:CreateTexture(nil, "OVERLAY")
    chip.check:SetSize(18, 18)
    chip.check:SetPoint("CENTER", face, "BOTTOMRIGHT", 2, 2)
    chip.check:Hide()
    chip.text = Label(chip, 13, 46, false, true)
    chip:Hide()
    return chip
end
local function MakeBossChip(self, hud)
    local B = V.BOSS_CHIP
    local chip = Box(hud, B)
    local face = CreateFrame("Frame", nil, chip)
    face:SetSize(B.portrait, B.portrait)
    face:SetPoint("TOPLEFT", chip, "TOPLEFT", 4, -4)
    chip.face = face
    chip.ring = Disc(face:CreateTexture(nil, "BACKGROUND"), {.55, .12, .1})
    chip.ring:SetSize(B.portrait, B.portrait)
    chip.ring:SetPoint("CENTER", face, "CENTER", 0, 0)
    chip.well = Disc(face:CreateTexture(nil, "BORDER"), {.03, .02, .02})
    chip.well:SetSize(B.portrait - 4, B.portrait - 4)
    chip.well:SetPoint("CENTER", face, "CENTER", 0, 0)
    chip.portrait = face:CreateTexture(nil, "ARTWORK")
    chip.portrait:SetSize(B.portrait - 6, B.portrait - 6)
    chip.portrait:SetPoint("CENTER", face, "CENTER", 0, 0)
    Round(face, chip.portrait)
    -- A 3D head when the client gives one (MiniGames:Model); else the portrait texture.
    local model = CreateFrame("PlayerModel", nil, face)
    model:SetSize(B.portrait - 6, B.portrait - 6)
    model:SetPoint("CENTER", face, "CENTER", 0, 0)
    model:SetScript("OnModelLoaded", function(frame) MG:FrameModel(frame, "blastBoss") end)
    model:Hide()
    chip.model = model
    local badge = CreateFrame("Frame", nil, face)
    badge:SetSize(22, 22)
    badge:SetPoint("CENTER", face, "BOTTOMRIGHT", -3, 3)
    badge:SetFrameLevel(face:GetFrameLevel() + 3)
    chip.badge = badge
    chip.badgeBack = Disc(badge:CreateTexture(nil, "BORDER"), {.1, .07, .05})
    chip.badgeBack:SetSize(22, 22)
    chip.badgeBack:SetPoint("CENTER", badge, "CENTER", 0, 0)
    chip.timer = MG.Text(badge, "", 13, false, true)
    chip.timer:SetPoint("CENTER", badge, "CENTER", 0, 0)
    chip.timer:SetJustifyH("CENTER")
    local left = B.portrait + 12
    chip.left = left
    chip.name = MG.Text(chip, "", 12)
    chip.name:SetPoint("TOPLEFT", chip, "TOPLEFT", left, -5)
    chip.name:SetWidth(B.w - left - 84)
    chip.name:SetWordWrap(false)
    chip.shield = chip:CreateTexture(nil, "ARTWORK")
    chip.shield:SetSize(14, 14)
    chip.shield:SetPoint("TOPRIGHT", chip, "TOPRIGHT", -66, -4)
    chip.half = MG.Text(chip, "Half damage", 10)
    chip.half:SetPoint("TOPRIGHT", chip, "TOPRIGHT", -6, -6)
    chip.half:SetTextColor(HUD.red[1], HUD.red[2], HUD.red[3])
    chip.half:SetJustifyH("RIGHT")
    local barW = B.w - left - 8
    chip.barW = barW
    chip.track = chip:CreateTexture(nil, "BORDER")
    chip.track:SetSize(barW, 14)
    chip.track:SetPoint("TOPLEFT", chip, "TOPLEFT", left, -22)
    chip.track:SetColorTexture(HUD.track[1], HUD.track[2], HUD.track[3], 1)
    chip.fill = chip:CreateTexture(nil, "ARTWORK")
    chip.fill:SetSize(barW, 14)
    chip.fill:SetPoint("TOPLEFT", chip.track, "TOPLEFT", 0, 0)
    chip.fill:SetColorTexture(HUD.fill[1], HUD.fill[2], HUD.fill[3], 1)
    chip.sheen = chip:CreateTexture(nil, "ARTWORK", nil, 1)
    chip.sheen:SetSize(barW, 6)
    chip.sheen:SetPoint("TOPLEFT", chip.fill, "TOPLEFT", 0, 0)
    chip.sheen:SetColorTexture(HUD.sheen[1], HUD.sheen[2], HUD.sheen[3], HUD.sheen[4])
    chip.hp = MG.Text(chip, "", 10, false, true)
    chip.hp:SetPoint("CENTER", chip.track, "CENTER", 0, 0)
    chip.hp:SetJustifyH("CENTER")
    chip.next = MG.Text(chip, "", 10, true)
    chip.next:SetPoint("TOPLEFT", chip, "TOPLEFT", left, -41)
    chip:Hide()
    self.hud.boss = chip
end
local function MakeMeter(self, hud)
    local M = V.METER
    local box = Box(hud, M)
    local meter = {box = box}
    meter.well = box:CreateTexture(nil, "BORDER")
    meter.well:SetSize(30, 30)
    meter.well:SetPoint("CENTER", box, "TOP", 0, -20)
    meter.well:SetColorTexture(0, 0, 0, 1)
    meter.icon = box:CreateTexture(nil, "ARTWORK")
    meter.icon:SetSize(28, 28)
    meter.icon:SetPoint("CENTER", box, "TOP", 0, -20)
    meter.icon:SetTexCoord(.08, .92, .08, .92)
    meter.track = box:CreateTexture(nil, "BORDER")
    meter.track:SetSize(56, 8)
    meter.track:SetPoint("TOPLEFT", box, "TOPLEFT", (M.w - 56) / 2, -40)
    meter.track:SetColorTexture(.05, .05, .06, 1)
    meter.fill = box:CreateTexture(nil, "ARTWORK")
    meter.fill:SetSize(56, 8)
    meter.fill:SetPoint("TOPLEFT", meter.track, "TOPLEFT", 0, 0)
    meter.label = MG.Text(box, "", 10, false, true)
    meter.label:SetPoint("CENTER", meter.track, "CENTER", 0, 0)
    meter.label:SetJustifyH("CENTER")
    self.meter = meter
end
local function MakeFree(self, hud)
    local G = V.GOALS
    local free = CreateFrame("Frame", nil, hud)
    free:SetSize(240, G.h)
    free:SetPoint("TOPLEFT", hud, "TOPLEFT", G.x, -G.y)
    free.title = MG.Text(free, "Free play", 14)
    free.title:SetPoint("TOPLEFT", free, "TOPLEFT", 8, -10)
    free.best = MG.Text(free, "", 11, true)
    free.best:SetPoint("TOPLEFT", free, "TOPLEFT", 8, -32)
    free.look = MG.Button(free, "Look", 64, 22)
    free.look:SetPoint("TOPRIGHT", free, "TOPRIGHT", -4, -17)
    free.look:SetScript("OnClick", function() if game.NextLook then game:NextLook() end end)
    free:Hide()
    self.hud.free = free
end
-- The bar under the board: up to four power-ups, centred.
local function MakePower(self, play)
    local P = V.POWER
    local bar = CreateFrame("Frame", nil, play)
    bar:SetSize(MG.CONTENT_W, P.size)
    bar:SetPoint("TOPLEFT", play, "TOPLEFT", 0, -P.y)
    bar:SetFrameLevel(play:GetFrameLevel() + V.LEVEL.hud)
    self.power = bar
    bar.buttons = {}
    for k, id in ipairs(HUD.POWERS) do
        local button = CreateFrame("Button", nil, bar)
        button:SetSize(P.size, P.size)
        button:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        button.id = id
        button.back = button:CreateTexture(nil, "BACKGROUND")
        button.back:SetSize(P.size, P.size)
        button.back:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.back:SetColorTexture(0, 0, 0, .7)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(P.icon, P.icon)
        button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.glow = Lit(button:CreateTexture(nil, "OVERLAY"), ART.square, HUD.gold)
        button.glow:SetSize(P.size + 22, P.size + 22)
        button.glow:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.glow:Hide()
        button.badge = Disc(button:CreateTexture(nil, "OVERLAY", nil, 1), {.05, .04, .03}, .95)
        button.badge:SetSize(16, 16)
        button.badge:SetPoint("CENTER", button, "BOTTOMRIGHT", -3, 3)
        button.count = MG.Text(button, "", 11, false, true)
        button.count:SetPoint("CENTER", button.badge, "CENTER", 0, 0)
        button.count:SetJustifyH("CENTER")
        button.tag = button:CreateTexture(nil, "OVERLAY", nil, 1)
        button.tag:SetSize(P.icon, 14)
        button.tag:SetPoint("BOTTOM", button, "BOTTOM", 0, 1)
        button.tag:SetColorTexture(0, 0, 0, .8)
        button.coin = button:CreateTexture(nil, "OVERLAY", nil, 2)
        button.coin:SetSize(12, 12)
        button.coin:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 4, 2)
        button.price = MG.Text(button, "", 10, false, true)
        button.price:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 2)
        button.price:SetJustifyH("RIGHT")
        button.price:SetTextColor(HUD.gold[1], HUD.gold[2], HUD.gold[3])
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(frame, which)
            if which == "RightButton" then
                if game.Disarm then game:Disarm(true) end
            elseif game.UsePower then
                game:UsePower(frame.id)
            end
        end)
        button:Hide()
        bar.buttons[k] = button
    end
end
-- The bands of light round the board while Bloodlust or Heroism runs: four
-- inner and four outer (top and bottom full width, the sides between), all
-- outside the board, and four sparks running clockwise round it.
local function Band(edge, x, y, w, h)
    local band = edge:CreateTexture(nil, "ARTWORK")
    band:SetSize(w, h)
    band:SetPoint("TOPLEFT", edge, "TOPLEFT", x, -y)
    band:SetColorTexture(1, 1, 1, 1)
    band:SetBlendMode("ADD")
    band:Hide()
    return band
end
local function Bands(edge, out, d, into, kind)
    local L, R, T, B = V.LEFT, V.LEFT + V.BOARD, V.TOP, V.BOTTOM
    local far = out + d
    local list = {
        Band(edge, L - far, T - far, R - L + 2 * far, d),
        Band(edge, L - far, B + out, R - L + 2 * far, d),
        Band(edge, L - far, T - out, d, B - T + 2 * out),
        Band(edge, R + out, T - out, d, B - T + 2 * out),
    }
    for _, band in ipairs(list) do
        band.kind = kind
        into[#into + 1] = band
    end
end
local function MakeEdge(self, play)
    local E = V.EDGE
    local edge = CreateFrame("Frame", nil, play)
    edge:SetSize(MG.CONTENT_W, MG.CONTENT_H)
    edge:SetPoint("TOPLEFT", play, "TOPLEFT", 0, 0)
    edge:SetFrameLevel(play:GetFrameLevel() + V.LEVEL.edge)
    self.edge = edge
    self.glows = {}
    Bands(edge, E.innerOut, E.inner, self.glows, "inner")
    Bands(edge, E.outerOut, E.outer, self.glows, "outer")
    self.runners = {}
    for k = 1, 4 do
        local spark = edge:CreateTexture(nil, "OVERLAY")
        spark:SetSize(E.runner, E.runner)
        spark:SetPoint("CENTER", edge, "TOPLEFT", 0, 0)
        if spark:SetTexture(ART.spark) == false then spark:SetColorTexture(1, 1, 1, .6) end
        spark:SetBlendMode("ADD")
        spark.start = k - 1
        spark:Hide()
        self.runners[k] = spark
    end
end

function game:MakeHud(play)
    local hud = CreateFrame("Frame", nil, play)
    hud:SetSize(MG.CONTENT_W, V.HUD_H)
    hud:SetPoint("TOPLEFT", play, "TOPLEFT", 0, 0)
    hud:SetFrameLevel(play:GetFrameLevel() + V.LEVEL.hud)
    self.hud = {frame = hud, chips = {}}
    MakeMoves(self, hud)
    for k = 1, 3 do self.hud.chips[k] = MakeChip(self, hud, k) end
    MakeBossChip(self, hud)
    MakeMeter(self, hud)
    MakeFree(self, hud)
    MakePower(self, play)
    MakeEdge(self, play)
end

-- Painting ---------------------------------------------------------------------------------------

function game:ShowMoves(n, pop)
    local box = self.hud and self.hud.moves
    if not box or n == nil then return end
    local text = tostring(n)
    if box.number:GetText() == text then return end
    box.number:SetText(text)
    local colour = n <= HUD.MOVES_LOW and HUD.red or HUD.white
    box.number:SetTextColor(colour[1], colour[2], colour[3])
    if pop then MG:Pop(box.pop, HUD.pop) end
end
-- A goal chip's picture: a race's face on its plate, the other side's crest
-- (an enemy goal), a star (score), a blocker's or a relic's art.
local ICONS = {score = "star", oil = "block.oil", ice = "block.ice", crate = "block.crate", web = "block.web", relic = "relic.1"}
function game:GoalIcon(chip, goal)
    chip.plate:Hide()
    chip.rim:Hide()
    chip.portrait:Hide()
    chip.icon:Hide()
    if goal.id == "collect" and Blast.RACE[goal.race] then
        local race = Blast.RACE[goal.race]
        self:PaintPlate(chip.plate, chip.rim, race.id, 30)
        chip.plate:Show()
        chip.rim:Show()
        Blast.PutFace(chip.portrait, race)
        chip.portrait:Show()
    elseif goal.id == "enemy" then
        -- The crest, not a red or blue dot (read as one race's colour).
        MG:Art(chip.icon, "crest." .. (goal.foe == "Horde" and "Horde" or "Alliance"))
    else
        MG:Art(chip.icon, ICONS[goal.id] or "star")
    end
end
local function PaintChip(chip, goal, have)
    local done = have >= (goal.need or 0)
    chip.text:SetText(("%d/%d"):format(have, goal.need or 0))
    local colour = done and HUD.green or HUD.white
    chip.text:SetTextColor(colour[1], colour[2], colour[3])
    if done then MG:Art(chip.check, "check") else chip.check:Hide() end
    chip.have = have
end
-- The boss chip: name, health, the countdown and the shield.
function game:PaintBoss(hp)
    local chip, state = self.hud.boss, self.state
    local boss = state.boss
    local key = boss.key or (state.spec and state.spec.zone) or "elwynn"
    if chip.key ~= key then
        chip.key = key
        MG:Art(chip.portrait, "zone." .. key .. ".bossIcon")
        local ok = MG:Model(chip.model, "zone." .. key .. ".boss", "blastBoss")
        chip.model:SetShown(ok and true or false)
        chip.portrait:SetShown(not ok)
    end
    chip.face:Show()
    chip.face:SetAlpha(1)
    chip.name:SetText(boss.name or "")
    self:BossBar(hp or boss.hp)
    local shielded = boss.hp > 0 and Blast.Shielded(state)
    chip.half:SetShown(shielded and true or false)
    if shielded then MG:Art(chip.shield, "lock") else chip.shield:Hide() end
    -- His whole name unless the shield's words share the line.
    chip.name:SetWidth(V.BOSS_CHIP.w - chip.left - (shielded and 84 or 8))
    local timer = boss.timer or 0
    chip.timer:SetText(tostring(timer))
    local colour = timer <= 1 and HUD.red or HUD.white
    chip.timer:SetTextColor(colour[1], colour[2], colour[3])
    chip.urgent = timer <= 1 and boss.hp > 0
    if boss.hp <= 0 then chip.next:SetText("Down!")
    elseif shielded and Blast.WAIT_SHIELDED then chip.next:SetText("Waits while his mess is up")
    else chip.next:SetText(timer == 1 and "Strikes next move" or ("Strikes in %d moves"):format(timer)) end
end
function game:BossBar(hp)
    local chip, boss = self.hud and self.hud.boss, self.state and self.state.boss
    if not (chip and boss) then return end
    local max = math.max(1, boss.max or 1)
    hp = math.max(0, math.min(max, hp or 0))
    chip.shownHp = hp
    local share = hp / max
    chip.fill:SetShown(share > 0)
    chip.sheen:SetShown(share > 0)
    if share > 0 then
        chip.fill:SetWidth(chip.barW * share)
        chip.sheen:SetWidth(chip.barW * share)
    end
    chip.hp:SetText(("%d / %d"):format(math.floor(hp + .5), max))
end
-- Everything on the HUD as the state now is (force: the meter too).
function game:PaintHud(force)
    local hud = self.hud
    if not (hud and self.state) then return end
    local state = self.state
    local level = state.mode == "level"
    hud.free:SetShown(not level)
    hud.moves.label:SetText(level and "Moves" or "")
    if level then
        self:ShowMoves(state.movesLeft, false)
    else
        hud.moves.number:SetText("Free")
        hud.moves.number:SetTextColor(HUD.white[1], HUD.white[2], HUD.white[3])
    end
    local boss = level and state.boss ~= nil
    hud.boss:SetShown(boss)
    for k, chip in ipairs(hud.chips) do
        local goal = level and not boss and state.goals[k] or nil
        if goal then
            if chip.goal ~= goal then
                chip.goal = goal
                self:GoalIcon(chip, goal)
            end
            PaintChip(chip, goal, goal.have)
            chip:Show()
        else
            chip.goal = nil
            chip:Hide()
        end
    end
    if boss then self:PaintBoss() end
    if not level then
        local best = MG:Best("blast")
        hud.free.best:SetText(("Best %d"):format(best or 0))
        local P = MG.Progress
        hud.free.look:SetShown(P ~= nil and #P:Looks() > 1)
    end
    self:PaintMeter(force)
    self:PaintPower()
end
-- A beat's goal counts (each chip that moved pops) and the boss hit.
function game:StepHud(step)
    local hud, state = self.hud, self.state
    if not (hud and state and state.mode == "level") then return end
    local counts = step.goals or EMPTY
    for k, chip in ipairs(hud.chips) do
        local goal = chip.goal
        local have = counts[k]
        if goal and have and have ~= chip.have then
            PaintChip(chip, goal, have)
            MG:Pop(chip.face, HUD.pop)
            if have >= goal.need then MG:Sound("chime") end
        end
    end
    if state.boss and step.damage and step.damage > 0 then self:BossHit(step) end
end
-- The boss is hit: his bar drains, the damage floats up red, his portrait flashes.
function game:BossHit(step)
    local chip = self.hud.boss
    local from, to = chip.shownHp or self.state.boss.max, step.bossHp or self.state.boss.hp
    MG:Tween(.4, function(share) self:BossBar(from + (to - from) * share) end, function() self:BossBar(to) end)
    MG:FloatText(chip.face, "-" .. step.damage, HUD.hit)
    MG:Pulse(chip.face, HUD.flash)
    self:Once("bossHit." .. (self.state.boss.key or "elwynn"))
    chip.half:SetShown(step.shielded and true or false)
end
-- The boss strikes: his portrait shakes and he roars.
local function ShakeStep(share, chip)
    local d = 4 * (1 - share) * math.sin(share * 40)
    chip.face:SetPoint("TOPLEFT", chip, "TOPLEFT", 4 + d, -4)
end
function game:BossStrikes(step)
    local chip = self.hud and self.hud.boss
    if not chip then return end
    MG:Sound("bossRoar." .. (self.state.boss and self.state.boss.key or "elwynn"))
    MG:Tween(.4, ShakeStep, function() ShakeStep(1, chip) end, chip)
    local boss = self.state.boss
    if boss then
        chip.timer:SetText(tostring(boss.timer or 0))
        MG:Pop(chip.badge, HUD.pop)
    end
end
-- The boss is down: his portrait shakes and pops away, gold sparks, a banner; then done.
function game:BossDown(done)
    local chip = self.hud.boss
    local boss = self.state.boss
    MG:Sound("bossDown." .. (boss.key or "elwynn"))
    MG:Tween(.6, ShakeStep, function()
        ShakeStep(1, chip)
        MG:Pop(chip.face, {peak = 1.3, to = 0, life = .35, done = function(frame) frame:Hide() end})
    end, chip)
    MG:Burst(chip.face, HUD.down)
    MG:Shake(9, .5)
    MG:Banner(("%s is down!"):format(boss.name or "The boss"), {size = 32, sub = ("Level %d cleared"):format(self.state.level or 0),
        life = 1.6})
    MG:Tween(1.4, nil, function(_, cleared) if done then done(cleared) end end)
end
-- Where a goal's chip is (a relic flies there), in the play area's coordinates.
function game:GoalSpot(id)
    for k, chip in ipairs(self.hud and self.hud.chips or EMPTY) do
        if chip.goal and chip.goal.id == id and chip:IsShown() then
            local G = V.GOALS
            return G.x + (k - 1) * (G.w + G.gap) + G.w / 2, -(G.y + 22)
        end
    end
    return nil
end

-- The meter and the edge glow ----------------------------------------------------------------------

function game:PaintMeter(force)
    local state, meter = self.state, self.meter
    if not (state and meter) then return end
    local faction = self:Faction()
    local level = state.mode == "level"
    local lust = state.lust > 0 and not self.lustPending
    local share, words
    if lust then
        share = level and state.lust / Blast.LUST_MOVES or state.lust / Blast.LUST_TIME
        local left = math.ceil(state.lust)
        words = level and (left == 1 and "1 move" or ("%d moves"):format(left)) or ("%ds"):format(left)
    else
        local count = self.shownMeter or state.meter
        share = count / Blast.METER_FULL
        words = ("%d/%d"):format(count, Blast.METER_FULL)
    end
    share = math.max(0, math.min(1, share))
    if force or meter.faction ~= faction then
        meter.faction = faction
        meter.icon:SetTexture(faction == "Alliance" and Blast.ICONS.heroism or Blast.ICONS.bloodlust)
        local c = PAINT.lust[faction]
        meter.fill:SetColorTexture(c[1], c[2], c[3], 1)
    end
    if force or meter.share ~= share then
        meter.share = share
        meter.fill:SetShown(share > 0)
        if share > 0 then meter.fill:SetWidth(56 * share) end
    end
    if force or meter.words ~= words then
        meter.words = words
        meter.label:SetText(words)
    end
    if force or meter.lit ~= lust then
        meter.lit = lust
        if meter.icon.SetDesaturated then meter.icon:SetDesaturated(not lust) end
        self:LightEdge(lust)
    end
end
-- Bloodlust or Heroism on: the bands and runners show, in its colour. The
-- rim keeps its metal.
function game:LightEdge(on)
    self.lit = on and true or false
    local colour = PAINT.lust[self:Faction()] or PAINT.lust.Alliance
    for _, band in ipairs(self.glows or EMPTY) do
        band:SetColorTexture(colour[1], colour[2], colour[3], 1)
        band:SetShown(self.lit)
    end
    for _, spark in ipairs(self.runners or EMPTY) do
        spark:SetVertexColor(colour[1], colour[2], colour[3], 1)
        spark:SetShown(self.lit)
    end
    self.edgeT = 0
    if self.lit then self:MoveEdge(0) end
end
-- A spot d px clockwise round the runners' path (10 px outside the board) from its top left corner.
local function RunnerAt(d)
    local E = V.EDGE
    local x0, y0 = V.LEFT - E.runnerOut, V.TOP - E.runnerOut
    local w, h = V.BOARD + 2 * E.runnerOut, V.BOARD + 2 * E.runnerOut
    local around = 2 * (w + h)
    d = d % around
    if d < w then return x0 + d, y0 end
    d = d - w
    if d < h then return x0 + w, y0 + d end
    d = d - h
    if d < w then return x0 + w - d, y0 + h end
    return x0, y0 + h - (d - w)
end
VIEW.RunnerAt = RunnerAt
function game:MoveEdge(dt)
    if not self.lit then return end
    local E = V.EDGE
    self.edgeT = (self.edgeT or 0) + (dt or 0)
    local t = self.edgeT
    local p = .6 + .4 * (.5 + .5 * math.sin(t * E.pulse * 2 * math.pi))
    for _, band in ipairs(self.glows or EMPTY) do band:SetAlpha((band.kind == "inner" and .9 or .35) * p) end
    local side = V.BOARD + 2 * E.runnerOut
    for _, spark in ipairs(self.runners or EMPTY) do
        local x, y = RunnerAt(spark.start * side + t * E.speed)
        spark:SetPoint("CENTER", self.edge, "TOPLEFT", x, -y)
    end
end
-- The armed power-up's glow and the boss's countdown at 1 pulse.
function game:ShineHud(dt)
    local s = .5 + .5 * math.sin(self.clock * 6)
    for _, button in ipairs(self.power and self.power.buttons or EMPTY) do
        if button.glow:IsShown() then button.glow:SetAlpha(.45 + .55 * s) end
    end
    local chip = self.hud and self.hud.boss
    if chip and chip.urgent and chip:IsShown() then chip.badge:SetAlpha(.55 + .45 * s) elseif chip then chip.badge:SetAlpha(1) end
end

-- The power-up bar ------------------------------------------------------------------------------------

function game:PaintPower()
    local bar = self.power
    if not bar then return end
    local P, state = MG.Progress, self.state
    local level = state and state.mode == "level" and not state.outcome
    local shown = {}
    for _, button in ipairs(bar.buttons) do
        if level and P and P:Unlocked(button.id) then shown[#shown + 1] = button else button:Hide() end
    end
    local S = V.POWER
    local width = #shown * S.size + math.max(0, #shown - 1) * S.gap
    for k, button in ipairs(shown) do
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", bar, "TOPLEFT", (MG.CONTENT_W - width) / 2 + (k - 1) * (S.size + S.gap), 0)
        if not button.dressed then
            button.dressed = true
            MG:Art(button.icon, "power." .. button.id)
            MG:Art(button.coin, "coin")
        end
        local count = P:Count(button.id)
        button.badge:SetShown(count > 0)
        button.count:SetText(count > 0 and tostring(count) or "")
        button.tag:SetShown(count <= 0)
        button.coin:SetShown(count <= 0)
        button.price:SetText(count <= 0 and tostring(P:Price(button.id) or 0) or "")
        button.glow:SetShown(self.armed == button.id)
        button:SetAlpha(self.busy and .4 or 1)
        button:Show()
    end
    bar:SetShown(#shown > 0)
end
