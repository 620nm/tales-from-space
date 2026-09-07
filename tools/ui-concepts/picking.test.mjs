import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {runInNewContext} from 'node:vm';
import test from 'node:test';

const window = {};
runInNewContext(await readFile(new URL('./picking.js', import.meta.url), 'utf8'), {window});
const {pick, opaqueAt} = window.ConceptPicking;
const primitive = (id, alpha, geometry = {}) => ({id, x: 0, y: 0, width: 8, height: 8,
  raster: {width: 4, height: 4, alpha: Uint8Array.from(alpha)}, ...geometry});
const floor = primitive('floor', Array(16).fill(255));
const lower = primitive('pipe1', [0,255,0,0, 0,255,0,0, 0,255,0,0, 0,255,0,0]);
const upper = primitive('pipe3', [0,0,0,0, 0,0,0,0, 255,255,255,255, 0,0,0,0]);
const cable = primitive('cable', [0,0,0,0, 0,0,0,0, 0,255,0,0, 0,0,0,0]);

test('transparent source pixels fall through each overlapping draw layer', () => {
  const list = [floor, lower, upper, cable];
  assert.equal(pick(list, 3, 1), lower);
  assert.equal(pick(list, 7, 5), upper);
  assert.equal(pick(list, 3, 5), cable);
  assert.equal(pick(list, 7, 7), floor);
});
test('frontmost opaque primitive follows supplied render order', () => {
  assert.equal(pick([floor, cable, upper, lower], 3, 5), lower);
  assert.equal(pick([floor, lower, cable, upper], 3, 5), upper);
  assert.equal(pick([], 3, 5), null);
});
test('source sampling inverts translated nonuniform destination scaling', () => {
  const moved = {...lower, x: 10.25, y: 20.5, width: 12, height: 20};
  assert.equal(opaqueAt(moved, 13.249, 20.5), false);
  assert.equal(opaqueAt(moved, 13.25, 20.5), true);
  assert.equal(opaqueAt(moved, 16.249, 40.499), true);
  assert.equal(opaqueAt(moved, 16.25, 20.5), false);
  assert.equal(opaqueAt(moved, 13.25, 40.5), false);
});
test('source bounds do not bleed and any nonzero alpha is visible', () => {
  const faint = primitive('faint', [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,255]);
  assert.equal(opaqueAt(faint, 0, 0), true);
  assert.equal(opaqueAt(faint, -0.001, 0), false);
  assert.equal(opaqueAt(faint, 8, 7), false);
  assert.equal(opaqueAt(faint, 7, 8), false);
  assert.equal(opaqueAt(faint, 7.999, 7.999), true);
  assert.equal(opaqueAt(faint, NaN, 0), false);
  assert.equal(opaqueAt({...faint, width: 0}, 0, 0), false);
});
