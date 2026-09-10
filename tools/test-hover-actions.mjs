import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw new Error("Set LUNATIC_ENGINE or pass the absolute engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const result = await build({
  stdin: { contents: `export { default as overlay } from './overlay/main';
    export { overlayRules } from './theme/overlay';`,
    resolveDir: fileURLToPath(new URL("../ui", import.meta.url)), loader: "ts" },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true, format: "esm", platform: "node", write: false,
});
const UI = await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString("base64")}`);
const flatten = (node) => [node, ...(node.children ?? []).flatMap(flatten)];
const descriptor = (id, extras = {}) => ({ id, gesture: "primary",
  label: { key: `lunatic/tfs:ui.affordance.${id}`, args: {} },
  available: true, group: "action", ...extras });
const render = (actions, bindings) => flatten(UI.overlay.render({ state: {
  hover: { name: "laptop", sprite: "laptop", hints: [], actions }, effectiveBindings: bindings,
} }));
const icons = (nodes) => nodes.filter((node) => node.class?.includes("hover-implement"));

test("empty descriptors never invent primary or examine actions", () => {
  assert.equal(render([]).filter((node) => node.id.startsWith("hover/hint/")).length, 0);
});
test("equivalent laptop controls retain distinct nodes across state labels", () => {
  for (const state of ["open_lid", "power_on", "view_interface"]) {
    const label = { key: `lunatic/tfs:ui.affordance.${state}`, args: {} };
    const nodes = render(["self", "secondary"].map((gesture) =>
      descriptor(`gesture/${gesture}`, { gesture, label })), { use_self: ["P"] });
    assert.equal(new Set(nodes.map((node) => node.id)).size, nodes.length);
    for (const gesture of ["self", "secondary"])
      assert(nodes.some((node) => node.id === `hover/key/gesture/${gesture}`));
  }
});
test("same gesture preserves distinct available, range and suggested rows", () => {
  const held = { name: { key: "", text: "wrench" }, sprite: "actual_wrench", suggested: false };
  const nodes = render([
    descriptor("wire", { available: false, group: "suggestion", implement: { ...held, sprite: "cable", suggested: true } }),
    descriptor("unfasten_pipe", { available: false, group: "range", implement: held }),
    descriptor("face"), descriptor("examine", { gesture: "shift_primary" }),
  ]);
  assert.deepEqual(nodes.filter((node) => node.id.startsWith("hover/hint/")).map((node) => node.id),
    ["hover/hint/face", "hover/hint/examine", "hover/hint/unfasten_pipe", "hover/hint/wire"]);
  assert.equal(icons(flatten(nodes.find((node) => node.id === "hover/key/face"))).length, 0);
  assert.equal(icons(nodes)[0].asset, "actual_wrench");
  assert(nodes.find((node) => node.id === "hover/key/unfasten_pipe").class.includes("hover-unavailable"));
  assert.equal(nodes.filter((node) => node.id === "hover/group/suggestion").length, 1);
});
test("only bound self-use keys render, including long localized chords", () => {
  const action = descriptor("open_lid", { gesture: "self" });
  for (const bindings of [undefined, {}, { use_self: [] }])
    assert.equal(render([action], bindings).filter((node) => node.id.includes("/binding/")).length, 0);
  const parts = ["Управљање", "Десни померај", "Page Down"];
  const nodes = render([action], { use_self: parts });
  assert.deepEqual(nodes.filter((node) => node.id.includes("/binding/")).map((node) => node.text), parts);
  const grid = UI.overlayRules.find((rule) => rule.class === "hover-actions");
  assert.deepEqual(grid.props.gridTemplateColumns, ["auto", "1fr"]);
});
test("pack group, style, requirements and order stay data-driven", () => {
  const nodes = render([descriptor("second", { order: 2 }), descriptor("wire_frame", {
    order: 1, style: "construction", presentation_group: "lunatic/tfs:ui.look.role",
    requirements: [{ label: { key: "lunatic/tfs:ui.item.cable" }, count: 5 }],
  })]);
  assert(nodes.find((node) => node.id === "hover/label/wire_frame").class.includes("hover-construction"));
  assert(nodes.some((node) => node.id === "hover/group/wire_frame"));
  assert(nodes.some((node) => node.id === "hover/requirement/wire_frame/0"));
  assert.equal(nodes.find((node) => node.id.startsWith("hover/hint/")).id, "hover/hint/wire_frame");
});
test("disabled role actions render their authoritative reason", () => {
  const nodes = render([descriptor("role", { available: false, style: "role",
    unavailable_reason: { key: "", text: "Permission needed" },
  })]);
  assert.equal(nodes.find((node) => node.id === "hover/reason/role").text, "Permission needed");
  assert(!nodes.some((node) => node.text?.includes("out_of_range")));
});
test("representative catalogs preserve variables and fall back to English", async () => {
  const catalog = async (tag) => JSON.parse(await readFile(new URL(`../locale/${tag}.json`, import.meta.url)));
  const en = await catalog("en");
  for (const tag of ["zh-hans", "sr-cyrl", "sr-latn"]) {
    const partial = await catalog(tag), merged = { ...en, ...partial };
    for (const [key, value] of Object.entries(partial)) {
      if (en[key]) assert.deepEqual([...value.matchAll(/\{([^}]+)\}/g)].map((m) => m[1]).sort(),
        [...en[key].matchAll(/\{([^}]+)\}/g)].map((m) => m[1]).sort(), `${tag}: ${key}`);
    }
    assert.notEqual(merged["lunatic/tfs:ui.look.examine"], en["lunatic/tfs:ui.look.examine"]);
    assert.equal(merged["lunatic/tfs:ui.affordance.spray"], en["lunatic/tfs:ui.affordance.spray"]);
    globalThis.__lunaticLocale = { tag, catalog: merged };
    const nodes = render([descriptor("wire_frame", {
      requirements: [{ label: { key: "lunatic/tfs:ui.affordance.spray" }, count: 5 }],
    })]);
    assert.equal(nodes.find((node) => node.id === "hover/label/wire_frame").text,
      merged["lunatic/tfs:ui.affordance.wire_frame"]);
    assert.equal(nodes.find((node) => node.id === "hover/requirement/wire_frame/0").text,
      partial["lunatic/tfs:ui.look.requires_quantity"].replace("{quantity}", "5").replace("{item}", "Spray"));
  }
  delete globalThis.__lunaticLocale;
});
test("literal key-looking player names remain literal and nested catalog args translate", () => {
  globalThis.__lunaticLocale = { tag: "en", catalog: {
    "example:name": "Translated", "example:action": "Give {item}",
  } };
  const nodes = flatten(UI.overlay.render({ state: { hover: {
    name: "example:name", name_label: { key: "", text: "example:name" },
    actions: [descriptor("give", { label: {
      key: "example:action", args: { item: "example:name" }, arg_keys: ["item"],
    } })],
  } } }));
  assert.equal(nodes.find((node) => node.id === "hover/name").text, "example:name");
  assert.equal(nodes.find((node) => node.id === "hover/label/give").text, "Give Translated");
  delete globalThis.__lunaticLocale;
});
