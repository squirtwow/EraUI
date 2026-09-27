-- Exercise real QoL and Classic tracker presentation with native layout methods
-- forbidden from addon callbacks. This models ownership, not the client's taint VM.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local function Session(classic, enabled, late)
    local env = setmetatable({}, {__index=_G})
    env._G = env
    local native = false
    local queued, blocks, watched, hookCounts = {}, {}, {}, {}
    local secret = setmetatable({}, {__tostring=function() error("secret converted to text") end,
        __lt=function() error("secret compared") end, __le=function() error("secret compared") end})
    env.issecretvalue = function(value) return value == secret end
    env.C_Timer = {After=function(_, callback) queued[#queued+1] = callback end}
    local E = {settings={enabled=true, questLevels=enabled ~= false}, modules={}}
    function E:GetSetting(key) return self.settings[key] end
    function E:RegisterModule(key, value) self.modules[key] = value end
    local nativeCalls = {header=0, dirty=0, strings=0}
    local function Native(callback, ...)
        local before = native
        native = true
        local ok, value = pcall(callback, ...)
        native = before
        assert(ok, value)
        return value
    end
    env.hooksecurefunc = function(object, method, callback)
        hookCounts[object] = hookCounts[object] or {}
        hookCounts[object][method] = (hookCounts[object][method] or 0) + 1
        local original = assert(object[method])
        object[method] = function(...)
            local result = original(...)
            local before = native
            native = false
            local ok, err = pcall(callback, ...)
            native = before
            assert(ok, err)
            return result
        end
    end
    local levels = {[1]=5, [2]=12, [3]=0, [4]=secret}
    env.C_QuestLog = {
        GetQuestDifficultyLevel=function(id) return levels[id] end,
        GetNumQuestWatches=function() return #watched end,
        GetQuestIDForQuestWatchIndex=function(index) return watched[index] end,
    }
    local function Label(text, width)
        local label = {text=text, width=width or 180, writes=0}
        function label:GetText() return self.text end
        function label:SetText(value) self.text=value; self.writes=self.writes+1 end
        function label:GetWidth() return self.secretWidth and secret or self.width end
        function label:GetStringWidth() return #self.text * 5 end
        function label:GetHeight()
            if self.secretHeight or (self.secretPaintedHeight and self.text:match("^%[")) then return secret end
            return math.min(2, math.max(1, math.ceil(#self.text * 5 / self.width))) * 12
        end
        function label:IsTruncated() return self.secretTruncation and secret or #self.text * 5 > self.width * 2 end
        function label:SetFont() end
        function label:SetTextColor(r,g,b) self.colour={r,g,b} end
        function label:SetShadowColor() end
        function label:SetShadowOffset() end
        return label
    end
    local tracker = {Header={}, usedBlocks={QuestTemplate={}}}
    function tracker:GetExistingBlock(id) return blocks[id] end
    function tracker:AddBlock(block)
        assert(native, "addon called native AddBlock")
        self.usedBlocks.QuestTemplate[block.id]=block
        return true
    end
    function tracker:MarkDirty()
        nativeCalls.dirty=nativeCalls.dirty+1
        assert(native, "addon called QuestObjectiveTracker:MarkDirty")
    end
    local function Block(id, text, width)
        local block = {id=id, HeaderText=Label(text, width)}
        function block:SetStringText(label, title)
            assert(native, "addon called native SetStringText")
            nativeCalls.strings=nativeCalls.strings+1
            label:SetText(title)
            return label:GetHeight()
        end
        function block:SetHeader(title)
            assert(native, "addon called native SetHeader")
            nativeCalls.header=nativeCalls.header+1
            self.height=self:SetStringText(self.HeaderText, title)
        end
        Native(block.SetHeader, block, text)
        blocks[id]=block
        watched[#watched+1]=id
        tracker.usedBlocks.QuestTemplate[id]=block
        return block
    end
    local initial = Block(1, "Gather supplies")
    if not late then env.QuestObjectiveTracker=tracker end
    env.ObjectiveTrackerFrame = {modules={tracker}, Update=function() assert(native, "addon invoked tracker Update") end}
    local skin
    E.Classic = {
        RegisterModule=function(_, module) skin=module end,
        HookMethod=function(object, method, callback)
            if type(object[method]) == "function" then env.hooksecurefunc(object, method, callback) end
        end,
        MissingPiece=function() end,
        QuestLevelColor=function() return 1, .82, 0 end,
    }
    env.unpack = table.unpack or unpack
    assert(loadfile("Modules/QoL.lua", "t", env))("EraUI", E)
    if classic then
        assert(loadfile("Classic/QuestTracker.lua", "t", env))("EraUI", E)
        if classic ~= "after" then skin.apply() end
    end
    local M=E.modules.QoL
    return {E=E, M=M, env=env, initial=initial, tracker=tracker, native=Native, block=Block,
        calls=nativeCalls, hookCounts=hookCounts, levels=levels, secret=secret,
        skin=skin, queued=queued, flush=function() for _, callback in ipairs(queued) do callback() end end}
end

for _, classic in ipairs({false, true, "after"}) do
    local s=Session(classic)
    s.M:SetupQuestLevels()
    s.flush() -- The old implementation calls native MarkDirty here from addon code.
    if classic == "after" then s.skin.apply() end
    Equal(#s.queued, 0, "presentation schedules no native rebuild")
    Equal(s.calls.dirty, 0, "native dirty state untouched")
    Equal(s.calls.header, 1, "initial painting does not rerun native header layout")
    Equal(s.initial.HeaderText:GetText(), "[5] Gather supplies", "existing title gets a level")
    Equal(s.initial.height, 12, "native header height preserved")
    local writes=s.initial.HeaderText.writes
    s.native(s.tracker.AddBlock, s.tracker, s.initial)
    Equal(s.initial.HeaderText.writes, writes, "existing AddBlock does not repaint the same title twice")
    s.initial.height=48 -- native layout includes objectives after the title
    s.M:RefreshQuestLevels()
    Equal(s.initial.height, 48, "setting refresh preserves accumulated objective height")
    Equal(s.initial.HeaderText:GetText(), "[5] Gather supplies", "refresh does not stack prefixes")
    s.E.settings.questLevels=false; s.M:RefreshQuestLevels()
    Equal(s.initial.HeaderText:GetText(), "Gather supplies", "toggle off restores owned title")
    s.E.settings.questLevels=true; s.M:RefreshQuestLevels()
    Equal(s.initial.HeaderText:GetText(), "[5] Gather supplies", "toggle on paints without rebuild")
    s.E.settings.enabled=false; s.M:RefreshQuestLevels()
    Equal(s.initial.HeaderText:GetText(), "Gather supplies", "global disable restores owned title")
    s.E.settings.enabled=true; s.M:RefreshQuestLevels()

    s.native(s.initial.SetHeader, s.initial, "Find the scout")
    Equal(s.initial.HeaderText:GetText(), "[5] Find the scout", "native title update painted")
    Equal(s.calls.header, 2, "native title update is not reentered")
    Equal(s.calls.strings, 2, "native string layout is not reentered")
    Equal(s.initial.height, 12, "native update retains its calculated height")
    s.native(s.initial.SetHeader, s.initial, "[7] Another addon's label")
    Equal(s.initial.HeaderText:GetText(), "[7] Another addon's label", "existing prefix not duplicated")
    s.E.settings.questLevels=false; s.M:RefreshQuestLevels()
    Equal(s.initial.HeaderText:GetText(), "[7] Another addon's label", "unowned prefix preserved on disable")
    s.E.settings.questLevels=true
    s.native(s.initial.SetHeader, s.initial, "Find the scout")
    s.initial.HeaderText:SetText("Other addon replacement")
    s.E.settings.questLevels=false; s.M:RefreshQuestLevels()
    Equal(s.initial.HeaderText:GetText(), "Other addon replacement", "disable does not overwrite changed text")
    s.E.settings.questLevels=true

    -- Width and wrapping must not grow Blizzard's already allocated title area.
    local narrow=s.block(2, "Ten letters", 60)
    s.native(s.tracker.AddBlock, s.tracker, narrow)
    Equal(narrow.HeaderText:GetText(), "Ten letters", "prefix requiring another line falls back to full native title")
    Equal(narrow.height, 12, "fallback keeps native single-line height")
    narrow.HeaderText.width=100
    s.native(narrow.SetHeader, narrow, "A title already using two lines")
    Equal(narrow.HeaderText:GetText(), "[12] A title already using two lines", "prefix fits existing two-line space")
    Equal(narrow.HeaderText:GetHeight(), narrow.height, "two-line prefix does not exceed native height")
    s.native(narrow.SetHeader, narrow, "This native title nearly fills two lines")
    Equal(narrow.HeaderText:GetText(), "This native title nearly fills two lines", "prefix that truncates full title is declined")

    s.levels[2]=nil; s.native(narrow.SetHeader, narrow, "Unknown level")
    Equal(narrow.HeaderText:GetText(), "Unknown level", "unknown level left native")
    s.levels[2]=0; s.native(narrow.SetHeader, narrow, "No level")
    Equal(narrow.HeaderText:GetText(), "No level", "zero level left native")
    s.levels[2]=s.secret; s.native(narrow.SetHeader, narrow, "Restricted level")
    Equal(narrow.HeaderText:GetText(), "Restricted level", "restricted level not formatted")
    s.levels[2]=12
    narrow.HeaderText.secretHeight=true
    s.M:RefreshQuestLevels()
    Equal(narrow.HeaderText:GetText(), "Restricted level", "restricted geometry not compared")
    narrow.HeaderText.secretHeight=false
    narrow.HeaderText.secretPaintedHeight=true
    s.M:RefreshQuestLevels()
    Equal(narrow.HeaderText:GetText(), "Restricted level", "restricted candidate height restores native text")
    narrow.HeaderText.secretPaintedHeight=false
    narrow.HeaderText.secretTruncation=true
    s.M:RefreshQuestLevels()
    Equal(narrow.HeaderText:GetText(), "Restricted level", "restricted truncation result restores native text")
    narrow.HeaderText.secretTruncation=false
    narrow.HeaderText:SetText(s.secret)
    s.M:RefreshQuestLevels()
    Equal(narrow.HeaderText:GetText(), s.secret, "restricted title left untouched")
    narrow.HeaderText:SetText("Public title")
    narrow.id=s.secret
    s.M:RefreshQuestLevels()
    Equal(narrow.HeaderText:GetText(), "Public title", "restricted quest ID left untouched")
    narrow.id=2
    local getter=s.env.C_QuestLog.GetQuestDifficultyLevel
    s.env.C_QuestLog.GetQuestDifficultyLevel=function() error("unavailable") end
    s.M:RefreshQuestLevels()
    Equal(narrow.HeaderText:GetText(), "Public title", "unavailable quest data leaves title usable")
    s.env.C_QuestLog.GetQuestDifficultyLevel=getter

    -- Pooled blocks must use their current quest, never a cached quest's prefix.
    s.initial.id=2
    s.native(s.initial.SetHeader, s.initial, "Reused block")
    Equal(s.initial.HeaderText:GetText(), "[12] Reused block", "reused block uses current quest level")
    s.M:RefreshQuestLevels(); s.M:SetupQuestLevels()
    Equal(s.hookCounts[s.initial].SetHeader, 1, "one header hook per pooled block")
    Equal(s.hookCounts[s.tracker].AddBlock, classic and 2 or 1, "no stacked discovery hooks")
    Equal(#s.queued, 0, "all title paths leave native scheduling alone")
    Equal(s.calls.dirty, 0, "all title paths leave native dirty state alone")
end

local off=Session(false, false)
off.M:SetupQuestLevels(); off.flush()
Equal(off.initial.HeaderText:GetText(), "Gather supplies", "disabled feature keeps native title")
Equal(#off.queued, 0, "disabled feature does not schedule rebuilds")
local late=Session(false, true, true)
late.M:SetupQuestLevels()
Equal(#late.queued, 0, "absent tracker schedules nothing")
late.env.QuestObjectiveTracker=late.tracker
late.tracker.MarkDirty=nil -- purely cosmetic support has no layout dependency
late.M:SetupQuestLevels()
Equal(late.initial.HeaderText:GetText(), "[5] Gather supplies", "late tracker works without MarkDirty")
print("Quest-level presentation checks passed: " .. checks .. " assertions.")
