// What Tools/TestPortraitDebuffs.lua can't trap at run time: a truth test, or an
// == against a number or nil, on a value that may be secret in M:UpdatePlayer.
// The game errors on them, Lua doesn't.
// Run from the addon folder: node --test Tools/TestPortraitDebuffsSource.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const text=readFileSync(new URL('../Modules/PortraitDebuffs.lua',import.meta.url),'utf8');
const body=(text.match(/function M:UpdatePlayer\(\)\r?\n[\s\S]*?\r?\nend\r?\n/)||[])[0];

test('UpdatePlayer only looks at the icon once it knows the icon is plain',()=>{
 assert.ok(body,'UpdatePlayer found');
 assert.ok(body.includes('if Public(icon) and not icon then'),'the one look, guarded');
 const rest=body.replace('if Public(icon) and not icon then','');
 assert.deepEqual(rest.match(/\bnot icon\b|\bif icon\b|\bicon and\b|\bicon or\b|\bicon (?:==|~=|<|>)|(?:==|~=|<|>) icon\b/g),null);
});

test('UpdatePlayer does sums on the times only behind Number',()=>{
 const guard=body.indexOf('if Number(start) and Number(duration) and duration > 0 then');
 assert.ok(guard>0,'both checked first');
 assert.ok(body.indexOf('start + duration')>guard,'the sum comes after');
 assert.ok(!/\bif (?:start|duration)\b|\bnot (?:start|duration)\b/.test(body),'no truth test on them');
});
