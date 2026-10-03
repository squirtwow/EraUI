// Rogue weapon poison selection from Forever DB2 rows (CSV strings as exported
// by wago.tools). Pure functions: no downloads, no addon code or addon tables.
// Used by Tools/GeneratePoisonData.mjs and Tools/TestPoisonData.mjs.
import assert from 'node:assert/strict';

// Forever applies weapon imbues (rogue poisons, shaman weapon imbues, firestones,
// spellstones, the mage imbue scrolls) with spell effect 360. Classic's
// temporary enchant effect 54 is still used by sharpening stones and by the
// Season of Discovery poisons and test items that Forever did not convert.
export const BUILD='1.60.1.70170';
export const TABLES=['Item','ItemSparse','ItemEffect','ItemXItemEffect','SpellEffect','SpellName','Spell','SpellItemEnchantment','SkillLineAbility'];
export const IMBUE_EFFECT=360;
export const LEGACY_TEMP_ENCHANT=54;
export const CREATE_ITEM=24;
export const ROGUE=8;
const CLASS_BITS=0x1fff;
const ON_USE=0;
const CONSUMABLE=0;
// SpellItemEnchantment effect 1: casts a spell on a weapon hit (every poison).
const PROC_ON_HIT=1;

export function csv(text){
 const rows=[];let row=[],v='',quoted=false;
 for(let i=0;i<text.length;i++){const c=text[i];
  if(c==='"'){if(quoted&&text[i+1]==='"'){v+='"';i++;}else quoted=!quoted;}
  else if(!quoted&&(c===','||c==='\n')){row.push(v.replace(/\r$/,''));v='';if(c==='\n'){rows.push(row);row=[];}}
  else v+=c;
 }
 if(v||row.length){row.push(v);rows.push(row);}const header=rows.shift();
 return rows.filter(r=>r.length>1).map(r=>{assert.equal(r.length,header.length,'CSV width');return Object.fromEntries(header.map((h,i)=>[h,r[i]]));});
}

const ROMAN={I:1,V:5,X:10,L:50,C:100};
export function roman(text){
 let total=0;
 for(let i=0;i<text.length;i++){const v=ROMAN[text[i]],next=ROMAN[text[i+1]]||0;total+=v<next?-v:v;}
 return total;
}
// "Instant Poison VI" -> family "Instant Poison", rank 6. No numeral is rank 1.
export function splitRank(name){
 const m=name.match(/^(.*\S)\s+([IVXLC]+)$/);
 return m?{family:m[1],rank:roman(m[2])}:{family:name,rank:1};
}
// The family's own word, as the reminders already key them: "Mind-numbing
// Poison" -> "numbing", "Instant Poison" -> "instant".
export function familyKey(family){
 const words=family.split(/[\s-]+/).filter(Boolean);
 if(words.length>1&&/^poison$/i.test(words[words.length-1]))words.pop();
 return words[words.length-1].toLowerCase().replace(/[^a-z]/g,'');
}
function rogueOnly(mask){return mask>0&&(mask&ROGUE)!==0&&(mask&CLASS_BITS&~ROGUE)===0;}

// tables: {Item, ItemSparse, ItemEffect, ItemXItemEffect, SpellEffect, SpellName,
// Spell, SpellItemEnchantment, SkillLineAbility}, each an array of CSV rows.
export function poisonFamilies(tables){
 const by=(name,key='ID')=>new Map(tables[name].map(r=>[+r[key],r]));
 const items=by('Item'),sparse=by('ItemSparse'),itemEffects=by('ItemEffect'),
  spellNames=by('SpellName'),spells=by('Spell'),enchants=by('SpellItemEnchantment');
 const coating=new Map(),creates=new Map();
 for(const r of tables.SpellEffect){
  if(+r.DifficultyID!==0)continue;
  const effect=+r.Effect,spell=+r.SpellID;
  if((effect===IMBUE_EFFECT||effect===LEGACY_TEMP_ENCHANT)&&!coating.has(spell))coating.set(spell,{effect,enchant:+r.EffectMiscValue_0});
  if(effect===CREATE_ITEM&&+r.EffectItemType>0){const list=creates.get(+r.EffectItemType)||[];list.push(spell);creates.set(+r.EffectItemType,list);}
 }
 const rogueAbilities=new Set(tables.SkillLineAbility.filter(r=>(+r.ClassMask&ROGUE)!==0).map(r=>+r.Spell));
 const accepted=[],excluded=[];
 for(const link of tables.ItemXItemEffect){
  const itemEffect=itemEffects.get(+link.ItemEffectID);
  if(!itemEffect||+itemEffect.TriggerType!==ON_USE)continue;
  const spell=+itemEffect.SpellID,coat=coating.get(spell);if(!coat)continue;
  const id=+link.ItemID,item=items.get(id),s=sparse.get(id);
  if(!s)continue;
  const name=s.Display_lang,mask=+s.AllowableClass;
  // Only rogue-only coatings are poison candidates; anything all classes can
  // use (sharpening stones, oils, the shared weapon items) is not a poison.
  if(!rogueOnly(mask))continue;
  const enchant=enchants.get(coat.enchant);
  const row={item:id,name,level:+s.RequiredLevel,itemLevel:+s.ItemLevel,spell,
   spellName:spellNames.get(spell)?.Name_lang||'',subtext:spells.get(spell)?.NameSubtext_lang||'',
   effect:coat.effect,enchant:coat.enchant,enchantName:enchant?.Name_lang||''};
  let reason;
  if(+item?.ClassID!==CONSUMABLE)reason=`item class ${item?.ClassID}/${item?.SubclassID}, not a consumable`;
  else if(coat.effect!==IMBUE_EFFECT)reason=`applied with the old temporary enchant effect ${coat.effect}, not Forever's imbue effect ${IMBUE_EFFECT} (not converted for Forever: Season of Discovery or test item)`;
  else if(!enchant)reason=`weapon enchant ${coat.enchant} missing`;
  else if(+enchant.Effect_0!==PROC_ON_HIT)reason=`weapon enchant ${coat.enchant} does not cast a spell on hit`;
  else if(!(row.level>=1&&row.level<=60))reason=`required level ${row.level} outside 1 to 60`;
  if(reason){excluded.push({...row,reason});continue;}
  const recipes=(creates.get(id)||[]).filter(r=>rogueAbilities.has(r)).sort((a,b)=>a-b);
  row.recipe=recipes[0]??null;
  accepted.push(row);
 }
 const byFamily=new Map();
 for(const row of accepted){
  const {family,rank}=splitRank(row.name);
  const list=byFamily.get(family)||[];list.push({...row,rank});byFamily.set(family,list);
 }
 const families=[];
 for(const [name,rows]of byFamily){
  rows.sort((a,b)=>a.rank-b.rank||a.item-b.item);
  rows.forEach((r,i)=>{
   assert.equal(r.rank,i+1,`${name}: ranks run 1 to ${rows.length} without gaps or repeats (item ${r.item} "${r.name}")`);
   const stated=r.subtext.match(/^Rank (\d+)$/);
   if(stated)assert.equal(+stated[1],r.rank,`${r.name}: use spell ${r.spell} says ${r.subtext}`);
   if(i>0)assert.ok(r.level>rows[i-1].level,`${name}: rank ${r.rank} needs a higher level than rank ${r.rank-1}`);
  });
  families.push({key:familyKey(name),name,ranks:rows.map(({item,level,spell,enchant,recipe})=>({item,level,spell,enchant,recipe}))});
 }
 families.sort((a,b)=>a.ranks[0].level-b.ranks[0].level||a.name.localeCompare(b.name));
 const keys=families.map(f=>f.key);
 assert.equal(new Set(keys).size,keys.length,`family keys are unique: ${keys.join(', ')}`);
 for(const k of keys)assert.match(k,/^[a-z]+$/,`family key "${k}"`);
 const ids=families.flatMap(f=>f.ranks.map(r=>r.item));
 assert.equal(new Set(ids).size,ids.length,'every poison item is listed once');
 excluded.sort((a,b)=>a.item-b.item);
 return {families,excluded};
}

const q=s=>JSON.stringify(s);
export function renderLua(build,families){
 let lua=`-- Generated by Tools/GeneratePoisonData.mjs from Forever ${build} game data. Do not edit by hand.\n`
  +'-- Rogue weapon poisons by family, lowest rank first. level: required level to use the item.\n'
  +'-- spell: the item\'s use spell, which applies the poison. enchant: the weapon enchant it leaves.\n'
  +'-- recipe: the Poisons skill spell that makes it (nil when nothing makes it).\n'
  +'local _,E=...\n'
  +`E.PoisonData={build=${q(build)},families={\n`;
 for(const f of families){
  lua+=` {key=${q(f.key)},name=${q(f.name)},ranks={\n`;
  for(const r of f.ranks)lua+=`  {item=${r.item},level=${r.level},spell=${r.spell},enchant=${r.enchant},recipe=${r.recipe??'nil'}},\n`;
  lua+=' }},\n';
 }
 return lua+'}}\n';
}
