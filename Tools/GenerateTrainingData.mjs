// Independent game metadata export. No addon code or addon tables are inputs.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {trainingLevel} from './TrainingLevelRules.mjs';
const root=dirname(dirname(fileURLToPath(import.meta.url)));
const cache=process.argv[2];assert(cache,'Pass a cache directory');await mkdir(cache,{recursive:true});
const build='1.60.1.70790',sources=[];
// Cached by file name, so pass a new cache directory for each new build, with
// the classic-*.html reference pages copied in from
// C:\AddonDev\_ForeverData\classic-reference-pages: Classic's data doesn't move
// with Forever's builds, and those pages answer 403 now.
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
const names=['SkillLine','SkillLineAbility','SkillRaceClassInfo','SpellLevels','SpellName','Spell','SpellMisc','SpellEffect',
 'SkillLineXTraitTree','TraitNode','TraitNodeXTraitNodeEntry','TraitNodeEntry','TraitDefinition'];
const tables={};for(const name of names)tables[name]=await table(name);
const by=(name,key='ID')=>new Map(tables[name].map(r=>[+r[key],r]));
const skills=by('SkillLine'),spellNames=by('SpellName'),spells=by('Spell');
const levels=new Map(tables.SpellLevels.filter(r=>+r.DifficultyID===0).map(r=>[+r.SpellID,r]));
const misc=new Map(tables.SpellMisc.filter(r=>+r.DifficultyID===0).map(r=>[+r.SpellID,r]));
// A skill line's classes (SkillRaceClassInfo). Many trainer rows name no class
// (Innervate, Evocation, Aimed Shot, Voice of Truth...): a class skill line
// belongs to one class, so the row is that class's.
const skillClasses=new Map();
for(const r of tables.SkillRaceClassInfo)if(+r.ClassMask>0)skillClasses.set(+r.SkillID,(skillClasses.get(+r.SkillID)||0)|+r.ClassMask);
// A class line naming a second class would quietly put its unclassed rows in both.
for(const s of tables.SkillLine)if(+s.CategoryID===7&&(+s.Flags&1024)){
 const m=skillClasses.get(+s.ID)||0;assert(m&&!(m&(m-1)),`${s.ID}: a class skill line names one class`);
}
const classOf=a=>+a.ClassMask||skillClasses.get(+a.SkillLine)||0;
// Forever's class talents are trait trees, and only they decide what is a
// talent: Forever trains many Classic talents (Blessing of Kings, Lightwell,
// Omen of Clarity...), so the Classic Talent table is no guide. A spell
// defined in a class's tree (SkillLineXTraitTree) is a talent even where
// SkillLineAbility files it like a trainer spell (Arcane Wrath, Lava Burst
// rank 1); its trained higher ranks are not in the tree. Each talent maps to
// its tree's class (the tree's skill line), for the ranks trained after it.
const classTrees=new Map(tables.SkillLineXTraitTree.map(r=>[+r.TraitTreeID,skillClasses.get(+r.SkillLineID)||0]));
const treeNodes=new Map(tables.TraitNode.filter(r=>classTrees.has(+r.TraitTreeID)).map(r=>[+r.ID,classTrees.get(+r.TraitTreeID)]));
const treeEntries=new Map(tables.TraitNodeXTraitNodeEntry.filter(r=>treeNodes.has(+r.TraitNodeID)).map(r=>[+r.TraitNodeEntryID,treeNodes.get(+r.TraitNodeID)]));
const treeDefinitions=new Map(tables.TraitNodeEntry.filter(r=>treeEntries.has(+r.ID)).map(r=>[+r.TraitDefinitionID,treeEntries.get(+r.ID)]));
const treeTalents=new Map(tables.TraitDefinition.filter(r=>treeDefinitions.has(+r.ID)&&+r.SpellID>0).map(r=>[+r.SpellID,treeDefinitions.get(+r.ID)]));
assert(classTrees.size===9&&treeTalents.size>400,'nine class talent trees');
assert.equal(new Set(classTrees.values()).size,9,'each tree is one class\'s');
const teaching=new Set(tables.SpellEffect.filter(r=>+r.Effect===36).map(r=>+r.SpellID));
// Taught with another trainer spell, never bought on its own: Revoke comes
// with Salvation (trainer spell 1912 teaches 1038 and 1325499). By ID only: a
// rule for every second taught spell would also drop Call Pet, Growl, Prowl...
const learnedWithAnother=new Set([1325499]);
// Trainer lists are server-side, so no client export shows these. Forever's
// 30 Oct 2026 hotfix notes (on build 1.60.1.70707, whose files still list
// them the old way): paladin trainers stop teaching Blessing of Light
// (19977-19979), Greater Blessing of Light (25890), Salvation (1038), Mass
// Salvation (25895) and Revoke; Voice of Truth (paladin) and Binding Heal
// rank 1 (priest) leave the talent trees and trainers teach them, at the
// levels SpellLevels already gives (20 and 25). By ID only. The client data
// still makes them learnable, so the spellbook can list them as coming:
// TrainingData.lua carries notTaught and Modules/TrainingGuide.lua leaves
// those future entries out too. A spell left out here still shows once a
// trainer offers it (the guide keeps every recorded quote). The 70753 files
// drop the blessings and Salvation, but a client still on 70707 has them.
// Lava Burst ranks 2-4 (1238299, 1238300, 1326047) too: Blizzard's launch notes
// of 3 Nov 2026 remove the spell with every reference, yet the 70753 files still
// list these ranks, waiting on a talent nobody can get. Official word only, so
// take them off this list if live data disagrees. Build 70790 drops every
// Lava Burst and Binding Heal row; the Lava Burst IDs stay on notTaught for a
// client still on an older build, and Binding Heal leaves nowTaught.
const notTaught=new Set([19977,19978,19979,25890,1038,25895,1325499,1238299,1238300,1326047]);
const nowTaught=new Map([[1310897,'PALADIN']]);
// Levels set by ID, each with its evidence in the manifest's levelAudit. Aspect
// of the Beast ranks 2-4 are new ranks with BaseLevel 0 and no Classic reference,
// so the level rules leave them out; their SpellLevel and Forever's spellbook
// changes for 70707 agree on 40/50/60.
const newRank='A new rank with BaseLevel 0 and no Classic reference; its SpellLevel and Forever\'s 70707 spellbook changes give this level';
// Forever's new spells, BaseLevel 0 with no Classic reference, so the level
// rules leave them out too: Poised (rogue 1328825, druid 1328829; build 70753)
// and Shank's two ranks (rogue; build 70790). Their SpellLevel, Wowhead
// Forever's tooltips (Requires level ...) and warcraft.wiki.gg's Forever
// ability lists (Trainer, 6 Nov 2026) agree; a player was told by the
// trainer list that Poised is trained at 18.
const newSpell='A new Forever spell with BaseLevel 0 and no Classic reference; its SpellLevel, Wowhead Forever\'s tooltip and warcraft.wiki.gg\'s Forever ability list (Trainer) give this level';
const levelsById=new Map([[1299445,[40,newRank]],[1299446,[50,newRank]],[1299447,[60,newRank]],
 [1328825,[18,newSpell]],[1328829,[32,newSpell]],[1329283,[24,newSpell]],[1329549,[44,newSpell]]]);
// Shank's two ranks have no rank text in the client (build 70790), so the
// guide, which tells spells apart by name and rank, saw one. Wowhead Forever's
// tooltips call them Rank 1 and Rank 2. By ID; the build checks below stop on
// any other class list with two rows of one name and rank.
const rankTextById=new Map([[1329283,'Rank 1'],[1329549,'Rank 2']]);
// Tiger's Fury's only row is AcquireMethod 3 and nothing in the client teaches
// it, yet Forever's trainers do: one rank, at its BaseLevel 24. By ID only.
const trainedAnyway=new Map([[5217,'AcquireMethod 3 and taught by nothing in the client; Forever\'s 70707 spellbook changes list one rank, trained at 24']]);
// Not trainer spells: talent effects filed as mage spells (Chilled, Master of
// Elements, Impact), the passive that comes with Aquatic Form, and two
// seasonal rune spells Forever never had (Hammer of the Righteous, Portal of
// Summoning). By ID only.
const notTrainerSpells=new Set([12484,29077,12355,5421,407632,437169]);
// Left out until a trainer visit settles them. None now: 70753 settled Holy
// Shield's ranks at 40, 50 and 60.
const awaitingCheck=new Set();
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
 const classMask=classOf(a);
 if(!skill||+skill.CategoryID!==7||!(+skill.Flags&1024)||classMask===0||(+a.AcquireMethod!==0&&!trainedAnyway.has(id)))continue;
 const [byId,evidence]=levelsById.get(id)||[];
 assert(!byId||+level?.BaseLevel!==byId,`${id}: the client now says level ${byId}, so its by-ID level can go`);
 const decision=byId?{level:byId,source:'forever-level-by-id',evidence}
  :trainingLevel({baseLevel:+level?.BaseLevel,spellLevel:+level?.SpellLevel,reference:references.get(id)});
 const required=decision.level;
 levelAudit.push({id,name:spellNames.get(id)?.Name_lang,classMask,baseLevel:+level?.BaseLevel||0,
  spellLevel:+level?.SpellLevel||0,reference:references.get(id),...decision,
  ...(trainedAnyway.has(id)?{trainedById:trainedAnyway.get(id)}:{})});
 if(!required){exclusions.push(id);continue;}
 if((treeTalents.has(id)&&!nowTaught.has(id))||learnedWithAnother.has(id)||notTaught.has(id)||notTrainerSpells.has(id)||awaitingCheck.has(id)||teaching.has(id)||!spells.get(id)?.Description_lang||!level||required<1||required>60||!m||(+m.Attributes_0&128)){
  exclusions.push(id);continue;
 }
 const n=spellNames.get(id)?.Name_lang,rank=spells.get(id)?.NameSubtext_lang||rankTextById.get(id)||'';
 assert(!rankTextById.has(id)||!spells.get(id)?.NameSubtext_lang,`${id}: the client gives its rank text now, so its by-ID text can go`);
 if(!n||/\b(?:OLD|DND|Deprecated|Passive Effect)\b/i.test(n))continue;
 // A rank before it with no SpellName row is no spell anyone can know (Claw
 // rank 1 names 1263850), so nothing comes before it.
 const prev=spellNames.has(+a.SupercedesSpell)?+a.SupercedesSpell:0;
 for(const [className,mask]of Object.entries(classes))if(classMask&mask){
  const key=className+':'+id,prior=seen.get(key),race=+a.RaceMasks_0;
  if(prior){prior.race=prior.race===0||race===0?0:prior.race|race;continue;}
  // line: its skill line, for the rank before it (not written out).
  const row={id,level:required,prev,race,name:n,rank,cost:legacy.get(id)??null,line:+a.SkillLine};
  output[className].push(row);seen.set(key,row);
 }
}
// Skill-granted passives can have no SpellLevels record (notably Dual Wield).
// Their exact-build SkillRaceClassInfo supplies the class-specific level.
for(const a of tables.SkillLineAbility.filter(r=>+r.AcquireMethod===2&&+skills.get(+r.SkillLine)?.CategoryID===6)){
 const id=+a.Spell,m=misc.get(id);if(!m||(+m.Attributes_0&128))continue;
 for(const requirement of tables.SkillRaceClassInfo.filter(r=>+r.SkillID===+a.SkillLine&&+r.MinLevel>1)){
  for(const [c,mask]of Object.entries(classes))if((classOf(a)&mask)&&(+requirement.ClassMask&mask)&&!seen.has(c+':'+id)){
   const name=spellNames.get(id)?.Name_lang;if(!name)continue;
    const row={id,level:+requirement.MinLevel,prev:0,race:+a.RaceMasks_0,name,rank:spells.get(id)?.NameSubtext_lang||'',cost:legacy.get(id)??null};
    skillLevelAudit.push({id,className:c,level:row.level,skillID:+a.SkillLine,source:'forever-class-skill-level'});
   output[c].push(row);seen.set(c+':'+id,row);
  }
 }
}
// The client names no earlier rank (SupercedesSpell 0) for the trained ranks
// of a spell whose rank 1 is a talent in Forever's trees (Seal of Command
// 2-5, Holy Shock 2-4, Conflagrate 2-6...), so a guide would offer them to a
// character without the talent. Each such rank needs the one before it, by
// the client's rank number: rank 2 the talent, rank 3 rank 2, and so on.
// Voice of Truth is not one: trainers teach it now (nowTaught).
const rankOf=rank=>+(/^Rank (\d+)$/.exec(rank||'')||[])[1]||0;
const talentRanks=new Map();
for(const [id,mask]of treeTalents)if(!nowTaught.has(id)){
 const key=[mask,spellNames.get(id)?.Name_lang,rankOf(spells.get(id)?.NameSubtext_lang)].join('|');
 talentRanks.set(key,[...(talentRanks.get(key)||[]),id]);
}
// Held at prev 0 by ID, as the client gives them (manifest heldPrev), until
// the game settles them. (Binding Heal's ranks were held here until build
// 70790 dropped the spell.)
const keepPrev=new Map([
 [20287,'Seal of Righteousness rank 2: rank 1 is 21084 by the client\'s rank text, 20154 by Forever\'s 70707 spellbook changes and its recorded trainer list; kept until a game check shows which one characters have'],
 [25916,'Greater Blessing of Might rank 2: Forever\'s trainer list (recorded on build 70124) asks for Blessing of Might rank 7, not rank 1'],
 [25918,'Greater Blessing of Wisdom rank 2: Forever\'s trainer list (recorded on build 70124) asks for Blessing of Wisdom rank 6, not rank 1']]);
const talentChains=[];
function chainTalentRanks(className,rows){
 const mask=classes[className],at=(name,rank)=>[...(talentRanks.get([mask,name,rank].join('|'))||[]),
  ...rows.filter(r=>r.name===name&&rankOf(r.rank)===rank).map(r=>r.id)];
 for(const r of rows){
  const rank=rankOf(r.rank);
  if(r.prev||rank<2||keepPrev.has(r.id))continue;
  // Other spells keep the client's prev, so none may follow a talent rank.
  if(!talentRanks.has([mask,r.name,1].join('|'))){
   assert(!talentRanks.has([mask,r.name,rank-1].join('|')),`${className} ${r.id} ${r.name}: the rank before it is a talent`);
   assert(!talentRanks.has([mask,r.name,0].join('|')),`${className} ${r.id} ${r.name}: an unranked talent of that name`);
   continue;
  }
  const before=at(r.name,rank-1);
  assert.equal(before.length,1,`${className} ${r.id} ${r.name}: one rank ${rank-1} before it`);
  r.prev=before[0];talentChains.push({className,name:r.name,rank,id:r.id,prev:r.prev});
 }
}
// Every other trained rank above 1. The client names the rank before
// (SupercedesSpell) only on the warrior's and rogue's lines, the druid's Feral
// Combat and a few paladin rows, so elsewhere a guide offered Fireball 3 before
// Fireball 2. Forever's trainers want the rank before, as Classic's did: each
// such rank names the rank of the same class, skill line and name one lower,
// a row, or else the rank 1 every character of the class starts with (an
// AcquireMethod 2 row of that line: Fireball, Smite...). Rank 1 of Redemption
// and of Stoneskin, Searing and Healing Stream Totem comes from a class quest:
// a row here, and the guides that leave quest spells out find it in the
// spellbook. A rank with nothing before it, or two different ranks (a row and
// another starting spell), stops the build until it is held. A starting spell
// only some races get doesn't count: the class's other races never have it.
const starting=new Map();
for(const a of tables.SkillLineAbility)if(+a.AcquireMethod===2&&!+a.RaceMasks_0){
 const skill=skills.get(+a.SkillLine),id=+a.Spell,name=spellNames.get(id)?.Name_lang;
 if(!skill||+skill.CategoryID!==7||!(+skill.Flags&1024)||!name)continue;
 for(const [className,mask]of Object.entries(classes))if(classOf(a)&mask){
  const key=[className,+a.SkillLine,name,rankOf(spells.get(id)?.NameSubtext_lang)].join('|'),ids=starting.get(key)||[];
  if(!ids.includes(id))starting.set(key,[...ids,id]);
 }
}
const rankChains=[];
function chainTrainedRanks(className,rows){
 for(const r of rows){
  const rank=rankOf(r.rank);
  if(r.prev||rank<2||keepPrev.has(r.id))continue;
  const before=rows.filter(o=>o.line===r.line&&o.name===r.name&&rankOf(o.rank)===rank-1).map(o=>o.id);
  const first=starting.get([className,r.line,r.name,rank-1].join('|'))||[];
  // A row that is also a starting spell is one rank, not two.
  const ids=[...new Set([...before,...first])];
  assert.equal(ids.length,1,`${className} ${r.id} ${r.name}: one rank ${rank-1} before it, not ${ids.join(', ')||'none'}`);
  r.prev=ids[0];
  rankChains.push({className,name:r.name,rank,id:r.id,prev:r.prev,...(before.length?{}:{starting:true})});
 }
}
const q=s=>JSON.stringify(s).replace(/\\u([\da-f]{4})/gi,(_,h)=>String.fromCharCode(parseInt(h,16)));
let lua='-- Generated from independent Blizzard metadata. See Tools/TrainingDataSources.json.\n'+
 '-- notTaught: spells trainers no longer teach (server side) that the spellbook may still list as coming.\n'+
 'local _,E=...\nE.TrainingData={build="'+build+'",notTaught={'+[...notTaught].sort((a,b)=>a-b).join(',')+'},classes={\n';
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
 // The guide keeps one row per name and rank for a character, so two rows
 // one race can have would hide one (Shank's two ranks with no rank text did).
 const everyone=race=>race===0||race===-1;
 for(const a of rows)for(const b of rows)if(a!==b&&a.name===b.name&&a.rank===b.rank){
  assert(!everyone(a.race)&&!everyone(b.race)&&((a.race>>>0)&(b.race>>>0))===0,`${className} ${a.id} and ${b.id}: both ${a.name} ${a.rank||'(no rank)'}, so the guide shows one`);
 }
 rows.sort((a,b)=>a.level-b.level||a.id-b.id);assert(rows.length>20,`${className}: incomplete catalog`);
 chainTalentRanks(className,rows);chainTrainedRanks(className,rows);
 lua+=' '+className+'={\n';
 for(const r of rows)lua+=`  {${r.id},${r.level},${r.prev},${r.race},${r.cost??'nil'},${q(r.name)},${q(r.rank)}},\n`;
 lua+=' },\n';summary[className]={spells:rows.length,basePrices:rows.filter(r=>r.cost!==null).length};
}
lua+='}}\n';
await writeFile(join(root,'Modules/TrainingData.lua'),lua);
const trainerChanges={source:'Forever hotfix notes, 30 Oct 2026, and launch notes, 3 Nov 2026 (trainer lists are server-side, not in client data)',
 notTaught:[...notTaught],nowTaught:[...nowTaught].map(([id,className])=>({id,className}))};
await writeFile(join(root,'Tools/TrainingDataSources.json'),JSON.stringify({build,sources,summary,excluded:exclusions,levelAudit,skillLevelAudit,trainerChanges,talentChains,rankChains,
 heldPrev:[...keepPrev].map(([id,reason])=>({id,reason})),
 note:'Levels require an explicit Forever BaseLevel, a non-seasonal Classic reference corroborating a non-default level or priced starter ability, class-specific SkillRaceClassInfo, or a by-ID level (source forever-level-by-id, with its evidence). Uncorroborated seasonal/default level-one records are not assumed trainable. A row with no ClassMask takes its class skill line\'s class. Tiger\'s Fury 5217 is trained by ID though its only row is AcquireMethod 3 (levelAudit trainedById). Talents (spells defined in the class trait trees; Forever trains many Classic talents, so the Classic Talent table is not used), Revoke 1325499, taught with Salvation, and a few non-trainer spells by ID (talent effects, a form\'s passive, seasonal rune spells) are excluded. trainerChanges lists the spells trainers stopped or started teaching by server hotfix, which client data cannot show. talentChains lists the trained ranks of a spell whose rank 1 is a tree talent, each given the rank before it by the client\'s rank number (the client\'s SupercedesSpell is 0 on them), so they wait for the talent. rankChains lists every other trained rank above 1 the client gives no earlier rank, each given the rank of the same class, skill line and name one lower (a row, or with starting the rank 1 every character of the class starts with). heldPrev lists the ranks kept at 0 by ID, with why. Prices are non-seasonal Classic base-price references, not verified Forever quotes.'},null,2)+'\n');
console.log(JSON.stringify(summary,null,2));
