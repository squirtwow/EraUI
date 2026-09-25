-- EraUI cast bars.
-- The 1.x cast bars: 195x13 with the old border sheet, UI-StatusBar fills in
-- the old yellow/green/gray/red, a static spark and none of the modern flakes,
-- wisps and glow lines. Nothing here writes a field on a cast bar; secure
-- hooks put the classic art back after each change so Blizzard's own update
-- loop keeps running untouched.
local _, EraUI = ...
local ns = EraUI.Classic

local FX = { "Flakes01", "Flakes02", "Flakes03", "BaseGlow", "WispGlow", "Sparkles01", "Sparkles02", "Shine",
    "EnergyGlow", "InterruptGlow", "ChargeGlow", "ChargeFlash", "StandardGlow", "CraftGlow", "ChannelShadow", "DropShadow", "TextBorder" }
local FINISH_ANIMS = { "StandardFinish", "ChannelFinish", "CraftingFinish" }

local FILL_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local COLORS = {
    yellow = CASTBAR_CLASSIC_YELLOW or CreateColor(1, 0.7, 0),
    green = CASTBAR_CLASSIC_GREEN or CreateColor(0, 1, 0),
    gray = CASTBAR_CLASSIC_GRAY or CreateColor(0.5, 0.5, 0.5),
    red = CASTBAR_CLASSIC_RED or CreateColor(1, 0, 0),
}

local active = false
local skinned = {}

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

-- 12.x never calls SetLook on the target, focus and boss spell bars, so their
-- look is unset; those are the small bars (they have AdjustPosition).
local function LookOf(bar)
    if bar.look then return bar.look end
    return bar.AdjustPosition and "UNITFRAME" or "CLASSIC"
end

local function Shape(bar)
    local look = LookOf(bar)
    if look == "UNITFRAME" then
        bar:SetSize(150, 10)
        if bar.Border then
            ns.SetTex(bar.Border, "castBorderSmall")
            bar.Border:SetTexCoord(0, 1, 0, 1)
            bar.Border:ClearAllPoints()
            bar.Border:SetHeight(56)
            bar.Border:SetPoint("TOPLEFT", bar, "TOPLEFT", -23, 23)
            bar.Border:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 23, 23)
        end
        if bar.BorderShield then
            bar.BorderShield:ClearAllPoints()
            bar.BorderShield:SetHeight(56)
            bar.BorderShield:SetPoint("TOPLEFT", bar, "TOPLEFT", -28, 23)
            bar.BorderShield:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 18, 23)
        end
        if bar.Text then
            bar.Text:ClearAllPoints()
            bar.Text:SetHeight(16)
            bar.Text:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 4)
            bar.Text:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 4)
            bar.Text:SetFontObject("SystemFont_Shadow_Small")
        end
        if bar.Icon then
            bar.Icon:SetSize(18, 18)
            bar.Icon:ClearAllPoints()
            bar.Icon:SetPoint("RIGHT", bar, "LEFT", -3.5, 1)
        end
    elseif look == "CLASSIC" then
        bar:SetSize(195, 13)
        if bar.Border then
            ns.SetTex(bar.Border, "castBorder")
            bar.Border:SetTexCoord(0, 1, 0, 1)
            bar.Border:ClearAllPoints()
            bar.Border:SetSize(256, 64)
            bar.Border:SetPoint("TOP", bar, "TOP", 0, 28)
        end
        if bar.BorderShield then
            bar.BorderShield:ClearAllPoints()
            bar.BorderShield:SetSize(256, 64)
            bar.BorderShield:SetPoint("TOP", bar, "TOP", 0, 28)
        end
        if bar.Text then
            bar.Text:ClearAllPoints()
            bar.Text:SetSize(185, 16)
            bar.Text:SetPoint("TOP", bar, "TOP", 0, 5)
            bar.Text:SetFontObject("GameFontHighlight")
        end
    end
end

local function HideFx(bar)
    for _, key in ipairs(FX) do
        local region = bar[key]
        if region then
            if region.SetAtlas then region:SetAtlas(nil) end
            region:SetAlpha(0)
            region:Hide()
        end
    end
end

local function DressSpark(bar)
    if not bar.Spark then return end
    ns.SetTex(bar.Spark, "castSpark")
    bar.Spark:SetTexCoord(0, 1, 0, 1)
    bar.Spark:SetSize(32, 32)
    bar.Spark:SetBlendMode("ADD")
end

local function DressFlash(bar)
    if not bar.Flash then return end
    local small = LookOf(bar) == "UNITFRAME"
    ns.SetTex(bar.Flash, small and "castFlashSmall" or "castFlash")
    bar.Flash:SetTexCoord(0, 1, 0, 1)
    bar.Flash:SetBlendMode("ADD")
    bar.Flash:ClearAllPoints()
    if small then
        bar.Flash:SetHeight(56)
        bar.Flash:SetPoint("TOPLEFT", bar, "TOPLEFT", -23, 23)
        bar.Flash:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 23, 23)
    else
        bar.Flash:SetSize(256, 64)
        bar.Flash:SetPoint("TOP", bar, "TOP", 0, 28)
    end
end

-- The classic fill color from the modern atlas name, so the bar type (a
-- secret value for other units) is never read.
local function FillColor(atlas)
    atlas = (type(atlas) == "string" and not IsSecret(atlas)) and atlas:lower() or ""
    if atlas:find("interrupted", 1, true) then return COLORS.red end
    if atlas:find("full", 1, true) then return COLORS.green end
    if atlas:find("channel", 1, true) then return COLORS.green end
    if atlas:find("uninterrupt", 1, true) then return COLORS.gray end
    return COLORS.yellow
end

local function Fill(bar)
    if not active then return end
    local tex = bar:GetStatusBarTexture()
    local atlas = tex and tex.GetAtlas and tex:GetAtlas()
    local color = FillColor(atlas)
    bar:SetStatusBarTexture(FILL_TEXTURE)
    bar:SetStatusBarColor(color:GetRGB())
end

local Position
Position = function(bar)
    if not active or bar.boss then return end
    if InCombatLockdown() and bar.IsProtected and bar:IsProtected() then return end
    local parent = bar:GetParent()
    if not parent or not parent.GetAuraContainer then return end
    if parent.smallSize then
        if bar:GetScale() ~= 1 then bar:SetScale(1) end
    end
    local container = parent:GetAuraContainer()
    local ok, _, relativeTo = pcall(bar.GetPoint, bar, 1)
    local underAuras = ok and container ~= nil and relativeTo == container
    if ns.OnSpellBarPlaced then ns.OnSpellBarPlaced(bar, underAuras, parent) end
    bar:ClearAllPoints()
    if underAuras then
        bar:SetPoint("TOPLEFT", container, "BOTTOMLEFT", 22, -16)
        return
    end
    local y = 3
    if parent.haveToT then
        y = -25
    elseif parent.haveElite then
        y = -9
    end
    bar:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 43, y)
end

local function StopFinishAnims(bar)
    for _, key in ipairs(FINISH_ANIMS) do
        local anim = bar[key]
        if anim and anim.Stop then anim:Stop() end
    end
    HideFx(bar)
end

local function Dress(bar)
    if not active then return end
    Shape(bar)
    if bar.Background then
        bar.Background:SetAtlas(nil)
        bar.Background:SetColorTexture(0, 0, 0, 0.5)
        bar.Background:ClearAllPoints()
        bar.Background:SetAllPoints(bar)
    end
    DressSpark(bar)
    DressFlash(bar)
    if bar.BorderShield then
        ns.SetTex(bar.BorderShield, LookOf(bar) == "UNITFRAME" and "castSmallShield" or "castBorder")
        bar.BorderShield:SetTexCoord(0, 1, 0, 1)
    end
    HideFx(bar)
    Fill(bar)
    if bar.AdjustPosition then Position(bar) end
end

local function Skin(bar)
    if not bar then return end
    if not skinned[bar] then
        skinned[bar] = true
        ns.HookMethod(bar, "SetLook", Dress)
        ns.HookMethod(bar, "UpdateShownState", Dress)
        if bar.AdjustPosition then
            ns.HookMethod(bar, "AdjustPosition", Position)
            local parent = bar:GetParent()
            if parent and parent.SetSmallSize then
                ns.HookMethod(parent, "SetSmallSize", function() Position(bar) end)
            end
        end
        ns.HookMethod(bar, "UpdateBarFillTexture", Fill)
        ns.HookMethod(bar, "ShowSpark", function(b)
            if not active then return end
            DressSpark(b)
            HideFx(b)
        end)
        ns.HookMethod(bar, "PlayFadeAnim", function(b)
            if active then DressFlash(b) end
        end)
        ns.HookMethod(bar, "PlayFinishAnim", function(b)
            if active then StopFinishAnims(b) end
        end)
        ns.HookMethod(bar, "PlayInterruptAnims", function(b)
            if active then HideFx(b) end
        end)
    end
    Dress(bar)
end

local function Apply()
    active = true
    Skin(PlayerCastingBarFrame)
    Skin(PetCastingBarFrame)
    if TargetFrame then Skin(TargetFrame.spellbar) end
    if FocusFrame then Skin(FocusFrame.spellbar) end
    local bosses = BossTargetFrameContainer and BossTargetFrameContainer.BossTargetFrames
    if bosses then
        for _, boss in pairs(bosses) do Skin(boss.spellbar) end
    end
end

local function Restore()
    active = false
    for bar in pairs(skinned) do
        if bar.Border then bar.Border:SetAtlas("ui-castingbar-frame") end
        if bar.Spark then bar.Spark:SetAtlas("ui-castingbar-pip") end
        if bar.Flash then bar.Flash:SetAtlas("ui-castingbar-full-glow-standard") end
        if bar.Background then bar.Background:SetAtlas("ui-castingbar-background") end
        for _, key in ipairs(FX) do
            if bar[key] then bar[key]:SetAlpha(1) end
        end
    end
    ns.needsReload = true
end

ns.RegisterModule("castBars", { apply = Apply, restore = Restore })
