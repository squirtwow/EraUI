local _, EraUI = ...
local ns = EraUI.Classic
local decorative = {}
for key in ("questLogTopLeft questLogTopRight questLogBotLeft questLogBotRight questLogDualLeft questLogDualRight questLogEmptyTopLeft questLogEmptyTopRight questLogEmptyBotLeft questLogEmptyBotRight questLogTabLeft questLogTabMiddle questLogTabRight endCap barBody barKeyring maxLevel slotEmpty slotNormal targetingFrame targetingElite targetingRare targetingRareElite targetingMinus targetOfTarget smallTargetingFrame levelBackground castBorder castBorderSmall minimapBorder minimapBackground trackingBorder nameplateBorder frameMetal frameMetalH frameMetalV frameSheet marbleBg rockBg tabActive tabInactive optionsTabActive optionsTabInactive scrollKnob charScrollBar lootPanel merchantBottom merchantLabelSlots bagComponents backpackBg bankFloor skillsBarBorder charGeneralTopLeft charGeneralTopRight charGeneralBotLeft charGeneralBotRight"):gmatch("%S+") do decorative[key]=true end
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
        if issecretvalue and issecretvalue(class) then texture:SetVertexColor(.42,.44,.48);return end
        if class=="PALADIN" then texture:SetVertexColor(.96,.55,.73);return end
        local colour=(CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])
            or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
        if colour then texture:SetVertexColor(colour.r,colour.g,colour.b);return end
    end
    texture:SetVertexColor(.42,.44,.48)
end

