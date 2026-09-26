-- EraUI skinning helpers.
-- Shared routines used by every skin module. Blizzard frames stay alive and
-- keep their logic; we only change textures, anchors and alpha, and hook the
-- update methods that would otherwise undo those changes.
local _, EraUI = ...
local ns = EraUI.Classic

-- Alpha 0 rather than Hide: the client calls Show() on its regions constantly,
-- and alpha survives that.

-- 1.x quest difficulty colors (by level relative to the player).
local QUEST_COLOURS = {
    impossible = { 1, 0.1, 0.1 }, verydifficult = { 1, 0.5, 0.25 }, difficult = { 1, 0.92, 0 },
    standard = { 0.25, 0.75, 0.25 }, trivial = { 0.5, 0.5, 0.5 },
}

function ns.QuestYellow()
    local c = QUEST_COLOURS.difficult
    return c[1], c[2], c[3]
end

function ns.QuestLevelColor(level)
    level = tonumber(level) or 0
    local player = UnitLevel("player") or 1
    local diff = level - player
    local key
    if level <= 0 then
        key = "difficult"
    elseif diff >= 5 then
        key = "impossible"
    elseif diff >= 3 then
        key = "verydifficult"
    elseif diff >= -2 then
        key = "difficult"
    else
        local range = 5
        if UnitQuestTrivialLevelRange then
            local ok, r = pcall(UnitQuestTrivialLevelRange, "player")
            if ok and tonumber(r) then range = r end
        elseif GetQuestGreenRange then
            local ok, r = pcall(GetQuestGreenRange)
            if ok and tonumber(r) then range = r end
        end
        key = (-diff <= range) and "standard" or "trivial"
    end
    local c = QUEST_COLOURS[key]
    return c[1], c[2], c[3]
end

-- Old gold (1, 0.82, 0) on the standard font objects, for text that must read
-- as the classic yellow whatever the client's own color is.
local function GoldFont(name, base)
    local font = CreateFont(name)
    font:SetFontObject(base)
    font:SetTextColor(1, 0.82, 0)
    return font
end
ns.FONT_GOLD = GoldFont("EraUIClassicGold", "GameFontNormal")
ns.FONT_GOLD_SMALL = GoldFont("EraUIClassicGoldSmall", "GameFontNormalSmall")
ns.FONT_GOLD_LARGE = GoldFont("EraUIClassicGoldLarge", "GameFontNormalLarge")

-- 1.x showed a skull for anything more than ten levels above you (the server
-- hid those levels and sent -1). This client sends the real number, so the
-- old rule is kept here. -1 (a boss) is a skull as before. Only for what can
-- be fought: a friendly's level was never hidden, and where the client
-- withholds whether the unit is attackable the skull stands.
function ns.SkullLevel(level, unit)
    if level == nil then return false end
    if issecretvalue and issecretvalue(level) then return false end
    if level < 0 then return true end
    if unit and UnitCanAttack then
        local foe = UnitCanAttack("player", unit)
        if not (issecretvalue and issecretvalue(foe)) and not foe then return false end
    end
    local mine = UnitLevel("player")
    if mine == nil or (issecretvalue and issecretvalue(mine)) then return false end
    return (level - mine) > 10
end

function ns.Fade(region)
    if region and region.SetAlpha then region:SetAlpha(0) end
end

function ns.Unfade(region)
    if region and region.SetAlpha then region:SetAlpha(1) end
end

local hooked = setmetatable({}, { __mode = "k" })

-- Hook a method on a frame once. Missing methods are skipped and reported
-- through the debug flush rather than erroring the module out.
function ns.HookMethod(frame, method, fn)
    if not frame then return false end
    if type(frame[method]) ~= "function" then
        ns.MissingPiece((frame.GetName and frame:GetName() or "?") .. ":" .. method)
        return false
    end
    hooked[frame] = hooked[frame] or {}
    if hooked[frame][method] then return true end
    hooked[frame][method] = true
    hooksecurefunc(frame, method, fn)
    return true
end

local hookedGlobals = {}
function ns.HookGlobal(name, fn)
    if type(_G[name]) ~= "function" then
        ns.MissingPiece(name)
        return false
    end
    if hookedGlobals[name] then return true end
    hookedGlobals[name] = true
    hooksecurefunc(name, fn)
    return true
end

-- Pieces the running client does not have are listed for the debug command.
ns.missing = {}
function ns.MissingPiece(name)
    if not ns.missing[name] then
        ns.missing[name] = true
        ns.missingCount = (ns.missingCount or 0) + 1
    end
end

local hookedScripts = {}
function ns.HookScriptOnce(frame, script, fn)
    if not frame or not frame.HookScript then return end
    hookedScripts[frame] = hookedScripts[frame] or {}
    if hookedScripts[frame][script] then return end
    hookedScripts[frame][script] = true
    frame:HookScript(script, fn)
end

-- The 12.x level and PvP circles: any texture on the frame drawn from a
-- "SmallCircle" atlas goes away, whatever key it hangs on.
function ns.FadeCircles(frame)
    if not frame or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") and region.GetAtlas then
            local atlas = region:GetAtlas()
            if atlas and atlas:lower():find("smallcircle", 1, true) then region:SetAlpha(0) end
        end
    end
end

function ns.Path(frame, ...)
    local node = frame
    for i = 1, select("#", ...) do
        if type(node) ~= "table" then return nil end
        node = node[(select(i, ...))]
    end
    return node
end

function ns.SetPointOnce(region, ...)
    if not region then return end
    region:ClearAllPoints()
    region:SetPoint(...)
end

-- A texture created once on a frame, keyed so re-applies reuse it.
function ns.OwnTexture(frame, key, layer, sublevel)
    frame.fcui = frame.fcui or {}
    local tex = frame.fcui[key]
    if not tex then
        tex = frame:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
        frame.fcui[key] = tex
    end
    return tex
end

-- A square icon in a round hole. The icon carries its own border, so it is
-- drawn from a little way in past it, and (for a texture of ours) cut round.
local ICON_CROP = 0.1
function ns.RoundIcon(tex, inset)
    if not tex then return end
    tex:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    local owner = tex:GetParent()
    if tex.fcuiMask or not (owner and owner.CreateMaskTexture and tex.AddMaskTexture) then return end
    local mask = owner:CreateMaskTexture()
    mask:SetTexture(ns.TexPath("portraitMask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetPoint("TOPLEFT", tex, "TOPLEFT", inset or 0, -(inset or 0))
    mask:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", -(inset or 0), inset or 0)
    tex:AddMaskTexture(mask)
    tex.fcuiMask = mask
end

-- The client puts a face, a round piece of art, or a plain icon in a window's
-- portrait; only the icon needs drawing in from its border. Which of the three
-- is up changes with tabs, so dressed portraits are watched and set to match.
-- Coordinates the client has set itself are left alone.
local portraits = setmetatable({}, { __mode = "k" })
local portraitWatch

local function IsIconTexture(tex)
    local path = tex.GetTextureFilePath and tex:GetTextureFilePath()
    if type(path) == "string" and not path:find("^FileData ID") then
        return path:lower():find("icons", 1, true) ~= nil
    end
    local file = tex:GetTexture()
    if type(file) == "number" then return true end
    if type(file) == "string" then
        local lower = file:lower()
        if lower:find("^rt") or lower:find("^portrait") then return false end
        return lower:find("icons", 1, true) ~= nil
    end
    return false
end

local function Near(a, b) return math.abs((a or 0) - b) < 0.002 end

local function FitPortrait(tex)
    local ulx, uly, _, _, _, _, lrx, lry = tex:GetTexCoord()
    local full = Near(ulx, 0) and Near(uly, 0) and Near(lrx, 1) and Near(lry, 1)
    local ours = Near(ulx, ICON_CROP) and Near(uly, ICON_CROP) and Near(lrx, 1 - ICON_CROP) and Near(lry, 1 - ICON_CROP)
    if not full and not ours then
        -- A piece cut from a sheet by the client (the class circles), each
        -- with a gold rim that showed along the top of the ring.
        local zoom = tex.fcuiZoom
        if zoom and Near(ulx, zoom[1]) and Near(uly, zoom[2]) and Near(lrx, zoom[3]) and Near(lry, zoom[4]) then return end
        if lrx <= ulx or lry <= uly then return end
        -- The client's round mask is not centered: it cuts nothing off the
        -- top, two pixels off each side and four off the bottom.
        local dx, span = (lrx - ulx) * ICON_CROP, lry - uly
        zoom = { ulx + dx, uly + span * 0.16, lrx - dx, lry - span * 0.06 }
        tex.fcuiZoom = zoom
        tex:SetTexCoord(zoom[1], zoom[3], zoom[2], zoom[4])
        return
    end
    local icon = IsIconTexture(tex)
    if icon and full then
        tex:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    elseif ours and not icon then
        tex:SetTexCoord(0, 1, 0, 1)
    end
end

function ns.WatchPortrait(tex)
    if not tex or not tex.GetTexCoord then return end
    portraits[tex] = true
    if not portraitWatch then
        portraitWatch = CreateFrame("Frame")
        portraitWatch:SetScript("OnUpdate", function(self, elapsed)
            self.since = (self.since or 0) + elapsed
            if self.since < 0.05 then return end
            self.since = 0
            for portrait in pairs(portraits) do
                if portrait:IsVisible() then pcall(FitPortrait, portrait) end
            end
        end)
    end
    pcall(FitPortrait, tex)
end

function ns.OwnFontString(frame, key, layer, font)
    frame.fcui = frame.fcui or {}
    local fs = frame.fcui[key]
    if not fs then
        fs = frame:CreateFontString(nil, layer or "OVERLAY", font or "GameFontHighlightSmall")
        frame.fcui[key] = fs
    end
    return fs
end

-- 1.x power colors. Blizzard's PowerBarColor still exists on both clients and
-- is used for anything not listed here.
ns.POWER_COLORS = {
    MANA = { 0, 0, 1 }, RAGE = { 1, 0, 0 }, FOCUS = { 1, 0.5, 0.25 }, ENERGY = { 1, 1, 0 },
    RUNIC_POWER = { 0, 0.82, 1 }, LUNAR_POWER = { 0.3, 0.52, 0.9 }, MAELSTROM = { 0, 0.5, 1 },
    INSANITY = { 0.4, 0, 0.8 }, FURY = { 0.788, 0.259, 0.992 }, PAIN = { 1, 0.61, 0 },
    AMMOSLOT = { 0.8, 0.6, 0 }, FUEL = { 0, 0.55, 0.5 },
}

function ns.PowerColor(unit)
    local powerType, token, altR, altG, altB = UnitPowerType(unit)
    if issecretvalue and (issecretvalue(token) or issecretvalue(powerType)) then return 0, 0, 1 end
    local c = token and ns.POWER_COLORS[token]
    if c then return c[1], c[2], c[3] end
    if altR and not (issecretvalue and issecretvalue(altR)) then return altR, altG, altB end
    local info = PowerBarColor and (PowerBarColor[token] or PowerBarColor[powerType])
    if info then return info.r, info.g, info.b end
    return 0, 0, 1
end

-- Secret values (12.x combat data) never reach a StatusBar.
function ns.SafeNumber(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

-- A StatusBar we own with the 1.x fill, under no mouse.
function ns.CreateBar(parent, key, width, height)
    parent.fcui = parent.fcui or {}
    local bar = parent.fcui[key]
    if not bar then
        bar = CreateFrame("StatusBar", nil, parent)
        bar:EnableMouse(false)
        parent.fcui[key] = bar
    end
    bar:SetSize(width, height)
    bar:SetStatusBarTexture((ns.TexPath("statusBar")))
    bar:GetStatusBarTexture():SetTexCoord(0, 1, 0, 1)
    bar:Show()
    return bar
end

local function FillBar(bar, value, max)
    if value == nil or max == nil then return end
    if not IsSecret(max) and max <= 0 then
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        return
    end
    bar:SetMinMaxValues(0, max)
    bar:SetValue(value)
end

-- The health bar color: the old green, or the unit's class color when the
-- toggle asks for it and the unit is a player (secret identities keep green).
function ns.HealthColor(unit)
    if ns.db and ns.db.classColorHealth and unit and UnitIsPlayer then
        local isPlayer = UnitIsPlayer(unit)
        if not IsSecret(isPlayer) and isPlayer then
            local _, class = UnitClass(unit)
            if class and not IsSecret(class) then
                local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
                if color then return color.r, color.g, color.b end
            end
        end
    end
    return 0, 1, 0
end

function ns.SetHealth(bar, unit)
    FillBar(bar, UnitHealth(unit), UnitHealthMax(unit))
    bar:SetStatusBarColor(ns.HealthColor(unit))
end

function ns.SetPower(bar, unit)
    FillBar(bar, UnitPower(unit), UnitPowerMax(unit))
    bar:SetStatusBarColor(ns.PowerColor(unit))
end

-- A slider dressed as the old scroll bar, with its two arrow buttons.
function ns.ClassicScrollBar(parent, anchorTo, onValue)
    local bar = CreateFrame("Slider", nil, parent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(16)
    bar:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 6, -16)
    bar:SetPoint("BOTTOMLEFT", anchorTo, "BOTTOMRIGHT", 6, 16)
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    ns.SetTex(thumb, "scrollKnob")
    thumb:SetSize(18, 24)
    thumb:SetTexCoord(0.2, 0.8, 0.125, 0.875)
    bar:SetThumbTexture(thumb)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)

    local function Arrow(kind, point, relPoint)
        local button = CreateFrame("Button", nil, bar)
        button:SetSize(16, 16)
        button:SetPoint(point, bar, relPoint, 0, 0)
        ns.SetButtonTex(button, "Normal", "scroll" .. kind .. "ButtonUp")
        ns.SetButtonTex(button, "Pushed", "scroll" .. kind .. "ButtonDown")
        ns.SetButtonTex(button, "Disabled", "scroll" .. kind .. "ButtonDisabled")
        ns.SetButtonTex(button, "Highlight", "scroll" .. kind .. "ButtonHighlight")
        button:GetHighlightTexture():SetBlendMode("ADD")
        -- The sheets are 32x32 with the 16x16 arrow in the middle.
        for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
            local tex = button["Get" .. state .. "Texture"](button)
            if tex then tex:SetTexCoord(0.25, 0.75, 0.25, 0.75) end
        end
        return button
    end
    bar.up = Arrow("Up", "BOTTOM", "TOP")
    bar.down = Arrow("Down", "TOP", "BOTTOM")
    bar.up:SetScript("OnClick", function() bar:SetValue(bar:GetValue() - bar.step) PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON) end)
    bar.down:SetScript("OnClick", function() bar:SetValue(bar:GetValue() + bar.step) PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON) end)
    bar.step = 1

    function bar:SetRange(max, step)
        self.step = step or 1
        max = math.max(0, max)
        local value = self:GetValue()
        self:SetMinMaxValues(0, max)
        self:SetValue(math.min(value, max))
        self:SetShown(not self.hideWhenIdle or max > 0)
        local thumb = self:GetThumbTexture()
        if thumb then thumb:SetShown(max > 0) end
        self:Refresh()
    end
    function bar:Refresh()
        local _, max = self:GetMinMaxValues()
        local value = self:GetValue()
        self.up:SetEnabled(value > 0)
        self.down:SetEnabled(value < max)
    end
    bar:SetScript("OnValueChanged", function(self, value)
        self:Refresh()
        onValue(value)
    end)
    return bar
end

-- The old windows never stacked: opening one closed whatever was in its place.
-- The client handles that for its own windows through its panel system, but the
-- windows this addon owns sit outside that system (a window inside it cannot
-- open during a fight), so they keep the old manners here.
local classicWindows = {}
local WatchClientWindows

local LOOSE_PANELS = { "WorldMapFrame" }

-- Never closed from here: the talents window (its close clears the note each
-- action bar keeps about showing empty slots, which the client then stops
-- acting on).
local LEAVE_OPEN = { PlayerSpellsFrame = true }
-- The client's windows that stand beside ours rather than taking their place.
local BESIDE = { CharacterFrame = true }
local BESIDE_WIDTH = 352
local PlaceClassicWindows

local function HideClientPanels(except)
    if InCombatLockdown() then return end
    for name in pairs(UIPanelWindows or {}) do
        local panel = _G[name]
        local ghost = ns.guildGhost and name == "CommunitiesFrame"
        if panel and panel ~= except and not LEAVE_OPEN[name] and not BESIDE[name] and not ghost and panel:IsShown() and HideUIPanel then
            pcall(HideUIPanel, panel)
        end
    end
    for _, name in ipairs(LOOSE_PANELS) do
        local panel = _G[name]
        if panel and panel ~= except and panel:IsShown() and HideUIPanel then
            pcall(HideUIPanel, panel)
        end
    end
end

-- NPC-opened windows that take the place the old windows shared. They are not
-- hooked, they are watched (a hook on the panel call ran inside every window
-- the client opened, in the client's own pass; a watcher never does).
local NPC_WINDOWS = { "GossipFrame", "QuestFrame", "MerchantFrame", "MailFrame", "BankFrame", "ClassTrainerFrame",
    "AuctionHouseFrame", "AuctionFrame", "TradeFrame", "TaxiFrame", "FlightMapFrame", "PetStableFrame", "StableFrame",
    "ItemTextFrame", "TabardFrame", "GuildRegistrarFrame", "PetitionFrame", "CraftFrame", "TradeSkillFrame",
    "ProfessionsFrame", "BarberShopFrame", "GuildBankFrame", "InspectFrame", "LootFrame" }
local npcWindow = {}
for _, name in ipairs(NPC_WINDOWS) do npcWindow[name] = true end

local clientShown = {}
local windowWatch

local function ClientWindowOpened(name, panel)
    if LEAVE_OPEN[name] then return end
    if BESIDE[name] and not InCombatLockdown() then
        PlaceClassicWindows()
        return
    end
    ns.HideClassicWindows(panel)
    if npcWindow[name] and FriendsFrame and FriendsFrame ~= panel and FriendsFrame:IsShown() then
        ns.HidePanel(FriendsFrame)
    end
end

function WatchClientWindows()
    if windowWatch then return end
    windowWatch = CreateFrame("Frame")
    -- Some client windows only load their piece of the interface the first
    -- time they are wanted; the list of names is rebuilt the moment anything
    -- loads so such a first open is not missed.
    windowWatch:RegisterEvent("ADDON_LOADED")
    windowWatch:SetScript("OnEvent", function(self) self.names = nil end)
    windowWatch:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        self.scan = (self.scan or 0) + elapsed
        if not self.names or self.since > 5 then
            self.since = 0
            local names, have = {}, {}
            local function Add(name)
                if type(name) == "string" and not have[name] then
                    have[name] = true
                    names[#names + 1] = name
                end
            end
            for name in pairs(UIPanelWindows or {}) do Add(name) end
            for _, name in ipairs(LOOSE_PANELS) do Add(name) end
            for _, name in ipairs(NPC_WINDOWS) do Add(name) end
            self.names = names
        end
        -- One scan of the panel list is ~100 IsShown calls, so the idle poll
        -- runs ten times a second rather than every frame.
        if self.scan < 0.1 then return end
        self.scan = 0
        for _, name in ipairs(self.names) do
            local panel = _G[name]
            if type(panel) == "table" and panel.IsShown then
                local shown = panel:IsShown() and true or false
                if shown and ns.guildGhost and name == "CommunitiesFrame" then shown = false end
                if shown and not clientShown[name] then ClientWindowOpened(name, panel) end
                if not shown and clientShown[name] and BESIDE[name] then PlaceClassicWindows() end
                clientShown[name] = shown
            end
        end
    end)
end

function ns.HideClassicWindows(except)
    for frame in pairs(classicWindows) do
        if frame ~= except and frame:IsShown() then
            frame:Hide()
        end
    end
end

-- Two of our windows may stand side by side (as the old spellbook and talent
-- window did); the first opened keeps the left place, the other opens right.
local SLOT_Y, SLOT_STEP = -104, 352
local showCount = 0

PlaceClassicWindows = function()
    local shown = {}
    for frame in pairs(classicWindows) do
        if frame:IsShown() then shown[#shown + 1] = frame end
    end
    table.sort(shown, function(a, b) return (a.fcuiShownAt or 0) < (b.fcuiShownAt or 0) end)
    -- A window that cannot move for now keeps its place; the rest are stood
    -- in the room left around it.
    local held = {}
    for _, frame in ipairs(shown) do
        local at = frame.fcuiHoldX and frame:fcuiHoldX()
        if at then held[frame] = at end
    end
    local function Past(x, width)
        for frame, at in pairs(held) do
            local wide = frame.fcuiSlotWidth or SLOT_STEP
            if x < at + wide and at < x + width then return at + wide end
        end
    end
    -- A client window that stands beside ours keeps the place the client gave
    -- it, and ours begin at its drawn right edge.
    local cursor = 0
    for name in pairs(BESIDE) do
        local panel = _G[name]
        if panel and panel:IsShown() and panel:GetLeft() then
            cursor = math.max(cursor, math.floor(panel:GetLeft() + BESIDE_WIDTH + 0.5))
        end
    end
    for _, frame in ipairs(shown) do
        local width = frame.fcuiSlotWidth or SLOT_STEP
        local x = held[frame]
        if not x then
            local keep = frame.fcuiKeep and frame:fcuiKeep()
            local right = keep and keep:IsShown() and keep:GetRight()
            if right then cursor = math.max(cursor, math.floor(right + 0.5)) end
            x = cursor
            local past = Past(x, width)
            while past do
                x = past
                past = Past(x, width)
            end
        end
        if frame.fcuiSlotX ~= x then
            frame.fcuiSlotX = x
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, SLOT_Y)
            if frame.OnClassicPlaced then frame:OnClassicPlaced(x, SLOT_Y) end
        end
        cursor = math.max(cursor, x + width)
    end
end
ns.PlaceClassicWindows = PlaceClassicWindows

function ns.RegisterClassicWindow(frame, shares)
    if not frame or classicWindows[frame] then return end
    classicWindows[frame] = true
    frame.fcuiShares = shares and true or false
    frame:HookScript("OnShow", function(self)
        showCount = showCount + 1
        self.fcuiShownAt = showCount
        for other in pairs(classicWindows) do
            if other ~= self and other:IsShown() and not (self.fcuiShares and other.fcuiShares) then other:Hide() end
        end
        HideClientPanels(self.fcuiKeep and self:fcuiKeep() or nil)
        PlaceClassicWindows()
    end)
    frame:HookScript("OnHide", function() PlaceClassicWindows() end)
    WatchClientWindows()
end

-- Opening and closing a window during a fight. The client's own opener refuses
-- an addon window in combat; a window that protects nothing can be shown where
-- it stands, one holding the client's own protected pieces is left alone.
function ns.ShowPanel(frame)
    if not frame or frame:IsShown() then return true end
    if not InCombatLockdown() then
        if ShowUIPanel then ShowUIPanel(frame) else frame:Show() end
        return true
    end
    if frame.IsProtected and frame:IsProtected() then return false end
    if frame.GetNumPoints and frame:GetNumPoints() == 0 then
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
    end
    frame:Show()
    return true
end

function ns.HidePanel(frame)
    if not frame or not frame:IsShown() then return true end
    if not InCombatLockdown() then
        if HideUIPanel then HideUIPanel(frame) else frame:Hide() end
        return true
    end
    if frame.IsProtected and frame:IsProtected() then return false end
    frame:Hide()
    return true
end

-- The friends window sweeps: the client hangs more controls than this UI knows
-- by name. While one of our tabs is up, anything of the client's still showing
-- on that window steps aside and comes back when ours goes. Our own frames,
-- the tabs and the close button are left alone.
local sweepSaid = false
function ns.SweepFriendsReport()
    sweepSaid = false
end

local function SweepInside(container, mark, hide)
    if not container or not container.GetChildren then return end
    for _, child in ipairs({ container:GetChildren() }) do
        local name = (child.GetName and child:GetName()) or ""
        if not name:find("EraUIClassic", 1, true) then
            if hide then
                if not child[mark] then
                    child[mark] = true
                    local was = child:GetAlpha()
                    child.fcuiAlpha = (was and was > 0) and was or nil
                    child.fcuiMouse = child.IsMouseEnabled and child:IsMouseEnabled()
                end
                if child:GetAlpha() > 0 then child:SetAlpha(0) end
                if child.EnableMouse and not InCombatLockdown() and child.IsMouseEnabled and child:IsMouseEnabled() then
                    child:EnableMouse(false)
                end
            elseif child[mark] then
                child[mark] = nil
                child:SetAlpha(child.fcuiAlpha or 1)
                if child.EnableMouse and not InCombatLockdown() and child.fcuiMouse then child:EnableMouse(true) end
                child.fcuiAlpha, child.fcuiMouse = nil, nil
            end
        end
    end
end

function ns.RestoreFriendsTitle()
    local title = FriendsFrameTitleText
    local host = FriendsFrame
    if not title or not host then return end
    local selected = host.selectedTab or (PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(host)) or 1
    local text
    if FRIEND_TAB_WHO and selected == FRIEND_TAB_WHO then
        text = WHO_LIST
    elseif selected == (FRIEND_TAB_RAID or 3) then
        text = RAID
    elseif selected == (FRIEND_TAB_QUICK_JOIN or 4) then
        text = QUICK_JOIN
    else
        local header = FriendsTabHeader
        local sub = header and header.GetTab and header:GetTab()
        if sub and header.recentAlliesTabID and sub == header.recentAlliesTabID then
            text = CONTACTS_RECENT_ALLIES_TITLE
        elseif sub and header.recruitAFriendTabID and sub == header.recruitAFriendTabID then
            text = RECRUIT_A_FRIEND
        else
            text = CONTACTS_LIST_TITLE or FRIENDS
        end
    end
    if text then title:SetText(text) end
end

local function DeepMouse(frame, mark, off, depth)
    if not frame or not frame.GetChildren or (depth or 0) > 4 or InCombatLockdown() then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        local key = mark .. "Mouse"
        if off then
            if child.IsMouseEnabled and child:IsMouseEnabled() then
                child[key] = true
                child:EnableMouse(false)
            end
        elseif child[key] then
            child[key] = nil
            child:EnableMouse(true)
        end
        DeepMouse(child, mark, off, (depth or 0) + 1)
    end
end

function ns.SweepFriendsFrame(mark, hide)
    local host = FriendsFrame
    if not host or not host.GetChildren then return end
    local inset = _G["FriendsFrameInset"]
    if hide and inset and not InCombatLockdown() then
        local _, _, _, x, y = inset:GetPoint(1)
        if y and math.abs(y + 83) > 0.5 then
            inset:SetPoint("TOPLEFT", host, "TOPLEFT", x or 4, -83)
        end
    end
    SweepInside(host.TitleContainer, mark, hide)
    SweepInside(_G["FriendsFrameInset"], mark, hide)
    if hide and not sweepSaid and ns.db and ns.db.sweepTrace then
        sweepSaid = true
        local kept, hidden = {}, {}
        for _, child in ipairs({ host:GetChildren() }) do
            local name = (child.GetName and child:GetName()) or (child.GetDebugName and child:GetDebugName()) or "?"
            local shown = child:IsShown() and (child:GetAlpha() or 0) > 0
            table.insert(shown and kept or hidden, name)
        end
        ns.Print("friends window children still visible: " .. (next(kept) and table.concat(kept, ", ") or "none"))
        for _, container in ipairs({ host.TitleContainer, _G["FriendsFrameInset"] }) do
            if container and container.GetChildren then
                local inside = {}
                for _, child in ipairs({ container:GetChildren() }) do
                    if child:IsShown() and (child:GetAlpha() or 0) > 0 then
                        table.insert(inside, (child.GetName and child:GetName()) or (child.GetDebugName and child:GetDebugName()) or "?")
                    end
                end
                ns.Print("  inside " .. ((container.GetDebugName and container:GetDebugName()) or "?") .. ": "
                    .. (next(inside) and table.concat(inside, ", ") or "none"))
            end
        end
    end
    for _, child in ipairs({ host:GetChildren() }) do
        local name = (child.GetName and child:GetName()) or ""
        local keep = name:find("EraUIClassic", 1, true) or name:find("FriendsFrameTab", 1, true)
            or child == host.CloseButton or child == host.PortraitContainer
            or child == host.NineSlice or child == host.TitleContainer or child == _G["FriendsFrameInset"]
        if not keep then
            if hide then
                if not child[mark] then
                    child[mark] = true
                    local was = child:GetAlpha()
                    child.fcuiAlpha = (was and was > 0) and was or nil
                    child.fcuiMouse = child.IsMouseEnabled and child:IsMouseEnabled()
                end
                if child:GetAlpha() > 0 then child:SetAlpha(0) end
                if child.EnableMouse and not InCombatLockdown() and child.IsMouseEnabled and child:IsMouseEnabled() then
                    child:EnableMouse(false)
                end
                if child == host.FriendsTabHeader then DeepMouse(child, mark, true) end
            elseif child[mark] then
                child[mark] = nil
                if child == host.FriendsTabHeader then DeepMouse(child, mark, false) end
                child:SetAlpha(child.fcuiAlpha or 1)
                if child.EnableMouse and not InCombatLockdown() and child.fcuiMouse then child:EnableMouse(true) end
                child.fcuiAlpha, child.fcuiMouse = nil, nil
            end
        end
    end
end

local sweepers = {}
local sweepDriver
function ns.KeepFriendsSwept(panel, mark)
    if not panel then return end
    sweepers[panel] = mark
    if sweepDriver then return end
    sweepDriver = CreateFrame("Frame")
    sweepDriver:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 0.25 then return end
        self.since = 0
        for frame, tag in pairs(sweepers) do
            if frame:IsShown() then ns.SweepFriendsFrame(tag, true) end
        end
    end)
end

-- Whisper a name: the box opens with the line already written and the cursor
-- after it. The client's own opener adds to whatever was half typed, so the
-- box is emptied first and the whole line written at once.
function ns.Whisper(name)
    if type(name) ~= "string" or name == "" then return end
    local box = (ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend(DEFAULT_CHAT_FRAME)) or ChatFrame1EditBox
    if not box then
        if ChatFrame_SendTell then ChatFrame_SendTell(name) end
        return
    end
    box:SetText("")
    if ChatEdit_ActivateChat then ChatEdit_ActivateChat(box) else box:Show() end
    box:SetText("/w " .. name .. " ")
    if box.SetCursorPosition and box.GetNumLetters then box:SetCursorPosition(box:GetNumLetters()) end
    box:SetFocus()
end
