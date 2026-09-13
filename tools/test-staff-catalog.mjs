import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw Error("Pass the engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const output = await build({
  stdin: { contents: "export { default as ui } from './staff/main';", resolveDir: fileURLToPath(new URL("../ui", import.meta.url)), loader: "ts" },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true, format: "esm", platform: "node", write: false,
});
const contractOutput = await build({
  stdin: { contents: "export { validateTree } from './src/pack-ui/contract';", resolveDir: resolve(engine, "web"), loader: "ts" },
  bundle: true, format: "esm", platform: "node", write: false,
});
globalThis.__lunaticLocale = { tag: "en", catalog: JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url))) };
const { ui } = await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString("base64")}`);
const { validateTree } = await import(`data:text/javascript;base64,${Buffer.from(contractOutput.outputFiles[0].text).toString("base64")}`);
const fixture = JSON.parse(await readFile(new URL("../ui/staff/fixtures/staff-live.json", import.meta.url)));
const view = structuredClone(fixture.view);
view.state.staff.payload.roster = {
  items: [{ kind: "item", prototype: "ambient", name: "Ambient", default_properties: {}, properties: [] }],
  structures: [], machines: [], mobs: [], bodies: [], items_truncated: true,
};

const flatten = (node) => node ? [node, ...(node.children ?? []).flatMap(flatten)] : [];
const nodes = () => flatten(ui.render(view));
const node = (id) => nodes().find((item) => item.id === id);
const event = (id, extra = {}) => ui.onEvent({ id, type: "activate", ...extra }, view).action;
const requestId = (action) => action.request.request_id;
const query = (action) => JSON.parse(action.request.action.Query.query);
const response = (action, body, responseQuery = query(action)) => {
  view.state.staff.payload.records.response = {
    request_id: requestId(action), query: responseQuery, refs: [], result: body,
  };
};
const item = (prototype, name = prototype, extraProperties = []) => catalogItem("item", prototype, name, extraProperties);
const catalogItem = (kind, prototype, name = prototype, extraProperties = []) => ({
  kind, prototype, name, default_properties: { name },
  properties: [{ path: "name", label: "Name", type: "text", value: name, editable: true }, ...extraProperties],
});

const dial = {
  path: "dial.recipe", label: "Recipe", type: "enum", value: 1,
  options: [{ value: 0, label: "One" }, { value: 1, label: "Two" }, { value: 2, label: "Three" }],
  editable: true, min: 0, max: 2, step: 1,
};

const mixed = {
  path: "mixed.value", label: "Mixed", type: "enum", value: 1,
  options: [1, "1"], editable: true,
};

test("catalog queries are explicit, paged, correlated, and preserve drafts", () => {
  view.state.staff.payload.records.response = null;
  view.state.staff.payload.workspace = "live";
  ui.render(view);
  const opening = event("staff/live/spawn");
  assert.deepEqual(query(opening), { kind: "catalog", category: "item", search: "", after: null, limit: 64 });
  const pendingTree = ui.render(view);
  assert(pendingTree);
  assert.doesNotThrow(() => validateTree(pendingTree), "pending spawn drawer satisfies the engine tree contract");
  assert(!node("staff/live/spawn/catalog/more"), "truncated ambient roster waits for its canonical first page");
  response(opening, { kind: "catalog", items: [item("ambient")], next: "ambient-next" });
  const loadedTree = ui.render(view);
  assert(loadedTree);
  assert.doesNotThrow(() => validateTree(loadedTree), "loaded valid spawn draft satisfies the engine tree contract");
  assert(node("staff/live/spawn/search"));
  assert(node("staff/live/spawn/catalog/more"), "canonical catalog replies expose the next page");

  const first = event("staff/live/spawn/search/submit", { value: "alpha" });
  assert.deepEqual(query(first), { kind: "catalog", category: "item", search: "alpha", after: null, limit: 64 });
  ui.render(view);
  const second = event("staff/live/spawn/search/submit", { value: "beta" });
  response(first, { kind: "catalog", items: [item("alpha")], next: "alpha-next" });
  assert(!nodes().some((item) => item.text === "alpha"), "a stale search reply must not replace the newer query");

  response(second, { kind: "catalog", items: [item("wrong-limit")], next: "wrong-limit-next" }, { ...query(second), limit: 63 });
  assert(node("staff/live/spawn/catalog/loading"), "same-ID replies with a wrong limit stay pending");
  response(second, { kind: "catalog", items: [item("extra-field")], next: "extra-field-next" }, { ...query(second), extra: true });
  assert(node("staff/live/spawn/catalog/loading"), "same-ID replies with an extra query field stay pending");

  response(second, { kind: "catalog", items: [item("beta", "Beta", [dial, mixed])], next: "beta-next" });
  let rendered = nodes();
  assert(rendered.some((entry) => entry.text === "Beta"));
  assert(node("staff/live/spawn/catalog/more"));

  const dialControl = node("staff/live/spawn/property/1");
  assert.equal(dialControl?.type, "select");
  assert.equal(dialControl?.value, "staff-option:1", "numeric descriptor current value remains selected");
  assert.equal(dialControl?.children?.find((entry) => entry.value === "staff-option:2")?.text, "Three");
  ui.onEvent({ id: "staff/live/spawn/property/1", type: "change", value: "staff-option:2" }, view);
  const place = event("staff/live/spawn/place");
  const spawn = place.request.action.Edit.edit.Spawn;
  assert.equal(JSON.parse(spawn.properties)["dial.recipe"], 2, "dial option is sent as a number");

  const mixedControl = node("staff/live/spawn/property/2");
  assert.deepEqual(mixedControl?.children?.map((entry) => entry.value), ["staff-option:1", 'staff-option:"1"']);
  ui.onEvent({ id: "staff/live/spawn/property/2", type: "change", value: 'staff-option:"1"' }, view);
  assert.equal(JSON.parse(event("staff/live/spawn/place").request.action.Edit.edit.Spawn.properties)["mixed.value"], "1");
  ui.onEvent({ id: "staff/live/spawn/property/2", type: "change", value: "staff-option:1" }, view);
  assert.equal(JSON.parse(event("staff/live/spawn/place").request.action.Edit.edit.Spawn.properties)["mixed.value"], 1);

  const property = node("staff/live/spawn/property/0");
  assert(property);
  const propertyInput = nodes().find((entry) => entry.id === "staff/live/spawn/property/0" && entry.type === "input");
  assert(propertyInput);
  ui.onEvent({ id: propertyInput.id, type: "change", value: "Draft name" }, view);
  rendered = nodes();
  const more = event("staff/live/spawn/catalog/more");
  assert.equal(query(more).after, "beta-next");
  response(more, { kind: "catalog", items: [item("gamma", "Gamma")], next: null });
  rendered = nodes();
  assert(rendered.some((entry) => entry.text === "Beta"));
  assert(rendered.some((entry) => entry.text === "Gamma"));
  assert.equal(nodes().find((entry) => entry.id === propertyInput.id)?.value, "Draft name");

  const drafts = event("staff/live/spawn/search/submit", { value: "drafts" });
  response(drafts, { kind: "catalog", items: Array.from({ length: 25 }, (_, index) => item(`draft-${index}`)), next: null });
  ui.render(view);
  for (let index = 0; index < 25; index += 1) {
    ui.onEvent({ id: "staff/live/spawn/prototype", type: "change", value: `draft-${index}` }, view);
    ui.render(view);
    ui.onEvent({ id: "staff/live/spawn/property/0", type: "change", value: `Draft ${index}` }, view);
    ui.render(view);
  }
  assert.equal(nodes().find((entry) => entry.id === "staff/live/spawn/property/0")?.value, "Draft 24", "the active draft survives the bounded LRU");

  const bounded = event("staff/live/spawn/search/submit", { value: "bounded" });
  let page = bounded;
  for (let index = 0; index < 24; index += 1) {
    response(page, { kind: "catalog", items: Array.from({ length: 64 }, (_, row) => item(`bounded-${index}-${row}`)), next: `bounded-${index + 1}` });
    ui.render(view);
    if (index < 23) page = event("staff/live/spawn/catalog/more");
  }
  assert(!node("staff/live/spawn/catalog/more"), "catalog paging stops at the aggregate row bound");
});

test("kind changes request an exact category page", () => {
  const kind = node("staff/live/spawn/kind");
  assert(kind);
  const action = ui.onEvent({ id: kind.id, type: "change", value: "body" }, view).action;
  assert.deepEqual(query(action), { kind: "catalog", category: "body", search: "bounded", after: null, limit: 64 });
});

test("catalog nullable enums expose a clear option and preserve absent options", () => {
  const kind = node("staff/live/spawn/kind");
  assert(kind);
  const kindAction = ui.onEvent({ id: kind.id, type: "change", value: "item" }, view).action;
  const search = event("staff/live/spawn/search/submit", { value: "nullable" });
  const nullableRow = item("nullable", "Nullable", [{ path: "mount", label: "Mount", type: "enum", value: null, options: ["north", "south"], nullable: true, editable: true }]);
  nullableRow.default_properties.mount = "north";
  response(search, {
    kind: "catalog",
    items: [
      nullableRow,
      item("without-options", "Without options", [{ path: "mount", label: "Mount", type: "enum", value: "north", nullable: true, editable: true }]),
    ],
    next: null,
  });
  ui.render(view);
  assert.deepEqual(query(kindAction), { kind: "catalog", category: "item", search: "bounded", after: null, limit: 64 });
  const nullable = node("staff/live/spawn/property/1");
  assert(nullable);
  assert.equal(nullable.type, "select");
  assert(nullable.children?.some((option) => option.value === "staff-option:null"));
  const defaults = JSON.parse(event("staff/live/spawn/place").request.action.Edit.edit.Spawn.properties);
  assert.equal(defaults.mount, undefined, "a null descriptor keeps the prototype default untouched");

  ui.onEvent({ id: "staff/live/spawn/prototype", type: "change", value: "without-options" }, view);
  ui.render(view);
  const withoutOptions = node("staff/live/spawn/property/1");
  assert(withoutOptions);
  assert.equal(withoutOptions.type, "input", "nullable does not invent options when the schema omits them");
});

test("Place revalidates refreshed spawn drafts and preserves exact primitives", () => {
  const absentSearch = event("staff/live/spawn/search/submit", { value: "absent-enum" });
  response(absentSearch, {
    kind: "catalog",
    items: [item("absent-enum", "Absent enum", [{ path: "mount", label: "Mount", type: "enum", value: "north", editable: true }])],
    next: null,
  });
  ui.render(view);
  const absentProperty = node("staff/live/spawn/property/1");
  assert.equal(absentProperty?.type, "input");
  assert.equal(absentProperty?.disabled, true, "an enum without disclosed options is unavailable");
  ui.onEvent({ id: "staff/live/spawn/property/1", type: "change", value: "arbitrary" }, view);
  assert.equal(event("staff/live/spawn/place"), undefined, "an arbitrary absent-option enum cannot dispatch");

  const initialSearch = event("staff/live/spawn/search/submit", { value: "stale-draft" });
  response(initialSearch, { kind: "catalog", items: [validationItem(true, ["one", "two"])], next: null });
  ui.render(view);
  ui.onEvent({ id: "staff/live/spawn/property/1", type: "change", value: "staff-option:null" }, view);
  ui.onEvent({ id: "staff/live/spawn/property/2", type: "change", value: 'staff-option:"two"' }, view);

  const refreshedSearch = event("staff/live/spawn/search/submit", { value: "refreshed" });
  response(refreshedSearch, { kind: "catalog", items: [validationItem(false, ["one"])], next: null });
  const invalidDraftTree = ui.render(view);
  assert(invalidDraftTree);
  assert.doesNotThrow(() => validateTree(invalidDraftTree), "loaded invalid spawn draft satisfies the engine tree contract");
  assert.equal(node("staff/live/spawn/place")?.disabled, true, "a removed option disables Place");
  assert.equal(event("staff/live/spawn/place"), undefined, "removed null and option values cannot dispatch");

  const validSearch = event("staff/live/spawn/search/submit", { value: "valid-draft" });
  response(validSearch, { kind: "catalog", items: [validationItem(true, ["one", "two"])], next: null });
  const validDraftTree = ui.render(view);
  assert(validDraftTree);
  assert.doesNotThrow(() => validateTree(validDraftTree), "loaded valid spawn draft satisfies the engine tree contract");
  ui.onEvent({ id: "staff/live/spawn/property/3", type: "change", value: "" }, view);
  ui.onEvent({ id: "staff/live/spawn/property/4", type: "change", value: "false" }, view);
  ui.onEvent({ id: "staff/live/spawn/property/5", type: "change", value: "0" }, view);
  const placed = event("staff/live/spawn/place");
  assert(placed);
  const properties = JSON.parse(placed.request.action.Edit.edit.Spawn.properties);
  assert.equal(properties.name, "Validation");
  assert.equal(properties.mount, null);
  assert.equal(properties.choice, "two");
  assert.equal(properties.label, "");
  assert.equal(properties.flag, false);
  assert.equal(properties.count, 0);
});

console.log("staff catalog: explicit full-query search, stale-reply rejection, paging, and draft retention");

function validationItem(nullableMount, choiceOptions) {
  return item("validation", "Validation", [
    { path: "mount", label: "Mount", type: "enum", value: "north", options: ["north", "south"], nullable: nullableMount, editable: true },
    { path: "choice", label: "Choice", type: "enum", value: "one", options: choiceOptions, editable: true },
    { path: "label", label: "Label", type: "string", value: "seed", editable: true },
    { path: "flag", label: "Flag", type: "boolean", value: true, editable: true },
    { path: "count", label: "Count", type: "number", value: 1, editable: true },
  ]);
}
