import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";

const read = (path) => readFile(new URL(path, import.meta.url), "utf8");
const manifest = JSON.parse(await read("../editor/manifest.json"));
const editor = await read("../docs/EDITOR.md");
const standard = await read("../content/blends/standard_air.luau");
const compositions = await read("../content/compositions.luau");

test("both modes offer the blend lens turf paint breathes under", () => {
  for (const [mode, declaration] of Object.entries(manifest.modes)) {
    assert(declaration.lenses.includes("surface"), `${mode} keeps surface`);
    assert(declaration.lenses.includes("blend"), `${mode} offers blend`);
  }
});

test("lattice is turf, not a placement prototype", () => {
  for (const [mode, declaration] of Object.entries(manifest.modes)) {
    const ids = declaration.prototypes.map((p) => p.id);
    assert(!ids.includes("lattice"), `${mode} has no lattice prototype`);
    assert(!ids.includes("catwalk"), `${mode} has no catwalk prototype`);
  }
  assert.match(compositions, /id = "lattice"/);
  assert.match(compositions, /id = "catwalk"/);
  assert.doesNotMatch(editor, /bare entry admits it/);
});

test("fresh turf opens breathable on the pack default", () => {
  assert.match(standard, /id = "standard_air"/);
  assert.match(standard, /default = true/);
  assert.match(editor, /`standard_air`/);
  assert.match(editor, /never touches `painted`/);
});

test("the lens table covers walls and explicit override", () => {
  assert.match(compositions, /gas_blocking = true/);
  assert.match(editor, /Walls read as nothing/);
  assert.match(editor, /explicit override/);
  assert.match(editor, /atmosphere_blend/);
  assert.match(editor, /eraser is the inherit/);
});
