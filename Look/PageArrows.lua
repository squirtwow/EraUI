-- Action Bar 1's page arrows and page number: placed in the band's nook by
-- each band layout, and dressed in the 1.x scroll arrows by their own entry
-- in the Classic registry (under the band's key, after the band's layout).
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Number, Pin = Look.Number, Look.Pin
local band = Look.band

-- The page frame, its two arrows (with the y each sits at on the band, and
-- by the bar with the band off), its number, and the bar.
local function Pages()
    local main = Look.MainBar()
    local holder = main and main.ActionBarPageNumber
    if type(holder) ~= "table" then return nil end
    local arrows = {
        { holder.UpButton, -22, 10, "Up", "pageuparrow" },
        { holder.DownButton, -42, -10, "Down", "pagedownarrow" },
    }
    return holder, arrows, holder.Text, main
end

---------------------------------------------------------------------------
-- Place (part of the band's layout)
---------------------------------------------------------------------------

-- In the nook: the column 10 in from the right half's start; the page frame
-- in band units (its scale the band's), above the band's other art.
function Look.PlacePageArrows(shape)
    local holder, arrows, number, main = Pages()
    if not holder or Look.InFight() then return end
    local hidden = Look.PagesHidden(main)
    Look.Shown(holder, not hidden)
    if hidden then return end
    local column, frame = shape.base + 10, band.frame
    holder:SetScale(band.scale)
    holder:SetFrameStrata("HIGH")
    holder:SetSize(32, 76)
    Pin(holder, "CENTER", frame, "TOPLEFT", column, -32)
    for _, arrow in ipairs(arrows) do
        local knob = arrow[1]
        if knob then
            knob:SetSize(32, 32)
            knob:SetHitRectInsets(6, 6, 7, 7) -- a 20 x 18 hit area
            Pin(knob, "CENTER", frame, "TOPLEFT", column, arrow[2])
        end
    end
    if number then
        number:SetFontObject("GameFontNormalSmall")
        Pin(number, "CENTER", frame, "TOPLEFT", column + 20, -31.5)
    end
end

-- With the band off: the page frame back beside Action Bar 1 at the game's
-- size, its arrows and number where the game has them.
function Look.RestorePageFrame()
    local holder, arrows, number, main = Pages()
    if not holder then return end
    holder:SetFrameStrata(main:GetFrameStrata())
    holder:SetScale(1)
    Pin(holder, "BOTTOMRIGHT", main, "BOTTOMLEFT", -4, 9)
    for _, arrow in ipairs(arrows) do
        local knob = arrow[1]
        if knob then
            knob:SetSize(17, 14)
            knob:SetHitRectInsets(0, 0, 0, 0) -- the whole arrow again
            Pin(knob, "CENTER", holder, "CENTER", 0, arrow[3])
        end
    end
    if number then
        number:SetFontObject("GameFontNormal")
        Pin(number, "CENTER", holder, "CENTER", -1, 0)
    end
    holder:SetShown(not Look.PagesHidden(main))
end

---------------------------------------------------------------------------
-- Art (its own registry entry)
---------------------------------------------------------------------------

-- Each state: the 1.x art's key suffix and the game's atlas suffix.
local FACES = { { "Normal", "Up", "-up" }, { "Pushed", "Down", "-down" }, { "Disabled", "Disabled", "-disabled" },
    { "Highlight", "Highlight", "-mouseover" } }
local firstSeen = {} -- arrow: { width, height, y } as the game had it
local wearsOld = false

local function Note(knob, fallbackY)
    if firstSeen[knob] then return end
    local _, _, _, _, y = knob:GetPoint(1)
    firstSeen[knob] = { Number(knob:GetWidth()) or 17, Number(knob:GetHeight()) or 14, Number(y) or fallbackY }
end

local function DressArrows()
    local _, arrows = Pages()
    for _, arrow in ipairs(arrows or {}) do
        local knob = arrow[1]
        if knob then
            Note(knob, arrow[3])
            for _, face in ipairs(FACES) do
                local look = Look.StateArt(knob, face[1], "page" .. arrow[4] .. face[2])
                if look then
                    Look.Crop(look, 0, 1, 0, 1)
                    Look.Fill(look, knob)
                    if face[1] == "Highlight" then look:SetBlendMode("ADD") end
                end
            end
            wearsOld = true
        end
    end
end

-- The game's atlases back, filling each arrow, at the size first seen.
local function UndressArrows()
    if not wearsOld then return end
    wearsOld = false
    local holder, arrows = Pages()
    for _, arrow in ipairs(arrows or {}) do
        local knob = arrow[1]
        if knob then
            for _, face in ipairs(FACES) do
                local giveAtlas = knob["Set" .. face[1] .. "Atlas"]
                if type(giveAtlas) == "function" then pcall(giveAtlas, knob, "ui-hud-actionbar-" .. arrow[5] .. face[3]) end
                local look = knob["Get" .. face[1] .. "Texture"](knob)
                if look then
                    Look.Fill(look, knob)
                    if face[1] == "Highlight" then look:SetBlendMode("BLEND") end
                end
            end
            local seen = firstSeen[knob]
            if seen then
                knob:SetSize(seen[1], seen[2])
                Pin(knob, "CENTER", holder, "CENTER", 0, seen[3])
            end
        end
    end
end

-- The game's own sizes, read before any band layout resizes the arrows.
do
    local _, arrows = Pages()
    for _, arrow in ipairs(arrows or {}) do
        if arrow[1] then Note(arrow[1], arrow[3]) end
    end
end

ns.RegisterModule("classicBar", { apply = DressArrows, restore = UndressArrows })
