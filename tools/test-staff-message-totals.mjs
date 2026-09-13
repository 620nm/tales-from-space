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
      "export { readStaff } from './staff/model';",
      "export { profileView, resetProfileCaches, messageCount } from './staff/profile/data';",
      "export { resetActionScope, staffRequest } from './staff/shared/actions';",
    ].join("\n"),
    resolveDir: fileURLToPath(new URL("../ui", import.meta.url)),
    loader: "ts",
  },
  alias: { "@lunatic/ui": resolve(engine, "web/sdk/index.ts") },
  bundle: true, format: "esm", platform: "node", write: false,
});
const { readStaff, profileView, resetProfileCaches, messageCount, resetActionScope, staffRequest } = await import(
  `data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString("base64")}`,
);

globalThis.__lunaticLocale = { tag: "en", catalog: JSON.parse(await readFile(new URL("../locale/en.json", import.meta.url))) };
const fixture = JSON.parse(await readFile(new URL("../ui/staff/fixtures/staff-profile.json", import.meta.url))).view;
const accountId = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
const account = { round: "", kind: "account", id: accountId };
const conversation = { round: "84", kind: "conversation", id: "7001" };

function cloneView() {
  const view = structuredClone(fixture);
  view.state.staff.round_id = "84";
  view.state.staff.payload.current_round = "84";
  view.state.staff.payload.records.response = null;
  const ambient = view.state.staff.payload.profiles.find((profile) => profile.id === accountId);
  delete ambient.message_count;
  return view;
}

function response(view, request, query, result) {
  view.state.staff.payload.records.response = {
    request_id: request.request.request_id,
    query,
    refs: [],
    cursor: null,
    result,
    error: null,
  };
}

function profileQuery() {
  return { op: "profile", target: account, limit: 64 };
}

function conversationQuery() {
  return { op: "conversation", conversation, limit: 16, newest: true };
}

function messages(count) {
  return Array.from({ length: count }, (_, index) => ({
    reference: { round: "84", kind: "message", id: String(7100 + index) },
    body: `message-${index}`,
  }));
}

function profileResult(message_count, loaded = 0, delivery_receipts = []) {
  const record = { reference: conversation, account, messages: messages(loaded), delivery_receipts, next: null };
  if (message_count !== undefined) record.message_count = message_count;
  return {
    kind: "profile",
    profile: {
      target: account,
      identity: { id: accountId, username: "Rowan Vale", avatar: "portrait-02", role: "player" },
      warnings: [], notes: [], conversations: [record], next: null,
    },
  };
}

function conversationResult(message_count, loaded = 0, delivery_receipts = []) {
  const record = { reference: conversation, account, messages: messages(loaded), delivery_receipts, next: null };
  if (message_count !== undefined) record.message_count = message_count;
  return { kind: "conversation_page", conversation: record };
}

function profileWithTotal(message_count, loaded = 0, delivery_receipts = [], ambientCount) {
  resetActionScope();
  resetProfileCaches();
  const view = cloneView();
  if (ambientCount !== undefined) view.state.staff.payload.profiles.find((profile) => profile.id === accountId).message_count = ambientCount;
  const session = readStaff(view);
  assert(session);
  const query = profileQuery();
  const request = staffRequest(session, { kind: "query", query: JSON.stringify(query) });
  response(view, request, query, profileResult(message_count, loaded, delivery_receipts));
  const profile = profileView(session, accountId);
  assert(profile);
  return { view, session, profile };
}

test("conversation total wins over its loaded page and excludes receipts", { concurrency: false }, () => {
  const receipt = { message: { round: "84", kind: "message", id: "7100" }, account };
  const { profile } = profileWithTotal(65, 16, [receipt]);
  assert.equal(messageCount(profile), 65);
});

test("empty conversations report zero and do not count the conversation row", { concurrency: false }, () => {
  const { profile } = profileWithTotal(0, 0, [{ message: { round: "84", kind: "message", id: "7100" }, account }]);
  assert.equal(messageCount(profile), 0);
});

test("ambient summary remains the fallback when a conversation has no total", { concurrency: false }, () => {
  const { profile } = profileWithTotal(undefined, 0, [], 9);
  assert.equal(messageCount(profile), 9);
});

test("conversation cache keeps the newest total over an older page", { concurrency: false }, () => {
  const { view, session, profile } = profileWithTotal(65, 16);
  const query = conversationQuery();
  const newer = staffRequest(session, { kind: "query", query: JSON.stringify(query) });
  response(view, newer, query, conversationResult(66, 16));
  assert.equal(messageCount(profileView(session, accountId)), 66);

  const older = staffRequest(session, { kind: "query", query: JSON.stringify(query) });
  response(view, older, query, conversationResult(65, 16));
  assert.equal(messageCount(profileView(session, accountId)), 66);
});

test("invalid totals are rejected in favor of loaded rows", { concurrency: false }, () => {
  for (const invalid of [-1, 1.5, Number.MAX_SAFE_INTEGER + 1, "65"]) {
    const { profile } = profileWithTotal(invalid, 16);
    assert.equal(messageCount(profile), 16, `invalid total ${String(invalid)}`);
  }
});

console.log("staff message totals: bounded pages, receipts, empty records and monotonic cache totals");
