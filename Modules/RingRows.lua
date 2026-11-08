local _, E = ...

-- /era > Action Bars > Action Rings (Modules/ActionRings.lua): the switch,
-- Ring Size, Slice Names, Cooldowns & Counts and Ring Motion, then the
-- whole-line Your Rings heading with the editor's box under it
-- (Modules/RingEditor.lua). All but the switch show only while it's on
-- (Core/Settings.lua SHOWN_WITH). Core/Settings.lua calls Build once its own
-- rows are made, handing over its tick maker, so the ticks behave as every
-- other: their clicks run its Action Rings branch.
local RR = {}
E.RingRows = RR

RR.WORDS = "ring rings radial wheel pie menu quest items mounts markers macros pets toys equipment sets teleports portals keybind key binding"

local function Module() return E.modules and E.modules.ActionRings end

function RR.Build(frame, MakeCheck)
    local Rows = E.SettingsRows
    local rings = MakeCheck(frame, "Action Rings", "actionRings", nil, "Hold a key for a ring of spells and items round your cursor.", false)
    rings.searchText = rings.searchText .. " " .. RR.WORDS
    -- Ring Size: the faces and the middle's size follow at once, out of a
    -- fight (in one, when it ends).
    local size = Rows.Slider(frame, "actionRingScale", "Ring Size", {low = 75, high = 150, step = 5,
        read = function() return math.max(75, math.min(150, tonumber(E:GetSavedSetting("actionRingScale")) or 100)) end,
        save = function(value)
            if E:GetSavedSetting("actionRingScale") == value then return end
            E:SetSetting("actionRingScale", value)
            local module = Module()
            if module then module:Refresh() end
            local secure = E.RingSecure
            if InCombatLockdown() and secure and not secure.told then
                secure.told = true
                E:Status("Action Rings: your rings change when this fight ends.")
            end
        end,
        format = function(value) return value .. "%" end})
    size.summary = "How big your rings are."
    size.searchText = "action ring rings size scale big bigger smaller radial wheel"
    local names = MakeCheck(frame, "Slice Names", "actionRingNames", nil, "The slice's name under the ring.", false)
    names.searchText = names.searchText .. " action ring rings name names label middle"
    local counts = MakeCheck(frame, "Cooldowns & Counts", "actionRingCooldowns", nil, "Cooldowns and item counts on the icons.", false)
    counts.searchText = counts.searchText .. " action ring rings cooldown cooldowns count counts sweep"
    local motion = MakeCheck(frame, "Ring Motion", "actionRingMotion", nil, "Icons swirl in and out.", false)
    motion.searchText = motion.searchText .. " action ring rings motion animation swirl spin glow"
    -- Your Rings: a whole line, its box under it on its page only (never in
    -- search, which lists results instead of rows).
    local heading = Rows.Heading(frame, "actionRingEditor", "Your Rings")
    heading.summary = "Make rings and fill them. They're in the box below."
    heading.searchText = "your rings action ring rings editor make new fill slices " .. RR.WORDS
    heading.wideRow = true
    heading.attachPanel = function()
        local module = Module()
        if module and module.AttachEditor then module:AttachEditor(frame, heading) end
    end
    heading:HookScript("OnShow", function() if not frame.searching then heading.attachPanel() end end)
    heading:HookScript("OnHide", function()
        local module = Module()
        if module and module.HideEditor then module:HideEditor() end
    end)
    return rings
end
