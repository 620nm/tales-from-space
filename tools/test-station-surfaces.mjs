import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";
const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw Error("Pass the engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const result = await build({
  stdin: { contents: "export { default as ui } from './main';", resolveDir: fileURLToPath(new URL("../ui", import.meta.url)), loader: "ts" },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true, format: "esm", platform: "node", write: false,
});
const { ui } = await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString("base64")}`);
const flatten = (node) => [node, ...(node.children ?? []).flatMap(flatten)];
const fixture = async (name) => JSON.parse(await readFile(new URL(`../ui/fixtures/${name}.json`, import.meta.url))).view;
globalThis.__lunaticLocale = { tag: "en", catalog: JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url))) };

test("busy HUD exposes named actions as valid pinned buttons", async () => {
  const view = await fixture("hud-busy-compact"), nodes = flatten(ui.render(view));
  for (const node of nodes) if (node.children) assert(["panel", "row", "column", "select"].includes(node.type), node.id);
  const action = nodes.find((node) => node.id === "action/90/1/flash");
  assert.equal(action.type, "button");
  assert.equal(action.label, "Flash");
  assert.equal(ui.onEvent({ id: action.id, type: "activate" }, view).action.act, "flash");
});
test("disclosed material and stock shortages explain disabled actions", async () => {
  for (const [name, disabled, reason] of [
    ["document-construction", "doc/1/1/recipe/0/arm", "doc/1/1/recipe/0/unavailable"],
    ["document-shelf", "doc/1/1/product/0/vend", "doc/1/1/product/0/unavailable"],
  ]) {
    const nodes = flatten(ui.render(await fixture(name)));
    assert.equal(nodes.find((node) => node.id === disabled).disabled, true);
    assert(nodes.find((node) => node.id === reason).text.length > 0);
    assert(nodes.find((node) => node.id === "doc/1/1/status"));
  }
});
test("unavailable construction follows document status even with enough materials", async () => {
  const view = await fixture("document-construction"); view.documents[1].state.status = 1;
  const nodes = flatten(ui.render(view));
  assert.equal(nodes.find((node) => node.id === "doc/1/1/recipe/1/arm").disabled, true);
  assert.match(nodes.find((node) => node.id === "doc/1/1/status").text, /Unavailable/);
});
test("empty documents retain a labeled body and status", async () => {
  const nodes = flatten(ui.render(await fixture("document-empty")));
  assert.equal(nodes.find((node) => node.id === "doc/1/1/empty").text, "No entries are available.");
  assert.equal(nodes.find((node) => node.id === "doc/1/1/status").text, "Ready");
});
