import assert from 'node:assert/strict';
import {deflateSync} from 'node:zlib';
import test from 'node:test';
import {parseHudSheet} from './hud-sheet.mjs';

const chunk = (kind, body) => {
  const header = Buffer.alloc(8); header.writeUInt32BE(body.length); header.write(kind, 4);
  return Buffer.concat([header, body, Buffer.alloc(4)]);
};
function sheet(metadata, width = 128, height = 64) {
  const header = Buffer.alloc(13); header.writeUInt32BE(width); header.writeUInt32BE(height, 4);
  const text = Buffer.concat([Buffer.from('Description\0\0'), deflateSync(metadata)]);
  return Buffer.concat([Buffer.from('89504e470d0a1a0a', 'hex'), chunk('IHDR', header), chunk('zTXt', text), chunk('IEND', Buffer.alloc(0))]);
}
const metadata = '# BEGIN DMI\nwidth = 32\nheight = 32\nstate = "animated"\ndirs = 2\nframes = 2\nstate = "template"\ndirs = 1\nframes = 1\n# END DMI';
test('HUD frame addresses count every preceding direction and animation frame', () => {
  const result = parseHudSheet(sheet(metadata), ['template']);
  assert.deepEqual(result.states.template, {x: 0, y: 32});
  assert.equal(result.width, 128); assert.equal(result.height, 64); assert.equal(result.tile, 32);
});
test('missing state, malformed chunks and out-of-sheet cells fail closed', () => {
  assert.throws(() => parseHudSheet(sheet(metadata), ['absent']), /Missing HUD state/);
  assert.throws(() => parseHudSheet(Buffer.from('not a PNG'), ['template']), /PNG/);
  assert.throws(() => parseHudSheet(sheet(metadata).subarray(0, 40), ['template']), /chunk/);
  assert.throws(() => parseHudSheet(sheet(metadata, 32, 32), ['template']), /bounds/);
});
