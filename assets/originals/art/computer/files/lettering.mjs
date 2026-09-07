// Bake the supplied font into the two editable letter fields; preserve all other pixels.
import { execFileSync } from 'node:child_process';
import { join } from 'node:path';

const ink = [0xf1, 0xea, 0xd4, 0xff];
const labels = {
  'file-disl': { color: [0x42, 0x6b, 0x9a, 0xff], clear: [8, 7, 17, 22], rows: [['Di', 8, 7], ['SL', 8, 20]] },
  'file-md': { color: [0xbd, 0x9a, 0x31, 0xff], clear: [8, 8, 17, 13], rows: [['MD', 8, 12]] },
};
const run = (args, input) => execFileSync('magick', args, { input, maxBuffer: 1024 * 1024 });

export function applyLettering(directory) {
  const font = join(directory, '../../../../../docs/art-reference/fonts/BoldsPixels.ttf');
  for (const [name, spec] of Object.entries(labels)) {
    const file = join(directory, name + '.png');
    const pixels = run([file, '-depth', '8', 'RGBA:-']);
    if (pixels.length !== 32 * 32 * 4) throw Error(name + ': expected native 32px sprite');
    const original = Buffer.from(pixels);
    const [left, top, width, height] = spec.clear;
    const set = (x, y, color) => pixels.set(color, (y * 32 + x) * 4);
    for (let y = top; y < top + height; y++) {
      for (let x = left; x < left + width; x++) set(x, y, spec.color);
    }
    for (const [text, x, y] of spec.rows) {
      const glyph = join(directory, '../../../../../docs/art-reference/examples', 'bold-' + text + '.png');
      run(['-background', 'none', '-fill', '#f1ead4', '-density', '72', '-font', font, '-pointsize', '16',
        '+antialias', 'label:' + text, '-trim', '+repage', 'PNG32:' + glyph]);
      const [w, h] = run(['identify', '-format', '%w %h', glyph]).toString().split(' ').map(Number);
      if (x < left || y < top || x + w > left + width || y + h > top + height) {
        throw Error(name + ': font overflows the existing letter field');
      }
      const mask = run([glyph, '-alpha', 'extract', '-threshold', '50%', '-depth', '8', 'GRAY:-']);
      for (let row = 0; row < h; row++) {
        for (let col = 0; col < w; col++) if (mask[row * w + col]) set(x + col, y + row, ink);
      }
    }
    for (let y = 0; y < 32; y++) for (let x = 0; x < 32; x++) {
      if (x >= left && x < left + width && y >= top && y < top + height) continue;
      const i = (y * 32 + x) * 4;
      if (!pixels.subarray(i, i + 4).equals(original.subarray(i, i + 4))) {
        throw Error(name + ': changed a pixel outside the lettering');
      }
    }
    run(['-size', '32x32', '-depth', '8', 'RGBA:-', 'PNG32:' + file], pixels);
  }
}
