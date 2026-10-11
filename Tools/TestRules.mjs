// Rules read straight from EraUI's source, beside the mock-game tests.
// Escape closes EraUI's windows through the game's own list of windows
// Escape closes (UISpecialFrames, Classic/Widgets.lua ns.CloseOnEscape),
// never by binding the key: a binding changed from addon code has the game
// rebuild your action bars and state inside the addon's code, which then
// breaks on your hidden health (thousands of errors, 2026-10-06).
// Tools/TestEscapeWindows.lua and Tools/TestSpellBookToggle.lua check what
// Escape does. The only key bindings EraUI still changes are four window
// keys (guild, quest log, spellbook, talents), each opening EraUI's own
// window with the key you set; no other file may add one.
// Run with: node --test Tools/TestRules.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const root = new URL('../', import.meta.url);
const files = readFileSync(new URL('EraUI.toc', root), 'utf8').split(/\r?\n/).map(line => line.trim())
  .filter(line => line && !line.startsWith('#') && /\.lua$/i.test(line)).map(line => line.replace(/\\/g, '/'));
// Code without its comments, so notes about these calls don't count.
const bare = text => text.replace(/--\[(=*)\[[\s\S]*?\]\1\]/g, '').replace(/--[^\n]*/g, '');
const code = Object.fromEntries(files.map(name => [name, bare(readFileSync(new URL(name, root), 'utf8'))]));
const count = (text, pattern) => (text.match(pattern) || []).length;
const where = pattern => files.filter(name => pattern.test(code[name]));
const BINDING = /\b(SetOverrideBinding\w*|ClearOverrideBindings?|SetBinding\w*|SaveBindings|LoadBindings)\b/;

test('the files the .toc loads are all read', () => {
  assert.ok(files.length >= 90, `${files.length} files`);
  assert.ok(files.includes('Classic/Widgets.lua') && files.includes('Core/Init.lua'));
});

test('Escape is never bound', () => {
  assert.deepEqual(where(/\b(SetOverrideBinding\w*|SetBinding\w*)\s*\([^)]*ESCAPE/), [], 'files binding Escape');
  assert.deepEqual(where(/EscButton|EscUpdate/), [], 'nothing left of the old Escape button');
  assert.equal(BINDING.test(code['Classic/Widgets.lua']), false, 'Widgets.lua changes no key binding');
});

test('only the four window keys change key bindings', () => {
  assert.deepEqual(where(BINDING).sort(), ['Classic/Guild.lua', 'Classic/QuestLog.lua', 'Classic/SpellBook.lua', 'Classic/Talents.lua'],
    'files changing key bindings');
});

test("EraUI's windows close on Escape through the game's own list", () => {
  const widgets = code['Classic/Widgets.lua'];
  assert.equal(count(widgets, /function ns\.CloseOnEscape\(frame, closer, held\)/g), 1, 'ns.CloseOnEscape');
  assert.equal(count(widgets, /table\.insert\(UISpecialFrames, name\)/g), 1, 'lists a window (or its stand-in) by name');
  const callers = files.filter(name => count(code[name], /\bns\.CloseOnEscape\(/g) > (name === 'Classic/Widgets.lua' ? 1 : 0));
  assert.deepEqual(callers.sort(), ['Classic/OptionsWindow.lua', 'Classic/QuestLog.lua', 'Classic/SpellBook.lua', 'Classic/Status.lua',
    'Classic/Talents.lua', 'Classic/Widgets.lua'], 'the windows that close on Escape (Widgets.lua: the drop down lists)');
});

// Dark Windows (Core/Appearance.lua) darkens every classic dialog box EraUI
// draws: each backdrop with the dialog border goes to ns.DarkBackdrop, and
// each dialog header plate to ns.DarkWindowArt as frame art, later in the
// same file. A new box made without it shows up here. Tools/TestDarkWindows.lua
// checks the colours on the mock game.
const after = (text, from, pattern) => pattern.test(text.slice(from));
const name = who => who.replace(/[.]/g, '\\.');
test('every classic dialog box and header plate is handed to Dark Windows', () => {
  const boxes = new Set(), plates = new Set(), missing = [];
  for (const file of files) {
    const text = code[file];
    const backdrop = /([\w.]+):SetBackdrop\(/g;
    let match;
    while ((match = backdrop.exec(text))) {
      let depth = 1, end = backdrop.lastIndex;
      while (end < text.length && depth > 0) {
        if (text[end] === '(') depth++;
        else if (text[end] === ')') depth--;
        end++;
      }
      if (!/UI-DialogBox-Border|DIALOG_BORDER/.test(text.slice(backdrop.lastIndex, end))) continue;
      boxes.add(file);
      if (!after(text, end, new RegExp(`DarkBackdrop\\(${name(match[1])}[,)]`))) missing.push(`${file}: ${match[1]}'s backdrop`);
    }
    const header = /([\w.]+):SetTexture\((DIALOG_HEADER|"[^"]*UI-DialogBox-Header")\)/g;
    while ((match = header.exec(text))) {
      plates.add(file);
      if (!after(text, header.lastIndex, new RegExp(`DarkWindowArt\\(${name(match[1])}, "frame"\\)`))) missing.push(`${file}: ${match[1]}'s header`);
    }
  }
  assert.deepEqual(missing, [], 'dialog art Dark Windows never sees');
  assert.deepEqual([...boxes].sort(), ['Classic/CharacterSheet.lua', 'Classic/Controls.lua', 'Classic/EquipmentPane.lua',
    'Classic/GameMenu.lua', 'Classic/Guild.lua', 'Classic/OptionsWindow.lua', 'Classic/SettingsPanel.lua', 'Classic/Social.lua',
    'Classic/Status.lua', 'Classic/TradeSkill.lua', 'Classic/Welcome.lua', 'Classic/Widgets.lua', 'Core/Utils.lua', 'Modules/Popups.lua'],
    'the files drawing a classic dialog box');
  assert.deepEqual([...plates].sort(), ['Classic/EquipmentPane.lua', 'Classic/GameMenu.lua', 'Classic/OptionsWindow.lua',
    'Classic/SettingsPanel.lua', 'Classic/Status.lua', 'Classic/Welcome.lua'], 'the files drawing a dialog header plate');
});

// The game's red panel button (UIPanelButtonTemplate) is darkened by Dark
// Windows in the game's own windows (Core/Appearance.lua); each one EraUI
// makes is darkened too, as it is made: handed to ns.DarkNativeButton, or
// given the classic red art (EraUI:SkinClassicRedButton), which Dark Windows
// darkens. A new one made without either shows up here.
test("EraUI's own red panel buttons are handed to Dark Windows", () => {
  const makers = new Set(), missing = [];
  for (const file of files) {
    const text = code[file];
    const make = /([\w.]+)\s*=\s*CreateFrame\(\s*"Button"[^)]*"UIPanelButtonTemplate"\s*\)/g;
    let match;
    while ((match = make.exec(text))) {
      makers.add(file);
      const soon = text.slice(make.lastIndex, make.lastIndex + 400);
      if (!new RegExp(`(DarkNativeButton|SkinClassicRedButton)\\(${name(match[1])}[,)]`).test(soon)) missing.push(`${file}: ${match[1]}`);
    }
  }
  assert.deepEqual(missing, [], 'red panel buttons Dark Windows never sees');
  assert.deepEqual([...makers].sort(), ['Classic/ClassicBar.lua', 'Classic/Controls.lua', 'Classic/Minimap.lua',
    'Classic/OptionsWindow.lua', 'Core/Commands.lua'], 'the files making a red panel button');
});

// The red X close buttons (and the minimise and maximise pair) go dark with
// Dark Windows too: the game's in its windows (Core/Appearance.lua), EraUI's
// as they are made or skinned. Both copies of ns.SkinCloseButton (the later
// one, Classic/Panels.lua, is the one in use) and the minimise/maximise skin
// hand the button to ns.DarkCloseButton; each close button EraUI makes from
// the game's template is skinned (so handed over) or handed over itself. A
// new one made without either shows up here.
test("EraUI's own red X close buttons are handed to Dark Windows", () => {
  for (const file of ['Classic/Controls.lua', 'Classic/Panels.lua']) {
    const skin = code[file].match(/function ns\.SkinCloseButton\(button, keepPosition\)([\s\S]*?)\r?\nend\r?\n/);
    assert.ok(skin, `${file}: ns.SkinCloseButton`);
    assert.match(skin[1], /if ns\.DarkCloseButton then ns\.DarkCloseButton\(button\) end/, `${file}: its close button handed over`);
  }
  const maxMin = code['Classic/Panels.lua'].match(/local function SkinMaxMin\(button\)([\s\S]*?)\r?\nend\r?\n/);
  assert.ok(maxMin, 'Classic/Panels.lua: SkinMaxMin');
  assert.match(maxMin[1], /if ns\.DarkCloseButton then ns\.DarkCloseButton\(b\) end/, 'the minimise and maximise buttons handed over');
  const makers = new Set(), missing = [];
  for (const file of files) {
    const text = code[file];
    const make = /([\w.]+)\s*=\s*CreateFrame\(\s*"Button"[^)]*"UIPanelCloseButton\w*"\s*\)/g;
    let match;
    while ((match = make.exec(text))) {
      makers.add(file);
      const soon = text.slice(make.lastIndex, make.lastIndex + 400);
      if (!new RegExp(`(DarkCloseButton|SkinCloseButton)\\(${name(match[1])}[,)]`).test(soon)) missing.push(`${file}: ${match[1]}`);
    }
  }
  assert.deepEqual(missing, [], 'red X close buttons Dark Windows never sees');
  assert.deepEqual([...makers].sort(), ['Classic/ClassicBar.lua', 'Classic/EquipmentPane.lua', 'Classic/Guild.lua',
    'Classic/OptionsWindow.lua', 'Classic/QuestLog.lua', 'Core/Commands.lua'], 'the files making a red X close button');
});

// EraUI.version (Core/Init.lua) is what What's New, the Update Notice and
// the settings window's "just added" words compare against. It was a string
// left at 1.5.2 through 1.5.3 to 1.5.5; it is now read from the .toc's
// Version as the addon loads, so it can't fall behind again
// (Tools/TestVersion.mjs runs that read).
test("EraUI.version comes from the .toc, never a number typed in Init.lua", () => {
  const toc = readFileSync(new URL('EraUI.toc', root), 'utf8').match(/^## Version:\s*(\S+)/m)?.[1];
  const init = code['Core/Init.lua'];
  assert.ok(toc, 'the .toc has a Version');
  assert.equal(/EraUI\.version\s*=\s*["'\d]/.test(init), false, 'no version typed into Core/Init.lua');
  assert.match(init, /^EraUI\.version\s*=\s*TocVersion\(C_AddOns and C_AddOns\.GetAddOnMetadata\)/m, 'read with C_AddOns.GetAddOnMetadata');
  assert.match(init, /TocVersion\(GetAddOnMetadata\)\s*or\s*"dev"/, 'then the old global, then "dev"');
});

// The player, target and focus frames and the main chat window are Edit Mode
// frames on Forever: their SetPoint, SetScale and ClearAllPoints are Edit
// Mode's overrides, which keep snap records and mark every anchor changed.
// Called from EraUI's code those records carry EraUI's taint, and the game's
// own moves of these protected frames in a fight are then blocked and blamed
// on EraUI ("blocked FocusFrame:SetPointBase() (in combat)", 2026-10-11).
// EraUI moves them only through Edit Mode's plain ...Base methods.
test('Edit Mode frames are only moved through their plain ...Base methods', () => {
  const direct = /\b(?:PlayerFrame|TargetFrame|FocusFrame|ChatFrame1):(?:SetPoint|SetScale|ClearAllPoints)\(/;
  assert.deepEqual(where(direct), [], 'no direct SetPoint, SetScale or ClearAllPoints on them');
  const units = code['Classic/UnitFrames.lua'];
  assert.match(units, /local set = frame\.SetPointBase or frame\.SetPoint/, 'unit frames are placed with SetPointBase');
  assert.match(units, /local base = frame\.SetScaleBase/, 'and rescaled with SetScaleBase');
  assert.match(units, /Place\(frame, point, rel, relPoint, nx \/ scale, ny \/ scale\)/, 'pixel snapping goes through Place');
  assert.match(units, /Rescale\(FocusFrame, scale\)/, 'Match Focus Size goes through Rescale');
  const chat = code['Modules/ChatDragging.lua'];
  assert.match(chat, /ChatFrame1\.SetPointBase or ChatFrame1\.SetPoint/, 'the chat window is placed with SetPointBase');
  assert.match(chat, /ChatFrame1\.ClearAllPointsBase or ChatFrame1\.ClearAllPoints/, 'and cleared with ClearAllPointsBase');
});

// The same report again after 1.6.0 (2026-10-11, at a level-up in a fight):
// Match Focus Size ran the game's own FocusFrame:SetSmallSize from EraUI's
// code, which moves the frame through Edit Mode's overrides, so the snap
// record (FocusFrame.snappedToFrame) and a dozen of the frame's keys carried
// EraUI's taint; Edit Mode re-applying the layout in the fight read the record
// and its FocusFrame:SetPointBase was blocked. So EraUI writes no key on the
// player, target, focus or pet frames or the targets of target, runs none of
// the game's methods that write their records, and keeps its own pieces for
// them in Classic/UnitFrames.lua's weak table (ns.UnitFrameOwn). Its own moves
// of these frames never run in a fight. Tools/TestFocusTaint.lua runs the
// taint on a mock game (and fails on the 1.6.0 code).
test("EraUI writes no key on the unit frames and runs none of the game's methods that write them", () => {
  const FRAMES = '(?:PlayerFrame|TargetFrame|FocusFrame|PetFrame|TargetFrameToT|FocusFrameToT)';
  const write = new RegExp(`\\b${FRAMES}(?:\\.\\w+|\\[[^\\]]+\\])+\\s*=(?!=)`);
  assert.deepEqual(where(write), [], 'files writing a key on them');
  const writers = /[.:](?:SetSmallSize|SetSnappedToFrame|ClearFrameSnap|BreakFrameSnap|BreakSnappedFrames|AddSnappedFrame|RemoveSnappedFrame|OnEditModeSystemAnchorChanged|SetScaleOverride|SetPointOverride|ClearAllPointsOverride|ApplySystemAnchor|UpdateSystemSettingUseLargerFrame)\s*\(/;
  assert.deepEqual(where(writers), [], "files running the game's record-writing methods");
  const units = code['Classic/UnitFrames.lua'];
  // Only EraUI's own frames (the holders and hosts it makes) carry an fcui
  // table; the game's frames' pieces go in the weak table.
  const fcuiOwners = new Set([...units.matchAll(/([\w.]+)\.fcui\b/g)].map(m => m[1]));
  assert.deepEqual([...fcuiOwners].sort(), ['holder'], 'only the text holder (an EraUI frame) is read for its fcui');
  assert.equal(/\.fcui\s*=/.test(units), false, 'no fcui table written');
  const makers = [...units.matchAll(/ns\.(?:OwnTexture|OwnFontString|CreateBar)\((\w+)/g)].map(m => m[1]);
  assert.deepEqual([...new Set(makers)].sort(), ['barHost', 'holder', 'host'], "ns.OwnTexture and ns.CreateBar only on EraUI's own frames");
  const kept = [...units.matchAll(/(\w+)\.(?:lastClassification|haveElite)\b/g)].map(m => m[1]);
  assert.deepEqual([...new Set(kept)], ['mine'], 'the classification and elite flag kept in the weak table');
  assert.match(units, /local own = setmetatable\(\{\}, \{ __mode = "k" \}\)/, 'the weak table');
  assert.match(units, /function ns\.UnitFrameOwn\(frame, key\) return Mine\(frame, key\) end/, 'read through ns.UnitFrameOwn');
  assert.equal(/parent\.haveElite/.test(code['Classic/CastBars.lua']), false, 'the cast bars read the elite flag from the weak table');
  assert.match(units, /local function Place\(frame, \.\.\.\)\s+if InCombatLockdown\(\) then return end/, 'Place never runs in a fight');
  assert.match(units, /local function Rescale\(frame, newScale\)\s+if InCombatLockdown\(\) then return end/, 'nor Rescale');
});
