// Build-sized raster import only; artwork is generated once, not drawn by the UI.
import { readFile, writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { applyLettering } from './lettering.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const sources = ['file-disl', 'file-md', 'file-atmo', 'file-pem'];
const colors = {
  'file-disl': ['#426b9a'], 'file-md': ['#bd9a31'],
  'file-atmo': ['#36877f', '#205458'], 'file-pem': ['#795891'],
};
const run = args => execFileSync('magick', args, { maxBuffer: 1024 * 1024 });
for (const name of sources) {
  const saved = join(here, '../../../../sources/computer/files', name + '.png');
  const palette = join(here, '../../../../../docs/art-reference/palettes/file-icons', name + '.palette.png');
  run(['#202c2d', '#f1ead4', ...colors[name], '#ff00ff'].map(color => 'xc:' + color)
    .concat(['+append', palette]));
  run([saved, '-alpha', 'on', '-fuzz', '18%', '-transparent', '#ff00ff', '-trim', '+repage',
    '-sample', '26x32!', '-background', '#ff00ff', '-alpha', 'remove', '-alpha', 'off',
    '+dither', '-remap', palette, '-fuzz', '0%', '-transparent', '#ff00ff',
    '-background', 'none', '-gravity', 'center', '-extent', '32x32',
    'PNG32:' + join(here, name + '.png')]);
}

applyLettering(here);

for (const name of sources) {
  const file = join(here, name + '.png');
  const bytes = run([file, '-depth', '8', 'RGBA:-']);
  if (bytes.length !== 32 * 32 * 4) throw Error(name + ': expected 32x32 RGBA');
  const palette = [], indexes = new Map(), pixels = [];
  for (let i = 0; i < bytes.length; i += 4) {
    if (name !== 'computer' && bytes[i + 3] !== 0 && bytes[i + 3] !== 255) throw Error(name + ': fractional alpha');
    const color = bytes[i + 3] === 0 ? '#00000000' : '#' + bytes.subarray(i, i + 4).toString('hex');
    if (!indexes.has(color)) { indexes.set(color, palette.length); palette.push(color); }
    pixels.push(indexes.get(color));
  }
  const rows = Array.from({ length: 32 }, (_, row) => pixels.slice(row * 32, row * 32 + 32));
  const header = JSON.stringify({ width: 32, height: 32, palette }, null, 2).slice(0, -2);
  const encoded = header + ',\n  "rows": [\n' + rows.map(row => '    ' + JSON.stringify(row)).join(',\n') + '\n  ]\n}\n';
  await writeFile(join(here, name + '.pixels.json'), encoded);
  console.log(`${name}: 32x32, ${palette.length} colors including transparency`);
}
