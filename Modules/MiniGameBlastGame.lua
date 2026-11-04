local _, EraUI = ...

-- Azeroth Blast in the mini-games window (experimental, with the
-- mini-games): its screens, cards and flow, and the one file that registers
-- it (MiniGames:Register("blast", game)). The board's drawing and beats are
-- Modules/MiniGameBlastView.lua, the HUD and power-ups
-- Modules/MiniGameBlastHud.lua, the rules Modules/MiniGameBlast.lua with its
-- goals and levels files.
--
-- Screens (game.screen): "map" (the level map, MiniGames.Map: one zone a
-- page; footer Shop and Free play), "level" (a level's board, HUD and
-- power-up bar; footer Map and Hint) and "free" (the old endless board,
-- kept per character; footer Map, Hint and New board). Over a level, one
-- card at a time (MiniGames.Card): the intro (goals, moves, boosters to
-- pick, Play or Carry on), a win (stars, score, coins, what opened; Next
-- walks the map to the next level) or a loss (how close it was, +5 moves,
-- Try again, Map), and each how-it-works card the first time.
--
-- Opening (game:Shown's why): a flight carries on where you left off (a
-- level waiting on any character of the account goes straight back in;
-- else Free play when that was last; else the next level's intro); /era
-- blast and the Play row open the map; the Switch button shows what showed
-- last. Every move settles in the rules at once and the level is saved then
-- (MiniGames.Progress:SaveResume), on every pause, on logout and as it
-- starts; a win is paid for (Progress:Finish) the moment it's won, so a
-- window closed mid-move loses nothing. A lost level waits on its lose card
-- until Try again or Map.
local MG = EraUI.MiniGames
local VIEW = MG and MG.BlastView
if not VIEW then return end

local Blast = MG.Blast
local game, V, NOTES, OPTS = VIEW.game, VIEW.V, VIEW.NOTES, VIEW.OPTS
local EMPTY = {}
local WORDS = {
    carry = "Carrying on with level %d.",
    left = "Level %d in progress will be left.",
    malletArm = "Click a piece or blocker to smash it. Right-click to cancel.",
    swapArm = "Swap any two pieces side by side.",
    coins = "Not enough coins. You need %d.",
    bought = "Bought %s for %d coins.",
    relicSmash = "Relics can't be smashed.",
    shuffled = "Pieces shuffled.",
    moreMoves = "Five more moves.",
    won = "Level %d cleared!",
    lost = "Out of moves. Try again.",
    pick = "Pick a level on the map.",
    play = "Meet the goals before your moves run out.",
    free = "Match three or more of a race.",
    strikes = "Strikes back every %d moves",
    freeCoin = "+1 coin",
    freeCoins = "+%d coins",
    lostBuy = "Out of moves. Buy 5 more or try again.",
}
local BOOSTERS = {"charge", "sheep", "lust"}
local GOAL_ICONS = {score = "star", oil = "block.oil", ice = "block.ice", crate = "block.crate", web = "block.web",
    relic = "relic.1", skull = "block.skull"}
local ACTION_ICONS = {oil = "block.oil", freeze = "block.ice", crates = "block.crate", skulls = "block.skull", web = "block.web"}
local FOOTER = {map = {"free", "shop"}, level = {"hint", "map"}, free = {"new", "hint", "map"}}
game.boost = {}

local function Progress() return MG.Progress end
local function Faction() return MG.Faction() == "Alliance" and "Alliance" or "Horde" end
local function CardUp() return MG.Card ~= nil and MG.Card.Shown("blast") end
local function HideCard() if MG.Card then MG.Card.Hide("blast") end end

function game:Title() return "Azeroth ", "Blast" end
function game:Hint()
    if self.screen == "level" and self.level then
        local spec = self.level.spec
        return ("%s, level %d"):format(spec.name, spec.n)
    elseif self.screen == "map" then
        return WORDS.pick
    end
    return WORDS.free
end
function game:Score()
    if self.screen == "map" then return 0 end
    if self.shownScore then return self.shownScore end
    return self.state and self.state.score or 0
end
-- The header's best: this level's (a level), your stars (the map), else the old best.
function game:HeaderBest()
    local P = Progress()
    if not P then return nil end
    if self.screen == "level" and self.level then return ("Best %d"):format(P:BestScore("blast", self.level.level)) end
    if self.screen == "map" then
        local stars = P:TotalStars("blast")
        return stars == 1 and "1 star" or ("%d stars"):format(stars)
    end
    return nil
end
function game:Header()
    if MG.window and MG.current == "blast" and MG.PaintHeader then MG:PaintHeader() end
end

-- Free play's board: this character's kept one, else a new one (kept at once).
function game:Load()
    if self.free then return self.free end
    local state = Blast.New(nil, MG.Faction())
    self.free = state
    local kept = MG:CharData("blast")
    if not Blast.Load(state, kept) then Blast.Save(state, kept) end
    -- A board from before coins: its points so far count as paid.
    local P = Progress()
    if kept.coined == nil and P then kept.coined = math.floor((tonumber(state.score) or 0) / P.COINS.freePer) end
    return state
end
-- The level in play, saved for every character of the account (never a won one).
function game:Save()
    local P, state = Progress(), self.level
    if not (P and state and self.started) or state.outcome == "won" then return end
    P:SaveResume("blast", Blast.SaveLevel(state))
end
function game:Keep()
    if self.free then Blast.Save(self.free, MG:CharData("blast")) end
    self:Save()
end

-- Building ---------------------------------------------------------------------------------------

local function MakeButtons(self, bar)
    local function Make(label, width, onClick)
        local button = MG.Button(bar, label, width, 28)
        button:SetScript("OnClick", onClick)
        button:Hide()
        return button
    end
    self.buttons = {
        free = Make("Free play", 96, function() MG:Sound("uiClick"); game:ShowFree() end),
        shop = Make("Shop", 70, function() game:OpenShop() end),
        hint = Make("Hint", 64, function() game:AskHint() end),
        map = Make("Map", 64, function() MG:Sound("uiClick"); game:ToMap() end),
        new = Make("New board", 100, function() game:NewBoard() end),
    }
    self.button, self.hintButton, self.mapButton = self.buttons.new, self.buttons.hint, self.buttons.map
end
-- The level map's source (MiniGames.Map): a zone a page.
local source = {game = "blast", PerPage = 10, noun = "level"}
function source.Page(page)
    local P = Progress()
    local first = (page - 1) * 10 + 1
    local zone, tier = Blast.Zone(first)
    local locked = P ~= nil and first > P:Level("blast")
    local lockText
    if locked and first > 1 then lockText = ("Beat %s to open."):format(Blast.Zone(first - 1).boss.name) end
    return {title = zone.name .. (tier > 0 and (" " .. (tier + 1)) or ""),
        sub = ("Levels %d to %d, %d of 30 stars"):format(first, first + 9, P and P:TotalStars("blast", first, first + 9) or 0),
        ground = "zone." .. zone.key .. ".ground", tint = {MG:Colour3("zone." .. zone.key .. ".tint", zone.tint)},
        locked = locked, lockText = lockText}
end
function source.Node(n)
    local P = Progress()
    local stars = P:Stars("blast", n)
    local open = n <= P:Level("blast")
    local snap = P:Resume("blast")
    local zone = Blast.Zone(n)
    return {state = stars > 0 and "done" or open and "open" or "locked", stars = stars, boss = n % 10 == 0,
        art = "zone." .. zone.key .. ".bossIcon", carry = snap ~= nil and snap.level == n or nil}
end
function source.Pick(n) game:Intro(n) end
function source.Last() return Progress():Level("blast") end
game.mapSource = source

function game:Build(shell, holder, bar)
    self.holder, self.bar = holder, bar
    local play = CreateFrame("Frame", nil, holder)
    play:SetSize(MG.CONTENT_W, MG.CONTENT_H)
    play:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    self.play = play
    self:MakeBoard(shell, play)
    self:MakeHud(play)
    MakeButtons(self, bar)
    if MG.Map and Progress() then self.map = MG.Map.New(holder, source) end
    self.state = self:Load()
    self:Look(Progress() and Progress():Look() or "stone")
    self:PaintCells()
end

-- Screens ----------------------------------------------------------------------------------------

function game:Footer(screen)
    local P = Progress()
    for _, button in pairs(self.buttons) do button:Hide() end
    local prev
    for _, id in ipairs(FOOTER[screen] or EMPTY) do
        local button = self.buttons[id]
        if id ~= "shop" or (P and P:Unlocked("shop") and MG.Shop) then
            button:ClearAllPoints()
            if prev then button:SetPoint("RIGHT", prev, "LEFT", -6, 0) else button:SetPoint("RIGHT", self.bar, "RIGHT", 0, 0) end
            button:Show()
            prev = button
        end
    end
end
function game:SetScreen(screen)
    self.screen = screen
    if screen ~= "map" and self.map then self.map:Hide() end
    self.play:SetShown(screen ~= "map")
    self:Footer(screen)
end
-- Everything let go: a move shown, the pick, a hint, an armed power-up.
function game:Settle()
    if self.busy then self:Done(true) end
    self:Select(nil)
    self:ClearHint()
    self.pressed = nil
    self:Disarm()
end
function game:ShowMap(page)
    self:Settle()
    HideCard()
    if MG.Shop and MG.Shop.Shown("blast") then MG.Shop.Close("blast") end
    if not self.map then return self:ShowFree() end
    self:SetScreen("map")
    MG:StopSound("drums")
    MG:Note("")
    self.map:Show(page)
    self:Header()
end
-- Free play: the old endless board in the look picked.
function game:ShowFree()
    self:Settle()
    HideCard()
    local P = Progress()
    self.state = self:Load()
    self:SetScreen("free")
    if P then P:SetLast("blast", "free") end
    self:Look(P and P:Look() or "stone")
    self:PaintCells()
    MG:SetScore(self.state.score, true)
    self:PaintHud(true)
    self:Header()
    if self.landed then MG:Note(self.landed)
    elseif self.state.moves == 0 and self.state.score == 0 then MG:Note(NOTES.first)
    else MG:Note("") end
    if self.state.lust > 0 and not MG.held.drums then MG:Sound("drums") end
end
-- Free play's look: the next unlocked one ("stone" first).
function game:NextLook()
    local P = Progress()
    if not P or self.screen ~= "free" then return end
    local looks, at = P:Looks(), 1
    for k, key in ipairs(looks) do if key == P:Look() then at = k end end
    local key = looks[at % #looks + 1]
    P:SetLook(key)
    self:Look(key)
    MG:Sound("uiClick")
    MG:Note(("Board: %s."):format(key == "stone" and "Stone" or P:Name("zone:" .. key)))
end
-- A level on screen: its zone's look, pieces, oil, HUD and header.
function game:SetLevel(state, started)
    self.level, self.state, self.started = state, state, started and true or false
    self.win = nil
    self:SetScreen("level")
    self:Look(state.spec.zone)
    self:Calm()
    self:PaintCells()
    MG:SetScore(state.score, true)
    self:PaintHud(true)
    self:Header()
end
-- What showed last, as it was (the Switch button, a fight over): a card or
-- the shop over the map stays (a how-it-works card after a win, say).
function game:Restore()
    local screen = self.screen
    if screen == "map" and self.map then
        self:SetScreen("map")
        self.map:Show(self.map:Page())
        self:Header()
        return
    end
    if screen == "map" or screen == "free" then return self:ShowFree() end
    if not self.level then
        if CardUp() then return self:Header() end
        return self:ShowMap()
    end
    self.state = self.level
    self:SetScreen("level")
    self:Look(self.level.spec.zone)
    self:PaintCells()
    MG:SetScore(self.level.score, true)
    self:PaintHud(true)
    self:Header()
    if self.level.lust > 0 and not MG.held.drums then MG:Sound("drums") end
end

-- Levels -----------------------------------------------------------------------------------------

local function GoalIcon(goal, state)
    if goal.id == "enemy" then return "crest." .. (goal.foe == "Horde" and "Horde" or "Alliance") end
    if goal.id == "collect" then
        local race = Blast.RACE[goal.race]
        return race and race.file
    end
    if goal.id == "boss" then return "zone." .. (state.spec.zone or "elwynn") .. ".bossIcon" end
    return GOAL_ICONS[goal.id] or "star"
end
local function GoalLines(state, progress)
    local lines = {}
    for k, goal in ipairs(state.goals) do
        if k > 3 then break end
        lines[k] = {icon = GoalIcon(goal, state), text = Blast.GoalText(goal, state.faction),
            progress = progress and Blast.GoalShort(goal) or nil, done = progress and goal.have >= goal.need or nil}
    end
    return lines
end
-- A level's intro: its first how-it-works card (once), then its goals, moves
-- and boosters over its board. A level waiting for this one: Carry on.
function game:Intro(n)
    local P = Progress()
    if not P then return end
    self:Settle()
    HideCard()
    local faction = Faction()
    local snap = P:Resume("blast")
    local waiting = snap and snap.level or nil
    local state, carry
    if waiting == n then
        if self.level and self.started and self.level.level == n then state = self.level
        else state = Blast.LoadLevel(snap, nil, faction) end
        carry = state ~= nil
        if not state then
            P:SaveResume("blast", nil)
            waiting = nil
        end
    end
    state = state or Blast.NewLevel(n, nil, faction)
    if not state then return self:ShowMap() end
    self:SetLevel(state, carry)
    self.pending, self.boost = n, {}
    local first = n == 1 and P:Stars("blast", 1) == 0
    MG:Note(first and NOTES.first or WORDS.play)
    local leaving = waiting ~= nil and waiting ~= n and waiting or nil
    local function Show() if self.pending == n then self:IntroCard(n, carry, leaving) end end
    -- Any card still owed (the window closed before its "Got it"), then the level's own.
    local cards = P.Owed and P:Owed() or {}
    if state.spec.card then cards[#cards + 1] = state.spec.card end
    if MG.Card and #cards > 0 then MG.Card.HowItWorks(cards, Show) else Show() end
end
function game:IntroCard(n, carry, leaving)
    local P, state = Progress(), self.level
    if not (MG.Card and state) then return end
    local spec = state.spec
    local lines = GoalLines(state, carry)
    local boss = spec.boss
    if boss and #lines < 4 then
        local action = boss.actions and boss.actions[1]
        lines[#lines + 1] = {icon = action and ACTION_ICONS[action.kind] or "zone." .. spec.zone .. ".bossIcon",
            text = WORDS.strikes:format(boss.every or 4)}
    end
    local toggles = {}
    if not carry then
        for _, id in ipairs(BOOSTERS) do
            if P:Unlocked(id) then
                toggles[#toggles + 1] = {id = id, icon = "boost." .. id, count = P:Count(id), price = P:Price(id), on = self.boost[id]}
            end
        end
    end
    local buttons
    if carry then
        buttons = {{label = "Carry on", width = 110, primary = true, onClick = function() game:CarryOnLevel() end},
            {label = "Start again", width = 100, onClick = function() game:Begin() end},
            {label = "Map", width = 70, onClick = function() game:IntroMap() end}}
    else
        buttons = {{label = "Play", width = 110, primary = true, onClick = function() game:Begin() end},
            {label = "Map", width = 70, onClick = function() game:IntroMap() end}}
    end
    local best = P:BestScore("blast", n)
    MG.Card.Show({game = "blast", title = ("Level %d"):format(n),
        sub = leaving and WORDS.left:format(leaving) or (boss and ("%s, boss fight"):format(spec.name) or spec.name),
        icon = "zone." .. spec.zone .. ".icon", lines = lines, big = ("%d moves"):format(state.movesLeft),
        best = best > 0 and ("Best %d"):format(best) or nil, toggles = toggles, width = carry and 320 or nil,
        onToggle = function(id) return game:ToggleBoost(id) end, buttons = buttons})
end
-- A booster on the intro card: on and off when owned; else bought (and on).
function game:ToggleBoost(id)
    local P = Progress()
    if self.boost[id] then
        self.boost[id] = nil
        return false, P:Count(id)
    end
    if P:Count(id) > 0 then
        self.boost[id] = true
        return true, P:Count(id)
    end
    local ok, why, price = P:Buy(id)
    if ok then
        MG:Sound("buy")
        MG:Note(WORDS.bought:format(P:Name(id), price or 0))
        self.boost[id] = true
        return true, P:Count(id)
    end
    MG:Sound("buzz")
    if why == "coins" then MG:Note(WORDS.coins:format(price or 0)) end
    return false, 0
end
-- Play (or Start again): the boosters picked are used, a lost level left
-- waiting is paid for and let go, and the level starts (saved at once).
-- quiet: no fade (a click on the board behind the card).
function game:Begin(quiet)
    local P, n = Progress(), self.pending or (self.level and self.level.level)
    if not (P and n) then return end
    self.pending = nil
    HideCard()
    local faction = Faction()
    local snap = P:Resume("blast")
    if snap and snap.outcome == "lost" then
        local old = Blast.LoadLevel(snap, nil, faction)
        if old then P:Finish("blast", old.level, Blast.Result(old)) end
        P:SaveResume("blast", nil)
    end
    local boosters, any = {}, false
    for _, id in ipairs(BOOSTERS) do
        if self.boost[id] and P:Use(id) then boosters[id], any = true, true end
    end
    self.boost = {}
    local state = self.level
    if any or self.started or not state or state.level ~= n then state = Blast.NewLevel(n, nil, faction, boosters) end
    self:SetLevel(state, true)
    self:Save()
    P:SetLast("blast", "level")
    if not quiet then
        self:Queue({kind = "fade", dur = V.FADE, sound = "chime"})
        if any then self:Queue({kind = "boost", boosted = state.boosted, dur = V.BOOST}) end
        self.after = n == 1 and P:Stars("blast", 1) == 0 and NOTES.first or WORDS.play
    end
end
-- Carry on from the intro: the level as it was left (a lost one on its lose card).
function game:CarryOnLevel()
    self.pending = nil
    HideCard()
    self.started = true
    local state = self.level
    if state.outcome == "lost" then return self:LoseCard() end
    MG:Note(WORDS.carry:format(state.level))
    self:Save()
    Progress():SetLast("blast", "level")
end
function game:IntroMap()
    self.pending = nil
    if not self.started then self.level = nil end
    self:ShowMap()
end
-- Map from the footer: a card's Map, else the level kept (its node says Carry on).
function game:ToMap()
    if self.pending then return self:IntroMap() end
    if self.win then return self:AfterWin() end
    local state = self.level
    if self.screen == "level" and state and state.outcome == "lost" then self:LeaveLost() end
    self:Settle()
    self:Save()
    self:ShowMap()
end
-- A flight, or the Switch with nothing shown yet: back where you left off.
function game:CarryOn()
    local P = Progress()
    if not P then return self:ShowFree() end
    local state = self.level
    if self.screen == "level" and state and (self.pending or self.win or (self.started and not state.outcome)) then
        self:Restore()
        if self.started and not self.pending then MG:Note(WORDS.carry:format(state.level)) end
        return
    end
    local snap = P:Resume("blast")
    if snap then
        local loaded
        if state and self.started and state.level == snap.level and not state.outcome then loaded = state
        else loaded = Blast.LoadLevel(snap, nil, Faction()) end
        if loaded then
            HideCard()
            self.pending = nil
            self:SetLevel(loaded, true)
            if loaded.outcome == "lost" then self:LoseCard(true) else MG:Note(WORDS.carry:format(loaded.level)) end
            return
        end
        P:SaveResume("blast", nil)
    end
    if P:Last("blast") == "free" then return self:ShowFree() end
    self:Intro(P:Level("blast"))
end

-- Playing ----------------------------------------------------------------------------------------

function game:Pick(index, button)
    if self.busy or not (self.state and self.cells) then return end
    if self.screen ~= "level" and self.screen ~= "free" then return end
    -- A click on the board behind the intro card starts the level.
    if self.screen == "level" and self.pending then self:Begin(true) end
    local state = self.state
    if state.outcome then return end
    self.idle = 0
    if self.hintA then self:ClearHint() end
    if button == "RightButton" then
        self:Disarm(true)
        self:Select(nil)
        return
    end
    if self.armed == "mallet" then
        self:Smash(index)
        return
    end
    local piece = state.board[index]
    if not piece then return end
    local what = Blast.Locked(piece)
    if what then
        MG:Sound("buzz")
        MG:Pulse(self.cells[index], OPTS.buzz)
        MG:Note(NOTES.locked[what] or "")
        self:Select(nil)
        return
    end
    local selected = self.selected
    if selected == index then
        self:Select(nil)
        return
    end
    if selected and Blast.Adjacent(selected, index) then
        self:Select(nil)
        self.pressed = nil
        self:Move(selected, index)
        return
    end
    self:Select(index)
    self.pressed = index
    MG:Sound("uiClick")
end
-- Pressed on one piece and dragged onto the next: the same swap.
function game:Drag(index)
    local pressed = self.pressed
    if not pressed or self.busy or pressed == index or self.selected ~= pressed then return end
    if type(IsMouseButtonDown) ~= "function" or not IsMouseButtonDown("LeftButton") then
        self.pressed = nil
        return
    end
    if Blast.Adjacent(pressed, index) then self:Pick(index, "LeftButton") end
end
-- What the footer says once a move has played out.
function game:MoveNote(result)
    if result.lustStep then
        return (self.state and self.state.mode == "level" and NOTES.lustMoves or NOTES.lust):format(self:LustName())
    end
    if result.reshuffled or result.settled then return NOTES.shuffled end
    local combo = result.combo
    if combo == "hearth" then
        local race = Blast.RACE[result.hearthKind]
        return NOTES.hearthUsed:format(race and race.name or "piece")
    elseif combo == "flyer" then
        return NOTES.flyerCombo:format(self:FlyerName())
    elseif combo then
        return NOTES[combo]
    end
    local made, epics = nil, 0
    for _, step in ipairs(result.steps) do
        if step.made and step.made[1] then made = made or step.made[1].piece end
        epics = epics + (step.epics or 0)
    end
    if made then return made.special == "flyer" and NOTES.flyer:format(self:FlyerName()) or NOTES[made.special] end
    local clears = 0
    for _, step in ipairs(result.steps) do if (step.kind or "clear") == "clear" then clears = clears + 1 end end
    if clears >= 3 then return NOTES.chain:format(clears) end
    if epics > 0 then return NOTES.epic end
    return ""
end
-- A move made (a swap, a smash): its beats queued, then saved or paid for at once.
function game:Played(result, first)
    self.shownScore, self.shownMeter = result.scoreBefore, result.meterBefore
    self.lustPending = result.lustStep ~= nil
    if first then self:Queue(first) end
    self:QueueSteps(result)
    if result.reshuffled or result.settled then self:Queue({kind = "fade", dur = V.FADE, sound = "shuffle"}) end
    self.after = self:MoveNote(result)
    local epic = false
    for _, step in ipairs(result.steps or EMPTY) do if (step.epics or 0) > 0 then epic = true end end
    self.epicSound = epic
    if result.lustOver then self:LustOver() end
    self:Settled(result)
    self:PaintMeter()
    self:PaintPower()
end
function game:Move(a, b)
    local state = self.state
    self:ClearHint()
    local free = state.mode == "level" and self.armed == "swap"
    local result = Blast.Swap(state, a, b, free and {free = true} or nil)
    if not result.ok then
        if result.why == "nomatch" then
            self:Queue({kind = "slide", a = a, b = b, back = true, dur = V.SLIDE * 2})
            self.after = NOTES.nomatch
        elseif result.why == "locked" then
            MG:Sound("buzz")
            MG:Note(NOTES.locked[result.what] or "")
        end
        return result
    end
    if free then
        Progress():Use("swap")
        self:Disarm()
    end
    self:Played(result, {kind = "slide", a = a, b = b, dur = V.SLIDE, board = result.swapped,
        moves = state.mode == "level" and state.movesLeft or nil})
    return result
end
-- The Mallet on a cell: no move used; a relic can't be smashed.
function game:Smash(index)
    local state = self.level
    local result = Blast.Smash(state, index)
    if not result.ok then
        if result.why == "relic" then
            MG:Sound("buzz")
            MG:Note(WORDS.relicSmash)
        end
        return result
    end
    Progress():Use("mallet")
    self:Disarm()
    self:Played(result, {kind = "smash", i = index, dur = V.SMASH})
    return result
end
-- A move settled in the rules: Free play's board kept (and its coins),
-- a level saved, or its win paid for now.
function game:Settled(result)
    local state, P = self.state, Progress()
    if state.mode ~= "level" then
        local kept = MG:CharData("blast")
        Blast.Save(state, kept)
        if P then self.freeCoins = (self.freeCoins or 0) + P:FreeCoins(kept, state.score) end
        return
    end
    self.started = true
    if state.outcome == "won" then self:Won() else self:Save() end
end
function game:Won()
    local state, P = self.level, Progress()
    if self.win or not (P and state) then return end
    local result = Blast.Result(state)
    local report = P:Finish("blast", state.level, result)
    P:SaveResume("blast", nil)
    P:SetLast("blast", "level")
    self.win = {n = state.level, result = result, report = report, bonus = state.finished and state.finished.bonus or 0}
end
-- A move played out: Free play's coins float up; a level won shows its
-- boss going down and its win card, a level lost its lose card. cut: the
-- window is hiding (the cards wait there, quietly).
function game:Ended(cut)
    local state = self.state
    if state.mode ~= "level" then
        local coins = self.freeCoins or 0
        self.freeCoins = 0
        if coins > 0 and not cut and self.hud then
            MG:FloatText(self.hud.moves, coins == 1 and WORDS.freeCoin or WORDS.freeCoins:format(coins), {colour = {1, .84, .35}, size = 15, rise = 26})
            MG:Sound("coin")
        end
        return
    end
    if self.screen ~= "level" then return end
    if state.outcome then MG:StopSound("drums") end
    if self.win and not self.win.shown then
        self.win.shown = true
        if state.boss and not cut then
            -- Cut short (the window hid, a Switch): the card waits there, quietly.
            self:BossDown(function(cleared) if self.win then self:WinCard(cleared) end end)
        else
            self:WinCard(cut)
        end
    elseif state.outcome == "lost" and not CardUp() then
        self:LoseCard(cut)
    end
end

-- Win and loss ------------------------------------------------------------------------------------

local function UnlockIcon(id)
    local P = Progress()
    local kind, key = tostring(id):match("^(%a+):(%w+)$")
    if kind == "zone" or kind == "look" then return "zone." .. key .. ".icon" end
    if kind == "mallet" then
        for _, skin in ipairs(P and P.SKINS or EMPTY) do if skin.id == key then return skin.icon end end
        return "mallet.1"
    end
    if id == "shop" then return "coin" end
    if P and P.BOOSTERS[id] then return "boost." .. id end
    return "power." .. tostring(id)
end
function game:WinCard(quiet)
    local win, P = self.win, Progress()
    if not (win and P and MG.Card) then return end
    local report, result = win.report, win.result
    local lines = {}
    for _, gift in ipairs(report.gifts or EMPTY) do
        lines[#lines + 1] = {icon = UnlockIcon(gift.id), text = ("%s x%d"):format(P:Name(gift.id), gift.count)}
    end
    for _, id in ipairs(report.unlocks or EMPTY) do lines[#lines + 1] = {icon = UnlockIcon(id), text = ("New: %s"):format(P:Name(id))} end
    while #lines > 4 do table.remove(lines) end
    local spec = self.level and self.level.spec
    local sub = win.bonus > 0 and ("%d moves left: +%d"):format(result.movesLeft, win.bonus) or (spec and spec.name)
    MG.Card.Show({game = "blast", title = WORDS.won:format(win.n), sub = sub, stars = result.stars, lines = lines,
        best = ("Score %d"):format(result.score) .. (report.newBest and "  |cffffd659New best!|r" or ""), coins = report.coins, quiet = quiet,
        buttons = {{label = "Next", width = 110, primary = true, onClick = function() game:Next() end},
            {label = "Map", width = 70, onClick = function() game:AfterWin() end}}})
    if not quiet then
        MG:Sound("win")
        -- Something opened: its own sound once the stars have filled.
        if report.unlocks and report.unlocks[1] then
            MG:Tween(1.3, nil, function(_, cleared) if not cleared then MG:Sound("unlock") end end)
        end
    end
    MG:Note(WORDS.won:format(win.n))
end
-- After a win: the map first (so a Switch or a fight brings it back as it
-- was), the how-it-works cards for what opened over it, then (walk) its
-- glow walks to the next level's intro.
function game:LeaveWin(walk)
    local win = self.win
    local n = win and win.n or (self.level and self.level.level) or 1
    HideCard()
    self.win, self.level, self.started = nil, nil, false
    self:ShowMap(walk and math.floor((n - 1) / 10) + 1 or nil)
    local function Walk()
        if not (walk and self.map and self.screen == "map") then return end
        self.map:Walk(n, n + 1, function(cleared) if not cleared and self.screen == "map" then self:Intro(n + 1) end end)
    end
    if MG.Card then MG.Card.HowItWorks(win and win.report.cards or EMPTY, Walk) else Walk() end
end
function game:Next() return self:LeaveWin(true) end
function game:AfterWin() return self:LeaveWin(false) end
function game:LoseCard(quiet)
    local state, P = self.level, Progress()
    if not (state and P and MG.Card) then return end
    local buttons = {}
    if P:Unlocked("moves") then
        local owned, price = P:Count("moves"), P:Price("moves", state.extra or 0)
        buttons[1] = {label = "+5 moves", width = 120, primary = true, sub = owned > 0 and ("%d left"):format(owned) or ("%d coins"):format(price),
            onClick = function() game:BuyMoves() end}
    end
    buttons[#buttons + 1] = {label = "Try again", width = 100, primary = #buttons == 0, onClick = function() game:TryAgain() end}
    buttons[#buttons + 1] = {label = "Map", width = 70, onClick = function() game:LeaveLost(); game:ShowMap() end}
    MG.Card.Show({game = "blast", title = "Out of moves", sub = ("Level %d"):format(state.level), lines = GoalLines(state, true),
        buttons = buttons, width = 320})
    if not quiet then MG:Sound("lose") end
    MG:Note(#buttons == 3 and WORDS.lostBuy or WORDS.lost)
end
-- +5 moves on the lose card: an owned one first, else coins up the price ladder.
function game:BuyMoves()
    local state, P = self.level, Progress()
    local ok, why, price = P:BuyAndUse("moves", state.extra or 0)
    if not ok then
        MG:Sound("buzz")
        if why == "coins" then MG:Note(WORDS.coins:format(price or 0)) end
        return
    end
    MG:Sound((price or 0) > 0 and "buy" or "powerUse")
    Blast.AddMoves(state, 5)
    HideCard()
    self:Save()
    self:PaintHud(true)
    self:ShowMoves(state.movesLeft, true)
    MG:Note((price or 0) > 0 and WORDS.bought:format(P:Name("moves"), price) or WORDS.moreMoves)
end
-- A lost attempt let go (Try again, Map): paid for (a little), its save gone.
function game:LeaveLost()
    local state, P = self.level, Progress()
    if not (state and P and state.outcome == "lost") then return end
    P:Finish("blast", state.level, Blast.Result(state))
    P:SaveResume("blast", nil)
    self.level, self.started = nil, false
end
function game:TryAgain()
    local n = self.level and self.level.level
    if not n then return end
    self:LeaveLost()
    HideCard()
    local state = Blast.NewLevel(n, nil, Faction())
    self:SetLevel(state, true)
    self:Save()
    self:Queue({kind = "fade", dur = V.FADE, sound = "chime"})
    self.after = WORDS.play
end

-- Power-ups ----------------------------------------------------------------------------------------

-- A power-up on the bar: the Mallet and Free swap arm (spent when used),
-- Shuffle and +5 moves work at once. None left: one is bought first.
function game:UsePower(id)
    local P, state = Progress(), self.level
    if self.busy or self.screen ~= "level" or not (P and state) or state.outcome or self.pending or CardUp() then return end
    if self.armed == id then return self:Disarm(true) end
    self:Disarm()
    local bought
    if P:Count(id) <= 0 then
        local ok, why, price = P:Buy(id)
        if not ok then
            MG:Sound("buzz")
            if why == "coins" then MG:Note(WORDS.coins:format(price or 0)) end
            return
        end
        MG:Sound("buy")
        bought = WORDS.bought:format(P:Name(id), price or 0)
    end
    self:ClearHint()
    if id == "mallet" or id == "swap" then
        self.armed = id
        self:Select(nil)
        MG:Sound("uiClick")
        MG:Note(id == "mallet" and WORDS.malletArm or WORDS.swapArm)
    elseif id == "shuffle" then
        P:Use("shuffle")
        Blast.Shuffle(state)
        self:Queue({kind = "fade", dur = V.FADE, sound = "shuffle"})
        self:Save()
        self.after = bought or WORDS.shuffled
    elseif id == "moves" then
        P:Use("moves")
        Blast.AddMoves(state, 5)
        self:ShowMoves(state.movesLeft, true)
        MG:Sound("powerUse")
        self:Save()
        MG:Note(bought or WORDS.moreMoves)
    end
    self:PaintPower()
end
-- The armed power-up let go (said: the footer cleared too).
function game:Disarm(said)
    if not self.armed then return end
    self.armed = nil
    if said then MG:Note("") end
    self:PaintPower()
end
function game:AskHint()
    if CardUp() or not self.state or (self.screen ~= "level" and self.screen ~= "free") or self.pending then return end
    self:ShowHint(true)
end
-- The Hint button greys and counts down while the last hint's cooldown runs.
function game:PaintHintButton()
    local button = self.hintButton
    if not button then return end
    local wait = math.ceil(self:HintWait())
    if wait == self.hintCount then return end
    self.hintCount = wait
    button.label:SetText(wait > 0 and ("%ds"):format(wait) or "Hint")
    button:SetAlpha(wait > 0 and .55 or 1)
end
function game:OpenShop()
    if not MG.Shop then return end
    MG.Shop.Open("blast", function()
        if self.screen == "map" and self.map then self.map:Refresh() end
        if MG.PaintCoins then MG:PaintCoins() end
    end)
end

-- Free play's New board: the old score kept as a best when it is one.
function game:NewBoard()
    if self.screen ~= "free" then return end
    local state = self:Load()
    if self.busy then self:Done() end
    local old = state.score
    local mine, account = MG:Record("blast", old)
    Blast.Restart(state)
    local kept = MG:CharData("blast")
    Blast.Save(state, kept)
    if Progress() then Progress():FreeCoins(kept, 0) end
    self:Select(nil)
    self:ClearHint()
    self.pressed = nil
    self:PaintCells()
    self:Queue({kind = "fade", dur = V.FADE})
    self.after = (mine or account) and NOTES.best or NOTES.fresh
    MG:SetScore(0)
    MG:StopSound("drums")
    self:PaintHud(true)
    MG:Sound("chime")
    if (mine or account) and old > 0 then
        MG:Sound("record")
        OPTS.best.sub = "Score " .. old
        MG:Banner("New best!", OPTS.best)
    end
end

-- The window -----------------------------------------------------------------------------------------

function game:Update(shell, elapsed)
    elapsed = tonumber(elapsed) or 0
    if elapsed ~= elapsed or elapsed < 0 then elapsed = 0 end
    self.clock = self.clock + elapsed
    local state = self.state
    if not (state and self.cells) or self.screen == "map" then return end
    -- Free play's 10 s of Bloodlust or Heroism start once its clear shows.
    if state.mode ~= "level" and not self.lustPending and Blast.Tick(state, elapsed) then self:LustOver() end
    if self.busy then
        self:Play(elapsed)
    elseif not self.hintA and not self.pending and not state.outcome and not CardUp() then
        -- A while with no move, the last hint's cooldown over: a hint shows by itself.
        self.idle = self.idle + elapsed
        if self.idle >= Blast.HINT_AFTER and self:HintWait() == 0 then
            self.idle = 0
            self:ShowHint(false)
        end
    end
    self:PaintHintButton()
    self:PaintMeter()
    self:Shine(elapsed)
end
function game:Shown(shell, why)
    self:Load()
    self.idle = 0
    if self.resetPending then
        self.resetPending = nil
        self:ShowMap()
    elseif self.screen and (why == "switch" or (why == "flight" and self.lastPause == "combat")) then
        self:Restore()
    elseif why == "command" then
        self:ShowMap()
    else
        self:CarryOn()
    end
    self.lastPause, self.landed = nil, nil
end
-- Every hide ends a move being shown and saves what's in play.
function game:Pause(shell, why)
    self.lastPause = why
    if not self.cells then return end
    self:Settle()
    self:Keep()
    if self.free then MG:Record("blast", self.free.score) end
end
-- Landed: what's in play waits for the next flight.
function game:Land(shell)
    self:Pause(shell, "land")
    self.landed = self.screen == "free" and NOTES.landed or nil
end
-- /era reset the progress: the level in memory goes, the map shows next.
function game:ProgressReset()
    if self.busy then self:Done(true) end
    self.level, self.pending, self.win, self.started, self.armed = nil, nil, nil, false, nil
    self.boost = {}
    HideCard()
    if MG.Shop and MG.Shop.Shown("blast") then MG.Shop.Close("blast") end
    if MG:Shown("blast") then self:ShowMap() else self.resetPending = true end
end

MG:Register("blast", game)
