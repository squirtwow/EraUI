-- Bags and the bank, the part both share (Look/Bag*.lua and Look/BankDress.lua,
-- the "Bags & Bank" switch): the art they wear, the One Bag column count, the
-- 1.x ring and dark hole a slot sits in, and EraUI's records of what it made.
-- Every record is EraUI's own and weak-keyed; nothing is written on the
-- game's windows or buttons.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local B = {}
Look.Bags = B

-- How many slots across the One Bag window may be (other files read these
-- before they build their column sliders).
ns.ONE_BAG_COLUMNS_MIN, ns.ONE_BAG_COLUMNS_MAX = 4, 16

-- The bag sheets exist only as EraUI's copies (the client's are gone or
-- redrawn); Dark Mode greys both. The bank's empty bag icon has a client
-- file and a copy, and is never greyed.
Look.DefineArt("bagSheet", nil, "UI-Bag-Components", "bagComponents", true)
Look.DefineArt("backpackSheet", nil, "UI-BackpackBackground", "backpackBg", true)
Look.DefineArt("bankBagSlot", "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag", "UI-PaperDoll-Slot-Bag")

-- Set straight from these files: no fallback and no Dark Mode tint.
B.RING = "Interface\\Buttons\\UI-Quickslot2"
B.FLOOR = Look.MEDIA .. "UI-BankFrame-Floor"

-- The textures this area made on the game's windows (they are never faded
-- with the game's own art).
B.mine = Look.Weak()

-- A whole number of columns from anything: rounded to the nearest, kept
-- within the limits; not a usable number: the fewest.
function B.Columns(value)
    local fewest, most = ns.ONE_BAG_COLUMNS_MIN, ns.ONE_BAG_COLUMNS_MAX
    local wanted = Look.Number(value)
    if not wanted then return fewest end
    return Look.Clamp(math.floor(wanted + 0.5), fewest, most)
end

-- A slot button's width, or the game's usual 37 when it can't be read.
function B.Width(button)
    local fine, across = Look.Ask(button, "GetWidth")
    across = fine and Look.Number(across) or nil
    if not across or across <= 0 then return 37 end
    return across
end

-- The 1.x ring a slot sits in: the slot's normal face from the quickslot
-- file, the whole file, `across` square, its middle one below the slot's.
function B.Ring(button, across)
    local read = button.GetNormalTexture
    local ring = type(read) == "function" and read(button) or nil
    if not ring and type(button.SetNormalTexture) == "function" then
        button:SetNormalTexture(B.RING)
        ring = read and read(button) or nil
    end
    if not ring then return end
    ring:SetTexture(B.RING)
    Look.Crop(ring, 0, 1, 0, 1)
    ring:SetSize(across, across)
    Look.Pin(ring, "CENTER", button, "CENTER", 0, -1)
end

-- The near-black hole under a bank slot: its own Background, one in from
-- every edge.
function B.Hole(button)
    local hole = button.Background
    if not hole or type(hole.SetColorTexture) ~= "function" then return end
    hole:SetColorTexture(0.06, 0.06, 0.06, 1)
    Look.Inside(hole, button, 1, 1, 1, 1)
    hole:SetAlpha(1)
end

-- A texture of this area's own on a game window, made the first time.
function B.Own(owner, purpose, sublevel)
    local made = Look.OwnTexture(owner, purpose, "BACKGROUND", sublevel)
    B.mine[made] = true
    return made
end

-- True for a plain texture (not a font string, line or mask).
function B.IsTexture(region)
    local fine, kind = Look.Ask(region, "GetObjectType")
    return fine and kind == "Texture"
end
