-- EraUI empty-slot handling.
-- 1.x drew the main bar's empty slots but hid empty buttons on the other bars
-- unless a spell was being dragged. Blizzard now keeps them visible per bar;
-- this fades the empties on the side bars the old way and brings them back
-- while the grid is shown. The main bar's empty slots also keep their binding
-- labels.
local _, EraUI = ...
local ns = EraUI.Classic

local BARS = { "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft" }

local active = false
local gridShown = false
local driver
local mainLabels = {}
local mainSlots = {}

local DRAG_REASONS = 6

local function HasSomething(button)
    if button.HasAction then return button:HasAction() end
    return button.action and HasAction(button.action)
end

local function Refresh()
    if not active then return end
    local bar = MainActionBar or MainMenuBar
    for i = 1, 12 do
        local button = _G["ActionButton" .. i]
        local label = mainLabels[i]
        if bar and button and not label then
            label = bar:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            label:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3, -2)
            label:SetJustifyH("RIGHT")
            label:SetShadowColor(0, 0, 0, 1)
            label:SetShadowOffset(1, -1)
            mainLabels[i] = label
        end
        if label then
            local art = mainSlots[i]
            if not art then
                art = {}
                art.socket = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
                art.border = bar:CreateTexture(nil, "ARTWORK")
                ns.SetTex(art.socket, "slotEmpty")
                art.socket:SetTexCoord(0, 1, 0, 1)
                art.socket:SetAlpha(0.4)
                ns.SetTex(art.border, "slotNormal")
                art.border:SetTexCoord(0.1875, 0.796875, 0.1875, 0.796875)
                art.border:SetAlpha(0.5)
                art.socket:SetPoint("CENTER", button, "CENTER")
                art.border:SetPoint("CENTER", button, "CENTER")
                mainSlots[i] = art
            end
            local empty = button and not HasSomething(button)
            local normal = button.GetNormalTexture and button:GetNormalTexture()
            local nativeArt = normal and normal:IsShown() and normal:GetAlpha() > 0
                and button:IsShown() and button:GetEffectiveAlpha() > 0
            local showArt = empty and not gridShown and not nativeArt
            local size = button:GetWidth()
            local scale = (size and size > 0 and size or 36) / 36
            art.socket:SetSize(66 * scale, 66 * scale)
            art.border:SetSize(40 * scale, 40 * scale)
            art.socket:SetShown(not not showArt)
            art.border:SetShown(not not showArt)
            local key = GetBindingKey("ACTIONBUTTON" .. i)
            local native = button and (button.HotKey or _G["ActionButton" .. i .. "HotKey"])
            local nativeVisible = native and native:IsShown() and native:GetText() and native:GetText() ~= ""
                and native:GetText() ~= RANGE_INDICATOR and native:GetAlpha() > 0 and button:IsShown() and button:GetEffectiveAlpha() > 0
            local show = empty and key and not gridShown
                and not EraUI:GetSetting("hideKeybindText") and not nativeVisible
            if show then
                if native then
                    local font, size2, flags = native:GetFont()
                    if font then label:SetFont(font, size2, flags) end
                    label:SetTextColor(native:GetTextColor())
                end
                label:SetText(GetBindingText and GetBindingText(key, "KEY_", true) or key)
            end
            label:SetShown(not not show)
        end
    end
    for _, name in ipairs(BARS) do
        local bar = _G[name]
        for _, button in ipairs(bar and bar.actionButtons or {}) do
            local reasons = button.GetAttribute and button:GetAttribute("showgrid") or 0
            local dragging = gridShown or (type(reasons) == "number" and bit.band(reasons, DRAG_REASONS) ~= 0)
            button:SetAlpha((dragging or HasSomething(button)) and 1 or 0)
        end
    end
end

local function OnEvent(_, event)
    if event == "ACTIONBAR_SHOWGRID" then
        gridShown = true
    elseif event == "ACTIONBAR_HIDEGRID" then
        gridShown = false
    end
    Refresh()
end

local function Apply()
    active = true
    if not driver then
        driver = CreateFrame("Frame")
        driver:SetScript("OnEvent", OnEvent)
        local elapsed = 0
        driver:SetScript("OnUpdate", function(_, dt)
            if not active then return end
            elapsed = elapsed + dt
            if elapsed >= 0.2 then elapsed = 0 Refresh() end
        end)
        for _, event in ipairs({ "UPDATE_BINDINGS", "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "ACTIONBAR_SLOT_CHANGED", "PLAYER_ENTERING_WORLD", "UPDATE_BONUS_ACTIONBAR", "ACTIONBAR_PAGE_CHANGED" }) do
            pcall(driver.RegisterEvent, driver, event)
        end
    end
    Refresh()
end

local function Restore()
    active = false
    for _, label in pairs(mainLabels) do label:Hide() end
    for _, art in pairs(mainSlots) do art.socket:Hide() art.border:Hide() end
    for _, name in ipairs(BARS) do
        local bar = _G[name]
        for _, button in ipairs(bar and bar.actionButtons or {}) do
            button:SetAlpha(1)
        end
    end
end

ns.RegisterModule("emptySlots", { apply = Apply, restore = Restore })
