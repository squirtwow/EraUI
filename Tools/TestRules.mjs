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
