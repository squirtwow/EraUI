// EraUI.version is read from the .toc's own "## Version" as Core/Init.lua
// loads (C_AddOns.GetAddOnMetadata, then the old global GetAddOnMetadata),
// so What's New, the Update Notice and the settings window's "just added"
// words always compare against the version players run. It was once a
// string typed into Init.lua and stayed at 1.5.2 through 1.5.5. A copy
// without a real number there (the packager's placeholder, or nothing) runs
// as "dev". This loads the real Init.lua in fengari (Lua 5.3; the game's
// 5.1 limits are Tools/TestLuaLimits.mjs) with the game's metadata calls
// answered from the real .toc.
// Run with: node --test Tools/TestVersion.mjs (FENGARI to point at fengari)
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { lua, lauxlib, lualib, to_luastring } = require(process.env.FENGARI || join(tmpdir(), 'opencode', 'lua-check', 'node_modules', 'fengari'));
const root = new URL('../', import.meta.url);
const toc = readFileSync(new URL('EraUI.toc', root), 'utf8').match(/^## Version:\s*(\S+)/m)?.[1];
const init = readFileSync(new URL('Core/Init.lua', root), 'utf8');

// Runs Lua with the real Init.lua source as INIT and the .toc's Version as
// TOC; Load(api, global) loads Init.lua once with those two metadata
// readers and gives back EraUI.version.
const PRELUDE = `
local asked = {}
function Load(api, global)
  CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
  C_CVar = nil
  C_AddOns = api and {GetAddOnMetadata = function(...) asked[#asked + 1] = table.concat({...}, ",") return api(...) end} or nil
  GetAddOnMetadata = global
  local E = {}
  assert(load(INIT, "@Core/Init.lua"))("EraUI", E)
  return E.version
end
function Asked() return table.concat(asked, ";") end
function Toc(name, field) if name == "EraUI" and field == "Version" then return TOC end end
`;
function run(body) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  lua.lua_pushstring(L, to_luastring(init)); lua.lua_setglobal(L, to_luastring('INIT'));
  lua.lua_pushstring(L, to_luastring(toc)); lua.lua_setglobal(L, to_luastring('TOC'));
  const status = lauxlib.luaL_dostring(L, to_luastring(PRELUDE + body));
  if (status !== 0) throw new Error(lua.lua_tojsstring(L, -1));
  return lua.lua_tojsstring(L, -1);
}

test('the .toc has a version number', () => {
  assert.match(toc || '', /^\d+\.\d+(\.\d+)?$/);
});

test("the .toc's Version flows to EraUI.version", () => {
  assert.equal(run('return Load(Toc, nil)'), toc, 'through C_AddOns.GetAddOnMetadata');
  assert.equal(run('Load(Toc, nil) return Asked()'), 'EraUI,Version', 'asking for its own folder and the Version field');
  assert.equal(run('return Load(nil, Toc)'), toc, 'through the old global GetAddOnMetadata without C_AddOns');
  assert.equal(run('return Load(function() error("no metadata") end, Toc)'), toc, 'and the old global when C_AddOns fails');
  assert.equal(run('return Load(function() return nil end, Toc)'), toc, 'or gives nothing');
  assert.equal(run('return Load(function() return "  1.6.0 " end, nil)'), '1.6.0', 'spaces round it are dropped');
});

test('a copy without a real number runs as "dev"', () => {
  for (const [label, body] of [
    ["the packager's placeholder", 'return Load(function() return "@project-version@" end, nil)'],
    ['an empty Version', 'return Load(function() return "" end, nil)'],
    ['no Version', 'return Load(function() return nil end, nil)'],
    ['not text', 'return Load(function() return 155 end, nil)'],
    ['both readers failing', 'return Load(function() error("x") end, function() error("y") end)'],
    ['no reader at all', 'return Load(nil, nil)'],
  ]) assert.equal(run(body), 'dev', label);
});
