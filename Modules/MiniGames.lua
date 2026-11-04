local _, EraUI = ...

-- Mini-games (/era > Screen & Cursor > Mini-games; experimental). Small games
-- in a window of EraUI's own: Whack (Modules/MiniGameWhack.lua) and Azeroth
-- Blast (Modules/MiniGameBlast.lua). Nothing opens by itself unless "On a
-- Flight Path" names a game (off by default): then that game opens as you
-- take off on a flight path and closes when you land, its best scores kept.
-- Never in a fight: a fight hides the window and pauses the game, and a
-- flight's game comes back once the fight is over if you're still flying.
-- Closing it by hand during a flight keeps it closed for that flight. The
-- Switch button in the footer swaps to the other game in the same window
-- (the one showing pauses); every game played on a flight is told as you land
-- (game:Land), and keeps its level or stage for the next flight.
--
-- This file is what the games share: the settings they read, the saved best
-- scores and window position, the flight trigger, combat hiding, the
-- /era whack and /era blast words (Core/Commands.lua calls MiniGames:Toggle)
-- and the window shell. Each game's rules (its board or timing and its
-- scoring) are plain Lua functions with no frames, kept apart from its view,
-- so Tools/TestMiniGames.lua plays them without the client.
--
-- Plugging a game in (as Whack and Azeroth Blast do): a file loaded after this one in
-- EraUI.toc calls EraUI.MiniGames:Register(id, game). "whack" and "blast" are
-- the ids /era already offers (MiniGames.ORDER: the flight choice's buttons
-- after Off, the two Play rows and the slash words), so a game registered as
-- "blast" needs nothing more in /era or Core/Commands.lua. A game may have:
--   game:Title()      -> prefix, accent: the header reads prefix .. accent,
--                        the accent word in your class colour ("Whack-a-", "Gnome")
--   game:Icon()       -> its icon in the header and on the other game's Switch
--                        button (a texture path or file ID); else MiniGames.ICONS[id]
--   game:Hint()       -> the line under the title while you're not flying
--   game:Build(shell, holder, bar)  once, the first time it opens: its frames
--                        go in holder (CONTENT_W x CONTENT_H, the framed play
--                        area under the header) and bar (BAR_W x BAR_H, the
--                        right of the footer; the Switch button is on its left
--                        and MiniGames:Note writes on the line above it), both
--                        sized and shown only while this game is the one shown
--                        (should it error, that game stays closed until a /reload)
--   game:Shown(shell, why) each time the window shows it. why as MiniGames:Open
--                        was given it ("flight", "command" or "switch"; also
--                        in MiniGames.openWhy): a flight carries on where you
--                        left off, a command opens the level map, a switch
--                        shows what it showed last
--   game:Update(shell, elapsed)  every frame while the window shows (the
--                        window's OnUpdate, set only while it is shown)
--   game:Pause(shell, why)  the window hid it: "hand" (its X or Escape),
--                        "combat", "switch" (the other game opened), "hidden"
--                        (the whole interface hidden), "land", "error". Save
--                        what's running here (MiniGames.Progress:SaveResume)
--   game:Land(shell)  the flight it was played on has landed: keep what's
--                        running for the next flight (or finish it) before
--                        the window closes
--   game:Keep()       save now: the core calls it for every built game as you
--                        log out (PLAYER_LOGOUT, heard once the window exists)
--   game:Score()      -> the score the header shows
--   game:HeaderBest() -> the header's best line ("Best N" without it)
--   game:Command(words) -> handled: "/era whack <words>" and "/era blast
--                        <words>" (MiniGames:Command; unhandled words are
--                        said to be unknown)
--   game:ProgressReset()  /era reset the games' progress: drop any level in
--                        memory and show the map next time
-- And use: MiniGames:Record(id, score) (best scores, this character's and the
-- account's), MiniGames:Best(id), MiniGames:SetScore(n, now) (the header
-- counts up to n; now: at once), MiniGames:Note(text) (the line above the
-- footer), MiniGames.Button(parent, label, width, height, icon) and
-- MiniGames.Text(parent, text, size, muted, outline) (EraUI's look), MiniGames:CharData(id)
-- (a table of the game's own, kept per character, for a board to keep
-- between flights), MiniGames.Faction() and MiniGames.Random(low, high)
-- (math.random; the tests swap it), MiniGames:PaintCoins() (the header's coin
-- purse; MiniGames.Progress calls it on every coin change).
--
-- The helpers loaded after this file and the effects kit (each says how to
-- use it at its top): Modules/MiniGameAssets.lua (art and sounds by role:
-- MiniGames:Art, :Model, :Tune), Modules/MiniGameProgress.lua (the saved
-- progress both games share: MiniGames.Progress), Modules/MiniGameMap.lua
-- (the level map, MiniGames.Map), Modules/MiniGameCards.lua (MiniGames.Card)
-- and Modules/MiniGameShop.lua (MiniGames.Shop).
--
-- The effects kit (the sound helper here, the rest in Modules/MiniGameFX.lua).
-- Everything is pooled, drawn over the play area (shell.fx, above the game's
-- frames) and moved by the window's own every-frame update only while
-- something animates. A call while the window is hidden does nothing; hiding
-- it or switching games clears them all. at: a frame or texture the effect
-- is centred on (one that stays put: a cell, a hole), nil for the play
-- area's middle; opts.x and opts.y move it from there. Colours are {r, g, b}.
--   MiniGames:Sound(name, step) -> played, handle: a sound from
--       MiniGames.SOUNDS (SoundKit IDs in build 1.60.1.70707), only with
--       Mini-game Sounds on. A list plays its step-th sound (the last when
--       step is past it), or one at random without a step; {file, kit} plays
--       a sound file, else the kit; {kit = A, alt = B} plays A, else B when
--       the client refuses A. A name with a dot ("bossRoar.elwynn") falls
--       back to the part before it; a list of names plays each
--       ({"squish", "boing"}). No ID in MiniGames.FORBIDDEN_SOUNDS (the
--       blacksmith and metal sounds) ever plays. MiniGames:StopSound(name)
--       stops a held one (MiniGames.HELD: the drums), as hiding the window
--       or switching games does.
--   MiniGames:Burst(at, opts) -> sparks made: sparks fly out and fade. opts:
--       count (8, up to 40), texture (ART.spark) or atlas, coords, colour,
--       size (14), speed (120, px a second), life (.55), gravity (0, px a
--       second squared, down), spin (0, turns a second), shrink (.5), alpha
--       (1), blend ("ADD", or "BLEND" for a plain texture), angle (radians),
--       spread (a whole turn)
--   MiniGames:FloatText(at, text, opts)  words rising and fading ("+30",
--       "Bonk!"). opts: colour, size (16), rise (32), life (.8), pop (1.5,
--       the size it starts at, settling to 1)
--   MiniGames:Banner(text, opts)  a big word in the middle that scales in,
--       holds and fades ("Unstoppable!"). opts: colour, size (30), life
--       (1.4), sub (a smaller line under it), glow (a colour), from (1.8), y
--   MiniGames:Shake(strength, life)  the play area shakes (4 px, .3 s)
--   MiniGames:Pulse(at, opts)  a glow flashing and fading on a region. opts:
--       colour, texture (ART.glow) or atlas, coords, blend ("ADD" or "BLEND"), alpha
--       (.7), life (.35), w and h (else at's size times scale), scale (1.3),
--       grow (1.15)
--   MiniGames:Pop(frame, opts)  a frame of the game's scales up, then back
--       (to = 1) or away (to = 0, fading); it ends at its own size and alpha,
--       so hide it in done when it should be gone. opts: peak (1.3), to (1),
--       life (.25), done(frame, cleared)
--   MiniGames:Tween(life, step, done, data)  step(share 0 to 1, data) every
--       frame for life seconds, then done(data, cleared)
--   MiniGames:ClearFX()  every effect stopped at once (cleared = true)
--   MiniGames.ART  the kit's textures (all in build 1.60.1.70707),
--   MiniGames.QUARTER  the four colours of ART.bursts (texture coords),
--   MiniGames.Jitter()  a number from 0 to 1 that never uses the game's rolls
--
-- Only EraUI's own frames are made or written; the one hook is a post-hook
-- on the game's TakeTaxiNode (the name of the flight point you picked, for
-- "Flying to ..."), made the first time a flight choice is set. No
-- GameTooltip, no key binding, no keyboard: the window never takes keys
-- (Escape closes it through the game's own list of windows).
local MG = {}
EraUI:RegisterModule("MiniGames", MG)
EraUI.MiniGames = MG

MG.ORDER = {"whack", "blast"}
MG.NAMES = {whack = "Whack-a-Gnome", blast = "Azeroth Blast"}
-- Each game's icon (ManifestInterfaceData, build 1.60.1.70707): a wooden
-- mallet, and the Explosive Sheep's polymorph.
MG.ICONS = {whack = "Interface\\Icons\\INV_Hammer_15", blast = "Interface\\Icons\\Spell_Nature_Polymorph"}
MG.games = {}
-- The flight being flown: on, the game opened for it (opened), closed by
-- hand (stays closed), waiting for a fight to end, where it goes, and the
-- games shown during it (played: each finishes as you land).
MG.flight = {on = false, opened = false, closedByHand = false, waiting = false, destination = nil, played = {}}
-- The games' sounds by name: SoundKit IDs, each with its sound files in this
-- client's SoundKit and SoundKitEntry (build 1.60.1.70707). A list: a chain's
-- rising steps or lines to pick from. heroism has no kit in this build, so
-- its sound file plays (Battle Shout when that can't). The soft sounds
-- (pop to mapStep) are stand-ins already used before: Modules/MiniGameAssets.lua
-- points them at their own sounds (balloon pops, squishes, boings...).
MG.SOUNDS = {
    done = 878, epic = 31578,
    chain = {206515, 206517, 208731, 208732, 31578},
    buzz = 47355, fail = 847,
    boom = 4100, fireball = 362976, flamestrike = 3077, sheep = 3580, poly = 1372,
    charge = 3330, shout = 3113, chargeOrc = 2694, chargeHuman = 2670, chargeGnome = 2828,
    hearthCast = 2561, hearthArrive = 3315,
    bloodlust = 347047, heroism = {file = 569013, kit = 3113}, drums = 344561,
    cheerHuman = 2677, cheerOrc = 2701, cheerGnome = 2835,
    legendary = 63971, levelUp = 888, record = 74438, success = 43502, bossDown = 50111,
    peonUp = 7121, peonWhat = 7194, peonHit = 7195, peonReady = 6192, peonDone = 6199, peonYes = 6197,
    orcWound = 1320, orcCrit = 1321, orcDeath = 1322, orcLaugh = 6943, orcFlee = 2695,
    gnomeUp = 5925, gnomeHello = 5922, gnomeHit = 5927, gnomeAngry = 5924,
    gnomeWound = 3276, gnomeCrit = 3277, gnomeDeath = 3278, gnomeLaugh = 6913, gnomeFlee = 2829,
    pop = 838, squish = 838, boing = 856, whoosh = 856, chime = 878, coin = 120, coins = 287276,
    star = 878, win = 43502, lose = 847, unlock = 63971, bossRoar = 6943, bossHit = 838,
    iceCrack = 838, oilSplat = 838, crateBreak = 838, relicDrop = 878, shuffle = 856,
    powerUse = 3315, buy = 287276, uiClick = 856, mapStep = 856,
}
-- Never played (measured in 70707): 941 and 942 mace hits, 1143 mining hits,
-- 865 the money window's clink, 1221 and 1204 gem clinks, 233 to 238 the
-- weapon swing sounds. The blacksmith clangs Squirt heard.
MG.FORBIDDEN_SOUNDS = {[941] = true, [942] = true, [1143] = true, [865] = true, [1221] = true, [1204] = true,
    [233] = true, [234] = true, [235] = true, [236] = true, [237] = true, [238] = true}
-- The first games' names, pointed at the soft sounds so old calls stay clean.
MG.SOUND_ALIAS = {bonk = "squish", hit = "squish", hitBig = "boing", swing = "whoosh", swingBig = "whoosh",
    tink = "uiClick", clink = "chime", gems = "uiClick", gemsDown = "chime", swap = "whoosh", start = "chime",
    coinBig = "coins"}
function MG:PointSounds()
    for old, new in pairs(self.SOUND_ALIAS) do self.SOUNDS[old] = self.SOUNDS[new] end
end
MG:PointSounds()
-- Sounds that run on (a loop sample): kept to be stopped.
MG.HELD = {drums = true}
MG.held = {}
MG.WIDTH, MG.HEIGHT = 440, 650
MG.CONTENT_W, MG.CONTENT_H = 412, 500
MG.CONTENT_X, MG.CONTENT_Y = 14, 70  -- the play area's top left corner, in from the window's
MG.FOOTER_W, MG.FOOTER_H = 412, 32
MG.BAR_W, MG.BAR_H = 256, 32
MG.SWITCH_W = 148
MG.LAND_CHECK = 1   -- seconds between the open window's own look for a landing
MG.CHECKS = {.5, 1.5, 3} -- seconds after losing control to look for a flight again
MG.PICK_KEEP = 15   -- seconds a picked flight point counts as where you're flying
MG.WINDOW_NAME = "EraUIMiniGames"

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BACKDROP = {bgFile = WHITE, edgeFile = WHITE, edgeSize = 1}
local FLIGHT_EVENTS = {"PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_ENTERING_WORLD"}
local FIGHT_EVENTS = {"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}

local function Hidden(value) return issecretvalue ~= nil and issecretvalue(value) end
local function Number(value)
    return not Hidden(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
local function Now() return type(GetTime) == "function" and GetTime() or 0 end
local function InFight() return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false end

-- On a flight path now: a hidden, failing or missing answer is no.
function MG.OnTaxi()
    if type(UnitOnTaxi) ~= "function" then return false end
    local ok, yes = pcall(UnitOnTaxi, "player")
    return ok and not Hidden(yes) and yes == true
end
-- "Horde" or "Alliance", or nil when the game won't say.
function MG.Faction()
    if type(UnitFactionGroup) ~= "function" then return nil end
    local ok, faction = pcall(UnitFactionGroup, "player")
    if not ok or Hidden(faction) or type(faction) ~= "string" then return nil end
    return faction
end
function MG.Random(low, high) return math.random(low, high) end
-- The effects' own numbers (a small generator of their own), so a spark or
-- a sound picked never takes one of a game's rolls.
local seed = 4242
function MG.Jitter()
    seed = (seed * 16807) % 2147483647
    return seed / 2147483647
end

-- Your class colour; grey when the class can't be read.
function MG.Colour()
    local ok, _, class = pcall(UnitClass, "player")
    if not ok or Hidden(class) or type(class) ~= "string" then return .7, .7, .7 end
    local colour = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if colour then return colour.r, colour.g, colour.b end
    return .7, .7, .7
end
local function Hex(r, g, b)
    local function Byte(v) return math.max(0, math.min(255, math.floor(v * 255 + .5))) end
    return ("%02x%02x%02x"):format(Byte(r), Byte(g), Byte(b))
end

-- Settings ------------------------------------------------------------------

-- The game that opens on a flight path: "whack", "blast" or "off".
function MG:FlightChoice()
    local choice = EraUI:GetSetting("miniGameFlight")
    for _, id in ipairs(self.ORDER) do if choice == id then return id end end
    return "off"
end
function MG:SoundsOn() return EraUI:GetSetting("miniGameSounds") ~= false end

-- One SoundKit ID (never a forbidden one), or one sound file.
local function PlayKit(id)
    if not Number(id) or MG.FORBIDDEN_SOUNDS[id] or type(PlaySound) ~= "function" then return false end
    local ok, willPlay, handle = pcall(PlaySound, id, "SFX")
    return ok and willPlay ~= false, handle
end
local function PlayFile(file)
    if file == nil or type(PlaySoundFile) ~= "function" then return false end
    local ok, willPlay, handle = pcall(PlaySoundFile, file, "SFX")
    return ok and willPlay ~= false, handle
end
-- An entry of MiniGames.SOUNDS: a kit, a list (its step-th, else one at
-- random), {file, kit} (the file, else the kit) or {kit, alt} (alt when the
-- kit is refused). Lists and pairs may hold each other, a few deep.
local function PlayEntry(entry, step, depth)
    if type(entry) == "number" then return PlayKit(entry) end
    if type(entry) ~= "table" or depth > 4 then return false end
    local count = #entry
    if count > 0 then
        local pick = Number(step) and math.floor(step) or math.floor(MG.Jitter() * count) + 1
        return PlayEntry(entry[math.max(1, math.min(count, pick))], nil, depth + 1)
    end
    if entry.file ~= nil then
        local played, handle = PlayFile(entry.file)
        if played then return true, handle end
    end
    if entry.kit ~= nil then
        local played, handle = PlayEntry(entry.kit, step, depth + 1)
        if played then return true, handle end
    end
    if entry.alt ~= nil then return PlayEntry(entry.alt, step, depth + 1) end
    return false
end
function MG:Sound(name, step)
    -- A list of names: each played ("squish" and "boing" together).
    if type(name) == "table" then
        local played, handle = false, nil
        for _, each in ipairs(name) do
            local ok, held = self:Sound(each, step)
            if ok and not played then played, handle = true, held end
        end
        return played, handle
    end
    local entry = self.SOUNDS[name]
    if entry == nil and type(name) == "string" then
        local base = name:match("^([^%.]+)%.")
        entry = base and self.SOUNDS[base]
    end
    if entry == nil or not self:SoundsOn() then return false end
    local played, handle = PlayEntry(entry, step, 0)
    if played and self.HELD[name] and handle ~= nil then
        self:StopSound(name)
        self.held[name] = handle
    end
    return played, handle
end
-- Stops a held sound (the drums), or every one without a name.
function MG:StopSound(name)
    for held, handle in pairs(self.held) do
        if name == nil or held == name then
            if type(StopSound) == "function" then pcall(StopSound, handle) end
            self.held[held] = nil
        end
    end
end

-- Games and scores ------------------------------------------------------------

function MG:Register(id, game)
    game.id = id
    self.games[id] = game
    return game
end

-- A game's header name in two parts, the second in your class colour.
function MG:TitleParts(id)
    local game = self.games[id]
    if game and type(game.Title) == "function" then
        local ok, prefix, accent = pcall(game.Title, game)
        if ok and type(prefix) == "string" then return prefix, type(accent) == "string" and accent or "" end
    end
    return self.NAMES[id] or tostring(id), ""
end
function MG:Title(id)
    local prefix, accent = self:TitleParts(id)
    return prefix .. accent
end
-- A game's icon: its own, else the one kept here for its id.
function MG:Icon(id)
    local game = self.games[id]
    if game and type(game.Icon) == "function" then
        local ok, icon = pcall(game.Icon, game)
        if ok and (type(icon) == "string" or Number(icon)) then return icon end
    end
    return self.ICONS[id]
end

-- This character's mini-game record (EraUIClassicCharDB.miniGames), made on
-- demand. Core/Persistence.lua backs up its bests (never the kept board).
local function CharRecord(make)
    local char = EraUIClassicCharDB
    if type(char) ~= "table" then
        if not make then return nil end
        char = {}
        EraUIClassicCharDB = char
    end
    local record = char.miniGames
    if type(record) ~= "table" then
        if not make then return nil end
        record = {}
        char.miniGames = record
    end
    return record
end
-- A game's own table, kept for this character (Azeroth Blast's board).
function MG:CharData(id)
    local record = CharRecord(true)
    if type(record.games) ~= "table" then record.games = {} end
    if type(record.games[id]) ~= "table" then record.games[id] = {} end
    return record.games[id]
end
local function Count(value)
    if not Number(value) or value < 0 then return 0 end
    return math.floor(value)
end
-- This character's best and the account's best (never under this character's).
function MG:Best(id)
    local record = CharRecord(false)
    local mine = record and type(record.best) == "table" and Count(record.best[id]) or 0
    local account = EraUI:GetSetting("miniGameBest")
    local all = type(account) == "table" and Count(account[id]) or 0
    return mine, math.max(mine, all)
end
-- A finished game's score. Returns whether it beat this character's best,
-- then whether it beat the account's.
function MG:Record(id, score)
    score = Count(score)
    local mine, all = self:Best(id)
    local newMine, newAll = score > mine, score > all
    if newMine then
        local record = CharRecord(true)
        if type(record.best) ~= "table" then record.best = {} end
        record.best[id] = score
    end
    if newAll then
        local account = EraUI:GetSetting("miniGameBest")
        if type(account) ~= "table" then account = {} end
        account[id] = score
        EraUI:SetSetting("miniGameBest", account)
    end
    if (newMine or newAll) and EraUI.SaveSettings then EraUI:SaveSettings() end
    if self.window and self.current == id then self:PaintHeader() end
    return newMine, newAll
end

-- A mini-game's error, said once in chat.
function MG.Report(err)
    if MG.failed then return end
    MG.failed = true
    EraUI:Print("A mini-game hit an error and was closed: " .. tostring(err))
end
-- A game's method, through a protected call: an error is said once in chat,
-- and one in the window's every-frame update closes the window.
local function Run(game, method, ...)
    local fn = game and game[method]
    if type(fn) ~= "function" then return true end
    local ok, err = pcall(fn, game, ...)
    if not ok then
        MG.Report(err)
        if method == "Update" then MG:Close("error") end
    end
    return ok
end

-- The look ----------------------------------------------------------------------

-- outline: the letters outlined (numbers and titles over art).
function MG.Text(parent, value, size, muted, outline)
    local text = parent:CreateFontString(nil, "OVERLAY")
    local font, _, flags = GameFontHighlight:GetFont()
    text:SetFont(font, size or 13, outline and "OUTLINE" or flags or "")
    if muted then text:SetTextColor(.58, .62, .68) else text:SetTextColor(.94, .95, .98) end
    text:SetJustifyH("LEFT")
    text:SetText(value or "")
    return text
end
-- A texture shows an icon (a path or file ID), else hides. Returns whether it shows.
function MG.SetIcon(texture, icon)
    local ok = icon ~= nil and texture:SetTexture(icon) ~= false
    texture:SetShown(ok)
    return ok
end
-- A soft fade between two colours (bottom to top, or left to right); a
-- flat mix of the two should the client refuse it.
function MG.Gradient(texture, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
    texture:SetColorTexture(1, 1, 1, 1)
    if type(CreateColor) == "function" and type(texture.SetGradient) == "function" then
        local ok = pcall(texture.SetGradient, texture, orientation, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
        if ok then return true end
    end
    texture:SetColorTexture((r1 + r2) / 2, (g1 + g2) / 2, (b1 + b2) / 2, (a1 + a2) / 2)
    return false
end

-- state: "normal", "hover" or "down".
local function PaintButton(button, state)
    local r, g, b = MG.Colour()
    local k = state == "down" and .12 or state == "hover" and .3 or .19
    button:SetBackdropColor(r * k, g * k, b * k, 1)
    button:SetBackdropBorderColor(r, g, b, state == "normal" and .8 or 1)
    button.sheen:SetAlpha(state == "hover" and .11 or state == "down" and .02 or .06)
end
local function Press(button, down)
    local at = button.labelAt
    local dx, dy = down and 1 or 0, down and -1 or 0
    button.label:SetPoint(at[1], at[2], at[3], at[4] + dx, at[5] + dy)
    if button.icon then button.icon:SetPoint("LEFT", button, "LEFT", 6 + dx, dy) end
end
local function ButtonScripts(button)
    button:SetScript("OnEnter", function(self) PaintButton(self, "hover") end)
    button:SetScript("OnLeave", function(self) Press(self, false); PaintButton(self, "normal") end)
    button:SetScript("OnMouseDown", function(self) Press(self, true); PaintButton(self, "down") end)
    button:SetScript("OnMouseUp", function(self)
        Press(self, false)
        PaintButton(self, self.IsMouseOver and self:IsMouseOver() and "hover" or "normal")
    end)
end
-- EraUI's own button: a class-coloured edge on a dark fill of the same,
-- a lighter top half, brighter on hover, pressed in on a click. icon: a
-- small one on its left (a path or file ID).
function MG.Button(parent, label, width, height, icon)
    width, height = width or 110, height or 28
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetBackdrop(BACKDROP)
    button.sheen = button:CreateTexture(nil, "ARTWORK")
    button.sheen:SetSize(width - 2, math.floor(height / 2))
    button.sheen:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    MG.Gradient(button.sheen, "VERTICAL", 1, 1, 1, .2, 1, 1, 1, 1)
    button.shade = button:CreateTexture(nil, "ARTWORK")
    button.shade:SetSize(width - 2, math.floor(height / 2) - 1)
    button.shade:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    MG.Gradient(button.shade, "VERTICAL", 0, 0, 0, .28, 0, 0, 0, 0)
    button.label = MG.Text(button, label, 13)
    if icon ~= nil then
        button.icon = button:CreateTexture(nil, "OVERLAY")
        button.icon:SetSize(height - 10, height - 10)
        button.icon:SetTexCoord(.08, .92, .08, .92)
        MG.SetIcon(button.icon, icon)
        button.labelAt = {"LEFT", button, "LEFT", height, 0}
        button.label:SetWidth(width - height - 6)
        button.label:SetWordWrap(false)
    else
        button.labelAt = {"CENTER", button, "CENTER", 0, 0}
        button.label:SetJustifyH("CENTER")
    end
    Press(button, false)
    PaintButton(button, "normal")
    ButtonScripts(button)
    return button
end

-- The window ---------------------------------------------------------------------

-- The art (ManifestInterfaceData and UiTextureAtlasMember, build
-- 1.60.1.70707): a dark stone tile under the whole window, dark rock in the
-- play area, a soft glow behind the header, and the play area's edge: the
-- gold and blue frame of the Alliance's mission table, the bronze and iron
-- of the Horde's (an unknown faction gets the gold), drawn from their atlas
-- pieces by hand so the corners can be mirrored.
local ART = {
    stone = "Interface\\Garrison\\ClassHallBackground",
    rock = "Interface\\FrameGeneral\\UI-Background-Rock",
    glow = "Interface\\Glues\\Models\\UI_Draenei\\GenericGlow64",
}
local function Px(left, right, top, bottom, width, height) return {left / width, right / width, top / height, bottom / height} end
local EDGES = {
    Horde = {file = "Interface\\Garrison\\HordeBfAMissionFrame", side = "Interface\\Garrison\\HordeBfAMissionFrame2",
        corner = Px(1, 167, 331, 497, 512, 512), top = Px(0, 256, 178, 208, 512, 512), bottom = Px(0, 256, 146, 176, 512, 512),
        left = Px(1, 31, 0, 256, 32, 256), metal = {.66, .48, .28}},
    Alliance = {file = "Interface\\Garrison\\AllianceBfAMissionFrame", side = "Interface\\Garrison\\AllianceBfAMissionFrame2",
        corner = Px(43, 209, 210, 376, 512, 512), top = Px(0, 256, 76, 106, 512, 512), bottom = Px(0, 256, 44, 74, 512, 512),
        left = Px(1, 31, 0, 256, 32, 256), metal = {.86, .68, .27}},
}
MG.EDGES = EDGES
local EDGE_OUT, EDGE_CORNER, EDGE_THICK = 6, 50, 9 -- the frame at 0.3 of its size
local GLOW = {x = 40, y = 36, rx = 170, ry = 80}    -- the header glow's middle and reach
local HEADER_LINE = 60
local WHERE_X, BEST_RIGHT, WHERE_GAP = 62, 46, 10    -- the header's second line: where (left), Best (right)
local PURSE_ICON, PURSE_GAP = 14, 3                  -- the coin purse at the right of that line, Best left of it
local NOTE_Y = 591                                   -- the note line's middle, down from the top
local BAND_Y = 606                                   -- the footer band's top
MG.NOTE_Y, MG.BAND_Y = NOTE_Y, BAND_Y

-- Where it was dragged to (its top left corner, from the screen's), or nil.
local function Spot()
    local spot = EraUI:GetSetting("miniGamePosition")
    if type(spot) == "table" and Number(spot.x) and Number(spot.y) then return spot end
end
local function Place(shell)
    shell:ClearAllPoints()
    local spot = Spot()
    if spot then shell:SetPoint("TOPLEFT", UIParent, "TOPLEFT", spot.x, spot.y)
    else shell:SetPoint("CENTER", UIParent, "CENTER", 0, 40) end
end
local function SavePlace(shell)
    shell.moving = false
    if shell.SetUserPlaced then shell:SetUserPlaced(false) end
    local left, top, height = shell:GetLeft(), shell:GetTop(), UIParent:GetHeight()
    if not (Number(left) and Number(top) and Number(height)) then return end
    EraUI:SetSetting("miniGamePosition", {x = math.floor(left + .5), y = math.floor(top - height + .5)})
    if EraUI.SaveSettings then EraUI:SaveSettings() end
    Place(shell)
end

local function OnUpdate(shell, elapsed)
    local game = MG.games[MG.current]
    if game then Run(game, "Update", shell, elapsed) end
    -- The effects move only while there are some (Modules/MiniGameFX.lua).
    if MG.fxBusy and MG.Animate and shell:IsShown() then
        local ok, err = pcall(MG.Animate, MG, Number(elapsed) and elapsed or 0)
        if not ok then MG.Report(err) end
        if not ok or MG.fxFailed then
            MG.fxFailed = nil
            MG:Close("error")
        end
    end
    if not MG.flight.on then return end
    -- A landing the game's events didn't bring: looked for once a second.
    MG.sinceCheck = (MG.sinceCheck or 0) + (Number(elapsed) and elapsed or 0)
    if MG.sinceCheck >= MG.LAND_CHECK then
        MG.sinceCheck = 0
        if not MG.OnTaxi() then MG:Landed() end
    end
end
local function OnShow(shell)
    MG.sinceCheck = 0
    shell:SetScript("OnUpdate", OnUpdate)
    MG:PaintHeader()
end
-- Every hide stops the effects and pauses the game shown. Why: as
-- MiniGames:Close said, else the game's list of windows (Escape: by hand)
-- or the whole interface hidden (the window itself still counts as shown).
local function OnHide(shell)
    local why = shell.hideWhy or (shell:IsShown() and "hidden" or "hand")
    shell.hideWhy = nil
    shell:SetScript("OnUpdate", nil)
    if shell.moving then shell:StopMovingOrSizing(); SavePlace(shell) end
    if MG.ClearFX then MG:ClearFX() end
    MG:StopSound()
    local game = MG.games[MG.current]
    if game and game.built then Run(game, "Pause", shell, why) end
    if (why == "hand" or why == "error") and MG.flight.on then MG.flight.closedByHand = true end
end

-- The game's icon in a small metal frame, at the header's left.
local function HeaderIcon(shell, metal)
    local rim = shell:CreateTexture(nil, "ARTWORK")
    rim:SetSize(38, 38)
    rim:SetPoint("TOPLEFT", shell, "TOPLEFT", 14, -12)
    rim:SetColorTexture(metal[1], metal[2], metal[3], 1)
    local well = shell:CreateTexture(nil, "ARTWORK", nil, 1)
    well:SetSize(36, 36)
    well:SetPoint("CENTER", rim, "CENTER", 0, 0)
    well:SetColorTexture(0, 0, 0, 1)
    shell.icon = shell:CreateTexture(nil, "ARTWORK", nil, 2)
    shell.icon:SetSize(34, 34)
    shell.icon:SetPoint("CENTER", rim, "CENTER", 0, 0)
    shell.icon:SetTexCoord(.08, .92, .08, .92)
end
-- A soft glow of your class colour behind the icon, cut at the window's edges.
local function HeaderGlow(shell)
    local glow = shell:CreateTexture(nil, "BACKGROUND", nil, 3)
    local width, height = GLOW.x + GLOW.rx - 1, GLOW.y + GLOW.ry - 1
    glow:SetSize(width, height)
    glow:SetPoint("TOPLEFT", shell, "TOPLEFT", 1, -1)
    if glow:SetTexture(ART.glow) == false then glow:Hide() end
    local left, top = GLOW.x - GLOW.rx, GLOW.y - GLOW.ry
    glow:SetTexCoord((1 - left) / (2 * GLOW.rx), 1, (1 - top) / (2 * GLOW.ry), 1)
    glow:SetBlendMode("ADD")
    shell.glow = glow
end
local function Header(shell, metal)
    shell.stripe = shell:CreateTexture(nil, "ARTWORK")
    shell.stripe:SetPoint("TOPLEFT", shell, "TOPLEFT", 1, -1)
    shell.stripe:SetPoint("TOPRIGHT", shell, "TOPRIGHT", -1, -1)
    shell.stripe:SetHeight(3)
    HeaderGlow(shell)
    HeaderIcon(shell, metal)
    shell.title = MG.Text(shell, "", 18)
    shell.title:SetPoint("TOPLEFT", shell, "TOPLEFT", 62, -15)
    shell.where = MG.Text(shell, "", 11, true)
    shell.where:SetPoint("TOPLEFT", shell, "TOPLEFT", WHERE_X, -38)
    shell.where:SetWidth(170)
    shell.where:SetWordWrap(false)
    shell.score = MG.Text(shell, "", 17)
    shell.score:SetPoint("TOPRIGHT", shell, "TOPRIGHT", -BEST_RIGHT, -14)
    shell.score:SetJustifyH("RIGHT")
    shell.score:SetTextColor(1, .86, .5)
    -- The coin purse (MiniGames.Progress): a coin and the count, Best left of it.
    shell.coins = MG.Text(shell, "", 11)
    shell.coins:SetPoint("TOPRIGHT", shell, "TOPRIGHT", -BEST_RIGHT, -38)
    shell.coins:SetJustifyH("RIGHT")
    shell.coins:SetTextColor(1, .86, .5)
    shell.coin = shell:CreateTexture(nil, "ARTWORK")
    shell.coin:SetSize(PURSE_ICON, PURSE_ICON)
    shell.coin:SetPoint("RIGHT", shell.coins, "LEFT", -PURSE_GAP, 0)
    if not (MG.Art and MG:Art(shell.coin, "coin")) then
        shell.coin:SetShown(shell.coin:SetTexture("Interface\\Icons\\INV_Misc_Coin_01") ~= false)
        shell.coin:SetTexCoord(.08, .92, .08, .92)
    end
    shell.best = MG.Text(shell, "", 11, true)
    shell.best:SetPoint("TOPRIGHT", shell, "TOPRIGHT", -BEST_RIGHT, -38)
    shell.best:SetJustifyH("RIGHT")
    shell.line = shell:CreateTexture(nil, "BORDER")
    shell.line:SetPoint("TOPLEFT", shell, "TOPLEFT", 1, -HEADER_LINE)
    shell.line:SetPoint("TOPRIGHT", shell, "TOPRIGHT", -1, -HEADER_LINE)
    shell.line:SetHeight(1)
    local close
    if EraUI.CreateCloseX then
        close = EraUI:CreateCloseX(shell, function() MG:Close("hand") end)
    else
        close = CreateFrame("Button", nil, shell)
        close:SetSize(36, 36)
        close:SetPoint("TOPRIGHT", shell, "TOPRIGHT", -8, -8)
        close.label = MG.Text(close, "X", 20, true)
        close.label:SetPoint("CENTER", close, "CENTER", 0, 0)
        close:SetScript("OnClick", function() MG:Close("hand") end)
    end
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", shell, "TOPRIGHT", -4, -4)
    shell.close = close
end

-- The whole window's dark stone, faintly there under EraUI's dark fill.
local function Stone(shell)
    local stone = shell:CreateTexture(nil, "BACKGROUND", nil, 1)
    stone:SetSize(MG.WIDTH - 2, MG.HEIGHT - 2)
    stone:SetPoint("TOPLEFT", shell, "TOPLEFT", 1, -1)
    if stone:SetTexture(ART.stone, "REPEAT", "REPEAT") == false then stone:Hide() end
    stone:SetTexCoord(0, (MG.WIDTH - 2) / 256, 0, (MG.HEIGHT - 2) / 256)
    stone:SetVertexColor(.55, .57, .64)
    stone:SetAlpha(.5)
    shell.stone = stone
    -- The footer's band, a shade lighter, under a hairline.
    local band = shell:CreateTexture(nil, "BACKGROUND", nil, 2)
    band:SetSize(MG.WIDTH - 2, MG.HEIGHT - BAND_Y - 1)
    band:SetPoint("TOPLEFT", shell, "TOPLEFT", 1, -BAND_Y)
    band:SetColorTexture(.045, .05, .062, .88)
    local hair = shell:CreateTexture(nil, "BORDER")
    hair:SetSize(MG.WIDTH - 2, 1)
    hair:SetPoint("TOPLEFT", shell, "TOPLEFT", 1, -BAND_Y)
    hair:SetColorTexture(.17, .18, .22, 1)
end
-- The play area's floor: darker than the window, dark rock on it, and a
-- shadow along its inside edges.
local function Floor(shell)
    local x, y, w, h = MG.CONTENT_X, MG.CONTENT_Y, MG.CONTENT_W, MG.CONTENT_H
    local floor = shell:CreateTexture(nil, "BACKGROUND", nil, 4)
    floor:SetSize(w, h)
    floor:SetPoint("TOPLEFT", shell, "TOPLEFT", x, -y)
    floor:SetColorTexture(.012, .013, .018, .8)
    local rock = shell:CreateTexture(nil, "BACKGROUND", nil, 5)
    rock:SetSize(w, h)
    rock:SetPoint("TOPLEFT", shell, "TOPLEFT", x, -y)
    if rock:SetTexture(ART.rock, "REPEAT", "REPEAT") == false then rock:Hide() end
    rock:SetTexCoord(0, w / 256, 0, h / 256)
    rock:SetVertexColor(.5, .5, .55)
    rock:SetAlpha(.32)
    shell.floor, shell.rock = floor, rock
    local deep = 24
    local sides = {
        {"TOPLEFT", x, -y, w, deep, "VERTICAL", 0, .55}, {"TOPLEFT", x, -(y + h - deep), w, deep, "VERTICAL", .55, 0},
        {"TOPLEFT", x, -y, deep, h, "HORIZONTAL", .55, 0}, {"TOPLEFT", x + w - deep, -y, deep, h, "HORIZONTAL", 0, .55},
    }
    for _, side in ipairs(sides) do
        local shade = shell:CreateTexture(nil, "BACKGROUND", nil, 6)
        shade:SetSize(side[4], side[5])
        shade:SetPoint(side[1], shell, "TOPLEFT", side[2], side[3])
        MG.Gradient(shade, side[6], 0, 0, 0, side[7], 0, 0, 0, side[8])
    end
end

-- One piece of the play area's edge. Returns it, and whether its art loaded.
local function EdgePiece(edge, layer, file, coords, flipX, flipY)
    local piece = edge:CreateTexture(nil, layer)
    local ok = piece:SetTexture(file) ~= false
    local left, right, top, bottom = coords[1], coords[2], coords[3], coords[4]
    if flipX then left, right = right, left end
    if flipY then top, bottom = bottom, top end
    piece:SetTexCoord(left, right, top, bottom)
    return piece, ok
end
local function EdgePieces(edge, art, width, height)
    local c, t, long, tall = EDGE_CORNER, EDGE_THICK, width - 2 * EDGE_CORNER, height - 2 * EDGE_CORNER
    local spots = {
        {"BORDER", art.file, art.top, false, false, long, t, "TOPLEFT", c, 0},
        {"BORDER", art.file, art.bottom, false, false, long, t, "BOTTOMLEFT", c, 0},
        {"BORDER", art.side, art.left, false, false, t, tall, "TOPLEFT", 0, -c},
        {"BORDER", art.side, art.left, true, false, t, tall, "TOPRIGHT", 0, -c},
        {"ARTWORK", art.file, art.corner, false, false, c, c, "TOPLEFT", 0, 0},
        {"ARTWORK", art.file, art.corner, true, false, c, c, "TOPRIGHT", 0, 0},
        {"ARTWORK", art.file, art.corner, false, true, c, c, "BOTTOMLEFT", 0, 0},
        {"ARTWORK", art.file, art.corner, true, true, c, c, "BOTTOMRIGHT", 0, 0},
    }
    local pieces, all = {}, true
    for index, spot in ipairs(spots) do
        local piece, ok = EdgePiece(edge, spot[1], spot[2], spot[3], spot[4], spot[5])
        piece:SetSize(spot[6], spot[7])
        piece:SetPoint(spot[8], edge, spot[8], spot[9], spot[10])
        pieces[index] = piece
        all = all and ok
    end
    return pieces, all
end
-- Plain metal lines instead, should the client refuse the frame's art.
local function EdgeLines(edge, metal, width, height)
    local i = EDGE_OUT - 3 -- 3 px out from the play area
    local long, tall = width - 2 * i, height - 2 * i
    local spots = {{"TOPLEFT", long, 2, i, -i}, {"BOTTOMLEFT", long, 2, i, i}, {"TOPLEFT", 2, tall, i, -i}, {"TOPRIGHT", 2, tall, -i, -i}}
    local lines = {}
    for index, spot in ipairs(spots) do
        local line = edge:CreateTexture(nil, "BORDER")
        line:SetSize(spot[2], spot[3])
        line:SetPoint(spot[1], edge, spot[1], spot[4], spot[5])
        line:SetColorTexture(metal[1], metal[2], metal[3], 1)
        lines[index] = line
    end
    return lines
end
-- The play area's edge, over the game's frames (it takes no clicks) and
-- under the effects.
local function Edge(shell, art)
    local width, height = MG.CONTENT_W + 2 * EDGE_OUT, MG.CONTENT_H + 2 * EDGE_OUT
    local edge = CreateFrame("Frame", nil, shell)
    edge:SetSize(width, height)
    edge:SetPoint("TOPLEFT", shell, "TOPLEFT", MG.CONTENT_X - EDGE_OUT, -(MG.CONTENT_Y - EDGE_OUT))
    edge:SetFrameLevel(shell.content:GetFrameLevel() + 30)
    local pieces, ok = EdgePieces(edge, art, width, height)
    edge.pieces = pieces
    if not ok then
        for _, piece in ipairs(pieces) do piece:Hide() end
        edge.lines = EdgeLines(edge, art.metal, width, height)
    end
    shell.edge = edge
end

local function Footer(shell)
    shell.footer = CreateFrame("Frame", nil, shell)
    shell.footer:SetSize(MG.FOOTER_W, MG.FOOTER_H)
    shell.footer:SetPoint("BOTTOMLEFT", shell, "BOTTOMLEFT", MG.CONTENT_X, 8)
    local switch = MG.Button(shell.footer, "", MG.SWITCH_W, 28, MG.ICONS.blast)
    switch:SetPoint("LEFT", shell.footer, "LEFT", 0, 0)
    switch:SetScript("OnClick", function() MG:Switch() end)
    switch:Hide()
    shell.switch = switch
    shell.note = MG.Text(shell, "", 12)
    shell.note:SetTextColor(.76, .79, .85)
    shell.note:SetJustifyH("CENTER")
    shell.note:SetWidth(MG.CONTENT_W - 8)
    shell.note:SetWordWrap(true)
    shell.note:SetPoint("CENTER", shell, "TOP", 0, -NOTE_Y)
end

-- Made the first time a game opens, sized before anything is placed on it
-- (Forever may never draw a frame laid out under one without a size).
-- DIALOG: over the game's windows, like /era.
local function BuildWindow()
    local shell = CreateFrame("Frame", MG.WINDOW_NAME, UIParent, "BackdropTemplate")
    shell:SetSize(MG.WIDTH, MG.HEIGHT)
    shell:SetFrameStrata("DIALOG")
    shell:SetToplevel(true)
    shell:SetClampedToScreen(true)
    shell:SetMovable(true)
    -- Its place is EraUI's own (miniGamePosition), never the game's layout cache.
    if shell.SetDontSavePosition then shell:SetDontSavePosition(true) end
    shell:EnableMouse(true)
    shell:RegisterForDrag("LeftButton")
    shell:SetBackdrop(BACKDROP)
    shell:SetBackdropColor(.026, .029, .037, .98)
    shell:SetBackdropBorderColor(.19, .20, .24, 1)
    shell:Hide()
    Place(shell)
    local art = EDGES[MG.Faction() == "Horde" and "Horde" or "Alliance"]
    shell.metal = art.metal
    Stone(shell)
    Header(shell, art.metal)
    Floor(shell)
    shell.content = CreateFrame("Frame", nil, shell)
    shell.content:SetSize(MG.CONTENT_W, MG.CONTENT_H)
    shell.content:SetPoint("TOPLEFT", shell, "TOPLEFT", MG.CONTENT_X, -MG.CONTENT_Y)
    Edge(shell, art)
    -- The effects' layer: over the game's frames and the edge, no clicks.
    shell.fx = CreateFrame("Frame", nil, shell.content)
    shell.fx:SetSize(MG.CONTENT_W, MG.CONTENT_H)
    shell.fx:SetPoint("TOPLEFT", shell.content, "TOPLEFT", 0, 0)
    shell.fx:SetFrameLevel(shell.content:GetFrameLevel() + 40)
    Footer(shell)
    shell:SetScript("OnDragStart", function(self)
        if InFight() then return end
        self.moving = true
        self:StartMoving()
    end)
    shell:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePlace(self) end)
    shell:SetScript("OnShow", OnShow)
    shell:SetScript("OnHide", OnHide)
    -- Escape closes it through the game's own list of windows; it takes no keys.
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, MG.WINDOW_NAME) end
    return shell
end

function MG:Window()
    if not self.window then
        self.window = BuildWindow()
        self:ListenForFights()
        -- Logging out saves what each game has running (game:Keep); heard
        -- only once a game was ever opened.
        if self.events then self.events:RegisterEvent("PLAYER_LOGOUT") end
    end
    return self.window
end

-- A game's holder and footer strip, and its own frames in them, the first
-- time. A game whose Build fails stays broken (never built again) until a /reload.
local function Parts(shell, game)
    if game.built then return true end
    if game.broken then return false end
    local holder = CreateFrame("Frame", nil, shell.content)
    holder:SetSize(MG.CONTENT_W, MG.CONTENT_H)
    holder:SetPoint("TOPLEFT", shell.content, "TOPLEFT", 0, 0)
    holder:Hide()
    local bar = CreateFrame("Frame", nil, shell.footer)
    bar:SetSize(MG.BAR_W, MG.BAR_H)
    bar:SetPoint("TOPRIGHT", shell.footer, "TOPRIGHT", 0, 0)
    bar:Hide()
    game.holder, game.bar = holder, bar
    game.built = Run(game, "Build", shell, holder, bar)
    game.broken = not game.built
    return game.built
end

-- The game the Switch button goes to: the next one registered after the one
-- shown (in MiniGames.ORDER, a broken one skipped), or nil.
function MG:OtherGame()
    local order, at = self.ORDER, 0
    for index, id in ipairs(order) do if id == self.current then at = index end end
    for step = 1, #order do
        local id = order[(at + step - 1) % #order + 1]
        local game = self.games[id]
        if id ~= self.current and game and not game.broken then return id end
    end
    return nil
end
function MG:PaintSwitch()
    local shell = self.window
    if not shell then return end
    local other = self:OtherGame()
    shell.switch.target = other
    shell.switch:SetShown(other ~= nil)
    if not other then return end
    shell.switch.label:SetText(self:Title(other))
    MG.SetIcon(shell.switch.icon, self:Icon(other))
end
-- The Switch button: the window shows the other game, in the same place.
function MG:Switch()
    local other = self:OtherGame()
    if not (other and self:Shown()) then return false end
    return self:Open(other, "switch")
end

-- The score shown in the header now (the count-up's step).
function MG:ShowScore(score)
    local shell = self.window
    if not shell then return end
    if shell.scoreShown ~= score then
        shell.scoreShown = score
        shell.score:SetText("Score " .. score)
    end
end
function MG:PaintHeader()
    local shell = self.window
    if not shell then return end
    local id = self.current
    local game = self.games[id]
    local r, g, b = self.Colour()
    shell.stripe:SetColorTexture(r, g, b, 1)
    shell.line:SetColorTexture(r, g, b, .3)
    shell.glow:SetVertexColor(r, g, b, .22)
    MG.SetIcon(shell.icon, self:Icon(id))
    local prefix, accent = self:TitleParts(id)
    shell.title:SetText(prefix .. (accent ~= "" and ("|cff" .. Hex(r, g, b) .. accent .. "|r") or ""))
    local flight, where = self.flight, ""
    if flight.on then
        where = flight.destination and ("Flying to " .. flight.destination) or "On a flight"
    elseif game and type(game.Hint) == "function" then
        local ok, hint = pcall(game.Hint, game)
        if ok and type(hint) == "string" then where = hint end
    end
    shell.where:SetText(where)
    local score = 0
    if game and type(game.Score) == "function" then
        local ok, value = pcall(game.Score, game)
        if ok then score = Count(value) end
    end
    shell.scoreGoal = score
    self:ShowScore(score)
    local best
    if game and type(game.HeaderBest) == "function" then
        local ok, text = pcall(game.HeaderBest, game)
        if ok and type(text) == "string" then best = text end
    end
    if not best then
        local mine, all = self:Best(id)
        best = mine == all and ("Best " .. mine) or ("Best " .. mine .. ", account " .. all)
    end
    shell.best:SetText(best)
    local purse = self:PaintCoins()
    -- The where line takes the room the Best line and the purse leave (cut short, never under them).
    local ok, used = pcall(shell.best.GetStringWidth, shell.best)
    if ok and Number(used) then
        shell.where:SetWidth(math.max(60, MG.WIDTH - WHERE_X - BEST_RIGHT - WHERE_GAP - used - purse))
    end
    self:PaintSwitch()
end
-- The header's coin purse (MiniGames.Progress's coins), Best left of it.
-- Returns the room it takes (0 without the progress helper).
function MG:PaintCoins()
    local shell = self.window
    if not (shell and shell.coins) then return 0 end
    local P = self.Progress
    local shown = type(P) == "table" and type(P.Coins) == "function"
    local coins = 0
    if shown then
        local ok, value = pcall(P.Coins, P)
        if ok then coins = Count(value) else shown = false end
    end
    shell.coins:SetShown(shown)
    shell.coin:SetAlpha(shown and 1 or 0)
    shell.best:ClearAllPoints()
    if not shown then
        shell.best:SetPoint("TOPRIGHT", shell, "TOPRIGHT", -BEST_RIGHT, -38)
        return 0
    end
    shell.coins:SetText(tostring(coins))
    shell.best:SetPoint("TOPRIGHT", shell.coin, "TOPLEFT", -WHERE_GAP, 2)
    local ok, wide = pcall(shell.coins.GetStringWidth, shell.coins)
    return (ok and Number(wide) and wide or 0) + PURSE_GAP + PURSE_ICON + WHERE_GAP
end
-- The header's score. A rise counts up (the effects' update moves it), a
-- point at a time at once; now, a fall or a hidden window: at once.
local SCORE_GLOW = {colour = {1, .8, .35}, w = 120, h = 40, alpha = .45, life = .45}
function MG:SetScore(score, now)
    local shell = self.window
    if not shell then return end
    score = Count(score)
    shell.scoreGoal = score
    local from = shell.scoreShown or 0
    if now or score <= from + 1 or not shell:IsVisible() or not self.Animate then
        self:ShowScore(score)
        return
    end
    self.fxBusy = true
    if self.Pulse then self:Pulse(shell.score, SCORE_GLOW) end
end
function MG:Note(text)
    if self.window then self.window.note:SetText(text or "") end
end

-- Opens a game. why: "flight" (taking off, or back after a fight),
-- "command" (/era whack, /era blast, the Play rows) or "switch" (the
-- window's Switch button). Never in a fight. Returns true when it shows.
function MG:Open(id, why)
    local game = self.games[id]
    if not game or game.broken then
        if why ~= "flight" then
            if game then EraUI:Print(self:Title(id) .. " hit an error. Type /reload to try again.")
            else EraUI:Print((self.NAMES[id] or "That mini-game") .. " is not ready yet.") end
        end
        return false
    end
    if InFight() then
        if why == "flight" then self.flight.waiting = true
        else EraUI:Print("Mini-games open once the fight is over.") end
        return false
    end
    local shell = self:Window()
    -- Its frames first: a game that fails to build never takes the window
    -- (one showing closes, its game paused as any hide pauses it).
    if not Parts(shell, game) then
        if shell:IsShown() then self:Close("error") end
        return false
    end
    if shell:IsShown() and self.current and self.current ~= id then
        -- The game showing pauses; anything its pause starts is cleared too.
        if self.ClearFX then self:ClearFX() end
        local other = self.games[self.current]
        if other and other.built then Run(other, "Pause", shell, "switch") end
        if self.ClearFX then self:ClearFX() end
        self:StopSound()
    end
    self.current = id
    for _, other in pairs(self.games) do
        if other.holder then
            other.holder:SetShown(other == game)
            other.bar:SetShown(other == game)
        end
    end
    if self.flight.on then
        self.flight.opened, self.flight.closedByHand = true, false
        self.flight.played[id] = true
    end
    self:Note("")
    if shell:IsShown() then self:PaintHeader() else shell:Show() end
    shell:Raise()
    self.openWhy = why
    Run(game, "Shown", shell, why)
    return true
end
-- /era whack <words>, /era blast <words>: the game's own command (Whack's
-- tune). Returns whether it was handled.
function MG:Command(id, words)
    local game = self.games[id]
    if not (self.ready and game) or type(game.Command) ~= "function" then
        EraUI:Print(("Unknown mini-game command: %s"):format(tostring(words)))
        return false
    end
    local ok, handled = pcall(game.Command, game, words)
    if not ok then
        MG.Report(handled)
        return false
    end
    if not handled then EraUI:Print(("Unknown mini-game command: %s"):format(tostring(words))) end
    return handled and true or false
end
-- Every built game saves what's running (as you log out).
function MG:KeepAll()
    for _, game in pairs(self.games) do
        if game.built then Run(game, "Keep") end
    end
end
-- Hides the window, pausing its game. why as in OnHide.
function MG:Close(why)
    local shell = self.window
    if not (shell and shell:IsShown()) then return false end
    shell.hideWhy = why or "hand"
    shell:Hide()
    shell.hideWhy = nil
    return true
end
-- /era whack, /era blast: opens that game, or closes it when it shows.
function MG:Toggle(id)
    if not self.ready then
        EraUI:Print("Mini-games are not available.")
        return false
    end
    local shell = self.window
    if shell and shell:IsShown() and self.current == id then return not self:Close("hand") end
    return self:Open(id, "command")
end
function MG:Shown(id)
    return self.window ~= nil and self.window:IsShown() and (id == nil or self.current == id)
end

-- Flights ---------------------------------------------------------------------------

function MG:TookOff()
    local flight = self.flight
    flight.on, flight.opened, flight.closedByHand, flight.waiting, flight.played = true, false, false, false, {}
    local picked = self.picked
    flight.destination = (picked and Number(self.pickedAt) and Now() - self.pickedAt <= self.PICK_KEEP) and picked or nil
    self.picked, self.pickedAt = nil, nil
    local choice = self:FlightChoice()
    if choice ~= "off" then self:Open(choice, "flight") end
    if self.window and self.window:IsShown() then
        if self.current then flight.played[self.current] = true end
        self:PaintHeader()
    end
end
function MG:Landed()
    local flight = self.flight
    local opened, played = flight.opened, flight.played
    flight.on, flight.opened, flight.closedByHand, flight.waiting, flight.destination = false, false, false, false, nil
    flight.played = {}
    if opened then
        -- Every game played on this flight finishes, the one showing last.
        for id in pairs(played) do
            local game = self.games[id]
            if id ~= self.current and game and game.built then Run(game, "Land", self.window) end
        end
        local game = self.games[self.current]
        if game and game.built then Run(game, "Land", self.window) end
        self:Close("land")
    end
    if self.window and self.window:IsShown() then self:PaintHeader() end
end
-- Taking off or landing, as the game says now. Returns whether you're flying.
function MG:Check()
    local taxi = self.OnTaxi()
    if taxi and not self.flight.on then self:TookOff()
    elseif not taxi and self.flight.on then self:Landed() end
    return taxi
end
-- The flight flag can come a moment after control goes: looked for again.
function MG:CheckSoon()
    if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then return end
    for _, delay in ipairs(self.CHECKS) do
        C_Timer.After(delay, function() if MG.armed then MG:Check() end end)
    end
end

-- The flight point you clicked, read while the flight map is still open.
local function Picked(index)
    if not MG.armed or type(TaxiNodeName) ~= "function" then return end
    local ok, name = pcall(TaxiNodeName, index)
    if not ok or Hidden(name) or type(name) ~= "string" or name == "" then return end
    MG.picked, MG.pickedAt = name, Now()
end
function MG:WatchPicks()
    if self.watching then return end
    self.watching = true
    if type(hooksecurefunc) == "function" and type(TakeTaxiNode) == "function" then
        pcall(hooksecurefunc, "TakeTaxiNode", Picked)
    end
end

-- A fight hides the window; its end brings a flight's game back.
function MG:Fight()
    local shell = self.window
    if shell and shell:IsShown() then
        self.combatHidden = true
        self:Close("combat")
    end
end
function MG:FightOver()
    local flight = self.flight
    local hidden, waiting = self.combatHidden, flight.waiting
    self.combatHidden, flight.waiting = false, false
    if not flight.on or flight.closedByHand then return end
    if hidden and flight.opened and self.current then
        self:Open(self.current, "flight")
    elseif waiting then
        local choice = self:FlightChoice()
        if choice ~= "off" then self:Open(choice, "flight") end
    end
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then MG:Fight()
    elseif event == "PLAYER_REGEN_ENABLED" then MG:FightOver()
    elseif event == "PLAYER_LOGOUT" then MG:KeepAll()
    elseif MG.armed then
        -- The flight flag can lag control both ways: looked for again after
        -- control goes while not flying yet, and after it comes back while
        -- still flying (a landing the shut window's own look can't catch).
        local flying = MG:Check()
        if (event == "PLAYER_CONTROL_LOST" and not flying) or (event == "PLAYER_CONTROL_GAINED" and flying) then MG:CheckSoon() end
    end
end

function MG:ListenForFights()
    if self.fights or not self.events then return end
    self.fights = true
    for _, event in ipairs(FIGHT_EVENTS) do self.events:RegisterEvent(event) end
end

-- Follows the flight choice: armed, the flight events are heard (and the
-- flight point you pick is read); off, none of them. atLogin: the first
-- call; the loading screen's end then opens the game when you log in or
-- /reload on a flight. Chosen in /era during a flight, nothing opens until
-- the next one. Set to Off, no flight is followed any more (a game open
-- stays open).
function MG:Refresh(atLogin)
    if not self.events then return end
    local want = self:FlightChoice() ~= "off"
    if want == (self.armed == true) then return end
    self.armed = want
    for _, event in ipairs(FLIGHT_EVENTS) do
        if want then self.events:RegisterEvent(event) else self.events:UnregisterEvent(event) end
    end
    if not want then
        local flight = self.flight
        flight.on, flight.opened, flight.closedByHand, flight.waiting, flight.destination = false, false, false, false, nil
        flight.played = {}
        if self.window and self.window:IsShown() then self:PaintHeader() end
        return
    end
    self:WatchPicks()
    self:ListenForFights()
    if not atLogin then
        local taxi = self.OnTaxi()
        if taxi ~= self.flight.on then
            self.flight.on, self.flight.opened, self.flight.closedByHand = taxi, false, false
        end
    end
end

function MG:Initialize()
    if not self.events then
        self.events = CreateFrame("Frame")
        self.events:SetScript("OnEvent", OnEvent)
    end
    self.ready = true
    self:Refresh(true)
end
