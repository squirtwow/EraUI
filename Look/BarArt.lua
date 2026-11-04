-- The 1.x art on the menu bar's small buttons, and the two Dark Mode extras
-- that colour them:
--   * micro buttons: the old 32x64 sheets (lower 42 rows), the portrait shell
--     on the character button
--   * bag buttons: the quick slot art, the open-bag glow, the backpack's
--     free-slot number, the round reagent bag
--   * the key ring's own art
--   * Dark Menu Bar: the modern micro buttons' bronze frames in Dark Mode's grey
--   * Dark Bag Buttons: the bag icons grey and the open-bag line dark
-- Other files call the public functions on the Classic namespace; the band
-- (Look/Band*.lua) uses them for every button it lays out.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local Art, StateArt, Number = Look.Art, Look.StateArt, Look.Number
local Pin, Fill, Crop, Alpha = Look.Pin, Look.Fill, Look.Crop, Look.Alpha

local function NameOf(object)
    if type(object) ~= "table" or type(object.GetName) ~= "function" then return nil end
    local fine, called = pcall(object.GetName, object)
    return (fine and type(called) == "string") and called or nil
end

local function Hidden(region)
    if region and region.Hide then region:Hide() end
end

local function Unhidden(region)
    if region and region.Show then region:Show() end
end

---------------------------------------------------------------------------
-- Micro buttons
---------------------------------------------------------------------------

-- Each button with a 1.x counterpart, by name: the sheet it wears.
local SHEET_OF = {}
for pair in ([[CharacterMicroButton=Character ProfessionMicroButton=Abilities SpellbookMicroButton=Spellbook
    TalentMicroButton=Talents PlayerSpellsMicroButton=Talents AchievementMicroButton=Achievement
    LegacyMicroButton=Achievement QuestLogMicroButton=Quest GuildMicroButton=Socials LFDMicroButton=LFG
    CollectionsMicroButton=Mounts EJMicroButton=EJ HelpMicroButton=Help StoreMicroButton=BStore
    MainMenuMicroButton=MainMenu EraUIClassicWorldMapMicroButton=World]]):gmatch("%S+") do
    local called, sheet = pair:match("^(%w+)=(%w+)$")
    SHEET_OF[called] = sheet
end
Look.MICRO_SHEETS = SHEET_OF

local wearing = Look.Weak()  -- micro button: true while it wears the 1.x art
local painting = Look.Weak() -- micro button: true while the skin is setting its art
local followed = Look.Weak() -- micro button: its re-apply hooks are in
Look.microWorn = wearing
Look.microOnBand = Look.Weak() -- micro button: true while the band lays it out
Look.parkedMicro = Look.Weak() -- micro button: hidden, never placed, parked off the screen by the band
local SHEET_TOP = 22 / 64      -- the art fills the sheet's lower 42 rows
local MICRO_FACES = { { "Normal", "Up" }, { "Pushed", "Down" }, { "Disabled", "Disabled" } }

local function SheetFor(micro)
    return SHEET_OF[NameOf(micro) or ""]
end

-- The character button's portrait inside the old round shell; pressed, it
-- sits a little lower and dimmer.
local function Portrait(micro)
    local face = micro.Portrait
    if not face then return end
    Hidden(micro.PortraitMask)
    Hidden(micro.Shadow)
    Hidden(micro.PushedShadow)
    face:SetSize(18, 25)
    Pin(face, "TOP", micro, "TOP", 0, -7)
    face:SetDrawLayer("OVERLAY")
    local down = micro:GetButtonState() == "PUSHED"
    if down then Crop(face, 0.2666, 0.8666, 0, 0.8333) else Crop(face, 0.2, 0.8, 0.0666, 0.9) end
    Alpha(face, down and 0.5 or 1)
end
Look.MicroPortrait = Portrait

local function PaintMicro(micro)
    local sheet = SheetFor(micro)
    if not sheet then return end
    painting[micro] = true
    for _, pair in ipairs(MICRO_FACES) do
        local face = StateArt(micro, pair[1], "micro" .. sheet .. pair[2])
        if face then
            Crop(face, 0, 1, SHEET_TOP, 1)
            Fill(face, micro)
        end
    end
    local glow = StateArt(micro, "Highlight", "microHighlight")
    if glow then
        Crop(glow, 0, 1, SHEET_TOP, 1)
        Fill(glow, micro)
        glow:SetBlendMode("ADD")
        Alpha(glow, 1)
    end
    Hidden(micro.Background)
    Hidden(micro.PushedBackground)
    if sheet == "Character" then Portrait(micro) end
    painting[micro] = nil
end

local function Rewear(micro)
    if wearing[micro] and not painting[micro] then PaintMicro(micro) end
end

-- The game fades the normal art while the mouse is over (its own highlight
-- is a whole button); the 1.x highlight is only a glow, so it comes back.
local function NormalBack(micro)
    if wearing[micro] then Alpha(micro:GetNormalTexture(), 1) end
end

local function Follow(micro)
    if followed[micro] then return end
    followed[micro] = true
    for _, method in ipairs(Look.Words("SetNormal SetPushed UpdateMicroButton")) do Look.HookOwn(micro, method, Rewear) end
    for _, method in ipairs(Look.Words("SetNormalAtlas SetPushedAtlas SetDisabledAtlas SetHighlightAtlas")) do
        Look.Hook(micro, method, Rewear)
    end
    Look.HookScript(micro, "OnEnter", NormalBack)
end

local function DressMicro(micro)
    if not micro or not SheetFor(micro) then return false end
    wearing[micro] = true
    Follow(micro)
    PaintMicro(micro)
    Look.PaintMenu(micro)
    return true
end

-- The game's own art back. Its atlases are set straight on the button (the
-- game's loader would also write a key on it).
local function UndressMicro(micro)
    if not micro or not wearing[micro] then return end
    wearing[micro] = nil
    for _, state in ipairs(Look.Words("Normal Pushed Disabled Highlight")) do
        local face = micro["Get" .. state .. "Texture"](micro)
        if face then
            Crop(face, 0, 1, 0, 1)
            Fill(face, micro)
        end
    end
    local art = micro.textureName
    if type(art) == "string" then
        for state, suffix in pairs({ Normal = "-Up", Pushed = "-Down", Disabled = "-Disabled", Highlight = "-Mouseover" }) do
            pcall(micro["Set" .. state .. "Atlas"], micro, "UI-HUD-MicroMenu-" .. art .. suffix)
        end
    end
    Unhidden(micro.PortraitMask)
    Unhidden(micro.Shadow)
    if micro.Portrait then
        Crop(micro.Portrait, 0, 1, 0, 1)
        micro.Portrait:SetDrawLayer("ARTWORK")
        Alpha(micro.Portrait, 1)
    end
    local settle = micro[micro:GetButtonState() == "PUSHED" and "SetPushed" or "SetNormal"]
    if type(settle) == "function" then pcall(settle, micro) end
    Look.PaintMenu(micro)
end

---------------------------------------------------------------------------
-- Dark Menu Bar: the modern buttons' frames (Background, PushedBackground)
-- in Dark Mode's grey. The icons (state textures) keep their colours; a
-- button wearing the 1.x art (or laid out on the band) is left to it.
---------------------------------------------------------------------------

local DARK_MENU = {}
for called in pairs(SHEET_OF) do
    if called ~= "EraUIClassicWorldMapMicroButton" then DARK_MENU[#DARK_MENU + 1] = called end
end
table.sort(DARK_MENU)

local tintGiven = Look.Weak() -- micro button: the grey it was last given
local inWorld = false

local function MenuDark()
    return Look.Enabled() and EraUI:GetSetting("darkMode") and EraUI:GetSetting("darkMenuBar")
        and type(ns.DarkGrey) == "function" and true or false
end

local function Backs(micro, r, g, b)
    for _, back in ipairs({ micro.Background or false, micro.PushedBackground or false }) do
        if back then back:SetVertexColor(r, g, b) end
    end
end

-- force: paint again even unchanged (the game has just reloaded its art).
function Look.PaintMenu(micro, force)
    if not inWorld or not micro then return end
    if MenuDark() and not wearing[micro] and not Look.microOnBand[micro] then
        local r, g, b = ns.DarkGrey()
        local given = tintGiven[micro]
        if given and not force and given[1] == r and given[2] == g and given[3] == b then return end
        Backs(micro, r, g, b)
        tintGiven[micro] = { r, g, b }
    elseif tintGiven[micro] then
        Backs(micro, 1, 1, 1)
        tintGiven[micro] = nil
    end
end

local function RepaintMenu()
    if not inWorld then return end
    for _, called in ipairs(DARK_MENU) do
        local micro = _G[called]
        if type(micro) == "table" then Look.PaintMenu(micro) end
    end
end

local function AfterArtReload(micro)
    if type(micro) ~= "table" then return end
    Rewear(micro)
    if SHEET_OF[NameOf(micro) or ""] then Look.PaintMenu(micro, true) end
end

---------------------------------------------------------------------------
-- Dark Bag Buttons: the bag bar's icons desaturated and grey (all alike, still
-- told apart) and the open-bag line dark, wherever the buttons sit. Only
-- colour calls on the game's textures, after the game's own updates; EraUI's
-- state in weak tables, nothing hooked until the tick is first on.
---------------------------------------------------------------------------

local BAG_NAMES = Look.Words("MainMenuBarBackpackButton CharacterBag0Slot CharacterBag1Slot CharacterBag2Slot "
    .. "CharacterBag3Slot CharacterReagentBag0Slot KeyRingButton")
local BAG_GREY, BAG_LINE = 0.6, 0
local bagBar = setmetatable({}, { __mode = "k" })   -- a bag bar button: its own update followed
local bagPaint = setmetatable({}, { __mode = "k" }) -- a texture: its own colour and EraUI's last paint
local bagGrey = setmetatable({}, { __mode = "k" })  -- an icon: the desaturation it had before EraUI's grey
local bagWatching = false

local function DarkBags()
    return Look.Enabled() and EraUI:GetSetting("darkMode") and EraUI:GetSetting("darkBagButtons") and true or false
end
Look.DarkBags = DarkBags

local function OnBagBar(slot)
    for _, slotName in ipairs(BAG_NAMES) do
        if _G[slotName] == slot then return true end
    end
    return false
end

local function Readable(...)
    for i = 1, select("#", ...) do
        if Number((select(i, ...))) == nil then return false end
    end
    return true
end

-- A colour read back near EraUI's own last paint is EraUI's; any other is the
-- texture's own and kept. A colour that can't be read is never kept.
local function PaintBag(texture, r, g, b)
    local paint = bagPaint[texture] or {}
    bagPaint[texture] = paint
    local red, green, blue, alpha = texture:GetVertexColor()
    if Readable(red, green, blue, alpha) then
        local last = paint.last
        local ours = last ~= nil and math.abs(red - last[1]) <= 0.01 and math.abs(green - last[2]) <= 0.01
            and math.abs(blue - last[3]) <= 0.01
        if not ours then paint.own = { red, green, blue, alpha } end
    end
    texture:SetVertexColor(r, g, b, paint.own and paint.own[4] or 1)
    paint.last = { r, g, b }
end

local function GiveBack(texture)
    local paint = bagPaint[texture]
    if not paint then return false end
    local own = paint.own or { 1, 1, 1, 1 }
    texture:SetVertexColor(own[1], own[2], own[3], own[4])
    bagPaint[texture] = nil
    return true
end

-- One button's look, on or off. Off it touches only what EraUI painted.
local function DarkenBag(slot)
    if type(slot) ~= "table" then return end
    local icon, line = slot.icon or slot.Icon, slot.SlotHighlightTexture
    if DarkBags() then
        if icon then
            PaintBag(icon, BAG_GREY, BAG_GREY, BAG_GREY)
            icon:SetDesaturated(true)
        end
        if line then PaintBag(line, BAG_LINE, BAG_LINE, BAG_LINE) end
        return
    end
    if icon and GiveBack(icon) then icon:SetDesaturated(bagGrey[icon] == true) end
    if line then GiveBack(line) end
end
Look.DarkenBag = DarkenBag

local function AfterGameColour(slot)
    if OnBagBar(slot) then DarkenBag(slot) end
end

local function AfterGameGrey(slot, desaturated)
    if not OnBagBar(slot) then return end
    local icon = slot.icon or slot.Icon
    if icon then bagGrey[icon] = desaturated and true or false end
    DarkenBag(slot)
end

local GAME_CALLS = { SetItemButtonTextureVertexColor = AfterGameColour, SetItemButtonDesaturated = AfterGameGrey }

-- Each button's own texture update, and the game's two item-button calls.
local function WatchBags()
    for _, slotName in ipairs(BAG_NAMES) do
        local slot = _G[slotName]
        if type(slot) == "table" and not bagBar[slot] and type(rawget(slot, "UpdateTextures")) == "function" then
            bagBar[slot] = true
            hooksecurefunc(slot, "UpdateTextures", DarkenBag)
        end
    end
    if bagWatching then return end
    bagWatching = true
    for call, after in pairs(GAME_CALLS) do
        if type(_G[call]) == "function" then hooksecurefunc(call, after) end
    end
end

local function BagIconGrey(icon, grey)
    bagGrey[icon] = grey and true or false
    icon:SetDesaturated(grey and true or false)
end

---------------------------------------------------------------------------
-- Bag buttons in the 1.x quick slot art
---------------------------------------------------------------------------

local BAG_SLOTS = {}
for _, slotName in ipairs(Look.Words("CharacterBag0Slot CharacterBag1Slot CharacterBag2Slot CharacterBag3Slot CharacterReagentBag0Slot")) do
    BAG_SLOTS[slotName] = true
end
local EMPTY_SLOT_ICON = "Interface\\PaperDoll\\" .. "UI-PaperDoll-Slot-Bag"
local bagWorn = Look.Weak()  -- bag button: how it wears the art { size, backpack, slim, round }
local bagFollowed = Look.Weak()
local keyWorn = Look.Weak()  -- key ring: true while it wears its 1.x art
Look.bagWorn, Look.keyWorn = bagWorn, keyWorn

local function SlotIcon(bag, how, icon)
    if how.round then
        Alpha(icon, 1)
        BagIconGrey(icon, false)
        icon:Show()
        return
    end
    local id = Number(bag.GetID and bag:GetID())
    local holds = id and GetInventoryItemTexture and GetInventoryItemTexture("player", id)
    if holds then
        BagIconGrey(icon, false)
        Alpha(icon, 1)
        Crop(icon, 0, 1, 0, 1)
    else
        icon:SetTexture(EMPTY_SLOT_ICON)
        BagIconGrey(icon, true)
        Alpha(icon, 0.5)
    end
end

-- The backpack's free-slot number at the bottom in the small number font. On
-- build 70170 and later that is FreeSlots, and Count (the game's leftover ammo
-- count) is hidden by alpha only, never shown or hidden.
local function BackpackText(pack)
    local number = pack.FreeSlots or pack.Count
    if number then
        Pin(number, "BOTTOM", pack, "BOTTOM", 0, 3)
        number:SetFontObject("NumberFontNormalSmall")
    end
    if pack.FreeSlots and pack.Count then Alpha(pack.Count, 0) end
end

local function BagBorder(bag, how, width, height)
    local ring = bag.IconBorder
    if not ring then return end
    ring:SetDrawLayer("OVERLAY")
    if how.round then
        local across = how.size
        Art(ring, "reagentRing")
        ring:SetSize(across * 2.5, across * 2.5)
        Pin(ring, "TOPLEFT", bag, "TOPLEFT", -0.26 * across, 0.26 * across)
        ring:SetVertexColor(1, 1, 1, 1)
        Alpha(ring, 1)
        ring:Show()
    else
        Art(ring, "bagFrame")
        ring:SetSize(width, height)
        Pin(ring, "CENTER", bag, "CENTER")
    end
end

local function OpenBagLine(bag)
    local line = bag.SlotHighlightTexture
    if not line then return end
    -- Dark Bag Buttons: an open bag looks pressed in (no colour darkens the
    -- additive glow).
    if DarkBags() then
        Art(line, "slotPushed")
        line:SetBlendMode("BLEND")
    else
        Art(line, "slotChecked")
        line:SetBlendMode("ADD")
    end
    Crop(line, 0, 1, 0, 1)
    Alpha(line, 1)
end

local function DressBagFaces(bag, width, height)
    local ring = StateArt(bag, "Normal", "slotNormal")
    if ring then
        Crop(ring, 0, 1, 0, 1)
        ring:SetSize(width * 50 / 30, height * 50 / 30)
        Pin(ring, "CENTER", bag, "CENTER", 0, -1)
        Alpha(ring, 0) -- set, but never shown
    end
    local down = StateArt(bag, "Pushed", "slotPushed")
    if down then
        Fill(down, bag)
        Alpha(down, 1)
    end
    local glow = StateArt(bag, "Highlight", "slotHighlight")
    if glow then
        Fill(glow, bag)
        glow:SetBlendMode("ADD")
        Alpha(glow, 1)
    end
end

local function ApplyBagSkin(bag)
    local how = bagWorn[bag]
    if not how then return end
    local width, height = how.size, how.size
    if how.slim then width, height = Number(bag:GetWidth()) or 18, Number(bag:GetHeight()) or 39 end
    DressBagFaces(bag, width, height)
    OpenBagLine(bag)
    if bag.CircleMask then bag.CircleMask:SetShown(how.round) end
    BagBorder(bag, how, width, height)
    local icon = bag.icon or bag.Icon
    if icon then
        if how.slim then
            local side = (1 - math.min(1, width / height)) / 2
            Crop(icon, side, 1 - side, 0, 1)
        elseif not how.backpack then
            Crop(icon, 0, 1, 0, 1)
        end
        if how.backpack then
            Art(icon, "backpack")
        elseif BAG_SLOTS[NameOf(bag) or ""] then
            SlotIcon(bag, how, icon)
        end
    end
    if how.backpack then BackpackText(bag) end
    DarkenBag(bag)
end

local function ReapplyBagSkin(bag)
    if bagWorn[bag] then ApplyBagSkin(bag) end
end

-- size: the button's size; slim: narrow (keeps the icon's shape); round: the
-- small round reagent bag.
local function DressBag(bag, size, isBackpack, slim, round)
    if not bag then return end
    bagWorn[bag] = { size = Number(size) or Number(bag:GetWidth()) or 30, backpack = isBackpack and true or false,
        slim = slim and true or false, round = round and true or false }
    if not bagFollowed[bag] then
        bagFollowed[bag] = true
        Look.HookOwn(bag, "UpdateTextures", ReapplyBagSkin)
        Look.HookOwn(bag, "SetItemButtonQuality", ReapplyBagSkin)
    end
    ApplyBagSkin(bag)
end

local function UndressBag(bag)
    local how = bag and bagWorn[bag]
    if not how then return end
    bagWorn[bag] = nil
    Unhidden(bag.CircleMask)
    if bag.IconBorder then Fill(bag.IconBorder, bag) end
    if how.backpack and bag.FreeSlots then
        Pin(bag.FreeSlots, "CENTER", bag, "CENTER", 0, -10)
        bag.FreeSlots:SetFontObject("NumberFontNormal")
        Alpha(bag.Count, 1)
    elseif how.backpack and bag.Count then
        Pin(bag.Count, "BOTTOMRIGHT", bag, "BOTTOMRIGHT", -3, 4)
    end
    Look.Ask(bag, "UpdateTextures")
    DarkenBag(bag)
end

---------------------------------------------------------------------------
-- The key ring (or the reagent bag wearing it, on a client without one)
---------------------------------------------------------------------------

local KEY_FACES = { { "Normal", "keyRingUp" }, { "Pushed", "keyRingDown" }, { "Highlight", "keyRingHighlight" } }

local function ApplyKeyRing(ring)
    if not keyWorn[ring] then return end
    local ours = {}
    for _, pair in ipairs(KEY_FACES) do
        local face = StateArt(ring, pair[1], pair[2])
        if face then
            ours[face] = true
            Crop(face, 0, 18 / 32, 0, 39 / 64)
            Fill(face, ring)
            Alpha(face, 1)
            if pair[1] == "Highlight" then face:SetBlendMode("ADD") end
        end
    end
    Look.EachRegion(ring, function(piece)
        if not ours[piece] then Alpha(piece, 0) end
    end)
    Hidden(ring.CircleMask)
    Alpha(ring.Count, 0)
    DarkenBag(ring)
end

local function AfterKeyRingUpdate(ring)
    if keyWorn[ring] then ApplyKeyRing(ring) else ReapplyBagSkin(ring) end
end

local function DressKeyRing(ring)
    if not ring then return end
    keyWorn[ring] = true
    if not bagFollowed[ring] then
        bagFollowed[ring] = true
        Look.HookOwn(ring, "UpdateTextures", AfterKeyRingUpdate)
    end
    ApplyKeyRing(ring)
end

local function UndressKeyRing(ring)
    if not ring or not keyWorn[ring] then return end
    keyWorn[ring] = nil
    -- The faces as they are (the game's update below puts its own art back).
    for _, pair in ipairs(KEY_FACES) do
        local face = ring["Get" .. pair[1] .. "Texture"](ring)
        if face then Crop(face, 0, 1, 0, 1) end
    end
    Look.EachRegion(ring, function(piece) Alpha(piece, 1) end)
    Alpha(ring.Count, 1)
    Look.Ask(ring, "UpdateTextures")
    DarkenBag(ring)
end

-- The tick in /era: each bag button's look again, and the 1.x art again on
-- a button wearing it (its open-bag art differs with the tick).
local function RefreshBags()
    if DarkBags() then WatchBags() end
    for _, bagName in ipairs(BAG_NAMES) do
        local bag = _G[bagName]
        if type(bag) == "table" then
            if keyWorn[bag] then ApplyKeyRing(bag)
            elseif bagWorn[bag] then ApplyBagSkin(bag)
            else DarkenBag(bag) end
        end
    end
end

---------------------------------------------------------------------------
-- What other files call
---------------------------------------------------------------------------

ns.SkinMicroButton, ns.UnskinMicroButton = DressMicro, UndressMicro
ns.SkinBagButton, ns.UnskinBagButton = DressBag, UndressBag
ns.SkinKeyRing, ns.UnskinKeyRing = DressKeyRing, UndressKeyRing
ns.RefreshDarkMenuBar = RepaintMenu

function ns.RefreshDarkBagButtons()
    if DarkBags() then WatchBags() end
    RefreshBags()
end

---------------------------------------------------------------------------
-- Timing: both Dark extras wait for the world; the game reloading a micro
-- button's art repaints it.
---------------------------------------------------------------------------

Look.HookGlobal("LoadMicroButtonTextures", AfterArtReload)

local arrival = CreateFrame("Frame")
arrival:RegisterEvent("PLAYER_ENTERING_WORLD")
arrival:SetScript("OnEvent", function()
    inWorld = true
    Look.HookGlobal("LoadMicroButtonTextures", AfterArtReload)
    RepaintMenu()
    RefreshBags()
end)
