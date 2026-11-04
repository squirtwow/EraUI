// Independent game metadata export. No addon code or addon tables are inputs.
// Writes Modules/PoisonData.lua (every rogue weapon poison in Forever, by family
// and rank) and Tools/PoisonDataSources.json (sources, hashes, exclusions).
// Run: node Tools/GeneratePoisonData.mjs <cache directory>
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {csv,poisonFamilies,renderLua,BUILD,TABLES,IMBUE_EFFECT,LEGACY_TEMP_ENCHANT} from './PoisonDataRules.mjs';
const root=dirname(dirname(fileURLToPath(import.meta.url)));
const cache=process.argv[2];assert(cache,'Pass a cache directory');await mkdir(cache,{recursive:true});
const build=BUILD,sources=[];
async function download(name,url){
 let text;try{text=await readFile(join(cache,name),'utf8');}catch(e){if(e.code!=='ENOENT')throw e;
  const r=await fetch(url);assert(r.ok,`${url}: ${r.status}`);text=await r.text();await writeFile(join(cache,name),text);}
 sources.push({url,sha256:createHash('sha256').update(text).digest('hex')});return text;
}
const tables={};
for(const name of TABLES)tables[name]=csv(await download(`${name}.csv`,`https://wago.tools/db2/${name}/csv?build=${build}`));
const {families,excluded}=poisonFamilies(tables);
assert(families.length>=5,`only ${families.length} poison families found`);
await writeFile(join(root,'Modules/PoisonData.lua'),renderLua(build,families));
const summary=Object.fromEntries(families.map(f=>[f.name,f.ranks.map(r=>`${r.item}@${r.level}`).join(' ')]));
await writeFile(join(root,'Tools/PoisonDataSources.json'),JSON.stringify({build,sources,summary,
 excluded:excluded.map(({item,name,level,spell,effect,enchant,enchantName,reason})=>({item,name,level,spell,effect,enchant,enchantName,reason})),
 note:`A poison is a consumable item usable only by rogues whose use spell coats a weapon with Forever's imbue effect ${IMBUE_EFFECT} and an enchant that casts a spell on hit. `
  +`Rogue items still on the old temporary enchant effect ${LEGACY_TEMP_ENCHANT} (Season of Discovery poisons, test items) were not converted for Forever and are left out. `
  +'Families and ranks come from the item names (a trailing Roman numeral is the rank), checked against the use spell\'s rank and rising required levels.'},null,2)+'\n');
console.log(JSON.stringify({families:summary,excluded:excluded.map(e=>`${e.item} ${e.name}: ${e.reason}`)},null,2));
