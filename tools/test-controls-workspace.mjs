import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL, fileURLToPath } from "node:url";
import { test } from "node:test";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw new Error("Set LUNATIC_ENGINE or pass the absolute engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const result = await build({
  stdin: {
    contents: `export * from './files'; export * from './files-buffer';
      export { documents } from './documents'; export { begin, event } from './view';`,
    resolveDir: fileURLToPath(new URL("../ui", import.meta.url)),
    loader: "ts",
  },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true, format: "esm", platform: "node", write: false,
});
globalThis.__lunaticLocale = {
  tag: "en",
  catalog: JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url), "utf8")),
};
const U = await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString("base64")}`);

const doc = { id: 5, generation: 1, title: "Control terminal", owner_sprite: "terminal" };
const stores = [{ key: "host", binding: "host-1", label: "Local", used: 10, capacity: 65536, count: 3, count_cap: 16 }];
const files = [
  { store: "host", uid: 1, binding: "host-1", name: "one", ext: "md", size: 1 },
  { store: "host", uid: 2, binding: "host-1", name: "two", ext: "disl", size: 2 },
  { store: "host", uid: 3, binding: "host-1", name: "three", ext: "md", size: 3 },
];
const base = (extra = {}) => ({
  document: "modules", status: 2, stores, files,
  open: { store: "host", uid: 2, binding: "host-1", revision: 3, name: "two", ext: "disl", body: "original" },
  editor: { body: "original", read_only: false, byte_budget: 65536, markers: [], revision: 3, bound: true },
  ...extra,
});
const flatten = (node) => [node, ...(node.children ?? []).flatMap(flatten)];
const render = (state, identity = doc) => {
  U.begin();
  return Object.values(U.filePanes(`doc/${identity.id}/${identity.generation}`, identity, state, state.status !== 0))
    .filter(Array.isArray).flat().flatMap(flatten);
};
const id = (suffix, identity = doc) => `doc/${identity.id}/${identity.generation}/${suffix}`;
const node = (nodes, suffix, identity = doc) => nodes.find((entry) => entry.id === id(suffix, identity));
const action = (suffix, event = {}, identity = doc) => U.event({ id: id(suffix, identity), ...event }).action;
const reset = () => { U.retainOpenFileBuffers([]); U.retainWorkspaces([]); };

test("Details is first when disclosed while Controls and Files keep their defaults", () => {
  reset();
  let nodes = render(base({ control_panels: [], readouts: [{ label: "Owner", value: "Ready" }], program_slots: [{ id: "slot_a", file: null, uid: null, runs: 0, faults: 0, state: "empty" }] }));
  assert.ok(node(nodes, "workspace/details"));
  assert.ok(node(nodes, "workspace/controls"));
  assert.deepEqual(node(nodes, "workspace-tabs").children.slice(0, 2).map(tab => tab.id),
    [id("workspace/details"), id("workspace/controls")]);
  assert.equal(node(nodes, "workspace/controls").class.includes("workspace-tab-active"), true);
  assert.ok(node(nodes, "workspace/programs"), "disclosed program slots get a Programs tab");
  assert.equal(node(nodes, "workspace/files").text, "Files (3)");
  assert.equal(action("workspace/controls"), undefined, "workspace tabs never post a sim command");

  reset();
  nodes = render(base());
  assert.equal(node(nodes, "workspace/details"), undefined, "Details requires disclosed owner readings");
  assert.equal(node(nodes, "workspace/files").class.includes("workspace-tab-active"), true);
  assert.equal(node(nodes, "workspace/controls"), undefined);
  assert.equal(node(nodes, "workspace/programs"), undefined);
});

test("program summaries are read-only, count native slots, and open Programs", () => {
  reset();
  const state = base({ control_panels: [], program_slots: [
    { id: "slot_a", file: "one.disl", uid: 2, runs: 4, faults: 1, state: "loaded" },
    { id: "slot_b", file: null, uid: null, runs: 0, faults: 0, state: "empty" },
  ] });
  let nodes = render(state);
  assert.equal(node(nodes, "workspace/programs").text, "Programs (2)");
  assert.ok(node(nodes, "program-summary"));
  assert.equal(nodes.some((entry) => entry.id?.startsWith(id("program-summary")) && entry.payload), false);
  assert.equal(action("program-summary/0/open"), undefined);
  nodes = render(state);
  assert.equal(node(nodes, "workspace/programs").class.includes("workspace-tab-active"), true);
  assert.ok(node(nodes, "programs"));
});

test("Controls to Files mounts source before every navigation submit", () => {
  const state = base({ control_panels: [], readouts: [{ label: "Owner", value: "Ready" }], toggles: [linkLock(true)], program_slots: [
    { id: "slot_a", file: "two.disl", uid: 2, runs: 0, faults: 0, state: "loaded" },
  ] });
  reset();
  render(state);
  action("workspace/files");
  let nodes = render(state);
  const body = nodes.find((entry) => entry.type === "textarea");
  assert.ok(body, "the first Files tree mounts the native source input");
  for (const destination of ["workspace/controls", "workspace/details", "toggle/link_lock/switch", "program-summary/0/open"]) {
    assert.equal(node(nodes, destination).submit, body.id, `${destination} submits the mounted source`);
  }

  for (const destination of ["workspace/controls", "workspace/details", "toggle/link_lock/switch", "program-summary/0/open"]) {
    reset();
    render(state);
    action("workspace/files");
    nodes = render(state);
    const input = nodes.find((entry) => entry.type === "textarea");
    assert.ok(input);
    action(destination, { value: "fresh draft", revision: 3 });
    nodes = render(state);
    assert.ok(node(nodes, "editor/guard"), `${destination} guards an unflushed draft`);
    assert.equal(nodes.find((entry) => entry.id === input.id).value, "fresh draft",
      `${destination} retains the latest source text`);
  }
});

test("preview readers omit source submits from workspace navigation", () => {
  const state = base({
    control_panels: [],
    readouts: [{ label: "Owner", value: "Ready" }],
    program_slots: [{ id: "slot_a", file: "two.disl", uid: 2, runs: 0, faults: 0, state: "loaded" }],
    open: { store: "host", uid: 2, binding: "host-1", revision: 3, name: "two", ext: "md", body: "# Preview" },
    editor: { body: "# Preview", read_only: false, byte_budget: 65536, markers: [], revision: 3, bound: true },
  });
  reset();
  render(state);
  action("workspace/files");
  const nodes = render(state);
  assert.equal(nodes.some((entry) => entry.type === "textarea"), false, "preview has no mounted source input");
  for (const destination of ["workspace/controls", "workspace/details", "program-summary/0/open"]) {
    assert.equal(node(nodes, destination).submit, undefined, `${destination} omits submit for a preview reader`);
  }
});

test("leaving Files submits the visible source and keeps the draft on return", () => {
  reset();
  const state = base();
  let nodes = render(state);
  const body = nodes.find((entry) => entry.type === "textarea");
  assert.ok(body);
  action(`editor/body/${body.id.split("/").at(-1)}`, { value: "draft", revision: 3 });
  nodes = render(state);
  state.control_panels = [];
  nodes = render(state);
  const controls = node(nodes, "workspace/controls");
  assert.equal(controls.submit, body.id, "navigation submits the mounted source body");
  action("workspace/controls", { value: "draft", revision: 3 });
  nodes = render(state);
  assert.ok(node(nodes, "editor/guard"), "dirty navigation retains the existing guard");
  action("editor/guard/cancel");
  nodes = render(state);
  assert.equal(nodes.find((entry) => entry.type === "textarea").value, "draft");
});

test("the native header action waits for the Files guard, then honors cancel, save, and discard", () => {
  const state = base({ toggles: [linkLock(true)] });
  reset();
  render(state);
  let nodes = render(state);
  const body = nodes.find((entry) => entry.type === "textarea");
  assert.ok(body, "Files mounts the source before header actions are attached");
  action(`editor/body/${body.id.split("/").at(-1)}`, { value: "draft", revision: 3 });
  nodes = render(state);
  const header = node(nodes, "toggle/link_lock/switch");
  assert.equal(header.submit, body.id, "the header lock submits the mounted source");
  assert.equal(action("toggle/link_lock/switch", { value: "draft", revision: 3 }), undefined,
    "dirty Files owns the header transition");
  nodes = render(state);
  assert.ok(node(nodes, "editor/guard"));
  assert.equal(action("editor/guard/cancel"), undefined, "Cancel keeps the local draft and sends no native action");
  nodes = render(state);
  assert.equal(node(nodes, "editor/guard"), undefined);
  assert.equal(nodes.find((entry) => entry.type === "textarea").value, "draft");

  assert.equal(action("toggle/link_lock/switch", { value: "draft", revision: 3 }), undefined);
  nodes = render(state);
  const save = action("editor/guard/save", { value: "draft", revision: 3 });
  assert.equal(save.act, "text");
  assert.equal(save.payload.field, "file_save", "Save sends the file save before the pending lock action");

  reset();
  render(state);
  nodes = render(state);
  const secondBody = nodes.find((entry) => entry.type === "textarea");
  action(`editor/body/${secondBody.id.split("/").at(-1)}`, { value: "draft", revision: 3 });
  render(state);
  action("toggle/link_lock/switch", { value: "draft", revision: 3 });
  render(state);
  const discard = action("editor/guard/discard");
  assert.deepEqual(discard, {
    kind: "document", document: doc.id, generation: doc.generation,
    act: "toggle", payload: { field: "link_lock", option: "target" },
  }, "Discard releases the queued native header action");
});

test("primarySave is advertised only for a mounted writable source", () => {
  reset();
  const view = (editor, extra = {}) => ({ body: false, state: {}, documents: {
    [doc.id]: { ...doc, state: base({ ...extra, editor }) },
  } });
  let nodes = U.documents(view({ ...base().editor, bound: false }));
  assert.equal(nodes[0].primarySave, undefined);
  nodes = U.documents(view({ ...base().editor, bound: true }));
  assert.equal(nodes[0].primarySave, id("editor/save"));

  reset();
  const controls = view({ ...base().editor, bound: true }, {
    control_panels: [], readouts: [{ label: "Owner", value: "Ready" }],
  });
  nodes = U.documents(controls);
  assert.equal(nodes[0].primarySave, undefined, "Controls has no source save target");
  action("workspace/files");
  nodes = U.documents(controls);
  assert.equal(nodes[0].primarySave, id("editor/save"));
  action("workspace/details");
  nodes = U.documents(controls);
  assert.equal(nodes[0].primarySave, undefined, "Details has no source save target");
  action("workspace/files");
  U.documents(controls);
  action("workspace/files", { value: "unflushed draft", revision: 3 });
  nodes = U.documents(controls);
  assert.equal(nodes.flatMap(flatten).some((entry) => entry.id === id("editor/guard")), false,
    "the selected Files tab is a no-op");

  const rendered = nodes;
  const ids = rendered.flatMap(flatten).map((entry) => entry.id);
  assert.equal(new Set(ids).size, ids.length, "the full computer document has unique node ids");
});

test("workspace memory is scoped to document generation and locked controls disclose no diagnosis", () => {
  reset();
  const locked = { ...base({ control_panels: [], status: 0, readouts: [{ label: "temperature", value: "stable" }] }), status: 0 };
  const first = render(locked);
  assert.ok(node(first, "workspace/details"));
  assert.equal(node(first, "workspace/controls").class.includes("workspace-tab-active"), true);
  action("workspace/details");
  const details = render(locked);
  assert.ok(node(details, "details-body"));
  assert.equal(details.some((entry) => ["offline", "locked"].includes(String(entry.text))), false);

  const next = { ...doc, generation: 2 };
  U.retainWorkspaces([next]);
  const fresh = render(base({ control_panels: [], readouts: [{ label: "temperature", value: "stable" }] }), next);
  assert.equal(node(fresh, "workspace/controls", next).class.includes("workspace-tab-active"), true);
  assert.equal(node(fresh, "workspace/details", next).class.includes("workspace-tab-active"), false);
});

const linkLock = (on, option = "target") => ({
  label: "Link lock", on, on_text: "Unlocked", off_text: "Locked", field: "link_lock", option,
});

test("the heading owns the native lock action and reflects both lock states", () => {
  for (const [on, label, asset] of [[true, "Lock", "ui_lock_open"], [false, "Unlock", "ui_lock_closed"]]) {
    reset();
    const state = base({ control_panels: [], readouts: [{ label: "Owner", value: "Ready" }], toggles: [linkLock(on)] });
    const nodes = render(state);
    const button = node(nodes, "toggle/link_lock/switch");
    assert.equal(button.text, label);
    assert.equal(button.disabled, undefined);
    assert.equal(node(nodes, "toggle/link_lock/switch/icon").asset, asset);
    assert.deepEqual(action("toggle/link_lock/switch"), {
      kind: "document", document: doc.id, generation: doc.generation,
      act: "toggle", payload: { field: "link_lock", option: "target" },
    });
  }
});

test("the lock action is disclosed only when native state says so and disables while inactive", () => {
  reset();
  let nodes = render(base({ control_panels: [], readouts: [{ label: "Owner", value: "Ready" }] }));
  assert.equal(node(nodes, "toggle/link_lock/switch"), undefined);

  nodes = render(base({ status: 0, control_panels: [], toggles: [linkLock(false)] }));
  assert.equal(node(nodes, "toggle/link_lock/switch").disabled, true);
});

test("Details removes only the root link lock row and keeps other owner modules", () => {
  reset();
  const state = base({ control_panels: [], readouts: [{ label: "Owner", value: "Ready" }], toggles: [
    linkLock(true),
    { label: "Other switch", on: true, on_text: "On", off_text: "Off", field: "other_switch" },
  ] });
  let nodes = render(state);
  assert.equal(nodes.filter((entry) => entry.id === id("toggle/link_lock/switch")).length, 1);
  assert.equal(nodes.some((entry) => entry.id?.includes("/information/") && entry.id?.includes("link_lock")), false);
  action("workspace/details");
  nodes = render(state);
  assert.equal(node(nodes, "workspace/details").class.includes("workspace-tab-active"), true);
  assert.equal(nodes.filter((entry) => entry.id === id("toggle/link_lock/switch")).length, 1);
  assert.equal(nodes.some((entry) => entry.id?.includes("/information/") && entry.id?.includes("other_switch")), true);
});

console.log("Workspace navigation: Details disclosure, native lock, safe navigation, draft guards and identity cleanup passed");
