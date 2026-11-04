-- Classic character window: the Skills list, skill detail and Reputation bar
-- fills (Look/CharKit.lua and Look/CharLists.lua, clean-room 2026-10-21), on
-- Tools/CharMockGame.lua.
-- Forever (70425) sizes a ColoredProgressBar's fill against FillArea, a track
-- 6 in from each side of the bar. A list row is made the first time its list
-- is shown and filled there and then, before it is laid out, while that track
-- is still 0 wide: the fill's width says nothing about the bar's share (an
-- early fix that read widths drew Fishing 1/75, First Aid 121/150 and Poisons
-- 1/120 full on the first open after a /reload). EraUI catches the share from
-- the game's own SetFillPercent, hooked on the bar mixins as it loads, and
-- draws its fill that share of the bar (reputation bars 2 in).
-- Covered on both builds (70425 with FillArea, 70374 without): the first open
-- after a /reload, a list opened before EraUI applied, rows made later, rows
-- recycled while scrolling, size changes, the skill detail bar, Reputation,
-- maxed, partial and empty bars, a secret share, and the window off. The
-- game's bars are sealed: no key may be written on them (none tolerated).
-- Run: fengari Tools/TestSkillBarFill.lua
local Mock = dofile("Tools/CharMockGame.lua")
local SECRET = Mock.SECRET
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
local function Near(actual, expected, label)
    checks = checks + 1
    if type(actual) ~= "number" or math.abs(actual - expected) > 1e-6 then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local LINES = {
    { name = "Fishing", rank = 1, maxRank = 75 }, { name = "First Aid", rank = 121, maxRank = 150 },
    { name = "Poisons", rank = 1, maxRank = 120 }, { name = "Herbalism", rank = 0, maxRank = 150 },
    { name = "Defense", rank = 300, maxRank = 300 },
}

local function Session(build, opts)
    opts = opts or {}
    local game = Mock.New({ noFillArea = build == 70374, db = opts.db })
    local env = game.env
    local rank = env.SkillsFrame.SkillDetailFrame.RankBar
    local before = { colored = env.ColoredProgressBarMixin.SetFillPercent, skills = env.SkillsBarMixin.SetFillPercent,
        rank = rank.SetFillPercent }
    local C = game.Load()
    local s = { game = game, env = env, C = C, rank = rank, before = before }
    function s.Fill(bar) return bar.Fill end
    function s.Width(bar) return game.State(bar.Fill).w end
    function s.Alpha(bar) return bar.Fill:GetAlpha() end
    function s.Coords(bar)
        local out = {}
        for i, value in ipairs(game.State(bar.Fill).coords) do out[i] = string.format("%g", value) end
        return table.concat(out, ",")
    end
    function s.Bars(id)
        local bars = {}
        for i, row in ipairs(game.Rows(id)) do bars[i] = row.Content and (row.Content.SkillsBar or row.Content.ReputationBar) end
        return bars
    end
    function s.RowWidth(row) local l, _, r = row:Rect() return r - l end
    function s.Clean(label) Equal(#game.errors, 0, label .. ": nothing reached the error handler (" .. tostring(game.errors[1]) .. ")") end
    return s
end

-- Each skills bar fills exactly its share of the skinned bar (row width - 28),
-- with the whole 1.x fill texture.
local function SharesRight(s, lines, label)
    for i, row in ipairs(s.game.Rows("skills")) do
        local line = lines[i]
        if line and row:IsShown() then
            local bar = row.Content.SkillsBar
            Near(bar:GetWidth(), s.RowWidth(row) - 28, label .. ": " .. line.name .. "'s bar spans the row")
            local share = line.rank / line.maxRank
            if share > 0 then
                Near(s.Width(bar), share * bar:GetWidth(), label .. ": " .. line.name .. " fills its share")
                Equal(s.Alpha(bar), 1, label .. ": " .. line.name .. " drawn")
            else
                Equal(s.Alpha(bar), 0, label .. ": " .. line.name .. " draws nothing")
            end
            Equal(s.Coords(bar), "0,1,0,0.5", label .. ": " .. line.name .. " shows the whole fill")
        end
    end
end

for _, build in ipairs({ 70425, 70374 }) do
    local tag = "(" .. build .. ") "

    -- At load, before any row exists.
    do
        local s = Session(build)
        local env = s.env
        checks = checks + 1
        assert(env.ColoredProgressBarMixin.SetFillPercent ~= s.before.colored, tag .. "ColoredProgressBarMixin hooked at load")
        checks = checks + 1
        assert(env.SkillsBarMixin.SetFillPercent ~= s.before.skills, tag .. "SkillsBarMixin hooked at load")
        Equal(rawget(env.ReputationBarMixin, "SetFillPercent"), nil, tag .. "ReputationBarMixin is given none")
        checks = checks + 1
        assert(s.rank.SetFillPercent ~= s.before.rank, tag .. "the detail rank bar (made before load) hooked on its own")
        s.Clean(tag .. "load")
    end

    -- The first open after a /reload.
    do
        local s = Session(build)
        local game, env = s.game, s.env
        game.Pass()
        game.Open("PaperDollFrame")
        local hooks = game.hooks
        game.Fill("skills", LINES)
        for _, bar in ipairs(s.Bars("skills")) do
            Equal(bar.SetFillPercent, env.SkillsBarMixin.SetFillPercent, tag .. "a row made later carries the mixin's hooked method")
        end
        env.CharacterFrame:ShowSubFrame("SkillsFrame")
        checks = checks + 1
        assert(game.hooks > hooks, tag .. "the dressed bars are kept up by post-hooks")
        for i, bar in ipairs(s.Bars("skills")) do Equal(s.Alpha(bar), 0, tag .. LINES[i].name .. " draws nothing before it's laid out") end
        game.LayRows("skills")
        SharesRight(s, LINES, tag .. "after layout")
        game.Tick(0.05)
        SharesRight(s, LINES, tag .. "a frame later")
        game.Tick(0.3)
        SharesRight(s, LINES, tag .. "after the poll")

        -- Scrolling: the same rows refilled with other skills.
        local scrolled = { LINES[5], LINES[1], LINES[4], LINES[2], LINES[3] }
        game.Fill("skills", scrolled)
        SharesRight(s, scrolled, tag .. "refilled rows at once (full to 1/75, empty to full)")
        game.Tick(0.1)
        SharesRight(s, scrolled, tag .. "refilled rows after re-dressing")
        local longer = { LINES[1], LINES[2], LINES[3], LINES[4], LINES[5], { name = "Lockpicking", rank = 3, maxRank = 300 } }
        game.Fill("skills", longer)
        local sixth = s.Bars("skills")[6]
        Equal(s.Alpha(sixth), 0, tag .. "a row made while scrolling draws nothing until laid out")
        game.LayRows("skills")
        Near(s.Width(sixth), 3 / 300 * sixth:GetWidth(), tag .. "then 3/300")

        -- A new texture from the game keeps the share.
        local first = s.Bars("skills")[1]
        first:SetFillTextureByColorType(3)
        Near(s.Width(first), 1 / 75 * first:GetWidth(), tag .. "a new fill texture keeps the share")
        Equal(s.Coords(first), "0,1,0,0.5", tag .. "and EraUI's coordinates")
        Equal(game.State(first.Fill).h, 15, tag .. "and its height")
        local r, g, b = first.Fill:GetVertexColor()
        Equal(r .. "," .. g .. "," .. b, "0,0,0.5", tag .. "the skill fill stays dark blue")
        Equal(first.Text:GetText(), "1/75", tag .. "the rank reads 1/75")

        -- Rows made narrower.
        local rows = game.Rows("skills")
        for _, row in ipairs(rows) do
            local _, relative, _, _, y = row:GetPoint(2)
            row:SetPoint("TOPRIGHT", relative, "TOPRIGHT", -40, y)
        end
        game.Resize()
        SharesRight(s, longer, tag .. "rows made narrower")

        -- A secret share leaves the fill as it was.
        local width = s.Width(rows[2].Content.SkillsBar)
        rows[2].Content.SkillsBar:SetFillPercent(SECRET)
        Near(s.Width(rows[2].Content.SkillsBar), width, tag .. "a secret share leaves the skill fill as it was")
        s.Clean(tag .. "first open")
    end

    -- The skill detail bar.
    do
        local s = Session(build)
        local game, env = s.game, s.env
        game.selected = 2
        game.skillList = { { name = "Weapon Skills", isHeader = true }, { name = "First Aid", rank = 121, maxRank = 150 } }
        game.Pass()
        game.Open("SkillsFrame")
        local rank = s.rank
        Equal(s.Alpha(rank), 0, tag .. "before a share is caught the detail bar draws nothing")
        Near(rank:GetWidth(), 320 - 46 - 70, tag .. "the detail bar spans the pane")
        rank:SetFillPercent(1)
        Near(s.Width(rank), rank:GetWidth(), tag .. "at max it fills the bar")
        game.Tick(0.1)
        Near(s.Width(rank), rank:GetWidth(), tag .. "still full a frame later")
        rank:SetFillPercent(75 / 300)
        Near(s.Width(rank), rank:GetWidth() / 4, tag .. "75/300 fills a quarter")
        rank:SetFillPercent(1.4)
        Near(s.Width(rank), rank:GetWidth(), tag .. "past max: full and no further")
        rank:SetFillPercent(SECRET)
        Near(s.Width(rank), rank:GetWidth(), tag .. "a secret share leaves the detail fill as it was")
        s.Clean(tag .. "detail")
    end

    -- Reputation: rows first filled before they're laid out.
    do
        local s = Session(build)
        local game, env = s.game, s.env
        game.Pass()
        game.Open("PaperDollFrame")
        local factions = { { name = "Exalted", share = 1, factionID = 1 }, { name = "Halfway", share = 0.5, factionID = 2 },
            { name = "Nothing", share = 0, factionID = 3 } }
        game.Fill("reputation", factions)
        env.CharacterFrame:ShowSubFrame("ReputationFrame")
        local bars = s.Bars("reputation")
        for i, bar in ipairs(bars) do Equal(s.Alpha(bar), 0, tag .. factions[i].name .. " draws nothing before it's laid out") end
        game.LayRows("reputation")
        Near(bars[1]:GetWidth(), 137, tag .. "the 1.x reputation bar is 137 wide")
        Near(s.Width(bars[1]), 135, tag .. "Exalted fills to 2 in from its end")
        Near(s.Width(bars[2]), 67.5, tag .. "halfway fills half")
        Equal(s.Alpha(bars[3]), 0, tag .. "empty draws nothing")
        Equal(s.Coords(bars[1]), "0,1,0,1", tag .. "the whole fill texture")
        local r, g = bars[1].Fill:GetVertexColor()
        Equal(r .. "," .. g, "0,0.6", tag .. "the standing colour stays the game's")
        game.Tick(0.1)
        Near(s.Width(bars[1]), 135, tag .. "still right a frame later")
        game.Fill("reputation", { factions[3], factions[1], factions[2] })
        Equal(s.Alpha(bars[1]), 0, tag .. "a recycled row right at once (empty)")
        Near(s.Width(bars[2]), 135, tag .. "a recycled row right at once (Exalted)")
        bars[2]:SetFillPercent(SECRET)
        Near(s.Width(bars[2]), 135, tag .. "a secret share leaves the reputation fill as it was")
        s.Clean(tag .. "reputation")
    end

    -- A list opened before EraUI applied.
    do
        local s = Session(build)
        local game, env = s.game, s.env
        env.CharacterFrame:Show()
        game.Fill("skills", LINES, true)
        env.CharacterFrame:ShowSubFrame("SkillsFrame")
        game.Pass()
        SharesRight(s, LINES, tag .. "a list opened before EraUI applied, as soon as it's dressed")
        s.Clean(tag .. "opened before")
    end

    -- The window off: Blizzard's own fills, untouched.
    do
        local s = Session(build, { db = { characterSheet = false } })
        local game, env = s.game, s.env
        game.Pass()
        game.Open("SkillsFrame")
        game.Fill("skills", LINES, true)
        game.Fill("skills", LINES) -- filled again once laid out: the game's own sizes
        game.Tick(0.2)
        for i, bar in ipairs(s.Bars("skills")) do
            local share = LINES[i].rank / LINES[i].maxRank
            local track = bar.FillArea or bar
            Near(s.Width(bar), share * track:GetWidth(), tag .. "off: Blizzard's own width for " .. LINES[i].name)
            Equal(s.Alpha(bar), 1, tag .. "off: alpha 1")
            Equal(s.Coords(bar), string.format("0,%g,1,0", share), tag .. "off: Blizzard's own crop")
        end
        s.Clean(tag .. "off")
    end
end

print("Skill bar fill checks passed: " .. checks .. " assertions.")
