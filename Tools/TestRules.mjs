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
