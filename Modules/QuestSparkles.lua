local _, EraUI = ...

-- Quest Item Sparkles and Herb and Ore Sparkles (/era > Quests; off by default,
-- experimental). Quest items: the game can already make these sparkle. With its
-- Outline Mode off it replaces passive outlines with loot sparkles (its own help
-- text, outlineModeShowLootEffectWhenDisabled). The cost, said in /era: the
-- game's outlines are off meanwhile. Herbs and ore: the game has no sparkle for
-- these, but its soft targeting picks the nearest thing you can interact with
-- as you walk up and floats its icon there. While that's a herb or ore vein
-- (by name, so English clients only for now) the game's name plate for it is
-- turned on, and EraUI's own glints are placed on that plate: one node at a
-- time. Only the addon's own frame is drawn; no key goes on the game's frames.
-- Each value you had is kept the first time it's changed (EraUIDB.sparkleKept)
-- and goes back when its option is turned off, not to the game's default. While
-- on, a change from elsewhere (a graphics preset) is put right; in a fight
-- settings wait for the end. Off with nothing kept, nothing is listened to and
-- nothing is touched.
local Sparkles = {}
EraUI:RegisterModule("QuestSparkles", Sparkles)

-- For the game's own sparkle on quest items.
local OUTLINES = {outlineModeShowLootEffectWhenDisabled = "1", graphicsOutlineMode = "0", OutlineEngineMode = "0"}
-- For herbs and ore: the nearest one is picked out, with its icon, from as far
-- as the game will. Asking for 100 is taken, but the game still won't pick a
-- herb from further than about 15 to 20 yards (seen in game, 4 Nov 2026).
local NODES = {SoftTargetInteract = "3", SoftTargetIconGameObject = "1", SoftTargetIconInteract = "1",
    SoftTargetInteractArc = "2", SoftTargetInteractRange = "100", SoftTargetInteractOnlyInRange = "0",
    SoftTargetLowPriorityIcons = "1", nameplateGameObjectMaxDistance = "100"}

-- Herbs by name (Forever has others, like Wilted Peacebloom, so part of a name
-- counts). Ore: anything ending Vein or Deposit, or an Ooze Covered one.
local HERBS = {"Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed",
    "Wild Steelbloom", "Grave Moss", "Kingsblood", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker",
    "Wintersbite", "Firebloom", "Purple Lotus", "Arthas' Tears", "Sungrass", "Blindweed", "Ghost Mushroom",
    "Gromsblood", "Golden Sansam", "Dreamfoil", "Mountain Silversage", "Plaguebloom", "Icecap", "Black Lotus"}

local UNIT = "softinteract"
local GLINT_ART = "Interface\\Cooldown\\star4" -- the star the mini-games' sparks use
local GLINT_COLOUR = {1, .84, .35}
-- Where each glint sits round the middle, its size, and how fast and when it twinkles.
local GLINTS = {
    {-20, 8, 22, 3.1, 0}, {16, 18, 16, 2.3, 1.3}, {24, -10, 20, 2.8, 2.6},
    {-8, -18, 16, 3.6, 3.9}, {2, 2, 26, 2, 5.1}, {-26, -8, 14, 3.3, 4.4},
}
local GLINT_DROP = -44 -- from the name plate, which floats above the node, down to it
local LOOK_EVERY = .1  -- seconds between looks for the plate, only while there's a node

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end

-- Whether a thing's name is a herb or an ore vein.
function Sparkles.IsNodeName(name)
    if type(name) ~= "string" then return false end
    if name:find(" Vein$") or name:find(" Deposit$") or name:find("^Ooze Covered ") then return true end
    for _, herb in ipairs(HERBS) do
        if name:find(herb, 1, true) then return true end
    end
    return false
end

-- Whether the game's soft target now is a herb or ore node. Objects only, so an
-- NPC with the same name isn't one, nor is anything the game won't say about.
local function NodeNear()
    if type(UnitGUID) ~= "function" or type(UnitName) ~= "function" then return false end
    local okGuid, guid = pcall(UnitGUID, UNIT)
    if not okGuid or not Public(guid) or type(guid) ~= "string" or not guid:find("^GameObject") then return false end
    local okName, name = pcall(UnitName, UNIT)
    return okName and Public(name) and Sparkles.IsNodeName(name)
end

-- The game's name plate for the soft target, or nil.
local function NodePlate()
    local get = C_NamePlate and C_NamePlate.GetNamePlateForUnit
    if type(get) ~= "function" then return nil end
    local ok, plate = pcall(get, UNIT)
    if ok and Public(plate) then return plate end
end

-- A setting's value as text, or nil when the game won't say.
local function Read(name)
    local get = C_CVar and C_CVar.GetCVar
    if type(get) ~= "function" then return nil end
    local ok, value = pcall(get, name)
    if not ok or not Public(value) or type(value) ~= "string" then return nil end
    return value
end

-- The same value? (A range can read back as "30.000000".)
local function Same(a, b)
    return a == b or (tonumber(a) ~= nil and tonumber(a) == tonumber(b))
end

-- The values you had, made on demand.
local function Kept(make)
    if type(EraUIDB) ~= "table" then
        if not make then return nil end
        EraUIDB = {}
    end
    local kept = EraUIDB.sparkleKept
    if type(kept) ~= "table" then
        if not make then return nil end
        kept = {}
        EraUIDB.sparkleKept = kept
    end
    return kept
end

-- The settings the options ask for now.
function Sparkles:Wanted()
    local want = {}
    if EraUI:GetSetting("enabled") == false then return want end
    if EraUI:GetSetting("questSparkles") == true then
        for name, value in pairs(OUTLINES) do want[name] = value end
    end
    if EraUI:GetSetting("gatherSparkles") == true then
        for name, value in pairs(NODES) do want[name] = value end
        -- The plate the glints sit on, only while there's a node: other things
        -- you can use nearby get no name floating over them.
        want.SoftTargetNameplateInteract = self.near and "1" or "0"
    end
    return want
end

local function Write(name, value)
    if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, name, value) end
end

local refused = {}

-- Sets what's wanted and puts back what no longer is. Out of a fight: in one,
-- it waits for the end.
function Sparkles:Apply()
    if InCombatLockdown() then
        self:Frame():RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if self.frame then self.frame:UnregisterEvent("PLAYER_REGEN_ENABLED") end
    local want = self:Wanted()
    local kept = Kept(next(want) ~= nil)
    self.busy = true
    for name, value in pairs(want) do
        local now = Read(name)
        if now ~= nil and not Same(now, value) and not refused[name] then
            if kept[name] == nil then kept[name] = now end
            Write(name, value)
            -- A number the game caps lower reads back as its cap: that's as
            -- far as it goes, so it isn't asked again and again.
            if not Same(Read(name), value) then refused[name] = true end
        end
    end
    if kept then
        for name, old in pairs(kept) do
            if want[name] == nil then
                Write(name, old)
                kept[name] = nil
            end
        end
        if next(kept) == nil then EraUIDB.sparkleKept = nil end
    end
    self.busy = false
    if EraUI.SaveSettings then EraUI:SaveSettings() end
end

-- A setting changed from elsewhere: looked at on the next frame, once.
function Sparkles:Changed(name)
    if self.busy or self.looking or not Public(name) or type(name) ~= "string" then return end
    local lower = name:lower()
    for wanted in pairs(self:Wanted()) do
        if wanted:lower() == lower then
            self.looking = true
            C_Timer.After(0, function()
                self.looking = false
                self:Apply()
            end)
            return
        end
    end
end

-- The glints: one frame of the addon's own, made the first time they're wanted.
-- Only looks for the plate and twinkles while it's shown.
function Sparkles:GlintFrame()
    if self.glints then return self.glints end
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(72, 72)
    frame:SetFrameStrata("LOW")
    frame:Hide()
    frame.stars = {}
    for index, glint in ipairs(GLINTS) do
        local star = frame:CreateTexture(nil, "OVERLAY")
        star:SetTexture(GLINT_ART)
        star:SetBlendMode("ADD")
        star:SetVertexColor(GLINT_COLOUR[1], GLINT_COLOUR[2], GLINT_COLOUR[3])
        star:SetSize(glint[3], glint[3])
        star:SetPoint("CENTER", frame, "CENTER", glint[1], glint[2])
        star:SetAlpha(0)
        frame.stars[index] = star
    end
    local clock, waited = 0, LOOK_EVERY
    frame:SetScript("OnUpdate", function(_, elapsed)
        elapsed = elapsed or 0
        clock, waited = clock + elapsed, waited + elapsed
        if waited >= LOOK_EVERY then
            waited = 0
            Sparkles:PlaceGlints()
        end
        for index, glint in ipairs(GLINTS) do
            frame.stars[index]:SetAlpha(math.max(0, math.sin(clock * glint[4] + glint[5])))
        end
    end)
    self.glints = frame
    return frame
end

-- On the plate when it's there (it comes a moment after the setting changes).
-- With no plate they're placed nowhere, which draws nothing.
function Sparkles:PlaceGlints()
    local frame = self.glints
    if not frame then return end
    local plate = NodePlate()
    if plate == self.onPlate then return end
    self.onPlate = plate
    frame:ClearAllPoints()
    if plate then frame:SetPoint("CENTER", plate, "CENTER", 0, GLINT_DROP) end
end

-- The soft target changed: glints on a herb or ore, and off anything else. Each
-- change starts from no plate, so they never linger where the last node was.
function Sparkles:Target()
    local near = EraUI:GetSetting("enabled") ~= false and EraUI:GetSetting("gatherSparkles") == true and NodeNear()
    near = near == true
    if near ~= (self.near == true) then
        self.near = near
        self:Apply()
    end
    if self.glints then
        self.glints:ClearAllPoints()
        self.onPlate = nil
    end
    if near then
        self:GlintFrame():Show()
        self:PlaceGlints()
    elseif self.glints then
        self.glints:Hide()
    end
end

local function OnEvent(_, event, name)
    if event == "CVAR_UPDATE" then
        Sparkles:Changed(name)
    elseif event == "PLAYER_SOFT_INTERACT_CHANGED" then
        Sparkles:Target()
    else
        Sparkles:Apply()
    end
end

function Sparkles:Frame()
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", OnEvent)
    end
    return self.frame
end

-- Follows the options.
function Sparkles:Refresh()
    local on = next(self:Wanted()) ~= nil
    if on then
        local frame = self:Frame()
        frame:RegisterEvent("CVAR_UPDATE")
        -- (The game may still be setting its graphics up as you log in.)
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    elseif self.frame then
        self.frame:UnregisterEvent("CVAR_UPDATE")
        self.frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
    -- Herbs and ore: the soft target heard (each event the game lacks is left out).
    if EraUI:GetSetting("enabled") ~= false and EraUI:GetSetting("gatherSparkles") == true then
        pcall(self:Frame().RegisterEvent, self.frame, "PLAYER_SOFT_INTERACT_CHANGED")
    elseif self.frame then
        pcall(self.frame.UnregisterEvent, self.frame, "PLAYER_SOFT_INTERACT_CHANGED")
    end
    self:Target()
    self:Apply()
end

function Sparkles:Initialize()
    self:Refresh()
end
