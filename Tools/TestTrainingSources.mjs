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
 const row=line.match(/^  \{(\d+),(\d+),/);if(row)rows.push({className,id:+row[1],level:+row[2]});
}
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
console.log(`Training source audit passed: ${checks} checks; ${rows.length} packaged class entries.`);
