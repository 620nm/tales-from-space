import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw new Error("Set LUNATIC_ENGINE or pass the absolute engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const result = await build({
  stdin: { contents: `export * from './files'; export * from './files-buffer';
    export { begin, event } from './view';`,
    resolveDir: fileURLToPath(new URL("../ui", import.meta.url)), loader: "ts" },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true, format: "esm", platform: "node", write: false,
});
globalThis.__lunaticLocale = { tag: "en", catalog: JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url), "utf8")) };
const U = await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString("base64")}`);
const id = "doc/5/1", doc = { id: 5, generation: 1, title: "Terminal", owner_sprite: "laptop" };
const atmo = JSON.stringify({ version: 1, temperature_k: 293, pressure_kpa: 101, gases: [] });
const state = (ext = "md", body = "Saved") => ({
  stores: [{ key: "host", binding: "disk", label: "Internal", used: 5, capacity: 100, count: 1, count_cap: 8 }],
  files: [{ store: "host", binding: "disk", uid: 1, name: "notes", ext, size: body.length }], create: { host: ["md", "atmo", "pem"] },
  open: { store: "host", binding: "disk", uid: 1, revision: 3, name: "notes", ext, body },
});
const flatten = (node) => [node, ...(node.children ?? []).flatMap(flatten)];
function render(s) {
  U.begin();
  const p = U.filePanes(id, doc, s, true);
  return Object.values(p).flat().flatMap(flatten);
}
const act = (suffix, extra = {}) => U.event({ id: `${id}/${suffix}`, ...extra }).action;
const get = (nodes, suffix) => nodes.find((node) => node.id === `${id}/${suffix}`);
const dialogs = (nodes) => nodes.filter((node) => node.class?.includes("dialog"));
function createGuard() {
  U.retainOpenFileBuffers([]);
  const s = state(); render(s);
  act("editor/edit"); render(s);
  act("drive/host/create"); render(s);
  act("drive/host/create/confirm", { value: "Draft", revision: 3,
    values: { stem: { value: "Air notes" }, ext: { value: "atmo" } } });
  return s;
}

test("readers offer preview and source; malformed atmosphere stays editable", () => {
  for (const [ext, body] of [["md", "# Heading"], ["atmo", atmo], ["pem", "ACCESS"]]) {
    U.retainOpenFileBuffers([]);
    const s = state(ext, body); let nodes = render(s);
    assert(nodes.find((n) => n.event === `${id}/editor/view`));
    assert(!nodes.some((n) => n.id.startsWith(`${id}/editor/body/`)));
    act("editor/edit"); nodes = render(s);
    assert(nodes.some((n) => n.id.startsWith(`${id}/editor/body/`)));
    assert(U.bodyId(id));
    act("editor/view", { value: body }); nodes = render(s);
    assert.equal(U.bodyId(id), undefined);
    assert.equal(get(nodes, "drive/host/file/0/open").submit, undefined, "preview drive actions cannot reference hidden source");
  }
  U.retainOpenFileBuffers([]);
  const nodes = render(state("atmo", "{"));
  assert(!nodes.find((n) => n.event === `${id}/editor/view`));
  assert(nodes.some((n) => n.id.startsWith(`${id}/editor/body/`)));
});
test("read-only previews expose source without mutation controls", () => {
  U.retainOpenFileBuffers([]);
  const s = state("pem", "ACCESS");
  s.editor = { body: "ACCESS", revision: 3, read_only: true, byte_budget: 100, markers: [], bound: true };
  const nodes = render(s);
  assert.equal(nodes.find((n) => n.event === `${id}/editor/edit`).text, "Source");
  assert(!get(nodes, "editor/save"));
  assert(!get(nodes, "editor/rename-button"));
});
test("Create yields sole modal to guard; Cancel restores naming draft", () => {
  const s = createGuard(); let nodes = render(s);
  assert.equal(dialogs(nodes).length, 1);
  assert(get(nodes, "editor/guard"));
  assert(!get(nodes, "drive/host/create/stem"));
  act("editor/guard/cancel"); nodes = render(s);
  assert.equal(dialogs(nodes).length, 1);
  assert.equal(get(nodes, "drive/host/create/stem").value, "Air notes");
  assert.equal(get(nodes, "drive/host/create/stem").label, "File name");
  assert.equal(get(nodes, "drive/host/create/ext").label, "File type");
  assert.equal(get(nodes, "drive/host/create/ext").value, "atmo");
  assert.equal(U.editorBuffer(id, doc, s).text, "Draft");
});
test("Create discard releases exactly once and closes its modal", () => {
  const s = createGuard(); render(s);
  const command = act("editor/guard/discard");
  assert.equal(command.payload.field, "file_create");
  assert.equal(command.payload.text, "Air notes");
  assert.equal(act("editor/guard/discard"), undefined);
  assert.equal(dialogs(render(s)).length, 0);
});
test("Create save waits behind sole guard and continues once after receipt", () => {
  const s = createGuard(); render(s);
  const save = act("editor/guard/save");
  assert.equal(save.payload.field, "file_save");
  let nodes = render(s);
  assert.equal(dialogs(nodes).length, 1);
  assert(get(nodes, "editor/guard/save").disabled);
  assert(!get(nodes, "drive/host/create/stem"));
  s.open = { ...s.open, revision: 4, body: "Draft" };
  s.save_ack = { request: save.payload.request, binding: "disk", uid: 1, revision: 4 };
  const docs = [{ ...doc, state: s }];
  assert.equal(U.pollContinuation(docs).payload.field, "file_create");
  assert.equal(U.pollContinuation(docs), undefined);
  assert.equal(dialogs(render(s)).length, 0);
});
test("repairing malformed atmosphere keeps source and focus until View is chosen", () => {
  U.retainOpenFileBuffers([]);
  const s = state("atmo", "{");
  let nodes = render(s);
  const input = nodes.find((n) => n.id.startsWith(`${id}/editor/body/`));
  assert.equal(input.label, "File contents");
  assert.equal(get(nodes, "editor/name").label, "File name");
  assert(get(nodes, "drive/host/stem").label);
  U.event({ id: input.id, value: atmo, revision: 3 });
  nodes = render(s);
  assert.equal(nodes.find((n) => n.id === input.id).value, atmo);
  assert(!get(nodes, "reader"));
  act("editor/view", { value: atmo });
  nodes = render(s);
  assert(get(nodes, "reader"));
  assert(!nodes.some((n) => n.id === input.id));
});
test("an unanswered save can be cancelled, preserving Create for retry or discard", () => {
  const s = createGuard(); render(s);
  const save = act("editor/guard/save"); render(s);
  act("editor/guard/cancel");
  let nodes = render(s);
  assert.equal(get(nodes, "drive/host/create/stem").value, "Air notes");
  act("drive/host/create/confirm", { values: { stem: { value: "Air notes" }, ext: { value: "atmo" } } });
  nodes = render(s);
  assert(!get(nodes, "editor/guard/discard").disabled);
  assert.equal(act("editor/guard/discard").payload.field, "file_create");
  s.open = { ...s.open, revision: 4, body: "Draft" };
  s.save_ack = { request: save.payload.request, binding: "disk", uid: 1, revision: 4 };
  assert.equal(U.pollContinuation([{ ...doc, state: s }]), undefined);
});
