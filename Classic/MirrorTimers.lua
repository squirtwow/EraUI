-- EraUI mirror timers.
-- The breath, fatigue and feign death bars. 1.x drew them as a cast bar: the
-- old border around a plain status bar, the label on top, in the old colors.
-- The timers are restyled from the event that starts one, a frame later, so
-- our code stays out of the client's own setup pass.
local _, EraUI = ...
local ns = EraUI.Classic

local BAR_W, BAR_H = 195, 13
local FRAME_W, FRAME_H = 206, 26

local COLORS = {
    BREATH = { 0, 0.5, 1 },
    EXHAUSTION = { 1, 0.9, 0 },
    DEATH = { 1, 0.7, 0 },
    FEIGNDEATH = { 1, 0.7, 0 },
}

local active = false
local driver

local function Kind(bar)
    return bar.timer or bar.type or (bar.GetAttribute and bar:GetAttribute("timer")) or "BREATH"
end

local function Dress(bar)
    if not bar or not bar.StatusBar then return end
    bar:SetSize(FRAME_W, FRAME_H)

    local fill = ns.OwnTexture(bar, "ground", "BACKGROUND", 0)
    fill:SetColorTexture(0, 0, 0, 0.5)
    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 5, -2)
    fill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -5, 11)
    fill:Show()

    local status = bar.StatusBar
    status:SetSize(BAR_W, BAR_H)
    status:ClearAllPoints()
    status:SetPoint("TOP", bar, "TOP", 0, -2)
    status:SetStatusBarTexture((ns.TexPath("statusBar")))
    local color = COLORS[Kind(bar)] or COLORS.BREATH
    status:SetStatusBarColor(color[1], color[2], color[3])

    if bar.Border then
        ns.SetTex(bar.Border, "castBorder")
        bar.Border:SetTexCoord(0, 1, 0, 1)
        bar.Border:SetSize(256, 64)
        bar.Border:ClearAllPoints()
        bar.Border:SetPoint("TOP", bar, "TOP", 0, 25)
    end
    if bar.TextBorder then bar.TextBorder:SetAlpha(0) end
    if bar.Text then
        bar.Text:SetFontObject("GameFontHighlight")
        bar.Text:ClearAllPoints()
        bar.Text:SetPoint("TOP", bar, "TOP", 0, -2)
    end
end

local function DressAll()
    local container = MirrorTimerContainer
    if not active or not container or not container.GetChildren then return end
    for _, child in ipairs({ container:GetChildren() }) do
        if child.StatusBar then ns.SafeCall(Dress, child) end
    end
end

local function Apply()
    active = true
    if not driver then
        driver = CreateFrame("Frame")
        for _, event in ipairs({ "MIRROR_TIMER_START", "MIRROR_TIMER_STOP", "PLAYER_ENTERING_WORLD" }) do
            pcall(driver.RegisterEvent, driver, event)
        end
        driver:SetScript("OnEvent", function()
            if not active then return end
            C_Timer.After(0, DressAll)
        end)
    end
    DressAll()
end

local function Restore()
    active = false
    local container = MirrorTimerContainer
    if not container or not container.GetChildren then return end
    for _, child in ipairs({ container:GetChildren() }) do
        if child.fcui and child.fcui.ground then child.fcui.ground:Hide() end
        if child.TextBorder then child.TextBorder:SetAlpha(1) end
    end
    ns.needsReload = true
end

ns.RegisterModule("mirrorTimers", { apply = Apply, restore = Restore })
