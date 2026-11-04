local _, EraUI = ...

-- The mini-games' level map (experimental, with the mini-games): a page of
-- ten levels (Blast: one zone; Whack: ten stages) on the zone's own ground, a
-- dotted path from the first node at the bottom left to the boss at the top
-- right, stars under the levels cleared, a gold glow pulsing on the next one,
-- and arrows to the pages before and after. A game makes one in its holder
-- and says what to draw through its source; the map draws by role
-- (Modules/MiniGameAssets.lua), with plain discs when the client refuses the art.
--
-- How to use it:
--   local map = MiniGames.Map.New(parent, source)  once (frames sized 412 x 500,
--       at the parent's top left, made at once, hidden until Show)
--   source = {game = "blast"|"whack", PerPage = 10, noun = "level"|"stage",
--       Page(page) -> {title, sub, ground (a role), tint {r, g, b}, locked, lockText},
--       Node(n) -> {state = "done"|"open"|"locked", stars = 0..3, boss, art (the boss
--           portrait's role), label, carry (a snapshot waits: "Carry on")},
--       Pick(n) (an open or done node clicked), Last() -> the highest open n}
--   map:Show(page)  that page (nil: the page of Last()), its glow pulsing, and the
--       footer note "Next: %s at level %d." (MiniGames.Progress:NextUnlock)
--   map:Hide()  map:Refresh()  map:IsShown()  map:Page()  map:Note()
--   map:Walk(from, to, done)  the glow walks dot by dot from node from to node to
--       (.08 s a dot, a step sound every 2nd), turning the page when to is on the
--       next (banner "New place: %s"), then done(cleared). Hidden part way: it
--       jumps to the end and done(true).
-- No update of its own: the glow's pulse and the walk run on MiniGames:Tween.
local MG = EraUI.MiniGames
if not MG then return end

local Map = {}
MG.Map = Map
Map.W, Map.H = 412, 500
Map.PER_PAGE = 10
-- Node middles (x right, y down from the top left): level 1 bottom left, the boss top right.
Map.PATH = {{86, 430}, {176, 448}, {268, 420}, {330, 352}, {252, 300}, {150, 290}, {78, 228}, {140, 160}, {238, 150}, {318, 92}}
Map.DOT, Map.DOT_GAP, Map.CLEAR = 6, 14, 22   -- dot size, every 14 px, none within 22 px of a node's middle
Map.NODE, Map.BOSS, Map.PORTRAIT, Map.STAR = 44, 56, 40, 12
Map.GLOW = 70
Map.STEP = .08        -- seconds a dot of a walk
Map.PULSE = .5        -- seconds a pulse of the glow (2 a second)
Map.SHADE = .55       -- the ground's tint times this
Map.PATH_COLOUR = {done = {1, .9, .5, 1}, open = {.95, .85, .55, .75}, locked = {.5, .5, .5, .4}}
Map.BANNER = {w = 300, h = 44, y = 8}

-- The dots between node k and k + 1, every DOT_GAP px, clear of both nodes.
Map.SEGMENTS = {}
for k = 1, #Map.PATH - 1 do
    local a, b = Map.PATH[k], Map.PATH[k + 1]
    local dx, dy = b[1] - a[1], b[2] - a[2]
    local length = math.sqrt(dx * dx + dy * dy)
    local dots = {}
    local along = Map.DOT_GAP
    while along < length - 1e-6 do
        if along >= Map.CLEAR and along <= length - Map.CLEAR then
            dots[#dots + 1] = {a[1] + dx * along / length, a[2] + dy * along / length}
        end
        along = along + Map.DOT_GAP
    end
    Map.SEGMENTS[k] = dots
end

local METHODS = {}
local GREY = {.6, .6, .6}

local function PageOf(map, n) return math.floor((n - 1) / map.per) + 1 end
local function Last(map)
    local ok, n = pcall(map.source.Last)
    n = ok and tonumber(n) or 1
    return math.max(1, math.floor(n))
end

-- Building ------------------------------------------------------------------------------

local function MakeNode(map, k)
    local frame = map.frame
    local node = CreateFrame("Button", nil, frame)
    node:SetSize(Map.BOSS, Map.BOSS)
    node:SetPoint("CENTER", frame, "TOPLEFT", Map.PATH[k][1], -Map.PATH[k][2])
    node.art = node:CreateTexture(nil, "ARTWORK")
    node.art:SetSize(Map.NODE, Map.NODE)
    node.art:SetPoint("CENTER", node, "CENTER", 0, 0)
    node.portrait = node:CreateTexture(nil, "ARTWORK", nil, 2)
    node.portrait:SetSize(Map.PORTRAIT, Map.PORTRAIT)
    node.portrait:SetPoint("CENTER", node, "CENTER", 0, 0)
    if type(node.CreateMaskTexture) == "function" and type(node.portrait.AddMaskTexture) == "function" then
        local mask = node:CreateMaskTexture()
        mask:SetTexture(MG.ART.portraitMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(node.portrait)
        node.portrait:AddMaskTexture(mask)
    end
    node.label = MG.Text(node, "", 15, false, true)
    node.label:SetPoint("CENTER", node, "CENTER", 0, 0)
    node.label:SetJustifyH("CENTER")
    node.stars = {}
    for s = 1, 3 do
        local star = node:CreateTexture(nil, "OVERLAY")
        star:SetSize(Map.STAR, Map.STAR)
        star:SetPoint("CENTER", node, "CENTER", (s - 2) * (Map.STAR + 1), -28)
        node.stars[s] = star
    end
    node.carry = MG.Text(node, "Carry on", 9)
    node.carry:SetPoint("CENTER", node, "CENTER", 0, -28)
    node.carry:SetJustifyH("CENTER")
    node.carry:SetTextColor(.4, 1, .5)
    node.k = k
    node:SetScript("OnClick", function(self) map:Click((map.page - 1) * map.per + self.k) end)
    return node
end
local function MakeArrows(map)
    local frame = map.frame
    map.prev = MG.Button(frame, "<", 36, 28)
    map.prev:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -16)
    map.prev:SetScript("OnClick", function() MG:Sound("uiClick"); map:Show(map.page - 1) end)
    map.next = MG.Button(frame, ">", 36, 28)
    map.next:SetPoint("TOPLEFT", frame, "TOPLEFT", 368, -16)
    map.next:SetScript("OnClick", function() MG:Sound("uiClick"); map:Show(map.page + 1) end)
end
local function MakeBanner(map)
    local frame, B = map.frame, Map.BANNER
    map.banner = frame:CreateTexture(nil, "BORDER", nil, 2)
    map.banner:SetSize(B.w, B.h)
    map.banner:SetPoint("TOP", frame, "TOP", 0, -B.y)
    map.title = MG.Text(frame, "", 16, false, true)
    map.title:SetPoint("TOP", frame, "TOP", 0, -(B.y + 7))
    map.title:SetJustifyH("CENTER")
    map.sub = MG.Text(frame, "", 11, true)
    map.sub:SetPoint("TOP", frame, "TOP", 0, -(B.y + 27))
    map.sub:SetJustifyH("CENTER")
end

function Map.New(parent, source)
    local map = setmetatable({source = source, per = tonumber(source.PerPage) or Map.PER_PAGE, page = 1,
        noun = source.noun or (source.game == "whack" and "stage" or "level")}, {__index = METHODS})
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(Map.W, Map.H)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    frame:Hide()
    map.frame = frame
    map.ground = frame:CreateTexture(nil, "BACKGROUND")
    map.ground:SetSize(Map.W, Map.H)
    map.ground:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    map.dots = {}
    for k, dots in ipairs(Map.SEGMENTS) do
        for _, at in ipairs(dots) do
            local dot = frame:CreateTexture(nil, "BORDER")
            dot:SetSize(Map.DOT, Map.DOT)
            dot:SetPoint("CENTER", frame, "TOPLEFT", at[1], -at[2])
            dot.segment = k
            map.dots[#map.dots + 1] = dot
        end
    end
    map.glow = frame:CreateTexture(nil, "ARTWORK")
    map.glow:SetSize(Map.GLOW, Map.GLOW)
    map.glow:SetPoint("CENTER", frame, "TOPLEFT", Map.PATH[1][1], -Map.PATH[1][2])
    map.nodes = {}
    for k = 1, map.per do
        if Map.PATH[k] then map.nodes[k] = MakeNode(map, k) end
    end
    MakeBanner(map)
    MakeArrows(map)
    map.shade = frame:CreateTexture(nil, "OVERLAY")
    map.shade:SetSize(Map.W, Map.H)
    map.shade:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    map.shade:SetColorTexture(0, 0, 0, .45)
    -- The lock's words over the greyed page's nodes.
    map.lockLayer = CreateFrame("Frame", nil, frame)
    map.lockLayer:SetSize(Map.W, Map.H)
    map.lockLayer:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    map.lockLayer:SetFrameLevel(frame:GetFrameLevel() + 5)
    map.lockText = MG.Text(map.lockLayer, "", 14)
    map.lockText:SetPoint("CENTER", map.lockLayer, "CENTER", 0, 0)
    map.lockText:SetJustifyH("CENTER")
    map.lockLayer:Hide()
    return map
end

-- Drawing ---------------------------------------------------------------------------------

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok then
        MG.Report(value)
        return nil
    end
    return value
end
local function PaintNode(map, node, n, locked)
    local info = Call(map.source.Node, n) or {}
    local state = locked and "locked" or info.state or "locked"
    node.state, node.n = state, n
    local boss = info.boss and true or false
    local size = boss and Map.BOSS or Map.NODE
    node.art:SetSize(size, size)
    local role = boss and "map.nodeBoss" or (state == "done" and "map.nodeDone" or state == "open" and "map.node" or "map.nodeLocked")
    node.role = role
    MG:Art(node.art, role)
    if boss and state == "locked" and node.art.SetDesaturated then pcall(node.art.SetDesaturated, node.art, true) end
    if boss and info.art then
        MG:Art(node.portrait, info.art)
        if state == "locked" and node.portrait.SetDesaturated then pcall(node.portrait.SetDesaturated, node.portrait, true) end
        node.label:Hide()
    else
        node.portrait:Hide()
        node.label:SetText(info.label or tostring(n))
        node.label:Show()
        if state == "locked" then node.label:SetTextColor(GREY[1], GREY[2], GREY[3]) else node.label:SetTextColor(1, 1, 1) end
    end
    local stars = state == "done" and not info.carry and math.max(0, math.min(3, tonumber(info.stars) or 0)) or nil
    for s = 1, 3 do
        local star = node.stars[s]
        if stars then MG:Art(star, s <= stars and "star" or "starEmpty") else star:Hide() end
    end
    node.carry:SetShown(info.carry and true or false)
    node:SetAlpha(locked and .55 or 1)
    return state
end
local function PaintPath(map, states)
    for _, dot in ipairs(map.dots) do
        local state = states[dot.segment + 1] or "locked"
        local colour = Map.PATH_COLOUR[state] or Map.PATH_COLOUR.locked
        MG:Art(dot, "map.path", {tint = {colour[1], colour[2], colour[3]}, plain = true})
        dot:SetAlpha(colour[4])
    end
end
function METHODS:PlaceGlow(x, y)
    self.glow:ClearAllPoints()
    self.glow:SetPoint("CENTER", self.frame, "TOPLEFT", x, -y)
end
local function Pulse(map)
    if map.pulsing or not map.frame:IsVisible() then return end
    map.pulsing = true
    local function Step(share) map.glow:SetAlpha(.45 + .55 * (.5 + .5 * math.cos(share * 2 * math.pi))) end
    MG:Tween(Map.PULSE, Step, function(_, cleared)
        map.pulsing = false
        if cleared or not map.frame:IsVisible() then
            map.glow:SetAlpha(1)
        else
            Pulse(map)
        end
    end)
end
function METHODS:Refresh()
    local page = self.page
    local info = Call(self.source.Page, page) or {}
    local tint = type(info.tint) == "table" and info.tint or {1, 1, 1}
    local shade = {tint[1] * Map.SHADE, tint[2] * Map.SHADE, tint[3] * Map.SHADE}
    MG:Art(self.ground, info.ground or "zone.elwynn.ground", {wrap = "REPEAT", coords = {0, Map.W / 256, 0, Map.H / 256},
        tint = shade, plain = true, colour = {.06, .07, .08, 1}})
    MG:Art(self.banner, "map.banner")
    self.title:SetText(info.title or "")
    self.sub:SetText(info.sub or "")
    local locked = info.locked and true or false
    local states = {}
    for k, node in ipairs(self.nodes) do
        states[k] = PaintNode(self, node, (page - 1) * self.per + k, locked)
    end
    PaintPath(self, states)
    local last = Last(self)
    local frontier = PageOf(self, last)
    self.prev:SetShown(page > 1)
    self.next:SetShown(page <= frontier)
    self.shade:SetShown(locked)
    self.lockLayer:SetShown(locked)
    self.lockText:SetText(locked and (info.lockText or "") or "")
    local k = last - (page - 1) * self.per
    local glowing = not locked and k >= 1 and k <= #self.nodes
    if not self.walking then
        if glowing then self:PlaceGlow(Map.PATH[k][1], Map.PATH[k][2]) end
        self.glow:SetShown(glowing)
    end
    if glowing or self.walking then
        MG:Art(self.glow, "map.glow", {tint = {1, .82, .35}})
        self.glow:SetBlendMode("ADD")
        self.glow:SetSize(Map.GLOW, Map.GLOW)
        Pulse(self)
    end
end
function METHODS:Show(page)
    page = tonumber(page) or PageOf(self, Last(self))
    self.page = math.max(1, math.floor(page))
    self.frame:Show()
    self:Refresh()
    if self.source.note ~= false then self:Note() end
end
function METHODS:Hide() self.frame:Hide() end
function METHODS:IsShown() return self.frame:IsShown() end
function METHODS:Page() return self.page end
-- The footer's note: the next milestone.
function METHODS:Note()
    local P = MG.Progress
    local nextUp = P and P:NextUnlock(self.source.game)
    if nextUp then MG:Note(("Next: %s at %s %d."):format(nextUp.name, self.noun, nextUp.at)) end
    return nextUp
end
function METHODS:Click(n)
    local node = self.nodes[n - (self.page - 1) * self.per]
    if not node then return end
    if node.state == "done" or node.state == "open" then
        MG:Sound("uiClick")
        Call(self.source.Pick, n)
    else
        MG:Sound("buzz")
        MG:Note(("Clear %s %d first."):format(self.noun, Last(self)))
    end
end

-- The glow's walk from one node to the next, dot by dot.
function METHODS:Walk(from, to, done)
    from, to = math.floor(tonumber(from) or 1), math.floor(tonumber(to) or 1)
    local map = self
    local fromPage, toPage = PageOf(self, from), PageOf(self, to)
    if self.page ~= fromPage then self:Show(fromPage) end
    local points = {}
    local stop = toPage == fromPage and to or fromPage * self.per
    for n = from, stop - 1 do
        local k = n - (fromPage - 1) * self.per
        for _, dot in ipairs(Map.SEGMENTS[k] or {}) do points[#points + 1] = dot end
        if Map.PATH[k + 1] then points[#points + 1] = Map.PATH[k + 1] end
    end
    local k0 = from - (fromPage - 1) * self.per
    if Map.PATH[k0] then self:PlaceGlow(Map.PATH[k0][1], Map.PATH[k0][2]) end
    self.walking = true
    self.glow:Show()
    local index = 0
    local function Finish(cleared)
        map.walking = nil
        if toPage ~= map.page then
            map:Show(toPage)
            if not cleared then
                local info = Call(map.source.Page, toPage) or {}
                MG:Banner(("New place: %s"):format(info.title or ""), {size = 26})
                MG:Sound("unlock")
            end
        else
            map:Refresh()
        end
        if type(done) == "function" then done(cleared and true or false) end
    end
    local Step
    Step = function(_, cleared)
        if cleared then return Finish(true) end
        index = index + 1
        if index > #points then return Finish(false) end
        local at = points[index]
        map:PlaceGlow(at[1], at[2])
        if index % 2 == 0 then MG:Sound("mapStep") end
        MG:Tween(Map.STEP, nil, Step)
    end
    Step(nil, false)
end
