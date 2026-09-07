// Read local DMI state addresses; the browser decodes the original PNG unchanged.
import {execFileSync} from 'node:child_process';
import {inflateSync} from 'node:zlib';

export function parseHudSheet(bytes, names) {
  if (!bytes.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex'))) throw new Error('Expected HUD PNG');
  let width, height, description, ended = false;
  for (let offset = 8; offset < bytes.length;) {
    if (offset + 12 > bytes.length) throw new Error('Truncated PNG chunk');
    const length = bytes.readUInt32BE(offset), kind = bytes.toString('ascii', offset + 4, offset + 8);
    if (offset + 12 + length > bytes.length) throw new Error('Invalid PNG chunk length');
    const data = bytes.subarray(offset + 8, offset + 8 + length);
    if (kind === 'IHDR') {
      if (length !== 13) throw new Error('Invalid PNG header');
      width = data.readUInt32BE(0); height = data.readUInt32BE(4);
    }
    if (kind === 'zTXt') {
      const split = data.indexOf(0);
      if (data.toString('utf8', 0, split) === 'Description') {
        if (data[split + 1] !== 0) throw new Error('Unsupported DMI metadata compression');
        description = inflateSync(data.subarray(split + 2), {maxOutputLength: 1024 * 1024}).toString('utf8');
      }
    }
    offset += 12 + length;
    if (kind === 'IEND') { ended = true; break; }
  }
  if (!ended || !description || !width || !height || width > 4096 || height > 4096) throw new Error('Incomplete HUD PNG');
  const entries = [...description.matchAll(/^\s*state\s*=\s*"([^"]*)"\s*$/gm)];
  const header = description.slice(0, entries[0]?.index);
  const tile = Number(header.match(/\bwidth\s*=\s*(\d+)/)?.[1]);
  if (tile !== 32 || Number(header.match(/\bheight\s*=\s*(\d+)/)?.[1]) !== tile || width % tile || height % tile) throw new Error('Expected 32px HUD cells');
  const states = {}, columns = width / tile, capacity = columns * height / tile;
  let cell = 0;
  entries.forEach((entry, index) => {
    const metadata = description.slice(entry.index + entry[0].length, entries[index + 1]?.index);
    const dirs = Number(metadata.match(/\bdirs\s*=\s*(\d+)/)?.[1] ?? 1);
    const frames = Number(metadata.match(/\bframes\s*=\s*(\d+)/)?.[1] ?? 1);
    if (!Number.isSafeInteger(dirs * frames) || dirs < 1 || frames < 1 || cell + dirs * frames > capacity) throw new Error('HUD state exceeds sheet bounds');
    if (names.includes(entry[1])) states[entry[1]] = {x: cell % columns * tile, y: Math.floor(cell / columns) * tile};
    cell += dirs * frames;
  });
  for (const name of names) if (!states[name]) throw new Error(`Missing HUD state: ${name}`);
  return {width, height, tile, states};
}

export async function loadHudSheet(tg, expectedRevision) {
  const revision = execFileSync('git', ['-C', tg, 'rev-parse', 'HEAD'], {encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']}).trim();
  if (revision !== expectedRevision.trim()) throw new Error('TG checkout differs from assets/tg-revision');
  const path = 'icons/hud/screen_midnight.dmi';
  const bytes = execFileSync('git', ['-C', tg, 'show', `${revision}:${path}`], {maxBuffer: 8 * 1024 * 1024, stdio: ['ignore', 'pipe', 'pipe']});
  const sheet = parseHudSheet(bytes, ['template', 'template_small', 'suit', 'gloves', 'shoes']);
  return {...sheet, path, revision, image: `data:image/png;base64,${bytes.toString('base64')}`};
}
