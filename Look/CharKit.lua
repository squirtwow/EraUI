-- The character window's kit (Classic look, "characterSheet" and
-- "statPanes"): what the sheet, the stat panes, the lists, the skill and
-- reputation details and the equipment pane share.
--
-- EraUI dresses the game's character window: it moves, sizes, fades and
-- recolours the game's pieces, draws the 1.x art beside them and lets the
-- game do every click. What EraUI keeps about a game frame or region lives in
-- weak tables here, never as a key on the game's object.
--
-- Two things happen as this file loads, whatever the settings:
--   * post-hooks on the game's progress-bar SetFillPercent (the skill and
--     reputation bars), so a bar made later is caught from its first fill;
--   * the unlearn pop-up's definition.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local C = { active = false, built = false }
Look.Char = C

C.SHEET_W, C.SHEET_H = 384, 512
C.ART_RIGHT, C.ART_LEFT = 349, 3 -- where the 1.x stone is drawn to
C.PAPER = "Interface\\PaperDollInfoFrame\\"
C.BUTTONS = "Interface\\Buttons\\"
C.GREEN, C.RED, C.WHITE = "|cff20ff20", "|cffff2020", "|cffffffff"
C.GOLD = { 1, 0.82, 0 }
C.GREY = { 0.5, 0.5, 0.5 }

---------------------------------------------------------------------------
-- The 1.x art (the last name is Dark Mode's key, where it has one)
---------------------------------------------------------------------------

do
    local define, paper = Look.DefineArt, C.PAPER
    local general = { TopLeft = "charGeneralTopLeft", TopRight = "charGeneralTopRight", BottomLeft = "charGeneralBotLeft",
        BottomRight = "charGeneralBotRight" }
    for corner, key in pairs(general) do
        define(key, paper .. "UI-Character-General-" .. corner, "UI-Character-General-" .. corner, key)
    end
    for file, key in pairs({ L1 = "charTabTopLeft", R1 = "charTabTopRight", BottomLeft = "charTabBotLeft",
        BottomRight = "charTabBotRight" }) do
        define(key, paper .. "UI-Character-CharacterTab-" .. file, "UI-Character-CharacterTab-" .. file, key)
    end
    define("statBackground", paper .. "UI-Character-StatBackground", "UI-Character-StatBackground")
    define("resistIcons", paper .. "UI-Character-ResistanceIcons", "UI-Character-ResistanceIcons")
    define("tabActive", paper .. "UI-Character-ActiveTab", "UI-Character-ActiveTab", "tabActive")
    define("tabInactive", paper .. "UI-Character-InActiveTab", "UI-Character-InActiveTab", "tabInactive")
    define("tabHighlight", paper .. "UI-Character-Tab-RealHighlight", "UI-Character-Tab-RealHighlight")
    for side in ("Left Right"):gmatch("%a+") do
        for _, state in ipairs({ "Up", "Down" }) do
            local file = "UI-Rotation" .. side .. "-Button-" .. state
            define("rotate" .. side .. state, C.BUTTONS .. file, file)
        end
    end
    define("roundHighlight", C.BUTTONS .. "ButtonHilight-Round", "ButtonHilight-Round")
    -- These exist only as EraUI's copies.
    define("skillsBar", nil, "UI-Character-Skills-Bar", nil, true)
    define("skillsBarBorder", nil, "UI-Character-Skills-BarBorder", "skillsBarBorder", true)
    define("repPlate", nil, "UI-Character-ReputationBar", nil, true)
    define("repHighlight", nil, "UI-Character-ReputationBar-Highlight", nil, true)
    define("charScrollBar", nil, "UI-Character-ScrollBar", "charScrollBar", true)
end

-- The four pieces of a 1.x sheet: key, width, x, y from the top-left.
C.SHEET_PIECES = {
    general = { { "charGeneralTopLeft", 256, 0, 0 }, { "charGeneralTopRight", 128, 256, 0 },
        { "charGeneralBotLeft", 256, 0, -256 }, { "charGeneralBotRight", 128, 256, -256 } },
    tab = { { "charTabTopLeft", 256, 0, 0 }, { "charTabTopRight", 128, 256, 0 },
        { "charTabBotLeft", 256, 0, -256 }, { "charTabBotRight", 128, 256, -256 } },
}

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

-- A number as the window writes it: whole numbers without a decimal point.
function C.Whole(value)
    value = Look.Number(value) or 0
    if value == math.floor(value) then return string.format("%d", value) end
    return tostring(value)
end

-- The 1.x bonus rule: base + bonus + penalty (penalty below 0), white with
-- neither or both, green with only a bonus, red with only a penalty. Returns
-- the coloured value and, when there is a bonus or a penalty, the detail
-- line ("15 (10 base +5)"). A missing or secret input counts as 0.
function C.Bonus(base, bonus, penalty)
    base, bonus, penalty = Look.Number(base) or 0, Look.Number(bonus) or 0, Look.Number(penalty) or 0
    local total = C.Whole(base + bonus + penalty)
    local up, down = bonus > 0, penalty < 0
    local colour = C.WHITE
    if up and not down then colour = C.GREEN elseif down and not up then colour = C.RED end
    local value = colour .. total .. "|r"
    if not up and not down then return value, nil end
    local detail = total .. " (" .. C.Whole(base) .. " base"
    if up then detail = detail .. " " .. C.GREEN .. "+" .. C.Whole(bonus) .. "|r" end
    if down then detail = detail .. " " .. C.RED .. C.Whole(penalty) .. "|r" end
    return value, detail .. ")"
end

-- The game's global string, or the English stand-in.
function C.Text(globalName, fallback)
    local text = _G[globalName]
    if type(text) == "string" and text ~= "" then return text end
    return fallback
end

-- A frame EraUI may change now: anything outside a fight, and in a fight
-- only what the game doesn't guard (the window's layout catches up at the
-- fight's end).
function C.Free(frame)
    if not frame then return false end
    if not Look.InFight() then return true end
    local asked, guarded = Look.Ask(frame, "IsProtected")
    return not (asked and guarded)
end

-- The paper doll's 3D model (its own key, else the global name), or nil.
function C.Model()
    local paper = PaperDollFrame
    return (paper and paper.CharacterModelScene) or CharacterModelScene
end

-- The game's mouse switch on one of its frames, protected.
function C.Mouse(frame, on)
    if frame and frame.EnableMouse and C.Free(frame) then pcall(frame.EnableMouse, frame, on) end
end

-- True on Forever (interface 16000 to 16999).
function C.OnForever()
    if type(ns.OnForever) == "function" then
        local fine, yes = pcall(ns.OnForever)
        if fine then return yes == true end
    end
    local build = GetBuildInfo and select(4, GetBuildInfo())
    build = Look.Number(build)
    return build ~= nil and build >= 16000 and build < 17000
end

-- A frame of EraUI's that runs fn(elapsed) every `every` seconds (0: every
-- frame), only while its parent is visible.
function C.Poll(parent, every, fn)
    local poll = Look.Build("Frame", parent, nil, { size = { 1, 1 } })
    local waited = 0
    poll:SetScript("OnUpdate", function(_, elapsed)
        waited = waited + (elapsed or 0)
        if waited < every then return end
        local spent = waited
        waited = 0
        fn(spent)
    end)
    return poll
end

-- A row of a list: its element data (the game's own accessor, else the
-- copy the game keeps on the row), or nil.
function C.RowData(row)
    local asked, data = Look.Ask(row, "GetElementData")
    if asked and type(data) == "table" then return data end
    local kept = row and row.elementData
    return type(kept) == "table" and kept or nil
end

-- Every row a list's scroll box holds, protected.
function C.EachRow(box, fn)
    if not box or type(box.ForEachFrame) ~= "function" then return false end
    return (pcall(box.ForEachFrame, box, fn))
end

-- The textures directly on a frame whose atlas name holds `word`, faded.
function C.FadeAtlas(owner, word)
    Look.EachRegion(owner, function(piece)
        local read = piece.GetAtlas
        if type(read) ~= "function" then return end
        local fine, atlas = pcall(read, piece)
        if fine and type(atlas) == "string" and not Look.Secret(atlas) and atlas:lower():find(word, 1, true) then
            Look.Fade(piece)
        end
    end)
end

-- The EventRegistry signal other code may follow.
function C.Signal()
    if EventRegistry and EventRegistry.TriggerEvent then
        pcall(EventRegistry.TriggerEvent, EventRegistry, "EraUIClassic.CharacterSheetLaid")
    end
end

---------------------------------------------------------------------------
-- Skill and reputation bar fills: the share each bar was last filled to
---------------------------------------------------------------------------
-- The game sizes a fill against its FillArea, a track that is still 0 wide
-- while a new row is filled for the first time, so the fill's own width says
-- nothing about how full the bar is. The percent the game asked for is kept
-- instead, and the fill is drawn as that share of EraUI's bar.

C.shares = Look.Weak() -- bar: 0..1, the percent the game last asked for
C.fills = Look.Weak()  -- bar: { inset, coords } once EraUI has dressed it

-- The bar's laid-out width: 0 until its edges can be placed (a row the game
-- hasn't laid out yet still reports its template's size).
local function LaidWidth(bar)
    local left, right = Look.Number(bar:GetLeft()), Look.Number(bar:GetRight())
    if not left or not right then return 0 end
    return math.max(0, right - left)
end

-- The fill as its share of the bar: drawn at that width, or not at all
-- when there's nothing to draw (a texture set 0 wide draws at its own size).
function C.FitFill(bar)
    local dressed, fill = C.fills[bar], bar and bar.Fill
    if not dressed or not fill then return end
    local width = (C.shares[bar] or 0) * (LaidWidth(bar) - dressed.inset)
    if width > 0 then
        fill:SetWidth(width)
        fill:SetAlpha(1)
    else
        fill:SetAlpha(0)
    end
end

local function Catch(bar, percent)
    percent = Look.Number(percent)
    if percent then C.shares[bar] = Look.Clamp(percent, 0, 1) end
    local dressed = C.fills[bar]
    if not (dressed and C.active and bar.Fill) then return end
    local crop = dressed.coords
    Look.Crop(bar.Fill, crop[1], crop[2], crop[3], crop[4])
    C.FitFill(bar)
end

-- It runs inside the game's own fill of every bar made from these mixins:
-- a problem goes to the error handler, never back into the game's code.
function C.CatchFill(bar, percent)
    Look.Try(Catch, bar, percent)
end

do
    Look.Hook(ColoredProgressBarMixin, "SetFillPercent", C.CatchFill)
    Look.Hook(SkillsBarMixin, "SetFillPercent", C.CatchFill)
    -- Only a method of its own (it has none today; it takes the hooked one
    -- from ColoredProgressBarMixin).
    Look.HookOwn(ReputationBarMixin, "SetFillPercent", C.CatchFill)
    -- Made with the game's UI before EraUI loads, so it carries the method
    -- from before the hook.
    local rank = SkillsFrame and SkillsFrame.SkillDetailFrame and SkillsFrame.SkillDetailFrame.RankBar
    if rank and SkillsBarMixin and rank.SetFillPercent ~= SkillsBarMixin.SetFillPercent then
        Look.Hook(rank, "SetFillPercent", C.CatchFill)
    end
end

---------------------------------------------------------------------------
-- The unlearn pop-up (Skills tab)
---------------------------------------------------------------------------

if type(StaticPopupDialogs) == "table" then
    StaticPopupDialogs.ERAUI_BASE_UNLEARN_SKILL = {
        text = C.Text("UNLEARN_SKILL_PROMPT", "Unlearn %s?"),
        button1 = C.Text("YES", "Yes"),
        button2 = C.Text("NO", "No"),
        OnAccept = function(_, skillID)
            local abandon = C_SkillInfo and C_SkillInfo.AbandonSkill
            if type(abandon) == "function" then Look.Try(abandon, skillID) end
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        showAlert = 1,
    }
end
