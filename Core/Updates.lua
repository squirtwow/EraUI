-- EraUI "What's new" notes.
-- Shown once after the addon version changes: what's new, what changed,
-- what was fixed, and what's coming. Styled like the other EraUI windows,
-- with the player's class colour on the stripe, title and button.
local _, EraUI = ...

local UPDATES = {
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

    local function Text(size, r, g, b, x, y, width)
        local t = window:CreateFontString(nil, "OVERLAY")
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

    -- Section headers and bullets, laid out once for this version.
    window.blocks = {}
    local y = -92
    for _, section in ipairs(EntryForVersion().sections) do
        local header = Text(13, 1, .82, 0, 28, y)
        header:SetText(section[1])
        y = y - 24
        local lines = {}
        for _, text in ipairs(section[2]) do
            local line = Text(12, .86, .88, .93, 44, y, 480)
            line:SetText("• " .. text)
            lines[#lines + 1] = line
            y = y - 18
        end
        y = y - 12
        window.blocks[#window.blocks + 1] = { header = header, lines = lines }
    end
    window:SetHeight(math.max(240, -y + 70))

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
end

EraUI.ShowUpdateNotes = Show
