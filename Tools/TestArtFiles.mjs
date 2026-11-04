// Every 1.x art copy the shared base names (Look/ArtKeys.lua's ns.TEX, and
// the Look base's own Look.ART, clean-room 2026-10-22) is a file in
// Media/Classic with exactly that name: a name that differs only in case
// loads on Windows and can fail on a case-sensitive disk. The game's own
// files aren't checked (the client has them). Loads the two files in
// fengari, as the game would, with nothing but a bare namespace.
// Run with: node --test Tools/TestArtFiles.mjs (FENGARI: the fengari module folder)
import test from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const { lua, lauxlib, lualib, to_luastring } = require(process.env.FENGARI || join(tmpdir(), 'opencode', 'lua-check', 'node_modules', 'fengari'));
const root = fileURLToPath(new URL('../', import.meta.url)).replace(/\\/g, '/');
const MEDIA = 'Interface\\AddOns\\EraUI\\Media\\Classic\\';

function artPaths() {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const chunk = `
    local root = ...
    local ns = {}
    local E = { Classic = ns }
    assert(loadfile(root .. "Look/Base.lua"))("EraUI", E)
    assert(loadfile(root .. "Look/ArtKeys.lua"))("EraUI", E)
    local out = {}
    for key, piece in pairs(ns.TEX) do out[#out + 1] = "TEX " .. key .. "\\t" .. piece[1] .. "\\t" .. piece[2] end
    for key, art in pairs(E.Look.ART) do
      out[#out + 1] = "ART " .. key .. "\\t" .. tostring(art.client) .. "\\t" .. tostring(art.bundled)
    end
    return table.concat(out, "\\n")`;
  assert.equal(lauxlib.luaL_loadstring(L, to_luastring(chunk)), 0, 'the loader compiles');
  lua.lua_pushstring(L, to_luastring(root));
  const status = lua.lua_pcall(L, 1, 1, 0);
  assert.equal(status, 0, status ? lua.lua_tojsstring(L, -1) : '');
  return lua.lua_tojsstring(L, -1).split('\n');
}

test('every art copy the base names is on disk under its exact name', () => {
  const disk = new Set(readdirSync(join(root, 'Media', 'Classic')));
  const lines = artPaths();
  assert.ok(lines.filter(line => line.startsWith('TEX ')).length >= 200, 'the art names loaded');
  const absent = [];
  for (const line of lines) {
    const [key, ...paths] = line.split('\t');
    for (const path of paths) {
      if (!path.startsWith(MEDIA)) continue;
      const file = path.slice(MEDIA.length);
      if (!(disk.has(file) || disk.has(file + '.blp') || disk.has(file + '.tga'))) absent.push(`${key}: ${file}`);
    }
  }
  assert.deepEqual(absent, [], 'copies missing or named in another case');
});
