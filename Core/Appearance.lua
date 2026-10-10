local _, EraUI = ...
local ns = EraUI.Classic
local decorative = {}
for key in ("questLogTopLeft questLogTopRight questLogBotLeft questLogBotRight questLogDualLeft questLogDualRight questLogEmptyTopLeft questLogEmptyTopRight questLogEmptyBotLeft questLogEmptyBotRight questLogTabLeft questLogTabMiddle questLogTabRight endCap barBody barKeyring maxLevel slotEmpty slotNormal targetingFrame targetingElite targetingRare targetingRareElite targetingMinus targetOfTarget smallTargetingFrame levelBackground castBorder castBorderSmall minimapBorder minimapBackground trackingBorder nameplateBorder frameMetal frameMetalH frameMetalV frameSheet marbleBg rockBg tabActive tabInactive optionsTabActive optionsTabInactive scrollKnob charScrollBar lootPanel merchantBottom merchantLabelSlots bagComponents backpackBg bankFloor skillsBarBorder charGeneralTopLeft charGeneralTopRight charGeneralBotLeft charGeneralBotRight"
    -- Added with the Darkness slider: the minimap's ring, zoom buttons and
    -- clock, the reputation bar's frame and the latency bar. Frame art only;
    -- icons (bags, micro menu) keep their colours.
    .." compassRing zoomInUp zoomInDown zoomInDisabled zoomOutUp zoomOutDown zoomOutDisabled clockBackground repBar performanceBar"):gmatch("%S+") do decorative[key]=true end

-- Darkness: 40 (light grey) to 90 (near black); 58 is the original Dark Mode
-- grey (.42, .44, .48). The slight blue of that grey is kept at every step.
ns.DARKNESS_MIN, ns.DARKNESS_MAX, ns.DARKNESS_DEFAULT = 40, 90, 58
function ns.DarkGrey()
    local d = tonumber(EraUI:GetSetting("darkModeDarkness")) or ns.DARKNESS_DEFAULT
    d = math.max(ns.DARKNESS_MIN, math.min(ns.DARKNESS_MAX, d))
    local v = 1 - d / 100
    return v, math.min(1, v * 44 / 42), math.min(1, v * 48 / 42)
end

-- Textures given the dark grey, so the slider can re-tint them live. Weak
-- keys: a texture the game lets go of drops out by itself.
local tinted = setmetatable({}, { __mode = "k" })
-- Class-coloured borders and their full class colour, for "Darken class
-- colours too" (off unless ticked).
local classTinted = setmetatable({}, { __mode = "k" })

-- How much darker than the original grey the slider is: 1 at 58 (or less),
-- down to about a quarter at 90. Class colours are multiplied by it.
local function ClassShade()
    if not EraUI:GetSetting("darkenClassColours") then return 1 end
    return math.min(1, (ns.DarkGrey()) / .42)
end

local function PaintClass(texture, r, g, b)
    local f = ClassShade()
    texture:SetVertexColor(r * f, g * f, b * f)
end

-- Texture-only, called by EraUI's existing artwork application. No scanning,
-- native setter hooks, timers, geometry changes, or protected value reads.
function ns.ThemeTexture(texture,key)
    if not texture or not EraUI:GetSetting("darkMode") or not decorative[key] then return end
    local borderUnit
    local owner=texture
    while owner do
        if owner==CharacterFrame or owner==PartyFrame or owner==CompactRaidFrameContainer then return end
        if owner==PlayerFrame then borderUnit="player"
        elseif owner==TargetFrame then borderUnit="target"
        elseif owner==FocusFrame then borderUnit="focus" end
        local name=owner.GetName and owner:GetName()
        if name and (name:match("^PartyMemberFrame") or name:match("^CompactParty") or name:match("^CompactRaid") or name:match("^RaidFrame")) then return end
        owner=owner.GetParent and owner:GetParent()
    end
    -- Normal frame shell only: leave rare/elite classification art and all
    -- fills, icons, flash/status textures under their existing ownership.
    local isPlayer=borderUnit and UnitIsPlayer(borderUnit)
    if issecretvalue and issecretvalue(isPlayer) then isPlayer=false end
    if isPlayer and key=="targetingFrame" and EraUI:GetSetting("classColourBorders") then
        local _,class=UnitClass(borderUnit)
        if not (issecretvalue and issecretvalue(class)) then
            local colour=(CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])
                or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
            if class=="PALADIN" then colour={r=.96,g=.55,b=.73} end
            if colour then
                tinted[texture]=nil
                classTinted[texture]={colour.r,colour.g,colour.b}
                PaintClass(texture,colour.r,colour.g,colour.b);return
            end
        end
    end
    classTinted[texture]=nil
    tinted[texture]=true
    texture:SetVertexColor(ns.DarkGrey())
end

-- The Darkness slider and its class colour tick: re-tint what Dark Mode has
-- already tinted, at once.
function ns.RefreshDarkness()
    if not EraUI:GetSetting("darkMode") then return end
    local r, g, b = ns.DarkGrey()
    for texture in pairs(tinted) do texture:SetVertexColor(r, g, b) end
    for texture, c in pairs(classTinted) do PaintClass(texture, c[1], c[2], c[3]) end
    -- Dark Aura Borders' grey line and the tooltips' bevel darken with the
    -- slider too, and so do the menu bar's frames (Dark Menu Bar).
    local auras = EraUI.modules.AuraStyle
    if auras and auras.RefreshDarkness then auras:RefreshDarkness() end
    if ns.RefreshDarkMenuBar then ns.RefreshDarkMenuBar() end
end
