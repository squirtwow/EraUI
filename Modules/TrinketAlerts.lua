local _, E = ...

-- The Trinket Bar's cooldown alerts (/era > Action Bars > Trinkets; all four
-- off to start with): a short line in the middle of the screen as a trinket on
-- the bar comes off cooldown (Say When One Is Ready), another thirty seconds
-- before it does (Warn Thirty Seconds Before), the same words in your own chat
-- as well (Say It In Chat Too) and a small sound with them (Play A Sound).
--
-- Only the slots the bar shows are watched, and they hold what you wear, so
-- nothing here ever walks your bags.
--
-- The line is EraUI's own frame on UIParent, in the same box the bar and the
-- grid wear, and it fades itself: its tick is set as the line shows and put
-- back to nothing as the fade ends, so none of it runs while no line is up.
-- The game's tooltip is never touched.
--
-- Forever keeps a cooldown secret while a fight is on, and a secret may not be
-- compared or added up, so the two alerts are worked out in the only honest
-- ways there are:
--
--   * Ready: the slot's own Cooldown widget counts the game's numbers itself,
--     secret or not, and says so when its sweep runs out. The bar hands that
--     on (Modules/TrinketBar.lua), so this works in a fight with nothing read
--     and nothing compared.
--   * Thirty seconds before: the start and the length are read only while they
--     are plain numbers, which is out of a fight, and one timer is set for the
--     moment thirty seconds are left. A cooldown that began inside a fight has
--     no readable numbers until the fight ends, so its warning is worked out
--     then and is simply left out where under thirty seconds are left by then.
--
-- Nothing here reads the game for itself: the slots, what you wear and the
-- words a player sees are all Modules/TrinketKit.lua's.
local A = {}
E.TrinketAlerts = A

A.WINDOW_NAME = "EraUITrinketAlert"
-- Warn Thirty Seconds Before: how far ahead that line comes.
A.LEAD = 30
-- A small sound with the line (Play A Sound): the first of the game's own
-- kits this client has. One with neither, or without PlaySound, is silent.
A.SOUNDS = {"IG_MAINMENU_OPTION_CHECKBOX_ON", "U_CHAT_SCROLL_BUTTON"}

local WIDTH, HEIGHT, PAD, RISE = 272, 26, 8, 140
local HOLD, FADE = 2.5, 1.2 -- how long the line stays, and how long it fades for
local GAP = 3               -- one line a slot in three seconds, however it was asked for

local function K() return E.TrinketKit end

local frame, box, word
local left = 0
local waiting, said = {}, {}
local tokens = 0

local function Saying() return E:GetSetting("trinketBarReady") == true end
local function Warning() return E:GetSetting("trinketBarWarn") == true end

---------------------------------------------------------------------------
-- The line on screen
---------------------------------------------------------------------------

-- Made once, the first time a line shows, and sized as it is made: Forever may
-- never draw a frame laid out under one without a size. It takes no mouse, so
-- it never comes between you and the world under it.
local function Build()
    if frame then return end
    local kit = K()
    frame = CreateFrame("Frame", A.WINDOW_NAME, UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, RISE)
    frame:EnableMouse(false)
    frame:Hide()
    box = kit.Box(frame)
    word = kit.Text(frame, 14)
    word:SetJustifyH("CENTER")
    word:SetWordWrap(false)
    word:SetPoint("LEFT", frame, "LEFT", PAD, 0)
    word:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    A.frame = frame
end

function A.Paint()
    if not frame then return end
    local kit = K()
    kit.Paint(box)
    word:SetTextColor(kit.GOLD[1], kit.GOLD[2], kit.GOLD[3])
end

-- The fade: the line is held whole, then goes out over a moment, and the tick
-- is put back to nothing as it ends so nothing of this runs between lines.
local function OnUpdate(self, elapsed)
    left = left - (elapsed or 0)
    if left > FADE then return end
    if left <= 0 then
        self:SetScript("OnUpdate", nil)
        self:Hide()
        self:SetAlpha(1)
        left = 0
        return
    end
    self:SetAlpha(left / FADE)
end

-- One line, in the middle of the screen. A line while one is already up takes
-- its place and the fade starts again.
function A.Line(text)
    if not K().Word(text) then return false end
    Build()
    A.Paint()
    word:SetText(text)
    left = HOLD + FADE
    frame:SetAlpha(1)
    frame:Show()
    frame:SetScript("OnUpdate", OnUpdate)
    return true
end

local function Sound()
    if E:GetSetting("trinketBarSound") ~= true then return false end
    local kits = SOUNDKIT
    if type(kits) ~= "table" or type(PlaySound) ~= "function" then return false end
    for _, name in ipairs(A.SOUNDS) do
        local kit = kits[name]
        if kit ~= nil then
            pcall(PlaySound, kit)
            return true
        end
    end
    return false
end

-- A line said: on the screen, in your chat with Say It In Chat Too, and with
-- the sound where that is on. One way out for both alerts, so the two always
-- read and sound the same.
function A.Say(text)
    local kit = K()
    if not A.Line(text) then return false end
    if E:GetSetting("trinketBarChat") == true then E:Status(kit.SAID .. text) end
    Sound()
    return true
end

-- One line a slot in three seconds: the game's own widget and the bar's tick
-- can both see the same cooldown run out, and that is one trinket coming
-- ready, not two. GetTime is never secret, so this is safe in a fight.
local function Fresh(slot, now)
    local kit = K()
    if not kit.Num(now) then return true end
    local was = said[slot]
    if was and now - was < GAP then return false end
    said[slot] = now
    return true
end

-- What the line calls the item: its own name where the client knows it, else
-- the slot's ("Trinket 1").
local function Name(info, id)
    return K().ById(id) or info.label or "Trinket"
end

---------------------------------------------------------------------------
-- Say When One Is Ready
---------------------------------------------------------------------------

-- A slot's cooldown has run out (the bar says so, from its own Cooldown
-- widget out of a fight and in one alike).
function A.Ready(info, id)
    if type(info) ~= "table" or not Saying() then return false end
    local kit = K()
    if not Fresh(info.slot, kit.Call(GetTime)) then return false end
    return A.Say(string.format(kit.READY, Name(info, id)))
end

---------------------------------------------------------------------------
-- Warn Thirty Seconds Before
---------------------------------------------------------------------------

-- The warning's own moment. The slot must still hold the same item: an item's
-- ID is never secret, so that holds in a fight as well.
local function Due(slot, token)
    local kept = waiting[slot]
    if not (kept and kept.token == token) then return false end
    waiting[slot] = nil
    if not Warning() then return false end
    local kit = K()
    local id = kit.Worn(slot)
    if id == nil or id ~= kept.id then return false end
    if not Fresh(slot, kit.Call(GetTime)) then return false end
    return A.Say(string.format(kit.SOON, Name(kept.info, id), A.LEAD))
end

-- A slot's cooldown as the bar last read it. Only plain numbers get this far
-- (in a fight the bar has nothing to hand over), so the one piece of adding
-- up here is on the game's own readable numbers and never on a secret.
--
-- The same cooldown asked about again changes nothing: the bar reads its slots
-- ten times a second, and one timer a cooldown is all that is set. Under
-- thirty seconds left when it is read: nothing to warn about.
function A.Watch(info, id, start, length)
    local kit = K()
    if type(info) ~= "table" or not Warning() then return false end
    if not (kit.Num(id) and kit.Num(start) and kit.Num(length)) then return false end
    local now = kit.Call(GetTime)
    if not kit.Num(now) then return false end
    local finish = start + length
    local at = finish - A.LEAD
    if at <= now then return false end
    local kept = waiting[info.slot]
    if kept and kept.id == id and math.abs(kept.finish - finish) < .5 then return false end
    local after = C_Timer and C_Timer.After
    if type(after) ~= "function" then return false end
    tokens = tokens + 1
    local slot, token = info.slot, tokens
    waiting[slot] = {token = token, id = id, finish = finish, info = info}
    kit.Call(after, at - now, function() Due(slot, token) end)
    return true
end

-- No cooldown on that slot any more (it ran out, the item came off, or the
-- game has nothing to say about it): its warning is dropped. A timer already
-- out finds nothing waiting and does nothing, and a token is never used twice.
function A.Forget(slot)
    if waiting[slot] == nil then return false end
    waiting[slot] = nil
    return true
end

-- The bar switched off: nothing waiting and no line left on screen.
function A.Reset()
    waiting, said = {}, {}
    if not frame then return false end
    frame:SetScript("OnUpdate", nil)
    frame:SetAlpha(1)
    left = 0
    frame:Hide()
    return true
end

function A.Shown() return frame ~= nil and frame:IsShown() end
-- What is waiting for its thirty-second warning on that slot, or nothing.
function A.Pending(slot) return waiting[slot] end
