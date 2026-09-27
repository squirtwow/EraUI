// Original, supersampled alpha masks for portrait crowd-control icons: the
// portrait circle joined with the level badge circle, so a shown icon covers
// the whole badge. Geometry is in unit-frame units (Classic/UnitFrames.lua:
// 64-unit portrait; level text centred 23 below and 19-20 across from the
// portrait centre). The mask spans BOX units around the portrait centre, which
// Modules/PortraitDebuffs.lua uses as the icon size. Run from the addon root.
import { writeFileSync } from 'node:fs';
const SIZE = 128, BOX = 88, PORTRAIT_RADIUS = 31, BADGE_RADIUS = 13, BADGE_DOWN = 23;
function mask(name, badgeAcross) {
  const data = Buffer.alloc(18 + SIZE * SIZE * 4);
  data[2] = 2; // Uncompressed BGRA, top-left origin.
  data.writeUInt16LE(SIZE, 12); data.writeUInt16LE(SIZE, 14);
  data[16] = 32; data[17] = 0x28;
  const unit = BOX / SIZE;
  const inside = (ux, uy) => Math.hypot(ux, uy) <= PORTRAIT_RADIUS
    || Math.hypot(ux - badgeAcross, uy - BADGE_DOWN) <= BADGE_RADIUS;
  for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
    let coverage = 0;
    for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) {
      const ux = (x + (sx + .5) / 4 - SIZE / 2) * unit;
      const uy = (y + (sy + .5) / 4 - SIZE / 2) * unit; // Down is positive.
      if (inside(ux, uy)) coverage += 1 / 16;
    }
    const offset = 18 + (y * SIZE + x) * 4;
    data[offset] = data[offset + 1] = data[offset + 2] = 255;
    data[offset + 3] = Math.round(255 * coverage);
  }
  writeFileSync(`Media/${name}.tga`, data);
}
mask('PortraitCCMaskLeft', -19); // Player frame: badge below-left of the portrait.
mask('PortraitCCMaskRight', 20); // Target and focus frames: badge below-right.
console.log('Generated original portrait crowd-control masks.');
