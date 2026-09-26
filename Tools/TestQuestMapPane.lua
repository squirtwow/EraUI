-- Native detail-panel geometry, scrolling and restore regression.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
unpack = table.unpack or unpack
function wipe(t) for k in pairs(t) do t[k] = nil end end
local combat, frames, timers = false, {}, {}
function InCombatLockdown() return combat end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function Flush()
    local batch = timers; timers = {}
    for _, fn in ipairs(batch) do fn() end
    Equal(#timers, 0, "metrics refresh does not loop")
end
local function Frame(parent)
    local f = { parent = parent, width = 308, height = 502, points = {}, scripts = {}, hooks = {}, shown = true, offset = 0, contentHeight = 1100 }
    function f:GetWidth() return self.width end
    function f:GetHeight()
        local top, bottom
        for _, point in ipairs(self.points) do
            if point[1] == "TOPRIGHT" or point[1] == "TOPLEFT" then top = point end
            if point[1] == "BOTTOMRIGHT" or point[1] == "BOTTOMLEFT" then bottom = point end
        end
        if top and bottom and top[2] == bottom[2] then return top[2]:GetHeight() + top[5] - bottom[5] end
        return self.height
    end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i) return unpack(self.points[i]) end
    function f:SetPoint(...)
        local p = { ... }
        for i, old in ipairs(self.points) do if old[1] == p[1] then self.points[i] = p; return end end
        self.points[#self.points + 1] = p
    end
    function f:SetAllPoints(parent) self:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0); self:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0) end
    function f:ClearAllPoints() wipe(self.points) end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:HookScript(event, fn) self.hooks[event] = self.hooks[event] or {}; table.insert(self.hooks[event], fn) end
    function f:RegisterEvent(event) self.event = event end
    function f:Fire(event) for _, fn in ipairs(self.hooks[event] or {}) do fn(self) end end
    function f:GetRegions() end
    function f:GetChildren() end
    function f:SetAlpha(value) self.alpha = value end
    function f:SetTexture(value) self.texture = value end
    function f:SetTexCoord(...) self.coords = { ... } end
    function f:SetHorizTile() end
    function f:SetVertTile() end
    function f:SetVertexColor() end
    function f:IsShown() return self.shown end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:UpdateScrollChildRect() self.rectUpdates = (self.rectUpdates or 0) + 1 end
    function f:GetVerticalScroll() return self.offset end
    function f:GetVerticalScrollRange() return math.max(0, self.contentHeight - self:GetHeight()) end
    function f:SetVerticalScroll(value) self.offset = value end
    frames[#frames + 1] = f
    return f
end
function CreateFrame() return Frame() end
QuestMapFrame = Frame()
local quests, details, scroll = Frame(QuestMapFrame), Frame(), Frame()
QuestMapFrame.QuestsFrame, QuestMapFrame.DetailsFrame = quests, details
details.ScrollFrame = scroll
details:SetPoint("TOPRIGHT", quests, "TOPRIGHT", 0, -1)
scroll:SetSize(298, 430)
scroll:SetPoint("TOPLEFT", details, "TOPLEFT", 5, -43)
scroll.Contents = Frame(scroll)
details.RewardsFrameContainer = { RewardsFrame = Frame() }
details.RewardsFrameContainer.RewardsFrame.height = 160
local rewardCalls = 0
function details:SetRewardsHeight(height) Equal(height, 160, "native reward height retained"); rewardCalls = rewardCalls + 1 end
details.AbandonButton = { OnClick = function() end }
local abandon = details.AbandonButton.OnClick
local module, hooks = nil, {}
local ns = {
    OwnTexture = function(parent) return Frame(parent) end,
    TexPath = function(key) return key end,
    ThemeTexture = function() end,
    HookGlobal = function(name, fn) hooks[name] = fn end,
    RegisterModule = function(_, value) module = value end,
}
assert(loadfile("Classic/QuestMapPane.lua"))("EraUI", { Classic = ns })
module.apply()
Flush()
Equal(details:GetHeight(), 499, "details fill normal parent height")
Equal(scroll:GetHeight(), 427, "scroll region keeps native footer spacing")
Equal(details:GetWidth(), 308, "native detail width retained")
Equal(scroll:GetWidth(), 298, "native text width retained")
Equal(details.AbandonButton.OnClick, abandon, "quest action handler unchanged")
quests.height = 900
scroll.offset = 700
details:Fire("OnSizeChanged")
details:Fire("OnSizeChanged")
Equal(#timers, 1, "resize metrics coalesced")
Flush()
Equal(details:GetHeight(), 897, "large-map details follow parent bottom")
Equal(scroll:GetHeight(), 825, "large-map text viewport grows")
Equal(scroll.offset, 275, "scroll position clamped after enlargement")
quests.height = 400
details:Fire("OnSizeChanged")
Flush()
Equal(scroll:GetHeight(), 325, "text viewport shrinks with map")
Equal(scroll.offset, 275, "valid scroll position preserved")
Equal(rewardCalls, 3, "native reward metrics refreshed on both resizes")
combat = true
hooks.QuestMapFrame_ShowQuestDetails()
details:Fire("OnSizeChanged")
Flush()
Equal(rewardCalls, 3, "combat does not run addon geometry refresh")
combat = false
for _, frame in ipairs(frames) do if frame.event == "PLAYER_REGEN_ENABLED" then frame.scripts.OnEvent(frame) end end
Flush()
Equal(rewardCalls, 4, "metrics resume after combat")
details:Fire("OnSizeChanged")
module.restore()
Flush()
Equal(details:GetHeight(), 502, "restore removes stretching anchor")
Equal(scroll:GetHeight(), 430, "restore resets native scroll height")
Equal(details:GetNumPoints(), 1, "detail anchors restored exactly")
Equal(scroll:GetNumPoints(), 1, "scroll anchors restored exactly")
Equal(rewardCalls, 4, "queued callback inert after disable")
module.apply()
Flush()
Equal(details:GetHeight(), 397, "reenable follows current map size")
module.restore()
Equal(details:GetHeight(), 502, "second restore preserves native baseline")
print("Quest map pane: " .. checks .. " assertions passed")
