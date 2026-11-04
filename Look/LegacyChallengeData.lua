-- The Legacy window's Challenges page as EraUI draws it (registry
-- "legacyWindow"): the game's challenge data, read the way the game's own
-- page reads it (Blizzard_LegacySystem: the challenges page, its category
-- list and detail pane, LegacySystem's helpers and the camelot achievement
-- overrides), so EraUI's list shows exactly what the game's would:
--   * the categories: the game's list of them (GetCategoryList), each one
--     shown while the filter lets some of its challenges through and the
--     search hides not all of them, with every category above it, in the
--     game's order;
--   * each category's challenges: the game's range of them for the filter
--     (the done ones come first), each one in the search's results and,
--     while unfinished ones are hidden, earned by this character;
--   * one challenge: its name, text, icon and reward text, the points its
--     card shows (its Legacy points, or a chain's points for a step of a
--     chain), done or not (earned by this character), the date, and its
--     objectives (a counted one with its count);
--   * tracking it, through the game's own calls, limit and words; a link to
--     it for the chat box; the player's class's category (the game opens it
--     first).
-- Every read is protected and secret-safe: a value the game hides (in a
-- fight or an instance) is never compared or shown. The last value read for
-- that challenge stands in for it, and a list that can't be read whole
-- keeps the last one (the caller's). Nothing here touches a frame.
local _, EraUI = ...
local Look = EraUI.Look
local L = Look.Legacy

local D = {}
L.ChallengeData = D
D.QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local known = {} -- achievement id: the last record read of it
local goals = {} -- achievement id: the last objectives read of it
local TOP = -1   -- GetCategoryInfo's parent of a top level category
local Num = Look.Number

-- A call of the game's, protected: true and its results, or false.
local function Ask(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

-- A plain yes: only a true the game let EraUI read.
local function Yes(value)
    return not Look.Secret(value) and value == true
end

local function Words(value)
    if type(value) == "string" and not Look.Secret(value) then return value end
    return nil
end

-- The game's words for a global name, or the English stand-in.
local function Say(name, fallback)
    local said = Words(_G[name])
    if said and said ~= "" then return said end
    return fallback
end
D.Say = Say

---------------------------------------------------------------------------
-- The filter and the search
---------------------------------------------------------------------------

-- One of the game's two filter boxes (LegacyChallengeFilters, keyed by the
-- game's own words for "Completed" and "Incomplete"); on unless it says no.
local function Filter(globalName)
    local filters, key = LegacyChallengeFilters, Words(_G[globalName])
    local entry = type(filters) == "table" and key and filters[key] or nil
    if type(entry) ~= "table" then return true end
    local value = entry.value
    if Look.Secret(value) or type(value) ~= "boolean" then return true end
    return value
end

-- Done ones shown, unfinished ones shown.
function D.Filters()
    return Filter("ACHIEVEMENTFRAME_FILTER_COMPLETED"), Filter("ACHIEVEMENTFRAME_FILTER_INCOMPLETE")
end

-- No results yet: the game has none (right after a loading screen, until
-- its page has set the search again), as its own page checks.
function D.Waiting()
    local fine, count = Ask(GetNumFilteredAchievements)
    count = fine and Num(count) or nil
    return count == 0
end

-- The search's results ({ id = true }), or nil when they can't be read.
-- With no search the game's results are every challenge; right after a
-- loading screen they are none until the game has them again.
function D.Searched()
    local fine, count = Ask(GetNumFilteredAchievements)
    count = fine and Num(count) or nil
    if not count then return nil end
    local found = {}
    for i = 1, count do
        local ok, id = Ask(GetFilteredAchievementID, i)
        id = ok and Num(id) or nil
        if id then found[id] = true end
    end
    return found
end

---------------------------------------------------------------------------
-- Categories
---------------------------------------------------------------------------

-- How many challenges, done and not done (nil: unreadable).
local function Counts(category)
    local fine, total, done, open = Ask(GetCategoryNumAchievements, category)
    if not fine then return nil end
    total, done, open = Num(total), Num(done), Num(open)
    if not (total and done and open) then return nil end
    return total, done, open
end

-- The game's HasChallenges: true or false, nil when unreadable.
local function Has(category, showDone, showOpen)
    local total, done, open = Counts(category)
    if not total then return nil end
    if showDone and not showOpen then return done > 0 end
    if showOpen and not showDone then return open > 0 end
    if showDone and showOpen then return total > 0 end
    return false
end

-- LegacySystem.GetChallengeIndices: where the filter's range starts (less
-- one) and how many it has.
local function Range(category, showDone, showOpen)
    local total, done, open = Counts(category)
    if not total then return nil end
    local first, count = 0, total
    if not showDone then first, count = done, open end
    if not showOpen then first, count = 0, done end
    return first, count
end

---------------------------------------------------------------------------
-- One challenge
---------------------------------------------------------------------------

local FIELDS = { "id", "name", "points", "completed", "month", "day", "year", "description", "flags", "icon", "reward",
    "isGuild", "earnedByMe", "earnedBy" }

-- The points the game's card shows: a step of a chain shows the chain's
-- (AchievementButton_GetProgressivePoints), any other its Legacy points
-- (the camelot AchievementFrame_GetOverridePoints, else what it reads).
local function Points(id, raw)
    local fine, before = Ask(GetPreviousAchievement, id)
    if fine and Look.Secret(before) then return nil end
    if fine and before ~= nil then
        local ok, chain = Ask(AchievementButton_GetProgressivePoints, id)
        return ok and Num(chain) or nil
    end
    local ok, legacy = Ask(AchievementFrame_GetOverridePoints, raw, id)
    if ok then return Num(legacy) end
    local consts = type(Constants) == "table" and Constants.LegacyConsts or nil
    local currency = type(consts) == "table" and Num(consts.LEGACY_POINTS_TRAIT_CURRENCY_ID) or nil
    local traits = type(C_Traits) == "table" and C_Traits or nil
    if currency and traits then
        local asked, worth = Ask(traits.GetTraitCurrencyForAchievement, currency, id)
        if asked then return Num(worth) end
    end
    return Num(raw)
end

-- The date the game's card shows for a done one.
local function Date(day, month, year)
    day, month, year = Num(day), Num(month), Num(year)
    if not (day and month and year) then return nil end
    local ok, shown = Ask(FormatShortDate, day, month, year)
    shown = ok and Words(shown) or nil
    if shown then return shown end
    return string.format("%d/%d/%02d", month, day, year % 100)
end

-- GetAchievementInfo's results as a record; a value the game hid taken
-- from the last record of the same challenge. nil: no id to go by, and
-- true with it when that is because the game hid it (or the call failed),
-- not because there is no challenge there.
local function Record(fine, ...)
    if not fine then return nil, true end
    local got, hidden = {}, {}
    for i, key in ipairs(FIELDS) do
        local value = (select(i, ...))
        if Look.Secret(value) then hidden[key] = true else got[key] = value end
    end
    local id = Num(got.id)
    if not id then return nil, hidden.id == true end
    local last = known[id]
    local info = { id = id }
    for _, key in ipairs(FIELDS) do
        if hidden[key] then
            info[key] = last and last[key] or nil
        elseif key ~= "id" then
            info[key] = got[key]
        end
    end
    info.name = Words(info.name) or ""
    info.description = Words(info.description) or ""
    info.reward = Words(info.reward) or ""
    if info.icon == nil or Look.Secret(info.icon) then info.icon = D.QUESTION end
    -- AchievementFrame_ShowAsComplete: done when earned by this character.
    info.done = Yes(info.completed) and Yes(info.earnedByMe)
    info.date = info.done and Date(info.day, info.month, info.year) or nil
    local worth = Points(id, Num(info.points))
    if worth == nil and last then worth = last.worth end
    info.worth = worth or 0
    known[id] = info
    return info
end

-- A challenge by its category and place in it, or by its id alone.
function D.Info(category, index)
    if index then return Record(pcall(GetAchievementInfo, category, index)) end
    return Record(pcall(GetAchievementInfo, category))
end

-- The last record read of a challenge (nil: none yet).
function D.Known(id)
    return known[id]
end

-- A flag in a number of flags (the game's bit.band).
local function Flagged(flags, flag)
    flags, flag = Num(flags), Num(flag)
    if not (flags and flag) or flag <= 0 then return false end
    local band = type(bit) == "table" and bit.band or nil
    if type(band) == "function" then return band(flags, flag) == flag end
    return math.floor(flags / flag) % 2 == 1
end

local function Goal(ok, words, finished, quantity, required, flags)
    if not ok then return nil end
    local read = { words, finished, quantity, required, flags }
    for i = 1, 5 do
        if Look.Secret(read[i]) then return nil end
    end
    quantity, required = Num(quantity), Num(required)
    -- The game's ShouldShowCriteriaProgress: a count it draws as a bar.
    local counted = quantity ~= nil and required ~= nil and required > 0
        and Flagged(flags, Num(EVALUATION_TREE_FLAG_PROGRESS_BAR) or 1)
    return { text = Words(words) or "", done = finished == true, quantity = quantity or 0, required = required or 0,
        counted = counted }
end

-- A challenge's objectives: { text, done, quantity, required, counted }
-- each; one the game hid now is the one read last.
function D.Objectives(id)
    local fine, count = Ask(GetAchievementNumCriteria, id)
    count = fine and Num(count) or nil
    local last = goals[id]
    if not count then return last or {} end
    local out = {}
    for i = 1, count do
        local ok, words, _, finished, quantity, required, _, flags = Ask(GetAchievementCriteriaInfo, id, i)
        out[i] = Goal(ok, words, finished, quantity, required, flags) or (last and last[i])
            or { text = "", done = false, quantity = 0, required = 0, counted = false }
    end
    goals[id] = out
    return out
end

---------------------------------------------------------------------------
-- The tree
---------------------------------------------------------------------------

-- A category's challenges as the game's detail pane lists them (records,
-- each with its category and index), or nil when unreadable.
local function Listed(category, showDone, showOpen, found)
    local first, count = Range(category, showDone, showOpen)
    if not first then return nil end
    local out = {}
    for index = first + 1, first + count do
        local info, unread = D.Info(category, index)
        -- A place the game hides: the last list stands. One with no challenge
        -- in it: left out, as the game's page leaves it out.
        if unread then return nil end
        -- LegacySystem.IsChallengeVisible: earned by others counts as not done.
        local hidden = info and not showOpen and not Yes(info.earnedByMe)
        if info and found[info.id] and not hidden then
            info.category, info.index = category, index
            out[#out + 1] = info
        end
    end
    return out
end

-- Each node's challenges under it and how many of those are done.
local function Tally(nodes)
    local total, done = 0, 0
    for _, node in ipairs(nodes) do
        local count, earned = #node.own, 0
        for _, entry in ipairs(node.own) do
            if entry.done then earned = earned + 1 end
        end
        local below, belowDone = Tally(node.kids)
        node.total, node.done = count + below, earned + belowDone
        total, done = total + node.total, done + node.done
    end
    return total, done
end

-- The categories shown (and every one above each), as the game's page
-- works them out; nil when unreadable. own: each category's challenges.
local function Shown(list, showDone, showOpen, found)
    local shown, own = {}, {}
    for _, raw in ipairs(list) do
        local category = Num(raw)
        if not category then return nil end
        local has = Has(category, showDone, showOpen)
        if has == nil then return nil end
        if has then
            local entries = Listed(category, showDone, showOpen, found)
            if not entries then return nil end
            own[category] = entries
            if #entries > 0 then
                local up = category
                while up and up ~= TOP and not shown[up] do
                    shown[up] = true
                    local ok, _, parent = Ask(GetCategoryInfo, up)
                    if ok and Look.Secret(parent) then return nil end
                    up = ok and Num(parent) or nil
                end
            end
        end
    end
    return shown, own
end

-- The game's tree of categories for the filter and search now: the top
-- level nodes in its order and every node by its category, or nil when
-- the game hides any of it (keep the last). A node: { id, name, depth,
-- parent, kids, own (its challenges), total, done }.
function D.Tree()
    local fine, list = Ask(GetCategoryList)
    if not fine or type(list) ~= "table" then return nil end
    local showDone, showOpen = D.Filters()
    local found = D.Searched()
    if not found then return nil end
    local shown, own = Shown(list, showDone, showOpen, found)
    if not shown then return nil end
    local nodes, roots, broken = {}, {}, false
    local function Node(category)
        if not (category and shown[category]) then return nil end
        if nodes[category] then return nodes[category] end
        local ok, called, parent = Ask(GetCategoryInfo, category)
        if not ok or Look.Secret(parent) then
            broken = true
            return nil
        end
        parent = Num(parent)
        local above = (parent and parent ~= TOP) and Node(parent) or nil
        local node = { id = category, name = Words(called) or "", kids = {}, own = own[category] or {}, parent = above,
            depth = above and (above.depth + 1) or 0 }
        local siblings = above and above.kids or roots
        siblings[#siblings + 1] = node
        nodes[category] = node
        return node
    end
    for _, raw in ipairs(list) do Node(Num(raw)) end
    if broken then return nil end
    Tally(roots)
    return roots, nodes
end

-- A category holding a challenge done since the player last opened it in
-- the game's own list (the game's "new" mark, read only: clearing it is
-- the game's own list's to do, as it updates the micro button too).
function D.Unviewed(category)
    local util = LegacyChallengeViewedUtil
    if type(util) ~= "table" then return false end
    local ok, on = Ask(util.CategoryHasUnviewedChallenges, category)
    return ok and Yes(on)
end

-- The category the game opens first: the player's class's.
function D.Home()
    local homes = LegacyChallengeDefaultCategories
    local ok, _, file = Ask(UnitClass, "player")
    file = ok and Words(file) or nil
    if type(homes) ~= "table" or not file then return nil end
    return Num(homes[file])
end

---------------------------------------------------------------------------
-- Tracking, links
---------------------------------------------------------------------------

local function Kind()
    local enum = type(Enum) == "table" and Enum.ContentTrackingType or nil
    return type(enum) == "table" and Num(enum.Achievement) or nil
end

-- The game's rule that turns tracking challenges off.
local function RuledOut()
    local rules, enum = C_GameRules, type(Enum) == "table" and Enum.GameRule or nil
    local rule = type(enum) == "table" and enum.TrackAchievementsDisabled or nil
    if type(rules) ~= "table" or rule == nil then return false end
    local ok, active = Ask(rules.IsGameRuleActive, rule)
    return ok and Yes(active)
end

-- The game offers tracking: its tracker's calls are there and allowed.
function D.CanTrack()
    local tracking = C_ContentTracking
    return type(tracking) == "table" and type(tracking.StartTracking) == "function" and Kind() ~= nil and not RuledOut()
end

function D.Tracked(id)
    if not D.CanTrack() then return false end
    local ok, on = Ask(C_ContentTracking.IsTracking, Kind(), id)
    return ok and Yes(on)
end

-- The Track box shows where the game's would: tracked, or not done (by
-- this character, or a guild's).
function D.TrackShown(info)
    if not (info and D.CanTrack()) then return false end
    if D.Tracked(info.id) then return true end
    return not (Yes(info.completed) and (Yes(info.earnedByMe) or Yes(info.isGuild)))
end

local function Complain(words)
    local box = UIErrorsFrame
    if type(box) == "table" and type(box.AddMessage) == "function" then pcall(box.AddMessage, box, words, 1, 0.1, 0.1, 1) end
end

local function Most()
    local consts = type(Constants) == "table" and Constants.ContentTrackingConsts or nil
    return type(consts) == "table" and Num(consts.MaxTrackedAchievements) or 10
end

-- Tracked or not, as the game's Track box does it (its ToggleTracking):
-- the game's own calls, its limit and its words. True when tracked now.
function D.ToggleTrack(id)
    if not D.CanTrack() then return false end
    local tracking, kind = C_ContentTracking, Kind()
    if D.Tracked(id) then
        local stops = type(Enum) == "table" and Enum.ContentTrackingStopType or nil
        Ask(tracking.StopTracking, kind, id, type(stops) == "table" and stops.Manual or nil)
        return D.Tracked(id)
    end
    local ok, ids = Ask(tracking.GetTrackedIDs, kind)
    local most = Most()
    if ok and type(ids) == "table" and #ids >= most then
        Complain(string.format(Say("ACHIEVEMENT_WATCH_TOO_MANY", "You may only track %d achievements at a time."), most))
        return false
    end
    local info = D.Info(id)
    if info and ((Yes(info.completed) and Yes(info.isGuild)) or Yes(info.earnedByMe)) then
        Complain(Say("ERR_ACHIEVEMENT_WATCH_COMPLETED", "That achievement is already complete."))
        return false
    end
    local fine, problem = Ask(tracking.StartTracking, kind, id)
    if fine and problem ~= nil and not Look.Secret(problem) and type(ContentTrackingUtil) == "table" then
        Ask(ContentTrackingUtil.DisplayTrackingError, problem)
    end
    return D.Tracked(id)
end

-- A challenge's chat link (nil: none).
function D.Link(id)
    local ok, link = Ask(GetAchievementLink, id)
    return ok and Words(link) or nil
end

-- The challenge the game's own page would focus on its selection.
function D.Focus(id)
    Ask(SetFocusedAchievement, id)
end
