-- Azeroth Blast's campaign in the window (Modules/MiniGameBlastView.lua,
-- MiniGameBlastHud.lua and MiniGameBlastGame.lua) on the mock client
-- (Tools/MiniGameMock.lua): the layout and its gaps (board, HUD, power-up
-- bar, the Bloodlust / Heroism bands, cards inside the play area), the
-- pieces' plates, faces and pips, the flow (a flight carries on, a command
-- opens the map, the Switch keeps the screen, intro, Play with boosters,
-- Carry on, Start again), a move's HUD counts and checks, the boss's bar,
-- strike and defeat, the win card (stars, coins, what opened, Next walking
-- the map), the lose card (+5 moves owned first, then coins up the ladder,
-- Try again, Map), the power-up bar (counts, prices, the Mallet, Free swap,
-- Shuffle, +5 moves), sounds (no metal ones, none forbidden), saving on
-- every pause, landing and logout, another character and the other faction
-- carrying on, and Free play's coins and looks.
-- Run: fengari Tools/TestBlastCampaign.lua
local M = dofile("Tools/MiniGameMock.lua")
local equal, near = M.equal, M.near

local function Lcg(seed)
    local x = seed
    return function(low, high)
        x = (x * 1103515245 + 12345) % 2147483648
        return low + math.floor(x / 65536) % (high - low + 1)
    end
end
local MG, B, P
-- Every sound name Azeroth Blast asks for (while it shows), and each fade
-- between two colours asked for while Bloodlust or Heroism lights the board.
local asked, gradientsLit = {}, 0
local function Session(opts)
    opts = opts or {}
    opts.random = opts.random or Lcg(opts.seed or 7)
    MG = M.Session(opts)
    B, P = MG.Blast, MG.Progress
    local sound, gradient = MG.Sound, MG.Gradient
    MG.Sound = function(self, name, step)
        if MG.current == "blast" and type(name) == "string" then asked[name] = true end
        return sound(self, name, step)
    end
    MG.Gradient = function(texture, ...)
        local game = MG.games.blast
        if game and game.lit and (texture.parent == game.edge or texture == game.rim or texture.parent == game.board) then
            gradientsLit = gradientsLit + 1
        end
        return gradient(texture, ...)
    end
    return MG
end
local function Game() return MG.games.blast end
local function Shell() return M.Shell() end
local function Note() return Shell().note.text end
local function Settle() for _ = 1, 600 do if not Game().busy then return end; M.Tick(.05) end end
local function Card() return MG.Card.Frame("blast") end
local function CardUp() return MG.Card.Shown("blast") end
local function Button(label)
    local card = Card()
    for _, button in ipairs(card and card.buttons or {}) do
        if button.shown and button.label.text == label then return button end
    end
    return nil
end
local function Press(label)
    local button = Button(label)
    assert(button, "no card button " .. label .. " (card: " .. tostring(Card() and Card().title.text) .. ")")
    button:Click()
end
-- Every how-it-works card got past ("Got it"), up to the intro.
local function PastHow()
    for _ = 1, 8 do
        if CardUp() and Button("Got it") then Press("Got it") else return end
    end
end
local function Errors()
    for _, line in ipairs(M.printed) do if line:find("hit an error", 1, true) then return line end end
    return nil
end
local function Heard(id)
    for _, sound in ipairs(M.sounds) do if sound == id then return true end end
    return false
end
local function Forbidden()
    for _, sound in ipairs(M.sounds) do
        local id = tonumber(sound:match("^(%d+):"))
        if id and MG.FORBIDDEN_SOUNDS[id] then return sound end
    end
    return nil
end
-- A swap by clicks, played out.
local function Swap(a, b)
    Game().cells[a]:Click("LeftButton")
    Game().cells[b]:Click("LeftButton")
    Settle()
end
local function BotMove()
    local a, b = B.GoalHint(Game().state)
    assert(a, "a move to make")
    Swap(a, b)
end
-- The rect of a region placed by one point in the play area (x right, y down).
local function Rect(region, anchorAt)
    local point = region.points[#region.points]
    local w, h = region.w, region.h
    local x, y = point[4], -point[5]
    if anchorAt == "CENTER" or point[1] == "CENTER" then return x - w / 2, y - h / 2, x + w / 2, y + h / 2 end
    if point[1] == "TOP" then return x - w / 2, y, x + w / 2, y + h end
    return x, y, x + w, y + h
end
local function Overlap(a, b)
    return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
end

-- Layout -----------------------------------------------------------------------------------------

Session()
MG:Open("blast", "command")
do
    local game = Game()
    local V = B.VIEW
    equal(MG.CONTENT_W .. "x" .. MG.CONTENT_H .. " " .. game.holder.w .. "x" .. game.holder.h .. " " .. game.play.w .. "x" .. game.play.h,
        "412x500 412x500 412x500", "the play area: 412 x 500, the game's frames sized to it")
    equal(("%d %d %d %d %d"):format(V.CELL, V.BOARD, V.LEFT, V.TOP, V.BOTTOM), "45 360 26 78 438", "45 px cells: the board 26..386 x 78..438")
    equal(("%d %d %d %d"):format(V.PLATE, V.FACE, V.PIP, V.PLATE_RIM), "41 33 12 47", "bigger pieces: a 41 px plate (a 3 px dark rim), a 33 px face, a 12 px pip")
    local board = game.board
    local tl, br = board.points[1], board.points[2]
    equal(#board.points .. " " .. tl[1] .. " " .. br[1] .. " " .. tostring(board.sizedFirst and board.clips) .. " "
        .. ("%gx%g"):format(br[4] - tl[4], tl[5] - br[5]), "2 TOPLEFT BOTTOMRIGHT true 360x360",
        "the board clips, so it is sized first and pinned by two opposite corners")
    -- The HUD's boxes, the board, the bands and the power-up bar never touch.
    local boxes = {V.MOVES, V.GOALS, V.METER, V.BOSS_CHIP}
    local hudBottom, inside = 0, true
    for _, box in ipairs(boxes) do
        local w = box == V.GOALS and (3 * box.w + 2 * box.gap) or box.w
        hudBottom = math.max(hudBottom, box.y + box.h)
        if box.x < 0 or box.x + w > MG.CONTENT_W or box.y < 0 then inside = false end
    end
    equal(inside and hudBottom, 60, "the HUD's boxes inside the play area, down to 60")
    equal(V.MOVES.x + V.MOVES.w < V.GOALS.x and V.GOALS.x + 3 * V.GOALS.w + 2 * V.GOALS.gap < V.METER.x
        and V.BOSS_CHIP.x + V.BOSS_CHIP.w < V.METER.x, true, "moves, goals (or the boss chip) and the meter side by side, apart")
    equal(V.POWER.y .. " " .. (V.POWER.y + V.POWER.size), "458 498", "the power-up bar under the board, inside the play area")
    local boardRect = {V.LEFT, V.TOP, V.LEFT + V.BOARD, V.BOTTOM}
    local over, top, bottom, left, right = 0, 1000, 0, 1000, 0
    for _, band in ipairs(game.glows) do
        local r = {Rect(band)}
        if Overlap(r, boardRect) then over = over + 1 end
        top, bottom, left, right = math.min(top, r[2]), math.max(bottom, r[4]), math.min(left, r[1]), math.max(right, r[3])
    end
    equal(#game.glows .. " " .. over, "8 0", "eight bands of the edge glow, not one pixel over the board")
    equal(("%g %g %g %g"):format(top, bottom, left, right), "62 454 10 402", "they run 3 to 16 px outside it: clear of the HUD (60) and the bar (458)")
    local runnerOver = 0
    for step = 0, 40 do
        local x, y = MG.BlastView.RunnerAt(step * 40)
        local s = V.EDGE.runner / 2
        if Overlap({x - s, y - s, x + s, y + s}, boardRect) or y - s < hudBottom or y + s > V.POWER.y then runnerOver = runnerOver + 1 end
    end
    equal(runnerOver, 0, "the runners' path round it clears the board, the HUD and the bar")
    local gradients = 0
    for _, band in ipairs(game.glows) do if band.gradient then gradients = gradients + 1 end end
    equal(gradients .. " " .. game.glows[1].blend .. " " .. tostring(game.glows[1].shown), "0 ADD false", "flat light added, never a gradient, hidden until it runs")
    local unsized = 0
    local function Under(f, root) while f do if f == root then return true end; f = f.parent end; return false end
    for _, f in ipairs(M.frames) do
        if (f.kind == "Frame" or f.kind == "Button" or f.kind == "PlayerModel") and (Under(f, game.holder) or Under(f, game.bar))
            and not f.sizedFirst then unsized = unsized + 1 end
    end
    equal(unsized, 0, "every frame of the game sized before it's placed")
    equal(game.sky.level < game.holder.level + MG.Card.LEVEL, true, "the picked ring and flying icons under the cards")
    -- Plates far apart in colour.
    local races, close = B.RACES, 1
    for i = 1, #races do
        for j = i + 1, #races do
            local a, b = MG.BlastView.PAINT.race[races[i].id], MG.BlastView.PAINT.race[races[j].id]
            local d = math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
            close = math.min(close, d)
        end
    end
    equal(close >= .35, true, ("each race's plate at least .35 apart in colour (closest %.2f)"):format(close))
    local r, g, b = MG:Colour3("piece.nightelf.colour")
    local paint = MG.BlastView.PAINT.race.nightelf
    equal(paint[1] == r and paint[2] == g and paint[3] == b, true, "read from the assets' piece colours (one source)")
end

-- Opening: the map, a level's intro, Play ------------------------------------------------------

do
    local game = Game()
    equal(game.screen .. " | " .. Shell().where.text .. " | " .. Shell().best.text, "map | Pick a level on the map. | 0 stars",
        "/era blast: the map, its header")
    equal(game.map:IsShown() and not game.play.shown, true, "the map over the play area, the board hidden")
    equal(Note(), "Next: The shop at level 3.", "the footer: the next thing to open")
    local footer = {}
    for _, id in ipairs({"free", "shop", "hint", "map", "new"}) do if game.buttons[id].shown then footer[#footer + 1] = id end end
    equal(table.concat(footer, " "), "free", "the map's footer: Free play (the shop opens at level 3)")
    game.map.nodes[2]:Click()
    equal(game.screen .. " " .. Note(), "map Clear level 1 first.", "a locked level: says what to clear")
    game.map.nodes[1]:Click()
    equal(game.screen .. " " .. tostring(game.pending) .. " " .. Card().title.text, "level 1 Level goals",
        "level 1: its how-it-works card first, over the level's board")
    equal(game.play.shown and not game.map:IsShown(), true, "the board shows under it")
    Press("Got it")
    local card = Card()
    equal(card.title.text .. " | " .. card.sub.text .. " | " .. card.big.text, "Level 1 | Elwynn Forest | 16 moves", "then the intro: level, zone, moves")
    equal(card.lines[1].text.text, "Clear 14 humans", "its goal (a Horde player's foes)")
    equal(card.lines[1].icon.texture, "Interface\\CharacterFrame\\TemporaryPortrait-Male-Human", "with the race's face")
    equal(card.h <= MG.CONTENT_H and card.w <= MG.CONTENT_W, true, "the card inside the play area")
    equal(Note(), "Click a piece, then one next to it to swap.", "a first-time player is told how to swap")
    equal(P:Resume("blast"), nil, "nothing saved before Play")
    Press("Play")
    equal(tostring(CardUp()), "false", "Play: the card goes")
    equal(game.started and P:Resume("blast").level, 1, "the level starts, saved at once")
    Settle()
    local hud = game.hud
    equal(hud.moves.number.text .. " " .. hud.moves.label.text, "16 Moves", "the HUD: moves left")
    equal(hud.chips[1].shown and hud.chips[1].text.text, "0/14", "a goal chip: 0/14")
    equal(hud.chips[1].portrait.texture .. " " .. tostring(hud.chips[1].plate.shown), "Interface\\CharacterFrame\\TemporaryPortrait-Male-Human true",
        "a human face on its plate")
    equal(hud.chips[2].shown or hud.boss.shown or hud.free.shown, false, "one goal, no boss, not Free play")
    equal(Shell().where.text .. " | " .. Shell().best.text, "Elwynn Forest, level 1 | Best 0", "the header: where and this level's best")
    local footer2 = {}
    for _, id in ipairs({"free", "shop", "hint", "map", "new"}) do if game.buttons[id].shown then footer2[#footer2 + 1] = id end end
    equal(table.concat(footer2, " "), "hint map", "a level's footer: Hint and Map")
    -- Pieces: plates, faces, pips.
    local human
    for i, piece in ipairs(game.state.board) do if piece.kind == "human" and not human then human = i end end
    local art = game.cells[human].art
    equal(art.face.texture .. " " .. tostring(art.face.mask ~= nil) .. " " .. table.concat(art.face.coords, ","),
        "Interface\\CharacterFrame\\TemporaryPortrait-Male-Human true 0.1,0.9,0.08,0.88", "a face, cut round, cropped to the face")
    local colour = MG.BlastView.PAINT.race.human
    equal(art.plate.shown and art.plate.vertex[1] == colour[1] and art.plate.vertex[3] == colour[3] and art.plate.w, 41,
        "on a 41 px plate in its race's colour")
    equal(art.rim.vertex[1] < colour[1] * .3 and art.rim.w, 47, "a dark rim behind it, 3 px round")
    equal(art.pip.shown and table.concat(art.pip.vertex, ",", 1, 3) .. " " .. art.pip.w, "0.18,0.44,1 12", "an Alliance blue pip")
    equal(art.pipRim.shown and art.pipRim.vertex[1] > .9 and art.pipRim.w, 16, "in a pale ring, so it shows on a blue plate")
    -- The pointer over a piece lights it (the cell's own highlight sits under the piece).
    game.cells[human]:GetScript("OnEnter")(game.cells[human])
    equal(art.hover.shown and art.hover.blend, "ADD", "hover: a soft light over the piece")
    game.cells[human]:GetScript("OnLeave")(game.cells[human])
    equal(art.hover.shown, false, "gone as the pointer leaves")
    local orc
    for i, piece in ipairs(game.state.board) do if piece.kind == "orc" and not orc then orc = i end end
    equal(table.concat(game.cells[orc].art.pip.vertex, ",", 1, 3), "0.86,0.16,0.1", "a Horde red pip")
    -- Picking: a ring, the piece a little bigger, a soft click.
    M.sounds[#M.sounds + 1] = "mark"
    local start = #M.sounds
    game.cells[human]:Click("LeftButton")
    equal(game.selected .. " " .. game.cells[human].scale .. " " .. tostring(game.picker.ring.shown), human .. " 1.1 true", "a pick: ringed and bigger")
    equal(M.sounds[start + 1], "856:SFX", "a soft click, no metal")
    game.cells[human]:Click("RightButton")
    equal(tostring(game.selected) .. " " .. game.cells[human].scale, "nil 1", "a right click lets go")
    equal(Errors(), nil, "no error")
end

-- A level played to a win: HUD counts per step, checks, the win card, Next --------------------

do
    local game = Game()
    local goal = game.state.goals[1]
    goal.have = goal.need - 1
    game:PaintHud(true)
    local start = P:Coins()
    local played = 0
    while not game.state.outcome and played < 30 do
        BotMove()
        played = played + 1
    end
    equal(game.state.outcome, "won", "the goal met: won")
    equal(game.hud.chips[1].text.text .. " " .. tostring(game.hud.chips[1].check.shown), "14/14 true", "the chip full, with a check")
    equal(P:Resume("blast") == nil and P:Stars("blast", 1) > 0 and P:Level("blast"), 2, "paid for the moment it was won: stars, level 2 open, the save gone")
    M.Tick(1)
    local card = Card()
    equal(CardUp() and card.title.text, "Level 1 cleared!", "the win card")
    equal(card.sub.text:match("^%d+ moves left: %+%d+$") ~= nil, true, "the moves left's bonus (" .. card.sub.text .. ")")
    equal(card.best.text:match("^Score %d+") ~= nil, true, "the score")
    equal(card.coins.text, ("+%d coins"):format(P:Coins() - start), "the coins it paid, counted up")
    local stars = 0
    for _, star in ipairs(card.starArt) do if star.shown then stars = stars + 1 end end
    equal(stars, 3, "three stars shown (filled one by one)")
    equal(Heard("218231:SFX") or Heard("43502:SFX"), true, "a win sound")
    Press("Next")
    equal(Card().title.text, "Stars", "Next: what opened is explained first (the stars card)")
    Press("Got it")
    equal(game.screen, "map", "then the map")
    M.Tick(3)
    equal(game.screen .. " " .. tostring(game.pending) .. " " .. Card().title.text, "level 2 Level 2", "the glow walks there, then level 2's intro")
    equal(Heard("1209:SFX") or Heard("44319:SFX"), true, "with steps along the path")
    Press("Map")
    equal(game.screen .. " " .. tostring(P:Resume("blast")), "map nil", "Map from the intro: back, nothing saved")
    equal(game.map.nodes[1].stars[1].shown and game.map.nodes[2].state, "open", "level 1 done (its stars under it), level 2 open")
end

-- Boosters on the intro, Carry on, Start again --------------------------------------------------

do
    local game = Game()
    P:Unlock("charge")
    P:Unlock("lust")
    P:Give("charge", 1)
    P:AddCoins(200)
    game.map.nodes[2]:Click()
    PastHow()
    local card = Card()
    local toggles = {}
    for _, toggle in ipairs(card.toggles) do if toggle.shown then toggles[#toggles + 1] = toggle end end
    equal(#toggles, 2, "the intro offers the boosters opened: Charge and Bloodlust")
    equal(toggles[1].count.text .. " | " .. toggles[2].price.text, "1 | 70", "one Charge owned; Bloodlust shows its price")
    toggles[1]:Click()
    toggles[2]:Click()
    equal(tostring(game.boost.charge) .. " " .. tostring(game.boost.lust) .. " " .. P:Count("lust"), "true true 1",
        "clicked: the Charge on, a Bloodlust bought and on")
    local coins = P:Coins()
    Press("Play")
    equal(P:Count("charge") .. " " .. P:Count("lust") .. " " .. P:Coins(), "0 0 " .. coins, "Play uses them")
    local charges = 0
    for _, piece in ipairs(game.state.board) do if piece.special == "charge" then charges = charges + 1 end end
    equal(charges .. " " .. game.state.lust, "1 3", "the level starts with a Charge and Bloodlust for 3 moves")
    M.Tick(1)
    equal(game.lit and game.glows[1].shown and game.runners[1].shown, true, "Bloodlust lights the edge glow")
    equal(table.concat(game.rimColour, ","), table.concat({game.rim.colour[1], game.rim.colour[2], game.rim.colour[3]}, ","),
        "the rim keeps its metal")
    local x1, y1 = game.runners[1].lastPoint[4], game.runners[1].lastPoint[5]
    M.Tick(.2)
    equal(x1 ~= game.runners[1].lastPoint[4] or y1 ~= game.runners[1].lastPoint[5], true, "the runners move round it")
    equal(game.meter.label.text .. " " .. tostring(game.meter.icon.desaturated), "3 moves false", "the meter: 3 moves, lit")
    for _ = 1, 3 do if not game.state.outcome then BotMove() end end
    equal(game.state.lust .. " " .. tostring(game.glows[1].shown or game.runners[1].shown), "0 false", "3 moves on: over, the glow gone")
    -- Map keeps it; its node says Carry on; Carry on goes back in.
    local moves = game.state.movesLeft
    game.buttons.map:Click()
    equal(game.screen .. " " .. P:Resume("blast").level .. " " .. tostring(game.map.nodes[2].carry.shown), "map 2 true",
        "Map mid-level: kept, its node says Carry on")
    game.map.nodes[2]:Click()
    equal(Card().title.text .. " | " .. tostring(Button("Carry on") ~= nil) .. " " .. tostring(Button("Start again") ~= nil),
        "Level 2 | true true", "its intro: Carry on or Start again")
    equal(Card().w, 320, "a wider card, so its three buttons have room")
    Press("Carry on")
    equal(game.screen .. " " .. game.state.movesLeft .. " " .. Note(), "level " .. moves .. " Carrying on with level 2.", "Carry on: as it was")
    game.buttons.map:Click()
    game.map.nodes[2]:Click()
    Press("Start again")
    equal(game.state.movesLeft .. " " .. P:Resume("blast").movesLeft, game.state.spec.moves .. " " .. game.state.spec.moves,
        "Start again: a fresh board, saved")
    equal(Errors(), nil, "no error")
end

-- The lose card: owned +5 first, then coins up the ladder; Try again; Map -------------------------

do
    local game = Game()
    P:Unlock("moves")
    P:Give("moves", 1)
    game.state.movesLeft = 1
    BotMove()
    if game.state.outcome ~= "lost" then
        game.state.movesLeft = 1
        BotMove()
    end
    equal(game.state.outcome, "lost", "out of moves: lost")
    M.Tick(.5)
    equal(Card().title.text .. " | " .. Button("+5 moves").sub.text, "Out of moves | 1 left", "the lose card: +5 moves, one owned")
    equal(Card().lines[1].progress.text:match("^%d+/%d+$") ~= nil, true, "how close each goal got")
    equal(P:Resume("blast").outcome, "lost", "saved lost: the next flight brings the card back")
    Press("+5 moves")
    equal(game.state.movesLeft .. " " .. tostring(game.state.outcome) .. " " .. P:Count("moves") .. " " .. tostring(CardUp()), "5 nil 0 false",
        "the owned one used: 5 more moves, playing again")
    game.state.movesLeft = 1
    repeat BotMove() until game.state.outcome
    if game.state.outcome == "lost" then
        M.Tick(.5)
        local coins = P:Coins()
        equal(Button("+5 moves").sub.text, ("%d coins"):format(P:Price("moves", 1)), "none owned: the ladder's next price (" .. P:Price("moves", 1) .. ")")
        Press("+5 moves")
        equal(P:Coins() .. " " .. game.state.movesLeft, (coins - P:Price("moves", 1)) .. " 5", "bought with coins")
        game.state.movesLeft = 1
        repeat BotMove() until game.state.outcome
    end
    if game.state.outcome == "lost" then
        M.Tick(.5)
        local tries = P:Data().blast.tries
        Press("Try again")
        equal(game.state.movesLeft .. " " .. tostring(game.state.outcome) .. " " .. P:Data().blast.tries,
            game.state.spec.moves .. " nil " .. (tries + 1), "Try again: the level from its start, the lost try counted")
        game.state.movesLeft = 1
        repeat BotMove() until game.state.outcome
        if game.state.outcome == "lost" then
            M.Tick(.5)
            Press("Map")
            equal(game.screen .. " " .. tostring(P:Resume("blast")), "map nil", "Map from the lose card: let go")
        end
    end
    equal(Errors(), nil, "no error")
end

-- The power-up bar --------------------------------------------------------------------------------

Session({seed = 11})
P:Data().blast.level = 12
for _, id in ipairs({"mallet", "shuffle", "moves", "swap"}) do P:Unlock(id) end
P:Give("mallet", 1)
P:AddCoins(300)
MG:Open("blast", "command")
do
    local game = Game()
    game.map:Show(2)
    game.map.nodes[2]:Click()  -- level 12
    PastHow()
    Press("Play")
    Settle()
    local bar = game.power
    local shown = {}
    for _, button in ipairs(bar.buttons) do if button.shown then shown[#shown + 1] = button end end
    equal(#shown .. " " .. shown[1].id .. " " .. shown[1].count.text .. " " .. tostring(shown[1].badge.shown), "4 mallet 1 true",
        "four power-ups: the Mallet with its count")
    local shuffle = bar.buttons[2]
    equal(shuffle.count.text .. " " .. tostring(shuffle.tag.shown) .. " " .. shuffle.price.text, " true 30", "none owned: a price tag")
    local first = {Rect(shown[1])}
    local last = {Rect(shown[4])}
    equal(math.abs(first[1] - (MG.CONTENT_W - last[3])) < 1 and shown[1].w, 40, "centred, 40 px each")
    -- The Mallet: armed, cancelled, armed, smashing a piece.
    shown[1]:Click("LeftButton")
    equal(game.armed .. " | " .. Note() .. " | " .. tostring(shown[1].glow.shown), "mallet | Click a piece or blocker to smash it. Right-click to cancel. | true",
        "the Mallet armed: a glow, the footer says how")
    game.cells[30]:Click("RightButton")
    equal(tostring(game.armed) .. " " .. P:Count("mallet"), "nil 1", "a right click cancels, nothing spent")
    shown[1]:Click("LeftButton")
    local moves = game.state.movesLeft
    local before = game.state.board[30]
    game.cells[30]:Click("LeftButton")
    equal(game.busy and bar.buttons[1].alpha, .4, "it smashes: the bar dims while it plays")
    Settle()
    equal(P:Count("mallet") .. " " .. game.state.movesLeft .. " " .. tostring(game.state.board[30] ~= before), "0 " .. moves .. " true",
        "a Mallet spent, no move used, the piece gone")
    equal(bar.buttons[1].alpha .. " " .. tostring(bar.buttons[1].tag.shown) .. " " .. bar.buttons[1].price.text, "1 true 40", "none left: its price")
    -- Shuffle bought and used at once.
    local coins = P:Coins()
    M.sounds[#M.sounds + 1] = "mark"
    shuffle:Click("LeftButton")
    equal(P:Coins() .. " " .. P:Count("shuffle") .. " " .. tostring(game.busy), (coins - 30) .. " 0 true", "Shuffle: bought for 30 and used")
    Settle()
    equal(Note(), "Bought Shuffle for 30 coins.", "the footer says so")
    equal(Heard("218228:SFX") or Heard("287276:SFX"), true, "a buy sound")
    -- Free swap: two pieces that match nothing swap anyway, no move used.
    local swap = bar.buttons[3]
    swap:Click("LeftButton")
    equal(game.armed .. " " .. Note(), "swap Swap any two pieces side by side.", "Free swap armed")
    local a, b
    for i = 1, 63 do
        local j = i + 1
        if j % 8 ~= 1 and game.state.board[i] and game.state.board[j] and not B.Locked(game.state.board[i]) and not B.Locked(game.state.board[j])
            and B.MoveValue(game.state.board, i, j) == nil then a, b = i, j; break end
    end
    moves = game.state.movesLeft
    local pa, pb = game.state.board[a], game.state.board[b]
    Swap(a, b)
    equal(game.state.movesLeft .. " " .. tostring(game.armed) .. " " .. P:Count("swap"), moves .. " nil 0", "swapped with no match, no move used, spent")
    equal(game.state.board[b] == pa and game.state.board[a] == pb, true, "the pieces swapped places")
    -- +5 moves at once.
    bar.buttons[4]:Click("LeftButton")
    Settle()
    equal(game.state.movesLeft, moves + 5, "+5 moves: five more at once")
    equal(game.hud.moves.number.text, tostring(moves + 5), "the HUD shows it")
    equal(Errors(), nil, "no error")
    -- A locked piece clicked: a buzz, the footer says why.
    local frozen
    for i, piece in ipairs(game.state.board) do if piece.ice then frozen = i end end
    if frozen then
        game.cells[frozen]:Click("LeftButton")
        equal(Note() .. " " .. tostring(game.selected), "Frozen pieces can't move. Match next to them. nil", "a frozen piece won't pick")
    end
end

-- Blockers drawn, hits shown ------------------------------------------------------------------------

Session({seed = 3})
P:Data().blast.level = 40
MG:Open("blast", "command")
do
    local game = Game()
    game.map:Show(2)
    game.map.nodes[9]:Click() -- level 19: ice and crates
    PastHow()
    Press("Play")
    Settle()
    local state = game.state
    local seen = {}
    for i, piece in ipairs(state.board) do
        local art = game.cells[i].art
        if piece.ice and art.ice.shown then seen.ice = true end
        if piece.block == "crate" and art.block.shown and not art.plate.shown then seen.crate = true end
        if piece.block == "crate" and piece.hits == 3 and art.count.text == "3" then seen.three = true end
    end
    equal(tostring(seen.ice) .. " " .. tostring(seen.crate) .. " " .. tostring(seen.three), "true true true",
        "level 19: ice over pieces, crates in their place (a 3 on the strongest)")
    equal(game.hud.chips[1].shown and game.hud.chips[2].shown, true, "two goal chips: ice and crates")
    -- A move that cracks ice or breaks a crate: its bits fly, its sound once.
    local played = 0
    M.sounds = M.sounds
    local hitHeard = false
    while played < 12 and not hitHeard and not state.outcome do
        BotMove()
        played = played + 1
        hitHeard = Heard("164634:SFX") or Heard("42782:SFX") or Heard("37904:SFX") or Heard("4783:SFX")
    end
    equal(hitHeard, true, "ice cracking or a crate breaking is heard")
    -- Oil and holes: level 27.
    game.buttons.map:Click()
    game.map:Show(3)
    game.map.nodes[7]:Click()
    PastHow()
    Press("Play")
    Settle()
    local holes, tiles, oil = 0, 0, 0
    for i, cell in ipairs(game.cells) do
        if B.Hole(game.state, i) then
            holes = holes + 1
            if cell.tile.shown or cell.art.shown then tiles = tiles + 1 end
        end
        if (game.oil[i] or 0) > 0 and cell.oil.shown then oil = oil + 1 end
    end
    equal(holes > 0 and tiles, 0, "a hole: no tile, no piece")
    equal(oil, 12, "oil under 12 cells (dark where it's 2 layers)")
    -- Oil cleaned shows as the clear that cleans it plays, not only at the end.
    local cleaned = false
    for _ = 1, 6 do
        if cleaned or game.state.outcome then break end
        local before = {}
        for i = 1, 64 do before[i] = game.oil[i] or 0 end
        local a, b = B.GoalHint(game.state)
        game.cells[a]:Click("LeftButton")
        game.cells[b]:Click("LeftButton")
        M.Tick(.2)
        for i = 1, 64 do if game.busy and (game.oil[i] or 0) < before[i] and game.cells[i].oil.shown == ((game.oil[i] or 0) > 0) then cleaned = true end end
        Settle()
    end
    equal(cleaned, true, "oil cleaned mid-move: it goes as its clear pops")
    -- Relics and exits: level 23.
    game.buttons.map:Click()
    game.map:Show(3)
    game.map.nodes[3]:Click()
    PastHow()
    Press("Play")
    Settle()
    local arrows = {}
    for c, arrow in ipairs(game.exits) do if arrow.shown then arrows[#arrows + 1] = c end end
    equal(table.concat(arrows, ","), "4,5", "level 23: arrows under its exits")
    local relic
    for i, piece in ipairs(game.state.board) do if piece.block == "relic" then relic = i end end
    equal(relic and game.cells[relic].art.block.shown and game.cells[relic].art.relicGlow.shown, true, "a relic on its gold glow")
    equal(game.hud.chips[1].goal.id, "relic", "a relic goal chip")
    equal(Errors(), nil, "no error")
end

-- The boss ---------------------------------------------------------------------------------------

Session({seed = 5})
P:Data().blast.level = 10
MG:Open("blast", "command")
do
    local game = Game()
    game.map.nodes[10]:Click()
    PastHow()
    equal(Card().title.text .. " | " .. Card().sub.text, "Level 10 | Elwynn Forest, boss fight", "a boss level's intro")
    local lines = {}
    for _, line in ipairs(Card().lines) do if line.shown then lines[#lines + 1] = line.text.text end end
    equal(table.concat(lines, " | "), "Defeat Hogger | Strikes back every 4 moves", "its goal and how often he strikes")
    Press("Play")
    Settle()
    local chip = game.hud.boss
    equal(chip.shown and chip.name.text .. " | " .. chip.hp.text .. " | " .. chip.timer.text .. " | " .. chip.next.text,
        "Hogger | 1250 / 1250 | 4 | Strikes in 4 moves", "the boss chip: name, health, countdown")
    equal(chip.portrait.shown and chip.portrait.texture ~= nil and chip.fill.w, chip.barW, "his portrait and a full bar")
    equal(game.hud.chips[1].shown, false, "no goal chips beside him")
    -- A hit: the bar drains, the damage floats up red.
    local floats = 0
    local real = MG.FloatText
    MG.FloatText = function(self, at, text, opts) if at == chip.face and text:match("^%-%d+$") then floats = floats + 1 end; return real(self, at, text, opts) end
    BotMove()
    MG.FloatText = real
    equal(game.state.boss.hp < game.state.boss.max and floats >= 1, true, "a hit: damage floats from his portrait")
    equal(chip.hp.text, ("%d / %d"):format(game.state.boss.hp, game.state.boss.max), "the bar shows his health")
    -- He strikes: the timer at 1, a move later his mess is on the board.
    game.state.boss.timer = 1
    game:PaintHud(true)
    equal(chip.timer.text .. " " .. chip.next.text .. " " .. table.concat(chip.timer.textColour, ",", 1, 3), "1 Strikes next move 1,0.35,0.3",
        "about to strike: the countdown red")
    BotMove()
    local mess = 0
    for i = 1, 64 do
        local cell = game.state.cells[i]
        if cell and (cell.bossOil or 0) > 0 and game.cells[i].oil.shown then mess = mess + 1 end
    end
    equal(mess > 0 or game.state.outcome ~= nil, true, "he spilt oil: drawn under the pieces")
    equal(Note():find("Hogger spills oil.", 1, true) ~= nil or game.state.outcome ~= nil, true, "the footer says what he did")
    equal(chip.half.shown or not B.Shielded(game.state), true, "his mess up: Half damage shown")
    -- Saved mid-fight: the next flight (a /reload later) brings him back as he was.
    if not game.state.outcome then
        local hp, timer, max = game.state.boss.hp, game.state.boss.timer, game.state.boss.max
        local oil = 0
        for i = 1, 64 do if (game.oil[i] or 0) > 0 then oil = oil + 1 end end
        MG:Close("hand")
        Session({db = EraUIDB, seed = 6})
        MG:Open("blast", "flight")
        game = Game()
        chip = game.hud.boss
        local shownOil = 0
        for i = 1, 64 do if game.cells[i].oil.shown then shownOil = shownOil + 1 end end
        equal(game.screen .. " | " .. chip.hp.text .. " | " .. chip.timer.text .. " | " .. shownOil,
            ("level | %d / %d | %d | %d"):format(hp, max, timer, oil), "carried on mid-fight: his health, his countdown and his oil as they were")
        equal(math.abs(chip.fill.w - chip.barW * hp / max) < .01, true, "his bar as full as his health")
    end
    -- Down: his portrait pops away, a banner, then the win card.
    local played = 0
    while not game.state.outcome and played < 60 do
        BotMove()
        played = played + 1
    end
    equal(game.state.outcome, "won", "Hogger beaten")
    local banner = MG.FX.banner
    equal(banner and banner.shown and banner.text.text, "Hogger is down!", "a banner: he is down")
    M.Tick(2)
    equal(Card().title.text .. " " .. P:Level("blast"), "Level 10 cleared! 11", "then the win card, level 11 open")
    local news = {}
    for _, line in ipairs(Card().lines) do if line.shown then news[#news + 1] = line.text.text end end
    equal(table.concat(news, " | "), "New: Durotar | New: Elwynn Forest board", "what opened: the next zone and a board look")
    equal(Forbidden(), nil, "no blacksmith or metal sound in a whole level")
    equal(Errors(), nil, "no error")
end

-- Flights, switching, landing, logout, another character, the other faction -------------------

Session({seed = 9, db = {miniGameFlight = "blast"}})
do
    M.TakeOff(3)
    local game = Game()
    equal(M.Showing() and game.screen .. " " .. Card().title.text, "level Level goals", "a first flight: level 1, its how-it-works card")
    PastHow()
    equal(Card().title.text, "Level 1", "then its intro")
    Press("Play")
    Settle()
    BotMove()
    local left, score = game.state.movesLeft, game.state.score
    MG:Open("whack", "switch")
    equal(P:Resume("blast").movesLeft, left, "switched away: saved")
    MG:Open("blast", "switch")
    equal(game.screen .. " " .. game.state.movesLeft, "level " .. left, "and back: the same level, as it was")
    M.Land()
    equal(M.Showing(), false, "landing closes it")
    equal(P:Resume("blast").movesLeft .. " " .. P:Resume("blast").score, left .. " " .. score, "the level saved for the next flight")
    M.TakeOff()
    equal(game.screen .. " " .. game.state.movesLeft .. " | " .. Note(), "level " .. left .. " | Carrying on with level 1.",
        "the next flight: straight back in")
    MG:Open("blast", "command")
    equal(game.screen, "map", "/era blast: the map")
    MG:Open("whack", "switch")
    MG:Open("blast", "switch")
    equal(game.screen, "map", "the Switch keeps the screen")
    M.Fire("PLAYER_LOGOUT")
    equal(P:Resume("blast").level, 1, "logging out keeps it")
    -- Another character on the account (the Alliance): the same level, its foes flipped.
    local db = EraUIDB
    local saved = P:Resume("blast")
    Session({db = db, faction = "Alliance", seed = 4})
    MG:Open("blast", "flight")
    game = Game()
    equal(game.screen .. " " .. game.state.level .. " " .. game.state.movesLeft, "level 1 " .. saved.movesLeft, "another character carries on")
    equal(game.state.goals[1].race .. " " .. B.GoalText(game.state.goals[1], "Alliance"), "orc Clear 14 orcs", "an Alliance player's foes: orcs")
    local cells = 0
    for i = 1, 64 do if game.cells[i].piece == game.state.board[i] then cells = cells + 1 end end
    equal(cells .. " " .. game.hud.moves.number.text .. " " .. game.hud.chips[1].text.text,
        "64 " .. saved.movesLeft .. " " .. saved.goals[1] .. "/14", "every piece drawn, the HUD as saved")
    equal(Errors(), nil, "no error")
end
-- A damaged save: let go, the level's intro instead.
Session({db = {miniGameResume = {version = 1, blast = {v = 1, mode = "level", level = 3, board = "frog"}}}})
MG:Open("blast", "flight")
equal(Game().screen .. " " .. tostring(P:Resume("blast")) .. " " .. Card().title.text, "level nil Level goals", "a damaged save: dropped, the intro instead")
-- Free play last: a flight opens it.
Session({db = {miniGameFlight = "blast"}})
MG:Open("blast", "command")
Game().buttons.free:Click()
equal(Game().screen .. " " .. P:Last("blast"), "free free", "Free play from the map: remembered")
MG:Close("hand")
M.TakeOff()
equal(Game().screen, "free", "a flight opens Free play when it was last")

-- Free play: coins per 1,000, its looks ---------------------------------------------------------

do
    local game = Game()
    equal(game.hud.free.shown and game.hud.moves.number.text .. " " .. game.hud.free.title.text, "Free Free play", "the HUD: Free play")
    equal(game.power.shown or game.hud.boss.shown or game.hud.chips[1].shown, false, "no power-ups, boss or goals")
    equal(game.hud.free.look.shown, false, "no Look button until a look opens")
    local coins = P:Coins()
    game.state.score = 990
    local a, b = B.FindMove(game.state.board)
    Swap(a, b)
    equal(P:Coins() - coins >= 1 and MG:CharData("blast").coined, 1, "passing 1,000 points: a coin")
    P:Unlock("look:elwynn")
    game:PaintHud(true)
    equal(game.hud.free.look.shown, true, "a look opened: the Look button")
    game.hud.free.look:Click()
    equal(P:Look() .. " " .. game.look .. " | " .. Note(), "elwynn elwynn | Board: Elwynn Forest.", "Look: Elwynn Forest's ground")
    equal(game.cells[1].tile.texture == 187126 or game.cells[1].tile.texture == 187113, true, "the tiles in its art")
    game.hud.free.look:Click()
    equal(P:Look() .. " " .. game.cells[1].tile.texture, "stone Interface\\Garrison\\ClassHallBackground", "and round again to stone")
    equal(Errors(), nil, "no error")
end

-- Reset from /era: the map next time ------------------------------------------------------------

Session()
MG:Open("blast", "command")
Game().map.nodes[1]:Click()
PastHow()
Press("Play")
Settle()
P:Reset()
equal(Game().screen .. " " .. tostring(Game().level) .. " " .. tostring(CardUp()), "map nil false", "Reset while shown: the map, the level gone")

-- After a win: the map first; a card for what opened stays over a Switch and a fight ---------------

local function AtLevel3(flight)
    Session({seed = 5, db = {miniGameFlight = flight and "blast" or "off", miniGameProgress = {version = 1, stamp = 5, coins = 0, earned = 0,
        powers = {}, unlocked = {}, cards = {goals = true, stars = true}, gifts = {},
        blast = {level = 3, stars = "22", best = {}, last = "level", look = "stone", tries = 2, wins = 2},
        whack = {stage = 1, stars = "", best = {}, last = "stage", mallet = "wood", tries = 0, wins = 0}}}})
    if flight then M.TakeOff(); M.Tick(.1) else MG:Open("blast", "command") end
    local game = Game()
    game:Intro(3)
    Press("Play")
    Settle()
    for _, goal in ipairs(game.state.goals) do goal.have = goal.need end
    BotMove()
    equal(game.state.outcome .. " " .. Card().title.text, "won Level 3 cleared!", "level 3 won")
    return game
end
do
    local game = AtLevel3(false)
    Press("Next")
    equal(game.screen .. " " .. tostring(CardUp()) .. " " .. Card().title.text, "map true The shop", "Next: the map, the shop's card over it")
    MG:Switch()
    MG:Switch()
    equal(MG.current .. " " .. game.screen .. " " .. tostring(CardUp()) .. " " .. P:Last("blast"), "blast map true level",
        "a Switch away and back: the map and its card as they were, Free play not picked")
    Press("Got it")
    equal(Card().title.text, "Mallet", "then the Mallet's card")
    Press("Got it")
    equal(tostring(game.map.walking) .. " " .. tostring(P:Seen("shop") and P:Seen("mallet")), "true true", "both seen, the glow walks")
    for _ = 1, 100 do if CardUp() then break end; M.Tick(.05) end
    equal(Card().title.text, "Oil", "and level 4's oil card follows")
    PastHow()
    equal(Card().title.text, "Level 4", "then its intro")
end
do
    local game = AtLevel3(true)
    Press("Map")
    equal(game.screen .. " " .. tostring(CardUp()) .. " " .. Card().title.text, "map true The shop", "Map on the win card: the map, the card over it")
    M.world.combat = true; M.Fire("PLAYER_REGEN_DISABLED")
    equal(M.Showing(), false, "a fight hides the window")
    M.world.combat = false; M.Fire("PLAYER_REGEN_ENABLED")
    equal(tostring(M.Showing()) .. " " .. game.screen .. " " .. tostring(CardUp()) .. " " .. P:Last("blast"), "true map true level",
        "the fight over: the map and its card back, Free play not picked")
    Press("Got it")
    Press("Got it")
    equal(tostring(P:Seen("shop") and P:Seen("mallet")) .. " " .. game.screen, "true map", "both cards seen")
end
-- A card missed (the window closed before its Got it) comes before the next intro.
do
    local game = AtLevel3(false)
    Press("Next")
    MG:Close("hand")
    MG:Open("blast", "command")
    game:Intro(4)
    equal(Card().title.text, "The shop", "the shop's card first")
    Press("Got it")
    equal(Card().title.text, "Mallet", "then the Mallet's")
    Press("Got it")
    equal(Card().title.text, "Oil", "then level 4's own")
end

-- An enemy goal shows the other side's crest; the idle hint is only a match ------------------------

do
    Session({seed = 9, db = {miniGameProgress = {version = 1, stamp = 5, coins = 0, earned = 0, powers = {}, unlocked = {},
        cards = {goals = true, stars = true, oil = true, holes = true}, gifts = {}, blast = {level = 8, stars = ("2"):rep(7), best = {}, last = "level",
        look = "stone", tries = 7, wins = 7}, whack = {stage = 1, stars = "", best = {}, last = "stage", mallet = "wood", tries = 0, wins = 0}}}})
    MG:Open("blast", "command")
    local game = Game()
    game:Intro(8)
    PastHow()
    equal(Card().lines[1].text.text .. " " .. tostring(Card().lines[1].icon.texture), "Clear 50 Alliance pieces 463450",
        "an enemy goal on the intro: the Alliance crest, not one race's face")
    Press("Play")
    Settle()
    local chip = game.hud.chips[1]
    equal(chip.icon.shown and chip.icon.texture .. " " .. tostring(chip.plate.shown), "463450 false", "and on its HUD chip, no red or blue dot")
    -- The goal hint made to name another pair, so the two hints can't agree by chance.
    local ia, ib = B.Hint(game.state.board)
    local goalHint = B.GoalHint
    local oa, ob = ia == 1 and 63 or 1, ia == 1 and 64 or 2
    B.GoalHint = function() return oa, ob end
    for _ = 1, 320 do if game.hintA then break end; M.Tick(.05) end
    equal(game.hintA .. " " .. game.hintB, ia .. " " .. ib, "a hint shows by itself after a while: only the biggest match")
    game:ClearHint()
    game.buttons.hint:Click()
    equal(game.hintA, nil, "the Hint button waits out the cooldown in a level too")
    game.hintReady = nil
    game.buttons.hint:Click()
    equal(game.hintA .. " " .. game.hintB, oa .. " " .. ob, "the Hint button: the best move for the goals")
    B.GoalHint = goalHint
end

-- The boss going down cut short: the win card waits quietly -----------------------------------------

do
    Session({seed = 3, db = {miniGameProgress = {version = 1, stamp = 5, coins = 0, earned = 0, powers = {}, unlocked = {},
        cards = {goals = true, stars = true, boss = true}, gifts = {}, blast = {level = 10, stars = ("2"):rep(9), best = {}, last = "level",
        look = "stone", tries = 9, wins = 9}, whack = {stage = 1, stars = "", best = {}, last = "stage", mallet = "wood", tries = 0, wins = 0}}}})
    MG:Open("blast", "command")
    local game = Game()
    game:Intro(10)
    PastHow()
    Press("Play")
    Settle()
    game.state.boss.hp = 1
    local a, b = B.GoalHint(game.state)
    game.cells[a]:Click("LeftButton")
    game.cells[b]:Click("LeftButton")
    for _ = 1, 600 do if game.win and game.win.shown then break end; M.Tick(.05) end
    equal(game.state.outcome .. " " .. tostring(game.win and game.win.shown) .. " " .. tostring(CardUp()), "won true false", "the boss going down, no card yet")
    local heard = {}
    local sound = MG.Sound
    MG.Sound = function(self, name, step) heard[#heard + 1] = tostring(name); return sound(self, name, step) end
    MG:Close("hand")
    MG.Sound = sound
    equal(table.concat(heard, ","), "", "the window closed: no fanfare, no coins after it")
    equal(tostring(CardUp()) .. " " .. Card().title.text, "true Level 10 cleared!", "the win card waits for the next open")
end

-- An old Free play board: its points so far count as paid ------------------------------------------

do
    Session()
    MG:Open("blast", "command")
    Game():ShowFree()
    local kept = {}
    for key, value in pairs(MG:CharData("blast")) do kept[key] = value end
    kept.coined, kept.score = nil, 30000
    Session({char = {miniGames = {games = {blast = kept}}}})
    MG:Open("blast", "command")
    local game = Game()
    game:ShowFree()
    equal(game.state.score .. " " .. tostring(MG:CharData("blast").coined), "30000 30", "kept from before coins: 30,000 points already paid")
    local coins = P:Coins()
    BotMove()
    equal(P:Coins() - coins <= 1, true, "a move pays only for the points it made")
end

-- Every sound asked for above by its new name; no fade drawn while the board is lit ---------------

do
    local old = {}
    for _, word in ipairs({"gems", "gemsDown", "clink", "tink", "hit", "hitBig", "swing", "swingBig", "swap", "start", "bonk", "coinBig"}) do
        if asked[word] then old[#old + 1] = word end
    end
    equal(table.concat(old, ","), "", "Azeroth Blast asked for no old sound name (no clinks or clangs)")
    equal(asked.pop and asked.uiClick and asked.whoosh and asked.win and asked.lose and asked.bossHit == nil and asked["bossHit.elwynn"]
        and asked["bossRoar.elwynn"] and asked["bossDown.elwynn"] and asked.buy and asked.powerUse and asked.shuffle and true, true,
        "it asked for the soft sounds by role: pops, clicks, whooshes, win and lose, the boss's own, buy, power-ups, shuffle")
    equal(gradientsLit, 0, "no fade between colours on the edge glow, the rim or the board while Bloodlust or Heroism runs")
end

print("Blast campaign checks passed: " .. M.checks .. " assertions.")
