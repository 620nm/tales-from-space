import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw new Error("Pass the engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const output = await build({
  stdin: {
    contents: [
      "export { default as ui } from './staff/main';",
      "export { readStaff } from './staff/model';",
      "export { selectedEntity } from './staff/live';",
    ].join("\n"),
    resolveDir: fileURLToPath(new URL("../ui", import.meta.url)),
    loader: "ts",
  },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true,
  format: "esm",
  platform: "node",
  write: false,
});
const contractOutput = await build({
  stdin: { contents: "export { validateTree } from './src/pack-ui/contract';", resolveDir: resolve(engine, "web"), loader: "ts" },
  bundle: true,
  format: "esm",
  platform: "node",
  write: false,
});
const { ui, readStaff, selectedEntity } = await import(
  `data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString("base64")}`,
);
const { validateTree } = await import(
  `data:text/javascript;base64,${Buffer.from(contractOutput.outputFiles[0].text).toString("base64")}`,
);
globalThis.__lunaticLocale = {
  tag: "en",
  catalog: JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url))),
};

const source = JSON.parse(await readFile(new URL("../ui/staff/fixtures/staff-live.json", import.meta.url)));

function cloneView() {
  return structuredClone(source.view);
}

function nodes(node) {
  return [node, ...(node?.children ?? []).flatMap(nodes)];
}

function node(view, id) {
  return nodes(ui.render(view)).find((item) => item.id === id) ?? null;
}

function queryOf(action) {
  return JSON.parse(action.request.action.Query.query);
}

function findNode(root, id) {
  if (root.id === id) return root;
  for (const child of root.children ?? []) {
    const found = findNode(child, id);
    if (found) return found;
  }
  return null;
}

function sparseItemView() {
  const view = cloneView();
  const itemId = "4294967300";
  const selected = view.state.staff.payload.selected;
  selected.target = { round: "84", kind: "item", id: itemId };
  selected.payload = {
    entity_id: itemId,
    kind: "item",
    live: true,
    name: "Spare ID",
    position: { x: 31, y: 41 },
  };
  selected.related = [];
  const audit = selected.audit[0];
  audit.payload.target = itemId;
  audit.payload.target_ref = selected.target;
  audit.body = null;
  audit.refs[0] = selected.target;
  view.state.staff.payload.audit = [];
  view.state.staff.payload.records.response = null;
  view.state.staff.payload.workspace = "live";
  return view;
}

function contextResponse(view, requestId, result, error) {
  const anchor = view.state.staff.payload.selected.target;
  view.state.staff.payload.records.response = {
    request_id: requestId,
    query: { op: "context", anchor, limit: 64 },
    refs: [],
    result,
    ...(error ? { error } : {}),
  };
}

test("sparse item audit context states satisfy the engine tree contract", () => {
  const view = sparseItemView();
  ui.render(view);
  ui.onEvent({ id: "staff/live/tab/audit", type: "activate" }, view);
  const renderAudit = (message) => {
    const tree = ui.render(view);
    assert(tree);
    assert.doesNotThrow(() => validateTree(tree), message);
    return tree;
  };

  let tree = renderAudit("an item audit with no context anchor has no sparse child");
  assert(findNode(tree, "staff/live/audit/903/action"), "the sparse item still shows its audit row");
  assert.equal(findNode(tree, "staff/live/audit/context"), null, "no matching context anchor omits the context section");
  assert.equal(findNode(tree, "staff/live/audit/context/load-more"), null);

  contextResponse(view, "context-pending", null);
  tree = renderAudit("a pending context response has no sparse child");
  assert.equal(findNode(tree, "staff/live/audit/context"), null);
  assert.equal(findNode(tree, "staff/live/audit/context/load-more"), null);

  contextResponse(view, "context-empty", {
    kind: "context",
    context: { anchor: view.state.staff.payload.selected.target, next: null },
    rows: [],
  });
  tree = renderAudit("an empty context response has no sparse child");
  assert.equal(findNode(tree, "staff/live/audit/context"), null);
  assert.equal(findNode(tree, "staff/live/audit/context/load-more"), null);

  contextResponse(view, "context-error", null, "context unavailable");
  tree = renderAudit("an errored context response keeps a valid section");
  assert(findNode(tree, "staff/live/audit/context/error"));
  assert.equal(findNode(tree, "staff/live/audit/context/load-more"), null);

  contextResponse(view, "context-next", {
    kind: "context",
    context: { anchor: view.state.staff.payload.selected.target, next: "context-2" },
    rows: [],
  });
  tree = renderAudit("a paged context response keeps a valid section");
  assert(findNode(tree, "staff/live/audit/context/load-more"));
  assert.equal(findNode(tree, "staff/live/audit/context/error"), null);
  ui.onEvent({ id: "staff/live/tab/read", type: "activate" }, view);
});

test("native selected payload keeps identity, profile card and capability array", () => {
  const view = cloneView();
  const session = readStaff(view);
  assert(session);
  assert.equal(session.entities.length, 8);
  assert.equal(session.entities[0].ref.kind, "entity");
  assert.equal(session.entities[0].name, "Mara Venn");
  const nameless = cloneView();
  delete nameless.state.staff.payload.world.entities.at(-1).name;
  assert.equal(readStaff(nameless)?.entities.at(-1)?.name, "player · 4294967304");

  const entity = selectedEntity(session);
  assert(entity);
  assert.equal(entity.ref.kind, "body");
  assert.equal(entity.accountId, "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd");
  assert.equal(entity.mindId, "4294967307");
  assert.equal(entity.profileCard?.username, "Mara Venn");
  assert.equal(entity.capabilities?.freeze, true);
  assert.equal(entity.capabilities?.duplicate, true);
  assert.equal(entity.readOnly, false);

  assert.equal(node(view, "staff/live/freeze")?.disabled, undefined);
  assert.equal(node(view, "staff/live/read/profile/username")?.text, "Mara Venn");
  const edit = ui.onEvent({ id: "staff/live/tab/edit", type: "activate" }, view);
  assert.equal(edit.action, undefined);
  assert.equal(node(view, "staff/live/edit/move/action")?.disabled, undefined);
  assert.equal(node(view, "staff/live/edit/duplicate")?.disabled, undefined);
});

test("cached authoritative identity role overrides ambient profile and card", () => {
  const view = cloneView();
  const accountId = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd";
  view.state.staff.payload.records.response = {
    request_id: "profile-identity-1",
    query: { op: "profile", target: { round: "", kind: "account", id: accountId } },
    refs: [],
    result: {
      kind: "profile",
      profile: { identity: { id: accountId, username: "Mara Canonical", avatar: "portrait-01", role: "staff" } },
    },
  };
  const session = readStaff(view);
  assert(session);
  assert.equal(session.profiles.find((profile) => profile.id === accountId)?.role, "player");
  assert.equal(selectedEntity(session)?.profileCard?.username, "Mara Venn");
  ui.render(view);
  ui.onEvent({ id: "staff/live/tab/read", type: "activate" }, view);
  assert.equal(node(view, "staff/live/read/profile/username")?.text, "Mara Canonical");
  assert.equal(node(view, "staff/live/read/profile/role")?.text, "Staff");
});

test("property edits require the native property capability", () => {
  const view = cloneView();
  view.state.staff.payload.selected.payload.capabilities = [
    "inspect", "freeze", "restore", "drive", "kill", "delete", "gib", "move", "duplicate",
  ];
  const session = readStaff(view);
  assert(session);
  const entity = selectedEntity(session);
  assert(entity);
  assert.equal(entity.capabilities?.property, undefined);
  ui.onEvent({ id: "staff/live/tab/edit", type: "activate" }, view);
  const control = node(view, "staff/live/edit/property/1");
  assert(control);
  assert.equal(control.disabled, true);
  ui.onEvent({ id: control.id, type: "change", value: "true" }, view);
  assert.equal(node(view, "staff/live/edit/property/1/apply"), null);
  assert.equal(ui.onEvent({ id: "staff/live/edit/property/1/apply", type: "activate" }, view).action, undefined);
});

function liveProperties(view, properties) {
  view.state.staff.payload.selected.payload.properties = properties;
  const session = readStaff(view);
  assert(session);
  assert(selectedEntity(session));
  ui.onEvent({ id: "staff/live/tab/edit", type: "activate" }, view);
}

function propertyAction(reply) {
  const value = reply.action?.request?.action?.Edit?.edit?.Property?.value;
  assert.equal(typeof value, "string");
  return JSON.parse(value);
}

test("live numeric enum choices preserve primitive values and object labels", () => {
  const view = cloneView();
  liveProperties(view, [
    { path: "service", label: "Service", type: "enum", value: 1, options: [1, 4, 8], editable: true },
    { path: "dial.speed", label: "Speed", type: "enum", value: 4, options: [
      { value: 1, label: "Low" }, { value: 4, label: "Medium" }, { value: 8, label: "High" },
    ], editable: true },
    { path: "mixed.number", label: "Mixed number", type: "enum", value: 1, options: [1, "1"], editable: true },
    { path: "mixed.boolean", label: "Mixed boolean", type: "enum", value: true, options: [true, "true"], editable: true },
  ]);
  const service = node(view, "staff/live/edit/property/0");
  const dial = node(view, "staff/live/edit/property/1");
  const mixedNumber = node(view, "staff/live/edit/property/2");
  const mixedBoolean = node(view, "staff/live/edit/property/3");
  assert(service);
  assert(dial);
  assert(mixedNumber);
  assert(mixedBoolean);
  assert.deepEqual(service.children?.map((option) => [option.value, option.text]), [["staff-option:1", "1"], ["staff-option:4", "4"], ["staff-option:8", "8"]]);
  assert.deepEqual(dial.children?.map((option) => [option.value, option.text]), [["staff-option:1", "Low"], ["staff-option:4", "Medium"], ["staff-option:8", "High"]]);
  assert.deepEqual(mixedNumber.children?.map((option) => [option.value, option.text]), [["staff-option:1", "1"], ["staff-option:\"1\"", "1"]]);
  assert.deepEqual(mixedBoolean.children?.map((option) => [option.value, option.text]), [["staff-option:true", "true"], ["staff-option:\"true\"", "true"]]);

  ui.onEvent({ id: service.id, type: "change", value: service.children[1].value }, view);
  assert(node(view, "staff/live/edit/property/0/apply"));
  const serviceReply = ui.onEvent({ id: "staff/live/edit/property/0/apply", type: "activate" }, view);
  assert.equal(propertyAction(serviceReply), 4);
  ui.onEvent({ id: dial.id, type: "change", value: dial.children[2].value }, view);
  assert(node(view, "staff/live/edit/property/1/apply"));
  const dialReply = ui.onEvent({ id: "staff/live/edit/property/1/apply", type: "activate" }, view);
  assert.equal(propertyAction(dialReply), 8);
  ui.onEvent({ id: mixedNumber.id, type: "change", value: mixedNumber.children[1].value }, view);
  assert(node(view, "staff/live/edit/property/2/apply"));
  const mixedNumberReply = ui.onEvent({ id: "staff/live/edit/property/2/apply", type: "activate" }, view);
  assert.equal(propertyAction(mixedNumberReply), "1");
  ui.onEvent({ id: mixedBoolean.id, type: "change", value: mixedBoolean.children[1].value }, view);
  assert(node(view, "staff/live/edit/property/3/apply"));
  const mixedBooleanReply = ui.onEvent({ id: "staff/live/edit/property/3/apply", type: "activate" }, view);
  assert.equal(propertyAction(mixedBooleanReply), "true");
});

test("nullable enum choices clear to null and refuse a removed null option", () => {
  const view = cloneView();
  const directions = ["north", "east", "south", "west", "northeast", "southeast", "southwest", "northwest"];
  liveProperties(view, [{ path: "mount", label: "Mount", type: "enum", value: "north", options: directions, nullable: true, editable: true }]);
  let control = node(view, "staff/live/edit/property/0");
  assert(control);
  assert.equal(control.value, "staff-option:\"north\"");
  const clear = control.children?.find((option) => option.value === "staff-option:null");
  assert(clear);
  ui.onEvent({ id: control.id, type: "change", value: clear.value }, view);
  let apply = node(view, "staff/live/edit/property/0/apply");
  assert(apply);
  assert.equal(propertyAction(ui.onEvent({ id: apply.id, type: "activate" }, view)), null);

  liveProperties(view, [{ path: "mount", label: "Mount", type: "enum", value: "north", options: directions, nullable: true, editable: true }]);
  control = node(view, "staff/live/edit/property/0");
  assert(control);
  assert.equal(control.value, "staff-option:null", "a remounted string value does not discard the null draft");

  liveProperties(view, [{ path: "mount", label: "Mount", type: "enum", value: "north", options: directions, nullable: false, editable: true }]);
  assert.equal(node(view, "staff/live/edit/property/0")?.children?.some((option) => option.value === "staff-option:null"), false);
  assert.equal(node(view, "staff/live/edit/property/0/apply"), null, "a removed null option cannot be submitted");
});

test("enum drafts survive option reorder and reject removed choices", () => {
  const view = cloneView();
  liveProperties(view, [{ path: "facing.reorder", type: "enum", value: "north", options: ["north", "east", "south"], editable: true }]);
  const initial = node(view, "staff/live/edit/property/0");
  assert(initial);
  const east = initial.children?.find((option) => option.text === "east");
  assert(east);
  assert.equal(east.value, 'staff-option:"east"');
  ui.onEvent({ id: initial.id, type: "change", value: east.value }, view);

  liveProperties(view, [{ path: "facing.reorder", type: "enum", value: "north", options: ["south", "north", "east"], editable: true }]);
  const reordered = node(view, "staff/live/edit/property/0");
  assert(reordered);
  const apply = node(view, "staff/live/edit/property/0/apply");
  assert(apply);
  assert.equal(propertyAction(ui.onEvent({ id: apply.id, type: "activate" }, view)), "east");

  liveProperties(view, [{ path: "facing.reorder", type: "enum", value: "north", options: ["south", "north"], editable: true }]);
  assert.equal(node(view, "staff/live/edit/property/0/apply"), null);
  liveProperties(view, [{ path: "facing.reorder", type: "enum", value: "north", options: [], editable: true }]);
  assert.equal(node(view, "staff/live/edit/property/0/apply"), null);
});

test("enum choices preserve zero, false and empty strings", () => {
  for (const value of [0, false, ""]) {
    const view = cloneView();
    liveProperties(view, [{ path: "choice", type: "enum", value: "initial", options: ["initial", value], editable: true }]);
    const control = node(view, "staff/live/edit/property/0");
    ui.onEvent({ id: control.id, type: "change", value: control.children[1].value }, view);
    const apply = node(view, "staff/live/edit/property/0/apply");
    assert(apply);
    assert.equal(propertyAction(ui.onEvent({ id: apply.id, type: "activate" }, view)), value);
  }
});

test("string descriptors quote numeric-looking names and submit the live field draft", () => {
  const view = cloneView();
  liveProperties(view, [{ path: "name", label: "Name", type: "string", value: "Mara", editable: true }]);
  const control = node(view, "staff/live/edit/property/0");
  assert(control);
  ui.onEvent({ id: control.id, type: "change", value: "123" }, view);
  const apply = node(view, "staff/live/edit/property/0/apply");
  assert(apply);
  assert.equal(apply.submit, control.id);
  const reply = ui.onEvent({ id: apply.id, type: "activate", value: "123" }, view);
  assert.equal(propertyAction(reply), "123");
});

test("explicit primitive types win over non-enum options", () => {
  const view = cloneView();
  liveProperties(view, [
    { path: "title", label: "Title", type: "string", value: "old", options: [1], editable: true },
    { path: "ratio", label: "Ratio", type: "number", value: 0, options: ["1"], editable: true },
    { path: "enabled", label: "Enabled", type: "boolean", value: false, options: ["true"], editable: true },
  ]);
  const title = node(view, "staff/live/edit/property/0");
  const ratio = node(view, "staff/live/edit/property/1");
  const enabled = node(view, "staff/live/edit/property/2");
  assert(title);
  assert(ratio);
  assert(enabled);
  ui.onEvent({ id: title.id, type: "change", value: "1" }, view);
  assert(node(view, "staff/live/edit/property/0/apply"));
  assert.equal(propertyAction(ui.onEvent({ id: "staff/live/edit/property/0/apply", type: "activate" }, view)), "1");
  ui.onEvent({ id: ratio.id, type: "change", value: "1" }, view);
  assert(node(view, "staff/live/edit/property/1/apply"));
  assert.equal(propertyAction(ui.onEvent({ id: "staff/live/edit/property/1/apply", type: "activate" }, view)), 1);
  ui.onEvent({ id: enabled.id, type: "change", value: "true" }, view);
  assert(node(view, "staff/live/edit/property/2/apply"));
  assert.equal(propertyAction(ui.onEvent({ id: "staff/live/edit/property/2/apply", type: "activate" }, view)), true);
});

test("invalid numeric drafts and read-only properties cannot dispatch", () => {
  const view = cloneView();
  liveProperties(view, [
    { path: "rate_lps", label: "Rate", type: "number", value: 1, editable: true },
    { path: "health.state", label: "Life state", type: "enum", value: "Healthy", options: ["Healthy", "Dead"], editable: false },
  ]);
  const numberControl = node(view, "staff/live/edit/property/0");
  const readonlyControl = node(view, "staff/live/edit/property/1");
  assert(numberControl);
  assert(readonlyControl);
  ui.onEvent({ id: numberControl.id, type: "change", value: "not-a-number" }, view);
  assert.equal(node(view, "staff/live/edit/property/0/apply"), null);
  assert.equal(ui.onEvent({ id: "staff/live/edit/property/0/apply", type: "activate" }, view).action, undefined);
  assert.equal(readonlyControl.disabled, true);
  ui.onEvent({ id: readonlyControl.id, type: "change", value: "Dead" }, view);
  assert.equal(node(view, "staff/live/edit/property/1/apply"), null);
  assert.equal(ui.onEvent({ id: "staff/live/edit/property/1/apply", type: "activate" }, view).action, undefined);
});

test("world classification stays separate from its canonical entity reference", () => {
  const view = cloneView();
  view.state.staff.payload.selected.target = { round: "84", kind: "entity", id: "4294967297" };
  view.state.staff.payload.selected.payload.reference = view.state.staff.payload.selected.target;
  view.state.staff.payload.selected.payload.kind = "entity";
  const entity = selectedEntity(readStaff(view));
  assert(entity);
  assert.equal(entity.kind, "player");
  assert.equal(entity.ref.kind, "entity");
});

test("stale exact references cannot act on a current entity with the same id", () => {
  const view = cloneView();
  view.state.staff.round_id = "85";
  view.state.staff.payload.current_round = "85";
  view.state.staff.payload.world.entities[0].ref.round = "85";
  const session = readStaff(view);
  assert(session);
  const entity = selectedEntity(session);
  assert(entity);
  assert.equal(entity.id, "4294967297");
  assert.equal(entity.ref.round, "84");
  assert.equal(entity.readOnly, true);
  assert.equal(node(view, "staff/live/freeze"), null);
  assert.equal(node(view, "staff/live/edit/move/action"), null);
  assert.equal(node(view, "staff/live/edit/duplicate"), null);
  assert.equal(node(view, "staff/live/intervene"), null);
  assert.equal(node(view, "staff/live/tab/edit"), null);

  const create = ui.onEvent({ id: "staff/live/read/case/create", type: "activate" }, view).action;
  assert(create);
  assert.deepEqual(JSON.parse(create.request.action.Records.request), { op: "create_case", anchor: { round: "84", kind: "body", id: "4294967297" } });
});

test("a review opened before deletion cannot survive a tombstone", () => {
  const view = cloneView();
  ui.render(view);
  const opened = ui.onEvent({ id: "staff/live/review/kill", type: "activate" }, view);
  assert.equal(opened.action, undefined);
  assert(node(view, "staff/review"));
  view.state.staff.payload.selected.tombstone = true;
  assert.equal(node(view, "staff/review"), null);
});

for (const [name, change] of [
  ["tombstone", (view) => { view.state.staff.payload.selected.tombstone = true; }],
  ["nonlive", (view) => { view.state.staff.payload.selected.payload.live = false; }],
  ["opaque reference", (view) => {
    view.state.staff.payload.selected.target = { round: "84", kind: "virus", id: "spore-alpha" };
    view.state.staff.payload.selected.payload.reference = view.state.staff.payload.selected.target;
  }],
  ["account reference", (view) => {
    view.state.staff.payload.selected.target = { round: "", kind: "account", id: "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd" };
    view.state.staff.payload.selected.payload.reference = view.state.staff.payload.selected.target;
  }],
]) {
  test(`${name} selections omit live mutation controls`, () => {
    const view = cloneView();
    change(view);
    const session = readStaff(view);
    assert(session);
    assert.equal(selectedEntity(session)?.readOnly, true);
    assert.equal(node(view, "staff/live/intervene"), null);
    assert.equal(node(view, "staff/live/edit/move/action"), null);
    assert.equal(node(view, "staff/live/edit/duplicate"), null);
    assert.equal(node(view, "staff/live/tab/edit"), null);
  });
}

console.log("staff live projection: native payload, exact identity and historical safety");
