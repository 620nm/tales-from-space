// This pack's providers through the pinned interpreter: the file
// workspace's readers and drafts, the naming dialog, the vendor shelf and
// the HUD a body view draws — from `ui/main.tsx` and every addon
// `ui/extensions.json` names, compiled against the engine SDK.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import {
  compilePackModule, createGuest, engineModule, find, guestPackage, packRoot,
} from "./ui-runtime-harness.mjs";

const { fileViews } = await engineModule("web/tests/pack-ui/file-views.mjs");

// The pack is the subject here, so each of these is a check, never a
// reason to answer zero quietly.
const manifest = await readFile(join(packRoot, "mod.toml"), "utf8");
const ui = /^\[ui\]\s*\n([\s\S]*?)(?=^\[|$(?![\s\S]))/m.exec(manifest)?.[1];
assert.ok(ui, "mod.toml declares a [ui] table");
assert.match(manifest, /^id\s*=\s*"lunatic\/tfs"/m, "these provider fixtures target this pack's UI");
const entry = /^entry\s*=\s*"([^"\n]+)"/m.exec(ui)?.[1];
assert.ok(entry, "the [ui] table declares an entry");

const vm = await createGuest(guestPackage(await compilePackModule(entry)));
// A pack may move panels into an addon package; `ui/extensions.json`
// names each one's source, and an id the HUD stopped drawing is
// expected to render there instead (the engine's docs/pack-ui/sdk.md, slots).
const overlays = [];
let index = "[]";
try {
  index = await readFile(join(packRoot, "ui/extensions.json"), "utf8");
} catch (error) {
  if (error.code !== "ENOENT") throw error;
}
for (const row of JSON.parse(index)) {
  if (typeof row?.entry !== "string") continue;
  overlays.push(await createGuest(guestPackage(await compilePackModule(row.entry))));
}
const file = {
  id: 2,
  generation: 1,
  title: "Files",
  state: {
    status: 2,
    stores: [
      { key: "host", binding: "fixture-host", label: { text: "Disk" }, used: 8192, capacity: 32768, count: 1, count_cap: 16 },
    ],
    files: [],
    create: {},
    editor: { body: "", read_only: false, byte_budget: 24576, markers: [], revision: 1, bound: false },
    open: {
      store: "host",
      binding: "fixture-host",
      uid: 1,
      name: "record",
      ext: "disl",
      body: "a".repeat(8192),
      revision: 1,
    },
  },
};
const vendor = {
  id: 1,
  generation: 1,
  title: "Shelf",
  state: {
    status: 2,
    products: [
      {
        label: "Product",
        sprite: "missing",
        category: "Stock",
        stock: 2,
        act: "vend",
        payload: { product: "fixture" },
      },
    ],
  },
};
const view = {
  version: 6,
  revision: 1,
  body: false,
  state: {},
  documents: { 1: vendor, 2: file },
  log: [],
};
try {
  fileViews(vm, view, file, find);
  // Exercise every production reader with the native editor disclosure. Its
  // status row is absent without this module, hiding invalid dynamic styles.
  const records = [
    ["md", ""], ["md", "# Heading\n> Quote\n```\nlocal n = 1\n```\n![remote](https://example.invalid/image)"],
    ["atmo", ""], ["atmo", "{bad"],
    ["atmo", JSON.stringify({version: 1, temperature_k: 293, pressure_kpa: 101, gases: [{id: "oxygen", moles: 2}]})],
    ["pem", "-----BEGIN PUBLIC KEY-----\nordinary text"],
    ["disl", "local x = 1"],
  ];
  for (const [ext, body] of records) {
    const record = structuredClone(file);
    Object.assign(record.state.open, {ext, body});
    record.state.editor.body = body;
    record.state.document = "modules";
    record.state.script = {data: {kind: "desktop", powered: true, wallpaper: "wallpaper_bliss"}, actions: [{id: "power"}]};
    const readerTree = vm.render({...view, documents: {2: record}});
    assert.ok(readerTree, `${ext} reader and native editor validate together`);
    const preview = ext === "md" || ext === "pem" || (ext === "atmo" && body.startsWith('{"version"'));
    assert.equal(!!find(readerTree, "doc/2/1/editor/mode/view"), preview, `${ext} selects its supported reader`);
    if (preview) assert.equal(find(readerTree, "doc/2/1/editor/save").submit, undefined);
    vm.render({...view, documents: {}});
  }
  // Naming comes from one live submission, never an earlier change event.
  const named = structuredClone(file);
  named.state.create = {host: ["md"]};
  named.state.files = [{...named.state.open, size: 8192}];
  named.state.stores.push({key: "media", binding: "fixture-media", label: {text: "Disk"}, used: 0, capacity: 65536, count: 0, count_cap: 16});
  const namingView = {...view, documents: {2: named}};
  let namingTree = vm.render(namingView);
  // The create dialog owns the filename and type fields.
  const openId = "doc/2/1/drive/host/create";
  const createId = "doc/2/1/drive/host/create/confirm";
  const stemId = "doc/2/1/drive/host/create/stem";
  const extId = "doc/2/1/drive/host/create/ext";
  assert.equal(find(namingTree, stemId), undefined, "the dialog is closed until pressed");
  assert.equal(vm.event({id: openId, type: "activate"}, namingView).action, undefined);
  namingTree = vm.render(namingView);
  assert.equal(find(namingTree, stemId).submitOnly, true);
  assert.equal(find(namingTree, stemId).revision, 0, "host owns the dirty naming draft across blur and updates");
  assert.equal(find(namingTree, extId).type, "select");
  assert.deepEqual(find(namingTree, extId).children.map((option) => option.value), ["md"]);
  assert.deepEqual(find(namingTree, createId).submitValues, {stem: stemId, ext: extId});
  vm.event({id: stemId, type: "change", value: "stale name"}, namingView);
  assert.equal(vm.event({id: createId, type: "activate"}, namingView).action, undefined);
  const namedAction = vm.event({id: createId, type: "activate", value: named.state.open.body,
    values: {stem: {value: "live name"}, ext: {value: "md"}}}, namingView).action;
  assert.equal(namedAction.payload.text, "live name");
  assert.equal(namedAction.payload.option, "host:md:fixture-host");
  assert.equal(find(vm.render(namingView), stemId), undefined, "a created file closes the dialog");
  const copyId = "doc/2/1/drive/host/file/0/copy";
  assert.equal(vm.event({id: copyId, type: "activate"}, namingView).action.payload.text, named.state.files[0].name);
  assert.equal(vm.event({id: copyId, type: "activate", values: {stem: {value: "copy live"}}}, namingView).action.payload.text, named.state.files[0].name);
  vm.event({id: openId, type: "activate"}, namingView);
  vm.render(namingView);
  assert.equal(vm.event({id: createId, type: "activate", value: named.state.open.body,
    values: {stem: {value: "bogus ext"}, ext: {value: "bogus"}}}, namingView).action, undefined, "an unknown type creates nothing");
  assert.ok(find(vm.render(namingView), stemId), "and leaves the dialog open");
  assert.equal(vm.event({id: createId, type: "activate", value: "unsent dirty draft", revision: 1,
    values: {stem: {value: "deferred live name"}, ext: {value: "md"}}}, namingView).action, undefined);
  namingTree = vm.render(namingView);
  assert.ok(find(namingTree, "doc/2/1/editor/guard/discard"));
  assert.equal(find(namingTree, stemId), undefined, "Create yields its modal to the dirty guard");
  const modals = (node) => (node.modal ? 1 : 0) + (node.children ?? []).reduce((sum, child) => sum + modals(child), 0);
  assert.equal(modals(namingTree), 1, "one workspace has exactly one active modal");
  vm.event({id: "doc/2/1/editor/guard/cancel", type: "activate"}, namingView);
  namingTree = vm.render(namingView);
  assert.equal(find(namingTree, stemId).value, "deferred live name", "Cancel restores the naming draft");
  assert.equal(modals(namingTree), 1);
  vm.event({id: createId, type: "activate", value: "unsent dirty draft", revision: 1,
    values: {stem: {value: "deferred live name"}, ext: {value: "md"}}}, namingView);
  vm.render(namingView);
  const deferred = vm.event({id: "doc/2/1/editor/guard/discard", type: "activate"}, namingView).action;
  assert.equal(deferred.payload.text, "deferred live name");
  assert.equal(vm.event({id: "doc/2/1/editor/guard/discard", type: "activate"}, namingView).action, undefined,
    "a repeated stale discard cannot repeat the deferred action");
  assert.equal(find(vm.render(namingView), stemId), undefined, "the discarded guard released the dialog");
  vm.render({...view, documents: {}});
  let tree = vm.render(view);
  assert.ok(find(tree, "doc/1/1/product/0/vend"));
  const bodyId = find(tree, "doc/2/1/editor/save").submit;
  assert.equal(find(tree, bodyId).value.length, 8192);
  assert.deepEqual(
    vm.event({ id: "doc/1/1/product/0/vend", type: "activate" }, view).action,
    {
      kind: "document",
      document: 1,
      generation: 1,
      act: "vend",
      payload: { product: "fixture" },
    },
  );
  const saved = vm.event(
    { id: "doc/2/1/editor/save", type: "activate", value: "edited" },
    view,
  );
  assert.equal(saved.action.payload.text, "edited");
  assert.equal(saved.action.payload.revision, 1);
  tree = vm.render(view);
  assert.equal(find(tree, bodyId).value, "edited");
  assert.match(find(tree, "doc/2/1/editor/title").text, /modified/);
  file.state.open.revision = 2;
  file.state.open.body = "edited";
  file.state.save_ack = { request: saved.action.payload.request, binding: "fixture-host", uid: 1, revision: 2 };
  assert.doesNotMatch(
    find(vm.render(view), "doc/2/1/editor/title").text,
    /modified/,
  );
  file.state.open.revision = 3;
  file.state.open.body = "remote";
  vm.render(view);
  const stale = vm.event(
    {
      id: "doc/2/1/editor/save",
      type: "activate",
      value: "unsent draft",
      revision: 2,
    },
    view,
  );
  assert.equal(stale.action.payload.revision, 2);
  tree = vm.render(view);
  assert.ok(find(tree, "doc/2/1/editor/conflict"));
  assert.equal(find(tree, bodyId).value, "unsent draft");
  vm.event({ id: "doc/2/1/editor/revert", type: "activate" }, view);
  vm.render(view);
  vm.event({ id: "doc/2/1/editor/guard/discard", type: "activate" }, view);
  tree = vm.render(view);
  const resetId = find(tree, "doc/2/1/editor/save").submit;
  assert.notEqual(resetId, bodyId);
  assert.equal(find(tree, resetId).value, "remote");
  assert.equal(find(tree, resetId).revision, 3);
  vm.event(
    { id: "doc/2/1/editor/save", type: "activate", value: "closed draft" },
    view,
  );
  const otherFile = { ...structuredClone(file), id: 3 };
  view.documents[3] = otherFile;
  vm.render(view);
  vm.event(
    { id: "doc/3/1/editor/save", type: "activate", value: "retained draft" },
    view,
  );
  view.documents = { 3: otherFile };
  tree = vm.render(view);
  const otherBodyId = find(tree, "doc/3/1/editor/save").submit;
  assert.equal(find(tree, otherBodyId).value, "retained draft");
  assert.match(find(tree, "doc/3/1/editor/title").text, /modified/);

  otherFile.state.open = {
    ...otherFile.state.open,
    uid: 2,
    body: "next file",
  };
  tree = vm.render(view);
  const nextBodyId = find(tree, "doc/3/1/editor/save").submit;
  assert.notEqual(nextBodyId, otherBodyId);
  assert.equal(find(tree, nextBodyId).value, "next file");
  otherFile.state.open = {
    ...otherFile.state.open,
    uid: 1,
    body: "first file",
  };
  tree = vm.render(view);
  const firstBodyId = find(tree, "doc/3/1/editor/save").submit;
  assert.notEqual(firstBodyId, otherBodyId);
  assert.equal(find(tree, firstBodyId).value, "first file");
  assert.doesNotMatch(find(tree, "doc/3/1/editor/title").text, /modified/);
  vm.event(
    {
      id: "doc/3/1/editor/save",
      type: "activate",
      value: "last closed draft",
    },
    view,
  );
  view.documents = {};
  vm.render(view);
  // Reuse the key to prove closing discarded the old submitted buffer.
  file.state.open.body = "reopened";
  file.state.open.revision = 4;
  otherFile.state.open.body = "last reopened";
  otherFile.state.open.revision = 5;
  view.documents = { 1: vendor, 2: file, 3: otherFile };
  tree = vm.render(view);
  const reopenedId = find(tree, "doc/2/1/editor/save").submit;
  assert.notEqual(reopenedId, resetId);
  assert.equal(find(tree, reopenedId).value, "reopened");
  assert.equal(find(tree, reopenedId).revision, 4);
  assert.equal(find(tree, "doc/2/1/editor/conflict"), undefined);
  assert.doesNotMatch(find(tree, "doc/2/1/editor/title").text, /modified/);
  const lastReopenedId = find(tree, "doc/3/1/editor/save").submit;
  assert.notEqual(lastReopenedId, firstBodyId);
  assert.equal(find(tree, lastReopenedId).value, "last reopened");
  assert.equal(find(tree, lastReopenedId).revision, 5);
  assert.equal(find(tree, "doc/3/1/editor/conflict"), undefined);
  assert.doesNotMatch(find(tree, "doc/3/1/editor/title").text, /modified/);
  view.body = true;
  Object.assign(view.state, {
    inventory: {
      receipt: 17,
      active: 0,
      hands: [{ name: "Tool", sprite: "missing" }, null],
      held: [[{ name: "Stored", sprite: "missing" }], null],
      equipment: [
        {
          slot: 0,
          item: { name: "Carrier", sprite: "missing" },
          contents: [{ name: "Stored", sprite: "missing" }],
        },
      ],
    },
    equipment: {
      slots: [{ id: "carrier", label: "Carrier", quick_store: true }],
    },
    targets: { zones: [{ id: "center", label: "Center" }] },
    target: { zone: 0 },
    identity: { name: "Reader", you: 17 },
    vitals: { values: [{ slot: 0, text: "Normal" }] },
    readouts: { slots: [{ label: "State" }] },
    jobs: { jobs: [{ key: "role", name: "Role", taken: 0, slots: 2 }] },
    bodyStatus: {
      state: { controllable: false, animate: false, label: "Unavailable" },
      can_respawn: true,
    },
    speech: [{ id: 17, sequence: 1, text: "Speech", channel: "local" }],
    progress: [{ job: 1, sequence: 1, ms: 3600000 }],
    inspections: [{
      sequence: 1,
      sprite: "missing",
      title: "Fixture",
      lines: [{ spans: [{ text: "Observed" }] }],
    }],
    context: [{ sprite: "missing", name: "Fixture", target: 17 }],
  });
  tree = vm.render(view);
  for (const id of [
    "inventory",
    "speech/17/1",
    "progress/1/1",
    "inspect/1",
    "lobby",
    "body-state",
  ])
    assert.ok(find(tree, id), `missing ${id}`);
  // Wherever the pack put it: the HUD, or one of its addon packages.
  assert.ok(
    [tree, ...overlays.map((overlay) => overlay.render(view))].some((drawn) =>
      find(drawn, "context"),
    ),
    "missing context",
  );
  vm.event({ id: "inspect/1/pin", type: "activate" }, view);
  assert.equal(find(vm.render(view), "inspect/1").expires, undefined);
  view.state.inspections.push({ ...view.state.inspections[0], sequence: 2 });
  tree = vm.render(view);
  assert.equal(find(tree, "inspect/1"), undefined);
  assert.equal(find(tree, "inspect/2").expires, undefined, "repeat inherits its pin");
  vm.event({ id: "inspection-history", type: "activate" }, view);
  tree = vm.render(view);
  assert.ok(find(tree, "history/1"));
  assert.ok(find(tree, "inspect/2"), "history leaves live toast mounted");
  vm.event({ id: "inspection-history-close", type: "activate" }, view);
  vm.event({ id: "inspect/2/close", type: "activate" }, view);
  tree = vm.render(view);
  assert.equal(find(tree, "inspect/1"), undefined, "dismiss cannot replay old history");
  assert.equal(find(tree, "inspect/2"), undefined);
  vm.event({ id: "hand/0/open", type: "activate" }, view);
  assert.ok(find(vm.render(view), "stored/hand/0/0/take"));
  assert.deepEqual(vm.event({ id: "equipment/carrier/pick", type: "activate" }, view).action, {
    kind: "interact_item", target: { Equipment: { slot: "carrier" } }, receipt: 17,
  });
  assert.equal(find(vm.render(view), "stored/equipment/carrier/0/take"), undefined);
  view.state.inventory.active = 1;
  view.state.inventory.receipt = 18;
  vm.render(view);
  vm.event({ id: "equipment/carrier/pick", type: "activate" }, view);
  assert.ok(find(vm.render(view), "stored/equipment/carrier/0/take"));
  for (let id = 3; id < 9; id++)
    view.documents[id] = {
      id,
      generation: 1,
      title: "Instrument",
      state: {
        status: 2,
        readouts: Array.from({ length: 70 }, (_, index) => ({
          label: `Value ${index}`,
          value: "v".repeat(150),
        })),
      },
    };
  assert.ok(JSON.stringify(view).length > 65536);
  assert.ok(vm.render(view));
} finally {
  vm.dispose();
  for (const overlay of overlays) overlay.dispose();
}
console.log("Providers: readers, drafts, naming, shelf and HUD checks passed");
