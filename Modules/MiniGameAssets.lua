local _, EraUI = ...

-- The mini-games' art and sounds by role (experimental, with the mini-games).
-- A game names what it draws ("zone.elwynn.ground", "block.ice", "power.mallet",
-- "coin") and this file gives the client's own art for it: each ID checked in
-- build 1.60.1.70707 (ManifestInterfaceData, UiTextureAtlasMember,
-- CreatureDisplayInfo, SoundKit and SoundKitEntry, or the file in the build
-- itself), with a stand-in for each, and last of all a plain colour, so a
-- refused file never leaves a hole or an error.
--
-- How to use it (CORE's contract for the game builders):
--   MiniGames.ASSET[role] = {kind = "file"|"atlas"|"display"|"colour"|"text"|"kit"|"soundfile",
--       id = <file ID, path, atlas name, display ID, rgb or text>, coords = {l, r, t, b},
--       tint = {r, g, b}, alpha, blend, alt = <another entry, or a list of them>}
--   MiniGames.FALLBACK[role]  what to draw when the role and its alts are refused
--   MiniGames:Asset(role) -> entry or nil (zone keys through MiniGames.ZONE_ALIAS)
--   MiniGames:Art(texture, role, opts) -> "atlas"|"file"|"colour"|nil: draws the
--       role on a texture (its alts, then its fallback, then opts.colour);
--       shows the texture when something drew, hides it when nothing did.
--       opts: wrap ("REPEAT", both ways), coords (instead of the entry's),
--       tint (instead of the entry's), colour {r, g, b, a} (the last resort),
--       plain (leave alpha and blend alone)
--   MiniGames:ArtValue(role) -> a value for SetTexture (a file ID or path) or
--       nil: for MiniGames.Button's icon, which can't take an atlas
--   MiniGames:Colour3(role, fallback) -> r, g, b (a colour role: a zone's tint,
--       a race's plate colour)
--   MiniGames:Words(role, fallback) -> text (a boss's name)
--   MiniGames:Model(model, role, tuneKey, baseTurn) -> ok, displayID: the role's
--       3D model (its alts if one is refused), framed by MiniGames:Tune(tuneKey)
--   MiniGames:FrameModel(model, tuneKey, baseTurn): the framing again (call it in
--       OnModelLoaded and after every SetDisplayInfo: a model load resets it).
--       Tune fields: zoom (SetPortraitZoom), cam (SetCamDistanceScale), up
--       (SetPosition z), turn (degrees, added to baseTurn radians), insets
--       ({l, r, t, b}: SetViewInsets), each only when set and the model has it
--   MiniGames:TuneDefaults(key, defaults)  a game's own framing defaults
--   MiniGames:Tune(key) -> a new table: the defaults with EraUIDB.miniGameTune[key] over them
--   MiniGames:SetTune(key, field, value), MiniGames:ClearTune(key) (nil: every key)
--   MiniGames.ZONE_ALIAS[key] = assets key (empty: the keys match)
--   Sound roles fill MiniGames.SOUNDS under their short names ("sound.pop" is
--   MiniGames.SOUNDS.pop); each zone's boss sounds are "bossRoar.<key>",
--   "bossHit.<key>", "bossDown.<key>" (MiniGames:Sound falls back to
--   "bossRoar" for a zone without its own).
-- Roles: zone.<key>.ground|tint|frame|icon|boss|bossName|bossIcon|bossRoar|bossHit|bossDown
-- (keys elwynn westfall redridge duskwood durotar barrens mulgore silverpine
-- stranglethorn blackrock; any other zone key gets the fallback look),
-- block.oil|oil2|ice|iceCrack|crate|crateCrack|web|skull, relic.1..5, exit,
-- hole, power.mallet|shuffle|swap|moves, boost.charge|sheep|lust (the
-- Alliance's Heroism through MiniGames:Art's faction pick), coin, coinBig,
-- star, starEmpty, lock, check, crest.Alliance|Horde, map.node|nodeDone|nodeBoss|nodeLocked|path|glow|banner,
-- card, whack.golden|decoyAlliance|decoyHorde|bossPeon|bossGnome, mallet.1..6,
-- plate.<race> and piece.<race>.colour (orc tauren undead human dwarf nightelf).
local MG = EraUI.MiniGames
if not MG then return end

local ICON = "Interface\\Icons\\"
local EMPTY = {}
local A = {}
MG.ASSET = A
MG.ZONE_ALIAS = {}

local function File(id, alt, extra)
    local entry = {kind = "file", id = id, alt = alt}
    for key, value in pairs(extra or EMPTY) do entry[key] = value end
    return entry
end
local function Atlas(id, alt, extra)
    local entry = {kind = "atlas", id = id, alt = alt}
    for key, value in pairs(extra or EMPTY) do entry[key] = value end
    return entry
end
local function Kit(id, alt) return {kind = "kit", id = id, alt = alt} end
local CROP = {.08, .92, .08, .92}   -- an icon's border cropped
local function Icon(id, alt) return File(id, alt, {coords = CROP}) end

-- Zones: ground tile and its stand-in, tint, frame atlas and tint, zone icon,
-- boss display, boss icon, name, roar, hit and down sound kits.
local ZONES = {
    elwynn = {187126, 187113, {.45, .72, .3}, "AllianceFrameCorner-TopLeft", {1, .95, .85}, 236761, 384, 134163, "Hogger", 1015, 310, 413},
    westfall = {188991, 188989, {.86, .7, .36}, "AllianceFrameCorner-TopLeft", {1, .9, .7}, 236852, 2029, 236409, "Edwin VanCleef", 1263, 2942, 2944},
    redridge = {188756, 188760, {.8, .45, .25}, "AllianceFrameCorner-TopLeft", {1, .8, .7}, 236814, 703, 132184, "Bellygrub", 379, 381, 383},
    duskwood = {187084, 187079, {.36, .36, .56}, "AllianceFrameCorner-TopLeft", {.75, .75, 1}, 236757, 1693, 298667, "Stitches", 1446, 1442, 1444},
    durotar = {187021, 187017, {.78, .4, .22}, "HordeFrame-Corner-TopLeft", {1, .85, .75}, 236756, 4078, 236456, "Zalazane", 344001, 3308, 3310},
    barrens = {186908, 186899, {.86, .62, .3}, "HordeFrame-Corner-TopLeft", {1, .9, .7}, 236717, 4088, 236425, "Mutanus the Devourer", 416, 418, 420},
    mulgore = {188654, 188652, {.62, .7, .32}, "HordeFrame-Corner-TopLeft", {.95, 1, .8}, 236809, 10916, 132243, "Arra'chea", 771, 773, 775},
    silverpine = {188791, 188789, {.45, .55, .5}, "HordeFrame-Corner-TopLeft", {.85, .95, .9}, 236830, 2353, 254646, "Archmage Arugal", 1263, 2942, 2944},
    stranglethorn = {188821, 188827, {.2, .55, .3}, "_StoneFrameTile-Top", {.8, 1, .8}, 236844, 616, 134176, "King Bangalash", 643, 644, 646},
    blackrock = {186959, 186950, {.85, .3, .1}, "_StoneFrameTile-Top", {1, .6, .4}, 236718, 11121, 254652, "Ragnaros", 8046, 7554, 7555},
}
MG.ZONE_ART = ZONES
for key, z in pairs(ZONES) do
    local at = "zone." .. key .. "."
    A[at .. "ground"] = File(z[1], File(z[2]))
    A[at .. "tint"] = {kind = "colour", id = z[3]}
    A[at .. "frame"] = Atlas(z[4], File(131076), {tint = z[5]})
    A[at .. "icon"] = Icon(z[6], Atlas("taxinode_neutral"))
    A[at .. "bossIcon"] = Icon(z[8])
    A[at .. "boss"] = {kind = "display", id = z[7], alt = Icon(z[8])}
    A[at .. "bossName"] = {kind = "text", id = z[9]}
    A[at .. "bossRoar"] = Kit(z[10], 3326)
    A[at .. "bossHit"] = Kit(z[11], 722)
    A[at .. "bossDown"] = Kit(z[12], 50111)
end

-- Blockers, relics and the board's marks.
A["block.oil"] = File(4675225, File(469595), {tint = {.1, .08, .06}, alpha = .9})
A["block.oil2"] = File(469595, File(4675225), {tint = {.06, .05, .04}, alpha = 1})
A["block.ice"] = File(2510379, {Atlas("perks-frozen-icon"), Icon(135841)}, {tint = {.75, .9, 1}, alpha = .8})
A["block.iceCrack"] = File(252830, File(254263), {alpha = .9})
A["block.crate"] = Icon(132761, Icon(132594))
A["block.crateCrack"] = File(132762, Icon(132761), {coords = CROP, overlay = File(165823)})
A["block.web"] = File(166943, Icon(136113), {tint = {1, 1, 1}})
A["block.skull"] = File(137008, {Atlas("dungeonskull"), Icon(133730)})
local RELICS = {{133639, 133628}, {134344, 647735}, {134506, 134505}, {134509, 134507}, {134231, 134443}}
for n, ids in ipairs(RELICS) do A["relic." .. n] = Icon(ids[1], Icon(ids[2])) end
A["exit"] = Atlas("npe_arrowdown", Atlas("hud-mainmenubar-arrowdown-up"), {glow = Atlas("npe_arrowdownglow")})
A["hole"] = Atlas("talents-node-circle-shadow", File(130924), {under = File(374155, nil, {tint = {.25, .25, .28}})})

-- Power-ups, boosters, coins and marks.
A["power.mallet"] = Icon(133052, Icon(133053))
A["power.shuffle"] = Icon(237284, Icon(237285))
A["power.swap"] = Icon(135736, Icon(132180))
A["power.moves"] = Icon(237538, Icon(134376))
A["boost.charge"] = Icon(132337)
A["boost.sheep"] = Icon(136071)
A["boost.lust"] = Icon(136012, nil, nil)
A["boost.lust"].alliance = Icon(132313)
A["coin"] = Atlas("coin-icon", Icon(133784))
A["coinBig"] = Icon(133785, Atlas("islands-queue-prop-coins"))
A["star"] = Atlas("tradeskills-star", File(166955))
A["starEmpty"] = Atlas("tradeskills-star-off", Atlas("tradeskills-star", nil, {desaturate = true, alpha = .35}))
A["lock"] = Atlas("adventuremapicon-lock", Atlas("UI-CharacterCreate-PadLock"))
-- Each side's crest (Blast's "Clear 30 Horde pieces" goal): the honor icons, the group frame's as stand-ins.
A["crest.Alliance"] = Icon(463450, File(132067))
A["crest.Horde"] = Icon(463451, File(132068))
A["check"] = Atlas("common-icon-checkmark", Atlas("Tracker-Check"))

-- The level map and the cards.
A["map.node"] = Atlas("talents-node-circle-yellow", Atlas("taxi_frame_yellow"))
A["map.nodeDone"] = Atlas("talents-node-circle-green", Atlas("taxi_frame_green"))
A["map.nodeBoss"] = Atlas("BossBanner-SkullCircle", Atlas("dungeonskull"))
A["map.nodeLocked"] = Atlas("talents-node-circle-locked", Atlas("taxi_frame_gray"))
A["map.path"] = Atlas("ui-taxi-icon-nub", Atlas("!UI-Taxi-Line"))
A["map.glow"] = Atlas("BonusChest-CircleGlow", File(1063457))
A["map.banner"] = Atlas("GarrMission_RewardsBanner", Atlas("Banner-BgFiligree"))
A["card"] = Atlas("warboard-parchment", {Atlas("ui-frame-neutral-cardparchment"), Atlas("GarrMission_MissionParchment")})

-- Whack: the golden target, decoys, bosses (3D models; head icons for a
-- texture) and the mallet skins' icons (5 and 6 are 1 and 2 tinted).
A["whack.golden"] = Atlas("BonusChest-CircleGlow", nil, {tint = {1, .82, .25}, sparkle = File(240909)})
A["whack.decoyAlliance"] = {kind = "display", id = 89, alt = {{kind = "display", id = 310}, {kind = "display", id = 11354}, Icon(134166)}}
A["whack.decoyHorde"] = {kind = "display", id = 10038, alt = {{kind = "display", id = 9574}, Icon(134170)}}
A["whack.bossPeon"] = {kind = "display", id = 4259, alt = {{kind = "display", id = 4602}, {kind = "display", id = 9574}, Icon(ICON .. "INV_Misc_Head_Orc_01")}}
A["whack.bossGnome"] = {kind = "display", id = 7006, alt = {{kind = "display", id = 6980}, {kind = "display", id = 6973}, Icon(ICON .. "INV_Misc_Head_Gnome_01")}}
A["mallet.1"] = Icon(133052)
A["mallet.2"] = Icon(133053)
A["mallet.3"] = Icon(133042)
A["mallet.4"] = Icon(133066)
A["mallet.5"] = Icon(133052, nil)
A["mallet.5"].tint = {.45, 1, .35}
A["mallet.6"] = Icon(133053, nil)
A["mallet.6"].tint = {1, .7, .4}

-- Blast's pieces: each race its own bright colour, every pair at least .4
-- apart (the night elves a pink lilac, far from the humans' blue; the tauren
-- a yellower orange than the dwarves' red), and its own plate shape (the
-- night elves a hexagon, no longer a narrow copy of the dwarves' diamond).
-- The one place these colours live: the view reads them with MiniGames:Colour3.
local PLATES = {
    orc = {{.3, .82, .22}, File(3893512, nil, {coords = {.188, .797, .234, .766}})},
    tauren = {{1, .6, .1}, File(2922105)},
    undead = {{.18, .87, .82}, Atlas("talents-node-choice-mask")},
    human = {{.24, .48, 1}, Atlas("talents-node-circle-mask", File(130924))},
    dwarf = {{.95, .18, .2}, File(3152572)},
    nightelf = {{.96, .5, .95}, Atlas("covenantsanctum-renown-hexagon-mask", File(3152572))},
}
for race, p in pairs(PLATES) do
    A["piece." .. race .. ".colour"] = {kind = "colour", id = p[1]}
    p[2].tint = p[1]
    A["plate." .. race] = p[2]
    A["piece." .. race .. ".plate"] = p[2]
end

-- Sounds (SoundKit IDs; each with a stand-in played when the client refuses it).
local SOUNDS = {
    pop = Kit(140556, 7355), squish = Kit(722, 1208), boing = Kit(91242, 140556), whoosh = Kit(219930, 196471),
    chime = Kit(206515, 233377), coin = Kit(120), coins = Kit(40345, 287276),
    win = Kit(218231, 43502), lose = Kit(43503, 847), unlock = Kit(63971, 878),
    bossRoar = Kit(3326, 6943), bossHit = Kit(722, 838), bossDown = Kit(50111),
    iceCrack = Kit(164634, 42782), iceFreeze = Kit(198260, 243290), oilSplat = Kit(271793, 838), oilBubble = Kit(99405),
    crateBreak = Kit(37904, 4783), relicDrop = Kit(51402, 1279), shuffle = Kit(43937, 62539),
    powerUse = Kit(233377, 170271), buy = Kit(218228, 287276), uiClick = Kit(856, 170271), mapStep = Kit(1209, 44319),
    voicePeasant = Kit({7094, 6284, 6285, 6286, 6290, 6240, 6241}), voiceGrunt = Kit({6018, 6019, 6020}),
    voiceMekkatorque = Kit(7226),
}
for name, entry in pairs(SOUNDS) do A["sound." .. name] = entry end
-- The three stars: the trading post's reward tiers, one file each (their kit if refused).
A["sound.star"] = {kind = "soundfile", id = {4956080, 4956082, 4956084}, alt = 218238}

-- A role's entry as MiniGames.SOUNDS keeps it.
local function SoundEntry(entry)
    if entry.kind == "soundfile" then
        local list = {}
        for index, file in ipairs(entry.id) do list[index] = {file = file, kit = entry.alt} end
        return list
    end
    if entry.alt == nil then return entry.id end
    return {kit = entry.id, alt = entry.alt}
end
function MG:LoadSounds()
    for role, entry in pairs(A) do
        local name = role:match("^sound%.(.+)$")
        if name then self.SOUNDS[name] = SoundEntry(entry) end
        local key, what = role:match("^zone%.(%w+)%.(boss%a+)$")
        if key and entry.kind == "kit" then self.SOUNDS[what .. "." .. key] = SoundEntry(entry) end
    end
    self:PointSounds()
end
MG:LoadSounds()

-- Fallbacks: art the mini-games already drew before, or a plain colour.
local F = {}
MG.FALLBACK = F
local function Disc(colour)
    return {File("Interface\\Masks\\CircleMask", nil, {tint = colour}), {kind = "colour", id = colour}}
end
F["block.oil"] = File(MG.ART and MG.ART.glow or "Interface\\Glues\\Models\\UI_Draenei\\GenericGlow64", nil, {tint = {.15, .1, .05}, alpha = .85, blend = "BLEND"})
F["block.oil2"] = File(F["block.oil"].id, nil, {tint = {.08, .05, .02}, alpha = .95, blend = "BLEND"})
F["block.ice"] = {kind = "colour", id = {.55, .8, 1, .4}}
F["block.iceCrack"] = {kind = "colour", id = {.55, .8, 1, .22}}
F["block.crate"] = {kind = "colour", id = {.45, .28, .12, 1}}
F["block.crateCrack"] = {kind = "colour", id = {.58, .38, .18, 1}}
F["block.web"] = File("Interface\\Cooldown\\starburst", nil, {tint = {1, 1, 1}, alpha = .7, blend = "BLEND"})
F["block.skull"] = Disc({.85, .82, .72})
F["relic.1"] = Icon(ICON .. "INV_Hammer_Unique_Sulfuras")
F["relic.2"] = Icon(ICON .. "INV_Misc_Head_Dragon_01")
F["relic.3"] = Icon(ICON .. "INV_Sword_39")
F["relic.4"] = F["relic.1"]
F["relic.5"] = F["relic.2"]
F["exit"] = File("Interface\\Glues\\Models\\UI_Draenei\\GenericGlow64", nil, {tint = {1, .85, .4}, blend = "ADD"})
F["power.mallet"] = Icon(ICON .. "INV_Hammer_15")
F["power.shuffle"] = Icon(ICON .. "Spell_Nature_Polymorph")
F["power.swap"] = Icon(ICON .. "Ability_Mount_Gryphon_01")
F["power.moves"] = Icon(ICON .. "INV_Potion_51")
F["boost.charge"] = Icon(ICON .. "Ability_Warrior_Charge")
F["boost.sheep"] = Icon(ICON .. "Spell_Nature_Polymorph")
F["boost.lust"] = Icon(ICON .. "Spell_Nature_BloodLust")
F["coin"] = Icon(ICON .. "INV_Misc_Coin_01")
F["coinBig"] = Icon(ICON .. "INV_Misc_Coin_05")
F["star"] = File(166955)
F["starEmpty"] = File(166955, nil, {desaturate = true, alpha = .35})
F["lock"] = File("Interface\\Cooldown\\ping4", nil, {tint = {.6, .6, .6}})
F["crest.Alliance"] = Disc({.24, .48, 1})
F["crest.Horde"] = Disc({.9, .15, .12})
F["check"] = File("Interface\\Cooldown\\star4", nil, {tint = {.4, 1, .5}, blend = "ADD"})
F["map.node"] = Disc({.25, .22, .16})
F["map.nodeDone"] = Disc({.85, .68, .3})
F["map.nodeBoss"] = Disc({.7, .2, .15})
F["map.nodeLocked"] = Disc({.3, .3, .3})
F["map.path"] = Disc({1, 1, 1})
F["map.glow"] = File("Interface\\Glues\\Models\\UI_Draenei\\GenericGlow64", nil, {tint = {1, .82, .35}, blend = "ADD"})
F["map.banner"] = {kind = "colour", id = {0, 0, 0, .55}}
F["card"] = {kind = "colour", id = {.03, .035, .045, .97}}
F["whack.golden"] = File("Interface\\Glues\\Models\\UI_Draenei\\GenericGlow64", nil, {tint = {1, .82, .25}, blend = "ADD"})
F["whack.decoyAlliance"] = {{kind = "display", id = 6973}, Icon(ICON .. "INV_Misc_Head_Gnome_01")}
F["whack.decoyHorde"] = {{kind = "display", id = 10038}, Icon(ICON .. "INV_Misc_Head_Orc_01")}
F["whack.bossPeon"] = {{kind = "display", id = 10038}, Icon(ICON .. "INV_Misc_Head_Orc_01")}
F["whack.bossGnome"] = {{kind = "display", id = 7028}, Icon(ICON .. "INV_Misc_Head_Gnome_01")}
F["hole"] = {kind = "colour", id = {0, 0, 0, 0}}
-- By pattern: every zone, plate and mallet.
local ZONE_FALLBACK = {
    ground = File("Interface\\Garrison\\ClassHallBackground"),
    frame = {kind = "colour", id = {.66, .48, .28, 1}},   -- the metal rim, flat
    tint = {kind = "colour", id = {.6, .6, .6, 1}},
    icon = Icon(ICON .. "Spell_Nature_Polymorph"),
    boss = Icon(ICON .. "INV_Misc_Head_Dragon_01"),
    bossIcon = Icon(ICON .. "INV_Misc_Head_Dragon_01"),
}
local MALLET_FALLBACK = {"INV_Hammer_15", "INV_Hammer_16", "INV_Hammer_15", "INV_Hammer_16", "INV_Hammer_15", "INV_Hammer_15"}
function MG:Fallback(role)
    if F[role] then return F[role] end
    if type(role) ~= "string" then return nil end
    local part = role:match("^zone%.%w+%.(%a+)$")
    if part then return ZONE_FALLBACK[part] end
    local race = role:match("^plate%.(%a+)$") or role:match("^piece%.(%a+)%.plate$")
    if race then
        local colour = A["piece." .. race .. ".colour"]
        return Disc(colour and colour.id or {.7, .7, .7})
    end
    local n = tonumber(role:match("^mallet%.(%d)$"))
    if n and MALLET_FALLBACK[n] then return Icon(ICON .. MALLET_FALLBACK[n]) end
    return nil
end

-- Lookups ---------------------------------------------------------------------------------

function MG:Asset(role)
    if type(role) ~= "string" then return nil end
    local key, rest = role:match("^zone%.(%w+)%.(.+)$")
    if key and self.ZONE_ALIAS[key] then role = "zone." .. self.ZONE_ALIAS[key] .. "." .. rest end
    return A[role]
end

local function HasAtlas(name)
    local info = type(C_Texture) == "table" and C_Texture.GetAtlasInfo
    if type(name) ~= "string" or type(info) ~= "function" then return false end
    local ok, found = pcall(info, name)
    return ok and found ~= nil
end
local function Try(object, method, ...)
    local fn = object and object[method]
    if type(fn) ~= "function" then return false end
    return (pcall(fn, object, ...))
end
-- A boost's art for the faction (Heroism's icon for the Alliance).
local function ForFaction(entry)
    if entry and entry.alliance and MG.Faction() == "Alliance" then return entry.alliance end
    return entry
end
local function Dress(texture, entry, opts)
    local tint = opts.tint or entry.tint
    if tint then
        texture:SetVertexColor(tint[1] or 1, tint[2] or 1, tint[3] or 1, tint[4] or 1)
    else
        texture:SetVertexColor(1, 1, 1, 1)
    end
    Try(texture, "SetDesaturated", entry.desaturate == true)
    if opts.plain then return end
    if entry.alpha then texture:SetAlpha(entry.alpha) end
    -- Light added, or laid on plainly; never another mode.
    if entry.blend == "ADD" then texture:SetBlendMode("ADD") elseif entry.blend == "BLEND" then texture:SetBlendMode("BLEND") end
end
-- One entry (or a list of them, first that draws) on a texture.
local function Apply(texture, entry, opts, depth)
    if type(entry) ~= "table" or depth > 6 then return nil end
    if entry.kind == nil and #entry > 0 then
        for _, each in ipairs(entry) do
            local kind = Apply(texture, each, opts, depth + 1)
            if kind then return kind end
        end
        return nil
    end
    entry = ForFaction(entry)
    local kind = entry.kind
    if kind == "atlas" then
        if HasAtlas(entry.id) and type(texture.SetAtlas) == "function" and pcall(texture.SetAtlas, texture, entry.id) then
            Dress(texture, entry, opts)
            return "atlas"
        end
    elseif kind == "file" then
        local wrap = opts.wrap
        local ok, set = pcall(texture.SetTexture, texture, entry.id, wrap, wrap)
        if ok and set ~= false then
            local c = opts.coords or entry.coords
            if c then texture:SetTexCoord(c[1], c[2], c[3], c[4]) else texture:SetTexCoord(0, 1, 0, 1) end
            Dress(texture, entry, opts)
            return "file"
        end
    elseif kind == "colour" then
        local c = entry.id
        texture:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1)
        texture:SetVertexColor(1, 1, 1, 1)
        return "colour"
    end
    return Apply(texture, entry.alt, opts, depth + 1)
end
function MG:Art(texture, role, opts)
    if type(texture) ~= "table" then return nil end
    opts = type(opts) == "table" and opts or EMPTY
    local drawn = Apply(texture, self:Asset(role), opts, 0) or Apply(texture, self:Fallback(role), opts, 0)
    if not drawn and type(opts.colour) == "table" then
        local c = opts.colour
        texture:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1)
        drawn = "colour"
    end
    texture:SetShown(drawn ~= nil)
    return drawn
end
-- The first file (never an atlas, display or colour) of an entry and its alts.
local function FirstFile(entry, depth)
    if type(entry) ~= "table" or depth > 6 then return nil end
    if entry.kind == nil and #entry > 0 then
        for _, each in ipairs(entry) do
            local value = FirstFile(each, depth + 1)
            if value ~= nil then return value end
        end
        return nil
    end
    entry = ForFaction(entry)
    if entry.kind == "file" then return entry.id end
    return FirstFile(entry.alt, depth + 1)
end
function MG:ArtValue(role)
    local value = FirstFile(self:Asset(role), 0)
    if value == nil then value = FirstFile(self:Fallback(role), 0) end
    return value
end
function MG:Colour3(role, fallback)
    local entry = self:Asset(role)
    if not (entry and entry.kind == "colour") and fallback == nil then entry = self:Fallback(role) end
    local c = entry and entry.kind == "colour" and entry.id or fallback
    if type(c) ~= "table" then return .7, .7, .7 end
    return c[1] or .7, c[2] or .7, c[3] or .7
end
function MG:Words(role, fallback)
    local entry = self:Asset(role)
    if entry and entry.kind == "text" and type(entry.id) == "string" then return entry.id end
    return fallback
end

-- Models and their framing ------------------------------------------------------------------

MG.TUNE = {}
local function Saved()
    local saved = EraUI:GetSetting("miniGameTune")
    return type(saved) == "table" and saved or nil
end
function MG:TuneDefaults(key, defaults)
    if type(key) == "string" and type(defaults) == "table" then self.TUNE[key] = defaults end
end
function MG:Tune(key)
    local out = {}
    for field, value in pairs(self.TUNE[key] or EMPTY) do out[field] = value end
    local saved = Saved()
    local mine = saved and type(saved[key]) == "table" and saved[key] or EMPTY
    for field, value in pairs(mine) do
        local kind = type(value)
        if type(field) == "string" and (kind == "boolean" or kind == "string"
            or (kind == "number" and value == value and value > -math.huge and value < math.huge)) then
            out[field] = value
        end
    end
    return out
end
function MG:SetTune(key, field, value)
    if type(key) ~= "string" or type(field) ~= "string" then return false end
    local saved = Saved()
    if not saved then
        saved = {}
        EraUI:SetSetting("miniGameTune", saved)
    end
    if type(saved[key]) ~= "table" then saved[key] = {} end
    saved[key][field] = value
    return true
end
function MG:ClearTune(key)
    local saved = Saved()
    if not saved then return end
    if key == nil then
        EraUI:SetSetting("miniGameTune", {})
    else
        saved[key] = nil
    end
end
function MG:FrameModel(model, key, baseTurn)
    if type(model) ~= "table" then return false end
    local tune = self:Tune(key)
    if type(tune.zoom) == "number" then Try(model, "SetPortraitZoom", tune.zoom) end
    if type(tune.cam) == "number" then Try(model, "SetCamDistanceScale", tune.cam) end
    if type(tune.up) == "number" then Try(model, "SetPosition", 0, 0, tune.up) end
    if type(tune.turn) == "number" or type(baseTurn) == "number" then
        Try(model, "SetRotation", (tonumber(baseTurn) or 0) + math.rad(tonumber(tune.turn) or 0))
    end
    local insets = tune.insets
    if type(insets) == "table" then Try(model, "SetViewInsets", insets[1] or 0, insets[2] or 0, insets[3] or 0, insets[4] or 0) end
    return true
end
-- The display IDs of an entry and its alts, in order.
local function Displays(entry, out, depth)
    if type(entry) ~= "table" or depth > 6 then return out end
    if entry.kind == nil and #entry > 0 then
        for _, each in ipairs(entry) do Displays(each, out, depth + 1) end
        return out
    end
    if entry.kind == "display" and type(entry.id) == "number" then out[#out + 1] = entry.id end
    return Displays(entry.alt, out, depth + 1)
end
function MG:Model(model, role, tuneKey, baseTurn)
    if type(model) ~= "table" or type(model.SetDisplayInfo) ~= "function" then return false end
    local ids = Displays(self:Asset(role), {}, 0)
    Displays(self:Fallback(role), ids, 0)
    for _, id in ipairs(ids) do
        if pcall(model.SetDisplayInfo, model, id) then
            if tuneKey then self:FrameModel(model, tuneKey, baseTurn) end
            return true, id
        end
    end
    return false
end
