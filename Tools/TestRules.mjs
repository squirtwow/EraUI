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
    'Classic/Status.lua', 'Classic/TradeSkill.lua', 'Classic/Welcome.lua', 'Classic/Widgets.lua', 'Core/Utils.lua',
    'Modules/MinimapTools.lua', 'Modules/Popups.lua'],
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

// Rounded Cast Bars (Appearance > Style > Frame Style, 2026-10-11): the
// shell is EraUI's own frames and textures, its state in weak tables. The
// cast bars write a key only on EraUI's own tables, never set a script on
// the game's bars (post-hooks only), never move the bars themselves (the
// player's is an Edit Mode frame), and don't use the game's tooltip; the
// class accents write only on EraUI's own outline. Tools/TestRoundedCastBars.lua
// runs it all on sealed mock bars.
test('Rounded Cast Bars writes only on EraUI\'s own tables and uses no GameTooltip', () => {
  const cast = code['Classic/CastBars.lua'];
  assert.equal(/GameTooltip/.test(cast), false, 'no GameTooltip in the cast bars');
  const owners = [...cast.matchAll(/^\s*([A-Za-z_][\w.]*)\.[A-Za-z_]\w*\s*(?:,\s*[\w.]+\s*)*=(?!=)/gm)].map(m => m[1]);
  assert.deepEqual([...new Set(owners)].sort(), ['ns', 'state', 'was'], 'keys written only on EraUI\'s own tables');
  assert.equal(/\b(?:bar|b|parent|shield|own|text)\s*:\s*SetScript\s*\(/.test(cast), false, 'no script set on the game\'s bars');
  const shell = cast.slice(cast.indexOf('function ns.RoundedCastLine()'), cast.indexOf('local Position'));
  assert.ok(shell.length > 1000, 'the shell\'s code found');
  assert.equal(/\bbar\s*:\s*(?:ClearAllPoints|SetPoint|SetAllPoints|SetScale|SetParent)\s*\(/.test(shell), false, 'the shell never moves a bar itself');
  assert.equal(/hooksecurefunc|HookScript/.test(shell), false, 'and adds no hook of its own');
  // Under the target's aura row the game keeps layout scripts from addons
  // (UntrustedLayoutScriptExecution), so the shell is pinned, never resized.
  assert.equal(/OnSizeChanged|OnRectChanged/.test(cast), false, 'no layout script on the cast bars');
  assert.match(cast, /local rounds = setmetatable\(\{\}, \{ __mode = "k" \}\)/, 'each bar\'s shell kept in a weak table');
  const accents = code['Modules/ClassAccents.lua'];
  const accentOwners = [...accents.matchAll(/\b([A-Za-z_]\w*)\.[A-Za-z_]\w*\s*=(?!=)/g)].map(m => m[1]);
  assert.deepEqual([...new Set(accentOwners)].sort(), ['outline', 'state'], 'the class accents write only on their own outline and state');
});

// Cast Bar Colour (Casting, 2026-10-11): the kind of cast comes only from
// the fill's atlas name (the bar's type is a secret for other units), and
// the live switch recolours only the player's and pet's bars, with the one
// cosmetic setter. Tools/TestCastBarColour.lua runs it on sealed mock bars.
test("Cast Bar Colour reads the atlas name only and recolours only your own and your pet's bar", () => {
  const cast = code['Classic/CastBars.lua'];
  assert.equal(/\bbarType\b|notInterruptible/.test(cast), false, "the bar's type is never read");
  assert.match(cast, /local function OwnBar\(bar\)\s+return bar ~= nil and \(bar == PlayerCastingBarFrame or bar == PetCastingBarFrame\)/,
    "your own bars are the player's and the pet's");
  const refresh = cast.slice(cast.indexOf('function ns.RefreshCastColours()'), cast.indexOf('function ns.RefreshRoundedCasts()'));
  assert.ok(refresh.length > 50, "the live switch's code found");
  assert.match(refresh, /if OwnBar\(bar\) then bar:SetStatusBarColor\(FillRGB\(bar, kinds\[bar\]\)\) end/, 'only your own bars, their colour only');
  assert.equal(count(refresh, /\bbar\s*:\s*\w+\s*\(/g), 1, 'one call on a bar, the colour');
  assert.match(cast, /local kinds = setmetatable\(\{\}, \{ __mode = "k" \}\)/, "each bar's last kind kept in a weak table");
});

// Dark Bag Buttons (Appearance > Dark Mode, 2026-10-14): only colours, on the
// game's own bag icons and open-bag lines, after the game's own updates
// (post-hooks); EraUI's state in weak tables beside the buttons, never a key
// on them. Tools/TestDarkBagButtons.lua runs it on a mock of the bag bar.
test("Dark Bag Buttons only colours the game's textures and writes no key on the bag buttons", () => {
  const skins = code['Classic/BarSkins.lua'];
  const block = skins.slice(skins.indexOf('local BAG_BAR ='), skins.indexOf('local function ApplyBagArt'));
  assert.ok(block.length > 1000, "the block's code found");
  const calls = [...block.matchAll(/\b(?:texture|button)\s*:\s*(\w+)\s*\(/g)].map(m => m[1]);
  assert.deepEqual([...new Set(calls)].sort(), ['GetVertexColor', 'SetDesaturated', 'SetVertexColor'], "only colour calls on the game's textures");
  assert.equal(/\b(?:button|texture|icon)\s*(?:\.\w+|\[[^\]]+\])\s*=(?!=)/.test(block), false, 'no key written on a button or its textures');
  assert.equal(/GameTooltip|SetScript|HookScript|SetOverrideBinding/.test(block), false, 'no tooltip, script or binding');
  assert.equal(count(block, /hooksecurefunc\(/g), 2, "two post-hooks: each button's texture update, and the game's two icon calls");
  assert.match(block, /local bagBar = setmetatable\(\{\}, \{ __mode = "k" \}\)/, 'the buttons kept in a weak table');
  assert.match(block, /local bagPaint = setmetatable\(\{\}, \{ __mode = "k" \}\)/, "each texture's colours kept in a weak table");
  const refresh = skins.slice(skins.indexOf('function ns.RefreshDarkBagButtons()'), skins.indexOf('local keyrings'));
  assert.match(refresh, /if DarkBags\(\) then WatchBags\(\) end/, 'nothing hooked until the tick is first on');
});

// Upgrade Spell Ranks (Action Bars, 2026-10-14): the only file that puts
// anything on your action bars. It changes a slot through the game's own
// pick up, place and clear calls, only for a spell, never in a fight, and
// touches no frame, tooltip, hook or binding. Tools/TestSpellRanks.lua runs
// it on a mock of the spellbook and the bars.
test('Upgrade Spell Ranks alone places actions, spells only, never in a fight', () => {
  assert.deepEqual(where(/\b(PlaceAction|PickupAction|PutActionInSlot)\b/), ['Modules/SpellRanks.lua'], 'files placing actions on the bars');
  const ranks = code['Modules/SpellRanks.lua'];
  assert.match(ranks, /function Module:Apply\(\)[\s\S]*?if InCombatLockdown\(\) then return end[\s\S]*?for _, slot in ipairs\(Slots\(\)\) do/,
    'a fight stops it before any slot is touched');
  assert.match(ranks, /local new = kind == "spell" and pending\[id\]/, 'only a spell in a slot is ever replaced');
  assert.equal(/GameTooltip|HookScript|hooksecurefunc|SetOverrideBinding|SetBinding/.test(ranks), false, 'no tooltip, hook or binding');
  assert.equal(count(ranks, /:SetScript\(/g), 1, "one script, on its own event frame");
  // The game's own buttons are only read, to spot a move that tainted them.
  assert.match(ranks, /pcall\(issecurevariable, button, "action"\)/, "the game's buttons' slot key is checked after a move");
  assert.equal(/\b(button|events)\.\w+\s*=[^=]|\bActionBarButtonEventsFrame\.\w+\s*=[^=]/.test(ranks), false, "no key written on the game's buttons or their events frame");
});

// Stat Tracker (Character & Spells, 2026-10-14): EraUI's own panel only. It
// hooks nothing of the game's (its two hooks are on EraUI's own /era
// window), uses no tooltip or binding, writes keys only on its own tables,
// reads every stat through pcall (the game's functions are never called
// straight) and registers every event through pcall, so an event Forever
// lacks can't stop it. Tools/TestStatTracker.lua runs it on a mock of the game.
test("Stat Tracker hooks nothing of the game's, reads through pcall and writes keys only on its own tables", () => {
  const stats = code['Modules/StatTracker.lua'];
  assert.equal(/GameTooltip|hooksecurefunc|SetOverrideBinding|SetBinding/.test(stats), false, 'no tooltip, hook or binding');
  const owners = [...stats.matchAll(/^\s*([A-Za-z_][\w.]*)\.[A-Za-z_]\w*\s*(?:,\s*[\w.]+\s*)*=(?!=)/gm)].map(m => m[1]);
  assert.deepEqual([...new Set(owners)].sort(), ['Module', 'gain'], 'keys written only on its own module and gain tables');
  assert.equal(count(stats, /:HookScript\(/g), 2, 'two hooks');
  assert.match(stats, /local settings = EraUI\.settingsFrame[\s\S]*?settings:HookScript\("OnShow"[\s\S]*?settings:HookScript\("OnHide"/,
    "both on EraUI's own /era window");
  assert.equal(/\b(UnitStat|UnitAttackPower|UnitRangedAttackPower|UnitArmor|GetUnitSpeed|GetInventoryItemDurability|GetCritChance|GetRangedCritChance|GetSpellCritChance|GetSpellBonusDamage|GetCombatRatingBonus|GetHitModifier|GetRangedHitModifier|GetSpellHitModifier|GetDodgeChance|GetParryChance|GetBlockChance)\s*\(/.test(stats),
    false, "no stat function called straight: each through pcall");
  assert.equal(/:Register(Unit)?Event\(/.test(stats), false, 'every event registered through pcall');
  assert.match(stats, /local function Number\(v\) return Public\(v\) and type\(v\) == "number" end/, 'a number is used only when it is no secret');
  // The mock's secrets can't catch `secret ~= nil` (Lua never asks a table's
  // metatable about nil), so the order is checked here.
  assert.match(stats, /local current, maximum = Call\(GetInventoryItemDurability, slot\)\s*if not \(Public\(current\) and Public\(maximum\)\) then return false end\s*if current ~= nil or maximum ~= nil then/,
    "durability checked for secrets before it's compared");
  // 2026-10-14, after the first look in game: whether you swim and your class
  // come through pcall and are checked for secrets before they're compared
  // (the mock can't see `secret == true`); the panel sits on its own: one
  // layer (HIGH), never pinned to /era, never raised for it.
  assert.equal(/\b(IsSwimming|UnitClass)\s*\(/.test(stats), false, 'IsSwimming and UnitClass through pcall too');
  assert.match(stats, /local swimming = Call\(IsSwimming\)\s*if not Public\(swimming\) then return false end\s*if swimming == true then/,
    'swimming checked for a secret before it is compared');
  assert.match(stats, /local _, class = Call\(UnitClass, "player"\)\s*if Public\(class\) and type\(class\) == "string" then/,
    'the class checked for a secret before it is compared');
  assert.deepEqual([...stats.matchAll(/:SetFrameStrata\(([^)]*)\)/g)].map(m => m[1]), ['"HIGH"'], 'one layer, HIGH, set once');
  assert.equal(/SetFrameLevel|SetPoint\([^)]*settingsFrame/.test(stats), false, 'never raised, never pinned to /era');
});

// Thick Frames (Appearance > Style > Frame Style, 2026-10-14): EraUI's own
// textures, each frame's look kept in a weak table beside it. On the game's
// pieces only cosmetic setters: no hook or script of its own, no key written
// on the game's frames or pieces, no method run on the player, target, focus
// or pet frame (Edit Mode frames) or on any unit frame handed to it, no
// tooltip or binding. Classic/UnitFrames.lua's keepers follow the look a
// frame already wears. Tools/TestThickFrames.lua runs it on a mock game.
test("Thick Frames writes only on EraUI's own tables and only dresses the game's pieces", () => {
  const thick = code['Classic/ThickFrames.lua'];
  assert.ok(thick && thick.length > 2000, 'Thick Frames is in the .toc');
  assert.ok(files.indexOf('Classic/ThickFrames.lua') < files.indexOf('Classic/UnitFrames.lua'), 'loaded before the unit frames');
  assert.equal(/GameTooltip|hooksecurefunc|HookScript|SetScript|SetOverrideBinding|SetBinding/.test(thick), false, 'no tooltip, hook, script or binding');
  const roots = [...thick.matchAll(/^\s*([A-Za-z_]\w*)(?:\.[A-Za-z_]\w*|\[[^\]]+\])+\s*(?:,\s*[\w.]+\s*)*=(?!=)/gm)].map(m => m[1]);
  // cap and masks: a texture's two end masks and their state, EraUI's own
  // tables in the frame's s.caps (rounded bar ends).
  assert.deepEqual([...new Set(roots)].sort(), ['GEOMETRY', 'T', 'cap', 'g', 'masks', 'ns', 's', 'worn'], "keys written only on EraUI's own tables");
  // Rounded ends: a mask goes on or off a texture only through pcall (a
  // fourth mask throws on Forever), never more than the two end caps, CLAMP.
  assert.equal(/:(?:Add|Remove)MaskTexture\(/.test(thick), false, 'masks added and removed only through pcall');
  assert.equal([...thick.matchAll(/:CreateMaskTexture\(/g)].length, 1, 'masks made in one place');
  assert.match(thick, /for i, side in ipairs\(\{ "Left", "Right" \}\) do/, 'two end masks per texture, no more');
  assert.match(thick, /SetTexture\(CAP_FILE:format\(side\), "CLAMP", "CLAMP"\) == false/, 'the art CLAMP-wrapped, and checked that it loaded');
  assert.equal(/\b(?:frame|tot|label|text|region|reaction|threat|group|container|main|health|power|bar)\s*(?:\.\w+|\[[^\]]+\])\s*=(?!=)/.test(thick), false,
    "no key written on the game's pieces");
  assert.equal(/\b(?:PlayerFrame|TargetFrame|FocusFrame|PetFrame)\s*:/.test(thick), false, 'no method run on the Edit Mode frames by name');
  assert.equal(/\b(?:frame|tot)\s*:\s*\w+\s*\(/.test(thick), false, 'no method run on a unit frame handed to it (a canvas only makes textures)');
  assert.match(thick, /local worn = setmetatable\(\{\}, \{ __mode = "k" \}\)/, "each frame's look kept in a weak table");
  const units = code['Classic/UnitFrames.lua'];
  assert.match(units, /local thick = ThickWorn\(PlayerFrame\)/, "the player's keeper follows the look it wears");
  assert.match(units, /local thick = ThickWorn\(frame\)\s+local wantY = thick and thick\.AURA_Y or AURA_Y/, 'so does the aura row');
});

// Raid-style Party Outline (Appearance > Style > Frame Style, 2026-10-14):
// EraUI's own frame on the game's party border, pinned to it, and the flat
// fill on the game's party bars; nothing else. One post-hook (the game's
// party frame being made, set only while the look waits for it), no script,
// tooltip or binding, nothing of Edit Mode's touched, no key written on the
// game's frames (its state in weak tables), on the game's pieces only the
// fill, the border fill's alpha and reads, and nothing done in a fight.
// Tools/TestPartyOutline.lua runs it on a mock of the game's party frame.
test("Raid-style Party Outline writes only on EraUI's own tables and never acts in a fight", () => {
  const outline = code['Classic/PartyOutline.lua'];
  assert.ok(outline && outline.length > 2000, 'the Raid-style Party Outline is in the .toc');
  assert.ok(files.indexOf('Classic/PartyOutline.lua') > files.indexOf('Classic/Skin.lua'), 'loaded after the skin helpers it uses');
  assert.equal(/GameTooltip|HookScript|SetScript|SetOverrideBinding|SetBinding|EditMode/.test(outline), false, 'no tooltip, script, binding or Edit Mode');
  assert.equal(count(outline, /hooksecurefunc\(/g), 1, 'one post-hook');
  assert.match(outline, /local function Watch\(\)[\s\S]*?hooksecurefunc\("CompactPartyFrame_Generate"/, "on the game's party frame being made, from Watch");
  const roots = [...outline.matchAll(/^\s*([A-Za-z_]\w*)(?:\.[A-Za-z_]\w*|\[[^\]]+\])+\s*(?:,\s*[\w.]+\s*)*=(?!=)/gm)].map(m => m[1]);
  assert.deepEqual([...new Set(roots)].sort(), ['faded', 'flat', 'o', 'outline'], "keys written only on EraUI's own tables");
  assert.equal(/\b(?:group|border|bar|b|tex|member|members|region|unitFrame|list)\s*(?:\.\w+|\[[^\]]+\])\s*=(?!=)/.test(outline), false,
    "no key written on the game's pieces");
  const calls = [...outline.matchAll(/\b(?:bar|b|tex|member|members|region|group|border|unitFrame|list)\s*:\s*(\w+)\s*\(/g)].map(m => m[1]);
  assert.deepEqual([...new Set(calls)].sort(), ['GetAlpha', 'GetAtlas', 'GetFrameLevel', 'GetStatusBarTexture', 'GetTexture', 'SetAlpha', 'SetStatusBarTexture'],
    "on the game's pieces only the fill, the border fill's alpha, and reads");
  assert.match(outline, /local flat = setmetatable\(\{\}, \{ __mode = "k" \}\)/, "each bar's own art kept in a weak table");
  assert.match(outline, /local faded = setmetatable\(\{\}, \{ __mode = "k" \}\)/, "the border fill's alpha kept in a weak table");
  assert.match(outline, /function ns\.RefreshPartyOutline\(\)[\s\S]*?if InCombatLockdown\(\) then[\s\S]*?return false\s*end\s*local group = Group\(\)/,
    'a fight stops it before anything is touched');
  assert.match(code['Core/Appearance.lua'], /if ns\.RefreshPartyOutlineLine then ns\.RefreshPartyOutlineLine\(\) end/, 'the Darkness slider tones its line');
});
