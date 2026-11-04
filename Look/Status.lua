-- The status report (/eraui-classic status or report, or the chat link offered
-- the first time the game blocks something EraUI did): one window with what a
-- bug report needs to start with, read fresh each time it opens, kept nowhere.
-- Built on first open. The text box is read-only; Select all and Ctrl+C copy it.
local addonName, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local status = { offered = false }
Look.status = status

local WRAP_AT = 78
local INDENT = "    "
local PLAIN_TYPES = { boolean = true, number = true, string = true }
-- Classic keys that only keep EraUI's own bookkeeping, never a choice: the
-- layout records, the one-time moves (Core/Integration.lua), the notes and
-- welcome seen, and the player's own simplified plates value kept to hand
-- back.
local BOOKKEEPING = {}
for _, key in ipairs(Look.Words([[dbVersion previousLayout layoutSelectPending layoutSelectTries microPosText welcomed
    layoutPrompted textureSource barDragged questLogPosText erauiMigrated erauiSettingsMenuMigrated
    erauiNumericSettingsMirrored erauiWelcomeSeen erauiSetupComplete updateNotesSeen welcomeNote
    savedSimplifiedTypes]])) do
    BOOKKEEPING[key] = true
end
-- Classic keys copied from /era on every pass (Core/Integration.lua): a
-- difference there is /era's own choice, listed as its eraui_ line, never
-- the player's here (the minimap button is always off: /era has its own).
local COPIED = {}
for _, key in ipairs(Look.Words("namePlates emptySlots spellBookTopRank hideLastNames minimapButton")) do
    COPIED[key] = true
end
local function Copied(key)
    local mapping = EraUI.classicMapping
    return COPIED[key] or (type(mapping) == "table" and mapping[key] ~= nil)
end
-- An /era choice's copy (eraui_<setting>) is measured against /era's own
-- default; a copy with none (a class reminder's, the game's own spell rank
-- switch) is left out.
local function EraDefault(key)
    local setting = key:match("^eraui_(.+)$")
    if not setting then return nil, false end
    local defaults = EraUI.settingDefaults
    if type(defaults) ~= "table" then return nil, true end
    return defaults[setting], true
end
local HOW_TO = table.concat({
    "Reporting a bug? Take a screenshot with this window and the problem both in it, or press Select all, copy with Ctrl+C, and paste the text into your report.",
    "Say what you did and what you expected.",
    "Use Discord below for support, bugs and ideas.",
}, " ")

---------------------------------------------------------------------------
-- What the game blocked this session (EraUI's own calls only)
---------------------------------------------------------------------------

-- Newest first, the last five: when, how, what, in a fight, Edit Mode open.
status.blocked = {}
local function Remember(_, event, who, what)
    if who ~= addonName then return end
    table.insert(status.blocked, 1, {
        at = type(date) == "function" and date("%H:%M:%S") or "?",
        forbidden = event == "ADDON_ACTION_FORBIDDEN",
        call = tostring(what or "?"),
        fighting = Look.InFight(),
        editing = Look.EditModeOpen(),
    })
    status.blocked[6] = nil
end
do
    local listener = Look.Build("Frame", nil)
    Look.Listen(listener, "ADDON_ACTION_BLOCKED")
    Look.Listen(listener, "ADDON_ACTION_FORBIDDEN")
    listener:SetScript("OnEvent", Remember)
end

---------------------------------------------------------------------------
-- The text
---------------------------------------------------------------------------

local function Readable(value)
    if Look.Secret(value) or value == nil then return "?" end
    return tostring(value)
end

-- A game function that may be missing, asked quietly: ok, then its results.
local function Quietly(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

local function Metadata(name, field)
    local ok, value = Quietly((C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata, name, field)
    return (ok and type(value) == "string" and value ~= "") and value or nil
end

-- The label, then the items, ", " after each but the last; a new indented
-- line whenever the next item would run the line past 78 characters (never
-- while the line is still only the label).
local function Wrapped(label, items)
    local done, current = {}, label
    for index = 1, #items do
        local word = items[index]
        if index < #items then word = word .. ", " end
        if current ~= label and #current + #word > WRAP_AT then
            done[#done + 1] = current
            current = INDENT .. word
        else
            current = current .. word
        end
    end
    done[#done + 1] = current
    return table.concat(done, "\n")
end

-- Every Classic setting with a plain default that differs from it, every
-- /era choice (its eraui_ copy) away from /era's default, and every
-- option-list key with no default that is off. EraUI's own bookkeeping and
-- the keys copied from /era are left out, so a player who changed nothing
-- reads "none, all as shipped".
local function Differs(key, now, default)
    if BOOKKEEPING[key] or Copied(key) or now == nil then return false end
    local shipped, mirrored = EraDefault(key)
    if mirrored then return shipped ~= nil and PLAIN_TYPES[type(shipped)] and now ~= shipped end
    return PLAIN_TYPES[type(default)] and now ~= default
end

local function SettingsDiff()
    local saved, defaults = ns.db, ns.DB_DEFAULTS
    local found = {}
    if type(saved) ~= "table" or type(defaults) ~= "table" then return found end
    local listed = {}
    for key, default in pairs(defaults) do
        local now = saved[key]
        if Differs(key, now, default) then
            found[#found + 1] = key .. "=" .. tostring(now)
            listed[key] = true
        end
    end
    for _, entry in ipairs(type(ns.TOGGLES) == "table" and ns.TOGGLES or {}) do
        local key = type(entry) == "table" and entry[1]
        if type(key) == "string" and not listed[key] and defaults[key] == nil and saved[key] == false
            and Differs(key, false, true) then
            found[#found + 1] = key .. "=false"
        end
    end
    table.sort(found)
    return found
end

-- Every loaded addon but EraUI and Blizzard's own, as "Name Version".
local function AddonList()
    local api = C_AddOns or {}
    local found = {}
    local ok, total = Quietly(api.GetNumAddOns or GetNumAddOns)
    for index = 1, (ok and Look.Number(total)) or 0 do
        local named, title = Quietly(api.GetAddOnInfo or GetAddOnInfo, index)
        local asked, loaded = Quietly(api.IsAddOnLoaded or IsAddOnLoaded, index)
        if named and asked and loaded and type(title) == "string" and title ~= addonName and not title:find("^Blizzard_") then
            local version = Metadata(title, "Version")
            found[#found + 1] = version and (title .. " " .. version) or title
        end
    end
    table.sort(found)
    return found
end

local function BlockedSection()
    local list = status.blocked
    if #list == 0 then return "Blocked by the game this session: nothing" end
    local out = { "Blocked by the game this session:" }
    for _, entry in ipairs(list) do
        out[#out + 1] = string.format("%s%s %s %s%s%s", INDENT, entry.at, entry.forbidden and "forbidden" or "blocked", entry.call,
            entry.fighting and " (in combat)" or "", entry.editing and " (edit mode)" or "")
    end
    return table.concat(out, "\n")
end

function ns.StatusText()
    local _, version, build, _, toc = Quietly(GetBuildInfo)
    local knownLocale, locale = Quietly(GetLocale)
    local _, width, height = Quietly(GetPhysicalScreenSize)
    local _, maximised = Quietly((C_CVar and C_CVar.GetCVar) or GetCVar, "gxMaximize")
    local scale = UIParent and Look.Number(UIParent:GetEffectiveScale())
    local _, classToken = UnitClass("player")
    local zone = type(GetRealZoneText) == "function" and GetRealZoneText() or nil
    local changed, others = SettingsDiff(), AddonList()
    return table.concat({
        "EraUI " .. (Metadata(addonName, "Version") or "?"),
        string.format("Client: %s (%s), toc %s, %s", Readable(version), Readable(build), Readable(toc),
            knownLocale and Readable(locale) or "?"),
        string.format("Display: %sx%s%s, UI scale %s", Readable(width), Readable(height), maximised == "0" and " windowed" or "",
            scale and string.format("%.2f", scale) or "?"),
        string.format("Character: %s %s, %s%s", Readable(classToken), Readable(UnitLevel("player")), Readable(zone),
            Look.InFight() and ", in combat" or ""),
        #changed > 0 and Wrapped("Settings changed: ", changed) or "Settings changed: none, all as shipped",
        #others > 0 and Wrapped("Other addons on (" .. #others .. "): ", others) or "Other addons on (0): none",
        BlockedSection(),
    }, "\n")
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

local DIALOG_ART = "Interface\\DialogFrame\\"
local TIP_ART = "Interface\\Tooltips\\"

-- A wheel notch moves the text 28 units, kept inside it.
local function Scrolled(pane, page, notches)
    local room = (Look.Number(page:GetHeight()) or 0) - (Look.Number(pane:GetHeight()) or 0)
    local at = (Look.Number(pane:GetVerticalScroll()) or 0) - notches * 28
    pane:SetVerticalScroll(Look.Clamp(at, 0, math.max(0, room)))
end

-- The report's text area: a tooltip-edged well with a scrolling, read-only page.
local function TextWell(sheet, under)
    local well = Look.Build("Frame", sheet, "BackdropTemplate")
    well:SetPoint("TOPLEFT", under, "BOTTOMLEFT", -4, -8)
    well:SetPoint("BOTTOMRIGHT", sheet, "BOTTOMRIGHT", -20, 52)
    well:SetBackdrop({ bgFile = TIP_ART .. "UI-Tooltip-Background", edgeFile = TIP_ART .. "UI-Tooltip-Border", tile = true,
        tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    local fill, edge = { 0, 0, 0, 0.7 }, { 0.6, 0.6, 0.6 }
    well:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
    well:SetBackdropBorderColor(edge[1], edge[2], edge[3])
    local pane = Look.Build("ScrollFrame", well, nil, { wheel = true })
    pane:SetPoint("TOPLEFT", well, "TOPLEFT", 8, -8)
    pane:SetPoint("BOTTOMRIGHT", well, "BOTTOMRIGHT", -8, 8)
    local page = Look.Build("EditBox", pane)
    page:SetMultiLine(true)
    page:SetAutoFocus(false)
    page:SetFontObject(GameFontHighlightSmall)
    page:SetWidth(500)
    pane:SetScrollChild(page)
    pane:SetScript("OnMouseWheel", function(_, notches) Scrolled(pane, page, notches) end)
    page:SetScript("OnTextChanged", function(_, typed)
        if not typed then return end
        page:SetText(status.text or "")
        page:HighlightText()
    end)
    page:SetScript("OnEscapePressed", function() page:ClearFocus() end)
    page:SetScript("OnEditFocusLost", function() page:HighlightText(0, 0) end)
    return pane, page
end

-- The shared panel button (the options window's), placed and wired.
local function Button(sheet, label, width, onClick, ...)
    if type(ns.PanelButton) ~= "function" then return nil end
    local made = ns.PanelButton(sheet, label, width)
    if not made then return nil end
    made:SetScript("OnClick", onClick)
    made:SetPoint(...)
    return made
end

local function Build()
    local sheet = CreateFrame("Frame", "EraUIClassicStatus", UIParent, "BackdropTemplate")
    sheet:SetSize(560, 380)
    sheet:SetFrameStrata("DIALOG")
    sheet:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    sheet:SetMovable(true)
    sheet:SetClampedToScreen(true)
    sheet:EnableMouse(true)
    sheet:RegisterForDrag("LeftButton")
    sheet:SetScript("OnDragStart", function() sheet:StartMoving() end)
    sheet:SetScript("OnDragStop", function() sheet:StopMovingOrSizing() end)
    sheet:SetBackdrop({ bgFile = DIALOG_ART .. "UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    if ns.DarkBackdrop then ns.DarkBackdrop(sheet) end
    sheet:Hide()

    local plate = sheet:CreateTexture(nil, "ARTWORK")
    plate:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    plate:SetSize(300, 64)
    Look.Pin(plate, "TOP", sheet, "TOP", 0, 12)
    if ns.DarkWindowArt then ns.DarkWindowArt(plate, "frame") end
    local heading = Look.Label(sheet, "GameFontNormal", "OVERLAY")
    Look.Pin(heading, "TOP", plate, "TOP", 0, -14)
    heading:SetText("EraUI status")

    local guide = Look.Label(sheet, "GameFontHighlightSmall", "OVERLAY")
    guide:SetJustifyH("LEFT")
    guide:SetPoint("TOPLEFT", sheet, "TOPLEFT", 24, -32)
    guide:SetPoint("TOPRIGHT", sheet, "TOPRIGHT", -24, -32)
    guide:SetText(HOW_TO)
    local pane, page = TextWell(sheet, guide)

    Button(sheet, "Select all", 90, function()
        page:SetFocus()
        page:HighlightText()
    end, "BOTTOMLEFT", sheet, "BOTTOMLEFT", 22, 20)
    local left = Button(sheet, CLOSE or "Close", 80, function() sheet:Hide() end, "BOTTOMRIGHT", sheet, "BOTTOMRIGHT", -22, 20)
    -- Right to left beside Close: where to report, each address copied from a box.
    for _, link in ipairs({
        { "GitHub issues", 110, "EraUI issues on GitHub", "GITHUB_URL" },
        { "CurseForge", 102, "EraUI on CurseForge", "CURSEFORGE_URL" },
        { "Discord", 86, "EraUI Discord: support, bugs and ideas", "DISCORD_URL" },
    }) do
        if left then
            left = Button(sheet, link[1], link[2], function()
                if type(ns.CopyLink) == "function" then ns.CopyLink(link[3], ns[link[4]]) end
            end, "RIGHT", left, "LEFT", -6, 0) or left
        end
    end

    -- Fresh each time it shows, from the top (looked up through the
    -- namespace, so a replacement takes effect).
    sheet:SetScript("OnShow", function()
        status.text = type(ns.StatusText) == "function" and ns.StatusText() or ""
        page:SetText(status.text)
        page:SetCursorPosition(0)
        pane:SetVerticalScroll(0)
    end)
    if type(ns.CloseOnEscape) == "function" then ns.CloseOnEscape(sheet) end
    status.window = sheet
    return sheet
end

function ns.ShowStatus()
    local sheet = status.window or Build()
    -- Hidden and shown again, so an open report is read afresh.
    if sheet:IsShown() then sheet:Hide() end
    sheet:Show()
end

-- The first time in a session the game blocks or forbids something EraUI
-- did (the engine's watchdog calls this): one line in chat with a link to
-- the report.
function ns.OfferStatus()
    if status.offered or type(ns.ChatLink) ~= "function" then return end
    status.offered = true
    local say = ns.Print or print
    say("the game blocked something this addon tried to do. If anything looks broken, "
        .. tostring(ns.ChatLink("status", "open the status report")) .. " and send it with a note of what you were doing.")
end
