// Original up-arrow art for Bag Item Levels: a white arrow with a thick dark
// outline, so the game can tint it green (upgrade) and flip it into a red
// down arrow (downgrade). It is drawn small (12 on a 37 bag slot), so the
// shape is bold and the outline wide enough to stay a clean edge once scaled
// down, with a clear pixel all round. 32x32, 32-bit TGA, top-left origin.
// Run: node Tools/GenerateBagArrow.mjs (Tools/TestBlendModes.mjs checks the
// shipped file is exactly this art).
import {writeFile} from 'node:fs/promises';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=dirname(dirname(fileURLToPath(import.meta.url)));
export const SIZE=32,OUTLINE=3;
// The arrow as a polygon in pixel units, y growing downward: a wide head and a
// short, thick stem.
const ARROW=[[16,4.5],[27.5,16],[21,16],[21,27.5],[11,27.5],[11,16],[4.5,16]];
function inside(x,y){
 let odd=false;
 for(let i=0,j=ARROW.length-1;i<ARROW.length;j=i++){
  const [xi,yi]=ARROW[i],[xj,yj]=ARROW[j];
  if((yi>y)!==(yj>y)&&x<(xj-xi)*(y-yi)/(yj-yi)+xi)odd=!odd;
 }
 return odd;
}
function edge(x,y){
 let best=Infinity;
 for(let i=0,j=ARROW.length-1;i<ARROW.length;j=i++){
  const [ax,ay]=ARROW[j],[bx,by]=ARROW[i];
  const dx=bx-ax,dy=by-ay,t=Math.max(0,Math.min(1,((x-ax)*dx+(y-ay)*dy)/(dx*dx+dy*dy)));
  best=Math.min(best,Math.hypot(x-ax-t*dx,y-ay-t*dy));
 }
 return best;
}
// Signed distance to the arrow's edge: negative inside.
const distance=(x,y)=>inside(x,y)?-edge(x,y):edge(x,y);
const clamp=v=>Math.max(0,Math.min(1,v));
// The whole TGA file.
export function arrowTGA(){
 const out=Buffer.alloc(SIZE*SIZE*4);
 for(let y=0;y<SIZE;y++)for(let x=0;x<SIZE;x++){
  // 4x4 samples a pixel: white inside, black in the outline, a soft pixel at each edge.
  let alpha=0,white=0;
  for(let j=0;j<4;j++)for(let i=0;i<4;i++){
   const d=distance(x+(i+.5)/4,y+(j+.5)/4);
   alpha+=clamp(OUTLINE+.5-d);white+=clamp(.5-d);
  }
  alpha/=16;white/=16;
  const v=alpha>0?Math.round(clamp(white/alpha)*255):0,at=(y*SIZE+x)*4;
  // BGRA
  out[at]=v;out[at+1]=v;out[at+2]=v;out[at+3]=Math.round(alpha*255);
 }
 const header=Buffer.alloc(18);
 header[2]=2;header.writeUInt16LE(SIZE,12);header.writeUInt16LE(SIZE,14);header[16]=32;header[17]=0x28;
 return Buffer.concat([header,out]);
}
if(process.argv[1]&&fileURLToPath(import.meta.url)===process.argv[1]){
 await writeFile(join(root,'Media/BagArrow.tga'),arrowTGA());
 console.log('Media/BagArrow.tga written');
}
