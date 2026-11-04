-- A mock of Forever's Legacy window (Blizzard_LegacySystem, camelot build
-- 70425) for Tools/TestLegacyWindow.lua. Not a test itself. It stands on
-- Tools/WindowMockGame.lua's object model (frames, regions, anchors and a
-- small layout solver, scripts and post-hooks, sealed game objects: any key
-- EraUI writes on one fails; no GameTooltip or MouseIsOver; every key
-- binding call fails) and builds, the way the game's XML does:
--   * LegacySystemFrame (PortraitFrameTemplate, 920 x 575, where the game's
--     panel manager puts it: 51 from the left, 116 down): its nine-slice,
--     rock, streaks, portrait and its mask, title, X, the three side tabs
--     (LargeSideTabButtonTemplate) and the three pages, with SelectPage;
--   * every frame anchored as the game's XML anchors it (so the layout
--     solver gives each piece's real place): the track's row of cards set
--     up afresh on every show (its pool hands them out in any order), its
--     selection moving the first card when it scrolls, the scroll boxes'
--     rows as wide as their box, the talent holder padded 54 inside its
--     panel on every load, the talents placed from their tree positions;
--   * the Legacy points (game.SetPoints): the currency callbacks each page's
--     points take, held as the methods were at load (as the game's are);
--   * the Progress Track page: backdrop, crown, points and label, the bar
--     (LegacyProgressBarTemplate), the track (RewardProgressFrameTemplate:
--     its clip frame and paragon, four arrows) and its cards
--     (LegacyRewardCardTemplate), set up on show and refreshed;
--   * the Challenges page: backdrop, divider, the points summary (its bar
--     and LegacyPointShield crown), the
--     category list (filter, search, scroll box of ListHeaderVisualTemplate
--     rows with their collapse buttons, a thin scroll bar), the detail pane
--     (LegacyChallengeTemplate cards, each with its points crown, set again
--     on Init) and the shared objectives frame with
--     its pool of LegacyChallengeCriteriaTemplate rows; the page's own Lua
--     EraUI follows (the search set on show and as typed, its results on
--     ACHIEVEMENT_SEARCH_UPDATED through OnFilterUpdate, the filter reset,
--     a challenge chosen through the window's SelectChallenge, the search
--     cleared or the filter reset for it);
--   * the challenges' data behind it: the achievement API as camelot has it
--     (categories, challenges done first, Legacy points, chains, objectives,
--     the search's results a frame later, the filter, tracking, links,
--     modified clicks, the gamepad mode), values hidden on request, and the
--     game's own page's results worked out as its Lua does (game.Reference);
--   * the Tree page: backdrop, divider, the three tree buttons
--     (LegacyTreeButtonTemplate) in their layout list, the points summary
--     (its text and LegacyPointShield crown),
--     and the trait panel (TalentFrameBaseTemplate): the chosen tree's icon,
--     label and spent points, Apply, undo and reset, search, the button
--     holder with its talents (TalentButtonLegacySquareTemplate), links
--     (TalentEdgeArrowTemplate, scale 1.25) and gates, loaded on show.
-- The game's own behaviour (visual states, text colours, atlases) is what
-- its Lua does, cut down to what EraUI's dressing reads or the game sets
-- again. Load the addon with game.LoadAddOn().
-- Two builds (options.build, game.build):
--   * 70450 (the default; Squirt's beta client and private server): a
--     talent's rank text only its current rank, blank on one not taken
--     that can't be (TalentButtonBaseMixin:GetSpendText), coloured by its
--     state; no rank box; the reward cards without a hover glow;
--   * 70532 (live Forever): TalentButtonLegacyMixin on every talent (its
--     rank always "current/max", GENERIC_FRACTION_STRING, in white; its
--     rank text re-anchored on the button's corner, the shadows hidden),
--     TalentButtonLegacySquareTemplate's unnamed "Talents-Square-Box-c60"
--     box hung from the rank text, and each reward card's Highlight (its
--     card art again, added, shown on hover and hidden on leave).
-- Usage: local Mock = dofile("Tools/LegacyMockGame.lua"); local game = Mock.New({ build = 70532 })
local Base = dofile("Tools/WindowMockGame.lua")
local Mock = {}

function Mock.New(options)
    local game = Base.New(options)
    local env, st, New = game.env, game.st, game.New
    game.build = options and options.build or 70450
    local LATE = game.build >= 70532
    local Proto = getmetatable(env.UIParent).__index
    local function Own(obj, key, value) rawset(obj, key, value) end
    game.Own = Own

    -- What the window mock doesn't have yet.
    function Proto:SetStatusBarTexture(file)
        local s = st[self]
        if not s.bar then s.bar = New("Texture", nil, self, "ARTWORK") end
        s.bar:SetTexture(file)
    end
    function Proto:GetStatusBarTexture() return st[self].bar end
    function Proto:SetStatusBarColor(r, g, b) st[self].barColour = { r, g, b } end
    function Proto:GetNormalFontObject() return st[self].normalFont end
    function Proto:GetHighlightFontObject() return st[self].highlightFont end
    function Proto:GetShadowColor() return unpack(st[self].shadowColour or { 0, 0, 0, 1 }) end
    function Proto:SetRotation(angle) st[self].rotation = angle end
    function Proto:SetFixedFrameLevel(on) st[self].fixedLevel = on end
    function Proto:SetID(id) st[self].id = id end
    function Proto:GetID() return st[self].id or 0 end
    function Proto:GetJustifyH() return st[self].justify or "CENTER" end
    function Proto:RegisterForClicks(...) st[self].clicks = { ... } end
    local GOLD_FONTS = { AchievementPointsFont = true, AchievementPointsFontSmall = true }
    for _, name in ipairs({ "GameFontNormalLarge", "GameFontHighlightMedium", "SystemFont_Shadow_Large",
        "SystemFont_Shadow_Med1", "Game15Font_Shadow", "SystemFont16_Shadow_ThickOutline", "GameFontNormalMed3",
        "Game32Font_Shadow2", "AchievementPointsFont", "AchievementPointsFontSmall" }) do
        local font = New("Font", name)
        st[font].game = false
        st[font].colour = (name:find("Normal", 1, true) or GOLD_FONTS[name]) and { 1, 0.82, 0 } or { 1, 1, 1 }
    end
    -- The old talent window's rank font (10 pt): about 5 across a character.
    st[env.GameFontNormalSmall].charWidth = 5
    env.GENERIC_FRACTION_STRING = "%d/%d"
    -- Dark Windows' hand-over of dark text, recorded.
    game.ns.DarkWindowText = function(text, force)
        game.dark[text] = "text"
        if force then game.darkForced = game.darkForced + 1 end
    end
    env.EventRegistry = { callbacks = {} }
    function env.EventRegistry:RegisterCallback(event, fn) self.callbacks[event] = fn end
    function env.EventRegistry:TriggerEvent(event, ...) if self.callbacks[event] then self.callbacks[event](nil, ...) end end

    ---------------------------------------------------------------------------
    -- The Legacy challenges' data: the achievement API as the camelot client
    -- has it, and the camelot overrides the game's page and cards call:
    --   * categories (GetCategoryList, GetCategoryInfo with the parent, -1 at
    --     the top), each one's challenges by index, done ones first
    --     (GetCategoryNumAchievements: all, done, not done);
    --   * a challenge's info (GetAchievementInfo by category and index or by
    --     id), Legacy points (C_Traits), a chain (GetPreviousAchievement),
    --     objectives (GetAchievementNumCriteria, GetAchievementCriteriaInfo);
    --   * the search: SetAchievementSearchString's results arrive on the next
    --     frame with ACHIEVEMENT_SEARCH_UPDATED (only when they change), none
    --     at all before the first one (the client drops them on a loading
    --     screen);
    --   * the game's two filter boxes (LegacyChallengeFilters), tracking
    --     (C_ContentTracking, the game rule, the limit), links, modified
    --     clicks, the chat box, the gamepad mode, the player's class.
    -- game.secret: "fields" hides each value of a challenge but its id (as a
    -- fight or an instance might), "all" its id and the counts too.
    ---------------------------------------------------------------------------

    local SECRET = Base.SECRET
    local cats, achs, catOrder = {}, {}, {}
    local function Category(id, name, parent)
        cats[id] = { id = id, name = name, parent = parent or -1, ids = {} }
        catOrder[#catOrder + 1] = id
    end
    local nextId = 1000
    local function Challenge(cat, name, data)
        nextId = nextId + 1
        data = data or {}
        data.id, data.name, data.category = nextId, name, cat
        data.description = data.description or ("Earn " .. name .. ".")
        data.legacy = data.legacy or 1
        data.points = data.points or 10
        data.icon = data.icon or ("Interface\\Icons\\Ach_" .. nextId)
        achs[nextId] = data
        table.insert(cats[cat].ids, nextId)
        return nextId
    end
    game.cats, game.achs, game.catOrder = cats, achs, catOrder
    local CLASSES = { "Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior" }
    Category(15576, "Classes")
    for i, class in ipairs(CLASSES) do
        local cat = 15576 + i
        Category(cat, class, 15576)
        for _, step in ipairs({ { "Novice", 25 }, { "Experienced", 45 }, { "Master", 60 } }) do
            game[class .. step[1]] = Challenge(cat, step[1] .. " " .. class, {
                description = "Reach level " .. step[2] .. " for the first time on a " .. class .. ".",
                criteria = { { text = "Reach level " .. step[2], quantity = 32, required = step[2], counted = true } } })
        end
    end
    Category(15600, "Tradeskills")
    Category(15601, "Alchemy", 15600)
    Challenge(15601, "Apprentice Alchemist")
    Challenge(15601, "Journeyman Alchemist")
    Category(15602, "Mining", 15600)
    Challenge(15602, "Apprentice Miner")
    Challenge(15602, "Journeyman Miner")
    Category(15610, "Player vs. Player")
    game.honor = Challenge(15610, "Honorable Kill")
    Challenge(15610, "Battle Hardened")
    Category(15611, "Battlegrounds", 15610)
    Challenge(15611, "Warsong Victor")
    Challenge(15611, "Arathi Victor")
    Category(15620, "Adventure")
    Category(15621, "Exploration", 15620)
    Category(15622, "Quests", 15620)
    Challenge(15622, "Questing Novice")
    Challenge(15622, "Questing Hero")
    Category(15630, "Dungeons")
    Challenge(15630, "Ragefire Chasm")
    Challenge(15630, "Wailing Caverns")
    game.deadmines = Challenge(15630, "The Deadmines", { legacy = 2, reward = "Reward: a Legacy chest",
        criteria = { { text = "Defeat Rhahk'Zor", done = true }, { text = "Defeat Sneed" },
            { text = "Clear the dungeon", quantity = 3, required = 5, counted = true } } })
    Challenge(15630, "Shadowfang Keep")
    game.delverOne = Challenge(15630, "Dungeon Delver I", { points = 10 })
    game.delverTwo = Challenge(15630, "Dungeon Delver II", { points = 15 })
    achs[game.delverTwo].previous = game.delverOne
    Category(15640, "Raids")
    Challenge(15640, "Molten Core", { legacy = 3 })
    Challenge(15640, "Onyxia's Lair", { legacy = 3 })
    Challenge(15640, "Blackwing Lair", { legacy = 3 })
    game.zulGurub = Challenge(15640, "Zul'Gurub", { legacy = 0 })
    Category(15650, "Feats")
    -- What is done: by this character, or (Experienced Priest) by another.
    function game.Done(id, mine)
        local a = achs[id]
        a.completed, a.mine, a.month, a.day, a.year = true, mine ~= false, 10, 21, 26
    end
    game.Done(game.PriestNovice)
    game.Done(game.PriestExperienced, false)
    game.Done(game.DruidNovice)
    game.Done(game.delverOne)
    game.Done(game.zulGurub)

    -- Each category's challenges as its indices give them: done first.
    local function Sorted(cat)
        local done, open = {}, {}
        for _, id in ipairs(cats[cat].ids) do table.insert(achs[id].completed and done or open, id) end
        for _, id in ipairs(open) do done[#done + 1] = id end
        return done
    end
    local function Hide(value)
        if game.secret then return SECRET end
        return value
    end
    local function Info(id)
        local a = achs[id]
        if not a then return nil end
        return (game.secret == "all") and SECRET or a.id, Hide(a.name), Hide(a.points), Hide(a.completed == true), Hide(a.month),
            Hide(a.day), Hide(a.year), Hide(a.description), Hide(0), Hide(a.icon), Hide(a.reward or ""), Hide(false),
            Hide(a.mine == true), Hide(nil)
    end
    env.GetCategoryList = function()
        local out = {}
        for i, id in ipairs(catOrder) do out[i] = id end
        return out
    end
    env.GetCategoryInfo = function(id)
        local cat = cats[id]
        if not cat then return nil end
        return cat.name, cat.parent, 0
    end
    env.GetCategoryNumAchievements = function(id)
        local cat = cats[id]
        if game.secret == "all" then return SECRET, SECRET, SECRET end
        local total, done = #cat.ids, 0
        for _, aid in ipairs(cat.ids) do if achs[aid].completed then done = done + 1 end end
        return total, done, total - done
    end
    -- game.gaps[category] = index: a place in a category's count with no
    -- challenge behind it (the game's page leaves it out).
    game.gaps = {}
    env.GetAchievementInfo = function(a, b)
        if b ~= nil then
            if game.gaps[a] == b then return nil end
            return Info(Sorted(a)[b])
        end
        return Info(a)
    end
    env.GetAchievementCategory = function(id) return achs[id] and achs[id].category end
    env.GetPreviousAchievement = function(id) return achs[id] and achs[id].previous end
    env.GetAchievementNumCriteria = function(id) return #(achs[id] and achs[id].criteria or {}) end
    env.GetAchievementCriteriaInfo = function(id, i)
        local c = achs[id].criteria[i]
        return Hide(c.text), 0, Hide(c.done == true), Hide(c.quantity or 0), Hide(c.required or 0), nil,
            Hide(c.counted and 1 or 0), 0, ""
    end
    env.GetAchievementLink = function(id)
        local a = achs[id]
        return a and ("|cffffff00|Hachievement:" .. id .. ":Player-1:0:0:0:0:0:0:0:0|h[" .. a.name .. "]|h|r") or nil
    end
    env.Constants = { LegacyConsts = { LEGACY_POINTS_TRAIT_CURRENCY_ID = 4225 }, ContentTrackingConsts = { MaxTrackedAchievements = 10 } }
    env.C_Traits = { GetTraitCurrencyForAchievement = function(currency, id)
        assert(currency == 4225, "the Legacy points currency")
        return Hide(achs[id] and achs[id].legacy or 0)
    end }
    -- The camelot override and the helper the game's card shows its points by.
    env.AchievementFrame_GetOverridePoints = function(_, id)
        return env.C_Traits.GetTraitCurrencyForAchievement(env.Constants.LegacyConsts.LEGACY_POINTS_TRAIT_CURRENCY_ID, id)
    end
    env.AchievementButton_GetProgressivePoints = function(id)
        local _, _, sum = env.GetAchievementInfo(id)
        while env.GetPreviousAchievement(id) do
            id = env.GetPreviousAchievement(id)
            local _, _, points = env.GetAchievementInfo(id)
            sum = sum + points
        end
        return sum or 0
    end
    env.FormatShortDate = function(day, month, year) return string.format("%d/%d/%02d", month, day, year) end
    env.SetFocusedAchievement = function(id) game.focused = id end
    env.EVALUATION_TREE_FLAG_PROGRESS_BAR = 1
    env.bit = { band = function(a, b)
        local out, place = 0, 1
        while a > 0 and b > 0 do
            if a % 2 == 1 and b % 2 == 1 then out = out + place end
            a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
        end
        return out
    end }
    -- The search: its results a frame later.
    local function Matches(text)
        local out, needle = {}, (text or ""):lower()
        for _, cat in ipairs(catOrder) do
            for _, id in ipairs(cats[cat].ids) do
                local a = achs[id]
                if needle == "" or a.name:lower():find(needle, 1, true) or a.description:lower():find(needle, 1, true) then
                    out[#out + 1] = id
                end
            end
        end
        return out
    end
    game.searchResults = nil
    game.searchCalls = 0
    env.SetAchievementSearchString = function(text)
        game.searchCalls = game.searchCalls + 1
        text = text or ""
        env.C_Timer.After(0, function()
            if game.searchResults == text then return end
            game.searchResults = text
            game.Fire("ACHIEVEMENT_SEARCH_UPDATED")
        end)
    end
    env.GetNumFilteredAchievements = function()
        if game.secret == "all" then return SECRET end
        if game.searchResults == nil then return 0 end
        return #Matches(game.searchResults)
    end
    env.GetFilteredAchievementID = function(i) return Matches(game.searchResults or "")[i] end
    env.ACHIEVEMENTFRAME_FILTER_COMPLETED, env.ACHIEVEMENTFRAME_FILTER_INCOMPLETE = "Completed", "Incomplete"
    env.LegacyChallengeFilters = { Completed = { default = true, value = true }, Incomplete = { default = true, value = true } }
    env.LegacyChallengeDefaultCategories = { DRUID = 15577, HUNTER = 15578, MAGE = 15579, PALADIN = 15580, PRIEST = 15581,
        ROGUE = 15582, SHAMAN = 15583, WARLOCK = 15584, WARRIOR = 15585 }
    game.classFile = "PRIEST"
    env.UnitClass = function() return "Priest", game.classFile, 5 end
    -- Tracking (C_ContentTracking, the game rule, the limit, the error box).
    game.tracked, game.trackCalls, game.uiErrors, game.rules = {}, {}, {}, {}
    env.Enum = { ContentTrackingType = { Achievement = 2 }, ContentTrackingStopType = { Manual = 0 },
        GameRule = { TrackAchievementsDisabled = 7 } }
    env.C_GameRules = { IsGameRuleActive = function(rule) return game.rules[rule] == true end }
    env.C_ContentTracking = {
        IsTracking = function(kind, id) return kind == 2 and game.tracked[id] == true end,
        StartTracking = function(kind, id)
            assert(kind == 2, "tracked as an achievement")
            game.tracked[id] = true
            table.insert(game.trackCalls, "start " .. id)
        end,
        StopTracking = function(kind, id, stop)
            assert(kind == 2 and stop == 0, "stopped as an achievement, by hand")
            game.tracked[id] = nil
            table.insert(game.trackCalls, "stop " .. id)
        end,
        GetTrackedIDs = function()
            local out = {}
            for id in pairs(game.tracked) do out[#out + 1] = id end
            return out
        end,
    }
    env.UIErrorsFrame = { AddMessage = function(_, text) table.insert(game.uiErrors, text) end }
    env.ACHIEVEMENT_WATCH_TOO_MANY = "You may only track %d achievements at a time."
    env.ERR_ACHIEVEMENT_WATCH_COMPLETED = "That achievement is already complete."
    env.LEGACY_NO_CHALLENGES = "No challenges found"
    env.TRACK_ACHIEVEMENT = "Track"
    env.GENERIC_FRACTION_STRING_WITH_SPACING = "%d / %d"
    -- Modified clicks (game.modified: the actions held), the chat box (open
    -- unless game.chatOpen is false) and the gamepad mode.
    game.modified, game.linked, game.chatOpen, game.gamepad = {}, {}, true, false
    env.IsModifiedClick = function(action)
        if action == nil then return next(game.modified) ~= nil end
        return game.modified[action] == true
    end
    env.ChatFrameUtil = { InsertLink = function(link)
        if not game.chatOpen then return false end
        table.insert(game.linked, link)
        return true
    end }
    env.InputUtil = { IsGamepadUIEnabled = function() return game.gamepad == true end }

    -- The game's own page, worked out as its Lua does (HasChallenges,
    -- AllChallengesFiltered, GenerateDataProvider, LegacySystem's indices
    -- and visibility, the detail pane's list): every category the game would
    -- list, in its tree order, each followed by the challenges it would show
    -- for it, as "C<id>" and "A<id>".
    local function Filters()
        local f = env.LegacyChallengeFilters
        return f.Completed.value, f.Incomplete.value
    end
    local function Visible(found, id, mine)
        local _, showOpen = Filters()
        return found[id] and not (not mine and not showOpen)
    end
    local function Indices(cat)
        local total, done, open = env.GetCategoryNumAchievements(cat)
        local showDone, showOpen = Filters()
        local first, count = 0, total
        if not showDone then first, count = done, open end
        if not showOpen then first, count = 0, done end
        return first, count
    end
    local function HasChallenges(cat)
        local total, done, open = env.GetCategoryNumAchievements(cat)
        local showDone, showOpen = Filters()
        if showDone and not showOpen then return done > 0 end
        if showOpen and not showDone then return open > 0 end
        if showDone and showOpen then return total > 0 end
        return false
    end
    local function Shown(cat, found)
        local out = {}
        local first, count = Indices(cat)
        for index = first + 1, first + count do
            local id, _, _, _, _, _, _, _, _, _, _, _, mine = env.GetAchievementInfo(cat, index)
            if Visible(found, id, mine) then out[#out + 1] = id end
        end
        return out
    end
    function game.Reference()
        local found = {}
        for i = 1, env.GetNumFilteredAchievements() do found[env.GetFilteredAchievementID(i)] = true end
        local visible = {}
        for _, cat in ipairs(catOrder) do
            if HasChallenges(cat) and #Shown(cat, found) > 0 then
                local up = cat
                while up and up ~= -1 and not visible[up] do
                    visible[up] = true
                    up = cats[up].parent
                end
            end
        end
        local nodes, roots = {}, {}
        local function Node(cat)
            if not visible[cat] then return nil end
            if nodes[cat] then return nodes[cat] end
            local parent = cats[cat].parent ~= -1 and Node(cats[cat].parent) or nil
            local node = { id = cat, kids = {}, own = HasChallenges(cat) and Shown(cat, found) or {} }
            table.insert(parent and parent.kids or roots, node)
            nodes[cat] = node
            return node
        end
        for _, cat in ipairs(catOrder) do Node(cat) end
        local out = {}
        local function Walk(node)
            out[#out + 1] = "C" .. node.id
            for _, id in ipairs(node.own) do out[#out + 1] = "A" .. id end
            for _, kid in ipairs(node.kids) do Walk(kid) end
        end
        for _, node in ipairs(roots) do Walk(node) end
        return out
    end
    -- The game would list this challenge now (its TrySelectChallenge).
    function game.ReferenceHas(id)
        for _, key in ipairs(game.Reference()) do
            if key == "A" .. id then return true end
        end
        return false
    end
    -- The game's "new" marks (Blizzard_LegacyChallengeTracker's
    -- LegacyChallengeViewedUtil): a category and those above it marked when
    -- one of its challenges is earned, cleared only by the game's own list.
    game.unviewed = {}
    env.LegacyChallengeViewedUtil = {
        CategoryHasUnviewedChallenges = function(id) return game.unviewed[id] == true end,
        MarkCategoryViewed = function() error("EraUI must leave clearing the game's new marks to the game's own list", 2) end,
    }
    -- A challenge earned (its date the 21st) and the game's event; the
    -- game's marks set by its own handler of the event, after EraUI's.
    function game.Earn(id)
        game.Done(id)
        game.Fire("ACHIEVEMENT_EARNED", id)
        local cat = achs[id].category
        while cat and cat ~= -1 do
            game.unviewed[cat] = true
            cat = cats[cat].parent
        end
    end

    ---------------------------------------------------------------------------
    -- Building blocks
    ---------------------------------------------------------------------------

    local function Make(fn)
        local made = { game.Building(fn) }
        game.Seal()
        return unpack(made)
    end
    game.Make = Make
    local function Tex(owner, key, layer, atlas)
        local texture = New("Texture", nil, owner, layer or "ARTWORK")
        if atlas then texture:SetAtlas(atlas) end
        if key then Own(owner, key, texture) end
        return texture
    end
    local function Text(owner, key, layer, colour)
        local text = New("FontString", nil, owner, layer or "OVERLAY")
        st[text].textColour = colour or { 1, 1, 1 }
        if key then Own(owner, key, text) end
        return text
    end
    local function Sized(frame, w, h) st[frame].width, st[frame].height = w, h return frame end
    game.Tex, game.Text = Tex, Text

    -- A pool of the game's frames: Acquire makes one (sealed) or reuses a
    -- released one; EnumerateActive walks the active ones.
    local function Pool(make)
        local pool = { active = {}, free = {}, made = 0 }
        function pool:Acquire()
            local frame = table.remove(self.free)
            if not frame then
                frame = Make(make)
                self.made = self.made + 1
            end
            self.active[frame] = true
            return frame
        end
        function pool:Release(frame)
            if not self.active[frame] then return end
            self.active[frame] = nil
            frame:Hide()
            frame:ClearAllPoints()
            table.insert(self.free, frame)
        end
        function pool:ReleaseAll() for frame in pairs(self.active) do self:Release(frame) end end
        function pool:EnumerateActive() return pairs(self.active) end
        function pool:GetNumActive()
            local n = 0
            for _ in pairs(self.active) do n = n + 1 end
            return n
        end
        return pool
    end
    game.Pool = Pool

    -- A scroll box (WowScrollBoxList): the frames it shows, in order, each
    -- laid out as wide as the box, one under another (Lay(extent)).
    local function ScrollBox(owner, key)
        local box = Sized(New("Frame", nil, owner), 300, 400)
        Own(owner, key, box)
        Own(box, "frames", {})
        Own(box, "ForEachFrame", function(self, fn) for _, frame in ipairs(rawget(self, "frames")) do fn(frame) end end)
        Own(box, "Lay", function(self, extent, spacing)
            local y = 0
            for _, frame in ipairs(rawget(self, "frames")) do
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
                frame:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -y)
                st[frame].height = extent
                y = y + extent + spacing
            end
        end)
        return box
    end

    -- LegacySystem.RegisterCurrencyInfoCallback: each owner's method as it
    -- was when its frame loaded (so a post-hook put on the frame's method
    -- later never runs from here), called at once and on each change of the
    -- Legacy points (game.SetPoints).
    local currency = {}
    local function Currency() return { renownCurrency = game.points, quantity = game.points, maxQuantity = game.pointsMax } end
    local function OnCurrency(owner, method)
        currency[#currency + 1] = { owner, method }
        method(owner, Currency())
    end
    function game.SetPoints(points)
        game.points = points
        for _, entry in ipairs(currency) do entry[2](entry[1], Currency()) end
    end

    -- LegacyPointShield (a page header's crown with the points in it): the
    -- crown's art at its own size and the number, white over its gold font.
    local function PointShield(owner)
        local shield = Sized(New("Button", nil, owner), 46, 64)
        Own(owner, "Shield", shield)
        local crown = Tex(shield, "Icon", "BACKGROUND", "UI-Legacy-Points-icon-c60")
        st[crown].width, st[crown].height = 46, 66
        crown:SetPoint("TOPRIGHT", shield, "TOPRIGHT", 0, 0)
        local number = Text(shield, "Points", "OVERLAY")
        number:SetFontObject(env.GameFontNormalMed3)
        number:SetTextColor(1, 1, 1)
        st[number].width, st[number].height = 42, 16
        number:SetPoint("TOPRIGHT", shield, "TOPRIGHT", -2, -31)
        return shield
    end

    -- A status bar of LegacyProgressBarTemplate.
    local function ProgressBar(owner, key)
        local bar = Sized(New("StatusBar", nil, owner), 200, 12)
        Own(owner, key, bar)
        bar:SetStatusBarTexture("Legacy-Progressbar-Fill")
        Tex(bar, "ProgressBarFrame", "OVERLAY", "Legacy-Progressbar-Frame")
        Text(bar, "Text", "OVERLAY")
        return bar
    end

    ---------------------------------------------------------------------------
    -- The window and its tabs
    ---------------------------------------------------------------------------

    local window
    local function SelectPage(self, id)
        Own(self, "currentPage", id)
        for i, page in ipairs(rawget(self, "Pages")) do page:SetShown(i == id) end
        for _, tab in ipairs(rawget(self, "Tabs")) do tab:SetChecked(tab:GetID() == id) end
    end

    local function SideTab(id)
        local tab = Sized(New("Frame", nil, window), 61, 55)
        st[tab].id = id
        st[tab].mouse = true
        Tex(tab, "Background", "BACKGROUND", "common-sidetab")
        Tex(tab, "Icon", "ARTWORK"):SetTexture("Interface/Icons/UI_Chat")
        Tex(tab, "SelectedTexture", "OVERLAY", "common-sidetab-selected")
        local glow = Tex(tab, "TabGlow", "OVERLAY", "common-sidetab-selected")
        glow:SetAlpha(0)
        Tex(tab, "HighlightTexture", "HIGHLIGHT", "common-sidetab-hover")
        Own(tab, "SetChecked", function(self, checked) rawget(self, "SelectedTexture"):SetShown(checked) end)
        tab:SetScript("OnMouseUp", function(self, button, upInside)
            if button == "LeftButton" and upInside then env.EventRegistry:TriggerEvent("Legacy.SelectPage", self:GetID()) end
        end)
        return tab
    end

    local function BuildWindow()
        window = game.Window("LegacySystemFrame", { width = 920, height = 575 })
        -- The panel manager's place for it (area left, xoffset 35).
        window:ClearAllPoints()
        window:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 51, -116)
        local holder = rawget(window, "PortraitContainer")
        local face = rawget(holder, "portrait")
        face:SetAtlas("Legacy-up-c60")
        st[face].width, st[face].height = 45, 62
        face:SetPoint("TOPLEFT", window, "TOPLEFT", 2, 10)
        local mask = New("MaskTexture", nil, holder, "OVERLAY")
        Own(holder, "CircleMask", mask)
        mask:SetPoint("TOPLEFT", face, "TOPLEFT", 2, 0)
        mask:SetPoint("BOTTOMRIGHT", face, "BOTTOMRIGHT", -2, 4)
        local close = rawget(window, "CloseButton")
        st[close].width, st[close].height = 28, 28
        st[close].mouse = true
        close:SetNormalTexture("RedButton-Exit")
        close:SetScript("OnClick", function() window:Hide() end)
        Own(window, "Tabs", {})
        Own(window, "Pages", {})
        for id = 1, 3 do
            local tab = SideTab(id)
            table.insert(rawget(window, "Tabs"), tab)
            if id == 1 then
                tab:SetPoint("TOPLEFT", window, "TOPRIGHT", 0, -60)
            else
                tab:SetPoint("TOPLEFT", rawget(window, "Tabs")[id - 1], "BOTTOMLEFT", 0, -2)
            end
        end
        Own(window, "LegacyRewardTrackTab", rawget(window, "Tabs")[1])
        Own(window, "LegacyChallengeTab", rawget(window, "Tabs")[2])
        Own(window, "LegacyTreeTab", rawget(window, "Tabs")[3])
        Own(window, "SelectPage", SelectPage)
        Own(window, "SetTitle", function(self, text) rawget(rawget(self, "TitleContainer"), "TitleText"):SetText(text) end)
        -- LegacySystemFrameMixin:SelectChallenge (what the tracker, alerts and
        -- links reach through AchievementFrame_SelectAchievement).
        Own(window, "SelectChallenge", function(self, id) rawget(self, "ChallengesPage"):SelectChallenge(id) end)
        env.EventRegistry:RegisterCallback("Legacy.SelectPage", function(_, id) window:SelectPage(id) end)
    end

    ---------------------------------------------------------------------------
    -- Progress Track
    ---------------------------------------------------------------------------

    local function RewardCard(track)
        local card = Sized(New("Frame", nil, rawget(track, "ClipFrame")), 216, 241)
        st[card].mouse = true
        Tex(card, "RewardCardBG", "BACKGROUND"):SetAllPoints(card)
        -- 70532: the hover glow, the card's own art again, added and hidden.
        if LATE then
            local glow = Tex(card, "Highlight", "BACKGROUND")
            glow:SetBlendMode("ADD")
            glow:SetAllPoints(card)
            glow:Hide()
        end
        local icon = Tex(card, "Icon", "ARTWORK")
        st[icon].width, st[icon].height = 64, 64
        icon:SetPoint("TOP", card, "TOP", 0, -60)
        local square = Tex(card, "LevelSquare", "OVERLAY")
        st[square].width, st[square].height = 40, 40
        square:SetPoint("TOP", card, "TOP", 0, 18)
        local check = Tex(card, "EarnedCheckmark", "OVERLAY", "worldquest-tracker-checkmark")
        st[check].width, st[check].height = 26, 26
        check:SetPoint("TOPRIGHT", card, "TOPRIGHT", -20, -15)
        local border = Tex(card, "IconBorder", "OVERLAY")
        st[border].width, st[border].height = 80, 80
        border:SetPoint("CENTER", icon, "CENTER", 0, 0)
        local level = Text(card, "Level", "OVERLAY")
        level:SetPoint("CENTER", square, "CENTER", 0, 0)
        local name = Text(card, "RewardName", "OVERLAY")
        st[name].width = 120
        name:SetPoint("TOP", border, "BOTTOM", 0, -10)
        card:SetScript("OnMouseUp", function() game.cardClicks = (game.cardClicks or 0) + 1 end)
        -- RenownLevelMixin:OnEnter (70532: the glow shown) and OnLeave (the
        -- method, 70532: the glow hidden; before, GameTooltip_Hide).
        card:SetScript("OnEnter", function(self)
            game.cardTips = (game.cardTips or 0) + 1
            if rawget(self, "Highlight") then rawget(self, "Highlight"):SetShown(true) end
        end)
        if LATE then
            card:SetScript("OnLeave", function(self)
                rawget(self, "Highlight"):SetShown(false)
                game.cardTipsHidden = (game.cardTipsHidden or 0) + 1
            end)
        end
        -- RenownLevelMixin:Refresh, cut down: the atlases and colours by earned.
        Own(card, "Refresh", function(self, actual)
            local earned = rawget(self, "level") <= actual
            local art = earned and "Legacy-Rewards-Tracker-Cards" or "Legacy-Rewards-Tracker-Cards-Disable"
            rawget(self, "RewardCardBG"):SetAtlas(art)
            if rawget(self, "Highlight") then rawget(self, "Highlight"):SetAtlas(art, true) end
            rawget(self, "LevelSquare"):SetAtlas(earned and "Legacy-Rewards-Tracker-Diamond" or "Legacy-Rewards-Tracker-Diamond-Disable")
            rawget(self, "IconBorder"):SetAtlas(earned and "Legacy-Rewards-Tracker-Icons-Frame" or "Legacy-Rewards-Tracker-Icons-Frame-Disable")
            rawget(self, "Icon"):SetDesaturated(not earned)
            local white = earned and { 1, 1, 1 } or { 0.5, 0.5, 0.5 }
            rawget(self, "Level"):SetTextColor(white[1], white[2], white[3])
            rawget(self, "RewardName"):SetTextColor(white[1], white[2], white[3])
            rawget(self, "EarnedCheckmark"):SetShown(earned)
        end)
        return card
    end

    local function BuildRewards()
        local page = New("Frame", nil, window)
        page:SetPoint("TOPLEFT", window, "TOPLEFT", 5, 0)
        page:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -5, 6)
        st[page].shown = false
        Own(window, "RewardTrackPage", page)
        table.insert(rawget(window, "Pages"), page)
        Tex(page, "Background", "BACKGROUND", "Legacy-Rewards-Tracker-background")
        -- The crown with the points (its atlas size, as in game).
        local emblem = Tex(page, "Icon", "ARTWORK", "Legacy-Rewards-Tracker-Icon")
        st[emblem].width, st[emblem].height = 86, 131
        emblem:SetPoint("TOP", page, "TOP", 0, -50)
        local number = Text(page, "Points", "ARTWORK")
        number:SetFontObject(env.Game32Font_Shadow2)
        number:SetPoint("CENTER", emblem, "CENTER", 0, -10)
        local label = Text(page, "PointsLabel", "ARTWORK")
        label:SetText("Legacy Points")
        label:SetPoint("TOP", emblem, "BOTTOM", 0, 0)
        local backing = Tex(page, "ProgressBarBackground", "ARTWORK", "Legacy-Progressbar-BG")
        st[backing].width, st[backing].height = 850, 12
        backing:SetPoint("TOP", label, "BOTTOM", 0, -55)
        local bar = ProgressBar(page, "LegacyRewardProgressBar")
        bar:SetPoint("TOPLEFT", backing, "TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", backing, "BOTTOMRIGHT", 0, 3)
        local track = Sized(New("Frame", nil, page), 849, 270)
        Own(page, "LegacyRewardProgressFrame", track)
        track:SetPoint("TOP", bar, "BOTTOM", 0, 2)
        -- RewardTrackFrameMixin's own fields (the Legacy track's key values).
        Own(track, "elementSpacing", -5)
        Own(track, "elementWidth", 216)
        Own(track, "offset", 0)
        Own(track, "selectedIndex", 1)
        local clip = New("Frame", nil, track)
        clip:SetAllPoints(track)
        st[clip].clips = true
        Own(track, "ClipFrame", clip)
        local paragon = Sized(New("Frame", nil, clip), 200, 50)
        st[paragon].shown = false
        Own(clip, "ParagonLevelFrame", paragon)
        Tex(paragon, "Divider", "ARTWORK", "ui-journeys-paragon-level-divider")
        Tex(paragon, "LabelBackground", "BACKGROUND", "shop-card-wide-map")
        Tex(paragon, "IconBorder", "BORDER", "CovenantSanctum-Renown-Icon-Border-Standard")
        Text(paragon, "Label", "BACKGROUND")
        Text(paragon, "Level", "OVERLAY")
        for _, way in ipairs({ { "LeftButton", -1 }, { "RightButton", 1 }, { "JumpLeftButton", -1 }, { "JumpRightButton", 1 } }) do
            local arrow = Sized(New("Button", nil, track), 22, way[1]:find("Jump", 1, true) and 22 or 34)
            st[arrow].mouse = true
            Own(track, way[1], arrow)
            Own(arrow, "direction", way[2])
            arrow:SetNormalTexture("ui-journeys-delve-arrow-big-left")
            arrow:SetHighlightTexture("ui-journeys-delve-arrow-big-left")
            if way[2] == 1 then arrow:GetNormalTexture():SetTexCoord(1, 0, 0, 1) end
            -- The game's arrow: a click picks the next card (StopScroll).
            arrow:SetScript("OnClick", function(self)
                game.arrowClicks = (game.arrowClicks or 0) + 1
                track:SetSelection(rawget(track, "selectedIndex") + rawget(self, "direction"))
            end)
        end
        -- RewardTrackFrameMixin:OnLoad's and the template's anchors.
        rawget(track, "LeftButton"):SetPoint("RIGHT", track, "LEFT", 0, 0)
        rawget(track, "RightButton"):SetPoint("LEFT", track, "RIGHT", 0, 0)
        rawget(track, "JumpLeftButton"):SetPoint("RIGHT", rawget(track, "LeftButton"), "LEFT", 0, 0)
        rawget(track, "JumpRightButton"):SetPoint("LEFT", rawget(track, "RightButton"), "RIGHT", 17, 0)
        local cards = Pool(function() return RewardCard(track) end)
        Own(page, "cardPool", cards)
        -- RewardTrackFrameMixin, cut down: the first card moved by the
        -- selection when the track scrolls, then (RefreshView) the shown range
        -- refreshed only when the middle card changed or when asked.
        Own(track, "SetSelection", function(self, index, forceRefresh)
            local count = #rawget(self, "Elements")
            index = math.max(1, math.min(count, index or count))
            Own(self, "selectedIndex", index)
            if rawget(self, "disableCentering") then
                Own(self, "offset", 0)
            else
                Own(self, "offset", (index - 1) * 211)
                rawget(self, "Elements")[1]:SetPoint("CENTER", clip, "CENTER", -rawget(self, "offset"), 0)
            end
            local middle = rawget(self, "disableCentering") and 1 or index
            if forceRefresh or rawget(self, "centerIndex") ~= middle then
                Own(self, "centerIndex", middle)
                page:OnTrackUpdate()
            end
        end)
        -- LegacyRewardTrackPageMixin, cut down: cards for each level, laid in
        -- a row as RewardTrackFrameMixin:Init does (the pool hands them out in
        -- any order), then each one refreshed (OnTrackUpdate).
        Own(page, "OnTrackUpdate", function(self)
            for _, card in ipairs(rawget(rawget(self, "LegacyRewardProgressFrame"), "Elements")) do card:Refresh(game.renown) end
        end)
        Own(page, "SetupRewardTrack", function(self)
            cards:ReleaseAll()
            local scrolling = #game.rewardLevels > 4
            Own(track, "disableCentering", not scrolling)
            local list = {}
            for i, level in ipairs(game.rewardLevels) do
                local card = cards:Acquire()
                Own(card, "level", level)
                rawget(card, "RewardName"):SetText("Reward " .. i)
                rawget(card, "Level"):SetText(tostring(level))
                if i > 1 then
                    card:SetPoint("LEFT", list[i - 1], "RIGHT", -5, 0)
                elseif scrolling then
                    card:SetPoint("CENTER", clip, "CENTER", 0, 0)
                else
                    card:SetPoint("LEFT", clip, "LEFT", 0, 0)
                end
                card:Show()
                list[i] = card
            end
            Own(track, "Elements", list)
            for _, key in ipairs({ "LeftButton", "RightButton", "JumpLeftButton", "JumpRightButton" }) do
                rawget(track, key):SetShown(scrolling)
            end
            self:OnTrackUpdate()
        end)
        page:SetScript("OnShow", function(self)
            self:SetupRewardTrack()
            track:SetSelection(1, true)
            window:SetTitle("Legacy Progress Track")
        end)
        Own(page, "RefreshPoints", function(self, info) rawget(self, "Points"):SetText(tostring(info.renownCurrency)) end)
        OnCurrency(page, rawget(page, "RefreshPoints"))
    end

    ---------------------------------------------------------------------------
    -- Challenges
    ---------------------------------------------------------------------------

    local function CategoryRow(box)
        local row = Sized(New("Button", nil, box), 300, 25)
        st[row].mouse = true
        row:SetNormalTexture("common-button-list-collapseExpand")
        row:SetHighlightTexture("common-button-list-collapseExpand")
        local fold = Sized(New("Button", nil, row), 20, 20)
        st[fold].mouse = true
        Own(row, "CollapseButton", fold)
        fold:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        Tex(fold, "Icon", "ARTWORK", "common-button-list-minus")
        fold:SetHighlightTexture("common-button-list-minus")
        Own(fold, "UpdateCollapsedState", function(self, collapsed)
            Own(self, "collapsed", collapsed)
            rawget(self, "Icon"):SetAtlas(collapsed and "common-button-list-plus" or "common-button-list-minus", true)
        end)
        local text = Text(row, "ButtonText", "ARTWORK", { 1, 0.82, 0 })
        text:SetPoint("LEFT", row, "LEFT", 8, 0)
        text:SetPoint("RIGHT", fold, "LEFT", -4, 0)
        Tex(row, "NotificationIcon", "ARTWORK", "UI-HUD-MicroMenu-Communities-Icon-Notification")
        -- ListHeaderVisualMixin and LegacyChallengeCategoryMixin, cut down.
        Own(row, "CheckHighlightTitle", function(self)
            local colour = rawget(self, "selected") and { 1, 1, 1 } or { 1, 0.82, 0 }
            rawget(self, "ButtonText"):SetTextColor(colour[1], colour[2], colour[3])
        end)
        Own(row, "SetSelected", function(self, selected)
            Own(self, "selected", selected)
            self:CheckHighlightTitle()
            self:GetNormalTexture():SetAtlas(selected and "Legacy-Challenge-Left-Sub-Tab-selected" or "Legacy-Challenge-Left-Sub-Tab")
        end)
        Own(row, "Init", function(self, data)
            rawget(self, "ButtonText"):SetText(data.name)
            Own(self, "collapsable", data.parent == true)
            fold:SetShown(data.parent == true)
            fold:UpdateCollapsedState(data.collapsed == true)
            local note = rawget(self, "NotificationIcon")
            note:ClearAllPoints()
            note:SetPoint("RIGHT", fold, "LEFT", -4, 0)
            self:SetSelected(data.selected == true)
        end)
        row:SetScript("OnClick", function(self) game.categoryClicks = (game.categoryClicks or 0) + 1 end)
        return row
    end

    local function Criteria(holder)
        local row = Sized(New("Frame", nil, holder), 180, 30)
        Tex(row, "Background", "BACKGROUND", "Legacy-Challenge-Cards-Bar")
        Tex(row, "ProgressBarBackground", "BORDER", "Legacy-Progressbar-BG")
        Tex(row, "Check", "ARTWORK", "worldquest-tracker-checkmark")
        Text(row, "Name", "ARTWORK")
        ProgressBar(row, "ProgressBar")
        Own(row, "Init", function(self, text, completed)
            local name = rawget(self, "Name")
            name:SetText(text)
            local colour = completed and { 1, 1, 1 } or { 0.5, 0.5, 0.5 }
            name:SetTextColor(colour[1], colour[2], colour[3])
            rawget(self, "Check"):SetShown(completed)
        end)
        return row
    end

    local function ChallengeCard(box)
        local card = Sized(New("EventButton", nil, box), 516, 122)
        st[card].mouse = true
        for _, key in ipairs({ "BackgroundMiddle", "Background", "BackgroundTop", "BackgroundBottom" }) do Tex(card, key, "BACKGROUND", "Legacy-Challenge-Cards") end
        Tex(card, "SelectedOverlay", "BORDER", "Legacy-Challenge-Cards-selected"):Hide()
        local ribbon = Tex(card, "TitleBar", "ARTWORK", "Legacy-Challenge-Cards-Ribbon-Brown")
        st[ribbon].height = 40
        ribbon:SetPoint("TOPLEFT", card, "TOPLEFT", 5, -4)
        ribbon:SetPoint("TOPRIGHT", card, "TOPRIGHT", -80, -4)
        Text(card, "Label", "OVERLAY"):SetPoint("TOPLEFT", ribbon, "TOPLEFT", 70, -18)
        -- 400 wide (LegacyChallengeTemplateMixin:OnLoad), three lines tall.
        for _, key in ipairs({ "Description", "HiddenDescription" }) do
            local words = Text(card, key, "OVERLAY")
            st[words].width, st[words].height = 400, 42
            words:SetPoint("TOPLEFT", ribbon, "BOTTOMLEFT", 72, -2)
        end
        rawget(card, "HiddenDescription"):Hide()
        local sign = Tex(card, "PlusMinus", "OVERLAY", "128-redbutton-plus")
        st[sign].width, st[sign].height = 20, 20
        sign:SetPoint("TOPLEFT", card, "TOPLEFT", 76, -49)
        local icon = Sized(New("Frame", nil, card), 60, 60)
        Own(card, "Icon", icon)
        icon:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -18)
        local face = Tex(icon, "texture", "ARTWORK")
        st[face].width, st[face].height = 50, 50
        face:SetPoint("CENTER", icon, "CENTER", 0, 0)
        Tex(icon, "frame", "OVERLAY", "Legacy-Tree-Frame-icon-frame")
        local shield = Sized(New("Button", nil, card), 64, 64)
        st[shield].mouse = true
        Own(card, "Shield", shield)
        shield:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -2)
        local crown = Tex(shield, "Icon", "BACKGROUND", "Legacy-Tree-Frame-Points-Icon")
        st[crown].width, st[crown].height = 35, 51
        crown:SetPoint("TOPRIGHT", shield, "TOPRIGHT", -8, -24)
        Text(shield, "Points", "OVERLAY"):SetPoint("CENTER", crown, "CENTER", -1, -4)
        -- AchievementShield_OnEnter: the challenge's reward in a tooltip.
        shield:SetScript("OnEnter", function() game.shieldTips = (game.shieldTips or 0) + 1 end)
        Tex(shield, "CheckBackground", "OVERLAY", "Legacy-Challenge-Cards-Date-BG")
        local check = Tex(shield, "Check", "OVERLAY", "worldquest-tracker-checkmark")
        st[check].width, st[check].height = 20, 20
        check:SetPoint("TOPRIGHT", shield, "TOPRIGHT", -4, -4)
        -- The date a done one was earned: GameFontNormal, beside the check.
        local date = Text(shield, "DateCompleted", "OVERLAY", { 1, 0.82, 0 })
        date:SetPoint("RIGHT", check, "LEFT", 0, 0)
        date:Hide()
        local tracked = Sized(New("CheckButton", nil, card), 15, 15)
        st[tracked].mouse = true
        st[tracked].shown = false
        Own(card, "Tracked", tracked)
        -- LegacyChallengeTemplateMixin, cut down.
        Own(card, "RefreshStateArt", function(self)
            local selected = rawget(self, "picked") == true
            local dimmed = not rawget(self, "completed") and not selected
            rawget(self, "SelectedOverlay"):SetShown(selected)
            local colour = dimmed and { 0.5, 0.5, 0.5 } or { 1, 1, 1 }
            for _, key in ipairs({ "Label", "Description", "HiddenDescription" }) do rawget(self, key):SetTextColor(colour[1], colour[2], colour[3]) end
            rawget(self, "Background"):SetAtlas(rawget(self, "completed") and "Legacy-Challenge-Cards" or "Legacy-Challenge-Cards-Disable")
        end)
        Own(card, "UpdatePlusMinusTexture", function(self)
            local plusMinus = rawget(self, "PlusMinus")
            local shown = rawget(self, "criteria") ~= nil
            plusMinus:SetShown(shown)
            plusMinus:SetAtlas(rawget(self, "picked") and "128-redbutton-minus" or "128-redbutton-plus")
            -- The text's start moved for the plus and minus (its TOPLEFT only).
            for _, key in ipairs({ "Description", "HiddenDescription" }) do
                rawget(self, key):SetPoint("TOPLEFT", rawget(self, "TitleBar"), "BOTTOMLEFT", shown and 95 or 72, -2)
            end
        end)
        Own(card, "DisplayObjectives", function(self)
            local objectives = env.LegacyChallengeObjectives
            local pool = rawget(objectives, "criteriaPool")
            pool:ReleaseAll()
            objectives:SetParent(self)
            for _, item in ipairs(rawget(self, "criteria") or {}) do
                local row = pool:Acquire()
                row:Init(item[1], item[2])
                row:Show()
            end
        end)
        Own(card, "Init", function(self, data)
            Own(self, "id", data.id)
            Own(self, "completed", data.completed == true)
            Own(self, "criteria", data.criteria)
            -- AchievementTemplateMixin:Init sets the name's width each time.
            rawget(self, "Label"):SetWidth(320)
            rawget(self, "Label"):SetText(data.name)
            rawget(self, "Description"):SetText("Reach a level.")
            -- AchievementShield_SetPoints and UpdateShieldArt (camelot): the
            -- font set again each time, no number and no crown for none.
            local worth = data.points or 1
            Own(self, "points", worth)
            local badge = rawget(self, "Shield")
            local number = rawget(badge, "Points")
            if worth == 0 then
                number:SetText("")
            else
                number:SetFontObject(env.AchievementPointsFont)
                number:SetText(tostring(worth))
            end
            rawget(badge, "Icon"):SetShown(worth > 0)
            rawget(rawget(self, "Shield"), "Check"):SetShown(data.completed == true)
            -- AchievementFrame_SetDateCompleted and ShowDateCompleted (the
            -- Legacy overrides): its words and width, shown when done.
            local date = rawget(badge, "DateCompleted")
            if data.completed == true then
                date:SetText("10/21/26")
                date:SetWidth(date:GetStringWidth() + 5)
            end
            date:SetShown(data.completed == true)
            self:RefreshStateArt()
            self:UpdatePlusMinusTexture()
            if rawget(self, "picked") then self:DisplayObjectives() end
        end)
        card:SetScript("OnClick", function(self)
            Own(self, "picked", not rawget(self, "picked"))
            self:Init({ id = rawget(self, "id"), name = rawget(self, "Label"):GetText(), completed = rawget(self, "completed"),
                criteria = rawget(self, "criteria"), points = rawget(self, "points") })
        end)
        return card
    end

    local function BuildChallenges()
        local page = New("Frame", nil, window)
        page:SetAllPoints(window)
        st[page].shown = false
        Own(window, "ChallengesPage", page)
        table.insert(rawget(window, "Pages"), page)
        Tex(page, "Background", "BACKGROUND", "Legacy-Challenge-BG")
        local divider = Sized(New("Frame", nil, page), 12, 503)
        divider:SetPoint("TOPLEFT", page, "TOPLEFT", 328, -72)
        Own(page, "VerticalDivider", divider)
        Tex(divider, nil, "BACKGROUND", "Legacy-Tree-Frame-divider-Vertical")
        local summary = Sized(New("Frame", nil, page), 520, 36)
        Own(page, "LegacyChallengePointSummary", summary)
        summary:SetPoint("TOPLEFT", page, "TOPLEFT", 280, -25)
        local backing = Tex(summary, "ProgressBarBackground", "ARTWORK", "Legacy-Progressbar-BG")
        st[backing].height = 16
        backing:SetPoint("LEFT", summary, "LEFT", -6, -3)
        backing:SetPoint("RIGHT", summary, "RIGHT", 0, -3)
        local pointsBar = ProgressBar(summary, "PointsBar")
        pointsBar:SetPoint("TOPLEFT", backing, "TOPLEFT", 0, 0)
        pointsBar:SetPoint("BOTTOMRIGHT", backing, "BOTTOMRIGHT", 0, 3)
        PointShield(summary):SetPoint("RIGHT", summary, "LEFT", 14, 4)
        -- LegacyChallengePointSummaryMixin, cut down.
        Own(summary, "RefreshText", function(self, info) rawget(rawget(self, "Shield"), "Points"):SetText(tostring(info.renownCurrency)) end)
        Own(summary, "SetCurrencyInfo", function(self, info)
            self:RefreshText(info)
            rawget(pointsBar, "Text"):SetText(("Legacy Points %d / %d"):format(info.renownCurrency, game.pointsMax))
        end)
        OnCurrency(summary, rawget(summary, "SetCurrencyInfo"))
        local list = Sized(New("Frame", nil, page), 330, 505)
        Own(page, "CategoryList", list)
        list:SetPoint("TOPLEFT", page, "TOPLEFT", 6, -80)
        list:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 8)
        local filter = Sized(New("DropdownButton", nil, list), 93, 22)
        st[filter].mouse = true
        Own(list, "FilterDropdown", filter)
        filter:SetPoint("TOPRIGHT", list, "TOPRIGHT", -8, -9)
        Tex(filter, "Background", "BACKGROUND", "common-dropdown-b-button")
        Text(filter, "Text", "OVERLAY"):SetText("Filter")
        filter:SetScript("OnMouseDown", function() game.filterClicks = (game.filterClicks or 0) + 1 end)
        local search = Sized(New("EditBox", nil, list), 200, 20)
        st[search].mouse = true
        Own(list, "SearchBox", search)
        search:SetPoint("RIGHT", filter, "LEFT", -4, 0)
        search:SetPoint("TOPLEFT", list, "TOPLEFT", 13, -8)
        -- LegacyChallengesPageMixin:OnLoad: the search box's text is the search.
        search:SetScript("OnTextChanged", function(self) env.SetAchievementSearchString(self:GetText() or "") end)
        local rows = ScrollBox(list, "ScrollBox")
        rows:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -35)
        rows:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -20, 5)
        local rowBar = game.ThinBar(list)
        rowBar:ClearAllPoints()
        rowBar:SetPoint("TOPLEFT", rows, "TOPRIGHT", 0, 0)
        rowBar:SetPoint("BOTTOMLEFT", rows, "BOTTOMRIGHT", 0, 0)
        Text(list, "NoResultsText", "ARTWORK", { 1, 0.82, 0 }):Hide()
        local rowPool = Pool(function() return CategoryRow(rows) end)
        Own(list, "RefreshCategorySelectionVisuals", function(self)
            for _, row in ipairs(rawget(rows, "frames")) do row:SetSelected(rawget(row, "selected") == true) end
        end)
        local pane = Sized(New("Frame", nil, page), 560, 490)
        Own(page, "DetailPane", pane)
        pane:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -24, 8)
        local cardBox = ScrollBox(pane, "ScrollBox")
        cardBox:SetPoint("TOPLEFT", pane, "TOPLEFT", 4, -3)
        cardBox:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 5)
        st[cardBox].strata = "HIGH"
        local cardBar = game.ThinBar(pane)
        cardBar:ClearAllPoints()
        cardBar:SetPoint("TOPLEFT", pane, "TOPRIGHT", 6, -8)
        cardBar:SetPoint("BOTTOMLEFT", pane, "BOTTOMRIGHT", 6, 6)
        local cardPool = Pool(function() return ChallengeCard(cardBox) end)
        Own(pane, "GenerateDataProvider", function()
            cardPool:ReleaseAll()
            local shown = {}
            for _, data in ipairs(game.challenges) do
                local card = cardPool:Acquire()
                card:Init(data)
                card:Show()
                shown[#shown + 1] = card
            end
            Own(cardBox, "frames", shown)
            cardBox:Lay(122, 5)
        end)
        Own(pane, "SelectChallenge", function() end)
        Own(pane, "UpdateChallenge", function() end)
        Own(page, "UpdateCategoryList", function()
            rowPool:ReleaseAll()
            local shown = {}
            for _, data in ipairs(game.categories) do
                local row = rowPool:Acquire()
                row:Init(data)
                row:Show()
                shown[#shown + 1] = row
            end
            Own(rows, "frames", shown)
            rows:Lay(25, 1)
        end)
        page:SetScript("OnShow", function(self)
            -- The client drops the search's results on a loading screen and
            -- builds them again when a search is set.
            env.SetAchievementSearchString(search:GetText() or "")
            self:UpdateCategoryList()
            pane:GenerateDataProvider()
            window:SetTitle("Legacy Challenges")
        end)
        page:SetScript("OnHide", function(self) Own(self, "pendingChallengeID", nil) end)
        -- LegacyChallengesPageMixin, cut down to what EraUI follows: the
        -- filter's update (also on the search's results), resetting it, and
        -- choosing a challenge (from the game's window), clearing the search
        -- or the filter when they hide it.
        Own(page, "OnFilterUpdate", function(self)
            game.filterUpdates = (game.filterUpdates or 0) + 1
            self:UpdateCategoryList()
        end)
        Own(page, "IsUsingDefaultFilters", function()
            for _, filter in pairs(env.LegacyChallengeFilters) do
                if filter.value ~= filter.default then return false end
            end
            return true
        end)
        Own(page, "ResetFilters", function(self)
            for _, filter in pairs(env.LegacyChallengeFilters) do filter.value = filter.default end
            self:OnFilterUpdate()
        end)
        Own(page, "TrySelectChallenge", function(_, id)
            local listed = game.ReferenceHas(id)
            if listed then pane:SelectChallenge(id) end
            return listed
        end)
        Own(page, "TrySelectChallengeResettingFilters", function(self, id)
            if self:TrySelectChallenge(id) then return true end
            if env.GetNumFilteredAchievements() == 0 or self:IsUsingDefaultFilters() then return false end
            self:ResetFilters()
            return self:TrySelectChallenge(id)
        end)
        Own(page, "SelectChallenge", function(self, id)
            Own(self, "pendingChallengeID", nil)
            if self:TrySelectChallengeResettingFilters(id) then return end
            local waiting = env.GetNumFilteredAchievements() == 0
            local searching = (search:GetText() or "") ~= ""
            if searching then search:SetText("") end
            if waiting or searching then Own(self, "pendingChallengeID", id) end
        end)
        for _, event in ipairs({ "ACHIEVEMENT_EARNED", "CRITERIA_UPDATE", "ACHIEVEMENT_SEARCH_UPDATED" }) do st[page].events[event] = true end
        page:SetScript("OnEvent", function(self, event)
            if event ~= "ACHIEVEMENT_SEARCH_UPDATED" then return end
            self:OnFilterUpdate()
            local pending = rawget(self, "pendingChallengeID")
            if pending then
                self:TrySelectChallengeResettingFilters(pending)
                Own(self, "pendingChallengeID", nil)
            end
        end)
        -- The filter drop down's box clicked (its update callback after).
        function game.SetFilter(which, on)
            env.LegacyChallengeFilters[which].value = on
            page:OnFilterUpdate()
        end
        -- The shared objectives frame and its pool of rows.
        local objectives = Sized(New("Frame", "LegacyChallengeObjectives", window), 400, 70)
        Own(objectives, "criteriaPool", Pool(function() return Criteria(objectives) end))
    end

    ---------------------------------------------------------------------------
    -- The Legacy Tree
    ---------------------------------------------------------------------------

    -- The game's talent states: its border's art and its rank's colour.
    local STATES = {
        locked = { "Legacy-Tree-Frame-icon-frame-disable", { 0.5, 0.5, 0.5 } },
        open = { "Legacy-Tree-Frame-icon-frame-Green", { 0.1, 1, 0.1 } },
        maxed = { "Legacy-Tree-Frame-icon-frame", { 1, 0.82, 0 } },
        refund = { "talents-node-square-red", { 1, 0.1, 0.1 } },
    }
    game.STATES = STATES

    local function TalentButton(holder)
        local button = Sized(New("Button", nil, holder), 40, 40)
        st[button].mouse = true
        Tex(button, "Shadow", "BACKGROUND", "talents-node-square-shadow")
        local icon = Tex(button, "Icon", "BORDER")
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        st[icon].width, st[icon].height = 46, 46
        icon:SetPoint("CENTER", button, "CENTER", 0, 0)
        local overlay = Tex(button, "DisabledOverlay", "BORDER")
        overlay:SetColorTexture(0, 0, 0, 1)
        Tex(button, "StateBorder", "ARTWORK")
        Tex(button, "StateBorderHover", "ARTWORK"):Hide()
        local rank = Text(button, "SpendText", "OVERLAY")
        rank:SetFontObject(env.SystemFont16_Shadow_ThickOutline)
        rank:SetPoint("BOTTOM", button, "BOTTOM", 11, 4)
        local shadows = {}
        for i = 1, 4 do shadows[i] = Text(button, "SpendTextShadow" .. i, "ARTWORK", { 0, 0, 0 }) end
        if LATE then
            -- TalentButtonLegacySquareTemplate's rank box: no key, on the
            -- rank text's left (game.boxArtUnread: a client that doesn't
            -- name its art, only a file).
            local box = Tex(button, nil, "ARTWORK", not game.boxArtUnread and "Talents-Square-Box-c60" or nil)
            if game.boxArtUnread then box:SetTexture(5432100) end
            st[box].width, st[box].height, st[box].sublevel = 79, 34, 1
            -- (game.boxElsewhere: a client hanging it from the button.)
            box:SetPoint("CENTER", game.boxElsewhere and button or rank, "LEFT", -9, 0)
            game.rankBoxes = game.rankBoxes or {}
            game.rankBoxes[button] = box
            -- TalentButtonLegacyMixin:AdjustBaseArt (on load).
            for _, shadow in ipairs(shadows) do shadow:SetShown(false) end
            rank:ClearAllPoints()
            rank:SetPoint("CENTER", button, "BOTTOMRIGHT", 0, 0)
        end
        Tex(button, "Glow", "OVERLAY", "talents-node-square-greenglow"):Hide()
        Tex(button, "Ghost", "OVERLAY"):Hide()
        local search = Sized(New("Frame", nil, button), 63, 63)
        st[search].shown = false
        Own(button, "SearchIcon", search)
        -- TalentButtonArtMixin (camelot), cut down; 70532's
        -- TalentButtonLegacyMixin: the rank white whatever the state.
        Own(button, "ApplyVisualState", function(self, state)
            Own(self, "visualState", state)
            local look = STATES[state]
            rawget(self, "StateBorder"):SetAtlas(look[1], true)
            rawget(self, "StateBorderHover"):SetAtlas(look[1], true)
            rawget(self, "StateBorderHover"):SetAlpha(0.4)
            rawget(self, "SpendText"):SetTextColor(look[2][1], look[2][2], look[2][3])
            local dim = state == "locked"
            rawget(self, "Icon"):SetDesaturated(dim)
            rawget(self, "DisabledOverlay"):SetAlpha(dim and 0.7 or 0.25)
            rawget(self, "DisabledOverlay"):SetShown(dim)
            if LATE then rawget(self, "SpendText"):SetTextColor(1, 1, 1) end
        end)
        -- The rank from the talent's node (its nodeInfo, as the game keeps
        -- it): 70450, TalentButtonBaseMixin:GetSpendText (the current rank
        -- once taken or while it can be, else nothing); 70532, always
        -- "current/max".
        Own(button, "UpdateSpendText", function(self)
            local info = rawget(self, "nodeInfo")
            if not info then return end
            local words
            if LATE then
                words = env.GENERIC_FRACTION_STRING:format(info.currentRank, info.maxRanks)
            else
                local open = rawget(self, "visualState") == "open"
                words = (info.ranksPurchased > 0 or open) and tostring(info.currentRank) or ""
            end
            rawget(self, "SpendText"):SetText(words)
            for _, shadow in ipairs(shadows) do shadow:SetText(words) end
        end)
        Own(button, "UpdateNonStateVisuals", function(self) rawget(self, "Glow"):SetShown(rawget(self, "visualState") == "open") end)
        -- The game's click: one rank more (a new node info, as the game's
        -- cache hands out), maxed at the last.
        button:SetScript("OnClick", function(self)
            game.talentClicks = (game.talentClicks or 0) + 1
            local info = rawget(self, "nodeInfo")
            if rawget(self, "visualState") == "open" and info then
                local now = info.currentRank + 1
                Own(self, "nodeInfo", { currentRank = now, maxRanks = info.maxRanks, ranksPurchased = now })
                self:ApplyVisualState(now >= info.maxRanks and "maxed" or "open")
                self:UpdateSpendText()
            end
        end)
        return button
    end

    local function Edge(holder)
        local edge = Sized(New("Frame", nil, holder), 10, 10)
        edge:SetScale(1.25)
        local line = New("Line", nil, edge, "OVERLAY")
        Own(edge, "Line", line)
        Tex(edge, "ArrowHead", "OVERLAY", "talents-arrow-head-gray")
        local ghost = New("Line", nil, edge, "OVERLAY")
        Own(edge, "GhostLine", ghost)
        ghost:Hide()
        Tex(edge, "GhostArrowHead", "OVERLAY", "talents-arrow-head-ghost"):Hide()
        Own(edge, "UpdatePosition", function(self)
            local finish = rawget(self, "endButton")
            rawget(self, "ArrowHead"):SetPoint("CENTER", finish, "CENTER", 0, 0)
        end)
        Own(edge, "UpdateState", function(self)
            local info = rawget(self, "edgeInfo")
            rawget(self, "Line"):SetAtlas(info.isActive and "talents-arrow-line-yellow" or "talents-arrow-line-gray")
            rawget(self, "ArrowHead"):SetAtlas(info.isActive and "talents-arrow-head-yellow" or "talents-arrow-head-gray")
            if rawget(self, "dirty") then
                Own(self, "dirty", false)
                self:UpdatePosition()
            end
        end)
        Own(edge, "Init", function(self, start, finish, info)
            Own(self, "startButton", start)
            Own(self, "endButton", finish)
            Own(self, "edgeInfo", info)
            Own(self, "dirty", true)
            self:UpdateState()
        end)
        return edge
    end

    local function Gate(holder)
        local gate = Sized(New("Frame", nil, holder), 124, 40)
        Tex(gate, "LockIcon", "ARTWORK", "talents-gate")
        Text(gate, "GateText", "OVERLAY", { 1, 0.64, 0.56 })
        return gate
    end

    local function TreeButton(list, index)
        local button = Sized(New("CheckButton", nil, list), 67, 67)
        st[button].mouse = true
        Tex(button, "Background", "BACKGROUND", "Legacy-Tree-Frame-Card")
        Tex(button, "SelectedGlow", "BACKGROUND", "Legacy-Tree-Frame-Card-Glow"):Hide()
        Tex(button, "Ring", "OVERLAY", "Legacy-Tree-Frame-Card-Ring")
        button:SetNormalTexture("UI-Legacy-Tree-Professions")
        button:SetHighlightTexture("Legacy-Tree-Frame-Card-Ring")
        button:SetCheckedTexture("charactercreate-ring-select")
        Own(button, "CheckedTexture", button:GetCheckedTexture())
        button:GetCheckedTexture():SetAlpha(0)
        Own(button, "layoutIndex", index)
        Own(button, "RefreshSelectionVisuals", function(self)
            button:GetHighlightTexture():SetAtlas(self:GetChecked() and "charactercreate-ring-select" or "Legacy-Tree-Frame-Card-Ring")
            rawget(self, "SelectedGlow"):SetShown(self:GetChecked())
        end)
        button:SetScript("OnClick", function(self)
            game.treeClicks = (game.treeClicks or 0) + 1
            env.EventRegistry:TriggerEvent("Legacy.SelectTree", rawget(self, "layoutIndex"))
        end)
        return button
    end

    local function BuildTree()
        local page = New("Frame", nil, window)
        page:SetAllPoints(window)
        st[page].shown = false
        Own(window, "TreePage", page)
        table.insert(rawget(window, "Pages"), page)
        Tex(page, "Background", "BACKGROUND", "Legacy-Tree-Frame-background")
        local selector = Sized(New("Frame", nil, page), 142, 230)
        Own(page, "LegacyTreeSelectionPanel", selector)
        selector:SetPoint("TOPLEFT", page, "TOPLEFT", -2, -205)
        local list = Sized(New("Frame", nil, selector), 1, 1)
        Own(selector, "TreeSelections", list)
        list:SetPoint("TOP", selector, "TOP", 0, 0)
        Own(selector, "treeButtons", {})
        for i = 1, 3 do
            local button = TreeButton(list, i)
            button:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(i - 1) * 82)
            table.insert(rawget(selector, "treeButtons"), button)
        end
        Own(selector, "UpdateSelection", function(self, index)
            for i, button in ipairs(rawget(self, "treeButtons")) do
                button:SetChecked(i == index)
                button:RefreshSelectionVisuals()
            end
        end)
        local summary = Sized(New("Frame", nil, page), 212, 36)
        Own(page, "LegacyTreePointSummary", summary)
        summary:SetPoint("TOPLEFT", page, "TOPLEFT", 155, -22)
        local available = Text(summary, "AvailablePointsLabel", "ARTWORK")
        st[available].height = 18
        available:SetPoint("LEFT", summary, "LEFT", 15, -6)
        Tex(summary, "Border", "BACKGROUND", "Legacy-Tree-Frame-Points-Bar")
        PointShield(summary):SetPoint("RIGHT", summary, "LEFT", 18, 0)
        -- LegacyTreePointSummaryMixin:OnEnter: the points' seasonal cap in a
        -- tooltip, on the summary itself.
        st[summary].mouse = true
        summary:SetScript("OnEnter", function() game.summaryTips = (game.summaryTips or 0) + 1 end)
        -- LegacyTreePointSummaryMixin, cut down.
        Own(summary, "RefreshText", function(self, info)
            rawget(self, "AvailablePointsLabel"):SetText("Available points: " .. info.quantity)
            rawget(rawget(self, "Shield"), "Points"):SetText(tostring(info.renownCurrency))
        end)
        OnCurrency(summary, rawget(summary, "RefreshText"))
        local divider = Sized(New("Frame", nil, page), 12, 503)
        divider:SetPoint("TOPLEFT", page, "TOPLEFT", 128, -72)
        Own(page, "VerticalDivider", divider)
        Tex(divider, "VerticalDivider", "BACKGROUND", "Legacy-Tree-Frame-divider-Vertical")
        local panel = Sized(New("Frame", nil, page), 775, 550)
        Own(page, "LegacyTreeTraitPanel", panel)
        panel:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -6, 8)
        local emblem = Sized(New("CheckButton", nil, panel), 110, 110)
        st[emblem].mouse = true
        Own(panel, "SelectedTreeIcon", emblem)
        emblem:SetPoint("LEFT", panel, "LEFT", 55, 20)
        emblem:SetNormalTexture("UI-Legacy-Tree-Professions")
        emblem:SetHighlightTexture("Legacy-Tree-Frame-Ring-big")
        emblem:SetCheckedTexture("charactercreate-ring-select")
        Own(emblem, "CheckedTexture", emblem:GetCheckedTexture())
        Tex(emblem, "Ring", "OVERLAY", "Legacy-Tree-Frame-Ring-big")
        local label = Text(emblem, "SelectedTreeLabel", "ARTWORK")
        label:SetPoint("BOTTOM", emblem, "TOP", 0, 32)
        local spent = Sized(New("Frame", nil, panel), 30, 30)
        Own(panel, "SpentPointsFrame", spent)
        spent:SetPoint("CENTER", emblem, "BOTTOM", 0, -3)
        Tex(spent, "Background", "BACKGROUND", "Legacy-Tree-Frame-level-circle")
        Text(spent, "Text", "ARTWORK"):SetText("0")
        local apply = Sized(New("Button", nil, panel), 164, 22)
        st[apply].mouse = true
        Own(panel, "ApplyButton", apply)
        apply:SetPoint("BOTTOM", panel, "BOTTOM", 0, 10)
        game.Pieces(apply, "Left Middle Right")
        local glow = New("Frame", nil, apply)
        st[glow].shown = false
        Own(apply, "YellowGlow", glow)
        apply:SetScript("OnClick", function() game.applyClicks = (game.applyClicks or 0) + 1 end)
        for _, key in ipairs({ "ResetButton", "UndoButton" }) do
            local small = Sized(New("Button", nil, panel), 25, 25)
            st[small].mouse = true
            Own(panel, key, small)
            small:SetPoint("LEFT", apply, "RIGHT", 14, 0)
            Tex(small, "Icon", "OVERLAY", key == "UndoButton" and "Legacy-Tree-Frame-reset-button" or "talents-button-reset")
            small:SetHighlightTexture("talents-button-reset")
            small:SetScript("OnClick", function() game.resetClicks = (game.resetClicks or 0) + 1 end)
        end
        local search = Sized(New("EditBox", nil, panel), 184, 30)
        st[search].mouse = true
        Own(panel, "SearchBox", search)
        search:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -15)
        -- The talents' holder: shows only what is inside it, padded 54 in at
        -- the panel's top and foot (TalentFrameBaseMixin:UpdatePadding, on
        -- every load).
        local holder = New("Frame", nil, panel)
        st[holder].level = 1000
        st[holder].mouse = true
        st[holder].clips = true
        Own(panel, "ButtonsParent", holder)
        local function Pad()
            holder:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -54)
            holder:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 54)
        end
        Pad()
        local buttons = Pool(function() return TalentButton(holder) end)
        local links = Pool(function() return Edge(holder) end)
        local gates = Pool(function() return Gate(holder) end)
        Own(panel, "talentButtonCollection", buttons)
        Own(panel, "edgePool", links)
        Own(panel, "gatePool", gates)
        -- TalentFrameBaseMixin, cut down: the buttons placed from their
        -- positions, then each one's links set up.
        Own(panel, "UpdateEdgesForButton", function(self, button)
            for _, link in ipairs(game.links) do
                local from = rawget(self, "byNode")[link[1]]
                if from == button then
                    local edge = links:Acquire()
                    edge:SetParent(holder)
                    edge:Init(from, rawget(self, "byNode")[link[2]], { isActive = link[3] == true })
                    edge:Show()
                end
            end
        end)
        -- TalentFrameBaseMixin:InstantiateTalentButton, cut down: a talent
        -- from the pool, sized (SetAndApplySize: the Legacy square's icon 46,
        -- or node.icon, as the circle template a choice talent gets: 36),
        -- placed from its tree position (posX / 10, -posY / 10).
        Own(panel, "InstantiateTalentButton", function(self, node)
            local button = buttons:Acquire()
            local face = rawget(button, "Icon")
            st[face].width, st[face].height = node.icon or 46, node.icon or 46
            button:SetPoint("CENTER", holder, "TOPLEFT", 0, 0)
            button:SetPoint("CENTER", holder, "TOPLEFT", node.x, node.y)
            st[button].level = st[holder].level + 100
            -- SetNodeID: the node's info (node.max ranks, 1 unless set).
            Own(button, "nodeInfo", { currentRank = node.ranks or 0, maxRanks = node.max or 1, ranksPurchased = node.ranks or 0 })
            Own(button, "nodeID", node.id)
            button:ApplyVisualState(node.state)
            button:UpdateSpendText()
            button:Show()
            rawget(self, "byNode")[node.id] = button
            return button
        end)
        Own(panel, "LoadTalentTreeInternal", function(self)
            buttons:ReleaseAll()
            links:ReleaseAll()
            gates:ReleaseAll()
            holder:SetScale(1)
            Pad()
            local byNode = {}
            Own(self, "byNode", byNode)
            for _, node in ipairs(game.nodes) do self:InstantiateTalentButton(node) end
            for _, node in ipairs(game.nodes) do self:UpdateEdgesForButton(byNode[node.id]) end
            if game.gate then
                local gate = gates:Acquire()
                rawget(gate, "GateText"):SetText("3 points")
                gate:Show()
            end
        end)
        Own(panel, "UpdateAllTalentButtonPositions", function(self)
            for _, node in ipairs(game.nodes) do
                local button = rawget(self, "byNode")[node.id]
                button:SetPoint("CENTER", holder, "TOPLEFT", node.x - game.pan, node.y)
            end
        end)
        Own(panel, "SelectTree", function(self, index)
            Own(self, "selectedTreeIdx", index)
            rawget(emblem, "SelectedTreeLabel"):SetText(({ "Professions", "Adventure", "Resourcefulness" })[index])
            self:LoadTalentTreeInternal()
        end)
        env.EventRegistry:RegisterCallback("Legacy.SelectTree", function(_, index)
            panel:SelectTree(index)
            selector:UpdateSelection(index)
        end)
        page:SetScript("OnShow", function()
            env.EventRegistry:TriggerEvent("Legacy.SelectTree", rawget(panel, "selectedTreeIdx") or 1)
            window:SetTitle("Legacy Tree")
        end)
    end

    ---------------------------------------------------------------------------
    -- Loading the game's addon
    ---------------------------------------------------------------------------

    game.renown = 2
    game.rewardLevels = { 1, 2, 3, 4 }
    game.categories = { { name = "Classes", parent = true }, { name = "Druid" }, { name = "Priest", selected = true },
        { name = "Tradeskills", parent = true, collapsed = true } }
    game.challenges = { { id = 1, name = "Novice Priest", completed = true, points = 1 },
        { id = 2, name = "Master Priest", points = 3, criteria = { { "Reach level 60", false }, { "Be a priest", true } } } }
    game.points, game.pointsMax = 16, 81
    -- Each talent's ranks: taken (ranks) of its most (max).
    game.nodes = { { id = 1, x = 200, y = -100, state = "maxed", ranks = 1, max = 1 }, { id = 2, x = 260, y = -100, state = "open", max = 2 },
        { id = 3, x = 200, y = -160, state = "locked", max = 3 }, { id = 4, x = 320, y = -220, state = "locked", max = 5 },
        { id = 5, x = 380, y = -40, state = "locked", max = 1 } }
    -- From, to, active: across a row, straight down, down and across, up.
    game.links = { { 1, 2, true }, { 1, 3, false }, { 2, 4, false }, { 3, 5, false } }
    game.pan = 0
    game.loadedAddOn = false

    -- The game loading Blizzard_LegacySystem: its frames made (as the
    -- game's, sealed), the first page chosen, then ADDON_LOADED.
    function game.LoadAddOn()
        Make(function()
            BuildWindow()
            BuildRewards()
            BuildChallenges()
            BuildTree()
        end)
        window:SelectPage(1)
        game.loadedAddOn = true
        game.Fire("ADDON_LOADED", "Blizzard_LegacySystem")
        return window
    end
    return game
end

return Mock
