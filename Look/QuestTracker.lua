-- The objective tracker in the old quest watch's manner (registry
-- "questTracker", from /era's Quest Tracker, a reload setting):
--   * no header plates, shines or glows: each header's art faded (its atlas
--     remembered and cleared, so the game's add animation shows nothing);
--   * the section titles small and gold, with the 1.x collapse buttons;
--   * the whole tracker's header only while the tracker is collapsed (it
--     comes back so the player can open the tracker again);
--   * quest titles in their difficulty colour, objectives a size smaller,
--     grey, white once started, green when done;
--   * quest item buttons in the 1.x slot ring;
--   * the map's quest list background swapped for the older parchment.
-- Post-hooks only, and only font, colour, texture, size and alpha set from
-- them: EraUI never runs the tracker's own layout (Update, MarkDirty,
-- AddBlock, SetHeader, SetStringText), so the text stays where the game put
-- it and Quest Levels (Modules/QoL.lua) can still prefix the titles. What
-- EraUI notes about the game's pieces sits in weak tables here.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Q = Look.Quest

local TR = { active = false, worn = false }
Q.tracker = TR

local oldAtlas = Look.Weak()     -- header texture: the atlas it had
local dressedBlocks = Look.Weak()
local ringedItems = Look.Weak()
local watchedModules = Look.Weak()
local HEADER_ART = { "Background", "Shine", "Glow" }

-- Each button state's place on the 128 x 64 QuestTrackerButtons sheet: the
-- top-left pixel of a 15 x 14 box, at rest then pressed.
local SHEET_SPOTS = {
    wholeOpen = { 18, 35, 1, 35 }, wholeShut = { 35, 49, 35, 33 },
    sectionOpen = { 35, 17, 35, 1 }, sectionShut = { 52, 17, 52, 1 },
}

local function TextFace()
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function DarkShadow(text)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
end

---------------------------------------------------------------------------
-- Headers
---------------------------------------------------------------------------

local function FadeHeaderArt(header)
    for _, key in ipairs(HEADER_ART) do
        local piece = header[key]
        if type(piece) == "table" and piece.SetAlpha then
            piece:SetAlpha(0)
            local fine, atlas = Look.Ask(piece, "GetAtlas")
            if fine and Q.Words(atlas) then
                oldAtlas[piece] = atlas
                piece:SetTexture(nil)
            end
        end
    end
end

local function GoldTitle(text)
    if type(text) ~= "table" or not text.SetFont then return end
    text:SetFont(TextFace(), 12, "")
    text:SetTextColor(1, 0.82, 0)
    DarkShadow(text)
end

-- One state of the collapse button: the sheet's box for it, filling the
-- 15 x 14 button.
local function SheetBox(face, x, y)
    Look.Fill(face, face:GetParent())
    Look.Crop(face, x / 128, (x + 15) / 128, y / 64, (y + 14) / 64)
end

local function CollapseArt(button, spots)
    if type(button) ~= "table" or not button.SetSize then return end
    button:SetSize(15, 14)
    local rest = Look.StateArt(button, "Normal", "questTrackerButtons")
    if rest then SheetBox(rest, spots[1], spots[2]) end
    local pressed = Look.StateArt(button, "Pushed", "questTrackerButtons")
    if pressed then SheetBox(pressed, spots[3], spots[4]) end
end

local function TrackerShut()
    local frame = ObjectiveTrackerFrame
    return type(frame) == "table" and frame.isCollapsed == true
end

-- The whole tracker's header: plain, and shown only while collapsed.
local function DressWholeHeader()
    local frame = ObjectiveTrackerFrame
    local header = type(frame) == "table" and frame.Header or nil
    if not TR.active or type(header) ~= "table" then return end
    local shut = TrackerShut()
    FadeHeaderArt(header)
    GoldTitle(header.Text)
    CollapseArt(header.MinimizeButton, shut and SHEET_SPOTS.wholeShut or SHEET_SPOTS.wholeOpen)
    Look.Shown(header, shut)
end

-- A section's own collapsed state (the game keeps it on the section, not
-- on its header).
local function SectionShut(module)
    local fine, shut = Look.Ask(module, "IsCollapsed")
    if fine and not Look.Secret(shut) then return shut == true end
    return module.isCollapsed == true
end

local function DressSectionHeader(module, shut)
    local header = module.Header
    if not TR.active or type(header) ~= "table" then return end
    if shut == nil then shut = SectionShut(module) or TrackerShut() end
    FadeHeaderArt(header)
    GoldTitle(header.Text)
    CollapseArt(header.MinimizeButton, shut and SHEET_SPOTS.sectionShut or SHEET_SPOTS.sectionOpen)
end

---------------------------------------------------------------------------
-- Lines (after the game's own SetStringText has laid them out)
---------------------------------------------------------------------------

local DONE, STARTED, WAITING = { 0.4, 0.75, 0.25 }, { 0.93, 0.93, 0.93 }, { 0.8, 0.8, 0.8 }

-- "have/need" at the start of an objective ("3/8 Boar Tusk").
local function Progress(text)
    local words = Q.Words(text)
    if not words then return nil end
    local have, need = words:match("^%s*(%d+)%s*/%s*(%d+)")
    if not have then return nil end
    return tonumber(have), tonumber(need)
end

-- An objective's colour, or nil to leave the game's (a failed line, or
-- text the game keeps hidden).
local function ObjectiveColour(text, style)
    local styles = OBJECTIVE_TRACKER_COLOR
    if type(styles) ~= "table" then styles = {} end
    if style ~= nil and style == styles.Failed then return nil end
    if Look.Secret(text) then return nil end
    local have, need = Progress(text)
    if have then
        if need > 0 and have >= need then return DONE end
        return have > 0 and STARTED or WAITING
    end
    if style ~= nil and style == styles.Complete then return DONE end
    return WAITING
end

-- A title's colour: its difficulty colour, gold without a level, nil
-- (the game's own) when the level or the quest is hidden.
local function TitleColour(block)
    local id = block.id
    if Look.Secret(id) then return nil end
    local level
    local ask = C_QuestLog and C_QuestLog.GetQuestDifficultyLevel
    if Look.Number(id) and type(ask) == "function" then
        local fine, answer = pcall(ask, id)
        if fine and Look.Secret(answer) then return nil end
        level = fine and Look.Number(answer) or nil
    end
    if level and level > 0 then return { Q.LevelColor(level) } end
    return { 1, 0.82, 0 }
end

local function Paint(text, colour)
    if colour then text:SetTextColor(colour[1], colour[2], colour[3]) end
end

-- text and style are the game's own arguments; when styling a line that
-- is already there, its shown text and the game's style are read instead.
local function DressLine(block, line, text, _, style)
    if not TR.active or type(line) ~= "table" or not line.SetFont then return end
    DarkShadow(line)
    if line == block.HeaderText then
        line:SetFont(TextFace(), 11, "")
        Paint(line, TitleColour(block))
        return
    end
    line:SetFont(TextFace(), 10, "")
    if text == nil then
        local fine, shown = Look.Ask(line, "GetText")
        text = fine and shown or nil
        style = style or rawget(line, "colorStyle")
    end
    local holder = line.GetParent and line:GetParent()
    local dash = type(holder) == "table" and holder.Dash or nil
    if dash == line or type(dash) ~= "table" or not dash.SetFont then dash = nil end
    if dash then
        dash:SetFont(TextFace(), 10, "")
        DarkShadow(dash)
    end
    local colour = ObjectiveColour(text, style)
    Paint(line, colour)
    if dash then Paint(dash, colour) end
end

---------------------------------------------------------------------------
-- Blocks and sections
---------------------------------------------------------------------------

local function RingItem(button)
    if type(button) ~= "table" or ringedItems[button] or not button.GetWidth then return end
    ringedItems[button] = true
    local wide = Look.Number(button:GetWidth()) or 26
    local tall = Look.Number(button:GetHeight()) or 26
    local ring = Look.StateArt(button, "Normal", "slotNormal")
    if ring then
        Look.Crop(ring, 0, 1, 0, 1)
        ring:SetSize(wide * 50 / 30, tall * 50 / 30)
        Look.Pin(ring, "CENTER", button, "CENTER", 0, -1)
    end
    local pressed = Look.StateArt(button, "Pushed", "slotPushed")
    if pressed then Look.Crop(pressed, 0, 1, 0, 1) end
end

local function DressBlock(block)
    if not TR.active or type(block) ~= "table" then return end
    RingItem(block.ItemButton or block.itemButton)
    if dressedBlocks[block] then return end
    dressedBlocks[block] = true
    Look.Hook(block, "SetStringText", DressLine)
    if block.HeaderText then DressLine(block, block.HeaderText) end
    if type(block.ForEachUsedLine) == "function" then
        pcall(block.ForEachUsedLine, block, function(line)
            if type(line) == "table" and line.Text then DressLine(block, line.Text) end
        end)
    end
end

local function EachBlock(module, fn)
    local used = module.usedBlocks
    if type(used) ~= "table" then return end
    for _, kind in pairs(used) do
        if type(kind) == "table" then
            for _, block in pairs(kind) do fn(block) end
        end
    end
end

local function DressSection(module)
    if type(module) ~= "table" or type(module.Header) ~= "table" then return end
    DressSectionHeader(module)
    if not watchedModules[module] then
        watchedModules[module] = true
        Look.Hook(module.Header, "SetCollapsed", function(_, shut) DressSectionHeader(module, shut and true or false) end)
        Look.Hook(module, "AddBlock", function(_, block) DressBlock(block) end)
    end
    EachBlock(module, DressBlock)
end

local function DressSections()
    local frame = ObjectiveTrackerFrame
    local sections = type(frame) == "table" and frame.modules or nil
    if type(sections) ~= "table" then return end
    for _, module in ipairs(sections) do Look.Try(DressSection, module) end
end

local function AfterTrackerUpdate()
    if not TR.active then return end
    DressWholeHeader()
    DressSections()
end

---------------------------------------------------------------------------
-- The map's quest list background
---------------------------------------------------------------------------

-- Today's atlas, then the older one shown in its place.
local OLDER = {}
for _, pair in ipairs(Look.Words("QuestLog-main-background>QuestLogBackground QuestLog-empty-quest-background>NoQuestsBackground")) do
    local now, older = pair:match("^(.-)>(.+)$")
    OLDER[now] = older
end

local function OlderListBackground()
    if not TR.active then return end
    local list = QuestScrollFrame
    local back = type(list) == "table" and list.Background or nil
    if type(back) ~= "table" then return end
    local fine, atlas = Look.Ask(back, "GetAtlas")
    local older = fine and Q.Words(atlas) and OLDER[atlas]
    if older then back:SetAtlas(older) end
end

---------------------------------------------------------------------------
-- On (each pass) and off
---------------------------------------------------------------------------

local function TrackerOn()
    TR.active = true
    local frame = ObjectiveTrackerFrame
    if type(frame) ~= "table" then
        Look.MissingPiece("ObjectiveTrackerFrame")
        return
    end
    TR.worn = true
    DressWholeHeader()
    DressSections()
    Look.Hook(QuestScrollFrame, "UpdateBackground", OlderListBackground)
    OlderListBackground()
    local header = frame.Header
    if type(header) == "table" then
        Look.Hook(header, "SetCollapsed", DressWholeHeader)
        Look.HookScript(header, "OnShow", DressWholeHeader, "questTracker")
    end
    Look.Hook(frame, "Update", AfterTrackerUpdate)
end

-- Only after the look went on this session: the whole tracker's header,
-- its art and its font given back; sections and blocks keep the look
-- until the reload this asks for.
local function TrackerOff()
    TR.active = false
    if not TR.worn then return end
    TR.worn = false
    local frame = ObjectiveTrackerFrame
    local header = type(frame) == "table" and frame.Header or nil
    if type(header) == "table" then
        local fine, wanted = Look.Ask(frame, "ShouldShowHeader")
        if fine and wanted == true then Look.Shown(header, true) end
        for _, key in ipairs(HEADER_ART) do
            local piece = header[key]
            if type(piece) == "table" and piece.SetAlpha then
                piece:SetAlpha(1)
                if oldAtlas[piece] then
                    piece:SetAtlas(oldAtlas[piece], true)
                    oldAtlas[piece] = nil
                end
            end
        end
        local text = header.Text
        if type(text) == "table" and text.SetFontObject and ObjectiveTrackerHeaderFont then
            text:SetFontObject(ObjectiveTrackerHeaderFont)
        end
    end
    ns.needsReload = true
end

ns.RegisterModule("questTracker", { apply = TrackerOn, restore = TrackerOff })
