local _, EraUI = ...

EraUI.Media = {
    gold = {0.93, 0.75, 0.32, 1},
    parchment = {0.82, 0.68, 0.42, 1},
    dark = {0.08, 0.07, 0.06, 0.94},
}

-- Forever names have a surname and no realm. UnitName("player") gives the
-- first name and the surname as two values, but the guild roster, /who,
-- whispers and addon messages call you "First Surname" (confirmed in game
-- 2026-09-29), so a name is never compared with the first name alone.
local function Hidden(v) return issecretvalue and issecretvalue(v) end
local function Joined(fn)
    if type(fn) ~= "function" then return end
    local ok, first, surname = pcall(fn, "player")
    if not ok or Hidden(first) or type(first) ~= "string" or first == "" then return end
    if Hidden(surname) or type(surname) ~= "string" or surname == "" then return first end
    local sep = Constants and Constants.CharacterNameSeparatorConsts
    sep = sep and sep.CHARACTERNAME_SURNAME_SEPARATOR
    if type(sep) ~= "string" or sep == "" then sep = " " end
    if first:sub(-#sep - #surname) == sep .. surname then return first end -- already whole
    return first .. sep .. surname
end

-- Your whole name as other players see it: "First Surname", or the first
-- name alone on a character without a surname.
function EraUI:PlayerFullName() return Joined(UnitName) end

-- Whether a roster, /who, chat or addon-message name, or a GUID, is you.
-- A matching GUID settles it; otherwise the whole name has to match.
function EraUI:IsPlayer(name, guid)
    if guid ~= nil and not Hidden(guid) and UnitGUID then
        local ok, mine = pcall(UnitGUID, "player")
        if ok and not Hidden(mine) and type(mine) == "string" and mine == guid then return true end
    end
    if Hidden(name) or type(name) ~= "string" or name == "" then return false end
    if Ambiguate then
        local ok, short = pcall(Ambiguate, name, "none")
        if ok and not Hidden(short) and type(short) == "string" then name = short end
    end
    return name == Joined(UnitName) or name == Joined(UnitNameUnmodified)
end

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
