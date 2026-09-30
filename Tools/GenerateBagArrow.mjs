// Original up-arrow art for Bag Item Levels: a white arrow with a dark
// outline, so the game can tint it green (upgrade) and flip it into a red
// down arrow (downgrade). 32x32, 32-bit TGA, top-left origin.
import {writeFile} from 'node:fs/promises';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=dirname(dirname(fileURLToPath(import.meta.url)));
const size=32;
// The arrow in pixel units, y growing downward: a head and a stem.
function inArrow(x,y){
 const headTop=3,headBase=17,half=12.5,cx=16;
 if(y>=headTop&&y<=headBase){
  const w=(y-headTop)/(headBase-headTop)*half;
  if(Math.abs(x-cx)<=w)return true;
 }
 return y>headBase-.5&&y<=29&&x>=11&&x<=21;
}
function near(x,y,r){
 for(let a=0;a<16;a++){
  const t=a/16*Math.PI*2;
  if(inArrow(x+Math.cos(t)*r,y+Math.sin(t)*r))return true;
 }
 return false;
}
const out=Buffer.alloc(size*size*4);
for(let y=0;y<size;y++)for(let x=0;x<size;x++){
 let fill=0,edge=0;
 for(let j=0;j<4;j++)for(let i=0;i<4;i++){
  const px=x+(i+.5)/4,py=y+(j+.5)/4;
  if(inArrow(px,py))fill++;else if(near(px,py,1.6))edge++;
 }
 const a=(fill+edge)/16,white=fill/Math.max(1,fill+edge);
 const v=Math.round(white*255),at=(y*size+x)*4;
 // BGRA
 out[at]=v;out[at+1]=v;out[at+2]=v;out[at+3]=Math.round(a*255);
}
const header=Buffer.alloc(18);
header[2]=2;header.writeUInt16LE(size,12);header.writeUInt16LE(size,14);header[16]=32;header[17]=0x28;
await writeFile(join(root,'Media/BagArrow.tga'),Buffer.concat([header,out]));
console.log('Media/BagArrow.tga written');
