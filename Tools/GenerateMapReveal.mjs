// Generate numeric map metadata from Blizzard DB2 exports, never addon tables.
// Run with Node 18+: node Tools/GenerateMapReveal.mjs [cache-directory]
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import assert from 'node:assert/strict';

const build = '1.60.1.70009';
const root = dirname(dirname(fileURLToPath(import.meta.url)));
const cache = process.argv[2] || join(tmpdir(), 'eraui-map-data', build);
const names = ['WorldMapOverlay', 'WorldMapOverlayTile', 'UiMapXMapArt', 'UiMapArt', 'UiMapArtStyleLayer'];
const sources = [];
await mkdir(cache, { recursive: true });

async function load(name) {
    const url = `https://wago.tools/db2/${name}/csv?build=${build}`;
    const path = join(cache, `${name}-${build}.csv`);
    let text;
    try { text = await readFile(path, 'utf8'); }
    catch (error) {
        if (error.code !== 'ENOENT') throw error;
        const response = await fetch(url);
        assert(response.ok, `${url}: HTTP ${response.status}`);
        text = await response.text();
        await writeFile(path, text);
    }
    const lines = text.trim().split(/\r?\n/);
    const fields = lines.shift().split(',');
    assert(fields.includes('ID'), `${name}: invalid CSV header`);
    const rows = lines.map(line => {
        const values = line.split(',');
        assert.equal(values.length, fields.length, `${name}: malformed row`);
        return Object.fromEntries(values.map((value, i) => {
            assert(value.trim() !== '' && Number.isFinite(Number(value)), `${name}: non-numeric ${fields[i]}`);
            return [fields[i], Number(value)];
        }));
    });
    assert(rows.length > 0, `${name}: empty export`);
    assert.equal(new Set(rows.map(row => row.ID)).size, rows.length, `${name}: duplicate IDs`);
    sources.push({ name, url, rows: rows.length, sha256: createHash('sha256').update(text).digest('hex') });
    return rows;
}

const [overlays, tiles, links, arts, styles] = await Promise.all(names.map(load));
const artByID = new Map(arts.map(row => [row.ID, row]));
const tileGroups = new Map();
for (const tile of tiles) {
    if (!tileGroups.has(tile.WorldMapOverlayID)) tileGroups.set(tile.WorldMapOverlayID, []);
    tileGroups.get(tile.WorldMapOverlayID).push(tile);
}

const mapArts = new Map();
for (const link of links) {
    if (!mapArts.has(link.UiMapID)) mapArts.set(link.UiMapID, new Set());
    mapArts.get(link.UiMapID).add(link.UiMapArtID);
}
const activeArts = new Set(links.map(row => row.UiMapArtID));
const generated = new Map();
const skipped = [];
let regionCount = 0, tileCount = 0;
for (const artID of [...activeArts].sort((a, b) => a - b)) {
    const art = artByID.get(artID);
    assert(art, `Missing art ${artID}`);
    const regions = overlays.filter(row => row.UiMapArtID === artID).sort((a, b) => a.ID - b.ID);
    if (!regions.length) continue;
    const layers = new Map();
    for (const style of styles.filter(row => row.UiMapArtStyleID === art.UiMapArtStyleID)) {
        const entries = [];
        const seen = new Set();
        assert(style.TileWidth > 0 && style.TileHeight > 0 && style.LayerWidth > 0 && style.LayerHeight > 0);
        for (const region of regions) {
            const label = `${artID}/${region.ID}/${style.LayerIndex}`;
            const omit = reason => skipped.push({ artID, overlayID: region.ID, layer: style.LayerIndex, reason });
            if (region.TextureWidth <= 0 || region.TextureHeight <= 0) { omit('no artwork dimensions'); continue; }
            if (region.PlayerConditionID !== 0 || ![0, 4].includes(region.Flags)) {
                omit('conditional or unsupported overlay flags'); continue;
            }
            const cells = (tileGroups.get(region.ID) || []).filter(t => t.LayerIndex === style.LayerIndex)
                .sort((a, b) => a.RowIndex - b.RowIndex || a.ColIndex - b.ColIndex);
            if (!cells.length) { omit('no texture records'); continue; }
            const cols = Math.ceil(region.TextureWidth / style.TileWidth);
            const rows = Math.ceil(region.TextureHeight / style.TileHeight);
            assert.equal(cells.length, cols * rows, `${label}: incomplete tile grid`);
            for (let i = 0; i < cells.length; i++) {
                const tile = cells[i];
                assert.equal(tile.RowIndex, Math.floor(i / cols), `${label}: wrong row`);
                assert.equal(tile.ColIndex, i % cols, `${label}: wrong column`);
                assert(Number.isSafeInteger(tile.FileDataID) && tile.FileDataID > 0, `${label}: invalid texture`);
            }
            const key = [region.OffsetX, region.OffsetY, region.TextureWidth, region.TextureHeight].join(',');
            assert(!seen.has(key), `${label}: duplicate bounds`);
            seen.add(key);
            entries.push({ region, cells });
            regionCount++;
            tileCount += cells.length;
        }
        if (entries.length) layers.set(style.LayerIndex + 1, { style, entries });
    }
    if (layers.size) generated.set(artID, layers);
}

// Data-specific checks guard the initial in-game test zones and continent views.
assert.equal(generated.get(2169)?.get(1)?.entries.length, 11, 'Durotar overlay count');
assert.equal(generated.get(2180)?.get(1)?.entries.length, 11, 'Teldrassil overlay count');
for (const id of [947, 1414, 1415]) {
    for (const art of mapArts.get(id)) assert(!generated.has(art), `Continent/world ${id} must not have reveal tiles`);
}

const out = [
    'local _,E=...',
    `-- Generated from Blizzard DB2 exports for ${build}. See Tools/MapRevealData.md.`,
    '-- No texture assets are bundled; these IDs address artwork already in the client.',
    '-- Region: {overlayID, x, y, width, height, {{column, row, fileDataID}, ...}}.',
    `E.MapRevealData={build="${build}",maps={`,
];
for (const [mapID, artIDs] of [...mapArts].sort((a, b) => a[0] - b[0])) {
    const supported = [...artIDs].filter(id => generated.has(id)).sort((a, b) => a - b);
    if (supported.length) out.push(` [${mapID}]={${supported.map(id => `[${id}]=true`).join(',')}},`);
}
out.push('},art={');
for (const [artID, layers] of generated) {
    out.push(` [${artID}]={`);
    for (const [index, { style, entries }] of layers) {
        out.push(`  [${index}]={width=${style.LayerWidth},height=${style.LayerHeight},tileWidth=${style.TileWidth},tileHeight=${style.TileHeight},regions={`);
        for (const { region: r, cells } of entries) {
            out.push(`   {${r.ID},${r.OffsetX},${r.OffsetY},${r.TextureWidth},${r.TextureHeight},{${cells.map(t => `{${t.ColIndex},${t.RowIndex},${t.FileDataID}}`).join(',')}}},`);
        }
        out.push('  }},');
    }
    out.push(' },');
}
out.push('}}', '');
await writeFile(join(root, 'Modules', 'MapRevealData.lua'), out.join('\n'));
const report = { build, arts: generated.size, regions: regionCount, tiles: tileCount, sources: sources.sort((a, b) => a.name.localeCompare(b.name)), skipped };
await writeFile(join(root, 'Tools', 'MapRevealData.json'), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ build, arts: generated.size, regions: regionCount, tiles: tileCount, skipped }, null, 2));
