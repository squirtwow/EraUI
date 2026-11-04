-- A guild member, chosen (Classic look, spec 10 sections 8.11 and 8.12):
--   * the member box (EraUIClassicGuildMember), EraUI's own dialog to the
--     window's right: level and class, zone, rank with promote and demote
--     arrows, last online, the public and officer notes, and Remove, Group
--     Invite and (for the guild leader) Promote to Guild Master;
--   * the roster rows' clicks (left: the box; right: the menu; double: a
--     whisper) and the right-click menu.
-- Nothing is offered on your own line but your own public note. Writing a
-- note goes through the game's own member box (Look/GuildNotes.lua).
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Social
local G = S.guild
local parts = G.parts
local box = {} -- the member box's pieces
G.memberParts = box

local HINT = "Out of combat, click the member in the list, then click here to write the note."

local function Leader() return S.Yes(IsGuildLeader) end

function G.IsMe(entry)
    return ns.GuildIsMe(entry)
end

function G.MayEditPublic(entry)
    return S.Yes(CanEditPublicNote) or (entry ~= nil and G.IsMe(entry))
end

function G.MayEditOfficer()
    local info = C_GuildInfo
    return S.Yes(info and info.CanEditOfficerNote) or S.Yes(CanEditOfficerNote)
end

function G.MayViewOfficer()
    local info = C_GuildInfo
    return S.Yes(info and info.CanViewOfficerNote) or S.Yes(CanViewOfficerNote)
end

-- Whether the chosen member's note ("note" or "officer") may be written
-- (for the hint and the overlays).
function G.NoteMayEdit(which)
    local entry = G.Chosen()
    if not entry then return false end
    if which == "officer" then return G.MayEditOfficer() end
    return G.MayEditPublic(entry)
end

---------------------------------------------------------------------------
-- Acting on a member
---------------------------------------------------------------------------

local function Act(fn, entry)
    if type(fn) == "function" and entry and entry.name then S.Call(fn, entry.name) end
end

local function Info(method) return C_GuildInfo and C_GuildInfo[method] or nil end
local function Invite(entry) Act(C_PartyInfo and C_PartyInfo.InviteUnit, entry) end

---------------------------------------------------------------------------
-- The member box
---------------------------------------------------------------------------

local function InfoLine(holder, down, word, fallback)
    local line = Look.Build("Frame", holder, nil, { size = { 182, 14 } })
    line:SetPoint("TOPLEFT", holder, "TOPLEFT", 14, down)
    line:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -10, down)
    local label = Look.Label(line, "GameFontNormalSmall", "ARTWORK")
    S.Colour(label, S.GOLD)
    Look.Pin(label, "LEFT", line, "LEFT", 0, 0)
    label:SetText(S.Say(word, fallback) .. ":")
    local value = Look.Label(line, "GameFontHighlightSmall", "ARTWORK")
    Look.Pin(value, "LEFT", label, "RIGHT", 4, 0)
    value:SetJustifyH("LEFT")
    return line, value
end

local function Arrow(line, anchor, way, onClick)
    local arrow = Look.Build("Button", line, nil, { size = { 16, 16 } })
    Look.Pin(arrow, "LEFT", anchor, "RIGHT", anchor == box.rank and 6 or 2, 0)
    for face, look in pairs({ Normal = "Up", Pushed = "Down", Disabled = "Disabled", Highlight = "Highlight" }) do
        local texture = Look.StateArt(arrow, face, "scroll" .. way .. "Button" .. look)
        if texture then
            Look.Fill(texture, arrow)
            Look.Crop(texture, 0.25, 0.75, 0.25, 0.75)
            if face == "Highlight" then texture:SetBlendMode("ADD") end
        end
    end
    arrow:SetScript("OnClick", onClick)
    return arrow
end

local function NoteHint(owner, which)
    if not G.NoteMayEdit(which) then return end
    local label = which == "officer" and box.officerLabel or box.noteLabel
    Look.ShowTip(owner, "RIGHT", { { label:GetText() or "", 1, 1, 1 }, { HINT, 1, 0.82, 0, 220 } })
end

local function NoteBox(holder, down, word, fallback, which)
    local label = Look.Label(holder, "GameFontNormalSmall", "ARTWORK")
    S.Colour(label, S.GOLD)
    Look.Pin(label, "TOPLEFT", holder, "TOPLEFT", 14, down)
    label:SetText(fallback and S.Say(word, fallback) or word)
    local note = Look.Build("Button", holder, "BackdropTemplate", { size = { 178, 40 } })
    note:SetPoint("TOPLEFT", holder, "TOPLEFT", 14, down - 15)
    note:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -14, down - 15)
    note:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    note:SetBackdropColor(0, 0, 0, 0.85)
    note:SetBackdropBorderColor(0.78, 0.78, 0.78, 1)
    local text = Look.Label(note, "GameFontHighlightSmall", "ARTWORK")
    Look.Inside(text, note, 8, 6, 8, 6)
    text:SetJustifyH("LEFT")
    if text.SetJustifyV then text:SetJustifyV("TOP") end
    note:SetScript("OnEnter", function(self) NoteHint(self, which) end)
    note:SetScript("OnLeave", function(self) Look.HideTip(self) end)
    return label, note, text
end

local function Buttons(holder)
    local remove = Look.PanelButton(holder, S.Say("REMOVE", "Remove"), 90)
    Look.Pin(remove, "BOTTOMLEFT", holder, "BOTTOMLEFT", 14, 16)
    remove:SetScript("OnClick", function() Act(Info("Uninvite"), G.Chosen()) end)
    local invite = Look.PanelButton(holder, S.Say("GROUP_INVITE", "Group Invite"), 90)
    Look.Pin(invite, "LEFT", remove, "RIGHT", 4, 0)
    invite:SetScript("OnClick", function() Invite(G.Chosen()) end)
    local leader = Look.PanelButton(holder, "Promote to Guild Master", 186)
    Look.Pin(leader, "BOTTOMLEFT", holder, "BOTTOMLEFT", 14, 42)
    leader:SetScript("OnClick", function() Act(Info("SetLeader"), G.Chosen()) end)
    box.remove, box.invite, box.leader = remove, invite, leader
end

function G.BuildMember()
    if box.frame then return box.frame end
    local window = FriendsFrame
    local frame = Look.Build("Frame", window, "BackdropTemplate", { name = "EraUIClassicGuildMember", size = { 206, 250 },
        mouse = true, hidden = true })
    Look.Pin(frame, "TOPLEFT", window, "TOPRIGHT", -6, -70)
    frame:SetFrameLevel((Look.Number(window:GetFrameLevel()) or 1) + 10)
    frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    frame:SetBackdropColor(1, 1, 1, 1)
    frame:SetBackdropBorderColor(1, 1, 1, 1)
    if ns.DarkBackdrop then ns.DarkBackdrop(frame) end
    S.Own(frame)
    box.frame = frame
    local title = Look.Label(frame, "GameFontNormal", "ARTWORK")
    S.Colour(title, S.GOLD)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -20)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -20)
    title:SetJustifyH("LEFT")
    box.title = title
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    Look.SkinCloseButton(close)
    Look.Pin(close, "TOPRIGHT", frame, "TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() frame:Hide() end)
    box.close = close
    local level = Look.Label(frame, "GameFontHighlightSmall", "ARTWORK")
    level:SetHeight(12)
    Look.Pin(level, "TOPLEFT", frame, "TOPLEFT", 14, -40)
    box.level = level
    local zoneLine, rankLine
    zoneLine, box.zone = InfoLine(frame, -56, "ZONE", "Zone")
    rankLine, box.rank = InfoLine(frame, -74, "RANK", "Rank")
    box.lastLine, box.last = InfoLine(frame, -92, "LASTONLINE", "Last Online")
    box.zone:SetPoint("RIGHT", zoneLine, "RIGHT", 0, 0)
    box.last:SetPoint("RIGHT", box.lastLine, "RIGHT", 0, 0)
    box.promote = Arrow(rankLine, box.rank, "Up", function() Act(Info("Promote"), G.Chosen()) end)
    box.demote = Arrow(rankLine, box.promote, "Down", function() Act(Info("Demote"), G.Chosen()) end)
    box.noteLabel, box.note, box.noteText = NoteBox(frame, -112, S.Say("LABEL_NOTE", "Note") .. ":", nil, "note")
    local officerWord = S.Say("GUILD_OFFICERNOTE_LABEL", S.Say("OFFICER_NOTE_COLON", "Officer Note:"))
    box.officerLabel, box.officer, box.officerText = NoteBox(frame, -172, officerWord, nil, "officer")
    Buttons(frame)
    frame:SetScript("OnShow", function() G.UpdateMember() end)
    return frame
end

-- The box drawn for the chosen member (only while it shows).
function G.UpdateMember()
    local frame = box.frame
    if not frame or not frame:IsShown() then return end
    local entry = G.Chosen()
    local me = entry ~= nil and G.IsMe(entry)
    local other = entry ~= nil and not me
    local leader, viewOfficer = Leader(), G.MayViewOfficer()
    frame:SetHeight(216 + (viewOfficer and 60 or 0) + (leader and 26 or 0))
    box.title:SetText(entry and entry.name or S.Say("PLAYER_STATUS", "Player Status"))
    box.level:SetText(entry and (S.Say("LEVEL", "Level") .. " " .. entry.level .. " " .. entry.class) or "")
    box.zone:SetText(entry and entry.zone or "")
    box.rank:SetText(entry and entry.rank or "")
    box.last:SetText(entry and entry.lastText or "")
    local writable = S.notes.Writable and S.notes.Writable() or false
    local mayPublic, mayOfficer = G.MayEditPublic(entry), G.MayEditOfficer()
    local note = entry and entry.note or ""
    if note == "" and entry and mayPublic and writable then note = S.Say("GUILD_NOTE_EDITLABEL", "Click here to set a Public Note.") end
    box.noteText:SetText(note)
    local officer = entry and entry.officerNote or ""
    if officer == "" and entry and mayOfficer and writable then
        officer = S.Say("GUILD_OFFICERNOTE_EDITLABEL", "Click here to set an Officer's Note.")
    end
    box.officerText:SetText(officer)
    Look.Shown(box.officer, viewOfficer)
    Look.Shown(box.officerLabel, viewOfficer)
    box.promote:SetEnabled(other and S.Yes(CanGuildPromote))
    box.demote:SetEnabled(other and S.Yes(CanGuildDemote))
    box.remove:SetEnabled(other and S.Yes(CanGuildRemove))
    box.invite:SetEnabled(other and entry.online == true)
    Look.Shown(box.leader, leader)
    box.leader:SetEnabled(other and entry.online == true)
end

function G.HideMember()
    if box.frame then box.frame:Hide() end
end

---------------------------------------------------------------------------
-- The rows' clicks and the right-click menu
---------------------------------------------------------------------------

local function NotMe(entry) return entry ~= nil and not G.IsMe(entry) end
local function NotMeOnline(entry) return NotMe(entry) and entry.online == true end

function G.Menu()
    if G.menu then return G.menu end
    G.menu = S.RowMenu({
        { S.Say("WHISPER", "Whisper"), function(entry) Look.Whisper(entry and entry.name) end, NotMeOnline },
        { S.Say("INVITE", "Invite"), Invite, NotMeOnline },
        { S.Say("ADD_FRIEND", "Add Friend"), function(entry) Act(C_FriendList and C_FriendList.AddFriend, entry) end, NotMe },
        { S.Say("GUILD_PROMOTE", "Promote"), function(entry) Act(Info("Promote"), entry) end,
            function(entry) return NotMe(entry) and S.Yes(CanGuildPromote) end },
        { S.Say("GUILD_DEMOTE", "Demote"), function(entry) Act(Info("Demote"), entry) end,
            function(entry) return NotMe(entry) and S.Yes(CanGuildDemote) end },
        { S.Say("REMOVE", "Remove"), function(entry) Act(Info("Uninvite"), entry) end,
            function(entry) return NotMe(entry) and S.Yes(CanGuildRemove) end },
    })
    G.menu.Follow(parts.page)
    return G.menu
end

-- A member clicked (a row, or its secure overlay after the game's own row
-- was clicked through it).
function G.Click(entry, mouse)
    if not entry then return end
    G.selected = entry.index
    if mouse == "RightButton" then
        G.Fill()
        G.Menu().Open(entry, entry.name)
        G.UpdateMember()
        return
    end
    if not Look.InFight() then S.Call(SetGuildRosterSelection, entry.index) end
    G.Fill()
    local frame = G.BuildMember()
    if frame:IsShown() then G.UpdateMember() else frame:Show() end
    if S.notes.Check then Look.Try(S.notes.Check) end
end

function G.DoubleClick(entry)
    if entry and entry.online then Look.Whisper(entry.name) end
end

function G.RowClicked(row, mouse)
    G.Click(G.rowEntry[row], mouse)
end

function G.RowDoubleClicked(row)
    G.DoubleClick(G.rowEntry[row])
end
