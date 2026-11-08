local _, EraUI = ...

-- Hide Zzz in Cities (/era > Frames & Nameplates > Unit Frames; off by
-- default; seen in game 2026-11-07). In a capital city you rest the whole time, and the
-- resting "Zzz" covers the level on your player frame. With this on, while
-- you are in a capital your level shows instead:
--   * on EraUI's 1.x player frame the rest icon gives way to the level
--     (Look/UnitPlayer.lua asks Rest:Hides() in its keepers);
--   * on the game's own player frame its Zzz picture fades out (its alpha
--     only, put back to 1 when you leave or switch this off).
-- A capital: the map the game puts you on, or one of its parents, is a
-- capital's map, or the zone's name is a capital's own map name (for a client
-- whose maps number differently). It is checked again as you change zone or
-- start or stop resting, and kept, so the keepers never ask the map.
-- Only cosmetic: one post-hook on the game's rest picture function and
-- SetAlpha on its texture. Nothing of the game's is written on.
local Rest = {inCapital = false}
EraUI:RegisterModule("RestInCities", Rest)

-- The capitals' world maps on this client: Stormwind City, Orgrimmar,
-- Ironforge, Thunder Bluff, Darnassus and Undercity.
local CAPITALS = {[1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true}
Rest.CAPITALS = CAPITALS
local EVENTS = {"PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_UPDATE_RESTING"}

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end

local function MapInfo(id)
    local maps = C_Map
    if not (maps and maps.GetMapInfo) then return nil end
    local ok, info = pcall(maps.GetMapInfo, id)
    if ok and type(info) == "table" then return info end
end

-- True on a capital's map or a map inside one, false elsewhere, nil when the
-- game gives no map.
local function ByMap()
    local maps = C_Map
    if not (maps and maps.GetBestMapForUnit) then return nil end
    local ok, id = pcall(maps.GetBestMapForUnit, "player")
    if not ok or not Public(id) or type(id) ~= "number" then return nil end
    for _ = 1, 10 do
        if CAPITALS[id] then return true end
        local info = MapInfo(id)
        local parent = info and info.parentMapID
        if not Public(parent) or type(parent) ~= "number" or parent == 0 or parent == id then break end
        id = parent
    end
    return false
end

-- The zone's name against the capitals' own map names.
local function ByName()
    local zone = GetRealZoneText and GetRealZoneText()
    if not Public(zone) or type(zone) ~= "string" or zone == "" then return false end
    for id in pairs(CAPITALS) do
        local info = MapInfo(id)
        local name = info and info.name
        if Public(name) and type(name) == "string" and name == zone then return true end
    end
    return false
end

function Rest.InCapital()
    return ByMap() == true or ByName()
end

function Rest:On()
    return EraUI:GetSetting("enabled") ~= false and EraUI:GetSetting("hideRestInCities") == true
end

-- Whether the level shows instead of the rest icon now (Look/UnitPlayer.lua).
function Rest:Hides()
    return self.active == true and self.inCapital == true
end

-- The game's own rest picture on its player frame, or nil.
local function GameRest()
    local frame = PlayerFrame
    local content = type(frame) == "table" and frame.PlayerFrameContent
    local contextual = type(content) == "table" and content.PlayerFrameContentContextual
    local loop = type(contextual) == "table" and contextual.PlayerRestLoop
    local texture = type(loop) == "table" and loop.RestTexture
    if type(texture) == "table" and texture.SetAlpha then return texture end
end

-- Fades the game's Zzz in a capital, or puts back only what this faded.
function Rest:Apply()
    local texture = GameRest()
    if texture then
        if self:Hides() then
            texture:SetAlpha(0)
            self.faded = true
        elseif self.faded then
            texture:SetAlpha(1)
            self.faded = false
        end
    end
    -- EraUI's 1.x player frame follows at once (its keepers ask Hides).
    local look = EraUI.Look
    local UF = look and look.UF
    if UF and UF.KeepPlayerState then pcall(UF.KeepPlayerState) end
end

function Rest:Update()
    self.inCapital = Rest.InCapital() == true
    self:Apply()
end

-- After the game shows or hides its Zzz.
local function Hook()
    if Rest.hooked or type(PlayerFrame_UpdatePlayerRestLoop) ~= "function" then return end
    Rest.hooked = true
    hooksecurefunc("PlayerFrame_UpdatePlayerRestLoop", function()
        if Rest.active or Rest.faded then Rest:Apply() end
    end)
end

-- Follows the option.
function Rest:Refresh()
    local want = self:On()
    if want ~= (self.active == true) then
        if not self.frame then
            self.frame = CreateFrame("Frame")
            self.frame:SetScript("OnEvent", function() Rest:Update() end)
        end
        for _, event in ipairs(EVENTS) do
            if want then pcall(self.frame.RegisterEvent, self.frame, event) else pcall(self.frame.UnregisterEvent, self.frame, event) end
        end
        self.active = want
    end
    if want then Hook() end
    self:Update()
end

function Rest:Initialize()
    self:Refresh()
end
