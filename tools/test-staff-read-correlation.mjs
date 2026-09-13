import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";

const engine = process.argv[2] ?? process.env.LUNATIC_ENGINE;
if (!engine) throw Error("Pass the engine checkout path.");
const { build } = await import(pathToFileURL(resolve(engine, "web/node_modules/esbuild/lib/main.js")));
const output = await build({
  stdin: { contents: [
    "export { begin, event } from './view';",
    "export { readStaff } from './staff/model';",
    "export { profileCard } from './staff/actions';",
    "export { conversationFor, profileView, resetProfileCaches, warningCount, messageCount } from './staff/profile/data';",
    "export { staffRequest, resetActionScope } from './staff/shared/actions';",
  ].join("\n"), resolveDir: fileURLToPath(new URL("../ui", import.meta.url)), loader: "ts" },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") }, bundle: true, format: "esm", platform: "node", write: false,
});
const { begin, event, readStaff, profileCard, conversationFor, profileView, resetProfileCaches, warningCount, messageCount, staffRequest, resetActionScope } = await import(
  `data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString("base64")}`,
);

globalThis.__lunaticLocale = { tag: "en", catalog: JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url))) };
const fixture = JSON.parse(await readFile(new URL("../ui/staff/fixtures/staff-profile.json", import.meta.url))).view;
const accountId = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
const account = { round: "", kind: "account", id: accountId };

function cloneView() {
  const view = structuredClone(fixture);
  view.state.staff.round_id = "84";
  view.state.staff.payload.current_round = "84";
  return view;
}

function payloadOf(view) {
  return view.state.staff.payload;
}

function requestId(action) {
  return action.request.request_id;
}

function queryOf(action) {
  return JSON.parse(action.request.action.Query.query);
}

function response(view, request, query, result, error = null) {
  payloadOf(view).records.response = { request_id: typeof request === "string" ? request : requestId(request), query, refs: [], cursor: null, result, error };
}

function profileResult(username, warnings = [], next = null) {
  return { kind: "profile", profile: {
    target: account,
    identity: { id: accountId, username, avatar: "portrait-02", role: "player" },
    warnings, notes: [], conversations: [], next,
  } };
}

function profileQuery(after) {
  return { op: "profile", target: account, ...(after ? { after } : {}), limit: 64 };
}

function warning(text, at = 1) {
  return { target: account, author: { round: "", kind: "account", id: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }, at, text };
}

const conversation = { round: "84", kind: "conversation", id: "7001" };
const message = { round: "84", kind: "message", id: "7002" };

function conversationQuery() {
  return { op: "conversation", conversation, limit: 16, newest: true };
}

function conversationResult(body) {
  return { kind: "conversation_page", conversation: {
    reference: conversation, account, messages: [{ reference: message, body }], delivery_receipts: [], next: null,
  } };
}

test("ambient profile snapshots survive until a local read, then delayed ids stay out", { concurrency: false }, () => {
  resetActionScope(); resetProfileCaches();
  const view = cloneView();
  const session = readStaff(view);
  assert(session);
  const query = profileQuery();
  response(view, "ambient-profile", query, profileResult("Ambient Rowan"));
  assert.equal(profileView(session, accountId)?.profile.username, "Ambient Rowan");

  const newer = staffRequest(session, { kind: "query", query: JSON.stringify(query) });
  response(view, "ambient-profile", query, profileResult("Delayed Rowan", [warning("delayed")]));
  const delayed = profileView(session, accountId);
  assert(delayed);
  assert.equal(delayed.profile.username, "Ambient Rowan");
  assert.equal(delayed.records.warnings.length, 0);

  response(view, newer, query, profileResult("Fresh Rowan", [warning("fresh")]));
  const fresh = profileView(session, accountId);
  assert(fresh);
  assert.equal(fresh.profile.username, "Fresh Rowan");
  assert.deepEqual(fresh.warnings.map((row) => row.text), ["fresh"]);
  response(view, "ambient-profile", query, profileResult("Late Delayed Rowan", [warning("late-delayed")]));
  assert.equal(profileView(session, accountId)?.profile.username, "Fresh Rowan");
});

test("the first local read is registered before a cold cache can initialize", { concurrency: false }, () => {
  resetActionScope(); resetProfileCaches();
  const view = cloneView();
  payloadOf(view).records.response = null;
  const session = readStaff(view);
  assert(session);
  const query = profileQuery();
  const read = staffRequest(session, { kind: "query", query: JSON.stringify(query) });
  response(view, { request: { request_id: "foreign-cold-cache" } }, query, profileResult("Foreign Cold Cache"));
  assert.equal(profileView(session, accountId)?.profile.username, "Rowan Vale");
  response(view, read, query, profileResult("Fresh Cold Cache"));
  assert.equal(profileView(session, accountId)?.profile.username, "Fresh Cold Cache");
});

test("manual profile cards register their read before dispatch", { concurrency: false }, () => {
  resetActionScope(); resetProfileCaches();
  const view = cloneView();
  payloadOf(view).records.response = null;
  const session = readStaff(view);
  assert(session);
  const ambient = session.profiles.find((profile) => profile.id === accountId);
  assert(ambient);
  begin();
  profileCard("manual-profile", ambient, "", session);
  const action = event({ id: "manual-profile/open", type: "activate" }).action;
  assert(action);
  const query = queryOf(action);
  response(view, { request: { request_id: "foreign-manual-card" } }, query, profileResult("Foreign Manual Card"));
  assert.equal(profileView(session, accountId)?.profile.username, "Rowan Vale");
  response(view, action, query, profileResult("Fresh Manual Card"));
  assert.equal(profileView(session, accountId)?.profile.username, "Fresh Manual Card");
});

test("a newer page makes older request ids foreign, even with the same target", { concurrency: false }, () => {
  resetActionScope(); resetProfileCaches();
  const view = cloneView();
  const session = readStaff(view);
  assert(session);
  const firstQuery = profileQuery();
  const first = staffRequest(session, { kind: "query", query: JSON.stringify(firstQuery) });
  response(view, first, firstQuery, profileResult("First Rowan", [warning("first")], "page-2"));
  assert.equal(profileView(session, accountId)?.profile.username, "First Rowan");

  const secondQuery = profileQuery("page-2");
  const second = staffRequest(session, { kind: "query", query: JSON.stringify(secondQuery) });
  response(view, first, firstQuery, profileResult("Delayed First Rowan", [warning("delayed-first")]));
  assert.equal(profileView(session, accountId)?.profile.username, "First Rowan");
  assert.deepEqual(profileView(session, accountId)?.warnings.map((row) => row.text), ["first"]);

  response(view, { request: { request_id: "foreign-same-scope" } }, secondQuery, profileResult("Foreign Rowan", [warning("foreign")]));
  assert.equal(profileView(session, accountId)?.profile.username, "First Rowan");

  response(view, second, secondQuery, profileResult("Second Rowan", [warning("second")]));
  assert.equal(profileView(session, accountId)?.profile.username, "Second Rowan");
});

test("conversation cache keeps the newest exact read after delayed and foreign replies", { concurrency: false }, () => {
  resetActionScope(); resetProfileCaches();
  const view = cloneView();
  payloadOf(view).records.response = null;
  const session = readStaff(view);
  assert(session);
  const profile = profileView(session, accountId);
  assert(profile);
  const query = conversationQuery();
  const first = staffRequest(session, { kind: "query", query: JSON.stringify(query) });
  response(view, first, query, conversationResult("first"));
  const loaded = profileView(session, accountId);
  assert(loaded);
  assert.equal(conversationFor(session, loaded)?.record.messages[0].body, "first");

  const second = staffRequest(session, { kind: "query", query: JSON.stringify(query) });
  response(view, first, query, conversationResult("delayed"));
  assert.equal(conversationFor(session, profile)?.record.messages[0].body, "first");
  response(view, { request: { request_id: "foreign-conversation" } }, query, conversationResult("foreign"));
  assert.equal(conversationFor(session, profile)?.record.messages[0].body, "first");
  response(view, second, query, conversationResult("second"));
  assert.equal(conversationFor(session, profile)?.record.messages[0].body, "second");
});

test("historical conversation references still correlate after the round changes", { concurrency: false }, () => {
  resetActionScope(); resetProfileCaches();
  const view = cloneView();
  view.state.staff.round_id = "85";
  view.state.staff.payload.current_round = "85";
  payloadOf(view).records.response = null;
  const session = readStaff(view);
  assert(session);
  const profile = profileView(session, accountId);
  assert(profile);
  const query = conversationQuery();
  const read = staffRequest(session, { kind: "query", query: JSON.stringify(query) });
  response(view, read, query, conversationResult("historical"));
  const loaded = profileView(session, accountId);
  assert(loaded);
  assert.equal(conversationFor(session, loaded)?.record.messages[0].body, "historical");

  const newer = staffRequest(session, { kind: "query", query: JSON.stringify(query) });
  response(view, read, query, conversationResult("delayed-historical"));
  assert.equal(conversationFor(session, profile)?.record.messages[0].body, "historical");
  response(view, newer, query, conversationResult("new-historical"));
  assert.equal(conversationFor(session, profile)?.record.messages[0].body, "new-historical");
});

test("foreign historical pages stay hidden on a cold conversation cache", { concurrency: false }, () => {
  resetActionScope(); resetProfileCaches();
  const view = cloneView();
  view.state.staff.round_id = "85";
  view.state.staff.payload.current_round = "85";
  payloadOf(view).records.response = null;
  const session = readStaff(view);
  assert(session);
  const profile = profileView(session, accountId);
  assert(profile);
  const query = conversationQuery();
  staffRequest(session, { kind: "query", query: JSON.stringify(query) });
  response(view, { request: { request_id: "foreign-historical-cold-cache" } }, query, conversationResult("foreign-historical"));
  const refreshed = profileView(session, accountId);
  assert(refreshed);
  assert.equal(conversationFor(session, refreshed), null);
});

test("canonical metadata merges with ambient summaries and partial rows keep counts", { concurrency: false }, () => {
  resetActionScope(); resetProfileCaches();
  const view = cloneView();
  const session = readStaff(view);
  assert(session);
  const ambient = session.profiles.find((profile) => profile.id === accountId);
  assert(ambient);
  ambient.username = "Ambient Name";
  ambient.warnings = ["ambient warning", "another warning", "third warning"];
  ambient.messageCount = 9;

  const query = profileQuery();
  const read = staffRequest(session, { kind: "query", query: JSON.stringify(query) });
  response(view, read, query, profileResult("Canonical Name", [warning("one")]));
  const profile = profileView(session, accountId);
  assert(profile);
  assert.equal(profile.profile.username, "Canonical Name");
  assert.equal(profile.profile.avatar, "portrait-02");
  assert.deepEqual(profile.profile.warnings, ambient.warnings);
  assert.equal(profile.profile.messageCount, 9);
  assert.equal(warningCount(profile), 3);
  assert.equal(messageCount(profile), 9);
});

console.log("staff read correlation: ambient admission, latest exact query identity, and summary count preservation");
