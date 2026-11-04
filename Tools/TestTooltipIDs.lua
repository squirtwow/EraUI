-- Tooltip IDs (Modules/ExtraQoL.lua) on a small model of the game's tooltip
-- data path (TooltipDataHandler.lua in 70425): a fresh fill starts a new
-- infoList and clears the lines, an append keeps both, a rebuild starts a
-- new list, and OnTooltipCleared drops the list. Audit A8: the comparison
-- tooltips (ShoppingTooltip1/2) and the quest reward tooltip, which EraUI
-- never clears through a hook, must get their ID line on every fill, never
-- twice in one fill. Every tooltip is a proxy that refuses key writes and
-- counts hooks, so the checks also prove nothing is stored or hooked on them.
-- Run from the addon folder: fengari Tools/TestTooltipIDs.lua
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local settings = { tooltipIDs = true }
local E = { modules = {} }
function E:RegisterModule(name, module) self.modules[name] = module end
function E:GetSetting(key) return settings[key] end

local SECRET = {}
issecretvalue = function(value) return value == SECRET end
Enum = { TooltipDataType = { Item = 0, Spell = 1, Unit = 2 } }
local postCalls = {}
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) postCalls[#postCalls + 1] = { kind, fn } end }
strsplit = function(sep, text)
    local parts = {}
    for part in (text .. sep):gmatch("(.-)" .. sep:gsub("%-", "%%-")) do parts[#parts + 1] = part end
    return table.unpack(parts)
end

-- The game's tooltip: Blizzard's own keys (infoList) live behind a proxy
-- that refuses EraUI's writes.
local hooks = 0
local function Tooltip(name)
    local b = { name = name, lines = {} }
    local p = setmetatable({}, { __index = b, __newindex = function(_, key) error("wrote " .. tostring(key) .. " on " .. name) end })
    function b.IsForbidden() return false end
    function b.HookScript() hooks = hooks + 1 end
    function b.AddDoubleLine(_, left, right) b.lines[#b.lines + 1] = left .. "=" .. right end
    function b.AddLine(_, text) b.lines[#b.lines + 1] = text end
    -- What the game does (ProcessInfo): a new list and no lines unless
    -- appending, the data's own lines, then the add-ons' post-calls.
    function b.Process(_, kind, data, append)
        if not append then
            b.infoList = {}
            b.lines = {}
        elseif not b.infoList then
            b.infoList = {}
        end
        table.insert(b.infoList, data)
        b.lines[#b.lines + 1] = data.text or "?"
        for _, call in ipairs(postCalls) do
            if call[1] == kind then call[2](p, data) end
        end
    end
    -- RebuildFromTooltipInfo: a new list, every info filled again.
    function b.Rebuild(self)
        local list = b.infoList
        b.infoList = {}
        b.lines = {}
        for i, data in ipairs(list) do
            b.infoList[#b.infoList + 1] = data
            b.lines[#b.lines + 1] = data.text or "?"
            for _, call in ipairs(postCalls) do
                if call[1] == data.kind then call[2](p, data) end
            end
        end
    end
    -- OnTooltipCleared: ClearHandlerInfo drops the list.
    function b.Clear() b.infoList = nil; b.lines = {} end
    return p, b
end
local function Count(b, text)
    local n = 0
    for _, line in ipairs(b.lines) do if line == text then n = n + 1 end end
    return n
end

GameTooltip = Tooltip("GameTooltip")
ItemRefTooltip = Tooltip("ItemRefTooltip")
local shopping, shoppingBack = Tooltip("ShoppingTooltip1")
local reward, rewardBack = Tooltip("EmbeddedItemTooltip")
local gameBack = getmetatable(GameTooltip).__index

assert(loadfile("Modules/ExtraQoL.lua"))("EraUI", E)
local Module = E.modules.ExtraQoL
Module:SetupTooltipIDs()
equal(#postCalls, 3, "three post-calls: item, spell and unit")
equal(hooks, 0, "no hook on GameTooltip or ItemRefTooltip on this client (the list is enough)")

local sword = { kind = 0, id = 1234, text = "Sword" }
local helm = { kind = 0, id = 5678, text = "Helm" }

-- A bag hover: the comparison tooltip is filled twice in a row with the same
-- equipped item (FinalizeItemTooltip, then the bag button's OnUpdate).
shopping:Process(0, helm)
equal(Count(shoppingBack, "Item ID=5678"), 1, "A8: the comparison tooltip's first fill shows Item ID")
shopping:Process(0, helm)
equal(Count(shoppingBack, "Item ID=5678"), 1, "A8: its second fill in a row shows it again, once")
shopping:Process(0, sword)
shopping:Process(0, helm)
equal(Count(shoppingBack, "Item ID=5678"), 1, "A8: back to the same item later: still shown")

-- An append keeps the list: the same ID is never added twice in one fill.
shopping:Process(0, helm, true)
equal(Count(shoppingBack, "Item ID=5678"), 1, "an append of the same item keeps one ID line")
shopping:Process(0, sword, true)
equal(Count(shoppingBack, "Item ID=1234") .. " " .. Count(shoppingBack, "Item ID=5678"), "1 1", "an append of another item adds its own")

-- A rebuild (RebuildFromTooltipInfo) fills it again from a new list.
shoppingBack.Rebuild(shopping)
equal(Count(shoppingBack, "Item ID=1234") .. " " .. Count(shoppingBack, "Item ID=5678"), "1 1", "after a rebuild both IDs once again")

-- The quest reward tooltip, never cleared through a hook here.
reward:Process(0, sword)
reward:Process(0, sword)
equal(Count(rewardBack, "Item ID=1234"), 1, "A8: the quest reward tooltip shows Item ID on each fill")

-- GameTooltip cleared by the game (OnTooltipCleared) and filled again.
GameTooltip:Process(0, sword)
gameBack.Clear()
GameTooltip:Process(0, sword)
equal(Count(gameBack, "Item ID=1234"), 1, "GameTooltip: cleared and filled again, one ID line")

-- Spells and NPCs, and what is left alone.
GameTooltip:Process(1, { kind = 1, id = 133, text = "Fireball" })
equal(Count(gameBack, "Spell ID=133"), 1, "a spell's ID")
GameTooltip:Process(2, { kind = 2, guid = "Creature-0-1-2-3-299-0000", text = "Wolf" })
equal(Count(gameBack, "NPC ID=299"), 1, "an NPC's ID from its GUID")
GameTooltip:Process(2, { kind = 2, guid = "Player-1-0000ABCD", text = "Squirt" })
equal(#gameBack.lines, 1, "a player: no ID line")
GameTooltip:Process(0, { kind = 0, id = SECRET, text = "Hidden" })
equal(#gameBack.lines, 1, "a secret ID: no line")
settings.tooltipIDs = false
GameTooltip:Process(0, helm)
equal(#gameBack.lines, 1, "Tooltip IDs off: no line")
settings.tooltipIDs = true

-- The older path (no tooltip data, OnTooltipSetItem) still hooks the clears.
postCalls, hooks = {}, 0
TooltipDataProcessor = nil
Module:SetupTooltipIDs()
equal(hooks, 2, "the older item path: OnTooltipCleared hooked on GameTooltip and ItemRefTooltip, as before")

print("Tooltip ID checks passed: " .. checks .. " assertions.")
