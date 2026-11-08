local _, EraUI = ...

-- Plain AddOn List (/era > Windows & Tooltips > Windows; off by default;
-- seen in game 2026-11-07). The game's AddOn list now sorts addons under category
-- headings and tucks an addon's parts under it. With this on, every time the
-- game fills the list it shows as one plain list instead, in the game's own
-- addon order: every addon the game's list kept (so its search box still
-- filters), no headings, nothing tucked under another. The rows are still the
-- game's own, so ticking, greying, the right-click menu and the tooltips
-- work as before. Switched off, the grouped list is back the next time the
-- game fills it (opening the list, a search, a tick).
-- Only the list's contents are swapped, through the scroll box's own setter;
-- the game's fill function and its search box are post-hooked. No key of
-- ours goes on the game's frames, and enabling or disabling addons is left
-- alone. Taint: that setter runs as our code, so the scroll box keeps our
-- list, and the game's next fill (inside the list's OnShow, which the panel
-- manager calls when the list opens from the Game Menu) runs tainted. No
-- taint-free way exists to change the list's contents; nothing it touches is
-- protected. It ships off by default because opening and closing the list in
-- a fight has not been checked for blocked actions yet.
local List = {}
EraUI:RegisterModule("PlainAddonList", List)

local ours = setmetatable({}, {__mode = "k"}) -- the plain lists this made

function List:On()
    return EraUI:GetSetting("enabled") ~= false and EraUI:GetSetting("plainAddonList") == true
end

-- Every addon in the game's list, each once, in addon order; nil when the
-- list can't be read.
function List.Indexes(provider)
    if type(provider) ~= "table" or type(provider.EnumerateEntireRange) ~= "function" then return nil end
    local list, seen = {}, {}
    for _, node in provider:EnumerateEntireRange() do
        local data = type(node) == "table" and node.GetData and node:GetData()
        local index = type(data) == "table" and data.addonIndex
        if type(index) == "number" and not seen[index] then
            seen[index] = true
            list[#list + 1] = index
        end
    end
    table.sort(list)
    return list
end

-- The game's list as one plain list. False when there's nothing to do.
function List:Flatten()
    if not self:On() then return false end
    local frame = AddonList
    local box = type(frame) == "table" and frame.ScrollBox
    if type(box) ~= "table" or type(box.GetDataProvider) ~= "function" or type(box.SetDataProvider) ~= "function"
        or type(CreateTreeDataProvider) ~= "function" then
        return false
    end
    local current = box:GetDataProvider()
    if current == nil or ours[current] then return false end
    local indexes = List.Indexes(current)
    if not indexes then return false end
    local flat = CreateTreeDataProvider()
    for _, index in ipairs(indexes) do flat:Insert({addonIndex = index}) end
    ours[flat] = true
    box:SetDataProvider(flat, ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
    return true
end

-- Runs after the game fills the list; an error is reported, never passed on.
local function After()
    if not List:On() then return end
    local ok, problem = pcall(List.Flatten, List)
    if not ok and geterrorhandler then geterrorhandler()(problem) end
end

-- The game's fill function and its search box (which keeps its own copy of
-- that function, so a search needs its own hook). True once both are in.
function List:Hook()
    if self.hooked then return true end
    if type(AddonList_Update) ~= "function" then return false end
    self.hooked = true
    hooksecurefunc("AddonList_Update", After)
    local search = type(AddonList) == "table" and AddonList.SearchBox
    if type(search) == "table" and type(search.HookScript) == "function" then search:HookScript("OnTextChanged", After) end
    return true
end

-- The game's AddOn list may load later: hook it as it does.
local function OnEvent(self)
    if List:Hook() then self:UnregisterEvent("ADDON_LOADED") end
end

-- Follows the option. Switched on with the list open, it goes plain at once.
function List:Refresh()
    if not self:On() then return end
    if not self:Hook() and not self.waiting then
        self.waiting = CreateFrame("Frame")
        self.waiting:SetScript("OnEvent", OnEvent)
        self.waiting:RegisterEvent("ADDON_LOADED")
    end
    local frame = AddonList
    if self.hooked and type(frame) == "table" and frame.IsShown and frame:IsShown() then After() end
end

function List:Initialize()
    self:Refresh()
end
