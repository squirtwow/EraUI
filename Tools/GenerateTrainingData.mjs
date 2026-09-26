// Independent game metadata export. No addon code or addon tables are inputs.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {trainingLevel} from './TrainingLevelRules.mjs';
const root=dirname(dirname(fileURLToPath(import.meta.url)));
const cache=process.argv[2];assert(cache,'Pass a cache directory');await mkdir(cache,{recursive:true});
const build='1.60.1.70009',sources=[];
async function download(name,url){
 let text;try{text=await readFile(join(cache,name),'utf8');}catch(e){if(e.code!=='ENOENT')throw e;
  const r=await fetch(url);assert(r.ok,`${url}: ${r.status}`);text=await r.text();await writeFile(join(cache,name),text);}
 sources.push({url,sha256:createHash('sha256').update(text).digest('hex')});return text;
}
function csv(text){
 const rows=[];let row=[],v='',quoted=false;
 for(let i=0;i<text.length;i++){const c=text[i];
  if(c==='"'){if(quoted&&text[i+1]==='"'){v+='"';i++;}else quoted=!quoted;}
  else if(!quoted&&(c===','||c==='\n')){row.push(v.replace(/\r$/,''));v='';if(c==='\n'){rows.push(row);row=[];}}
  else v+=c;
 }
 if(v||row.length){row.push(v);rows.push(row);}const header=rows.shift();
 return rows.filter(r=>r.length>1).map(r=>{assert.equal(r.length,header.length,'CSV width');return Object.fromEntries(header.map((h,i)=>[h,r[i]]));});
}
async function table(name){return csv(await download(`${name}.csv`,`https://wago.tools/db2/${name}/csv?build=${build}`));}
const names=['SkillLine','SkillLineAbility','SkillRaceClassInfo','SpellLevels','SpellName','Spell','SpellMisc','SpellEffect','Talent'];
const tables={};for(const name of names)tables[name]=await table(name);
const by=(name,key='ID')=>new Map(tables[name].map(r=>[+r[key],r]));
const skills=by('SkillLine'),spellNames=by('SpellName'),spells=by('Spell');
const levels=new Map(tables.SpellLevels.filter(r=>+r.DifficultyID===0).map(r=>[+r.SpellID,r]));
const misc=new Map(tables.SpellMisc.filter(r=>+r.DifficultyID===0).map(r=>[+r.SpellID,r]));
const talents=new Set(tables.Talent.flatMap(r=>Object.entries(r).filter(([k,v])=>(k==='SpellID'||k.startsWith('SpellRank_'))&&+v>0).map(([,v])=>+v)));
const teaching=new Set(tables.SpellEffect.filter(r=>+r.Effect===36).map(r=>+r.SpellID));
const classes={WARRIOR:1,PALADIN:2,HUNTER:4,ROGUE:8,PRIEST:16,SHAMAN:64,MAGE:128,WARLOCK:256,DRUID:1024};
const legacy=new Map(),references=new Map();
for(const c of Object.keys(classes)){
 const text=await download(`classic-${c}.html`,`https://www.wowhead.com/classic/spells/abilities/${c.toLowerCase()}`);
 // Extract factual IDs/prices only; never evaluate page JavaScript.
 for(const match of text.matchAll(/\{[^{}]*"id":\d+[^{}]*\}/g)){
  const s=match[0],id=+(s.match(/"id":(\d+)/)||[])[1];
  if(!/"cat":7[,}]/.test(s))continue;
  const reference={level:+(s.match(/"level":(\d+)/)||[])[1],season:+(s.match(/"seasonId":(\d+)/)||[])[1]||0};
  references.set(id,reference);
  const cost=s.match(/"trainingcost":(\d+)/);
  if(cost&&!reference.season){reference.cost=+cost[1];legacy.set(id,+cost[1]);}
 }
}
const output={},exclusions=[],seen=new Map(),levelAudit=[],skillLevelAudit=[];
for(const [name]of Object.entries(classes))output[name]=[];
for(const a of tables.SkillLineAbility){
 const id=+a.Spell,skill=skills.get(+a.SkillLine),level=levels.get(id),m=misc.get(id);
 if(!skill||+skill.CategoryID!==7||!(+skill.Flags&1024)||+a.ClassMask===0||+a.AcquireMethod!==0)continue;
 const decision=trainingLevel({baseLevel:+level?.BaseLevel,spellLevel:+level?.SpellLevel,reference:references.get(id)});
 const required=decision.level;
 levelAudit.push({id,name:spellNames.get(id)?.Name_lang,classMask:+a.ClassMask,baseLevel:+level?.BaseLevel||0,
  spellLevel:+level?.SpellLevel||0,reference:references.get(id),...decision});
 if(!required){exclusions.push(id);continue;}
 if(talents.has(id)||teaching.has(id)||!spells.get(id)?.Description_lang||!level||required<1||required>60||!m||(+m.Attributes_0&128)){
  exclusions.push(id);continue;
 }
 const n=spellNames.get(id)?.Name_lang,rank=spells.get(id)?.NameSubtext_lang||'';
 if(!n||/\b(?:OLD|DND|Deprecated|Passive Effect)\b/i.test(n))continue;
 for(const [className,mask]of Object.entries(classes))if(+a.ClassMask&mask){
  const key=className+':'+id,prior=seen.get(key),race=+a.RaceMasks_0;
  if(prior){prior.race=prior.race===0||race===0?0:prior.race|race;continue;}
  const row={id,level:required,prev:+a.SupercedesSpell,race,name:n,rank,cost:legacy.get(id)??null};
  output[className].push(row);seen.set(key,row);
 }
}
// Skill-granted passives can have no SpellLevels record (notably Dual Wield).
// Their exact-build SkillRaceClassInfo supplies the class-specific level.
for(const a of tables.SkillLineAbility.filter(r=>+r.AcquireMethod===2&&+skills.get(+r.SkillLine)?.CategoryID===6)){
 const id=+a.Spell,m=misc.get(id);if(!m||(+m.Attributes_0&128))continue;
 for(const requirement of tables.SkillRaceClassInfo.filter(r=>+r.SkillID===+a.SkillLine&&+r.MinLevel>1)){
  for(const [c,mask]of Object.entries(classes))if((+a.ClassMask&mask)&&(+requirement.ClassMask&mask)&&!seen.has(c+':'+id)){
   const name=spellNames.get(id)?.Name_lang;if(!name)continue;
    const row={id,level:+requirement.MinLevel,prev:0,race:+a.RaceMasks_0,name,rank:spells.get(id)?.NameSubtext_lang||'',cost:legacy.get(id)??null};
    skillLevelAudit.push({id,className:c,level:row.level,skillID:+a.SkillLine,source:'forever-class-skill-level'});
   output[c].push(row);seen.set(c+':'+id,row);
  }
 }
}
const q=s=>JSON.stringify(s).replace(/\\u([\da-f]{4})/gi,(_,h)=>String.fromCharCode(parseInt(h,16)));
let lua='-- Generated from independent Blizzard metadata. See Tools/TrainingDataSources.json.\nlocal _,E=...\nE.TrainingData={build="'+build+'",classes={\n';
const summary={};
for(const [className,rawRows]of Object.entries(output)){
 // Some aura damage helpers repeat the player spell's name and rank. Keep one
 // entry for the same class/race/level, preferring a documented trainer record.
 const canonical=new Map();
 for(const r of rawRows){
  const key=[r.name,r.rank,r.level,r.race].join('|'),old=canonical.get(key);
  if(!old)canonical.set(key,r);
  else if((r.cost!==null&&old.cost===null)||(r.cost===old.cost&&r.id<old.id)){exclusions.push(old.id);canonical.set(key,r);}
  else exclusions.push(r.id);
 }
 const rows=[...canonical.values()];
 rows.sort((a,b)=>a.level-b.level||a.id-b.id);assert(rows.length>20,`${className}: incomplete catalog`);
 lua+=' '+className+'={\n';
 for(const r of rows)lua+=`  {${r.id},${r.level},${r.prev},${r.race},${r.cost??'nil'},${q(r.name)},${q(r.rank)}},\n`;
 lua+=' },\n';summary[className]={spells:rows.length,basePrices:rows.filter(r=>r.cost!==null).length};
}
lua+='}}\n';
await writeFile(join(root,'Modules/TrainingData.lua'),lua);
await writeFile(join(root,'Tools/TrainingDataSources.json'),JSON.stringify({build,sources,summary,excluded:exclusions,levelAudit,skillLevelAudit,
 note:'Levels require an explicit Forever BaseLevel, a non-seasonal Classic reference corroborating a non-default level or priced starter ability, or class-specific SkillRaceClassInfo. Uncorroborated seasonal/default level-one records are not assumed trainable. Prices are non-seasonal Classic base-price references, not verified Forever quotes.'},null,2)+'\n');
console.log(JSON.stringify(summary,null,2));
