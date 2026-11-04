-- The targets of target (TargetFrame.totFrame, FocusFrame.totFrame) in the
-- small 1.x frame: EraUI's own art, bars and backing, the name starting at
-- the bars. The frame itself is a protected unit button, so it is only moved
-- or re-scaled out of a fight. Its bars are filled on EraUI's own frame
-- (every 0.1 s and at once on a change of target), and its name is checked
-- for a moment after each change: the client never rewrites it when the
-- target of target becomes you, but a label another addon swaps in later
-- (a privacy addon) is left alone.
local _, EraUI = ...
local Look = EraUI.Look
local UF = Look.UF

local ART_CROP = { 0.015625, 0.7265625, 0, 0.703125 }
local DEBUFFS = { { -23, -8 }, { -10, -8 }, { -23, -21 }, { -10, -21 } }
local WINDOW = 0.5 -- seconds the name is watched after a change
local SPOT_X, SPOT_Y = 124, -69

---------------------------------------------------------------------------
-- Filling it
---------------------------------------------------------------------------

-- With surnames hidden a full name is trimmed at any time (the client
-- writes the full name here even when the target frame follows the
-- setting); otherwise only within the moment after a change.
local function CheckName(tot, record, changed)
    local name = UnitName(record.unit)
    if Look.Secret(name) or type(name) ~= "string" or name == "" then return end
    local now = GetTime()
    if name ~= record.lastName or changed then
        record.lastName = name
        record.watchUntil = now + WINDOW
    end
    local label = tot.Name
    local text = label and label:GetText()
    if not label or Look.Secret(text) then return end
    local hidden = UF.Setting("hideSecondaryNames") and true or false
    local withSurname = type(text) == "string" and #text > #name + 1 and text:sub(1, #name + 1) == name .. " "
    if hidden and withSurname then
        label:SetText(name)
        return
    end
    if now > (record.watchUntil or 0) then return end
    if text ~= name and not withSurname then label:SetText(name) end
end

local function Fill(tot, record, changed)
    if not UF.active or not record.health then return end
    if not UF.Exists(record.unit) then
        UF.Empty(record.health)
        UF.Empty(record.power)
        record.lastName = nil
        return
    end
    UF.FillHealth(record.health, record.unit)
    UF.FillPower(record.power, record.unit)
    CheckName(tot, record, changed)
end

-- The art holder's own checks: every 0.1 s, and at once (as a change) when
-- it shows or the target, the focus or the owner's target changes.
local function Watch(holder, tot, record)
    local waited = 0
    holder:SetScript("OnUpdate", function(_, elapsed)
        waited = waited + (elapsed or 0)
        if waited < 0.1 then return end
        waited = 0
        Fill(tot, record, false)
    end)
    holder:SetScript("OnShow", function() Fill(tot, record, true) end)
    holder:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_TARGET" and unit ~= record.ownerUnit then return end
        Fill(tot, record, true)
    end)
    for _, event in ipairs(Look.Words("PLAYER_TARGET_CHANGED PLAYER_FOCUS_CHANGED UNIT_TARGET")) do
        Look.Listen(holder, event)
    end
end

---------------------------------------------------------------------------
-- Dressing
---------------------------------------------------------------------------

local function Art(tot, record)
    local art = record.art
    Look.Art(art, "targetOfTarget")
    art:SetTexCoord(ART_CROP[1], ART_CROP[2], ART_CROP[3], ART_CROP[4])
    art:SetSize(93, 45)
    UF.KeepAt(art, "TOPLEFT", tot, "TOPLEFT", 0, 0)
    art:Show()
end

local function NamePlace(tot, record)
    local name = tot.Name
    if not name then return end
    if name:GetParent() ~= record.artHolder then name:SetParent(record.artHolder) end
    UF.KeepAt(name, "BOTTOMLEFT", record.art, "BOTTOMLEFT", 42, 3)
    -- Forever's template centres it in its 100-wide box, well right of the bars.
    if name:GetJustifyH() ~= "LEFT" then name:SetJustifyH("LEFT") end
end

local function Highest(...)
    local top = 0
    for i = 1, select("#", ...) do
        local frame = select(i, ...)
        if frame then top = math.max(top, UF.Level(frame)) end
    end
    return top
end

-- Out of a fight only: TOPLEFT on the owner's at (124, -69), or Thick
-- Frames' spot, divided by its own scale; back at scale 1 in the owner's
-- small mode.
function UF.PlaceToT(owner, tot)
    if Look.InFight() or not owner or not tot then return end
    local scale = Look.Number(tot:GetScale())
    if not scale or scale <= 0 then scale = 1 end
    if owner.smallSize and math.abs(scale - 1) > 0.01 then
        Look.Rescale(tot, 1)
        scale = 1
    end
    local y = UF.ThickWorn(owner) and UF.ThickNumber("TOT_Y", -92) or SPOT_Y
    local x = SPOT_X / scale
    y = y / scale
    if UF.OnlyPointIs(tot, "TOPLEFT", owner, "TOPLEFT", x, y) then return end
    tot:ClearAllPoints()
    tot:SetPoint("TOPLEFT", owner, "TOPLEFT", x, y)
end

function UF.DressToT(owner, ownerKind, ownerUnit)
    local tot = owner and owner.totFrame
    if not tot then return end
    local record = UF.Note(tot)
    record.ownerUnit = ownerUnit
    record.unit = type(tot.unit) == "string" and tot.unit or (ownerUnit .. "target")
    local holder = record.artHolder
    if not holder then
        holder = UF.Cover(tot)
        record.artHolder = holder
        Watch(holder, tot, record)
    end
    holder:Show()
    UF.SetLevel(holder, Highest(tot, tot.HealthBar, tot.ManaBar) + 1)
    UF.OwnTexture(record, "art", holder, "ARTWORK")
    Art(tot, record)
    Look.Fade(tot.FrameTexture)
    local portrait = tot.Portrait
    if portrait then
        portrait:SetSize(35, 35)
        Look.Pin(portrait, "TOPLEFT", tot, "TOPLEFT", 5, -5)
    end
    local name = tot.Name
    if name then
        name:SetParent(holder)
        name:SetWidth(100)
        name:SetJustifyH("LEFT")
        Look.Pin(name, "BOTTOMLEFT", record.art, "BOTTOMLEFT", 42, 3)
    end
    local backing = UF.Backing(record, tot, 46, 15, tot, 45, -15)
    Look.Fade(tot.HealthBar)
    Look.Fade(tot.ManaBar)
    record.barHost = record.barHost or UF.Cover(tot)
    record.barHost:Show()
    local health = UF.OwnBar(record, "health", record.barHost, 46, 7, 45, -15, { 0, 1, 0 })
    local power = UF.OwnBar(record, "power", record.barHost, 46, 7, 45, -23, { 0, 0, 1 })
    -- The art draws over the bars.
    UF.SetLevel(holder, math.max(Highest(health, power), UF.Level(holder) - 2) + 2)
    local called = tot:GetName()
    if type(called) == "string" then
        for i, spot in ipairs(DEBUFFS) do
            local debuff = _G[called .. "Debuff" .. i]
            if debuff then Look.Pin(debuff, "TOPLEFT", tot, "TOPRIGHT", spot[1], spot[2]) end
        end
    end
    if UF.ThickWant(ownerKind) and UF.ThickWant("tot") then
        UF.ThickCall("Tot", tot, record.art, backing, health, power)
    else
        UF.ThickCall("Off", tot)
    end
    UF.PlaceToT(owner, tot)
    Fill(tot, record, true)
end

-- On the owner's keeper pass, while it shows.
function UF.KeepToT(owner)
    local tot = owner and owner.totFrame
    local record = UF.Peek(tot)
    if not record or not record.art or not tot:IsShown() then return end
    Look.Fade(tot.FrameTexture)
    Look.Fade(tot.HealthBar)
    Look.Fade(tot.ManaBar)
    if UF.ThickWorn(tot) then
        UF.ThickCall("KeepTot", tot)
    else
        Art(tot, record)
        NamePlace(tot, record)
    end
    UF.PlaceToT(owner, tot)
end

function UF.RestoreToT(owner)
    local tot = owner and owner.totFrame
    if not tot then return end
    UF.ThickCall("Off", tot)
    local record = UF.Peek(tot)
    if record then
        if record.artHolder then record.artHolder:Hide() end
        if record.barHost then record.barHost:Hide() end
        Look.Shown(record.backing, false)
    end
    Look.Alpha(tot.FrameTexture, 1)
    Look.Alpha(tot.HealthBar, 1)
    Look.Alpha(tot.ManaBar, 1)
end
