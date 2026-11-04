-- Links: the copy-a-link pop-up (an address ready to copy with Ctrl+C), the
-- project's addresses, the Discord invite, EraUI's own chat links (welcome,
-- status report, set up) and the first run's chat line. Also the stand-in
-- welcome Core/Integration.lua replaces with EraUI's own as it loads.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

ns.CURSEFORGE_URL = "https://www.curseforge.com/wow/addons/eraui"
ns.GITHUB_URL = "https://github.com/squirtwow/EraUI"
ns.DISCORD_URL = "https://discord.gg/FVfcDWJncr"

local COPY_POPUP = "ERAUI_CLASSIC_COPY_LINK"

---------------------------------------------------------------------------
-- The copy pop-up
---------------------------------------------------------------------------

local function BoxOf(dialog)
    if dialog == nil then return nil end
    return dialog.EditBox or dialog.editBox or (dialog.GetEditBox and dialog:GetEditBox()) or nil
end

-- The address in the box, all of it chosen (typing just puts it back).
local function Chosen(box, address)
    if box == nil then return end
    box:SetText(address or "")
    box:HighlightText()
end

local function Shut(box)
    local dialog = box and box:GetParent()
    if dialog then dialog:Hide() end
end

if type(StaticPopupDialogs) == "table" then
    StaticPopupDialogs[COPY_POPUP] = {
        text = "%s\n\nPress Ctrl+C to copy.",
        button1 = CLOSE or "Close", hasEditBox = true, editBoxWidth = 360,
        OnShow = function(dialog, address)
            local box = BoxOf(dialog)
            Chosen(box, address)
            if box then box:SetFocus() end
        end,
        EditBoxOnTextChanged = function(box, address)
            if box:GetText() ~= address then Chosen(box, address) end
        end,
        EditBoxOnEscapePressed = Shut,
        EditBoxOnEnterPressed = Shut,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
end

local function CopyLink(label, address)
    if StaticPopup_Show then StaticPopup_Show(COPY_POPUP, label, nil, address) end
end

function EraUI.ShowDiscord()
    ns.CopyLink("Found a bug or have an idea? Join the EraUI Discord.", ns.DISCORD_URL)
end

---------------------------------------------------------------------------
-- Chat links (the game's own "addon" link type, EraUI's name inside)
---------------------------------------------------------------------------

local LINK_HEAD = "addon:EraUI:"

-- A stand-in until Core/Integration.lua puts EraUI's own welcome here.
local function Welcome()
    if type(ns.OpenOptions) == "function" then ns.OpenOptions() end
end

local ROUTES = {
    welcome = function() ns.ShowWelcome() end,
    status = function() if type(ns.ShowStatus) == "function" then ns.ShowStatus() end end,
    layout = function()
        ns.setupRequested = true
        if EraUI.settingsFrame then EraUI.settingsFrame:Hide() end
        ns.ShowWelcome()
    end,
}

local function Clicked(link)
    if type(link) ~= "string" or Look.Secret(link) then return end
    local target = link:match("^" .. LINK_HEAD .. "(%a+)")
    if target and ROUTES[target] then Look.Try(ROUTES[target]) end
end

-- The game hands EraUI's links to the "SetItemRef" event (local addon
-- links); a client without that sees them through a post-hook instead.
local listening, listener = false, {}
local function Listen()
    if listening then return end
    listening = true
    local registry, kinds = EventRegistry, LinkTypes
    if type(registry) == "table" and type(registry.RegisterCallback) == "function" and type(kinds) == "table"
        and kinds.AddOn == "addon" then
        registry:RegisterCallback("SetItemRef", function(_, link) Clicked(link) end, listener)
    else
        Look.HookGlobal("SetItemRef", Clicked)
    end
end

local function ChatLink(target, label)
    Listen()
    return string.format("|cff70d6ff|H%s%s|h[%s]|h|r", LINK_HEAD, tostring(target), tostring(label))
end

---------------------------------------------------------------------------
-- The first run (Core/Integration.lua wraps it: its welcome and notes
-- first, then this)
---------------------------------------------------------------------------

local function FirstRun()
    local saved = ns.db
    if saved == nil then return end
    local wanted = saved.welcomeNote ~= false and not saved.welcomed
    local forever = type(ns.OnForever) == "function" and ns.OnForever()
    if not forever then
        if wanted then ns.ShowWelcome() else ns.CheckLayoutPosition() end
        return
    end
    Listen()
    local parts = {}
    if wanted then parts[#parts + 1] = "read the welcome note " .. ChatLink("welcome", "here") end
    -- The set up link only until the player has set up EraUI or closed its
    -- welcome (which has the same set up), never at every login after that.
    if saved.erauiSetupComplete ~= true and saved.erauiWelcomeSeen ~= true then
        parts[#parts + 1] = "set up EraUI " .. ChatLink("layout", "here")
    end
    if #parts == 0 then return end
    local line = table.concat(parts, ", or ") .. "."
    -- A status line: Quiet Mode keeps it out of chat, like the /era hint.
    if type(EraUI.Status) == "function" then
        EraUI:Status(line)
    elseif type(ns.Print) == "function" then
        ns.Print(line)
    end
end

ns.CopyLink, ns.ChatLink, ns.ShowWelcome, ns.FirstRun = CopyLink, ChatLink, Welcome, FirstRun
