-- The Legacy window's frame in the 1.x look (registry "legacyWindow"): the
-- game's window at the 1.x spellbook's size (L.WIDE x L.TALL), the
-- spellbook's own four pieces under it at their own size, exactly as the
-- spellbook lays them (the grey stone frame, the round portrait ring, the
-- dark title strip, the stone band and the old parchment), Black Pages'
-- cover over the parchment, the game's crest in the ring on a dark disc, the
-- title light on its strip, the red X in the frame's corner box, and the
-- game's three page tabs as the spellbook's red-brown tabs along the foot.
-- The game's own frame art (nine-slice, rock, streaks, each page's
-- backdrop) is faded; its controls keep working, in front of EraUI's art.
--
-- Where the window opens is the game's own: its panel manager places it (51
-- from the left, 116 down) every time it or another panel opens, so EraUI
-- leaves that alone; the game never sizes it again, so its size holds.
local _, EraUI = ...
local Look = EraUI.Look
local L = Look.Legacy

---------------------------------------------------------------------------
-- The spellbook's pieces at their own size
---------------------------------------------------------------------------

-- The four pieces make a 384 x 512 sheet whose frame starts 15 in and 15
-- down: the sheet's top left is 15 out past the window's. The stretched cut
-- of the first build (the window 920 wide) drew the parchment's grain and
-- burnt edges out flat, which looked like the retail parchment; at their
-- own size they are the spellbook's page, light and dark bands and all.
local OUT = 15
-- Each piece: its name, art key, width (all 256 tall) and its top left on
-- the sheet.
local SHEET = { { "TopLeft", "sbTopLeft", 256, 0, 0 }, { "TopRight", "sbTopRight", 128, 256, 0 },
    { "BotLeft", "sbBotLeft", 256, 0, 256 }, { "BotRight", "sbBotRight", 128, 256, 256 } }

local function Shell(window)
    L.Size(window, L.WIDE, L.TALL)
    for _, part in ipairs(SHEET) do
        local piece = L.Own(window, "sheet" .. part[1], "BACKGROUND", -8)
        Look.Art(piece, part[2])
        Look.Crop(piece, 0, 1, 0, 1)
        piece:SetSize(part[3], 256)
        Look.Pin(piece, "TOPLEFT", window, "TOPLEFT", part[4] - OUT, OUT - part[5])
        L.Dark(piece, "trim")
    end
end

---------------------------------------------------------------------------
-- Black Pages' cover, the ring, the title and the red X
---------------------------------------------------------------------------

-- The parchment alone (L.PAGE: the sheet's 22 to 344 across, 75 to 431
-- down, where the spellbook's own cover goes).
local function Cover(window)
    local cover = L.Own(window, "cover", "BACKGROUND", -6, true)
    cover:ClearAllPoints()
    cover:SetPoint("TOPLEFT", window, "TOPLEFT", L.PAGE.left, -L.PAGE.top)
    cover:SetPoint("BOTTOMRIGHT", window, "TOPLEFT", L.PAGE.right, -L.PAGE.bottom)
    -- Forced: turning the look off hid it, and Dark Windows would otherwise
    -- think it still shows when the look comes back on.
    L.Dark(cover, "cover", true)
    L.cover = cover
end

-- The ring's middle: 24 in and 22 down from the window's corner.
local RING_X, RING_Y = 24, -22

local function Portrait(window)
    local disc = L.Own(window, "disc", "BACKGROUND", -7)
    Look.Art(disc, "legacyDisc")
    disc:SetVertexColor(L.DISC[1], L.DISC[2], L.DISC[3])
    disc:SetSize(56, 56)
    Look.Pin(disc, "CENTER", window, "TOPLEFT", RING_X, RING_Y)
    local holder = L.Field(window, "PortraitContainer")
    local face = holder and L.Field(holder, "portrait")
    if face then
        L.Size(face, 40, 55)
        L.Pin(face, "CENTER", window, "TOPLEFT", RING_X, RING_Y)
    end
end

local function Title(window)
    local holder = L.Field(window, "TitleContainer")
    if not holder then return end
    L.Pins(holder, { "TOPLEFT", window, "TOPLEFT", 58, 1 }, { "TOPRIGHT", window, "TOPRIGHT", -40, 1 })
    L.Paint(L.Field(holder, "TitleText"), L.LIGHT, true)
end

local function Close(window)
    local shut = L.Field(window, "CloseButton")
    if not shut then return end
    L.Size(shut, 32, 32)
    Look.SkinCloseButton(shut)
    L.Pin(shut, "CENTER", window, "TOPRIGHT", -11, -10)
end

-- The game's frame art, and each page's backdrop.
local PAGES = { "RewardTrackPage", "ChallengesPage", "TreePage" }
local function FadeChrome(window)
    L.Fade(L.Field(window, "NineSlice"))
    L.Fade(L.Field(window, "Bg"))
    L.Fade(L.Field(window, "TopTileStreaks"))
    for _, key in ipairs(PAGES) do
        local page = L.Field(window, key)
        if page then L.Fade(L.Field(page, "Background")) end
    end
end

---------------------------------------------------------------------------
-- The page tabs: the spellbook's along the foot
---------------------------------------------------------------------------

L.TAB_WORDS = { "Rewards", "Challenges", "Legacy Tree" }
local TAB_ART = { "tabOff", "tabOn", "tabGlow" }
local raised = L.Record(Look.Weak()) -- a tab: whether it was last drawn raised

local function DressTab(window, tabs, i)
    local tab = tabs[i]
    raised[tab] = nil
    for _, key in ipairs({ "Background", "Icon", "SelectedTexture", "HighlightTexture" }) do L.Fade(L.Field(tab, key)) end
    L.Hush(L.Field(tab, "TabGlow"))
    L.Size(tab, 100, 28)
    if i == 1 then
        L.Pin(tab, "TOPLEFT", window, "BOTTOMLEFT", 14, 2)
    else
        L.Pin(tab, "LEFT", tabs[i - 1], "RIGHT", 8, 0)
    end
    local off = L.Own(tab, "tabOff", "BACKGROUND", 0, true)
    Look.Art(off, "sbTabUnselected")
    local on = L.Own(tab, "tabOn", "BACKGROUND", 1, true)
    Look.Art(on, i == 3 and "sbTab3Selected" or "sbTab1Selected")
    local glow = L.Own(tab, "tabGlow", "HIGHLIGHT", 0)
    Look.Art(glow, "sbTabHighlight")
    glow:SetBlendMode("ADD")
    for _, piece in ipairs({ off, on, glow }) do
        piece:SetSize(128, 64)
        Look.Pin(piece, "TOPLEFT", tab, "TOPLEFT", -14, 16)
    end
    local label = L.Label(tab, "tabLabel", "GameFontNormalSmall", "OVERLAY")
    Look.Pin(label, "CENTER", tab, "CENTER", 0, 1)
    label:SetText(L.TAB_WORDS[i] or "")
end

-- Each tab raised while its page is the one shown (the game's own checked
-- state), its words white then and gold otherwise. Only EraUI's own art and
-- words change, so this is done in a fight too.
function L.TabsFollow(window)
    local tabs = L.Field(window, "Tabs")
    if type(tabs) ~= "table" then return end
    for _, tab in ipairs(tabs) do
        local chosen = L.IsShown(L.Field(tab, "SelectedTexture"))
        local on, off = Look.OwnPiece(tab, "legacy." .. TAB_ART[2]), Look.OwnPiece(tab, "legacy." .. TAB_ART[1])
        if on and off and raised[tab] ~= chosen then
            raised[tab] = chosen
            Look.Shown(on, chosen)
            Look.Shown(off, not chosen)
            local label = Look.OwnPiece(tab, "legacy.tabLabel")
            local font = chosen and GameFontHighlightSmall or GameFontNormalSmall
            if label and font then label:SetFontObject(font) end
        end
    end
end

local function Tabs(window)
    local tabs = L.Field(window, "Tabs")
    if type(tabs) ~= "table" then return end
    for i = 1, #tabs do Look.Try(DressTab, window, tabs, i) end
    L.TabsFollow(window)
    -- EraUI's own tab art only, so a page chosen in a fight raises its tab.
    L.AfterOwn(window, "SelectPage", function(self) L.TabsFollow(self) end)
end

---------------------------------------------------------------------------
-- The whole frame, in order
---------------------------------------------------------------------------

function L.DressShell(window)
    for _, step in ipairs({ FadeChrome, Shell, Cover, Portrait, Title, Close, Tabs }) do Look.Try(step, window) end
end
