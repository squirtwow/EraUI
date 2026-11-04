// Build 70170 (Forever 1.60.1) event registrations, checked in the source:
// PLAYER_LEVEL_UP can come before the new level is in, so Talents also
// refresh on PLAYER_LEVEL_CHANGED; the unit frames follow the new
// PLAYER_PVP_FLAG_CHANGED like a faction change. Both registered through
// pcall, so an older game without the event is fine. (The Training Guide's
// is run for real in Tools/TestTrainingGuide.lua.)
// Run: node Tools/TestBuild70170.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=dirname(dirname(fileURLToPath(import.meta.url)));
const read=path=>readFileSync(join(root,path),'utf8');
// Lua source without its comments.
const code=text=>text.replace(/--\[(=*)\[[\s\S]*?\]\1\]/g,'').replace(/--[^\n]*/g,'');
// The talent window (Look/TalentModule.lua, clean-room 2026-10-21): its one
// list of refresh events, each registered through Look.Listen (a pcall).
// Tools/TestTalents.lua fires PLAYER_LEVEL_CHANGED on the mock game and sees
// the new point straight away.
test('Talents refresh on the level change', () => {
 const src=code(read('Look/TalentModule.lua'));
 const group=src.match(/local REFRESH_EVENTS = Look\.Words\(\[\[([\s\S]*?)\]\]\)/);
 assert.ok(group,'the list of refresh events');
 const events=new Set(group[1].split(/\s+/).filter(Boolean));
 assert.ok(events.has('PLAYER_LEVEL_UP'),'still the level-up');
 assert.ok(events.has('PLAYER_LEVEL_CHANGED'),'and the level change');
 assert.match(src,/for _, event in ipairs\(REFRESH_EVENTS\) do\s+refreshing\[event\] = true\s+Look\.Listen\(listener, event\)/,
  'every one registered through Look.Listen');
});

// The unit frames (Look/UnitModule.lua, clean-room 2026-10-21): every event of
// a group gets the group's handling; each one is registered through
// Look.Listen (a pcall), from the one table of groups.
test('unit frames follow the PvP flag', () => {
 const src=code(read('Look/UnitModule.lua'));
 const group=src.match(/local CHANGE_EVENTS = Look\.Words\(\[\[([\s\S]*?)\]\]\)/);
 assert.ok(group,'the group of change events');
 const events=new Set(group[1].split(/\s+/).filter(Boolean));
 assert.ok(events.has('PLAYER_PVP_FLAG_CHANGED'),'the PvP flag in it');
 assert.ok(events.has('UNIT_FACTION'),'next to the faction change, handled the same');
 assert.match(src,/\{ CHANGE_EVENTS, "change" \}/,'the group handled as a change');
 assert.match(src,/for event in pairs\(kindOf\) do Look\.Listen\(listener, event\) end/,'every event registered through Look.Listen');
 assert.match(read('Look/Base.lua'),/function Look\.Listen\(listener, event, unit\)[\s\S]*?return \(pcall\(listener\.RegisterEvent, listener, event\)\)/,
  'which registers through pcall');
});

test('the Training Guide registers the level change safely', () => {
 const src=code(read('Modules/TrainingGuide.lua'));
 assert.ok(src.includes('pcall(events.RegisterEvent,events,"PLAYER_LEVEL_CHANGED")'),'through pcall');
});
