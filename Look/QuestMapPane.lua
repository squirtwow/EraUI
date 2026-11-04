-- The world map's quest pane in the quest log's manner (registry
-- "questMapPane", from /era's Quest Log, a reload setting):
--   * a tiled dark marble floor behind the whole pane (Dark Mode's
--     marbleBg); the list's own background, edge and border faded;
--   * the list's category headers as gold text with the 1.x plus and minus;
--   * quest titles in the 1.x difficulty colours, with the 1.x title glow
--     and the old check box;
--   * a quest's details on the 1.x parchment in brown ink (not tinted);
--   * the details stretched to the pane's full height (the game ships them
--     at a fixed height, which leaves a dead band on a bigger map): one
--     anchor each added to the details and their text area, never in a
--     fight, and the game asked to re-clip its rewards (at most once a
--     frame).
-- Post-hooks only; EraUI's art lives in its own textures, its notes about
-- the game's pieces in weak tables here. Turning it off gives back the
-- details' own size and anchors and asks for a reload for the rest.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Q = Look.Quest

local MP = { active = false, worn = false, queued = false }
Q.mapPane = MP

local keptShape = Look.Weak()     -- the details or their text area: their own size and anchors
local headersDressed = Look.Weak()
local titlesDressed = Look.Weak()
local detailsDressed = Look.Weak()
local INK = { 0.18, 0.12, 0.06 }

local function Details()
    local map = QuestMapFrame
    if type(map) ~= "table" then return nil end
    return map.DetailsFrame or Look.Path(map, "QuestsFrame", "DetailsFrame")
end

local function Rewards(details)
    return Look.Path(details, "RewardsFrameContainer", "RewardsFrame")
end

local function FadeArtOf(frame)
    Look.EachRegion(frame, function(piece)
        if piece.IsObjectType and piece:IsObjectType("Texture") then Look.Fade(piece) end
    end)
end

---------------------------------------------------------------------------
-- The details' height
---------------------------------------------------------------------------

local function RememberShape(frame)
    if keptShape[frame] then return end
    local shape = { wide = frame:GetWidth(), tall = frame:GetHeight(), anchors = {} }
    for i = 1, frame:GetNumPoints() do shape.anchors[i] = { frame:GetPoint(i) } end
    keptShape[frame] = shape
end

local function GiveBack(frame)
    local shape = keptShape[frame]
    if not shape then return false end
    keptShape[frame] = nil
    frame:ClearAllPoints()
    for _, anchor in ipairs(shape.anchors) do frame:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5]) end
    frame:SetSize(shape.wide, shape.tall)
    return true
end

-- The game re-clips its rewards and the text keeps a valid scroll.
local function Remeasure()
    MP.queued = false
    local details = Details()
    if not MP.active or Look.InFight() or not details or not details:IsShown() then return end
    local text = details.ScrollFrame
    if text and text.UpdateScrollChildRect then text:UpdateScrollChildRect() end
    local rewards = Rewards(details)
    local tall = rewards and Look.Number(rewards:GetHeight())
    if tall and type(details.SetRewardsHeight) == "function" then details:SetRewardsHeight(tall) end
    if text and text.GetVerticalScrollRange then
        local most, now = Look.Number(text:GetVerticalScrollRange()), Look.Number(text:GetVerticalScroll())
        if most and now and now > most then text:SetVerticalScroll(most) end
    end
end

local function QueueRemeasure()
    if MP.queued then return end
    MP.queued = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() Look.Try(Remeasure) end)
    else
        Look.Try(Remeasure)
    end
end

-- The game's top and width anchors stay; a bottom one each is added.
local function Stretch()
    local details = Details()
    local text = details and details.ScrollFrame
    local quests = Look.Path(QuestMapFrame, "QuestsFrame")
    if not MP.active or Look.InFight() or not (details and text and quests) then return end
    RememberShape(details)
    RememberShape(text)
    details:SetPoint("BOTTOMRIGHT", quests, "BOTTOMRIGHT", 0, 2)
    text:SetPoint("BOTTOMLEFT", details, "BOTTOMLEFT", 5, 29)
    QueueRemeasure()
end

---------------------------------------------------------------------------
-- The details' look
---------------------------------------------------------------------------

-- Every font string under a frame in parchment ink (through its child
-- frames, never into buttons).
local function Ink(frame)
    if type(frame) ~= "table" or not frame.GetRegions then return end
    Look.EachRegion(frame, function(piece)
        if piece.IsObjectType and piece:IsObjectType("FontString") then piece:SetTextColor(INK[1], INK[2], INK[3]) end
    end)
    for _, child in ipairs({ frame:GetChildren() }) do
        if not (child.IsObjectType and child:IsObjectType("Button")) then Ink(child) end
    end
end

local function DressDetails()
    if not MP.active then return end
    Stretch()
    local details = Details()
    if not details then return end
    local rewards = Rewards(details)
    if not detailsDressed[details] then
        detailsDressed[details] = true
        Look.Fade(details.Bg)
        -- Camelot's themed backdrop for some quests sits above the parchment.
        Look.Fade(details.SealMaterialBG)
        FadeArtOf(details.BorderFrame)
        FadeArtOf(details.BackFrame)
        if rewards then
            Look.Fade(rewards.Top)
            Look.Fade(rewards.Bottom)
            Look.Fade(rewards.Background)
        end
    end
    Ink(Look.Path(details, "ScrollFrame", "Contents"))
    Ink(rewards)
end

---------------------------------------------------------------------------
-- The list's rows
---------------------------------------------------------------------------

local function HeaderShut(button)
    local info = button.info
    if type(info) == "table" and info.isCollapsed ~= nil and not Look.Secret(info.isCollapsed) then
        return info.isCollapsed == true
    end
    local index = Look.Number(button.questLogIndex)
    local found = index and Q.Info(index)
    return found ~= nil and found.isCollapsed == true
end

local function DressHeader(button)
    local words = button.ButtonText or (button.GetFontString and button:GetFontString())
    if not headersDressed[button] then
        headersDressed[button] = true
        FadeArtOf(button)
        Look.Fade(button.GetNormalTexture and button:GetNormalTexture())
        Look.Fade(button.GetHighlightTexture and button:GetHighlightTexture())
        local fold = button.CollapseButton
        if fold then
            Look.Fade(fold)
            fold:EnableMouse(false)
        end
        local icon = Look.OwnTexture(button, "questIcon", "ARTWORK")
        icon:SetSize(16, 16)
        Look.Pin(icon, "LEFT", button, "LEFT", 4, 0)
        local shine = Look.OwnTexture(button, "questGlow", "HIGHLIGHT")
        shine:SetTexture(Q.FILES.plusGlow)
        shine:SetBlendMode("ADD")
        shine:SetSize(16, 16)
        Look.Pin(shine, "LEFT", button, "LEFT", 4, 0)
        if words then
            words:SetFontObject(GameFontNormal)
            words:ClearAllPoints()
            words:SetPoint("LEFT", button, "LEFT", 24, 0)
            words:SetPoint("RIGHT", button, "RIGHT", -4, 0)
        end
        if button.SetNormalFontObject then button:SetNormalFontObject(GameFontNormal) end
        if button.SetHighlightFontObject then button:SetHighlightFontObject(GameFontHighlight) end
    end
    local icon = Look.OwnPiece(button, "questIcon")
    icon:SetTexture(HeaderShut(button) and Q.FILES.plus or Q.FILES.minus)
    icon:SetVertexColor(1, 1, 1)
    if words then words:SetTextColor(1, 0.82, 0) end
end

local function TitleLevel(button)
    local info = button.info
    local level = type(info) == "table" and Look.Number(info.difficultyLevel) or nil
    if level and level > 0 then return level end
    local questID = Look.Number(button.questID)
    local ask = C_QuestLog and C_QuestLog.GetQuestDifficultyLevel
    if questID and type(ask) == "function" then
        local fine, answer = pcall(ask, questID)
        level = fine and Look.Number(answer) or nil
        if level and level > 0 then return level end
    end
    return nil
end

local function ColourTitle(button)
    if not MP.active then return end
    local level = TitleLevel(button)
    local r, g, b = 1, 0.82, 0
    if level then r, g, b = Q.LevelColor(level) end
    for _, key in ipairs({ "Text", "TagText" }) do
        local words = button[key]
        if words and words.SetTextColor then words:SetTextColor(r, g, b) end
    end
end

-- The old check box: the mark, the hover glow, the box.
local function OldCheckBox(box)
    Look.EachRegion(box, function(piece)
        if not (piece.IsObjectType and piece:IsObjectType("Texture")) then return end
        local file, glow = Q.FILES.box, false
        if piece == box.CheckMark then
            file = Q.FILES.check
        elseif piece:GetDrawLayer() == "HIGHLIGHT" then
            file, glow = Q.FILES.boxGlow, true
        end
        piece:SetTexture(file)
        Look.Crop(piece, 0, 1, 0, 1)
        if glow then piece:SetBlendMode("ADD") end
    end)
end

local function DressTitle(button)
    if not titlesDressed[button] then
        titlesDressed[button] = true
        Look.Fade(button.StorylineTexture)
        Look.Fade(button.TaskIcon)
        local band = button.HighlightTexture
        if band and band.SetTexture then
            Look.Art(band, "questLogHighlight")
            Look.Crop(band, 0, 1, 0, 1)
            band:SetBlendMode("ADD")
            Look.Inside(band, button, 0, 2, 0, 2)
        end
        if button.Checkbox then OldCheckBox(button.Checkbox) end
        Look.HookScript(button, "OnLeave", ColourTitle, "questMapPane")
    end
    ColourTitle(button)
end

local function EachActive(pool, dress)
    if type(pool) ~= "table" or type(pool.EnumerateActive) ~= "function" then return end
    for button in pool:EnumerateActive() do Look.Try(dress, button) end
end

local function DressRows()
    if not MP.active then return end
    local list = QuestScrollFrame
    if type(list) ~= "table" then return end
    EachActive(list.headerFramePool, DressHeader)
    EachActive(list.titleFramePool, DressTitle)
end

---------------------------------------------------------------------------
-- Made once: the floor, the parchment, the hooks
---------------------------------------------------------------------------

local function MakeOnce()
    if MP.built then return end
    MP.built = true
    local map = QuestMapFrame
    local floor = Look.OwnTexture(map, "questFloor", "BACKGROUND", -3)
    Look.Fill(floor, map)
    local shade = Look.Number(ns.PANE_SHADE) or 0.9
    floor:SetVertexColor(shade, shade, shade)
    Look.TileArt(floor, "marbleBg")
    MP.floor = floor
    local list = Look.Path(map, "QuestsFrame", "ScrollFrame") or QuestScrollFrame
    if type(list) == "table" then
        Look.Fade(list.Background)
        Look.Fade(list.Edge)
        FadeArtOf(list.BorderFrame)
    end
    local details = Details()
    if details then
        local paper = Look.OwnTexture(details, "questParchment", "BACKGROUND", -2)
        Look.Art(paper, "questParchment")
        Look.Crop(paper, 8 / 512, 300 / 512, 4 / 512, 336 / 512)
        Look.Fill(paper, details)
        MP.paper = paper
        Look.HookScript(details, "OnShow", DressDetails, "questMapPane")
        Look.HookScript(details, "OnSizeChanged", QueueRemeasure, "questMapPane")
    end
    Look.HookGlobal("QuestLogQuests_Update", DressRows)
    Look.HookGlobal("QuestMapFrame_ShowQuestDetails", DressDetails)
    local fightEnds = Look.Build("Frame", UIParent, nil, { size = { 1, 1 } })
    Look.Listen(fightEnds, "PLAYER_REGEN_ENABLED")
    fightEnds:SetScript("OnEvent", function() Stretch() end)
end

---------------------------------------------------------------------------
-- On (each pass) and off
---------------------------------------------------------------------------

local function PaneOn()
    MP.active = true
    if type(QuestMapFrame) ~= "table" then
        Look.MissingPiece("QuestMapFrame")
        return
    end
    MakeOnce()
    MP.worn = true
    Look.Shown(MP.floor, true)
    Look.Shown(MP.paper, true)
    Stretch()
    DressRows()
    local details = Details()
    if details and details:IsShown() then DressDetails() end
end

-- Only after the look went on this session: the floor and parchment put
-- away, the details' own size and anchors given back exactly.
local function PaneOff()
    MP.active = false
    if not MP.worn then return end
    MP.worn = false
    Look.Shown(MP.floor, false)
    Look.Shown(MP.paper, false)
    local details = Details()
    if details then
        GiveBack(details)
        GiveBack(details.ScrollFrame)
    end
    ns.needsReload = true
end

ns.RegisterModule("questMapPane", { apply = PaneOn, restore = PaneOff })
