local _, EraUI = ...

-- Evidence from real skin calls only; the audit never invokes a skin.
EraUI.classicButtonResults = setmetatable({}, {__mode = "k"})
local states = {{"Normal", "Up"}, {"Pushed", "Down"}, {"Disabled", "Disabled"}, {"Highlight", "Highlight"}}

function EraUI:SkinClassicRedButton(button, owner)
    if not button then return false end
    local result = {owner = owner or "Unknown", ok = false}
    self.classicButtonResults[button] = result
    for _, state in ipairs(states) do
        if not button["Set" .. state[1] .. "Texture"] or not button["Get" .. state[1] .. "Texture"] then
            result.error = "Button texture methods unavailable"
            return false
        end
    end
    if not button.SetNormalFontObject or not button.SetHighlightFontObject then
        result.error = "Button font methods unavailable"
        return false
    end
    for _, state in ipairs(states) do
        local key = "PanelButton" .. state[2]
        local setter = button["Set" .. state[1] .. "Texture"]
        if state[1] == "Highlight" then
            setter(button, self:GetClassicTexture(key), "ADD")
        else
            local path = self:GetClassicTexture(key)
            setter(button, path)
        end
        local texture = button["Get" .. state[1] .. "Texture"](button)
        if not self:SetClassicTexture(texture, key) then
            result.error = "Texture unavailable: " .. key
            return false
        end
        texture:ClearAllPoints()
        texture:SetAllPoints(button)
    end
    for _, key in ipairs({"Left", "Middle", "Right", "Center"}) do
        local region = button[key]
        if region and region.SetAlpha then region:SetAlpha(0) end
    end
    button:SetNormalFontObject(GameFontNormal)
    button:SetHighlightFontObject(GameFontHighlight)
    result.ok = true
    return true
end
