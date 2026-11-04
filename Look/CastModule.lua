-- The cast bars' registry entry ("castBars"): the hooks that keep the 1.x
-- look on the game's bars, a full dressing in its order, the player channel
-- keeper, the pass, turning it off, and what /era calls live.
--
-- Everything is driven by post-hooks on the game's own bar methods (no
-- polling), installed once per bar the first time it is dressed. Each hook
-- first asks whether Cast Bars is on and the bar is still EraUI's (a boss
-- bar handed to Forever Enhanced Cooldown Manager is not); after Cast Bars is
-- turned off they stay but do nothing.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Cast = Look.Cast

---------------------------------------------------------------------------
-- A full dressing
---------------------------------------------------------------------------

-- In order: (a boss bar's Blizzard look noted, the first time), the shape,
-- the ground, the spark, the flash, the shield, the effects hidden, the
-- rounded look on or off, the fill and its colour, and the bar's place.
function Cast.DressAll(bar)
    if not Cast.applied then return end
    if Cast.boss[bar] then
        if Cast.Styled() then return end
        Cast.NoteBossLook(bar)
        Cast.dressing[bar] = true
    end
    local look = Cast.LookOf(bar)
    local rounded, held = Cast.RoundOutcome(bar, look)
    Cast.Shape(bar, look)
    Cast.Ground(bar)
    Cast.Spark(bar, look, rounded)
    Cast.Flash(bar, look, rounded)
    Cast.ShieldArt(bar, look)
    Cast.HideEffects(bar)
    Cast.RoundStep(bar, look, rounded, held)
    Cast.Fill(bar)
    if type(bar.AdjustPosition) == "function" then Cast.Place(bar) end
end

-- Rounded Cast Bars switched: the shape, spark, flash, shield and rounded
-- look again; the fill and its colour stay as they are.
function Cast.Restyle(bar, look, rounded)
    Cast.Shape(bar, look)
    Cast.Spark(bar, look, rounded)
    Cast.Flash(bar, look, rounded)
    Cast.ShieldArt(bar, look)
    Cast.RoundStep(bar, look, rounded, false)
end

---------------------------------------------------------------------------
-- The hooks
---------------------------------------------------------------------------

local function Ours(bar)
    return Cast.applied and Cast.dressed[bar] == true and not Cast.HandedOver(bar)
end

local function Redress(bar)
    if Ours(bar) then Look.Try(Cast.DressAll, bar) end
end

local function Replace(bar)
    if Ours(bar) then Look.Try(Cast.Place, bar) end
end

local function SmallFocus(parent)
    local bar = Cast.parents[parent]
    if bar then Replace(bar) end
end

local function Refill(bar)
    if Ours(bar) then Look.Try(Cast.Fill, bar) end
end

local function SparkAgain(bar)
    local look = Cast.LookOf(bar)
    Cast.Spark(bar, look, (Cast.RoundOutcome(bar, look)))
    Cast.HideEffects(bar)
end

local function FlashAgain(bar)
    local look = Cast.LookOf(bar)
    Cast.Flash(bar, look, (Cast.RoundOutcome(bar, look)))
end

local function Finished(bar)
    Cast.StopFinish(bar)
    Cast.HideEffects(bar)
end

local function OnSpark(bar) if Ours(bar) then Look.Try(SparkAgain, bar) end end
local function OnFade(bar) if Ours(bar) then Look.Try(FlashAgain, bar) end end
local function OnFinish(bar) if Ours(bar) then Look.Try(Finished, bar) end end
local function OnInterrupt(bar) if Ours(bar) then Look.Try(Cast.HideEffects, bar) end end

---------------------------------------------------------------------------
-- The player channel keeper
---------------------------------------------------------------------------

-- The game rebuilds a channel's bar from the shortened span on each update,
-- so a hit made it jump. Your channel keeps one clock and one scale
-- (Core/CastTiming.lua); only the shown range, value and spark are touched.
-- Empowered casts stay on the game's own path. Stands down while the
-- Advanced Cast Bar is on.
local keeper = { snapshot = nil }

local function Keeping()
    return Cast.applied and not EraUI:GetSetting("advancedCastBar")
end

local function Hold(bar)
    local snapshot, timing = keeper.snapshot, EraUI.CastTiming
    if not snapshot or not timing then return end
    bar:SetMinMaxValues(0, snapshot.total)
    bar:SetValue(timing.Value(snapshot, GetTime()))
    local spark, fill = bar.Spark, bar:GetStatusBarTexture()
    if spark and fill then Look.Pin(spark, "CENTER", fill, "RIGHT", 0, 0) end
end

local function ReadChannel(bar, fresh)
    local fine, name, _, _, startMS, endMS, _, _, spellID, empowered = pcall(UnitChannelInfo, "player")
    if not fine or Look.Secret(empowered) or empowered == true then
        keeper.snapshot = nil
        return
    end
    local timing = EraUI.CastTiming
    keeper.snapshot = timing and timing.Snapshot(keeper.snapshot, true, name, startMS, endMS, spellID, fresh) or nil
    Hold(bar)
end

local function Forget() keeper.snapshot = nil end

local function Started(bar, event)
    keeper.snapshot = nil
    if Keeping() and event == "UNIT_SPELLCAST_CHANNEL_START" then Look.Try(ReadChannel, bar, true) end
end

local function Delayed(bar)
    if Keeping() then Look.Try(ReadChannel, bar, false) end
end

local function Ticked(bar)
    if Keeping() and keeper.snapshot then Look.Try(Hold, bar) end
end

local function KeepChannels(bar)
    Look.Hook(bar, "HandleCastStart", Started)
    Look.Hook(bar, "HandleChannelUpdateDelayed", Delayed)
    for _, method in ipairs({ "FinishSpell", "HandleCastStop", "HandleInterruptOrSpellFailed" }) do
        Look.Hook(bar, method, Forget)
    end
    Look.HookScript(bar, "OnHide", Forget)
    Look.HookScript(bar, "OnUpdate", Ticked)
end

---------------------------------------------------------------------------
-- Taking a bar in
---------------------------------------------------------------------------

local function HookBar(bar)
    Look.Hook(bar, "SetLook", Redress)
    Look.Hook(bar, "UpdateShownState", Redress)
    if type(bar.AdjustPosition) == "function" then Look.Hook(bar, "AdjustPosition", Replace) end
    local parent = bar:GetParent()
    if parent and type(parent.SetSmallSize) == "function" then
        Cast.parents[parent] = bar
        Look.Hook(parent, "SetSmallSize", SmallFocus)
    end
    Look.Hook(bar, "UpdateBarFillTexture", Refill)
    Look.Hook(bar, "ShowSpark", OnSpark)
    Look.Hook(bar, "PlayFadeAnim", OnFade)
    Look.Hook(bar, "PlayFinishAnim", OnFinish)
    Look.Hook(bar, "PlayInterruptAnims", OnInterrupt)
    if bar == PlayerCastingBarFrame then KeepChannels(bar) end
end

-- The hooks once, then a full dressing.
function Cast.Adopt(bar, isBoss)
    if isBoss then Cast.boss[bar] = true end
    if not Cast.dressed[bar] then
        Cast.dressed[bar] = true
        HookBar(bar)
    end
    Cast.DressAll(bar)
end

-- A bar EraUI dresses now: not a boss bar it has handed over or never had.
local function Wearing(bar)
    if not Cast.boss[bar] then return true end
    return Cast.dressing[bar] == true and not Cast.Styled()
end

---------------------------------------------------------------------------
-- The registry entry
---------------------------------------------------------------------------

local function Apply()
    Cast.applied = true
    Cast.Share()
    for _, entry in ipairs(Cast.Bars()) do
        local bar, isBoss = entry[1], entry[2]
        if isBoss then Cast.boss[bar] = true end
        if not Cast.HandedOver(bar) then Look.Try(Cast.Adopt, bar, isBoss) end
    end
end

-- The 1.x art off the game's pieces as far as it goes without a reload:
-- the game's own frame, pip, glow and ground atlases, the effects' alpha.
local ATLASES = { Border = "ui-castingbar-frame", Spark = "ui-castingbar-pip",
    Flash = "ui-castingbar-full-glow-standard", Background = "ui-castingbar-background" }

local function Undress(bar)
    Cast.TakeOff(bar)
    for key, atlas in pairs(ATLASES) do
        local piece = bar[key]
        if piece then piece:SetAtlas(atlas) end
    end
    for _, key in ipairs(Cast.EFFECTS) do
        local piece = bar[key]
        if piece then piece:SetAlpha(1) end
    end
end

-- Runs on every pass while Cast Bars is off (cheap to repeat). Sizes, fonts,
-- places and fills come back with the reload the option asks for.
local function Restore()
    Cast.applied = false
    for bar in pairs(Cast.dressed) do
        if Wearing(bar) then Look.Try(Undress, bar) end
    end
    ns.needsReload = true
end

ns.RegisterModule("castBars", { init = Cast.Share, apply = Apply, restore = Restore })

---------------------------------------------------------------------------
-- Public (live from /era)
---------------------------------------------------------------------------

-- Flat Bars switched (from the shared RefreshFlatBars): each bar's fill
-- swapped, its colour kept. False when a bar the game guards in a fight has
-- to wait (the caller books the pass after it).
function ns.RefreshCastFills()
    if not Cast.applied then return true end
    local done = true
    for bar in pairs(Cast.dressed) do
        if Wearing(bar) then
            if Look.HeldInFight(bar) then done = false else Look.Refill(bar, Cast.PutFill) end
        end
    end
    return done
end

-- Cast Bar Colour chosen: one colour call on each of your own bars.
function ns.RefreshCastColours()
    if not Cast.applied then return end
    for bar in pairs(Cast.dressed) do
        if Cast.Own(bar) then bar:SetStatusBarColor(Cast.FillRGB(bar, Cast.kinds[bar])) end
    end
end

-- Rounded Cast Bars ticked or unticked. False when a bar held in a fight
-- waits (a pass is booked for after it).
function ns.RefreshRoundedCasts()
    if not Cast.applied then return true end
    local waited = false
    for bar in pairs(Cast.dressed) do
        if not Cast.boss[bar] then
            local look = Cast.LookOf(bar)
            local rounded, held = Cast.RoundOutcome(bar, look)
            if held then
                waited = true
            elseif rounded or Cast.RoundShown(bar) then
                Look.Try(Cast.Restyle, bar, look, rounded)
            end
        end
    end
    if waited then Cast.AskPass() end
    return not waited
end
