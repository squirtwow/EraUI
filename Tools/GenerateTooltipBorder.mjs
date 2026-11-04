// Original neutral-grey tooltip art. Eight strips follow BackdropTemplate's
// documented L/R/T/B/TL/TR/BL/BR layout, with one-pixel sampling gutters.
import {writeFile} from 'node:fs/promises';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {deflateSync} from 'node:zlib';
import assert from 'node:assert/strict';
const root=dirname(dirname(fileURLToPath(import.meta.url)));
const tile=16,width=128,height=16;
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
function distance(x,y,w,h){
 const radius=5,qx=Math.abs(x-w/2)-(w/2-radius),qy=Math.abs(y-h/2)-(h/2-radius);
 return Math.hypot(Math.max(qx,0),Math.max(qy,0))+Math.min(Math.max(qx,qy),0)-radius;
}
function pixel(x,y,w,h){
 const d=distance(x,y,w,h),depth=-d;
 if(depth<0||depth>=3.2)return [0,0,0,0];
 const nx=(distance(x+.02,y,w,h)-d)/.02,ny=(distance(x,y+.02,w,h)-d)/.02;
 const light=-(nx+ny)*.707;
 let value;
 if(depth<.65)value=.12;
 else if(depth<1.35)value=.76+.1*light;
 else if(depth<2.05)value=.5+.08*light;
 else if(depth<2.7)value=.14;
 else value=.3-.04*light;
 const grey=Math.round(clamp(value,0,1)*255);
 return [grey,grey,grey,255];
}
function sample(fn,x,y,step=1){
 const out=[0,0,0,0];
 for(let j=0;j<4;j++)for(let i=0;i<4;i++){
  const p=fn(x+(i+.5)*step/4,y+(j+.5)*step/4);
  for(let c=0;c<3;c++)out[c]+=p[c]*p[3]/255;
  out[3]+=p[3];
 }
 if(!out[3])return [0,0,0,0];
 return [Math.round(out[0]*255/out[3]),Math.round(out[1]*255/out[3]),Math.round(out[2]*255/out[3]),Math.round(out[3]/16)];
}
const rgba=Buffer.alloc(width*height*4);
for(let t=0;t<8;t++)for(let y=0;y<tile;y++)for(let x=0;x<tile;x++){
 const u=(clamp(x,1,14)-1)*16/14,v=(clamp(y,1,14)-1)*16/14;
 const p=sample((a,b)=>{
  if(t===0)return pixel(a,32,96,96);
  if(t===1)return pixel(80+a,32,96,96);
  // Native backdrop UVs rotate these vertical strips into horizontal edges.
  if(t===2)return pixel(32,a,96,96);
  if(t===3)return pixel(32,80+a,96,96);
  return pixel((t%2?80:0)+a,(t>=6?80:0)+b,96,96);
 },u,v,16/14);
 const at=(y*width+t*tile+x)*4;rgba.set(p,at);
}
const header=Buffer.alloc(18);header[2]=2;header.writeUInt16LE(width,12);header.writeUInt16LE(height,14);header[16]=32;header[17]=0x28;
const bgra=Buffer.from(rgba);
for(let i=0;i<bgra.length;i+=4){assert.equal(rgba[i],rgba[i+1]);assert.equal(rgba[i+1],rgba[i+2]);[bgra[i],bgra[i+2]]=[bgra[i+2],bgra[i]];}
await writeFile(join(root,'Media/TooltipBorder.tga'),Buffer.concat([header,bgra]));

// Inspection preview drawn from the generated atlas, using the same UV crop
// and rotation as the game's BackdropTemplate. No external image dependency.
function borderAt(x,y,w,h){
 let t,u,v;
 if(x<16&&y<16){t=4;u=x;v=y;}
 else if(x>=w-16&&y<16){t=5;u=x-w+16;v=y;}
 else if(x<16&&y>=h-16){t=6;u=x;v=y-h+16;}
 else if(x>=w-16&&y>=h-16){t=7;u=x-w+16;v=y-h+16;}
 else if(x<16){t=0;u=x;v=8;}
 else if(x>=w-16){t=1;u=x-w+16;v=8;}
 else if(y<16){t=2;u=y;v=8;}
 else if(y>=h-16){t=3;u=y-h+16;v=8;}
 else return [0,0,0,0];
 const sx=t*16+clamp(Math.round(1+u*14/16),1,14),sy=clamp(Math.round(1+v*14/16),1,14);
 return [...rgba.subarray((sy*width+sx)*4,(sy*width+sx)*4+4)];
}
const pw=360,ph=200,scan=Buffer.alloc((pw*4+1)*ph);
for(let y=0;y<ph;y++)for(let x=0;x<pw;x++){
 let rgb=[89,66,47];const tx=x-28,ty=y-24,w=304,h=152;
 if(tx>=0&&ty>=0&&tx<w&&ty<h){
  if(tx>=3&&ty>=3&&tx<w-3&&ty<h-3)rgb=rgb.map(v=>Math.round(v*.1+4*.9));
  const p=borderAt(tx,ty,w,h),a=p[3]/255;rgb=rgb.map((v,c)=>Math.round(p[c]*a+v*(1-a)));
 }
 scan.set([...rgb,255],y*(pw*4+1)+1+x*4);
}
function crc32(buf){let c=0xffffffff;for(const b of buf){c^=b;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0);}return(c^0xffffffff)>>>0;}
function chunk(type,data){const t=Buffer.from(type),n=Buffer.alloc(4),c=Buffer.alloc(4);n.writeUInt32BE(data.length);c.writeUInt32BE(crc32(Buffer.concat([t,data])));return Buffer.concat([n,t,data,c]);}
const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(pw,0);ihdr.writeUInt32BE(ph,4);ihdr[8]=8;ihdr[9]=6;
await writeFile(join(root,'Tools/TooltipBorderPreview.png'),Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',ihdr),chunk('IDAT',deflateSync(scan)),chunk('IEND',Buffer.alloc(0))]));
console.log('Generated neutral 128x16 tooltip border and atlas-rendered preview.');
