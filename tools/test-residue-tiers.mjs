// The residue ladder: what settled dust draws at one blast and past two.
// The engine discloses the dominant kind per tile off this file, so these
// rows pin the numbers the specs assert by ledger and by sight -- the
// kind, the per-blast count, the tiers, and the layer order that puts
// dirt over paint and under spills.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("residue kinds rest one blast of dust and cake past two", async () => {
  const kinds = await read("content/lib/residue_kinds.luau");
  assert.match(kinds, /dust_kind = 0/);
  assert.match(kinds, /dust_per_blast = 15/);
  assert.match(kinds, /\{ at = 1, sprites = \{ "blast_shards" \} \}/);
  assert.match(kinds, /at = 32/);
  for (const flat of [0, 1, 2, 3]) {
    assert.match(kinds, new RegExp(`"dirt_flat_${flat}"`));
  }
});

test("residue appearances dress the settled kind on the residue layer", async () => {
  const appearances = await read("content/residue_appearances.luau");
  assert.match(appearances, /visual_layer = "residue"/);
  assert.match(appearances, /\[residue_kinds\.dust_kind\] = \{ tiers = residue_kinds\.tiers \}/);
});

test("every tier sprite is baked by the dirt family", async () => {
  const ron = await read("assets/sprites/13-dirt.ron");
  assert.match(ron, /Sprite\("blast_shards", "shards", s\)/);
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
