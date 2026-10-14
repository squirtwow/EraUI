-- Raid-style Party Outline (Appearance > Style > Frame Style) on the real
-- Classic/PartyOutline.lua, with Classic/Textures.lua, Classic/Skin.lua,
-- Core/Appearance.lua (Dark Mode's grey and the Darkness slider) and
-- Classic/ThickFrames.lua (loaded as in the game), against a mock of
-- Forever's raid-style party frame: CompactPartyFrame under PartyFrame, five
-- members and five pets (each with a health and a power bar in the game's
-- own atlases) and the border the game keeps round the members while Edit
-- Mode's Display Border is on, laid out as Forever's CompactRaidGroup.lua
-- lays them out. Every piece's place is worked out through its anchors.
-- Checked: off (the default) makes nothing, hooks nothing and touches none
-- of the game's frames. On: one outline an edge (5) out from the members on
-- every side, its soft corners (its own 6, quarters of the portrait mask)
-- and bands tiling it with no gap or overlap; the fine line one unit wide,
-- 2 to 1 units outside the members, its square corner clear of the round
-- one (bronze; Dark Mode's grey, live
-- with the slider, in a fight too); a level under the members, made on the
-- game's border so it shows only while that shows; the border's own fill
-- faded. It follows a smaller group, bigger frames and the horizontal
-- layout with no call of EraUI's (a fight changes nothing). Every bar of the
-- ten frames in the solid square, colours untouched; switched off, each
-- one's own atlas back, the border's fill back: the same as a game never
-- switched on. A bar whose art can't be read is left alone. A switch in a
-- fight touches nothing and books the pass after it. While Forever Enhanced
-- Raid Frames draws the party nothing is drawn and everything goes back.
-- A party frame made late: one post-hook, then the look. No key written on
-- the game's frames, nothing of Edit Mode's touched.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
unpack = unpack or table.unpack
local pack = table.pack or function(...) return { n = select("#", ...), ... } end
local function N(v) return string.format("%g", math.floor(v * 1000 + .5) / 1000) end
local function C(r, g, b, a) return string.format("%.3f,%.3f,%.3f,%.3f", r, g, b, a or 1) end

-- Mock widgets ------------------------------------------------------------------------
-- Each object's state lives beside it (S), never on it, so a key written on
-- one of the game's objects shows up in writes as "Name.key"; while logging,
-- every call made on one of them is listed as "Name:Method".
local S = setmetatable({}, { __mode = "k" })
local Proto = {}
local writes, calls, logging = {}, {}, false
local made = {} -- every object made by CreateFrame or CreateTexture (EraUI's), in order
local VERBS = { "Set", "Get", "Enable", "Disable", "Register", "Unregister", "Clear" }
local function Verb(key)
    if type(key) ~= "string" then return false end
    for _, verb in ipairs(VERBS) do
        if key:sub(1, #verb) == verb and key:sub(#verb + 1, #verb + 1):match("^%u") then return true end
    end
    return false
end
local function Noop() end
local function New(kind, name, parent, game, layer)
    local obj = {}
    S[obj] = { kind = kind, name = name, parent = parent, game = game, points = {}, w = 0, h = 0, alpha = 1, shown = true,
        level = (parent and S[parent] and S[parent].level or 0) + 1, layer = layer, tint = C(1, 1, 1, 1), coords = "0,1,0,1",
        scripts = {} }
    if not game then made[#made + 1] = obj end
    return setmetatable(obj, {
        __index = function(_, key)
            local fn = Proto[key] or (Verb(key) and Noop)
            if not fn then return nil end
            return function(self, ...)
                local st = S[self]
                if logging and st and st.game then calls[#calls + 1] = tostring(st.name) .. ":" .. key end
                return fn(self, ...)
            end
        end,
        __newindex = function(t, key, value)
            if S[t].game then writes[#writes + 1] = tostring(S[t].name or S[t].kind) .. "." .. tostring(key) end
            rawset(t, key, value)
        end,
    })
end
local SHEET = "Interface\\RaidFrame\\RaidFrameSheet" -- the file an atlas sits in
function Proto:GetName() return S[self].name end
function Proto:GetParent() return S[self].parent end
function Proto:SetParent(p) S[self].parent = p end
function Proto:IsObjectType(kind) return S[self].kind == kind end
function Proto:GetFrameLevel() return S[self].level end
function Proto:SetFrameLevel(v) S[self].level = v end
function Proto:IsShown() return S[self].shown end
function Proto:IsVisible()
    local s = S[self]
    if not s.shown then return false end
    return s.parent == nil or s.parent:IsVisible()
end
function Proto:Show() S[self].shown = true end
function Proto:Hide() S[self].shown = false end
function Proto:SetShown(v) S[self].shown = v and true or false end
function Proto:SetAlpha(a) S[self].alpha = a end
function Proto:GetAlpha() return S[self].alpha end
function Proto:EnableMouse(v) S[self].mouse = v end
function Proto:ClearAllPoints() S[self].points = {} end
function Proto:SetPoint(point, rel, relPoint, x, y)
    if type(rel) == "number" then rel, relPoint, x, y = nil, nil, rel, relPoint end
    table.insert(S[self].points, { point, rel or S[self].parent, relPoint or point, x or 0, y or 0 })
end
function Proto:SetAllPoints(rel)
    rel = rel or S[self].parent
    S[self].points = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0 } }
end
function Proto:GetNumPoints() return #S[self].points end
function Proto:GetPoint(i) local p = S[self].points[i or 1]; if p then return p[1], p[2], p[3], p[4], p[5] end end
function Proto:SetSize(w, h) S[self].w, S[self].h = w, h end
function Proto:SetWidth(w) S[self].w = w end
function Proto:SetHeight(h) S[self].h = h end
function Proto:GetWidth() return S[self].w end
function Proto:GetHeight() return S[self].h end
function Proto:SetScript(name, fn) S[self].scripts[name] = fn end
function Proto:HookScript(name) S[self].hooked = (S[self].hooked or 0) + 1 end
function Proto:IsProtected() return S[self].protected == true end
function Proto:CreateTexture(_, layer) return New("Texture", nil, self, false, layer or "ARTWORK") end
function Proto:SetTexture(file) local s = S[self]; s.texture, s.colour, s.atlas = file, nil, nil; return true end
function Proto:GetTexture() local s = S[self]; if s.secretArt then return SECRET end; return s.texture end
function Proto:SetColorTexture(r, g, b, a) local s = S[self]; s.colour, s.texture, s.atlas = C(r, g, b, a), nil, nil end
function Proto:SetVertexColor(r, g, b, a) S[self].tint = C(r, g, b, a) end
function Proto:SetTexCoord(...) local c = {}; for i, v in ipairs({ ... }) do c[i] = N(v) end; S[self].coords = table.concat(c, ",") end
function Proto:SetAtlas(atlas) local s = S[self]; s.atlas, s.texture, s.colour = atlas, SHEET, nil end
function Proto:GetAtlas() local s = S[self]; if s.secretArt then return SECRET end; return s.atlas end
-- A status bar: a file or one of the game's atlases (a name with no path)
-- on its fill; the colour is the bar's own and stays through the change.
function Proto:SetStatusBarTexture(asset)
    local fill = S[self].fill
    if type(asset) == "string" and not asset:find("\\", 1, true) then fill:SetAtlas(asset) else fill:SetTexture(asset) end
    return true
end
function Proto:GetStatusBarTexture() return S[self].fill end
function Proto:SetStatusBarColor(r, g, b, a) S[self].colour = { r, g, b, a } end
function Proto:GetStatusBarColor() local c = S[self].colour; return c[1], c[2], c[3], c[4] end

-- Where a region sits on the screen (left, top, right, bottom; y goes up),
-- worked out through its anchors as the game lays it out. The game's frames
-- with a fixed place have it; everything else is placed by its points.
local FRAC = { TOPLEFT = { 0, 0 }, TOP = { .5, 0 }, TOPRIGHT = { 1, 0 }, LEFT = { 0, .5 }, CENTER = { .5, .5 },
    RIGHT = { 1, .5 }, BOTTOMLEFT = { 0, 1 }, BOTTOM = { .5, 1 }, BOTTOMRIGHT = { 1, 1 } }
local function Rect(obj, depth)
    local s = S[obj]
    depth = (depth or 0) + 1
    assert(depth < 40, "anchor loop")
    if s.fixed then return s.fixed[1], s.fixed[2], s.fixed[1] + s.w, s.fixed[2] - s.h end
    assert(#s.points > 0, tostring(s.name or s.kind) .. " has no place")
    local w, h = s.w or 0, s.h or 0
    local left, right, top, bottom, cx, cy
    for _, p in ipairs(s.points) do
        local l, t, r, b = Rect(p[2], depth)
        local f = assert(FRAC[p[3]], "point " .. tostring(p[3]))
        local ax, ay = l + f[1] * (r - l) + p[4], t - f[2] * (t - b) + p[5]
        local g = assert(FRAC[p[1]], "point " .. tostring(p[1]))
        if g[1] == 0 then left = ax elseif g[1] == 1 then right = ax else cx = ax end
        if g[2] == 0 then top = ay elseif g[2] == 1 then bottom = ay else cy = ay end
    end
    if not left then left = right and right - w or cx - w / 2 end
    right = right or left + w
    if not top then top = bottom and bottom + h or cy + h / 2 end
    bottom = bottom or top - h
    return left, top, right, bottom
end
local function RectText(obj) local l, t, r, b = Rect(obj); return N(l) .. "," .. N(t) .. "," .. N(r) .. "," .. N(b) end
-- The rect a few units out from another (o: out on every side), as text.
local function Out(l, t, r, b, o) return N(l - o) .. "," .. N(t + o) .. "," .. N(r + o) .. "," .. N(b - o) end
local function Area(l, t, r, b) return math.max(0, r - l) * math.max(0, t - b) end
local function Overlap(a, b)
    local l1, t1, r1, b1 = Rect(a)
    local l2, t2, r2, b2 = Rect(b)
    return Area(math.max(l1, l2), math.min(t1, t2), math.min(r1, r2), math.max(b1, b2))
end

-- The game -----------------------------------------------------------------------
local combat = false
SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
local secret = { [SECRET] = true }
issecretvalue = function(v) return v ~= nil and secret[v] == true end
InCombatLockdown = function() return combat end
GetTime = function() return 100 end
CreateFrame = function(kind, name, parent) return New(kind, name, parent, false) end
CreateFont = function() return { SetFontObject = Noop, SetTextColor = Noop } end
CreateColor = function(r, g, b) return { GetRGB = function() return r, g, b end } end
local hooks = {} -- the names EraUI hooked, in order
hooksecurefunc = function(t, key, fn)
    if type(t) == "string" then t, key, fn = _G, t, key end
    hooks[#hooks + 1] = key
    local old = rawget(t, key)
    rawset(t, key, function(...) local r = pack(old(...)); fn(...); return unpack(r, 1, r.n) end)
end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function RunTimers()
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do fn() end
end
RAID_CLASS_COLORS = { WARRIOR = { r = .78, g = .61, b = .43 }, PRIEST = { r = 1, g = 1, b = 1 } }
-- Edit Mode: any key read on it at all is counted.
local editMode = 0
EditModeManagerFrame = setmetatable({}, { __index = function() editMode = editMode + 1; return Noop end,
    __newindex = function() editMode = editMode + 1 end })

-- Forever's raid-style party frame, keyed as its templates build it (keys set
-- before EraUI loads, as the game's XML does): five members and five pets,
-- each a health bar (atlas RaidFrame-Hp-Fill, the class colour) and a power
-- bar (atlas _RaidFrame-Resource-Fill, the power colour), the title, and the
-- border with its fill (atlas options_frame_child). The members are 72 x 36
-- (Edit Mode's Frame Width and Height), the pets 72 x 18.
local W, H, PET_H, TITLE = 72, 36, 18, 14
local HP, POWER = "RaidFrame-Hp-Fill", "_RaidFrame-Resource-Fill"
local SOLID = "Interface\\Buttons\\WHITE8X8"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local function G(kind, name, parent, w, h, layer)
    local o = New(kind, name, parent, true, layer)
    if w then S[o].w, S[o].h = w, h end
    return o
end
local function Put(obj, key, value) rawset(obj, key, value); return value end
local function Fixed(obj, l, t) S[obj].fixed = { l, t } end
local game -- the game's pieces
local function Bar(parent, name, atlas, r, g, b)
    local bar = G("StatusBar", name, parent)
    S[bar].fill = G("Texture", name .. "Texture", bar, nil, nil, "BORDER")
    S[S[bar].fill].atlas, S[S[bar].fill].texture = atlas, SHEET
    S[bar].colour = { r, g, b, 1 }
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -1, 9)
    return bar
end
-- The game's layout (Forever's CompactRaidGroup_UpdateLayout and
-- SetupBorderFrameAnchor): members top to bottom (or left to right) from
-- under the title, the group sized round them, the border pinned 2 out from
-- the first member's top left and the last shown member's bottom right, 3
-- below. count: members shown; border: Display Border (on unless false).
local function Layout(count, horizontal, border)
    local was = logging
    logging = false
    local g, m = game.group, game.members
    border = border ~= false
    S[game.border].shown = border
    for i = 1, 5 do S[m[i]].shown = i <= count end
    m[1]:ClearAllPoints()
    if horizontal then m[1]:SetPoint("TOPLEFT", g, "TOPLEFT", 0, -TITLE) else m[1]:SetPoint("TOP", g, "TOP", 0, -TITLE) end
    for i = 2, 5 do
        m[i]:ClearAllPoints()
        if horizontal then m[i]:SetPoint("LEFT", m[i - 1], "RIGHT", 0, 0) else m[i]:SetPoint("TOP", m[i - 1], "BOTTOM", 0, 0) end
    end
    local w, h = S[m[1]].w, S[m[1]].h
    if horizontal then g:SetSize(count * w + (border and 4 or 0), TITLE + h)
    else g:SetSize(w + (border and 8 or 0), TITLE + count * h + (border and 2 or 0)) end
    if border then
        game.border:ClearAllPoints()
        game.border:SetPoint("TOPLEFT", m[1], "TOPLEFT", -2, 2)
        game.border:SetPoint("BOTTOMRIGHT", m[count], "BOTTOMRIGHT", 2, -3)
    end
    logging = was
end
local gameObjects
local function Build()
    writes, calls, made = {}, {}, {}
    UIParent = G("Frame", "UIParent", nil, 2000, 1000)
    Fixed(UIParent, 0, 0)
    PartyFrame = G("Frame", "PartyFrame", UIParent, 82, 200)
    Fixed(PartyFrame, 100, -300)
    local group = G("Frame", "CompactPartyFrame", PartyFrame, 80, 200)
    Fixed(group, 102, -300)
    local members, pets = {}, {}
    for i = 1, 5 do
        local m = G("Button", "CompactPartyFrameMember" .. i, group, W, H)
        S[m].protected = true
        Put(m, "healthBar", Bar(m, m:GetName() .. "HealthBar", HP, .78, .61, .43))
        Put(m, "powerBar", Bar(m, m:GetName() .. "PowerBar", POWER, 0, 0, 1))
        members[i] = m
    end
    for i = 1, 5 do
        local p = G("Button", "CompactPartyFramePet" .. i, group, W, PET_H)
        S[p].protected, S[p].shown = true, false
        Put(p, "healthBar", Bar(p, p:GetName() .. "HealthBar", HP, 0, 1, 0))
        Put(p, "powerBar", Bar(p, p:GetName() .. "PowerBar", POWER, 0, 0, 1))
        pets[i] = p
    end
    Put(group, "memberUnitFrames", members)
    Put(group, "petUnitFrames", pets)
    Put(group, "title", G("Button", "CompactPartyFrameTitle", group, 50, 14))
    local border = G("Frame", "CompactPartyFrameBorderFrame", group)
    local fill = Put(border, "Background", G("Texture", "CompactPartyFrameBorderFrameBackground", border, nil, nil, "ARTWORK"))
    S[fill].atlas, S[fill].alpha = "options_frame_child", .8
    Put(group, "borderFrame", border)
    CompactPartyFrame = group
    CompactPartyFrame_Generate = function() CompactPartyFrame = group; return group, false end
    game = { group = group, border = border, fill = fill, members = members, pets = pets }
    gameObjects = { PartyFrame, group, border, fill, group.title }
    for _, list in ipairs({ members, pets }) do
        for _, f in ipairs(list) do
            for _, o in ipairs({ f, f.healthBar, S[f.healthBar].fill, f.powerBar, S[f.powerBar].fill }) do gameObjects[#gameObjects + 1] = o end
        end
    end
    Layout(5)
end
-- Every bar of the ten frames.
local function Bars()
    local list = {}
    for _, group in ipairs({ game.members, game.pets }) do
        for _, f in ipairs(group) do list[#list + 1] = f.healthBar; list[#list + 1] = f.powerBar end
    end
    return list
end
local function Fill(bar) local s = S[S[bar].fill]; return tostring(s.atlas or s.texture) end
local function Colour(bar) local c = S[bar].colour; return C(c[1], c[2], c[3], c[4]) end
-- What the game's pieces look like now, every one, as text.
local function Snapshot()
    local out = {}
    for _, o in ipairs(gameObjects) do
        local s = S[o]
        out[#out + 1] = table.concat({ tostring(s.name), N(s.alpha), tostring(s.shown), tostring(s.level), #s.points, tostring(s.atlas),
            tostring(s.texture), s.colour and type(s.colour) == "table" and C(unpack(s.colour)) or tostring(s.colour), tostring(s.parent and S[s.parent].name) }, "|")
    end
    return table.concat(out, "\n")
end

-- EraUI --------------------------------------------------------------------------
local settings, E, ns, modules, booked
-- A fresh game and EraUI on it. opts.ferf: Forever Enhanced Raid Frames
-- draws the party (its party block exists); opts.late: the game hasn't made
-- its party frame yet.
local function Session(extra, opts)
    opts = opts or {}
    settings = { enabled = true, darkModeDarkness = 58 }
    for k, v in pairs(extra or {}) do settings[k] = v end
    combat, hooks, timers = false, {}, {}
    Build()
    _G.FERFParty = opts.ferf and G("Frame", "FERFParty", UIParent) or nil
    if opts.late then CompactPartyFrame = nil end
    ns, modules, booked = {}, {}, 0
    E = { Classic = ns, modules = {} }
    function E:GetSetting(key) return settings[key] end
    function E:GetSavedSetting(key) return settings[key] end
    function E:RegisterModule(name, mod) self.modules[name] = mod end
    ns.RegisterModule = function(key, mod) modules[key] = mod end
    ns.SafeCall = function(fn, ...) local ok, err = pcall(fn, ...); assert(ok, err); return ok end
    ns.QueueApply = Noop
    -- EraUI's pass: in a fight it books the pass after it.
    ns.ApplyAll = function() booked = booked + 1 end
    assert(loadfile("Classic/Textures.lua"))("EraUI", E)
    assert(loadfile("Core/Appearance.lua"))("EraUI", E)
    assert(loadfile("Classic/Skin.lua"))("EraUI", E)
    assert(loadfile("Classic/ThickFrames.lua"))("EraUI", E)
    assert(loadfile("Classic/PartyOutline.lua"))("EraUI", E)
    made = {}
end
-- EraUI's pass, as Classic/Core.lua runs every module's apply.
local function Pass() modules.partyOutline.apply() end
-- EraUI's outline frame: the one it made on the game's border.
local function Outline()
    for _, o in ipairs(made) do
        if S[o].kind == "Frame" and S[o].parent == game.border then return o end
    end
end
-- Its pieces, in the order made: four corners, three bands, four strips.
local function Pieces(frame)
    local body, line = {}, {}
    for _, o in ipairs(made) do
        if S[o].kind == "Texture" and S[o].parent == frame then
            if S[o].layer == "BACKGROUND" then body[#body + 1] = o else line[#line + 1] = o end
        end
    end
    return body, line
end
-- The members' bounds: the first's top left to the last shown's bottom right.
local function Members(count)
    local l, t = Rect(game.members[1])
    local _, _, r, b = Rect(game.members[count])
    return l, t, r, b
end

-- Off (the default) ---------------------------------------------------------------
Session()
equal(modules.partyOutline ~= nil and type(modules.partyOutline.apply) .. type(modules.partyOutline.restore), "functionfunction",
    "a Classic module of its own, run on EraUI's passes")
equal(settings.partyOutline, nil, "the mock starts with the switch never touched (Core/Init.lua's default is off)")
local never = Snapshot()
logging = true
Pass(); Pass()
logging = false
equal(#made .. " " .. #hooks .. " " .. #calls .. " " .. #timers, "0 0 0 0", "off: nothing made, hooked, called or waiting")
equal(Snapshot(), never, "off: the game's frames exactly as they were")
equal(ns.RefreshPartyOutline(), true, "off out of a fight: done")
equal(Outline(), nil, "off: no outline")

-- On ---------------------------------------------------------------------------------
settings.partyOutline = true
Pass()
local frame = Outline()
equal(frame ~= nil, true, "on: EraUI's outline made on the game's border")
equal(#hooks, 0, "the game's party frame is there: nothing hooked")
local body, line = Pieces(frame)
equal(#body .. " " .. #line, "7 4", "four corners and three bands, the line's four strips")
-- Pinned to the game's border by two corners, an edge out from the members.
equal(S[frame].points[1][2] == game.border and S[frame].points[2][2] == game.border and #S[frame].points == 2, true,
    "pinned by its two corners to the game's border, nothing else")
-- The outline's own edge and corner (Classic/PartyOutline.lua EDGE and
-- CORNER), pinned here: the members 5 in (the approved mockup's Thick
-- border at the unit frames' size), corners 6 round. Not Thick Frames'
-- geometry: its corners can change without moving the outline's.
local own = { edge = 5, corner = 6 }
local function Shape(count, label)
    local l, t, r, b = Members(count)
    equal(RectText(frame), Out(l, t, r, b, own.edge), label .. ": the outline an edge out from the members on every side")
    -- The corners: 6 square, one in each corner, each a quarter of the mask.
    local fl, ft, fr, fb = Rect(frame)
    local x = { fl, fr - own.corner, fl, fr - own.corner }
    local y = { ft, ft, fb + own.corner, fb + own.corner }
    for i = 1, 4 do
        equal(RectText(body[i]), N(x[i]) .. "," .. N(y[i]) .. "," .. N(x[i] + own.corner) .. "," .. N(y[i] - own.corner),
            label .. ": corner " .. i .. " in its corner, " .. own.corner .. " square")
    end
    -- The line's square corner (its outer point, 2 out from the members)
    -- at least the line's own width inside the round corner's curve, so the
    -- two never seem to touch.
    local ox, oy = l - 2, t + 2
    local inside = own.corner - math.sqrt((fl + own.corner - ox) ^ 2 + (ft - own.corner - oy) ^ 2)
    equal(inside >= 1, true, label .. ": the line's corner clear of the round corner (" .. N(inside) .. " in)")
    -- The body tiles the outline: every piece inside it, none overlapping,
    -- their areas adding up to the whole.
    local sum = 0
    for i, piece in ipairs(body) do
        local pl, pt, pr, pb = Rect(piece)
        equal(pl >= fl - 1e-9 and pr <= fr + 1e-9 and pt <= ft + 1e-9 and pb >= fb - 1e-9, true, label .. ": piece " .. i .. " inside the outline")
        sum = sum + Area(pl, pt, pr, pb)
        for j = i + 1, #body do equal(Overlap(piece, body[j]), 0, label .. ": pieces " .. i .. " and " .. j .. " don't overlap") end
    end
    equal(N(sum), N(Area(fl, ft, fr, fb)), label .. ": the pieces cover the outline with no gap")
    -- The fine line: one unit wide, 2 to 1 units outside the members.
    sum = 0
    for i, strip in ipairs(line) do
        local sl, st, sr, sb = Rect(strip)
        equal(math.min(sr - sl, st - sb), 1, label .. ": strip " .. i .. " one unit wide")
        equal(sl >= l - 2 and sr <= r + 2 and st <= t + 2 and sb >= b - 2, true, label .. ": strip " .. i .. " within 2 of the members")
        equal(Area(math.max(sl, l - 1), math.min(st, t + 1), math.min(sr, r + 1), math.max(sb, b - 1)), 0,
            label .. ": strip " .. i .. " clear of the unit round the members")
        sum = sum + Area(sl, st, sr, sb)
        for j = i + 1, #line do equal(Overlap(strip, line[j]), 0, label .. ": strips " .. i .. " and " .. j .. " don't overlap") end
    end
    equal(N(sum), N(Area(l - 2, t + 2, r + 2, b - 2) - Area(l - 1, t + 1, r + 1, b - 1)), label .. ": the line goes all the way round")
end
Shape(5, "five in the party")
local CORNER_COORDS = { "0,0.5,0,0.5", "0.5,1,0,0.5", "0,0.5,0.5,1", "0.5,1,0.5,1" }
for i = 1, 4 do
    equal(S[body[i]].texture .. " " .. S[body[i]].coords .. " " .. S[body[i]].tint, MASK .. " " .. CORNER_COORDS[i] .. " " .. C(.05, .05, .06, 1),
        "corner " .. i .. ": its quarter of the game's round mask, near black")
end
for i = 5, 7 do equal(S[body[i]].colour, C(.05, .05, .06, 1), "band " .. i .. " near black") end
for i = 1, 4 do equal(S[line[i]].colour, C(.55, .46, .27, 1), "strip " .. i .. ": Classic's muted bronze") end
-- Under the members, shown with the game's border, no mouse, no script.
equal(S[frame].level < S[game.members[1]].level and S[frame].level < S[game.pets[1]].level, true, "a level under the members and pets")
equal(S[frame].level, S[game.members[1]].level - 1, "just one under")
equal(frame:IsVisible(), true, "it shows")
equal(S[frame].mouse ~= true and next(S[frame].scripts) == nil, true, "no mouse and no script of its own")
equal(S[game.fill].alpha, 0, "the game border's own fill faded under it")
-- The flat fill on every bar, colours as they were.
local colours = {}
for _, bar in ipairs(Bars()) do colours[bar] = Colour(bar) end
for i, bar in ipairs(Bars()) do
    equal(Fill(bar), SOLID, "bar " .. i .. " (" .. bar:GetName() .. "): the solid square")
    equal(Colour(bar), colours[bar], "bar " .. i .. ": its colour untouched")
end
equal(#writes, 0, "no key written on the game's frames")

-- It follows the game with no call of EraUI's, in a fight too ----------------------
combat = true
logging = true
Layout(3)
Shape(3, "three in the party, in a fight")
S[game.members[1]].w, S[game.members[1]].h = 110, 50
for i = 2, 5 do S[game.members[i]].w, S[game.members[i]].h = 110, 50 end
Layout(4)
Shape(4, "Edit Mode's bigger frames, four in the party")
Layout(4, true)
Shape(4, "horizontal groups")
Layout(5)
Shape(5, "five again")
equal(#calls, 0, "nothing of EraUI's ran while the game laid its frames out")
logging = false
combat = false
-- Display Border off: the game hides its border, and the outline with it.
Layout(5, false, false)
equal(frame:IsVisible(), false, "Display Border off: the outline goes with the game's border")
equal(S[frame].shown, true, "with no call of EraUI's")
Layout(5)
equal(frame:IsVisible(), true, "Display Border on again: it's back")
S[game.group].shown = false
equal(frame:IsVisible(), false, "the game's raid-style party frame hidden (Classic party frames, or a raid): nothing shows")
S[game.group].shown = true
-- Display Pets: the game hangs the first pet from its border's foot
-- (CompactPartyFrameMixin:UpdateLayout), so it sits over the outline's
-- lowest 2 units (a level over it), as it sits under the game's own border.
local pet = game.pets[1]
S[pet].shown = true
pet:SetPoint("TOP", game.border, "BOTTOM")
local _, _, _, outlineFoot = Rect(frame)
local _, petTop = Rect(pet)
local _, _, _, membersFoot = Members(5)
equal(N(petTop - outlineFoot) .. " " .. N(membersFoot - petTop), "2 3", "a shown pet: 3 under the members, over the outline's lowest 2")
equal(S[pet].level > S[frame].level, true, "and drawn over it")
S[pet].shown = false

-- The line's colour --------------------------------------------------------------------
Session({ partyOutline = true, darkMode = true })
Pass()
frame = Outline()
body, line = Pieces(frame)
for i = 1, 4 do equal(S[line[i]].colour, C(ns.DarkGrey()), "Dark Mode: strip " .. i .. " in the Darkness grey") end
equal(S[line[1]].colour, C(.42, .44, .48), "the grey at Darkness 58")
settings.darkModeDarkness = 90
ns.RefreshDarkness()
for i = 1, 4 do equal(S[line[i]].colour, C(ns.DarkGrey()), "the slider at 90: strip " .. i .. " follows at once") end
combat = true
settings.darkModeDarkness = 40
logging = true
ns.RefreshDarkness()
logging = false
equal(S[line[1]].colour, C(.6, .629, .686), "in a fight too (EraUI's own textures)")
equal(#calls, 0, "and nothing of the game's touched")
combat = false
for i = 5, 7 do equal(S[body[i]].colour, C(.05, .05, .06, 1), "Dark Mode: band " .. i .. " still near black") end

-- Off again: today's game exactly ----------------------------------------------------------
Session()
never = Snapshot()
Session({ partyOutline = true })
Pass(); Pass()
frame = Outline()
equal(Fill(game.members[1].healthBar), SOLID, "on after two passes")
settings.partyOutline = false
logging = true
Pass()
logging = false
equal(S[frame].shown, false, "off: the outline hidden")
for i, bar in ipairs(Bars()) do
    equal(Fill(bar), i % 2 == 1 and HP or POWER, "off: bar " .. i .. " has its own atlas back (not the square a second pass saw)")
end
equal(S[game.fill].alpha, .8, "the border's fill has its own alpha back")
equal(Snapshot(), never, "off: the game's frames the same as a game never switched on")
equal(#writes, 0, "no key written on the game's frames")
-- On again: the same look as the first time, on the same outline.
settings.partyOutline = true
Pass()
equal(Outline(), frame, "on again: the same outline")
equal(frame:IsVisible() and Fill(game.members[3].powerBar) == SOLID and S[game.fill].alpha == 0, true, "on again: the look back")
Shape(5, "on again")

-- A bar whose own art can't be read ------------------------------------------------------
Session({ partyOutline = true })
local odd = game.members[2].healthBar
S[S[odd].fill].secretArt = true
Pass()
equal(Fill(odd), HP, "a bar whose art is secret keeps it")
equal(Fill(game.members[2].powerBar) .. " " .. Fill(game.members[1].healthBar), SOLID .. " " .. SOLID, "the others go flat")
S[S[odd].fill].secretArt = nil
settings.partyOutline = false
Pass()
equal(Fill(odd) .. " " .. Fill(game.members[1].healthBar), HP .. " " .. HP, "off: it was left alone, the others are back")

-- In a fight ---------------------------------------------------------------------------
Session()
never = Snapshot()
combat = true
settings.partyOutline = true
logging = true
equal(ns.RefreshPartyOutline(), false, "switched on in a fight: it waits")
logging = false
equal(#made .. " " .. #calls .. " " .. booked, "0 0 1", "nothing made or touched, the pass after the fight booked")
equal(Snapshot(), never, "the game's frames untouched")
combat = false
Pass()
frame = Outline()
equal(frame ~= nil and frame:IsVisible() and Fill(game.members[1].healthBar) == SOLID, true, "the pass after the fight: the look on")
combat = true
equal(ns.RefreshPartyOutline(), true, "in a fight with nothing to change: done, nothing booked")
equal(booked, 1, "still one booked")
settings.partyOutline = false
logging = true
equal(ns.RefreshPartyOutline(), false, "switched off in a fight: it waits")
logging = false
equal(#calls .. " " .. booked, "0 2", "nothing touched, the pass booked")
equal(frame:IsVisible() and Fill(game.members[1].healthBar) == SOLID and S[game.fill].alpha == 0, true, "the look stays whole until then")
modules.partyOutline.restore()
equal(frame:IsVisible(), true, "a restore in a fight leaves it too")
combat = false
Pass()
equal(tostring(frame:IsVisible()) .. " " .. Fill(game.members[1].healthBar) .. " " .. N(S[game.fill].alpha), "false " .. HP .. " 0.8", "after the fight: off")

-- Forever Enhanced Raid Frames draws the party -------------------------------------------
Session({ partyOutline = true }, { ferf = true })
never = Snapshot()
equal(ns.PartyOutlineStepsAside(), true, "its party block is there")
logging = true
Pass()
logging = false
equal(#made .. " " .. #calls .. " " .. #hooks, "0 0 0", "it steps aside: nothing made, touched or hooked")
equal(Snapshot(), never, "the game's frames untouched")
-- Its block made after EraUI's first pass (it builds a step a tick at login):
-- the next pass gives everything back.
Session({ partyOutline = true })
Pass()
frame = Outline()
equal(frame:IsVisible(), true, "worn before its block is made")
_G.FERFParty = G("Frame", "FERFParty", UIParent)
Pass()
equal(tostring(frame:IsVisible()) .. " " .. Fill(game.members[4].powerBar) .. " " .. N(S[game.fill].alpha), "false " .. POWER .. " 0.8",
    "its block made: the outline hidden, the bars and the border's fill back")
-- It parks the game's party frames under a hidden frame of its own: nothing
-- of EraUI's could show there anyway.
_G.FERFParty = nil
Pass()
equal(frame:IsVisible(), true, "(without its block, worn again)")
local hold = New("Frame", "FERFHold", UIParent, false)
S[hold].shown = false
S[PartyFrame].parent = hold
equal(frame:IsVisible(), false, "the game's party frames parked: nothing shows")

-- The party frame made late ----------------------------------------------------------------
Session(nil, { late = true })
Pass()
equal(#hooks, 0, "off: nothing hooked while there's no party frame")
Session({ partyOutline = true }, { late = true })
Pass(); Pass()
equal(table.concat(hooks, ","), "CompactPartyFrame_Generate", "on with no party frame yet: one post-hook, once, on the game making it")
equal(#made, 0, "nothing made yet")
CompactPartyFrame_Generate()
equal(#timers, 1, "made: the look waits a moment")
RunTimers()
frame = Outline()
equal(frame ~= nil and frame:IsVisible() and Fill(game.pets[5].powerBar) == SOLID, true, "then goes on")
settings.partyOutline = false
Pass()
CompactPartyFrame_Generate()
equal(#timers, 0, "off: the hook does nothing")

-- Never on Edit Mode -------------------------------------------------------------------
equal(editMode, 0, "nothing of Edit Mode's read, called or written")
equal(#writes, 0, "no key written on the game's frames")

print("Raid-style Party Outline checks passed: " .. checks .. " assertions.")
