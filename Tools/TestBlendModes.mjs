// Static checks on what EraUI ships (everything but Tools and .github).
// No MOD blending: it multiplies the screen whatever the alpha, so a MOD
// texture stays on screen when the UI fades (Bag Item Levels' old red tint
// was the red square left on the AFK screen). Plus Bag Item Levels' art and
// font, and the AFK screen's banner, glow, quote font and quotes.
// Run: node Tools/TestBlendModes.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync,existsSync} from 'node:fs';
import {join,relative,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {arrowTGA,SIZE} from './GenerateBagArrow.mjs';
import {glowTGA,GLOW_SIZE} from './GenerateLogoGlow.mjs';
const root=dirname(dirname(fileURLToPath(import.meta.url)));
const SKIP=new Set(['.git','.github','Tools']);
function files(dir,out=[]){
 for(const entry of readdirSync(dir,{withFileTypes:true})){
  if(SKIP.has(entry.name))continue;
  const path=join(dir,entry.name);
  if(entry.isDirectory())files(path,out);
  else if(/\.(lua|xml)$/i.test(entry.name))out.push(path);
 }
 return out;
}
const shipped=files(root);
const name=path=>relative(root,path).replace(/\\/g,'/');
// Lua source without its comments, so a comment can still talk about MOD.
const code=text=>text.replace(/--\[(=*)\[[\s\S]*?\]\1\]/g,'').replace(/--[^\n]*/g,'');

test('the scan sees the addon', () => {
 assert.ok(shipped.length>50,`only ${shipped.length} files found`);
 assert.ok(shipped.some(p=>name(p)==='Modules/BagItemLevels.lua'));
});

test('no texture blends with MOD anywhere in EraUI', () => {
 const found=[];
 for(const path of shipped){
  const text=readFileSync(path,'utf8');
  const body=path.endsWith('.xml')?text:code(text);
  if(/alphaMode\s*=\s*["']MOD["']/i.test(body))found.push(`${name(path)}: alphaMode="MOD"`);
  if(/SetBlendMode\s*\(\s*["']MOD["']/.test(body))found.push(`${name(path)}: SetBlendMode("MOD")`);
  if(/["']MOD["']/.test(body))found.push(`${name(path)}: a "MOD" string`);
 }
 assert.deepEqual(found,[]);
});

test('every SetBlendMode names its mode, so the scan above cannot miss one', () => {
 const loose=[];
 for(const path of shipped.filter(p=>p.endsWith('.lua'))){
  const body=code(readFileSync(path,'utf8'));
  for(const m of body.matchAll(/SetBlendMode\s*\(\s*([^)]*)\)/g)){
   if(!/^["'](BLEND|ADD|ALPHAKEY|DISABLE)["']$/.test(m[1].trim()))loose.push(`${name(path)}: SetBlendMode(${m[1]})`);
  }
 }
 assert.deepEqual(loose,[]);
});

test('the scan catches a MOD blend', () => {
 assert.match(code('t:SetBlendMode("MOD") -- red'),/SetBlendMode\s*\(\s*["']MOD["']/);
 assert.doesNotMatch(code('-- once SetBlendMode("MOD")'),/["']MOD["']/);
});

test('Bag Item Levels ships its arrow art exactly as Tools/GenerateBagArrow.mjs draws it', () => {
 const shipped=readFileSync(join(root,'Media/BagArrow.tga'));
 assert.ok(shipped.equals(arrowTGA()),'Media/BagArrow.tga is out of date: run node Tools/GenerateBagArrow.mjs');
});

test('the arrow is crisp: a white fill, a solid dark outline and a clear pixel all round', () => {
 const tga=arrowTGA();
 assert.equal(tga[2],2,'uncompressed true colour');
 assert.equal(tga.readUInt16LE(12),SIZE);assert.equal(tga.readUInt16LE(14),SIZE);assert.equal(tga[16],32);
 const px=(x,y)=>{const at=18+(y*SIZE+x)*4;return {v:tga[at],a:tga[at+3]}};
 for(let i=0;i<SIZE;i++){
  for(const [x,y] of [[i,0],[i,SIZE-1],[0,i],[SIZE-1,i]])assert.equal(px(x,y).a,0,`edge pixel ${x},${y} clear`);
 }
 let white=0,dark=0;
 for(let y=0;y<SIZE;y++)for(let x=0;x<SIZE;x++){
  const p=px(x,y);
  if(p.a===255&&p.v===255)white++;
  if(p.a>=200&&p.v<=40)dark++;
 }
 assert.ok(white>150,`a solid white fill to tint (${white} px)`);
 // The first art's thin outline had 88 of these, too few to survive at 12.
 assert.ok(dark>150,`a thick dark outline that survives scaling down (${dark} px)`);
 // Points up: the head is wider than the stem, and the top is above the middle.
 const row=y=>{let n=0;for(let x=0;x<SIZE;x++)if(px(x,y).a>0)n++;return n};
 assert.ok(row(15)>row(24)+6,'a wide head over a narrower stem');
 assert.ok(row(3)<row(15),'the tip at the top');
});

// A shipped 32-bit TGA: its size and pixel readers (top-left origin, BGRA).
function readTGA(path){
 const tga=readFileSync(join(root,path));
 assert.equal(tga[2],2,`${path}: uncompressed true colour`);
 assert.equal(tga[16],32,`${path}: 32-bit, with alpha`);
 const w=tga.readUInt16LE(12),h=tga.readUInt16LE(14),top=(tga[17]&0x20)!==0;
 const at=(x,y)=>18+tga[0]+((top?y:h-1-y)*w+x)*4;
 const alpha=(x,y)=>tga[at(x,y)+3];
 const px=(x,y)=>{const i=at(x,y);return {r:tga[i+2],g:tga[i+1],b:tga[i],a:tga[i+3]}};
 return {tga,w,h,alpha,px};
}

test('the AFK screen ships its glow exactly as Tools/GenerateLogoGlow.mjs draws it', () => {
 const shipped=readFileSync(join(root,'Media/LogoGlow.tga'));
 assert.ok(shipped.equals(glowTGA()),'Media/LogoGlow.tga is out of date: run node Tools/GenerateLogoGlow.mjs');
 const {w,h,alpha}=readTGA('Media/LogoGlow.tga');
 assert.equal(w,GLOW_SIZE);assert.equal(h,GLOW_SIZE);
 // Soft and round: nothing at the edge, brightest in the middle.
 const mid=GLOW_SIZE/2;
 assert.equal(alpha(0,0),0);assert.equal(alpha(mid,0),0);assert.equal(alpha(0,mid),0);
 assert.ok(alpha(mid,mid)>=250,'bright in the middle');
 assert.ok(alpha(mid+32,mid)>0&&alpha(mid+32,mid)<alpha(mid+16,mid),'fades out toward the edge');
});

// The AFK banner: three 512x256 layers with the art in the top 243 rows.
const BANNER=['EraUIBannerShadow','EraUIBannerBase','EraUIBannerLetters'];
test('the AFK screen draws the banner in three layers, cut to the art\'s 243 rows', () => {
 const source=code(readFileSync(join(root,'Modules/AFKScreen.lua'),'utf8'));
 for(const n of BANNER)assert.match(source,new RegExp(`MEDIA\\.\\."${n}\\.tga"`),`AFKScreen.lua draws Media/${n}.tga`);
 assert.match(source,/BANNER_ROWS,BANNER_ASPECT=243\/256,512\/243/,'texcoords and shape from the 512x243 art');
 assert.match(source,/SetTexCoord\(0,1,0,BANNER_ROWS\)/,'every layer cut to the art');
});
test('the old square logo is gone and nothing draws it; the addon icon stays', () => {
 assert.equal(existsSync(join(root,'Media/EraUILogo.tga')),false,'Media/EraUILogo.tga removed');
 const users=shipped.filter(p=>/EraUILogo/.test(code(readFileSync(p,'utf8')))).map(name);
 assert.deepEqual(users,[]);
 assert.ok(existsSync(join(root,'Media/EraUIIcon.tga')),'Media/EraUIIcon.tga stays');
 assert.match(readFileSync(join(root,'EraUI.toc'),'utf8'),/## IconTexture: Interface\\AddOns\\EraUI\\Media\\EraUIIcon\.tga/);
});
test('each banner layer: 512x256, clear ground, nothing below the art or on the edges', () => {
 for(const n of BANNER){
  const {w,h,alpha}=readTGA(`Media/${n}.tga`);
  assert.equal(w,512,`${n} width`);assert.equal(h,256,`${n} height`);
  let clear=0,drawn=0,fullRows=0;
  for(let y=0;y<h;y++){
   let seen=0;
   for(let x=0;x<w;x++){
    const a=alpha(x,y);if(a===0)clear++;else drawn++;
    if(a>=8)seen++;
    if(y>=243)assert.equal(a,0,`${n}: row ${y} is below the art and clear, so the texcoords cut nothing`);
    if(x===0||x===w-1||y===0)assert.equal(a,0,`${n}: edge pixel ${x},${y} clear, so it never shows a hard edge`);
   }
   if(seen>w*.9)fullRows++;
  }
  // A box would cover whole rows. The shadow is blurred, so it spreads a
  // little wider than the letters and may cover a bit more of the ground.
  assert.equal(fullRows,0,`${n}: no row is covered edge to edge, so no box`);
  assert.ok(clear>w*h*(n==='EraUIBannerShadow'?.5:.6),`${n}: mostly clear ground (${clear} clear)`);
  assert.ok(drawn>20000,`${n}: the art is there (${drawn} drawn)`);
 }
});
test('the banner swirl keeps its violet with no dark box; the letters are grey to tint; the shadow is black', () => {
 const base=readTGA('Media/EraUIBannerBase.tga'),letters=readTGA('Media/EraUIBannerLetters.tga'),shadow=readTGA('Media/EraUIBannerShadow.tga');
 let violet=0,dark=0,grey=0,colour=0,bright=0,opaque=0,black=0,tinted=0,under=0,letterPx=0,soft=0;
 for(let y=0;y<256;y++)for(let x=0;x<512;x++){
  const b=base.px(x,y),l=letters.px(x,y),s=shadow.px(x,y);
  const lum=.3*b.r+.59*b.g+.11*b.b;
  if(b.a>=128&&b.b>b.r+40)violet++;
  if(b.a>=64&&lum<50)dark++;
  if(l.a>0){if(l.r===l.g&&l.g===l.b)grey++;else colour++}
  if(l.a>=128){opaque++;if(l.r>=150)bright++}
  if(s.a>0){if(s.r===0&&s.g===0&&s.b===0)black++;else tinted++}
  if(s.a>=16&&s.a<=200)soft++;
  if(l.a>200){letterPx++;if(s.a>100)under++}
 }
 assert.ok(violet>5000,`the swirl is violet (${violet} px)`);
 assert.equal(dark,0,'no dark ground left in the swirl layer: no box');
 assert.equal(colour,0,'every letter pixel is grey, so SetVertexColor gives the exact class colour');
 assert.ok(grey>20000&&bright>opaque*.9,`light letters (${bright} of ${opaque} bright)`);
 assert.equal(tinted,0,'the shadow is pure black');
 assert.ok(black>20000,'and it is there');
 assert.ok(under>letterPx*.95,`the shadow sits under the letters (${under} of ${letterPx})`);
 assert.ok(soft>5000,`the shadow is blurred, fading out at its edges, not a hard mask (${soft} part-clear px)`);
});

// The AFK class quote: IM Fell English Italic, shipped unmodified with its licence.
const QUOTE_FONT='Media/Fonts/IMFellEnglish-Italic.ttf';
function ttf(path){
 const f=readFileSync(join(root,path));
 const tables={};for(let i=0;i<f.readUInt16BE(4);i++){const o=12+i*16;tables[f.toString('latin1',o,o+4)]={off:f.readUInt32BE(o+8),len:f.readUInt32BE(o+12)}}
 const upem=f.readUInt16BE(tables.head.off+18),numH=f.readUInt16BE(tables.hhea.off+34);
 const c=tables.cmap.off;let sub;
 for(let i=0;i<f.readUInt16BE(c+2);i++){if(f.readUInt16BE(c+4+i*8)===3&&f.readUInt16BE(c+6+i*8)===1)sub=c+f.readUInt32BE(c+8+i*8)}
 const segX2=f.readUInt16BE(sub+6),ends=sub+14,starts=ends+segX2+2,deltas=starts+segX2,ranges=deltas+segX2;
 const glyph=cp=>{for(let i=0;i<segX2/2;i++){if(cp>f.readUInt16BE(ends+2*i))continue;const s=f.readUInt16BE(starts+2*i);if(cp<s)return 0;
  const d=f.readInt16BE(deltas+2*i),r=f.readUInt16BE(ranges+2*i);if(r===0)return(cp+d)&0xffff;
  const g=f.readUInt16BE(ranges+2*i+r+2*(cp-s));return g?(g+d)&0xffff:0}return 0};
 const advance=g=>f.readUInt16BE(tables.hmtx.off+4*Math.min(g,numH-1))/upem;
 // The full name, from the name table (platform 3, UTF-16BE).
 const nm=tables.name.off,count=f.readUInt16BE(nm+2),strings=nm+f.readUInt16BE(nm+4);let full='';
 for(let i=0;i<count;i++){const r=nm+6+i*12;if(f.readUInt16BE(r)===3&&f.readUInt16BE(r+6)===4){const len=f.readUInt16BE(r+8),off=f.readUInt16BE(r+10);
  full=Buffer.from(f.subarray(strings+off,strings+off+len)).swap16().toString('utf16le');break}}
 return {f,glyph,width:s=>{let w=0;for(const ch of s)w+=advance(glyph(ch.codePointAt(0)));return w},full};
}
// Every quote from Modules/AFKQuotes.lua, read as data.
function quotes(){
 const src=readFileSync(join(root,'Modules/AFKQuotes.lua'),'utf8');
 const unq=s=>s.replace(/\\(["\\])/g,'$1');
 return [...src.matchAll(/\{text="((?:[^"\\]|\\.)*)",speaker="((?:[^"\\]|\\.)*)",where="((?:[^"\\]|\\.)*)"/g)].map(m=>({text:unq(m[1]),speaker:unq(m[2]),where:unq(m[3])}));
}
test('the quote font ships unmodified as IM Fell English Italic, with its licence and a README line', () => {
 const source=code(readFileSync(join(root,'Modules/AFKScreen.lua'),'utf8'));
 assert.match(source,/local QUOTE_FONT=MEDIA\.\."Fonts\\\\IMFellEnglish-Italic\.ttf"/,'AFKScreen.lua uses the bundled italic');
 const font=ttf(QUOTE_FONT);
 assert.equal(font.f.readUInt32BE(0),0x00010000,'a TrueType font');
 assert.equal(font.full,'IM FELL English Italic','the italic cut, by its own name');
 const ofl=readFileSync(join(root,'Media/Fonts/IMFellEnglish-OFL.txt'),'utf8');
 assert.match(ofl,/Igino Marini/);assert.match(ofl,/SIL Open Font License, Version 1\.1/);
 const readme=readFileSync(join(root,'Media/Fonts/README.txt'),'utf8');
 assert.match(readme,/IM Fell English Italic by Igino Marini: SIL Open Font License 1\.1 \(IMFellEnglish-OFL\.txt\)/);
 assert.match(readme,/IMFellEnglish-Italic\.ttf/);
});
test('the quote font draws every character the quotes use, and the longest quote takes two lines', () => {
 const font=ttf(QUOTE_FONT),list=quotes();
 assert.equal(list.length,71,'all 71 quotes read');
 for(const ch of ['\u201C','\u201D','\u2014'])assert.ok(font.glyph(ch.codePointAt(0)),`the font has ${ch}`);
 for(const q of list)for(const ch of q.text+q.speaker+q.where)assert.ok(font.glyph(ch.codePointAt(0)),`the font has "${ch}" (${q.text})`);
 // The screen keeps a line at least QUOTE_EM of the font size wide; greedy
 // word wrap with the font's own widths, with 10% to spare, must give 2 lines.
 const em=Number(readFileSync(join(root,'Modules/AFKScreen.lua'),'utf8').match(/local QUOTE_SIZE,QUOTE_MIN,QUOTE_MAX,QUOTE_EM=\d+,\d+,\d+,(\d+)/)[1]);
 const lines=(s,width)=>{let n=1,cur=0;const sp=font.width(' ');for(const w of s.split(' ').map(font.width)){if(cur===0)cur=w;else if(cur+sp+w<=width)cur+=sp+w;else{n++;cur=w}}return n};
 for(const q of list)assert.ok(lines('\u201C'+q.text+'\u201D',em*.9)<=2,`two lines at most: ${q.text}`);
 // And the check itself bites: a width half as wide wraps the longest quote further.
 assert.ok(list.some(q=>lines('\u201C'+q.text+'\u201D',em*.45)>2),'a narrow line would need three');
});
test('the TOC loads the quotes just before the AFK screen', () => {
 const toc=readFileSync(join(root,'EraUI.toc'),'utf8').split(/\r?\n/).map(l=>l.trim());
 const q=toc.indexOf('Modules\\AFKQuotes.lua'),a=toc.indexOf('Modules\\AFKScreen.lua');
 assert.ok(q>0,'Modules\\AFKQuotes.lua is listed');
 assert.equal(a,q+1,'directly before Modules\\AFKScreen.lua');
});

test('Bag Item Levels uses a bundled font that is shipped with its licence', () => {
 const source=readFileSync(join(root,'Modules/BagItemLevels.lua'),'utf8');
 const font=source.match(/local FONT="Interface\\\\AddOns\\\\EraUI\\\\([^"]+)"/);
 assert.ok(font,'FONT points inside EraUI');
 const file=font[1].replace(/\\\\/g,'/');
 assert.ok(existsSync(join(root,file)),`${file} is shipped`);
 const base=file.replace(/-Regular\.ttf$/,'');
 assert.ok([`${base}-OFL.txt`,`${base}-LICENSE.txt`].some(f=>existsSync(join(root,f))),'with its licence beside it');
});
