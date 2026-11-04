local _, EraUI = ...

-- Remember Minimap Zoom (/era > Map & Minimap; off by default, experimental).
-- The game forgets how far the minimap is zoomed every time you log in: its
-- own UI only zooms from the + and - buttons (the mouse wheel and the zoom
-- keys press them too) and saves nothing. The minimap keeps two zooms, one
-- for indoors and one for outdoors, and swaps between them as you go in and
-- out. While this option is on, EraUI keeps each zoom you leave it at, for
-- this character (EraUIClassicCharDB.minimapZoom, backed up with the rest of
-- the character's data by Core/Persistence.lua), and puts it back once a
-- loading screen is over (logging in, a /reload) and the first time after
-- that you go indoors or outdoors.
-- Your own zooming always wins: a place (indoors or outdoors) you have
-- zoomed in is never put back over, and a change nobody clicked counts as
-- yours too (another addon's), except in the first
-- seconds after a loading screen, while the game may still be setting its
-- own. Off, nothing is listened to and nothing is touched. Only reads and
-- Minimap:SetZoom (not a protected call) are used on the game's minimap; a
-- post-hook on its two zoom buttons' clicks is the only hook, made the first
-- time the option is on; no key is written on the game's frames.
local Zoom = {}
EraUI:RegisterModule("MinimapZoom", Zoom)

-- Seconds after a loading screen in which a zoom change nobody clicked is the
-- game's own (it set its default, or swapped indoors and outdoors late).
local SETTLE = 3
local EVENTS = {"PLAYER_LEAVING_WORLD", "PLAYER_ENTERING_WORLD", "MINIMAP_UPDATE_ZOOM"}

-- A plain finite number from the game, or nil.
local function Plain(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

-- One of the minimap's own readers (GetZoom, GetZoomLevels), asked safely.
local function Read(method)
    local map = _G.Minimap
    local reader = map and map[method]
    if type(reader) ~= "function" then return nil end
    local ok, value = pcall(reader, map)
    if not ok then return nil end
    return Plain(value)
end

-- "indoor" or "outdoor", which of its two zooms the minimap shows; nil when
-- the game won't say.
local function Place()
    if type(IsIndoors) ~= "function" then return nil end
    local ok, inside = pcall(IsIndoors)
    if not ok or (issecretvalue and issecretvalue(inside)) then return nil end
    return inside and "indoor" or "outdoor"
end

local function Now()
    return type(GetTime) == "function" and GetTime() or 0
end

-- This character's kept zooms, {outdoor = n, indoor = n}; made on demand.
local function Kept(make)
    local char = EraUIClassicCharDB
    if type(char) ~= "table" then
        if not make then return nil end
        char = {}
        EraUIClassicCharDB = char
    end
    local kept = char.minimapZoom
    if type(kept) ~= "table" then
        if not make then return nil end
        kept = {}
        char.minimapZoom = kept
    end
    return kept
end

-- A kept zoom as a level the minimap has now: whole, 0 to its last level.
local function Fit(value)
    value = Plain(value)
    local levels = Read("GetZoomLevels")
    if not value or not levels or levels < 1 then return nil end
    local top = math.floor(levels) - 1
    value = math.floor(value + .5)
    if value < 0 then return 0 end
    if value > top then return top end
    return value
end

function Zoom:On()
    return EraUI:GetSetting("enabled") ~= false and EraUI:GetSetting("rememberMinimapZoom") == true
end

-- Keeps the zoom you're looking at for this place.
function Zoom:Keep(place, level)
    local kept = Kept(true)
    if kept[place] == level then return end
    kept[place] = level
    if EraUI.SaveSettings then EraUI:SaveSettings() end
end

-- Puts this place's kept zoom back. Returns the minimap's zoom after. The
-- place is done with, unless the minimap can't say yet how many levels it
-- has (the next look tries again).
function Zoom:PutBack(place, level)
    local kept = Kept(false)
    local value = kept and Plain(kept[place])
    local want = Fit(value)
    if value ~= nil and want == nil then return level end
    self.done[place] = true
    if want == nil or want == level then return level end
    local map = _G.Minimap
    if not (map and type(map.SetZoom) == "function") then return level end
    self.busy = true
    pcall(map.SetZoom, map, want)
    self.busy = false
    return Read("GetZoom") or level
end

-- A look at the minimap. clicked: you just pressed + or - (or the mouse
-- wheel or a zoom key, which press them).
function Zoom:Look(clicked)
    if not self.active or not self.ready or self.busy then return end
    local place, level = Place(), Read("GetZoom")
    if not place or not level then return end
    -- moved: the game swapped between indoors and outdoors (or this is the
    -- first look since a loading screen), so that place's own zoom shows.
    local moved = place ~= self.place
    local changed = not moved and level ~= self.level
    self.place = place
    if clicked then
        -- Yours: kept, and never put back over.
        self.done[place] = true
        self.level = level
        self:Keep(place, level)
    elseif not self.done[place] or (changed and Now() < (self.settleUntil or 0)) then
        -- The place's first showing since a loading screen, or the game
        -- setting its own zoom in the seconds after one: the kept one goes back.
        self.level = self:PutBack(place, level)
    elseif changed then
        -- Nobody clicked, later on (another addon): kept as yours too.
        self.level = level
        self:Keep(place, level)
    else
        self.level = level
    end
end

-- A loading screen starts (a portal, an instance, logging out): until it's
-- over, a zoom change is the game's own while the world loads, never yours.
function Zoom:Leave()
    self.ready = false
end

-- A loading screen is over (logging in, a /reload, a portal): each place's
-- kept zoom goes back the next time the minimap shows it.
function Zoom:Settle()
    self.done = {}
    self.place, self.level = nil, nil
    self.ready = true
    self.settleUntil = Now() + SETTLE
    self:Look(false)
end

-- Switched on in play: it starts from the zoom you have now. Zooms kept
-- before it was last switched off are forgotten.
function Zoom:StartHere()
    local char = EraUIClassicCharDB
    if type(char) == "table" then char.minimapZoom = nil end
    self.done = {}
    self.place, self.level = nil, nil
    self.ready, self.settleUntil = true, 0
    local place, level = Place(), Read("GetZoom")
    if not place or not level then return end
    self.place, self.level = place, level
    self.done[place] = true
    self:Keep(place, level)
end

local function Clicked()
    Zoom:Look(true)
end

-- The game's + and - buttons, post-hooked once, the first time it's on.
function Zoom:HookButtons()
    if self.hooked then return end
    self.hooked = true
    local map = _G.Minimap
    if not map then return end
    for _, key in ipairs({"ZoomIn", "ZoomOut"}) do
        local button = map[key]
        if button and type(button.HookScript) == "function" then
            pcall(button.HookScript, button, "OnClick", Clicked)
        end
    end
end

local function OnEvent(_, event)
    if event == "PLAYER_ENTERING_WORLD" then Zoom:Settle()
    elseif event == "PLAYER_LEAVING_WORLD" then Zoom:Leave()
    else Zoom:Look(false) end
end

-- Follows the option. atLogin: the first call, before the loading screen
-- ends; later calls are the /era switch.
function Zoom:Refresh(atLogin)
    local want = self:On() and _G.Minimap ~= nil
    if want == (self.active == true) then return end
    if not want then
        self.active, self.ready = false, false
        if self.frame then
            for _, event in ipairs(EVENTS) do self.frame:UnregisterEvent(event) end
        end
        return
    end
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", OnEvent)
    end
    self.active = true
    self:HookButtons()
    for _, event in ipairs(EVENTS) do self.frame:RegisterEvent(event) end
    if atLogin then
        -- The loading screen's end (PLAYER_ENTERING_WORLD) puts them back.
        self.done, self.ready = {}, false
    else
        self:StartHere()
    end
end

function Zoom:Initialize()
    self.done, self.settleUntil = {}, 0
    self:Refresh(true)
end
