-- The classic button style ("buttons", switched with Action Bars): every
-- action button on the nine bars below wears the 1.x quick slot art in place
-- of Forever's modern frame:
--   * a recessed stone socket under the icon and a bevelled ring over it
--   * the old pressed, mouse-over and checked looks, the red attack flash and
--     the equipped item's border
--   * square icons (squareIcons): the icon's round mask taken off
-- Every size follows the button's own width, so the art fits a button the band
-- or Edit Mode has grown. Now and then the game redraws a button's frame; a
-- light look every 0.2 s finds such a button and dresses it again. Nothing of
-- the game's is hooked and no key is written on its buttons: what EraUI knows
-- about them is kept in weak tables here.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local Number, Art, StateArt = Look.Number, Look.Art, Look.StateArt
local Alpha, Crop, Pin = Look.Alpha, Look.Crop, Look.Pin

-- The bars dressed (Action Bar 1 under either of its names).
local STYLED_BARS = Look.Words([[MainActionBar MainMenuBar MultiBarBottomLeft MultiBarBottomRight MultiBarRight
    MultiBarLeft MultiBar5 MultiBar6 MultiBar7]])

-- 1.x sizes for a 36-wide slot; each grows with the button (width / 36).
local SLOT, RING_SIDE, SOCKET_SIDE, BORDER_SIDE = 36, 40, 66, 62
local RING_FROM, RING_TO = 12 / 64, 51 / 64 -- the ring's own pixels on its 64 sheet
local SOCKET_ALPHA, RING_ALPHA = 0.4, 0.5
local UNREADABLE_WIDTH = 45 -- Forever's own button size

-- The game's art, given back when the style comes off.
local GAME_SOCKET = "UI-HUD-ActionBar-IconFrame-Background"
local GAME_GLOW = "UI-HUD-ActionBar-IconFrame-Mouseover"
local GAME_FLASH = "UI-HUD-ActionBar-IconFrame-Flash"
local GAME_BORDER = "UI-HUD-ActionBar-IconFrame-Border"

-- The two glows, which add light rather than cover.
local GLOWS = { { "Highlight", "slotHighlight" }, { "Checked", "slotChecked" } }

local wearing = false        -- the style is on
local dressed = Look.Weak()  -- action button: wears the 1.x art
local unmasked = Look.Weak() -- action button: EraUI took its icon's round mask off

---------------------------------------------------------------------------
-- The buttons
---------------------------------------------------------------------------

-- fn on each action button of the styled bars, once each: a bar's own list,
-- else its buttons by their global names.
local function EachActionButton(fn)
    local barsDone, buttonsDone = {}, {}
    for _, barName in ipairs(STYLED_BARS) do
        local bar = _G[barName]
        if type(bar) == "table" and not barsDone[bar] then
            barsDone[bar] = true
            for _, actionButton in ipairs(Look.BarButtons(bar)) do
                if not buttonsDone[actionButton] then
                    buttonsDone[actionButton] = true
                    fn(actionButton)
                end
            end
        end
    end
end

local function BandOn()
    return type(ns.ClassicBarActive) == "function" and ns.ClassicBarActive() == true
end

-- With the band switched off (classicBar false), Action Bar 1 is the game's
-- own bar in its own art: its buttons keep the slot frame while it shows.
local function KeepsGameFrame(actionButton)
    local frame = actionButton.SlotArt
    if Look.Saved().classicBar ~= false or not frame or not frame:IsShown() then return false end
    local called = Look.AnchorName(actionButton)
    if type(called) ~= "string" then return false end
    local index = tonumber(called:match("^ActionButton(%d+)$"))
    return index ~= nil and index >= 1 and index <= 12
end

local function SideOf(actionButton)
    local wide = Number(actionButton:GetWidth())
    if not wide or wide <= 0 then wide = UNREADABLE_WIDTH end
    return wide
end

-- A square of the given side, in the middle of the button.
local function Centre(texture, owner, side)
    texture:SetSize(side, side)
    Pin(texture, "CENTER", owner, "CENTER")
end

local function Uncropped(texture)
    Crop(texture, 0, 1, 0, 1)
end

---------------------------------------------------------------------------
-- Putting the 1.x art on
---------------------------------------------------------------------------

local function Socket(actionButton, grow)
    local socket = actionButton.SlotBackground
    if not socket then return end
    Art(socket, "slotEmpty")
    Uncropped(socket)
    Centre(socket, actionButton, SOCKET_SIDE * grow)
    socket:SetDrawLayer("BACKGROUND", -1)
    socket:SetAlpha(SOCKET_ALPHA)
    socket:Show()
end

local function Ring(actionButton, grow)
    local ring = StateArt(actionButton, "Normal", "slotNormal")
    if not ring then return end
    Crop(ring, RING_FROM, RING_TO, RING_FROM, RING_TO)
    Centre(ring, actionButton, RING_SIDE * grow)
    ring:SetDrawLayer("OVERLAY")
    ring:SetAlpha(RING_ALPHA)
end

-- The faces the size of the button itself: pressed, mouse-over, checked and
-- the red attack flash.
local function WholeFaces(actionButton, side)
    local pressed = StateArt(actionButton, "Pushed", "slotPushed")
    if pressed then
        Uncropped(pressed)
        Centre(pressed, actionButton, side)
        pressed:SetDrawLayer("OVERLAY")
    end
    for _, pair in ipairs(GLOWS) do
        local glow = StateArt(actionButton, pair[1], pair[2])
        if glow then
            Uncropped(glow)
            Centre(glow, actionButton, side)
            glow:SetBlendMode("ADD")
        end
    end
    local flash = actionButton.Flash
    if flash then
        Art(flash, "slotFlash")
        Uncropped(flash)
        Centre(flash, actionButton, side)
    end
end

local function EquippedBorder(actionButton, grow)
    local border = actionButton.Border
    if not border then return end
    Art(border, "slotBorder")
    Uncropped(border)
    Centre(border, actionButton, BORDER_SIDE * grow)
    border:SetBlendMode("ADD")
end

-- The icon's round mask off (square) or back on; each change made once.
local function IconShape(actionButton, square)
    local icon, mask = actionButton.icon, actionButton.IconMask
    if not icon or not mask then return end
    if square and not unmasked[actionButton] then
        if Look.Ask(icon, "RemoveMaskTexture", mask) then unmasked[actionButton] = true end
    elseif not square and unmasked[actionButton] then
        Look.Ask(icon, "AddMaskTexture", mask)
        unmasked[actionButton] = nil
    end
end

-- Marked first, so a button that fails half-way is still undressed later.
local function Dress(actionButton)
    dressed[actionButton] = true
    local side = SideOf(actionButton)
    local grow = side / SLOT
    Alpha(actionButton.SlotArt, KeepsGameFrame(actionButton) and 1 or 0)
    Socket(actionButton, grow)
    Ring(actionButton, grow)
    WholeFaces(actionButton, side)
    EquippedBorder(actionButton, grow)
    IconShape(actionButton, Look.Saved().squareIcons ~= false)
end

---------------------------------------------------------------------------
-- Taking it off: the game's own art back
---------------------------------------------------------------------------

local function GameAtlas(texture, atlas, ownSize)
    if texture then Look.Ask(texture, "SetAtlas", atlas, ownSize) end
end

local function AtTopLeft(texture, owner)
    if texture then Pin(texture, "TOPLEFT", owner, "TOPLEFT") end
end

local function StateFace(actionButton, state)
    local read = actionButton["Get" .. state .. "Texture"]
    return type(read) == "function" and read(actionButton) or nil
end

local function Undress(actionButton)
    Alpha(actionButton.SlotArt, 1)
    local socket = actionButton.SlotBackground
    if socket then
        socket:SetAlpha(1)
        socket:SetDrawLayer("BACKGROUND", 0)
        Uncropped(socket)
        GameAtlas(socket, GAME_SOCKET)
        Look.Fill(socket, actionButton)
    end
    IconShape(actionButton, false)
    for _, state in ipairs({ "Normal", "Pushed" }) do
        local face = StateFace(actionButton, state)
        if face then
            Uncropped(face)
            AtTopLeft(face, actionButton)
        end
    end
    Alpha(StateFace(actionButton, "Normal"), 1)
    -- The game's own frame art (its atlases, sizes and slot pieces).
    Look.Ask(actionButton, "UpdateButtonArt")
    for _, pair in ipairs(GLOWS) do
        local glow = StateFace(actionButton, pair[1])
        if glow then
            GameAtlas(glow, GAME_GLOW)
            AtTopLeft(glow, actionButton)
            glow:SetSize(46, 45)
        end
    end
    GameAtlas(actionButton.Flash, GAME_FLASH, true)
    AtTopLeft(actionButton.Flash, actionButton)
    local border = actionButton.Border
    if border then
        GameAtlas(border, GAME_BORDER, true)
        border:SetBlendMode("BLEND")
        AtTopLeft(border, actionButton)
    end
    dressed[actionButton] = nil
end

---------------------------------------------------------------------------
-- Each button on its own: one that errors never stops the others; the
-- first error is passed on once all are done.
---------------------------------------------------------------------------

local function EachOnItsOwn(buttons, work)
    local firstProblem
    for _, actionButton in ipairs(buttons) do
        local fine, problem = pcall(work, actionButton)
        if not fine and firstProblem == nil then firstProblem = problem end
    end
    if firstProblem ~= nil then error(firstProblem, 0) end
end

local function Collect(wanted)
    local found = {}
    EachActionButton(function(actionButton)
        if wanted == nil or wanted(actionButton) then found[#found + 1] = actionButton end
    end)
    return found
end

---------------------------------------------------------------------------
-- The repaint watch: a button counts as redrawn by the game when its slot
-- frame shows again (or, kept, has faded), its socket was hidden while the
-- band is off, or its socket's alpha is no longer EraUI's.
---------------------------------------------------------------------------

local function Redrawn(actionButton)
    local frame = actionButton.SlotArt
    local frameAlpha = frame and Number(frame:GetAlpha())
    if frameAlpha then
        if KeepsGameFrame(actionButton) then
            if frameAlpha < 0.99 then return true end
        elseif frameAlpha > 0.01 then
            return true
        end
    end
    local socket = actionButton.SlotBackground
    if not socket then return false end
    if not socket:IsShown() and not BandOn() then return true end
    local socketAlpha = Number(socket:GetAlpha())
    return socketAlpha ~= nil and math.abs(socketAlpha - SOCKET_ALPHA) > 0.005
end

Look.Every(0.2, function()
    if wearing then EachOnItsOwn(Collect(Redrawn), Dress) end
end)

---------------------------------------------------------------------------
-- The registry entry and what other files call
---------------------------------------------------------------------------

local function PutOn()
    wearing = true
    EachOnItsOwn(Collect(), Dress)
end

-- Cheap to repeat: nothing unless the style was on.
local function TakeOff()
    if not wearing then return end
    wearing = false
    local worn = {}
    for actionButton in pairs(dressed) do worn[#worn + 1] = actionButton end
    EachOnItsOwn(worn, Undress)
end

ns.ForEachActionButton = EachActionButton
ns.RegisterModule("buttons", { apply = PutOn, restore = TakeOff })
