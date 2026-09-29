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
      "export { resetEconomyReads } from './staff/economy';",
      "export { resetActionScope } from './staff/shared/actions';",
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
const { ui, resetEconomyReads, resetActionScope } = await import(
  `data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString("base64")}`,
);
globalThis.__lunaticLocale = {
  tag: "en",
  catalog: JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url))),
};

const fixture = JSON.parse(await readFile(new URL("../ui/staff/fixtures/staff-live.json", import.meta.url))).view;
const sourceDb = "0123456789abcdef0123456789abcdef";
const account = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd";
const round = "84";
const bytes = (value, length = 16) => Array.from({ length }, () => value & 255);
const digest = (value) => bytes(value, 32);
const ref = (kind, id) => ({ round, kind, id });
const itemRef = ref("economy_item", "01010101010101010101010101010101");

function cloneView() {
  const view = structuredClone(fixture);
  view.state.staff.payload.workspace = "economy";
  view.state.staff.payload.records.response = null;
  return view;
}

function queryOf(action) {
  return JSON.parse(action.request.action.Query.query);
}

function response(view, request, query, result, error = null) {
  view.state.staff.payload.records.response = {
    request_id: typeof request === "string" ? request : request.request.request_id,
    query,
    refs: [],
    cursor: result?.next ?? null,
    result,
    error,
  };
}

function receipt(sequence, status = "Committed") {
  const value = Number(String(sequence).slice(-3)) % 256;
  return {
    attempt: { transaction_id: bytes(value), semantic_digest: digest(value + 10) },
    world_id: bytes(value + 20),
    account_id: bytes(value + 30),
    status,
    semantic_digest: digest(value + 10),
    semantic_inputs: { content: digest(value + 40), definitions: [], inputs: [] },
    entitlement: null,
    mutations: [],
    receipt_digest: digest(value + 50),
  };
}

function row(sequence, refs = [itemRef], status = "Committed") {
  return { sequence: String(sequence), receipt: receipt(sequence, status), refs, ref_count: refs.length, refs_more: false };
}

function economyResult(rows, next = null, completeness = null, anomalies = []) {
  return { kind: "economy", source_db: sourceDb, rows, next, completeness, anomalies };
}

function tree(node) {
  return [node, ...(node.children ?? []).flatMap(tree)];
}

function nodeText(node) {
  return tree(node).map((item) => item.text ?? "").join(" ");
}

function nodeById(node, id) {
  return tree(node).find((item) => item.id === id);
}

function openEconomy(view) {
  ui.render(view);
  ui.onEvent({ id: "staff/workspace/economy", type: "activate" }, view);
  ui.render(view);
}

function edit(view, id, value) {
  ui.render(view);
  return ui.onEvent({ id, type: "change", value }, view).action;
}

function lookup(view) {
  ui.render(view);
  return ui.onEvent({ id: "staff/economy/lookup", type: "activate" }, view).action;
}

test("player-time uses the required object selector and refuses malformed bounds", { concurrency: false }, () => {
  resetActionScope();
  resetEconomyReads();
  const view = cloneView();
  openEconomy(view);
  edit(view, "staff/economy/source-db", sourceDb);
  edit(view, "staff/economy/subject-kind", "player_time");
  edit(view, "staff/economy/subject", account);
  edit(view, "staff/economy/player-from", "900719925474099300");

  assert.equal(lookup(view), undefined, "a missing upper bound must never leave the UI");
  edit(view, "staff/economy/player-to", "900719925474099299");
  assert.equal(lookup(view), undefined, "a reversed range must never leave the UI");
  edit(view, "staff/economy/player-to", "900719925474099312");
  const action = lookup(view);
  assert.deepEqual(queryOf(action), {
    op: "economy",
    source_db: sourceDb,
    selector: {
      kind: "player_time",
      value: { player: account, from: "900719925474099300", to: "900719925474099312" },
    },
    after: null,
    limit: 64,
  });
});

test("draft edits clear old pages and stale replies cannot repopulate them", { concurrency: false }, () => {
  resetActionScope();
  resetEconomyReads();
  const view = cloneView();
  openEconomy(view);
  edit(view, "staff/economy/source-db", sourceDb);
  edit(view, "staff/economy/subject-kind", "item_uuid");
  edit(view, "staff/economy/subject", "item-a");
  const first = lookup(view);
  const firstQuery = queryOf(first);
  response(view, first, firstQuery, economyResult([row(1)]));
  ui.onView(view);
  assert.match(nodeText(ui.render(view)), /\[1,1,1/);

  edit(view, "staff/economy/subject", "item-b");
  assert.doesNotMatch(nodeText(ui.render(view)), /\[1,1,1/);
  const second = lookup(view);
  const secondQuery = queryOf(second);
  assert.equal(secondQuery.selector.value, "item-b");

  response(view, first, firstQuery, economyResult([row(1)]));
  ui.onView(view);
  assert.doesNotMatch(nodeText(ui.render(view)), /\[1,1,1/);
  response(view, second, secondQuery, economyResult([row(2)]));
  ui.onView(view);
  assert.match(nodeText(ui.render(view)), /\[2,2,2/);
  assert.match(nodeText(ui.render(view)), /item-b/);
});

test("serialized receipt statuses and typed economy evidence refs render and drill exactly", { concurrency: false }, () => {
  resetActionScope();
  resetEconomyReads();
  const view = cloneView();
  openEconomy(view);
  edit(view, "staff/economy/source-db", sourceDb);
  edit(view, "staff/economy/subject-kind", "item_uuid");
  edit(view, "staff/economy/subject", "item-a");
  const request = lookup(view);
  const query = queryOf(request);
  const refs = [
    itemRef,
    ref("economy_mint_lot", "02020202020202020202020202020202"),
    ref("economy_balance", "03030303030303030303030303030303"),
    ref("economy_entitlement", "04".repeat(32)),
    ref("economy_source_event", "05".repeat(16)),
    ref("economy_transaction", "06".repeat(16)),
    ref("event", "903"),
  ];
  response(view, request, query, economyResult([
    { ...row(1, refs), ref_count: refs.length + 4, refs_more: true },
    row(2, [], { Rejected: { code: "StaleStateVersion" } }),
  ]));
  ui.onView(view);
  const rendered = ui.render(view);
  const text = nodeText(rendered);
  assert.match(text, /Committed/);
  assert.match(text, /lunatic\/tfs:ui\.staff\.economy_references · 7\/11/);
  assert.match(text, /lunatic\/tfs:ui\.staff\.economy_references_more/);
  assert.match(text, /Rejected · StaleStateVersion/);
  assert.match(text, /04[,"]?04/);

  const itemAction = ui.onEvent({ id: "staff/economy/row/1/ref/0", type: "activate" }, view).action;
  assert.deepEqual(queryOf(itemAction).selector, { kind: "item_uuid", value: itemRef.id });
  const entitlementAction = ui.onEvent({ id: "staff/economy/row/1/ref/3", type: "activate" }, view).action;
  assert.deepEqual(queryOf(entitlementAction).selector, { kind: "entitlement", value: "04".repeat(32) });
  assert.equal(nodeById(rendered, "staff/economy/row/1/ref/6").type, "text", "generic staff events are not economy source events");
});

test("paging keeps decimal cursors exact and reports lag as highwater minus cursor", { concurrency: false }, () => {
  resetActionScope();
  resetEconomyReads();
  const view = cloneView();
  openEconomy(view);
  edit(view, "staff/economy/source-db", sourceDb);
  edit(view, "staff/economy/subject-kind", "item_uuid");
  edit(view, "staff/economy/subject", "item-a");
  const first = lookup(view);
  response(view, first, queryOf(first), economyResult(
    [row("900719925474099300")],
    "900719925474099300",
    {
      source_db_id: sourceDb,
      namespace: "staff",
      source_highwater: "900719925474099312",
      cursor: "900719925474099300",
      sampled_at_ms: "900719925474099200",
      oldest_pending_seq: "900719925474099301",
      status: "incomplete",
      error: null,
    },
  ));
  ui.onView(view);
  const rendered = ui.render(view);
  assert.match(nodeText(rendered), /900719925474099200/);
  assert.match(nodeText(rendered), /\b12\b/, "lag is the exact highwater-cursor difference");
  const next = ui.onEvent({ id: "staff/economy/results/next", type: "activate" }, view).action;
  assert.equal(queryOf(next).after, "900719925474099300");
  assert.equal(queryOf(next).limit, 64);

  response(view, next, queryOf(next), economyResult([], null, {
    source_db_id: sourceDb,
    namespace: "staff",
    source_highwater: null,
    cursor: "900719925474099300",
    sampled_at_ms: null,
    oldest_pending_seq: null,
    status: "unknown",
    error: "source unavailable",
  }));
  ui.onView(view);
  const unknown = nodeText(ui.render(view));
  assert.match(unknown, /source unavailable/);
  assert.doesNotMatch(unknown, /Projection lag.*900719925474099300/);
});

test("receipt definition references open bounded mirror chunks and preserve unavailable state", { concurrency: false }, () => {
  resetActionScope();
  resetEconomyReads();
  const view = cloneView();
  openEconomy(view);
  edit(view, "staff/economy/source-db", sourceDb);
  edit(view, "staff/economy/subject-kind", "item_uuid");
  edit(view, "staff/economy/subject", "item-a");
  const request = lookup(view);
  const query = queryOf(request);
  const digest = "ab".repeat(32);
  response(view, request, query, economyResult([row(1, [ref("economy_definition", digest)])]));
  ui.onView(view);
  ui.render(view);
  const definitionRequest = ui.onEvent({ id: "staff/economy/row/1/ref/0", type: "activate" }, view).action;
  const definitionQuery = queryOf(definitionRequest);
  assert.deepEqual(definitionQuery, {
    op: "economy_definition",
    source_db: sourceDb,
    digest,
    offset: "0",
    limit: 65536,
  });
  response(view, definitionRequest, definitionQuery, {
    kind: "economy_definition",
    source_db: sourceDb,
    digest,
    owner: "pack/owner",
    format_version: 3,
    total_bytes: "5",
    offset: "0",
    encoding: "base64",
    payload: "eyJ2ZXJzaW9uIjozfQ",
    next_offset: null,
    state: "complete",
    complete: true,
    available: true,
    error: null,
  });
  ui.onView(view);
  const rendered = nodeText(ui.render(view));
  assert.match(rendered, /economy_definition_complete/);
  assert.match(rendered, /eyJ2ZXJzaW9uIjozfQ/);
  assert.match(rendered, /pack\/owner/);

  ui.render(view);
  const unavailableRequest = ui.onEvent({ id: "staff/economy/row/1/ref/0", type: "activate" }, view).action;
  response(view, unavailableRequest, queryOf(unavailableRequest), {
    kind: "economy_definition",
    source_db: sourceDb,
    digest,
    offset: "0",
    next_offset: null,
    state: "missing",
    complete: false,
    available: false,
    error: "definition has not been mirrored",
  });
  ui.onView(view);
  assert.match(nodeText(ui.render(view)), /economy_definition_unavailable/);

  ui.render(view);
  const incompleteRequest = ui.onEvent({ id: "staff/economy/row/1/ref/0", type: "activate" }, view).action;
  response(view, incompleteRequest, queryOf(incompleteRequest), {
    kind: "economy_definition",
    source_db: sourceDb,
    digest,
    offset: "0",
    next_offset: null,
    state: "incomplete",
    complete: false,
    available: false,
    error: null,
  });
  ui.onView(view);
  const incompleteRendered = ui.render(view);
  assert.match(nodeText(incompleteRendered), /economy_definition_incomplete/);
  assert.match(nodeText(incompleteRendered), /economy_definition_state.*incomplete/);
  assert.doesNotMatch(nodeText(incompleteRendered), /economy_definition_continuation/);
  assert.ok(nodeById(incompleteRendered, "staff/economy/definition/status").class?.includes("staff-warning"));
  assert.equal(nodeById(incompleteRendered, "staff/economy/definition/next"), undefined);
  assert.equal(nodeById(incompleteRendered, "staff/economy/definition/payload"), undefined);
});

console.log("staff economy: typed selectors, correlated pages, receipt evidence and exact cursors");
