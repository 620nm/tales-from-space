import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw Error("Pass the engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const output = await build({
  stdin: {
    contents: [
      "export { default as ui } from './staff/main';",
      "export { createCaseRequest, resetStaffFlows, staffViewAction } from './staff/flows';",
      "export { readStaff } from './staff/model';",
      "export { cachedCase, contextFullRows, contextPageFor, MAX_CASE_ENTRIES, MAX_CASE_NESTED_ROWS, MAX_CONTEXT_ENTRIES, MAX_CONTEXT_PAGES, MAX_CONTEXT_PROFILES, MAX_CONTEXT_ROWS, rememberRecordResponse, resetRecordCaches, responseProfileFor } from './staff/cases/records';",
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
const { ui, cachedCase, createCaseRequest, readStaff, resetStaffFlows, contextFullRows, contextPageFor, MAX_CASE_ENTRIES, MAX_CASE_NESTED_ROWS, MAX_CONTEXT_ENTRIES, MAX_CONTEXT_PAGES, MAX_CONTEXT_PROFILES, MAX_CONTEXT_ROWS, rememberRecordResponse, resetRecordCaches, responseProfileFor } = await import(
  `data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString("base64")}`,
);
globalThis.__lunaticLocale = {
  tag: "en",
  catalog: JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url))),
};

const fixture = JSON.parse(await readFile(new URL("../ui/staff/fixtures/staff-live.json", import.meta.url))).view;
const anchor = { round: "84", kind: "body", id: "4294967297" };
const secondAnchor = { round: "84", kind: "item", id: "4294967300" };
const account = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
const row = (id, target = anchor) => ({
  reference: { round: "84", kind: "event", id },
  event_type: "staff_test",
  server_id: "server",
  created_at_ms: Number(id),
  tick: Number(id),
  payload: { action: `row ${id}`, target_ref: target },
  refs: [target, { round: "", kind: "account", id: account }],
  account: { round: "", kind: "account", id: account },
  deleted: false,
});
const caseRecord = {
  reference: { round: "84", kind: "case", id: "9001" },
  created_at: 1,
  label: "Fresh case",
  direct_anchor_history: [anchor, secondAnchor],
  case_addressed_events: [],
  attachments: [],
  notes: [],
  statuses: [],
  outcomes: [],
};

function response(payload, requestId, query, result, error = null) {
  payload.records.response = { request_id: requestId, query, refs: [], cursor: null, result, error };
}

function queryOf(action) {
  return JSON.parse(action.request.action.Query.query);
}

function cloneView() {
  return structuredClone(fixture);
}

test("create response opens exact case and reads each explicit anchor in order", { concurrency: false }, () => {
  resetStaffFlows();
  resetRecordCaches();
  const view = cloneView();
  ui.render(view);
  const create = ui.onEvent({ id: "staff/live/read/case/create", type: "activate" }, view).action;
  assert.equal(create.request.action.Records.request.includes('"op":"create_case"'), true);

  const payload = view.state.staff.payload;
  response(payload, create.request.request_id, { op: "create_case" }, { kind: "case_created", case: caseRecord.reference });
  const caseQuery = ui.onView(view).action;
  assert.deepEqual(queryOf(caseQuery), { op: "case", case: caseRecord.reference, limit: 64 });

  response(payload, caseQuery.request.request_id, { op: "case", case: caseRecord.reference, limit: 64 }, { kind: "case", case: caseRecord, next: null });
  const firstContext = ui.onView(view).action;
  assert.deepEqual(queryOf(firstContext), { op: "context", anchor, limit: 64 });

  response(payload, firstContext.request.request_id, { op: "context", anchor, limit: 64 }, {
    kind: "context",
    context: { anchor, source_events: [row("11").reference], historical_owned_bodies: [secondAnchor], next: null },
    rows: [row("11")],
    profiles: [{ id: account, username: "Rowan", avatar: "portrait-02", role: "player" }],
  });
  const secondContext = ui.onView(view).action;
  assert.deepEqual(queryOf(secondContext), { op: "context", anchor: secondAnchor, limit: 64 });

  response(payload, secondContext.request.request_id, { op: "context", anchor: secondAnchor, limit: 64 }, {
    kind: "context",
    // The body and account are derived evidence; neither is queried here.
    context: { anchor: secondAnchor, source_events: [row("12", secondAnchor).reference], historical_owned_bodies: [anchor], next: null },
    rows: [row("12", secondAnchor)],
    profiles: [{ id: account, username: "Rowan", avatar: "portrait-02", role: "player" }],
  });
  assert.equal(ui.onView(view).action, undefined);
  const session = view.state.staff;
  assert.equal(contextFullRows(session, anchor).length, 1);
  assert.equal(responseProfileFor(session, account)?.username, "Rowan");
});

test("create response refreshes an ambient case with the same reference", { concurrency: false }, () => {
  resetStaffFlows();
  resetRecordCaches();
  const view = cloneView();
  const payload = view.state.staff.payload;
  payload.records.cases = [{
    ...caseRecord,
    label: "Stale summary",
    direct_anchor_history: [secondAnchor],
  }];
  ui.render(view);
  const create = ui.onEvent({ id: "staff/live/read/case/create", type: "activate" }, view).action;
  response(payload, create.request.request_id, { op: "create_case" }, { kind: "case_created", case: caseRecord.reference });
  const caseQuery = ui.onView(view).action;
  assert.deepEqual(queryOf(caseQuery), { op: "case", case: caseRecord.reference, limit: 64 });

  response(payload, caseQuery.request.request_id, queryOf(caseQuery), { kind: "case", case: caseRecord, next: null });
  const firstContext = ui.onView(view).action;
  assert.deepEqual(queryOf(firstContext), { op: "context", anchor, limit: 64 });
});

test("historical case references stay exact while opening", { concurrency: false }, () => {
  resetStaffFlows();
  resetRecordCaches();
  const view = cloneView();
  view.state.staff.round_id = "85";
  view.state.staff.payload.current_round = "85";
  view.state.staff.payload.workspace = "cases";
  const payload = view.state.staff.payload;
  const create = createCaseRequest(readStaff(view), anchor);
  response(payload, create.request.request_id, { op: "create_case" }, { kind: "case_created", case: caseRecord.reference });
  const action = ui.onView(view).action;
  assert.deepEqual(queryOf(action), { op: "case", case: caseRecord.reference, limit: 64 });
});

test("a pending read waits through unrelated updates and foreign replies", { concurrency: false }, () => {
  resetStaffFlows();
  resetRecordCaches();
  const view = cloneView();
  const payload = view.state.staff.payload;
  response(payload, "unbound-create", { op: "create_case" }, { kind: "case_created", case: caseRecord.reference });
  assert.equal(ui.onView(view).action, undefined);
  ui.render(view);
  const create = ui.onEvent({ id: "staff/live/read/case/create", type: "activate" }, view).action;
  response(payload, create.request.request_id, { op: "create_case" }, { kind: "case_created", case: caseRecord.reference });
  const first = ui.onView(view).action;
  assert.deepEqual(queryOf(first), { op: "case", case: caseRecord.reference, limit: 64 });
  assert.equal(ui.onView(view).action, undefined);

  const queued = structuredClone(view);
  queued.state.staff.payload.workspace = "cases";
  queued.state.staff.revision = "8";
  queued.state.staff.payload.revision = "8";
  for (let i = 0; i < 8; i += 1) assert.equal(ui.onView(queued).action, undefined);

  response(payload, "foreign-case-read", queryOf(first), { kind: "case", case: caseRecord, next: null });
  assert.equal(ui.onView(view).action, undefined);
  response(payload, first.request.request_id, queryOf(first), { kind: "case", case: caseRecord, next: null });
  const context = ui.onView(view).action;
  assert.deepEqual(queryOf(context), { op: "context", anchor, limit: 64 });
});

test("bound and stale read errors retry three times then leave manual recovery", { concurrency: false }, () => {
  resetStaffFlows();
  resetRecordCaches();
  const view = cloneView();
  const payload = view.state.staff.payload;
  ui.render(view);
  const create = ui.onEvent({ id: "staff/live/read/case/create", type: "activate" }, view).action;
  response(payload, create.request.request_id, { op: "create_case" }, { kind: "case_created", case: caseRecord.reference });
  const caseRead = ui.onView(view).action;
  response(payload, caseRead.request.request_id, queryOf(caseRead), { kind: "case", case: caseRecord, next: null });
  let read = ui.onView(view).action;
  const query = queryOf(read);
  for (let attempt = 0; attempt < 4; attempt += 1) {
    response(payload, read.request.request_id, query, null, attempt === 0 ? "stale_revision" : "query_bound");
    const next = ui.onView(view).action;
    if (attempt < 3) {
      assert.ok(next, `retry ${attempt + 1} is issued`);
      assert.deepEqual(queryOf(next), query);
      read = next;
    } else {
      assert.equal(next, undefined);
      assert.equal(ui.onView(structuredClone(view)).action, undefined);
    }
  }
});

test("opening a case does not trap navigation and profile drill remains an input", { concurrency: false }, async () => {
  resetStaffFlows();
  resetRecordCaches();
  const view = cloneView();
  const payload = view.state.staff.payload;
  ui.render(view);
  const create = ui.onEvent({ id: "staff/live/read/case/create", type: "activate" }, view).action;
  response(payload, create.request.request_id, { op: "create_case" }, { kind: "case_created", case: caseRecord.reference });
  ui.onView(view);
  ui.render(view);
  const live = ui.onEvent({ id: "staff/workspace/live", type: "activate" }, view);
  assert.equal(live.action, undefined);
  ui.render(view);
  const toggle = ui.onEvent({ id: "staff/header/inspector", type: "activate" }, view);
  assert.equal(toggle.action, undefined);
  const tree = ui.render(view);
  const nodes = (node) => [node, ...(node.children ?? []).flatMap(nodes)];
  assert.equal(nodes(tree).some((node) => node.id === "staff/live/layout"), true);
  assert.equal(nodes(tree).some((node) => node.id === "staff/live/inspector"), false);

  const casesFixture = JSON.parse(await readFile(new URL("../ui/staff/fixtures/staff-cases.json", import.meta.url))).view;
  resetStaffFlows();
  ui.onEvent({ id: "staff/workspace/cases", type: "activate" }, casesFixture);
  ui.render(casesFixture);
  const selected = ui.onEvent({ id: "staff/cases/select/1201", type: "activate" }, casesFixture).action;
  assert.deepEqual(queryOf(selected), { op: "case", case: { round: "84", kind: "case", id: "1201" }, limit: 64 });
  const profile = ui.onEvent({ id: "staff/cases/event/901/profile/open", type: "activate" }, casesFixture).action;
  assert.equal(JSON.parse(profile.request.action.Query.query).op, "profile");
});

test("record caches use LRU and per-context bounds", { concurrency: false }, () => {
  resetStaffFlows();
  resetRecordCaches();
  const view = cloneView();
  const session = readStaff(view);
  const payload = view.state.staff.payload;
  const anchors = Array.from({ length: MAX_CONTEXT_ENTRIES }, (_, i) => ({ round: "84", kind: "body", id: String(5000 + i) }));
  for (const [i, item] of anchors.entries()) {
    response(payload, `context-${i}`, { op: "context", anchor: item, limit: 64 }, { kind: "context", context: { anchor: item, next: null }, rows: [row(String(20000 + i), item)], profiles: [] });
    contextFullRows(session, item);
  }
  assert.equal(contextFullRows(session, anchors[0]).length, 1);
  const extra = { round: "84", kind: "body", id: "6000" };
  response(payload, "context-extra", { op: "context", anchor: extra, limit: 64 }, { kind: "context", context: { anchor: extra, next: null }, rows: [row("26000", extra)], profiles: [] });
  contextFullRows(session, extra);
  assert.equal(contextFullRows(session, anchors[0]).length, 1, "recently read context stays hot");
  assert.equal(contextFullRows(session, anchors[1]).length, 0, "oldest untouched context is evicted");

  const crowded = { round: "84", kind: "body", id: "7000" };
  const profiles = Array.from({ length: 300 }, (_, i) => ({ id: i.toString(16).padStart(64, "0"), username: `P${i}`, avatar: "portrait-01", role: "player" }));
  const rows = Array.from({ length: 1100 }, (_, i) => row(String(30000 + i), crowded));
  response(payload, "context-crowded", { op: "context", anchor: crowded, limit: 64 }, { kind: "context", context: { anchor: crowded, next: "more" }, rows, profiles });
  const crowdedPage = contextPageFor(session, crowded);
  assert.equal(crowdedPage.rows.length, MAX_CONTEXT_ROWS);
  assert.equal(crowdedPage.fullRows.length, MAX_CONTEXT_ROWS);
  assert.equal(crowdedPage.profiles.length, MAX_CONTEXT_PROFILES);
  assert.equal(crowdedPage.next, null);

  const paged = { round: "84", kind: "body", id: "7100" };
  for (let page = 0; page < MAX_CONTEXT_PAGES; page += 1) {
    const query = { op: "context", anchor: paged, limit: 64, ...(page ? { after: `cursor-${page}` } : {}) };
    response(payload, `context-page-${page}`, query, { kind: "context", context: { anchor: paged, next: `cursor-${page + 1}` }, rows: [row(String(32000 + page), paged)], profiles: [] });
    contextPageFor(session, paged);
  }
  assert.equal(contextPageFor(session, paged).rows.length, MAX_CONTEXT_PAGES);
  assert.equal(contextPageFor(session, paged).next, null, "page cap ends the manual pager");

  const cases = Array.from({ length: MAX_CASE_ENTRIES + 1 }, (_, i) => ({ ...caseRecord, reference: { round: "84", kind: "case", id: String(8000 + i) }, notes: Array.from({ length: MAX_CASE_NESTED_ROWS + 100 }, (_, n) => ({ text: `${i}:${n}` })) }));
  for (const [i, item] of cases.entries()) {
    response(payload, `case-${i}`, { op: "case", case: item.reference, limit: 64 }, { kind: "case", case: item, next: null });
    rememberRecordResponse(session);
    if (i === 1) cachedCase(session, cases[0].reference);
  }
  assert.ok(cachedCase(session, cases[0].reference), "recently read case stays hot");
  assert.equal(cachedCase(session, cases[1].reference), null, "oldest untouched case is evicted");
  assert.equal(cachedCase(session, cases[MAX_CASE_ENTRIES].reference)?.notes.length, MAX_CASE_NESTED_ROWS);
});

console.log("staff flows: create, historical and queued-read response chains");
