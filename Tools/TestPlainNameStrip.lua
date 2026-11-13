-- Plain Target Name Strip (Modules/ClassAccents.lua): with it on, the strip
-- behind the target's and focus's names keeps the game's own colour instead
-- of a player's class colour. Off, a player's class colour shows as before.
local failures = 0
local function Equal(got, want, label)
    if got == want then print("ok   " .. label)
    else failures = failures + 1; print("FAIL " .. label .. ": got " .. tostring(got) .. ", want " .. tostring(want)) end
end

unpack = unpack or table.unpack
function hooksecurefunc(t, name, fn)
    local old = t[name]
    t[name] = function(...) local r = old(...); fn(...); return r end
end
local function Strip()
    local s = { colour = { 1, 0, 0 } }
    function s:SetVertexColor(r, g, b) self.colour = { r, g, b } end
    function s:GetVertexColor() return self.colour[1], self.colour[2], self.colour[3] end
    return s
end
local strips = { target = Strip(), focus = Strip() }
TargetFrame = { TargetFrameContent = { TargetFrameContentMain = { ReputationColor = strips.target } } }
FocusFrame = { TargetFrameContent = { TargetFrameContentMain = { ReputationColor = strips.focus } } }
RAID_CLASS_COLORS = { MAGE = { r = .25, g = .78, b = .92 } }
function UnitIsPlayer() return true end
function UnitClass() return "Mage", "MAGE" end
function CreateFrame() return { RegisterEvent = function() end, SetScript = function() end } end

local E = { modules = {}, settings = { enabled = true, unitFrames = true } }
function E:RegisterModule(name, mod) self.modules[name] = mod end
function E:GetSetting(key) return self.settings[key] end
assert(loadfile("Modules/ClassAccents.lua"))("EraUI", E)
local accents = E.modules.ClassAccents
local function Colour(s) return string.format("%.2f %.2f %.2f", s:GetVertexColor()) end

accents:RefreshFrames()
Equal(Colour(strips.target), "0.25 0.78 0.92", "off: a player target's strip takes their class colour, as before")
Equal(Colour(strips.focus), "0.25 0.78 0.92", "off: the focus strip too")

E.settings.plainNameStrip = true
accents:RefreshFrames()
Equal(Colour(strips.target), "1.00 0.00 0.00", "on: the target strip goes back to the game's colour")
Equal(Colour(strips.focus), "1.00 0.00 0.00", "on: the focus strip too")
strips.target:SetVertexColor(0, 1, 0)
Equal(Colour(strips.target), "0.00 1.00 0.00", "on: the game's new colour is kept, not repainted")

E.settings.plainNameStrip = false
accents:RefreshFrames()
Equal(Colour(strips.target), "0.25 0.78 0.92", "switched off again: the class colour is back")

print(failures == 0 and "ALL PASS" or (failures .. " FAILED"))
