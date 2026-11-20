import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";
import { assertLabelOutcomes } from "./node/sdk-preamble.mjs";

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
const plainLabel = (plain) => ({ plain });
const packLabel = (pack, args = []) => ({ keyed: { reference: { pack }, args } });
const descriptor = (id, extras = {}) => ({ id, gesture: "primary",
  label: packLabel(`lunatic/tfs:ui.affordance.${id}`),
  available: true, group: "action", ...extras });
const render = (actions, bindings) => flatten(UI.overlay.render({ state: {
  hover: { name: "laptop", sprite: "laptop", hints: [], actions }, effectiveBindings: bindings,
} }));
const icons = (nodes) => nodes.filter((node) => node.class?.includes("hover-implement"));

function withLocale(locale, renderView) {
  const previous = globalThis.__lunaticLocale;
  if (locale === undefined) delete globalThis.__lunaticLocale;
  else globalThis.__lunaticLocale = locale;
  try { return renderView(); }
  finally { globalThis.__lunaticLocale = previous; }
}

test("empty descriptors never invent primary or examine actions", () => {
  assert.equal(render([]).filter((node) => node.id.startsWith("hover/hint/")).length, 0);
});
test("hover labels resolve typed keys while key-shaped plain words stay literal", () => {
  const key = "lunatic/tfs:ui.look.examine";
  const actions = [
    descriptor("literal", { label: plainLabel(key) }),
    descriptor("keyed", { label: packLabel(key) }),
  ];
  const nodes = render(actions);
  assert.equal(nodes.find((node) => node.id === "hover/label/literal").text, key);
  assert.equal(nodes.find((node) => node.id === "hover/label/keyed").text, globalThis.__lunaticLocale.catalog[key]);
  assertLabelOutcomes([]);

  const missing = withLocale(undefined, () => render([actions[1]]));
  assert.equal(missing.find((node) => node.id === "hover/label/keyed").text, "");
  assert.equal(missing.find((node) => node.id === "hover/key/keyed/mouse-label").text, "");
  assertLabelOutcomes(["unproved_key", "unproved_key"]);
});
test("equivalent laptop controls retain distinct nodes across state labels", () => {
  for (const state of ["open_lid", "power_on", "view_interface"]) {
    const label = packLabel(`lunatic/tfs:ui.affordance.${state}`);
    const nodes = render(["self", "secondary"].map((gesture) =>
      descriptor(`gesture/${gesture}`, { gesture, label })), { use_self: ["P"] });
    assert.equal(new Set(nodes.map((node) => node.id)).size, nodes.length);
    for (const gesture of ["self", "secondary"])
      assert(nodes.some((node) => node.id === `hover/key/gesture/${gesture}`));
  }
});
test("same gesture preserves distinct available, range and suggested rows", () => {
  const held = { name: plainLabel("wrench"), sprite: "actual_wrench", suggested: false };
  const nodes = render([
    descriptor("wire", { label: packLabel("lunatic/tfs:ui.affordance.wire_frame"),
      available: false, group: "suggestion", implement: { ...held, sprite: "cable", suggested: true } }),
    descriptor("unfasten_pipe", { available: false, group: "range", implement: held }),
    descriptor("face", { label: packLabel("lunatic/tfs:ui.look.face") }),
    descriptor("examine", { gesture: "shift_primary", label: packLabel("lunatic/tfs:ui.look.examine") }),
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
test("other-hand rows show the use_other keys, the implement and their detail line", () => {
  const floppy = { name: plainLabel("floppy"), sprite: "floppy_disk", suggested: false };
  const action = descriptor("other/insert_disk", { gesture: "other", implement: floppy,
    label: packLabel("lunatic/tfs:ui.affordance.insert_disk"),
    detail: plainLabel("In other hand") });
  const keys = (nodes) => nodes.filter((node) => node.id.startsWith("hover/key/other/insert_disk/binding/"));
  assert.equal(keys(render([action], { use_self: ["P"] })).length, 0);
  const nodes = render([action], { use_self: ["P"], use_other: ["Shift", "P"] });
  assert.deepEqual(keys(nodes).map((node) => node.text), ["Shift", "P"]);
  assert.equal(icons(nodes)[0].asset, "floppy_disk");
  assert.equal(nodes.find((node) => node.id === "hover/detail/other/insert_disk").text, "In other hand");
  assert(!nodes.find((node) => node.id === "hover/key/other/insert_disk").class?.includes("hover-unavailable"));
});
test("pack group, style, requirements and order stay data-driven", () => {
  const nodes = render([descriptor("view_interface", { order: 2 }), descriptor("wire_frame", {
    order: 1, style: "construction", presentation_group: "lunatic/tfs:ui.look.role",
    requirements: [{ label: packLabel("lunatic/tfs:entity.cable_coil.name"), count: 5 }],
  })]);
  assert(nodes.find((node) => node.id === "hover/label/wire_frame").class.includes("hover-construction"));
  assert(nodes.some((node) => node.id === "hover/group/wire_frame"));
  assert.equal(nodes.find((node) => node.id === "hover/requirement/wire_frame/0").text, "Requires 5 × cable coil");
  assert.equal(nodes.find((node) => node.id.startsWith("hover/hint/")).id, "hover/hint/wire_frame");
});
test("disabled actions render their authoritative reason, short ones inline", () => {
  const short = render([descriptor("take", { available: false, style: "role",
    detail: plainLabel("Permission needed"),
  })]);
  assert.equal(short.find((node) => node.id === "hover/label/take").text, "Take (Permission needed)");
  assert(!short.some((node) => node.id === "hover/detail/take"));
  assert(!short.some((node) => node.text?.includes("out_of_range")));
  const long = "The whole assembly has to be bolted down first";
  const nodes = render([descriptor("take", { available: false, detail: plainLabel(long) })]);
  assert.equal(nodes.find((node) => node.id === "hover/detail/take").text, long);
});
test("next and back steps stand under their own headings, and suggestions are capped", () => {
  const suggestion = (id, extras = {}) => descriptor(id, {
    label: packLabel("lunatic/tfs:ui.affordance.wire_frame"), available: false, group: "suggestion", ...extras,
  });
  const nodes = render([
    suggestion("next", { presentation_group: "lunatic/tfs:ui.look.next" }),
    suggestion("back", { presentation_group: "lunatic/tfs:ui.look.back", order: 1 }),
    ...["a", "b", "c", "d"].map((id) => suggestion(id)),
  ]);
  assert(nodes.some((node) => node.id === "hover/group/next"));
  assert.equal(nodes.filter((node) => node.id.startsWith("hover/hint/")).length, 4);
});
test("tool requirements receive one Requires prefix and one quantity", () => {
  const { catalog } = globalThis.__lunaticLocale;
  const nodes = render([descriptor("weld_assembly", {
    requirements: [
      { label: plainLabel("lit welding tool"), count: 1 },
      { label: plainLabel("glass sheet"), count: 2 },
    ],
  })]);
  const requirements = nodes.filter((node) => node.id.startsWith("hover/requirement/weld_assembly/"));
  assert.deepEqual(requirements.map((node) => node.text), [
    catalog["lunatic/tfs:ui.look.requires"].replace("{item}", "lit welding tool"),
    catalog["lunatic/tfs:ui.look.requires_quantity"]
      .replace("{quantity}", "2").replace("{item}", "glass sheet"),
  ]);
  for (const requirement of requirements)
    assert.equal(requirement.text.match(/Requires/g)?.length, 1);
});
test("representative catalogs preserve variables and fall back to English", async () => {
  const catalog = async (tag) => JSON.parse(await readFile(new URL(`../locale/${tag}.json`, import.meta.url)));
  const en = globalThis.__lunaticLocale.catalog;
  for (const tag of ["zh-hans", "sr-cyrl", "sr-latn"]) {
    const partial = await catalog(tag), merged = { ...en, ...partial };
    for (const [key, value] of Object.entries(partial)) {
      if (en[key]) assert.deepEqual([...value.matchAll(/\{([^}]+)\}/g)].map((m) => m[1]).sort(),
        [...en[key].matchAll(/\{([^}]+)\}/g)].map((m) => m[1]).sort(), `${tag}: ${key}`);
    }
    assert.notEqual(merged["lunatic/tfs:ui.look.examine"], en["lunatic/tfs:ui.look.examine"]);
    assert.equal(merged["lunatic/tfs:ui.affordance.spray"], en["lunatic/tfs:ui.affordance.spray"]);
    const nodes = withLocale({ tag, catalog: merged }, () => render([descriptor("wire_frame", {
      requirements: [{ label: packLabel("lunatic/tfs:ui.affordance.spray"), count: 5 }],
    })]));
    assert.equal(nodes.find((node) => node.id === "hover/label/wire_frame").text,
      merged["lunatic/tfs:ui.affordance.wire_frame"]);
    assert.equal(nodes.find((node) => node.id === "hover/requirement/wire_frame/0").text,
      partial["lunatic/tfs:ui.look.requires_quantity"].replace("{quantity}", "5").replace("{item}", "Spray"));
  }
});
test("literal key-looking player names remain literal and nested catalog args translate", () => {
  const nameKey = "lunatic/tfs:ui.test.name";
  const actionKey = "lunatic/tfs:ui.test.action";
  const locale = { tag: "en", catalog: { ...globalThis.__lunaticLocale.catalog,
    [nameKey]: "Translated", [actionKey]: "Give {item}",
  } };
  const nodes = withLocale(locale, () => flatten(UI.overlay.render({ state: { hover: {
    name: nameKey, name_label: plainLabel(nameKey),
    actions: [descriptor("give", { label: packLabel(actionKey, [
      { name: "item", value: { ref: { pack: nameKey } } },
    ]) })],
  } } })));
  assert.equal(nodes.find((node) => node.id === "hover/name").text, nameKey);
  assert.equal(nodes.find((node) => node.id === "hover/label/give").text, "Give Translated");
});
