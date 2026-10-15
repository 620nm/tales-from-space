import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";
import { servedRoster } from "./served-roster.mjs";

const read = (path) => readFile(new URL(path, import.meta.url), "utf8");
// The declaration is content/editor.luau; the engine serves it decoded.
const served = servedRoster();
if (served.missing) console.log(`SKIP editor atmos: ${served.missing}`);
const skip = served.missing ?? false;
const manifest = served.roster?.editor;
assert(skip || manifest, "the served roster carries content/editor.luau's editor declaration");
const editor = await read("../docs/EDITOR.md");
const breathable = await read("../content/blends/breathable_air.luau");
const compositions = await read("../content/compositions.luau");

test("both modes offer the blend lens turf paint breathes under", { skip }, () => {
  for (const [mode, declaration] of Object.entries(manifest.modes)) {
    assert(declaration.lenses.includes("surface"), `${mode} keeps surface`);
    assert(declaration.lenses.includes("blend"), `${mode} offers blend`);
  }
});

test("lattice is turf, not a placement prototype in any mode", { skip }, () => {
  for (const [mode, declaration] of Object.entries(manifest.modes)) {
    const ids = declaration.prototypes.map((p) => p.id);
    assert(!ids.includes("lattice"), `${mode} has no lattice prototype`);
    assert(!ids.includes("catwalk"), `${mode} has no catwalk prototype`);
  }
});

test("lattice and catwalk are compositions, and the editor doc says so", () => {
  assert.match(compositions, /id = "lattice"/);
  assert.match(compositions, /id = "catwalk"/);
  assert.doesNotMatch(editor, /bare entry admits it/);
});

test("fresh turf auto-paints the breathable pack default", () => {
  assert.match(breathable, /id = "breathable_air"/);
  assert.match(breathable, /default = true/);
  assert.match(editor, /`breathable_air`/);
  assert.match(editor, /auto-paint/);
  assert.match(editor, /fill-if-blank/);
  assert.doesNotMatch(editor, /never touches `painted`/);
  assert.doesNotMatch(editor, /standard_air/);
  assert.doesNotMatch(editor, /ideal_air/);
});

test("wall and space strokes clear entries; the lens skips walls", () => {
  assert.match(compositions, /gas_blocking = true/);
  assert.match(editor, /clears the entry/);
  assert.match(editor, /Walls read as nothing/);
  assert.doesNotMatch(editor, /walls the layer tint/);
});

test("map atmosphere eraser restores inherit; refrigerated folds under the default", () => {
  assert.match(editor, /[Mm]ap atmosphere/);
  assert.match(editor, /atmosphere_blend/);
  assert.match(editor, /eraser is the inherit/);
  assert.match(editor, /explicit override/);
  assert.match(editor, /`refrigerated_air`/);
  assert.match(editor, /foldout/);
});
