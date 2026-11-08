-- The action bar gryphons in Dark Mode (Core/Appearance.lua, key "endCap"):
-- they take half the Darkness slider's darkness, so at 90 they sit at about
-- half brightness (.55) while the stone band under them stays near black
-- (.10), as before. Both follow the slider at once; with Dark Mode off
-- (a reload) nothing is tinted.
--   1. the real Core/Appearance.lua on bare textures: every key's grey at
--      several Darkness values, the slider live, the clamp, Dark Mode off
--   2. the real band (Look/Band.lua on Tools/LookMockGame.lua) with the real
--      Core/Appearance.lua: the gryphons and the band's own art after a pass,
--      the slider, Dark Menu Bar (it never touched the gryphons), Dark Mode off
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
local function Near(actual, expected, label)
    checks = checks + 1
    if type(actual) ~= "number" or math.abs(actual - expected) > 1e-6 then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end
-- Dark Mode's grey for a brightness v, with its slight blue.
local function Grey(colour, v, label)
    Near(colour[1], v, label .. " (red)")
    Near(colour[2], math.min(1, v * 44 / 42), label .. " (green)")
    Near(colour[3], math.min(1, v * 48 / 42), label .. " (blue)")
end
local function White(colour, label)
    Near(colour[1], 1, label .. " (red)")
    Near(colour[2], 1, label .. " (green)")
    Near(colour[3], 1, label .. " (blue)")
end

---------------------------------------------------------------------------
-- 1. Core/Appearance.lua on bare textures
---------------------------------------------------------------------------
do
    local function Texture()
        local t = { colour = { 1, 1, 1 }, sets = 0 }
        function t:SetVertexColor(r, g, b) self.colour = { r, g, b }; self.sets = self.sets + 1 end
        return t
    end
    local E = { modules = {}, Classic = {}, settings = { enabled = true, darkMode = true, darkModeDarkness = 90 } }
    function E:GetSetting(key) return self.settings[key] end
    local ns = E.Classic
    assert(loadfile("Core/Appearance.lua"))("EraUI", E)

    local band, keyring, cap, gryphon, plain = Texture(), Texture(), Texture(), Texture(), Texture()
    local knob, column = Texture(), Texture()
    ns.ThemeTexture(band, "barBody")
    ns.ThemeTexture(keyring, "barKeyring")
    ns.ThemeTexture(cap, "maxLevel")
    ns.ThemeTexture(gryphon, "endCap")
    ns.ThemeTexture(plain, "statusFill") -- not frame art: never tinted
    ns.ThemeTexture(knob, "scrollKnob")
    ns.ThemeTexture(column, "charScrollBar")
    Grey(band.colour, .10, "Darkness 90: the band near black, as before")
    Grey(keyring.colour, .10, "Darkness 90: the key ring piece, as before")
    Grey(cap.colour, .10, "Darkness 90: the max-level cap, as before")
    Grey(gryphon.colour, .55, "Darkness 90: the gryphons half as dark (about half bright)")
    Grey(knob.colour, .55, "Darkness 90: the scroll knob half as dark, so it shows on its column")
    Grey(column.colour, .10, "Darkness 90: the scroll column itself near black, as before")
    Equal(plain.sets, 0, "art without a Dark Mode key is never tinted")
    Grey({ ns.DarkGrey() }, .10, "ns.DarkGrey is still the full grey")

    -- The slider, live: every tinted piece at once, each at its share.
    for _, step in ipairs({ { 70, .30, .65 }, { 58, .42, .71 }, { 40, .60, .80 } }) do
        E.settings.darkModeDarkness = step[1]
        ns.RefreshDarkness()
        Grey(band.colour, step[2], "Darkness " .. step[1] .. ": the band")
        Grey(cap.colour, step[2], "Darkness " .. step[1] .. ": the max-level cap")
        Grey(gryphon.colour, step[3], "Darkness " .. step[1] .. ": the gryphons at half the darkness")
        Grey(knob.colour, step[3], "Darkness " .. step[1] .. ": the scroll knob at half the darkness")
        Grey({ ns.DarkGrey() }, step[2], "Darkness " .. step[1] .. ": ns.DarkGrey")
    end

    -- Out of range clamps first, then halves.
    E.settings.darkModeDarkness = 120
    ns.RefreshDarkness()
    Grey(band.colour, .10, "past 90: the band held at 90")
    Grey(gryphon.colour, .55, "past 90: the gryphons held at half of 90")
    E.settings.darkModeDarkness = nil
    ns.RefreshDarkness()
    Grey(band.colour, .42, "no saved Darkness: the default 58")
    Grey(gryphon.colour, .71, "no saved Darkness: the gryphons at half of 58")

    -- A texture given new art takes the new key's share.
    E.settings.darkModeDarkness = 90
    local swapped = Texture()
    ns.ThemeTexture(swapped, "endCap")
    ns.ThemeTexture(swapped, "barBody")
    ns.RefreshDarkness()
    Grey(swapped.colour, .10, "endCap art swapped for band art: full darkness")
    ns.ThemeTexture(swapped, "endCap")
    ns.RefreshDarkness()
    Grey(swapped.colour, .55, "and back to the gryphon: half again")

    -- A texture let go of (UntintTexture) is left alone by the slider.
    ns.UntintTexture(gryphon)
    local before = gryphon.sets
    E.settings.darkModeDarkness = 70
    ns.RefreshDarkness()
    Equal(gryphon.sets, before, "untinted: the slider leaves it alone")

    -- Dark Mode off (a reload): nothing tinted, the slider does nothing.
    E.settings.darkMode = false
    local fresh, freshGryphon = Texture(), Texture()
    ns.ThemeTexture(fresh, "barBody")
    ns.ThemeTexture(freshGryphon, "endCap")
    Equal(fresh.sets + freshGryphon.sets, 0, "Dark Mode off: band and gryphons untinted")
    White(freshGryphon.colour, "Dark Mode off: the gryphons as the art draws them")
    before = band.sets
    ns.RefreshDarkness()
    Equal(band.sets, before, "Dark Mode off: the slider sets nothing")
end

---------------------------------------------------------------------------
-- 2. The real band with the real Core/Appearance.lua
---------------------------------------------------------------------------
local Mock = dofile("Tools/LookMockGame.lua")

local function Session(settings)
    local game = Mock.New()
    for key, value in pairs(settings) do game.settings[key] = value end
    local Look = game.Load()
    -- The real Dark Mode tint in place of the mock's. Its window hooks (made
    -- only when CreateFrame exists at load) are left out: this is about art.
    local env = setmetatable({ CreateFrame = false }, { __index = game.env })
    game.E.modules = game.E.modules or {} -- the slider also asks EraUI's modules (none here)
    assert(loadfile("Core/Appearance.lua", "t", env))("EraUI", game.E)
    game.Login()
    game.Fire("PLAYER_ENTERING_WORLD")
    return game, Look
end

do
    local game, Look = Session({ darkMode = true, darkMenuBar = true, darkModeDarkness = 90 })
    local ns, band = game.ns, Look.band
    Equal(band.active, true, "the band is on")
    local left, right = band.caps.left, band.caps.right
    Equal(left.file, "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf", "the gryphon art")
    Equal(left:IsShown() and right:IsShown(), true, "both gryphons shown")
    Grey(left.color, .55, "Darkness 90: the left gryphon about half bright")
    Grey(right.color, .55, "Darkness 90: the right gryphon too")
    Equal(#band.slices >= 6, true, "the band's art slices")
    for i, slice in ipairs(band.slices) do
        if slice:IsShown() then Grey(slice.color, .10, "Darkness 90: band slice " .. i .. " near black, as before") end
    end
    Grey(band.maxLevel[1].color, .10, "Darkness 90: the max-level cap, as before")

    -- Another pass (the band laid again) keeps the same greys.
    game.Pass()
    Grey(left.color, .55, "a second pass: the gryphon still half")
    Grey(band.slices[1].color, .10, "a second pass: the band still full")

    -- The slider, live, through the settings' own refresh.
    game.settings.darkModeDarkness = 70
    ns.RefreshDarkness()
    Grey(left.color, .65, "Darkness 70: the gryphons at half")
    Grey(right.color, .65, "Darkness 70: both")
    Grey(band.slices[1].color, .30, "Darkness 70: the band in full")
    game.settings.darkModeDarkness = 40
    ns.RefreshDarkness()
    Grey(left.color, .80, "Darkness 40: the gryphons at half")
    Grey(band.slices[1].color, .60, "Darkness 40: the band in full")

    -- Dark Menu Bar darkens only the menu buttons' frames; the gryphons and
    -- the band keep Dark Mode's greys with it off or on, as before.
    game.settings.darkModeDarkness = 90
    ns.RefreshDarkness()
    game.settings.darkMenuBar = false
    ns.RefreshDarkMenuBar()
    Grey(left.color, .55, "Dark Menu Bar off: the gryphons unchanged")
    Grey(band.slices[1].color, .10, "Dark Menu Bar off: the band unchanged")
    game.settings.darkMenuBar = true
    ns.RefreshDarkMenuBar()
    Grey(left.color, .55, "Dark Menu Bar on: the gryphons unchanged")
end

do
    local game, Look = Session({ darkMode = false, darkMenuBar = true, darkModeDarkness = 90 })
    local band = Look.band
    Equal(band.active and band.caps.left:IsShown(), true, "Dark Mode off: the gryphons shown")
    White(band.caps.left.color, "Dark Mode off: the left gryphon untinted")
    White(band.caps.right.color, "Dark Mode off: the right gryphon untinted")
    White(band.slices[1].color, "Dark Mode off: the band untinted")
    game.ns.RefreshDarkness()
    White(band.caps.left.color, "Dark Mode off: the slider leaves the gryphons alone")
end

print("Gryphon darkness checks passed: " .. checks .. " assertions.")
