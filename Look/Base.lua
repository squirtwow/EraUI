-- The shared toolkit for EraUI's Classic look (the Look/ folder).
-- Everything here is EraUI's own: small helpers the look's files lean on, kept
-- on one private table (EraUI.Look), never on the game's frames.
--
--   * values: secret-safe number reads, word lists, a weak-keyed table maker
--   * calls: protected calls that report to the game's error handler
--   * hooks: post-hooks (hooksecurefunc) installed once per object and method
--   * regions: one-line setters (place, fill, crop, alpha, shown, build),
--     and EraUI's own textures on a frame, recorded by purpose
--   * art: each piece of 1.x art by key, with the game's file and EraUI's
--     bundled copy (Media/Classic), the fallback between them, and Dark Mode's
--     tint through Core/Appearance.lua's ThemeTexture
--   * bars and 1.x rules: fills (Flat Bars), power and health colours, the
--     skull rule, the modern circles faded
--   * Edit Mode: reads only, plus moves through a frame's plain ...Base methods
--   * a small tooltip of EraUI's own (the game's GameTooltip is never used)
--   * one shared ticker for the look's periodic checks
--   * pieces the Classic windows share: the red X, check boxes, the red
--     panel button (EraUI's own, or worn by a game button), the gold font,
--     the old drop down and its list, thin scroll bars with the 1.x knob,
--     the stone bar, portrait framing
--   * game panels shown and closed safely, a whisper ready to type, the
--     stone fill, and the stone column behind the game's thin scroll bars
local _, EraUI = ...
local ns = EraUI.Classic

local Look = {}
EraUI.Look = Look
Look.ns = ns
Look.MEDIA = "Interface\\AddOns\\EraUI\\Media\\Classic\\"

---------------------------------------------------------------------------
-- Values
---------------------------------------------------------------------------

-- True for a value the game keeps hidden from addons (a "secret").
function Look.Secret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

-- A number that may be used in arithmetic and comparisons, or nil.
function Look.Number(value)
    if type(value) ~= "number" or Look.Secret(value) or value ~= value then return nil end
    return value
end

function Look.Weak()
    return setmetatable({}, { __mode = "k" })
end

-- "a b c" -> { "a", "b", "c" }
function Look.Words(text)
    local words = {}
    for word in text:gmatch("%S+") do words[#words + 1] = word end
    return words
end

function Look.Clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

-- The Classic settings table, or an empty stand-in before it loads.
function Look.Saved()
    return ns.db or {}
end

---------------------------------------------------------------------------
-- Calls
---------------------------------------------------------------------------

local function Report(ok, ...)
    if not ok then
        local onError = geterrorhandler and geterrorhandler()
        if onError then pcall(onError, (...)) end
    end
    return ok, ...
end

-- A protected call: an error goes to the game's error handler and never stops
-- the caller. Returns ok and the call's results.
function Look.Try(fn, ...)
    return Report(pcall(fn, ...))
end

-- A method that may be missing on this client, called quietly. Returns ok and
-- its first two results.
function Look.Ask(object, methodName, ...)
    local method = type(object) == "table" and object[methodName]
    if type(method) ~= "function" then return false end
    local fine, first, second = pcall(method, object, ...)
    if not fine then return false end
    return true, first, second
end

-- An event that may not exist on this client, registered quietly.
function Look.Listen(listener, event, unit)
    if unit then return (pcall(listener.RegisterUnitEvent, listener, event, unit)) end
    return (pcall(listener.RegisterEvent, listener, event))
end

---------------------------------------------------------------------------
-- Hooks (post-hooks only; each installed once)
---------------------------------------------------------------------------

local onceMethods = Look.Weak() -- object: { method name = true }
local onceGlobals, onceScripts = {}, Look.Weak()
Look.missingHooks = {} -- method or function name: true, for the debug report

local function Marked(book, owner, key)
    local marks = book[owner]
    if not marks then
        marks = {}
        book[owner] = marks
    end
    if marks[key] then return true end
    marks[key] = true
    return false
end

-- owner (optional, here and in Look.HookGlobal): a hook of that owner's
-- own, kept beside any other owner's on the same method.
function Look.Hook(object, methodName, after, owner)
    if type(object) ~= "table" or type(object[methodName]) ~= "function" then
        Look.missingHooks[methodName] = true
        return false
    end
    local mark = owner and (methodName .. "/" .. owner) or methodName
    if not Marked(onceMethods, object, mark) then hooksecurefunc(object, methodName, after) end
    return true
end

-- The same, only when the method is the object's own field (a mixin's method
-- copied onto the frame), never one it merely inherits.
function Look.HookOwn(object, methodName, after)
    if type(object) ~= "table" or type(rawget(object, methodName)) ~= "function" then return false end
    return Look.Hook(object, methodName, after)
end

function Look.HookGlobal(globalName, after, owner)
    local mark = owner and (globalName .. "/" .. owner) or globalName
    if onceGlobals[mark] then return true end
    if type(_G[globalName]) ~= "function" then
        Look.missingHooks[globalName] = true
        return false
    end
    onceGlobals[mark] = true
    hooksecurefunc(globalName, after)
    return true
end

-- One hook per frame and script: the first function given is the one kept,
-- so a caller wanting two things on the same script does both in one hook.
-- owner (optional): a hook of that owner's own, kept beside any other
-- owner's on the same script (two areas post-hooking one game frame).
function Look.HookScript(target, scriptName, after, owner)
    if type(target) ~= "table" or type(target.HookScript) ~= "function" then return false end
    local mark = owner and (scriptName .. "/" .. owner) or scriptName
    if not Marked(onceScripts, target, mark) then target:HookScript(scriptName, after) end
    return true
end

-- Look.Hook, and when the method isn't there, "label:method" goes to the
-- debug report's missing pieces too (Look.MissingPiece, below).
function Look.HookOrMiss(object, label, methodName, after, owner)
    if Look.Hook(object, methodName, after, owner) then return true end
    Look.MissingPiece(label .. ":" .. methodName)
    return false
end

---------------------------------------------------------------------------
-- Regions: one-line setters
---------------------------------------------------------------------------

-- One anchor, for EraUI's own frames and the game's plain regions (never an
-- Edit Mode frame: Look.Place below).
function Look.Pin(region, point, relative, relativePoint, x, y)
    region:ClearAllPoints()
    region:SetPoint(point, relative, relativePoint or point, x or 0, y or 0)
end

function Look.Fill(region, owner)
    region:ClearAllPoints()
    region:SetAllPoints(owner)
end

-- Inside the owner, each side in by its own amount (left, top, right, bottom).
function Look.Inside(region, owner, left, top, right, bottom)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", owner, "TOPLEFT", left, -top)
    region:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -right, bottom)
end

function Look.Crop(texture, left, right, top, bottom)
    texture:SetTexCoord(left, right, top, bottom)
end

function Look.Alpha(region, alpha)
    if region and region.SetAlpha then region:SetAlpha(alpha) end
end

function Look.Fade(region)
    Look.Alpha(region, 0)
end

-- Shown or hidden, touching the region only when that changes.
function Look.Shown(region, wanted)
    if not region then return end
    wanted = wanted and true or false
    if (region:IsShown() and true or false) ~= wanted then region:SetShown(wanted) end
end

function Look.EachRegion(owner, fn)
    if not owner or type(owner.GetRegions) ~= "function" then return end
    for _, piece in ipairs({ owner:GetRegions() }) do fn(piece) end
end

-- A frame of EraUI's own, set up from a short description: name, size
-- { w, h }, strata, level, mouse, wheel, drag (button), movable, clamped,
-- hidden.
function Look.Build(kind, parent, template, setup)
    setup = setup or {}
    local made = CreateFrame(kind, setup.name, parent, template)
    if setup.size then made:SetSize(setup.size[1], setup.size[2]) end
    if setup.strata then made:SetFrameStrata(setup.strata) end
    if setup.level then made:SetFrameLevel(setup.level) end
    if setup.movable then made:SetMovable(true) end
    if setup.clamped then made:SetClampedToScreen(true) end
    if setup.mouse then made:EnableMouse(true) end
    if setup.wheel then made:EnableMouseWheel(true) end
    if setup.drag then made:RegisterForDrag(setup.drag) end
    if setup.hidden then made:Hide() end
    return made
end

function Look.Label(owner, font, layer)
    return owner:CreateFontString(nil, layer or "ARTWORK", font)
end

-- EraUI's own texture on a frame for one purpose ("ring", "plate"...): made
-- the first time it's asked for, the same texture every time after. The
-- record is EraUI's, weak-keyed by the frame, never a key on the frame.
-- Layer and sublevel count only when it is made.
local ownPieces = Look.Weak()

function Look.OwnTexture(owner, purpose, layer, sublevel)
    local pieces = ownPieces[owner]
    if not pieces then
        pieces = {}
        ownPieces[owner] = pieces
    end
    local piece = pieces[purpose]
    if not piece then
        piece = owner:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
        pieces[purpose] = piece
    end
    return piece
end

-- The texture made for (frame, purpose), or nil; never makes one.
function Look.OwnPiece(owner, purpose)
    local pieces = owner and ownPieces[owner]
    return pieces and pieces[purpose] or nil
end

---------------------------------------------------------------------------
-- Settings and the engine
---------------------------------------------------------------------------

function Look.Setting(key)
    return EraUI:GetSetting(key)
end

function Look.Enabled()
    return EraUI:GetSetting("enabled") ~= false
end

function Look.InFight()
    return InCombatLockdown ~= nil and InCombatLockdown() and true or false
end

-- "point,relPoint,x,y", x and y to one decimal: how the micro menu's own
-- place is kept in the settings mirror (microPosText).
function Look.EncodePlace(place)
    if type(place) ~= "table" then return "" end
    local x, y = tonumber(place[3]), tonumber(place[4])
    if type(place[1]) ~= "string" or type(place[2]) ~= "string" or not x or not y then return "" end
    return string.format("%s,%s,%.1f,%.1f", place[1], place[2], x, y)
end

function Look.DecodePlace(text)
    if type(text) ~= "string" then return nil end
    local point, relativePoint, x, y = text:match("^(%u+),(%u+),(%-?[%d%.]+),(%-?[%d%.]+)$")
    x, y = tonumber(x), tonumber(y)
    if not point or not x or not y then return nil end
    return { point, relativePoint, x, y }
end

-- The micro menu's place, read back from its text when the table was lost.
function Look.MicroPlace()
    local saved = ns.db
    if not saved then return nil end
    if type(saved.microPos) ~= "table" and saved.microPosText and saved.microPosText ~= "" then
        saved.microPos = Look.DecodePlace(saved.microPosText)
    end
    return type(saved.microPos) == "table" and saved.microPos or nil
end

-- Writes the Classic settings to their mirror (the engine's own save, which
-- Core/Integration.lua extends), with the micro menu's place as text first.
function Look.Save()
    local saved = ns.db
    if saved then saved.microPosText = Look.EncodePlace(saved.microPos) end
    if type(ns.MirrorSave) == "function" then Look.Try(ns.MirrorSave) end
end

-- A full pass on the next frame (the engine's queue).
function Look.Queue()
    if type(ns.QueueApply) == "function" then ns.QueueApply() end
end

-- One shared OnUpdate for the look's periodic checks. every: seconds, or a
-- function giving them (0: every frame). A task that errors is reported once
-- and keeps running.
local tasks, ticker = {}, nil

local function RunTasks(_, elapsed)
    for i = 1, #tasks do
        local task = tasks[i]
        task.waited = task.waited + elapsed
        local every = task.every
        if type(every) == "function" then every = every() end
        if task.waited >= (every or 0) then
            local waited = task.waited
            task.waited = 0
            local fine, problem = pcall(task.run, waited)
            if not fine and not task.told then
                task.told = true
                Report(false, problem)
            end
        end
    end
end

function Look.Every(every, run)
    tasks[#tasks + 1] = { every = every, run = run, waited = 0 }
    if not ticker then
        ticker = CreateFrame("Frame")
        ticker:SetScript("OnUpdate", RunTasks)
    end
end

-- A developer-only log line; nothing happens unless a dev tool listens.
function Look.Note(line)
    if type(ns.Persist) == "function" then pcall(ns.Persist, "Look: " .. tostring(line)) end
end

---------------------------------------------------------------------------
-- Art
---------------------------------------------------------------------------

-- key: { client = the game's file, bundled = EraUI's copy, theme = Dark
-- Mode's key, bundledFirst = prefer the copy }
Look.ART = {}
Look.artResults = {} -- key: "ok", "fallback" or "missing" (debug report)

function Look.DefineArt(key, client, bundled, theme, bundledFirst)
    Look.ART[key] = { client = client, bundled = bundled and (Look.MEDIA .. bundled) or nil, theme = theme,
        bundledFirst = bundledFirst and true or false }
end

local function PathOrder(art)
    local saved = ns.db
    if art.bundledFirst or (saved and saved.textureSource == "bundled") then return art.bundled, art.client end
    return art.client, art.bundled
end

local function Took(texture, path)
    return path ~= nil and texture:SetTexture(path) ~= false
end

-- A texture given the first file, else the second when the game refuses
-- the first: "ok", "fallback" or "missing" (both refused).
function Look.PutFile(texture, first, second)
    return (Took(texture, first) and "ok") or (Took(texture, second) and "fallback") or "missing"
end

-- Puts a piece of art on a texture: the preferred file, else the other, then
-- Dark Mode's tint for frame art. Returns true when a file was set.
function Look.Art(texture, key)
    local art = Look.ART[key]
    if not texture or not art then return false end
    local first, second = PathOrder(art)
    local outcome = Look.PutFile(texture, first, second)
    Look.artResults[key] = outcome
    if outcome ~= "missing" and art.theme and type(ns.ThemeTexture) == "function" then
        ns.ThemeTexture(texture, art.theme)
    end
    return outcome ~= "missing"
end

-- A button's state texture wearing a piece of art. A button with no texture
-- for that state yet is given one first, from whichever file the art has (the
-- game refuses nil: EraUI's own World Map button has only a bundled file).
-- Returns the texture.
function Look.StateArt(owner, state, key)
    if not owner then return nil end
    local read, give = owner["Get" .. state .. "Texture"], owner["Set" .. state .. "Texture"]
    if type(read) ~= "function" then return nil end
    local face = read(owner)
    if not face and type(give) == "function" and Look.ART[key] then
        local first, second = PathOrder(Look.ART[key])
        local path = first or second
        if path == nil then return nil end
        give(owner, path)
        face = read(owner)
    end
    if face then Look.Art(face, key) end
    return face
end

-- The 1.x art the look wears. Dark Mode's keys (the last name) are the ones
-- Core/Appearance.lua darkens: frame art only, never icons or highlights.
do
    local BAR, BUTTONS = "Interface\\MainMenuBar\\", "Interface\\Buttons\\"
    local define = Look.DefineArt
    define("dwarf", BAR .. "UI-MainMenuBar-Dwarf", "UI-MainMenuBar-Dwarf", "barBody")
    define("keyring", BAR .. "UI-MainMenuBar-KeyRing", "UI-MainMenuBar-KeyRing", "barKeyring")
    -- The gryphons: Dark Mode gives "endCap" half the Darkness (Core/Appearance.lua).
    define("endCap", BAR .. "UI-MainMenuBar-EndCap-Dwarf", "UI-MainMenuBar-EndCap-Dwarf", "endCap")
    define("maxLevel", BAR .. "UI-MainMenuBar-MaxLevel", "UI-MainMenuBar-MaxLevel", "maxLevel")
    define("repStrip", "Interface\\PaperDollInfoFrame\\UI-ReputationWatchBar", "UI-ReputationWatchBar", "repBar")
    define("statusFill", nil, "UI-StatusBar-Flat.tga")
    define("tickNormal", BAR .. "UI-ExhaustionTickNormal")
    define("tickHighlight", BAR .. "UI-ExhaustionTickHighlight")
    define("slotEmpty", BUTTONS .. "UI-Quickslot", "UI-Quickslot", "slotEmpty")
    define("slotNormal", BUTTONS .. "UI-Quickslot2", "UI-Quickslot2", "slotNormal")
    define("slotPushed", BUTTONS .. "UI-Quickslot-Depress", "UI-Quickslot-Depress")
    define("slotFlash", BUTTONS .. "UI-QuickslotRed", "UI-QuickslotRed")
    define("slotHighlight", BUTTONS .. "ButtonHilight-Square", "ButtonHilight-Square")
    define("slotChecked", BUTTONS .. "CheckButtonHilight", "CheckButtonHilight")
    define("slotBorder", BUTTONS .. "UI-ActionButton-Border", "UI-ActionButton-Border")
    define("backpack", BUTTONS .. "Button-Backpack-Up", "Button-Backpack-Up")
    define("bagFrame", "Interface\\Common\\WhiteIconFrame")
    define("reagentRing", "Interface\\Minimap\\MiniMap-TrackingBorder", "MiniMap-TrackingBorder")
    define("microHighlight", BUTTONS .. "UI-MicroButton-Hilight", "UI-MicroButton-Hilight")
    for suffix, key in pairs({ [""] = "keyRingUp", ["-Down"] = "keyRingDown", ["-Highlight"] = "keyRingHighlight" }) do
        define(key, BUTTONS .. "UI-Button-KeyRing" .. suffix, "UI-Button-KeyRing" .. suffix)
    end
    local pageStates = Look.Words("Up Down Disabled Highlight")
    for _, way in ipairs({ "Up", "Down" }) do
        for _, look in ipairs(pageStates) do
            local file = "UI-MainMenu-Scroll" .. way .. "Button-" .. look
            define("page" .. way .. look, BAR .. file, file)
        end
    end
    -- Micro button sheets: the game's name for each, and the bundled copy's
    -- (the client's own Socials file is a guild banner now: the copy first).
    local microStates = Look.Words("Up Down Disabled")
    for sheet in ("Abilities Spellbook Talents Achievement Quest Socials LFG Mounts EJ Help BStore MainMenu"):gmatch("%S+") do
        for _, look in ipairs(microStates) do
            define("micro" .. sheet .. look, BUTTONS .. "UI-MicroButton-" .. sheet .. "-" .. look,
                "UI-MicroButton-" .. sheet:lower() .. "-" .. look:lower(), nil, sheet == "Socials")
        end
    end
    for _, look in ipairs(microStates) do
        define("microWorld" .. look, nil, "UI-MicroButton-World-" .. look:lower())
        local portraitFile = "UI-MicroButtonCharacter-" .. (look == "Down" and "Down" or "Up")
        define("microCharacter" .. look, BUTTONS .. portraitFile, portraitFile)
    end
end

-- The unit frames' 1.x art (and the combo points'). Each key is also its Dark
-- Mode key: Core/Appearance.lua tints only the frame art among them.
do
    local folders = {
        ["Interface\\TargetingFrame\\"] = [[targetingFrame:UI-TargetingFrame targetingElite:UI-TargetingFrame-Elite
            targetingRare:UI-TargetingFrame-Rare targetingRareElite:UI-TargetingFrame-Rare-Elite
            targetingMinus:UI-TargetingFrame-Minus targetingFlash:UI-TargetingFrame-Flash
            targetingMinusFlash:UI-TargetingFrame-Minus-Flash levelBackground:UI-TargetingFrame-LevelBackground
            skull:UI-TargetingFrame-Skull targetOfTarget:UI-TargetofTargetFrame smallTargetingFrame:UI-SmallTargetingFrame
            partyFrame:UI-PartyFrame partyFlash:UI-PartyFrame-Flash petAttackStatus:UI-Player-AttackStatus
            questBadge:PortraitQuestBadge statusBar:UI-StatusBar]],
        ["Interface\\CharacterFrame\\"] = "portraitMask:TempPortraitAlphaMask stateIcon:UI-StateIcon playerStatus:UI-Player-Status",
        ["Interface\\GroupFrame\\"] = "leaderIcon:UI-Group-LeaderIcon",
        ["Interface\\ComboFrame\\"] = "comboPoint:ComboPoint",
    }
    for folder, list in pairs(folders) do
        for _, pair in ipairs(Look.Words(list)) do
            local key, file = pair:match("^(%w+):(.+)$")
            Look.DefineArt(key, folder .. file, file, key)
        end
    end
    -- The client's own white square, the same either way (no bundled copy).
    local square = "Interface\\Buttons\\WHITE8X8"
    Look.ART.statusBarSolid = { client = square, bundled = square, theme = "statusBarSolid", bundledFirst = false }
end

-- The file a piece of art would be set from first (a status bar's fill takes
-- a path, with no fallback).
function Look.FirstPath(key)
    local art = Look.ART[key]
    if not art then return nil end
    return (PathOrder(art))
end

---------------------------------------------------------------------------
-- Bars, colours and the 1.x rules (the unit frames, later the cast bars)
---------------------------------------------------------------------------

-- A chain of keys from a frame ("PlayerFrameContent", "...Main"...), or nil
-- as soon as one is missing.
function Look.Path(owner, ...)
    local here = owner
    for i = 1, select("#", ...) do
        if type(here) ~= "table" then return nil end
        here = here[(select(i, ...))]
    end
    return here
end

-- A piece this client lacks, named once for the debug report (the same
-- record as the namespace's missing pieces, Look/BaseNames.lua; a test's own
-- stand-in for ns.MissingPiece is told too).
Look.missingPieces = {}
function Look.MissingPiece(name)
    if Look.missingPieces[name] then return end
    Look.missingPieces[name] = true
    local told = ns.MissingPiece
    if type(told) == "function" and told ~= Look.MissingPiece then pcall(told, name) end
end

function Look.FlatBars()
    return EraUI:GetSetting("flatBars") == true
end

-- A bar's fill: Flat Bars' solid square while it's on, else the given art.
function Look.BarFill(key)
    if Look.FlatBars() then return Look.FirstPath("statusBarSolid") end
    return Look.FirstPath(key or "statusBar")
end

-- Changes a bar's fill and nothing else: its colour is read first and put
-- back after (when it can be read), so it never depends on the game keeping
-- it through a new texture.
function Look.Refill(bar, paint)
    local r, g, b, a = bar:GetStatusBarColor()
    paint(bar)
    if Look.Number(r) and Look.Number(g) and Look.Number(b) and not Look.Secret(a) then
        bar:SetStatusBarColor(r, g, b, a)
    end
end

-- A bar the game guards in a fight (EraUI waits for the fight's end).
function Look.HeldInFight(bar)
    return Look.InFight() and bar ~= nil and bar:IsProtected() == true
end

-- The 1.x power colours: token, red, green, blue.
local POWER_RGB = {}
for token, r, g, b in ([[MANA 0 0 1  RAGE 1 0 0  FOCUS 1 0.5 0.25  ENERGY 1 1 0  RUNIC_POWER 0 0.82 1
    LUNAR_POWER 0.3 0.52 0.9  MAELSTROM 0 0.5 1  INSANITY 0.4 0 0.8  FURY 0.788 0.259 0.992  PAIN 1 0.61 0
    AMMOSLOT 0.8 0.6 0  FUEL 0 0.55 0.5]]):gmatch("(%u[%u_]*)%s+([%d.]+)%s+([%d.]+)%s+([%d.]+)") do
    POWER_RGB[token] = { tonumber(r), tonumber(g), tonumber(b) }
end

local function BlizzardPowerColour(token, kind)
    local colours = type(PowerBarColor) == "table" and PowerBarColor or nil
    local found = colours and ((type(token) == "string" and colours[token]) or (kind ~= nil and colours[kind]))
    if type(found) == "table" and found.r then return found.r, found.g, found.b end
end

-- The 1.x colour of a unit's power, by its token; blue when unknown or secret.
function Look.PowerColor(unit)
    local kind, token, altR, altG, altB = UnitPowerType(unit)
    if Look.Secret(kind) or Look.Secret(token) then return 0, 0, 1 end
    local rgb = type(token) == "string" and POWER_RGB[token]
    if rgb then return rgb[1], rgb[2], rgb[3] end
    if Look.Number(altR) and Look.Number(altG) and Look.Number(altB) then return altR, altG, altB end
    local r, g, b = BlizzardPowerColour(token, kind)
    if r then return r, g, b end
    return 0, 0, 1
end

-- Green, or a player's class colour while "Class colored unit frames" is on.
function Look.HealthColor(unit)
    if Look.Saved().classColorHealth == true and unit then
        local person = UnitIsPlayer(unit)
        if not Look.Secret(person) and person then
            local _, class = UnitClass(unit)
            local colour = not Look.Secret(class) and type(class) == "string" and RAID_CLASS_COLORS
                and RAID_CLASS_COLORS[class]
            if colour then return colour.r, colour.g, colour.b end
        end
    end
    return 0, 1, 0
end

-- 1.x hid the level of anything more than ten above you behind a skull. A
-- boss level (below 0) is a skull before anything else is asked, a friend
-- included; otherwise friends never, and a hidden answer keeps the rule going.
function Look.SkullLevel(level, unit)
    level = Look.Number(level)
    if not level then return false end
    if level < 0 then return true end
    if unit then
        local hostile = UnitCanAttack("player", unit)
        if not Look.Secret(hostile) and not hostile then return false end
    end
    local mine = Look.Number(UnitLevel("player"))
    if not mine then return false end
    return level > mine + 10
end

-- The modern level and PvP circles on a frame (any texture whose atlas
-- names a "smallcircle"), faded.
function Look.FadeCircles(owner)
    Look.EachRegion(owner, function(piece)
        local read = piece.GetAtlas
        if type(read) ~= "function" then return end
        local fine, atlas = pcall(read, piece)
        if fine and type(atlas) == "string" and not Look.Secret(atlas) and atlas:lower():find("smallcircle", 1, true) then
            Look.Fade(piece)
        end
    end)
end

---------------------------------------------------------------------------
-- Frames and Edit Mode
---------------------------------------------------------------------------

-- Action Bar 1 under either of its names.
function Look.MainBar()
    return _G.MainActionBar or _G.MainMenuBar
end

function Look.EditModeOpen()
    local fine, open = Look.Ask(EditModeManagerFrame, "IsEditModeActive")
    return fine and open == true
end

-- Edit Mode frames are moved only through their plain ...Base methods, which
-- write no snap record; other frames through their own.
function Look.ClearPoints(frame)
    local clear = frame.ClearAllPointsBase or frame.ClearAllPoints
    clear(frame)
end

function Look.AddPoint(frame, point, relative, relativePoint, x, y)
    local set = frame.SetPointBase or frame.SetPoint
    set(frame, point, relative, relativePoint, x, y)
end

-- One anchor on an Edit Mode frame, never in a fight. True when written.
function Look.Place(frame, point, relative, relativePoint, x, y)
    if not frame or Look.InFight() then return false end
    Look.ClearPoints(frame)
    Look.AddPoint(frame, point, relative, relativePoint, x, y)
    return true
end

function Look.Rescale(frame, scale)
    if not frame or Look.InFight() then return false end
    local now = Look.Number(frame:GetScale())
    if now and math.abs(now - scale) < 0.0001 then return false end
    local set = frame.SetScaleBase or frame.SetScale
    set(frame, scale)
    return true
end

-- True, false, or nil when the game won't say (missing, an error, a secret,
-- or a frame Edit Mode hasn't set up yet: it answers false until then).
function Look.InDefaultPosition(frame)
    local asked, ready = Look.Ask(frame, "IsInitialized")
    if asked and ready == false then return nil end
    local fine, answer = Look.Ask(frame, "IsInDefaultPosition")
    if not fine or Look.Secret(answer) then return nil end
    return answer == true
end

-- An Edit Mode setting's value, or nil.
function Look.EditSetting(frame, which)
    if which == nil then return nil end
    local fine, value = Look.Ask(frame, "GetSettingValue", which)
    return fine and Look.Number(value) or nil
end

function Look.LayoutName()
    local fine, layout = Look.Ask(EditModeManagerFrame, "GetActiveLayoutInfo")
    local called = fine and type(layout) == "table" and layout.layoutName
    return (type(called) == "string" and called ~= "") and called or nil
end

local function AnchorName(relative)
    if type(relative) == "string" then return relative end
    if type(relative) ~= "table" or not relative.GetName then return nil end
    local fine, called = pcall(relative.GetName, relative)
    return fine and called or nil
end
Look.AnchorName = AnchorName

-- The frame's Edit Mode anchor (from its layout record), read only.
function Look.EditAnchor(frame)
    local record = type(frame) == "table" and rawget(frame, "systemInfo")
    local anchor = type(record) == "table" and record.anchorInfo
    return type(anchor) == "table" and anchor or nil
end

-- The pin EraUI saved for this frame in the active layout, if any.
function Look.SavedPin(frame)
    local saved, layout = ns.db, Look.LayoutName()
    local pins = saved and type(saved.barPins) == "table" and layout and saved.barPins[layout]
    local called = frame and frame.GetName and frame:GetName()
    return (type(pins) == "table" and called) and pins[called] or nil
end

local function Within(a, b)
    local first, second = Look.Number(a), Look.Number(b)
    return first ~= nil and second ~= nil and math.abs(first - second) <= 0.5
end

-- Pinned by EraUI: the frame's Edit Mode anchor is EraUI's own pin (to
-- UIParent with different points, an old BOTTOM-to-BOTTOM pin before pins
-- were shaped, or exactly the pin saved for this layout).
function Look.PinnedByEraUI(frame)
    local anchor = Look.EditAnchor(frame)
    if not anchor or AnchorName(anchor.relativeTo) ~= "UIParent" then return false end
    local from, to = anchor.point, anchor.relativePoint
    if type(from) ~= "string" or type(to) ~= "string" then return false end
    if from ~= to then return true end
    if not (ns.db and ns.db.pinShape) and from == "BOTTOM" then return true end
    local pin = Look.SavedPin(frame)
    return type(pin) == "table" and pin[1] == from and pin[2] == to
        and Within(anchor.offsetX, pin[3]) and Within(anchor.offsetY, pin[4])
end

-- At the anchor Edit Mode's preset layout gives the frame.
local function AtPreset(frame)
    local presets, anchor = EditModePresetLayoutManager, Look.EditAnchor(frame)
    if not anchor or type(presets) ~= "table" or type(presets.GetDefaultSystemAnchorInfo) ~= "function" then return false end
    local fine, preset = pcall(presets.GetDefaultSystemAnchorInfo, presets, frame.system, frame.systemIndex)
    if not fine or type(preset) ~= "table" then return false end
    return anchor.point == preset.point and anchor.relativePoint == preset.relativePoint
        and AnchorName(anchor.relativeTo) == AnchorName(preset.relativeTo)
        and Within(anchor.offsetX, preset.offsetX) and Within(anchor.offsetY, preset.offsetY)
end

-- Moved in Edit Mode: out of its default position, not EraUI's own pin, and
-- not simply at the preset's default anchor.
function Look.Moved(frame)
    return frame ~= nil and Look.InDefaultPosition(frame) == false and not Look.PinnedByEraUI(frame)
        and not AtPreset(frame)
end

-- A frame's rect in UIParent units: left, bottom, right, top (or nil).
function Look.Rect(frame)
    if not frame or not frame.GetLeft then return nil end
    local edges = { Look.Number(frame:GetLeft()), Look.Number(frame:GetBottom()), Look.Number(frame:GetRight()),
        Look.Number(frame:GetTop()) }
    local own = Look.Number(frame:GetEffectiveScale())
    local root = UIParent and Look.Number(UIParent:GetEffectiveScale())
    if not (edges[1] and edges[2] and edges[3] and edges[4] and own and root) or own <= 0 or root <= 0 then return nil end
    local f = own / root
    return edges[1] * f, edges[2] * f, edges[3] * f, edges[4] * f
end

---------------------------------------------------------------------------
-- EraUI's own tooltip (never the game's GameTooltip)
---------------------------------------------------------------------------

local tip

local function TipFrame()
    if tip then return tip end
    tip = Look.Build("Frame", UIParent, "BackdropTemplate", { size = { 160, 24 }, strata = "TOOLTIP", clamped = true,
        hidden = true })
    if tip.SetBackdrop then
        tip:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        tip:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
        tip:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
    end
    tip.rows, tip.rightRows = {}, {}
    return tip
end

-- The right-hand text of a two-column line, kept to the tip's right edge.
local function RightText(frame, i, right, depth)
    local text = frame.rightRows[i]
    if not right then
        if text then text:Hide() end
        return 0
    end
    if not text then
        text = Look.Label(frame, "GameFontNormalSmall", "OVERLAY")
        frame.rightRows[i] = text
    end
    Look.Pin(text, "TOPRIGHT", frame, "TOPRIGHT", -9, -depth)
    if text.SetJustifyH then text:SetJustifyH("RIGHT") end
    text:SetText(right[1])
    text:SetTextColor(right[2] or 1, right[3] or 1, right[4] or 1)
    text:Show()
    return (Look.Number(text:GetStringWidth()) or 40) + 12
end

-- rows: { { text, r, g, b, wrap, right = { text, r, g, b } }, ... }; side
-- "RIGHT" (beside) or "TOP" (above). wrap: a width the line wraps at (none:
-- one line, its own width). right: a second text in the same line, kept to
-- the tip's right edge (the line then never wraps).
function Look.ShowTip(owner, side, rows)
    if not owner or type(rows) ~= "table" or #rows == 0 then return end
    local frame = TipFrame()
    local widest, depth = 0, 6
    for i, row in ipairs(rows) do
        local line = frame.rows[i] or Look.Label(frame, i == 1 and "GameFontHighlight" or "GameFontNormalSmall", "OVERLAY")
        frame.rows[i] = line
        Look.Pin(line, "TOPLEFT", frame, "TOPLEFT", 9, -depth)
        local right = type(row.right) == "table" and row.right or nil
        local wrap = not right and Look.Number(row[5]) or nil
        line:SetWidth(wrap or 0)
        if line.SetJustifyH then line:SetJustifyH("LEFT") end
        line:SetText(row[1])
        line:SetTextColor(row[2] or 1, row[3] or 1, row[4] or 1)
        line:Show()
        local across = Look.Number(line:GetStringWidth()) or 120
        across = (wrap and math.min(wrap, across) or across) + RightText(frame, i, right, depth)
        widest = math.max(widest, across)
        depth = depth + (Look.Number(line:GetStringHeight()) or 12) + 2
    end
    for i = #rows + 1, #frame.rows do frame.rows[i]:Hide() end
    -- Right texts are made only for the lines that have one, so their list
    -- has gaps (and its # can stop short): each one past the last line is
    -- put away by walking them all.
    for i in pairs(frame.rightRows) do
        if i > #rows then RightText(frame, i, nil) end
    end
    frame:SetSize(widest + 18, depth + 6)
    if side == "TOP" then Look.Pin(frame, "BOTTOM", owner, "TOP", 0, 4) else Look.Pin(frame, "LEFT", owner, "RIGHT", 4, 0) end
    frame.owner = owner
    frame:Show()
end

function Look.HideTip(owner)
    if tip and (owner == nil or tip.owner == owner) then
        tip.owner = nil
        tip:Hide()
    end
end

-- The frame the shown tip belongs to, or nil.
function Look.TipOwner()
    if tip and tip:IsShown() then return tip.owner end
    return nil
end

---------------------------------------------------------------------------
-- Pieces the Classic windows share (the character sheet first): labels of
-- EraUI's own, tiled art, the red X, check boxes, the red panel button, the
-- label-frame drop down and its list, thin scroll bars with the 1.x knob,
-- the stone bar and the portrait framing. Every "done once" mark is kept
-- in a weak table here, never on the game's widget.
---------------------------------------------------------------------------

do
    local BUTTONS = "Interface\\Buttons\\"
    local define = Look.DefineArt
    for state, key in pairs({ Up = "closeUp", Down = "closeDown", Disabled = "closeDisabled", Highlight = "closeHighlight" }) do
        define(key, BUTTONS .. "UI-Panel-MinimizeButton-" .. state, "UI-Panel-MinimizeButton-" .. state)
    end
    -- These exist only as EraUI's copies.
    for _, way in ipairs({ "Up", "Down" }) do
        for _, look in ipairs({ "Up", "Down", "Disabled", "Highlight" }) do
            define("scroll" .. way .. "Button" .. look, nil, "UI-ScrollBar-Scroll" .. way .. "Button-" .. look, nil, true)
        end
    end
    define("scrollKnob", nil, "UI-ScrollBar-Knob", "scrollKnob", true)
    define("rockBg", nil, "UI-Background-Rock", "rockBg", true)
    define("marbleBg", nil, "UI-Background-Marble", "marbleBg", true)
    define("charScrollBar", nil, "UI-Character-ScrollBar", "charScrollBar", true)
end

-- EraUI's own font string on a frame for one purpose (as Look.OwnTexture:
-- the same one every time, recorded beside the frame).
function Look.OwnLabel(owner, purpose, font, layer)
    local pieces = ownPieces[owner]
    if not pieces then
        pieces = {}
        ownPieces[owner] = pieces
    end
    local label = pieces[purpose]
    if not label then
        label = owner:CreateFontString(nil, layer or "ARTWORK", font)
        pieces[purpose] = label
    end
    return label
end

-- A piece of art tiled both ways (stone, marble), with the same fallback,
-- record and Dark Mode tint as Look.Art.
function Look.TileArt(texture, key)
    local art = Look.ART[key]
    if not texture or not art then return false end
    local first, second = PathOrder(art)
    local function Tiled(path) return path ~= nil and texture:SetTexture(path, "REPEAT", "REPEAT") ~= false end
    local outcome = (Tiled(first) and "ok") or (Tiled(second) and "fallback") or "missing"
    Look.artResults[key] = outcome
    if texture.SetHorizTile then texture:SetHorizTile(true) end
    if texture.SetVertTile then texture:SetVertTile(true) end
    if outcome ~= "missing" and art.theme and type(ns.ThemeTexture) == "function" then
        ns.ThemeTexture(texture, art.theme)
    end
    return outcome ~= "missing"
end

-- A button state's texture filling the button with the whole file (or the
-- given crop), the glow additive.
local function FillFace(button, state, crop)
    local read = button["Get" .. state .. "Texture"]
    local face = type(read) == "function" and read(button)
    if not face then return nil end
    Look.Fill(face, button)
    if crop then Look.Crop(face, crop[1], crop[2], crop[3], crop[4]) else Look.Crop(face, 0, 1, 0, 1) end
    if state == "Highlight" then face:SetBlendMode("ADD") end
    return face
end

-- The 1.x red X: 32 x 32, every state from the minimise-button sheets,
-- handed to Dark Windows. Never moved here; callers place it.
local CLOSE_STATES = { Normal = "closeUp", Pushed = "closeDown", Disabled = "closeDisabled", Highlight = "closeHighlight" }
function Look.SkinCloseButton(button)
    if not button then return end
    button:SetSize(32, 32)
    for state, key in pairs(CLOSE_STATES) do
        if Look.StateArt(button, state, key) then FillFace(button, state) end
    end
    if ns.DarkCloseButton then ns.DarkCloseButton(button) end
end

-- The 1.x check box art on a check button.
local checksDone = Look.Weak()
local CHECK_FACES = { { "Normal", "Up" }, { "Pushed", "Down" }, { "Highlight", "Highlight" }, { "Checked", "Check" },
    { "DisabledChecked", "Check-Disabled" } }
function Look.SkinCheckBox(check)
    if not check then return end
    if not checksDone[check] then
        checksDone[check] = true
        Look.Fade(check.HoverBackground)
    end
    for _, face in ipairs(CHECK_FACES) do
        local give = check["Set" .. face[1] .. "Texture"]
        if type(give) == "function" then
            give(check, "Interface\\Buttons\\UI-CheckBox-" .. face[2])
            FillFace(check, face[1])
        end
    end
end

-- The red 1.x panel button, made by EraUI: (width, or 96) x 22, its own
-- label (OVERLAY) in the gold font centred one down and set as the button's
-- text, handed to Dark Windows. Should the client refuse the art, the game's
-- own red button stands in (darkened the same way). Also the Classic
-- namespace's PanelButton (Look/ChromeKit.lua).
local PANEL_STATES = { { "Normal", "Up" }, { "Pushed", "Down" }, { "Disabled", "Disabled" }, { "Highlight", "Highlight" } }
local PANEL_CROP = { 0, 0.625, 0, 0.6875 }
function Look.PanelButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 96, 22)
    for _, state in ipairs(PANEL_STATES) do
        local path = "Interface\\Buttons\\UI-Panel-Button-" .. state[2]
        button["Set" .. state[1] .. "Texture"](button, path)
        local face = FillFace(button, state[1], PANEL_CROP)
        if not face or face:SetTexture(path) == false then
            button:Hide()
            local native = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
            if ns.DarkNativeButton then ns.DarkNativeButton(native) end
            native:SetSize(width or 96, 22)
            native:SetText(text)
            return native
        end
    end
    local gold = CreateFont and Look.GoldFont() or GameFontNormal
    if type(button.SetFontString) == "function" then
        local label = Look.OwnLabel(button, "panelLabel", nil, "OVERLAY")
        if gold and label.SetFontObject then label:SetFontObject(gold) end
        Look.Pin(label, "CENTER", button, "CENTER", 0, -1)
        button:SetFontString(label)
    end
    button:SetNormalFontObject(gold)
    button:SetHighlightFontObject(GameFontHighlight)
    button:SetDisabledFontObject(GameFontDisable)
    button:SetText(text)
    local label = button:GetFontString()
    if label then Look.Pin(label, "CENTER", button, "CENTER", 0, -1) end
    if ns.DarkRedButton then ns.DarkRedButton(button) end
    return button
end

-- The same 1.x red art on a red button the game made (the bank's buying and
-- money buttons), once per button. Its Normal face goes on first: only when
-- the client takes that file are the game's own slices faded, so a refused
-- file never leaves a bare button. Handed to Dark Windows. True when worn.
local redWorn = Look.Weak()
local GAME_SLICES = Look.Words([[Left Right Center Middle TopLeft TopRight BottomLeft BottomRight TopMiddle
    MiddleLeft MiddleRight BottomMiddle MiddleMiddle]])
function Look.SkinRedButton(button)
    if not button or redWorn[button] ~= nil then return redWorn[button] == true end
    redWorn[button] = false
    for i, state in ipairs(PANEL_STATES) do
        local give = button["Set" .. state[1] .. "Texture"]
        if type(give) ~= "function" then return false end
        local path = "Interface\\Buttons\\UI-Panel-Button-" .. state[2]
        give(button, path)
        local face = FillFace(button, state[1], PANEL_CROP)
        local took = face ~= nil and face:SetTexture(path) ~= false
        if i == 1 then
            if not took then return false end
            for _, slice in ipairs(GAME_SLICES) do Look.Fade(button[slice]) end
        end
    end
    for setter, font in pairs({ SetNormalFontObject = GameFontNormal, SetHighlightFontObject = GameFontHighlight,
        SetDisabledFontObject = GameFontDisable }) do
        if type(button[setter]) == "function" and font then button[setter](button, font) end
    end
    redWorn[button] = true
    if ns.DarkRedButton then ns.DarkRedButton(button) end
    return true
end

-- EraUI's gold font: the game's normal font in the old gold (1, 0.82, 0)
-- whatever colour the client gives its own; small: the same from the game's
-- small font. Each made the first time it's asked for.
local goldFonts = {}
function Look.GoldFont(small)
    local which = small and "small" or "normal"
    if goldFonts[which] then return goldFonts[which] end
    local font = CreateFont(small and "EraUILookGoldSmall" or "EraUILookGold")
    local model = small and GameFontNormalSmall or GameFontNormal
    if model then
        if font.CopyFontObject then font:CopyFontObject(model) else font:SetFontObject(model) end
    end
    font:SetTextColor(1, 0.82, 0)
    goldFonts[which] = font
    return font
end

-- The old label-frame drop down drawn on any frame, its art reaching inset
-- (17 unless given) past the frame's edges. Returns the arrow.
local LABEL_FRAME = "Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame"
function Look.DressDropdown(frame, inset)
    inset = inset or 17
    local left = Look.OwnTexture(frame, "dropLeft", "BACKGROUND")
    local right = Look.OwnTexture(frame, "dropRight", "BACKGROUND")
    local middle = Look.OwnTexture(frame, "dropMiddle", "BACKGROUND")
    for piece, crop in pairs({ [left] = { 0, 0.1953125 }, [right] = { 0.8046875, 1 }, [middle] = { 0.1953125, 0.8046875 } }) do
        piece:SetTexture(LABEL_FRAME)
        Look.Crop(piece, crop[1], crop[2], 0, 1)
        piece:ClearAllPoints()
    end
    left:SetWidth(25)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", -inset, inset)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -inset, -inset)
    right:SetWidth(25)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", inset, inset)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", inset, -inset)
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    local arrow = Look.OwnTexture(frame, "dropArrow", "ARTWORK")
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    local glow = Look.OwnTexture(frame, "dropGlow", "HIGHLIGHT")
    glow:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    glow:SetBlendMode("ADD")
    for _, piece in ipairs({ arrow, glow }) do
        piece:SetSize(24, 24)
        Look.Pin(piece, "RIGHT", frame, "RIGHT", 1, 2)
    end
    return arrow
end

-- The list an old drop down opens. entries: { { label = text, pick =
-- function, chosen = function or nil }, ... }. Returns { frame, Toggle(owner),
-- Follow(frame) }. Closes on a click elsewhere, when the frame it follows
-- hides, and on Escape (the game's own list of windows, through the
-- engine's stand-in).
function Look.DropList(entries)
    local list = Look.Build("Frame", UIParent, "BackdropTemplate", { size = { 120, 44 }, strata = "FULLSCREEN_DIALOG",
        mouse = true, clamped = true, hidden = true })
    list:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    list:SetBackdropColor(1, 1, 1, 1)
    list:SetBackdropBorderColor(1, 1, 1, 1)
    if ns.DarkBackdrop then ns.DarkBackdrop(list) end
    local drop = { frame = list, marks = {} }
    local widest = 0
    for i, entry in ipairs(entries) do
        local row = Look.Build("Button", list, nil, { size = { 100, 16 } })
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 15, -14 - (i - 1) * 16)
        row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -15, -14 - (i - 1) * 16)
        local mark = Look.OwnTexture(row, "mark", "ARTWORK")
        mark:SetTexture("Interface\\Common\\UI-DropDownRadioChecks")
        mark:SetSize(16, 16)
        Look.Pin(mark, "LEFT", row, "LEFT", 0, 0)
        local label = Look.OwnLabel(row, "label", "GameFontHighlightSmall", "ARTWORK")
        Look.Pin(label, "LEFT", mark, "RIGHT", 4, 0)
        label:SetText(entry.label)
        widest = math.max(widest, math.ceil(Look.Number(label:GetStringWidth()) or 80))
        local glow = Look.OwnTexture(row, "glow", "HIGHLIGHT")
        glow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        glow:SetBlendMode("ADD")
        Look.Fill(glow, row)
        row:SetScript("OnClick", function()
            list:Hide()
            if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON) end
            Look.Try(entry.pick)
        end)
        drop.marks[i] = mark
    end
    list:SetSize(widest + 20 + 30, #entries * 16 + 28)
    Look.Listen(list, "GLOBAL_MOUSE_DOWN")
    list:SetScript("OnEvent", function()
        if not list:IsShown() or list:IsMouseOver() then return end
        if drop.owner and drop.owner:IsMouseOver() then return end
        list:Hide()
    end)
    if type(ns.CloseOnEscape) == "function" then ns.CloseOnEscape(list) end
    local followed = Look.Weak()
    function drop.Follow(frame)
        if not frame or followed[frame] then return end
        followed[frame] = true
        Look.HookScript(frame, "OnHide", function() list:Hide() end)
    end
    function drop.Toggle(owner)
        if list:IsShown() then
            list:Hide()
            return
        end
        drop.owner = owner
        for i, entry in ipairs(entries) do
            local chosen = type(entry.chosen) == "function" and entry.chosen()
            if chosen then Look.Crop(drop.marks[i], 0, 0.5, 0.5, 1) else Look.Crop(drop.marks[i], 0.5, 1, 0.5, 1) end
        end
        Look.Pin(list, "TOPLEFT", owner, "BOTTOMLEFT", 0, 6)
        list:Show()
        if list.Raise then list:Raise() end
    end
    return drop
end

-- The old round knob on a thin scroll bar, placed on the track from the
-- scroll fraction (the game's thumb is faded). reach: how far it may run
-- past the track's ends (3 unless set); nudge: added across.
local knobs = Look.Weak() -- bar: { knob, fraction, reach, nudge }

function Look.PlaceKnob(bar)
    local info = knobs[bar]
    local track = bar and bar.Track
    if not info or not track then return end
    local fine, scrollable = Look.Ask(bar, "HasScrollableExtent")
    if fine and scrollable == false then
        info.knob:Hide()
        return
    end
    local room = math.max(0, (Look.Number(track:GetHeight()) or 0) - 24)
    local arrow = bar.Back or bar.Forward or bar
    local arrowX, trackX = Look.Number((arrow:GetCenter())), Look.Number((track:GetCenter()))
    local across = (arrowX and trackX) and (arrowX - trackX) or 0
    Look.Pin(info.knob, "TOP", track, "TOP", across + info.nudge, info.reach - info.fraction * (room + 2 * info.reach))
    info.knob:Show()
end

function Look.Knob(bar, reach, nudge)
    local track = bar and bar.Track
    local thumb = track and track.Thumb
    if not thumb then return nil end
    local info = knobs[bar]
    if not info then
        Look.Fade(thumb.Begin)
        Look.Fade(thumb.Middle)
        Look.Fade(thumb.End)
        local knob = Look.OwnTexture(track, "knob", "ARTWORK")
        Look.Art(knob, "scrollKnob")
        knob:SetSize(18, 24)
        Look.Crop(knob, 0.2, 0.8, 0.125, 0.875)
        info = { knob = knob, fraction = 0, reach = 3, nudge = 0 }
        knobs[bar] = info
        local function Place() Look.PlaceKnob(bar) end
        Look.Hook(bar, "SetScrollPercentageInternal", function(_, fraction)
            fraction = Look.Number(fraction)
            if fraction then info.fraction = Look.Clamp(fraction, 0, 1) end
            Place()
        end)
        Look.Hook(bar, "Update", Place)
        Look.HookScript(track, "OnSizeChanged", Place)
    end
    info.reach, info.nudge = reach or info.reach, nudge or info.nudge
    Look.PlaceKnob(bar)
    return info.knob
end

-- A scroll bar a skin has taken: true the first time only (later skins
-- leave it alone).
local claimedBars = Look.Weak()
function Look.ClaimScrollBar(bar)
    if not bar or claimedBars[bar] then return false end
    claimedBars[bar] = true
    return true
end

-- A thin scroll bar in 1.x art: the track's pieces faded, a 16-wide thumb,
-- the 1.x arrows over the game's and the knob.
function Look.ThinScrollBar(bar)
    if not Look.ClaimScrollBar(bar) then return end
    local track = bar.Track
    if track then
        Look.Fade(track.Begin)
        Look.Fade(track.Middle)
        Look.Fade(track.End)
        if track.Thumb then track.Thumb:SetWidth(16) end
    end
    for _, pair in ipairs({ { bar.Back, "scrollUpButtonUp" }, { bar.Forward, "scrollDownButtonUp" } }) do
        local arrow, key = pair[1], pair[2]
        if arrow then
            Look.Fade(arrow.Texture)
            arrow:SetSize(16, 16)
            local face = Look.OwnTexture(arrow, "arrowArt", "ARTWORK")
            Look.Art(face, key)
            Look.Crop(face, 0.25, 0.75, 0.25, 0.75)
            face:ClearAllPoints()
            face:SetPoint("TOPLEFT", arrow, "TOPLEFT", 1, 0)
            face:SetPoint("BOTTOMRIGHT", arrow, "BOTTOMRIGHT", 1, 0)
            face:Show()
        end
    end
    Look.Knob(bar, nil, 1)
end

-- The stone's warm lift, and the light and dark edges drawn along it.
Look.STONE_TINT, Look.STONE_LIGHT, Look.STONE_DARK = { 1.25, 1.2, 1.1 }, { 0.52, 0.48, 0.40 }, { 0.06, 0.05, 0.04 }

-- A texture coloured { r, g, b }: its vertex colour, or (solid) a flat colour.
function Look.Tint(texture, rgb, solid)
    if solid then texture:SetColorTexture(rgb[1], rgb[2], rgb[3], 1) else texture:SetVertexColor(rgb[1], rgb[2], rgb[3]) end
end

-- A 6-tall stone strip with a light line along its top and a dark one along
-- its bottom (it divides a pane from what is above it).
function Look.StoneBar(parent)
    local bar = Look.Build("Frame", parent, nil, { size = { 100, 6 } })
    local stone = Look.OwnTexture(bar, "stone", "ARTWORK")
    -- The warm lift first: Dark Mode's grey (through the art lookup) then
    -- wins over it while Dark Mode is on.
    Look.Tint(stone, Look.STONE_TINT)
    Look.TileArt(stone, "rockBg")
    stone:SetPoint("TOPLEFT", 0, -1) -- one in from the top and bottom
    stone:SetPoint("BOTTOMRIGHT", 0, 1)
    for edge, colour in pairs({ TOP = Look.STONE_LIGHT, BOTTOM = Look.STONE_DARK }) do
        local line = Look.OwnTexture(bar, "line" .. edge, "OVERLAY")
        Look.Tint(line, colour, true)
        line:SetHeight(1)
        line:SetPoint(edge .. "LEFT", bar, edge .. "LEFT")
        line:SetPoint(edge .. "RIGHT", bar, edge .. "RIGHT")
    end
    return bar
end

-- A window's portrait kept framed in its round hole as the client swaps a
-- face, a piece of a sheet and a plain icon: an icon loses its own border
-- (10% off each side), a piece of a sheet is zoomed so the off-centre mask
-- cuts nothing it shouldn't, and EraUI's crop comes off anything that
-- isn't an icon. Checked at once and every 0.05 s while it shows.
local portraits, zooms = Look.Weak(), Look.Weak()

local function Near(a, b) return math.abs(a - b) <= 0.002 end

local function IconFile(texture)
    local fine, path = Look.Ask(texture, "GetTextureFilePath")
    if fine and type(path) == "string" and not Look.Secret(path) and not path:find("^FileData ID") then
        return path:lower():find("icons", 1, true) ~= nil
    end
    local asked, file = Look.Ask(texture, "GetTexture")
    if not asked or Look.Secret(file) then return false end
    -- A file ID is an icon; of the names, a render target or a unit's face
    -- isn't, anything from an icons folder is.
    if type(file) ~= "string" then return type(file) == "number" end
    local named = file:lower()
    return not (named:find("^rt") or named:find("^portrait")) and named:find("icons", 1, true) ~= nil
end

local function FramePortrait(texture)
    if not texture:IsVisible() then return end
    local corners = { texture:GetTexCoord() }
    local left, top, right, bottom = Look.Number(corners[1]), Look.Number(corners[2]), Look.Number(corners[7]),
        Look.Number(corners[8])
    if not (left and top and right and bottom) then return end
    local full = Near(left, 0) and Near(top, 0) and Near(right, 1) and Near(bottom, 1)
    local ours = Near(left, 0.1) and Near(top, 0.1) and Near(right, 0.9) and Near(bottom, 0.9)
    local icon = IconFile(texture)
    if full and icon then
        Look.Crop(texture, 0.1, 0.9, 0.1, 0.9)
    elseif ours and not icon then
        Look.Crop(texture, 0, 1, 0, 1)
    elseif not full and not ours then
        local zoom = zooms[texture]
        if zoom and Near(zoom[1], left) and Near(zoom[2], right) and Near(zoom[3], top) and Near(zoom[4], bottom) then return end
        if right <= left or bottom <= top then return end
        local wide, tall = right - left, bottom - top
        zoom = { left + wide * 0.1, right - wide * 0.1, top + tall * 0.16, bottom - tall * 0.06 }
        zooms[texture] = zoom
        Look.Crop(texture, zoom[1], zoom[2], zoom[3], zoom[4])
    end
end

local portraitTask = false
function Look.WatchPortrait(texture)
    if not texture then return end
    if portraits[texture] then
        Look.Try(FramePortrait, texture)
        return
    end
    if not portraitTask then
        portraitTask = true
        Look.Every(0.05, function()
            for watched in pairs(portraits) do pcall(FramePortrait, watched) end
        end)
    end
    portraits[texture] = true
    Look.Try(FramePortrait, texture)
end

---------------------------------------------------------------------------
-- EraUI's own 1.x scroll bar (a slider, its arrows standing outside it),
-- the character sheet's stone column behind it, and the iron-bordered inset
-- box. What a bar keeps (its arrows, step and top) lives in weak tables
-- here, never on the frame.
---------------------------------------------------------------------------

local sliders = Look.Weak() -- bar: { up, down, step, top, idle }
local ARROW_FACES = { { "Normal", "Up" }, { "Pushed", "Down" }, { "Disabled", "Disabled" }, { "Highlight", "Highlight" } }
local ARROW_CROP = { 0.25, 0.75, 0.25, 0.75 }

-- Up usable while the value is above 0, down while it is below the top.
local function ArrowsFollow(bar)
    local kept = sliders[bar]
    if not kept then return end
    local value = Look.Number(bar:GetValue()) or 0
    kept.up:SetEnabled(value > 0)
    kept.down:SetEnabled(value < kept.top)
end

-- One 16 x 16 arrow: the middle of its 32 x 32 sheets, a click moving the
-- bar by its step (sign -1 up, 1 down).
local function ScrollArrow(bar, way, sign)
    local arrow = Look.Build("Button", bar, nil, { size = { 16, 16 } })
    for _, face in ipairs(ARROW_FACES) do
        if Look.StateArt(arrow, face[1], "scroll" .. way .. "Button" .. face[2]) then FillFace(arrow, face[1], ARROW_CROP) end
    end
    arrow:SetScript("OnClick", function()
        local kept = sliders[bar]
        bar:SetValue((Look.Number(bar:GetValue()) or 0) + sign * (kept and kept.step or 1))
        if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON) end
    end)
    return arrow
end

-- A vertical bar 6 right of `area` and 16 in from its top and bottom, the
-- 1.x knob as its thumb, value step 1. onValue(value) runs on every change.
-- idle: hidden while there is nothing to scroll (else always shown).
function Look.ClassicScrollBar(parent, area, onValue, idle)
    local bar = Look.Build("Slider", parent, nil, { size = { 16, 100 } })
    bar:SetOrientation("VERTICAL")
    bar:SetPoint("TOPLEFT", area, "TOPRIGHT", 6, -16)
    bar:SetPoint("BOTTOMLEFT", area, "BOTTOMRIGHT", 6, 16)
    local areaTall = Look.Number(area:GetHeight())
    if areaTall and areaTall > 32 then bar:SetHeight(areaTall - 32) end
    local knob = bar:CreateTexture(nil, "ARTWORK")
    Look.Art(knob, "scrollKnob")
    knob:SetSize(18, 24)
    Look.Crop(knob, 0.2, 0.8, 0.125, 0.875)
    bar:SetThumbTexture(knob)
    bar:SetValueStep(1)
    if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    local up, down = ScrollArrow(bar, "Up", -1), ScrollArrow(bar, "Down", 1)
    Look.Pin(up, "BOTTOM", bar, "TOP", 0, 0)
    Look.Pin(down, "TOP", bar, "BOTTOM", 0, 0)
    sliders[bar] = { up = up, down = down, step = 1, top = 0, idle = idle and true or false }
    bar:SetScript("OnValueChanged", function(_, value)
        ArrowsFollow(bar)
        if onValue then onValue(Look.Number(value) or 0) end
    end)
    ArrowsFollow(bar)
    return bar
end

-- The bar's range, 0 to top (never below 0), with the arrows' step (1
-- unless given). The value is kept inside, the knob shows only while there
-- is something to scroll, and the arrows follow.
function Look.ScrollRange(bar, top, step)
    local kept = sliders[bar]
    if not kept then return end
    kept.step = Look.Number(step) or 1
    kept.top = math.max(0, Look.Number(top) or 0)
    bar:SetMinMaxValues(0, kept.top)
    local value = Look.Number(bar:GetValue()) or 0
    if value > kept.top then bar:SetValue(kept.top) elseif value < 0 then bar:SetValue(0) end
    Look.Shown(bar, not (kept.idle and kept.top == 0))
    Look.Shown(bar:GetThumbTexture(), kept.top > 0)
    ArrowsFollow(bar)
end

-- The bar's arrows: up, down (nil for a bar not made here).
function Look.ScrollArrows(bar)
    local kept = sliders[bar]
    if kept then return kept.up, kept.down end
    return nil
end

-- The character sheet's stone column behind such a bar, 31 wide: a top
-- piece from 5 above the up arrow, the 108-tall foot to 4 below the down
-- arrow, and a middle only where the two don't meet. Too short (under 132
-- in all): none of it. Fitted at once and whenever the bar's size changes.
local columns = Look.Weak() -- bar: { top, middle, foot }

local function FitColumn(bar)
    local parts = columns[bar]
    if not parts then return end
    local total = (Look.Number(bar:GetHeight()) or 0) + 41
    local room = total >= 132
    Look.Shown(parts.top, room)
    Look.Shown(parts.foot, room)
    if not room then
        Look.Shown(parts.middle, false)
        return
    end
    local topTall = math.min(256, total - 108)
    parts.top:SetHeight(topTall)
    Look.Crop(parts.top, 0, 0.484375, 0, topTall / 256)
    Look.Shown(parts.middle, total - topTall - 108 > 0.5)
end

function Look.ScrollColumn(bar)
    local up, down = Look.ScrollArrows(bar)
    if not (up and down) or columns[bar] then return end
    local parts = {}
    for _, piece in ipairs({ "top", "middle", "foot" }) do
        local stone = Look.OwnTexture(bar, "column" .. piece, "BACKGROUND")
        Look.Art(stone, "charScrollBar")
        stone:SetWidth(31)
        parts[piece] = stone
    end
    Look.Pin(parts.top, "TOPLEFT", up, "TOPLEFT", -7.5, 5)
    Look.Pin(parts.foot, "BOTTOMLEFT", down, "BOTTOMLEFT", -7.5, -4)
    parts.foot:SetHeight(108)
    Look.Crop(parts.foot, 0.515625, 1, 0, 108 / 256)
    parts.middle:ClearAllPoints()
    parts.middle:SetPoint("TOPLEFT", parts.top, "BOTTOMLEFT")
    parts.middle:SetPoint("BOTTOMRIGHT", parts.foot, "TOPRIGHT")
    Look.Crop(parts.middle, 0, 0.484375, 0.3, 0.7)
    columns[bar] = parts
    Look.HookScript(bar, "OnSizeChanged", function() FitColumn(bar) end)
    FitColumn(bar)
end

-- An inset box in the old iron dialog border (edge 16 unless given, inset
-- a quarter of it) over, unless bare, a marble floor at the lifted 1.35
-- the old windows showed (in effect full brightness; Dark Mode greys it).
-- Handed to Dark Windows as a border with no fill.
function Look.InsetBox(parent, edge, bare)
    edge = Look.Number(edge) or 16
    local inset = edge / 4
    local box = Look.Build("Frame", parent, "BackdropTemplate", { size = { edge * 2, edge * 2 } })
    if not bare then
        local floor = Look.OwnTexture(box, "floor", "BACKGROUND")
        floor:SetVertexColor(1.35, 1.35, 1.35)
        Look.TileArt(floor, "marbleBg")
        Look.Inside(floor, box, inset, inset, inset, inset)
    end
    box:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = edge,
        insets = { left = inset, right = inset, top = inset, bottom = inset } })
    if ns.DarkBackdrop then ns.DarkBackdrop(box, false) end
    return box
end

---------------------------------------------------------------------------
-- More pieces the spell windows brought (the spellbook, professions, trade
-- skill and trainer): the round icon, a chat link, the game's own tooltip
-- data shown in EraUI's box, closing a game panel safely, and what an
-- EraUI window tells the shared window manager.
---------------------------------------------------------------------------

-- An icon cut round: its border cropped off (10% each side) and, once per
-- texture, the portrait mask laid inside it (inset on every side). The
-- mask is a texture of the icon's parent, recorded here.
local roundMasks = Look.Weak()
function Look.RoundIcon(icon, inset)
    if not icon then return end
    Look.Crop(icon, 0.1, 0.9, 0.1, 0.9)
    if roundMasks[icon] then return end
    local holder = icon:GetParent()
    local path = Look.FirstPath("portraitMask")
    if not (holder and path and type(holder.CreateMaskTexture) == "function" and icon.AddMaskTexture) then return end
    local mask = holder:CreateMaskTexture()
    mask:SetTexture(path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    local cut = Look.Number(inset) or 0
    Look.Inside(mask, icon, cut, cut, cut, cut)
    icon:AddMaskTexture(mask)
    roundMasks[icon] = mask
end

-- A link put into the chat box: Forever's own chat code first; the old
-- name (only there while the game's deprecated copies load) when that is
-- all the client has. True when a box took it (the game's own answer: no
-- chat box open is a no, so a caller can go on to its plain click).
local function TookLink(ok, took)
    return ok and not Look.Secret(took) and took == true
end

function Look.ChatLink(link)
    if type(link) ~= "string" or Look.Secret(link) or link == "" then return false end
    local chat = ChatFrameUtil
    if type(chat) == "table" then
        if type(chat.InsertLink) ~= "function" then return false end
        return TookLink(Look.Try(chat.InsertLink, link))
    end
    if type(ChatEdit_InsertLink) == "function" then return TookLink(Look.Try(ChatEdit_InsertLink, link)) end
    return false
end

-- Text a tooltip-data line carries, when it can be read.
local function LineText(value)
    if Look.Secret(value) or type(value) ~= "string" or value == "" then return nil end
    return value
end

local function LineColour(colour, r, g, b)
    if type(colour) ~= "table" then return r, g, b end
    local cr, cg, cb = Look.Number(colour.r), Look.Number(colour.g), Look.Number(colour.b)
    if cr and cg and cb then return cr, cg, cb end
    return r, g, b
end

-- The lines of the game's own tooltip data (C_TooltipInfo), appended to
-- rows for Look.ShowTip: the first line white, the rest gold unless the
-- data colours them; a right text makes a two-column line; long lines wrap
-- at wrap (260 unless given). Hidden or unreadable lines are skipped.
function Look.DataRows(record, rows, wrap)
    rows = rows or {}
    if type(record) ~= "table" or type(record.lines) ~= "table" then return rows end
    for _, line in ipairs(record.lines) do
        local left = type(line) == "table" and LineText(line.leftText)
        if left then
            local first = #rows == 0
            local r, g, b = LineColour(line.leftColor, 1, first and 1 or 0.82, first and 1 or 0)
            local row = { left, r, g, b }
            local right = LineText(line.rightText)
            if right then
                row.right = { right, LineColour(line.rightColor, 1, 1, 1) }
            elseif not first then
                row[5] = wrap or 260
            end
            rows[#rows + 1] = row
        end
    end
    return rows
end

-- EraUI's box showing what the game's tooltip would for something:
-- fetch(...) is one of C_TooltipInfo's readers, called protected. Nothing
-- readable: the fallback rows instead (or nothing). True when shown.
function Look.ShowDataTip(owner, side, fetch, fallback, ...)
    local rows
    if type(fetch) == "function" then
        local fine, record = pcall(fetch, ...)
        if fine then rows = Look.DataRows(record) end
    end
    if not rows or #rows == 0 then rows = fallback end
    if type(rows) ~= "table" or #rows == 0 then return false end
    Look.ShowTip(owner, side, rows)
    return true
end

-- A game panel closed: out of a fight through the game's own panel manager
-- (or a plain hide where it has none); in a fight only a frame the game
-- doesn't guard, by a plain hide.
function Look.HidePanel(frame)
    if not frame or not frame:IsShown() then return true end
    if Look.InFight() then
        if frame:IsProtected() then return false end
        frame:Hide()
        return true
    end
    if type(HideUIPanel) == "function" then Look.Try(HideUIPanel, frame) else frame:Hide() end
    return true
end

-- The mirror of Look.HidePanel: out of a fight through the game's own panel
-- manager (or a plain show where it has none); in a fight a frame the game
-- guards is refused (false), any other is shown plainly, at UIParent's
-- top-left (16, -116) when nothing has placed it yet.
function Look.ShowPanel(frame)
    if not frame or frame:IsShown() then return true end
    if not Look.InFight() then
        if type(ShowUIPanel) == "function" then Look.Try(ShowUIPanel, frame) else frame:Show() end
        return true
    end
    if frame:IsProtected() then return false end
    if (Look.Number(frame:GetNumPoints()) or 0) == 0 then frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116) end
    frame:Show()
    return true
end

-- What an EraUI window tells the shared window manager (Look/Windows.lua),
-- kept here (never on the frame): width (its slot, 352 unless given),
-- hold() (an x it must keep for now, or nil), keep() (a frame it starts
-- right of and leaves open), placed(x, y) (after the manager moves it).
local windowTraits = Look.Weak()
function Look.WindowTraits(frame, traits)
    if frame and type(traits) == "table" then windowTraits[frame] = traits end
end

function Look.WindowTrait(frame, name)
    local traits = frame and windowTraits[frame]
    return traits and traits[name] or nil
end

---------------------------------------------------------------------------
-- More pieces the social windows brought (the Who and Guild lists, the
-- group finder): a whisper ready to type, a stone fill, and the stone
-- column behind the game's own thin scroll bars, every one under a frame.
---------------------------------------------------------------------------

-- The chat box opened on "/w Name " with the cursor after it: Forever's own
-- chat code (ChatFrameUtil) when the client has it, the older names only
-- where it has nothing else. The box is emptied first (the game's opener
-- would add to a half-typed line). No box at all: the game's own whisper
-- opener. True when something opened.
function Look.Whisper(name)
    if type(name) ~= "string" or Look.Secret(name) or name == "" then return false end
    local util = type(ChatFrameUtil) == "table" and ChatFrameUtil or nil
    local pick, open, tell
    if util then
        pick, open, tell = util.ChooseBoxForSend, util.ActivateChat, util.SendTell
    else
        pick, open, tell = ChatEdit_ChooseBoxForSend, ChatEdit_ActivateChat, ChatFrame_SendTell
    end
    local box
    if type(pick) == "function" then
        local fine, chosen = pcall(pick, DEFAULT_CHAT_FRAME)
        if fine then box = chosen end
    end
    box = box or ChatFrame1EditBox
    if not box then
        if type(tell) ~= "function" then return false end
        return (Look.Try(tell, name))
    end
    local line = "/w " .. name .. " "
    box:SetText("")
    if type(open) == "function" then Look.Try(open, box) elseif box.Show then box:Show() end
    box:SetText(line)
    if box.SetCursorPosition then box:SetCursorPosition(#line) end
    if box.SetFocus then box:SetFocus() end
    return true
end

-- The stone (rockBg) tiled over a frame on the given layer (ARTWORK unless
-- given), with its warm lift, through the art lookup (so Dark Mode greys
-- it). Returns the texture; the caller places it.
function Look.StoneFill(frame, layer)
    local stone = frame:CreateTexture(nil, layer or "ARTWORK")
    Look.Tint(stone, Look.STONE_TINT)
    Look.TileArt(stone, "rockBg")
    Look.Crop(stone, 0, 1, 0, 1)
    return stone
end

-- The character sheet's stone column behind one of the game's thin scroll
-- bars: a top piece from 10.5 left of the bar and 7 above it, the 108-tall
-- foot to 6 below it, and a middle only where they don't meet; 31 wide.
-- Fitted through a frame of EraUI's laid over the bar (its size and its
-- show), and at once. The bar's arrows move 2 further apart, once; the
-- knob may run 7 past the track's ends. Once per bar.
local trackColumns, movedArrows = Look.Weak(), Look.Weak()

local function FitTrack(bar)
    local parts = trackColumns[bar]
    if not parts then return end
    local total = (Look.Number(bar:GetHeight()) or 0) + 13
    local room = total >= 132
    Look.Shown(parts.top, room)
    Look.Shown(parts.foot, room)
    if not room then
        Look.Shown(parts.middle, false)
        return
    end
    local head = math.min(256, total - 108)
    parts.top:SetHeight(head)
    Look.Crop(parts.top, 0, 0.484375, 0, head / 256)
    Look.Shown(parts.middle, total - 108 - head > 0.5)
end

local function MoveArrow(arrow, rise)
    if not arrow or movedArrows[arrow] then return end
    local point, relative, relativePoint, x, y = arrow:GetPoint(1)
    x, y = Look.Number(x), Look.Number(y)
    if type(point) ~= "string" or not x or not y then return end
    movedArrows[arrow] = true
    arrow:SetPoint(point, relative, relativePoint, x, y + rise)
end

function Look.TrackColumn(bar)
    if not bar or trackColumns[bar] or columns[bar] then return end
    local parts = {}
    for _, piece in ipairs({ "top", "middle", "foot" }) do
        local stone = Look.OwnTexture(bar, "track" .. piece, "BACKGROUND", piece == "foot" and 1 or 0)
        Look.Art(stone, "charScrollBar")
        stone:SetWidth(31)
        parts[piece] = stone
    end
    Look.Pin(parts.top, "TOPLEFT", bar, "TOPLEFT", -10.5, 7)
    Look.Pin(parts.foot, "BOTTOMLEFT", bar, "BOTTOMLEFT", -10.5, -6)
    parts.foot:SetHeight(108)
    Look.Crop(parts.foot, 0.515625, 1, 0, 108 / 256)
    parts.middle:ClearAllPoints()
    parts.middle:SetPoint("TOPLEFT", parts.top, "BOTTOMLEFT")
    parts.middle:SetPoint("BOTTOMLEFT", parts.foot, "TOPLEFT")
    Look.Crop(parts.middle, 0, 0.484375, 0.3, 0.7)
    MoveArrow(bar.Back, 2)
    MoveArrow(bar.Forward, -2)
    trackColumns[bar] = parts
    local fitter = Look.Build("Frame", bar, nil, { size = { 16, 16 } })
    Look.Fill(fitter, bar)
    local function Fit() FitTrack(bar) end
    fitter:SetScript("OnSizeChanged", Fit)
    fitter:SetScript("OnShow", Fit)
    Fit()
    if bar.Track then Look.Knob(bar, 7) end
end

-- Every thin scroll bar (a frame's own ScrollBar field with its Track, Back
-- and Forward) on a frame and under it to depth levels: the 1.x arrows and
-- knob, and the stone column. Forbidden frames are passed over.
local function Forbidden(frame)
    local fine, answer = Look.Ask(frame, "IsForbidden")
    return fine and answer == true
end

function Look.SkinScrollBarsUnder(frame, depth)
    if type(frame) ~= "table" or type(frame.GetChildren) ~= "function" or Forbidden(frame) then return end
    local bar = rawget(frame, "ScrollBar")
    if type(bar) == "table" and not Forbidden(bar) and bar.Track and bar.Back and bar.Forward then
        Look.ThinScrollBar(bar)
        Look.TrackColumn(bar)
    end
    depth = Look.Number(depth) or 0
    if depth <= 0 then return end
    local fine, children = pcall(function() return { frame:GetChildren() } end)
    if not fine then return end
    for _, child in ipairs(children) do Look.SkinScrollBarsUnder(child, depth - 1) end
end

---------------------------------------------------------------------------
-- More pieces the windows and settings brought (the window chrome, the game
-- menu, the Settings window and the Classic options page): art put on
-- straight from its file, the old dialog box and its header plate, the old
-- options tabs, slider, page-arrow steppers and drop down on the game's
-- modern widgets, and the item name plate's fit. Every "done once" mark is
-- kept in a weak table here, never on the game's widget.
---------------------------------------------------------------------------

do
    Look.DefineArt("optionsTabActive", nil, "UI-OptionsFrame-ActiveTab", "optionsTabActive", true)
    Look.DefineArt("optionsTabInactive", nil, "UI-OptionsFrame-InActiveTab", "optionsTabInactive", true)
end

-- A piece of art put on straight from its file: the preferred file, else
-- the other, wrapped (repeating) across and/or down as asked. No Dark Mode
-- tint: Dark Windows paints these itself. True when a file was set.
function Look.PlainArt(texture, key, across, down)
    local art = Look.ART[key]
    if not texture or not art then return false end
    local first, second = PathOrder(art)
    local wrapAcross, wrapDown = across and "REPEAT" or "CLAMP", down and "REPEAT" or "CLAMP"
    local function Put(path) return path ~= nil and texture:SetTexture(path, wrapAcross, wrapDown) ~= false end
    local outcome = (Put(first) and "ok") or (Put(second) and "fallback") or "missing"
    Look.artResults[key] = outcome
    if texture.SetHorizTile then texture:SetHorizTile(across and true or false) end
    if texture.SetVertTile then texture:SetVertTile(down and true or false) end
    return outcome ~= "missing"
end

-- The old dialog box behind a frame: EraUI's own frame on all its points at
-- its level, the dialog background tiled (32) inside the dialog border (32,
-- insets 11, 12, 12, 11), white, handed to Dark Windows. Returns it.
local DIALOG_FILL = "Interface\\DialogFrame\\UI-DialogBox-Background"
function Look.DialogBox(owner)
    local box = Look.Build("Frame", owner, "BackdropTemplate", { size = { 64, 64 } })
    box:SetAllPoints(owner)
    box:SetFrameLevel(Look.Number(owner:GetFrameLevel()) or 0)
    box:SetBackdrop({ bgFile = DIALOG_FILL, edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true,
        tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    box:SetBackdropColor(1, 1, 1, 1)
    box:SetBackdropBorderColor(1, 1, 1, 1)
    if ns.DarkBackdrop then ns.DarkBackdrop(box) end
    return box
end

-- The old dialog header plate (256 x 64) on owner, its top 12 above the top
-- of `over` (owner unless given), handed to Dark Windows as frame art.
function Look.HeaderPlate(owner, layer, over)
    local plate = Look.OwnTexture(owner, "headerPlate", layer or "ARTWORK")
    plate:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    if ns.DarkWindowArt then ns.DarkWindowArt(plate, "frame") end
    plate:SetSize(256, 64)
    Look.Pin(plate, "TOP", over or owner, "TOP", 0, 12)
    plate:Show()
    return plate
end

-- The old options-window tab on one of the game's minimal tabs: its own
-- pieces faded, three of EraUI's (BACKGROUND) in the old tab art, the active
-- art while it is chosen, its text small and white while chosen, gold
-- otherwise. Dressed again after its own select calls, on show and the frame
-- after a click.
local minimalTabs = Look.Weak()

local function TabChosen(tab)
    local fine, chosen = Look.Ask(tab, "IsSelected")
    if fine and not Look.Secret(chosen) then return chosen and true or false end
    local field = rawget(tab, "selected")
    return not Look.Secret(field) and field and true or false
end

function Look.DressMinimalTab(tab)
    if not tab then return end
    local key = TabChosen(tab) and "optionsTabActive" or "optionsTabInactive"
    local left = Look.OwnTexture(tab, "optionsTabLeft", "BACKGROUND")
    local right = Look.OwnTexture(tab, "optionsTabRight", "BACKGROUND")
    local middle = Look.OwnTexture(tab, "optionsTabMiddle", "BACKGROUND")
    for piece, across in pairs({ [left] = { 0, 0.15625 }, [right] = { 0.84375, 1 }, [middle] = { 0.15625, 0.84375 } }) do
        Look.Art(piece, key)
        Look.Crop(piece, across[1], across[2], 0, 1)
        piece:Show()
    end
    left:SetSize(20, 32)
    Look.Pin(left, "BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
    right:SetSize(20, 32)
    Look.Pin(right, "BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
    middle:ClearAllPoints()
    middle:SetHeight(32)
    middle:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    local text = tab.Text
    if text and text.SetFontObject then
        local font = key == "optionsTabActive" and GameFontHighlightSmall or GameFontNormalSmall
        if font then text:SetFontObject(font) end
    end
end

function Look.SkinMinimalTab(tab)
    if not tab then return end
    if not minimalTabs[tab] then
        minimalTabs[tab] = true
        for _, piece in ipairs({ tab.Left, tab.Middle, tab.Right }) do Look.Fade(piece) end
        local function Again() Look.Try(Look.DressMinimalTab, tab) end
        for _, method in ipairs({ "SetSelected", "SetSelectedState", "UpdateTab" }) do
            if type(tab[method]) == "function" then Look.Hook(tab, method, Again) end
        end
        Look.HookScript(tab, "OnShow", Again)
        Look.HookScript(tab, "OnClick", function()
            if C_Timer and C_Timer.After then C_Timer.After(0, Again) else Again() end
        end)
    end
    Look.DressMinimalTab(tab)
end

-- The spellbook's page arrows on one of the game's steppers (forward or
-- back): its own art faded, the arrow's states centred at 26 x 26, the
-- mouse glow additive. Once per button; nothing more when the client
-- refuses the arrow's first file.
local steppers = Look.Weak()
function Look.SkinStepper(button, forward)
    if not button or steppers[button] then return end
    steppers[button] = true
    Look.EachRegion(button, function(piece)
        if piece.IsObjectType and piece:IsObjectType("Texture") then Look.Fade(piece) end
    end)
    local base = "Interface\\Buttons\\UI-SpellbookIcon-" .. (forward and "NextPage-" or "PrevPage-")
    local faces = { { "Normal", base .. "Up" }, { "Pushed", base .. "Down" }, { "Disabled", base .. "Disabled" },
        { "Highlight", "Interface\\Buttons\\UI-Common-MouseHilight" } }
    for i, face in ipairs(faces) do
        local give, read = button["Set" .. face[1] .. "Texture"], button["Get" .. face[1] .. "Texture"]
        if type(give) ~= "function" or type(read) ~= "function" then return end
        give(button, face[2])
        local texture = read(button)
        if not texture or (i == 1 and texture:SetTexture(face[2]) == false) then return end
        texture:ClearAllPoints()
        texture:SetSize(26, 26)
        texture:SetPoint("CENTER", button, "CENTER", 0, 0)
        Look.Crop(texture, 0, 1, 0, 1)
        texture:SetAlpha(1)
        if face[1] == "Highlight" then texture:SetBlendMode("ADD") end
    end
end

-- The old slider on one of the game's sliders with steppers: the modern
-- track faded, EraUI's bordered track under it, the round horizontal thumb,
-- and the steppers kept but drained of colour (the game sets their bronze
-- art again whenever it sets the slider up, so they are never hidden).
-- Once per frame.
local slidersDone = Look.Weak()
local function Drained(button)
    if not button then return end
    button:SetAlpha(1)
    if button.EnableMouse then button:EnableMouse(true) end
    Look.EachRegion(button, function(piece)
        if piece.SetDesaturated then piece:SetDesaturated(true) end
    end)
    for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
        local read = button["Get" .. state .. "Texture"]
        local face = type(read) == "function" and read(button) or nil
        if face and face.SetDesaturated then face:SetDesaturated(true) end
    end
end

function Look.SkinSlider(frame)
    if not frame or slidersDone[frame] then return end
    slidersDone[frame] = true
    local slider = frame.Slider or frame
    for _, piece in ipairs({ slider.Left, slider.Right, slider.Middle }) do Look.Fade(piece) end
    local track = Look.Build("Frame", slider, "BackdropTemplate", { size = { 100, 17 } })
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetFrameLevel(math.max(0, (Look.Number(slider:GetFrameLevel()) or 1) - 1))
    if track.SetBackdrop then
        track:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border", tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 3, right = 3, top = 6, bottom = 6 } })
    end
    if type(slider.SetThumbTexture) == "function" then
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        local thumb = slider.GetThumbTexture and slider:GetThumbTexture()
        if thumb then
            thumb:SetSize(32, 32)
            Look.Crop(thumb, 0, 1, 0, 1)
        end
    end
    Drained(frame.Back)
    Drained(frame.Forward)
end

-- One of the game's modern drop downs in the old label frame: its own
-- background, arrow and glow faded, the label frame round it, its text
-- small and white from its left to the round arrow. Once per drop down.
local dropdownsDone = Look.Weak()
function Look.SkinDropdown(dropdown)
    if not dropdown or dropdownsDone[dropdown] then return end
    dropdownsDone[dropdown] = true
    Look.Fade(dropdown.Background)
    Look.Fade(dropdown.Arrow)
    Look.Fade(dropdown.GetHighlightTexture and dropdown:GetHighlightTexture() or nil)
    local arrow = Look.DressDropdown(dropdown)
    local text = dropdown.Text
    if not text then return end
    if text.SetFontObject and GameFontHighlightSmall then text:SetFontObject(GameFontHighlightSmall) end
    text:ClearAllPoints()
    text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
    text:SetPoint("RIGHT", arrow, "LEFT", -2, 0)
    if text.SetJustifyH then text:SetJustifyH("LEFT") end
end

-- The old item name plate drawn so its visible part (106 of its 128 across,
-- 42 of its 64 down, starting 11 in) reads at width x height, `inset` in
-- from the host's left, centred down the host.
function Look.FitNamePlate(texture, host, inset, width, height)
    local across, down = width / (106 / 128), height / (42 / 64)
    texture:SetSize(across, down)
    Look.Pin(texture, "LEFT", host, "LEFT", inset - across * 11 / 128, 0)
end
