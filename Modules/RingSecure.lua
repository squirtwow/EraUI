local _, E = ...

-- Action Rings' secure side (Modules/ActionRings.lua): one header
-- (SecureHandlerBaseTemplate), and for each of the ten rings a named button
-- (EraUIRingButton1 to 10, SecureActionButtonTemplate) that the game's Key
-- Bindings menu clicks (Bindings.xml, "CLICK EraUIRingButtonN:LeftButton";
-- the player sets the key there, EraUI never sets one) and an invisible,
-- mouse-off hit frame (SecureFrameTemplate) 4096 wide, so a release anywhere
-- on screen picks by direction. One more invisible, mouse-off secure frame
-- covers the screen, so the secure code can measure it and move a ring
-- opened near an edge in far enough to show whole. Each button takes a key's
-- down and up clicks and acts on the up one, whatever the game's key-down
-- setting says.
-- The choice is Modules/RingSnippet.lua's PICK, wrapped round the button's
-- OnClick, so it runs as the game's own secure code, in a fight too.
--
-- Everything here that changes the buttons, the header or the hit frames
-- runs out of combat only: built once, then each ring's slices written as
-- attributes (s<k>-type, -key, -value, -action, -slot; ring-count, dead2,
-- tap2, ring-edge, ring-foot, ring-off) together with its face
-- (Modules/RingView.lua). A change asked
-- for in a fight is kept (dirty) and made when it ends. PostClick (after the
-- click, ordinary code) only reads the button and tells the view.
local S = {}
E.RingSecure = S

S.NAME = "EraUIRingButton"
S.buttons, S.hits, S.dirty, S.signature = {}, {}, {}, {}

local function Snip() return E.RingSnippet end
local function Module() return E.modules and E.modules.ActionRings end
local function On()
    local module = Module()
    return module ~= nil and module:Enabled()
end

-- The game's secure handler calls, by their global names (the header's own
-- methods where a client has only those).
local function SetRef(header, label, frame)
    if type(SecureHandlerSetFrameRef) == "function" then SecureHandlerSetFrameRef(header, label, frame)
    else header:SetFrameRef(label, frame) end
end
local function Wrap(button, header, body)
    if type(SecureHandlerWrapScript) == "function" then SecureHandlerWrapScript(button, "OnClick", header, body)
    else header:WrapScript(button, "OnClick", body) end
end
local function Execute(header, body)
    if type(SecureHandlerExecute) == "function" then SecureHandlerExecute(header, body)
    else header:Execute(body) end
end

-- Ring Size, 75 to 150 percent, as a scale.
function S.Scale()
    local value = tonumber(E:GetSetting("actionRingScale")) or 100
    return math.max(75, math.min(150, value)) / 100
end

-- After the click (ordinary code): the view hears that a ring opened, or
-- closed and what was picked. A key with its
-- ring off (none there, or the rings stopped) did nothing and PICK left
-- "chosen" as the last pick had it, so nothing is heard. ring-off changes
-- only out of combat, never inside a click, so it reads here as PICK read it.
function S.PostClick(button, _, down)
    if button:GetAttribute("ring-off") then return end
    local slot = button:GetAttribute("ring-slot")
    if not (slot and S.hits[slot]) then return end
    local chosen = button:GetAttribute("chosen")
    local view = E.RingView
    if down then
        if chosen == -1 and view then view.Opened(slot) end
        return
    end
    if view then view.Closed(slot, chosen) end
end

-- The header, the screen frame, the ten hit frames and the ten buttons,
-- once, out of combat. The rings show above every window (/era's included).
function S.Build()
    if S.built then return true end
    if InCombatLockdown() then return false end
    local RS = Snip()
    local header = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    header:SetSize(1, 1)
    header:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    S.header = header
    local screen = CreateFrame("Frame", nil, UIParent, "SecureFrameTemplate")
    screen:SetAllPoints(UIParent)
    screen:EnableMouse(false)
    screen:Show()
    S.screen = screen
    SetRef(header, "screen", screen)
    for slot = 1, RS.RINGS do
        local hit = CreateFrame("Frame", nil, UIParent, "SecureFrameTemplate")
        hit:SetSize(RS.HIT, RS.HIT)
        hit:SetFrameStrata("FULLSCREEN_DIALOG")
        hit:EnableMouse(false)
        hit:SetPoint("CENTER")
        hit:Hide()
        S.hits[slot] = hit
        SetRef(header, "ring" .. slot, hit)
        local button = CreateFrame("Button", S.NAME .. slot, UIParent, "SecureActionButtonTemplate")
        button:SetSize(1, 1)
        button:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        button:SetAlpha(0)
        button:EnableMouse(false)
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:SetAttribute("useOnKeyDown", false)
        button:SetAttribute("ring-slot", slot)
        button:SetAttribute("ring-off", true)
        button:SetAttribute("ring-count", 0)
        Wrap(button, header, RS.PICK)
        button:SetScript("PostClick", S.PostClick)
        S.buttons[slot] = button
    end
    S.built = true
    return true
end

-- A change in a fight: made when it ends. Said once a fight, and only for
-- a change from the editor.
function S.Later(slot, said)
    S.dirty[slot] = true
    if said and not S.told then
        S.told = true
        E:Status("Action Rings: your ring changes when this fight ends.")
    end
end

-- A ring's attributes, worked out: {key = value} for every s<k>-* of the
-- sixteen, and its slices with what the view needs (ready, cast, name, icon).
function S.Work(slot)
    local D, F, RS = E.RingData, E.RingFill, Snip()
    local ring = On() and D.Ring(slot) or nil
    local list = ring and F.Slices(ring) or {}
    local ctx = {ranks = F.BestRanks().byName}
    local attrs, parts = {}, {ring and (ring.kind .. ":" .. tostring(ring.name)) or "-", #list, S.Scale()}
    for k = 1, RS.SLICES do
        local slice = list[k]
        local kind, key, value, action, hand
        if slice then
            kind, key, value, action, hand = D.Attr(slice, ctx)
            if not kind then key, value, action, hand = nil, nil, nil, nil end
            slice.ready, slice.cast = kind ~= nil, value
            slice.name, slice.icon = D.Display(slice, ctx)
            parts[#parts + 1] = table.concat({tostring(kind), tostring(key), tostring(value), tostring(action), tostring(hand),
                tostring(slice.name), tostring(slice.icon)}, "|")
        end
        local pre = "s" .. k .. "-"
        attrs[pre .. "type"], attrs[pre .. "key"], attrs[pre .. "value"] = kind, key, value
        attrs[pre .. "action"], attrs[pre .. "slot"] = action, hand
    end
    return ring, list, attrs, table.concat(parts, "\n")
end

-- Writes a ring's slices on its button and draws its face, out of combat
-- only (in a fight it waits: dirty). Nothing is written when nothing changed.
function S.Apply(slot, said, force)
    if not S.built then return false end
    if InCombatLockdown() then S.Later(slot, said); return false end
    S.dirty[slot] = nil
    local ring, list, attrs, signature = S.Work(slot)
    if not force and S.signature[slot] == signature then return true end
    S.signature[slot] = signature
    local button, RS = S.buttons[slot], Snip()
    for k = 1, RS.SLICES do
        local pre = "s" .. k .. "-"
        for _, part in ipairs({"type", "key", "value", "action", "slot"}) do
            button:SetAttribute(pre .. part, attrs[pre .. part])
        end
    end
    local scale = S.Scale()
    local view = E.RingView
    button:SetAttribute("ring-count", #list)
    button:SetAttribute("dead2", RS.Dead2(scale))
    button:SetAttribute("tap2", RS.Tap2(scale))
    button:SetAttribute("ring-edge", (view and view.Edge(#list) or RS.DEAD) * scale)
    button:SetAttribute("ring-foot", (view and view.Foot(#list) or RS.DEAD) * scale)
    button:SetAttribute("ring-off", ring == nil)
    if view then view.Layout(slot, S.hits[slot], list, ring, scale) end
    return true
end

function S.ApplyAll(said, force)
    for slot = 1, Snip().RINGS do S.Apply(slot, said, force) end
end

-- Every ring put away (out of combat only): the snippet's CLOSE on the header.
function S.CloseAll()
    if not S.built or InCombatLockdown() then return false end
    Execute(S.header, Snip().CLOSE)
    if E.RingView then E.RingView.Reset() end
    return true
end

-- The option off: every key does nothing and every ring is put away; in a
-- fight, when it ends.
function S.Off()
    if not S.built then return true end
    if InCombatLockdown() then
        for slot = 1, Snip().RINGS do S.dirty[slot] = true end
        S.closeLater = true
        return false
    end
    for slot = 1, Snip().RINGS do
        S.buttons[slot]:SetAttribute("ring-off", true)
        S.signature[slot] = nil
    end
    S.CloseAll()
    return true
end

-- A fight ended: built if it was waiting, then each ring changed in it.
function S.OnRegen()
    S.told = nil
    if On() and not S.built then
        S.Build()
        S.ApplyAll(false, true)
        return
    end
    if not S.built then return end
    for slot = 1, Snip().RINGS do
        if S.dirty[slot] then S.Apply(slot) end
    end
    if S.closeLater then
        S.closeLater = nil
        S.CloseAll()
    end
end

-- A ring's key, as the game shows it ("F7"), or nil.
function S.KeyText(slot)
    local D = E.RingData
    local key = D.Call(GetBindingKey, "CLICK " .. S.NAME .. slot .. ":LeftButton")
    if not D.Str(key) then return nil end
    local text = D.Call(GetBindingText, key)
    return D.Str(text) and text or key
end
