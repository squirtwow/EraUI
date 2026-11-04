-- Writing guild notes and the message of the day through the game's own
-- guild window (Classic look, spec 10 section 9). EraUI's member box can't
-- write notes; the game's Communities window can. So while the Guild page is
-- up and you may write a note, the game's guild window is kept open but
-- invisible (alpha 0, parked far off the screen, taking no room in the
-- game's window layout), and secure click overlays of EraUI's own lie over
-- the roster rows, the note boxes and the message box: a click first clicks
-- the game's own member row (or its message editor) through the game's own
-- secure click, then EraUI's row logic runs. When the game's member box
-- shows the member you picked, it is moved into the member box's place.
-- ns.guildGhost is true exactly while that hidden window is open (EraUI's
-- window manager and the micro button's pressed look treat it as closed).
-- Everything here happens out of a fight; the overlays stand aside just
-- before one starts.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Social
local G = S.guild
local N = S.notes

N.open, N.live, N.docked, N.stale = false, false, false, true
N.failedAt, N.readAt = -10, -10
N.rows = {}
local rowPads, notePads = {}, {}
local padTarget = Look.Weak() -- overlay: the game's button it clicks
local dressed = Look.Weak()   -- the game's member box, dressed once

local function Window() return CommunitiesFrame end

local function ClubId()
    local club = C_Club
    local fine, id = S.Call(club and club.GetGuildClubId)
    if not fine or id == nil or Look.Secret(id) then return nil end
    return id
end

local function MaySomeNote()
    if S.Yes(CanEditPublicNote) or G.MayEditOfficer() then return true end
    local entry = G.Chosen()
    return entry ~= nil and G.IsMe(entry)
end

function N.Wanted()
    local page = G.parts.page
    return G.active == true and page ~= nil and page:IsVisible() and G.InGuild() and MaySomeNote()
end

---------------------------------------------------------------------------
-- The hidden window
---------------------------------------------------------------------------

function N.WantedHeight()
    local listed = G.ShowOffline() and G.total or G.onlineCount
    listed = math.min(Look.Number(listed) or 0, 500)
    return 91 + (listed + 12) * 20
end

-- Parked off the screen: one anchor, re-set only when it moved.
function N.Park()
    local hidden = Window()
    if not (N.open and hidden) or Look.InFight() then return end
    local point, relative, relativePoint, x, y = hidden:GetPoint(1)
    local parked = (Look.Number(hidden:GetNumPoints()) or 0) == 1 and point == "TOPLEFT" and relative == UIParent
        and relativePoint == "TOPRIGHT" and Look.Number(x) == 4000 and Look.Number(y) == 0
    if not parked then Look.Pin(hidden, "TOPLEFT", UIParent, "TOPRIGHT", 4000, 0) end
end

local function SetClub(club)
    local cvars = C_CVar
    local set = (type(cvars) == "table" and cvars.SetCVar) or SetCVar
    S.Call(set, "lastSelectedClubId", tostring(club))
end

function N.Open()
    if Look.InFight() then return end
    if not Window() and C_AddOns then S.Call(C_AddOns.LoadAddOn, "Blizzard_Communities") end
    local window = Window()
    if not (window and window.MemberList and window.GuildMemberDetailFrame and type(ShowUIPanel) == "function") then return end
    if N.open then
        if not window:IsShown() then return N.PutAway() end
        N.Park()
        local wanted = N.WantedHeight()
        if (Look.Number(window:GetHeight()) or 0) < wanted then window:SetHeight(wanted) end
        return
    end
    -- Never over a guild window the player has open; not again for 2 s
    -- after one that wouldn't open.
    if window:IsShown() or S.Now() - N.failedAt < 2 then return end
    local club = ClubId()
    if not club then return end
    N.saved = { alpha = Look.Number(window:GetAlpha()) or 1, width = Look.Number(window:GetWidth()),
        height = Look.Number(window:GetHeight()), strata = window:GetFrameStrata(),
        layout = window:GetAttribute("UIPanelLayout-width") }
    N.open = true
    ns.guildGhost = true
    window:SetAlpha(0)
    window:SetHeight(N.WantedHeight())
    window:SetAttribute("UIPanelLayout-width", 1)
    SetClub(club)
    Look.Try(ShowUIPanel, window)
    if not window:IsShown() then
        N.failedAt = S.Now()
        return N.PutAway()
    end
    N.Park()
end

-- The game's member box given back to its own window, hidden.
function N.GiveBack()
    local owner = Window()
    local memberBox = owner and owner.GuildMemberDetailFrame
    if not (memberBox and N.docked) then return end
    N.docked = false
    memberBox:Hide()
    memberBox:SetParent(owner)
    memberBox:SetFrameStrata(owner:GetFrameStrata())
    memberBox:SetFrameLevel(1000)
    Look.Pin(memberBox, "TOPLEFT", owner, "TOPRIGHT", -8, -76)
end

function N.PutAway()
    if Look.InFight() then return end
    N.HideOverlays()
    N.rows, N.live, N.stale = {}, false, true
    ns.guildGhost = false
    N.GiveBack()
    local window, wasOpen, saved = Window(), N.open, N.saved
    N.open, N.saved = false, nil
    if not (window and wasOpen) then return end
    if window:IsShown() and type(HideUIPanel) == "function" then Look.Try(HideUIPanel, window) end
    if saved then
        window:SetAttribute("UIPanelLayout-width", saved.layout)
        if saved.width then window:SetWidth(saved.width) end
        if saved.height then window:SetHeight(saved.height) end
        window:SetAlpha(saved.alpha or 1)
    end
end

---------------------------------------------------------------------------
-- The game's member rows, by GUID
---------------------------------------------------------------------------

function N.ReadRows()
    local window = Window()
    if not (N.open and window) then return end
    if not N.stale and S.Now() - N.readAt < 2 then return end
    local club = ClubId()
    local fine, chosen = Look.Ask(window, "GetSelectedClubId")
    if not club or not fine or Look.Secret(chosen) or chosen ~= club then return end
    N.readAt, N.stale = S.Now(), false
    local rows = {}
    local function Take(row)
        if type(row) ~= "table" or row.isInvitation or type(row.GetMemberInfo) ~= "function" then return end
        local ok, info = pcall(row.GetMemberInfo, row)
        local guid = ok and type(info) == "table" and info.guid or nil
        if type(guid) == "string" and not Look.Secret(guid) then rows[guid] = row end
    end
    local scroll = window.MemberList and window.MemberList.ScrollBox
    if scroll and type(scroll.ForEachFrame) == "function" then
        pcall(scroll.ForEachFrame, scroll, Take)
    elseif scroll and type(scroll.GetFrames) == "function" then
        local ok, frames = pcall(scroll.GetFrames, scroll)
        if ok and type(frames) == "table" then for _, row in ipairs(frames) do Take(row) end end
    end
    N.rows = rows
end

function N.RowFor(entry)
    return entry and entry.guid and N.rows[entry.guid] or nil
end

---------------------------------------------------------------------------
-- The game's member box in EraUI's member box's place ("live")
---------------------------------------------------------------------------

local function GameMemberBox()
    return Look.Path(Window(), "GuildMemberDetailFrame")
end

function N.LiveNow()
    local memberBox, page, entry = GameMemberBox(), G.parts.page, G.Chosen()
    if not (N.open and memberBox and memberBox:IsShown() and page and page:IsVisible() and entry and entry.guid) then
        return false
    end
    local fine, shows = Look.Ask(memberBox, "GetMemberInfo")
    local guid = fine and type(shows) == "table" and shows.guid or nil
    return type(guid) == "string" and not Look.Secret(guid) and guid == entry.guid
end

-- Notes can be written right now (the member box's "Click here to set...").
function N.Writable()
    if N.live then return true end
    return N.open and N.RowFor(G.Chosen()) ~= nil and not Look.InFight()
end

-- Its border greyed, the note backgrounds white and grey, the 1.x X and
-- red buttons (once).
local NOTE_BACKS = Look.Words("NoteBackground OfficerNoteBackground")

-- Every region of a holder but one, greyed (and, white, made plain white).
local function Grey(holder, spared, white)
    Look.EachRegion(holder, function(region)
        if region == spared or not region.SetDesaturated then return end
        region:SetDesaturated(true)
        if white then region:SetVertexColor(1, 1, 1) end
    end)
end

local function Dress(memberBox)
    if dressed[memberBox] then return end
    dressed[memberBox] = true
    local frameArt = memberBox.Border
    if frameArt then Grey(frameArt, frameArt.Bg, false) end
    for i = 1, #NOTE_BACKS do
        local back = memberBox[NOTE_BACKS[i]]
        if back then
            Grey(back, back.Center, true)
            if back.NineSlice then Grey(back.NineSlice, back.NineSlice.Center, true) end
        end
    end
    if memberBox.CloseButton then Look.Try(Look.SkinCloseButton, memberBox.CloseButton) end
    if memberBox.RemoveButton then Look.Try(Look.SkinRedButton, memberBox.RemoveButton) end
    if memberBox.GroupInviteButton then Look.Try(Look.SkinRedButton, memberBox.GroupInviteButton) end
end

-- The game's member box in the member box's spot, on top.
local function Dock(memberBox)
    memberBox:SetParent(UIParent)
    memberBox:SetFrameStrata("HIGH")
    Look.Pin(memberBox, "TOPLEFT", FriendsFrame, "TOPRIGHT", -6, -70)
    memberBox:SetAlpha(1)
    Look.Try(Dress, memberBox)
    N.docked = true
end

---------------------------------------------------------------------------
-- The secure overlays (made, set, moved and shown out of a fight only)
---------------------------------------------------------------------------

-- A secure button of EraUI's on UIParent: a click (on release) clicks
-- whatever button its "clickbutton" names. clickType: "type1" (the left
-- button only) or "type" (any).
local function Overlay(name, clickType)
    local overlay = Look.Build("Button", UIParent, "SecureActionButtonTemplate", { name = name, size = { 10, 10 },
        strata = "HIGH", hidden = true })
    for attribute, value in pairs({ [clickType or "type1"] = "click", useOnKeyDown = false }) do
        overlay:SetAttribute(attribute, value)
    end
    overlay:RegisterForClicks("AnyUp", "AnyDown")
    return overlay
end

local lastLeft = { index = nil, at = -10 }

-- A row's overlay released: EraUI's own row click (a second left release on
-- the same member within 0.4 s is a double-click).
local function RowReleased(i, mouse)
    local row = G.parts.rows and G.parts.rows[i]
    local entry = row and G.rowEntry[row]
    if not entry then return end
    local now = S.Now()
    if mouse == "LeftButton" and lastLeft.index == entry.index and now - lastLeft.at <= 0.4 then
        lastLeft.index = nil
        G.DoubleClick(entry)
        return
    end
    if mouse == "LeftButton" then lastLeft.index, lastLeft.at = entry.index, now end
    G.Click(entry, mouse)
end

local function RowPad(i)
    if rowPads[i] then return rowPads[i] end
    local pad = Overlay("EraUIClassicGuildRowPad" .. i)
    local glow = Look.OwnTexture(pad, "glow", "HIGHLIGHT")
    S.RowGlow(glow)
    Look.Fill(glow, pad)
    pad:SetScript("PostClick", function(_, mouse, down) if not down then RowReleased(i, mouse) end end)
    rowPads[i] = pad
    return pad
end

local function NotePad(which)
    if notePads[which] then return notePads[which] end
    local pad = Overlay(which == "officer" and "EraUIClassicGuildOfficerPad" or "EraUIClassicGuildNotePad")
    pad:SetScript("PostClick", function(_, _, down) if not down then Look.Try(N.Check) end end)
    notePads[which] = pad
    return pad
end

-- An overlay exactly over one of EraUI's frames (in UIParent's units),
-- clicking target; hidden when that frame can't be placed.
local function Cover(overlay, over, target)
    local left, bottom, right, top = Look.Rect(over)
    if left == nil then return overlay:Hide() end
    if padTarget[overlay] ~= target then
        overlay:SetAttribute("clickbutton", target)
        padTarget[overlay] = target
    end
    Look.Pin(overlay, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    overlay:SetSize(right - left, top - bottom)
    overlay:SetFrameStrata("HIGH")
    overlay:Show()
end

-- force: at the fight's start (the game's lockdown begins just after it).
function N.HideOverlays(force)
    if Look.InFight() and not force then return end
    for _, overlay in pairs(rowPads) do overlay:Hide() end
    for _, overlay in pairs(notePads) do overlay:Hide() end
    if N.motdPad then N.motdPad:Hide() end
end

function N.LayOverlays()
    if Look.InFight() then return end
    for i, row in ipairs(G.parts.rows or {}) do
        local entry = G.rowEntry[row]
        local target = N.open and entry and row:IsVisible() and N.RowFor(entry) or nil
        if target then
            Cover(RowPad(i), row, target)
        else
            if rowPads[i] then rowPads[i]:Hide() end
            if N.open and entry and row:IsVisible() then N.stale = true end
        end
    end
    local member = G.memberParts
    local target = N.RowFor(G.Chosen())
    for _, which in ipairs({ "note", "officer" }) do
        local over = which == "officer" and member.officer or member.note
        local wanted = target and not N.live and member.frame and member.frame:IsVisible() and over and over:IsVisible()
            and G.NoteMayEdit(which)
        if wanted then
            Cover(NotePad(which), over, target)
        elseif notePads[which] then
            notePads[which]:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- The state check: every 0.25 s while the window is open or the page shows,
-- and after every row fill
---------------------------------------------------------------------------

function N.Check()
    if Look.InFight() then return end
    if not N.Wanted() then
        if N.open then N.PutAway() else N.HideOverlays() end
        return
    end
    N.Open()
    if not N.open then return N.HideOverlays() end
    N.ReadRows()
    local live = N.LiveNow()
    if live then
        if not N.docked then Dock(GameMemberBox()) end
        G.HideMember()
    elseif N.docked then
        N.GiveBack()
    end
    if live ~= N.live then
        N.live = live
        G.UpdateMember()
    end
    N.LayOverlays()
end

---------------------------------------------------------------------------
-- The message of the day's overlay (every 0.2 s, out of a fight)
---------------------------------------------------------------------------

local function EditButton()
    return Look.Path(CommunitiesFrame, "GuildDetailsFrame", "Info", "EditMOTDButton")
end

local function MotdPad()
    if N.motdPad then return N.motdPad end
    if not EditButton() and C_AddOns then S.Call(C_AddOns.LoadAddOn, "Blizzard_Communities") end
    local editor = EditButton()
    if not editor then return nil end
    N.motdPad = Overlay("EraUIClassicMotdPad", "type")
    N.motdPad:SetAttribute("clickbutton", editor)
    return N.motdPad
end

function N.MotdCheck()
    if Look.InFight() then return end
    local page, info = G.parts.page, C_GuildInfo
    local mayEdit = S.Yes(CanEditMOTD) or S.Yes(info and info.CanEditMOTD)
    local box = G.parts.messageBox
    local overlay = (G.active and page and page:IsVisible() and mayEdit and box) and MotdPad() or nil
    if overlay then
        local left, bottom, right, top = Look.Rect(box)
        if left then
            Look.Pin(overlay, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
            overlay:SetSize(right - left, top - bottom)
            overlay:Show()
            return
        end
    end
    if N.motdPad then N.motdPad:Hide() end
end

---------------------------------------------------------------------------
-- The watchers (started with the page)
---------------------------------------------------------------------------

function N.Start()
    if N.started then return end
    N.started = true
    Look.Every(0, function() if N.open then N.Park() end end)
    Look.Every(0.25, function()
        local page = G.parts.page
        if N.open or (page and page:IsVisible()) then N.Check() end
    end)
    Look.Every(0.2, N.MotdCheck)
    local fightStarts = CreateFrame("Frame")
    Look.Listen(fightStarts, "PLAYER_REGEN_DISABLED")
    fightStarts:SetScript("OnEvent", function() N.HideOverlays(true) end)
end
