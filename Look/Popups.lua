-- Popups (EraUIDB "popups", on by default): the game's confirmation boxes,
-- StaticPopup1 to StaticPopup4 (destroy an item, sell, Release Spirit, quit,
-- invites...), wear the 1.x dialog box: the tiled stone-grey fill and the
-- gold-cornered border, drawn on a frame of EraUI's own that sits behind the
-- pop-up's text and buttons. The game's own background underneath is faded
-- out each time a pop-up is dressed.
--
-- Buttons:
--   * Forever holds Button1-4 in the pop-up's ButtonContainer, plus one
--     ExtraButton. They keep the game's red dialog-button art; Dark Mode
--     (Core/Appearance.lua) only darkens them.
--   * A pop-up that holds its buttons itself (older clients) gives them
--     EraUI's classic red panel-button art (Core/ClassicWidgets.lua), which
--     joins Dark Mode by itself. The ExtraButton never takes that art.
--
-- The setting is read the way /era loads it, so a change waits for /reload,
-- and nothing is undressed within a session. EraUI writes no key on the
-- game's frames: which pop-ups have a box or a hook lives in weak tables
-- here. The only changes to the game's pop-ups are one OnShow post-hook each
-- and the alpha or colour of their own pieces.
local _, EraUI = ...
local Look = EraUI.Look

local Popups = {}
local NAME = "ClassicPanels" -- the module's registry name; also the owner the classic buttons report

local HOW_MANY = 4
-- The game's own background and border, under whichever key this client uses
-- (Forever: BG, a frame holding the two halves of its dark diamond box).
local GAME_BACKING = Look.Words("NineSlice Bg BG Background Border TopTileStreaks")
local BUTTON_KEYS = Look.Words("button1 button2 button3 button4 Button1 Button2 Button3 Button4")

-- The 1.x dialog box: stone fill and gold-cornered edge (32 wide, 8 in).
local DIALOG_ART = "Interface\\DialogFrame\\"
local STONE_FILL, GOLD_DIALOG_BORDER = DIALOG_ART .. "UI-DialogBox-Background", DIALOG_ART .. "UI-DialogBox-Border"
local CORNER, TILE, INNER = 32, 32, 8

local boxOf = Look.Weak()    -- pop-up: EraUI's box behind it
local hookedOn = Look.Weak() -- pop-up: true once its OnShow post-hook is in
local passRunning = false    -- a pop-up shown during a pass starts no other
local listener

-- Present, and not one of the game's forbidden frames.
local function Reachable(frame)
    if type(frame) ~= "table" then return false end
    local asked, forbidden = Look.Ask(frame, "IsForbidden")
    return not (asked and forbidden)
end

local function SkinWanted()
    return EraUI:GetSetting("popups") and true or false
end

---------------------------------------------------------------------------
-- The box
---------------------------------------------------------------------------

-- Made once per pop-up: a child filling it, at the pop-up's own frame level,
-- its art on the backdrop's background layers, so the pop-up's text and
-- buttons draw over it. No mouse: clicks reach the pop-up as before. No key
-- of any kind is set on it either (the pop-up's layout code walks its
-- children and reads theirs).
local function BuildBox(popup)
    local level = Look.Number(popup:GetFrameLevel()) or 1
    local box = Look.Build("Frame", popup, "BackdropTemplate", { level = level })
    Look.Fill(box, popup)
    box:EnableMouse(false)
    local edges = { left = INNER, right = INNER, top = INNER, bottom = INNER }
    box:SetBackdrop({ bgFile = STONE_FILL, tile = true, tileSize = TILE, edgeFile = GOLD_DIALOG_BORDER, edgeSize = CORNER, insets = edges })
    box:SetBackdropColor(1, 1, 1, 1)
    -- Dark Mode's Dark Windows (its tick and the Darkness slider) take the
    -- box from here, live; without Dark Mode the helper does nothing.
    local ns = EraUI.Classic
    if ns and ns.DarkBackdrop then ns.DarkBackdrop(box) end
    boxOf[popup] = box
    return box
end

-- The game's own backing, faded out (the game may show it again: each pass
-- fades it once more).
local function HideGameBacking(popup)
    for _, key in ipairs(GAME_BACKING) do
        local piece = popup[key]
        if type(piece) == "table" and type(piece.SetAlpha) == "function" and Look.Number(piece:GetAlpha()) ~= 0 then
            Look.Fade(piece)
        end
    end
end

---------------------------------------------------------------------------
-- The buttons
---------------------------------------------------------------------------

-- The buttons a pop-up holds itself: its Buttons list when it has no
-- ButtonContainer, and any button1-4 / Button1-4 kept straight on it. Each
-- once, never the ExtraButton.
local function OwnButtons(popup)
    local list, already = {}, {}
    local function Take(button)
        if type(button) == "table" and button ~= popup.ExtraButton and not already[button] then
            already[button] = true
            list[#list + 1] = button
        end
    end
    if popup.ButtonContainer == nil and type(popup.Buttons) == "table" then
        for _, button in ipairs(popup.Buttons) do Take(button) end
    end
    for _, key in ipairs(BUTTON_KEYS) do Take(popup[key]) end
    return list
end

local function DressButtons(popup)
    for _, button in ipairs(OwnButtons(popup)) do
        if Reachable(button) then EraUI:SkinClassicRedButton(button, NAME) end
    end
    -- Forever's own buttons keep the game's dialog art; Dark Mode only
    -- darkens them (it skips everything without Dark Mode).
    local ns = EraUI.Classic
    local darken = ns and ns.DarkRedButton
    if type(darken) ~= "function" then return end
    local holder = popup.ButtonContainer
    if Reachable(holder) and type(holder.Buttons) == "table" then
        for _, button in ipairs(holder.Buttons) do
            if Reachable(button) then darken(button) end
        end
    end
    if Reachable(popup.ExtraButton) then darken(popup.ExtraButton) end
end

---------------------------------------------------------------------------
-- One pop-up, then all four
---------------------------------------------------------------------------

-- A pass over all four, from the pop-ups' OnShow and the module's events.
local function PassAgain()
    Popups:Refresh()
end

local function Dress(popup)
    if not Reachable(popup) then return end
    local box = boxOf[popup] or BuildBox(popup)
    box:Show()
    HideGameBacking(popup)
    DressButtons(popup)
    -- Dressed again each time it opens (after the game's own OnShow).
    if not hookedOn[popup] then
        hookedOn[popup] = true
        popup:HookScript("OnShow", PassAgain)
    end
end

-- Each pop-up on its own: one that errors never stops the others, and the
-- pass always ends.
function Popups:Refresh()
    if passRunning or not SkinWanted() then return end
    passRunning = true
    for index = 1, HOW_MANY do
        local popup = _G["StaticPopup" .. index]
        if popup ~= nil then Look.Try(Dress, popup) end
    end
    passRunning = false
end

-- At login (Core/Init.lua, PLAYER_LOGIN, with EraUI on): a pass now, and
-- again as other addons load and on each loading screen. The setting can't
-- come on later in the session, so with it off nothing is made at all.
function Popups:Initialize()
    if not SkinWanted() then return end
    if not listener then
        listener = CreateFrame("Frame")
        listener:RegisterEvent("ADDON_LOADED")
        listener:RegisterEvent("PLAYER_ENTERING_WORLD")
        listener:SetScript("OnEvent", PassAgain)
    end
    self:Refresh()
end

EraUI:RegisterModule(NAME, Popups)
