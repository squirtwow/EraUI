-- The character window's registry entry ("characterSheet", from /era's
-- Character Window, a reload setting): one layout in its order, the
-- post-hooks that lay it out again after the game's own passes, and turning
-- it on and off. Also the public names other code may use.
--
-- A pass runs the same apply again (logging in, entering the world, scale
-- changes, Edit Mode, any toggle), so the apply is cheap and safe to repeat.
-- Passes never run in a fight. The game's own passes can lay the window out
-- in a fight too; then anything the game guards is left for the layout at
-- the fight's end.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local C = Look.Char

-- The Classic settings this area reads, with their defaults (only where the
-- engine has none of its own).
do
    local engine = type(ns.DB_DEFAULTS) == "table" and ns.DB_DEFAULTS or {}
    for key, value in pairs({ characterSheet = true, statPanes = false, statPaneLeft = "section2", statPaneRight = "section3" }) do
        if engine[key] == nil then engine[key] = value end
    end
end

---------------------------------------------------------------------------
-- The layout
---------------------------------------------------------------------------

local laying = false

local function LayEverything()
    local sheet, paper = CharacterFrame, PaperDollFrame
    if not (sheet and paper) then return end
    local Try = Look.Try
    Try(C.LayWindow, sheet, paper)
    Try(C.LayPortrait, sheet)
    Try(C.LayTitle, sheet)
    Try(C.LayClose, sheet)
    Try(C.LaySlots, paper)
    Try(C.LayModel, paper)
    Try(C.LayTabs, sheet)
    Try(C.RefreshStats)
    if C.StatPanesHost then Try(C.StatPanesHost, paper) end
    if C.UpdateStatPanes then Try(C.UpdateStatPanes) end
    if sheet:IsShown() then C.Signal() end
end

-- Never inside itself (resizing the window fires the paper doll's
-- OnSizeChanged, which asks for a layout).
function C.Layout()
    if laying or not (C.active and C.built) then return end
    laying = true
    Look.Try(LayEverything)
    laying = false
end

local function LayNextFrame()
    if C_Timer and C_Timer.After then C_Timer.After(0, C.Layout) else C.Layout() end
end

---------------------------------------------------------------------------
-- The hooks (installed once, at the first apply)
---------------------------------------------------------------------------

local function IfActive(fn)
    return function() if C.active then Look.Try(fn) end end
end

local function CameraSoon(delay)
    return function()
        if C.active and C_Timer and C_Timer.After then C_Timer.After(delay, C.FitCamera) end
    end
end

-- The side pane hidden again after the game's own passes (they run inside
-- the window's OnShow: a problem goes to the error handler, not into them).
local function SidePaneAgain()
    Look.Try(C.HideSidePane)
end

local function InstallHooks(sheet, paper)
    Look.HookOrMiss(sheet, "CharacterFrame", "UpdateSize", C.Layout)
    Look.HookOrMiss(sheet, "CharacterFrame", "ShowSubFrame", function() if C.active then LayNextFrame() end end)
    Look.HookOrMiss(sheet, "CharacterFrame", "Expand", SidePaneAgain)
    Look.HookOrMiss(sheet, "CharacterFrame", "RefreshRightPane", SidePaneAgain)
    if not Look.HookGlobal("PaperDollFrame_UpdateSidebarTabs", SidePaneAgain) then
        Look.MissingPiece("PaperDollFrame_UpdateSidebarTabs")
    end
    Look.HookScript(sheet, "OnShow", IfActive(C.Layout))
    Look.HookScript(paper, "OnSizeChanged", IfActive(C.Layout))
    Look.HookScript(paper, "OnShow", function()
        if not C.active then return end
        Look.Try(C.RefreshStats)
        if C_Timer and C_Timer.After then C_Timer.After(0, function() if C.active then C.SyncEquipment() end end) end
    end)
    if PVPRankFrame then Look.HookScript(PVPRankFrame, "OnShow", IfActive(C.SkinPvP)) end
    local model = C.Model()
    if model then
        Look.HookOrMiss(model, "CharacterModelScene", "TransitionToModelSceneID", CameraSoon(0))
        Look.HookScript(model, "OnShow", CameraSoon(0.1))
    end
    local fightOver = Look.Build("Frame", nil, nil, { size = { 1, 1 } })
    Look.Listen(fightOver, "PLAYER_REGEN_ENABLED")
    fightOver:SetScript("OnEvent", function()
        if C.active and sheet:IsShown() then C.Layout() end
    end)
end

---------------------------------------------------------------------------
-- On (each pass, never in a fight) and off
---------------------------------------------------------------------------

local function Build(sheet, paper)
    C.built = true
    Look.Try(C.MakeArt, sheet, paper)
    Look.Try(C.MakeStats, paper)
    Look.Try(C.MakeRotate, paper)
    C.ListenForStats()
    C.WatchSidePane(sheet)
    InstallHooks(sheet, paper)
end

local copies = Look.Weak() -- frame given the sheet's art by EraUIClassic_SkinCharacterCopy: its ring

local function ShowCopies(on)
    for frame, ring in pairs(copies) do
        for i = 1, 8 do Look.Shown(Look.OwnPiece(frame, "copy" .. i), on) end
        Look.Shown(ring, on)
    end
end

local function SheetOn()
    local sheet, paper = CharacterFrame, PaperDollFrame
    if not (sheet and paper) then
        Look.MissingPiece("CharacterFrame")
        return
    end
    C.active = true
    EraUIClassic_CharacterSheetActive = true
    if not C.built then Build(sheet, paper) end
    Look.Try(C.HideSidePane)
    Look.Try(C.ApplyEquipment, paper)
    C.WriteCollapsed()
    C.SkinAllLists()
    C.ShowArt(true)
    ShowCopies(true)
    if C.rotate then for _, button in ipairs(C.rotate) do button:Show() end end
    C.ShowResistances(true)
    C.SetClassicStatsShown(Look.Saved().statPanes ~= true)
    C.Layout()
end

-- Character Window is a reload setting: turning it off puts back only
-- what's cheap to put back and leaves the rest for the reload. It runs on
-- every pass while the window is off, so it's safe to repeat.
local function SheetOff()
    C.active = false
    EraUIClassic_CharacterSheetActive = false
    if not C.built then return end
    if C.levelLine then C.levelLine:Hide() end
    C.HideTabs()
    C.ShowArt(false)
    ShowCopies(false)
    C.SetClassicStatsShown(false)
    C.ShowResistances(false)
    if C.rotate then for _, button in ipairs(C.rotate) do button:Hide() end end
    C.StopTurning()
    C.ShowRepLabels(false)
    C.HideRepBox()
    Look.Try(C.RestoreCurrencyBox)
    Look.Try(C.RestoreEquipment)
    Look.Alpha(PaperDollSidebarTabs, 1)
    local model = C.Model()
    Look.Alpha(model and model.GearEnchantAnimation, 1)
    ns.needsReload = true
end

ns.RegisterModule("characterSheet", { apply = SheetOn, restore = SheetOff })

---------------------------------------------------------------------------
-- Public names (nothing in EraUI needs them today; cheap to keep)
---------------------------------------------------------------------------

EraUIClassic_CharacterSheetActive = false

-- Width, height, the art's right edge (plus the open equipment dialog) and
-- its left edge.
function EraUIClassic_CharacterSheetSize()
    return C.SHEET_W, C.SHEET_H, C.ART_RIGHT + C.EquipmentExtent(), C.ART_LEFT
end

-- The sheet's 1.x art on any frame (once), shown while the sheet is on.
function EraUIClassic_SkinCharacterCopy(frame)
    if not frame then return false end
    if not copies[frame] then
        local index = 0
        for _, set in ipairs({ { "general", -2 }, { "tab", -1 } }) do
            for _, piece in ipairs(C.SHEET_PIECES[set[1]]) do
                index = index + 1
                local texture = Look.OwnTexture(frame, "copy" .. index, "BACKGROUND", set[2])
                Look.Art(texture, piece[1])
                texture:SetSize(piece[2], 256)
                Look.Pin(texture, "TOPLEFT", frame, "TOPLEFT", piece[3], piece[4])
            end
        end
        local holder = frame.PortraitContainer or frame
        copies[frame] = C.MakeRing(frame, "charTabTopLeft", (Look.Number(holder:GetFrameLevel()) or 1) + 1)
    end
    ShowCopies(C.active)
    return C.active
end
