-- Optional Forever tracker compatibility. Own only native tracker visibility;
-- Questie retains its quests, layout, bindings and replacement preferences.
local _, E = ...
local M = {}
E:RegisterModule("QuestieCompatibility", M)
local header, refreshing, faded
local wrapped = setmetatable({}, { __mode = "k" })
local observed = setmetatable({}, { __mode = "k" })

local function Replacing()
    local questie = _G.Questie
    local profile = questie and questie.db and questie.db.profile
    return profile and profile.trackerEnabled == true and not profile.showBlizzardQuestTimer
        and (not questie.IsEnabled or questie:IsEnabled())
end

local function Import(name)
    if not QuestieLoader or type(QuestieLoader.ImportModule) ~= "function" then return end
    local ok, module = pcall(QuestieLoader.ImportModule, QuestieLoader, name)
    if ok and type(module) == "table" then return module end
end

local function Observe(object, method)
    if not object or type(object[method]) ~= "function" then return end
    observed[object] = observed[object] or {}
    if observed[object][method] then return end
    observed[object][method] = true
    hooksecurefunc(object, method, function() M:Refresh() end)
end

function M:Discover()
    local tracker, compat = Import("QuestieTracker"), Import("QuestieCompat")
    for _, method in ipairs({"Update", "Enable", "Disable", "Toggle"}) do Observe(tracker, method) end
    for _, method in ipairs({"OnEnable", "OnDisable", "RefreshConfig"}) do Observe(_G.Questie, method) end
    Observe(compat, "HideWatchFrame")
    Observe(compat, "ShowWatchFrame")
    return compat
end

function M:Refresh()
    if refreshing then return end
    self:Discover()
    -- Preference changes in combat are reconciled once it ends. The already
    -- installed policy remains valid for native re-shows throughout combat.
    if InCombatLockdown() then return end
    local tracker = _G.ObjectiveTrackerFrame
    if not tracker then return end
    local replacing = Replacing()
    local suppress = E:GetSetting("enabled") and replacing and true or false
    if not header and not suppress then return end
    refreshing = true
    if not header then header = CreateFrame("Frame", nil, nil, "SecureHandlerBaseTemplate") end
    local was = header:GetAttribute("suppressTracker")
    header:SetFrameRef("tracker", tracker)
    if suppress and not wrapped[tracker] then
        -- The second pre-handler return is the message that enables Blizzard's
        -- post-handler dispatch. An empty pre-handler silently skips the post.
        header:WrapScript(tracker, "OnShow", "return nil, true", [[
            if control:GetAttribute("suppressTracker") and control:GetFrameRef("tracker") == self then
                self:Hide()
            end
        ]])
        tracker:HookScript("OnShow", function(frame)
            -- Restricted wrappers skip unprotected targets during combat. An
            -- addon Hide() there would run Edit Mode's Lua Hide override as
            -- EraUI and leave the tracker tainted (a later secure update then
            -- fails its aura check), so the tracker is only made invisible
            -- until combat ends, then hidden through the secure header.
            if frame == _G.ObjectiveTrackerFrame and header:GetAttribute("suppressTracker")
                and InCombatLockdown() and not frame:IsProtected() then
                frame:SetAlpha(0)
                faded = frame
            end
        end)
        wrapped[tracker] = true
    end
    if was ~= suppress then header:SetAttribute("suppressTracker", suppress) end
    if suppress then
        if tracker:IsShown() then header:Execute([[self:GetFrameRef("tracker"):Hide()]]) end
    elseif was then
        -- Shown through the secure header. EraUI never calls the tracker's
        -- Update or Questie's ShowWatchFrame: from addon code both run the whole
        -- tracker as EraUI and taint it. Blizzard's own events refresh it, and
        -- an older Questie hide request clears with Questie's own reload.
        header:Execute([[self:GetFrameRef("tracker"):Show()]])
    end
    if faded then
        faded:SetAlpha(1)
        faded = nil
    end
    refreshing = false
end

function M:Initialize()
    if not E.Classic.OnForever() then return end
    local events = CreateFrame("Frame")
    for _, event in ipairs({"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function() M:Refresh() end)
    hooksecurefunc(E, "SetSetting", function(_, key) if key == "enabled" then M:Refresh() end end)
    self:Refresh()
end
