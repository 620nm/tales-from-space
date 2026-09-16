import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";

const read = (path) => readFile(new URL(path, import.meta.url), "utf8");
const manifest = JSON.parse(await read("../editor/manifest.json"));
const editor = await read("../docs/EDITOR.md");
const breathable = await read("../content/blends/ideal_air.luau");
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

test("fresh turf auto-paints the breathable pack default", () => {
  assert.match(breathable, /id = "ideal_air"/);
  assert.match(breathable, /default = true/);
  assert.match(editor, /`ideal_air`/);
  assert.match(editor, /auto-paint/);
  assert.match(editor, /fill-if-blank/);
  assert.doesNotMatch(editor, /never touches `painted`/);
  assert.doesNotMatch(editor, /standard_air/);
});

test("wall and space strokes clear entries; the lens tints walls", () => {
  assert.match(compositions, /gas_blocking = true/);
  assert.match(editor, /clears the entry/);
  assert.match(editor, /walls the layer tint/);
  assert.doesNotMatch(editor, /Walls read as nothing/);
});

test("map atmosphere eraser restores inherit; refrigerated folds under the default", () => {
  assert.match(editor, /[Mm]ap atmosphere/);
  assert.match(editor, /atmosphere_blend/);
  assert.match(editor, /eraser is the inherit/);
  assert.match(editor, /explicit override/);
  assert.match(editor, /`refrigerated_air`/);
  assert.match(editor, /foldout/);
});
