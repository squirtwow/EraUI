// Original, supersampled alpha masks for Thick Frames' rounded bar ends
// (Classic/ThickFrames.lua): a half circle for each end of a bar, its flat
// side fully opaque. Each is pinned to one end of a bar (or its track), half
// the bar's height wide and the bar's full height, with CLAMP wrapping: past
// its flat side the mask keeps that side's opaque column, so the rest of the
// bar is untouched. Run from the addon root.
import { writeFileSync } from 'node:fs';
const W = 32, H = 64, R = 32, SAMPLES = 4;
function cap(name, left) {
  const data = Buffer.alloc(18 + W * H * 4);
  data[2] = 2; // Uncompressed BGRA, top-left origin.
  data.writeUInt16LE(W, 12); data.writeUInt16LE(H, 14);
  data[16] = 32; data[17] = 0x28;
  // The circle's centre on the flat side, halfway down.
  const cx = left ? W : 0, cy = H / 2;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    let coverage = 0;
    for (let sy = 0; sy < SAMPLES; sy++) for (let sx = 0; sx < SAMPLES; sx++) {
      const px = x + (sx + .5) / SAMPLES, py = y + (sy + .5) / SAMPLES;
      if (Math.hypot(px - cx, py - cy) <= R) coverage += 1 / (SAMPLES * SAMPLES);
    }
    // The flat side's column is the bar's body: always fully opaque.
    if ((left && x === W - 1) || (!left && x === 0)) coverage = 1;
    const offset = 18 + (y * W + x) * 4;
    data[offset] = data[offset + 1] = data[offset + 2] = 255;
    data[offset + 3] = Math.round(255 * coverage);
  }
  writeFileSync(`Media/${name}.tga`, data);
}
cap('ThickBarCapLeft', true);
cap('ThickBarCapRight', false);
console.log('Generated Thick Frames bar end masks.');
