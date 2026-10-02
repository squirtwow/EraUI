-- EraUI cast bars.
-- The 1.x cast bars: 195x13 with the old border sheet, UI-StatusBar fills in
-- the old yellow/green/gray/red, a static spark and none of the modern flakes,
-- wisps and glow lines. Nothing here writes a field on a cast bar; secure
-- hooks put the classic art back after each change so Blizzard's own update
-- loop keeps running untouched.
-- The boss frames' cast bars can be styled by Forever Enhanced Cooldown
-- Manager instead (its Raid Timers page); see "Boss cast bars" below.
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
local playerChannel
local function KeepPlayerChannel(bar)
    if not active or not playerChannel or EraUI:GetSetting("advancedCastBar")then return end
    bar:SetMinMaxValues(0,playerChannel.total)
    bar:SetValue(EraUI.CastTiming.Value(playerChannel,GetTime()))
    if bar.Spark then
        bar.Spark:ClearAllPoints()
        bar.Spark:SetPoint("CENTER",bar:GetStatusBarTexture(),"RIGHT",0,0)
    end
end
local function ReadPlayerChannel(bar,fresh)
    if not active or EraUI:GetSetting("advancedCastBar")then playerChannel=nil;return end
    local name,_,_,startMS,endMS,_,_,spellID,empowered=UnitChannelInfo("player")
    if (issecretvalue and issecretvalue(empowered))or empowered then playerChannel=nil;return end
    playerChannel=EraUI.CastTiming.Snapshot(playerChannel,true,name,startMS,endMS,spellID,fresh)
    KeepPlayerChannel(bar)
end

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

-- Boss cast bars ---------------------------------------------------------------
-- Forever Enhanced Cooldown Manager (Squirt's other addon) can style the boss
-- frames' cast bars too, from its Raid Timers page. It says whether it does
-- through its public API (ForeverEnhancedCooldownManagerAPI), never its
-- insides, and calls back each time that answer changes: before its look goes
-- on, and after Blizzard's is back. While it styles them, EraUI leaves those
-- bars alone, after putting back exactly what it changed on them; when it
-- hands them back, EraUI's look goes on again. The answer is asked on every
-- boss bar update, so both ways work at once, without a reload. Without that
-- addon, with one too old to have the API, or when its answer can't be read,
-- the boss bars are EraUI's as before.
local bossBars = {} -- the boss frames' cast bars
local before = {} -- each one's look before EraUI first dressed it (false if it couldn't be read)
local dressed = {} -- the boss bars in EraUI's look now
local shared = false -- told the other addon that EraUI steps back

-- Whether Forever Enhanced Cooldown Manager styles the boss cast bars now.
local function OtherStylesBoss()
    local api = _G.ForeverEnhancedCooldownManagerAPI
    if type(api) ~= "table" then return false end
    local ask = api.StylesBossCastBars
    if type(ask) ~= "function" then return false end
    local answer = ask()
    return not IsSecret(answer) and answer == true
end

-- A boss bar left to the other addon; anything unreadable leaves it EraUI's.
local function Yielded(bar)
    if not bossBars[bar] then return false end
    local ok, yes = pcall(OtherStylesBoss)
    return ok and yes == true
end

-- What EraUI changes on a boss bar, piece by piece: its art (atlas or texture,
-- coords and tint), its place (anchors and size), size alone, blend, font,
-- alpha and whether it shows.
local BOSS_PIECES = {
    Border = { art = true, place = true },
    BorderShield = { art = true, place = true },
    Flash = { art = true, place = true, blend = true },
    Spark = { art = true, size = true, blend = true },
    Background = { art = true, place = true },
    Text = { place = true, font = true },
    Icon = { place = true },
}

-- Values that can be put back as they were: nil if any of them is secret.
local function Plain(...)
    local values = { n = select("#", ...), ... }
    for i = 1, values.n do
        if IsSecret(values[i]) then return nil end
    end
    return values
end

local function Note(region, what)
    local was = {}
    if what.place then
        local points = {}
        for i = 1, region:GetNumPoints() do
            local point = Plain(region:GetPoint(i))
            if not point then
                points = nil
                break
            end
            points[i] = point
        end
        was.points = points
    end
    if what.place or what.size then was.size = Plain(region:GetSize()) end
    if what.art then
        local atlas = region:GetAtlas()
        if atlas and not IsSecret(atlas) then
            was.atlas = atlas
        else
            local texture = region:GetTexture()
            if texture and not IsSecret(texture) then was.texture = texture end
            was.coords = Plain(region:GetTexCoord())
        end
        was.tint = Plain(region:GetVertexColor())
    end
    if what.blend then was.blend = Plain(region:GetBlendMode()) end
    if what.font then was.font = Plain(region:GetFontObject()) end
    if what.alpha then was.alpha = Plain(region:GetAlpha()) end
    if what.shown then was.shown = Plain(region:IsShown()) end
    return was
end

-- Each piece on its own, so one that can't be read leaves the rest.
local function NoteBar(bar)
    local was = { size = Plain(bar:GetSize()), pieces = {} }
    local function Piece(key, what)
        local ok, piece = pcall(Note, bar[key], what)
        if ok then was.pieces[key] = piece end
    end
    for key, what in pairs(BOSS_PIECES) do
        if bar[key] then Piece(key, what) end
    end
    for _, key in ipairs(FX) do
        if bar[key] and not BOSS_PIECES[key] then Piece(key, { art = true, alpha = true, shown = true }) end
    end
    return was
end

local function Resize(object, size)
    if not size then return end
    local w, h = size[1], size[2]
    if type(w) == "number" and w > 0 then object:SetWidth(w) end
    if type(h) == "number" and h > 0 then object:SetHeight(h) end
end

local function PutBack(region, was)
    if was.points then
        region:ClearAllPoints()
        for _, point in ipairs(was.points) do region:SetPoint(unpack(point, 1, point.n)) end
    end
    Resize(region, was.size)
    if was.atlas then
        region:SetAtlas(was.atlas)
    else
        if was.texture then region:SetTexture(was.texture) end
        if was.coords then region:SetTexCoord(unpack(was.coords, 1, was.coords.n)) end
    end
    if was.tint then region:SetVertexColor(unpack(was.tint, 1, was.tint.n)) end
    -- Each mode by name (EraUI never sets MOD; Tools/TestBlendModes.mjs).
    local blend = was.blend and was.blend[1]
    if blend == "BLEND" then
        region:SetBlendMode("BLEND")
    elseif blend == "ADD" then
        region:SetBlendMode("ADD")
    elseif blend == "ALPHAKEY" then
        region:SetBlendMode("ALPHAKEY")
    elseif blend == "DISABLE" then
        region:SetBlendMode("DISABLE")
    end
    if was.font and was.font[1] then region:SetFontObject(was.font[1]) end
    if was.alpha then region:SetAlpha(was.alpha[1]) end
    if was.shown then region:SetShown(was.shown[1]) end
end

-- A boss bar's own size can't change while it's protected in a fight: it goes
-- back when the fight ends, unless EraUI has dressed the bar again by then.
local sizeAfterFight = {} -- handed-over boss bars waiting for Blizzard's size
local fightWatch

local function SizesAfterFight()
    for bar, size in pairs(sizeAfterFight) do
        sizeAfterFight[bar] = nil
        if not dressed[bar] then pcall(Resize, bar, size) end
    end
end

local function SizeBack(bar, size)
    if InCombatLockdown() and bar.IsProtected and bar:IsProtected() then
        sizeAfterFight[bar] = size
        if not fightWatch then
            fightWatch = CreateFrame("Frame")
            fightWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
            fightWatch:SetScript("OnEvent", SizesAfterFight)
        end
        return
    end
    sizeAfterFight[bar] = nil
    Resize(bar, size)
end

-- Blizzard's look back on a boss bar EraUI has dressed: what EraUI changed,
-- as it was, and nothing else.
local function GiveBack(bar)
    if not dressed[bar] then return end
    dressed[bar] = nil
    local was = before[bar]
    if not was then return end
    SizeBack(bar, was.size)
    for key, piece in pairs(was.pieces) do
        if bar[key] then pcall(PutBack, bar[key], piece) end
    end
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
    if not active or Yielded(bar) then return end
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
    if bossBars[bar] then
        if Yielded(bar) then return end
        -- Blizzard's look, read the first time, to put back when the bar is handed over.
        if before[bar] == nil then
            local ok, was = pcall(NoteBar, bar)
            before[bar] = ok and was or false
        end
        dressed[bar] = true
    end
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

local function Skin(bar, boss)
    if not bar then return end
    if boss then bossBars[bar] = true end
    if not skinned[bar] then
        skinned[bar] = true
        if bar==PlayerCastingBarFrame then
            ns.HookMethod(bar,"HandleCastStart",function(b,event)
                playerChannel=nil
                if event=="UNIT_SPELLCAST_CHANNEL_START"then ReadPlayerChannel(b,true)end
            end)
            ns.HookMethod(bar,"HandleChannelUpdateDelayed",function(b)ReadPlayerChannel(b,false)end)
            ns.HookMethod(bar,"FinishSpell",function()playerChannel=nil end)
            ns.HookMethod(bar,"HandleCastStop",function()playerChannel=nil end)
            ns.HookMethod(bar,"HandleInterruptOrSpellFailed",function()playerChannel=nil end)
            bar:HookScript("OnHide",function()playerChannel=nil end)
            bar:HookScript("OnUpdate",KeepPlayerChannel)
        end
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
            if not active or Yielded(b) then return end
            DressSpark(b)
            HideFx(b)
        end)
        ns.HookMethod(bar, "PlayFadeAnim", function(b)
            if active and not Yielded(b) then DressFlash(b) end
        end)
        ns.HookMethod(bar, "PlayFinishAnim", function(b)
            if active and not Yielded(b) then StopFinishAnims(b) end
        end)
        ns.HookMethod(bar, "PlayInterruptAnims", function(b)
            if active and not Yielded(b) then HideFx(b) end
        end)
    end
    Dress(bar)
end

-- Called by Forever Enhanced Cooldown Manager each time it takes the boss bars
-- or hands them back: Blizzard's look back on each bar it now styles (before
-- its own goes on), EraUI's look on each bar it has handed back.
local function Handover()
    for bar in pairs(bossBars) do
        if Yielded(bar) then pcall(GiveBack, bar) else pcall(Dress, bar) end
    end
end

-- Tells Forever Enhanced Cooldown Manager, once, that EraUI steps back from the
-- boss bars while it styles them (until then it leaves them to EraUI's Cast
-- Bars). Said at login, even when a fight holds EraUI's first pass back (a
-- /reload in one), and tried again on each pass until it's there to hear it.
local function Share()
    if shared then return end
    local ok, done = pcall(function()
        local api = _G.ForeverEnhancedCooldownManagerAPI
        if type(api) ~= "table" then return false end
        local share = api.ShareBossCastBars
        if type(share) ~= "function" then return false end
        return share("EraUI", Handover)
    end)
    shared = ok and done == true
end

local function Apply()
    active = true
    Share()
    Skin(PlayerCastingBarFrame)
    Skin(PetCastingBarFrame)
    if TargetFrame then Skin(TargetFrame.spellbar) end
    if FocusFrame then Skin(FocusFrame.spellbar) end
    local bosses = BossTargetFrameContainer and BossTargetFrameContainer.BossTargetFrames
    if bosses then
        for _, boss in pairs(bosses) do Skin(boss.spellbar, true) end
    end
end

local function Restore()
    active = false
    for bar in pairs(skinned) do
        -- A boss bar EraUI isn't dressing (the other addon's) is left alone.
        if not bossBars[bar] or (dressed[bar] and not Yielded(bar)) then
            if bar.Border then bar.Border:SetAtlas("ui-castingbar-frame") end
            if bar.Spark then bar.Spark:SetAtlas("ui-castingbar-pip") end
            if bar.Flash then bar.Flash:SetAtlas("ui-castingbar-full-glow-standard") end
            if bar.Background then bar.Background:SetAtlas("ui-castingbar-background") end
            for _, key in ipairs(FX) do
                if bar[key] then bar[key]:SetAlpha(1) end
            end
        end
    end
    ns.needsReload = true
end

-- init runs at login with Cast Bars on, before the first pass, fight or not.
ns.RegisterModule("castBars", { init = Share, apply = Apply, restore = Restore })
