-- EraUI "What's new" notes.
-- Shown once after the addon version changes: what's new, what changed,
-- what was fixed, and what's coming. Styled like the other EraUI windows,
-- with the player's class colour on the stripe, title and button.
local _, EraUI = ...

local UPDATES = {
    {
        version = "1.0.4",
        sections = {
            { "New", {
                "Training Guide is a searchable tab inside the Classic spellbook. Bundled Forever spell levels populate immediately, with availability groups and reference cost totals (? marks unverified prices).",
                "Class Reminders rebuilt: big class-coloured alerts with the spell icon, shown while something is missing.",
                "Pick which aspect, blessing, imbue or demon to track, and the alert uses that name.",
                "Class reminders cover learned buffs, pets, supplies and weapon coatings. Shaman Advanced options include a separate Windfury Totem reminder.",
            } },
            { "Changed", {
                "Tooltips and Training Guide now default to enabled for fresh settings and resets. Existing saved choices are respected; change either option in /era and reload.",
                "Reminder options sit below Class Reminders & Buffs in your class tab, with individual reminders under Advanced.",
                "Drag any alert to move it, pick Small, Normal or Large, and reset positions any time. Alerts stay hidden in combat by default.",
            } },
            { "Fixed", {
                "What's New fits within the screen, with scrollable notes and a fixed title and Got it button.",
                "The quest sidebar overlays the full-width map, keeping its window steady without squeezing the artwork into empty bands.",
                "Player channel progress keeps one clock and a stable scale when damage changes the remaining time.",
                "Map artwork resizes with its border. Normal and expanded layouts are remembered separately, and the Map Pin hover highlight stays on its button.",
                "Player level text stays gold after leveling. Player debuff borders and aura hover boxes now use Classic styling. Tooltips applies the same dark, grey-bordered style to regular tooltips.",
                "Expanded class options and search results scroll above the footer. Mage conjure controls hide during combat while settings remain usable.",
                "Reminders detect dead pets, selected demons and imbues, and the correct off-hand coating. Group checks filter unavailable members; Soulstone needs one protected checked member.",
                "Hunter feeding reads Forever's current pet happiness and food APIs. It stays clear of settings; right-click to unlock, drag or scroll to arrange it, then left-click to lock.",
                "Training Guide filters unverified seasonal learning levels. Tooltip borders now have a thin grey bevel and softened corners.",
                "Settings recovery now includes reminder choices and positions, map size and movable-bar layouts.",
                "Class-tool preferences and supply quantities are recovered per character, including the realm.",
            } },
        },
    },
    {
        version = "1.0.3",
        sections = {
            { "Changed", {
                "Smoother performance - a lot of work that ran every frame now runs only when something changes or a few times a second.",
            } },
            { "Fixed", {
                "Combo points no longer vanish mid-fight when the client hides the value.",
                "Elite and boss target frames keep their art in combat instead of dropping to the normal frame.",
                "Pet and target-of-target art refresh after summons and target changes.",
                "The player frame name no longer goes blank or shows as Unknown.",
                "Hide Secondary Names now reliably hides the surname on the player and target frames, and no longer switches itself back off.",
                "Your level updates on the character sheet the moment you ding with it open.",
                "Inspecting a second player updates the name and talents instead of keeping the previous one.",
            } },
        },
    },
    {
        version = "1.0.2",
        sections = {
            { "Fixed", {
                "Target frame name no longer sticks to the previous target after targeting yourself.",
            } },
        },
    },
    {
        version = "1.0.1",
        sections = {
            { "New", {
                "Movable world map - drag it by the header and resize it from the corners.",
                "Red combo points - switch the floating orbs to red in your class settings.",
            } },
            { "Changed", {
                "Quiet Mode is now on by default.",
                "Swing timers are now per character - each of your characters keeps its own setting.",
            } },
            { "Fixed", {
                "The action bar band and gryphons no longer vanish after dragging a spell.",
                "The welcome and first-run setup now appear only once per character.",
            } },
            { "Coming soon", {
                "Class reminders - being redesigned.",
                "Reveal world map - being worked on.",
            } },
        },
    },
}

local function ClassColour()
    local _, class = UnitClass("player")
    local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if c then return c.r, c.g, c.b end
    return 0.7, 0.7, 0.7
end

local function EntryForVersion()
    for _, entry in ipairs(UPDATES) do
        if entry.version == EraUI.version then return entry end
    end
    return UPDATES[#UPDATES]
end

-- The current release and the couple before it, so an update that skipped a
-- session still shows what changed.
local HISTORY = 3
local function Entries()
    local list = {}
    local start
    for i, entry in ipairs(UPDATES) do
        if entry.version == EraUI.version then start = i; break end
    end
    if not start then start = 1 end
    for i = start, math.min(#UPDATES, start + HISTORY - 1) do
        list[#list + 1] = UPDATES[i]
    end
    return list
end

local window

local function Build()
    window = CreateFrame("Frame", "EraUIUpdates", UIParent, "BackdropTemplate")
    window:SetSize(560, 380)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    window:SetBackdropColor(.026, .029, .037, 1)
    window:SetBackdropBorderColor(.19, .20, .24, 1)
    window:Hide()
    table.insert(UISpecialFrames, "EraUIUpdates")

    local stripe = window:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT", 1, -1)
    stripe:SetPoint("TOPRIGHT", -1, -1)
    stripe:SetHeight(3)
    window.stripe = stripe

    local function Text(size, r, g, b, x, y, width, parent)
        local t = (parent or window):CreateFontString(nil, "OVERLAY")
        local font, _, flags = GameFontHighlight:GetFont()
        t:SetFont(font, size, flags or "")
        t:SetTextColor(r, g, b)
        t:SetJustifyH("LEFT")
        t:SetPoint("TOPLEFT", x, y)
        if width then t:SetWidth(width) end
        return t
    end

    window.eyebrow = Text(11, 1, 1, 1, 28, -28)
    window.eyebrow:SetText("WHAT'S NEW")
    window.title = Text(26, 1, 1, 1, 28, -48)
    window.title:SetWidth(500)

    local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 28, -92)
    scroll:SetPoint("BOTTOMRIGHT", -44, 70)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 40)))
    end)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(488, 1)
    scroll:SetScrollChild(content)
    window.scroll, window.content = scroll, content

    -- Only note text belongs to the scrolling child. Keep the heading and
    -- dismissal button outside it so long release histories cannot hide them.
    local flow = {}
    local function Note(size, r, g, b, indent, text, gap)
        local t = Text(size, r, g, b, indent, 0, 488 - indent, content)
        t:SetText(text)
        flow[#flow + 1] = { text = t, indent = indent, gap = gap }
        return t
    end
    window.blocks = {}
    local entries = Entries()
    for index, entry in ipairs(entries) do
        if index > 1 then
            Note(15, 1, .82, 0, 0, "EraUI " .. entry.version, 11)
        end
        for _, section in ipairs(entry.sections) do
            local header = Note(13, 1, .82, 0, 0, section[1], 11)
            local lines = {}
            for _, text in ipairs(section[2]) do
                local line = Note(12, .86, .88, .93, 16, "• " .. text, 6)
                lines[#lines + 1] = line
            end
            flow[#flow + 1] = { gap = 12 }
            window.blocks[#window.blocks + 1] = { header = header, lines = lines }
        end
        if index < #entries then flow[#flow + 1] = { gap = 8 } end
    end

    function window:LayoutNotes()
        local width = math.min(560, math.max(1, UIParent:GetWidth() - 40))
        local contentWidth = math.max(1, width - 72)
        self:SetWidth(width)
        self.title:SetWidth(math.max(1, width - 56))
        content:SetWidth(contentWidth)
        local y = 0
        for _, row in ipairs(flow) do
            if row.text then
                row.text:SetWidth(math.max(1, contentWidth - row.indent))
                row.text:ClearAllPoints()
                row.text:SetPoint("TOPLEFT", row.indent, -y)
                y = y + math.max(12, row.text:GetStringHeight() or 12)
            end
            y = y + row.gap
        end
        content:SetHeight(math.max(1, y))
        self:SetHeight(math.min(640, math.max(1, UIParent:GetHeight() - 40), math.max(240, y + 162)))
        scroll:UpdateScrollChildRect()
        scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), scroll:GetVerticalScrollRange()))
    end
    window:RegisterEvent("UI_SCALE_CHANGED")
    window:RegisterEvent("DISPLAY_SIZE_CHANGED")
    window:SetScript("OnEvent", function(self)
        if self:IsShown() then self:LayoutNotes() end
    end)

    local button = CreateFrame("Button", nil, window, "BackdropTemplate")
    button:SetSize(120, 34)
    button:SetPoint("BOTTOM", window, "BOTTOM", 0, 20)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("CENTER")
    label:SetText("Got it")
    button:SetScript("OnClick", function() window:Hide() end)
    button:SetScript("OnEnter", function(self)
        local r, g, b = ClassColour()
        self:SetBackdropColor(r * .3, g * .3, b * .3, 1)
    end)
    button:SetScript("OnLeave", function(self)
        local r, g, b = ClassColour()
        self:SetBackdropColor(r * .2, g * .2, b * .2, 1)
    end)
    window.button = button
end

local function Show()
    if not window then Build() end
    local r, g, b = ClassColour()
    window.stripe:SetColorTexture(r, g, b, 1)
    window.eyebrow:SetTextColor(r, g, b)
    window.title:SetText("EraUI " .. EntryForVersion().version)
    window.title:SetTextColor(r, g, b)
    window.button:SetBackdropColor(r * .2, g * .2, b * .2, 1)
    window.button:SetBackdropBorderColor(r, g, b, 1)
    window:Show()
    window:LayoutNotes()
    window.scroll:SetVerticalScroll(0)
end

EraUI.ShowUpdateNotes = Show
