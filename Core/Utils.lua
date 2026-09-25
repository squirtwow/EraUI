local _, EraUI = ...

EraUI.Media = {
    gold = {0.93, 0.75, 0.32, 1},
    parchment = {0.82, 0.68, 0.42, 1},
    dark = {0.08, 0.07, 0.06, 0.94},
}

function EraUI:SafeHide(frame)
    if not frame then return end
    if InCombatLockdown and InCombatLockdown() and frame.IsProtected and frame:IsProtected() then
        return false
    end
    frame:Hide()
    return true
end

function EraUI:StripRetailBackdrop(frame)
    if not frame then return end
    if frame.NineSlice and frame.NineSlice.SetAlpha then
        frame.NineSlice:SetAlpha(0)
    end
    if frame.Border and frame.Border.SetAlpha then
        frame.Border:SetAlpha(0)
    end
end

function EraUI:AddClassicBackdrop(frame, inset)
    if not frame or frame.__EraUIBackdrop then return frame and frame.__EraUIBackdrop end
    inset = inset or 2
    local bg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", -inset, inset)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", inset, -inset)
    bg:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    bg:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    bg:SetBackdropColor(0.16, 0.12, 0.08, 0.96)
    frame.__EraUIBackdrop = bg
    return bg
end

function EraUI:CreateLabel(parent, text, size)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text)
    if size then
        local font, _, flags = fs:GetFont()
        if font then fs:SetFont(font, size, flags) end
    end
    fs:SetTextColor(unpack(self.Media.parchment))
    return fs
end
