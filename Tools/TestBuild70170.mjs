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
// The quoted names in the ipairs({...}) list that is followed by `follow`.
function list(text,follow){
 const at=text.indexOf(follow);
 assert.ok(at>=0,'registration loop found: '+follow);
 const open=text.lastIndexOf('ipairs({',at);
 assert.ok(open>=0,'event list found before '+follow);
 const body=text.slice(open,text.indexOf('})',open));
 return new Set([...body.matchAll(/"([A-Z_]+)"/g)].map(m=>m[1]));
}

test('Talents refresh on the level change', () => {
 const src=code(read('Classic/Talents.lua'));
 const events=list(src,'pcall(events.RegisterEvent, events, event)');
 assert.ok(events.has('PLAYER_LEVEL_UP'),'still the level-up');
 assert.ok(events.has('PLAYER_LEVEL_CHANGED'),'and the level change');
});

test('unit frames follow the PvP flag', () => {
 const src=code(read('Classic/UnitFrames.lua'));
 const events=list(src,'pcall(driver.RegisterEvent, driver, event)');
 assert.ok(events.has('PLAYER_PVP_FLAG_CHANGED'),'registered on the driver');
 assert.ok(events.has('UNIT_FACTION'),'next to the faction change');
 const branch=src.match(/or event == "UNIT_FACTION"[^\n]*/);
 assert.ok(branch,'the faction branch');
 assert.ok(branch[0].includes('event == "PLAYER_PVP_FLAG_CHANGED"'),'handled like a faction change');
});

test('the Training Guide registers the level change safely', () => {
 const src=code(read('Modules/TrainingGuide.lua'));
 assert.ok(src.includes('pcall(events.RegisterEvent,events,"PLAYER_LEVEL_CHANGED")'),'through pcall');
});
