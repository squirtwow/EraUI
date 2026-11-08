local _, EraUI = ...

-- Action Rings (/era > Action Bars > Action Rings; off by default,
-- experimental). Hold a ring's key for a ring of spells, items, mounts,
-- pets, toys, macros, equipment sets or markers round your cursor; point at
-- one and let go to use it, or let go in the middle for nothing. Up to ten
-- rings of sixteen slices, made and filled in /era (Modules/RingEditor.lua),
-- each with its own key, set by the player in Key Bindings > AddOns > EraUI
-- (Bindings.xml; the game won't let an addon set one). Ready-made rings fill
-- themselves: Quest Items, Raid Markers, World Markers, Mounts and your
-- class's ring.
--
-- The parts: Modules/RingSnippet.lua (the secure choice), RingClassData.lua
-- (each class's ring), RingData.lua (the saved rings and what each slice
-- does), RingFill.lua (ready-made rings and the pickers), RingSecure.lua (the
-- buttons and hit frames), RingView.lua (the look), RingEditor.lua (the box
-- in /era) and RingRows.lua (its rows). This file starts and stops them and
-- listens to the game. Rings change only out of combat (a change made in a
-- fight is saved at once and made when it ends).
local M = {}
EraUI:RegisterModule("ActionRings", M)

local APPLY = {"SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "PLAYER_LEVEL_UP", "BAG_UPDATE_DELAYED", "QUEST_LOG_UPDATE",
    "QUEST_ACCEPTED", "QUEST_REMOVED", "PLAYER_EQUIPMENT_CHANGED", "EQUIPMENT_SETS_CHANGED", "UPDATE_MACROS", "NEW_MOUNT_ADDED",
    "COMPANION_LEARNED", "NEW_PET_ADDED", "PET_JOURNAL_LIST_UPDATE", "NEW_TOY_ADDED", "TOYS_UPDATED"}
local SPELLBOOK = {SPELLS_CHANGED = true, LEARNED_SPELL_IN_SKILL_LINE = true, PLAYER_LEVEL_UP = true}
local LOOK = {SPELL_UPDATE_COOLDOWN = true, BAG_UPDATE_COOLDOWN = true, SPELL_UPDATE_USABLE = true, BAG_UPDATE_DELAYED = true}

function M:Enabled()
    return EraUI:GetSetting("enabled") ~= false and EraUI:GetSetting("actionRings") == true
end

-- A ring's name in Key Bindings ("Action Ring 3: Mage Ring"), or the plain one.
function M:Name(slot)
    local ring = EraUI.RingData.Ring(slot)
    EraUI:SetRingBindingName(slot, ring and ring.name or nil)
end

function M:Initialize()
    EraUI.RingData.Load()
    -- The test build's pick log, cleared from old saved files.
    EraUIClassicCharDB.actionRingsProbe = nil
    for slot = 1, EraUI.RingData.RINGS do self:Name(slot) end
    self:Listen()
    self:Refresh()
end

-- Switched on: built and applied (in a fight, when it ends). Off: every key
-- does nothing and every ring is put away.
function M:Refresh()
    local secure = EraUI.RingSecure
    if self:Enabled() then
        if secure.built or secure.Build() then secure.ApplyAll(false, true) end
    else
        secure.Off()
    end
    if EraUI.RingEditor then EraUI.RingEditor.Refresh() end
end

-- A ring changed in the editor: saved at once, its key's name too, and the
-- ring itself now (or when the fight ends: "later").
function M:Edited(slot)
    EraUI:SaveSettings()
    if slot then self:Name(slot) end
    if not self:Enabled() then return "off" end
    local secure = EraUI.RingSecure
    if InCombatLockdown() then
        if slot then secure.Later(slot, true) end
        return "later"
    end
    if slot then secure.Apply(slot, true) end
    return "now"
end

-- A deleted ring: put away too.
function M:Deleted(slot)
    local said = self:Edited(slot)
    local secure = EraUI.RingSecure
    if said == "later" then secure.closeLater = true elseif said == "now" then secure.CloseAll() end
    return said
end

-- Changes from the game, a moment later and once for many.
function M:Queue()
    if self.queued or not self:Enabled() then return end
    self.queued = true
    C_Timer.After(.2, function()
        self.queued = false
        if self:Enabled() then EraUI.RingSecure.ApplyAll(false) end
    end)
end

function M:Listen()
    if self.events then return end
    local events = CreateFrame("Frame")
    self.events = events
    local list = {"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UPDATE_BINDINGS", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN",
        "SPELL_UPDATE_USABLE"}
    for _, event in ipairs(APPLY) do list[#list + 1] = event end
    for _, event in ipairs(list) do pcall(events.RegisterEvent, events, event) end
    events:SetScript("OnEvent", function(_, event, ...) M:OnEvent(event, ...) end)
end

function M:OnEvent(event)
    local editor = EraUI.RingEditor
    if event == "PLAYER_REGEN_ENABLED" then
        EraUI.RingSecure.OnRegen()
        if editor then editor.Refresh() end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" or event == "UPDATE_BINDINGS" then
        if editor then editor.Refresh() end
        return
    end
    if SPELLBOOK[event] then EraUI.RingFill.Invalidate() end
    if LOOK[event] and EraUI.RingView then EraUI.RingView.RefreshOpen() end
    if not (LOOK[event] and event ~= "BAG_UPDATE_DELAYED") then self:Queue() end
end

-- The editor's box under Your Rings (Core/Settings.lua, Modules/RingRows.lua).
function M:AttachEditor(frame, row)
    if EraUI.RingEditor then EraUI.RingEditor.Attach(frame, row) end
end
function M:HideEditor()
    if EraUI.RingEditor then EraUI.RingEditor.Hide() end
end
