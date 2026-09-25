local _, EraUI = ...
local Module = {}
EraUI:RegisterModule("ClassicPanels", Module)
local skins = setmetatable({}, {__mode = "k"})
local observed = setmetatable({}, {__mode = "k"})
local applying = false
local function Fade(region, state)
    if not region or not region.SetAlpha then return end
    if state.alphas[region] == nil then state.alphas[region] = region:GetAlpha() end
    region:SetAlpha(0)
end
local function RedButton(button)
    return EraUI:SkinClassicRedButton(button, "ClassicPanels")
end
local function Restore(frame)
    local state = skins[frame]
    if not state then return end
    state.art:Hide()
    for region, alpha in pairs(state.alphas) do region:SetAlpha(alpha) end
end
local function Skin(frame)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
    local state = skins[frame]
    if not state then
        state = {alphas = {}}
        local art = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        art:SetAllPoints(frame)
        art:SetFrameLevel(frame:GetFrameLevel())
        art:EnableMouse(false)
        art:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true,
            tileSize = 32, edgeSize = 32, insets = {left = 8, right = 8, top = 8, bottom = 8}})
        art:SetBackdropColor(1, 1, 1, 1)
        state.art = art
        skins[frame] = state
    end
    state.art:Show()
    for _, key in ipairs({"NineSlice", "Bg", "BG", "Background", "Border", "TopTileStreaks"}) do Fade(frame[key], state) end
    for _, button in ipairs(frame.Buttons or {}) do RedButton(button) end
    for i = 1, 4 do RedButton(frame["button" .. i] or frame["Button" .. i]) end
    if not observed[frame] then
        observed[frame] = true
        frame:HookScript("OnShow", function() Module:Refresh() end)
    end
end
function Module:Refresh()
    if applying then return end
    applying = true
    if EraUI:GetSetting("popups") then
        for i = 1, 4 do Skin(_G["StaticPopup" .. i]) end
    end
    applying = false
end
function Module:Initialize()
    self.events = CreateFrame("Frame")
    self.events:RegisterEvent("ADDON_LOADED")
    self.events:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.events:SetScript("OnEvent", function() self:Refresh() end)
    self:Refresh()
end
