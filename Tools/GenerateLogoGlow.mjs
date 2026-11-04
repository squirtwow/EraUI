// Original soft radial glow for the AFK screen: white with a smooth alpha
// falloff to zero at the edge, so the game tints it (violet behind the logo,
// black for the ground shadow). 128x128, 32-bit TGA, top-left origin.
// Run: node Tools/GenerateLogoGlow.mjs (Tools/TestBlendModes.mjs checks the
// shipped file is exactly this art).
import {writeFile} from 'node:fs/promises';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
const root=dirname(dirname(fileURLToPath(import.meta.url)));
export const GLOW_SIZE=128;
const size=GLOW_SIZE,half=size/2;
// Alpha at a distance r from the centre, 0 at the middle and 1 at the edge.
export function falloff(r){
 if(r>=1)return 0;
 const s=1-(3*r*r-2*r*r*r); // smoothstep from the edge in
 return Math.pow(s,1.2);
}
export function glowTGA(){
 const out=Buffer.alloc(size*size*4);
 for(let y=0;y<size;y++)for(let x=0;x<size;x++){
  let a=0;
  for(let j=0;j<4;j++)for(let i=0;i<4;i++){
   const dx=(x+(i+.5)/4-half)/half,dy=(y+(j+.5)/4-half)/half;
   a+=falloff(Math.hypot(dx,dy));
  }
  const at=(y*size+x)*4;
  // BGRA: white, only the alpha carries the glow.
  out[at]=255;out[at+1]=255;out[at+2]=255;out[at+3]=Math.round(a/16*255);
 }
 // The glow is round, fades to nothing at the edge and peaks in the middle.
 const alpha=(x,y)=>out[(y*size+x)*4+3];
 assert.equal(alpha(0,0),0);assert.equal(alpha(0,half),0);
 assert.ok(alpha(half,half)>=250);
 assert.equal(alpha(half+20,half),alpha(half-21,half));
 const header=Buffer.alloc(18);
 header[2]=2;header.writeUInt16LE(size,12);header.writeUInt16LE(size,14);header[16]=32;header[17]=0x28;
 return Buffer.concat([header,out]);
}
if(process.argv[1]&&fileURLToPath(import.meta.url)===process.argv[1]){
 await writeFile(join(root,'Media/LogoGlow.tga'),glowTGA());
 console.log('Media/LogoGlow.tga written');
}
