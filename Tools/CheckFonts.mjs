// Checks every font the damage text list bundles is in Media/Fonts, with a
// licence file beside each one that needs it. Run: node Tools/CheckFonts.mjs
import { readFileSync, existsSync } from 'node:fs';
const source = readFileSync('Modules/CombatFont.lua', 'utf8');
const files = [...source.matchAll(/PATH \.\. "([^"]+)"/g)].map(m => m[1]);
let missing = 0;
for (const name of files) {
    const font = `Media/Fonts/${name}`;
    const base = name.replace(/-Regular\.ttf$/, '');
    const licence = [`Media/Fonts/${base}-OFL.txt`, `Media/Fonts/${base}-LICENSE.txt`].find(existsSync);
    const ok = existsSync(font) && (licence || name === 'PEPSI_pl.ttf');
    if (!ok) missing++;
    console.log(`${ok ? 'ok     ' : 'MISSING'} ${name}${licence ? '  + ' + licence.split('/').pop() : ''}`);
}
console.log(missing ? `${missing} problem(s)` : `All ${files.length} bundled fonts present.`);
process.exitCode = missing ? 1 : 0;
