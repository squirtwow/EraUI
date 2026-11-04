local _, EraUI = ...

-- Logical keys are independent of widget types. Future entries may describe
-- arrows, window sheets, borders or fills using the same path/texCoord format.
local assets = {}
EraUI.classicAssetResults = {}

function EraUI:RegisterClassicAsset(key, definition)
    assert(type(key) == "string" and not assets[key], "Duplicate or invalid Classic asset key")
    assert(type(definition) == "table" and type(definition.path) == "string", "Classic asset needs a path")
    assets[key] = definition
end

-- Stage 2A: only artwork used by the Character family.
-- Item state textures/colours remain owned by the native item buttons.

function EraUI:GetClassicTexture(key)
    local definition = assets[key]
    if not definition then return nil end
    return definition.path, definition
end

function EraUI:SetClassicTexture(texture, key)
    local path, definition = self:GetClassicTexture(key)
    if not path or not texture or not texture.SetTexture then
        self.classicAssetResults[key] = {ok = false, error = "Unknown asset or unavailable texture region"}
        return false
    end
    local ok = texture:SetTexture(path) ~= false
    self.classicAssetResults[key] = {ok = ok, error = not ok and "Client rejected texture path" or nil}
    if ok and definition.texCoord then texture:SetTexCoord(unpack(definition.texCoord)) end
    return ok
end

function EraUI:GetClassicAssetKeys()
    local keys = {}
    for key in pairs(assets) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

for _, state in ipairs({"Up", "Down", "Disabled", "Highlight"}) do
    EraUI:RegisterClassicAsset("PanelButton" .. state, {
        path = "Interface\\Buttons\\UI-Panel-Button-" .. state,
        texCoord = {0, 0.625, 0, 0.6875},
    })
end

for key, path in pairs({
    CharacterStatBackground = 'Interface\\PaperDollInfoFrame\\UI-Character-StatBackground',
    CharacterResistance = 'Interface\\PaperDollInfoFrame\\UI-Character-ResistanceIcons',
    CharacterSlot = 'Interface\\Buttons\\UI-Quickslot2',
    CharacterInset = 'Interface\\Tooltips\\UI-Tooltip-Border',
    CharacterBackground = 'Interface\\DialogFrame\\UI-DialogBox-Background',
    CharacterCloseUp = 'Interface\\Buttons\\UI-Panel-MinimizeButton-Up',
    CharacterCloseDown = 'Interface\\Buttons\\UI-Panel-MinimizeButton-Down',
    CharacterCloseHighlight = 'Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight',
}) do
    EraUI:RegisterClassicAsset(key, {path = path})
end

-- Stage 2B: native Blizzard minimap sheets and button states only.
for key, definition in pairs({
    MinimapBorder = {path="Interface\\Minimap\\UI-Minimap-Border",texCoord={.25,1,.125,.875}},
    MinimapTrackingBorder = {path="Interface\\Minimap\\MiniMap-TrackingBorder"},
    MinimapBackground = {path="Interface\\Minimap\\UI-Minimap-Background"},
    MinimapNorth = {path="Interface\\Minimap\\CompassNorthTag"},
    MinimapCompass = {path="Interface\\Minimap\\CompassRing"},
    MinimapMask = {path="Interface\\CharacterFrame\\TempPortraitAlphaMask"},
    MinimapHeader1 = {path="Interface\\Minimap\\UI-Minimap-Border",texCoord={84/256,94/256,0,28/256}},
    MinimapHeader2 = {path="Interface\\Minimap\\UI-Minimap-Border",texCoord={94/256,220/256,0,28/256}},
    MinimapHeader3 = {path="Interface\\Minimap\\UI-Minimap-Border",texCoord={94/256,84/256,0,28/256}},
    MinimapZoomHighlight = {path="Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"},
    MinimapSmallButton = {path="Interface\\Buttons\\UI-Quickslot2"},
    MinimapSmallButtonDown = {path="Interface\\Buttons\\UI-Quickslot-Depress"},
}) do
    EraUI:RegisterClassicAsset(key,definition)
end
for _, kind in ipairs({"ZoomIn","ZoomOut"}) do
    for _, state in ipairs({"Up","Down","Disabled"}) do
        EraUI:RegisterClassicAsset("Minimap"..kind..state, {path="Interface\\Minimap\\UI-Minimap-"..kind.."Button-"..state})
    end
end

-- Stage 2C: existing dock/button sheets; stateful overlays remain native.
for key,path in pairs({
    ActionDock="Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf",
    ActionDockMaxLevel="Interface\\MainMenuBar\\UI-MainMenuBar-MaxLevel",
    ActionGryphon="Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf",
    ActionSlotNormal="Interface\\Buttons\\UI-Quickslot2",
    ActionSlotEmpty="Interface\\Buttons\\UI-Quickslot",
    ActionSlotPushed="Interface\\Buttons\\UI-Quickslot-Depress",
    ActionSlotHighlight="Interface\\Buttons\\ButtonHilight-Square",
    MicroHighlight="Interface\\Buttons\\UI-MicroButton-Hilight",
}) do EraUI:RegisterClassicAsset(key,{path=path}) end
for _,name in ipairs({"Spellbook","Talents","Achievement","Quest","Socials","MainMenu","Help","Abilities","Mounts","EJ","LFG"}) do
    for _,state in ipairs({"Up","Down","Disabled"}) do
        EraUI:RegisterClassicAsset("Micro"..name..state,{path="Interface\\Buttons\\UI-MicroButton-"..name.."-"..state})
    end
end
-- The portrait shell has no hyphen before Character, or separate disabled file.
for _,state in ipairs({"Up","Down","Disabled"}) do
    EraUI:RegisterClassicAsset("MicroCharacter"..state,{path="Interface\\Buttons\\UI-MicroButtonCharacter-"..(state=="Disabled" and "Up" or state)})
end
for _,direction in ipairs({"Up","Down"}) do
    for _,state in ipairs({"Up","Down","Disabled","Highlight"}) do
        EraUI:RegisterClassicAsset("ActionPage"..direction..state,{path="Interface\\MainMenuBar\\UI-MainMenu-Scroll"..direction.."Button-"..state})
    end
end

-- The Forever client replaces these old paths with modern redraws, so the
-- Classic Era originals are bundled and referenced explicitly.
-- See Media/ClassicCharacterAssets.txt for source and reason for bundling.
for key, file in pairs({
    CharacterListFill = "UI-Character-Skills-Bar",
    CharacterSkillBorder = "UI-Character-Skills-BarBorder",
    CharacterReputationPlate = "UI-Character-ReputationBar",
}) do
    EraUI:RegisterClassicAsset(key, {path = "Interface\\AddOns\\EraUI\\Media\\" .. file})
end