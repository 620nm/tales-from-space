// The residue ladder: what settled dirt draws at one blast and past two.
// The engine discloses one composite per tile off this file -- a part
// per resting kind, each on its own tier -- so these rows pin the
// numbers the specs assert by ledger and by sight: the kinds, the
// per-blast counts, the tiers, and the layer order that puts dirt
// over paint and under spills.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("residue kinds rest one blast of shards and fallout and cake past two", async () => {
  const kinds = await read("content/lib/residue_kinds.luau");
  assert.match(kinds, /shard_kind = 0/);
  assert.match(kinds, /cloudy_kind = 1/);
  assert.match(kinds, /pellets_per_volley = 15/);
  assert.match(kinds, /cloudy_per_blast = 15/);
  assert.match(kinds, /\{ at = 1, sprites = \{ "blast_shards" \} \}/);
  assert.match(kinds, /\{ at = 1, sprites = \{ "dust" \} \}/);
  assert.match(kinds, /at = 32/);
  for (const flat of [0, 1, 2, 3]) {
    assert.match(kinds, new RegExp(`"dirt_flat_${flat}"`));
  }
});

test("residue appearances dress both settled kinds on the residue layer", async () => {
  const appearances = await read("content/residue_appearances.luau");
  assert.match(appearances, /visual_layer = "residue"/);
  assert.match(appearances, /\[residue_kinds\.shard_kind\] = \{ tiers = residue_kinds\.shard_tiers \}/);
  assert.match(appearances, /\[residue_kinds\.cloudy_kind\] = \{ tiers = residue_kinds\.cloudy_tiers \}/);
});

test("every tier sprite is baked by the dirt family", async () => {
  const ron = await read("assets/sprites/13-dirt.ron");
  assert.match(ron, /Sprite\("blast_shards", "shards", s\)/);
  assert.match(ron, /Sprite\("dust", "dust", s\)/);
  for (const flat of [0, 1, 2, 3]) {
    assert.match(ron, new RegExp(`Sprite\\("dirt_flat_${flat}", "dirt-flat-${flat}", s\\)`));
  }
});

test("the residue layer draws between paint and spills", async () => {
  const compositions = await read("content/compositions.luau");
  const decal = compositions.indexOf('{ id = "decal"');
  const residue = compositions.indexOf('{ id = "residue"');
  const matter = compositions.indexOf('{ id = "matter_ground"');
  assert.ok(decal !== -1 && residue !== -1 && matter !== -1, "all three layers declared");
  assert.ok(decal < residue && residue < matter, "dirt over paint, under spills");
});
