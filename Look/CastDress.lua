-- The 1.x look on one cast bar, piece by piece: the shape for its look, the
-- dark ground, the spark, the flash, the shield, the game's modern effects
-- hidden, and where the target's and focus's bars sit under their frame.
-- Cosmetic setters on the bar's own pieces only; the bar itself is sized
-- (never while the game guards it in a fight) and the target's and focus's
-- moved (they are no Edit Mode frames).
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Cast = Look.Cast

-- Per look: the bar's size, the border, flash and shield art, the name's font.
local SHAPES = {
    CLASSIC = { w = 195, h = 13, border = "castBorder", flash = "castFlash", shield = "castBorder",
        font = "GameFontHighlight" },
    UNITFRAME = { w = 150, h = 10, border = "castBorderSmall", flash = "castFlashSmall", shield = "castSmallShield",
        font = "SystemFont_Shadow_Small" },
}

-- A sheet of 1.x art on a piece, the whole file.
local function Sheet(piece, key)
    Look.Art(piece, key)
    piece:SetTexCoord(0, 1, 0, 1)
end

-- A piece w x h whose top sits on the bar's top, y up.
local function OnTop(piece, bar, w, h, y)
    piece:ClearAllPoints()
    piece:SetSize(w, h)
    piece:SetPoint("TOP", bar, "TOP", 0, y)
end

-- A piece of the given height held by the bar's two top corners.
local function Across(piece, bar, height, left, right, y)
    piece:ClearAllPoints()
    piece:SetHeight(height)
    piece:SetPoint("TOPLEFT", bar, "TOPLEFT", left, y)
    piece:SetPoint("TOPRIGHT", bar, "TOPRIGHT", right, y)
end

-- The bar's size, border, shield's place, name and (small bars) icon.
-- Any other look (the game's OVERLAY) is left as it is.
function Cast.Shape(bar, look)
    local shape = SHAPES[look]
    if not shape then return end
    if not Look.HeldInFight(bar) then bar:SetSize(shape.w, shape.h) end
    local border, shield, name = bar.Border, bar.BorderShield, bar.Text
    if border then Sheet(border, shape.border) end
    if look == "CLASSIC" then
        if border then OnTop(border, bar, 256, 64, 28) end
        if shield then OnTop(shield, bar, 256, 64, 28) end
        if name then OnTop(name, bar, 185, 16, 5) end
    else
        if border then Across(border, bar, 56, -23, 23, 23) end
        if shield then Across(shield, bar, 56, -28, 18, 23) end
        if name then Across(name, bar, 16, 0, 0, 4) end
        local icon = bar.Icon
        if icon then
            icon:SetSize(18, 18)
            Look.Pin(icon, "RIGHT", bar, "LEFT", -3.5, 1)
        end
    end
    if name then name:SetFontObject(shape.font) end
end

-- Black at half alpha behind the fill, filling the bar.
function Cast.Ground(bar)
    local ground = bar.Background
    if not ground then return end
    ground:SetTexture(nil)
    ground:SetColorTexture(0, 0, 0, 0.5)
    Look.Fill(ground, bar)
end

-- The static 1.x spark: 32 square, or as tall as the rounded shell when the
-- bar wears (or is about to wear) the rounded look. The game places it.
function Cast.Spark(bar, look, rounded)
    local spark = bar.Spark
    if not spark then return end
    Sheet(spark, "castSpark")
    local side = 32
    local shape = rounded and Cast.GEOMETRY[look]
    if shape then side = shape.h + 2 * shape.edge end
    spark:SetSize(side, side)
    spark:SetBlendMode("ADD")
end

-- The white 1.x flash when a cast completes, or the rounded look's soft one.
function Cast.Flash(bar, look, rounded)
    local flash = bar.Flash
    if not flash then return end
    if rounded and Cast.GEOMETRY[look] then
        Cast.SoftFlash(bar, flash)
        return
    end
    local shape = SHAPES[look]
    if not shape then return end
    Sheet(flash, shape.flash)
    flash:SetBlendMode("ADD")
    if look == "CLASSIC" then OnTop(flash, bar, 256, 64, 28) else Across(flash, bar, 56, -23, 23, 23) end
    if Cast.soft[flash] then
        -- Back from the rounded look: its soft tint off, once.
        Cast.soft[flash] = nil
        flash:SetVertexColor(1, 1, 1, 1)
    end
end

-- The shield the game shows for a cast that can't be interrupted: the small
-- 1.x shield, or on the big bar its plain border (1.x had no other).
function Cast.ShieldArt(bar, look)
    local shield, shape = bar.BorderShield, SHAPES[look]
    if shield and shape then Sheet(shield, shape.shield) end
end

-- The modern flakes, glows, shadows and name plate, out of sight.
function Cast.HideEffects(bar)
    for _, key in ipairs(Cast.EFFECTS) do
        local piece = bar[key]
        if piece then
            piece:SetTexture(nil)
            piece:SetAlpha(0)
            piece:Hide()
        end
    end
end

-- The game's three finish animations, stopped (the 1.x flash fades alone).
function Cast.StopFinish(bar)
    for _, key in ipairs({ "StandardFinish", "ChannelFinish", "CraftingFinish" }) do
        local anim = bar[key]
        if anim and type(anim.Stop) == "function" then anim:Stop() end
    end
end

---------------------------------------------------------------------------
-- The target's and focus's bars under their frame
---------------------------------------------------------------------------

-- How far below the frame's foot the bar starts: under Thick Frames' plate
-- (its own number), under a target of target, under an elite's dragon, else
-- just under the frame. The elite flag is the unit frames' own note.
function Cast.Drop(parent)
    local thick = type(ns.ThickCastY) == "function" and ns.ThickCastY(parent) or nil
    if Look.Number(thick) then return thick end
    if Cast.Flag(parent.haveToT) then return -25 end
    if type(ns.UnitFrameOwn) == "function" and ns.UnitFrameOwn(parent, "haveElite") then return -9 end
    return 3
end

-- The aura row the game hung the bar under (while auras show), or nil.
local function AuraRowAbove(bar, parent)
    local asked, row = Look.Ask(parent, "GetAuraContainer")
    if not asked or Look.Secret(row) or row == nil then return nil end
    local read, _, relative = pcall(bar.GetPoint, bar, 1)
    if not read or Look.Secret(relative) or relative ~= row then return nil end
    return row
end

-- After the game's own placing (so this always wins), in fights too: the
-- target's and focus's bars are neither Edit Mode frames nor protected.
function Cast.Place(bar)
    if not Cast.applied or Cast.boss[bar] or Cast.Flag(bar.boss) or Look.HeldInFight(bar) then return end
    local parent = bar:GetParent()
    if not parent or type(parent.GetAuraContainer) ~= "function" then return end
    if Cast.Flag(parent.smallSize) then
        -- The game's small focus scales its bar up; it stays at 1.
        local scale = Look.Number(bar:GetScale())
        if scale and scale ~= 1 then bar:SetScale(1) end
    end
    local row = AuraRowAbove(bar, parent)
    bar:ClearAllPoints()
    if row then
        bar:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 22, -16)
    else
        bar:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 43, Cast.Drop(parent))
    end
end
