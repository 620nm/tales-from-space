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
    export { overlayRules } from './theme-overlay';
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
test("hover uses structured fallback and never fills an explicitly hidden row", () => {
  const labels = (hover) => {
    const collect = (node) => [node.text, ...(node.children ?? []).flatMap(collect)].filter(Boolean);
    return collect(UI.overlay.render({ state: { hover: { name: "laptop", sprite: "laptop", hints: [], ...hover } } }));
  };
  assert(labels({ primary_fallback: "interact" }).includes("lunatic/tfs:ui.look.use_held"));
  assert(labels({ primary_fallback: "store" }).includes("lunatic/tfs:ui.look.store_held"));
  assert(!labels({ primary_fallback: null }).some((label) => label.endsWith("use_held") || label.endsWith("store_held")));
  const declared = labels({ primary_fallback: "interact", hints: [{ gesture: "primary", label: "lunatic/tfs:ui.affordance.insert_disk" }] });
  assert(declared.includes("lunatic/tfs:ui.affordance.insert_disk"));
  assert(!declared.includes("lunatic/tfs:ui.look.use_held"));
  assert(labels({ appearance: "world" }).includes("lunatic/tfs:ui.look.interact"));
});

const flatten = (node) => [node, ...(node.children ?? []).flatMap(flatten)];
const hoverNodes = (hover) => flatten(UI.overlay.render({ state: {
  hover: { name: "laptop", sprite: "laptop", hints: [], primary_fallback: null, ...hover },
} }));
const heldImplement = { name: "diskette", sprite: "diskette_blue", gestures: ["primary"] };
const insertHint = { gesture: "primary", label: "lunatic/tfs:ui.affordance.insert_disk" };
const itemIcons = (nodes) => nodes.filter((node) => node.class?.includes("hover-implement"));
test("held-object hints combine input, plus and the actual named atlas sprite", () => {
  const nodes = hoverNodes({ hints: [insertHint], implement: heldImplement });
  const keys = nodes.find((node) => node.id === "hover/key/0");
  assert.deepEqual(keys.children.map((node) => node.type), ["panel", "text", "image"]);
  assert.equal(keys.children[1].text, "+");
  assert.equal(keys.children[2].asset, "diskette_blue");
  assert.equal(keys.children[2].text, "diskette");
  assert.equal(itemIcons(nodes).length, 1);
  const spriteStyle = UI.overlayRules.find((rule) => rule.class === "hover-implement").props;
  assert.equal(spriteStyle.width, 32);
  assert.equal(spriteStyle.height, 32);
  assert.equal(spriteStyle.imageRendering, "pixelated");
});
test("mixed hints share a rail wide enough for two modifiers and an item", () => {
  const nodes = hoverNodes({ hints: [insertHint, { gesture: "shift_ctrl_primary", label: "tool action" }],
    implement: { ...heldImplement, gestures: ["primary", "shift_ctrl_primary", "shift_primary"] } });
  const rows = nodes.filter((node) => node.class?.includes("hover-row"));
  assert.equal(rows.length, 3);
  assert(rows.every((node) => node.style.gridTemplateColumns[0] === 132));
  assert(rows.every((node) => node.children[0].class.includes("hover-keys")));
  assert.equal(itemIcons(flatten(rows[1])).length, 0, "examine never uses the held item");
  const modifiedKeys = rows[2].children[0];
  assert.equal(modifiedKeys.children.length, 5);
  assert.equal(modifiedKeys.children[4].asset, "diskette_blue");
  assert.equal(nodes.find((node) => node.id === "hover/title").children[0].id, "hover/preview");
});
test("hover drops item icons when source clears and updates same-named item sprites", () => {
  assert.equal(itemIcons(hoverNodes({ hints: [insertHint], implement: heldImplement }))[0].asset, "diskette_blue");
  assert.equal(itemIcons(hoverNodes({ hints: [insertHint],
    implement: { ...heldImplement, sprite: "diskette_red" } }))[0].asset, "diskette_red");
  for (const implement of [undefined, null, { ...heldImplement, sprite: "" }]) {
    const nodes = hoverNodes({ hints: [insertHint], implement });
    assert.equal(itemIcons(nodes).length, 0);
    assert(!nodes.some((node) => node.class?.includes("hover-combination-plus")));
    assert(nodes.filter((node) => node.class?.includes("hover-row"))
      .every((node) => node.style.gridTemplateColumns[0] === 58));
  }
});
test("held item metadata never resurrects hidden hints or decorates unrelated rows", () => {
  const nodes = hoverNodes({ hints: [{ gesture: "alt_primary", label: "open" }], implement: heldImplement });
  assert.equal(itemIcons(nodes).length, 0);
  assert.equal(nodes.filter((node) => node.class?.includes("hover-row")).length, 2);
  for (const primary_fallback of ["interact", "store"]) {
    assert.equal(itemIcons(hoverNodes({ primary_fallback, implement: heldImplement })).length, 1);
  }
});
