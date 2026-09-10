import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";

const manifest = JSON.parse(await readFile(new URL("../editor/manifest.json", import.meta.url), "utf8"));
const defaults = {
  airlock: { paint: "public", glass: false },
  "airlock.engineering": { paint: "engineering", glass: false },
  "airlock.engineering_glass": { paint: "engineering", glass: true },
  "airlock.interior_glass": { paint: "interior", glass: true },
};
const art = {
  public: ["door", "door_bolt_lights"],
  engineering: ["door_eng", "door_bolt_lights"],
  interior: ["door_int", "door_int_bolt_lights"],
};
function preview(schema, values) {
  return schema.previews.find((rule) => Object.entries(rule.when ?? {}).every(([key, value]) => values[key] === value))?.layers;
}
for (const [mode, declaration] of Object.entries(manifest.modes)) {
  test(`${mode} previews every airlock livery, glazing, position and bolt setting`, () => {
    for (const [id, props] of Object.entries(defaults)) {
      const schema = declaration.prototypes.find((p) => p.kind === "structure" && p.id === id);
      assert(schema, `${id} has a preview`);
      const base = art[props.paint][0] + (props.glass ? "_glass" : "");
      assert.deepEqual(preview(schema, { open: false, bolted: false, ...props }), [base], `${id} defaults`);
      for (const [paint, [solid, light]] of Object.entries(art)) {
        for (const glass of [false, true]) for (const open of [false, true]) for (const bolted of [false, true]) {
          const expected = [solid + (glass ? "_glass" : "") + (open ? "_open" : "")];
          if (bolted && !open) expected.push(light);
          assert.deepEqual(preview(schema, { ...props, paint, glass, open, bolted }), expected,
            JSON.stringify({ mode, id, paint, glass, open, bolted }));
        }
      }
    }
  });
}
