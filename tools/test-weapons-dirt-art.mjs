// Presence for the frag-grenade art: the weapons and dirt sprite
// families plus the two sound entries. The bake itself is the rest of
// the contract -- `bake-atlas` fails closed on an unknown sheet, state
// or dir, so these rows only survive if the pinned tg checkout carries
// every state they name.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("weapons family declares the frag grenade's rest and armed cells", async () => {
  const ron = await read("assets/sprites/12-weapons.ron");
  assert.match(ron, /\("grenade", "obj\/weapons\/grenade\.dmi"\)/);
  assert.match(ron, /\("frag", Dmi\("@grenade", "frag", 0\)\)/);
  assert.match(ron, /\("frag_active", Dmi\("@grenade", "frag_active", 0\)\)/);
});

test("weapons family declares the flying fragment's pellet cell", async () => {
  const ron = await read("assets/sprites/12-weapons.ron");
  assert.match(ron, /\("projectiles", "obj\/weapons\/guns\/projectiles\.dmi"\)/);
  assert.match(ron, /\("shrapnel", Dmi\("@projectiles", "pellet", 0\)\)/);
});

test("dirt family declares junctions, flats, dust, shards, scorch and blast fire", async () => {
  const ron = await read("assets/sprites/13-dirt.ron");
  assert.match(ron, /\("dirt", "effects\/dirt\.dmi"\)/);
  assert.match(ron, /\("dirt_misc", "effects\/dirt_misc\.dmi"\)/);
  assert.match(ron, /\("effects", "effects\/effects\.dmi"\)/);
  assert.match(ron, /\("debris", "obj\/debris\.dmi"\)/);
  assert.match(ron, /Junctions\("dirt", "dirt"\)/);
  for (const flat of [0, 1, 2, 3]) {
    assert.match(ron, new RegExp(`Sprite\\("dirt_flat_${flat}", "dirt-flat-${flat}", s\\)`));
  }
  assert.match(ron, /Sprite\("dust", "dust", s\)/);
  assert.match(ron, /Sprite\("blast_shards", "shards", s\)/);
  assert.match(ron, /Directions\("scorch", "scorch"\)/);
  assert.match(ron, /AnimOnce\("blast_fire", "explosion", s\)/);
});

test("sound roster configures the grenade arm click and the blast", async () => {
  const ron = await read("assets/sounds.ron");
  assert.match(ron, /\("grenade_arm", "items\/weapons\/armbomb\.ogg"\)/);
  assert.match(ron, /\("explosion", "effects\/explosion\/explosion1\.ogg"\)/);
});

test("sound roster configures the grenade handling pair", async () => {
  const ron = await read("assets/sounds.ron");
  assert.match(ron, /\("grenade_pickup", "items\/handling\/grenade\/grenade_pick_up\.ogg"\)/);
  assert.match(ron, /\("grenade_drop", "items\/handling\/grenade\/grenade_drop\.ogg"\)/);
});
