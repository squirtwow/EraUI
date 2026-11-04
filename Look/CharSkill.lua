-- The Skills tab's 1.x detail pane (Classic look, "characterSheet"): the
-- game's skill detail pane brought into the window under the list, with a
-- stone divider above it, the chosen skill's bar, an unlearn X for a skill
-- that can be abandoned, its description with a thin scroll column, and a
-- stone foot with a Close button.
--
-- The pane is one of the game's side panes, which the game hides while the
-- window is collapsed; EraUI shows it itself while Skills shows.
local _, EraUI = ...
local Look = EraUI.Look
local C = Look.Char

local PANE_HEIGHT = 126
local parts = {} -- divider, box, column, foot, unlearn: EraUI's own pieces

local function DetailPane()
    return SkillsFrame and SkillsFrame.SkillDetailFrame
end

-- A region laid along an edge of another: its two corners on that edge
-- (TOP or BOTTOM of the region, at the owner's TOP or BOTTOM), the ends
-- shifted by the given amounts, `up` above.
local function Along(region, owner, edge, ownerEdge, leftShift, rightShift, up)
    region:ClearAllPoints()
    region:SetPoint(edge .. "LEFT", owner, ownerEdge .. "LEFT", leftShift, up)
    region:SetPoint(edge .. "RIGHT", owner, ownerEdge .. "RIGHT", rightShift, up)
end

local function CloseWindow()
    if type(HideUIPanel) == "function" and CharacterFrame then Look.Try(HideUIPanel, CharacterFrame) end
end

-- The chosen skill (not a header), or nil.
function C.ChosenSkill()
    local info = C_SkillInfo
    if not info or type(info.GetSelectedSkill) ~= "function" or type(info.GetSkillLineInfo) ~= "function" then return nil end
    local fine, index = pcall(info.GetSelectedSkill)
    index = fine and Look.Number(index)
    if not index or index <= 0 then return nil end
    local ok, skill = pcall(info.GetSkillLineInfo, index)
    if not ok or type(skill) ~= "table" or skill.isHeader == true then return nil end
    return skill
end

---------------------------------------------------------------------------
-- EraUI's pieces (made once)
---------------------------------------------------------------------------

local function UnlearnTip(button)
    local words = UNLEARN_SKILL_TOOLTIP
    if type(words) ~= "string" or #words > 40 then words = "Unlearn this profession" end
    Look.ShowTip(button, "RIGHT", { { words, C.GOLD[1], C.GOLD[2], C.GOLD[3] } })
end

local function Unlearn()
    local skill = C.ChosenSkill()
    if not skill or skill.isAbandonable ~= true or type(StaticPopup_Show) ~= "function" then return end
    StaticPopup_Show("ERAUI_BASE_UNLEARN_SKILL", skill.name, nil, skill.skillID)
end

local function MakeFoot(pane)
    local foot = Look.Build("Frame", pane, nil, { size = { 100, 26 } })
    Along(foot, pane, "BOTTOM", "BOTTOM", 0, 0, 0)
    local stone = Look.OwnTexture(foot, "stone", "BACKGROUND", 2)
    Look.TileArt(stone, "rockBg")
    Look.Tint(stone, Look.STONE_TINT)
    Look.Fill(stone, foot)
    local line = Look.OwnTexture(foot, "line", "BORDER")
    Look.Tint(line, Look.STONE_LIGHT, true)
    Along(line, foot, "TOP", "TOP", 0, 0, 0)
    line:SetHeight(1)
    local close = Look.PanelButton(foot, C.Text("CLOSE", "Close"), 80)
    Look.Pin(close, "RIGHT", foot, "RIGHT", -2, 0)
    close:SetScript("OnClick", CloseWindow)
    parts.close = close
    return foot
end

local function MakeUnlearn(pane)
    local button = Look.Build("Button", pane, nil, { size = { 32, 32 } })
    button:SetHitRectInsets(9, 9, 9, 9)
    button:SetNormalTexture(C.BUTTONS .. "CancelButton-Up")
    button:SetPushedTexture(C.BUTTONS .. "CancelButton-Down")
    button:SetHighlightTexture(C.BUTTONS .. "CancelButton-Highlight")
    local glow = button:GetHighlightTexture()
    if glow then glow:SetBlendMode("ADD") end
    button:SetScript("OnEnter", UnlearnTip)
    button:SetScript("OnLeave", function() Look.HideTip(button) end)
    button:SetScript("OnClick", Unlearn)
    button:Hide()
    return button
end

-- The description's scroll column: the character scroll sheet cut to 110
-- tall, lined up under the list's own column.
local function MakeColumn(sheet)
    local column = Look.Build("Frame", sheet, nil, { size = { 31, PANE_HEIGHT - 26 + 10 } })
    local half = (PANE_HEIGHT - 26 + 10) / 2
    -- The sheet's top piece from its top, its foot piece up to row 108.
    for edge, cut in pairs({ TOP = { 0, 0.484375, 0, half / 256 }, BOTTOM = { 0.515625, 1, (108 - half) / 256, 108 / 256 } }) do
        local piece = Look.OwnTexture(column, edge, "BACKGROUND", 1)
        Look.Art(piece, "charScrollBar")
        Look.Crop(piece, cut[1], cut[2], cut[3], cut[4])
        Along(piece, column, edge, edge, 0, 0, 0)
        piece:SetHeight(half)
    end
    return column
end

local function MakeParts(sheet, pane)
    if parts.foot then return end
    parts.divider = Look.StoneBar(sheet)
    parts.box = Look.Build("Frame", pane, nil, { size = { 1, 1 } })
    Look.Inside(parts.box, pane, 2, 38, 22, 28)
    parts.column = MakeColumn(sheet)
    parts.foot = MakeFoot(pane)
    parts.unlearn = MakeUnlearn(pane)
    -- The divider and the column live on the window, so they follow the
    -- pane by hand. One hook per script: Look.HookScript keeps only the
    -- first function it is given for a frame and script.
    Look.HookScript(pane, "OnShow", function() Look.Shown(parts.column, C.active and SkillsFrame:IsShown()) end)
    Look.HookScript(pane, "OnHide", function()
        parts.divider:Hide()
        parts.column:Hide()
    end)
end

---------------------------------------------------------------------------
-- Dressing (each time the list is skinned or the chosen skill changes)
---------------------------------------------------------------------------

local function PlacePane(sheet, pane, skills)
    if not C.Free(pane) then return end
    if pane:GetParent() ~= sheet then pcall(pane.SetParent, pane, sheet) end
    Along(pane, sheet, "BOTTOM", "BOTTOM", 20, -44, 84)
    pane:SetHeight(PANE_HEIGHT)
    pane:SetFrameLevel((Look.Number(sheet:GetFrameLevel()) or 1) + 6)
    if pane.SetClipsChildren then pane:SetClipsChildren(true) end
    Look.Shown(pane, skills)
end

local function DressDescription(sheet, pane)
    local description = pane.Description
    if not description then return end
    Look.Inside(description, parts.box, 6, 4, 6, 4)
    if type(description.SetFontObject) == "function" then pcall(description.SetFontObject, description, GameFontHighlightSmall) end
    local scroller = description.ScrollBox
    local holder = scroller and scroller.FontStringContainer
    local words = holder and holder.FontString
    if not words then return end
    -- The window less the pane's sides (20, 44), the box's (2, 22) and the
    -- text's own inset (6 each side): 284 at the 1.x width.
    local across = (Look.Number(sheet:GetWidth()) or C.SHEET_W) - 20 - 44 - 2 - 22 - 12
    for _, piece in ipairs({ words, holder }) do piece:SetWidth(across) end
    local tall = Look.Number(words:GetStringHeight()) or 0
    if tall > 0 then holder:SetHeight(tall) end
    if type(scroller.FullUpdate) == "function" then pcall(scroller.FullUpdate, scroller, true) end
end

local function PlaceColumn(sheet, pane, skills)
    local column = parts.column
    local listBar = SkillsFrame and SkillsFrame.ScrollBar
    local barLeft, sheetRight = listBar and Look.Number(listBar:GetLeft()), Look.Number(sheet:GetRight())
    local x = (barLeft and sheetRight) and (barLeft - 8 - sheetRight) or -68
    column:SetFrameLevel((Look.Number(pane:GetFrameLevel()) or 1) + 1)
    Look.Pin(column, "BOTTOMLEFT", sheet, "BOTTOMRIGHT", x, 110)
    Look.Shown(column, skills)
    local scroll = pane.DescriptionScrollBar
    if scroll then
        Look.ThinScrollBar(scroll)
        scroll:ClearAllPoints()
        for edge, down in pairs({ TOP = -20, BOTTOM = 20 }) do scroll:SetPoint(edge, column, edge, 0, down) end
    end
end

local function DressRank(pane, skill)
    local rank = pane.RankBar
    if not rank then return end
    C.DressBar(rank, "skills", skill and skill.name or "")
    Along(rank, pane, "TOP", "TOP", 46, -70, -12)
    rank:SetHeight(15)
    C.FitFill(rank)
end

function C.DressSkillPane()
    local sheet, pane = CharacterFrame, DetailPane()
    if not (C.active and sheet and pane) then return end
    MakeParts(sheet, pane)
    local skills = SkillsFrame:IsShown() and true or false
    PlacePane(sheet, pane, skills)
    -- The side-pane pass mutes this pane on the other tabs, and a tab click
    -- runs no side-pane pass: give it back here, while Skills shows.
    if skills and C.Unmute then C.Unmute(pane) end
    Look.Fade(pane.Title)
    Look.Fade(pane.Subtitle)
    if pane.Content then pane.Content:Hide() end
    local divider = parts.divider
    Along(divider, pane, "BOTTOM", "TOP", -2, -24, 6)
    Look.Shown(divider, skills)
    local skill = C.ChosenSkill()
    DressRank(pane, skill)
    DressDescription(sheet, pane)
    PlaceColumn(sheet, pane, skills)
    local unlearn = parts.unlearn
    if pane.RankBar then Look.Pin(unlearn, "LEFT", pane.RankBar, "RIGHT", 0, 0)
    else Look.Pin(unlearn, "TOPRIGHT", pane, "TOPRIGHT", -8, -10) end
    Look.Shown(unlearn, skill ~= nil and skill.isAbandonable == true)
end

-- Installed once: the pane's own refresh, a poll of the chosen skill while
-- Skills shows, and the tab showing or hiding.
function C.WatchSkillPane()
    local pane = DetailPane()
    if not pane or parts.watching then return end
    parts.watching = true
    Look.Hook(pane, "Refresh", function() if C.active then Look.Try(C.DressSkillPane) end end)
    local chosen
    C.Poll(SkillsFrame, 0.05, function()
        if not C.active then return end
        local fine, index = pcall(C_SkillInfo.GetSelectedSkill)
        index = fine and Look.Number(index) or 0
        if index ~= chosen then
            chosen = index
            Look.Try(C.DressSkillPane)
        end
    end)
    -- (SkillsFrame's OnShow is the list's own hook, CharLists.lua: it skins
    -- the list, which dresses this pane.)
    Look.HookScript(SkillsFrame, "OnHide", function() if C.active and C.Free(pane) then pane:Hide() end end)
end

-- What the tests read: EraUI's pieces by name.
function C.SkillPart(name)
    return parts[name]
end
