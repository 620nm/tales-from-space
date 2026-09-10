import assert from "node:assert/strict";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw new Error("Set LUNATIC_ENGINE or pass the absolute engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const result = await build({
  stdin: { contents: `export { inventory, wornGroup } from './inventory';
    export { openStorage, closeStorage, storageRegion } from './inventory-storage';
    export { begin, event } from './view';
    export { overlayRules } from './theme/overlay';
    export { default as overlay } from './overlay/main';`,
    resolveDir: fileURLToPath(new URL("../ui", import.meta.url)), loader: "ts" },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true, format: "esm", platform: "node", write: false,
});
const UI = await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString("base64")}`);
const laptop = { name: "laptop", sprite: "laptop", gestures: (1 << 1) | (1 << 9) | (1 << 12) | (1 << 13) };
const cartridge = { name: "floppy_disk", sprite: "floppy_disk" };
const bag = { name: "backpack", sprite: "backpack", contents: [laptop] };
function render(held = cartridge) {
  UI.begin(); UI.closeStorage();
  const inventory = { receipt: 47, active: 0, hands: [held, laptop], held: [null, null],
    equipment: [{ slot: 0, item: bag, contents: [bag] }, { slot: 1, item: laptop, contents: null }] };
  const view = { body: true, state: { inventory,
    equipment: { slots: [{ id: "back", label: "back" }, { id: "belt", label: "belt" }, { id: "head", label: "head" }] } } };
  UI.inventory(view); UI.wornGroup(view, true); UI.wornGroup(view);
  UI.openStorage({ slot: "back" }); UI.openStorage({ slot: "back", path: [0] });
  UI.storageRegion(view);
  return view;
}
const sites = [
  ["hand/1/pick", { Held: { hand: 1 } }],
  ["equipment/belt/pick", { Equipment: { slot: "belt" } }],
  ["stored/equipment/back/0-0/take", { NestedEquipment: { slot: "back", path: [0, 0] } }],
];
for (const [id, target] of sites) {
  test(`${id}: interaction carries the rendered receipt`, () => {
    const view = render(); view.state.inventory = { ...view.state.inventory, receipt: 99 };
    assert.deepEqual(UI.event({ id, type: "activate" }).action,
      { kind: "interact_item", target, receipt: 47 });
  });
  test(`${id}: declared modifiers precede inspect, undeclared modifiers never navigate`, () => {
    render();
    for (const [type, flags, gesture] of [
      ["context", {}, "secondary"], ["activate", { alt: true }, "alt_primary"],
      ["activate", { shift: true, ctrl: true }, "shift_ctrl_primary"],
      ["context", { shift: true, ctrl: true }, "shift_ctrl_secondary"],
    ]) assert.deepEqual(UI.event({ id, type, ...flags }).action,
      { kind: "use_item", target, gesture, receipt: 47 });
    assert.deepEqual(UI.event({ id, type: "activate", shift: true }).action,
      { kind: "examine", target });
    for (const type of ["activate", "context", "middle"])
      assert.equal(UI.event({ id, type, meta: true, shift: true }).action, undefined);
    for (const flags of [{ ctrl: true }, { meta: true }, { alt: true, ctrl: true }, {}])
      assert.equal(UI.event({ id, type: flags.ctrl || flags.meta ? "activate" : "middle", ...flags }).action, undefined);
  });
}
test("active slot and empty active hand preserve navigation", () => {
  render();
  assert.deepEqual(UI.event({ id: "hand/0/pick", type: "activate" }).action, { kind: "hand", index: 0 });
  assert.deepEqual(UI.event({ id: "equipment/head/pick", type: "activate" }).action, { kind: "equip" });
  render(null);
  assert.deepEqual(UI.event({ id: "hand/1/pick", type: "activate" }).action, { kind: "hand", index: 1 });
  assert.deepEqual(UI.event({ id: "equipment/belt/pick", type: "activate" }).action, { kind: "unequip", slot: "belt" });
  assert.deepEqual(UI.event({ id: sites[2][0], type: "activate" }).action,
    { kind: "move_item", from: sites[2][1], to: { Held: { hand: 0 } } });
  assert.equal(UI.event({ id: "stored/equipment/back/0/take", type: "activate", alt: true }).action, undefined);
  assert.equal(UI.event({ id: "stored/equipment/back/0/take", type: "activate" }).action, undefined);
});
