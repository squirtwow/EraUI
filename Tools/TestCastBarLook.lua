-- The 1.x look on the game's cast bars, piece by piece (Look/CastKit.lua,
-- CastDress.lua, CastModule.lua; clean-room 2026-10-21), against a mock of
-- Forever's player, pet, target, focus and boss cast bars (their pieces,
-- anchors, finish animations and the game's own methods). The game's bars
-- and pieces are sealed: a key written on one fails, and EraUI running one
-- of the game's own methods fails. Checked: the CLASSIC and UNITFRAME shapes
-- (also when Edit Mode locks your bar to the player frame), the OVERLAY look
-- left alone, the ground, spark, flash and shield, the modern effects hidden
-- after the game shows them again, the finish animations stopped; where the
-- target's and focus's bars sit (under the aura row, a target of target, an
-- elite, Thick Frames, the small focus); a bar the game guards in a fight is
-- neither resized nor moved; turning Cast Bars off; the registry and its hooks.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
unpack = unpack or table.unpack

-- Mock objects -------------------------------------------------------------------
local info = setmetatable({}, { __mode = "k" }) -- each object's state, beside it
local Methods = {}
local fromGame = false -- the game's own code is running (not EraUI's)
local writes = 0       -- EraUI's writes on the game's objects

local function N(...)
    local out = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        out[i] = type(v) == "number" and string.format("%g", v) or tostring(v)
    end
    return table.concat(out, ",")
end
local function New(kind, parent, name)
    local obj = {}
    info[obj] = { kind = kind, parent = parent, name = name, anchors = {}, w = 0, h = 0, alpha = 1, shown = true,
        coords = "0,1,0,1", tint = "1,1,1,1", blend = "BLEND", level = 1, scale = 1, stops = 0 }
    return setmetatable(obj, {
        __index = Methods,
        __newindex = function(t, key, value)
            if info[t].sealed then error("wrote key " .. tostring(key) .. " on the game's " .. tostring(info[t].name), 2) end
            rawset(t, key, value)
        end,
    })
end
local function Seal(obj) info[obj].sealed = true end
local function Put(owner, key, value) rawset(owner, key, value); return value end

-- A setter: counted when EraUI writes on the game's objects.
local function Setter(name, fn)
    Methods[name] = function(self, ...)
        if info[self].sealed and not fromGame then writes = writes + 1 end
        return fn(self, ...)
    end
end
Setter("SetSize", function(self, w, h) info[self].w, info[self].h = w, h end)
Setter("SetWidth", function(self, w) info[self].w = w end)
Setter("SetHeight", function(self, h) info[self].h = h end)
Setter("ClearAllPoints", function(self) info[self].anchors = {} end)
Setter("SetPoint", function(self, point, relative, relativePoint, x, y)
    local list = info[self].anchors
    for i, old in ipairs(list) do if old[1] == point then table.remove(list, i) break end end
    list[#list + 1] = { point, relative, relativePoint or point, x or 0, y or 0 }
end)
Setter("SetAllPoints", function(self, relative)
    info[self].anchors = { { "TOPLEFT", relative, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", relative, "BOTTOMRIGHT", 0, 0 } }
end)
Setter("SetTexture", function(self, file) info[self].file, info[self].atlas, info[self].colour = file, nil, nil; return true end)
Setter("SetAtlas", function(self, atlas) info[self].atlas, info[self].file, info[self].colour = atlas, nil, nil end)
Setter("SetColorTexture", function(self, ...) info[self].colour, info[self].file, info[self].atlas = N(...), nil, nil end)
Setter("SetTexCoord", function(self, ...) info[self].coords = N(...) end)
Setter("SetVertexColor", function(self, ...) info[self].tint = N(...) end)
Setter("SetBlendMode", function(self, mode) info[self].blend = mode end)
Setter("SetAlpha", function(self, a) info[self].alpha = a end)
Setter("Show", function(self) info[self].shown = true end)
Setter("Hide", function(self) info[self].shown = false end)
Setter("SetShown", function(self, on) info[self].shown = on and true or false end)
Setter("SetFontObject", function(self, font) info[self].font = font end)
Setter("SetJustifyH", function(self, side) info[self].justify = side end)
Setter("SetScale", function(self, scale) info[self].scale = scale end)
Setter("SetStatusBarTexture", function(self, file) info[info[self].fill].file, info[info[self].fill].atlas = file, nil end)
Setter("SetStatusBarColor", function(self, ...) info[self].fillColour = N(...) end)
Setter("SetMinMaxValues", function() end)
Setter("SetValue", function() end)
function Methods:GetPoint(i)
    local a = info[self].anchors[i or 1]
    if a then return a[1], a[2], a[3], a[4], a[5] end
end
function Methods:GetNumPoints() return #info[self].anchors end
function Methods:GetParent() return info[self].parent end
function Methods:GetScale() return info[self].scale end
function Methods:GetFrameLevel() return info[self].level end
function Methods:IsProtected() return info[self].protected == true end
function Methods:IsShown() return info[self].shown end
function Methods:GetAtlas() return info[self].atlas end
function Methods:GetStatusBarTexture() return info[self].fill end
function Methods:GetStatusBarColor() return 1, 1, 1, 1 end
function Methods:Stop() info[self].stops = info[self].stops + 1 end
function Methods:HookScript(script)
    info[self].scriptHooks = (info[self].scriptHooks or "") .. script .. " "
end
function Methods:SetScript() error("EraUI set a script on the game's " .. tostring(info[self].name)) end

-- The game's code runs as itself; a post-hook runs as EraUI's.
local hooked = {}
hooksecurefunc = function(owner, key, after)
    if type(owner) == "string" then owner, key, after = _G, owner, key end
    local original = owner[key]
    local id = tostring(info[owner] and info[owner].name or "?") .. ":" .. key
    hooked[id] = (hooked[id] or 0) + 1
    rawset(owner, key, function(...)
        local result = original(...)
        local was = fromGame
        fromGame = false
        after(...)
        fromGame = was
        return result
    end)
end
local function Game(obj, method, ...)
    local was = fromGame
    fromGame = true
    obj[method](obj, ...)
    fromGame = was
end

-- The game -------------------------------------------------------------------------
local combat = false
InCombatLockdown = function() return combat end
issecretvalue = function() return false end
GetTime = function() return 0 end
CreateFrame = function() error("EraUI made a frame with Rounded Cast Bars off") end
UnitChannelInfo = function() end

local EFFECT_KEYS = { "Flakes01", "StandardGlow", "InterruptGlow", "DropShadow", "TextBorder" }
local bars, frames

-- A cast bar as Forever builds it: small for the target's, focus's and boss's.
local function Bar(name, parent, small)
    local bar = New("StatusBar", parent, name)
    info[bar].fill = New("Texture", bar, name .. "Fill")
    info[bar].w, info[bar].h, info[bar].level = small and 150 or 208, small and 10 or 11, 4
    local function Piece(key, kind, w, h, ...)
        local piece = Put(bar, key, New(kind or "Texture", bar, key))
        info[piece].w, info[piece].h = w, h
        for _, a in ipairs({ ... }) do table.insert(info[piece].anchors, { a[1], bar, a[2], a[3], a[4] }) end
        return piece
    end
    info[Piece("Border", nil, 0, 0, { "TOPLEFT", "TOPLEFT", -1, 2 }, { "BOTTOMRIGHT", "BOTTOMRIGHT", 1, -2 })].atlas = "ui-castingbar-frame"
    local shield = Piece("BorderShield", nil, 29, 33, { "TOPLEFT", "TOPLEFT", -27, 4 })
    info[shield].atlas, info[shield].shown = "ui-castingbar-shield", false
    Piece("Icon", nil, small and 20 or 16, small and 20 or 16, { "RIGHT", "LEFT", small and -2 or -5, small and -5 or 0 })
    info[Piece("Spark", nil, 6, 16, { "CENTER", "CENTER", 0, 0 })].atlas = "ui-castingbar-pip"
    local flash = Piece("Flash", nil, 0, 0, { "TOPLEFT", "TOPLEFT", -1, 1 }, { "BOTTOMRIGHT", "BOTTOMRIGHT", 1, -1 })
    info[flash].atlas, info[flash].blend = "ui-castingbar-full-glow-standard", "ADD"
    info[Piece("Background", nil, 0, 0, { "TOPLEFT", "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0 })].atlas = "ui-castingbar-background"
    for _, key in ipairs(EFFECT_KEYS) do info[Piece(key, nil, 20, 20, { "CENTER", "CENTER", 0, 0 })].atlas = "modern-" .. key end
    local text = Piece("Text", "FontString", small and 0 or 185, 16, { "TOP", "TOP", 0, -10 })
    info[text].font = small and "SystemFont_Shadow_Small" or "GameFontHighlightSmall"
    for _, key in ipairs({ "StandardFinish", "ChannelFinish", "CraftingFinish" }) do Put(bar, key, New("AnimationGroup", bar, key)) end
    -- The game's own methods: hooked by EraUI, never run by it.
    local function Method(method, fn)
        rawset(bar, method, function(self, ...)
            assert(fromGame, "EraUI ran the game's " .. method)
            if fn then return fn(self, ...) end
        end)
    end
    Method("SetLook", function(self, look) rawset(self, "look", look) end)
    Method("UpdateShownState", function(self) self:Show() end)
    Method("UpdateBarFillTexture", function(self, atlas) info[info[self].fill].atlas, info[info[self].fill].file = atlas, nil end)
    -- The modern spark effects shown again, as the game does on each cast.
    Method("ShowSpark", function(self) self.Spark:Show(); self.StandardGlow:Show(); self.StandardGlow:SetAlpha(1) end)
    Method("PlayFadeAnim")
    Method("PlayFinishAnim", function(self) self.Flakes01:SetAlpha(1); self.Flakes01:Show() end)
    Method("PlayInterruptAnims", function(self) self.InterruptGlow:SetAlpha(1); self.InterruptGlow:Show() end)
    for _, method in ipairs({ "HandleCastStart", "HandleChannelUpdateDelayed", "FinishSpell", "HandleCastStop",
        "HandleInterruptOrSpellFailed" }) do
        Method(method)
    end
    if small then
        Method("AdjustPosition", function(self)
            local owner = self:GetParent()
            self:ClearAllPoints()
            if info[owner].auras then
                self:SetPoint("TOPLEFT", owner:GetAuraContainer(), "BOTTOMLEFT", 18, -10)
            elseif rawget(self, "boss") then
                self:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", -100, 17)
            else
                self:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 43, rawget(owner, "haveToT") and -46 or 5)
            end
        end)
    end
    Seal(bar)
    Seal(info[bar].fill)
    for key, piece in pairs(bar) do if type(piece) == "table" and info[piece] then Seal(piece) end end
    return bar
end

local function UnitLike(name)
    local frame = New("Button", nil, name)
    local row = New("Frame", frame, name .. "Auras")
    rawset(frame, "GetAuraContainer", function() return row end)
    return frame
end

local ns, modules, order, booked, elite, thick, reported
geterrorhandler = function() return function(problem) reported[#reported + 1] = tostring(problem) end end
local function Load(settings)
    combat, writes, hooked, booked, reported = false, 0, {}, 0, {}
    elite, thick = {}, {}
    frames = { target = UnitLike("TargetFrame"), focus = UnitLike("FocusFrame"), boss = UnitLike("Boss1TargetFrame") }
    bars = {
        player = Bar("PlayerCastingBarFrame", nil, false), pet = Bar("PetCastingBarFrame", nil, false),
        target = Bar("TargetFrameSpellBar", frames.target, true), focus = Bar("FocusFrameSpellBar", frames.focus, true),
        boss = Bar("Boss1SpellBar", frames.boss, true),
    }
    rawset(bars.player, "look", "CLASSIC")
    rawset(bars.pet, "look", "CLASSIC")
    rawset(bars.boss, "boss", "boss1")
    -- The game's small focus (FocusFrameMixin:SetSmallSize): its bar scaled up.
    rawset(frames.focus, "SetSmallSize", function(self, small)
        assert(fromGame, "EraUI ran the game's SetSmallSize")
        rawset(self, "smallSize", small)
        bars.focus:SetScale(small and 1.333 or 1)
    end)
    for key, frame in pairs(frames) do Put(frame, "spellbar", bars[key]); Seal(frame) end
    PlayerCastingBarFrame, PetCastingBarFrame = bars.player, bars.pet
    TargetFrame, FocusFrame = frames.target, frames.focus
    BossTargetFrameContainer = { BossTargetFrames = { frames.boss } }
    MirrorTimerContainer = nil
    modules, order = {}, {}
    ns = {}
    ns.RegisterModule = function(key, entry) modules[key] = entry; order[#order + 1] = key end
    ns.ApplyAll = function() booked = booked + 1 end
    ns.UnitFrameOwn = function(frame, key) if key == "haveElite" then return elite[frame] end end
    ns.ThickCastY = function(frame) return thick[frame] end
    local E = { Classic = ns, GetSetting = function(_, key) return (settings or {})[key] end }
    for _, file in ipairs({ "Look/Base.lua", "Look/CastKit.lua", "Look/CastDress.lua", "Look/CastRound.lua", "Look/CastBoss.lua",
        "Look/CastModule.lua", "Look/MirrorTimers.lua" }) do
        assert(loadfile(file))("EraUI", E)
    end
end

local function Where(obj, i)
    local a = info[obj].anchors[i or 1]
    if not a then return "none" end
    local relative = a[2] and (info[a[2]].name or info[a[2]].kind) or "nil"
    return a[1] .. ">" .. relative .. ":" .. a[3] .. "(" .. N(a[4], a[5]) .. ")"
end
local function All(obj)
    local out = {}
    for i = 1, #info[obj].anchors do out[i] = Where(obj, i) end
    return #out .. " " .. table.concat(out, " ")
end
local function Size(obj) return info[obj].w .. "x" .. info[obj].h end
local BORDER, SMALL_BORDER = "Interface\\CastingBar\\UI-CastingBar-Border", "Interface\\CastingBar\\UI-CastingBar-Border-Small"
local FLASH, SMALL_FLASH = "Interface\\CastingBar\\UI-CastingBar-Flash", "Interface\\CastingBar\\UI-CastingBar-Flash-Small"

-- 1. The registry ----------------------------------------------------------------------
Load()
equal(table.concat(order, " "), "castBars mirrorTimers", "castBars, then mirrorTimers")
equal(type(modules.castBars.init) .. " " .. type(modules.castBars.apply) .. " " .. type(modules.castBars.restore),
    "function function function", "castBars: a login step, apply and restore")
modules.castBars.init()
equal(writes, 0, "the login step touches no bar")

-- 2. Your bar on its own: the CLASSIC shape --------------------------------------------
modules.castBars.apply()
local p = bars.player
equal(Size(p), "195x13", "your bar 195 x 13")
equal(tostring(info[p.Border].file) .. " " .. info[p.Border].coords .. " " .. Size(p.Border) .. " " .. All(p.Border),
    BORDER .. " 0,1,0,1 256x64 1 TOP>PlayerCastingBarFrame:TOP(0,28)", "the 1.x border sheet over it")
equal(tostring(info[p.BorderShield].file) .. " " .. Size(p.BorderShield) .. " " .. All(p.BorderShield),
    BORDER .. " 256x64 1 TOP>PlayerCastingBarFrame:TOP(0,28)", "the shield: the plain border (1.x had no other)")
equal(Size(p.Text) .. " " .. All(p.Text) .. " " .. tostring(info[p.Text].font), "185x16 1 TOP>PlayerCastingBarFrame:TOP(0,5) GameFontHighlight",
    "the name on the bar in the 1.x font")
equal(Size(p.Icon) .. " " .. All(p.Icon), "16x16 1 RIGHT>PlayerCastingBarFrame:LEFT(-5,0)", "the icon left to the game")
local bg = info[p.Background]
equal(tostring(bg.atlas) .. " " .. tostring(bg.file) .. " " .. tostring(bg.colour) .. " " .. All(p.Background),
    "nil nil 0,0,0,0.5 2 TOPLEFT>PlayerCastingBarFrame:TOPLEFT(0,0) BOTTOMRIGHT>PlayerCastingBarFrame:BOTTOMRIGHT(0,0)",
    "the ground: black at half alpha over the whole bar")
local spark = info[p.Spark]
equal(tostring(spark.file) .. " " .. spark.coords .. " " .. Size(p.Spark) .. " " .. spark.blend .. " " .. All(p.Spark),
    "Interface\\CastingBar\\UI-CastingBar-Spark 0,1,0,1 32x32 ADD 1 CENTER>PlayerCastingBarFrame:CENTER(0,0)",
    "the static glowing spark, placed by the game")
local flash = info[p.Flash]
equal(tostring(flash.file) .. " " .. flash.coords .. " " .. flash.blend .. " " .. Size(p.Flash) .. " " .. All(p.Flash) .. " " .. flash.tint,
    FLASH .. " 0,1,0,1 ADD 256x64 1 TOP>PlayerCastingBarFrame:TOP(0,28) 1,1,1,1", "the white 1.x flash")
for _, key in ipairs(EFFECT_KEYS) do
    local e = info[p[key]]
    equal(tostring(e.atlas) .. " " .. tostring(e.file) .. " " .. e.alpha .. " " .. tostring(e.shown), "nil nil 0 false", key .. " out of sight")
end
equal(info[info[p].fill].file .. " " .. info[p].fillColour, "Interface\\TargetingFrame\\UI-StatusBar 1,0.7,0", "the shaded fill, yellow")

-- 3. The target's bar: the UNITFRAME shape ------------------------------------------------
local t = bars.target
equal(Size(t), "150x10", "the target's bar 150 x 10")
equal(tostring(info[t.Border].file) .. " " .. info[t.Border].h .. " " .. All(t.Border),
    SMALL_BORDER .. " 56 2 TOPLEFT>TargetFrameSpellBar:TOPLEFT(-23,23) TOPRIGHT>TargetFrameSpellBar:TOPRIGHT(23,23)", "the small border")
equal(tostring(info[t.BorderShield].file) .. " " .. info[t.BorderShield].h .. " " .. All(t.BorderShield),
    "Interface\\CastingBar\\UI-CastingBar-Small-Shield 56 2 TOPLEFT>TargetFrameSpellBar:TOPLEFT(-28,23) TOPRIGHT>TargetFrameSpellBar:TOPRIGHT(18,23)",
    "the small 1.x shield")
equal(info[t.Text].h .. " " .. All(t.Text) .. " " .. tostring(info[t.Text].font),
    "16 2 TOPLEFT>TargetFrameSpellBar:TOPLEFT(0,4) TOPRIGHT>TargetFrameSpellBar:TOPRIGHT(0,4) SystemFont_Shadow_Small", "the name on it")
equal(Size(t.Icon) .. " " .. All(t.Icon), "18x18 1 RIGHT>TargetFrameSpellBar:LEFT(-3.5,1)", "the icon to its left")
equal(tostring(info[t.Flash].file) .. " " .. info[t.Flash].h .. " " .. All(t.Flash),
    SMALL_FLASH .. " 56 2 TOPLEFT>TargetFrameSpellBar:TOPLEFT(-23,23) TOPRIGHT>TargetFrameSpellBar:TOPRIGHT(23,23)", "the small flash")
equal(Where(t), "TOPLEFT>TargetFrame:BOTTOMLEFT(43,3)", "under the target frame")
equal(Size(bars.boss) .. " " .. tostring(info[bars.boss.Border].file) .. " " .. Where(bars.boss), "150x10 " .. SMALL_BORDER .. " none",
    "a boss bar in the small look, its place the game's")

-- 4. Edit Mode locks your bar to the player frame, then frees it ----------------------------
Game(p, "SetLook", "UNITFRAME")
equal(Size(p) .. " " .. tostring(info[p.Border].file) .. " " .. Size(p.Icon), "150x10 " .. SMALL_BORDER .. " 18x18", "locked: the small look")
Game(p, "SetLook", "CLASSIC")
equal(Size(p) .. " " .. tostring(info[p.Border].file), "195x13 " .. BORDER, "free again: the big one")
-- The game's own OVERLAY look: its shape and flash left alone.
Game(p, "SetWidth", 208)
Game(p, "SetLook", "OVERLAY")
equal(Size(p) .. " " .. tostring(info[p.Border].file) .. " " .. tostring(info[p.Flash].file), "208x13 " .. BORDER .. " " .. FLASH,
    "OVERLAY: the bar's shape and flash as they were")
Game(p, "SetLook", "CLASSIC")

-- 5. The game shows its modern effects again: hidden again at once ---------------------------
Game(p, "ShowSpark")
equal(info[p.StandardGlow].alpha .. " " .. tostring(info[p.StandardGlow].shown), "0 false", "after ShowSpark")
Game(p, "PlayFinishAnim")
local stops = info[p.StandardFinish].stops .. info[p.ChannelFinish].stops .. info[p.CraftingFinish].stops
equal(info[p.Flakes01].alpha .. " " .. tostring(info[p.Flakes01].shown) .. " " .. stops, "0 false 111",
    "after PlayFinishAnim, its three finish animations stopped")
Game(p, "PlayInterruptAnims")
equal(info[p.InterruptGlow].alpha .. " " .. tostring(info[p.InterruptGlow].shown), "0 false", "after PlayInterruptAnims")
Game(p, "PlayFadeAnim")
equal(tostring(info[p.Flash].file) .. " " .. info[p.Flash].blend, FLASH .. " ADD", "the flash dressed again as it fades")

-- 6. Where the target's and focus's bars sit -----------------------------------------------
local function Placed(key) Game(bars[key], "AdjustPosition"); return Where(bars[key]) end
equal(Placed("target"), "TOPLEFT>TargetFrame:BOTTOMLEFT(43,3)", "plain: just under the frame")
rawset(frames.target, "haveToT", true)
equal(Placed("target"), "TOPLEFT>TargetFrame:BOTTOMLEFT(43,-25)", "with a target of target")
rawset(frames.target, "haveToT", nil)
elite[frames.target] = true
equal(Placed("target"), "TOPLEFT>TargetFrame:BOTTOMLEFT(43,-9)", "an elite (the unit frames' own flag)")
thick[frames.target] = -42
equal(Placed("target"), "TOPLEFT>TargetFrame:BOTTOMLEFT(43,-42)", "Thick Frames: its own number first")
thick[frames.target], elite[frames.target] = nil, nil
info[frames.target].auras = true
equal(Placed("target"), "TOPLEFT>TargetFrameAuras:BOTTOMLEFT(22,-16)", "under the aura row while auras show")
info[frames.target].auras = nil
equal(Placed("boss"), "TOPRIGHT>Boss1TargetFrame:BOTTOMRIGHT(-100,17)", "a boss bar: the game's place")
-- The game's small focus: the bar back at scale 1, at the usual spot.
Game(frames.focus, "SetSmallSize", true)
equal(info[bars.focus].scale .. " " .. Where(bars.focus), "1 TOPLEFT>FocusFrame:BOTTOMLEFT(43,3)", "the small focus: its bar at scale 1")
equal(hooked["FocusFrame:SetSmallSize"], 1, "the focus's SetSmallSize post-hooked, once")

-- 7. In a fight: a bar the game guards keeps its size and place --------------------------------
combat = true
info[t].protected = true
Game(t, "SetLook", "UNITFRAME")
Game(t, "SetWidth", 120)
Game(t, "UpdateShownState")
equal(info[t].w .. " " .. tostring(info[t.Border].file), "120 " .. SMALL_BORDER, "guarded in a fight: not resized, its pieces dressed")
rawset(frames.target, "haveToT", true)
Game(t, "AdjustPosition")
equal(Where(t), "TOPLEFT>TargetFrame:BOTTOMLEFT(43,-46)", "and not moved: the game's own place")
rawset(frames.target, "haveToT", nil)
Game(bars.focus, "UpdateShownState")
equal(Size(bars.focus), "150x10", "a bar the game doesn't guard: dressed in a fight too")
info[t].protected = false
combat = false
Game(t, "UpdateShownState")
equal(Size(t), "150x10", "after the fight: its size")

-- 8. Hooks once, whatever the passes ----------------------------------------------------------
modules.castBars.apply()
modules.castBars.apply()
local twice = {}
for id, n in pairs(hooked) do if n > 1 then twice[#twice + 1] = id end end
equal(table.concat(twice, ","), "", "every hook installed once")
equal(hooked["PlayerCastingBarFrame:HandleCastStart"] .. " " .. tostring(hooked["TargetFrameSpellBar:HandleCastStart"]), "1 nil",
    "the channel keeper on your bar only")
equal(tostring(info[p].scriptHooks) .. "| " .. tostring(info[t].scriptHooks), "OnHide OnUpdate | nil",
    "its two script hooks (never a script set) on your bar only")

-- 9. Turning Cast Bars off -----------------------------------------------------------------
ns.needsReload = nil
local beforeRestore = writes
modules.castBars.restore()
local restoreWrites = writes - beforeRestore
for _, key in ipairs({ "player", "target", "boss" }) do
    local bar = bars[key]
    equal(info[bar.Border].atlas .. " " .. info[bar.Spark].atlas .. " " .. info[bar.Flash].atlas .. " " .. info[bar.Background].atlas,
        "ui-castingbar-frame ui-castingbar-pip ui-castingbar-full-glow-standard ui-castingbar-background", key .. ": the game's four atlases back")
    equal(info[bar.Flakes01].alpha .. info[bar.TextBorder].alpha, "11", key .. ": the effects' alpha back")
end
equal(ns.needsReload, true, "the reload flag set")
local before = writes
for _, key in ipairs({ "player", "target", "boss" }) do
    Game(bars[key], "UpdateShownState")
    Game(bars[key], "UpdateBarFillTexture", "ui-castingbar-filling-standard")
    Game(bars[key], "ShowSpark")
    if bars[key].AdjustPosition then Game(bars[key], "AdjustPosition") end
end
equal(writes - before, 0, "then the hooks do nothing")
equal(tostring(ns.RefreshCastFills()) .. " " .. tostring(ns.RefreshRoundedCasts()) .. " " .. (writes - before), "true true 0",
    "and the live switches touch nothing")
ns.RefreshCastColours()
equal(writes - before, 0, "nor the colour switch")
before = writes
modules.castBars.restore()
equal(writes - before, restoreWrites, "restore again: the same cheap put-back, nothing more")

-- 10. Off since login: nothing touched -------------------------------------------------------
Load()
ns.needsReload = nil
modules.castBars.restore()
equal(writes .. " " .. tostring(ns.needsReload), "0 true", "off from the start: no bar touched, the reload flag set")
Game(bars.player, "UpdateShownState")
equal(writes .. " " .. tostring(hooked["PlayerCastingBarFrame:UpdateShownState"]), "0 nil", "and nothing hooked")

equal(table.concat(reported, " | "), "", "no error reported along the way")
print("Cast bar look checks passed: " .. checks .. " assertions.")
