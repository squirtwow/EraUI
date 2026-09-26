-- Optional Forever tracker compatibility. Own only native tracker visibility;
-- Questie retains its quests, layout, bindings and replacement preferences.
local _, E = ...
local M = {}
E:RegisterModule("QuestieCompatibility", M)
local header, refreshing
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
    local compat = self:Discover()
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
            -- Restricted wrappers skip unprotected targets during combat. Such
            -- a tracker can safely be hidden by ordinary Lua, even in combat.
            if frame == _G.ObjectiveTrackerFrame and header:GetAttribute("suppressTracker")
                and (not InCombatLockdown() or not frame:IsProtected()) then
                frame:Hide()
            end
        end)
        wrapped[tracker] = true
    end
    if was ~= suppress then header:SetAttribute("suppressTracker", suppress) end
    if suppress then
        if tracker:IsShown() then header:Execute([[self:GetFrameRef("tracker"):Hide()]]) end
    elseif was then
        -- Release Questie's previous native-hide request too when its own
        -- replacement setting is off; otherwise its older OnShow hook wins.
        if not replacing and compat and type(compat.ShowWatchFrame) == "function" then compat.ShowWatchFrame() end
        if tracker.Update then tracker:Update() end
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
