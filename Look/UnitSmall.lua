-- The pet frame and the party frames in their small 1.x dress (Classic look,
-- "unitFrames" with unitFramePet / unitFrameParty). The pet keeps the game's
-- own bars, restyled; each party member (Forever's non-raid-style party
-- frames) gets EraUI's bars. Both are protected frames: dressed out of a
-- fight only. Their keepers put the 1.x art back when the game redraws its
-- own (a new pet, a roster change, a vehicle), in fights too.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local UF = Look.UF

local FULL = UF.FULL
local FLIPPED = { 0, 1, 1, 0 }
local ROLE_X, ROLE_Y = 7, -41

---------------------------------------------------------------------------
-- The pet
---------------------------------------------------------------------------

-- The pet's two bars by name (their mask and three texts are named after
-- them), which they are, and their y.
local PET_BARS = {
    { "PetFrameHealthBar", "health", -22 },
    { "PetFrameManaBar", "power", -29 },
}

-- Only a fill and a colour, so it is safe in a fight: green health, the 1.x
-- colour of the bar's unit (or its frame's) for power.
function UF.RepaintPet()
    local fill = Look.BarFill("statusBar")
    for bar, which in pairs(UF.petBars) do
        bar:SetStatusBarTexture(fill)
        if which == "health" then
            bar:SetStatusBarColor(0, 1, 0)
        else
            local unit = bar.unit
            if type(unit) ~= "string" then
                local frame = bar:GetParent()
                unit = frame and frame.unit
            end
            if type(unit) == "string" then bar:SetStatusBarColor(Look.PowerColor(unit)) end
        end
    end
end

function UF.DressPet()
    if Look.InFight() then
        UF.waiting = true
        return
    end
    local frame = PetFrame
    if not frame then return end
    local record = UF.Note(frame)
    UF.petDressed = true
    frame:SetSize(128, 53)
    if PetPortrait then Look.Pin(PetPortrait, "TOPLEFT", frame, "TOPLEFT", 7, -6) end
    if PetName then
        PetName:SetWidth(0)
        Look.Pin(PetName, "BOTTOMLEFT", frame, "BOTTOMLEFT", 53, 33)
    end
    UF.Dress(PetFrameTexture, "smallTargetingFrame", FULL, 128, 64, "TOPLEFT", frame, "TOPLEFT", 0, -2)
    if PetFrameFlash then
        UF.Dress(PetFrameFlash, "partyFlash", FLIPPED, 128, 64, "TOPLEFT", frame, "TOPLEFT", -4, 11, "BACKGROUND")
        UF.HoldGlow(PetFrameFlash)
    end
    local holder = UF.Holder(frame, record, UF.Level(frame) + 3)
    for _, entry in ipairs(PET_BARS) do
        local called, which, y = entry[1], entry[2], entry[3]
        local bar = _G[called]
        if bar then
            bar:SetSize(69, 8)
            Look.Pin(bar, "TOPLEFT", frame, "TOPLEFT", 47, y)
            Look.Fade(_G[called .. "Mask"])
            UF.MoveText(_G[called .. "Text"], holder, bar, "CENTER", 0, 0)
            UF.MoveText(_G[called .. "TextLeft"], holder, bar, "LEFT", 3, 0)
            UF.MoveText(_G[called .. "TextRight"], holder, bar, "RIGHT", -3, 0)
            UF.petBars[bar] = which
        end
    end
    UF.RepaintPet()
    UF.Dress(PetAttackModeTexture, "petAttackStatus", { 0.703125, 1, 0, 1 }, 76, 64, "TOPLEFT", frame, "TOPLEFT", 6, -9)
    if PetHitIndicator then Look.Pin(PetHitIndicator, "CENTER", frame, "TOPLEFT", 28, -27) end
    if UF.ThickWant("pet") then UF.ThickCall("Pet", frame) else UF.ThickCall("Off", frame) end
end

function UF.KeepPet()
    if not UF.petDressed or not PetFrame or not PetFrameTexture then return end
    if UF.ArtState(PetFrameTexture, PetFrame, 0, -2) == "fine" then return end
    if Look.InFight() then UF.waiting = true else UF.DressPet() end
end

---------------------------------------------------------------------------
-- The party
---------------------------------------------------------------------------

function UF.PartyMembers()
    local pool = Look.Path(PartyFrame, "PartyMemberFramePool")
    local list = {}
    if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
        for member in pool:EnumerateActive() do list[#list + 1] = member end
    end
    return list
end

-- The member's 1.x art: frame, portrait, name (unless Thick Frames keeps it), flash.
local function MemberArt(member, keepName)
    UF.Dress(member.Texture, "partyFrame", FULL, 128, 64, "TOPLEFT", member, "TOPLEFT", 0, -10, "ARTWORK", 7)
    if member.Portrait then Look.Pin(member.Portrait, "TOPLEFT", member, "TOPLEFT", 7, -14) end
    if keepName and UF.ThickWorn(member) then
        UF.ThickCall("KeepParty", member)
    elseif member.Name then
        Look.Pin(member.Name, "TOPLEFT", member, "TOPLEFT", 49, -7)
    end
    UF.Dress(member.Flash, "partyFlash", FULL, 128, 64, "TOPLEFT", member, "TOPLEFT", -3, -6, "BACKGROUND", 0)
end

local function MemberBars(member, record, host, holder)
    local health = UF.OwnBar(record, "health", host, 70, 10, 45, -19, { 0, 1, 0 })
    local power = UF.OwnBar(record, "power", host, 74, 7, 41, -30)
    local box = member.HealthBarContainer
    Look.Fade(box)
    local gameHealth = box and box.HealthBar
    if gameHealth then
        UF.Pin(gameHealth, health)
        UF.TakeOverlays(gameHealth, health, box.HealthBarMask)
    end
    if box then
        UF.MoveText(box.CenterText, holder, health, "CENTER", 0, 0)
        UF.MoveText(box.LeftText, holder, health, "LEFT", 3, 0)
        UF.MoveText(box.RightText, holder, health, "RIGHT", -3, 0)
    end
    local mana = member.ManaBar
    if mana then
        Look.Fade(mana)
        UF.Pin(mana, power)
        UF.MoveText(mana.CenterText, holder, power, "CENTER", 2, 0)
        UF.MoveText(mana.LeftText, holder, power, "LEFT", 7, 0)
        UF.MoveText(mana.RightText, holder, power, "RIGHT", -3, 0)
    end
    return health, power
end

-- The role icon's home: one point, at the portrait's foot.
local function KeepRole(member)
    local role = Look.Path(member, "PartyMemberOverlay", "RoleIcon")
    if role then UF.KeepAt(role, "TOPLEFT", member, "TOPLEFT", ROLE_X, ROLE_Y) end
end

function UF.DressMember(member)
    if Look.InFight() then
        UF.waiting = true
        return
    end
    local record = UF.Note(member)
    record.unit = type(member.unit) == "string" and member.unit or "party1"
    UF.dressed[member] = "party"
    if member.Name then member.Name:SetWidth(0) end
    MemberArt(member, false)
    local backing = UF.Backing(record, member, 72, 20, member, 45, -19, -7)
    local host = UF.Host(member, record)
    UF.SetLevel(host, math.max(UF.Level(member) - 1, 0))
    local holder = UF.Holder(member, record, UF.Level(member) + 3)
    local health, power = MemberBars(member, record, host, holder)
    local overlay = member.PartyMemberOverlay
    if overlay then
        UF.Dress(overlay.LeaderIcon, "leaderIcon", FULL, 16, 16, "TOPLEFT", member, "TOPLEFT", 0, -8)
        if overlay.PVPIcon then Look.Pin(overlay.PVPIcon, "TOPLEFT", member, "TOPLEFT", -9, -23) end
        if overlay.RoleIcon then Look.Pin(overlay.RoleIcon, "TOPLEFT", member, "TOPLEFT", ROLE_X, ROLE_Y) end
    end
    if UF.ThickWant("party") then
        UF.ThickCall("Party", member, host, health, power, backing)
    else
        UF.ThickCall("Off", member)
    end
end

function UF.DressParty()
    if not UF.FrameOn("unitFrameParty") then return end
    for _, member in ipairs(UF.PartyMembers()) do Look.Try(UF.DressMember, member) end
end

local function PartyLater()
    if UF.active and UF.FrameOn("unitFrameParty") then UF.DressParty() end
end

-- Now, on the next frame and 0.3 s later (and 1 s later for roster and level changes).
function UF.DressPartySoon(alsoLater)
    UF.DressParty()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, PartyLater)
        C_Timer.After(0.3, PartyLater)
        if alsoLater then C_Timer.After(1, PartyLater) end
    end
end

-- Since build 70425 the party art (roster, member, vehicle) adds its own
-- anchor to the role icon and puts the frame's modern art back.
function UF.KeepParty()
    for _, member in ipairs(UF.PartyMembers()) do
        if UF.dressed[member] == "party" then
            local state = member.Texture and UF.ArtState(member.Texture, member, 0, -10) or "fine"
            if state ~= "fine" then
                MemberArt(member, true)
                if state == "undone" then
                    if Look.InFight() then UF.waiting = true else UF.DressMember(member) end
                end
            end
            KeepRole(member)
        end
    end
end

function UF.RestoreParty()
    for _, member in ipairs(UF.PartyMembers()) do
        UF.dressed[member] = nil
        UF.ThickCall("Off", member)
        local record = UF.Peek(member)
        if record then
            if record.host then record.host:Hide() end
            Look.Shown(record.backing, false)
        end
        Look.Alpha(member.HealthBarContainer, 1)
        Look.Alpha(member.ManaBar, 1)
    end
    ns.needsReload = true
end
