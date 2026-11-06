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
 const row=line.match(/^  \{(\d+),(\d+),(-?\d+),-?\d+,(?:\d+|nil),("(?:[^"\\]|\\.)*"),("(?:[^"\\]|\\.)*")\},$/);
 if(row)rows.push({className,id:+row[1],level:+row[2],prev:+row[3],name:JSON.parse(row[4]),rank:JSON.parse(row[5])});
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
// Build 1.60.1.70790. Talents live in Forever's class trait trees, not the
// Classic Talent table: rank 1 of a talent is never a trainer row (Wowhead
// Forever's ability pages leave them out too), but its trained ranks are.
// (70790 renumbered Mutilate: its talent is 399956 now; it dropped Lava Burst,
// and Venom 1310703 became a passive with no trainer row.)
equal(manifest.build,'1.60.1.70790','manifest build');
equal(lua.includes(`build="${manifest.build}"`),true,'data and manifest name one build');
for(const [id,name]of [[1310222,'Spearing Strike'],[1310994,'Swift Judgement'],[1310911,"Light's Vigil"],[1293241,'Summon Hawk'],
 [1317257,'Strider Kick'],[399956,'Mutilate'],[402174,'Penance'],[401859,'Prayer of Mending'],
 [408521,'Riptide'],[400574,'Arcane Blast'],[1312002,'Ice Lance'],[1326079,'Arcane Wrath'],[1225228,'Bane of Havoc'],
 [1293817,'Conflagrate'],[412758,'Incinerate'],[1316697,'Wrack'],[1238122,'Feral Charge'],[407995,'Primal Bite'],[408120,'Wild Growth']]){
 equal(rows.some(r=>r.id===id),false,`${id} ${name}: a talent is not a trainer row`);
 equal(manifest.excluded.includes(id),true,`${id} ${name}: seen and excluded, not just missing`);
}
// Revoke comes with Salvation (trainer spell 1912 teaches both), so it isn't
// a purchase of its own.
equal(rows.some(r=>r.id===1325499),false,'Revoke is not a trainer row');
equal(manifest.excluded.includes(1325499),true,'Revoke seen and excluded');
for(const [id,className,level,name]of [[5221,'DRUID',20,'Shred'],[20163,'PALADIN',26,'Seal of Fury'],[18499,'WARRIOR',30,'Berserker Rage'],
 [17354,'SHAMAN',38,'Mana Tide Totem'],[17359,'SHAMAN',48,'Mana Tide Totem'],[1325256,'SHAMAN',58,'Mana Tide Totem'],
 [1240826,'PRIEST',50,'Prayer of Mending'],[1240827,'PRIEST',60,'Prayer of Mending'],
 // 70707: Righteous Fury from 10 (was 16); trainers teach Voice of Truth,
 // which left the talent tree (30 Oct hotfix). (Binding Heal did too, until
 // 70790 dropped it.)
 [25780,'PALADIN',10,'Righteous Fury'],[1310897,'PALADIN',20,'Voice of Truth'],
 // Forever's new spells, levels by ID (BaseLevel 0): Poised for rogues and
 // druids (70753), Shank's two ranks (70790), named Rank 1 and 2 by ID.
 [1328825,'ROGUE',18,'Poised'],[1328829,'DRUID',32,'Poised'],[1329283,'ROGUE',24,'Shank'],[1329549,'ROGUE',44,'Shank'],
 // 70790: Sniper Shot's rank 3 has a level of its own (58).
 [1310786,'HUNTER',58,'Sniper Shot'],
 // 70753: Holy Shield's ranks at last agree (40, 50, 60).
 [20927,'PALADIN',40,'Holy Shield'],[20928,'PALADIN',50,'Holy Shield'],[1239570,'PALADIN',60,'Holy Shield'],
 // 70753: druids train a new Ferocious Bite rank 1 and a Lacerate rank 2.
 [1328618,'DRUID',24,'Ferocious Bite'],[1328616,'DRUID',34,'Lacerate']]){
 equal(rows.find(r=>r.id===id&&r.className===className&&r.level===level)?.name,name,`${id}: ${name} at ${level} in build 70790`);
}
equal([1329283,1329549].map(id=>{const r=rows.find(x=>x.id===id);return r&&`${r.rank} ${r.prev}`;}),['Rank 1 0','Rank 2 1329283'],
 'Shank: two ranks the guide tells apart, rank 2 after rank 1');
for(const id of [1328825,1328829,1329283,1329549]){
 equal(manifest.levelAudit.some(a=>a.id===id&&a.source==='forever-level-by-id'&&a.evidence),true,`${id}: by-ID level cites its evidence`);
}
// 70753 has no Primal Bite rank 4 any more.
equal(rows.some(r=>r.id===1238073),false,'1238073: Primal Bite rank 4 is gone');
equal(manifest.levelAudit.some(a=>a.id===1238073),false,'1238073: and has no record in 70753');
equal(rows.filter(r=>r.id===25780).length,1,'Righteous Fury listed once, at its new level');
// 70707 took Frost Blast out of the spellbook: no learnable row is left.
for(const id of [1326053,1326054,1326055]){
 equal(rows.some(r=>r.id===id),false,`${id}: Frost Blast is not a trainer row`);
 equal(manifest.levelAudit.some(a=>a.id===id),false,`${id}: Frost Blast has no learnable record in 70707`);
}
// Server hotfix (30 Oct): paladin trainers stop teaching these. The launch notes
// (3 Nov) remove Lava Burst too. The client data still lists them, so they are
// left out by ID and recorded as such.
equal(manifest.trainerChanges.notTaught,[19977,19978,19979,25890,1038,25895,1325499,1238299,1238300,1326047],'no longer taught, by ID');
equal(manifest.trainerChanges.nowTaught,[{id:1310897,className:'PALADIN'}],'now taught, by ID');
// The spellbook can still list them as coming, so the data hands the guide
// the same list to leave out (Modules/TrainingGuide.lua).
const shipped=(lua.match(/^E\.TrainingData=\{build="[^"]+",notTaught=\{([\d,]*)\},classes=\{$/m)||[])[1];
equal(shipped?.split(',').map(Number),[...manifest.trainerChanges.notTaught].sort((a,b)=>a-b),'TrainingData.lua carries the no-longer-taught list');
// The blessings and Salvation lost their level and name rows in 70753, yet stay
// on the list for a client still on 70707, whose book can still list them.
for(const [id,name]of [[19977,'Blessing of Light'],[19978,'Blessing of Light'],[19979,'Blessing of Light'],
 [25890,'Greater Blessing of Light'],[1038,'Salvation'],[25895,'Mass Salvation'],[1325499,'Revoke']]){
 equal(rows.some(r=>r.id===id),false,`${id} ${name}: no longer a trainer row`);
 equal(manifest.excluded.includes(id),true,`${id} ${name}: seen and excluded`);
 equal(manifest.levelAudit.some(a=>a.id===id&&a.level>0),false,`${id} ${name}: not learnable in the 70753 client data`);
}
// Lava Burst's ranks were still in the 70753 files (only the launch notes
// removed them); 70790 drops them, and Binding Heal's, from the client too.
for(const id of [1238299,1238300,1326047,401937,1240770,1240771,1240772,1240773,1240774]){
 equal(rows.some(r=>r.id===id),false,`${id}: no longer a trainer row`);
 equal(manifest.levelAudit.some(a=>a.id===id),false,`${id}: no learnable record in the 70790 client data`);
}
// 70707 renamed the three Explosive Trap Effect helpers "Explosive Trap": the
// trap is still one row per rank, under the trap's own IDs.
const traps=rows.filter(r=>r.className==='HUNTER'&&r.name==='Explosive Trap');
equal(traps.map(r=>`${r.id}@${r.level}`).join(' '),'13813@34 14316@44 14317@54','Explosive Trap: one row per rank');
for(const id of [13812,14314,14315])equal(manifest.excluded.includes(id),true,`${id}: the trap's effect stays out`);
// A row with no ClassMask is its class skill line's class's, and only the trait
// trees decide what is a talent: Forever trains these (former Classic talents
// among them). By ID: Tiger's Fury (AcquireMethod 3, yet trained) and Aspect of
// the Beast's new ranks. Primal Bite's levels are the client's own since 70753.
for(const [id,className,level,name]of [[29166,'DRUID',40,'Innervate'],[16864,'DRUID',20,'Omen of Clarity'],[16689,'DRUID',10,"Nature's Grasp"],
 [12051,'MAGE',20,'Evocation'],[1326080,'MAGE',36,'Arcane Wrath'],[1042,'PALADIN',30,'Holy Light'],[20217,'PALADIN',20,'Blessing of Kings'],
 [26573,'PALADIN',20,'Consecration'],[20915,'PALADIN',30,'Seal of Command'],[20473,'PALADIN',40,'Holy Shock'],
 [19434,'HUNTER',20,'Aimed Shot'],[1299348,'HUNTER',32,'Trueshot Aura'],[24118,'HUNTER',30,'Lacerate'],[1310785,'HUNTER',48,'Sniper Shot'],
 [1309595,'PRIEST',32,'Shadow Word: Death'],[14752,'PRIEST',30,'Divine Spirit'],[724,'PRIEST',40,'Lightwell'],
 [1014,'WARLOCK',18,'Bane of Agony'],[440892,'WARLOCK',20,'Curse of the Elements'],[17962,'WARLOCK',40,'Conflagrate'],
 [5217,'DRUID',24,"Tiger's Fury"],[1238069,'DRUID',50,'Primal Bite'],[1238070,'DRUID',60,'Primal Bite'],
 [1299445,'HUNTER',40,'Aspect of the Beast'],[1299446,'HUNTER',50,'Aspect of the Beast'],[1299447,'HUNTER',60,'Aspect of the Beast']]){
 equal(rows.filter(r=>r.id===id).map(r=>`${r.className} ${r.level} ${r.name}`),[`${className} ${level} ${name}`],`${id}: ${name} at ${level}`);
}
for(const id of [1299445,1299446,1299447]){
 equal(manifest.levelAudit.some(a=>a.id===id&&a.source==='forever-level-by-id'&&a.evidence),true,`${id}: by-ID level cites its evidence`);
}
for(const id of [1238069,1238070]){
 equal(manifest.levelAudit.some(a=>a.id===id&&a.source==='forever-base-level'),true,`${id}: Primal Bite's level is the client's own now`);
}
equal(manifest.levelAudit.filter(a=>a.trainedById).map(a=>a.id),[5217],"only Tiger's Fury is trained by ID, and the manifest says so");
// Out by ID: talent effects, Aquatic Form's passive and seasonal rune spells.
// Feral Charge (Bear) and Sniper Shot rank 3 wait for an in-game check.
for(const [id,name]of [[12484,'Chilled'],[29077,'Master of Elements'],[12355,'Impact'],[5421,'Aquatic Form (Passive)'],
 [407632,'Hammer of the Righteous'],[437169,'Portal of Summoning']]){
 equal(rows.some(r=>r.id===id),false,`${id} ${name}: not a trainer row`);
 equal(manifest.excluded.includes(id),true,`${id} ${name}: seen and excluded`);
}
equal(rows.some(r=>r.id===16979),false,'16979: not a trainer row before an in-game check');
// Lightning Shield's damage helpers name no class either: still one row per rank.
const shields=rows.filter(r=>r.className==='SHAMAN'&&r.name==='Lightning Shield');
equal(shields.map(r=>r.id).join(' '),'324 325 905 945 8134 10431 10432','Lightning Shield: one row per rank');
// Claw rank 1's SupercedesSpell 1263850 has no SpellName row: nothing comes first.
equal(rows.find(r=>r.id===1082)?.prev,0,'Claw rank 1 needs no earlier rank');
equal(rows.every(r=>r.prev!==1263850),true,'no row needs the missing spell 1263850');
// The trained ranks of a spell whose rank 1 is a tree talent wait for the rank
// before it (the client gives them none), so no guide offers them without the
// talent: rank 2 needs the talent, rank 3 rank 2, and so on.
const rankOf=r=>+(/^Rank (\d+)$/.exec(r.rank)||[])[1]||0;
const prevOf=id=>rows.find(r=>r.id===id)?.prev;
for(const [name,talent,ranks]of [['Seal of Command',20375,[20915,20918,20919,20920]],['Holy Shock',1311606,[20473,20929,20930]],
 ['Trueshot Aura',1299346,[1299348,19506,20905,20906]],['Arcane Wrath',1326079,[1326080,1326081,1326082]],['Sniper Shot',1310687,[1310785,1310786]],
 ['Conflagrate',1293817,[1293818,17962,18930,18931,18932]],['Primal Bite',407995,[1238069,1238070]],
 ['Holy Shield',20925,[20927,20928,1239570]],['Lacerate',1328617,[1328616,414644,1235826,1235827]]]){
 equal(ranks.map(prevOf),[talent,...ranks.slice(0,-1)],`${name}: each rank needs the one before it, from the talent on`);
 equal(rows.some(r=>r.id===talent),false,`${name}: its rank 1 is a talent, not a trainer row`);
 equal(manifest.excluded.includes(talent),true,`${name}: its talent is seen and left out`);
}
// 91 by this rule: since 70707 Holy Shield's 3 joined, Lava Burst's 3 left, and
// the client names Primal Bite's 2 and Lacerate's itself (its SupercedesSpell);
// 70790 adds Sniper Shot's rank 3.
equal(manifest.talentChains.length,91,'91 trained ranks follow a talent');
for(const c of manifest.talentChains){
 const row=rows.find(r=>r.id===c.id&&r.className===c.className),before=rows.find(r=>r.id===c.prev&&r.className===c.className);
 equal(row&&[row.name,rankOf(row),row.prev],[c.name,c.rank,c.prev],`${c.className} ${c.id}: shipped as the manifest says`);
 if(c.rank===2)equal(!before&&manifest.excluded.includes(c.prev),true,`${c.id} ${c.name}: rank 2 needs the talent, seen and left out`);
 else equal(before&&[before.name,rankOf(before)],[c.name,c.rank-1],`${c.id} ${c.name}: needs its rank ${c.rank-1}`);
 // Forever Prep reads the rows in order, so the rank before comes first.
 if(before)equal(before.level<row.level||(before.level===row.level&&before.id<row.id),true,`${c.id}: listed after the rank it needs`);
}
// Every other trained rank above 1 names the rank before it too (rankChains):
// the row of its class one rank lower, or the rank 1 every character of the
// class starts with (Fireball, Smite...), so no guide offers rank 3 unless
// rank 2 is known or on sale on the same trainer visit.
const row=(className,id)=>rows.find(r=>r.className===className&&r.id===id);
for(const [className,name,ranks]of [['PALADIN','Holy Light',[635,639,647,1026,1042,3472,10328,10329,25292]],
 ['PRIEST','Devouring Plague',[2944,19276,19277,19278,19279,19280]],['MAGE','Fireball',[133,143,145,3140,8400]],
 ['HUNTER','Lacerate',[24118,24119,24120,1299332]],['SHAMAN','Lightning Bolt',[403,529,548,915]]]){
 equal(ranks.slice(1).map(id=>row(className,id)?.prev),ranks.slice(0,-1),`${className} ${name}: each rank needs the one before it`);
 equal(ranks.slice(1).map(id=>row(className,id).name),ranks.slice(1).map(()=>name),`${className} ${name}: one spell`);
}
// Rank 1 of these comes from a class quest: still a row here (the guides that
// leave quest spells out find it in the spellbook), and rank 2 needs it.
const quests=await readFile(new URL('../Modules/ClassQuestData.lua',import.meta.url),'utf8');
for(const [className,name,first,second]of [['PALADIN','Redemption',7328,10322],['SHAMAN','Stoneskin Totem',8071,8154],
 ['SHAMAN','Searing Totem',3599,6363],['SHAMAN','Healing Stream Totem',5394,6375]]){
 equal([row(className,first)?.name,rankOf(row(className,first)),row(className,second)?.prev],[name,1,first],`${name}: rank 2 needs the quest's rank 1`);
 equal(new RegExp(`\\bQ\\[${first}\\]\\s*=`).test(quests),true,`${name}: rank 1 is a class quest's`);
}
// The druid's Lacerate and Ferocious Bite as 70753 gives them: Lacerate's talent
// is rank 1 and the old ranks move up to 3-5, Ferocious Bite has a new rank 1 and
// the old ranks move up to 2-6. The hunter's Lacerate, above, is its own.
for(const [id,prev,rank]of [[1328616,1328617,2],[414644,1328616,3],[1235826,414644,4],[1235827,1235826,5],
 [1328618,0,1],[22568,1328618,2],[22827,22568,3],[22828,22827,4],[22829,22828,5],[31018,22829,6]]){
 equal([row('DRUID',id)?.prev,rankOf(row('DRUID',id))],[prev,rank],`${id}: the druid's rank as the client gives it`);
}
// Held at 0 by ID, each with its reason: Seal of Righteousness 2 (which rank 1
// characters have waits for a game check) and the Greater Blessings of Might
// and Wisdom rank 2 (Forever's trainers ask for the plain blessing's top rank
// instead). Binding Heal 2-6 were held too, until 70790 dropped the spell.
const heldPrev=[20287,25916,25918];
equal(manifest.heldPrev.map(h=>h.id),heldPrev,'the ranks held at 0, by ID');
for(const h of manifest.heldPrev){
 equal(rows.filter(r=>r.id===h.id).map(r=>r.prev),[0],`${h.id}: held at 0`);
 equal(typeof h.reason==='string'&&h.reason.length>20,true,`${h.id}: held with its reason`);
}
const starting=new Map([[14260,2973],[2052,2050],[591,585],[332,331],[529,403],[143,133],[7300,168],[695,686],[696,687],[5177,5176],[5186,5185]]);
equal(manifest.rankChains.length,743,'743 more trained ranks name the rank before them');
const talentChained=new Set(manifest.talentChains.map(c=>c.className+':'+c.id));
for(const c of manifest.rankChains){
 const r=row(c.className,c.id),before=row(c.className,c.prev);
 equal(r&&[r.name,rankOf(r),r.prev],[c.name,c.rank,c.prev],`${c.className} ${c.id}: shipped as the manifest says`);
 equal(talentChained.has(c.className+':'+c.id),false,`${c.id}: not a talent's chain as well`);
 if(c.starting)equal([!before,c.rank,starting.get(c.id)],[true,2,c.prev],`${c.id} ${c.name}: rank 2 needs the rank 1 everyone starts with`);
 else{
  equal(before&&[before.name,rankOf(before)],[c.name,c.rank-1],`${c.id} ${c.name}: needs its rank ${c.rank-1}`);
  equal(before.level<r.level||(before.level===r.level&&before.id<r.id),true,`${c.id}: listed after the rank it needs`);
 }
}
equal(manifest.rankChains.filter(c=>c.starting).map(c=>c.id).sort((a,b)=>a-b),[...starting.keys()].sort((a,b)=>a-b),'the eleven starting spells');
// Strict: no rank above 1 is left without the rank before it but the held ones.
equal(rows.filter(r=>r.prev===0&&rankOf(r)>1).map(r=>`${r.className} ${r.id}`),rows.filter(r=>heldPrev.includes(r.id)).map(r=>`${r.className} ${r.id}`),
 'every rank above 1 names the rank before it, but the held ones');
// The rank names are checked once more for the spells a talent starts, not only
// the rows the manifest lists.
const talentSpells=new Set(manifest.talentChains.map(c=>`${c.className} ${c.name}`));
equal(talentSpells.size,26,'26 spells a talent starts');
equal(rows.filter(r=>talentSpells.has(`${r.className} ${r.name}`)&&rankOf(r)>1&&r.prev===0).map(r=>`${r.className} ${r.id} ${r.name}`),[],
 'every rank above 1 of a spell a talent starts names the rank before it');
console.log(`Training source audit passed: ${checks} checks; ${rows.length} packaged class entries.`);
