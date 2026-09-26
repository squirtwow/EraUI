local _, EraUI = ...
local Module = {}
EraUI:RegisterModule("SecondaryNames", Module)

-- Client versions expose different subsets; never create unknown CVars.
local settings = {"UnitSurnameOwn", "UnitSurname", "UnitSurnameOther",
    "UnitSurnameFriendly", "UnitSurnameEnemy", "ShowSurnames"}
local changing = false
local function Read(name)
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    if not get then return end
    local ok, value = pcall(get, name)
    if ok and value ~= nil and not (issecretvalue and issecretvalue(value)) then return tostring(value) end
end
function Module:Apply()
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if changing or not set or not EraUIDB then return end
    changing = true
    local hidden = EraUI:GetSetting("hideSecondaryNames")
    -- This toggle owns surname visibility in both directions. A saved "0"
    -- from a previous session must never become the value restored on disable.
    EraUIDB.secondaryNameBackup = nil
    for _, name in ipairs(settings) do
        local current = Read(name)
        if current ~= nil then
            local desired = "0"
            if not hidden then
                desired = "1"
                local getDefault = C_CVar and C_CVar.GetCVarDefault or GetCVarDefault
                if getDefault then
                    local ok, value = pcall(getDefault, name)
                    if ok and value ~= nil and not (issecretvalue and issecretvalue(value)) then
                        value = tostring(value)
                        if value ~= "0" and value ~= "" then desired = value end
                    end
                end
            end
            if current ~= desired then pcall(set, name, desired) end
        end
    end
    changing = false
end
-- Change only the visible label of player links; retain the full link target.
local chatFrames = setmetatable({}, {__mode="k"})
function Module:ShortenChatText(text)
    if not EraUI:GetSetting("hideSecondaryNames") or (issecretvalue and issecretvalue(text)) or type(text)~="string" then return text end
    return (text:gsub("(|Hplayer:[^|]+|h)(.-)(|h)", function(link,label,ending)
        label=label:gsub("(%[[^%s%]]+)%s+[^|%]]+", "%1")
        return link..label..ending
    end))
end
function Module:HookChatFrames()
    for _,name in ipairs(CHAT_FRAMES or {}) do
        local frame=_G[name]
        if frame and frame.AddMessage and not chatFrames[frame] then
            chatFrames[frame]=true
            local original=frame.AddMessage
            frame.AddMessage=function(self,text,...)
                return original(self,Module:ShortenChatText(text),...)
            end
        end
    end
end
function Module:Initialize()
    self:HookChatFrames()
    if FCF_OpenTemporaryWindow then hooksecurefunc("FCF_OpenTemporaryWindow", function() self:HookChatFrames() end) end
    if FCF_OpenNewWindow then hooksecurefunc("FCF_OpenNewWindow", function() self:HookChatFrames() end) end
    self.events = CreateFrame("Frame")
    self.events:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.events:SetScript("OnEvent", function()
        if not changing then self:Apply() end
    end)
    -- The client can rewrite these CVars while it redraws name text, which
    -- used to make the toggle look like it switched itself back off. While
    -- the toggle is on, quietly re-assert the values every couple of seconds;
    -- six reads that land on the right value change nothing at all.
    self.events:SetScript("OnUpdate", function(_, elapsed)
        if not EraUI:GetSetting("hideSecondaryNames") then return end
        self.since = (self.since or 0) + elapsed
        if self.since < 2 then return end
        self.since = 0
        if not changing then self:Apply() end
    end)
    self:Apply()
end
