local _, EraUI = ...

-- Whack's stages around a round (experimental, with the mini-games): the HUD
-- over the field (the stage, its goals and the boss chip), the stage map
-- (MiniGames.Map, ten stages a page, a boss every 5th), the cards (a stage's
-- intro, its win and its loss with +10 seconds), the footer's buttons, saving
-- and carrying on (every flight comes back to the round you left, on any
-- character), coins (MiniGames.Progress) and /era whack tune. Methods on
-- Whack's game (MiniGames.Whack.game, registered by Modules/MiniGameWhack.lua);
-- no frames until the game is built, no update of its own.
--
-- Screens (game.screen): "map" (the stage map; footer: Shop, Quick round),
-- "stage" and "quick" (the field; footer: Map, Start / Pause / Resume / Play Again).
-- Opening (game:Shown's why): a flight carries on with a round waiting (in
-- memory or saved), else a Quick round when that was last, else the next
-- stage's intro; /era whack and the Play row open the map; the Switch button
-- shows what showed last. Landing pauses and saves the round for the next flight.
--
-- /era whack tune [key] <field> <value> frames the 3D targets live and saves
-- it (EraUIDB.miniGameTune, so the numbers can be read back): key peon, gnome,
-- bosspeon, bossgnome, decoyalliance or decoyhorde (your side's target when
-- left out); fields zoom (0 to 1), cam (.3 to 3), up (-2 to 2), turn (-180 to
-- 180 degrees), body (.6 to 1.6), peek (.3 to 1), lift (0 to .6). "/era whack
-- tune" alone says the values; "/era whack tune reset" puts them back.
local MG = EraUI.MiniGames
if not MG then return end
local Whack = MG.Whack
local game = Whack and Whack.game
if not game then return end

local V = Whack.VIEW
local HUD = {chipW = 70, chipH = 56, chipX = 10, chipY = 26, chipGap = 6, icon = 26, bossX = 232, bossW = 170, portrait = 40, pip = 12}
Whack.HUD = HUD
local GOLD, GREEN, WHITE, DIM = {1, .84, .35}, {.4, 1, .5}, {.94, .95, .98}, {.25, .22, .2}
local LANDED = "You landed. Your round waits for your next flight."

local function Progress() return MG.Progress end
local function Live(state) return state.phase == "playing" or state.phase == "countdown" or state.phase == "paused" end
local function Plural(n, one, many) return n == 1 and ("1 " .. one) or (n .. " " .. many) end

-- The HUD ---------------------------------------------------------------------------------------

local function Chip(hud, index)
    local chip = CreateFrame("Frame", nil, hud)
    chip:SetSize(HUD.chipW, HUD.chipH)
    chip:SetPoint("TOPLEFT", hud, "TOPLEFT", HUD.chipX + (index - 1) * (HUD.chipW + HUD.chipGap), -HUD.chipY)
    chip.back = chip:CreateTexture(nil, "BACKGROUND")
    chip.back:SetSize(HUD.chipW, HUD.chipH)
    chip.back:SetPoint("TOPLEFT", chip, "TOPLEFT", 0, 0)
    chip.back:SetColorTexture(0, 0, 0, .45)
    chip.icon = chip:CreateTexture(nil, "ARTWORK")
    chip.icon:SetSize(HUD.icon, HUD.icon)
    chip.icon:SetPoint("TOP", chip, "TOP", 0, -5)
    chip.check = chip:CreateTexture(nil, "OVERLAY")
    chip.check:SetSize(16, 16)
    chip.check:SetPoint("CENTER", chip.icon, "BOTTOMRIGHT", 0, 2)
    chip.text = MG.Text(chip, "", 12, false, true)
    chip.text:SetPoint("TOP", chip, "TOP", 0, -36)
    chip.text:SetJustifyH("CENTER")
    chip:Hide()
    return chip
end
local function BossChip(hud)
    local chip = CreateFrame("Frame", nil, hud)
    chip:SetSize(HUD.bossW, HUD.chipH)
    chip:SetPoint("TOPLEFT", hud, "TOPLEFT", HUD.bossX, -HUD.chipY)
    chip.back = chip:CreateTexture(nil, "BACKGROUND")
    chip.back:SetSize(HUD.bossW, HUD.chipH)
    chip.back:SetPoint("TOPLEFT", chip, "TOPLEFT", 0, 0)
    chip.back:SetColorTexture(.12, .02, .02, .6)
    chip.portrait = chip:CreateTexture(nil, "ARTWORK")
    chip.portrait:SetSize(HUD.portrait, HUD.portrait)
    chip.portrait:SetPoint("LEFT", chip, "LEFT", 8, 0)
    if type(chip.CreateMaskTexture) == "function" and type(chip.portrait.AddMaskTexture) == "function" then
        local mask = chip:CreateMaskTexture()
        mask:SetTexture(Whack.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(chip.portrait)
        chip.portrait:AddMaskTexture(mask)
    end
    chip.name = MG.Text(chip, "", 11, false, true)
    chip.name:SetPoint("TOPLEFT", chip, "TOPLEFT", 56, -6)
    chip.pips = {}
    for index = 1, Whack.BOSS_HITS do
        local pip = chip:CreateTexture(nil, "ARTWORK")
        pip:SetSize(HUD.pip, HUD.pip)
        pip:SetPoint("TOPLEFT", chip, "TOPLEFT", 56 + (index - 1) * (HUD.pip + 4), -22)
        if pip:SetTexture(MG.ART.circleMask) == false then pip:SetColorTexture(1, 1, 1, 1) end
        chip.pips[index] = pip
    end
    chip.text = MG.Text(chip, "", 11)
    chip.text:SetPoint("TOPLEFT", chip, "TOPLEFT", 56, -38)
    chip:Hide()
    return chip
end
-- The HUD across the field's top (V.HUD_H): no clicks, over the rows.
function game:MakeHud(level)
    local hud = CreateFrame("Frame", nil, self.root)
    hud:SetSize(V.W, V.HUD_H)
    hud:SetPoint("TOPLEFT", self.holder, "TOPLEFT", 0, 0)
    hud:SetFrameLevel(level)
    hud.band = hud:CreateTexture(nil, "BACKGROUND")
    hud.band:SetSize(V.W, V.HUD_H)
    hud.band:SetPoint("TOPLEFT", hud, "TOPLEFT", 0, 0)
    MG.Gradient(hud.band, "VERTICAL", 0, 0, 0, 0, 0, 0, 0, .6)
    hud.title = MG.Text(hud, "", 14, false, true)
    hud.title:SetPoint("TOPLEFT", hud, "TOPLEFT", 10, -8)
    hud.right = MG.Text(hud, "", 11, true)
    hud.right:SetPoint("TOPRIGHT", hud, "TOPRIGHT", -10, -9)
    hud.right:SetJustifyH("RIGHT")
    hud.chips = {}
    for index = 1, 3 do hud.chips[index] = Chip(hud, index) end
    hud.boss = BossChip(hud)
    hud.mark = {}
    self.hud = hud
end
-- A goal's icon: the target's head (gold for golden heads), a star for a
-- score, the boss's own portrait. Returns a path or a role.
function game:GoalIcon(goal)
    if goal.id == "score" then return "star" end
    if goal.id == "boss" then return "whack." .. self.target.boss end
    if goal.id == "golden" then return "coin" end
    return self.target.icon
end
local function Icon(texture, icon)
    if type(icon) == "string" and not icon:find("\\", 1, true) then
        MG:Art(texture, icon)
        return
    end
    if texture:SetTexture(icon) == false then texture:SetColorTexture(.5, .5, .5, 1) end
    texture:SetTexCoord(.08, .92, .08, .92)
    texture:Show()
end
local function PaintChip(view, chip, goal, state)
    local have = Whack.Have(state, goal)
    local done = have >= goal.need
    if goal.id == "golden" then
        Icon(chip.icon, view.target.icon)
        chip.icon:SetVertexColor(1, .82, .3)
    else
        Icon(chip.icon, view:GoalIcon(goal))
        if goal.id == "bonk" then chip.icon:SetVertexColor(1, 1, 1) end
    end
    if done then MG:Art(chip.check, "check") else chip.check:Hide() end
    chip.text:SetText(("%d/%d"):format(math.min(have, goal.need), goal.need))
    local c = done and GREEN or WHITE
    chip.text:SetTextColor(c[1], c[2], c[3])
    chip:Show()
end
local function PaintBoss(view, chip, state)
    local boss = state.spec.boss
    if not boss then
        chip:Hide()
        return
    end
    MG:Art(chip.portrait, "whack." .. view.target.boss)
    chip.name:SetText("Boss " .. view.target.accent)
    local up = state.kind == "boss"
    for index, pip in ipairs(chip.pips) do
        local c = (up and index <= state.bossHits) and {1, .3, .2} or DIM
        pip:SetVertexColor(c[1], c[2], c[3], 1)
    end
    chip.text:SetText(("Beaten %d/%d"):format(math.min(state.beaten, boss.need), boss.need))
    local c = state.beaten >= boss.need and GREEN or WHITE
    chip.text:SetTextColor(c[1], c[2], c[3])
    chip:Show()
end
local MARKS = {"mode", "stage", "bonks", "golden", "beaten", "score", "bossHits", "kind", "spec"}
-- The HUD for the round now (only when something on it changed, or force).
function game:PaintHud(force)
    local hud, state = self.hud, self.state
    if not hud then return end
    local mark, same = hud.mark, not force
    for _, field in ipairs(MARKS) do
        if mark[field] ~= state[field] then same = false end
        mark[field] = state[field]
    end
    if same then return end
    local spec = state.spec
    if state.mode == "stage" then
        hud.title:SetText(("Stage %d"):format(state.stage))
        local stars = spec.stars or {}
        hud.right:SetText(spec.boss and "" or ("2 stars at %d, 3 at %d"):format(stars[1] or 0, stars[2] or 0))
    else
        hud.title:SetText("Quick round")
        hud.right:SetText(("Best %d"):format((MG:Best("whack"))))
    end
    local shown = 0
    for _, goal in ipairs(spec.goals or {}) do
        if goal.id ~= "boss" and shown < #hud.chips then
            shown = shown + 1
            PaintChip(self, hud.chips[shown], goal, state)
        end
    end
    for index = shown + 1, #hud.chips do hud.chips[index]:Hide() end
    PaintBoss(self, hud.boss, state)
end

-- The footer and the screens ------------------------------------------------------------------

local LABELS = {ready = "Start", countdown = "Pause", playing = "Pause", paused = "Resume", over = "Play Again"}
-- The footer's main button says what a click does now.
function game:Label()
    if not self.button then return end
    local text = self.screen == "map" and "Quick round" or LABELS[self.state.phase] or "Start"
    self.button.label:SetText(text)
end
function game:Hint()
    if self.screen ~= "map" and self.state.mode == "stage" then return ("Stage %d"):format(self.state.stage) end
    return "Whack the " .. self:Target().noun .. " before it ducks."
end
function game:HeaderBest()
    local P = Progress()
    if P and self.screen ~= "map" and self.state.mode == "stage" then
        return ("Best %d"):format(P:BestScore("whack", self.state.stage))
    end
    return nil
end
-- Shows a screen: the map, or the field for a stage or a Quick round.
function game:Screen(name)
    if name == "map" and not self.map then name = self.state.mode == "stage" and "stage" or "quick" end
    local map = name == "map"
    -- Leaving the map stops its glow (and a walk, which jumps to its end:
    -- the screen is already the new one, so its intro never follows).
    local leaving = self.screen == "map" and not map
    self.screen = name
    if leaving and MG.ClearFX then MG:ClearFX() end
    -- Each page of ten stages has its own zone's ground (a Quick round: home).
    if not map and self.PaintGround then self:PaintGround(self.state.mode == "stage" and self.state.stage or 1) end
    self.root:SetShown(not map)
    if self.map then
        if map then self.map:Show() else self.map:Hide() end
    end
    self.mapButton:SetShown(not map)
    self.shopButton:SetShown(map)
    if map then
        self.swingT = nil
        self.mallet:Hide()
    end
    self:Label()
    self:PaintHud(true)
    if MG:Shown("whack") then MG:PaintHeader() end
end
-- The line above the footer for the round shown.
function game:Remind()
    local state = self.state
    if self.screen == "map" then return end
    if state.phase == "paused" then
        MG:Note("Paused. Click Resume to carry on.")
    elseif state.phase == "ready" and state.mode == "quick" then
        MG:Note("Click Start, then whack the " .. self:Target().noun .. ".")
    end
end

-- Saving --------------------------------------------------------------------------------------

-- A stage lost, its lose card waiting (not yet left).
function game:LostWaiting()
    local state = self.state
    return state.mode == "stage" and state.phase == "over" and state.outcome == "lost" and not state.paid
end
-- The round in play (or its lose card) saved for the next flight. There's
-- one place for it: a Quick round never takes it from a stage waiting there.
function game:Save()
    local P = Progress()
    if not P or not (Live(self.state) or self:LostWaiting()) then return end
    if self.state.mode == "quick" then
        local snap = P:Resume("whack")
        if type(snap) == "table" and snap.mode == "stage" then return end
    end
    P:SaveResume("whack", Whack.SaveStage(self.state))
end
-- The saved round let go once it's over, when it's this one's kind ("stage" or "quick").
function game:Unsave(mode)
    local P = Progress()
    local snap = P and P:Resume("whack")
    if snap and snap.mode ~= mode then return end
    if P then P:SaveResume("whack", nil) end
end
function game:Keep() self:Save() end
-- A lost stage left (Try again, Map, another round): its coins paid, its snapshot gone.
function game:LeaveLost()
    if not self:LostWaiting() then return nil end
    local state, P = self.state, Progress()
    state.paid = true
    if not P then return nil end
    local report = P:Finish("whack", state.stage, {won = false, score = state.score, golden = state.golden})
    self:Unsave("stage")
    return report
end
-- The stage number a round waits in (in memory or saved), or nil.
function game:Waiting()
    local state = self.state
    if state.mode == "stage" and Live(state) then return state.stage end
    local P = Progress()
    local snap = P and P:Resume("whack")
    if type(snap) == "table" and snap.mode == "stage" and snap.outcome == nil and type(snap.stage) == "number" then return snap.stage end
    return nil
end
-- Golden heads and decoys in a Quick round once stage 4 is cleared.
function game:Extras()
    local P = Progress()
    return P ~= nil and P:Stars("whack", 4) > 0
end

-- Starting rounds -----------------------------------------------------------------------------

-- The round in game.state, from its 3, 2, 1 (saved at once, so even a fresh start carries on).
function game:Begin()
    Whack.Begin(self.state)
    self:Calm()
    self:DrawTimer()
    MG:SetScore(0)
    MG:Note("")
    self:Count(Whack.COUNTDOWN)
    self:Save()
    self:Label()
    self:PaintHud(true)
end
function game:StartStage(n)
    if MG.Card then MG.Card.Hide("whack") end
    self:LeaveLost()
    self.state = Whack.NewStage(n)
    local P = Progress()
    if P then P:SetLast("whack", "stage") end
    self:Screen("stage")
    self:Begin()
end
function game:StartQuick()
    if MG.Card then MG.Card.Hide("whack") end
    self:LeaveLost()
    self.state = Whack.New(nil, Whack.QuickSpec(self:Extras()))
    local P = Progress()
    if P then P:SetLast("whack", "quick") end
    self:Screen("quick")
    self:Begin()
end
-- The round waiting in stage n, paused on the field (else that stage from its start).
function game:CarryOn(n)
    local state = self.state
    if not (state.mode == "stage" and state.stage == n and Live(state)) then
        local P = Progress()
        local loaded = P and Whack.LoadStage(P:Resume("whack"))
        if not (loaded and loaded.mode == "stage" and loaded.stage == n and loaded.phase == "paused") then return self:StartStage(n) end
        self.state = loaded
    end
    if MG.Card then MG.Card.Hide("whack") end
    Whack.Pause(self.state)
    self:Calm()
    self:Screen("stage")
    self:DrawTimer()
    MG:SetScore(self.state.score, true)
    self:Remind()
end
-- Stage n on the field, its intro card over it (a flight's way in).
function game:ReadyStage(n)
    if MG.Card then MG.Card.Hide("whack") end
    self.state = Whack.NewStage(n)
    self:Calm()
    self:Screen("stage")
    self:DrawTimer()
    self:Intro(n)
end

-- The footer's main button: a Quick round from the map; else start, pause or
-- resume the round shown, or play it again.
function game:Press()
    local state = self.state
    if self.screen == "map" then
        if state.mode == "quick" and state.phase == "paused" then
            self:Screen("quick")
            self:Remind()
        else
            self:StartQuick()
        end
        return
    end
    if state.phase == "playing" or state.phase == "countdown" then
        Whack.Pause(state)
        self:Save()
        MG:Note("Paused.")
    elseif state.phase == "paused" then
        if MG.Card then MG.Card.Hide("whack") end
        Whack.Resume(state)
        MG:Note("")
    elseif state.phase == "ready" then
        if MG.Card then MG.Card.Hide("whack") end
        self:Begin()
    elseif state.mode == "stage" then
        self:StartStage(state.stage)
    else
        self:StartQuick()
    end
    self:Label()
end
-- The Map button (and a card's): the round shown paused and kept, the map.
function game:ToMap()
    if Whack.Pause(self.state) then self:Save() end
    if MG.Card then MG.Card.Hide("whack") end
    self:LeaveLost()
    self:Screen("map")
end
function game:OpenShop()
    local P = Progress()
    if not MG.Shop then return end
    if P and not P:Unlocked("shop") then
        MG:Sound("buzz")
        MG:Note("Clear stage 2 to open the shop.")
        return
    end
    MG.Shop.Open("whack", function()
        game:PaintMallet()
        if MG.PaintCoins then MG:PaintCoins() end
    end)
end

-- Cards -----------------------------------------------------------------------------------------

local function GoalLines(view, state)
    local lines, target = {}, view.target
    for _, goal in ipairs(state.spec.goals or {}) do
        local have = Whack.Have(state, goal)
        lines[#lines + 1] = {icon = view:GoalIcon(goal), text = Whack.GoalText(goal, target.noun, target.accent),
            progress = state.phase == "over" and ("%d/%d"):format(math.min(have, goal.need), goal.need) or nil,
            done = state.phase == "over" and have >= goal.need or nil}
    end
    return lines
end
-- Stage n's intro: its goals, its time, its best, Start (or Carry on when a
-- round waits in it). A new kind of head's how-it-works card first.
function game:Intro(n)
    local spec = Whack.StageSpec(n)
    local P = Progress()
    local function Show()
        local waiting = self:Waiting()
        local carry = waiting == n
        local buttons
        if carry then
            buttons = {{label = "Carry on", width = 110, primary = true, onClick = function() game:CarryOn(n) end},
                {label = "Start again", width = 100, onClick = function() game:StartStage(n) end},
                {label = "Map", width = 70, onClick = function() game:ToMap() end}}
        else
            buttons = {{label = "Start", width = 110, primary = true, onClick = function() game:StartStage(n) end},
                {label = "Map", width = 70, onClick = function() game:ToMap() end}}
        end
        local sub = spec.boss and "Boss stage" or nil
        if waiting and not carry then
            local left = ("Stage %d in progress will be left."):format(waiting)
            sub = sub and (sub .. ". " .. left) or left
        end
        local best = P and P:BestScore("whack", n) or 0
        MG.Card.Show({game = "whack", title = ("Stage %d"):format(n), sub = sub,
            icon = spec.boss and ("whack." .. self.target.boss) or self.target.icon,
            lines = GoalLines(self, Whack.NewStage(n)), big = ("%d seconds"):format(spec.length),
            best = best > 0 and ("Best %d"):format(best) or nil, buttons = buttons, width = 320})
    end
    if not MG.Card then return end
    -- The shop's card when it was missed (the window closed before its "Got it"), then the stage's own.
    local cards = P and P.Owed and P:Owed({"shop"}) or {}
    if spec.card then cards[#cards + 1] = spec.card end
    if #cards > 0 then MG.Card.HowItWorks(cards, Show) else Show() end
end
local function SayDone(view, cleared)
    if not cleared then view:Voice("done") end
end
local function UnlockIcon(id)
    local P = Progress()
    if id == "shop" then return "coin" end
    for _, skin in ipairs(P and P.SKINS or {}) do
        if id == "mallet:" .. skin.id then return skin.icon end
    end
    return nil
end
function game:WinCard(report, stars)
    if not MG.Card then return end
    local state, P = self.state, Progress()
    local n = state.stage
    local lines = {}
    for _, id in ipairs(report.unlocks or {}) do
        lines[#lines + 1] = {icon = UnlockIcon(id), text = ("New: %s"):format(P and P:Name(id) or id)}
    end
    local cards = report.cards or {}
    local function After(done)
        MG.Card.Hide("whack")
        MG.Card.HowItWorks(cards, done)
    end
    MG.Card.Show({game = "whack", title = ("Stage %d cleared!"):format(n), stars = stars, lines = lines,
        big = ("Score %d"):format(state.score), best = report.newBest and "New best!" or nil, coins = report.coins,
        buttons = {{label = "Next", width = 110, primary = true, onClick = function()
            After(function() game:Next(n) end)
        end}, {label = "Map", width = 70, onClick = function()
            After(function() game:Screen("map") end)
        end}}})
end
-- After a win: the map's glow walks on to the next stage, then its intro.
function game:Next(n)
    self:Screen("map")
    if not self.map then return self:Intro(n + 1) end
    -- Cut short (the map left, the window hidden): no intro.
    self.map:Walk(n, n + 1, function(cleared)
        if not cleared and game.screen == "map" then game:Intro(n + 1) end
    end)
end
function game:LoseCard()
    if not MG.Card then return end
    local state, P = self.state, Progress()
    local price = P and P:Price("time", state.extra) or 0
    MG.Card.Show({game = "whack", title = "Time's up", sub = ("Stage %d"):format(state.stage), lines = GoalLines(self, state),
        big = ("Score %d"):format(state.score), width = 320,
        buttons = {{label = "+10 seconds", width = 120, primary = true, sub = ("%d coins"):format(price), onClick = function() game:BuyTime() end},
            {label = "Try again", width = 100, onClick = function() game:StartStage(game.state.stage) end},
            {label = "Map", width = 70, onClick = function() game:ToMap() end}}})
end
-- +10 seconds on the lose card (the price ladder, 40 coins first): the round
-- carries on, paused, ten seconds longer.
function game:BuyTime()
    local state, P = self.state, Progress()
    if not (P and self:LostWaiting()) then return false end
    local ok, _, price = P:Buy("time", state.extra)
    if not ok then
        MG:Sound("buzz")
        MG:Note(("Not enough coins. You need %d."):format(price or 0))
        return false
    end
    Whack.AddTime(state)
    MG:Sound("buy")
    MG.Card.Hide("whack")
    self:Screen("stage")
    self:Save()
    self:Label()
    MG:Note("Ten more seconds. Click Resume when you're ready.")
    return true
end

-- A round's end ---------------------------------------------------------------------------------

function game:RoundOver()
    local state = self.state
    self:Label()
    if state.mode ~= "stage" then return self:QuickOver() end
    if state.outcome ~= "won" then
        MG:Sound("lose")
        MG:Banner("Time's up!", {size = 30, life = 1.4, glow = self.colour})
        self:Save()
        return self:LoseCard()
    end
    local stars = Whack.Stars(state)
    local P = Progress()
    local report = P and P:Finish("whack", state.stage, {won = true, stars = stars, score = state.score, golden = state.golden,
        boss = state.spec.boss ~= nil}) or {coins = 0, unlocks = {}, cards = {}}
    state.paid = true
    self:Unsave("stage")
    MG:Sound("win")
    MG:Banner("Stage cleared!", {size = 30, life = 1.4, colour = self.textColour, glow = GOLD})
    MG:Tween(.9, nil, SayDone, self)
    self:WinCard(report, stars)
end
-- A Quick round over: its score kept as a best when it beats one, its coins,
-- a banner, a fanfare, and a word from the target a moment later.
function game:QuickOver()
    local state, P = self.state, Progress()
    local mine, account = MG:Record("whack", state.score)
    local report = P and P:Finish("whack", "quick", {score = state.score, golden = state.golden})
    self:Unsave("quick")
    local coins = report and report.coins or 0
    local points = Plural(state.score, "point", "points")
    MG:Note("Time's up: " .. points .. (coins > 0 and (", +" .. Plural(coins, "coin", "coins")) or "") .. "."
        .. (account and " New account best!" or mine and " New best!" or ""))
    local best = mine or account
    MG:Sound(best and "record" or "win")
    MG:Banner(best and "New best!" or "Time's up!", {sub = points .. ", best streak " .. state.bestStreak,
        size = 30, life = 2.8, glow = best and GOLD or self.colour})
    if best then
        MG:Burst(nil, {count = 30, texture = MG.ART.sparkleGold, blend = "BLEND", size = 16, speed = 170, life = 1.1,
            gravity = 140, spin = .3})
    end
    MG:Tween(.9, nil, SayDone, self)
    self:PaintHud(true)
end

-- The window's calls --------------------------------------------------------------------------

-- A flight: the round you left (paused), its lose card, a saved one, a Quick
-- round when that was last, else the next stage's intro.
function game:OnFlight()
    local state, P = self.state, Progress()
    if Live(state) then
        Whack.Pause(state)
        self:Screen(state.mode)
        MG:Note(state.mode == "stage" and ("Carrying on with stage %d. Click Resume."):format(state.stage)
            or "Carrying on with your Quick round. Click Resume.")
        return
    end
    if self:LostWaiting() then
        self:Screen("stage")
        if MG.Card and not MG.Card.Shown("whack") then self:LoseCard() end
        return
    end
    local snap = P and P:Resume("whack")
    local loaded = snap and Whack.LoadStage(snap)
    if snap and not loaded then P:SaveResume("whack", nil) end
    if MG.Card then MG.Card.Hide("whack") end
    if loaded then
        self.state = loaded
        self:Calm()
        self:Screen(loaded.mode)
        self:DrawTimer()
        if loaded.phase == "over" then return self:LoseCard() end
        MG:Note(loaded.mode == "stage" and ("Carrying on with stage %d. Click Resume."):format(loaded.stage)
            or "Carrying on with your Quick round. Click Resume.")
        return
    end
    if P and P:Last("whack") == "quick" then
        self.state = Whack.New(nil, Whack.QuickSpec(self:Extras()))
        self:Calm()
        self:Screen("quick")
        self:DrawTimer()
        return self:Remind()
    end
    self:ReadyStage(P and P:Level("whack") or 1)
end
-- /era whack, the Play row: the stage map (what was playing paused and kept).
function game:OnCommand()
    if Whack.Pause(self.state) then self:Save() end
    self:LeaveLost()
    if MG.Card then MG.Card.Hide("whack") end
    if MG.Shop and MG.Shop.Shown("whack") then MG.Shop.Close("whack") end
    self:Screen("map")
    if self.landed then MG:Note(self.landed) end
end
function game:Shown(shell, why)
    why = why or MG.openWhy
    self.swingT = nil
    if self.mallet then self.mallet:Hide() end
    self:PaintMallet()
    if why == "switch" then
        self:Screen(self.screen or "map")
        self:Remind()
    elseif why == "flight" then
        self:OnFlight()
    else
        self:OnCommand()
    end
    self.landed = nil
    MG:SetScore(self.state.score, true)
end
-- Every hide pauses a round counting down or being played, and saves it.
function game:Pause(shell, why)
    if Whack.Pause(self.state) then self:Label() end
    self.swingT = nil
    self:Save()
end
-- Landed: the round waits, paused and saved, for the next flight.
function game:Land(shell)
    local state = self.state
    if Whack.Pause(state) then self:Label() end
    if state.phase == "paused" then self.landed = LANDED end
    self:Save()
end
-- /era reset of the games' progress: no round kept, the map next time.
function game:ProgressReset()
    self.state, self.landed = Whack.New(), nil
    if MG.Card then MG.Card.Hide("whack") end
    if not self.root then return end
    self:Calm()
    if MG:Shown("whack") then self:Screen("map") else self.screen = "map" end
end

-- /era whack tune -------------------------------------------------------------------------------

local KEYS = {}
for key in pairs(Whack.FRAMING) do KEYS[key:lower()] = key end
local function TuneLine(key)
    local t = MG:Tune(key)
    return ("Whack tune %s: zoom %.2f, cam %.2f, up %.2f, turn %d, body %.2f, peek %.2f, lift %.2f."):format(key,
        tonumber(t.zoom) or 0, tonumber(t.cam) or 1, tonumber(t.up) or 0, math.floor((tonumber(t.turn) or 0) + .5),
        tonumber(t.body) or 1, tonumber(t.peek) or V.PEEK, tonumber(t.lift) or 0)
end
-- Every hole framed again, and the peek's height kept.
function game:Retune()
    local peek = MG:Tune(self:Target().key).peek
    self.peek = type(peek) == "number" and peek or nil
    if self.holes then self:Reframe() end
end
function game:Command(words)
    local args = {}
    for word in tostring(words or ""):lower():gmatch("%S+") do args[#args + 1] = word end
    if args[1] ~= "tune" then return false end
    local key, at = self:Target().key, 2
    if KEYS[args[2] or ""] then key, at = KEYS[args[2]], 3 end
    local field, value = args[at], args[at + 1]
    if not field then
        EraUI:Print(TuneLine(key))
        return true
    end
    if field == "reset" then
        if at == 3 then MG:ClearTune(key) else for each in pairs(Whack.FRAMING) do MG:ClearTune(each) end end
        self:Retune()
        EraUI:Print(TuneLine(key))
        return true
    end
    if field == "cursor" then
        EraUI:Print("The game's pointer always shows over the field; the mallet sits on its tip.")
        return true
    end
    local range = Whack.TUNE_RANGE[field]
    if not range then
        EraUI:Print(("Whack tune fields: %s."):format(table.concat(Whack.TUNE_FIELDS, ", ")))
        return true
    end
    local n = tonumber(value)
    if not n or n ~= n then
        EraUI:Print(("Whack tune %s takes a number from %s to %s."):format(field, range[1], range[2]))
        return true
    end
    n = math.max(range[1], math.min(range[2], n))
    MG:SetTune(key, field, n)
    self:Retune()
    EraUI:Print(TuneLine(key))
    return true
end

-- The stage map ----------------------------------------------------------------------------------

local source = {game = "whack", PerPage = 10, noun = "stage"}
-- A page a zone (Whack.PageZone): its name on top, so the walk onto the next
-- page says "New place: Westfall".
function source.Page(page)
    local P = Progress()
    local first, last = (page - 1) * 10 + 1, page * 10
    local zone = Whack.PageZone(game.target, first)
    return {title = P.ZONE_NAMES[zone] or ("Stages %d to %d"):format(first, last),
        sub = ("Stages %d to %d, %d of 30 stars"):format(first, last, P:TotalStars("whack", first, last)),
        ground = "zone." .. zone .. ".ground", tint = {1, 1, 1},
        locked = first > P:Level("whack"), lockText = ("Clear stage %d to open."):format(first - 1)}
end
function source.Node(n)
    local P = Progress()
    local stars = P:Stars("whack", n)
    local state = n > P:Level("whack") and "locked" or (stars > 0 and "done" or "open")
    return {state = state, stars = stars, boss = Whack.StageSpec(n).boss ~= nil, art = "whack." .. game.target.boss,
        carry = game:Waiting() == n}
end
function source.Pick(n) game:Intro(n) end
function source.Last() return Progress():Level("whack") end
Whack.MAP_SOURCE = source
function game:MakeMap()
    self:Retune()
    if MG.Map and Progress() then self.map = MG.Map.New(self.holder, source) end
end
