import assert from "node:assert/strict";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";
import { assertLabelOutcomes } from "./node/sdk-preamble.mjs";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw Error("Pass the engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const result = await build({
  stdin: {
    contents: "export { renderLabel } from './labels'; export { actionGroups } from './actions'; export { event } from './view';",
    resolveDir: fileURLToPath(new URL("../ui", import.meta.url)),
    loader: "ts",
  },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true,
  format: "esm",
  platform: "node",
  write: false,
});
const UI = await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString("base64")}`);
const { catalog } = globalThis.__lunaticLocale;

const flatten = (node) => [node, ...(node.children ?? []).flatMap(flatten)];
const packLabel = (pack, args = []) => ({ keyed: { reference: { pack }, args } });
const structuralLabel = (structural, args = []) => ({ keyed: { reference: { structural }, args } });

test("qualified action groups use their real catalog labels and accessible names", () => {
  const view = {
    body: false,
    state: {},
    documents: {
      1: {
        id: 1,
        generation: 1,
        title: "Welder",
        state: {
          document: "script",
          status: 2,
          data: {
            presentation: "actions",
            groups: [{
              id: "equipment",
              label: packLabel("lunatic/tfs:ui.actions.equipment"),
              actions: [{ id: "activate", label: packLabel("lunatic/tfs:ui.actions.welder") }],
            }],
          },
        },
      },
    },
  };
  const nodes = UI.actionGroups(view).flatMap(flatten);
  const title = nodes.find((node) => node.id === "actions/equipment/title");
  const button = nodes.find((node) => node.id === "action/1/1/activate");
  assert.equal(catalog["lunatic/tfs:ui.actions.equipment"], "Equipment");
  assert.equal(catalog["lunatic/tfs:ui.actions.welder"], "Welding tool");
  assert.equal(title.text, "Equipment");
  assert.equal(button.text, "Welding tool");
  assert.equal(button.label, "Welding tool");
  assert.deepEqual(UI.event({ id: button.id, type: "activate" }), {
    action: { kind: "document", document: 1, generation: 1, act: "activate", payload: {} },
  });
  assert(!nodes.some((node) => typeof node.text === "string" && node.text.includes("lunatic/tfs:")));
});

test("the shared title screen resolves its pack words", () => {
  assert.equal(catalog["lunatic/tfs:title.heading"], "Tales from Space");
  assert.equal(UI.renderLabel(packLabel("lunatic/tfs:title.editor")), "Map editor");
  assert.equal(UI.renderLabel(packLabel("lunatic/tfs:title.connect")), "Connect to a server");
  assert.equal(UI.renderLabel(packLabel("lunatic/tfs:title.language")), "Language");
});

test("structural labels use the pack's fully-qualified catalog key", () => {
  assert.equal(UI.renderLabel(structuralLabel("link.state.online")), catalog["lunatic/tfs:module.link.state.online"]);
});

test("named arguments preserve literal and structural reference kinds", () => {
  const args = [
    { name: "address", value: { plain: "02-4a" } },
    { name: "state", value: { ref: { structural: "link.state.online" } } },
  ];
  assert.equal(UI.renderLabel(structuralLabel("link.member", args)), "02-4a — online");
  assert.equal(UI.renderLabel(packLabel("lunatic/tfs:module.link.member", args)), "02-4a — online");
});

test("key-shaped plain text stays literal and a missing reference records a refusal", () => {
  const key = "lunatic/tfs:module.link.state.online";
  assert.equal(UI.renderLabel({ plain: key }), key);
  assert.equal(UI.renderLabel(packLabel(key)), catalog[key]);
  assertLabelOutcomes([]);
  assert.equal(UI.renderLabel(packLabel("lunatic/tfs:ui.actions.missing")), "");
  assertLabelOutcomes(["unproved_key"]);
});
