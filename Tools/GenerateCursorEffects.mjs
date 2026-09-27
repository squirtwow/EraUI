// Original, supersampled alpha artwork. Run from the addon root with Node.
import { writeFileSync } from 'node:fs';
function texture(name, size, alpha) {
  const data = Buffer.alloc(18 + size * size * 4);
  data[2] = 2; // Uncompressed BGRA, top-left origin.
  data.writeUInt16LE(size, 12); data.writeUInt16LE(size, 14);
  data[16] = 32; data[17] = 0x28;
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    let coverage = 0;
    for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) {
      const radius = Math.hypot(x + (sx + .5) / 4 - size / 2, y + (sy + .5) / 4 - size / 2) / (size / 2);
      coverage += alpha(radius) / 16;
    }
    const offset = 18 + (y * size + x) * 4;
    data[offset] = data[offset + 1] = data[offset + 2] = 255;
    data[offset + 3] = Math.round(255 * coverage);
  }
  writeFileSync(`Media/${name}.tga`, data);
}
texture('CursorCastRing', 128, r => r >= .88 && r <= .98 ? 1 : 0);
texture('CursorTrailDot', 32, r => Math.pow(Math.max(0, 1 - r * r), 2));
console.log('Generated original cursor cast ring and trail textures.');
