local _, E = ...

-- Trinket Bar (/era > Action Bars > Trinkets; off by default): a small bar
-- of your two trinket slots, so you can see and swap them without opening
-- your bags. Each slot shows what you wear, its cooldown sweep and the time
-- left, and a glow says it is ready again. Show Your Rings adds your two
-- ring slots; Two Rows and Up and Down change its shape.
--
-- A left-click on a slot opens the grid of what you carry for that slot
-- (Modules/TrinketList.lua), each tile with its own cooldown, and a click
-- there puts it on; pointing at a slot opens it too while Open List is
-- Hover. A right-click opens the quick menu of the bar's own options
-- (Modules/TrinketMenu.lua). Nothing on the bar uses a trinket: using them
-- stays on your action bars and their keys.
--
-- The game never lets gear change in a fight, so a click in the grid during
-- one keeps that trinket for the slot instead (Queue in a Fight) and a Queued
-- strip sits across the top of the slot until the fight ends and it goes on.
-- The sets hold that waiting list (Modules/TrinketSets.lua); the bar only
-- draws what is in it.
--
-- Its parts: Modules/TrinketKit.lua (the slots, the reads and the box art),
-- Modules/TrinketList.lua (the grid), Modules/TrinketMenu.lua (the quick
-- menu), Modules/TrinketSets.lua and Modules/TrinketSetList.lua (your saved
-- sets, in /era), Modules/TrinketKeys.lua (the ten keys a set can answer to,
-- made here at load whether the bar is on or off),
-- Modules/TrinketAlerts.lua (the line that says a trinket is ready, or nearly,
-- all off to start with) and this file (the bar, its
-- slots and the options). Move Bar
-- in /era unlocks it for a drag; its place is EraUI's own
-- (trinketBarPosition) and is kept on screen.
--
-- Nothing here is a secure frame: the slots were secure buttons while a
-- click used the item, and are plain buttons now, so the bar is made, laid
-- out, sized, shown, hidden and moved in a fight as happily as out of one.
-- A fight still locks the drag and the quick menu, because moving the bar
-- about mid-fight is not wanted. The game never lets gear change in a
-- fight, so the grid greys out and says why.
local Module = {}
E:RegisterModule("TrinketBar", Module)

local function K() return E.TrinketKit end
local function List() return E.TrinketList end
local function Menu() return E.TrinketMenu end
local function Sets() return E.TrinketSets end
local function SetList() return E.TrinketSetList end
local function SetKeys() return E.TrinketKeys end
local function Alerts() return E.TrinketAlerts end

local SIZE_MIN, SIZE_MAX, SIZE_DEFAULT = 24, 56, 36
local PAD, GAP, HINT_H = 5, 5, 14
-- The first-time spot: right of the action bars and above them, where a
-- bar of four icons clears both.
local HOME_X, HOME_Y = 300, 150
local GLOW_SECONDS, PULSE = 4, 1.1 -- how long the ready glow stays, and a pulse's length
local TICK = .1                    -- how often the time left and the glow are redrawn

-- What the bar listens to while it is on: the world, a gear change, the
-- bags, the three cooldown events and the start and end of a fight.
local COOLDOWN = { SPELL_UPDATE_COOLDOWN = true, BAG_UPDATE_COOLDOWN = true, ACTIONBAR_UPDATE_COOLDOWN = true }
local EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "SPELL_UPDATE_COOLDOWN",
    "BAG_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_COOLDOWN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

local bar, events, box, hint, moveBox
local buttons, order = {}, {}
local fighting, dragging, watching = false, false, false
local ticking = 0

local function Enabled()
    return E:GetSetting("enabled") ~= false and E:GetSetting("trinketBar") == true
end
local function Size() return K().Setting("trinketBarSize", SIZE_MIN, SIZE_MAX, SIZE_DEFAULT) end
local function Glowing() return E:GetSetting("trinketBarGlow") ~= false end
local function Timing() return E:GetSetting("trinketBarTime") ~= false end
local function Hovering() return E:GetSetting("trinketBarOpen") ~= "click" end

-- The slots on the bar now: your first trinket, the second with Show Both
-- Slots, then the two rings with Show Your Rings. The kit works them out, so
-- the bar and a trinket set always agree about which slots you can see.
local function Wanted() return K().Shown() end

---------------------------------------------------------------------------
-- What each slot shows
---------------------------------------------------------------------------

-- The worn item's icon, or the paper doll's empty slot, faded.
local function Wear(button)
    local kit = K()
    local id, icon = kit.Worn(button.info.slot)
    button.id = id
    button.icon:SetTexture(icon or kit.EmptyArt(button.info))
    button.icon:SetDesaturated(id == nil)
    button.icon:SetAlpha(id and 1 or .5)
end

-- The ready glow: shown for a few seconds once a cooldown that was running
-- has run out. Off with Ready Glow.
local function Ready(button)
    if not Glowing() then return end
    local now = K().Call(GetTime)
    if not K().Num(now) then return end
    button.glowUntil = now + GLOW_SECONDS
    button.glow:Show()
end

-- One slot's sweep, time left, glow and cooldown alerts
-- (Modules/TrinketAlerts.lua). The seconds are written only with Time Left on
-- Icon on. In a fight the game keeps its own cooldowns secret: the two numbers
-- go to the sweep as they are (never read here), no time is written, and the
-- slot's own Cooldown widget is left to say when its sweep runs out.
--
-- swept and ran are what the alerts stand on. swept says a sweep was really
-- set for a worn item, so a widget that has merely been cleared never
-- announces a trinket that was never on cooldown; ran is what the last
-- readable numbers said, so a secret sweep is believed only where the cooldown
-- was known to be running. A cooldown that starts inside a fight has no
-- readable numbers until the fight ends, so it is announced when it runs out
-- after that and never guessed at mid-fight.
local function Sweep(button)
    local kit = K()
    local alerts = Alerts()
    local cd, text = button.cd, button.time
    local start, length = kit.Sweep(button.info.slot)
    if button.id == nil or start == nil or length == nil then
        cd:Clear()
        text:SetText("")
        button.running, button.hidden = false, false
        button.swept, button.ran = false, false
        if alerts then alerts.Forget(button.info.slot) end
        return
    end
    if not (kit.Num(start) and kit.Num(length)) then
        if not pcall(cd.SetCooldown, cd, start, length) then
            cd:Clear()
            button.swept = false
        else
            button.swept = button.ran == true
        end
        text:SetText("")
        -- Neither running nor not: the fight's own answer. A secret is never
        -- compared, so the per-frame tick leaves this slot alone until the
        -- game says the cooldown changed again.
        button.running, button.hidden = nil, true
        return
    end
    button.hidden = false
    local now = kit.Call(GetTime)
    local left = 0
    if start > 0 and length > 1.5 and kit.Num(now) then left = start + length - now end
    if left > 0 then
        cd:SetCooldown(start, length)
        text:SetText(Timing() and kit.TimeText(left, E:GetSetting("trinketBarTimeStyle")) or "")
        button.running, button.swept, button.ran = true, true, true
        -- Plain numbers, so the thirty-second warning can be worked out from
        -- them: one timer a cooldown, however many times the slot is read.
        if alerts then alerts.Watch(button.info, button.id, start, length) end
        return
    end
    cd:Clear()
    text:SetText("")
    button.swept, button.ran = false, false
    if alerts then alerts.Forget(button.info.slot) end
    if button.running == true then
        Ready(button)
        if alerts then alerts.Ready(button.info, button.id) end
    end
    button.running = false
end

-- A slot that is not on the bar any more: Show Both Slots or Show Your
-- Rings turned off, or the bar switched off altogether. Its sweep, its time,
-- its glow and its Queued strip go and the alerts forget it, so a cooldown
-- running out on a slot the bar is not showing never glows or announces
-- anything. Only the slots you can see are watched, as the alerts say.
local function Blank(button)
    button.cd:Clear()
    button.time:SetText("")
    button.glowUntil = nil
    button.glow:Hide()
    button.running, button.hidden = false, false
    button.swept, button.ran = false, false
    K().ShowQueue(button.mark, false)
    local alerts = Alerts()
    if alerts then alerts.Forget(button.info.slot) end
end

-- The sweep on a slot has run out, as the slot's own Cooldown widget says. In
-- a fight that is the only honest way to know: the widget counts the game's
-- own numbers, secret or not, and nothing here reads or compares them. It
-- speaks for a sweep that was really set for a worn item and for nothing else.
local function Finished(button)
    if button.swept ~= true then return end
    button.swept = false
    Ready(button)
    local alerts = Alerts()
    if alerts then alerts.Ready(button.info, button.id) end
end

-- The Queued strip on each slot: the trinket a click in the grid asked for
-- during a fight, which goes on the moment the fight ends. The sets own that
-- waiting list (Modules/TrinketSets.lua) and have this drawn again whenever it
-- changes, so the strip is never left behind.
function Module:Marks()
    if not bar then return end
    local kit, sets = K(), Sets()
    for _, info in ipairs(order) do
        local button = buttons[info.slot]
        if button then kit.ShowQueue(button.mark, sets ~= nil and sets.Queued(info.slot) ~= nil) end
    end
end

-- Every slot on the bar: its icon, sweep, time and Queued strip. Safe in a
-- fight.
function Module:Pictures()
    for _, info in ipairs(order) do
        local button = buttons[info.slot]
        if button then Wear(button); Sweep(button) end
    end
    self:Marks()
end

-- The glow's gentle pulse, and the time left, while the bar is up.
local function OnUpdate(_, elapsed)
    ticking = ticking + (elapsed or 0)
    if ticking < TICK then return end
    ticking = 0
    local kit = K()
    local now = kit.Call(GetTime)
    for _, info in ipairs(order) do
        local button = buttons[info.slot]
        if button then
            if not button.hidden then Sweep(button) end
            local until_ = button.glowUntil
            if until_ and kit.Num(now) then
                if now >= until_ or not Glowing() then
                    button.glowUntil = nil
                    button.glow:Hide()
                else
                    local step = (until_ - now) % PULSE / PULSE
                    button.glow:SetAlpha(.35 + .45 * math.abs(1 - 2 * step))
                end
            elseif until_ == nil and button.glow:IsShown() then
                button.glow:Hide()
            end
        end
    end
end

---------------------------------------------------------------------------
-- The slots
---------------------------------------------------------------------------

-- The grid for a slot, if there is anything to open it with. The quick menu
-- goes first: one of the two is up at a time.
local function OpenList(button, toggle)
    local list = List()
    if not list then return end
    local menu = Menu()
    if menu then menu.Close() end
    if toggle then list.Toggle(button.info.slot, button.info.kind, button, button.info.label)
    else list.Open(button.info.slot, button.info.kind, button, button.info.label) end
end

-- A click on a slot (ordinary code; nothing here uses the trinket):
-- left opens or closes the grid of what you carry for that slot, right opens
-- the quick menu. While the bar is unlocked a right-click locks it instead,
-- as a right-click on the bar itself does, and a fight keeps the menu shut
-- the way it keeps the drag locked.
local function Click(button, mouse)
    if mouse == "RightButton" then
        if Module.unlocked then Module:SetUnlocked(false); return end
        if fighting or K().Fight() then return end
        local list = List()
        if list then list.Close() end
        local menu = Menu()
        if menu then menu.Toggle(button) end
        return
    end
    OpenList(button, true)
end

local function Enter(button)
    button.edge:SetVertexColor(1, .82, .3, 1)
    if Hovering() then OpenList(button, false) end
end

local function Leave(button)
    local kit = K()
    button.edge:SetVertexColor(kit.GREY[1], kit.GREY[2], kit.GREY[3], .8)
    local list = List()
    if list then list.CloseSoon() end
end

-- One slot, made once: a plain button with EraUI's own icon, edge, sweep,
-- time and glow on it. It was a secure button while a click used the item;
-- nothing on the bar does that any more, so there is nothing left for the
-- game to protect and no attribute written on it.
local function Slot(info)
    local kit = K()
    local button = CreateFrame("Button", "EraUITrinketSlot" .. info.slot, bar)
    button.info = info
    button:SetSize(SIZE_DEFAULT, SIZE_DEFAULT)
    button:RegisterForClicks("AnyUp")
    button:Hide()
    -- ARTWORK, not BACKGROUND: the box below is one solid fill across the
    -- whole slot, so on BACKGROUND the icon sat UNDER it and every trinket
    -- came out washed grey. The icon is inset by one, so the box still shows
    -- as the slot's edge around it.
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button.edge = button:CreateTexture(nil, "BORDER")
    button.edge:SetTexture(kit.FILL)
    button.edge:SetVertexColor(kit.GREY[1], kit.GREY[2], kit.GREY[3], .8)
    button.edge:SetAllPoints(button)
    -- With the game's own template. Without it a Cooldown has no swipe
    -- texture set up and draws no wedge at all, whatever colour it is told:
    -- ours showed only a number while the character sheet's own slots swept
    -- round beside it (Squirt, 27 Nov 2026). The cooldown manager's icons
    -- use the same template, which is why theirs always swept.
    button.cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cd:SetAllPoints(button.icon)
    button.cd:EnableMouse(false)
    -- The edge is the bright line that sweeps round the rim as the cooldown
    -- runs down, and it is what makes a slot read as a clock rather than a
    -- number sitting on a picture (Squirt, 27 Nov 2026: "i like how theres
    -- like a clock going around"). It costs nothing in readability, unlike
    -- darkening the swipe, which he turned down earlier.
    button.cd:SetDrawEdge(true)
    button.cd:SetDrawBling(false)
    button.cd:SetHideCountdownNumbers(true)
    -- The game's own swipe, not one of ours. It was held at a little over
    -- half on 26 Nov because the full one looked like it blurred the slot
    -- out, but shown the game's own clock beside it Squirt wanted that look
    -- exactly (27 Nov 2026), and a washed sweep reads as broken next to it.
    -- The edge above is what keeps it legible at this size.
    -- The widget's own word for "the sweep has run out", which is what the
    -- ready alert and the glow stand on in a fight (Modules/TrinketAlerts.lua).
    button.cd:SetScript("OnCooldownDone", function() Finished(button) end)
    button.time = kit.Text(button, 12)
    button.time:SetJustifyH("CENTER")
    button.time:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
    button.time:SetTextColor(1, .95, .7)
    button.glow = button:CreateTexture(nil, "OVERLAY")
    button.glow:SetTexture(kit.GLOW)
    button.glow:SetBlendMode("ADD")
    button.glow:SetVertexColor(1, .9, .35)
    button.glow:Hide()
    -- The Queued strip, across the top of the slot. Our own texture on a plain
    -- button, so it goes on and off in a fight as happily as out of one.
    button.mark = kit.QueueStrip(button)
    button:SetScript("OnClick", Click)
    button:SetScript("OnEnter", Enter)
    button:SetScript("OnLeave", Leave)
    return button
end

---------------------------------------------------------------------------
-- Where it sits
---------------------------------------------------------------------------

-- Where it was dragged to (its top left corner, from the screen's, in the
-- screen's units whatever its size), or nil.
local function Saved()
    local spot = E:GetSetting("trinketBarPosition")
    local kit = K()
    if type(spot) == "table" and kit.Num(spot.x) and kit.Num(spot.y) then return spot end
end

local function Place()
    local spot = Saved()
    bar:ClearAllPoints()
    if spot then bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", spot.x, spot.y)
    else bar:SetPoint("BOTTOM", UIParent, "BOTTOM", HOME_X, HOME_Y) end
end

-- After a drag: where its top left corner is now, in the screen's units.
local function Save()
    dragging = false
    bar:StopMovingOrSizing()
    if bar.SetUserPlaced then bar:SetUserPlaced(false) end
    local kit = K()
    local left, top, height = bar:GetLeft(), bar:GetTop(), UIParent:GetHeight()
    if kit.Num(left) and kit.Num(top) and kit.Num(height) then
        E:SetSetting("trinketBarPosition", { x = math.floor(left + .5), y = math.floor(top - height + .5) })
        if E.SaveSettings then E:SaveSettings() end
    end
    Place()
end

---------------------------------------------------------------------------
-- Building and laying out
---------------------------------------------------------------------------

function Module:Paint()
    if not bar then return end
    local kit = K()
    kit.Paint(box)
    local list = List()
    if list then list.Paint() end
    local menu = Menu()
    if menu then menu.Paint() end
    local alerts = Alerts()
    if alerts then alerts.Paint() end
end

-- Made once. Locked it takes no mouse, so clicks go past it to the world;
-- its slots take their own.
local function Build()
    if bar then return end
    local kit = K()
    bar = CreateFrame("Frame", "EraUITrinketBar", UIParent)
    bar:SetSize(PAD * 2 + SIZE_DEFAULT * 2 + GAP, PAD * 2 + SIZE_DEFAULT)
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    -- Its place is EraUI's own (trinketBarPosition): the game's layout cache
    -- never keeps one of its own (Save also lets go of the "moved by you"
    -- mark a drag gives it).
    if bar.SetDontSavePosition then bar:SetDontSavePosition(true) end
    bar:EnableMouse(false)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function(self)
        if not Module.unlocked or fighting then return end
        dragging = true
        self:StartMoving()
    end)
    bar:SetScript("OnDragStop", function() if dragging then Save() end end)
    bar:SetScript("OnMouseUp", function(_, mouse)
        if mouse == "RightButton" and Module.unlocked then Module:SetUnlocked(false) end
    end)
    -- Hidden in the middle of a drag: the drag ends there and that spot is kept.
    bar:SetScript("OnHide", function() if dragging then Save() end end)
    bar:SetScript("OnUpdate", OnUpdate)
    bar:Hide()
    box = kit.Box(bar)
    -- Unlocked: a gold box over it and how to move it, under the slots.
    moveBox = bar:CreateTexture(nil, "OVERLAY")
    moveBox:SetTexture(kit.FILL)
    moveBox:SetVertexColor(.93, .75, .32, .14)
    moveBox:SetAllPoints(bar)
    moveBox:Hide()
    hint = kit.Text(bar, 10)
    hint:SetText("Drag to move. Right-click to lock.")
    hint:SetTextColor(kit.GOLD[1], kit.GOLD[2], kit.GOLD[3])
    hint:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", PAD, 3)
    hint:Hide()
    for _, info in ipairs(kit.SLOTS) do buttons[info.slot] = Slot(info) end
    Module:Paint()
    Place()
end

-- How many slots lie each way: the long way (across in a row, down in a
-- column) and the short way, which is one line or two with Two Rows. One
-- answer covers all four shapes Two Rows and Up and Down make between them.
local function Lanes(count)
    local short = 1
    if E:GetSetting("trinketBarTwoRows") == true and count > 1 then short = 2 end
    local long = math.ceil(count / short)
    if E:GetSetting("trinketBarColumn") == true then return short, long end
    return long, short
end

-- The slots sized, placed and shown or hidden. A row fills across first, a
-- column down first, so Two Rows splits a row into two rows and a column
-- into two columns.
local function Layout()
    local kit = K()
    order = Wanted()
    local size = Size()
    local count = #order
    local across, down = Lanes(count)
    local downward = E:GetSetting("trinketBarColumn") == true
    local taken = {}
    for index, info in ipairs(order) do
        local button = buttons[info.slot]
        taken[info.slot] = true
        local place = index - 1
        local column, row
        if downward then column, row = math.floor(place / down), place % down
        else column, row = place % across, math.floor(place / across) end
        button:SetSize(size, size)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", bar, "TOPLEFT", PAD + column * (size + GAP), -(PAD + row * (size + GAP)))
        button.glow:SetSize(size * 1.6, size * 1.6)
        button.glow:ClearAllPoints()
        button.glow:SetPoint("CENTER", button, "CENTER", 0, 0)
        -- Unlocked, the slots take no mouse, so a drag can start anywhere on
        -- the bar and a right-click anywhere on it locks it again.
        button:EnableMouse(Module.unlocked ~= true)
        button:Show()
    end
    for _, info in ipairs(kit.SLOTS) do
        local button = buttons[info.slot]
        if button and not taken[info.slot] then Blank(button); button:Hide() end
    end
    local hinted = Module.unlocked and HINT_H or 0
    bar:SetSize(PAD * 2 + across * size + math.max(0, across - 1) * GAP,
        PAD * 2 + down * size + math.max(0, down - 1) * GAP + hinted)
    bar:EnableMouse(Module.unlocked == true)
    moveBox:SetShown(Module.unlocked == true)
    hint:SetShown(Module.unlocked == true)
end

-- The bar as the options now have it. Nothing on it is protected any more,
-- so a change asked for in a fight is made there and then.
function Module:Rebuild()
    if not Enabled() then return false end
    Build()
    Layout()
    Place()
    bar:Show()
    self:Pictures()
    return true
end

---------------------------------------------------------------------------
-- Unlock, reset and the options
---------------------------------------------------------------------------

-- Unlock (or Lock). Nothing to unlock while it is off or in a fight.
-- watch(on) hears of each change (/era's Move Bar button).
function Module:SetUnlocked(on)
    on = on and true or false
    if on and not Enabled() then return false end
    if on and (fighting or K().Fight()) then return false end
    if not on and dragging then Save() end
    self.unlocked = on
    if bar then self:Rebuild() end
    if self.watch then self.watch(on) end
    return true
end

-- Reset: back to the first-time spot.
function Module:ResetPosition()
    E:SetSetting("trinketBarPosition", nil)
    if E.SaveSettings then E:SaveSettings() end
    if bar and not dragging then Place() end
end

-- Its switch, ticks, choice and slider in /era and in the quick menu, all
-- at once, in a fight as well as out of one.
function Module:Refresh()
    if not events then return end
    local kit = K()
    local list, menu = List(), Menu()
    if not Enabled() then
        if self.unlocked then
            if dragging then Save() end
            self.unlocked = false
            if self.watch then self.watch(false) end
        end
        if list then list.Close() end
        if menu then menu.Close() end
        -- The alerts go with it: no line left on screen and no warning left
        -- waiting for a bar that is not there any more.
        local alerts = Alerts()
        if alerts then alerts.Reset() end
        if bar then
            order = {}
            for _, info in ipairs(kit.SLOTS) do
                local button = buttons[info.slot]
                if button then Blank(button); button:Hide() end
            end
            bar:EnableMouse(false)
            bar:Hide()
        end
        if watching then events:UnregisterAllEvents(); watching = false end
        return
    end
    if not watching then
        watching = true
        for _, event in ipairs(EVENTS) do pcall(events.RegisterEvent, events, event) end
    end
    fighting = kit.Fight()
    self:Rebuild()
    if list then list.Refresh() end
    if menu then menu.Refresh() end
    -- The sets panel in /era draws a cell for each slot you can see, so it
    -- follows Show Both Slots and Show Your Rings while it is open.
    local sets = SetList()
    if sets then sets.Refresh() end
end

---------------------------------------------------------------------------
-- The game
---------------------------------------------------------------------------

local function OnEvent(_, event)
    if not Enabled() then return end
    local list = List()
    if event == "PLAYER_REGEN_ENABLED" then
        fighting = false
        -- Out of the fight the game's own cooldown numbers can be read
        -- again, so the sweeps and the time left are drawn afresh.
        Module:Pictures()
        if list then list.Refresh() end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        fighting = true
        -- A fight locks the bar and shuts the quick menu: both are about
        -- moving and changing it, and both wait for the fight's end.
        local menu = Menu()
        if menu then menu.Close() end
        if Module.unlocked then Module:SetUnlocked(false) end
        if list then list.Refresh() end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        fighting = K().Fight()
        Module:Rebuild()
        return
    end
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        Module:Rebuild()
        if list then list.Refresh() end
        return
    end
    if event == "BAG_UPDATE_DELAYED" then
        if list then list.Refresh() end
        Module:Pictures()
        return
    end
    if COOLDOWN[event] then Module:Pictures() end
end

function Module:Initialize()
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
    -- The ten trinket set keys (Modules/TrinketKeys.lua). They are made
    -- whether the bar is switched on or not: a key puts a set on with no bar
    -- on screen, and the game's Key Bindings menu shows each key's set either
    -- way.
    local keys = SetKeys()
    if keys then keys.Start() end
    self:Refresh()
end
