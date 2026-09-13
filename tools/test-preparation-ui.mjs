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
globalThis.__lunaticLocale = {
  tag: "en",
  catalog: JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url))),
};

const view = JSON.parse(await readFile(new URL("../ui/fixtures/preparation.json", import.meta.url)));
const flatten = (node) => [node, ...(node.children ?? []).flatMap(flatten)];

test("preparation name commits only a complete field change or Enter submission", () => {
  const tree = ui.render(view.view);
  const name = flatten(tree).find((node) => node.id === "preparation/name");
  assert(name, "preparation exposes its name input");

  const expected = {
    kind: "character_draft",
    round: 12,
    revision: 3,
    draft: { name: "Mira Pike", ranked_jobs: ["assistant", "engineer"], fallback: false },
  };
  for (const type of ["change", "submit"]) {
    ui.render(view.view);
    assert.deepEqual(ui.onEvent({ id: name.id, type, value: "Mira Pike" }, view.view).action, expected);
  }
});

test("a later blur does not resubmit an acknowledged name", async () => {
  for (const fixture of ["preparation", "preparation-playing"]) {
    const { view } = JSON.parse(await readFile(new URL(`../ui/fixtures/${fixture}.json`, import.meta.url)));
    const accepted = structuredClone(view);
    accepted.state.preparation.revision++;
    accepted.state.preparation.draft.name = "Mira Pike";
    ui.render(accepted);
    assert.equal(ui.onEvent({ id: "preparation/name", type: "change", value: "Mira Pike" }, accepted)?.action,
      undefined, `${fixture}: blur after acceptance must not start another save`);
  }
});

test("readiness capability controls Ready and Unready during a queued save", () => {
  for (const ready of [false, true]) {
    const state = structuredClone(view.view);
    state.state.preparation.ready = ready;
    state.state.preparation.can_ready = false;
    state.state.preparationPending = true;
    state.state.preparationCanQueue = true;
    const button = flatten(ui.render(state)).find((node) => node.id === "preparation/ready");
    assert.equal(button.disabled, true);
  }
});
