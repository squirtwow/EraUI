// Regression cases for the reported SoD entries and the generated nine-class
// catalog. Check shipped rows against evidence, not just the selection function.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {trainingLevel} from './TrainingLevelRules.mjs';
let checks=0;
function equal(actual,wanted,label){checks++;assert.deepEqual(actual,wanted,label);}
for(const id of [409580,415423]){
 equal(trainingLevel({baseLevel:0,spellLevel:1,reference:{season:2,level:1}}).level,undefined,`${id}: default SoD level is not learning evidence`);
}
equal(trainingLevel({baseLevel:1,spellLevel:1,reference:{season:2,level:1}}).level,undefined,'seasonal level-one base alone is insufficient');
equal(trainingLevel({baseLevel:20,spellLevel:20,reference:{season:2,level:1}}).level,20,'Forever-relevelled Victory Rush is preserved');
equal(trainingLevel({baseLevel:0,spellLevel:10,reference:{season:0,level:10}}).level,10,'corroborated Feed Pet quest ability is preserved');
equal(trainingLevel({baseLevel:0,spellLevel:1,reference:{season:0,level:1,cost:10}}).level,1,'documented non-seasonal starter training is preserved');
equal(trainingLevel({baseLevel:0,spellLevel:1,reference:{season:0,level:1}}).level,undefined,'unpriced default level-one record is not assumed trainable');
equal(trainingLevel({baseLevel:0,spellLevel:50}).level,undefined,'uncorroborated scaling level is not a training level');
equal(trainingLevel({baseLevel:0,spellLevel:32,reference:{season:0,level:28}}).level,undefined,'conflicting references stay excluded');
equal(trainingLevel({baseLevel:16,spellLevel:16,reference:{season:0,level:18}}).level,16,'explicit current-client base level wins over old Classic level');
equal(trainingLevel({baseLevel:-1,spellLevel:10,reference:{season:0,level:10}}).level,undefined,'invalid base data is not silently rescued');

const manifest=JSON.parse(await readFile(new URL('./TrainingDataSources.json',import.meta.url),'utf8'));
const lua=await readFile(new URL('../Modules/TrainingData.lua',import.meta.url),'utf8');
const rows=[];let className;
for(const line of lua.split('\n')){
 const header=line.match(/^ ([A-Z]+)=\{/);if(header)className=header[1];
 const row=line.match(/^  \{(\d+),(\d+),-?\d+,-?\d+,(?:\d+|nil),("(?:[^"\\]|\\.)*"),/);
 if(row)rows.push({className,id:+row[1],level:+row[2],name:JSON.parse(row[3])});
}
equal(rows.length,lua.split('\n').filter(line=>/^  \{\d+,/.test(line)).length,'every row parsed');
equal(new Set(rows.map(r=>r.className)).size,9,'all nine classes audited');
for(const row of rows){
 const evidence=manifest.levelAudit.find(a=>a.id===row.id&&a.level===row.level)
  ||manifest.skillLevelAudit.find(a=>a.id===row.id&&a.className===row.className&&a.level===row.level);
 equal(!!evidence,true,`${row.className} ${row.id}: shipped learning level has recorded evidence`);
 if(evidence.source==='corroborated-classic-ability'){
  equal(evidence.reference.season,0,`${row.id}: fallback reference is non-seasonal`);
  equal(evidence.reference.level,row.level,`${row.id}: fallback agrees with reference`);
  if(row.level===1)equal(Number.isFinite(evidence.reference.cost),true,`${row.id}: starter fallback has documented training`);
 }
}
for(const id of [409580,415423,425336,401977,438040,468766,469145,1221404]){
 equal(rows.some(r=>r.id===id),false,`${id}: unverified seasonal leftover absent from package`);
}
for(const [id,className,level]of [[6991,'HUNTER',10],[1515,'HUNTER',10],[674,'HUNTER',20],[674,'ROGUE',10],[402927,'WARRIOR',20]]){
 equal(rows.some(r=>r.id===id&&r.className===className&&r.level===level),true,`${id}: legitimate training entry survives cleanup`);
}
// Build 1.60.1.70425. Talents live in Forever's class trait trees, not the
// Classic Talent table: rank 1 of a talent is never a trainer row (Wowhead
// Forever's ability pages leave them out too), but its trained ranks are.
equal(manifest.build,'1.60.1.70425','manifest build');
equal(lua.includes(`build="${manifest.build}"`),true,'data and manifest name one build');
for(const [id,name]of [[1310222,'Spearing Strike'],[1310994,'Swift Judgement'],[1310911,"Light's Vigil"],[1293241,'Summon Hawk'],
 [1317257,'Strider Kick'],[1310707,'Mutilate'],[1310703,'Venom'],[401937,'Binding Heal'],[402174,'Penance'],[401859,'Prayer of Mending'],
 [408490,'Lava Burst'],[408521,'Riptide'],[400574,'Arcane Blast'],[1312002,'Ice Lance'],[1326079,'Arcane Wrath'],[1225228,'Bane of Havoc'],
 [1293817,'Conflagrate'],[412758,'Incinerate'],[1316697,'Wrack'],[1238122,'Feral Charge'],[407995,'Primal Bite'],[408120,'Wild Growth']]){
 equal(rows.some(r=>r.id===id),false,`${id} ${name}: a talent is not a trainer row`);
 equal(manifest.excluded.includes(id),true,`${id} ${name}: seen and excluded, not just missing`);
}
// Revoke comes with Salvation (trainer spell 1912 teaches both), so it isn't
// a purchase of its own.
equal(rows.some(r=>r.id===1325499),false,'Revoke is not a trainer row');
equal(manifest.excluded.includes(1325499),true,'Revoke seen and excluded');
for(const [id,className,level,name]of [[5221,'DRUID',20,'Shred'],[20163,'PALADIN',26,'Seal of Fury'],[18499,'WARRIOR',30,'Berserker Rage'],
 [1038,'PALADIN',26,'Salvation'],[25895,'PALADIN',60,'Mass Salvation'],
 [17354,'SHAMAN',38,'Mana Tide Totem'],[17359,'SHAMAN',48,'Mana Tide Totem'],[1325256,'SHAMAN',58,'Mana Tide Totem'],
 [1238299,'SHAMAN',40,'Lava Burst'],[1238300,'SHAMAN',50,'Lava Burst'],[1326047,'SHAMAN',60,'Lava Burst'],
 [1326053,'MAGE',24,'Frost Blast'],[1326054,'MAGE',36,'Frost Blast'],[1326055,'MAGE',48,'Frost Blast'],
 [1240826,'PRIEST',50,'Prayer of Mending'],[1240827,'PRIEST',60,'Prayer of Mending']]){
 equal(rows.find(r=>r.id===id&&r.className===className&&r.level===level)?.name,name,`${id}: ${name} at ${level} in build 70425`);
}
console.log(`Training source audit passed: ${checks} checks; ${rows.length} packaged class entries.`);
