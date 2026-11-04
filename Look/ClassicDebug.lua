-- /eraui-classic's diagnostics (players paste the debug one into bug
-- reports): what the client is, where the main frames sit, which art fell
-- back or is missing, the pieces this client lacks, the calls the game
-- refused; and the developer's own looks at the XP bars, the damage meter,
-- the frames under the mouse and what moves when the target changes. Reads
-- only: every answer the game may hide is shown as "secret".
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Slash
local Say = S.Say

local function Begin(title)
    if type(ns.BeginOutput) == "function" then Look.Try(ns.BeginOutput, title) end
end

local function Finish()
    if type(ns.FlushNotice) == "function" then Look.Try(ns.FlushNotice) end
end

local function Shown(value)
    if Look.Secret(value) then return "secret" end
    if value == nil then return "nil" end
    if type(value) == "number" then return string.format("%.1f", value) end
    return tostring(value)
end

local function Called(frame)
    local fine, name = Look.Ask(frame, "GetName")
    return fine and name or "?"
end

-- shown, width, height, left, bottom, effective scale (or why not).
local function Rect(frame)
    if type(frame) ~= "table" then return "missing" end
    local left, bottom = Look.Number(frame:GetLeft()), Look.Number(frame:GetBottom())
    if not left or not bottom then return "no rect yet" end
    return string.format("shown=%s %sx%s at %s,%s scale %s", tostring(frame:IsShown()), Shown(frame:GetWidth()),
        Shown(frame:GetHeight()), Shown(left), Shown(bottom), Shown(frame:GetEffectiveScale()))
end

local function Placed(frame)
    if type(frame) ~= "table" then return "missing" end
    local fine, strata = Look.Ask(frame, "GetFrameStrata")
    local asked, level = Look.Ask(frame, "GetFrameLevel")
    return string.format("%s level %s %s", fine and tostring(strata) or "?", asked and tostring(level) or "?", Rect(frame))
end

function S.Toggles()
    Begin("status")
    Say("textures: " .. tostring(ns.db and ns.db.textureSource))
    for _, entry in ipairs(type(ns.TOGGLES) == "table" and ns.TOGGLES or {}) do
        Say("  " .. entry[1] .. " = " .. tostring(ns.db and ns.db[entry[1]]))
    end
    Finish()
end

---------------------------------------------------------------------------
-- debug
---------------------------------------------------------------------------

local WATCHED = Look.Words([[PlayerFrame TargetFrame FocusFrame PetFrame MinimapCluster Minimap MinimapBackdrop
    PlayerCastingBarFrame CharacterMicroButton MainMenuMicroButton MainMenuBarBackpackButton CharacterBag0Slot
    QueueStatusButton GameTimeFrame TimeManagerClockButton EraUIClassicBar]])

-- Every piece of art set (the Look files' and the art names the kept files
-- use share Look.artResults), and every piece and hook this client lacks
-- (the namespace's missing pieces are the same record as Look's).
local function ArtLines()
    local bad = {}
    for key, outcome in pairs(Look.artResults) do
        if outcome ~= "ok" then bad[#bad + 1] = key .. "=" .. tostring(outcome) end
    end
    table.sort(bad)
    Say("art not ok: " .. (#bad > 0 and table.concat(bad, ", ") or "none"))
    local missing, seen = {}, {}
    local function Add(text)
        if seen[text] then return end
        seen[text] = true
        missing[#missing + 1] = text
    end
    for name in pairs(type(ns.missing) == "table" and ns.missing or {}) do Add(tostring(name)) end
    for name in pairs(Look.missingPieces) do Add(tostring(name)) end
    for name in pairs(Look.missingHooks) do Add("hook " .. tostring(name)) end
    table.sort(missing)
    Say("missing pieces: " .. (#missing > 0 and table.concat(missing, ", ") or "none"))
end

local function BarLines()
    local bar = Look.MainBar()
    Say("main bar: " .. (bar and Called(bar) or "missing") .. "; "
        .. (type(ns.ClassicBarInfo) == "function" and tostring(select(2, Look.Try(ns.ClassicBarInfo))) or "no band"))
    Say("main bar " .. Rect(bar))
    Say("micro menu " .. Rect(_G.MicroMenuContainer or _G.MicroMenu))
    Say("bags bar " .. Rect(_G.BagsBar))
    if bar then
        local fine, alpha = Look.Ask(bar, "GetAlpha")
        local parent = bar.GetParent and bar:GetParent()
        Say(string.format("main bar %s alpha %s visible %s parent %s hideBarArt %s", Placed(bar), fine and Shown(alpha) or "?",
            tostring(bar:IsVisible()), parent and Called(parent) or "none", Shown(rawget(bar, "hideBarArt"))))
    end
    local button = _G.ActionButton1
    if button then
        local face = button.GetNormalTexture and button:GetNormalTexture()
        local asked, file = Look.Ask(face, "GetTexture")
        local icon = button.icon
        local masks = icon and icon.GetNumMaskTextures and select(2, Look.Ask(icon, "GetNumMaskTextures")) or nil
        Say(string.format("button 1 face %s %s alpha %s layer %s; slot art alpha %s; icon masks %s",
            asked and Shown(file) or "none", Rect(face), face and Shown(face:GetAlpha()) or "-",
            face and tostring((face:GetDrawLayer())) or "-", button.SlotArt and Shown(button.SlotArt:GetAlpha()) or "-",
            Shown(masks)))
    end
end

local function PowerLines()
    local own = type(ns.UnitFrameOwn) == "function" and ns.UnitFrameOwn(PlayerFrame, "power") or nil
    if own and own.GetStatusBarColor then
        local r, g, b = own:GetStatusBarColor()
        local _, high = own:GetMinMaxValues()
        local fill = own.GetStatusBarTexture and own:GetStatusBarTexture()
        local asked, file = Look.Ask(fill, "GetTexture")
        Say(string.format("power bar colour %s,%s,%s value %s of %s fill %s shown %s %s", Shown(r), Shown(g), Shown(b),
            Shown(own:GetValue()), Shown(high), asked and Shown(file) or "-", tostring(own:IsShown()), Rect(own)))
    else
        Say("power bar: none")
    end
    local kind, token = UnitPowerType("player")
    Say(string.format("power type %s token %s secret %s", Shown(kind), Look.Secret(token) and "?" or tostring(token),
        tostring(Look.Secret(token))))
    local mana = Look.Path(PlayerFrame, "PlayerFrameContent", "PlayerFrameContentMain", "ManaBarArea")
    local alternate = _G.AlternatePowerBar
    Say(string.format("mana area alpha %s, alternate power shown %s", mana and Shown(mana:GetAlpha()) or "-",
        alternate and tostring(alternate:IsShown()) or "-"))
    local art = Look.Path(PlayerFrame, "PlayerFrameContainer", "FrameTexture")
    if art then
        local fine, file = Look.Ask(art, "GetTexture")
        local asked, atlas = Look.Ask(art, "GetAtlas")
        Say(string.format("player frame art %s atlas %s %s", fine and Shown(file) or "-", asked and Shown(atlas) or "-", Rect(art)))
    end
end

local function WindowLines()
    if type(ns.SpellBookBindInfo) == "function" then
        local fine, info = Look.Try(ns.SpellBookBindInfo)
        if fine then Say("spellbook: " .. tostring(info)) end
    end
    for _, name in ipairs(Look.Words("FriendsFrame EraUIClassicSpellBook CharacterFrame PlayerSpellsFrame WorldMapFrame")) do
        local frame = _G[name]
        if frame then
            Say(string.format("%s protected %s shown %s", name, tostring(frame:IsProtected()), tostring(frame:IsShown())))
        else
            Say(name .. " missing")
        end
    end
    Say("secure snippets usable: " .. tostring(type(loadstring_untainted) == "function"))
end

local function RefusedLines()
    local record = Look.status and Look.status.blocked
    local list = type(record) == "table" and record or (type(ns.blocked) == "table" and ns.blocked or {})
    if #list == 0 then return Say("refused calls: none") end
    for i = 1, math.min(5, #list) do
        local entry = list[i]
        Say(string.format("refused: %s %s %s%s%s", tostring(entry.at or entry.time or "?"),
            tostring(entry.event or (entry.forbidden and "forbidden" or "blocked")), tostring(entry.call or entry.func or "?"),
            (entry.fighting or entry.combat) and " (in combat)" or "", (entry.editing or entry.editMode) and " (edit mode)" or ""))
    end
end

function S.Debug()
    Begin("debug")
    local version, build, _, toc = GetBuildInfo()
    Say(string.format("client %s build %s toc %s project %s", tostring(version), tostring(build), tostring(toc),
        tostring(WOW_PROJECT_ID)))
    Look.Try(BarLines)
    Look.Try(ArtLines)
    for _, name in ipairs(WATCHED) do Say(name .. " " .. Placed(_G[name])) end
    local cluster = MinimapCluster
    Say("tracking " .. Placed(cluster and cluster.Tracking) .. "; zoom in " .. Placed(Minimap and Minimap.ZoomIn))
    Say("mail " .. Placed(cluster and cluster.IndicatorFrame and cluster.IndicatorFrame.MailFrame))
    local bar = Look.MainBar()
    local pages = bar and bar.ActionBarPageNumber
    Say("page number " .. Placed(pages) .. "; up " .. Placed(pages and pages.UpButton))
    Look.Try(PowerLines)
    Look.Try(WindowLines)
    Look.Try(RefusedLines)
    if ns.needsReload then Say("a part was turned off this session; a reload clears its old art") end
    Finish()
end

---------------------------------------------------------------------------
-- bars, dmg, hit, targettrace
---------------------------------------------------------------------------

local function MeterLines(track)
    Say(Called(track) .. " " .. Rect(track) .. " bars " .. tostring(type(track.bars) == "table" and #track.bars or 0))
    for _, meter in ipairs(type(track.bars) == "table" and track.bars or {}) do
        local gauge = meter.StatusBar
        local atlas, rested
        if type(Look.StripNotes) == "function" then atlas, rested = Look.StripNotes(meter) end
        local fill = gauge and gauge.GetStatusBarTexture and gauge:GetStatusBarTexture()
        local fine, file = Look.Ask(fill, "GetTexture")
        local asked, fillAtlas = Look.Ask(fill, "GetAtlas")
        local r, g, b
        if gauge then r, g, b = gauge:GetStatusBarColor() end
        Say(string.format("  bar shown %s xp %s %s colour %s,%s,%s value %s fill %s atlas %s kept %s rested %s",
            tostring(meter:IsShown()), tostring(meter.ExhaustionTick ~= nil), Rect(meter), Shown(r), Shown(g), Shown(b),
            gauge and Shown(gauge:GetValue()) or "-", fine and Shown(file) or "-", asked and Shown(fillAtlas) or "-",
            Shown(atlas), Shown(rested)))
        local part = meter.ExhaustionLevelFillBar
        if part then
            Say(string.format("  rested fill shown %s width %s", tostring(part:IsShown()), Shown(part:GetWidth())))
        end
    end
end

function S.Bars()
    Begin("bars")
    Say(string.format("xp %s of %s, rest %s, state %s", Shown(UnitXP("player")), Shown(UnitXPMax("player")),
        Shown(GetXPExhaustion and GetXPExhaustion()), Shown(GetRestState and (GetRestState()))))
    for _, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
        local track = _G[name]
        if track then Look.Try(MeterLines, track) else Say(name .. " missing") end
    end
    Finish()
end

function S.DamageMeter()
    Begin("dmg")
    local meter = C_DamageMeter
    Say("damage meter API " .. tostring(type(meter) == "table") .. ", session enums "
        .. tostring(Enum ~= nil and Enum.DamageMeterSessionType ~= nil))
    if type(meter) ~= "table" then return Finish() end
    if type(C_CombatLog) == "table" and type(C_CombatLog.IsCombatLogRestricted) == "function" then
        Say("combat log restricted " .. Shown(select(2, pcall(C_CombatLog.IsCombatLogRestricted))))
    end
    if type(meter.IsDamageMeterAvailable) == "function" then
        local fine, yes, why = pcall(meter.IsDamageMeterAvailable)
        Say("available " .. (fine and Shown(yes) or "error") .. (why and (" (" .. Shown(why) .. ")") or ""))
    end
    local kinds = Enum and Enum.DamageMeterType
    if type(meter.GetCombatSessionFromType) == "function" and kinds and Enum.DamageMeterSessionType then
        local fine, session = pcall(meter.GetCombatSessionFromType, Enum.DamageMeterSessionType.Current, kinds.DamageDone)
        if fine and type(session) == "table" then
            local sources = type(session.combatSources) == "table" and session.combatSources or {}
            Say("current damage done total " .. Shown(session.totalAmount) .. ", sources " .. #sources)
            for _, source in ipairs(sources) do
                Say(string.format("  %s mine %s total %s class %s", Look.Secret(source.name) and "held back" or tostring(source.name),
                    Shown(source.isLocalPlayer), Shown(source.totalAmount), Look.Secret(source.classFilename) and "held back"
                    or tostring(source.classFilename)))
            end
        end
    end
    Finish()
end

function S.Hit()
    Begin("hit")
    local found = {}
    if type(GetMouseFoci) == "function" then
        local fine, list = pcall(GetMouseFoci)
        if fine and type(list) == "table" then found = list end
    elseif type(GetMouseFocus) == "function" then
        local fine, frame = pcall(GetMouseFocus)
        if fine and frame then found = { frame } end
    end
    if #found == 0 then Say("nothing under the mouse") end
    for _, frame in ipairs(found) do
        local parent = frame.GetParent and frame:GetParent()
        Say(string.format("%s mouse %s parent %s %s", Called(frame), tostring(frame.IsMouseEnabled and frame:IsMouseEnabled()),
            parent and Called(parent) or "none", Placed(frame)))
    end
    Finish()
end

-- targettrace: for 30 frames after each target change, every listed frame
-- whose place, size or shown state changes (developer sink only).
local TRACED = Look.Words([[UIParentBottomManagedFrameContainer UIParentRightManagedFrameContainer MainActionBar
    MultiBarBottomLeft MultiBarBottomRight MultiBarRight MultiBarLeft MultiBar5 MultiBar6 MultiBar7 StanceBar PetActionBar
    ChatFrame1 GeneralDockManager MainStatusTrackingBarContainer SecondaryStatusTrackingBarContainer EraUIClassicBar
    PlayerFrame TargetFrame MicroMenuContainer BagsBar ObjectiveTrackerFrame]])
local tracer, framesLeft, last = nil, 0, {}

local function Snapshot(frame)
    return { Look.Number(frame:GetLeft()) or 0, Look.Number(frame:GetBottom()) or 0, Look.Number(frame:GetWidth()) or 0,
        Look.Number(frame:GetHeight()) or 0, frame:IsShown() and 1 or 0 }
end

local function TraceFrame()
    framesLeft = framesLeft - 1
    if framesLeft <= 0 then tracer:SetScript("OnUpdate", nil) end
    for _, name in ipairs(TRACED) do
        local frame = _G[name]
        if type(frame) == "table" and frame.GetLeft then
            local now, was = Snapshot(frame), last[name]
            if was then
                for i = 1, 5 do
                    if math.abs(now[i] - was[i]) > 0.5 then
                        if type(ns.Persist) == "function" then
                            ns.Persist(string.format("trace %s %d,%d %dx%d shown %d (band %s strips %s)", name, now[1], now[2],
                                now[3], now[4], now[5], tostring(ns.bandPasses), tostring(ns.stripPasses)))
                        end
                        break
                    end
                end
            end
            last[name] = now
        end
    end
end

function S.TargetTrace()
    local saved = ns.db
    if not saved then return end
    saved.targetTrace = not saved.targetTrace or nil
    if not tracer then
        tracer = Look.Build("Frame", UIParent, nil, { size = { 1, 1 } })
        tracer:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        tracer:SetScript("OnEvent", function()
            if not ns.db or not ns.db.targetTrace then return end
            framesLeft, last = 30, {}
            tracer:SetScript("OnUpdate", TraceFrame)
        end)
    end
    if saved.targetTrace then Look.Listen(tracer, "PLAYER_TARGET_CHANGED") else tracer:UnregisterAllEvents() end
    Say("target trace " .. (saved.targetTrace and "on" or "off"))
end
