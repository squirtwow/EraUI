// Rogue poison data: the selection rules on made-up rows, the shipped
// Modules/PoisonData.lua against Forever 1.60.1.70170, and every hardcoded
// poison list still in the addon against the generated data.
// Run: node Tools/TestPoisonData.mjs
// With POISON_DATA_CACHE=<the generator's cache directory> it also rebuilds the
// data from those CSVs and checks the shipped file is exactly that output.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {join,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {csv,poisonFamilies,renderLua,splitRank,familyKey,roman,BUILD,TABLES} from './PoisonDataRules.mjs';
const root=dirname(dirname(fileURLToPath(import.meta.url)));
// Git may check files out with CRLF line ends; compare them as LF.
const read=path=>readFileSync(join(root,path),'utf8').replace(/\r\n/g,'\n');
const code=text=>text.replace(/--\[(=*)\[[\s\S]*?\]\1\]/g,'').replace(/--[^\n]*/g,'');

// ---- made-up game rows -------------------------------------------------------
// One entry per item: {id,name,cls=0,mask=8,level,trigger=0,effect=360,enchantEffect=1,subtext,recipe,difficulty=0}
function fixture(entries){
 const t=Object.fromEntries(TABLES.map(n=>[n,[]]));
 let n=1;
 for(const e of entries){
  const spell=100000+e.id,enchant=500+e.id,link=n++;
  t.Item.push({ID:String(e.id),ClassID:String(e.cls??0),SubclassID:'8'});
  t.ItemSparse.push({ID:String(e.id),Display_lang:e.name,AllowableClass:String(e.mask??8),RequiredLevel:String(e.level),ItemLevel:String(e.level)});
  t.ItemEffect.push({ID:String(link),TriggerType:String(e.trigger??0),SpellID:String(spell)});
  t.ItemXItemEffect.push({ID:String(link),ItemEffectID:String(link),ItemID:String(e.id)});
  t.SpellEffect.push({SpellID:String(spell),Effect:String(e.effect??360),DifficultyID:String(e.difficulty??0),EffectMiscValue_0:String(enchant),EffectItemType:'0'});
  t.SpellName.push({ID:String(spell),Name_lang:e.name});
  t.Spell.push({ID:String(spell),NameSubtext_lang:e.subtext??''});
  t.SpellItemEnchantment.push({ID:String(enchant),Name_lang:e.name,Effect_0:String(e.enchantEffect??1)});
  if(e.recipe){
   t.SpellEffect.push({SpellID:String(e.recipe),Effect:'24',DifficultyID:'0',EffectMiscValue_0:'0',EffectItemType:String(e.id)});
   t.SkillLineAbility.push({Spell:String(e.recipe),ClassMask:String(e.recipeMask??8)});
  }
 }
 return t;
}
const tonic=[
 {id:30,name:'Tonic Poison III',level:40,subtext:'Rank 3',recipe:903},
 {id:10,name:'Tonic Poison',level:10,subtext:'Rank 1',recipe:901},
 {id:20,name:'Tonic Poison II',level:25,subtext:'Rank 2',recipe:902},
];

test('rank names, keys and numerals', () => {
 assert.deepEqual([roman('I'),roman('IV'),roman('VI'),roman('IX'),roman('XIV')],[1,4,6,9,14]);
 assert.deepEqual(splitRank('Instant Poison VI'),{family:'Instant Poison',rank:6});
 assert.deepEqual(splitRank('Occult Poison I'),{family:'Occult Poison',rank:1});
 assert.deepEqual(splitRank('Deadly Poison'),{family:'Deadly Poison',rank:1});
 assert.deepEqual(splitRank('Mind-numbing Poison II'),{family:'Mind-numbing Poison',rank:2});
 assert.equal(familyKey('Mind-numbing Poison'),'numbing');
 assert.equal(familyKey('Instant Poison'),'instant');
 assert.equal(familyKey('Wound Poison'),'wound');
 assert.equal(familyKey('Grave Toxin'),'toxin');
 assert.equal(familyKey('Poison'),'poison');
});

test('a family is ordered by rank with its levels, spells, enchants and recipes', () => {
 const {families,excluded}=poisonFamilies(fixture(tonic));
 assert.deepEqual(excluded,[]);
 assert.deepEqual(families,[{key:'tonic',name:'Tonic Poison',ranks:[
  {item:10,level:10,spell:100010,enchant:510,recipe:901},
  {item:20,level:25,spell:100020,enchant:520,recipe:902},
  {item:30,level:40,spell:100030,enchant:530,recipe:903},
 ]}]);
});

test('only rogue poisons on Forever\'s imbue effect are kept', () => {
 const {families,excluded}=poisonFamilies(fixture([...tonic,
  {id:40,name:'Old Poison',level:60,effect:54},
  {id:41,name:'Reagent Poison',level:20,cls:15},
  {id:42,name:'Blunt Poison',level:20,enchantEffect:2},
  {id:43,name:'Baby Poison',level:0},
  {id:50,name:'Sharpening Stone',level:20,mask:-1,effect:54},
  {id:51,name:'Scroll of Imbue Spark',level:16,mask:128},
  {id:52,name:'Shared Poison',level:20,mask:8|128},
  {id:53,name:'Equip Poison',level:20,trigger:1},
  {id:54,name:'Heroic Poison',level:20,difficulty:1},
 ]));
 assert.deepEqual(families.map(f=>f.key),['tonic']);
 const reasons=Object.fromEntries(excluded.map(e=>[e.item,e.reason]));
 assert.deepEqual(Object.keys(reasons).map(Number),[40,41,42,43],'rogue-only candidates that failed are recorded; other items are ignored');
 assert.match(reasons[40],/old temporary enchant effect 54/);
 assert.match(reasons[41],/not a consumable/);
 assert.match(reasons[42],/does not cast a spell on hit/);
 assert.match(reasons[43],/required level 0/);
});

test('a recipe must be a rogue ability, and a missing one is nil', () => {
 const t=fixture([{id:10,name:'Tonic Poison',level:10,recipe:901,recipeMask:4},{id:11,name:'Calm Poison',level:12}]);
 const {families}=poisonFamilies(t);
 assert.deepEqual(families.map(f=>f.ranks[0].recipe),[null,null]);
 assert.match(renderLua('x',families),/recipe=nil\}/);
});

test('families sort by first level, then name', () => {
 const {families}=poisonFamilies(fixture([
  {id:1,name:'Zeta Poison',level:20},{id:2,name:'Alpha Poison',level:30},{id:3,name:'Beta Poison',level:20}]));
 assert.deepEqual(families.map(f=>f.name),['Beta Poison','Zeta Poison','Alpha Poison']);
});

test('broken rank data stops the generator', () => {
 assert.throws(()=>poisonFamilies(fixture([tonic[1],tonic[0]])),/without gaps/,'rank II missing');
 assert.throws(()=>poisonFamilies(fixture([tonic[1],{...tonic[2],level:10}])),/higher level/,'level does not rise');
 assert.throws(()=>poisonFamilies(fixture([tonic[1],{...tonic[2],subtext:'Rank 3'}])),/says Rank 3/,'spell rank disagrees');
 assert.throws(()=>poisonFamilies(fixture([tonic[1],{...tonic[1],id:11}])),/without gaps or repeats/,'two rank ones');
 assert.throws(()=>poisonFamilies(fixture([{id:1,name:'Mind-numbing Poison',level:20},{id:2,name:'Numbing Poison',level:20}])),/keys are unique/);
});

test('CSV reader keeps quoted commas, quotes and line breaks', () => {
 assert.deepEqual(csv('ID,Name\n1,"a, ""b""\nc"\n2,d\n'),[{ID:'1',Name:'a, "b"\nc'},{ID:'2',Name:'d'}]);
});

// ---- the shipped file --------------------------------------------------------
function parseShipped(text){
 const lines=text.split('\n');let build;const families=[];let family;
 for(const line of lines){
  let m;
  if(line===''||line.startsWith('-- ')||line==='local _,E=...'||line===' }},'||line==='}}')continue;
  if((m=line.match(/^E\.PoisonData=\{build="([^"]+)",families=\{$/))){build=m[1];continue;}
  if((m=line.match(/^ \{key="([a-z]+)",name="([^"]+)",ranks=\{$/))){family={key:m[1],name:m[2],ranks:[]};families.push(family);continue;}
  if((m=line.match(/^  \{item=(\d+),level=(\d+),spell=(\d+),enchant=(\d+),recipe=(\d+|nil)\},$/))){
   family.ranks.push({item:+m[1],level:+m[2],spell:+m[3],enchant:+m[4],recipe:m[5]==='nil'?null:+m[5]});continue;}
  assert.fail(`unexpected line in Modules/PoisonData.lua: ${line}`);
 }
 return {build,families};
}
const shippedText=read('Modules/PoisonData.lua');
const shipped=parseShipped(shippedText);
const manifest=JSON.parse(read('Tools/PoisonDataSources.json'));
const family=key=>shipped.families.find(f=>f.key===key);

test('the shipped file is exactly the generator\'s output for Forever 70170', () => {
 assert.equal(shipped.build,BUILD);
 assert.equal(manifest.build,BUILD);
 assert.equal(renderLua(shipped.build,shipped.families),shippedText,'no hand edits');
 assert.deepEqual(manifest.sources.map(s=>s.url),TABLES.map(n=>`https://wago.tools/db2/${n}/csv?build=${BUILD}`));
 for(const s of manifest.sources)assert.match(s.sha256,/^[0-9a-f]{64}$/);
});

// Read from the 70170 tables by hand when the data was first generated.
const forever={
 crippling:{name:'Crippling Poison',items:[3775,3776],levels:[20,50],recipes:[3420,3421],enchants:[22,603]},
 instant:{name:'Instant Poison',items:[6947,6949,6950,8926,8927,8928],levels:[20,28,36,44,52,60],recipes:[8681,8687,8691,11341,11342,11343],enchants:[323,324,325,623,624,625]},
 numbing:{name:'Mind-numbing Poison',items:[5237,6951,9186],levels:[24,38,52],recipes:[5763,8694,11400],enchants:[35,23,643]},
 deadly:{name:'Deadly Poison',items:[2892,2893,8984,8985,20844],levels:[30,38,46,54,60],recipes:[2835,2837,11357,11358,25347],enchants:[7,8,626,627,2630]},
 wound:{name:'Wound Poison',items:[10918,10920,10921,10922],levels:[32,40,48,56],recipes:[13220,13228,13229,13230],enchants:[703,704,705,706]},
};

test('every Classic poison family and rank is there, in order', () => {
 assert.deepEqual(shipped.families.map(f=>f.key),['crippling','instant','numbing','deadly','wound']);
 for(const [key,want]of Object.entries(forever)){
  const f=family(key);
  assert.equal(f.name,want.name);
  assert.deepEqual(f.ranks.map(r=>r.item),want.items,`${key} items`);
  assert.deepEqual(f.ranks.map(r=>r.level),want.levels,`${key} levels`);
  assert.deepEqual(f.ranks.map(r=>r.recipe),want.recipes,`${key} recipes`);
  assert.deepEqual(f.ranks.map(r=>r.enchant),want.enchants,`${key} enchants`);
 }
 assert.equal(family('instant').ranks[0].spell,8679,'Instant Poison applies with spell 8679');
 assert.equal(family('deadly').ranks[4].spell,25351,'Deadly Poison V applies with spell 25351');
});

test('ranks rise in level, items and spells are unique', () => {
 const items=[],spells=[],enchants=[];
 for(const f of shipped.families){
  f.ranks.forEach((r,i)=>{if(i)assert.ok(r.level>f.ranks[i-1].level,`${f.key} rank ${i+1}`);assert.ok(r.level>=1&&r.level<=60);});
  for(const r of f.ranks){items.push(r.item);spells.push(r.spell);enchants.push(r.enchant);}
 }
 for(const [what,list]of [['items',items],['spells',spells],['enchants',enchants]])assert.equal(new Set(list).size,list.length,`unique ${what}`);
});

test('Season of Discovery and test poisons are left out, with the reason recorded', () => {
 const ids=new Set(shipped.families.flatMap(f=>f.ranks.map(r=>r.item)));
 const left=Object.fromEntries(manifest.excluded.map(e=>[e.item,e.reason]));
 for(const id of [202316,217345,217346,217347,226374,234444]){
  assert.equal(ids.has(id),false,`${id} not shipped`);
  assert.match(left[id]||'',/effect 54/,`${id} recorded as not converted for Forever`);
 }
 for(const id of [2896,2927,5654])assert.match(left[id]||'',/not a consumable/,`${id} recorded`);
});

test('the TOC loads the data before the rogue modules', () => {
 const toc=read('EraUI.toc').split(/\r?\n/).map(l=>l.trim());
 const at=toc.indexOf('Modules\\PoisonData.lua');
 assert.ok(at>0,'Modules\\PoisonData.lua is listed');
 for(const m of ['ClassTools','ClassReminderPoisons','ClassReminders','RoguePoisons']){
  const i=toc.indexOf(`Modules\\${m}.lua`);
  assert.ok(i>at,`before Modules\\${m}.lua`);
 }
 // POISON!'s module comes after Class Tools and before Class Reminders, which uses it.
 assert.ok(toc.indexOf('Modules\\ClassTools.lua')<toc.indexOf('Modules\\ClassReminderPoisons.lua'),'Class Tools first');
 assert.ok(toc.indexOf('Modules\\ClassReminderPoisons.lua')<toc.indexOf('Modules\\ClassReminders.lua'),'then the poison reminder, then Class Reminders');
 assert.equal(toc.indexOf('Modules\\PoisonReminders.lua'),-1,'the old Poison Reminders panel is gone');
 assert.equal(existsSync(join(root,'Modules/PoisonReminders.lua')),false,'and so is its file');
});

// ---- hardcoded copies, while they exist -------------------------------------
test('Rogue Poisons\' recipe and item lists match the data', t => {
 const src=code(read('Modules/RoguePoisons.lua'));
 const groups=[...src.matchAll(/\{name="([^"]+)",spells=\{([\d,]*)\},items=\{([\d,]*)\}/g)];
 if(!groups.length){t.skip('no hardcoded groups left');return;}
 const nums=s=>s.split(',').filter(Boolean).map(Number);
 assert.equal(groups.length,shipped.families.length,'one group per family');
 for(const [,name,spells,items]of groups){
  const f=shipped.families.find(f=>f.name===name);
  assert.ok(f,`${name} is a Forever family`);
  assert.deepEqual(nums(items),f.ranks.map(r=>r.item),`${name} items`);
  assert.deepEqual(nums(spells),f.ranks.map(r=>r.recipe),`${name} recipes`);
 }
});

test('Class Tools\' poison enchants and spells match the data', t => {
 const src=code(read('Modules/ClassTools.lua'));
 const block=src.match(/local coatingIDs=\{([\s\S]*?)\n\}/);
 if(!block){t.skip('no hardcoded coatings left');return;}
 for(const f of shipped.families){
  const m=block[1].match(new RegExp(`\\b${f.key}=\\{([\\d,]*)\\}`));
  assert.ok(m,`coatingIDs.${f.key}`);
  assert.deepEqual(m[1].split(',').map(Number),f.ranks.map(r=>r.enchant),`coatingIDs.${f.key}`);
 }
 const spells=src.match(/local poisonSpells=\{([^}]*)\}/);
 if(spells){
  const pairs=Object.fromEntries([...spells[1].matchAll(/(\w+)=(\d+)/g)].map(m=>[m[1],+m[2]]));
  assert.deepEqual(pairs,Object.fromEntries(shipped.families.map(f=>[f.key,f.ranks[0].recipe])));
 }
});

test('POISON! takes its poisons and first level from the data', () => {
 const data=code(read('Modules/ClassReminderData.lua'));
 const entry=data.match(/\{key="poison",[^\n]*\}/);
 assert.ok(entry,'the rogue\'s POISON! entry');
 assert.doesNotMatch(entry[0],/minLevel=/,'no level of its own');
 assert.doesNotMatch(data,/key="poison(Main|Off)"/,'the two old hand alerts are gone');
 const src=code(read('Modules/ClassReminderPoisons.lua'));
 assert.match(src,/E\.PoisonData/,'Modules/ClassReminderPoisons.lua reads Modules/PoisonData.lua');
 assert.doesNotMatch(src,/\b(6947|8928|2892|20844|3775)\b/,'and lists no poison item of its own');
 assert.equal(Math.min(...shipped.families.map(f=>f.ranks[0].level)),20,'the first poison level in Forever 1.60.1.70170');
});

// ---- optional: rebuild from the cached CSVs ---------------------------------
test('rebuilding from the cached tables gives the shipped file', t => {
 const cache=process.env.POISON_DATA_CACHE;
 if(!cache){t.skip('set POISON_DATA_CACHE to the generator cache to run');return;}
 const tables={};
 TABLES.forEach((name,i)=>{
  const text=readFileSync(join(cache,`${name}.csv`),'utf8');
  assert.equal(createHash('sha256').update(text).digest('hex'),manifest.sources[i].sha256,`${name}.csv is the recorded download`);
  tables[name]=csv(text);
 });
 const {families,excluded}=poisonFamilies(tables);
 assert.equal(renderLua(BUILD,families),shippedText);
 assert.deepEqual(excluded.map(e=>[e.item,e.reason]),manifest.excluded.map(e=>[e.item,e.reason]));
});
