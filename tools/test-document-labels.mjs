import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw Error("Pass the engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const result = await build({
  stdin: {
    contents: "export { labelText } from './labels'; export { actionGroups } from './actions'; export { event } from './view';",
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
const catalog = JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url)));
globalThis.__lunaticLocale = { tag: "en", catalog };

const flatten = (node) => [node, ...(node.children ?? []).flatMap(flatten)];

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
              label: { id: "lunatic/tfs:ui.actions.equipment" },
              actions: [{ id: "activate", label: { id: "lunatic/tfs:ui.actions.welder" } }],
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

test("bare module labels retain the native prefix", () => {
  assert.equal(UI.labelText({ id: "link.state.online" }), catalog["lunatic/tfs:module.link.state.online"]);
});

test("arg_ids resolve qualified and unqualified nested labels", () => {
  assert.equal(UI.labelText({
    id: "link.member",
    args: { address: "02-4a", state: "lunatic/tfs:module.link.state.online" },
    arg_ids: ["state"],
  }), "02-4a — online");
  assert.equal(UI.labelText({
    id: "lunatic/tfs:module.link.member",
    args: { address: "02-4a", state: "link.state.online" },
    arg_ids: ["state"],
  }), "02-4a — online");
});

test("literal text stays literal and missing ids remain visible", () => {
  assert.equal(UI.labelText({ text: "Welder" }), "Welder");
  assert.equal(UI.labelText({ id: "lunatic/tfs:ui.actions.missing" }), "lunatic/tfs:ui.actions.missing");
  assert.equal(UI.labelText({ id: "missing" }), "lunatic/tfs:module.missing");
});
