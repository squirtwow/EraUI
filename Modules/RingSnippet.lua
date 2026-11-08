local _, E = ...

-- Action Rings' choice of slice (Modules/ActionRings.lua), made by the game's
-- own secure code so it works in a fight. The two bodies below run in the
-- game's restricted environment, which refuses a body holding the word for
-- a Lua function or any brace (comments included), so they carry no comment
-- and no table. Their notes are here.
--
-- PICK is the pre-body wrapped round each ring button's OnClick (self is the
-- button, owner the header, then the click's button and down). Key down: the
-- ring's hit frame shows centred on the cursor and the click does nothing.
-- Near the screen's edge the centre moves in just enough for the whole ring
-- and its name to show (ring-edge: its reach up and to the sides, ring-foot:
-- down, in screen units; the header's screen frame gives the cursor's place
-- and the screen's size), so every slice can still be reached. A second down
-- while it shows changes nothing; opening another ring puts the open one
-- away. Key up: the cursor's direction from the centre picks the slice
-- (slice 1 straight up, then clockwise, each the same share of the circle),
-- so a quick flick works; a release inside the middle picks nothing, and so
-- does a release where the ring opened (within TAP, open-dx and open-dy: a
-- ring moved in from an edge opens with the cursor off its middle, and a tap
-- must still do nothing). The picked slice's prepared attributes (s<k>-type,
-- -key, -value, -action and -slot, written out of combat by
-- Modules/RingSecure.lua) become the button's live ones, and the click goes
-- on to the game's own action. Every refusal returns false before a live
-- attribute changes, so an older pick can never cast again. All the live
-- ones are cleared each pick, so a macro never shadows macro text and an old
-- weapon slot never follows a spell. "chosen" tells the view what happened:
-- -1 opened, -2 a release with no ring of this key open, -3 a slice that
-- can't be used now (it keeps its place, greyed), 0 nothing picked, or the
-- slice's number.
--
-- CLOSE (out of combat only, through SecureHandlerExecute on the header) puts
-- every ring away: the option switched off, a ring deleted, or a ring left
-- open with its key's release lost (an alt-tab).
local RS = {}
E.RingSnippet = RS

RS.HIT = 4096 -- the hit frame's size: a release anywhere on screen picks by direction
RS.DEAD = 26 -- the middle's radius, in face units (the ring as drawn at Ring Size 100%)
RS.TAP = 8 -- a release this close to where the ring opened picks nothing, in face units
RS.RINGS, RS.SLICES = 10, 16
-- The button's live action attributes, cleared at each pick.
RS.LIVE = {"spell", "item", "macro", "macrotext", "equipmentset", "toy", "marker", "action", "unit", "target-slot"}

RS.PICK = [[
if self:GetAttribute("ring-off") then return false end
local me = self:GetAttribute("ring-slot")
local ring = me and owner:GetFrameRef("ring" .. me)
if not ring then return false end
if down then
    if ring:IsShown() then return false end
    local open = owner:GetAttribute("open-ring")
    if open and open ~= me then
        local other = owner:GetFrameRef("ring" .. open)
        if other then other:Hide() end
    end
    owner:SetAttribute("open-ring", me)
    self:SetAttribute("chosen", -1)
    self:SetAttribute("open-dx", 0)
    self:SetAttribute("open-dy", 0)
    ring:ClearAllPoints()
    local screen = owner:GetFrameRef("screen")
    local sx, sy, w, h
    if screen then
        sx, sy = screen:GetMousePosition()
        w, h = screen:GetWidth(), screen:GetHeight()
    end
    if sx and sy and w and h and w > 0 and h > 0 then
        local x, y = sx * w, sy * h
        local side = self:GetAttribute("ring-edge") or 0
        local top, foot = side, self:GetAttribute("ring-foot") or side
        if side + side > w then side = w / 2 end
        if top + foot > h then top, foot = h / 2, h / 2 end
        local cx, cy = x, y
        if cx < side then cx = side elseif cx > w - side then cx = w - side end
        if cy < foot then cy = foot elseif cy > h - top then cy = h - top end
        self:SetAttribute("open-dx", (x - cx) / ring:GetWidth())
        self:SetAttribute("open-dy", (y - cy) / ring:GetHeight())
        ring:SetPoint("CENTER", screen, "BOTTOMLEFT", cx, cy)
    else
        ring:SetPoint("CENTER", "$cursor")
    end
    ring:Show()
    return false
end
if owner:GetAttribute("open-ring") ~= me or not ring:IsShown() then
    self:SetAttribute("chosen", -2)
    return false
end
owner:SetAttribute("open-ring", nil)
local x, y = ring:GetMousePosition()
ring:Hide()
local count = self:GetAttribute("ring-count") or 0
local slice = 0
if x and y and count > 0 then
    local dx, dy = x - 0.5, y - 0.5
    local mx, my = dx - (self:GetAttribute("open-dx") or 0), dy - (self:GetAttribute("open-dy") or 0)
    if dx * dx + dy * dy >= (self:GetAttribute("dead2") or 0) and mx * mx + my * my >= (self:GetAttribute("tap2") or 0) then
        local bearing = math.deg(math.atan2(dx, dy))
        if bearing < 0 then bearing = bearing + 360 end
        local step = 360 / count
        slice = math.floor((bearing + step / 2) / step) % count + 1
    end
end
if slice == 0 then
    self:SetAttribute("chosen", 0)
    return false
end
local pre = "s" .. slice .. "-"
local kind = self:GetAttribute(pre .. "type")
local key = self:GetAttribute(pre .. "key")
if not kind or not key then
    self:SetAttribute("chosen", -3)
    return false
end
self:SetAttribute("chosen", slice)
self:SetAttribute("spell", nil)
self:SetAttribute("item", nil)
self:SetAttribute("macro", nil)
self:SetAttribute("macrotext", nil)
self:SetAttribute("equipmentset", nil)
self:SetAttribute("toy", nil)
self:SetAttribute("marker", nil)
self:SetAttribute("action", nil)
self:SetAttribute("unit", nil)
self:SetAttribute("target-slot", nil)
self:SetAttribute("type", kind)
self:SetAttribute(key, self:GetAttribute(pre .. "value"))
self:SetAttribute("action", self:GetAttribute(pre .. "action"))
self:SetAttribute("target-slot", self:GetAttribute(pre .. "slot"))
]]

RS.CLOSE = [[
for i = 1, 10 do
    local ring = self:GetFrameRef("ring" .. i)
    if ring then ring:Hide() end
end
self:SetAttribute("open-ring", nil)
]]

-- The same choice in plain Lua, for the view (the lit slice is always the
-- one a release there would pick) and the tests. Lua 5.1 in the game has
-- math.atan2; the tests' Lua 5.3 takes math.atan(y, x).
local atan2 = math.atan2 or math.atan

-- The compass bearing of (dx, dy), up being +dy: 0 up, 90 right, clockwise.
function RS.Bearing(dx, dy)
    local bearing = math.deg(atan2(dx, dy))
    if bearing < 0 then bearing = bearing + 360 end
    return bearing
end

-- The slice a release at (dx, dy) from the centre picks out of count, or 0
-- inside the middle (dead: its radius, in the same units as dx and dy),
-- within tap of where the ring opened (ox, oy from the centre; 0, 0 when it
-- opened round the cursor), or off the hit frame (reach: its half-size in the
-- same units; past it on either axis the game gives PICK no position).
function RS.Pick(dx, dy, count, dead, ox, oy, tap, reach)
    if type(dx) ~= "number" or type(dy) ~= "number" or type(count) ~= "number" or count < 1 then return 0 end
    if reach and (math.abs(dx) > reach or math.abs(dy) > reach) then return 0 end
    dead = dead or 0
    if dx * dx + dy * dy < dead * dead then return 0 end
    if tap and type(ox) == "number" and type(oy) == "number" then
        local mx, my = dx - ox, dy - oy
        if mx * mx + my * my < tap * tap then return 0 end
    end
    local step = 360 / count
    return math.floor((RS.Bearing(dx, dy) + step / 2) / step) % count + 1
end

-- Where PICK centres a ring opened at (x, y) on a w x h screen: moved in from
-- each edge just enough for the whole ring to show (side: its reach up and
-- to the sides, foot: down), on a screen too small for it its middle.
function RS.Clamp(x, y, w, h, side, foot)
    side = side or 0
    local top
    top, foot = side, foot or side
    if side + side > w then side = w / 2 end
    if top + foot > h then top, foot = h / 2, h / 2 end
    if x < side then x = side elseif x > w - side then x = w - side end
    if y < foot then y = foot elseif y > h - top then y = h - top end
    return x, y
end

-- Where slice k of count sits: its bearing, in degrees.
function RS.SliceAngle(k, count) return (k - 1) * 360 / count end

-- The middle's size as the snippet reads it: (radius in hit-frame units /
-- the hit frame's size) squared. The face is drawn at scale (Ring Size / 100)
-- inside the hit frame, so a face unit is scale hit units.
function RS.Dead2(scale)
    local share = RS.DEAD * (scale or 1) / RS.HIT
    return share * share
end
-- The same for a tap (TAP).
function RS.Tap2(scale)
    local share = RS.TAP * (scale or 1) / RS.HIT
    return share * share
end
-- The hit frame's half-size in face units: a release further out than this
-- on either axis (a very wide screen) is off it, and picks nothing.
function RS.Reach(scale)
    return RS.HIT / 2 / (scale or 1)
end
