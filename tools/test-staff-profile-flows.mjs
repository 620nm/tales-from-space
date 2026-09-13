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
    "export { default as ui } from './staff/main';",
    "export { readStaff } from './staff/model';",
    "export { resetStaffFlows } from './staff/flows';",
    "export { beginProfileRender, observeDisplayedConversation, observeDisplayedProfile, profileViewAction, resetProfileFlows, warningRequest, profileNoteRequest, conversationRequest, messageRequest } from './staff/profile/flows';",
    "export { profileDrill } from './staff/profile';",
    "export { MAX_CONVERSATION_MESSAGES, MAX_PROFILE_ROWS, conversationFor, profileView, resetProfileCaches } from './staff/profile/data';",
  ].join("\n"), resolveDir: fileURLToPath(new URL("../ui", import.meta.url)), loader: "ts",
  },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") }, bundle: true, format: "esm", platform: "node", write: false,
});
const { ui, readStaff, resetStaffFlows, beginProfileRender, observeDisplayedConversation, observeDisplayedProfile, profileViewAction, resetProfileFlows, warningRequest, profileNoteRequest, conversationRequest, messageRequest, profileDrill, conversationFor, MAX_CONVERSATION_MESSAGES, MAX_PROFILE_ROWS, profileView, resetProfileCaches } = await import(
  `data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString("base64")}`,
);
globalThis.__lunaticLocale = { tag: "en", catalog: JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url))) };

const fixture = JSON.parse(await readFile(new URL("../ui/staff/fixtures/staff-profile.json", import.meta.url))).view;
const accountId = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
const otherAccount = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";
const account = { round: "", kind: "account", id: accountId };
const other = { round: "", kind: "account", id: otherAccount };
const conversation = { round: "84", kind: "conversation", id: "7001" };
const message = { round: "84", kind: "message", id: "7002" };

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
  return action?.request?.request_id;
}

function queryOf(action) {
  return JSON.parse(action.request.action.Query.query);
}

function response(view, request, query, result, error = null) {
  payloadOf(view).records.response = { request_id: requestId(request), query, refs: [], cursor: null, result, error };
}

function accepted(view, request, query) {
  response(view, request, query, { kind: "accepted" });
}

function warningRow(at, text) {
  return { target: account, author: other, at, text };
}

function profileResult(warnings, next = null) {
  return { kind: "profile", profile: {
    target: account,
    identity: { id: accountId, username: "Rowan Vale", avatar: "portrait-02", role: "player" },
    warnings, notes: [], conversations: [], next,
  } };
}

function conversationResult(messages = [], next = null, delivery_receipts = []) {
  return { kind: "conversation_page", conversation: {
    reference: conversation, account, created_at: 1, messages, delivery_receipts, next,
  } };
}

test("profile writes use the live submitted value and refresh only after their own receipt", { concurrency: false }, () => {
  resetProfileFlows(); resetProfileCaches(); resetStaffFlows();
  const view = cloneView();
  const session = readStaff(view);
  assert(session);
  const write = warningRequest(session, account, "fresh warning");
  const writeQuery = { op: "warning", target: account, text: "fresh warning" };
  response(view, { request: { request_id: "foreign" } }, writeQuery, { kind: "accepted" });
  assert.equal(profileViewAction(readStaff(view)), undefined);
  accepted(view, write, writeQuery);
  const refresh = profileViewAction(readStaff(view));
  assert(refresh);
  assert.deepEqual(queryOf(refresh), { op: "profile", target: account, limit: 64 });

  response(view, refresh, queryOf(refresh), profileResult([warningRow(2, "fresh warning")]));
  assert.equal(profileViewAction(readStaff(view)), undefined);
  const profile = profileView(readStaff(view), accountId);
  assert(profile);
  assert.equal(profile.warnings[0].text, "fresh warning");
});

test("profile submit captures the exact activation value before debounce", { concurrency: false }, () => {
  resetProfileFlows(); resetProfileCaches(); resetStaffFlows();
  const view = cloneView();
  ui.render(view);
  ui.onEvent({ id: "staff/cases/rail/ref/0", type: "activate" });
  const initial = ui.render(view);
  const nodes = (node) => [node, ...(node.children ?? []).flatMap(nodes)];
  assert(!nodes(initial).find((node) => node.id === "staff/profile/warning/save")?.disabled);
  // The fixture's profile is already selected by the cases rail. The event
  // value stands in for the browser's live submit field.
  const action = ui.onEvent({ id: "staff/profile/warning/save", type: "activate", value: "activation exact" }).action;
  assert(action);
  assert.equal(JSON.parse(action.request.action.Records.request).text, "activation exact");
  const tree = ui.render(view);
  assert.equal(nodes(tree).find((node) => node.id === "staff/profile/warning/new")?.debounceMs, 120);
});

test("conversation creation binds the returned reference to its requested account", { concurrency: false }, () => {
  resetProfileFlows(); resetProfileCaches(); resetStaffFlows();
  const view = cloneView();
  const session = readStaff(view);
  assert(session);
  const write = conversationRequest(session, account);
  const query = { op: "conversation", account };
  response(view, write, { ...query, account: other }, { kind: "conversation", conversation });
  assert.equal(profileViewAction(readStaff(view)), undefined);
  response(view, write, query, { kind: "conversation", conversation });
  const read = profileViewAction(readStaff(view));
  assert(read);
  assert.deepEqual(queryOf(read), { op: "conversation", conversation, limit: 16, newest: true });
  response(view, read, queryOf(read), conversationResult());
  assert.equal(profileViewAction(readStaff(view)), undefined);
  const profile = profileView(readStaff(view), accountId);
  assert(profile);
  assert.deepEqual(conversationFor(readStaff(view), profile), { reference: conversation, account, record: { reference: conversation, account, created_at: 1, messages: [], delivery_receipts: [], next: null } });
});

test("message receipt refreshes conversation, then profile, without retrying the write", { concurrency: false }, () => {
  resetProfileFlows(); resetProfileCaches(); resetStaffFlows();
  const view = cloneView();
  const session = readStaff(view);
  assert(session);
  const write = messageRequest(session, account, conversation, "hello");
  const writeQuery = { op: "message", conversation, body: "hello" };
  response(view, write, writeQuery, { kind: "message", message });
  const conversationRead = profileViewAction(readStaff(view));
  assert(conversationRead);
  assert.deepEqual(queryOf(conversationRead), { op: "conversation", conversation, limit: 16, newest: true });
  response(view, conversationRead, queryOf(conversationRead), conversationResult([{ reference: message, body: "hello" }]));
  const profileRead = profileViewAction(readStaff(view));
  assert(profileRead);
  assert.deepEqual(queryOf(profileRead), { op: "profile", target: account, limit: 64 });
  response(view, profileRead, queryOf(profileRead), profileResult([]));
  assert.equal(profileViewAction(readStaff(view)), undefined);
  assert.equal(profileViewAction(readStaff(view)), undefined, "the accepted write is never replayed");
});

test("refresh reads require their exact request id and whole query, with three bounded retries", { concurrency: false }, () => {
  resetProfileFlows(); resetProfileCaches(); resetStaffFlows();
  const view = cloneView();
  const session = readStaff(view);
  assert(session);
  const write = profileNoteRequest(session, account, "note");
  const writeQuery = { op: "profile_note", target: account, text: "note" };
  accepted(view, write, writeQuery);
  let read = profileViewAction(readStaff(view));
  assert(read);
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const query = queryOf(read);
    response(view, { request: { request_id: "foreign" } }, { ...query, limit: 63 }, null, "stale_revision");
    assert.equal(profileViewAction(readStaff(view)), undefined);
    response(view, read, query, null, attempt === 0 ? "stale_revision" : "query_bound");
    const retry = profileViewAction(readStaff(view));
    if (attempt < 3) {
      assert(retry);
      assert.deepEqual(queryOf(retry), query);
      read = retry;
    } else {
      assert.equal(retry, undefined);
    }
  }
});

test("profile first-page refresh replaces its fresh rows and preserves older pagination", { concurrency: false }, () => {
  resetProfileFlows(); resetProfileCaches(); resetStaffFlows();
  const view = cloneView();
  const session = readStaff(view);
  assert(session);
  const firstQuery = { op: "profile", target: account, limit: 64 };
  response(view, "profile-1", firstQuery, profileResult([warningRow(2, "fresh old")], "cursor-old"));
  profileView(session, accountId);
  const olderQuery = { ...firstQuery, after: "cursor-old" };
  response(view, "profile-2", olderQuery, profileResult([warningRow(1, "older")], null));
  profileView(session, accountId);
  response(view, "profile-3", firstQuery, profileResult([warningRow(3, "fresh new")], null));
  const profile = profileView(session, accountId);
  assert(profile);
  assert.deepEqual(profile.warnings.map((warning) => warning.text).sort(), ["fresh new", "older"]);
});

test("errored read payloads cannot replace accepted profile or conversation history", { concurrency: false }, () => {
  resetProfileFlows(); resetProfileCaches(); resetStaffFlows();
  const view = cloneView();
  const session = readStaff(view);
  const profileQuery = { op: "profile", target: account, limit: 64 };
  response(view, { request: { request_id: "accepted-profile" } }, profileQuery, profileResult([warningRow(1, "accepted")]));
  profileView(session, accountId);
  const rejected = profileResult([warningRow(2, "rejected")]);
  rejected.profile.identity.username = "Rejected identity";
  response(view, { request: { request_id: "rejected-profile" } }, profileQuery, rejected, "stale_revision");
  const profile = profileView(session, accountId);
  assert.equal(profile.profile.username, "Rowan Vale");
  assert.deepEqual(profile.warnings.map(row => row.text), ["accepted"]);

  const query = { op: "conversation", conversation, limit: 16, newest: true };
  const row = body => ({ reference: message, body });
  response(view, { request: { request_id: "accepted-conversation" } }, query, conversationResult([row("accepted")]));
  conversationFor(session, profile);
  response(view, { request: { request_id: "rejected-conversation" } }, query, conversationResult([row("rejected")]), "query_bound");
  assert.deepEqual(conversationFor(session, profile).record.messages.map(row => row.body), ["accepted"]);
});

test("profile and conversation scratch caches keep their row bounds", { concurrency: false }, () => {
  resetProfileFlows(); resetProfileCaches(); resetStaffFlows();
  const view = cloneView();
  const session = readStaff(view);
  assert(session);
  const profileQuery = { op: "profile", target: account, limit: 64 };
  const warnings = Array.from({ length: MAX_PROFILE_ROWS + 16 }, (_, index) => warningRow(index, `warning-${index}`));
  response(view, { request: { request_id: "bounded-profile" } }, profileQuery, profileResult(warnings));
  const profile = profileView(session, accountId);
  assert(profile);
  assert.equal(profile.warnings.length, MAX_PROFILE_ROWS);

  const messages = Array.from({ length: MAX_CONVERSATION_MESSAGES + 16 }, (_, index) => ({
    reference: { round: "84", kind: "message", id: String(8000 + index) }, body: `message-${index}`,
  }));
  const conversationQuery = { op: "conversation", conversation, limit: 16, newest: true };
  response(view, { request: { request_id: "bounded-conversation" } }, conversationQuery, conversationResult(messages));
  const current = profileView(session, accountId);
  assert(current);
  const saved = conversationFor(session, current);
  assert(saved);
  assert.equal(saved.record.messages.length, MAX_CONVERSATION_MESSAGES);
});

test("incoming profile updates refresh the displayed account once", { concurrency: false }, () => {
  resetProfileFlows(); resetProfileCaches(); resetStaffFlows();
  const view = cloneView();
  const session = readStaff(view);
  assert(session);
  observeDisplayedProfile(session, account);
  const change = { round: "84", kind: "message", id: "7010" };
  payloadOf(view).contact_updates = [{ account, conversation, change }];
  const refresh = profileViewAction(readStaff(view));
  assert(refresh);
  assert.deepEqual(queryOf(refresh), { op: "profile", target: account, limit: 64 });
  response(view, { request: { request_id: "foreign" } }, queryOf(refresh), profileResult([]));
  assert.equal(profileViewAction(readStaff(view)), undefined);
  response(view, refresh, queryOf(refresh), profileResult([]));
  assert.equal(profileViewAction(readStaff(view)), undefined);
  assert.equal(profileViewAction(readStaff(view)), undefined, "a seen update does not refresh again");
});

test("leaving an account retires its incoming refresh chain", { concurrency: false }, () => {
  resetProfileFlows(); resetProfileCaches(); resetStaffFlows();
  const view = cloneView();
  const session = readStaff(view);
  observeDisplayedConversation(session, account, conversation);
  payloadOf(view).contact_updates = [{ account, conversation, change: message }];
  const read = profileViewAction(readStaff(view));
  assert(read);

  beginProfileRender(session);
  observeDisplayedProfile(session, other);
  response(view, read, queryOf(read), conversationResult([{ reference: message, body: "reply" }]));
  assert.equal(profileViewAction(readStaff(view)), undefined, "the old account gets no follow-up read");
});

test("incoming conversation updates coalesce and refresh conversation before profile", { concurrency: false }, () => {
  resetProfileFlows(); resetProfileCaches(); resetStaffFlows();
  const view = cloneView();
  const session = readStaff(view);
  assert(session);
  observeDisplayedConversation(session, account, conversation);
  const firstChange = { round: "84", kind: "message", id: "7011" };
  const laterChange = { round: "84", kind: "message", id: "7012" };
  payloadOf(view).contact_updates = [{ account, conversation, change: firstChange }];
  const firstRead = profileViewAction(readStaff(view));
  assert(firstRead);
  assert.deepEqual(queryOf(firstRead), { op: "conversation", conversation, limit: 16, newest: true });

  payloadOf(view).contact_updates = [{ account, conversation, change: laterChange }];
  response(view, firstRead, queryOf(firstRead), conversationResult([{ reference: firstChange, body: "first" }]));
  const secondRead = profileViewAction(readStaff(view));
  assert(secondRead);
  assert.deepEqual(queryOf(secondRead), { op: "conversation", conversation, limit: 16, newest: true });

  response(view, secondRead, queryOf(secondRead), conversationResult([{ reference: laterChange, body: "later" }]));
  const profileRead = profileViewAction(readStaff(view));
  assert(profileRead);
  assert.deepEqual(queryOf(profileRead), { op: "profile", target: account, limit: 64 });
  response(view, profileRead, queryOf(profileRead), profileResult([]));
  assert.equal(profileViewAction(readStaff(view)), undefined);
});

test("loaded conversations retain a visible first-page manual refresh", { concurrency: false }, () => {
  resetProfileFlows(); resetProfileCaches(); resetStaffFlows();
  const view = cloneView();
  const session = readStaff(view);
  assert(session);
  const profileQuery = { op: "profile", target: account, limit: 64 };
  response(view, { request: { request_id: "manual-profile" } }, profileQuery, profileResult([]));
  profileView(session, accountId);
  const conversationQuery = { op: "conversation", conversation, limit: 16, newest: true };
  response(view, { request: { request_id: "manual-conversation" } }, conversationQuery, conversationResult([{ reference: message, body: "loaded" }]));
  profileView(session, accountId);
  beginProfileRender(session);
  const card = profileDrill(session, accountId);
  const refresh = findNode(card, "staff/profile/conversation/load");
  assert(refresh);
  assert.equal(refresh.text, "lunatic/tfs:ui.staff.refresh_messages");
  const action = ui.onEvent({ id: refresh.id, type: "activate" }).action;
  assert(action);
  assert.deepEqual(queryOf(action), conversationQuery);
});

test("newest conversation refresh keeps messages and receipts at a shifting page boundary", { concurrency: false }, () => {
  resetProfileFlows(); resetProfileCaches(); resetStaffFlows();
  const view = cloneView();
  const session = readStaff(view);
  assert(session);
  const row = (index) => ({
    reference: { round: "84", kind: "message", id: String(8000 + index) },
    body: `message-${index}`, at: index,
  });
  const firstQuery = { op: "conversation", conversation, limit: 16, newest: true };
  const firstPage = Array.from({ length: 16 }, (_, index) => row(index + 2));
  const boundaryReceipt = { message: firstPage[0].reference, account, at: 20 };
  response(view, { request: { request_id: "conversation-first" } }, firstQuery, conversationResult(firstPage, "older", [boundaryReceipt]));
  const profile = profileView(session, accountId);
  assert(profile);
  assert.deepEqual(conversationFor(session, profile)?.record.messages.map((item) => item.body), firstPage.map((item) => item.body));

  const olderQuery = { ...firstQuery, after: "older" };
  response(view, { request: { request_id: "conversation-older" } }, olderQuery, conversationResult([row(0), row(1)]));
  assert.deepEqual(conversationFor(session, profile)?.record.messages.map((item) => item.body), Array.from({ length: 18 }, (_, index) => `message-${index}`));

  response(view, { request: { request_id: "conversation-refresh" } }, firstQuery, conversationResult(Array.from({ length: 16 }, (_, index) => row(index + 3))));
  const refreshed = conversationFor(session, profile);
  assert(refreshed);
  assert.deepEqual(refreshed.record.messages.map((item) => item.body), Array.from({ length: 19 }, (_, index) => `message-${index}`));
  assert.deepEqual(refreshed.record.delivery_receipts.map((item) => item.message), [boundaryReceipt.message]);
});

test("mixed-round conversation pages follow journal ids and retain exact receipts", { concurrency: false }, () => {
  resetProfileFlows(); resetProfileCaches(); resetStaffFlows();
  const view = cloneView();
  const session = readStaff(view);
  assert(session);
  const row = (round, id, at) => ({
    reference: { round, kind: "message", id }, body: `${round}-${id}`, at,
  });
  const firstQuery = { op: "conversation", conversation, limit: 16, newest: true };
  const newerRound = row("8", "9007199254740993", 1);
  const olderRound = row("4", "9007199254740992", 90);
  const boundaryReceipt = { message: newerRound.reference, account, at: 2 };
  response(view, { request: { request_id: "mixed-round-first" } }, firstQuery, conversationResult([newerRound, olderRound], "older", [boundaryReceipt]));
  const profile = profileView(session, accountId);
  assert(profile);
  assert.deepEqual(conversationFor(session, profile)?.record.messages.map((item) => item.body), [olderRound.body, newerRound.body]);

  const olderPage = row("4", "9007199254740991", 99);
  const olderReceipt = { message: olderPage.reference, account, at: 100 };
  response(view, { request: { request_id: "mixed-round-older" } }, { ...firstQuery, after: "older" }, conversationResult([olderPage], null, [olderReceipt]));
  assert.deepEqual(conversationFor(session, profile)?.record.messages.map((item) => item.body), [olderPage.body, olderRound.body, newerRound.body]);
  assert.deepEqual(conversationFor(session, profile)?.record.delivery_receipts.map((item) => item.message), [olderReceipt.message, boundaryReceipt.message]);

  const sameIdOtherRound = row("5", "9007199254740992", 90);
  response(view, { request: { request_id: "mixed-round-same-id" } }, firstQuery, conversationResult([sameIdOtherRound]));
  const merged = conversationFor(session, profile);
  assert(merged);
  assert.deepEqual(merged.record.messages.map((item) => item.body), [olderPage.body, olderRound.body, sameIdOtherRound.body, newerRound.body]);
  assert.deepEqual(merged.record.delivery_receipts.map((item) => item.message), [olderReceipt.message, boundaryReceipt.message]);
});

function findNode(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = findNode(child, id);
    if (found) return found;
  }
  return null;
}

console.log("staff profile flows: exact writes, bounded refresh chains, account binding, debounce submits, and cache pagination");
