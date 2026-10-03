-- /era reset asks first. Runs the real slash command, the real Persistence
-- reset and EraUI's own prompt: typing /era reset alone never resets or
-- reloads, only the prompt's Reset button does, Cancel, the X and Escape do
-- nothing, a fight refuses (before and after the prompt exists), no key can
-- reach Reset, the prompt is placed, sized and readable, its words have no
-- dashes, and /era help says it asks.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function Has(text, part, label)
    checks = checks + 1
    assert(type(text) == "string" and text:find(part, 1, true) ~= nil,
        label .. ": expected to find " .. part .. " in " .. tostring(text))
end

local combat, failWrite = false, nil
local cvars, printed, everyLine, everyText = {}, {}, {}, {}
local resets, reloads = 0, 0
local prompt
local created = {}

InCombatLockdown = function() return combat end
UnitClass = function() return "Mage", "MAGE" end
RAID_CLASS_COLORS = { MAGE = { r = .4, g = .8, b = 1 } }
UISpecialFrames = {}
SlashCmdList = {}
UIParent = { width = 1920, height = 1080 }
GameFontHighlight = { GetFont = function() return "font", 12, "" end }
-- The prompt is EraUI's own window: the game's shared popups stay untouched.
StaticPopupDialogs = setmetatable({}, { __newindex = function() error("the reset prompt must not add a game popup") end })
StaticPopup_Show = function() error("the reset prompt must not open a game popup") end
-- No key binding may reach Reset either.
for _, name in ipairs({ "SetOverrideBinding", "SetOverrideBindingClick", "SetBinding", "SetBindingClick" }) do
    _G[name] = function() error("the reset prompt must not bind keys: " .. name) end
end
C_CVar = {
    GetCVar = function(name) return cvars[name] end,
    RegisterCVar = function(name, value) cvars[name] = value end,
    SetCVar = function(name, value)
        if name == failWrite then error("simulated write failure: " .. name) end
        cvars[name] = value
    end,
}
ReloadUI = function()
    assert(not combat, "reload refused in combat")
    assert(cvars.EraUIRecovery1Reset == "1", "the reset request must be durable before the reload")
    assert(prompt and prompt:IsShown(), "reload refused: the prompt was hidden before the reload request")
    reloads = reloads + 1
end

-- Regions and frames remember where they are placed, their size and colours,
-- so the test can tell whether the prompt would draw and be readable.
local function Region(parent)
    local r = { parent = parent, shown = true, anchors = {} }
    for _, name in ipairs({ "SetJustifyH", "SetAllPoints", "SetFont" }) do
        r[name] = function() end
    end
    function r:SetPoint(...) self.anchors[#self.anchors + 1] = { ... } end
    function r:SetWidth(width) self.width = width end
    function r:SetHeight(height) self.height = height end
    function r:SetColorTexture(...) self.colour = { ... } end
    function r:SetText(text)
        self.text = text
        everyText[#everyText + 1] = tostring(text)
    end
    function r:GetText() return self.text end
    function r:SetTextColor(...) self.textColour = { ... } end
    return r
end
local function Frame(kind, name, parent)
    local f = Region(parent)
    f.kind, f.name, f.scripts = kind, name, {}
    for _, method in ipairs({ "SetClampedToScreen", "SetMovable", "RegisterForDrag", "Raise", "RegisterEvent" }) do
        f[method] = function() end
    end
    function f:SetSize(width, height) self.width, self.height = width, height end
    function f:EnableMouse(on) self.mouse = on end
    function f:SetToplevel(on) self.toplevel = on end
    function f:SetBackdrop(backdrop) self.backdrop = backdrop end
    function f:SetBackdropColor(...) self.fill = { ... } end
    function f:SetBackdropBorderColor(...) self.edge = { ... } end
    function f:EnableKeyboard(on) self.keyboard = on end
    function f:SetFrameStrata(strata) self.strata = strata end
    function f:SetScript(key, fn) self.scripts[key] = fn end
    -- Like the client, showing and hiding run OnShow and OnHide.
    function f:Show()
        if self.shown then return end
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function f:Hide()
        if not self.shown then return end
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function f:IsShown() return self.shown and (not self.parent or self.parent.IsShown == nil or self.parent:IsShown()) end
    function f:CreateTexture() return Region(self) end
    function f:CreateFontString() return Region(self) end
    function f:Click() self.scripts.OnClick(self) end
    return f
end
CreateFrame = function(kind, name, parent)
    local f = Frame(kind, name, parent)
    if name then _G[name] = f end
    created[#created + 1] = f
    return f
end
-- What the client does with Escape for windows listed in UISpecialFrames.
local function PressEscape()
    for _, name in ipairs(UISpecialFrames) do
        local frame = _G[name]
        if frame and frame:IsShown() then frame:Hide() end
    end
end

local E = { modules = {} }
function E:Print(message)
    printed[#printed + 1] = tostring(message)
    everyLine[#everyLine + 1] = tostring(message)
end
assert(loadfile("Core/Persistence.lua"))("EraUI", E)
assert(loadfile("Core/Presets.lua"))("EraUI", E)
assert(loadfile("Core/Commands.lua"))("EraUI", E)
local realReset = E.Persistence.Reset
E.Persistence.Reset = function(self, ...)
    resets = resets + 1
    return realReset(self, ...)
end
local function Slash(text) SlashCmdList.ERAUI(text) end
local function Last() return printed[#printed] end
local function NothingHappened(label)
    Equal(resets, 0, label .. ": no settings reset")
    Equal(reloads, 0, label .. ": no reload")
    Equal(cvars.EraUIRecovery1Reset, nil, label .. ": no reset request saved")
    Equal(E.Persistence.resetting, nil, label .. ": settings keep saving")
end

-- In a fight: only the chat line, no prompt -----------------------------------------------
combat = true
Slash("reset")
Equal(Last(), "Finish combat before resetting EraUI settings.", "a fight: says to finish combat")
Equal(_G.EraUIResetPrompt, nil, "a fight: no prompt is made")
NothingHappened("a fight")
combat = false

-- /era reset alone only asks --------------------------------------------------------------
printed = {}
local firstMade = #created + 1
Slash("reset")
prompt = _G.EraUIResetPrompt
Equal(prompt ~= nil and prompt:IsShown(), true, "/era reset opens the prompt")
NothingHappened("/era reset alone")
Equal(#printed, 0, "/era reset alone prints nothing")
Equal(prompt.strata, "FULLSCREEN_DIALOG", "the prompt sits above /era, like the Presets window")
Equal(prompt.title.text, "Reset EraUI", "the title")
Equal(prompt.message.text, "Reset all EraUI settings to defaults? This reloads your UI.", "the question")
Equal(prompt.reset.label.text, "Reset", "Reset button")
Equal(prompt.cancel.label.text, "Cancel", "Cancel button")
Equal(prompt.close.label.text, "X", "the /era-style X")
Equal(prompt.note.text, "", "no warning to start with")

-- It draws, and can be read: placed, sized, dark behind the light text ---------------------
local function Sized(region, label)
    Equal(type(region.width) == "number" and region.width > 0, true, label .. " has a width")
    Equal(type(region.height) == "number" and region.height > 0, true, label .. " has a height")
end
local function Placed(region, label) Equal(#region.anchors > 0, true, label .. " is placed") end
local function Dark(colour, most, label)
    Equal(type(colour) == "table" and colour[1] <= most and colour[2] <= most and colour[3] <= most
        and (colour[4] == nil or colour[4] >= .9), true, label)
end
-- Where a frame placed by one point on its parent sits: left, bottom, right, top.
local function Box(f)
    Equal(#f.anchors, 1, "one anchor")
    local point, x, y = f.anchors[1][1], f.anchors[1][2] or 0, f.anchors[1][3] or 0
    assert(type(x) == "number" and type(y) == "number", "the test only reads anchors on the parent")
    local width, height = f.parent.width, f.parent.height
    local left = point:find("LEFT") and x or point:find("RIGHT") and (width + x - f.width) or ((width - f.width) / 2 + x)
    local bottom = point:find("BOTTOM") and y or point:find("TOP") and (height + y - f.height) or ((height - f.height) / 2 + y)
    return left, bottom, left + f.width, bottom + f.height
end
Equal(prompt.parent, UIParent, "the prompt hangs off the screen itself")
Placed(prompt, "the prompt"); Sized(prompt, "the prompt")
Equal(prompt.mouse, true, "the prompt catches clicks, so they don't reach /era underneath")
Equal(prompt.toplevel, true, "the prompt comes to the front when clicked")
Equal(prompt.backdrop and prompt.backdrop.bgFile ~= nil, true, "the prompt has a backing")
Dark(prompt.fill, .1, "the prompt's backing is dark under its light text")
Equal(prompt.edge ~= nil, true, "the prompt has an edge colour")
Placed(prompt.stripe, "the class stripe"); Equal(prompt.stripe.height, 3, "the class stripe's height")
Equal(prompt.stripe.colour and table.concat(prompt.stripe.colour, ","), "0.4,0.8,1,1", "the stripe is the class colour")
Placed(prompt.title, "the title"); Placed(prompt.message, "the question"); Placed(prompt.note, "the note")
Equal((prompt.message.width or 0) > 0 and (prompt.note.width or 0) > 0, true, "the question and note wrap inside the prompt")
for _, button in ipairs({ prompt.reset, prompt.cancel }) do
    local name = button.label.text
    Placed(button, name); Sized(button, name); Placed(button.label, name .. "'s label")
    Equal(button.backdrop and button.backdrop.bgFile ~= nil, true, name .. " has a backing")
    Dark(button.fill, .25, name .. "'s backing is dark under its light label")
    Equal(button.edge and table.concat(button.edge, ","), "0.4,0.8,1,1", name .. " has a class-coloured edge")
    local left, bottom, right, top = Box(button)
    Equal(left >= 0 and bottom >= 0 and right <= prompt.width and top <= prompt.height, true, name .. " sits inside the prompt")
    local resting = button.fill[1] + button.fill[2] + button.fill[3]
    button.scripts.OnEnter(button)
    local lit = button.fill[1] + button.fill[2] + button.fill[3]
    Equal(lit > resting, true, name .. " lights up on hover")
    Dark(button.fill, .35, name .. " stays dark enough to read on hover")
    button.scripts.OnLeave(button)
    Equal(button.fill[1] + button.fill[2] + button.fill[3], resting, name .. " goes back after hover")
end
do
    local l1, b1, r1, t1 = Box(prompt.reset)
    local l2, b2, r2, t2 = Box(prompt.cancel)
    Equal(r1 <= l2 or r2 <= l1 or t1 <= b2 or t2 <= b1, true, "Reset and Cancel don't overlap")
end
local red = prompt.reset.label.textColour
Equal(type(red) == "table" and red[1] > .8 and red[2] < .6 and red[3] < .6, true, "Reset's label is red")
Placed(prompt.close, "the X"); Sized(prompt.close, "the X")

-- No keys reach it, so Enter never resets ----------------------------------------------------
Equal(#created - firstMade + 1 >= 4, true, "the prompt, its two buttons and the X are made")
for i = firstMade, #created do
    local f = created[i]
    local name = (f.label and f.label.text) or f.name or "a prompt frame"
    Equal(f.keyboard, nil, name .. " takes no keys")
    for _, script in ipairs({ "OnKeyDown", "OnKeyUp", "OnChar" }) do
        Equal(f.scripts[script], nil, name .. " has no " .. script)
    end
end
local function Listed()
    local listed = 0
    for _, name in ipairs(UISpecialFrames) do if name == "EraUIResetPrompt" then listed = listed + 1 end end
    return listed
end
Equal(Listed(), 1, "Escape closes it")
for _, text in ipairs({ "  RESET  ", "Reset" }) do
    prompt:Hide(); Slash(text)
    Equal(prompt:IsShown(), true, "'" .. text .. "' opens the prompt too")
    NothingHappened("'" .. text .. "'")
end
Slash("reset")
Equal(_G.EraUIResetPrompt, prompt, "asking again reuses the one prompt")
Equal(Listed(), 1, "and lists it for Escape once")

-- Cancel, the X and Escape do nothing -------------------------------------------------------
prompt.cancel:Click()
Equal(prompt:IsShown(), false, "Cancel closes the prompt")
NothingHappened("Cancel")
Slash("reset"); prompt.close:Click()
Equal(prompt:IsShown(), false, "the X closes the prompt")
NothingHappened("the X")
Slash("reset"); PressEscape()
Equal(prompt:IsShown(), false, "Escape closes the prompt")
NothingHappened("Escape")
for _, event in ipairs({ "OnEnter", "OnLeave" }) do
    prompt.reset.scripts[event](prompt.reset); prompt.cancel.scripts[event](prompt.cancel)
end
NothingHappened("hovering the buttons")

-- A fight once the prompt has been made: still only the chat line ---------------------------
printed = {}
combat = true
Slash("reset")
Equal(prompt:IsShown(), false, "a later fight: the prompt stays shut")
Equal(Last(), "Finish combat before resetting EraUI settings.", "a later fight: says to finish combat")
NothingHappened("a later fight")
combat = false
-- Open when the fight starts: /era reset again only says to finish, and resets nothing.
Slash("reset")
printed = {}
combat = true
Slash("reset")
Equal(Last(), "Finish combat before resetting EraUI settings.", "a fight with the prompt up: says to finish combat")
NothingHappened("a fight with the prompt up")
combat = false
prompt:Hide()

-- A fight that starts with the prompt up ----------------------------------------------------
printed = {}
Slash("reset")
combat = true
prompt.reset:Click()
Equal(resets, 1, "a fight: Reset asks Persistence, which refuses")
Equal(reloads, 0, "a fight: no reload")
Equal(cvars.EraUIRecovery1Reset, nil, "a fight: no reset request saved")
Equal(Last(), "Finish combat before resetting EraUI settings.", "a fight: chat says to finish combat")
Equal(prompt:IsShown(), true, "a fight: the prompt stays up to try again")
Equal(prompt.note.text, "|cffff5555Finish combat first, then click Reset again.|r", "a fight: the prompt says so too, in red")
combat = false

-- A reset request that can't be saved --------------------------------------------------------
resets = 0
failWrite = "EraUIRecovery1Reset"
prompt.reset:Click()
Equal(resets, 1, "failed request: Reset asked Persistence")
Equal(reloads, 0, "failed request: no reload")
Equal(E.Persistence.resetting, nil, "failed request: settings keep saving")
Has(Last(), "could not be saved", "failed request: chat says the settings were kept")
Equal(prompt:IsShown(), false, "failed request: the prompt closes")
failWrite = nil

-- Reset ----------------------------------------------------------------------------------------
resets, printed = 0, {}
Slash("reset")
Equal(prompt.note.text, "", "reopened: the old warning is gone")
prompt.reset:Click()
Equal(resets, 1, "Reset resets exactly once")
Equal(cvars.EraUIRecovery1Reset, "1", "Reset saves the durable reset request")
Equal(E.Persistence.resetting, true, "Reset stops further saves until the reload")
Equal(reloads, 1, "Reset reloads straight from the click")
Equal(Last(), "Resetting settings to defaults. Reloading UI...", "Reset says it is reloading")

-- /era help ------------------------------------------------------------------------------------
printed = {}
Slash("help")
local resetHelp
for _, line in ipairs(printed) do
    if line:find("/era reset", 1, true) then
        Equal(resetHelp, nil, "/era help explains /era reset once")
        resetHelp = line
    end
end
Equal(resetHelp, "/era reload reloads the UI; /era reset asks first, then restores default settings and reloads (outside combat).",
    "/era help says /era reset asks first")

-- No dashes in anything a player reads here -------------------------------------------------
Equal(#everyText > 0 and #everyLine > 0, true, "the prompt's words and the chat lines were seen")
for _, list in ipairs({ everyText, everyLine }) do
    for _, text in ipairs(list) do
        Equal(text:find("\226\128\148", 1, true) == nil and text:find("\226\128\147", 1, true) == nil, true,
            "no dash in: " .. text)
    end
end

print("Reset prompt: " .. checks .. " assertions passed")
